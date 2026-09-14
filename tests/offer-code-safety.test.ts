import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

test("el canje no se ofrece sin vinculación segura a la cuenta", () => {
  const bridge = readFileSync("src/lib/offer-code.ts", "utf8");
  assert.match(bridge, /function canPresentOfferCode\(\): boolean \{[^}]*return false;/);
  assert.match(bridge, /if \(!canPresentOfferCode\(\)/);
  for (const kind of ["coach", "league"]) {
    const checkout = readFileSync(`src/components/${kind}-checkout.native.tsx`, "utf8");
    assert.match(checkout, /\{canPresentOfferCode\(\) \?/);
  }
});
