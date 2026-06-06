import { kv } from '@vercel/kv';

const CREDITS_PREFIX = 'credits:';
const TIER_PREFIX = 'tier:';
const RATE_LIMIT_PREFIX = 'ratelimit:';

type RateLimitEntry = {
  count: number;
  expiresAt: number;
};

const memoryCredits = new Map<string, number>();
const memoryTiers = new Map<string, string>();
const memoryRateLimits = new Map<string, RateLimitEntry>();

function isKVConfigured(): boolean {
  return Boolean(process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN);
}

async function withKV<T>(
  operation: () => Promise<T>,
  fallback: () => T | Promise<T>
): Promise<T> {
  if (!isKVConfigured()) {
    return fallback();
  }

  try {
    return await operation();
  } catch (error) {
    console.warn('KV unavailable, using in-memory fallback:', error);
    return fallback();
  }
}

export async function getCredits(receiptHash: string): Promise<number | null> {
  const key = `${CREDITS_PREFIX}${receiptHash}`;
  return withKV(
    () => kv.get<number>(key),
    () => memoryCredits.get(key) ?? null
  );
}

export async function setCredits(
  receiptHash: string,
  credits: number,
  tier: string
): Promise<void> {
  const creditsKey = `${CREDITS_PREFIX}${receiptHash}`;
  const tierKey = `${TIER_PREFIX}${receiptHash}`;
  await withKV(
    async () => {
      await kv.set(creditsKey, credits);
      await kv.set(tierKey, tier);
    },
    () => {
      memoryCredits.set(creditsKey, credits);
      memoryTiers.set(tierKey, tier);
    }
  );
}

export async function decrementCredits(receiptHash: string): Promise<number> {
  const key = `${CREDITS_PREFIX}${receiptHash}`;
  return withKV(
    async () => {
      const credits = await kv.get<number>(key);

      if (credits === null || credits <= 0) {
        return 0;
      }

      return kv.decr(key);
    },
    () => {
      const credits = memoryCredits.get(key);

      if (credits === undefined || credits <= 0) {
        return 0;
      }

      const nextCredits = credits - 1;
      memoryCredits.set(key, nextCredits);
      return nextCredits;
    }
  );
}

export async function getTier(receiptHash: string): Promise<string | null> {
  const key = `${TIER_PREFIX}${receiptHash}`;
  return withKV(
    () => kv.get<string>(key),
    () => memoryTiers.get(key) ?? null
  );
}

export async function checkRateLimit(
  receiptHash: string,
  limit: number = 10,
  windowSeconds: number = 60
): Promise<boolean> {
  const key = `${RATE_LIMIT_PREFIX}${receiptHash}`;
  return withKV(
    async () => {
      const current = await kv.get<number>(key);

      if (current === null) {
        await kv.set(key, 1, { ex: windowSeconds });
        return true;
      }

      if (current >= limit) {
        return false;
      }

      await kv.incr(key);
      return true;
    },
    () => {
      const now = Date.now();
      const current = memoryRateLimits.get(key);

      if (!current || current.expiresAt <= now) {
        memoryRateLimits.set(key, { count: 1, expiresAt: now + windowSeconds * 1000 });
        return true;
      }

      if (current.count >= limit) {
        return false;
      }

      current.count += 1;
      memoryRateLimits.set(key, current);
      return true;
    }
  );
}

export async function getAllCreditKeys(): Promise<string[]> {
  return withKV(
    () => kv.keys(`${CREDITS_PREFIX}*`),
    () => Array.from(memoryCredits.keys())
  );
}

export async function deleteCreditKey(receiptHash: string): Promise<void> {
  const creditsKey = `${CREDITS_PREFIX}${receiptHash}`;
  const tierKey = `${TIER_PREFIX}${receiptHash}`;
  await withKV(
    async () => {
      await kv.del(creditsKey);
      await kv.del(tierKey);
    },
    () => {
      memoryCredits.delete(creditsKey);
      memoryTiers.delete(tierKey);
    }
  );
}
