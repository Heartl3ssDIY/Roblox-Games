from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root / 'After/Shell.Controller.luau').read_text(encoding='utf-8-sig')
installer = (root / 'InstallEmoteThumbnails.luau').read_text(encoding='utf-8-sig')
installer = installer.replace('return install(game:GetService("StarterGui"):WaitForChild("PlaygroundShell"), true)', 'local installed = install(fixture, false)')
body = source[source.index('local function setText('):source.index('dock.Shop.Activated:Connect')]
prefix = '''local gui = script.Parent.Fixture
local shop, wallet, pager = gui.ShopPanel, gui.Wallet, gui.ShopPanel.Pager
local emoteEmptyState = shop.EmoteEmptyState
local ink, white, gold = Color3.fromRGB(27,45,61), Color3.fromRGB(255,255,248), Color3.fromRGB(255,211,78)
local blue, pink, mint, muted = Color3.fromRGB(89,193,244), Color3.fromRGB(255,153,166), Color3.fromRGB(130,225,180), Color3.fromRGB(194,201,206)
local attrs = { PCDataReady = true }
local player = { GetAttribute = function(_, key) return attrs[key] end }
local data = { ready = true, coins = 20000, owned = {}, equipped = {}, unlocks = {} }
local category, page, pageCount = "Emotes", 1, 1
local busy, pendingStatus, lastUnlockSerial = false, false, nil
local slots, previews, calls = {}, {}, {}
local gameLabels = {}
local lastToast, remoteReply = nil, { ok = true }
local function showToast(message) lastToast = message end
local remote = { IsA = function(_, class) return class == "RemoteFunction" end }
function remote:InvokeServer(action, id)
 table.insert(calls, { action, id })
 if remoteReply == "error" then error("Simulated transport failure") end
 return remoteReply
end
local actualStorage = game:GetService("ReplicatedStorage")
local ReplicatedStorage = { FindFirstChild = function(_, name)
 if name == "PlaygroundShopRequest" then return remote end
 return actualStorage:FindFirstChild(name)
end }
local ContentProvider = { PreloadAsync = function() end }
local catalog = { Items = {}, ById = {} }
for index = 1, 32 do
 if index ~= 7 then
  local item = { id = string.format("E%02d", index), name = "Test Emote " .. index, slot = "Emote", category = "Emotes", catalogId = 3360689775, thumbnail = "", available = true, playable = true, price = 250, unlock = { kind = "Coins", amount = 250 } }
  table.insert(catalog.Items, item) catalog.ById[item.id] = item
 end
end
'''
checks = '''
local count = 0
local function check(value, message) assert(value, message) count += 1 end
local function visibleCards() local n=0 for _, r in ipairs(slots) do if r.card.Visible then n+=1 end end return n end
local rectangles = {}
for _,r in ipairs(slots) do rectangles[r.card] = {r.card.Position,r.card.Size,r.card.Preview.Position,r.card.Preview.Size} end
refreshCards()
check(#slots == 12 and pageCount == 3 and visibleCards() == 12, "31 emotes have first 12-card page")
check(slots[7].item.id == "E08", "Removed emote does not change stable IDs")
check(not emoteEmptyState.Visible and pager.Visible, "Catalog replaces empty state")
check(slots[1].card.Thumbnail.Visible and not slots[1].card.Preview.Visible, "Emotes use thumbnail, not model")
check(slots[1].card.Thumbnail.Image == "rbxthumb://type=Asset&id=3360689775&w=420&h=420", "Catalog ID thumbnail fallback")
check(slots[1].card.Try.Text == "INFO", "Unowned emotes retain INFO")
useOrInfo(slots[1])
check(#calls == 0 and lastToast ~= nil, "INFO never invokes an unowned emote")
page = 2 refreshCards()
check(visibleCards() == 12 and slots[1].item.id == "E14", "Second page uses next 12 cards")
page = 3 refreshCards()
check(visibleCards() == 7 and slots[7].item.id == "E32" and not slots[8].card.Thumbnail.Visible, "Last seven cards and stale thumbnail hiding")
data.owned.E01 = true data.equipped.Emote = "E01" page = 1 refreshCards()
check(slots[1].card.Try.Text == "PLAY" and slots[1].card.Try.Active, "Owned playable emote exposes PLAY")
check(slots[1].card.Action.Text == "UNEQUIP", "Existing equipped action retained")
shop.Visible = true gui.Backdrop.Visible = true remoteReply = {ok=false,message="Not in lobby"}
useOrInfo(slots[1]) task.wait()
check(calls[#calls][1] == "UseEmote" and calls[#calls][2] == "E01", "PLAY sends exact endpoint and stable ID")
check(shop.Visible and gui.Backdrop.Visible, "Rejected PLAY leaves shop open")
remoteReply = "error" useOrInfo(slots[1]) task.wait()
check(shop.Visible, "Transport failure leaves shop open")
remoteReply = {ok=true} useOrInfo(slots[1]) task.wait()
check(not shop.Visible and not gui.Backdrop.Visible, "Accepted PLAY closes both shop and modal backdrop")
check(string.find(lastToast, "Starting", 1, true) ~= nil, "Accepted request does not claim animation has loaded")
for _,name in ipairs({"BBParticipating","TGParticipating","MDParticipating"}) do
 attrs[name]=true refreshCards() local before=#calls useOrInfo(slots[1])
 check(not slots[1].card.Try.Active and #calls==before, "PLAY cannot run during "..name)
 attrs[name]=false
end
data.ready=false refreshCards() local before=#calls useOrInfo(slots[1])
check(not slots[1].card.Try.Active and #calls==before, "Data-not-ready blocks PLAY")
data.ready=true busy=true refreshCards() useOrInfo(slots[1])
check(#calls==before and not slots[1].card.Try.Active, "In-flight request blocks duplicate PLAY")
busy=false catalog.Items[1].playable=false refreshCards()
check(not slots[1].card.Action.Active and slots[1].card.Action.Text=="UNAVAILABLE" and slots[1].card.Try.Text=="INFO", "Unverified emote cannot be bought, equipped or played")
catalog.Items[1].playable=true
check(emoteThumbnail({thumbnail="rbxthumb://type=Asset&id=123&w=420&h=420",catalogId=456})=="rbxthumb://type=Asset&id=123&w=420&h=420", "Explicit catalog thumbnail has precedence")
check(emoteThumbnail({catalogId=0/0})=="" and emoteThumbnail({catalogId=-1})=="", "Invalid catalog IDs do not produce malformed URI")
local first=slots[1]
local world=first.card.Preview.World world.Parent=nil
renderPreview(first,{id="E99",slot="Emote",thumbnail=""})
check(first.card.Thumbnail.Visible and first.card.ThumbnailStatus.Text=="Preview unavailable", "Thumbnail does not require model world and missing URI has honest status")
world.Parent=first.card.Preview
local camera=first.card.Preview:FindFirstChild("PreviewCamera") if camera then camera:Destroy() end
renderPreview(first,{id="B01",slot="Bat"})
check(first.model~=nil and first.card.Preview.Visible and not first.card.Thumbnail.Visible and not first.card.ThumbnailStatus.Visible, "Model previews survive switching away from emotes")
check(first.card.Preview.CurrentCamera~=nil and first.card.Preview.CurrentCamera.Parent==first.card.Preview, "Missing client camera is recreated")
renderPreview(first,nil)
check(first.model==nil and not first.card.Preview.Visible and not first.card.Thumbnail.Visible, "Empty card clears both kinds of preview")
for card, rect in pairs(rectangles) do
 check(card.Position==rect[1] and card.Size==rect[2] and card.Preview.Position==rect[3] and card.Preview.Size==rect[4], "Runtime preserves authored rectangle "..card.Name)
end
for _,r in ipairs(slots) do r.previewToken=(r.previewToken or 0)+1 end
return {passed=count, cards=#slots, activeEmotes=#catalog.Items}
'''
test = '''assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local live = game.StarterGui.PlaygroundShell
local box = live.Controller:Clone()
box.Name = "_EmoteShopNativeChecks" box.Enabled = false box.Parent = game.ServerStorage
local fixture = live:Clone() fixture.Name = "Fixture" fixture.Parent = box
local ok, result = xpcall(function()
'''+installer+'''
assert(installed.cards == 13, "12 authored cards plus editable template")
local first = fixture.ShopPanel.Cards.Slot01
assert(first.Thumbnail.Position == first.Preview.Position and first.Thumbnail.Size == first.Preview.Size, "Thumbnail follows authored preview rectangle")
assert(first.Thumbnail.BackgroundTransparency == 1 and first.Thumbnail.BorderSizePixel == 0, "Thumbnail adds no background panel")
assert(first.ThumbnailStatus.TextOutline.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual, "Live status keeps text outline")
local childCount = #first:GetChildren()
local second = install(fixture, false)
assert(second.cards == 13 and #first:GetChildren() == childCount, "Installer is idempotent")
local module = Instance.new("ModuleScript") module.Name = "Checks" module.Source = [========[
'''+prefix+body+checks+''']========] module.Parent = box
local report = require(module)
report.capabilities = tostring(box.Capabilities)
report.exactLiveCapabilities = box.Capabilities == live.Controller.Capabilities
report.sandboxed = box.Sandboxed
return report
end, debug.traceback)
box:Destroy()
assert(ok, result)
return game:GetService("HttpService"):JSONEncode(result)
'''
(root / 'Tests/EmoteShopNativeChecks.luau').write_text(test, encoding='utf-8')
