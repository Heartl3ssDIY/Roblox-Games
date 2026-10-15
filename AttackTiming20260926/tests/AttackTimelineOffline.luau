local timeline = require("../scripts/AttackTimeline")
local before = require("../before/UnitData")
local after = require("../scripts/UnitData")
local expected = {Yumcha = .60, Krillen = .60, Goku = 1.05, Tein = 1.05, Pikkolo = .82, Bluma = .72, MasterRoshu = 5.3}
local changed, checked = {}, 0

local function same(a, b, path)
    assert(type(a) == type(b), path .. ": type changed")
    if type(a) ~= "table" then
        assert(a == b, path .. ": changed")
        return
    end
    for key, value in pairs(a) do same(value, b[key], path .. "." .. tostring(key)) end
    for key in pairs(b) do assert(a[key] ~= nil, path .. ": unexpected field " .. tostring(key)) end
end

for id, old in pairs(before.all()) do
    local new = assert(after.get(id), "Unit removed: " .. id)
    checked += 1
    assert(new.hitSpeed == expected[id], "Unexpected cooldown: " .. id)
    for key, value in pairs(old) do
        if key ~= "hitSpeed" then same(value, new[key], id .. "." .. key) end
    end
    for key in pairs(new) do assert(old[key] ~= nil, id .. ": unexpected field " .. key) end
    if old.hitSpeed ~= new.hitSpeed then table.insert(changed, string.format('"%s":{"before":%s,"after":%s}', id, old.hitSpeed, new.hitSpeed)) end
    local profile = timeline.get(new.name, new.type, new.hitSpeed)
    assert(profile.releaseAt > 0 and profile.releaseAt < profile.duration, id .. ": invalid release phase")
    assert(profile.duration < profile.cooldown, id .. ": recovery overlaps next cooldown")
    assert(profile.cooldown == new.hitSpeed, id .. ": UI/combat cooldown mismatch")
    assert(profile.beamDuration >= 0 and profile.releaseAt + profile.beamDuration <= profile.duration, id .. ": blast exceeds animation")
    local another = timeline.get(new.name, new.type, new.hitSpeed)
    profile.cooldown = 10000
    assert(another.cooldown == new.hitSpeed, id .. ": shared mutable profile")
end
for id in pairs(after.all()) do assert(before.get(id), "Unit added: " .. id) end
assert(checked == 7, "Expected seven existing units")
local roshi = timeline.get("Master Roshu", "Tank", 5.3)
assert(roshi.releaseAt == 1.35 and roshi.duration == 2.25 and roshi.cooldown == 5.3 and roshi.beamDuration == .38, "Roshi timing mismatch")
local canonicalRoshi = timeline.get("Master Roshi", "Tank", 5.3)
assert(canonicalRoshi.kind == "Roshi", "Roshi alias not supported")
for _, invalid in ipairs({-1, 0, math.huge, -math.huge, 0 / 0}) do
    local profile = timeline.get("Unknown", "Ranged", invalid)
    assert(profile.cooldown >= profile.duration and profile.cooldown < math.huge, "Invalid input broke cooldown")
end
assert(timeline.get("Unknown", "Ranged", nil).cooldown >= .89, "Missing hitSpeed broke timing")
table.sort(changed)
print('{"passed":true,"unitsChecked":' .. checked .. ',"onlyHitSpeedChanged":true,"otherDataPreserved":true,"durationBelowCooldown":true,"uiMatchesCombatCooldown":true,"roshiCooldown":5.3,"profileInputsChecked":true,"changes":{' .. table.concat(changed, ",") .. '},"scope":"Offline pure Luau data/timeline validation; native engine harness pending."}')
