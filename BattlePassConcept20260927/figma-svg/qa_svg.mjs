import { chromium } from "file:///C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { join } from "node:path";

const folder = fileURLToPath(new URL(".", import.meta.url));
const cases = [
  ["battle-pass-layout.svg", "qa-layout.png", 1440, 800],
  ["battle-pass-with-currency.svg", "qa-with-currency.png", 1440, 800],
  ["all-45-tiers.svg", "qa-all45-first.png", 1600, 480],
];
const browser = await chromium.launch({ headless: true, executablePath: "C:/Program Files/Google/Chrome/Application/chrome.exe" });
for (const [file, screenshot, width, height] of cases) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  await page.goto(pathToFileURL(join(folder, file)).href, { waitUntil: "load" });
  if (file === "all-45-tiers.svg") {
    await page.evaluate(() => {
      const svg = document.querySelector("svg");
      svg.setAttribute("width", "9000");
      svg.setAttribute("height", "480");
    });
  }
  const result = await page.evaluate(() => ({
    viewBox: document.querySelector("svg")?.getAttribute("viewBox"),
    groups: document.querySelectorAll("g[id]").length,
    images: document.querySelectorAll("image").length,
  }));
  await page.screenshot({ path: join(folder, screenshot) });
  console.log(file, JSON.stringify(result), errors.join(" | "));
  await page.close();
}
await browser.close();
