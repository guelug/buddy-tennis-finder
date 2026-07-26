#!/usr/bin/env node
/**
 * Normalizes every non-canonical `i18n/*.json` catalog to the canonical English
 * key order. Adds new keys (in English) to incomplete locales so validation
 * can flag remaining translation gaps without blocking the build.
 *
 * `i18n/en.json` is treated as the canonical source and is NEVER modified.
 * `i18n/es.json` is also locked: it is the product source of truth and we
 * accept occasional key drift vs `en.json`; downstream tooling adds missing
 * keys to es.json on demand via a separate write script.
 */
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = resolve(root, "i18n");
const enPath = resolve(outDir, "en.json");
const en = JSON.parse(readFileSync(enPath, "utf8"));
const canonicalKeys = Object.keys(en);
let failed = false;

const lockedSources = new Set(["en.json", "es.json"]);

for (const file of readdirSync(outDir).filter((f) => f.endsWith(".json")).sort()) {
  if (lockedSources.has(file)) continue;
  const path = resolve(outDir, file);
  const dictionary = JSON.parse(readFileSync(path, "utf8"));
  for (const key of canonicalKeys) {
    if (!(key in dictionary)) dictionary[key] = en[key];
  }
  const ordered = Object.fromEntries(canonicalKeys.map((key) => [key, dictionary[key]]));
  writeFileSync(path, JSON.stringify(ordered, null, 2) + "\n", "utf8");
}

for (const file of readdirSync(outDir).filter((f) => f.endsWith(".json")).sort()) {
  if (lockedSources.has(file)) continue;
  const path = resolve(outDir, file);
  const dictionary = JSON.parse(readFileSync(path, "utf8"));
  const missing = canonicalKeys.filter((key) => dictionary[key] === en[key]);
  const extra = Object.keys(dictionary).filter((key) => !(key in en));
  const equal = Object.entries(dictionary).every(([key, value]) => en[key] === value);
  if (missing.length || extra.length) {
    failed = true;
    console.error(`✗ ${file}: missing ${missing.length}, extra ${extra.length}`);
    if (missing.length) console.error("  Missing:", missing.join(", "));
    if (extra.length) console.error("  Extra:", extra.join(", "));
  } else if (equal) {
    console.log(`· ${file} — ${canonicalKeys.length} keys (all English, needs translation)`);
  } else {
    console.log(`✓ ${file} — ${canonicalKeys.length} keys`);
  }
}

if (failed) process.exitCode = 1;
