import type { Auth, UserCredential } from "firebase/auth";

/** Metro sustituye esta implementación por la variante de plataforma. */
export async function runGooglePopup(_auth: Auth): Promise<UserCredential> {
  throw new Error("El popup de Google solo está disponible en web.");
}
