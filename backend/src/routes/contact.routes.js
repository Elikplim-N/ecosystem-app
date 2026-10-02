import { Router } from 'express';
import { z } from 'zod';
import { many, withActor } from '../db.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, verifyAccessToken, loadUser } from '../middleware/auth.js';
import { contactLimiter } from '../middleware/rateLimit.js';

const router = Router();
const uuid = z.string().uuid('Must be a valid id.');

/**
 * The contact form.
 *
 * The app's contact screen is reachable before signing in - someone who cannot
 * get past the login screen is exactly the person most likely to need to tell
 * us about it - so this endpoint does not require a session. If a valid token
 * is present the message is attached to that account, otherwise it is filed
 * standalone and the sender's own name/phone/email are used.
 */

/** Attaches req.user when a usable token is present, and does nothing when not. */
async function optionalAuth(req, _res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next();
  try {
    const payload = verifyAccessToken(token);
    req.user = await loadUser(payload.sub);
    req.userId = req.user.id;
  } catch {
    // A stale or invalid token should not block an anonymous message; the
    // contact form is the wrong place to tell someone their session expired.
  }
  return next();
}

const messageSchema = z.object({
  message: z.string().trim().min(10, 'Tell us a little more so we can help.').max(2000),
  name: z.string().trim().max(120).optional(),
  phone: z.string().trim().max(32).optional(),
  email: z.string().trim().email('Enter a valid email.').max(200).optional().or(z.literal('')),
});

/** POST /api/contact - file a support message. */
router.post(
  '/',
  contactLimiter,
  optionalAuth,
  validate({ body: messageSchema }),
  asyncHandler(async (req, res) => {
    const b = req.body;

    const id = await withActor(req.user?.id ?? null, async (client) => {
      const { rows } = await client.query(
        `insert into contact_messages (user_id, name, phone, email, message)
         values ($1, $2, $3, nullif($4, ''), $5)
         returning id`,
        [
          req.user?.id ?? null,
          b.name?.trim() || req.user?.name || null,
          b.phone?.trim() || req.user?.phone || null,
          b.email ?? '',
          b.message,
        ],
      );
      return rows[0].id;
    });

    res.status(201).json({ id, status: 'open' });
  }),
);

/** GET /api/contact/me - the signed-in member's own messages and replies. */
router.get(
  '/me',
  requireAuth(),
  asyncHandler(async (req, res) => {
    const rows = await many(
      `select id, message, status, reply, replied_at, created_at
         from contact_messages
        where user_id = $1
        order by created_at desc
        limit 50`,
      [req.user.id],
    );

    res.json({
      messages: rows.map((m) => ({
        id: m.id,
        message: m.message,
        status: m.status,
        reply: m.reply,
        repliedAt: m.replied_at,
        createdAt: m.created_at,
      })),
    });
  }),
);

export default router;
