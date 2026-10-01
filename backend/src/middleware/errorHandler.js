import config from '../config.js';
import { AppError } from '../errors.js';
import { describePgError } from '../db.js';
import { ZodError } from 'zod';

export function notFoundHandler(req, _res, next) {
  next(new AppError(404, 'route_not_found', `No route for ${req.method} ${req.path}`));
}

/**
 * Single place that turns any thrown error into a JSON response.
 *
 * Unknown errors become a generic 500 on purpose: a raw error from `pg` can
 * contain table names, column names and fragments of the query, none of which
 * a client should see. The full error is logged server-side instead.
 */
// eslint-disable-next-line no-unused-vars -- Express identifies handlers by arity
export function errorHandler(err, req, res, _next) {
  if (err instanceof AppError) {
    if (err.status >= 500) console.error(`[${req.method} ${req.path}]`, err);
    return res.status(err.status).json({
      error: { code: err.code, message: err.message, ...(err.details ? { details: err.details } : {}) },
    });
  }

  if (err instanceof ZodError) {
    return res.status(422).json({
      error: {
        code: 'validation_failed',
        message: 'Some fields need attention.',
        details: err.issues.map((i) => ({ field: i.path.join('.'), message: i.message })),
      },
    });
  }

  // Body parser rejecting malformed JSON.
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'bad_json', message: 'Request body is not valid JSON.' } });
  }
  if (err?.type === 'entity.too.large') {
    return res.status(413).json({ error: { code: 'payload_too_large', message: 'Request body is too large.' } });
  }

  const described = describePgError(err);
  if (described) {
    // Constraint violations are client errors, and naming the constraint is
    // useful to us without leaking anything sensitive.
    if (config.logLevel === 'debug') console.error('[pg]', err.code, err.constraint, err.message);
    return res.status(described.status).json({
      error: { code: 'database_error', message: described.message, ...(described.detail ? { field: described.detail } : {}) },
    });
  }

  console.error(`[${req.method} ${req.path}] unhandled:`, err);
  return res.status(500).json({ error: { code: 'internal_error', message: 'Something went wrong.' } });
}

export default { notFoundHandler, errorHandler };
