import { Router } from 'express';
import { z } from 'zod';
import { many, one, query, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, requireRole, requireSelfOrAdmin } from '../middleware/auth.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

const updateMeSchema = z.object({
  name: z.string().trim().min(2).max(120).optional(),
  nickname: z.string().trim().min(2).max(40).optional(),
  email: z.string().trim().email().optional().or(z.literal('').transform(() => null)),
  avatarIcon: z.string().trim().max(8).optional(),
});

function present(u) {
  return {
    id: u.id,
    name: u.name,
    nickname: u.nickname,
    phone: u.phone,
    email: u.email,
    avatarIcon: u.avatar_icon,
    role: u.role_id,
    accountState: u.account_state,
    ambassadorState: u.ambassador_state,
    ambassadorArea: u.ambassador_area ?? null,
    ambassadorMotivation: u.ambassador_motivation ?? null,
    ambassadorAppliedAt: u.ambassador_applied_at ?? null,
    ambassadorReviewNote: u.ambassador_review_note ?? null,
    points: u.points,
    bottles: u.bottles,
    weightKg: Number(u.weight_kg),
    rfidUid: u.rfid_tag ?? null,
    lastLoginAt: u.last_login_at ?? null,
    createdAt: u.created_at,
  };
}

/** PATCH /api/users/me */
router.patch(
  '/me',
  requireAuth(),
  validate({ body: updateMeSchema }),
  asyncHandler(async (req, res) => {
    const b = req.body;
    const row = await one(
      `update users set
         name = coalesce($2, name),
         nickname = coalesce($3, nickname),
         email = case when $4::boolean then $5 else email end,
         avatar_icon = coalesce($6, avatar_icon)
       where id = $1
       returning *`,
      [req.user.id, b.name ?? null, b.nickname ?? null, 'email' in b, b.email ?? null, b.avatarIcon ?? null],
    );
    res.json({ user: present(row) });
  }),
);

/** GET /api/users/me/deposits */
router.get(
  '/me/deposits',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select d.id, d.bottle_kind, d.bottle_count, d.weight_kg, d.points_awarded,
              d.created_at, b.code as bin_code, b.name as bin_name
         from deposits d
         left join bins b on b.id = d.bin_id
        where d.user_id = $1
        order by d.created_at desc
        limit 100`,
      [req.user.id],
    );
    res.json({
      deposits: rows.map((d) => ({
        id: d.id,
        bottleKind: d.bottle_kind,
        bottleCount: d.bottle_count,
        weightKg: Number(d.weight_kg),
        pointsAwarded: d.points_awarded,
        binCode: d.bin_code,
        binName: d.bin_name,
        at: d.created_at,
      })),
    });
  }),
);

/** GET /api/users/leaderboard - public ranking. */
router.get(
  '/leaderboard',
  validate({ query: z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }) }),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select rank, id, nickname, name, avatar_icon, points, bottles, weight_kg, role_id
         from leaderboard
        order by rank
        limit $1`,
      [req.query.limit],
    );
    res.json({
      leaderboard: rows.map((r) => ({
        rank: Number(r.rank),
        userId: r.id,
        nickname: r.nickname,
        name: r.name,
        avatarIcon: r.avatar_icon,
        points: r.points,
        bottles: r.bottles,
        weightKg: Number(r.weight_kg),
        role: r.role_id,
      })),
    });
  }),
);

/** GET /api/users/:id */
router.get(
  '/:id',
  requireAuth(),
  requireSelfOrAdmin('id'),
  asyncHandler(async (req, res) => {
    const row = await one('select * from users where id = $1', [req.params.id]);
    if (!row) throw AppError.notFound('User');
    res.json({ user: present(row) });
  }),
);

/** GET /api/users - admin member directory with filters. */
router.get(
  '/',
  requireAuth(),
  requireRole('admin'),
  validate({
    query: z.object({
      search: z.string().trim().max(80).optional(),
      role: z.enum(['user', 'ambassador', 'admin']).optional(),
      ambassadorState: z.enum(['none', 'pending', 'approved', 'rejected']).optional(),
      accountState: z.enum(['active', 'disabled', 'deleted']).optional(),
      limit: z.coerce.number().int().min(1).max(200).default(50),
      offset: z.coerce.number().int().min(0).default(0),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { search, role, ambassadorState, accountState, limit, offset } = req.query;
    const where = [];
    const params = [];

    if (search) {
      params.push(`%${search}%`);
      where.push(`(name ilike $${params.length} or nickname ilike $${params.length} or coalesce(phone,'') ilike $${params.length} or coalesce(email,'') ilike $${params.length})`);
    }
    for (const [column, value] of [['role_id', role], ['ambassador_state', ambassadorState], ['account_state', accountState]]) {
      if (value) {
        params.push(value);
        where.push(`${column} = $${params.length}`);
      }
    }

    const filter = where.length ? `where ${where.join(' and ')}` : '';
    const rows = await many(
      `select u.*, c.tag_normalised as rfid_tag
         from users u
         left join lateral (
           select tag_normalised from rfid_cards
            where assigned_user_id = u.id and state in ('linked','lost')
            order by assigned_at desc nulls last limit 1
         ) c on true
         ${filter}
         order by u.created_at desc
         limit $${params.length + 1} offset $${params.length + 2}`,
      [...params, limit, offset],
    );

    const { rows: countRows } = await query(
      `select count(*)::int as total from users u ${filter}`,
      params,
    );

    res.json({ users: rows.map(present), total: countRows[0].total });
  }),
);

/** POST /api/users/:id/points - admin adjusts a balance. */
router.post(
  '/:id/points',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }), body: z.object({
    delta: z.coerce.number().int().min(-100_000).max(100_000),
    reason: z.string().trim().max(240).optional(),
  }) }),
  asyncHandler(async (req, res) => {
    const target = await one('select id, name, points from users where id = $1', [req.params.id]);
    if (!target) throw AppError.notFound('User');

    const row = await withActor(req.user.id, async (client) => {
      // points has a CHECK (points >= 0), so the database refuses a deduction
      // that would go negative rather than silently allowing it.
      const { rows: r } = await client.query(
        `update users set points = points + $2 where id = $1 returning id, points`,
        [target.id, req.body.delta],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: 'user.points_adjusted',
        entityType: 'user',
        entityId: target.id,
        details: { delta: req.body.delta, reason: req.body.reason ?? null, result: r[0].points },
      });
      return r[0];
    });

    res.json({ userId: row.id, points: row.points });
  }),
);

/** POST /api/users/:id/role - admin changes a role. */
router.post(
  '/:id/role',
  requireAuth(),
  requireRole('admin'),
  validate({
    params: z.object({ id: uuid }),
    body: z.object({
      role: z.enum(['user', 'ambassador', 'admin']),
      note: z.string().trim().max(240).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    if (req.params.id === req.user.id && req.body.role !== 'admin') {
      throw AppError.badRequest('You cannot remove your own admin role.');
    }

    const target = await one('select id, name, role_id from users where id = $1', [req.params.id]);
    if (!target) throw AppError.notFound('User');

    const row = await withActor(req.user.id, async (client) => {
      const { rows: r } = await client.query(
        `update users set role_id = $2 where id = $1 returning id, role_id`,
        [target.id, req.body.role],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: 'user.role_changed',
        entityType: 'user',
        entityId: target.id,
        details: { from: target.role_id, to: req.body.role, note: req.body.note ?? null },
      });
      return r[0];
    });

    res.json({ userId: row.id, role: row.role_id });
  }),
);

/** POST /api/users/:id/disable - admin locks or unlocks an account. */
router.post(
  '/:id/disable',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }), body: z.object({
    disabled: z.boolean(),
    reason: z.string().trim().max(240).optional(),
  }) }),
  asyncHandler(async (req, res) => {
    if (req.params.id === req.user.id && req.body.disabled) {
      throw AppError.badRequest('You cannot disable your own account.');
    }

    const target = await one('select id, name from users where id = $1', [req.params.id]);
    if (!target) throw AppError.notFound('User');

    await withActor(req.user.id, async (client) => {
      await client.query(
        `update users set account_state = $2 where id = $1`,
        [target.id, req.body.disabled ? 'disabled' : 'active'],
      );
      if (req.body.disabled) {
        // Revoking sessions is what makes this immediate. Without it the
        // disabled user keeps working until their access token expires.
        await client.query(
          `update auth_sessions set state = 'revoked', revoked_at = now()
            where user_id = $1 and state = 'active'`,
          [target.id],
        );
      }
      await writeAudit(client, {
        actorId: req.user.id,
        action: req.body.disabled ? 'user.disabled' : 'user.enabled',
        entityType: 'user',
        entityId: target.id,
        details: { reason: req.body.reason ?? null },
      });
    });

    res.json({ userId: target.id, accountState: req.body.disabled ? 'disabled' : 'active' });
  }),
);

/**
 * DELETE /api/users/:id
 *
 * Removes the application account. Note what this does NOT do: it cannot
 * delete a Firebase Auth user, because there is no Firebase any more, and it
 * cannot undo recycling history. Bin ownership and deposit history are kept
 * and point at a deleted user via ON DELETE SET NULL.
 */
router.delete(
  '/:id',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }), body: z.object({
    reason: z.string().trim().min(3).max(240),
  }) }),
  asyncHandler(async (req, res) => {
    if (req.params.id === req.user.id) {
      throw AppError.badRequest('You cannot delete your own account here.');
    }

    const target = await one('select id, name, role_id from users where id = $1', [req.params.id]);
    if (!target) throw AppError.notFound('User');

    await withActor(req.user.id, async (client) => {
      // Soft delete: keeps the audit trail and any referenced history intact
      // while removing access immediately.
      await client.query(
        `update users set account_state = 'deleted' where id = $1`,
        [target.id],
      );
      await client.query(
        `update auth_sessions set state = 'revoked', revoked_at = now()
          where user_id = $1 and state = 'active'`,
        [target.id],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: 'user.deleted',
        entityType: 'user',
        entityId: target.id,
        details: { reason: req.body.reason, name: target.name },
      });
    });

    res.json({ ok: true, userId: target.id });
  }),
);

export default router;
