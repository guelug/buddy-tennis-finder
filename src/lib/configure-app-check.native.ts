import type { FirebaseApp } from "firebase/app";

// reCAPTCHA v3 es exclusivo de web. Android usará Play Integrity en una fase
// independiente cuando esté registrado en Firebase App Check.
export function configureAppCheck(_app: FirebaseApp, _siteKey?: string): void {}
