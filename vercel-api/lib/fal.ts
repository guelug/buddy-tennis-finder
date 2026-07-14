// fal.ai image provider (Nano Banana 2 / Gemini image edit).
//
// fal.run is the synchronous endpoint: POST the payload, get the result back in one call.
// Auth header is `Authorization: Key <FAL_KEY>`. Edit models accept input images as data URIs
// in `image_urls` and return `{ images: [{ url }] }` where `url` is a fal.media file we fetch.
//
// Env:
//   FAL_KEY                 fal.ai API key (required to use this provider)
//   FAL_IMAGE_MODEL         edit model slug. Default: fal-ai/nano-banana/edit
//                           For "Nano Banana 2" (Gemini 3 image), set: fal-ai/nano-banana-pro/edit

const FAL_BASE = 'https://fal.run';

type FalImage = { url?: string; content_type?: string };
type FalResponse = { images?: FalImage[]; image?: FalImage; detail?: unknown; error?: string };

function falModel(): string {
  return process.env.FAL_IMAGE_MODEL || 'fal-ai/nano-banana/edit';
}

function dataUri(buffer: Buffer, mime = 'image/jpeg'): string {
  return `data:${mime};base64,${buffer.toString('base64')}`;
}

async function callFalEdit(prompt: string, images: Buffer[]): Promise<Buffer> {
  const apiKey = process.env.FAL_KEY;
  if (!apiKey) {
    throw new Error('FAL_KEY_NOT_CONFIGURED');
  }

  const response = await fetch(`${FAL_BASE}/${falModel()}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify({
      prompt,
      image_urls: images.map(img => dataUri(img)),
      num_images: 1,
      output_format: 'jpeg',
    }),
  });

  if (response.status === 401 || response.status === 403) {
    throw new Error('INVALID_API_KEY');
  }
  if (response.status === 429) {
    throw new Error('RATE_LIMIT_EXCEEDED');
  }
  if (response.status === 422 || response.status === 400) {
    throw new Error('INVALID_IMAGES');
  }

  const data = (await response.json().catch(() => ({}))) as FalResponse;

  if (!response.ok) {
    const detail =
      (typeof data.error === 'string' && data.error) ||
      (typeof data.detail === 'string' && data.detail) ||
      `FAL HTTP ${response.status}`;
    throw new Error(detail);
  }

  const url = data.images?.find(i => i.url)?.url || data.image?.url;
  if (!url) {
    throw new Error('NO_IMAGE_GENERATED');
  }

  const fileRes = await fetch(url);
  if (!fileRes.ok) {
    throw new Error('FAL_RESULT_FETCH_FAILED');
  }
  return Buffer.from(await fileRes.arrayBuffer());
}

export async function generateTryOnWithFal(
  clothingImage: Buffer,
  personImage: Buffer
): Promise<Buffer> {
  const prompt = [
    'Create a realistic virtual try-on photo.',
    'Use the first image as the garment and the second image as the person.',
    'Dress the person in the garment. Preserve their identity, pose, body proportions,',
    'skin tone, hair, lighting and background. Only change the clothing.',
    'Output a clean, photorealistic full result.',
  ].join(' ');
  return callFalEdit(prompt, [clothingImage, personImage]);
}

export async function generateMarketingImageWithFal(
  garmentImage: Buffer,
  categoryHint?: string
): Promise<Buffer> {
  const hint = categoryHint ? ` The item is a ${categoryHint}.` : '';
  const prompt = [
    'Turn this into a clean store-style product thumbnail.',
    'Pure white seamless background, the garment centered, facing front and fully visible,',
    'soft even studio lighting, no people, no props, no shadows, sharp e-commerce catalog look.' + hint,
  ].join(' ');
  return callFalEdit(prompt, [garmentImage]);
}

export function isFalConfigured(): boolean {
  return Boolean(process.env.FAL_KEY);
}
