import crypto from 'crypto';
import { readFileSync } from 'fs';
import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
} from '@apple/app-store-server-library';

export type ReceiptTier = 'free' | 'premium' | 'pro' | 'lifetime';
export type AuthorizedTier = ReceiptTier | 'testflight';

export interface StoreAuthorization {
  userId: string;
  tier: AuthorizedTier;
  environment: Environment;
  appTransactionId: string;
}

export class StoreAuthorizationError extends Error {
  constructor(message: string, readonly status: number = 401) {
    super(message);
  }
}

const EXPECTED_BUNDLE_ID = process.env.APP_BUNDLE_ID || 'com.personalshooper.app';
const APP_APPLE_ID = Number(process.env.APP_APPLE_ID || '6774502051');
const ROOT_CERTIFICATES = [
  'AppleIncRootCertificate.cer',
  'AppleRootCA-G2.cer',
  'AppleRootCA-G3.cer',
].map(name => readFileSync(new URL(`../certs/${name}`, import.meta.url)));

const ENABLE_ONLINE_CHECKS = process.env.APPLE_ENABLE_ONLINE_CHECKS !== 'false';
const sandboxVerifier = new SignedDataVerifier(
  ROOT_CERTIFICATES,
  ENABLE_ONLINE_CHECKS,
  Environment.SANDBOX,
  EXPECTED_BUNDLE_ID
);
const productionVerifier = new SignedDataVerifier(
  ROOT_CERTIFICATES,
  ENABLE_ONLINE_CHECKS,
  Environment.PRODUCTION,
  EXPECTED_BUNDLE_ID,
  APP_APPLE_ID
);

const TIER_MAP: Record<string, ReceiptTier> = {
  'com.personalshooper.free': 'free',
  'com.personalshooper.premium.monthly': 'premium',
  'com.personalshooper.pro.monthly': 'pro',
  'com.personalshooper.lifetime': 'lifetime',
};

const CREDITS_MAP: Record<ReceiptTier, number> = {
  free: 5,
  premium: 50,
  pro: 200,
  lifetime: 100,
};

type HeaderReader = Pick<Headers, 'get'>;

export function getCreditsForTier(tier: ReceiptTier): number {
  return CREDITS_MAP[tier];
}

export async function verifyStoreAuthorization(headers: HeaderReader): Promise<StoreAuthorization> {
  const appJWS = headers.get('X-App-Transaction-JWS');
  if (!appJWS) {
    throw new StoreAuthorizationError('Missing App Store authorization');
  }

  const verifiedApp = await verifyAppTransaction(appJWS);
  const appTransactionId = verifiedApp.payload.appTransactionId;
  if (!appTransactionId) {
    throw new StoreAuthorizationError('App transaction has no stable identifier');
  }

  let tier: AuthorizedTier = verifiedApp.environment === Environment.SANDBOX
    ? 'testflight'
    : 'free';

  const entitlementJWS = headers.get('X-Entitlement-JWS');
  if (entitlementJWS && verifiedApp.environment === Environment.PRODUCTION) {
    const transaction = await verifiedApp.verifier.verifyAndDecodeTransaction(entitlementJWS);
    validateEntitlement(transaction, appTransactionId);
    tier = tierForTransaction(transaction);
  }

  return {
    userId: stableUserId(appTransactionId),
    tier,
    environment: verifiedApp.environment,
    appTransactionId,
  };
}

async function verifyAppTransaction(jws: string) {
  try {
    const payload = await sandboxVerifier.verifyAndDecodeAppTransaction(jws);
    return { payload, environment: Environment.SANDBOX, verifier: sandboxVerifier };
  } catch {
    try {
      const payload = await productionVerifier.verifyAndDecodeAppTransaction(jws);
      return { payload, environment: Environment.PRODUCTION, verifier: productionVerifier };
    } catch {
      throw new StoreAuthorizationError('Invalid App Store authorization');
    }
  }
}

function validateEntitlement(transaction: JWSTransactionDecodedPayload, appTransactionId: string): void {
  if (transaction.appTransactionId && transaction.appTransactionId !== appTransactionId) {
    throw new StoreAuthorizationError('Entitlement belongs to another app transaction');
  }
  if (transaction.revocationDate) {
    throw new StoreAuthorizationError('Entitlement was revoked');
  }
  if (transaction.expiresDate && transaction.expiresDate <= Date.now()) {
    throw new StoreAuthorizationError('Entitlement has expired');
  }
}

function tierForTransaction(transaction: JWSTransactionDecodedPayload): ReceiptTier {
  return transaction.productId ? TIER_MAP[transaction.productId] ?? 'free' : 'free';
}

function stableUserId(appTransactionId: string): string {
  return crypto
    .createHash('sha256')
    .update(`${EXPECTED_BUNDLE_ID}:${appTransactionId}`)
    .digest('hex');
}
