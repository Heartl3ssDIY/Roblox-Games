-- Temporary compatibility path for client-local prototype modules.
-- The client remains an untrusted source for legacy shop/story/unit mutations.
-- Match outcome, pass progress, reward ledgers, entitlement and rank are server-owned.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(script.Parent.ProfileSchema)
local Delta = require(ReplicatedStorage:WaitForChild("ProfileDelta"))

local Sync = {}

function Sync.merge(profile, report, unitData)
    if type(report) ~= "table" or type(report.base) ~= "table" or type(report.current) ~= "table" then
        return false, "incomplete client delta"
    end
    local function isGated(id)
        if id == "Beeras" then return true end
        local unit = unitData.get(id)
        return unit and (unit.rarity == "Mythic" or unit.premium == true or unit.serverOnly == true or unit.storeOnly == true)
    end
    local merged = Delta.apply(report.base, report.current, Schema.clientSnapshot(profile), isGated)
    local normalized, reason = Schema.normalize(merged)
    if not normalized then return false, reason end
    for _, id in ipairs(normalized.loadout) do
        local unit = unitData.get(id)
        if not unit then return false, "unknown loadout unit" end
        local unlock = normalized.playerData.unitUnlock[id]
        if unlock ~= "owned" and (unlock ~= nil or unit.unlockable == true) then return false, "locked loadout unit" end
    end
    profile.playerData = normalized.playerData
    profile.loadout = normalized.loadout
    profile.shopClaims = normalized.shopClaims
    profile.seasonPass.premiumPreview = normalized.seasonPass.premiumPreview
    return true
end

return Sync


