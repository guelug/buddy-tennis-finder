import { existsSync } from 'node:fs';
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

const packageName = option('--package', 'com.matchpoint.clubs');
const requestedTrack = option('--track', 'alpha');
const keyFile = path.resolve(
  option(
    '--service-account',
    path.join(rootDir, 'credentials/google-play-service-account.json'),
  ),
);

if (!existsSync(keyFile)) {
  throw new Error(`No se encontró la cuenta de servicio: ${keyFile}`);
}

const auth = new google.auth.GoogleAuth({
  keyFile,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});
const androidPublisher = google.androidpublisher({ version: 'v3', auth });

let editId;

try {
  const editResponse = await androidPublisher.edits.insert({
    packageName,
    requestBody: {},
  });
  editId = editResponse.data.id;

  if (!editId) {
    throw new Error('Google Play no devolvió un identificador de edición.');
  }

  const [trackResponse, bundlesResponse] = await Promise.all([
    androidPublisher.edits.tracks.get({
      packageName,
      editId,
      track: requestedTrack,
    }),
    androidPublisher.edits.bundles.list({ packageName, editId }),
  ]);

  const releases = (trackResponse.data.releases ?? []).map((release) => ({
    name: release.name ?? null,
    status: release.status ?? null,
    versionCodes: release.versionCodes ?? [],
    userFraction: release.userFraction ?? null,
    releaseNotes: release.releaseNotes ?? [],
  }));
  const bundles = (bundlesResponse.data.bundles ?? []).map((bundle) => ({
    versionCode: bundle.versionCode ?? null,
    sha256: bundle.sha256 ?? null,
  }));

  console.log(
    JSON.stringify(
      {
        checkedAt: new Date().toISOString(),
        packageName,
        track: trackResponse.data.track ?? requestedTrack,
        releases,
        bundles,
      },
      null,
      2,
    ),
  );
} finally {
  if (editId) {
    await androidPublisher.edits.delete({ packageName, editId }).catch(() => {});
  }
}
