import { Router } from 'express';
import { one } from '../db.js';
import asyncHandler from '../lib/asyncHandler.js';

const router = Router();

/**
 * GET /health - unauthenticated, for uptime checks and load balancers.
 * Deliberately cheap: one round trip, no auth, no user data.
 */
router.get(
  '/',
  asyncHandler(async (_req, res) => {
    const started = Date.now();
    const row = await one('select version() as version, current_database() as db');
    res.json({
      ok: true,
      service: 'ecosystem-api',
      database: { connected: true, name: row.db, latencyMs: Date.now() - started },
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  }),
);

export default router;
