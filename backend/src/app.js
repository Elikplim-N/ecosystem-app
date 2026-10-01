import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import config from './config.js';
import { apiLimiter } from './middleware/rateLimit.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

import healthRoutes from './routes/health.routes.js';
import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/users.routes.js';
import binRoutes from './routes/bins.routes.js';
import rfidRoutes from './routes/rfid.routes.js';
import ambassadorRoutes from './routes/ambassador.routes.js';
import rewardRoutes from './routes/rewards.routes.js';
import adminRoutes from './routes/admin.routes.js';
import deviceRoutes from './routes/devices.routes.js';

/**
 * Every mounted router, in one place.
 *
 * Exported so scripts/list-routes.js can print real paths instead of guessing
 * them from Express's compiled regexps (which store paths escaped, so naive
 * substring matching silently loses every mount prefix).
 */
export const ROUTE_MODULES = [
  ['/health', healthRoutes],
  ['/api/auth', authRoutes],
  ['/api/users', userRoutes],
  ['/api/bins', binRoutes],
  ['/api/rfid', rfidRoutes],
  ['/api/ambassador', ambassadorRoutes],
  ['/api/rewards', rewardRoutes],
  ['/api/admin', adminRoutes],
  ['/api/devices', deviceRoutes],
];

export function createApp() {
  const app = express();

  // Behind nginx/Caddy on the server this must be 1, or express-rate-limit
  // sees every request as coming from the proxy and throttles all users at once.
  app.set('trust proxy', config.isProduction ? 1 : false);
  app.disable('x-powered-by');

  app.use(helmet());

  // Credentials are sent as a Bearer header, not a cookie, so
  // Access-Control-Allow-Credentials is not needed. Origins are listed
  // explicitly; '*' is never allowed because that would let any site call
  // this API with a stolen token.
  app.use(
    cors({
      origin(origin, callback) {
        if (!origin) return callback(null, true); // curl, native app, health checks
        if (config.corsOrigins.length === 0 && !config.isProduction) return callback(null, true);
        if (config.corsOrigins.includes(origin)) return callback(null, true);
        return callback(new Error(`Origin ${origin} is not allowed.`));
      },
      methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      maxAge: 86_400,
    }),
  );

  app.use(express.json({ limit: '256kb' }));

  app.use('/health', healthRoutes);
  app.use('/api', apiLimiter);

  for (const [prefix, router] of ROUTE_MODULES) {
    if (prefix === '/health') continue; // already mounted above
    app.use(prefix, router);
  }

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export default createApp;
