import rateLimit from 'express-rate-limit';

const jsonMessage = (message) => ({ error: { code: 'rate_limited', message } });

/**
 * Login and registration are the only endpoints worth brute-forcing, so they
 * get a tight limit. Everything else gets a generous ceiling that still stops
 * a single client from flooding the database pool.
 */

// Applied per IP. Note that in production behind a proxy this needs
// `app.set('trust proxy', 1)` or every client looks like the proxy.
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: jsonMessage('Too many attempts. Try again in a few minutes.'),
});

export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: jsonMessage('Too many accounts created from this device.'),
});

export const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: jsonMessage('Slow down.'),
});

/** For device ingestion, which is authenticated by sensor rather than session. */
export const deviceLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: jsonMessage('Reporting too frequently.'),
});

/**
 * The contact form, which is deliberately reachable without a session.
 *
 * Being unauthenticated means the general per-IP ceiling is the only thing
 * standing between the database and someone who found the endpoint, so this
 * is tighter than apiLimiter and ignores successes.
 */
export const contactLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: jsonMessage('Too many messages sent. Try again in an hour.'),
});

export default { loginLimiter, registerLimiter, apiLimiter, deviceLimiter, contactLimiter };
