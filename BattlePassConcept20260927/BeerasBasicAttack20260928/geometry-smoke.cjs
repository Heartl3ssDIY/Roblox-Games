const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const combat = fs.readFileSync(path.join(__dirname, "CombatController.luau"), "utf8");
const timing = fs.readFileSync(path.join(__dirname, "AttackTimeline.luau"), "utf8");
const arena = fs.readFileSync(path.join(__dirname, "..", "ArenaScale20260928", "ArenaConfig.luau"), "utf8");
const ranges = combat.match(/local ranges = \{([^}]+)\}/)[1].split(",").map(Number);
const front = Number(arena.match(/lineZ = \{ front = (\d+)/)[1]);
const back = Number(arena.match(/back = (\d+)/)[1]);
const beamRadius = Number(combat.match(/BEERAS_BEAM_RADIUS = ([\d.]+)/)[1]);
const reach = ranges[2] + (back - front + 1);

assert.equal(ranges[2], 22);
assert.equal(reach, 43);
assert.match(timing, /profile\.releaseAt, profile\.duration = 2\.0, 2\.65/);
assert.match(timing, /profile\.cooldown, profile\.beamDuration = math\.max\(speed, 3\), 0\.45/);
assert.match(combat, /if unit\.data\.id == "Beeras" then/);
assert.match(combat, /damage\[hit\.unit\] = \(damage\[hit\.unit\] or 0\) \+ unit\.damage/);

function hit(enemy) {
    if (enemy.side !== "opponent" || !enemy.alive) return false;
    const dx = enemy.x;
    const attackerZ = front - ranges[2];
    const dz = enemy.z - attackerZ;
    const along = dz;
    const lateral = Math.abs(dx);
    return along >= 0 && along <= reach && lateral <= beamRadius + enemy.bodyRadius;
}
const enemy = (x, z, side = "opponent", alive = true) => ({x, z, side, alive, bodyRadius: 1});

assert.equal(hit(enemy(0, front)), true, "front line");
assert.equal(hit(enemy(0, 20)), true, "mid line");
assert.equal(hit(enemy(0, back)), true, "back line");
assert.equal(hit(enemy(6, 20)), false, "adjacent column");
assert.equal(hit(enemy(0, back + 2)), false, "beyond beam");
assert.equal(hit(enemy(0, -15)), false, "behind attacker");
assert.equal(hit(enemy(0, 20, "player")), false, "friendly");
assert.equal(hit(enemy(0, 20, "opponent", false)), false, "defeated");
assert.equal(hit(enemy(beamRadius + 1, 20)), true, "body edge intersects");
assert.equal(hit(enemy(beamRadius + 1.01, 20)), false, "body edge misses");

console.log("Beeras geometry and timing smoke checks passed.");
