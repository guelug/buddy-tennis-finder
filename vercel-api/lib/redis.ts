import { kv } from '@vercel/kv';

const CREDITS_PREFIX = 'credits:';
const TIER_PREFIX = 'tier:';
const RATE_LIMIT_PREFIX = 'ratelimit:';

export async function getCredits(receiptHash: string): Promise<number | null> {
  const credits = await kv.get<number>(`${CREDITS_PREFIX}${receiptHash}`);
  return credits;
}

export async function setCredits(
  receiptHash: string,
  credits: number,
  tier: string
): Promise<void> {
  await kv.set(`${CREDITS_PREFIX}${receiptHash}`, credits);
  await kv.set(`${TIER_PREFIX}${receiptHash}`, tier);
}

export async function decrementCredits(receiptHash: string): Promise<number> {
  const key = `${CREDITS_PREFIX}${receiptHash}`;
  const credits = await kv.get<number>(key);

  if (credits === null || credits <= 0) {
    return 0;
  }

  const newCredits = await kv.decr(key);
  return newCredits;
}

export async function getTier(receiptHash: string): Promise<string | null> {
  const tier = await kv.get<string>(`${TIER_PREFIX}${receiptHash}`);
  return tier;
}

export async function checkRateLimit(
  receiptHash: string,
  limit: number = 10,
  windowSeconds: number = 60
): Promise<boolean> {
  const key = `${RATE_LIMIT_PREFIX}${receiptHash}`;
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
}

export async function getAllCreditKeys(): Promise<string[]> {
  const keys = await kv.keys(`${CREDITS_PREFIX}*`);
  return keys;
}

export async function deleteCreditKey(receiptHash: string): Promise<void> {
  await kv.del(`${CREDITS_PREFIX}${receiptHash}`);
  await kv.del(`${TIER_PREFIX}${receiptHash}`);
}
