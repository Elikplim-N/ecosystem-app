import { Router } from 'express';
import { z } from 'zod';
import { many, one, withActor } from '../db.js';
import { AppError } from '../errors.js';
import { validate } from '../lib/validate.js';
import asyncHandler from '../lib/asyncHandler.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { assertCanEditBin, stateForFill } from '../lib/bins.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();
router.use(requireAuth());

const uuid = z.string().uuid('Must be a valid id.');

const createSchema = z.object({
  name: z.string().trim().min(2, 'Give the bin a name.').max(120),
  code: z.string().trim().max(32).optional(),
  address: z.string().trim().max(240).optional(),
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  capacityKg: z.coerce.number().positive().max(100_000).optional(),
  sensorId: z.string().trim().max(64).optional(),
  fillPercent: z.coerce.number().min(0).max(100).optional(),
  rejectedFillPercent: z.coerce.number().min(0).max(100).optional(),
  collects: z.string().trim().min(2).max(60).optional(),
  notes: z.string().trim().max(1000).optional(),
});

const updateSchema = createSchema.partial().extend({
  disabled: z.boolean().optional(),
});

const listSchema = z.object({
  state: z.enum(['available', 'filling', 'full', 'disabled']).optional(),
  mine: z.coerce.boolean().optional(),
  search: z.string().trim().max(80).optional(),
  hasSensor: z.coerce.boolean().optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
  offset: z.coerce.number().int().min(0).default(0),
});

const statusSchema = z.object({
  fillPercent: z.coerce.number().min(0).max(100).optional(),
  rejectedFillPercent: z.coerce.number().min(0).max(100).optional(),
  disabled: z.boolean().optional(),
  note: z.string().trim().max(500).optional(),
});

const collectSchema = z.object({
  weightKg: z.coerce.number().min(0).max(100_000),
  isEstimated: z.boolean().default(false),
  notes: z.string().trim().max(500).optional(),
});

/** Serialise a bin row for the app. */
function present(b) {
  return {
    id: b.id,
    code: b.code,
    name: b.name,
    status: b.bin_state,
    fillLevel: Number(b.fill_percent),
    rejectedFillLevel: Number(b.rejected_fill_percent ?? 0),
    collects: b.collects ?? 'Plastic',
    capacityKg: Number(b.capacity_kg),
    address: b.address ?? null,
    latitude: b.latitude === null ? null : Number(b.latitude),
    longitude: b.longitude === null ? null : Number(b.longitude),
    hasSensor: b.sensor_id !== null,
    sensorId: b.sensor_id,
    notes: b.notes ?? null,
    createdById: b.created_by_id,
    createdByRole: b.created_by_role,
    createdByName: b.created_by_name,
    lastCollectedAt: b.last_collected_at,
    lastReportedAt: b.last_reported_at,
    updatedAt: b.updated_at,
  };
}

const SELECT_BIN = `
  select b.*, u.name as created_by_name
    from bins b
    left join users u on u.id = b.created_by_id`;

async function loadBin(id) {
  const bin = await one(`${SELECT_BIN} where b.id = $1`, [id]);
  if (!bin) throw AppError.notFound('Bin');
  return bin;
}

/** GET /api/bins - honours ownership for ambassadors. */
router.get(
  '/',
  validate({ query: listSchema }),
  asyncHandler(async (req, res) => {
    const { state, mine, search, hasSensor, limit, offset } = req.query;
    const where = [];
    const params = [];

    if (state) {
      params.push(state);
      where.push(`b.bin_state = $${params.length}`);
    }
    if (hasSensor !== undefined) {
      params.push(hasSensor);
      where.push(`b.sensor_id is ${hasSensor ? 'not' : ''} null`);
    }
    if (search) {
      params.push(`%${search}%`);
      where.push(`(b.name ilike $${params.length} or b.code ilike $${params.length} or coalesce(b.address,'') ilike $${params.length})`);
    }
    if (mine) {
      if (req.user.role_id === 'admin') {
        // "My bins" is meaningless for an admin; treat it as everything.
      } else if (req.user.role_id === 'ambassador') {
        params.push(req.user.id);
        where.push(`b.created_by_id = $${params.length}`);
      } else {
        throw AppError.forbidden('Only ambassadors have their own bins.');
      }
    }

    const rows = await many(
      `${SELECT_BIN}
       ${where.length ? `where ${where.join(' and ')}` : ''}
       order by b.bin_state = 'full' desc, b.code
       limit $${params.length + 1} offset $${params.length + 2}`,
      [...params, limit, offset],
    );

    res.json({ bins: rows.map(present) });
  }),
);

/** GET /api/bins/summary */
router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    // Admins see every bin; ambassadors see all bins but also how many are
    // theirs. Both branches keep $1 bound so the same SQL shape is used.
    const rows = await many(
      `select
         b.bin_state,
         count(*)::int as total,
         count(*) filter (where b.created_by_id = $1)::int as mine,
         count(*) filter (where b.rejected_fill_percent >= 90
                            and b.bin_state <> 'disabled')::int as rejected_full,
         count(*) filter (where b.sensor_id is not null)::int as with_sensor
       from bins b
       ${req.user.role_id === 'admin' ? '' : 'where b.created_by_id = $1'}
       group by b.bin_state`,
      [req.user.id],
    );

    const summary = { total: 0, mine_total: 0, rejected_full: 0, with_sensor: 0 };
    for (const state of ['available', 'filling', 'full', 'disabled']) {
      summary[state] = 0;
      summary[`${state}_mine`] = 0;
    }
    for (const r of rows) {
      summary[r.bin_state] = r.total;
      summary[`${r.bin_state}_mine`] = r.mine;
      summary.total += r.total;
      summary.mine_total += r.mine;
      summary.rejected_full += r.rejected_full;
      summary.with_sensor += r.with_sensor;
    }
    res.json({ summary });
  }),
);

/** GET /api/bins/map - bins with coordinates, for the map screen. */
router.get(
  '/map',
  asyncHandler(async (_req, res) => {
    const rows = await many(
      `${SELECT_BIN}
       where b.latitude is not null
       order by b.code`,
    );
    res.json({ bins: rows.map(present) });
  }),
);

/** GET /api/bins/:id */
router.get(
  '/:id',
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    res.json({ bin: present(await loadBin(req.params.id)) });
  }),
);

/** POST /api/bins - admin or ambassador. */
router.post(
  '/',
  requireRole('admin', 'ambassador'),
  validate({ body: createSchema }),
  asyncHandler(async (req, res) => {
    const b = req.body;

    // The database enforces lat/lon pairing, but failing here gives a better
    // message than a 23514 constraint violation.
    if ((b.latitude === undefined) !== (b.longitude === undefined)) {
      throw AppError.validation('Some fields need attention.', [
        { field: 'body.latitude', message: 'Provide latitude and longitude together.' },
        { field: 'body.longitude', message: 'Provide latitude and longitude together.' },
      ]);
    }

    const created = await withActor(req.user.id, async (client) => {
      const code = b.code ?? (await client.query('select next_bin_code() as code')).rows[0].code;
      const fill = b.fillPercent ?? 0;

      const { rows } = await client.query(
        `insert into bins (code, name, address, latitude, longitude, capacity_kg,
                           sensor_id, fill_percent, rejected_fill_percent, collects,
                           bin_state, status_source, created_by_id, created_by_role, notes)
         values ($1,$2,$3,$4,$5,coalesce($6,50),$7,$8,$9,coalesce($10,'Plastic'),$11,'manual',$12,$13,$14)
         returning id`,
        [
          code, b.name, b.address ?? null, b.latitude ?? null, b.longitude ?? null,
          b.capacityKg ?? null, b.sensorId ?? null, fill, b.rejectedFillPercent ?? 0,
          b.collects ?? null, stateForFill(fill), req.user.id,
          req.user.role_id, b.notes ?? null,
        ],
      );
      const id = rows[0].id;

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'bin.created',
        entityType: 'bin',
        entityId: id,
        details: { code, name: b.name },
      });

      return id;
    });

    res.status(201).json({ bin: present(await loadBin(created)) });
  }),
);

/** PATCH /api/bins/:id - owner or admin. */
router.patch(
  '/:id',
  validate({ params: z.object({ id: uuid }), body: updateSchema }),
  asyncHandler(async (req, res) => {
    const bin = await loadBin(req.params.id);
    assertCanEditBin(req.user, bin);

    const b = req.body;

    if ((b.latitude === undefined && b.longitude !== undefined) ||
        (b.latitude !== undefined && b.longitude === undefined)) {
      throw AppError.validation('Some fields need attention.', [
        { field: 'body.longitude', message: 'Provide latitude and longitude together.' },
      ]);
    }

    // Recomputing state on any edit keeps bin_state consistent with the fields,
    // unless the caller is explicitly enabling/disabling.
    const fill = b.fillPercent ?? Number(bin.fill_percent);
    const disabled = b.disabled ?? bin.bin_state === 'disabled';
    const state = stateForFill(fill, disabled);

    await withActor(req.user.id, async (client) => {
      await client.query(
        `update bins set
           name = coalesce($2, name),
           address = coalesce($3, address),
           latitude = coalesce($4, latitude),
           longitude = coalesce($5, longitude),
           capacity_kg = coalesce($6, capacity_kg),
           sensor_id = coalesce($7, sensor_id),
           notes = coalesce($8, notes),
           collects = coalesce($9, collects),
           rejected_fill_percent = coalesce($10, rejected_fill_percent),
           fill_percent = $11,
           bin_state = $12,
           status_source = 'manual',
           disabled_at = case when $12 = 'disabled' then now() else null end,
           last_reported_at = now()
         where id = $1`,
        [
          bin.id, b.name ?? null, b.address ?? null, b.latitude ?? null, b.longitude ?? null,
          b.capacityKg ?? null, b.sensorId ?? null, b.notes ?? null, b.collects ?? null,
          b.rejectedFillPercent ?? null, fill, state,
        ],
      );

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'bin.updated',
        entityType: 'bin',
        entityId: bin.id,
        details: { fields: Object.keys(b), state },
      });
    });

    res.json({ bin: present(await loadBin(bin.id)) });
  }),
);

/**
 * POST /api/bins/:id/status - the path sensors and manual reporting share.
 *
 * bin_state is derived from fill_percent here, never accepted from the
 * client, so the two can never disagree.
 */
router.post(
  '/:id/status',
  validate({ params: z.object({ id: uuid }), body: statusSchema }),
  asyncHandler(async (req, res) => {
    const bin = await loadBin(req.params.id);
    assertCanEditBin(req.user, bin);

    const disabled = req.body.disabled ?? bin.bin_state === 'disabled';
    // Either compartment may be reported on its own, so fall back to what the
    // bin already holds rather than resetting the other level to zero.
    const fill = req.body.fillPercent ?? Number(bin.fill_percent);
    const rejectedFill = req.body.rejectedFillPercent ?? Number(bin.rejected_fill_percent ?? 0);
    const state = stateForFill(fill, disabled);

    await withActor(req.user.id, async (client) => {
      await client.query(
        `update bins set
           fill_percent = $2,
           rejected_fill_percent = $3,
           bin_state = $4,
           status_source = 'manual',
           disabled_at = case when $4 = 'disabled' then now() else null end,
           last_reported_at = now()
         where id = $1`,
        [bin.id, fill, rejectedFill, state],
      );

      if (req.body.note) {
        await client.query(
          `insert into bin_status_events (bin_id, new_state, fill_percent, source, reported_by_id, note)
           values ($1, $2, $3, 'manual', $4, $5)`,
          [bin.id, state, fill, req.user.id, req.body.note],
        );
      }

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'bin.status_changed',
        entityType: 'bin',
        entityId: bin.id,
        details: { from: bin.bin_state, to: state, fill: req.body.fillPercent },
      });
    });

    res.json({ bin: present(await loadBin(bin.id)) });
  }),
);

/**
 * POST /api/bins/:id/collect - records a truck collection.
 *
 * Without this, "collected" only reset a number and nothing recorded who took
 * what, which makes any reporting on recycling volume impossible.
 */
router.post(
  '/:id/collect',
  validate({ params: z.object({ id: uuid }), body: collectSchema }),
  asyncHandler(async (req, res) => {
    const bin = await loadBin(req.params.id);
    assertCanEditBin(req.user, bin);

    const collectionId = await withActor(req.user.id, async (client) => {
      const { rows } = await client.query(
        `insert into collections (bin_id, collected_by_id, weight_kg, is_estimated, notes)
         values ($1, $2, $3, $4, $5) returning id`,
        [bin.id, req.user.id, req.body.weightKg, req.body.isEstimated, req.body.notes ?? null],
      );

      await client.query(
        `update bins set
           fill_percent = 0,
           rejected_fill_percent = 0,
           bin_state = 'available',
           status_source = 'manual',
           last_collected_at = now(),
           last_reported_at = now()
         where id = $1`,
        [bin.id],
      );

      await writeAudit(client, {
        actorId: req.user.id,
        action: 'bin.collected',
        entityType: 'bin',
        entityId: bin.id,
        details: { weightKg: req.body.weightKg, estimated: req.body.isEstimated },
      });

      return rows[0].id;
    });

    res.status(201).json({
      collection: { id: collectionId },
      bin: present(await loadBin(bin.id)),
    });
  }),
);

/** GET /api/bins/:id/history - the audit trail for one bin. */
router.get(
  '/:id/history',
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    await loadBin(req.params.id);
    const rows = await many(
      `select e.previous_state, e.new_state, e.fill_percent, e.source,
              e.note, e.created_at, u.name as reported_by
         from bin_status_events e
         left join users u on u.id = e.reported_by_id
        where e.bin_id = $1
        order by e.created_at desc, e.id desc
        limit 100`,
      [req.params.id],
    );
    res.json({
      history: rows.map((r) => ({
        from: r.previous_state,
        to: r.new_state,
        fillLevel: r.fill_percent === null ? null : Number(r.fill_percent),
        source: r.source,
        note: r.note,
        reportedBy: r.reported_by,
        at: r.created_at,
      })),
    });
  }),
);

/** DELETE /api/bins/:id - admin only. */
router.delete(
  '/:id',
  requireRole('admin'),
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    const bin = await loadBin(req.params.id);
    await withActor(req.user.id, async (client) => {
      // ON DELETE CASCADE clears status history and collections, which is
      // intended: deleting a bin is destructive and only an admin can do it.
      await client.query('delete from bins where id = $1', [bin.id]);
      await writeAudit(client, {
        actorId: req.user.id,
        action: 'bin.deleted',
        entityType: 'bin',
        entityId: bin.id,
        details: { code: bin.code, name: bin.name },
      });
    });
    res.json({ ok: true });
  }),
);

/** Convenience for admin dashboards. */
router.post(
  '/:id/toggle',
  requireRole('admin', 'ambassador'),
  validate({ params: z.object({ id: uuid }) }),
  asyncHandler(async (req, res) => {
    const bin = await loadBin(req.params.id);
    assertCanEditBin(req.user, bin);

    const disabling = bin.bin_state !== 'disabled';
    const state = disabling ? 'disabled' : stateForFill(Number(bin.fill_percent));

    await withActor(req.user.id, async (client) => {
      await client.query(
        `update bins set bin_state = $2, disabled_at = case when $2 = 'disabled' then now() else null end
          where id = $1`,
        [bin.id, state],
      );
      await writeAudit(client, {
        actorId: req.user.id,
        action: disabling ? 'bin.disabled' : 'bin.enabled',
        entityType: 'bin',
        entityId: bin.id,
      });
    });

    res.json({ bin: present(await loadBin(bin.id)) });
  }),
);

export default router;
