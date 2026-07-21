import type { Auth, UserCredential } from "firebase/auth";

export async function runGooglePopup(_auth: Auth): Promise<UserCredential> {
  throw new Error("El popup de Google solo está disponible en web.");
}
