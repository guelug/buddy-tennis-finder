export type GoogleAuthTokens = {
  idToken: string;
  accessToken: string;
};

type MaybeGoogleAuthTokens = {
  idToken?: string | null;
  accessToken?: string | null;
};

/**
 * Firebase Auth para Android exige que ambos campos enviados al puente nativo
 * sean cadenas no vacías. Normalizarlos aquí evita que `undefined` termine
 * convertido en `""` dentro de React Native Firebase.
 */
export function requireGoogleAuthTokens(tokens: MaybeGoogleAuthTokens): GoogleAuthTokens {
  const idToken = tokens.idToken?.trim();
  const accessToken = tokens.accessToken?.trim();

  if (!idToken) {
    throw new Error("Google no devolvió un token de identidad válido.");
  }
  if (!accessToken) {
    throw new Error("Google no devolvió un token de acceso válido.");
  }

  return { idToken, accessToken };
}
