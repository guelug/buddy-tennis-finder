#!/usr/bin/env node
import { readFile, readdir } from "node:fs/promises";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const localesDir = resolve(root, "i18n");
const baseFile = resolve(localesDir, "en.json");
const placeholders = /\{[A-Za-z0-9_]+\}/g;

const files = (await readdir(localesDir))
  .filter((name) => name.endsWith(".json"))
  .sort((a, b) => a.localeCompare(b));

if (!files.includes("en.json")) throw new Error("Missing canonical locale i18n/en.json");

const base = JSON.parse(await readFile(baseFile, "utf8"));
const baseKeys = Object.keys(base);
let failed = false;

for (const file of files) {
  const locale = JSON.parse(await readFile(resolve(localesDir, file), "utf8"));
  const keys = Object.keys(locale);
  const missing = baseKeys.filter((key) => !(key in locale));
  const extra = keys.filter((key) => !(key in base));
  const orderMatches = keys.length === baseKeys.length && keys.every((key, index) => key === baseKeys[index]);
  const placeholderErrors = baseKeys.filter((key) => {
    const expected = [...String(base[key]).matchAll(placeholders)].map(([token]) => token).sort();
    const actual = [...String(locale[key] ?? "").matchAll(placeholders)].map(([token]) => token).sort();
    return expected.join("\u0000") !== actual.join("\u0000");
  });
  const invalidValues = keys.filter((key) => typeof locale[key] !== "string" || locale[key].length === 0);
  const valid = missing.length === 0
    && extra.length === 0
    && orderMatches
    && placeholderErrors.length === 0
    && invalidValues.length === 0;
  failed ||= !valid;

  console.log(
    `${valid ? "✓" : "✗"} ${basename(file, ".json").padEnd(5)} ${String(keys.length).padStart(3)} keys` +
    ` · missing ${missing.length}` +
    ` · extra ${extra.length}` +
    ` · placeholders ${placeholderErrors.length}` +
    ` · invalid ${invalidValues.length}` +
    ` · order ${orderMatches ? "ok" : "mismatch"}`
  );
  if (missing.length) console.error("  Missing:", missing.join(", "));
  if (extra.length) console.error("  Extra:", extra.join(", "));
  if (placeholderErrors.length) console.error("  Placeholder mismatch:", placeholderErrors.join(", "));
  if (invalidValues.length) console.error("  Empty/non-string:", invalidValues.join(", "));
}

console.log(`\n${files.length} locale files checked against ${baseKeys.length} canonical keys.`);
if (failed) process.exitCode = 1;
