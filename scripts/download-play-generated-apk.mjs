import { createWriteStream, existsSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { finished } from "node:stream/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { google } from "googleapis";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packageName = "com.matchpoint.clubs";
const versionCode = Number(process.argv[2] ?? "3");
const outputPath = path.resolve(process.argv[3] ?? `/tmp/matchpoint-play-${versionCode}.apk`);
const keyFile = path.join(rootDir, "credentials/google-play-service-account.json");

if (!Number.isInteger(versionCode) || versionCode < 1) {
  throw new Error("El versionCode debe ser un entero positivo.");
}
if (!existsSync(keyFile)) {
  throw new Error(`No se encontró la cuenta de servicio: ${keyFile}`);
}

const auth = new google.auth.GoogleAuth({
  keyFile,
  scopes: ["https://www.googleapis.com/auth/androidpublisher"]
});
const publisher = google.androidpublisher({ version: "v3", auth });
const generated = await publisher.generatedapks.list({ packageName, versionCode });
const signingGroup = generated.data.generatedApks?.[0];

if (!signingGroup) {
  throw new Error(`Google Play no devolvió APKs generados para la versión ${versionCode}.`);
}

const baseSplit = signingGroup.generatedSplitApks?.find(
  (apk) => apk.moduleName === "base" && !apk.splitId
);
const candidate =
  signingGroup.generatedUniversalApk ??
  signingGroup.generatedStandaloneApks?.[0] ??
  baseSplit ??
  signingGroup.generatedSplitApks?.[0];

if (!candidate?.downloadId) {
  throw new Error("Google Play no devolvió un APK descargable.");
}

const response = await publisher.generatedapks.download(
  { packageName, versionCode, downloadId: candidate.downloadId, alt: "media" },
  { responseType: "arraybuffer" }
);
const payload = response.data;
if (payload && typeof payload.pipe === "function") {
  const output = createWriteStream(outputPath, { mode: 0o600 });
  payload.pipe(output);
  await finished(output);
} else {
  await writeFile(outputPath, Buffer.from(payload), { mode: 0o600 });
}

console.log(JSON.stringify({
  packageName,
  versionCode,
  certificateSha256Hash: signingGroup.certificateSha256Hash ?? null,
  outputPath
}, null, 2));
