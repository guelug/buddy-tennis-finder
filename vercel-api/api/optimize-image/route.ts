import { NextRequest, NextResponse } from 'next/server.js';
import { StoreAuthorizationError, verifyStoreAuthorization } from '../../lib/apple.js';
import { generateMarketingImageWithFal, isFalConfigured } from '../../lib/fal.js';
import { generateTryOnWithOpenRouter } from '../../lib/openrouter.js';
import { checkAndConsumeQuota, normalizeTier, refundQuota } from '../../lib/quota.js';
import { InputValidationError, optionalText, requiredImage } from '../../lib/input.js';

export async function POST(request: NextRequest) {
  let quotaUserId: string | null = null;

  try {
    const authorization = await verifyStoreAuthorization(request.headers);
    quotaUserId = authorization.userId;
    const tier = normalizeTier(authorization.tier);

    const formData = await request.formData();
    const garmentFile = requiredImage(formData, 'image');
    const categoryHint = optionalText(formData, 'categoryHint', 120);

    const quota = await checkAndConsumeQuota(authorization.userId, tier, 'optimize');
    if (!quota.allowed) {
      return NextResponse.json(
        { error: 'Quota exceeded', resetAt: quota.resetAt, window: quota.window, tier: quota.tier },
        { status: 429 }
      );
    }

    try {
      const result = await runOptimize(Buffer.from(await garmentFile.arrayBuffer()), categoryHint);
      return NextResponse.json({
        success: true,
        imageUrl: result.toString('base64'),
        tier: quota.tier,
        remaining: quota.remaining,
      });
    } catch (error) {
      await refundQuota(authorization.userId, 'optimize');
      return errorResponse(error);
    }
  } catch (error) {
    if (error instanceof StoreAuthorizationError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    if (error instanceof InputValidationError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error('Optimize-image error:', { quotaUserId, error });
    return errorResponse(error);
  }
}

async function runOptimize(garment: Buffer, categoryHint?: string): Promise<Buffer> {
  if (isFalConfigured()) {
    return generateMarketingImageWithFal(garment, categoryHint);
  }
  if (process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_IMAGE_MODEL) {
    return generateTryOnWithOpenRouter(garment, garment);
  }
  throw new Error('NO_IMAGE_PROVIDER_CONFIGURED');
}

function errorResponse(error: unknown): NextResponse {
  const message = error instanceof Error ? error.message : 'Unknown error';
  if (message === 'INVALID_API_KEY') {
    return NextResponse.json({ error: 'API configuration error' }, { status: 500 });
  }
  if (message === 'RATE_LIMIT_EXCEEDED') {
    return NextResponse.json({ error: 'External API rate limit, try again later' }, { status: 429 });
  }
  if (message === 'INVALID_IMAGES') {
    return NextResponse.json({ error: 'Invalid image provided' }, { status: 400 });
  }
  if (message === 'NO_IMAGE_PROVIDER_CONFIGURED') {
    return NextResponse.json({ error: 'No image provider configured on server' }, { status: 503 });
  }
  if (message === 'QUOTA_STORE_NOT_CONFIGURED') {
    return NextResponse.json({ error: 'Usage service unavailable' }, { status: 503 });
  }
  return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
}
