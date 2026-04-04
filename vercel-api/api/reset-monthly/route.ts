import { NextRequest, NextResponse } from 'next/server';
import { getAllCreditKeys, deleteCreditKey } from '../../lib/redis';

export async function POST(request: NextRequest) {
  try {
    // Verify this is a Vercel Cron request
    const authHeader = request.headers.get('Authorization');
    const cronSecret = process.env.CRON_SECRET;

    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Get all credit keys
    const keys = await getAllCreditKeys();

    let deletedCount = 0;
    for (const key of keys) {
      // Extract receipt hash from key (format: credits:{hash})
      const receiptHash = key.replace('credits:', '');
      await deleteCreditKey(receiptHash);
      deletedCount++;
    }

    return NextResponse.json({
      success: true,
      message: `Reset monthly credits`,
      deletedCount,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Reset monthly error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Vercel Cron requires GET method as well
export async function GET(request: NextRequest) {
  return POST(request);
}
