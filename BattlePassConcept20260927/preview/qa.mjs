import { chromium } from "file:///C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs";

const browser = await chromium.launch({
  headless: true,
  executablePath: "C:/Program Files/Google/Chrome/Application/chrome.exe"
});
const errors = [];
const origin = "http://127.0.0.1:8875/";
const check = (condition, message) => { if (!condition) errors.push(message); };
const textOf = (page, selector) => page.locator(selector).textContent();
const waitForArt = async (page) => {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((image) => image.decode().catch(() => {})));
    await Promise.all(["coin", "diamond"].map(async (name) => {
      const image = new Image();
      image.src = "./assets/reward-" + name + ".png";
      await image.decode();
    }));
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
};

const desktop = await browser.newPage({ viewport: { width: 1440, height: 850 }, deviceScaleFactor: 1 });
desktop.on("pageerror", (error) => errors.push("Desktop page error: " + error.message));
desktop.on("response", (response) => {
  if (response.status() >= 400) errors.push("Desktop HTTP " + response.status() + " " + response.url());
});
await desktop.goto(origin, { waitUntil: "networkidle" });
await desktop.evaluate(() => localStorage.clear());
await desktop.reload({ waitUntil: "networkidle" });
await desktop.locator(".tier").first().waitFor();
await waitForArt(desktop);

check(await desktop.locator(".tier").count() === 45, "Expected 45 reward-track tiers");
check(await desktop.locator(".milestone").count() === 45, "Expected 45 numbered milestones");
check(await desktop.locator(".reward-cell.free").count() === 1, "Only level 1 should have a free reward card");
check(await desktop.locator(".reward-cell.paid").count() === 1, "Only level 1 should have a paid reward card");
check(await desktop.locator(".reward-empty").count() === 88, "Unspecified levels 2–45 should have blank free and paid slots");
check(await textOf(desktop, '.reward-cell.free[data-level="1"] .reward-name') === "COINS", "Level 1 free reward should use coins");
check(await textOf(desktop, '.reward-cell.paid[data-level="1"] .reward-name') === "DIAMONDS", "Level 1 paid reward should use diamonds");
const art = await desktop.evaluate(() => {
  return ["coin", "diamond"].map((name) => {
    const image = document.querySelector(".icon-" + name);
    return { name, complete: image.complete, width: image.naturalWidth, source: image.currentSrc };
  });
});
console.log("Reward art:", JSON.stringify(art));
check(art.every((item) => item.complete && item.width > 0 && item.source.includes("reward-" + item.name)), "Supplied coin/diamond art should render on cards");
check((await textOf(desktop, "#buyButton")).includes("1499"), "Paid lane should show the user's 1499 mockup label");
const scroller = desktop.locator("#trackScroller");
check(await scroller.evaluate((el) => el.scrollWidth > el.clientWidth), "The 45 levels should scroll sideways");
await desktop.screenshot({ path: "./qa-desktop.png", fullPage: true });

await desktop.locator("#buyButton").click();
check((await textOf(desktop, "#toast")).includes("DESIGN PREVIEW ONLY"), "1499 button should preview a message, not a purchase");
check(!(await desktop.locator("#premiumToggle").isChecked()), "1499 button should not unlock paid rewards");
await desktop.locator("#closePass").click();
check(await desktop.locator("#passScreen").isHidden(), "Close button should hide the pass panel");
check(await desktop.locator("#reopenPass").isVisible(), "Close button should show a way to reopen");
await desktop.locator("#reopenPass").click();
check(await desktop.locator("#passScreen").isVisible(), "Reopen button should restore the pass panel");

await desktop.locator("#demoButton").click();
for (let i = 0; i < 3; i++) await desktop.locator("#winButton").click();
check(await textOf(desktop, "#passLevel") === "LEVEL 02", "Three wins should complete level 1");
check(await textOf(desktop, "#xpText") === "0 / 15 PASS XP", "Level 2 should start at 0/15 XP");
check(await textOf(desktop, "#trophyValue") === "30", "Three wins should give 30 trophies");
const freeOne = desktop.locator('.reward-cell.free[data-level="1"]');
const paidOne = desktop.locator('.reward-cell.paid[data-level="1"]');
check(await freeOne.evaluate((el) => el.classList.contains("available")), "Level 1 free reward should become available");
check(await paidOne.evaluate((el) => el.classList.contains("locked")), "Level 1 paid reward should remain locked before premium access");
await paidOne.click();
check((await textOf(desktop, "#toast")).includes("PAID PASS REQUIRED"), "Paid reward should explain its lock");
await freeOne.click();
check(await freeOne.evaluate((el) => el.classList.contains("claimed")), "Free level 1 reward should claim");
await desktop.locator("#premiumToggle").check();
check(await paidOne.evaluate((el) => el.classList.contains("available")), "Designer premium toggle should unlock earned paid reward");
await paidOne.click();
check(await paidOne.evaluate((el) => el.classList.contains("claimed")), "Paid level 1 reward should claim");
await desktop.locator("#lossButton").click();
check(await textOf(desktop, "#xpText") === "2 / 15 PASS XP", "Loss should give 2 pass XP");
check(await textOf(desktop, "#trophyValue") === "26", "Loss should remove 4 trophies");
await desktop.locator("#forfeitButton").click();
check(await textOf(desktop, "#xpText") === "0 / 15 PASS XP", "Forfeit should remove at most current-level XP");
check(await textOf(desktop, "#passLevel") === "LEVEL 02", "Forfeit should never roll back a completed level");
await scroller.evaluate((el) => { el.scrollLeft = el.scrollWidth; });
check(await scroller.evaluate((el) => el.scrollLeft > 0), "Reward track should reach the later levels");
check(await desktop.locator('.tier[data-tier="45"] .milestone').count() === 1, "Last milestone should be level 45");
await desktop.screenshot({ path: "./qa-interactive.png", fullPage: true });

for (const width of [390, 320]) {
  const phone = await browser.newPage({ viewport: { width, height: 800 }, deviceScaleFactor: 1 });
  phone.on("pageerror", (error) => errors.push(width + "px page error: " + error.message));
  phone.on("response", (response) => {
    if (response.status() >= 400) errors.push(width + "px HTTP " + response.status() + " " + response.url());
  });
  await phone.goto(origin, { waitUntil: "networkidle" });
  await phone.locator(".tier").first().waitFor();
  await waitForArt(phone);
  check(await phone.locator(".tier").count() === 45, width + "px should retain 45 tiers");
  check(await phone.locator("#passScreen").isVisible(), width + "px pass panel should be visible");
  check(!(await phone.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1)), width + "px has page-level horizontal overflow");
  await phone.screenshot({ path: "./qa-" + width + ".png", fullPage: true });
  await phone.close();
}

await browser.close();
if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else {
  console.log("PASS: edited layout, 45 scrollable milestones, only level 1 supplied art, match math and claims, safe 1499 preview, close/reopen, desktop and mobile");
}
