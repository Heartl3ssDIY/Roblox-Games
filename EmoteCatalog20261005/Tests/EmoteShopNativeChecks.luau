assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local live = game.StarterGui.PlaygroundShell
local box = live.Controller:Clone()
box.Name = "_EmoteShopNativeChecks" box.Enabled = false box.Parent = game.ServerStorage
local fixture = live:Clone() fixture.Name = "Fixture" fixture.Parent = box
local ok, result = xpcall(function()
local function install(shell, backup)
	assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
	local shop = shell:WaitForChild("ShopPanel")
	if backup then
		local storage = game:GetService("ServerStorage")
		if not storage:FindFirstChild("EmoteShopUIBackup20261005") then
			local folder = Instance.new("Folder")
			folder.Name = "EmoteShopUIBackup20261005"
			local copy = shop:Clone()
			copy.Parent = folder
			shell.Templates.ItemCard:Clone().Parent = folder
			folder.Parent = storage
		end
	end
	local cards = { shell.Templates.ItemCard }
	for _, card in ipairs(shop.Cards:GetChildren()) do
		if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then table.insert(cards, card) end
	end
	for _, card in ipairs(cards) do
		local preview = card.Preview
		local thumbnail = card:FindFirstChild("Thumbnail")
		if not thumbnail then
			thumbnail = Instance.new("ImageLabel")
			thumbnail.Name = "Thumbnail"
			thumbnail.AnchorPoint = preview.AnchorPoint
			thumbnail.Position = preview.Position
			thumbnail.Size = preview.Size
			thumbnail.Rotation = preview.Rotation
			thumbnail.ZIndex = preview.ZIndex
			thumbnail.BackgroundTransparency = 1
			thumbnail.BorderSizePixel = 0
			thumbnail.Image = ""
			thumbnail.ScaleType = Enum.ScaleType.Fit
			thumbnail.Visible = false
			thumbnail:SetAttribute("EmoteThumbnail", true)
			thumbnail.Parent = card
		end
		if not card:FindFirstChild("ThumbnailStatus") then
			local status = card.Category:Clone()
			status.Name = "ThumbnailStatus"
			status.AnchorPoint = preview.AnchorPoint
			status.Position = preview.Position
			status.Size = preview.Size
			status.Rotation = preview.Rotation
			status.ZIndex = preview.ZIndex + 1
			status.BackgroundTransparency = 1
			status.BorderSizePixel = 0
			status.Text = "Loading preview..."
			status.TextColor3 = Color3.fromRGB(255, 255, 248)
			status.TextStrokeTransparency = 1
			status.TextXAlignment = Enum.TextXAlignment.Center
			status.TextYAlignment = Enum.TextYAlignment.Center
			status.TextScaled = true
			status.TextWrapped = true
			status.Visible = false
			local limit = status:FindFirstChildOfClass("UITextSizeConstraint")
			if limit then limit.MinTextSize = 10 limit.MaxTextSize = 16 end
			local stroke = status:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stroke.Color = Color3.fromRGB(27, 45, 61)
				stroke.Thickness = 1.5
				stroke.Transparency = 0
			end
			status.Parent = card
		end
	end
	return { cards = #cards, thumbnails = #cards, templateIncluded = true }
end

local installed = install(fixture, false)

assert(installed.cards == 13, "12 authored cards plus editable template")
local first = fixture.ShopPanel.Cards.Slot01
assert(first.Thumbnail.Position == first.Preview.Position and first.Thumbnail.Size == first.Preview.Size, "Thumbnail follows authored preview rectangle")
assert(first.Thumbnail.BackgroundTransparency == 1 and first.Thumbnail.BorderSizePixel == 0, "Thumbnail adds no background panel")
assert(first.ThumbnailStatus.TextOutline.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual, "Live status keeps text outline")
local childCount = #first:GetChildren()
local second = install(fixture, false)
assert(second.cards == 13 and #first:GetChildren() == childCount, "Installer is idempotent")
local module = Instance.new("ModuleScript") module.Name = "Checks" module.Source = [========[
local gui = script.Parent.Fixture
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
local function setText(label, value)
	label.Text = value
	local caption = label:FindFirstChild("LiveCaption")
	if caption and caption:IsA("TextLabel") then caption.Text = value end
end

local function refreshWallet()
	local coins = data.ready and tostring(data.coins or 0) or "..."
	wallet.Coins.Text = coins
	wallet.Wins.Text = data.ready and tostring(player:GetAttribute("PCWins") or 0) or "..."
	wallet.Level.Text = data.ready and tostring(player:GetAttribute("PCLevel") or 1) or "..."
	shop.Coins.Text = coins .. " coins"
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.card.Preview
	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera or not camera:IsA("Camera") then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = viewport:GetAttribute("PreviewFieldOfView") or 35
		camera.Parent = viewport
	end
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local radius = record.radius
	local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
	local direction = Vector3.new(0.5, 0.2, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function emotePlayable(item)
	return item and item.slot == "Emote" and item.playable == true and item.available ~= false
end

local function emoteInLobby()
	return player:GetAttribute("BBParticipating") ~= true
		and player:GetAttribute("TGParticipating") ~= true
		and player:GetAttribute("MDParticipating") ~= true
end

local function emoteThumbnail(item)
	if typeof(item.thumbnail) == "string" and item.thumbnail ~= "" then return item.thumbnail end
	local id = item.catalogId
	if typeof(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0 then
		return "rbxthumb://type=Asset&id=" .. string.format("%.0f", id) .. "&w=420&h=420"
	end
	return ""
end

local function refreshThumbnail(record)
	local thumbnail = record.card.Thumbnail
	local status = record.card.ThumbnailStatus
	status.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	status.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "Preview unavailable" or "Loading preview..."
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	if record.previewId == id and (not id or record.model or item.slot == "Emote" and record.card.Thumbnail.Image == emoteThumbnail(item)) then return end
	record.previewId = nil
	record.previewToken = (record.previewToken or 0) + 1
	local token = record.previewToken
	record.card.Thumbnail.Visible = false
	record.card.ThumbnailStatus.Visible = false
	record.card.Preview.Visible = item ~= nil and item.slot ~= "Emote"
	if record.model then record.model:Destroy() end
	record.model = nil
	previews[record] = nil
	local world = record.card.Preview:FindFirstChild("World")
	if world then for _, child in ipairs(world:GetChildren()) do child:Destroy() end end
	if not item then return end
	if item.slot == "Emote" then
		record.previewId = id
		record.thumbnailTimedOut = false
		record.card.Thumbnail.Image = emoteThumbnail(item)
		record.card.Thumbnail.Visible = true
		refreshThumbnail(record)
		task.delay(8, function()
			if record.previewToken == token and record.card.Parent then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
		return
	end
	if not world then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then return end
	local model = original:Clone()
	model.Name = "ItemModel"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = visibleBounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.previewId = id
	record.pivot = model:GetPivot()
	record.radius = math.max(0.01, size.Magnitude * 0.5)
	previews[record] = record
	framePreview(record)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ model }) end)
		if record.model == model and world.Parent then
			model.Parent = nil
			model.Parent = world
			framePreview(record)
		end
	end)
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "Coins" then return tostring(item.price or rule.amount or 0) .. " coins", item.category end
	local progress = unlock and unlock.progress or 0
	local target = rule.amount or 0
	if rule.kind == "Level" then return "Level " .. tostring(target), tostring(math.min(progress, target)) .. " / " .. tostring(target) end
	return tostring(target) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins", tostring(math.min(progress, target)) .. " / " .. tostring(target)
end

local function isEquipped(item)
	if item.slot == "Gear" and typeof(data.equipped.Toys) == "table" then
		return table.find(data.equipped.Toys, item.id) ~= nil
	end
	return data.equipped[item.slot] == item.id
end

local function refreshCards()
	refreshWallet()
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = #filtered > 0
	pageCount = math.max(1, math.ceil(#filtered / math.max(1, #slots)))
	page = math.clamp(page, 1, pageCount)
	setText(pager.PageLabel, tostring(page) .. " / " .. tostring(pageCount))
	for _, spec in ipairs({ { pager.Previous, page > 1 }, { pager.Next, page < pageCount } }) do
		spec[1].Active = spec[2] and not busy
		spec[1].Selectable = spec[1].Active
		spec[1].BackgroundColor3 = spec[1].Active and blue or muted
	end
	for index, record in ipairs(slots) do
		local item = filtered[(page - 1) * #slots + index]
		local card = record.card
		record.item = item
		card.Visible = item ~= nil
		renderPreview(record, item)
		if item then
			card:SetAttribute("CatalogId", item.id)
			setText(card:FindFirstChild("Name"), item.name)
			local owned = data.owned[item.id] == true
			local equipped = isEquipped(item)
			local unlock = data.unlocks[item.id]
			local price, detail = requirement(item, unlock)
			setText(card.Price, owned and (equipped and "Equipped" or "Owned") or price)
			setText(card.Category, owned and item.category or detail)
			local isCoins = item.unlock and item.unlock.kind == "Coins"
			local canBuy = isCoins and (unlock and unlock.purchasable == true or not unlock and data.coins >= (item.price or 0))
			local available = item.available ~= false and (item.slot ~= "Emote" or emotePlayable(item))
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or "LOCKED"
			if busy then action = "PLEASE WAIT" end
			setText(card.Action, action)
			card.Action.Visible = true
			card.Action.Active = not busy and data.ready and available and (owned or canBuy)
			card.Action.Selectable = card.Action.Active
			card.Action.BackgroundColor3 = not card.Action.Active and muted or equipped and mint or owned and blue or gold
			local canPlay = emotePlayable(item) and owned
			setText(card.Try, canPlay and "PLAY" or "INFO")
			card.Try.Visible = true
			card.Try.Active = not canPlay or not busy and data.ready and emoteInLobby()
			card.Try.Selectable = card.Try.Active
			local outline = card:FindFirstChild("Outline")
			if outline then outline.Color = equipped and gold or ink end
		else
			card:SetAttribute("CatalogId", nil)
		end
	end
	for _, button in ipairs(shop.Categories:GetChildren()) do
		if button:IsA("TextButton") and button.Visible then button.BackgroundColor3 = button.Name == category and gold or white end
	end
end

local function applyReply(reply)
	if typeof(reply) ~= "table" then return end
	if typeof(reply.coins) == "number" then data.coins = reply.coins end
	if typeof(reply.ready) == "boolean" then data.ready = reply.ready end
	if typeof(reply.owned) == "table" then data.owned = reply.owned end
	if typeof(reply.equipped) == "table" then data.equipped = reply.equipped end
	if typeof(reply.unlocks) == "table" then data.unlocks = reply.unlocks end
	if typeof(reply.unlockSerial) == "number" and reply.unlockSerial ~= lastUnlockSerial then
		lastUnlockSerial = reply.unlockSerial
		if typeof(reply.newlyUnlocked) == "table" and #reply.newlyUnlocked > 0 then
			local names = {}
			for index, id in ipairs(reply.newlyUnlocked) do
				if index > 2 then break end
				local item = catalog.ById[id]
				if item then table.insert(names, item.name) end
			end
			if #names > 0 then
				local more = #reply.newlyUnlocked > 2 and " and " .. tostring(#reply.newlyUnlocked - 2) .. " more" or ""
				showToast("Unlocked: " .. table.concat(names, ", ") .. more .. "!", 5)
			end
		end
	end
	refreshCards()
end

local request
request = function(action, id, quiet, onSuccess)
	if busy then
		if action == "GetStatus" then pendingStatus = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then
		if not quiet then shop.Status.Text = "The shop is getting ready. Try again in a moment." end
		return
	end
	busy = true
	refreshCards()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		busy = false
		if ok and typeof(reply) == "table" then
			applyReply(reply)
			if reply.ok == true and onSuccess then onSuccess(reply) end
			if not quiet or not reply.ok then shop.Status.Text = tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
			if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
		else
			refreshCards()
			if not quiet then shop.Status.Text = "That did not go through. Try again in a moment." end
		end
		if pendingStatus then
			pendingStatus = false
			task.defer(function() request("GetStatus", nil, true) end)
		end
	end)
end

local function setShop(visible)
	shop.Visible = visible
	gui.Backdrop.Visible = visible
	if visible then
		shop.Status.Text = data.ready and "Earn rewards, or spend your coins." or "Your coins are loading..."
		request("GetStatus", nil, true)
	end
end

local function setCategory(value)
	category = value
	page = 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end

local function useOrInfo(record)
	local item = record.item
	if not item or not record.card.Try.Active then return end
	if emotePlayable(item) and data.owned[item.id] then
		if busy or not data.ready or not emoteInLobby() then return end
		request("UseEmote", item.id, false, function()
			setShop(false)
			showToast("Starting " .. item.name .. ". Move to stop.", 3)
		end)
		return
	end
	local unlock = data.unlocks[item.id]
	local description = item.description or item.name
	if unlock and not data.owned[item.id] then description ..= " " .. unlock.label .. "." end
	showToast(description, 5)
end

for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then
		table.insert(slots, { card = card })
	end
end
table.sort(slots, function(a, b) return a.card.Name < b.card.Name end)
for _, record in ipairs(slots) do
	record.card.Action.Activated:Connect(function()
		local item = record.item
		if busy or not data.ready or not item or not record.card.Action.Active then return end
		if isEquipped(item) then request("Unequip", item.slot == "Gear" and item.id or item.slot)
		elseif data.owned[item.id] then request("Equip", item.id)
		else request("Buy", item.id) end
	end)
	record.card.Try.Activated:Connect(function() useOrInfo(record) end)
	record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() framePreview(record) end)
	record.card.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Connect(function() refreshThumbnail(record) end)
end
for _, button in ipairs(shop.Categories:GetChildren()) do
	if button:IsA("TextButton") and button.Visible then button.Activated:Connect(function() setCategory(button.Name) end) end
end
pager.Previous.Activated:Connect(function()
	if busy or page <= 1 then return end
	page -= 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)
pager.Next.Activated:Connect(function()
	if busy or page >= pageCount then return end
	page += 1
	shop.Cards.CanvasPosition = Vector2.zero
	refreshCards()
end)

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
]========] module.Parent = box
local report = require(module)
report.capabilities = tostring(box.Capabilities)
report.exactLiveCapabilities = box.Capabilities == live.Controller.Capabilities
report.sandboxed = box.Sandboxed
return report
end, debug.traceback)
box:Destroy()
assert(ok, result)
return game:GetService("HttpService"):JSONEncode(result)
