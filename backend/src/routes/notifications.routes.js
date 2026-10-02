import { Router } from 'express';
import { z } from 'zod';
import { many, one, query, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

router.use(requireAuth());

/**
 * A member's own notification feed.
 *
 * The admin side of this already existed under /api/admin/notifications; this
 * is the reading end, which the app's notification screen needs. A row is
 * visible to a member when it was addressed to them personally, or when it was
 * broadcast to their role.
 *
 * Note on broadcasts: notifications holds one row per broadcast rather than one
 * row per recipient, so `is_read` on a broadcast means "an admin marked this
 * sent" rather than "this member has read it". Per-member read state for
 * broadcasts would need a join table; for now the unread badge counts
 * personal rows only, which is the case that actually happens.
 */

const feedSchema = z.object({
  limit: z.coerce.number().int().min(1).max(200).default(50),
  offset: z.coerce.number().int().min(0).default(0),
  unreadOnly: z.coerce.boolean().default(false),
});

/** GET /api/notifications - the member's feed, newest first. */
router.get(
  '/',
  validate({ query: feedSchema }),
  asyncHandler(async (req, res) => {
    const { limit, offset, unreadOnly } = req.query;

    const rows = await many(
      `select n.id, n.title, n.body, n.kind, n.is_read, n.read_at, n.created_at,
              n.user_id is not null as is_personal
         from notifications n
        where (n.user_id = $1 or n.target_role = $2)
          ${unreadOnly ? 'and n.is_read = false' : ''}
        order by n.created_at desc
        limit $3 offset $4`,
      [req.user.id, req.user.role_id, limit, offset],
    );

    const { rows: countRows } = await query(
      `select count(*)::int as total,
              count(*) filter (where is_read = false)::int as unread
         from notifications
        where user_id = $1 or target_role = $2`,
      [req.user.id, req.user.role_id],
    );

    res.json({
      notifications: rows.map((n) => ({
        id: n.id,
        title: n.title,
        body: n.body,
        kind: n.kind,
        isRead: n.is_read,
        readAt: n.read_at,
        createdAt: n.created_at,
        isPersonal: n.is_personal,
      })),
      total: countRows[0].total,
      unread: countRows[0].unread,
    });
  }),
);

/** POST /api/notifications/:id/read - mark one as read. */
router.post(
  '/:id/read',
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    // The visibility check is in the WHERE clause rather than a separate read
    // so a member cannot mark somebody else's notification read by guessing
    // an id, and does not learn that the id exists.
    const row = await one(
      `update notifications set is_read = true, read_at = coalesce(read_at, now())
        where id = $1 and (user_id = $2 or target_role = $3)
        returning id`,
      [req.params.id, req.user.id, req.user.role_id],
    );

    if (!row) throw AppError.notFound('Notification');
    res.json({ ok: true });
  }),
);

/** POST /api/notifications/read-all - clear the badge. */
router.post(
  '/read-all',
  asyncHandler(async (req, res) => {
    const updated = await withActor(req.user.id, async (client) => {
      const { rowCount } = await client.query(
        `update notifications set is_read = true, read_at = coalesce(read_at, now())
          where (user_id = $1 or target_role = $2) and is_read = false`,
        [req.user.id, req.user.role_id],
      );
      return rowCount;
    });

    res.json({ ok: true, marked: updated });
  }),
);

export default router;
