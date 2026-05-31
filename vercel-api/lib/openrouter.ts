export type ChatRequest = {
  systemPrompt: string;
  message: string;
  model?: string;
};

type OpenRouterChoice = {
  message?: {
    content?: string | OpenRouterContentPart[];
    images?: OpenRouterImage[];
  };
};

type OpenRouterResponse = {
  choices?: OpenRouterChoice[];
  error?: {
    message?: string;
  };
};

type OpenRouterContentPart = {
  type?: string;
  text?: string;
  content?: string;
  image_url?: {
    url?: string;
  };
};

type OpenRouterImage = {
  image_url?: {
    url?: string;
  };
};

export async function generateStyleChat({
  systemPrompt,
  message,
  model,
}: ChatRequest): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY_NOT_CONFIGURED');
  }

  const selectedModel = model || process.env.OPENROUTER_CHAT_MODEL || 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free';
  const maxTokens = Number(process.env.OPENROUTER_CHAT_MAX_TOKENS || 520);

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
      'HTTP-Referer': process.env.APP_PUBLIC_URL || 'https://personalshooper.rebka.co',
      'X-Title': 'Personal Shooper',
    },
    body: JSON.stringify({
      model: selectedModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: message },
      ],
      temperature: 0.35,
      max_tokens: maxTokens,
    }),
  });

  const data = (await response.json().catch(() => ({}))) as OpenRouterResponse;

  if (!response.ok) {
    const detail = data.error?.message || `OpenRouter HTTP ${response.status}`;
    if (response.status === 429) {
      throw new Error('OPENROUTER_RATE_LIMIT');
    }
    throw new Error(detail);
  }

  const content = extractTextContent(data.choices?.[0]?.message?.content);
  if (!content) {
    throw new Error('EMPTY_OPENROUTER_RESPONSE');
  }

  return content;
}

function extractTextContent(content: string | OpenRouterContentPart[] | undefined): string | undefined {
  if (typeof content === 'string') {
    return content.trim() || undefined;
  }

  if (Array.isArray(content)) {
    const text = content
      .map(part => part.text || part.content)
      .filter(Boolean)
      .join('\n')
      .trim();
    return text || undefined;
  }

  return undefined;
}

export async function generateTryOnWithOpenRouter(
  clothingImage: Buffer,
  personImage: Buffer
): Promise<Buffer> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY_NOT_CONFIGURED');
  }

  const model = process.env.OPENROUTER_IMAGE_MODEL || 'openai/gpt-5.4-image-2';
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
      'HTTP-Referer': process.env.APP_PUBLIC_URL || 'https://personalshooper.rebka.co',
      'X-Title': 'Personal Shooper',
    },
    body: JSON.stringify({
      model,
      modalities: ['image', 'text'],
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: [
                'Create a realistic virtual try-on image.',
                'Use the first image as the garment and the second image as the person.',
                'Preserve the person identity, pose, body proportions, lighting, and background.',
                'Only replace/add the visible clothing item. Avoid changing face, hair, skin tone, or scene.',
                'Return the generated try-on image.',
              ].join(' '),
            },
            {
              type: 'image_url',
              image_url: { url: `data:image/jpeg;base64,${clothingImage.toString('base64')}` },
            },
            {
              type: 'image_url',
              image_url: { url: `data:image/jpeg;base64,${personImage.toString('base64')}` },
            },
          ],
        },
      ],
    }),
  });

  const data = (await response.json().catch(() => ({}))) as OpenRouterResponse;

  if (!response.ok) {
    const detail = data.error?.message || `OpenRouter HTTP ${response.status}`;
    if (response.status === 429) {
      throw new Error('RATE_LIMIT_EXCEEDED');
    }
    if (response.status === 401) {
      throw new Error('INVALID_API_KEY');
    }
    throw new Error(detail);
  }

  const imageUrl = extractImageDataUrl(data);
  if (!imageUrl) {
    throw new Error('NO_IMAGE_GENERATED');
  }

  return imageDataUrlToBuffer(imageUrl);
}

function extractImageDataUrl(data: OpenRouterResponse): string | null {
  const message = data.choices?.[0]?.message;
  if (!message) {
    return null;
  }

  const imageFromArray = message.images
    ?.map(image => image.image_url?.url)
    .find(Boolean);
  if (imageFromArray) {
    return imageFromArray;
  }

  if (Array.isArray(message.content)) {
    return message.content
      .map(part => part.image_url?.url || (part.type === 'image_url' ? part.image_url?.url : undefined))
      .find(Boolean) || null;
  }

  if (typeof message.content === 'string') {
    const match = message.content.match(/data:image\/[a-zA-Z]+;base64,[A-Za-z0-9+/=]+/);
    return match?.[0] || null;
  }

  return null;
}

function imageDataUrlToBuffer(dataUrl: string): Buffer {
  const base64 = dataUrl.includes(',') ? dataUrl.split(',').pop() : dataUrl;
  if (!base64) {
    throw new Error('INVALID_IMAGE_RESPONSE');
  }

  return Buffer.from(base64, 'base64');
}
