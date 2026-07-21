const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "..");
const variants = ["dark", "light"];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1200, height: 360 } });

  for (const variant of variants) {
    const source = path.join(root, "assets/brand", `matchpoint-tennis-logo-${variant}.svg`);
    const output = path.join(root, "assets/brand", `matchpoint-tennis-logo-${variant}.png`);
    await page.goto(pathToFileURL(source).href);
    await page.screenshot({ path: output, omitBackground: true });
  }

  const shareSource = path.join(root, "assets/share", "matchpoint-share-banner.svg");
  const shareOutput = path.join(root, "assets/share", "matchpoint-share-banner.png");
  await page.setViewportSize({ width: 1080, height: 1350 });
  await page.goto(pathToFileURL(shareSource).href);
  await page.screenshot({ path: shareOutput, omitBackground: false });

  await browser.close();
})();
