import { NextRequest, NextResponse } from 'next/server.js';
import { StoreAuthorizationError, verifyStoreAuthorization } from '../../lib/apple.js';
import { generateTryOn } from '../../lib/gemini.js';
import { generateTryOnWithOpenRouter } from '../../lib/openrouter.js';
import { generateTryOnWithFal, isFalConfigured } from '../../lib/fal.js';
import { checkAndConsumeQuota, normalizeTier, refundQuota } from '../../lib/quota.js';
import { InputValidationError, requiredImage } from '../../lib/input.js';

export async function POST(request: NextRequest) {
  let quotaUserId: string | null = null;

  try {
    const authorization = await verifyStoreAuthorization(request.headers);
    quotaUserId = authorization.userId;
    const tier = normalizeTier(authorization.tier);

    const formData = await request.formData();
    const clothingFile = requiredImage(formData, 'clothingImage');
    const personFile = requiredImage(formData, 'personImage');

    const quota = await checkAndConsumeQuota(authorization.userId, tier, 'try_on');
    if (!quota.allowed) {
      return NextResponse.json(
        { error: 'Quota exceeded', resetAt: quota.resetAt, window: quota.window, tier: quota.tier },
        { status: 429 }
      );
    }

    try {
      const result = await generateTryOnImage(
        Buffer.from(await clothingFile.arrayBuffer()),
        Buffer.from(await personFile.arrayBuffer())
      );
      return NextResponse.json({
        success: true,
        imageUrl: result.toString('base64'),
        creditsRemaining: quota.remaining.monthly ?? quota.remaining.daily ?? 0,
        tier: quota.tier,
      });
    } catch (error) {
      await refundQuota(authorization.userId, 'try_on');
      throw error;
    }
  } catch (error) {
    if (error instanceof StoreAuthorizationError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof InputValidationError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }

    console.error('Try-on error:', { quotaUserId, error });
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message === 'INVALID_IMAGES') {
      return NextResponse.json({ error: 'Invalid images provided' }, { status: 400 });
    }
    if (message === 'RATE_LIMIT_EXCEEDED') {
      return NextResponse.json({ error: 'External API rate limit, try again later' }, { status: 429 });
    }
    if (message === 'QUOTA_STORE_NOT_CONFIGURED') {
      return NextResponse.json({ error: 'Usage service unavailable' }, { status: 503 });
    }
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function generateTryOnImage(clothing: Buffer, person: Buffer): Promise<Buffer> {
  if (isFalConfigured()) {
    return generateTryOnWithFal(clothing, person);
  }
  if (process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_IMAGE_MODEL) {
    return generateTryOnWithOpenRouter(clothing, person);
  }
  return generateTryOn(clothing, person);
}
