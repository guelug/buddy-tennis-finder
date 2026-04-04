const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:image=generate';

export async function generateTryOn(
  clothingImage: Buffer,
  personImage: Buffer
): Promise<Buffer> {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  const formData = new FormData();

  const clothingBlob = new Blob([clothingImage], { type: 'image/jpeg' });
  const personBlob = new Blob([personImage], { type: 'image/jpeg' });

  formData.append('image', clothingBlob, 'clothing.jpg');
  formData.append('prompt', 'Virtual try-on: Show this clothing item on the person in the other image. Professional fashion photography style.');
  formData.append('person_image', personBlob, 'person.jpg');

  const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: 'POST',
    body: formData,
  });

  if (response.status === 400) {
    throw new Error('INVALID_IMAGES');
  }

  if (response.status === 401) {
    throw new Error('INVALID_API_KEY');
  }

  if (response.status === 429) {
    throw new Error('RATE_LIMIT_EXCEEDED');
  }

  if (!response.ok) {
    throw new Error('GEMINI_ERROR');
  }

  const data = await response.json();

  if (!data.image || !data.image.data) {
    throw new Error('NO_IMAGE Generated');
  }

  const imageBuffer = Buffer.from(data.image.data, 'base64');
  return imageBuffer;
}
