import { getCrashlytics, log, recordError as recordCrashlyticsError } from "@react-native-firebase/crashlytics";

const crashlytics = getCrashlytics();

/**
 * Captura los errores no manejados (JS globales y promesas rechazadas) que
 * hoy solo pasaban por `console.warn` y se perdían en producción. En
 * desarrollo seguimos viendo el warning en consola; en release además queda
 * registrado en Crashlytics para poder diagnosticar sin depender de que el
 * usuario reporte el fallo.
 */
export function initCrashReporting() {
  const globalObject = globalThis as unknown as {
    ErrorUtils?: { setGlobalHandler: (handler: (error: Error, isFatal?: boolean) => void) => void; getGlobalHandler: () => (error: Error, isFatal?: boolean) => void };
  };

  const previousHandler = globalObject.ErrorUtils?.getGlobalHandler();
  globalObject.ErrorUtils?.setGlobalHandler((error, isFatal) => {
    recordCrashlyticsError(crashlytics, error);
    previousHandler?.(error, isFatal);
  });

  const rejectionTracker = require("promise/setimmediate/rejection-tracking");
  rejectionTracker.enable({
    allRejections: true,
    onUnhandled: (_id: number, error: unknown) => {
      recordCrashlyticsError(crashlytics, error instanceof Error ? error : new Error(String(error)));
    },
    onHandled: () => {}
  });
}

export function recordError(error: unknown, context?: string) {
  const normalized = error instanceof Error ? error : new Error(String(error));
  if (context) log(crashlytics, context);
  recordCrashlyticsError(crashlytics, normalized);
}

export function setCrashReportingUser(_uid: string | null) {
  // Deliberately keep crash reports detached from the Firebase account UID.
  // Installation diagnostics are enough to investigate stability issues.
}
