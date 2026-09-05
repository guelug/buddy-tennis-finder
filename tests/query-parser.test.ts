import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const query = require("query-string");
const { getStateFromPath } = require("expo-router/build/react-navigation/core/getStateFromPath");
const { getPathFromState } = require("expo-router/build/react-navigation/core/getPathFromState");

test("el adaptador conserva la función CommonJS y queries legítimas", () => {
  assert.equal(typeof require("decode-uri-component"), "function");
  assert.deepEqual({ ...query.parse("name=Pedro+Gonz%C3%A1lez&code=ABC%20123&literal=%2B&empty=&flag") }, {
    name: "Pedro González", code: "ABC 123", literal: "+", empty: "", flag: null
  });
  assert.deepEqual({ ...query.parse("tag=single&tag=double&pct=%25&bad=%&bom=%FE%FF") }, {
    tag: ["single", "double"], pct: "%", bad: "%", bom: "\uFFFD\uFFFD"
  });
});

test("el core de navegación conserva parámetros y roundtrip de invitaciones", () => {
  const config = { screens: { "private-league": "private-league" } };
  const state = getStateFromPath("/private-league?id=liga-123&code=ABC%20123", config);
  assert.deepEqual(state.routes[0].params, { id: "liga-123", code: "ABC 123" });
  const restored = getStateFromPath(getPathFromState(state, config), config);
  assert.deepEqual(restored.routes[0].params, state.routes[0].params);
});

test("queries malformadas no bloquean el parser ni el core de navegación", () => {
  // Isolate the regression: an old decoder must fail this test by timeout,
  // not hang the complete test runner or CI indefinitely.
  const result = spawnSync(process.execPath, ["-e", `
    const assert = require('node:assert/strict');
    const query = require('query-string');
    const {getStateFromPath} = require('expo-router/build/react-navigation/core/getStateFromPath');
    for (const value of ['%FF'.repeat(1500), '%41%FF'.repeat(1000), '%E0%A4'.repeat(1000)]) {
      assert.equal(typeof query.parse('name=' + value).name, 'string');
      const state = getStateFromPath('/private-league?id=' + value, {screens: {'private-league': 'private-league'}});
      assert.equal(typeof state.routes[0].params.id, 'string');
    }
    const distinct = Array.from({length: 30000}, (_, i) =>
      [...('value' + i)].map(c => '%' + c.charCodeAt(0).toString(16)).join('')
    ).join('-') + '%FF';
    assert.ok(query.parse('name=' + distinct).name.endsWith('%FF'));
  `], { cwd: new URL("..", import.meta.url), timeout: 2000, encoding: "utf8" });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
});

test("el fallback no reinterpreta porcentajes decodificados y conserva Unicode válido", () => {
  const decode = require("decode-uri-component");
  assert.equal(decode("%25C2%FF"), "%C2%FF");
  assert.equal(decode("%25FE%25FF%FF"), "%FE%FF%FF");
  assert.equal(decode("%FE%FF%41"), "\uFFFD\uFFFDA");
  assert.equal(decode("%C2%41"), "\uFFFDA");
  for (const text of ["Español + tenis", "東京", "🎾", "100%", "a/b?c=d&x=y", "\u0080"]) {
    assert.equal(decode(encodeURIComponent(text)), text);
  }
});
