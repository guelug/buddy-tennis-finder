#!/usr/bin/env node
/**
 * Normalizes every `i18n/*.json` catalog to the canonical English key order.
 * Fails on missing/extra keys so runtime catalogs cannot silently drift.
 */
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = resolve(root, "i18n");
const files = readdirSync(outDir).filter((file) => file.endsWith(".json")).sort();
const en = JSON.parse(readFileSync(resolve(outDir, "en.json"), "utf8"));
const canonicalKeys = Object.keys(en);
let failed = false;

for (const file of files) {
  const path = resolve(outDir, file);
  const dictionary = JSON.parse(readFileSync(path, "utf8"));
  const missing = canonicalKeys.filter((key) => !(key in dictionary));
  const extra = Object.keys(dictionary).filter((key) => !(key in en));
  if (missing.length || extra.length) {
    failed = true;
    console.error(`✗ ${file}: missing ${missing.length}, extra ${extra.length}`);
    continue;
  }
  const ordered = Object.fromEntries(canonicalKeys.map((key) => [key, dictionary[key]]));
  writeFileSync(path, JSON.stringify(ordered, null, 2) + "\n", "utf8");
  console.log(`✓ ${file} — ${canonicalKeys.length} keys`);
}

if (failed) process.exitCode = 1;
