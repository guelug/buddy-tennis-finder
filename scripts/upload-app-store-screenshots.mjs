#!/usr/bin/env node

import { createHash, createPrivateKey, sign } from "node:crypto";
import { readFile, readdir, stat } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const apiBase = "https://api.appstoreconnect.apple.com";

await loadEnvironment(join(root, ".env.appstoreconnect"));

const localizationID =
  process.env.ASC_APP_STORE_VERSION_LOCALIZATION_ID ??
  "6607b78d-bf63-4537-b597-ee84812f78b7";

const screenshotGroups = [
  {
    displayType: "APP_IPHONE_67",
    directory: join(root, "AppStore", "Screenshots", "iPhone-6.9")
  },
  {
    displayType: "APP_IPAD_PRO_3GEN_129",
    directory: join(root, "AppStore", "Screenshots", "iPad-13")
  }
];

const keyID = required("ASC_KEY_ID");
const issuerID = required("ASC_ISSUER_ID");
const keyPath = required("ASC_KEY_PATH");
const privateKey = createPrivateKey(await readFile(keyPath, "utf8"));

for (const group of screenshotGroups) {
  const files = (await readdir(group.directory))
    .filter((name) => name.endsWith(".png"))
    .sort()
    .map((name) => join(group.directory, name));

  if (files.length === 0) {
    throw new Error(`No PNG screenshots found in ${group.directory}`);
  }

  const set = await findOrCreateScreenshotSet(group.displayType);
  await deleteExistingScreenshots(set.id);

  const screenshotIDs = [];
  for (const file of files) {
    const screenshot = await uploadScreenshot(set.id, file);
    screenshotIDs.push(screenshot.id);
    console.log(`Processed ${group.displayType}: ${basename(file)}`);
  }

  await api(`/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
    method: "PATCH",
    body: {
      data: screenshotIDs.map((id) => ({ type: "appScreenshots", id }))
    }
  });
}

console.log("App Store screenshots are uploaded and processed.");

async function findOrCreateScreenshotSet(displayType) {
  const response = await api(
    `/v1/appStoreVersionLocalizations/${localizationID}/appScreenshotSets?limit=50`
  );
  const existing = response.data.find(
    (item) => item.attributes.screenshotDisplayType === displayType
  );

  if (existing) {
    return existing;
  }

  const created = await api("/v1/appScreenshotSets", {
    method: "POST",
    body: {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: displayType },
        relationships: {
          appStoreVersionLocalization: {
            data: {
              type: "appStoreVersionLocalizations",
              id: localizationID
            }
          }
        }
      }
    }
  });

  return created.data;
}

async function deleteExistingScreenshots(setID) {
  const response = await api(
    `/v1/appScreenshotSets/${setID}/appScreenshots?limit=200`
  );

  for (const screenshot of response.data) {
    await api(`/v1/appScreenshots/${screenshot.id}`, { method: "DELETE" });
  }
}

async function uploadScreenshot(setID, file) {
  const fileData = await readFile(file);
  const fileInfo = await stat(file);
  const checksum = createHash("md5").update(fileData).digest("hex");

  const reservation = await api("/v1/appScreenshots", {
    method: "POST",
    body: {
      data: {
        type: "appScreenshots",
        attributes: {
          fileSize: fileInfo.size,
          fileName: basename(file)
        },
        relationships: {
          appScreenshotSet: {
            data: { type: "appScreenshotSets", id: setID }
          }
        }
      }
    }
  });

  const screenshot = reservation.data;
  for (const operation of screenshot.attributes.uploadOperations) {
    const headers = Object.fromEntries(
      operation.requestHeaders.map((header) => [header.name, header.value])
    );
    const body = fileData.subarray(
      operation.offset,
      operation.offset + operation.length
    );
    const response = await fetch(operation.url, {
      method: operation.method,
      headers,
      body
    });

    if (!response.ok) {
      throw new Error(
        `Screenshot part upload failed (${response.status}): ${await response.text()}`
      );
    }
  }

  await api(`/v1/appScreenshots/${screenshot.id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appScreenshots",
        id: screenshot.id,
        attributes: {
          uploaded: true,
          sourceFileChecksum: checksum
        }
      }
    }
  });

  await waitUntilProcessed(screenshot.id);
  return screenshot;
}

async function waitUntilProcessed(screenshotID) {
  const timeoutAt = Date.now() + 120_000;

  while (Date.now() < timeoutAt) {
    const response = await api(`/v1/appScreenshots/${screenshotID}`);
    const delivery = response.data.attributes.assetDeliveryState;
    const state = delivery?.state;

    if (state === "COMPLETE") {
      return;
    }
    if (state === "FAILED") {
      const errors = delivery.errors?.map((error) => error.description).join("; ");
      throw new Error(`Apple rejected screenshot ${screenshotID}: ${errors ?? "unknown error"}`);
    }

    await new Promise((resolveDelay) => setTimeout(resolveDelay, 2_000));
  }

  throw new Error(`Timed out while processing screenshot ${screenshotID}`);
}

async function api(path, options = {}) {
  const response = await fetch(`${apiBase}${path}`, {
    method: options.method ?? "GET",
    headers: {
      Authorization: `Bearer ${createToken()}`,
      ...(options.body ? { "Content-Type": "application/json" } : {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });

  if (response.status === 204) {
    return undefined;
  }

  const text = await response.text();
  const payload = text ? JSON.parse(text) : undefined;
  if (!response.ok) {
    const details = payload?.errors
      ?.map((error) => `${error.status} ${error.title}: ${error.detail}`)
      .join("\n");
    throw new Error(details ?? `App Store Connect request failed: ${response.status}`);
  }

  return payload;
}

function createToken() {
  const now = Math.floor(Date.now() / 1_000);
  const header = encodeJSON({ alg: "ES256", kid: keyID, typ: "JWT" });
  const payload = encodeJSON({
    iss: issuerID,
    iat: now - 5,
    exp: now + 1_200,
    aud: "appstoreconnect-v1"
  });
  const unsigned = `${header}.${payload}`;
  const signature = sign("sha256", Buffer.from(unsigned), {
    key: privateKey,
    dsaEncoding: "ieee-p1363"
  }).toString("base64url");

  return `${unsigned}.${signature}`;
}

function encodeJSON(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

async function loadEnvironment(file) {
  let contents;
  try {
    contents = await readFile(file, "utf8");
  } catch {
    return;
  }

  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }
    const separator = line.indexOf("=");
    if (separator < 1) {
      continue;
    }
    const name = line.slice(0, separator).trim();
    const value = line
      .slice(separator + 1)
      .trim()
      .replace(/^(['"])(.*)\1$/, "$2");
    process.env[name] ??= value;
  }
}

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing ${name} in .env.appstoreconnect`);
  }
  return value;
}
