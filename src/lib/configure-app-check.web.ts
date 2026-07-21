import type { FirebaseApp } from "firebase/app";
import type {
  initializeAppCheck as InitializeAppCheckFn,
  ReCaptchaV3Provider as ReCaptchaV3ProviderClass
} from "firebase/app-check";

export function configureAppCheck(app: FirebaseApp, siteKey?: string): void {
  if (typeof window === "undefined" || !siteKey || siteKey === "undefined" || siteKey === "null") {
    return;
  }

  try {
    // Carga diferida: evita evaluar APIs de navegador durante el prerender web.
    const { initializeAppCheck, ReCaptchaV3Provider } = require("firebase/app-check") as {
      initializeAppCheck: typeof InitializeAppCheckFn;
      ReCaptchaV3Provider: typeof ReCaptchaV3ProviderClass;
    };
    initializeAppCheck(app, {
      provider: new ReCaptchaV3Provider(siteKey),
      isTokenAutoRefreshEnabled: true
    });
  } catch (error) {
    console.warn("[matchpoint] No se pudo inicializar App Check web", error);
  }
}
