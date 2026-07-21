import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/opt/homebrew/lib/node_modules/playwright/index.mjs";

const email = process.env.MATCHPOINT_REVIEW_EMAIL;
const password = process.env.MATCHPOINT_REVIEW_PASSWORD;
const baseUrl = process.env.MATCHPOINT_BASE_URL ?? "http://localhost:8081";

if (!email || !password) {
  throw new Error("Define MATCHPOINT_REVIEW_EMAIL y MATCHPOINT_REVIEW_PASSWORD.");
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = path.join(root, "store-assets", "screenshots");
const executablePath =
  process.env.PLAYWRIGHT_CHROMIUM_PATH ??
  "/Users/guelug/Library/Caches/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-mac-arm64/chrome-headless-shell";

const routes = [
  { name: "rivals", path: "/", button: "Rivales" },
  { name: "home", path: "/home", button: "Abrir inicio" },
  { name: "matches", path: "/matches", button: "Partidos" },
  { name: "ranking", path: "/liga", button: "Ranking" },
  { name: "profile", path: "/profile", button: "Perfil" }
];

async function settle(page) {
  await page.waitForLoadState("domcontentloaded");
  await page.waitForTimeout(3200);
}

async function captureSet(page, prefix, viewport) {
  await page.setViewportSize(viewport);
  await page.waitForTimeout(1000);
  for (const route of routes) {
    await page.getByRole("button", { name: route.button, exact: true }).last().click();
    await page.waitForFunction((expectedPath) => window.location.pathname === expectedPath, route.path);
    await settle(page);
    await page.screenshot({
      path: path.join(outputDir, `${prefix}-${route.name}.png`),
      fullPage: false
    });
  }
}

await fs.mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({ executablePath, headless: true });
try {
  const context = await browser.newContext({
    deviceScaleFactor: 2,
    viewport: { width: 540, height: 960 },
    colorScheme: "light"
  });
  const page = await context.newPage();

  await page.goto(`${baseUrl}/login`, { waitUntil: "domcontentloaded" });
  await settle(page);
  await page.getByRole("button", { name: "Continuar con correo y contraseña" }).click();
  await page.getByPlaceholder("Correo electrónico").fill(email);
  await page.getByPlaceholder("Contraseña").fill(password);
  await page.getByRole("button", { name: "Iniciar sesión", exact: true }).click();
  await page.waitForURL((url) => !url.pathname.endsWith("/login"), { timeout: 30000 });
  await settle(page);

  await captureSet(page, "phone", { width: 540, height: 960 });
  await captureSet(page, "tablet", { width: 960, height: 540 });

  await context.close();
} finally {
  await browser.close();
}

console.log(`Capturas guardadas en ${outputDir}`);
