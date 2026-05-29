import { NextRequest, NextResponse } from 'next/server';
import { getCredits, setCredits, getTier } from '../../lib/redis';

export async function POST(request: NextRequest) {
  try {
    const cloudKitToken = request.headers.get('X-CloudKit-Token');

    if (!cloudKitToken) {
      return NextResponse.json(
        { error: 'Missing CloudKit token' },
        { status: 401 }
      );
    }

    // Verify CloudKit JWT (placeholder - implement proper JWT verification)
    const isValidToken = await verifyCloudKitToken(cloudKitToken);
    if (!isValidToken) {
      return NextResponse.json(
        { error: 'Invalid CloudKit token' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { receiptHash, cloudKitCredits, tier } = body;

    if (!receiptHash || typeof cloudKitCredits !== 'number' || !tier) {
      return NextResponse.json(
        { error: 'Missing required fields: receiptHash, cloudKitCredits, tier' },
        { status: 400 }
      );
    }

    // Get current Redis credits
    const redisCredits = await getCredits(receiptHash);
    const redisTier = await getTier(receiptHash);

    // Anti-cheat: take the more restrictive value
    // If CloudKit says 5 and Redis says 10, use 5 (user might have upgraded on another device)
    // If Redis says 0 and CloudKit says 5, use 0 (wait for sync from other device)
    const officialCredits = Math.min(cloudKitCredits, redisCredits ?? cloudKitCredits);
    const officialTier = tier || redisTier || 'free';

    // Update Redis with official values
    await setCredits(receiptHash, officialCredits, officialTier);

    return NextResponse.json({
      success: true,
      credits: officialCredits,
      tier: officialTier,
      source: 'synced',
    });

  } catch (error) {
    console.error('Sync credits error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

async function verifyCloudKitToken(token: string): Promise<boolean> {
  const configuredSecret = process.env.CLOUDKIT_SYNC_SECRET;

  if (process.env.NODE_ENV === 'development') {
    return token.length > 0 && (!configuredSecret || token === configuredSecret);
  }

  if (!configuredSecret) {
    return false;
  }

  return token === configuredSecret;
}
