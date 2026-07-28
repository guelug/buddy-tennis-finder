import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  GOOGLE_IOS_CLIENT_ID,
  GOOGLE_WEB_CLIENT_ID
} from "../src/lib/google-oauth-config";

test("los clientes OAuth compilados coinciden con Firebase Android e iOS", () => {
  const androidConfig = JSON.parse(readFileSync("google-services.json", "utf8")) as {
    client: Array<{
      oauth_client?: Array<{ client_id: string; client_type: number }>;
    }>;
  };
  const androidWebClients = androidConfig.client.flatMap((client) =>
    (client.oauth_client ?? [])
      .filter((oauth) => oauth.client_type === 3)
      .map((oauth) => oauth.client_id)
  );
  assert.ok(androidWebClients.includes(GOOGLE_WEB_CLIENT_ID));

  const iosConfig = readFileSync("GoogleService-Info.plist", "utf8");
  assert.match(iosConfig, new RegExp(`<string>${GOOGLE_IOS_CLIENT_ID.replaceAll(".", "\\.")}</string>`));
});
