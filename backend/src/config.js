import 'dotenv/config';
import { z } from 'zod';

/**
 * Environment is validated once, at import time, so a misconfigured server
 * fails immediately and loudly rather than at 3am when a login is attempted.
 */

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  DB_POOL_MAX: z.coerce.number().int().positive().max(100).default(10),
  DB_SSL: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),

  JWT_SECRET: z
    .string()
    .min(32, 'JWT_SECRET must be at least 32 characters. Generate one with: openssl rand -hex 32'),
  ACCESS_TOKEN_TTL_MIN: z.coerce.number().int().positive().default(15),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),

  CORS_ORIGINS: z
    .string()
    .default('')
    .transform((v) =>
      v
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
    ),

  // Used to build links in password-reset messages.
  APP_BASE_URL: z.string().url().default('http://localhost:3000'),

  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error', 'silent']).default('info'),

  // Argon2id cost parameters. OWASP's second recommended option; the memory
  // cost is what makes offline cracking expensive.
  ARGON2_MEMORY_COST: z.coerce.number().int().min(8192).default(19456),
  ARGON2_TIME_COST: z.coerce.number().int().min(1).default(2),
  ARGON2_PARALLELISM: z.coerce.number().int().min(1).max(16).default(1),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
    .join('\n');
  console.error(`\nInvalid environment configuration:\n${issues}\n`);
  console.error('Copy .env.example to .env and fill it in.\n');
  process.exit(1);
}

const env = parsed.data;

if (env.NODE_ENV === 'production') {
  if (env.CORS_ORIGINS.length === 0) {
    console.error('CORS_ORIGINS must list your allowed origins in production.\n');
    process.exit(1);
  }
  if (!env.DB_SSL) {
    console.error('DB_SSL must be true in production. The connection must be encrypted.\n');
    process.exit(1);
  }
  if (env.JWT_SECRET.includes('replace_me')) {
    console.error('JWT_SECRET still has its placeholder value.\n');
    process.exit(1);
  }
}

export const config = {
  env: env.NODE_ENV,
  isProduction: env.NODE_ENV === 'production',
  port: env.PORT,
  logLevel: env.LOG_LEVEL,

  db: {
    url: env.DATABASE_URL,
    poolMax: env.DB_POOL_MAX,
    ssl: env.DB_SSL,
  },

  auth: {
    jwtSecret: env.JWT_SECRET,
    accessTtlMin: env.ACCESS_TOKEN_TTL_MIN,
    refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
    argon2: {
      memoryCost: env.ARGON2_MEMORY_COST,
      timeCost: env.ARGON2_TIME_COST,
      parallelism: env.ARGON2_PARALLELISM,
    },
  },

  corsOrigins: env.CORS_ORIGINS,

  // Where the app lives, so links in outbound messages point somewhere real.
  appBaseUrl: env.APP_BASE_URL,
};

export default config;
