import crypto from 'crypto';
import { readFileSync } from 'fs';
import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';

export type AuthorizedTier = 'free' | 'testflight';

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

type HeaderReader = Pick<Headers, 'get'>;

export async function verifyStoreAuthorization(headers: HeaderReader): Promise<StoreAuthorization> {
  const appJWS = headers.get('X-App-Transaction-JWS');
  if (!appJWS) {
    throw new StoreAuthorizationError('Missing App Store authorization');
  }

  const verifiedApp = await verifyAppTransaction(appJWS);
  const appTransactionId = verifiedApp.appTransactionId;
  if (!appTransactionId) {
    throw new StoreAuthorizationError('App transaction has no stable identifier');
  }

  return {
    userId: stableUserId(appTransactionId),
    tier: verifiedApp.environment === Environment.SANDBOX ? 'testflight' : 'free',
    environment: verifiedApp.environment,
    appTransactionId,
  };
}

async function verifyAppTransaction(jws: string) {
  try {
    const payload = await sandboxVerifier.verifyAndDecodeAppTransaction(jws);
    return { appTransactionId: payload.appTransactionId, environment: Environment.SANDBOX };
  } catch {
    try {
      const payload = await productionVerifier.verifyAndDecodeAppTransaction(jws);
      return { appTransactionId: payload.appTransactionId, environment: Environment.PRODUCTION };
    } catch {
      throw new StoreAuthorizationError('Invalid App Store authorization');
    }
  }
}

function stableUserId(appTransactionId: string): string {
  return crypto
    .createHash('sha256')
    .update(`${EXPECTED_BUNDLE_ID}:${appTransactionId}`)
    .digest('hex');
}
