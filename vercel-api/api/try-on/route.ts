import { NextRequest, NextResponse } from 'next/server.js';
import { verifyReceipt, hashReceipt, getCreditsForTier } from '../../lib/apple.js';
import { getCredits, decrementCredits, getTier, checkRateLimit } from '../../lib/redis.js';
import { generateTryOn } from '../../lib/gemini.js';
import { generateTryOnWithOpenRouter } from '../../lib/openrouter.js';
import { assertTestSecret, checkAndConsumeQuota, refundQuota } from '../../lib/quota.js';

const RATE_LIMIT = 10;
const RATE_WINDOW = 60;

export async function POST(request: NextRequest) {
  try {
    const receiptData = request.headers.get('X-Receipt-Data');
    const testMode = request.headers.get('X-Test-Mode') === 'true';
    const testSecret = request.headers.get('X-Test-Secret');
    const testUser = request.headers.get('X-User-ID') || 'testflight';

    if (!receiptData) {
      return NextResponse.json(
        { error: 'Missing receipt data' },
        { status: 400 }
      );
    }

    const formData = await request.formData();
    const clothingImageFile = formData.get('clothingImage') as File | null;
    const personImageFile = formData.get('personImage') as File | null;

    if (!clothingImageFile || !personImageFile) {
      return NextResponse.json(
        { error: 'Missing required images' },
        { status: 400 }
      );
    }

    const clothingBuffer = Buffer.from(await clothingImageFile.arrayBuffer());
    const personBuffer = Buffer.from(await personImageFile.arrayBuffer());

    // TestFlight mode uses a server-side secret and quota. It should never be unlimited in prod.
    if (testMode) {
      if (!assertTestSecret(testSecret)) {
        return NextResponse.json({ error: 'Invalid TestFlight secret' }, { status: 401 });
      }

      const quota = await checkAndConsumeQuota(testUser, 'testflight', 'try_on');
      if (!quota.allowed) {
        return NextResponse.json({
          error: 'Quota exceeded',
          resetAt: quota.resetAt,
          window: quota.window,
          tier: quota.tier,
        }, { status: 429 });
      }

      try {
        const resultImage = await generateTryOnImage(clothingBuffer, personBuffer);
        return NextResponse.json({
          success: true,
          imageUrl: resultImage.toString('base64'),
          creditsRemaining: quota.remaining.monthly ?? quota.remaining.daily ?? 0,
          tier: 'testflight',
          mode: 'test',
        });
      } catch (error) {
        await refundQuota(testUser, 'try_on');
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        if (errorMessage === 'INVALID_API_KEY') {
          return NextResponse.json({ error: 'API key invalid' }, { status: 401 });
        }
        if (errorMessage === 'RATE_LIMIT_EXCEEDED') {
          return NextResponse.json({ error: 'Rate limit exceeded' }, { status: 429 });
        }
        return NextResponse.json({ error: errorMessage }, { status: 500 });
      }
    }

    // Verify receipt
    const receipt = await verifyReceipt(receiptData);
    if (!receipt) {
      return NextResponse.json(
        { error: 'Invalid receipt' },
        { status: 401 }
      );
    }

    const receiptHash = hashReceipt(receiptData);

    // Check rate limit
    const withinLimit = await checkRateLimit(receiptHash, RATE_LIMIT, RATE_WINDOW);
    if (!withinLimit) {
      return NextResponse.json(
        {
          error: 'Rate limit exceeded',
          message: 'Please upgrade your plan for more requests',
          upgradeUrl: '/subscription'
        },
        { status: 429 }
      );
    }

    // Get stored tier and check if receipt tier is valid
    const storedTier = await getTier(receiptHash);
    const currentTier = receipt.tier;

    // If stored tier is higher than receipt tier, use stored tier (user downgraded)
    const effectiveTier = (storedTier && getTierPriority(storedTier) > getTierPriority(currentTier)
      ? storedTier
      : currentTier) as 'free' | 'premium' | 'pro';

    // Check credits
    const credits = await getCredits(receiptHash);

    if (credits === null) {
      // First time - initialize credits
      const initialCredits = getCreditsForTier(effectiveTier);
      await decrementCredits(receiptHash); // This will set to initial - 1, so we need to set first
      const { setCredits } = await import('../../lib/redis.js');
      await setCredits(receiptHash, initialCredits - 1, effectiveTier);

      try {
        const resultImage = await generateTryOnImage(clothingBuffer, personBuffer);
        return NextResponse.json({
          success: true,
          imageUrl: resultImage.toString('base64'),
          creditsRemaining: initialCredits - 1,
          tier: effectiveTier,
        });
      } catch (error) {
        // Refund credit on failure
        const { setCredits: setCreditsImport } = await import('../../lib/redis.js');
        await setCreditsImport(receiptHash, initialCredits, effectiveTier);
        throw error;
      }
    }

    if (credits <= 0) {
      return NextResponse.json(
        {
          error: 'No credits remaining',
          message: 'Please upgrade your plan for more try-ons',
          upgradeUrl: '/subscription',
          tier: effectiveTier,
        },
        { status: 429 }
      );
    }

    // Decrement and generate
    const remainingCredits = await decrementCredits(receiptHash);

    try {
      const resultImage = await generateTryOnImage(clothingBuffer, personBuffer);
      return NextResponse.json({
        success: true,
        imageUrl: resultImage.toString('base64'),
        creditsRemaining: remainingCredits,
        tier: effectiveTier,
      });
    } catch (error) {
      // Refund credit on failure
      const { setCredits: setCreditsImport } = await import('../../lib/redis.js');
      await setCreditsImport(receiptHash, credits, effectiveTier);
      throw error;
    }

  } catch (error) {
    console.error('Try-on error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';

    if (errorMessage === 'INVALID_IMAGES') {
      return NextResponse.json({ error: 'Invalid images provided' }, { status: 400 });
    }
    if (errorMessage === 'INVALID_API_KEY') {
      return NextResponse.json({ error: 'API configuration error' }, { status: 500 });
    }
    if (errorMessage === 'RATE_LIMIT_EXCEEDED') {
      return NextResponse.json({ error: 'External API rate limit, try again later' }, { status: 429 });
    }

    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function generateTryOnImage(clothingBuffer: Buffer, personBuffer: Buffer): Promise<Buffer> {
  if (process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_IMAGE_MODEL) {
    return generateTryOnWithOpenRouter(clothingBuffer, personBuffer);
  }

  return generateTryOn(clothingBuffer, personBuffer);
}

function getTierPriority(tier: string): number {
  const priorities: Record<string, number> = {
    free: 1,
    premium: 2,
    pro: 3,
    test: 4,
  };
  return priorities[tier] || 0;
}
