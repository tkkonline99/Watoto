import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url().default('postgresql://watoto:watoto@localhost:5432/watoto?schema=public'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  JWT_SECRET: z.string().min(8).default('dev-secret-change-me'),
  JWT_ACCESS_TTL: z.coerce.number().int().positive().default(900),
  FIREBASE_SA_B64: z.string().optional().default(''),
});

export interface AppConfig {
  nodeEnv: 'development' | 'test' | 'staging' | 'production';
  port: number;
  databaseUrl: string;
  redisUrl: string;
  jwtSecret: string;
  jwtAccessTtl: number;
  firebaseSaB64: string;
}

let cached: AppConfig | undefined;

/** Validates process.env once and fails fast on bad configuration. */
export function loadConfig(): AppConfig {
  if (cached) return cached;
  const parsed = envSchema.parse(process.env);
  if (parsed.NODE_ENV === 'production' && parsed.JWT_SECRET === 'dev-secret-change-me') {
    throw new Error('JWT_SECRET must be set in production');
  }
  cached = {
    nodeEnv: parsed.NODE_ENV,
    port: parsed.PORT,
    databaseUrl: parsed.DATABASE_URL,
    redisUrl: parsed.REDIS_URL,
    jwtSecret: parsed.JWT_SECRET,
    jwtAccessTtl: parsed.JWT_ACCESS_TTL,
    firebaseSaB64: parsed.FIREBASE_SA_B64,
  };
  return cached;
}

/** Test seam: clears the memoized config. */
export function resetConfigForTests(): void {
  cached = undefined;
}
