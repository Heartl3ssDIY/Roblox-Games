-- Shared client/server rebase for the legacy prototype modules.
-- It applies the client's change relative to its last server snapshot onto
-- the latest server state, preserving server match/pass awards made meanwhile.
local Delta = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function numericChange(before, current, target, low, high)
    before = type(before) == "number" and before or 0
    current = type(current) == "number" and current or 0
    target = type(target) == "number" and target or 0
    local value = target + (current - before)
    if value ~= value or value == math.huge or value == -math.huge then return target end
    return math.clamp(math.floor(value), low or 0, high or 1000000000)
end

local function accountXpChange(baseLevel, baseXp, currentLevel, currentXp, targetLevel, targetXp)
    local function total(level, xp)
        level = math.clamp(math.floor(tonumber(level) or 1), 1, 200)
        local amount = math.max(0, tonumber(xp) or 0)
        for index = 1, level - 1 do
            amount += math.floor(100 * (1.25 ^ (index - 1)) + 0.5)
        end
        return amount
    end
    local earned = math.max(0, total(targetLevel, targetXp) + total(currentLevel, currentXp) - total(baseLevel, baseXp))
    local level = 1
    while level < 200 do
        local needed = math.floor(100 * (1.25 ^ (level - 1)) + 0.5)
        if earned < needed then break end
        earned -= needed
        level += 1
    end
    return level, math.floor(earned)
end

local function numberMap(before, current, target, maxValue, skip)
    before = type(before) == "table" and before or {}
    current = type(current) == "table" and current or {}
    target = type(target) == "table" and target or {}
    for key, value in pairs(current) do
        if type(key) == "string" and type(value) == "number" and not (skip and skip(key)) then
            target[key] = numericChange(before[key], value, target[key], 0, maxValue)
        end
    end
    for key, value in pairs(before) do
        if type(key) == "string" and type(value) == "number" and current[key] == nil and not (skip and skip(key)) then
            target[key] = numericChange(value, 0, target[key], 0, maxValue)
        end
    end
    return target
end

local function unionFlags(before, current, target)
    before = type(before) == "table" and before or {}
    current = type(current) == "table" and current or {}
    target = type(target) == "table" and target or {}
    for key, value in pairs(current) do
        if value == true and before[key] ~= true then target[tostring(key)] = true end
    end
    return target
end

local function timestamps(before, current, target)
    before = type(before) == "table" and before or {}
    current = type(current) == "table" and current or {}
    target = type(target) == "table" and target or {}
    for key, value in pairs(current) do
        if type(key) == "string" and type(value) == "number" and value > (before[key] or 0) then
            target[key] = math.max(target[key] or 0, value)
        end
    end
    return target
end

local function pendingKey(item)
    if type(item) ~= "table" then return nil end
    return tostring(item.packId) .. ":" .. tostring(item.day) .. ":" .. tostring(item.slot)
end

local function pendingChange(before, current, target)
    before = type(before) == "table" and before or {}
    current = type(current) == "table" and current or {}
    target = type(target) == "table" and target or {}
    local beforeCounts, currentCounts = {}, {}
    for _, item in ipairs(before) do local key = pendingKey(item); beforeCounts[key] = (beforeCounts[key] or 0) + 1 end
    for _, item in ipairs(current) do local key = pendingKey(item); currentCounts[key] = (currentCounts[key] or 0) + 1 end
    for key, count in pairs(beforeCounts) do
        local remove = count - (currentCounts[key] or 0)
        while remove > 0 do
            local found
            for index, item in ipairs(target) do
                if pendingKey(item) == key then found = index; break end
            end
            if not found then break end
            table.remove(target, found)
            remove -= 1
        end
    end
    for key, count in pairs(currentCounts) do
        local add = count - (beforeCounts[key] or 0)
        if add > 0 then
            for _, item in ipairs(current) do
                if pendingKey(item) == key and add > 0 then
                    table.insert(target, copy(item))
                    add -= 1
                end
            end
        end
    end
    return target
end

local UNLOCK_ORDER = {locked = 1, unlockable = 2, owned = 3}
function Delta.apply(base, current, authoritative, isGated)
    assert(type(base) == "table" and type(current) == "table" and type(authoritative) == "table", "snapshots required")
    local result = copy(authoritative)
    local old = type(base.playerData) == "table" and base.playerData or {}
    local changed = type(current.playerData) == "table" and current.playerData or {}
    local target = result.playerData
    for _, key in ipairs({"coins", "gems", "masteryChips"}) do
        target[key] = numericChange(old[key], changed[key], target[key], key == "level" and 1 or 0)
    end
    target.level, target.xp = accountXpChange(old.level, old.xp, changed.level, changed.xp, target.level, target.xp)
    for _, key in ipairs({"unitLevels", "unitXp", "masteryPoints", "packInventory"}) do
        local skip = key == "packInventory" and nil or isGated
        target[key] = numberMap(old[key], changed[key], target[key], key == "unitLevels" and 15 or key == "masteryPoints" and 2000 or nil, skip)
    end
    target.claimedLevels = unionFlags(old.claimedLevels, changed.claimedLevels, target.claimedLevels)
    target.dailyClaims = timestamps(old.dailyClaims, changed.dailyClaims, target.dailyClaims)
    old.claimedMilestones = old.claimedMilestones or {}
    changed.claimedMilestones = changed.claimedMilestones or {}
    target.claimedMilestones = target.claimedMilestones or {}
    for arena, flags in pairs(changed.claimedMilestones) do
        target.claimedMilestones[arena] = unionFlags(old.claimedMilestones[arena], flags, target.claimedMilestones[arena])
    end
    old.arenaProgress = old.arenaProgress or {}
    changed.arenaProgress = changed.arenaProgress or {}
    target.arenaProgress = target.arenaProgress or {}
    for arena, progress in pairs(changed.arenaProgress) do
        if type(arena) == "string" and type(progress) == "table" then
            local previous = old.arenaProgress[arena] or {}
            local row = target.arenaProgress[arena] or {points = 0, wins = 0, losses = 0}
            for _, key in ipairs({"points", "wins", "losses"}) do
                row[key] = numericChange(previous[key], progress[key], row[key], 0, key == "points" and 100 or nil)
            end
            if progress.completed == true and previous.completed ~= true then row.completed = true end
            target.arenaProgress[arena] = row
        end
    end
    old.unitUnlock = old.unitUnlock or {}
    changed.unitUnlock = changed.unitUnlock or {}
    target.unitUnlock = target.unitUnlock or {}
    for id, value in pairs(changed.unitUnlock) do
        if value ~= old.unitUnlock[id] and UNLOCK_ORDER[value] and not (isGated and isGated(id)) then
            local existing = target.unitUnlock[id]
            if (UNLOCK_ORDER[value] or 0) >= (UNLOCK_ORDER[existing] or 0) then target.unitUnlock[id] = value end
        end
    end
    old.unitLocks = old.unitLocks or {}
    changed.unitLocks = changed.unitLocks or {}
    target.unitLocks = target.unitLocks or {}
    for id, value in pairs(changed.unitLocks) do
        if value ~= old.unitLocks[id] and not (isGated and isGated(id)) then target.unitLocks[id] = value == true end
    end
    for id in pairs(old.unitLocks) do
        if changed.unitLocks[id] == nil and not (isGated and isGated(id)) then target.unitLocks[id] = nil end
    end
    -- Daily win slots and pending pack claims are issued and consumed only by
    -- validated server actions. Client day rollover must never reset them.
    result.playerData = target
    if not same(base.loadout, current.loadout) then result.loadout = copy(current.loadout) end
    result.shopClaims = timestamps(base.shopClaims, current.shopClaims, result.shopClaims)
    local oldPass = base.seasonPass or {}
    local currentPass = current.seasonPass or {}
    if currentPass.premiumPreview ~= oldPass.premiumPreview then
        result.seasonPass.premiumPreview = currentPass.premiumPreview == true
    end
    -- Pass XP, trophies, free reward ledger, paid entitlement, rank and match
    -- totals stay server-owned and cannot be changed through snapshot sync.
    return result
end

return Delta
