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
 * The ambassador application flow.
 *
 * ambassador_state and role_id are kept separate on purpose. A rejected
 * applicant stays a user and can apply again; only approval moves them to the
 * ambassador role. Collapsing both into role would lose that history.
 */

const applySchema = z.object({
  area: z.string().trim().min(2, 'Which area do you want to cover?').max(120),
  motivation: z.string().trim().min(20, 'Tell us a little more (at least 20 characters).').max(1000),
});

/** POST /api/ambassador/apply */
router.post(
  '/apply',
  requireAuth(),
  validate({ body: applySchema }),
  asyncHandler(async (req, res) => {
    if (req.user.role_id === 'ambassador') {
      throw AppError.conflict('You are already an ambassador.');
    }
    if (req.user.role_id === 'admin') {
      throw AppError.forbidden('Administrators do not need to apply.');
    }
    if (req.user.ambassador_state === 'pending') {
      throw AppError.conflict('Your application is already being reviewed.');
    }

    const row = await one(
      `update users set
         ambassador_state = 'pending',
         ambassador_area = $2,
         ambassador_motivation = $3,
         ambassador_applied_at = now()
       where id = $1
       returning id, ambassador_state, ambassador_area, ambassador_motivation, ambassador_applied_at`,
      [req.user.id, req.body.area, req.body.motivation],
    );

    await withActor(req.user.id, (client) =>
      writeAudit(client, {
        actorId: req.user.id,
        action: 'ambassador.applied',
        entityType: 'user',
        entityId: req.user.id,
        details: { area: req.body.area },
      }),
    );

    res.status(201).json({
      application: {
        status: row.ambassador_state,
        area: row.ambassador_area,
        motivation: row.ambassador_motivation,
        appliedAt: row.ambassador_applied_at,
      },
    });
  }),
);

/** POST /api/ambassador/withdraw */
router.post(
  '/withdraw',
  requireAuth(),
  asyncHandler(async (req, res) => {
    if (req.user.ambassador_state !== 'pending') {
      throw AppError.badRequest('You have no pending application to withdraw.');
    }
    const row = await one(
      `update users set ambassador_state = 'none', ambassador_applied_at = null
        where id = $1 returning id, ambassador_state`,
      [req.user.id],
    );
    res.json({ application: { status: row.ambassador_state } });
  }),
);

/** GET /api/ambassador/applications - admin queue. */
router.get(
  '/applications',
  requireAuth(),
  requireRole('admin'),
  validate({
    query: z.object({
      status: z.enum(['none', 'pending', 'approved', 'rejected']).default('pending'),
      limit: z.coerce.number().int().min(1).max(200).default(50),
      offset: z.coerce.number().int().min(0).default(0),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { status, limit, offset } = req.query;
    const rows = await many(
      `select id, name, nickname, phone, email, avatar_icon, points, bottles, weight_kg,
              ambassador_state, ambassador_area, ambassador_motivation,
              ambassador_applied_at, ambassador_reviewed_at, ambassador_review_note
         from users
        where ambassador_state = $1
        order by ambassador_applied_at asc nulls last
        limit $2 offset $3`,
      [status, limit, offset],
    );

    res.json({
      applications: rows.map((u) => ({
        userId: u.id,
        name: u.name,
        nickname: u.nickname,
        phone: u.phone,
        email: u.email,
        avatarIcon: u.avatar_icon,
        points: u.points,
        bottles: u.bottles,
        weightKg: Number(u.weight_kg),
        status: u.ambassador_state,
        area: u.ambassador_area,
        motivation: u.ambassador_motivation,
        appliedAt: u.ambassador_applied_at,
        reviewedAt: u.ambassador_reviewed_at,
        reviewNote: u.ambassador_review_note,
      })),
    });
  }),
);

/** POST /api/ambassador/applications/:id/review - admin approves or rejects. */
router.post(
  '/applications/:id/review',
  requireAuth(),
  requireRole('admin'),
  validate({
    params: z.object({ id: uuid }),
    body: z.object({
      decision: z.enum(['approve', 'reject']),
      note: z.string().trim().max(500).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const applicant = await one(
      `select id, name, ambassador_state from users where id = $1`,
      [req.params.id],
    );
    if (!applicant) throw AppError.notFound('Application');
    if (applicant.ambassador_state !== 'pending') {
      throw AppError.conflict(`This application is already ${applicant.ambassador_state}.`);
    }

    const approved = req.body.decision === 'approve';

    await withActor(req.user.id, async (client) => {
      // role_id and ambassador_state move together, in one transaction, so an
      // applicant can never be an approved ambassador whose state says pending.
      await client.query(
        `update users set
           ambassador_state = $2,
           ambassador_reviewed_at = now(),
           ambassador_review_note = $3,
           role_id = case when $4 then 'ambassador' else role_id end
         where id = $1`,
        [applicant.id, approved ? 'approved' : 'rejected', req.body.note ?? null, approved],
      );

      await writeAudit(client, {
        actorId: req.user.id,
        action: approved ? 'ambassador.approved' : 'ambassador.rejected',
        entityType: 'user',
        entityId: applicant.id,
        details: { name: applicant.name, note: req.body.note ?? null },
      });
    });

    // No session revocation here in either direction: a rejected applicant is
    // still a member and must stay signed in, and an approved member already
    // has a valid session that will pick up the new role on its next request.

    const updated = await one(
      `select id, role_id, ambassador_state, ambassador_review_note, ambassador_reviewed_at
         from users where id = $1`,
      [applicant.id],
    );

    res.json({
      user: {
        id: updated.id,
        role: updated.role_id,
        ambassadorState: updated.ambassador_state,
        reviewNote: updated.ambassador_review_note,
        reviewedAt: updated.ambassador_reviewed_at,
      },
    });
  }),
);

export default router;
