import { deleteUser, getIdTokenResult } from "@react-native-firebase/auth";
import { collection, doc, getDocs, query, serverTimestamp, where, writeBatch, type WriteBatch } from "@react-native-firebase/firestore";
import { auth, db } from "@/../firebase.config";

export async function deleteCurrentAccountAndData() {
  const user = auth.currentUser;
  if (!user) throw new Error("No hay una sesión activa.");

  const token = await getIdTokenResult(user);
  const authAgeMs = Date.now() - new Date(token.authTime).getTime();
  if (authAgeMs > 10 * 60 * 1000) {
    throw new Error("Por seguridad, cierra sesión, vuelve a entrar y repite la eliminación.");
  }

  const [sent, accepted] = await Promise.all([
    getDocs(query(collection(db, "matches"), where("fromPlayerId", "==", user.uid))),
    getDocs(query(collection(db, "matches"), where("acceptedByPlayerId", "==", user.uid)))
  ]);

  const mutations: Array<(batch: WriteBatch) => void> = [];
  const ownedIds = new Set(sent.docs.map((match) => match.id));

  for (const match of sent.docs) {
    mutations.push((batch) => batch.delete(match.ref));
  }

  // Un partido creado por otra persona no lo puede borrar quien lo aceptó.
  // Desvinculamos el UID y lo reabrimos solo si todavía es futuro.
  for (const match of accepted.docs) {
    if (ownedIds.has(match.id)) continue;
    const startsAt = String(match.data().startsAt ?? "");
    const future = new Date(startsAt).getTime() > Date.now();
    mutations.push((batch) => batch.update(match.ref, {
      acceptedByPlayerId: null,
      status: future ? "proposed" : "declined",
      updatedAt: serverTimestamp()
    }));
  }

  mutations.push((batch) => batch.delete(doc(db, "players", user.uid)));
  mutations.push((batch) => batch.delete(doc(db, "users", user.uid)));

  // Firestore admite hasta 500 escrituras por batch; dejamos margen operativo.
  for (let index = 0; index < mutations.length; index += 400) {
    const batch = writeBatch(db);
    for (const mutate of mutations.slice(index, index + 400)) mutate(batch);
    await batch.commit();
  }

  await deleteUser(user);
}
