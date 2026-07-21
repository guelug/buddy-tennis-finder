import { applicationDefault, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const apply = process.argv.includes("--apply");
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "tenisbuddy-app";
initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();

const levels = {
  beginner: "novato",
  intermediate: "d",
  advanced: "c",
  competitive: "b",
  novato: "novato",
  d: "d",
  c: "c",
  b: "b",
  a: "a"
};

const players = await db.collection("players").get();
const matches = await db.collection("matches").get();
const changes = [];

for (const snapshot of players.docs) {
  const data = snapshot.data();
  const patch = {};
  if (!Array.isArray(data.clubIds)) patch.clubIds = data.clubId ? [data.clubId] : [];
  const normalizedLevel = levels[String(data.level ?? "novato").toLowerCase()] ?? "novato";
  if (data.level !== normalizedLevel) patch.level = normalizedLevel;
  if (Object.keys(patch).length) changes.push({ ref: snapshot.ref, kind: "player", id: snapshot.id, patch });
}

for (const snapshot of matches.docs) {
  const data = snapshot.data();
  if (!("acceptedByPlayerId" in data) && "toPlayerId" in data) {
    // Una invitación privada antigua nunca se convierte silenciosamente en
    // propuesta pública. Se archiva y conserva el destinatario para auditoría.
    changes.push({
      ref: snapshot.ref,
      kind: "legacy-match",
      id: snapshot.id,
      patch: {
        acceptedByPlayerId: data.toPlayerId || null,
        status: "declined",
        migratedLegacyDirected: true,
        legacyToPlayerId: data.toPlayerId || null
      }
    });
  }
}

console.log(`${apply ? "APPLY" : "DRY RUN"}: ${changes.length} documentos por migrar`);
for (const change of changes) console.log(`- ${change.kind}/${change.id}`, change.patch);

if (apply && changes.length) {
  for (let offset = 0; offset < changes.length; offset += 400) {
    const batch = db.batch();
    for (const change of changes.slice(offset, offset + 400)) {
      batch.update(change.ref, { ...change.patch, migratedAt: FieldValue.serverTimestamp() });
    }
    await batch.commit();
  }
  console.log("Migración completada.");
} else if (!apply) {
  console.log("No se escribió nada. Ejecuta con --apply después de revisar el listado.");
}
