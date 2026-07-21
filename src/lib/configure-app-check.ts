import type { FirebaseApp } from "firebase/app";

/** Metro usa la implementación web; en nativo App Check se configura aparte. */
export function configureAppCheck(_app: FirebaseApp, _siteKey?: string): void {}
