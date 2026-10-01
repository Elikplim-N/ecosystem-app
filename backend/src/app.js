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
import notificationRoutes from './routes/notifications.routes.js';
import contactRoutes from './routes/contact.routes.js';

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
  ['/api/notifications', notificationRoutes],
  // The contact form. Deliberately not session-gated - see the route module.
  ['/api/contact', contactRoutes],
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
  //
  // `flutter run -d chrome` picks a random port every launch, so pinning one
  // port in CORS_ORIGINS makes the web build fail with a confusing preflight
  // error. In development we therefore accept any loopback port. That is still
  // same-machine only - a request from another host is rejected below.
  const isLoopback = (url) => /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(url);

  app.use(
    cors({
      origin(origin, callback) {
        if (!origin) return callback(null, true); // curl, native app, health checks
        if (!config.isProduction && isLoopback(origin)) return callback(null, true);
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
