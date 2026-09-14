# Temporary CommonJS compatibility adapter

Source: https://github.com/SamVerschueren/decode-uri-component/blob/v0.5.0/index.js
License: MIT, included in `license`.

Expo Router 57 uses query-string 7, which calls the result of `require('decode-uri-component')` as a function. Upstream 0.5.0 fixes GHSA-vcc3-ghjq-m6fr but is ESM-only; a direct npm override breaks that contract. This fork uses its UTF-8 scanner with a CommonJS export and the legacy 0.2.x plus-to-space conversion.

Additional hardening: upstream still uses repeated global replacement for distinct encoded runs, which is quadratic. This fork invokes the scanner directly and applies malformed BOM/incomplete `%C2` handling while consuming original bytes. It never decodes an emitted percent sign a second time. Valid URI results are unchanged; malformed runs are decoded locally, without the upstream replacement-order side effects. Regression tests cover both long malformed runs and many distinct fragments.

The normal Expo Router linking fork currently uses URLSearchParams. This override also protects its compatibility React Navigation core and future query-string consumers. It is not evidence that every app link previously reached the affected decoder.

Remove the adapter when the installed Expo Router dependency tree supplies a patched CommonJS-compatible decoder or no longer uses query-string 7. Keep the query parser regression tests when removing it.
