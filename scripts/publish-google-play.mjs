import { createReadStream, existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { google } from 'googleapis';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);

function option(name, fallback) {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
}

if (!args.includes('--confirm')) {
  throw new Error(
    'Publicación cancelada. Añade --confirm para confirmar el envío a Google Play.',
  );
}

const packageName = 'com.matchpoint.clubs';
const track = option('--track', 'alpha');
const status = option('--status', 'completed');
const uploadOnly = args.includes('--upload-only');
const existingVersionCode = option('--version-code');
const preserveExisting = args.includes('--preserve-existing');
const notes = option(
  '--notes',
  'Correcciones, mejoras de estabilidad y ajustes para la prueba cerrada.',
);
const requestedBundlePath = option('--bundle');
const builtBundlePath = path.join(
  rootDir,
  'android/app/build/outputs/bundle/release/app-release.aab',
);
const distributableBundlePath = path.join(
  rootDir,
  'dist/android/matchpoint-clubs-release.aab',
);
const bundlePath = path.resolve(
  requestedBundlePath ??
    (existsSync(distributableBundlePath)
      ? distributableBundlePath
      : builtBundlePath),
);
const keyFile = path.resolve(
  option(
    '--service-account',
    path.join(rootDir, 'credentials/google-play-service-account.json'),
  ),
);

for (const requiredPath of [keyFile, ...(existingVersionCode ? [] : [bundlePath])]) {
  if (!existsSync(requiredPath)) {
    throw new Error(`No se encontró el archivo requerido: ${requiredPath}`);
  }
}

const auth = new google.auth.GoogleAuth({
  keyFile,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});
const androidPublisher = google.androidpublisher({ version: 'v3', auth });

let editId;

try {
  console.log('Creando edición en Google Play...');
  const editResponse = await androidPublisher.edits.insert({
    packageName,
    requestBody: {},
  });
  editId = editResponse.data.id;
  let versionCode = existingVersionCode;
  if (versionCode) {
    console.log(`Usando el bundle ya subido con versionCode ${versionCode}.`);
  } else {
    console.log('Subiendo Android App Bundle...');
    const uploadResponse = await androidPublisher.edits.bundles.upload({
      packageName,
      editId,
      media: {
        mimeType: 'application/octet-stream',
        body: createReadStream(bundlePath),
      },
    });
    versionCode = String(uploadResponse.data.versionCode);
    console.log(`Bundle ${versionCode} subido.`);
  }

  if (!uploadOnly) {
    console.log(`Actualizando el canal ${track}...`);
    const existingReleases = preserveExisting
      ? (await androidPublisher.edits.tracks.get({ packageName, editId, track })).data.releases ?? []
      : [];
    await androidPublisher.edits.tracks.update({
      packageName,
      editId,
      track,
      requestBody: {
        track,
        releases: [
          ...existingReleases.filter((release) => !(release.versionCodes ?? []).includes(versionCode)),
          {
            name: `MatchPoint Tennis (${versionCode})`,
            versionCodes: [versionCode],
            status,
            releaseNotes: [{ language: 'es-419', text: notes }],
          },
        ],
      },
    });
  }

  console.log('Confirmando edición...');
  await androidPublisher.edits.commit({ packageName, editId });

  console.log(
    JSON.stringify(
      { packageName, track, status, versionCode, uploadOnly, bundlePath },
      null,
      2,
    ),
  );
} catch (error) {
  if (editId) {
    await androidPublisher.edits.delete({ packageName, editId }).catch(() => {});
  }
  throw error;
}
