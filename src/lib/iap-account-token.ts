import * as Crypto from "expo-crypto";

/**
 * StoreKit exige un UUID estable para vincular una compra con la cuenta de la
 * app. No es un secreto: se deriva del uid con SHA-256, pero no revela el uid
 * original ni cambia entre dispositivos.
 */
export async function iapAccountTokenForUid(uid: string): Promise<string> {
  const hex = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, uid);
  const bytes = Array.from({ length: 16 }, (_, index) => Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16));
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x50;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const normalized = bytes.map((value) => value.toString(16).padStart(2, "0")).join("");
  return `${normalized.slice(0, 8)}-${normalized.slice(8, 12)}-${normalized.slice(12, 16)}-${normalized.slice(16, 20)}-${normalized.slice(20)}`;
}
