const LEVEL_COUNT = 45;
const XP_PER_LEVEL = 15;
const STORAGE_KEY = "acu-battle-pass-user-edit-v3";
// The remaining rewards have not been chosen, so those slots stay empty.
const REWARDS = {
  free: { 1: { label: "COINS", key: "coin" } },
  paid: { 1: { label: "DIAMONDS", key: "diamond" } }
};
const $ = (id) => document.getElementById(id);
const trackScroller = $("trackScroller");
const tierList = $("tierList");
const demoPanel = $("demoPanel");
const toast = $("toast");
let toastTimer;

function blankState() {
  return { completed: 0, currentXp: 0, trophies: 0, premium: false, freeClaimed: [], paidClaimed: [] };
}

function readState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (!saved || typeof saved !== "object") return blankState();
    const completed = Math.min(LEVEL_COUNT, Math.max(0, Math.floor(Number(saved.completed) || 0)));
    return {
      completed,
      currentXp: completed === LEVEL_COUNT ? XP_PER_LEVEL : Math.min(14, Math.max(0, Math.floor(Number(saved.currentXp) || 0))),
      trophies: Math.max(0, Math.floor(Number(saved.trophies) || 0)),
      premium: Boolean(saved.premium),
      freeClaimed: Array.isArray(saved.freeClaimed) ? saved.freeClaimed.filter(validLevel) : [],
      paidClaimed: Array.isArray(saved.paidClaimed) ? saved.paidClaimed.filter(validLevel) : []
    };
  } catch {
    return blankState();
  }
}

function validLevel(level) { return Number.isInteger(level) && level >= 1 && level <= LEVEL_COUNT; }
let state = readState();
function save() { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch {} }

function rewardFor(level, lane) {
  return REWARDS[lane][level] || null;
}

function rewardStatus(level, lane) {
  const claimed = lane === "free" ? state.freeClaimed : state.paidClaimed;
  if (claimed.includes(level)) return "claimed";
  if (lane === "paid" && !state.premium) return "premium-locked";
  return level <= state.completed ? "available" : "locked";
}

function makeRewardCell(level, lane) {
  const reward = rewardFor(level, lane);
  if (!reward) {
    const empty = document.createElement("div");
    empty.className = "reward-empty " + lane;
    empty.setAttribute("aria-hidden", "true");
    return empty;
  }
  const status = rewardStatus(level, lane);
  const button = document.createElement("button");
  button.type = "button";
  button.className = "reward-cell " + lane + " " + (status === "premium-locked" ? "locked" : status);
  button.dataset.level = String(level);
  button.dataset.lane = lane;
  button.setAttribute("aria-label", (lane === "free" ? "Free" : "Paid") + " level " + level + " " + reward.label + " preview reward, " + status.replace("-", " "));
  const stateLabel = status === "claimed" ? "CLAIMED" : status === "available" ? "CLAIM" : "LOCKED";
  button.innerHTML =
    '<img class="reward-icon icon-' + reward.key + '" src="./assets/reward-' + reward.key + '.png" alt="' + reward.label + '">' +
    '<strong class="reward-name">' + reward.label + '</strong>' +
    '<span class="reward-state">' + stateLabel + '</span>';
  button.addEventListener("click", () => claimReward(level, lane));
  return button;
}

function makeTier(level) {
  const tier = document.createElement("div");
  tier.className = "tier";
  tier.dataset.tier = String(level);
  tier.appendChild(makeRewardCell(level, "free"));
  const milestone = document.createElement("div");
  milestone.className = "milestone" + (level <= state.completed ? " complete" : "");
  milestone.innerHTML = "<span>" + level + "</span>";
  tier.appendChild(milestone);
  tier.appendChild(makeRewardCell(level, "paid"));
  return tier;
}

function render() {
  const scroll = trackScroller.scrollLeft;
  const fragment = document.createDocumentFragment();
  for (let level = 1; level <= LEVEL_COUNT; level++) fragment.appendChild(makeTier(level));
  tierList.replaceChildren(fragment);
  trackScroller.scrollLeft = scroll;
  const level = Math.min(LEVEL_COUNT, state.completed + 1);
  const shownXp = state.completed === LEVEL_COUNT ? XP_PER_LEVEL : state.currentXp;
  const percent = shownXp / XP_PER_LEVEL * 100;
  $("passLevel").textContent = state.completed === LEVEL_COUNT ? "PASS COMPLETE" : "LEVEL " + String(level).padStart(2, "0");
  $("xpText").textContent = shownXp + " / 15 PASS XP";
  $("progressRail").style.setProperty("--progress", percent + "%");
  $("progressRail").setAttribute("aria-valuenow", String(shownXp));
  if ($("progressFill")) $("progressFill").style.width = percent + "%";
  if ($("progressOrb")) $("progressOrb").style.left = percent + "%";
  if ($("premiumStatus")) {
    $("premiumStatus").textContent = state.premium ? "ACTIVE" : "LOCKED";
    $("premiumStatus").classList.toggle("active", state.premium);
  }
  $("premiumToggle").checked = state.premium;
  $("trophyValue").textContent = state.trophies.toLocaleString();
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2700);
}

function scrollToLevel(level) {
  const tier = tierList.querySelector('[data-tier="' + level + '"]');
  if (!tier) return;
  trackScroller.scrollTo({ left: Math.max(0, tier.offsetLeft - trackScroller.clientWidth / 2 + tier.clientWidth / 2), behavior: "smooth" });
}

function applyMatch(kind) {
  const previousCompleted = state.completed;
  if (kind === "win" || kind === "loss") {
    const earned = kind === "win" ? 5 : 2;
    state.trophies = Math.max(0, state.trophies + (kind === "win" ? 10 : -4));
    if (state.completed < LEVEL_COUNT) {
      state.currentXp += earned;
      while (state.currentXp >= XP_PER_LEVEL && state.completed < LEVEL_COUNT) {
        state.completed++;
        state.currentXp -= XP_PER_LEVEL;
      }
      if (state.completed === LEVEL_COUNT) state.currentXp = XP_PER_LEVEL;
    }
    showToast(kind === "win" ? "WIN · +5 PASS XP" : "LOSS · +2 PASS XP");
  } else {
    if (state.completed < LEVEL_COUNT) state.currentXp = Math.max(0, state.currentXp - 3);
    showToast("DESIGNER PREVIEW: FORFEIT");
  }
  save();
  render();
  if (state.completed > previousCompleted) {
    showToast("LEVEL " + String(state.completed).padStart(2, "0") + " UNLOCKED");
    scrollToLevel(state.completed);
  }
}

function claimReward(level, lane) {
  if (!rewardFor(level, lane)) return;
  const status = rewardStatus(level, lane);
  if (status === "claimed") { showToast("ALREADY CLAIMED"); return; }
  if (status === "premium-locked") { showToast("PAID PASS REQUIRED"); return; }
  if (status === "locked") { showToast("REACH LEVEL " + String(level).padStart(2, "0") + " TO UNLOCK"); return; }
  const claimed = lane === "free" ? state.freeClaimed : state.paidClaimed;
  claimed.push(level);
  save();
  render();
  showToast((lane === "free" ? "FREE" : "PAID") + " LEVEL " + String(level).padStart(2, "0") + " CLAIMED");
}

function showDemo(open) {
  demoPanel.hidden = !open;
  $("demoButton").setAttribute("aria-expanded", String(open));
}

$("demoButton").addEventListener("click", () => showDemo(demoPanel.hidden));
$("closeDemo").addEventListener("click", () => showDemo(false));
$("closePass").addEventListener("click", () => {
  $("passScreen").hidden = true;
  $("reopenPass").hidden = false;
  $("reopenPass").focus();
});
$("reopenPass").addEventListener("click", () => {
  $("passScreen").hidden = false;
  $("reopenPass").hidden = true;
  $("closePass").focus();
});
$("buyButton").addEventListener("click", () => showToast("PAID PASS PURCHASE: DESIGN PREVIEW ONLY"));
document.addEventListener("keydown", (event) => { if (event.key === "Escape") showDemo(false); });
$("winButton").addEventListener("click", () => applyMatch("win"));
$("lossButton").addEventListener("click", () => applyMatch("loss"));
$("forfeitButton").addEventListener("click", () => applyMatch("forfeit"));
$("premiumToggle").addEventListener("change", () => { state.premium = $("premiumToggle").checked; save(); render(); });
$("resetButton").addEventListener("click", () => { state = blankState(); save(); render(); trackScroller.scrollTo({ left: 0, behavior: "smooth" }); showToast("PREVIEW RESET"); });

let dragStart = null;
let suppressClickUntil = 0;
trackScroller.addEventListener("pointerdown", (event) => {
  if (event.pointerType === "touch") return;
  dragStart = { x: event.clientX, scroll: trackScroller.scrollLeft, moved: false };
});
trackScroller.addEventListener("pointermove", (event) => {
  if (!dragStart || !(event.buttons & 1)) return;
  const distance = event.clientX - dragStart.x;
  if (Math.abs(distance) > 4) dragStart.moved = true;
  trackScroller.scrollLeft = dragStart.scroll - distance;
});
function finishDrag() { if (dragStart?.moved) suppressClickUntil = performance.now() + 250; dragStart = null; }
trackScroller.addEventListener("pointerup", finishDrag);
trackScroller.addEventListener("pointerleave", finishDrag);
trackScroller.addEventListener("click", (event) => {
  if (performance.now() < suppressClickUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
}, true);

render();
Promise.all(["coin", "diamond"].map(async (key) => {
  const image = new Image();
  image.src = "./assets/reward-" + key + ".png";
  try { await image.decode(); } catch {}
})).then(render);
