import crypto from 'crypto';

export interface ReceiptData {
  bundleId: string;
  productId: string;
  purchaseDate: string;
  expirationDate?: string;
  tier: ReceiptTier;
}

export type ReceiptTier = 'free' | 'premium' | 'pro' | 'lifetime';

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

export function hashReceipt(receipt: string): string {
  return crypto.createHash('sha256').update(receipt).digest('hex');
}

export function getCreditsForTier(tier: ReceiptTier): number {
  return CREDITS_MAP[tier] ?? 0;
}

export async function verifyReceipt(receiptBase64: string): Promise<ReceiptData | null> {
  try {
    const receiptBuffer = Buffer.from(receiptBase64, 'base64');
    const receiptPayload = JSON.parse(receiptBuffer.toString('utf-8'));

    const bundleId = receiptPayload.bundleId || receiptPayload.receipt?.bundle_id;
    const productId = receiptPayload.productId || receiptPayload.receipt?.product_id;
    const purchaseDate = receiptPayload.purchaseDate || receiptPayload.receipt?.purchase_date;
    const expirationDate = receiptPayload.expirationDate || receiptPayload.receipt?.expiration_date;

    if (!bundleId || !productId || !purchaseDate) {
      return null;
    }

    const tier = TIER_MAP[productId] || 'free';

    return {
      bundleId,
      productId,
      purchaseDate,
      expirationDate,
      tier,
    };
  } catch {
    // For production, call Apple verifyReceipt endpoint
    // This is a simplified placeholder for server-side validation
    try {
      const response = await fetch('https://buy.itunes.apple.com/verifyReceipt', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          'receipt-data': receiptBase64,
          'password': process.env.APPLE_SHARED_SECRET,
        }),
      });

      if (!response.ok) {
        return null;
      }

      const data = await response.json() as any;

      if (data.status !== 0) {
        return null;
      }

      const latestReceipt = data.latest_receipt_info?.[0];
      const productId = latestReceipt?.product_id || data.receipt?.product_id;
      const tier = TIER_MAP[productId] || 'free';

      return {
        bundleId: data.receipt?.bundle_id || '',
        productId,
        purchaseDate: latestReceipt?.purchase_date || '',
        expirationDate: latestReceipt?.expiration_date || undefined,
        tier,
      };
    } catch {
      return null;
    }
  }
}
