import { Router } from 'express';
import { z } from 'zod';
import { many, one, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { normaliseTag } from '../lib/rfid.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

const cardKinds = ['standard', 'mifare_1k', 'mifare_ultralight', 'em4100', 'hid_prox', 'student_id', 'staff_id'];

/** Issue a card. */
const createSchema = z.object({
  tag: z.string().trim().min(4, 'Scan or type the card tag.'),
  cardKind: z.enum(cardKinds).default('standard'),
  notes: z.string().trim().max(500).optional(),
  assignToUserId: uuid.optional(),
});

const linkSchema = z.object({
  userId: uuid.nullable().optional(),
});

function present(c) {
  return {
    id: c.id,
    tag: c.tag_normalised,
    tagRaw: c.tag_raw,
    tagLength: c.tag_length,
    cardKind: c.card_kind,
    state: c.state,
    assignedUserId: c.assigned_user_id,
    assignedUserName: c.assigned_user_name ?? null,
    assignedAt: c.assigned_at,
    notes: c.notes,
    createdAt: c.created_at,
  };
}

const SELECT_CARD = `
  select c.*, u.name as assigned_user_name
    from rfid_cards c
    left join users u on u.id = c.assigned_user_id`;

/** GET /api/rfid/cards */
router.get(
  '/cards',
  requireAuth(),
  validate({
    query: z.object({
      state: z.enum(['available', 'linked', 'lost', 'revoked']).optional(),
      search: z.string().trim().max(40).optional(),
      limit: z.coerce.number().int().min(1).max(200).default(100),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { state, search, limit } = req.query;
    const where = [];
    const params = [];

    if (state) {
      params.push(state);
      where.push(`c.state = $${params.length}`);
    }
    if (search) {
      const tag = normaliseTag(search);
      params.push(tag.ok ? `%${tag.hex}%` : `%${search.replace(/[\s:._-]/g, '').toUpperCase()}%`);
      where.push(`c.tag_normalised ilike $${params.length} or replace(c.tag_normalised,' ','') ilike $${params.length}`);
    }

    const rows = await many(
      `${SELECT_CARD}
       ${where.length ? `where ${where.map((w) => `(${w})`).join(' and ')}` : ''}
       order by c.created_at desc
       limit $${params.length + 1}`,
      [...params, limit],
    );

    res.json({ cards: rows.map(present) });
  }),
);

/**
 * POST /api/rfid/cards
 *
 * The tag is normalised before insert, so 'a3f9:21c0' and 'A3F9 21C0' collide
 * on the UNIQUE constraint instead of becoming two cards. The database is the
 * thing enforcing that, not this code.
 */
router.post(
  '/cards',
  requireAuth(),
  requireRole('admin'),
  validate({ body: createSchema }),
  asyncHandler(async (req, res) => {
    const tag = normaliseTag(req.body.tag);
    if (!tag.ok) throw AppError.validation('Some fields need attention.', [{ field: 'body.tag', message: tag.reason }]);

    if (req.body.assignToUserId) {
      const user = await one(`select id from users where id = $1 and account_state = 'active'`, [req.body.assignToUserId]);
      if (!user) throw AppError.validation('Some fields need attention.', [
        { field: 'body.assignToUserId', message: 'No active member with that id.' },
      ]);
    }

    try {
      const id = await withActor(req.user.id, async (client) => {
        const { rows } = await client.query(
          `insert into rfid_cards (tag_raw, tag_normalised, tag_length, card_kind, state,
                                    assigned_user_id, assigned_at, issued_by, notes)
           values ($1, $2, $3, $4,
                   case when $5::uuid is null then 'available' else 'linked' end,
                   $5, case when $5::uuid is null then null else now() end, $6, $7)
           returning id`,
          [req.body.tag.trim(), tag.normalised, tag.length, req.body.cardKind, req.body.assignToUserId ?? null, req.user.id, req.body.notes ?? null],
        );
        await writeAudit(client, {
          actorId: req.user.id,
          action: 'rfid.issued',
          entityType: 'rfid_card',
          entityId: rows[0].id,
          details: { tag: tag.normalised, assignedTo: req.body.assignToUserId ?? null },
        });
        return rows[0].id;
      });

      const card = await one(`${SELECT_CARD} where c.id = $1`, [id]);
      res.status(201).json({ card: present(card), detected: { bytes: tag.bytes, label: tag.label } });
    } catch (err) {
      if (err.code === '23505') {
        const existing = await one(`${SELECT_CARD} where c.tag_normalised = $1`, [tag.normalised]);
        throw AppError.conflict(
          `That card is already registered${existing?.assigned_user_name ? ` to ${existing.assigned_user_name}` : ''}.`,
          { existingCard: existing ? present(existing) : null },
        );
      }
      throw err;
    }
  }),
);

/** PATCH /api/rfid/cards/:id/link - assign or unassign. */
router.patch(
  '/cards/:id/link',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }), body: linkSchema }),
  asyncHandler(async (req, res) => {
    const card = await one(`${SELECT_CARD} where c.id = $1`, [req.params.id]);
    if (!card) throw AppError.notFound('Card');

    const userId = req.body.userId ?? null;

    if (userId) {
      const user = await one(`select id, name from users where id = $1 and account_state = 'active'`, [userId]);
      if (!user) throw AppError.validation('Some fields need attention.', [
        { field: 'body.userId', message: 'No active member with that id.' },
      ]);
      const held = await one(
        `select id from rfid_cards
          where assigned_user_id = $1 and id <> $2 and state in ('linked','lost')`,
        [userId, card.id],
      );
      if (held) throw AppError.conflict('That member already has an active card.');
    }

    const updated = await withActor(req.user.id, async (client) => {
      await client.query(
        `update rfid_cards set
           assigned_user_id = $2,
           assigned_at = case when $2::uuid is null then null else now() end,
           state = case when $2::uuid is null then 'available' else 'linked' end,
           lost_at = null
         where id = $1`,
        [card.id, userId],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: userId ? 'rfid.linked' : 'rfid.unlinked',
        entityType: 'rfid_card',
        entityId: card.id,
        details: { tag: card.tag_normalised, userId },
      });
      const { rows } = await client.query(`${SELECT_CARD} where c.id = $1`, [card.id]);
      return rows[0];
    });

    res.json({ card: present(updated) });
  }),
);

/** POST /api/rfid/cards/:id/status - lost / restore / revoke. */
router.post(
  '/cards/:id/status',
  requireAuth(),
  requireRole('admin'),
  validate({
    params: z.object({ id: uuid }),
    body: z.object({
      state: z.enum(['available', 'linked', 'lost', 'revoked']),
      notes: z.string().trim().max(500).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const card = await one(`${SELECT_CARD} where c.id = $1`, [req.params.id]);
    if (!card) throw AppError.notFound('Card');

    // Marking a card lost must not silently unassign it: the link is the only
    // record that this tag belonged to someone, and it may be needed to issue
    // a replacement.
    if (req.body.state === 'lost' && !card.assigned_user_id) {
      throw AppError.badRequest('Only an assigned card can be marked lost.');
    }

    const updated = await withActor(req.user.id, async (client) => {
      await client.query(
        `update rfid_cards set
           state = $2,
           lost_at = case when $2 = 'lost' then now() else null end,
           revoked_at = case when $2 = 'revoked' then now() else null end,
           notes = coalesce($3, notes)
         where id = $1`,
        [card.id, req.body.state, req.body.notes ?? null],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: `rfid.${req.body.state}`,
        entityType: 'rfid_card',
        entityId: card.id,
        details: { tag: card.tag_normalised },
      });
      const { rows } = await client.query(`${SELECT_CARD} where c.id = $1`, [card.id]);
      return rows[0];
    });

    res.json({ card: present(updated) });
  }),
);

/** DELETE /api/rfid/cards/:id */
router.delete(
  '/cards/:id',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    const card = await one(`${SELECT_CARD} where c.id = $1`, [req.params.id]);
    if (!card) throw AppError.notFound('Card');

    if (card.state === 'linked') {
      throw AppError.conflict('Unassign the card before deleting it.');
    }

    await withActor(req.user.id, async (client) => {
      await client.query('delete from rfid_cards where id = $1', [card.id]);
      await writeAudit(client, {
        actorId: req.user.id,
        action: 'rfid.deleted',
        entityType: 'rfid_card',
        entityId: card.id,
        details: { tag: card.tag_normalised },
      });
    });

    res.json({ ok: true });
  }),
);

export default router;
