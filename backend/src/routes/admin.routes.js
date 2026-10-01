import { Router } from 'express';
import { z } from 'zod';
import { many, one, query } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

router.use(requireAuth(), requireRole('admin'));

/** GET /api/admin/dashboard - the numbers the admin home screen shows. */
router.get(
  '/dashboard',
  asyncHandler(async (_req, res) => {
    const [summary] = await one('select * from admin_dashboard_summary');
    const [bins] = await one('select * from bin_summary');

    const recent = await many(
      `select a.action, a.entity_type, a.entity_id, a.created_at, u.name as actor
         from audit_log a
         left join users u on u.id = a.actor_id
        order by a.created_at desc
        limit 10`,
    );

    res.json({
      users: {
        active: summary.active_users,
        ambassadors: summary.ambassadors,
        pendingApplications: summary.pending_applications,
      },
      queues: {
        pendingRedemptions: summary.pending_redemptions,
        openMessages: summary.open_messages,
      },
      bins: {
        total: bins.total,
        available: bins.available,
        filling: bins.filling,
        full: bins.full,
        disabled: bins.disabled,
        sensorBacked: bins.sensor_backed,
        located: bins.located,
      },
      rfid: { spareCards: summary.spare_cards },
      recentActivity: recent.map((r) => ({
        action: r.action,
        entityType: r.entity_type,
        entityId: r.entity_id,
        actor: r.actor,
        at: r.created_at,
      })),
    });
  }),
);

/** GET /api/admin/messages - the contact form inbox. */
router.get(
  '/messages',
  validate({
    query: z.object({
      status: z.enum(['open', 'answered', 'closed']).default('open'),
      limit: z.coerce.number().int().min(1).max(200).default(50),
    }),
  }),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select m.*, u.name as user_name, u.phone as user_phone
         from contact_messages m
         left join users u on u.id = m.user_id
        where m.status = $1
        order by m.created_at asc
        limit $2`,
      [req.query.status, req.query.limit],
    );
    res.json({
      messages: rows.map((m) => ({
        id: m.id,
        userId: m.user_id,
        userName: m.user_name,
        name: m.name,
        phone: m.phone,
        email: m.email,
        message: m.message,
        status: m.status,
        reply: m.reply,
        repliedAt: m.replied_at,
        createdAt: m.created_at,
      })),
    });
  }),
);

/** POST /api/admin/messages/:id/reply */
router.post(
  '/messages/:id/reply',
  validate({
    params: z.object({ id: uuid }),
    body: z.object({ reply: z.string().trim().min(1).max(2000), close: z.boolean().default(true) }),
  }),
  asyncHandler(async (req, res) => {
    const updated = await one(
      `update contact_messages
          set reply = $2, replied_by_id = $3, replied_at = now(),
              status = case when $4 then 'closed' else 'answered' end
        where id = $1
        returning id, status`,
      [req.params.id, req.body.reply, req.user.id, req.body.close],
    );
    if (!updated) throw AppError.notFound('Message');
    res.json({ id: updated.id, status: updated.status });
  }),
);

/** GET /api/admin/notifications - broadcast history. */
router.get(
  '/notifications',
  validate({ query: z.object({ limit: z.coerce.number().int().min(1).max(200).default(50) }) }),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select n.id, n.user_id, n.target_role, n.title, n.body, n.kind, n.created_at, u.name
         from notifications n
         left join users u on u.id = n.user_id
        order by n.created_at desc
        limit $1`,
      [req.query.limit],
    );
    res.json({
      notifications: rows.map((n) => ({
        id: n.id,
        userId: n.user_id,
        userName: n.name,
        targetRole: n.target_role,
        title: n.title,
        body: n.body,
        kind: n.kind,
        at: n.created_at,
      })),
    });
  }),
);

/** POST /api/admin/notifications - send to one member or a whole role. */
router.post(
  '/notifications',
  validate({
    body: z.object({
      title: z.string().trim().min(1).max(120),
      body: z.string().trim().min(1).max(1000),
      kind: z.enum(['info', 'bin', 'reward', 'alert']).default('info'),
      userId: uuid.optional(),
      targetRole: z.enum(['user', 'ambassador', 'admin']).optional(),
    }).refine((v) => v.userId || v.targetRole, {
      message: 'Choose a member or a role to send to.',
      path: ['userId'],
    }),
  }),
  asyncHandler(async (req, res) => {
    const { userId, targetRole } = req.body;
    const result = await query(
      `insert into notifications (user_id, target_role, title, body, kind)
       values ($1, $2, $3, $4, $5)
       returning id`,
      [userId ?? null, userId ? null : targetRole, req.body.title, req.body.body, req.body.kind],
    );
    res.status(201).json({ id: result.rows[0].id });
  }),
);

/** GET /api/admin/audit - the full change log. */
router.get(
  '/audit',
  validate({
    query: z.object({
      entityType: z.string().trim().max(40).optional(),
      limit: z.coerce.number().int().min(1).max(500).default(100),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { entityType, limit } = req.query;
    const params = [];
    let filter = '';
    if (entityType) {
      params.push(entityType);
      filter = `where a.entity_type = $1`;
    }
    params.push(limit);

    const rows = await many(
      `select a.*, u.name as actor_name
         from audit_log a
         left join users u on u.id = a.actor_id
         ${filter}
        order by a.created_at desc, a.id desc
        limit $${params.length}`,
      params,
    );

    res.json({
      entries: rows.map((a) => ({
        id: Number(a.id),
        action: a.action,
        entityType: a.entity_type,
        entityId: a.entity_id,
        actor: a.actor_name,
        details: a.details,
        at: a.created_at,
      })),
    });
  }),
);

/** GET /api/admin/collections - what was collected, and how much. */
router.get(
  '/collections',
  validate({
    query: z.object({
      since: z.coerce.date().optional(),
      limit: z.coerce.number().int().min(1).max(500).default(100),
    }),
  }),
  asyncHandler(async (req, res) => {
    const params = [];
    let filter = '';
    if (req.query.since) {
      params.push(req.query.since);
      filter = `where c.collected_at >= $1`;
    }
    params.push(req.query.limit);

    const rows = await many(
      `select c.*, b.code as bin_code, b.name as bin_name, u.name as collected_by
         from collections c
         join bins b on b.id = c.bin_id
         left join users u on u.id = c.collected_by_id
         ${filter}
        order by c.collected_at desc
        limit $${params.length}`,
      params,
    );

    const totals = await one(
      `select count(*)::int as collections, coalesce(sum(weight_kg),0) as total_kg,
              count(*) filter (where is_estimated)::int as estimated
         from collections`,
    );

    res.json({
      collections: rows.map((c) => ({
        id: c.id,
        binCode: c.bin_code,
        binName: c.bin_name,
        collectedBy: c.collected_by,
        weightKg: Number(c.weight_kg),
        isEstimated: c.is_estimated,
        notes: c.notes,
        at: c.collected_at,
      })),
      totals: {
        collections: totals.collections,
        totalKg: Number(totals.total_kg),
        estimated: totals.estimated,
      },
    });
  }),
);

export default router;
