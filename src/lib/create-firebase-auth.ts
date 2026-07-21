import { getAuth, type Auth } from "firebase/auth";
import type { FirebaseApp } from "firebase/app";

/**
 * Implementación de respaldo para entornos que no exponen una plataforma.
 * Metro sustituye este archivo por `.native.ts` o `.web.ts` en cada build.
 */
export function createFirebaseAuth(app: FirebaseApp): Auth {
  return getAuth(app);
}
