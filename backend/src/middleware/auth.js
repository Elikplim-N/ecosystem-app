import jwt from 'jsonwebtoken';
import config from '../config.js';
import { one } from '../db.js';
import { AppError } from '../errors.js';

/**
 * Sign a short-lived access token.
 *
 * Only the user id goes in it. Role and account_state are deliberately NOT
 * trusted from the token: they are re-read from the database on every request
 * (see loadUser), so disabling an account or changing a role takes effect
 * immediately instead of whenever the old token happens to expire.
 */
export function signAccessToken(userId) {
  return jwt.sign({ sub: userId, typ: 'access' }, config.auth.jwtSecret, {
    expiresIn: `${config.auth.accessTtlMin}m`,
    issuer: 'ecosystem',
  });
}

export function verifyAccessToken(token) {
  try {
    const payload = jwt.verify(token, config.auth.jwtSecret, { issuer: 'ecosystem' });
    if (payload.typ !== 'access') throw new Error('wrong token type');
    return payload;
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw AppError.unauthorized('Session expired. Please sign in again.');
    }
    throw AppError.unauthorized('Invalid session.');
  }
}

/**
 * Re-read the user so authorisation always reflects current database state.
 * Selecting three columns off the primary key is cheap, and it is what makes
 * "disable this account" work instantly.
 */
export async function loadUser(userId) {
  const user = await one(
    `select id, name, nickname, phone, email, avatar_icon, role_id, account_state,
            ambassador_state, points, bottles, weight_kg
       from users
      where id = $1`,
    [userId],
  );

  if (!user) throw AppError.unauthorized('Account no longer exists.');
  if (user.account_state === 'disabled') {
    throw AppError.forbidden('This account has been disabled. Contact an administrator.');
  }
  if (user.account_state === 'deleted') {
    throw AppError.unauthorized('Account no longer exists.');
  }

  return user;
}

/** Requires a valid access token; attaches req.user. */
export function requireAuth() {
  return async function requireAuthMiddleware(req, _res, next) {
    try {
      const header = req.get('authorization') || '';
      const [scheme, token] = header.split(' ');

      if (scheme !== 'Bearer' || !token) {
        throw AppError.unauthorized('Sign in to continue.');
      }

      const payload = verifyAccessToken(token);
      req.user = await loadUser(payload.sub);
      req.userId = req.user.id;
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

/** Requires one of the given roles. Use after requireAuth. */
export function requireRole(...roles) {
  return function requireRoleMiddleware(req, _res, next) {
    if (!req.user) return next(AppError.unauthorized('Sign in to continue.'));
    if (!roles.includes(req.user.role_id)) {
      return next(
        AppError.forbidden(`This action requires: ${roles.join(' or ')}.`),
      );
    }
    return next();
  };
}

/** Allows the owner of the resource, or any admin. */
export function requireSelfOrAdmin(paramName = 'id') {
  return function requireSelfOrAdminMiddleware(req, _res, next) {
    if (!req.user) return next(AppError.unauthorized('Sign in to continue.'));
    if (req.user.role_id === 'admin') return next();
    if (req.params[paramName] === req.user.id) return next();
    return next(AppError.forbidden('You can only access your own records.'));
  };
}

export default { signAccessToken, verifyAccessToken, requireAuth, requireRole, requireSelfOrAdmin };
