import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent
old = root.parent / 'PriorityPass20261007'
snapshot = json.loads((root / 'CatalogLiveSnapshot.json').read_text(encoding='utf-8'))
before = snapshot['source']
source = before
prior = (old / 'After/PlaygroundCatalog.luau').read_text(encoding='utf-8')
schedule = json.loads((old / 'ExpansionUnlocks.json').read_text(encoding='utf-8'))
icons = json.loads((old / 'ExpansionIconAssets.json').read_text(encoding='utf-8'))
prices = {
    'B16': 36000, 'B18': 42000, 'B21': 55000, 'B22': 70000, 'B23': 85000, 'B25': 100000,
    'P21': 100000, 'P26': 36000, 'P27': 42000, 'P29': 75000, 'P30': 90000, 'P31': 48000, 'P33': 60000,
    'M16': 18000, 'M17': 33000, 'M18': 22500, 'M19': 20000, 'M20': 28000,
    'M21': 30000, 'M22': 24000, 'M23': 45000, 'M24': 60000, 'M25': 75000,
}
assert 'local COIN_PRICE_MULTIPLIER = 3' in before
assert 'item("B16"' not in before
source = source.replace('local COIN_PRICE_CAP = 50000', 'local COIN_PRICE_CAP = 100000', 1)
source = source.replace('gameId, description, color)', 'gameId, description, color, finalCoinPrice)', 1)
source = source.replace('if kind == "Coins" then amount = amount * COIN_PRICE_MULTIPLIER end', 'if kind == "Coins" and not finalCoinPrice then amount = amount * COIN_PRICE_MULTIPLIER end', 1)
lines = []
for entry in schedule:
    item_id = entry['id']
    line = next(line for line in prior.splitlines() if line.startswith('\titem("' + item_id + '"'))
    if entry['unlockKind'] == 'Coins':
        entry['price'] = entry['amount'] = prices[item_id]
        line, count = re.subn(r'("Coins", )\d+', lambda m: m[1] + str(entry['price']), line, count=1)
        assert count == 1
        line = line[:-2] + ', true),'
    lines.append(line)
source = source.replace('\n}\n\nlocal emoteAnimations = {}', '\n' + '\n'.join(lines) + '\n}\n\nlocal emoteAnimations = {}', 1)
source = source.replace('local suppliedThumbnails = {', 'local suppliedThumbnails = {\n' + '\n'.join('\t["' + key + '"] = "' + value + '",' for key, value in sorted(icons.items())), 1)
source = source.replace('byId.M09.toyActionPending = true', 'byId.M09.toyActionPending = true\nfor index = 16, 25 do\n\tbyId[string.format("M%02d", index)].toyActionPending = true\nend', 1)
for directory in ('Before', 'After'):
    (root / directory).mkdir(exist_ok=True)
(root / 'Before/PlaygroundCatalog.luau').write_bytes(before.encode('utf-8'))
(root / 'After/PlaygroundCatalog.luau').write_bytes(source.encode('utf-8'))
(root / 'ExpansionUnlocks.json').write_text(json.dumps(schedule, indent=2), encoding='utf-8')

def long_string(text):
    delimiter = '='
    while ']' + delimiter + ']' in text:
        delimiter += '='
    return '[' + delimiter + '[\n' + text + ']' + delimiter + ']'

ids = ', '.join(json.dumps(entry['id']) for entry in schedule)
install = '''local catalog = game:GetService("ReplicatedStorage"):WaitForChild("PlaygroundCatalog")
local before = BEFORE_SOURCE
local after = AFTER_SOURCE
if catalog.Source == after then return "Catalog already installed" end
assert(catalog.Source == before, "Catalog changed since the snapshot; refresh before applying")
local assets = game.ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
assert(assets, "Install the expansion models before the catalog")
for _, id in ipairs({ITEM_IDS}) do
    local model = assets:FindFirstChild(id, true)
    assert(model and model:IsA("Model"), "Missing expansion model: " .. id)
end
local backup = game.ServerStorage:FindFirstChild("ExpansionFinishBackup20261007")
if not backup then
    backup = Instance.new("Folder")
    backup.Name = "ExpansionFinishBackup20261007"
    backup.Parent = game.ServerStorage
end
assert(not backup:FindFirstChild("PlaygroundCatalog"), "Catalog backup already exists")
local original = catalog:Clone()
original.Parent = backup
catalog.Source = after
assert(catalog.Source == after, "Catalog installation verification failed")
return "Installed expansion catalog: 35 items; existing prices preserved; 100000 coin cap"
'''.replace('BEFORE_SOURCE', long_string(before)).replace('AFTER_SOURCE', long_string(source)).replace('ITEM_IDS', ids)
(root / 'InstallCatalog.luau').write_text(install, encoding='utf-8')

checks = '''local previous = (function()
BEFORE_SOURCE
end)()
local current = (function()
AFTER_SOURCE
end)()
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
assert(#previous.Items == 81, "Unexpected starting catalog count")
assert(#current.Items == 116, "Expansion catalog count")
for id, item in pairs(previous.ById) do assert(equal(item, current.ById[id]), "Changed existing item: " .. id) end
local count, coins, levels, wins, maxPrice, maxLevel = 0, 0, 0, 0, 0, 0
for _, item in ipairs(current.Items) do
    if not previous.ById[item.id] then
        count += 1
        assert(item.thumbnailSource == "UI-512" and item.thumbnail:match("^rbxassetid://%d+$"), "Missing PNG: " .. item.id)
        assert(item.assetId == item.id and item.available, "Unavailable expansion item: " .. item.id)
        if item.unlock.kind == "Coins" then
            coins += 1
            assert(item.price == item.unlock.amount and item.price > 0 and item.price <= 100000)
            maxPrice = math.max(maxPrice, item.price)
        elseif item.unlock.kind == "Level" then
            levels += 1
            assert(item.price == 0 and item.unlock.amount <= 500)
            maxLevel = math.max(maxLevel, item.unlock.amount)
        elseif item.unlock.kind == "Wins" then
            wins += 1
            assert(item.price == 0 and current.GameNames[item.unlock.gameId])
        else error("Invalid expansion unlock: " .. item.id) end
        if item.slot == "Gear" then assert(item.unlock.kind == "Coins" and item.toyActionPending) end
    end
end
assert(count == 35 and coins == 23 and levels == 8 and wins == 4)
assert(maxPrice == 100000 and maxLevel == 500)
assert(current.ById.B01.price == 0 and current.ById.B01.unlock.kind == "Starter")
assert(current.ById.E07 == nil, "Disabled emote returned")
assert(equal(previous.EmoteAnimations, current.EmoteAnimations), "Emote mappings changed")
assert(current.MaxCoinPrice == 100000 and current.MaxEquipmentCoinPrice == 100000)
return game:GetService("HttpService"):JSONEncode({passed=true, existingItemsPreserved=#previous.Items, newItems=count, coinUnlocks=coins, levelUnlocks=levels, winUnlocks=wins, maximumCoins=maxPrice, maximumLevel=maxLevel, thumbnails=35})
'''.replace('BEFORE_SOURCE', before).replace('AFTER_SOURCE', source)
(root / 'CatalogChecks.luau').write_text(checks, encoding='utf-8')
print('Prepared 35 additions and catalog checks; no Studio edits applied.')
