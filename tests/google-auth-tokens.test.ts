import assert from "node:assert/strict";
import test from "node:test";
import { requireGoogleAuthTokens } from "../src/lib/google-auth-tokens";

test("normaliza los tokens de Google antes de cruzar el puente nativo", () => {
  assert.deepEqual(
    requireGoogleAuthTokens({
      idToken: "  identity-token  ",
      accessToken: "  access-token  "
    }),
    {
      idToken: "identity-token",
      accessToken: "access-token"
    }
  );
});

test("rechaza tokens vacíos para evitar el crash de Firebase Auth en Android", () => {
  assert.throws(
    () => requireGoogleAuthTokens({ idToken: "identity-token", accessToken: "" }),
    /token de acceso válido/
  );
  assert.throws(
    () => requireGoogleAuthTokens({ idToken: " ", accessToken: "access-token" }),
    /token de identidad válido/
  );
});
