import { Platform } from "react-native";
import * as Application from "expo-application";
import * as Crypto from "expo-crypto";
import * as SecureStore from "expo-secure-store";

/**
 * Huella del dispositivo para detectar varias cuentas creadas en el mismo
 * móvil (el caso típico de alguien que se autovota o infla su valoración con
 * cuentas propias). No identifica a la persona ni sale del backend: se guarda
 * ya hasheada en `users/{uid}`, que es privado, y las reglas de Firestore la
 * comparan con `get()` sin que ningún cliente pueda leerla.
 *
 * Preferimos el identificador del sistema (idForVendor en iOS, ANDROID_ID en
 * Android) porque sobrevive a reinstalaciones dentro del mismo vendor. Si no
 * está disponible caemos a un id propio persistido en SecureStore, que al
 * menos cubre el caso de dos cuentas abiertas a la vez en el mismo teléfono.
 */

const FALLBACK_KEY = "matchpoint.device-id";
// Sal fija: evita que el hash sea una tabla directa del identificador del
// sistema. No es un secreto (viaja en el binario), solo desacopla el valor.
const SALT = "matchpoint-device-v1";

async function readPlatformDeviceId(): Promise<string | null> {
  try {
    if (Platform.OS === "android") return Application.getAndroidId() || null;
    if (Platform.OS === "ios") return await Application.getIosIdForVendorAsync();
  } catch {
    // Sin permiso o API no disponible: usamos el fallback.
  }
  return null;
}

async function readOrCreateFallbackId(): Promise<string | null> {
  if (Platform.OS === "web") return null;
  try {
    const stored = await SecureStore.getItemAsync(FALLBACK_KEY);
    if (stored) return stored;
    const generated = Crypto.randomUUID();
    await SecureStore.setItemAsync(FALLBACK_KEY, generated);
    return generated;
  } catch {
    return null;
  }
}

/**
 * Devuelve el hash del dispositivo, o `null` en web y cuando no hay ningún
 * identificador disponible. Nunca lanza: es una señal antifraude auxiliar y no
 * debe impedir usar la app.
 */
export async function getDeviceHash(): Promise<string | null> {
  try {
    const raw = (await readPlatformDeviceId()) ?? (await readOrCreateFallbackId());
    if (!raw) return null;
    return await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, `${SALT}:${raw}`);
  } catch {
    return null;
  }
}
