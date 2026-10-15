"""Produce drop-in client modules from the audited live exports.

This does not edit Studio or the audit copies. Run after reviewing the live
versions; copy the four generated `.luau` files into ReplicatedStorage.
"""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
AUDIT = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\BattlePassConcept20260927\persistence-audit")
SHOP = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\PackUI20260922\scripts\ShopConfig.luau")
OUT = HERE / "client-facades"
OUT.mkdir(exist_ok=True)

COPY = '''
local function profileCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = profileCopy(child) end
    return result
end
'''

def insert_before_return(source: str, module_name: str, insertion: str) -> str:
    pattern = rf"(?m)^return {module_name}$"
    result, count = re.subn(pattern, lambda match: insertion + "\n" + match.group(0), source)
    assert count == 1, (module_name, count)
    return result

def write(name: str, source: str) -> None:
    (OUT / name).write_text(source, encoding="utf-8", newline="\n")

source = (AUDIT / "PlayerData.luau").read_text(encoding="utf-8")
source = source.replace('local PlayerData = {}', 'local PlayerData = {}\nlocal UnitData = require(game:GetService("ReplicatedStorage"):WaitForChild("UnitData"))', 1)
source = source.replace('Pikkolo = "locked",', 'Pikkolo = "locked",\n\t\tBeeras = "locked",', 1)
source = source.replace('Legendary = 25 }', 'Legendary = 25, Mythic = 25 }', 1)
source, unlock_count = re.subn(r'function PlayerData\.unitUnlockState\(id: string\): string\n.*?\nend', 'function PlayerData.unitUnlockState(id: string): string\n    local explicit = state.unitUnlock[id]\n    if explicit then return explicit end\n    local unit = UnitData.get(id)\n    return unit and unit.unlockable and "locked" or "owned"\nend', source, count=1, flags=re.S)
assert unlock_count == 1
mastery_block = '''function PlayerData.masteryThreshold(rarity: string): number
    -- Compatibility: level 2 begins at 40 points for every rarity.
    return 40
end

PlayerData.MASTERY_LEVEL_THRESHOLDS = {0, 40, 80, 150, 300, 500, 750, 1000, 1500, 2000}

function PlayerData.masteryLevel(id: string, rarity: string): number
    local points = math.max(0, PlayerData.masteryFor(id))
    for level = 10, 1, -1 do
        if points >= PlayerData.MASTERY_LEVEL_THRESHOLDS[level] then return level end
    end
    return 1
end

function PlayerData.masteryNextThreshold(id: string): number?
    local level = PlayerData.masteryLevel(id, "Common")
    return level < 10 and PlayerData.MASTERY_LEVEL_THRESHOLDS[level + 1] or nil
end

function PlayerData.masteryProgress(id: string)
    local level = PlayerData.masteryLevel(id, "Common")
    local points = math.max(0, PlayerData.masteryFor(id))
    local start = PlayerData.MASTERY_LEVEL_THRESHOLDS[level]
    local finish = PlayerData.masteryNextThreshold(id)
    if not finish then return 0, 0, level end
    return math.clamp(points - start, 0, finish - start), finish - start, level
end

function PlayerData.masteryUnlocked(id: string, rarity: string): boolean
    return PlayerData.masteryLevel(id, rarity) >= 2
end
'''
source, count = re.subn(r"function PlayerData\.masteryThreshold\(.*?PlayerData\.MASTERY_PER_MATCH", mastery_block + "\nPlayerData.MASTERY_PER_MATCH", source, count=1, flags=re.S)
assert count == 1
source = insert_before_return(source, "PlayerData", COPY + '''
function PlayerData._profileExport()
    return profileCopy(state)
end

function PlayerData._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "playerData snapshot required")
    state = profileCopy(snapshot)
    local function numberKeys(flags)
        if type(flags) ~= "table" then return end
        for key, value in pairs(flags) do
            local number = tonumber(key)
            if number then flags[number] = value end
        end
    end
    numberKeys(state.claimedLevels)
    for _, flags in pairs(state.claimedMilestones or {}) do numberKeys(flags) end
    numberKeys(state.dailyWin and state.dailyWin.claimed)
    fire()
end
''')
write("PlayerData.luau", source)

source = (AUDIT / "SeasonPassData.luau").read_text(encoding="utf-8")
source = source.replace('if state.claimed[lane][level] then return "claimed" end', 'if state.claimed[lane][tostring(level)] or state.claimed[lane][level] then return "claimed" end')
source = source.replace('if lane == "paid" and not state.premiumPreview then return "premium" end', 'if lane == "paid" and not state.premiumEntitled then return "premium" end')
source = insert_before_return(source, "SeasonPassData", COPY + '''
function SeasonPassData._profileExport()
    return profileCopy(state)
end

function SeasonPassData._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "seasonPass snapshot required")
    state = profileCopy(snapshot)
    changed:Fire(copyState())
end
''')
write("SeasonPassData.luau", source)

source = (AUDIT / "Loadout.luau").read_text(encoding="utf-8")
source = insert_before_return(source, "Loadout", COPY + '''
function Loadout._profileExport()
    return Loadout.getAll()
end

function Loadout._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "loadout snapshot required")
    equipped = profileCopy(snapshot)
    changed:Fire()
end
''')
write("Loadout.luau", source)

source = SHOP.read_text(encoding="utf-8")
source = source.replace('local ShopConfig = {}', 'local ShopConfig = {}\nlocal changed = Instance.new("BindableEvent")\nShopConfig.Changed = changed.Event')
source = source.replace('function ShopConfig.markClaimed(id) claims[id] = os.time() end', 'function ShopConfig.markClaimed(id) claims[id] = os.time(); changed:Fire() end')
source = insert_before_return(source, "ShopConfig", COPY + '''
function ShopConfig._profileExport()
    return profileCopy(claims)
end

function ShopConfig._profileHydrate(snapshot)
    assert(type(snapshot) == "table", "shopClaims snapshot required")
    claims = profileCopy(snapshot)
    changed:Fire()
end
''')
write("ShopConfig.luau", source)

print("Built", len(list(OUT.glob("*.luau"))), "client facades in", OUT)

