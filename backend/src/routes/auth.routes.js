import { Router } from 'express';
import { z } from 'zod';
import { one, withTransaction } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, signAccessToken } from '../middleware/auth.js';
import { loginLimiter, registerLimiter } from '../middleware/rateLimit.js';
import {
  authenticate,
  createPasswordResetToken,
  createSession,
  hashPassword,
  resetPasswordWithToken,
  revokeAllSessions,
  revokeSession,
  rotateSession,
} from '../services/authService.js';
import { writeAudit } from '../services/auditService.js';
import { deliverPasswordReset } from '../services/mailer.js';
import config from '../config.js';

const router = Router();

/** Ghana numbers are stored with the country code, e.g. +233201234567. */
const phone = z
  .string()
  .trim()
  .regex(/^\+?[0-9]{9,15}$/, 'Enter a valid phone number.')
  .transform((v) => (v.startsWith('+') ? v : `+${v.replace(/^0/, '')}`));

const password = z
  .string()
  .min(8, 'Use at least 8 characters.')
  .max(200, 'That password is too long.');

const registerSchema = z.object({
  name: z.string().trim().min(2, 'Enter your full name.').max(120),
  phone,
  password,
  email: z.string().trim().email('Enter a valid email.').optional().or(z.literal('').transform(() => undefined)),
  nickname: z.string().trim().min(2).max(40).optional(),
  avatarIcon: z.string().trim().max(8).optional(),
});

const loginSchema = z.object({
  // Either the phone number or the email address.
  identifier: z.string().trim().min(3, 'Enter your phone number or email.'),
  password: z.string().min(1, 'Enter your password.'),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(10, 'Missing refresh token.'),
});

/** Shape returned to the Flutter app. No password_hash, ever. */
function publicUser(u) {
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
    // The applicant's own screen shows why a decision went the way it did, so
    // the review note has to come back on /me rather than only on the admin
    // queue endpoint.
    ambassadorReviewNote: u.ambassador_review_note ?? null,
    points: u.points ?? 0,
    bottles: u.bottles ?? 0,
    weightKg: Number(u.weight_kg ?? 0),
  };
}

/** POST /api/auth/register */
router.post(
  '/register',
  registerLimiter,
  validate({ body: registerSchema }),
  asyncHandler(async (req, res) => {
    const { name, phone: phoneNumber, password: raw, email, nickname, avatarIcon } = req.body;

    const clash = await one(
      `select
         case when phone = $1 then 'phone' end as on_phone,
         case when email is not null and email = lower($2) then 'email' end as on_email
       from users
       where phone = $1 or (email is not null and email = lower($2))
       limit 1`,
      [phoneNumber, email ?? null],
    );

    if (clash?.on_phone) throw AppError.conflict('That phone number is already registered.');
    if (clash?.on_email) throw AppError.conflict('That email is already registered.');

    // Hashing before the transaction keeps the connection held for as little
    // time as possible - argon2id is deliberately slow.
    const hash = await hashPassword(raw);

    const result = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `insert into users (name, nickname, phone, email, password_hash, avatar_icon, role_id)
         values ($1, $2, $3, $4, $5, coalesce($6, U&'\+01F642'), 'user')
         returning id, name, nickname, phone, email, avatar_icon, role_id,
                   account_state, ambassador_state, points, bottles, weight_kg`,
        [name, nickname ?? null, phoneNumber, email || null, hash, avatarIcon ?? null],
      );
      const user = rows[0];

      const session = await createSession(client, user.id, {
        userAgent: req.get('user-agent'),
        ipAddress: req.ip,
      });

      await writeAudit(client, {
        actorId: user.id,
        action: 'user.registered',
        entityType: 'user',
        entityId: user.id,
        ipAddress: req.ip,
      });

      return { user, session };
    });

    res.status(201).json({
      user: publicUser(result.user),
      accessToken: signAccessToken(result.user.id),
      refreshToken: result.session.refreshToken,
    });
  }),
);

/** POST /api/auth/login */
router.post(
  '/login',
  loginLimiter,
  validate({ body: loginSchema }),
  asyncHandler(async (req, res) => {
    const { identifier, password: raw } = req.body;
    const user = await authenticate(identifier, raw);

    const session = await withTransaction((client) =>
      createSession(client, user.id, { userAgent: req.get('user-agent'), ipAddress: req.ip }),
    );

    res.json({
      user: publicUser(user),
      accessToken: signAccessToken(user.id),
      refreshToken: session.refreshToken,
    });
  }),
);

/** POST /api/auth/refresh - rotates the refresh token. */
router.post(
  '/refresh',
  validate({ body: refreshSchema }),
  asyncHandler(async (req, res) => {
    const { user, refreshToken, accessToken } = await rotateSession(req.body.refreshToken, {
      userAgent: req.get('user-agent'),
      ipAddress: req.ip,
    });
    res.json({ user: publicUser(user), accessToken, refreshToken });
  }),
);

/** POST /api/auth/logout - revokes one session. */
router.post(
  '/logout',
  validate({ body: refreshSchema }),
  asyncHandler(async (req, res) => {
    await revokeSession(req.body.refreshToken);
    res.json({ ok: true });
  }),
);

/** POST /api/auth/logout-all - signs out every device. */
router.post(
  '/logout-all',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const revoked = await revokeAllSessions(req.user.id);
    res.json({ ok: true, sessionsRevoked: revoked });
  }),
);

/** GET /api/auth/me */
router.get(
  '/me',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const full = await one(
      `select id, name, nickname, phone, email, avatar_icon, role_id, account_state,
              ambassador_state, ambassador_area, ambassador_motivation,
              ambassador_applied_at, ambassador_review_note,
              points, bottles, weight_kg, created_at, last_login_at
         from users where id = $1`,
      [req.user.id],
    );
    res.json({ user: publicUser(full) });
  }),
);

/**
 * POST /api/auth/forgot-password
 *
 * Always responds 200, whether or not the identifier belongs to an account.
 * Anything else turns this into a way of discovering which phone numbers and
 * emails are registered, which is exactly what login's vague error is there to
 * prevent.
 *
 * No email/SMS provider is wired up yet (see the Known gaps section of the
 * README), so in development the reset token is logged and echoed back, which
 * is what makes the flow testable end to end without one. In production the
 * token is never included in the response - wire `deliverPasswordReset` to a
 * real provider before deploying, and it will simply start sending.
 */
router.post(
  '/forgot-password',
  loginLimiter,
  validate({ body: z.object({ identifier: z.string().trim().min(3) }) }),
  asyncHandler(async (req, res) => {
    const user = await one(
      `select id, phone, email from users
        where (phone = $1 or lower(email) = lower($1)) and account_state <> 'deleted'
        limit 1`,
      [req.body.identifier],
    );

    // Declared outside the branch because the development response below
    // reads it even when there is no account.
    let token = null;
    if (user) {
      token = await withTransaction((client) => createPasswordResetToken(client, user.id));
      await deliverPasswordReset({ user, token });
    }

    res.json({
      ok: true,
      message: 'If that account exists, a reset link is on its way.',
      // Development only. See the comment above.
      ...(config.isProduction ? {} : { debugToken: token }),
    });
  }),
);

/**
 * POST /api/auth/reset-password
 *
 * Consumes a single-use token, sets the new password, and revokes every
 * existing session for that account in the same transaction.
 */
router.post(
  '/reset-password',
  validate({ body: z.object({ token: z.string().min(20), password }) }),
  asyncHandler(async (req, res) => {
    const user = await resetPasswordWithToken(req.body.token, req.body.password);
    res.json({ ok: true, name: user.name });
  }),
);

export default router;
