import { withTransaction } from '../db.js';

/**
 * Audit log writes.
 *
 * Takes a client so it can join an existing transaction - approving an
 * ambassador and recording that they were approved must either both happen or
 * neither. A failed audit write must never leave the change silently
 * unattributed.
 */
export async function writeAudit(client, { actorId, action, entityType, entityId, details, ipAddress }) {
  await client.query(
    `insert into audit_log (actor_id, action, entity_type, entity_id, details, ip_address)
     values ($1, $2, $3, $4, coalesce($5, '{}'::jsonb), $6)`,
    [actorId ?? null, action, entityType, entityId ?? null, details ? JSON.stringify(details) : null, ipAddress ?? null],
  );
}

/** Same, but opens its own transaction. */
export async function audit({ actorId, action, entityType, entityId, details, ipAddress }) {
  return withTransaction((client) =>
    writeAudit(client, { actorId, action, entityType, entityId, details, ipAddress }),
  );
}

export default { writeAudit, audit };
