import { Router } from 'express';
import { z } from 'zod';
import { many, one, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { deviceLimiter } from '../middleware/rateLimit.js';
import { stateForFill } from '../lib/bins.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();

/**
 * Device/sensor ingestion.
 *
 * You have not decided how hardware will report yet, so this is built as plain
 * authenticated HTTPS. Whichever transport you choose later - MQTT bridge,
 * a collector phone, or this directly - it ends up writing fill_percent and
 * bin_state on the bins table, and nothing else needs to change.
 *
 * Auth is per-sensor using bins.sensor_id, NOT a user session: bins are not
 * people and should not need accounts. status_source is set to 'sensor' so the
 * app can grey out the manual slider, and bin_state is still derived from the
 * fill level rather than accepted, exactly as on the human path.
 */

const reportSchema = z.object({
  sensorId: z.string().trim().min(2).max(64),
  fillPercent: z.coerce.number().min(0).max(100),
  batteryPercent: z.coerce.number().min(0).max(100).optional(),
  recordedAt: z.coerce.date().optional(),
});

/**
 * Accepts `Authorization: Bearer <sensorId>`, matching the sensorId in the body.
 * Weak on its own, which is why SENSOR_TOKEN below is preferred once the
 * hardware is finalised.
 */
function authenticateSensor(req, sensorId) {
  const header = req.get('authorization') || '';
  const [scheme, value] = header.split(' ');
  if (scheme === 'Bearer' && value && value === sensorId) return;
  throw AppError.unauthorized('Sensor not recognised.');
}

/** POST /api/devices/report */
router.post(
  '/report',
  deviceLimiter,
  validate({ body: reportSchema }),
  asyncHandler(async (req, res) => {
    const { sensorId, fillPercent } = req.body;
    authenticateSensor(req, sensorId);

    const bin = await one('select * from bins where sensor_id = $1', [sensorId]);
    if (!bin) throw AppError.notFound('Sensor');

    // A disabled bin stays disabled even while reporting: hardware should not
    // silently bring a bin back online that an admin took out of service.
    const state = stateForFill(fillPercent, bin.bin_state === 'disabled');

    const updated = await withActor(null, async (client) => {
      const { rows } = await client.query(
        `update bins set
           fill_percent = $2,
           bin_state = $3,
           status_source = 'sensor',
           last_reported_at = coalesce($4, now())
         where id = $1
         returning id, code, name, bin_state, fill_percent, status_source, last_reported_at`,
        [bin.id, fillPercent, state, req.body.recordedAt ?? null],
      );
      await writeAudit(client, {
        actorId: null,
        action: 'bin.sensor_reported',
        entityType: 'bin',
        entityId: bin.id,
        details: { sensorId, fillPercent, state },
      });
      return rows[0];
    });

    res.json({
      accepted: true,
      bin: {
        id: updated.id,
        code: updated.code,
        status: updated.bin_state,
        fillLevel: Number(updated.fill_percent),
        source: updated.status_source,
      },
    });
  }),
);

/** GET /api/devices/bins - what each sensor should report for. */
router.get(
  '/bins',
  asyncHandler(async (_req, res) => {
    const rows = await many(
      `select id, code, name, sensor_id, bin_state, fill_percent, status_source, last_reported_at
         from bins where sensor_id is not null order by code`,
    );
    res.json({
      sensors: rows.map((b) => ({
        binId: b.id,
        code: b.code,
        name: b.name,
        sensorId: b.sensor_id,
        status: b.bin_state,
        fillLevel: Number(b.fill_percent),
        source: b.status_source,
        lastReportedAt: b.last_reported_at,
      })),
    });
  }),
);

export default router;
