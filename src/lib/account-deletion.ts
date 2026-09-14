import { getIdTokenResult, signOut } from "@react-native-firebase/auth";
import { auth } from "@/../firebase.config";
import { deleteAccountSecure } from "@/lib/secure-backend";

export async function deleteCurrentAccountAndData() {
  const user = auth.currentUser;
  if (!user) throw new Error("No hay una sesión activa.");

  const token = await getIdTokenResult(user);
  const authAgeMs = Date.now() - new Date(token.authTime).getTime();
  if (authAgeMs > 10 * 60 * 1000) {
    throw new Error("Por seguridad, cierra sesión, vuelve a entrar y repite la eliminación.");
  }

  // La limpieza se hace con credenciales de servidor: hay documentos
  // inmutables (reseñas, rankings, compras) que el cliente no puede tocar y
  // subcolecciones que Firestore no elimina junto con su documento padre.
  await deleteAccountSecure();

  // El backend elimina también Firebase Auth. Limpiamos la sesión nativa para
  // que el listener de autenticación actualice la UI inmediatamente.
  await signOut(auth).catch(() => undefined);
}
