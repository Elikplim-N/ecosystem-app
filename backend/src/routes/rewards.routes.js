import { Router } from 'express';
import { z } from 'zod';
import { many, one, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

/**
 * Rewards and redemptions.
 *
 * Under Firebase a redemption was written under the user document and nothing
 * ever read it back, so a member could redeem and then hear nothing. The
 * status column here is what gives the admin console a queue to work through.
 */

/** Serialise a reward for the app. [mine] adds the caller's own balance. */
function present(r, myPoints = null) {
  return {
    id: r.id,
    title: r.title,
    description: r.description ?? null,
    category: r.category ?? 'standard',
    partnerName: r.partner_name,
    costPoints: r.cost_points,
    stock: r.stock,
    active: r.is_active,
    myPoints,
    canAfford: myPoints === null ? null : myPoints >= r.cost_points,
    createdAt: r.created_at,
  };
}

const adminCreateSchema = z.object({
  title: z.string().trim().min(2, 'Give the reward a title.').max(160),
  description: z.string().trim().max(1000).optional(),
  category: z.enum(['standard', 'partner']).default('standard'),
  partnerName: z.string().trim().max(120).optional(),
  costPoints: z.coerce.number().int().min(1, 'A reward must cost at least 1 point.').max(1_000_000),
  stock: z.coerce.number().int().min(0).max(1_000_000).nullable().optional(),
  active: z.boolean().default(true),
});

const adminUpdateSchema = adminCreateSchema.partial();

/** GET /api/rewards - the member-facing catalogue. Inactive rows are hidden. */
router.get(
  '/',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select r.*, u.points as my_points
         from rewards r
         cross join users u
        where u.id = $1
        order by r.cost_points asc`,
      [req.user.id],
    );
    res.json({
      rewards: rows.filter((r) => r.is_active).map((r) => present(r, r.my_points)),
    });
  }),
);

/**
 * GET /api/rewards/admin - the full catalogue, including inactive rows.
 *
 * Kept separate from the member list so a deactivated reward is hidden from
 * members without being deleted.
 */
router.get(
  '/admin',
  requireAuth(),
  requireRole('admin'),
  asyncHandler(async (_req, res) => {
    const rows = await many(`select * from rewards order by cost_points asc`);
    res.json({ rewards: rows.map((r) => present(r)) });
  }),
);

/** POST /api/rewards/admin - add a reward to the catalogue. */
router.post(
  '/admin',
  requireAuth(),
  requireRole('admin'),
  validate({ body: adminCreateSchema }),
  asyncHandler(async (req, res) => {
    const b = req.body;

    if (b.category === 'partner' && !b.partnerName) {
      throw AppError.validation('Some fields need attention.', [
        { field: 'body.partnerName', message: 'Name the partner for a partner reward.' },
      ]);
    }

    const row = await withActor(req.user.id, async (client) => {
      const { rows } = await client.query(
        `insert into rewards (title, description, category, partner_name, cost_points, stock, is_active)
         values ($1, $2, $3, $4, $5, $6, $7)
         returning *`,
        [
          b.title, b.description ?? null, b.category, b.partnerName ?? null,
          b.costPoints, b.stock ?? null, b.active,
        ],
      );

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'reward.created',
        entityType: 'reward',
        entityId: rows[0].id,
        details: { title: b.title, costPoints: b.costPoints },
      });

      return rows[0];
    });

    res.status(201).json({ reward: present(row) });
  }),
);

/** PATCH /api/rewards/admin/:id - edit or deactivate. */
router.patch(
  '/admin/:id',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }), body: adminUpdateSchema }),
  asyncHandler(async (req, res) => {
    const b = req.body;
    const row = await withActor(req.user.id, async (client) => {
      const { rows } = await client.query(
        `update rewards set
           title = coalesce($2, title),
           description = coalesce($3, description),
           category = coalesce($4, category),
           partner_name = coalesce($5, partner_name),
           cost_points = coalesce($6, cost_points),
           stock = case when $7::boolean then $8 else stock end,
           is_active = coalesce($9, is_active),
           updated_at = now()
         where id = $1
         returning *`,
        [
          req.params.id, b.title ?? null, b.description ?? null, b.category ?? null,
          b.partnerName ?? null, b.costPoints ?? null, 'stock' in b, b.stock ?? null,
          b.active ?? null,
        ],
      );

      if (!rows[0]) throw AppError.notFound('Reward');

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'reward.updated',
        entityType: 'reward',
        entityId: req.params.id,
        details: { fields: Object.keys(b) },
      });

      return rows[0];
    });

    res.json({ reward: present(row) });
  }),
);

/**
 * DELETE /api/rewards/admin/:id
 *
 * A reward that has ever been redeemed cannot be deleted - redemptions
 * reference it with ON DELETE RESTRICT, and the history is the point of the
 * queue. Deactivate it instead.
 */
router.delete(
  '/admin/:id',
  requireAuth(),
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    const used = await one(
      'select exists(select 1 from redemptions where reward_id = $1) as used',
      [req.params.id],
    );

    if (used?.used) {
      throw AppError.conflict('This reward has been redeemed already. Deactivate it instead.');
    }

    const removed = await withActor(req.user.id, async (client) => {
      const { rowCount } = await client.query('delete from rewards where id = $1', [req.params.id]);
      if (!rowCount) throw AppError.notFound('Reward');

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'reward.deleted',
        entityType: 'reward',
        entityId: req.params.id,
      });
    });

    res.json({ ok: true });
  }),
);

/**
 * POST /api/rewards/:id/redeem
 *
 * Points are deducted inside the transaction that creates the redemption, and
 * users.points has a CHECK (points >= 0). Two concurrent redemptions for the
 * same member cannot both succeed if together they exceed the balance: the
 * second UPDATE would violate the check and roll back.
 */
router.post(
  '/:id/redeem',
  requireAuth(),
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    const result = await withActor(req.user.id, async (client) => {
      const reward = await one(
        `select id, title, cost_points, stock from rewards
          where id = $1 and is_active for update`,
        [req.params.id],
      );
      if (!reward) throw AppError.notFound('Reward');
      if (reward.stock !== null && reward.stock <= 0) throw AppError.conflict('This reward is out of stock.');

      const me = await one(`select points from users where id = $1 for update`, [req.user.id]);
      if (me.points < reward.cost_points) {
        throw AppError.badRequest(
          `You need ${reward.cost_points - me.points} more point(s) for this reward.`,
        );
      }

      const { rows: updated } = await client.query(
        `update users set points = points - $2 where id = $1 returning points`,
        [req.user.id, reward.cost_points],
      );

      const { rows: redemption } = await client.query(
        `insert into redemptions (user_id, reward_id, cost_points, status)
         values ($1, $2, $3, 'pending') returning id, status, created_at`,
        [req.user.id, reward.id, reward.cost_points],
      );

      if (reward.stock !== null) {
        await client.query(`update rewards set stock = stock - 1 where id = $1`, [reward.id]);
      }

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'reward.redeemed',
        entityType: 'redemption',
        entityId: redemption[0].id,
        details: { reward: reward.title, cost: reward.cost_points },
      });

      return { redemption: redemption[0], pointsLeft: updated[0].points, title: reward.title };
    });

    res.status(201).json({
      redemption: { id: result.redemption.id, status: result.redemption.status, at: result.redemption.created_at },
      rewardTitle: result.title,
      pointsLeft: result.pointsLeft,
    });
  }),
);

/** GET /api/rewards/me/redemptions */
router.get(
  '/me/redemptions',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select d.id, d.cost_points, d.status, d.review_note, d.created_at, d.reviewed_at,
              r.title, r.partner_name
         from redemptions d
         join rewards r on r.id = d.reward_id
        where d.user_id = $1
        order by d.created_at desc
        limit 50`,
      [req.user.id],
    );
    res.json({
      redemptions: rows.map((d) => ({
        id: d.id,
        title: d.title,
        partnerName: d.partner_name,
        costPoints: d.cost_points,
        status: d.status,
        reviewNote: d.review_note,
        requestedAt: d.created_at,
        reviewedAt: d.reviewed_at,
      })),
    });
  }),
);

/** GET /api/rewards/redemptions - admin queue. */
router.get(
  '/redemptions',
  requireAuth(),
  requireRole('admin'),
  validate({
    query: z.object({
      status: z.enum(['pending', 'approved', 'rejected', 'fulfilled']).default('pending'),
      limit: z.coerce.number().int().min(1).max(200).default(50),
      offset: z.coerce.number().int().min(0).default(0),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { status, limit, offset } = req.query;
    const rows = await many(
      `select d.id, d.cost_points, d.status, d.review_note, d.created_at,
              u.id as user_id, u.name, u.phone, u.nickname,
              r.title as reward_title, r.partner_name
         from redemptions d
         join users u on u.id = d.user_id
         join rewards r on r.id = d.reward_id
        where d.status = $1
        order by d.created_at asc
        limit $2 offset $3`,
      [status, limit, offset],
    );
    res.json({
      redemptions: rows.map((d) => ({
        id: d.id,
        userId: d.user_id,
        userName: d.name,
        userPhone: d.phone,
        rewardTitle: d.reward_title,
        partnerName: d.partner_name,
        costPoints: d.cost_points,
        status: d.status,
        reviewNote: d.review_note,
        requestedAt: d.created_at,
      })),
    });
  }),
);

/**
 * POST /api/rewards/redemptions/:id/review
 *
 * Rejecting refunds the points, because they were taken at request time. Not
 * refunding on rejection would let a member lose points for an admin decision
 * they did not cause.
 */
router.post(
  '/redemptions/:id/review',
  requireAuth(),
  requireRole('admin'),
  validate({
    params: z.object({ id: uuid }),
    body: z.object({
      decision: z.enum(['approve', 'reject', 'fulfil']),
      note: z.string().trim().max(500).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const outcome = await withActor(req.user.id, async (client) => {
      const d = await one(
        `select id, user_id, cost_points, status from redemptions where id = $1 for update`,
        [req.params.id],
      );
      if (!d) throw AppError.notFound('Redemption');
      if (d.status !== 'pending') {
        throw AppError.conflict(`This redemption is already ${d.status}.`);
      }

      const nextStatus = { approve: 'approved', reject: 'rejected', fulfil: 'fulfilled' }[req.body.decision];

      await client.query(
        `update redemptions set status = $2, reviewed_by_id = $3, reviewed_at = now(),
                                 review_note = $4, collected_at = case when $2 = 'fulfilled' then now() else null end
          where id = $1`,
        [d.id, nextStatus, req.user.id, req.body.note ?? null],
      );

      if (nextStatus === 'rejected') {
        await client.query(
          `update users set points = points + $2 where id = $1`,
          [d.user_id, d.cost_points],
        );
      }

      await writeAudit(client, {
        actorId: req.user.id,
        action: `redemption.${nextStatus}`,
        entityType: 'redemption',
        entityId: d.id,
        details: { refunded: nextStatus === 'rejected', cost: d.cost_points },
      });

      return { status: nextStatus, refunded: nextStatus === 'rejected', cost: d.cost_points };
    });

    res.json(outcome);
  }),
);

export default router;
