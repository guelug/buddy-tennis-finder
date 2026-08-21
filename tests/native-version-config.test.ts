import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

type ExpoConfig = {
  expo: {
    version: string;
    ios: { buildNumber: string; bundleIdentifier: string };
    android: { versionCode: number; package: string };
  };
};

const appConfig = JSON.parse(readFileSync("app.json", "utf8")) as ExpoConfig;

test("iOS conserva la versión, build y bundle id declarados en app.json", () => {
  const project = readFileSync("ios/MatchPointTennis.xcodeproj/project.pbxproj", "utf8");

  assert.match(project, new RegExp(`MARKETING_VERSION = ${appConfig.expo.version.replaceAll(".", "\\.")};`));
  assert.match(project, new RegExp(`CURRENT_PROJECT_VERSION = ${appConfig.expo.ios.buildNumber};`));
  assert.match(project, new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${appConfig.expo.ios.bundleIdentifier.replaceAll(".", "\\.")};`));
});

test("Android toma versión y versionCode de app.json por defecto", () => {
  const gradle = readFileSync("android/app/build.gradle", "utf8");

  assert.match(gradle, /expoAppConfig\.expo\.android\.versionCode\.toString\(\)/);
  assert.match(gradle, /expoAppConfig\.expo\.version/);
  assert.match(gradle, new RegExp(`applicationId '${appConfig.expo.android.package.replaceAll(".", "\\.")}'`));
});
