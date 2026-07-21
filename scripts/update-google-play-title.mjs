import { existsSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { google } from "googleapis";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packageName = "com.matchpoint.clubs";
const language = "es-419";
const title = "MatchPoint Tennis";
const keyFile = path.join(rootDir, "credentials/google-play-service-account.json");

if (!process.argv.includes("--confirm")) {
  throw new Error("Añade --confirm para actualizar el nombre público en Google Play.");
}
if (!existsSync(keyFile)) {
  throw new Error(`No se encontró la cuenta de servicio: ${keyFile}`);
}

const auth = new google.auth.GoogleAuth({
  keyFile,
  scopes: ["https://www.googleapis.com/auth/androidpublisher"]
});
const publisher = google.androidpublisher({ version: "v3", auth });
let editId;

try {
  const edit = await publisher.edits.insert({ packageName, requestBody: {} });
  editId = edit.data.id;
  const current = await publisher.edits.listings.get({ packageName, editId, language });

  await publisher.edits.listings.update({
    packageName,
    editId,
    language,
    requestBody: {
      language,
      title,
      shortDescription: current.data.shortDescription,
      fullDescription: current.data.fullDescription,
      video: current.data.video
    }
  });
  await publisher.edits.commit({ packageName, editId });
  console.log(JSON.stringify({ packageName, language, title }, null, 2));
} catch (error) {
  if (editId) {
    await publisher.edits.delete({ packageName, editId }).catch(() => {});
  }
  throw error;
}
