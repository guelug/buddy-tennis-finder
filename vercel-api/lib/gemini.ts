const GEMINI_API_ROOT = 'https://generativelanguage.googleapis.com/v1beta/models';
const GEMINI_IMAGE_MODEL = 'gemini-3.1-flash-image';
const GEMINI_TEXT_MODEL = process.env.GEMINI_TEXT_MODEL || 'gemini-2.5-flash';

type GeminiPart = {
  text?: string;
  inlineData?: { data?: string; mimeType?: string };
  inline_data?: { data?: string; mime_type?: string };
};

type GeminiResponse = {
  candidates?: Array<{ content?: { parts?: GeminiPart[] } }>;
  error?: { message?: string };
};

function modelURL(model: string): string {
  return `${GEMINI_API_ROOT}/${model}:generateContent`;
}

function imageMimeType(buffer: Buffer): string {
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    return 'image/png';
  }
  if (buffer.length >= 12 && buffer.subarray(0, 4).toString('ascii') === 'RIFF'
      && buffer.subarray(8, 12).toString('ascii') === 'WEBP') {
    return 'image/webp';
  }
  return 'image/jpeg';
}

function inlineImage(buffer: Buffer): GeminiPart {
  return {
    inlineData: {
      mimeType: imageMimeType(buffer),
      data: buffer.toString('base64'),
    },
  };
}

export async function generateTryOn(
  clothingImage: Buffer,
  personImage: Buffer
): Promise<Buffer> {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  const prompt = [
    'Create a realistic professional full-body virtual try-on image.',
    'Image 1 is the exact garment and image 2 is the person.',
    'Dress the person in that garment while preserving their identity, face, hair, skin tone,',
    'body proportions, pose, lighting, and background.',
    'Preserve the garment color, pattern, texture, silhouette, seams, logos, and details.',
    'Only change the relevant clothing and return one photorealistic image.',
  ].join(' ');

  const response = await fetch(modelURL(GEMINI_IMAGE_MODEL), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      contents: [{
        role: 'user',
        parts: [
          inlineImage(clothingImage),
          inlineImage(personImage),
          { text: prompt },
        ],
      }],
      generationConfig: {
        responseModalities: ['IMAGE'],
        temperature: 0.25,
      },
    }),
  });

  if (response.status === 400 || response.status === 422) {
    throw new Error('INVALID_IMAGES');
  }

  if (response.status === 401 || response.status === 403) {
    throw new Error('INVALID_API_KEY');
  }

  if (response.status === 429) {
    throw new Error('RATE_LIMIT_EXCEEDED');
  }

  const data = await response.json().catch(() => ({})) as GeminiResponse;
  if (!response.ok) {
    throw new Error(data.error?.message || `GEMINI_HTTP_${response.status}`);
  }

  const encodedImage = data.candidates
    ?.flatMap(candidate => candidate.content?.parts || [])
    .map(part => part.inlineData?.data || part.inline_data?.data)
    .find((value): value is string => Boolean(value));

  if (!encodedImage) {
    throw new Error('NO_IMAGE_GENERATED');
  }

  return Buffer.from(encodedImage, 'base64');
}

export async function generateStyleChatWithGemini(
  systemPrompt: string,
  message: string
): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  const response = await fetch(modelURL(GEMINI_TEXT_MODEL), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemPrompt }],
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: message }],
        },
      ],
      generationConfig: {
        maxOutputTokens: 520,
        temperature: 0.7,
      },
    }),
  });

  if (response.status === 401 || response.status === 403) {
    throw new Error('INVALID_API_KEY');
  }

  if (response.status === 429) {
    throw new Error('RATE_LIMIT_EXCEEDED');
  }

  if (!response.ok) {
    throw new Error('GEMINI_TEXT_ERROR');
  }

  const data = await response.json() as GeminiResponse;
  const text = data?.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part.text)
    .filter(Boolean)
    .join('\n')
    .trim();

  if (!text) {
    throw new Error('EMPTY_GEMINI_RESPONSE');
  }

  return text;
}
