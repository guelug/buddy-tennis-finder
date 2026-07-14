export class InputValidationError extends Error {
  readonly status = 400;
}

const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set([
  'image/heic',
  'image/heif',
  'image/jpeg',
  'image/png',
  'image/webp',
]);

export function requiredImage(formData: FormData, field: string): File {
  const value = formData.get(field);
  if (!(value instanceof File) || value.size === 0) {
    throw new InputValidationError(`Missing image: ${field}`);
  }
  if (value.size > MAX_IMAGE_BYTES) {
    throw new InputValidationError(`Image is too large: ${field}`);
  }
  if (!ALLOWED_IMAGE_TYPES.has(value.type.toLowerCase())) {
    throw new InputValidationError(`Unsupported image type: ${field}`);
  }
  return value;
}

export function optionalText(
  formData: FormData,
  field: string,
  maxLength: number
): string | undefined {
  const value = formData.get(field);
  if (typeof value !== 'string') {
    return undefined;
  }
  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new InputValidationError(`Field is too long: ${field}`);
  }
  return trimmed || undefined;
}
