import { manipulateAsync, SaveFormat } from "expo-image-manipulator";

export async function uploadProfilePhoto(
  _uid: string,
  uri: string,
  onProgress: (progress: number) => void
): Promise<string> {
  onProgress(0.15);
  const image = await manipulateAsync(
    uri,
    [{ resize: { width: 320, height: 320 } }],
    { base64: true, compress: 0.68, format: SaveFormat.JPEG }
  );
  onProgress(0.78);
  if (!image.base64) throw new Error("No se pudo procesar la fotografía.");
  const dataUrl = `data:image/jpeg;base64,${image.base64}`;
  // Firestore limita cada documento a 1 MiB. Reservamos amplio margen para
  // el resto del perfil y rechazamos miniaturas mayores de ~350 KiB.
  if (dataUrl.length > 350_000) throw new Error("La fotografía sigue siendo demasiado grande.");
  await new Promise((resolve) => setTimeout(resolve, 180));
  onProgress(1);
  return dataUrl;
}
