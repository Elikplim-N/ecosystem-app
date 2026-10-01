import { AppError } from '../errors.js';

/**
 * Bin state is never set by hand from a fill percentage: it is derived.
 * Keeping that in one place means the sensor ingest path and the admin
 * editing path cannot disagree about when a bin counts as full.
 *
 * These thresholds match the Flutter UI's LevelBar.
 */
export const FULL_AT = 90;
export const FILLING_AT = 55;

/**
 * @param {number} fillPercent
 * @param {boolean} disabled
 * @returns {'available' | 'filling' | 'full' | 'disabled'}
 */
export function stateForFill(fillPercent, disabled = false) {
  if (disabled) return 'disabled';
  const pct = Number(fillPercent);
  if (Number.isNaN(pct)) throw AppError.badRequest('fillPercent must be a number.');
  if (pct >= FULL_AT) return 'full';
  if (pct >= FILLING_AT) return 'filling';
  return 'available';
}

/**
 * Who may change a bin.
 *
 * Admins may change any bin. Ambassadors may change bins they created - which
 * is the same rule BinsRepository.canEdit() applies on the client.
 *
 * If the team decides ambassadors should manage every bin in their assigned
 * area instead, this is the single place to change.
 */
export function assertCanEditBin(user, bin) {
  if (user.role_id === 'admin') return;
  if (user.role_id === 'ambassador' && bin.created_by_id === user.id) return;
  throw AppError.forbidden('You can only manage bins you created.');
}

/** Only an admin may delete a bin. */
export function assertIsAdmin(user) {
  if (user.role_id !== 'admin') {
    throw AppError.forbidden('This action is restricted to administrators.');
  }
}

export default { stateForFill, assertCanEditBin, assertIsAdmin, FULL_AT, FILLING_AT };
