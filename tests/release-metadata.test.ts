import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

test("la versión iOS usa la configuración de Xcode y coincide con Expo", () => {
  const root = new URL("../", import.meta.url);
  const { expo } = JSON.parse(readFileSync(new URL("app.json", root), "utf8"));
  const plist = readFileSync(new URL("ios/MatchPointTennis/Info.plist", root), "utf8");
  const project = readFileSync(new URL("ios/MatchPointTennis.xcodeproj/project.pbxproj", root), "utf8");
  assert.match(plist, /<key>CFBundleShortVersionString<\/key>\s*<string>\$\(MARKETING_VERSION\)<\/string>/);
  assert.match(plist, /<key>CFBundleVersion<\/key>\s*<string>\$\(CURRENT_PROJECT_VERSION\)<\/string>/);
  const versions = [...project.matchAll(/MARKETING_VERSION = ([^;]+);/g)].map((match) => match[1]);
  const builds = [...project.matchAll(/CURRENT_PROJECT_VERSION = ([^;]+);/g)].map((match) => match[1]);
  assert.ok(versions.length > 0 && builds.length > 0);
  versions.forEach((version) => assert.equal(version, expo.version));
  builds.forEach((build) => assert.equal(build, expo.ios.buildNumber));
});
