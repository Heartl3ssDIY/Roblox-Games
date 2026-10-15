assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing the HUD")
local ui=game.StarterGui
assert(not ui.PlaygroundShell:FindFirstChild("PortraitDock"),"Portrait dock already exists")
assert(not ui.PlaygroundSessionControls.Dock.Body:FindFirstChild("AdminAccess"),"Admin settings button already exists")
local function normalized(s) return s:gsub("\r\n","\n"):gsub("%s+$","") end
assert(normalized(game.StarterGui.PlaygroundShell.Controller.Source)==normalized([======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local vote = gui:WaitForChild("VotePanel")
local compactVote = gui:WaitForChild("CompactVotePanel")
local votePanels = { vote, compactVote }
local wallet = gui:WaitForChild("Wallet")
local dock = gui:WaitForChild("Dock")
local compactDock = gui:WaitForChild("CompactDock")
local docks = { dock, compactDock }
local toast = gui:WaitForChild("RewardToast")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog = require(catalogObject)
local ink = Color3.fromRGB(27, 45, 61)
local white = Color3.fromRGB(255, 255, 248)
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local pink = Color3.fromRGB(255, 153, 166)
local mint = Color3.fromRGB(130, 225, 180)
local muted = Color3.fromRGB(194, 201, 206)
local data = { coins = player:GetAttribute("PCCoins") or 0, ready = player:GetAttribute("PCDataReady") == true, owned = {}, equipped = {}, unlocks = {} }
local category = "All"
local page = 1
local pageCount = 1
local busy = false
local pendingStatus = false
local voteBusy = false
local toastToken = 0
local lastUnlockSerial = nil
local slots = {}
local alive = true
local thumbnailConnections = {}
local lastReward = player:GetAttribute("PCRewardAt")
local lastCoinPickup = player:GetAttribute("PCCoinPickupSerial") or 0
local coinPopups = {}
local wasInsideShop = false
local state = nil
local stateConnection = nil
local pager = shop:WaitForChild("Pager")
local emoteEmptyState = shop:WaitForChild("EmoteEmptyState")
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose", All = "total" }

local hudScales = {}
local hudScaleConnection
local function trackHudScale(object)
	if object:IsA("UIScale") and object.Name == "ResponsiveHudScale" then hudScales[object] = true end
end
for _, object in ipairs(gui.Parent:GetDescendants()) do trackHudScale(object) end
hudScaleConnection = gui.Parent.DescendantAdded:Connect(trackHudScale)

local function hudProfile(viewport)
	local short = math.min(viewport.X, viewport.Y)
	if viewport.X <= 900 or short <= 600 then return "PhoneScale" end
	if short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400 then return "TabletScale" end
	return "DesktopScale"
end

local function refreshLobbyDock(visible)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local compact = hudProfile(viewport) ~= "DesktopScale"
	dock.Visible = visible and not compact
	compactDock.Visible = visible and compact
end

local function lobbyHudSuppressed()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    return controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("UIHidden") == true or controls:GetAttribute("SessionMenuOpen") == true)
end

local function refreshHudScale()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then return end
	local profile = hudProfile(camera.ViewportSize)
	for scale in pairs(hudScales) do
		if not scale:IsDescendantOf(gui.Parent) then
			hudScales[scale] = nil
		else
			local value = scale:GetAttribute(profile)
			if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = 1 end
			value = math.clamp(value, 0.35, 1)
			if scale.Scale ~= value then scale.Scale = value end
		end
	end
end
refreshHudScale()

local function showToast(message, duration)
	if lobbyHudSuppressed() then return end
	toastToken += 1
	local token = toastToken
	toast.Message.Text = tostring(message)
	toast.Visible = true
	task.delay(duration or 3.2, function()
		if token == toastToken and toast.Parent then toast.Visible = false end
	end)
end

local function clearCoinPopup(popup)
	local record = coinPopups[popup]
	if not record then return end
	coinPopups[popup] = nil
	if record.completed then record.completed:Disconnect() end
	for _, tween in ipairs(record.tweens) do tween:Cancel() end
	popup:Destroy()
end

local function showCoinPickup(amount, position)
	if lobbyHudSuppressed() then return end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or typeof(position) ~= "Vector3" then return end
	local templates = gui:FindFirstChild("Templates")
	local template = templates and templates:FindFirstChild("CoinPickupPopup")
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local markers = gameplay and gameplay:FindFirstChild("CoinSpawns")
	if not template or not template:IsA("BillboardGui") or not markers then return end
	local anchor, distance = nil, 8
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			local gap = (marker.Position - position).Magnitude
			if gap < distance then anchor, distance = marker, gap end
		end
	end
	if not anchor then return end
	local popup = template:Clone()
	popup.Name = "CoinPickup"
	local label = popup:FindFirstChild("Amount")
	if not label or not label:IsA("TextLabel") then popup:Destroy() return end
	label.Text = "+" .. tostring(amount)
	popup.Adornee = anchor
	popup.StudsOffsetWorldSpace += position - anchor.Position
	popup.Enabled = true
	popup.Parent = gui
	local lift = TweenService:Create(popup, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = popup.StudsOffsetWorldSpace + Vector3.new(0, 1.8, 0) })
	local fade = TweenService:Create(label, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 })
	local record = { tweens = { lift, fade } }
	coinPopups[popup] = record
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then table.insert(record.tweens, TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 })) end
	record.completed = fade.Completed:Connect(function() clearCoinPopup(popup) end)
	for _, tween in ipairs(record.tweens) do tween:Play() end
	return popup
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

local function emotePlayable(item)
	return item and item.slot == "Emote" and item.playable == true and item.available ~= false
end

local function emoteInLobby()
	return player:GetAttribute("BBParticipating") ~= true
		and player:GetAttribute("TGParticipating") ~= true
		and ( player:GetAttribute("MDParticipating") ~= true and player:GetAttribute("HSParticipating") ~= true and player:GetAttribute("DGParticipating") ~= true and player:GetAttribute("DGEliminated") ~= true )
end

local function itemThumbnail(item)
	if not item then return "" end
	if typeof(item.thumbnail) == "string" and item.thumbnail ~= "" then return item.thumbnail end
	local id = item.catalogId
	if item.slot == "Emote" and typeof(id) == "number" and id == id and id > 0 and id < math.huge and id % 1 == 0 then
		return "rbxthumb://type=Asset&id=" .. string.format("%.0f", id) .. "&w=420&h=420"
	end
	return ""
end

local function clearModelPreview(record)
	if record.previewModel then record.previewModel:Destroy() record.previewModel = nil end
	if record.previewCamera then record.previewCamera:Destroy() record.previewCamera = nil end
	record.card.Preview.CurrentCamera = nil
end

local function frameModelPreview(record)
	if not record.previewModel or not record.previewCamera then return end
	local viewport = record.card.Preview
	local bounds, size = record.previewModel:GetBoundingBox()
	local radius = math.max(0.1, size.Magnitude * 0.5)
	local aspect = math.max(0.1, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local halfFov = math.rad(record.previewCamera.FieldOfView * 0.5)
	local limitingFov = math.min(halfFov, math.atan(math.tan(halfFov) * aspect))
	local distance = radius / math.sin(limitingFov) * 1.08
	local center = bounds.Position
	record.previewCamera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.15, -1).Unit * distance, center)
end

local function buildModelPreview(record, item)
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local template = assets and assets:FindFirstChild(item.id)
	if not template or not template:IsA("Model") then return false end
	local viewport = record.card.Preview
	local world = viewport:FindFirstChild("World")
	if not world then return false end
	local ok = pcall(function()
		world:ClearAllChildren()
		local model = template:Clone()
		record.previewModel = model
		model.Name = "ItemModel"
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("BaseScript") or object:IsA("ObjectValue") or object:IsA("Highlight") then
				object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
			end
		end
		model:PivotTo(CFrame.identity)
		model.Parent = world
		local camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = 35
		camera.Parent = viewport
		record.previewCamera = camera
		viewport.CurrentCamera = camera
		frameModelPreview(record)
	end)
	if not ok then clearModelPreview(record) end
	return ok
end

local function refreshThumbnail(record)
	if not alive or not record.card.Parent then return end
	local thumbnail = record.card.Thumbnail
	local status = record.card.ThumbnailStatus
	status.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	status.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "Preview unavailable" or "Loading preview..."
end

local function renderPreview(record, item)
	local id = item and item.id or nil
	local image = itemThumbnail(item)
	if record.previewId == id and record.card.Thumbnail.Image == image and (image ~= "" or record.previewModel or not item) then return end
	clearModelPreview(record)
	record.previewId = id
	record.previewToken = (record.previewToken or 0) + 1
	local token = record.previewToken
	record.thumbnailTimedOut = false
	local modelReady = item and image == "" and buildModelPreview(record, item) or false
	record.card.Preview.Visible = modelReady
	record.card.Thumbnail.Image = image
	record.card.Thumbnail.Visible = item ~= nil and not modelReady
	refreshThumbnail(record)
	if item and image ~= "" and not record.card.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and record.previewToken == token and record.card.Parent and record.card.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end

local function requirement(item, unlock)
	local rule = item.unlock or { kind = "Coins", amount = item.price or 0 }
	if rule.kind == "Starter" then return "Starter reward", "FREE" end
	if rule.kind == "VIP" then return "Included with VIP", "VIP EXCLUSIVE" end
	if rule.kind == "BetaTester" then return "Beta Tester reward", "BETA TESTER" end
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
	local commerce = category == "BuyCoins"
	shop.Cards.Visible = not commerce
	shop.BuyCoinsPanel.Visible = commerce
	shop.Status.Visible = not commerce
	shop:SetAttribute("SelectedCategory", category)
	local filtered = {}
	for _, item in ipairs(catalog.Items) do
		if category == "All" or item.category == category then table.insert(filtered, item) end
	end
	emoteEmptyState.Visible = category == "Emotes" and #filtered == 0
	pager.Visible = not commerce and #filtered > 0
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
			local action = not available and "UNAVAILABLE" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or isCoins and "BUY" or item.unlock and item.unlock.kind == "VIP" and "VIP ONLY" or item.unlock and item.unlock.kind == "BetaTester" and "BETA ONLY" or "LOCKED"
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
	if visible and lobbyHudSuppressed() then return end
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
	table.insert(thumbnailConnections, record.card.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Connect(function() refreshThumbnail(record) end))
	table.insert(thumbnailConnections, record.card.Preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() frameModelPreview(record) end))
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
for _, target in ipairs(docks) do
	target.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
	target.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
	target.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
end
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
gui:GetAttributeChangedSignal("OpenEmoteShopSerial"):Connect(function()
	if not alive or not emoteInLobby() then return end
	setCategory("Emotes")
	setShop(true)
end)
for _, attribute in ipairs({ "PCCoins", "PCWins", "PCLevel", "PCDataReady" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local wasReady = data.ready
		data.coins = player:GetAttribute("PCCoins") or data.coins
		data.ready = player:GetAttribute("PCDataReady") == true
		refreshCards()
		if data.ready and not wasReady then request("GetStatus", nil, true) end
	end)
end
player:GetAttributeChangedSignal("PCInventoryVersion"):Connect(function() request("GetStatus", nil, true) end)
player:GetAttributeChangedSignal("PCEmotePlaybackStatus"):Connect(function()
	if player:GetAttribute("PCEmotePlaybackStatus") == "failed" then
		showToast(player:GetAttribute("PCEmotePlaybackMessage") or "That emote could not load. Please try again.", 5)
	end
end)
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
	local now = player:GetAttribute("PCRewardAt")
	if now and now ~= lastReward then
		lastReward = now
		local message = player:GetAttribute("PCRewardText")
		if typeof(message) == "string" and message ~= "" then showToast(message, 4) end
	end
end)
local coinPickupConnection = player:GetAttributeChangedSignal("PCCoinPickupSerial"):Connect(function()
	local serial = player:GetAttribute("PCCoinPickupSerial")
	if typeof(serial) ~= "number" or serial <= lastCoinPickup then return end
	lastCoinPickup = serial
	showCoinPickup(player:GetAttribute("PCCoinPickupAmount"), player:GetAttribute("PCCoinPickupPosition"))
end)
script.Destroying:Connect(function()
	alive = false
	hudScaleConnection:Disconnect()
	table.clear(hudScales)
	for _, connection in ipairs(thumbnailConnections) do connection:Disconnect() end
	for _, record in ipairs(slots) do record.previewToken = (record.previewToken or 0) + 1 clearModelPreview(record) end
	coinPickupConnection:Disconnect()
	while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
end)
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "PlaygroundShopRequest" then request("GetStatus", nil, true) end
end)

local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local lastDisplayedVote = {}
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 for _, id in ipairs({ "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }) do
  local card = vote.Choices[id]
  local button, counter = card.Button, card.VoteCount
  local available = state and state:GetAttribute("Available" .. id) ~= false
  local color = ({ BritishBulldog = blue, TagYoureIt = pink, StuckInTheMud = mint, HideAndSeek = Color3.fromRGB(188,143,245), DuckDuckGoose = Color3.fromRGB(246,189,62) })[id]
  counter.Text = votesText(state and state:GetAttribute("Votes" .. id) or 0)
  button.BackgroundColor3 = chosen == id and gold or color
  button.Active = voting and not voteBusy and available == true
  button.Selectable = button.Active
  local selection = button:FindFirstChild("SelectionMark")
  if selection then selection.Visible = chosen == id end
  if not available then
   button.BackgroundColor3 = Color3.fromRGB(162,169,184)
   local minimum = state and state:GetAttribute("Minimum" .. id) or 2
   counter.Text = (state and state:GetAttribute("ReadyPlayerCount") or 0) < minimum and "Needs " .. tostring(minimum) .. " players" or "Unavailable"
  end
  local fallback = button:FindFirstChild("ArtFallback")
  if fallback then
   fallback.Visible = not button.ReusableSkin.IsLoaded
   fallback.Face.BackgroundColor3 = button.BackgroundColor3
  end
 end
 if chosen and chosen ~= "" and chosen ~= lastDisplayedVote[vote] then
  local card = vote.Choices:FindFirstChild(chosen)
  if card then
   local left = card.Position.X.Offset
   local right = left + card.Size.X.Offset
   local current = vote.Choices.CanvasPosition.X
   local width = vote.Choices.AbsoluteSize.X
   local maximum = math.max(0, vote.Choices.AbsoluteCanvasSize.X - width)
   if left < current then current = left elseif right > current + width then current = right - width end
   vote.Choices.CanvasPosition = Vector2.new(math.clamp(current, 0, maximum), 0)
   lastDisplayedVote[vote] = chosen
  end
 end
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud", "HideAndSeek", "DuckDuckGoose"}) do panel.Choices[id].Button.Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local function refreshSpectatorVisibility()
    local watching = lobbyHudSuppressed()
    local participating = player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
    refreshLobbyDock(not participating and not watching)
    wallet.Visible = not participating and not watching
    if watching then
        toast.Visible = false
        while next(coinPopups) do clearCoinPopup(next(coinPopups)) end
        setShop(false)
        vote.Visible = false
        compactVote.Visible = false
    end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = controls.AttributeChanged:Connect(function(name)
        if name == "Spectating" or name == "UIHidden" or name == "SessionMenuOpen" then refreshSpectatorVisibility() end
    end)
    refreshSpectatorVisibility()
end
local sessionChildConnection = player.PlayerGui.ChildAdded:Connect(bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end
script.Destroying:Connect(function()
    sessionChildConnection:Disconnect()
    if spectatorConnection then spectatorConnection:Disconnect() end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 if elapsed<0.15 then return end
 elapsed=0
 refreshHudScale()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true ))
 wallet.Visible=not participating and not lobbyHudSuppressed()
 refreshLobbyDock(not participating and not lobbyHudSuppressed())
 if (participating or lobbyHudSuppressed()) and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and not lobbyHudSuppressed() and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and hudProfile(camera.ViewportSize) ~= "DesktopScale" or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)




]======]),"Source changed: StarterGui.PlaygroundShell.Controller")
assert(normalized(game.StarterGui.PlaygroundAdminPanel.Controller.Source)==normalized([======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
for _, name in ipairs({ "Toggle", "AdminHub", "Panel", "CompactPanel", "CompactToggle" }) do
	local object = gui:FindFirstChild(name)
	if object then object.Visible = false end
end
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Hiding = "Hide now", Seeking = "Seekers released", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", HideAndSeek = "Hide and Seek", DuckDuckGoose = "Duck Duck Goose", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
for _, fallback in ipairs(gui:GetDescendants()) do
	if fallback.Name == "ArtFallback" and fallback:IsA("Frame") then
		local skin = fallback.Parent:FindFirstChild("ReusableSkin")
		if skin and skin:IsA("ImageLabel") then
			local function updateFallback() fallback.Visible = not skin.IsLoaded end
			connect(skin:GetPropertyChangedSignal("IsLoaded"), updateFallback)
			connect(skin:GetPropertyChangedSignal("Image"), updateFallback)
			updateFallback()
		end
	end
end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
	local entitlements = targetData and targetData.entitlements or {}
	for _, kind in ipairs({ "VIP", "BetaTester" }) do
		local button = pages.Rewards.Entitlements["Grant" .. kind]
		local granted = entitlements[kind] == true
		local label = kind == "VIP" and "VIP" or "BETA TESTER"
		caption(button, busy and "WAIT..." or granted and (label .. " ACTIVE") or ("GRANT " .. label))
		enabled(button, rewardReady() and not granted, kind == "VIP" and gold or green)
	end
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	if unlock.kind == "VIP" then return "VIP reward" end
	if unlock.kind == "BetaTester" then return "Beta Tester reward" end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and not equipped and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState", HideAndSeek = "HideAndSeekState", DuckDuckGoose = "DuckDuckGooseState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
for _, kind in ipairs({ "VIP", "BetaTester" }) do
	local button = pages.Rewards.Entitlements["Grant" .. kind]
	connect(button.Activated, function()
		if button.Active and rewardReady() then request("Grant" .. kind) end
	end)
end
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "HSStart", "DGStart", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true, HideAndSeekState = true, DuckDuckGooseState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState", "HideAndSeekState", "DuckDuckGooseState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()
]======]),"Source changed: StarterGui.PlaygroundAdminPanel.Controller")
assert(normalized(game.StarterGui.PlaygroundSessionControls.Controller.Source)==normalized([======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local dock = gui:WaitForChild("Dock")
local content = dock:WaitForChild("Body")
local toggle = gui:WaitForChild("Toggle")
local roundToggle = gui:WaitForChild("RoundToggle")
local compactRoundToggle = gui:WaitForChild("CompactRoundToggle")
local portraitRoundToggle = gui:WaitForChild("PortraitRoundToggle")
local roundLaunchers = { roundToggle, compactRoundToggle, portraitRoundToggle }
local compactToggle = gui:WaitForChild("CompactToggle")
local portraitToggle = gui:WaitForChild("PortraitToggle")
local backdrop = gui:WaitForChild("MenuBackdrop")
local panel = gui:WaitForChild("SpectatePanel")
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local remote = ReplicatedStorage:WaitForChild("PlaygroundSessionRequest")
local afkButton = content:WaitForChild("AFK")
local watchButton = gui:WaitForChild("Spectate")
local compactWatch = gui:WaitForChild("CompactSpectate")
local portraitWatch = gui:WaitForChild("PortraitSpectate")
local settingsLaunchers = { toggle, compactToggle, portraitToggle }
local watchLaunchers = { watchButton, compactWatch, portraitWatch }
local visibilityButton = content:WaitForChild("Visibility")
local settingsClose = dock:WaitForChild("Close")
local connections = {}
local watching = false
local menuOpen = false
local target
local savedCamera
local savedSelection
local watchingGame
local watchingRound
local busy = false
local alive = true
local requestSerial = 0
local requestWorker
local controlsWorker
local playerControls
local controlsWereEnabled
local focusWorker
local focusSerial = 0
local focusStamp = 0
local lastFocusAt = -math.huge
local lastTargetChange = -math.huge
local loadingUntil = 0
local rejectedUntil = {}
local noticeUntil = 0
local actionName = "PlaygroundSessionControls"
local movementAction = "PlaygroundSpectateMovement"
local movementStep = "PlaygroundSpectateHoldPosition"
local participatingNames = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating" }
local roundStates = { BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState", HideAndSeek = "HideAndSeekState", DuckDuckGoose = "DuckDuckGooseState" }
local roundAttributes = { BritishBulldog = "BBParticipating", TagYoureIt = "TGParticipating", StuckInTheMud = "MDParticipating", HideAndSeek = "HSParticipating", DuckDuckGoose = "DGParticipating" }
local refresh
local stepTarget

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	for _, name in ipairs(participatingNames) do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
end

local function gamepadActive()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

local function otherModalOpen()
	if GuiService.MenuIsOpen then return true end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false end
	for name, panels in pairs({
		PlaygroundShell = { "ShopPanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
	}) do
		local other = playerGui:FindFirstChild(name)
		if other and other.Enabled then
			for _, panelName in ipairs(panels) do
				local object = other:FindFirstChild(panelName)
				if object and object.Visible then return true end
			end
		end
	end
	return false
end

local function activeRound()
	local gameId = state:GetAttribute("ActiveGame")
	local roundState = roundStates[gameId] and ReplicatedStorage:FindFirstChild(roundStates[gameId])
	if state:GetAttribute("Phase") ~= "Playing" or not roundState then return nil end
	local phase = roundState:GetAttribute("Phase")
	if phase == "Waiting" or phase == "Results" or phase == "Intermission" then return nil end
	return gameId, roundState:GetAttribute("RoundNumber")
end

local function targetsFor(gameId)
	local result = {}
	local attribute = roundAttributes[gameId]
	if not attribute then return result end
	for _, candidate in ipairs(Players:GetPlayers()) do
		local character = candidate.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if candidate ~= player and candidate:GetAttribute(attribute) == true and (not humanoid or humanoid.Health > 0)
			and (rejectedUntil[candidate.UserId] or 0) <= os.clock() then
			table.insert(result, candidate)
		end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

local function tell(message)
	content.Notice.Text = message
	noticeUntil = os.clock() + 4
end

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Interactable = enabled
	button.Selectable = enabled
	button.ReusableSkin.Image = button:GetAttribute(not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage")
	if button:GetAttribute("IconButton") then button.ReusableSkin.ImageTransparency = enabled and 0 or 0.55 end
end

local function disableMovement()
	if playerControls and controlsWereEnabled == nil then
		controlsWereEnabled = playerControls.controlsEnabled ~= false
		if controlsWereEnabled then playerControls:Disable() end
	end
end

local function restoreMovement()
	if playerControls and controlsWereEnabled then playerControls:Enable() end
	controlsWereEnabled = nil
end

local function closeMenu()
	menuOpen = false
	gui:SetAttribute("SessionMenuOpen", false)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil end
end

local function nextFocusStamp()
	focusStamp = math.max(focusStamp + 0.0001, workspace:GetServerTimeNow())
	return focusStamp
end

local function exitSpectate(message)
	if not watching then return end
	watching = false
	focusSerial += 1
	if focusWorker then pcall(task.cancel, focusWorker) focusWorker = nil end
	local stopStamp = nextFocusStamp()
	task.spawn(function() pcall(remote.InvokeServer, remote, "SetSpectate", 0, stopStamp) end)
	target = nil
	watchingGame = nil
	watchingRound = nil
	gui:SetAttribute("Spectating", false)
	gui:SetAttribute("SpectatingUserId", 0)
	ContextActionService:UnbindAction(movementAction)
	restoreMovement()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		local subject = humanoid or (savedCamera and savedCamera.subject and savedCamera.subject.Parent and savedCamera.subject)
		camera.CameraSubject = subject
		camera.CameraType = inRound() and Enum.CameraType.Custom or (savedCamera and savedCamera.kind or Enum.CameraType.Custom)
		if savedCamera and not inRound() then
			camera.CFrame = savedCamera.cframe
			camera.Focus = savedCamera.focus
		end
	end
	savedCamera = nil
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = savedSelection and savedSelection.Parent and savedSelection or nil
	end
	savedSelection = nil
	panel.Visible = false
	if message then tell(message) end
end

local function applyTargetCamera(candidate)
	local humanoid = candidate and candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid")
	local root = candidate and candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not camera or not humanoid or not root or humanoid.Health <= 0 then return false end
	target = candidate
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	gui:SetAttribute("SpectatingUserId", candidate.UserId)
	panel.PlayerName.Text = candidate.DisplayName
	panel.Username.Text = "@" .. candidate.Name
	return true
end

local function requestFocus(candidate)
	focusSerial += 1
	local serial = focusSerial
	if focusWorker then pcall(task.cancel, focusWorker) end
	local stamp = nextFocusStamp()
	lastFocusAt = os.clock()
	focusWorker = task.spawn(function()
		local ok, result = pcall(remote.InvokeServer, remote, "SetSpectate", candidate.UserId, stamp)
		if not alive or not watching or serial ~= focusSerial or target ~= candidate then return end
		focusWorker = nil
		if not ok or typeof(result) ~= "table" or not result.ok then
			rejectedUntil[candidate.UserId] = os.clock() + 3
			task.delay(0.25, function() if alive and watching and serial == focusSerial then stepTarget(1) end end)
		end
	end)
	task.delay(8, function()
		if alive and watching and serial == focusSerial and focusWorker then
			exitSpectate("Could not load the arena. Try again.")
			refresh()
		end
	end)
end

local function setTarget(candidate)
	target = candidate
	gui:SetAttribute("SpectatingUserId", candidate.UserId)
	panel.PlayerName.Text = candidate.DisplayName
	panel.Username.Text = "LOADING ARENA..."
	loadingUntil = os.clock() + 10
	requestFocus(candidate)
	applyTargetCamera(candidate)
end

stepTarget = function(direction)
	if not watching then return end
	if os.clock() - lastTargetChange < 0.25 then return end
	lastTargetChange = os.clock()
	local list = targetsFor(watchingGame)
	if #list == 0 then exitSpectate("No players left to watch.") return end
	local index = table.find(list, target)
	local nextIndex = index and ((index - 1 + direction) % #list + 1) or 1
	setTarget(list[nextIndex])
	panel.Counter.Text = string.format("%d / %d", nextIndex, #list)
end

local function startSpectate()
	if watching or inRound() or otherModalOpen() or not gui.Enabled then return end
	local gameId, roundNumber = activeRound()
	local list = targetsFor(gameId)
	local camera = workspace.CurrentCamera
	if not gameId or #list == 0 or not camera then tell("No round to watch yet.") return end
	savedCamera = { subject = camera.CameraSubject, kind = camera.CameraType, cframe = camera.CFrame, focus = camera.Focus }
	local selected = GuiService.SelectedObject
	if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
	watching = true
	lastTargetChange = -math.huge
	closeMenu()
	disableMovement()
	watchingGame = gameId
	watchingRound = roundNumber
	gui:SetAttribute("Spectating", true)
	panel.Visible = true
	ContextActionService:BindActionAtPriority(movementAction, function()
		return watching and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 2,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	stepTarget(1)
	if gamepadActive() then GuiService.SelectedObject = panel.Exit end
	refresh()
end

local function toggleAFK()
	if busy or not gui.Enabled then return end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	refresh()
	requestWorker = task.spawn(function()
		local ok, response = pcall(remote.InvokeServer, remote, "SetAFK", player:GetAttribute("PCAFKRequested") ~= true)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		if ok and typeof(response) == "table" then tell(response.message or "AFK updated.") else tell("Could not update AFK. Try again.") end
		refresh()
	end)
	task.delay(8, function()
		if alive and busy and serial == requestSerial then
			requestSerial += 1
			busy = false
			if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
			tell("AFK request timed out. Try again.")
			refresh()
		end
	end)
end

refresh = function()
	if not alive then return end
	local modal = otherModalOpen()
	local participating = inRound()
	if modal or not gui.Enabled then closeMenu() end
	local gameId, roundNumber = activeRound()
	local localHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if watching then
		if participating or not gui.Enabled or modal or not localHumanoid or localHumanoid.Health <= 0 then
			exitSpectate()
		elseif not gameId or gameId ~= watchingGame or roundNumber ~= watchingRound then
			exitSpectate("The round has ended.")
		else
			disableMovement()
			local list = targetsFor(gameId)
			local index = table.find(list, target)
			if not index then
				stepTarget(1)
			else
				local camera = workspace.CurrentCamera
				local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
				local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if camera and humanoid and root then
					if camera.CameraSubject ~= humanoid or camera.CameraType ~= Enum.CameraType.Custom then applyTargetCamera(target) end
				elseif os.clock() >= loadingUntil then
					rejectedUntil[target.UserId] = os.clock() + 3
					stepTarget(1)
				end
				panel.Counter.Text = string.format("%d / %d", index, #list)
				if watching and target and not focusWorker and os.clock() - lastFocusAt >= 4 then requestFocus(target) end
			end
		end
	end
	dock.Visible = gui.Enabled and not modal and not watching and menuOpen
	backdrop.Visible = dock.Visible
	local compact, portrait = compactLayout()
	local showSettings = gui.Enabled and not modal and not participating
	toggle.Visible = showSettings and not compact
	compactToggle.Visible = showSettings and compact and not portrait
	portraitToggle.Visible = showSettings and compact and portrait
	local showRoundSettings = gui.Enabled and not modal and participating
	roundToggle.Visible = showRoundSettings and not compact
	compactRoundToggle.Visible = showRoundSettings and compact and not portrait
	portraitRoundToggle.Visible = showRoundSettings and compact and portrait
	panel.Visible = watching and not modal
	local requested = player:GetAttribute("PCAFKRequested") == true
	local queued = player:GetAttribute("PCAFKQueued") == true
	panel.JoinStatus.Text = requested and "AFK ON • STAYING IN LOBBY" or "YOU WILL JOIN THE NEXT ROUND"
	afkButton.Label.Text = queued and "AFK NEXT ROUND" or requested and "AFK: ON" or "AFK: OFF"
	buttonState(afkButton, not busy, requested)
	for _, launcher in ipairs(settingsLaunchers) do buttonState(launcher, true) end
	for _, launcher in ipairs(roundLaunchers) do buttonState(launcher, true) end
	local uiHidden = gui:GetAttribute("UIHidden") == true
	visibilityButton.Label.Text = uiHidden and "SHOW UI" or "HIDE UI"
	buttonState(visibilityButton, true, uiHidden)
	local showWatch = gui.Enabled and not modal and not participating and not menuOpen
	watchButton.Visible = showWatch and not compact
	compactWatch.Visible = showWatch and compact and not portrait
	portraitWatch.Visible = showWatch and compact and portrait
	local canWatch = watching or (gameId ~= nil and #targetsFor(gameId) > 0)
	for _, launcher in ipairs(watchLaunchers) do
		launcher.Label.Text = watching and "STOP" or "SPECTATE"
		buttonState(launcher, canWatch)
	end
	watchButton.Label.Text = watching and "STOP WATCHING" or "SPECTATE"
	if os.clock() >= noticeUntil then
		content.Notice.Text = queued and "After this round" or requested and "Staying in the lobby" or ""
	end
	local controller = gamepadActive()
	content.Hint.Visible = controller
	content.Hint.Text = "D-PAD UP: SETTINGS  •  RIGHT: WATCH"
	panel.Controls.Text = controller and "L1 / R1: PLAYER   B / ○: EXIT" or "ARROWS: PLAYER   BACKSPACE: EXIT"
end

connect(afkButton.Activated, toggleAFK)
local function toggleSettings()
	if watching then exitSpectate() end
	if menuOpen then closeMenu() else menuOpen = true gui:SetAttribute("SessionMenuOpen", true) end
	refresh()
end
for _, launcher in ipairs(settingsLaunchers) do connect(launcher.Activated, toggleSettings) end
for _, launcher in ipairs(roundLaunchers) do connect(launcher.Activated, toggleSettings) end
connect(settingsClose.Activated, function() closeMenu() refresh() end)
connect(visibilityButton.Activated, function()
	gui:SetAttribute("UIHidden", gui:GetAttribute("UIHidden") ~= true)
	refresh()
end)
connect(backdrop.Activated, function() closeMenu() refresh() end)
for _, launcher in ipairs(watchLaunchers) do
	connect(launcher.Activated, function()
		if watching then exitSpectate() refresh() else startSpectate() end
	end)
end
connect(panel.Previous.Activated, function() stepTarget(-1) end)
connect(panel.Next.Activated, function() stepTarget(1) end)
connect(panel.Exit.Activated, function() exitSpectate() refresh() end)
ContextActionService:BindActionAtPriority(actionName, function(_, inputState, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or otherModalOpen() then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadRight and not watching and not inRound() then
		if inputState == Enum.UserInputState.Begin then startSpectate() end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.DPadUp then
		if inputState == Enum.UserInputState.Begin then
			local selected = GuiService.SelectedObject
			if not selected or not selected:IsDescendantOf(gui) then savedSelection = selected end
			if not watching then menuOpen = true gui:SetAttribute("SessionMenuOpen", true) refresh() end
			GuiService.SelectedObject = watching and panel.Exit or afkButton
		end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.ButtonB and not watching then
		local selected = GuiService.SelectedObject
		if menuOpen or (selected and selected:IsDescendantOf(gui)) then
			if inputState == Enum.UserInputState.Begin then closeMenu() refresh() savedSelection = nil end
			return Enum.ContextActionResult.Sink
		end
	end
	if not watching then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then exitSpectate() refresh()
		elseif key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.Left then stepTarget(-1)
		elseif key == Enum.KeyCode.ButtonR1 or key == Enum.KeyCode.Right then stepTarget(1) end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Backspace)

for _, name in ipairs({ "PCAFK", "PCAFKRequested", "PCAFKQueued", table.unpack(participatingNames) }) do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterAdded, function() exitSpectate() refresh() end)
connect(player.CharacterRemoving, function() exitSpectate() refresh() end)
connect(Players.PlayerRemoving, function(candidate) if candidate == target then target = nil task.defer(refresh) end end)
connect(UserInputService.LastInputTypeChanged, refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(gui:GetAttributeChangedSignal("UIHidden"), refresh)
connect(state:GetAttributeChangedSignal("ActiveGame"), refresh)
connect(state:GetAttributeChangedSignal("Phase"), refresh)
RunService:BindToRenderStep(movementStep, Enum.RenderPriority.Input.Value + 1, function()
	if not watching or inRound() then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) humanoid.Jump = false end
end)
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
	elapsed += dt
	if elapsed >= 0.2 then elapsed = 0 refresh() end
end)
script.Destroying:Connect(function()
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) end
	if controlsWorker then pcall(task.cancel, controlsWorker) end
	exitSpectate()
	closeMenu()
	ContextActionService:UnbindAction(actionName)
	ContextActionService:UnbindAction(movementAction)
	RunService:UnbindFromRenderStep(movementStep)
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)
controlsWorker = task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
	if playerModule then
		local ok, controls = pcall(function() return require(playerModule):GetControls() end)
		if ok and controls and alive then
			playerControls = controls
			if watching then disableMovement() end
		end
	end
	controlsWorker = nil
end)
gui:SetAttribute("Spectating", false)
gui:SetAttribute("SessionMenuOpen", false)
gui:SetAttribute("SpectatingUserId", 0)
panel.Visible = false
refresh()]======]),"Source changed: StarterGui.PlaygroundSessionControls.Controller")
assert(normalized(game.StarterGui.HideAndSeekHUD.Controller.Source)==normalized([======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("HideAndSeekState")
local sprintRemote = ReplicatedStorage:WaitForChild("HideAndSeekSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("HideAndSeekActionRequest")
local headers = { gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader }
local sprintButtons = { gui.DesktopSprint, gui.MobileSprint }
local connections = {}
local sprintRequested = false
local keysHeld = {}
local touchHeld = {}
local focused = true
local elapsed = 0
local nextLockerExit = 0
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local phase = state:GetAttribute("Phase")
	return focused and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		and gui.Enabled and player:GetAttribute("HSParticipating") == true
		and (phase == "Hiding" or phase == "Seeking") and player:GetAttribute("HSHiding") ~= true
		and not (phase == "Hiding" and player:GetAttribute("HSRole") == "Seeker")
		and player:GetAttribute("HSRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value)
	value = value == true and canSprint() == true
	if value == sprintRequested then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(touchHeld)
	requestSprint(false)
end
local function leaveLocker()
	if not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or player:GetAttribute("HSParticipating") ~= true or player:GetAttribute("HSHiding") ~= true
		or os.clock() < nextLockerExit then return end
	nextLockerExit = os.clock() + 0.3
	actionRemote:FireServer("LeaveLocker")
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local participating = player:GetAttribute("HSParticipating") == true
	local roundState = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true and roundState and roundState:GetAttribute("ActiveGame") == "HideAndSeek"
	local shown = (participating or watching) and not muted
	local phase = state:GetAttribute("Phase")
	local role = player:GetAttribute("HSRole")
	local now = workspace:GetServerTimeNow()
	local ending = phase == "Hiding" and state:GetAttribute("HidingEndsAt") or state:GetAttribute("EndsAt")
	local seconds = typeof(ending) == "number" and ending == ending and math.abs(ending) ~= math.huge and math.max(0, math.ceil(ending - now)) or 0
	local blindfold = participating and role == "Seeker" and phase == "Hiding"
	gui.SeekerBlindfold.Visible = blindfold
	gui.SeekerBlindfold.WaitingCard.Countdown.Text = clock(seconds)
	local instruction = "Find a hiding spot!"
	if phase == "Countdown" then instruction = "Get ready!"
	elseif phase == "Hiding" then instruction = role == "Seeker" and "Wait while players hide" or "Hide before the seeker is released"
	elseif phase == "Seeking" then instruction = role == "Seeker" and "Swing your bat to find hiders" or "Stay hidden or run from seekers"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	if player:GetAttribute("HSHiding") == true then instruction = "Hiding in a locker • Leave to run" end
	for _, header in headers do
		header.Visible = shown and not blindfold and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "HIDE & SEEK"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or role == "Seeker" and "SEEKER" or "HIDER"
		header.Role.TextColor3 = role == "Seeker" and Color3.fromRGB(245,83,117) or Color3.fromRGB(68,163,245)
		local hiders, seekers = state:GetAttribute("HiderCount") or 0, state:GetAttribute("SeekerCount") or 0
		header.Counts.Text = string.format("%d %s • %d %s", hiders, hiders == 1 and "hider" or "hiders", seekers, seekers == 1 and "seeker" or "seekers")
		header.Hint.Text = watching and "Watching the school round" or instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	if not active then clearInputs() end
	for _, button in sprintButtons do
		button.Visible = participating and shown and (phase == "Hiding" or phase == "Seeking") and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local stamina = math.clamp((player:GetAttribute("HSStamina") or 0) / math.max(1, player:GetAttribute("HSMaxStamina") or 10), 0, 1)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(stamina, 1)
		button.StaminaText.Text = string.format("%.1f / 10", player:GetAttribute("HSStamina") or 0)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(150,157,170)
		local fallback = button:FindFirstChild("ArtFallback") or button:FindFirstChild("Fallback")
		if fallback then fallback.Visible = not button.ReusableSkin.IsLoaded end
	end
	gui.LeaveLocker.Visible = shown and player:GetAttribute("HSHiding") == true
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touchHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if touchHeld[input] then touchHeld[input] = nil requestSprint(next(touchHeld) ~= nil or next(keysHeld) ~= nil) end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.LeaveLocker.Activated, leaveLocker)
ContextActionService:BindAction("HideAndSeekSprint", function(_, inputState, input)
	if player:GetAttribute("HSParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then keysHeld[input.KeyCode] = true requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then keysHeld[input.KeyCode] = nil requestSprint(next(keysHeld) ~= nil or next(touchHeld) ~= nil) end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("HideAndSeekLeaveLocker", function(_, inputState)
	if player:GetAttribute("HSHiding") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then leaveLocker() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
connect(state.AttributeChanged, refresh)
for _, name in { "HSParticipating", "HSRole", "HSHiding", "HSRagdolled", "HSStamina", "HSMaxStamina" } do connect(player:GetAttributeChangedSignal(name), refresh) end
connect(player.CharacterRemoving, clearInputs)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	clearInputs()
	ContextActionService:UnbindAction("HideAndSeekSprint")
	ContextActionService:UnbindAction("HideAndSeekLeaveLocker")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
]======]),"Source changed: StarterGui.HideAndSeekHUD.Controller")
local backup=Instance.new("Folder") backup.Name="MobilePlacementBackup20261011" assert(not game.ServerStorage:FindFirstChild(backup.Name),"Backup already exists") backup.Parent=game.ServerStorage
local function attach(node,parent)
 if #node:GetDescendants()>450 then
  local children=node:GetChildren() for _,c in children do c.Parent=nil end
  node.Parent=parent for _,c in children do attach(c,node) end
 else node.Parent=parent task.wait() end
end
for _,g in ui:GetChildren() do if g:IsA("ScreenGui") then attach(g:Clone(),backup) end end
local layout=(function()
return function(ui)
	local function place(item, position, size, anchor)
		item.Position, item.Size, item.AnchorPoint = position, size, anchor or Vector2.zero
	end
	local function limitText(item, maximum)
		item.TextScaled = true
		local limit = item:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		limit.MinTextSize, limit.MaxTextSize, limit.Parent = 8, maximum, item
	end
	local shell, timer, session = ui.PlaygroundShell, ui.PlaygroundIntermissionHUD, ui.PlaygroundSessionControls
	place(shell.Wallet.CoinsCaption,UDim2.fromOffset(58,4),UDim2.new(1,-68,0,12))
	place(shell.Wallet.Coins,UDim2.fromOffset(58,18),UDim2.new(1,-68,0,28))
	limitText(shell.Wallet.CoinsCaption,12)
	local level = shell.CompactLevelPanel
	place(level, UDim2.fromOffset(8,6), UDim2.fromOffset(128,44))
	place(level.FacePreview, UDim2.fromOffset(6,7), UDim2.fromOffset(28,28))
	place(level.Level, UDim2.fromOffset(40,4), UDim2.fromOffset(82,15))
	place(level.XP, UDim2.fromOffset(40,20), UDim2.fromOffset(82,12))
	place(level.XPTrack, UDim2.fromOffset(40,34), UDim2.fromOffset(82,4))
	limitText(level.Level,14) limitText(level.XP,10)
	place(shell.CompactDock, UDim2.new(.5,0,1,-8), UDim2.fromOffset(238,44), Vector2.new(.5,1))
	local portraitDock = shell.CompactDock:Clone()
	portraitDock.Name, portraitDock.Visible = "PortraitDock", false
	portraitDock.Parent = shell
	place(portraitDock, UDim2.new(.5,0,1,-148), UDim2.fromOffset(238,44), Vector2.new(.5,1))
	for _, card in {timer.Compact,timer.Portrait} do
		place(card, UDim2.new(.5,0,0,card == timer.Portrait and 108 or 6), card == timer.Portrait and UDim2.fromOffset(224,44) or UDim2.new(1,-288,0,44), Vector2.new(.5,0))
		local limit = card:FindFirstChildOfClass("UISizeConstraint")
		limit.MinSize, limit.MaxSize = Vector2.new(160,44), Vector2.new(224,44)
		place(card.Title,UDim2.fromOffset(8,4),UDim2.new(.72,-12,0,16))
		place(card.Timer,UDim2.new(.72,0,0,3),UDim2.new(.28,-8,0,18))
		place(card.Detail,UDim2.fromOffset(8,22),UDim2.new(1,-16,0,13))
		limitText(card.Title,14) limitText(card.Timer,19) limitText(card.Detail,10)
		card.Detail.TextColor3 = Color3.fromRGB(29,34,53)
		card.Detail.TextYAlignment = Enum.TextYAlignment.Center
		card.Detail.ZIndex = 4
	end
	for _, name in {"CompactToggle","PortraitToggle"} do
		place(session[name],UDim2.fromOffset(8,56),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactSpectate","PortraitSpectate"} do
		place(session[name],UDim2.fromOffset(60,56),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactRoundToggle","PortraitRoundToggle"} do
		place(session[name],UDim2.fromOffset(8,6),UDim2.fromOffset(44,44))
	end
	for _, name in {"CompactEmoteToggle","PortraitEmoteToggle"} do
		place(ui.PlaygroundEmoteWheel[name],UDim2.new(1,-8,0,56),UDim2.fromOffset(80,44),Vector2.new(1,0))
	end
	place(session.Toggle,UDim2.new(1,-122,1,-18),UDim2.fromOffset(44,44),Vector2.new(1,1))
	place(session.Spectate,UDim2.new(1,-70,1,-18),UDim2.fromOffset(44,44),Vector2.new(1,1))
	local admin = session.Dock.Body.AFK:Clone()
	admin.Name, admin.Visible = "AdminAccess", false
	admin.Label.Text = "ADMIN PANEL"
	admin.Parent = session.Dock.Body
	place(admin,UDim2.new(0,14,0,320),UDim2.new(1,-28,0,46))
	session.Dock.Body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	session.Dock.Body.CanvasSize = UDim2.new()
	local bodyPadding = session.Dock.Body:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	bodyPadding.PaddingBottom = UDim.new(0,12) bodyPadding.Parent = session.Dock.Body
	for _, item in {ui.PlaygroundFishingHUD.CompactDock,ui.PlaygroundFishingHUD.PortraitDock} do
		place(item,UDim2.new(1,-8,0,104),UDim2.fromOffset(96,38),Vector2.new(1,0))
	end
	place(ui.PlaygroundFishingHUD.PortraitDock,UDim2.new(.5,0,1,-202),UDim2.fromOffset(96,38),Vector2.new(.5,1))
	place(ui.PlaygroundFishingHUD.RoundDock,UDim2.new(0,8,0,92),UDim2.fromOffset(96,38))
	local bar = ui.PlaygroundToyHotbar.Bar
	place(bar,UDim2.new(.5,0,.57,0),UDim2.fromOffset(244,58),Vector2.new(.5,0))
	ui.PlaygroundToyHotbar.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	for _, name in {"BritishBulldogHUD","TagHUD","HideAndSeekHUD","DuckDuckGooseHUD"} do
		place(ui[name].MobileSprint,UDim2.new(1,-16,1,-138),UDim2.fromOffset(100,44),Vector2.new(1,1))
	end
	place(ui.MudHUD.Main.MobileSprint,UDim2.new(1,-16,1,-138),UDim2.fromOffset(100,44),Vector2.new(1,1))
	place(ui.PlaygroundBatControls.Swing,UDim2.new(1,-16,1,-188),UDim2.fromOffset(100,44),Vector2.new(1,1))
	place(ui.HideAndSeekHUD.LeaveLocker,UDim2.new(1,-16,1,-188),UDim2.fromOffset(100,44),Vector2.new(1,1))
	ui.HideAndSeekHUD.LeaveLocker.Caption.Text = "LEAVE"
	ui.HideAndSeekHUD.LeaveLocker.Text = "LEAVE"
	local function fallback(target, color)
		local skin = target:FindFirstChild("ReusableSkin")
		if not skin or target:FindFirstChild("ReusableSkinFallback") then return end
		local panel = Instance.new("Frame")
		panel.Name = "ReusableSkinFallback"
		panel:SetAttribute("BackgroundFallbackFor","ReusableSkin")
		panel:SetAttribute("FallbackFaceColor",color)
		panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(31,38,60), 0
		panel.Position, panel.Size, panel.AnchorPoint = skin.Position, skin.Size, skin.AnchorPoint
		panel.ZIndex, panel.Visible = skin.ZIndex, not skin.IsLoaded
		local corner = Instance.new("UICorner") corner.CornerRadius=UDim.new(0,12) corner.Parent=panel
		local edge = Instance.new("Frame") edge.Name="Edge" edge.Position=UDim2.fromOffset(2,2) edge.Size=UDim2.new(1,-4,1,-7) edge.BorderSizePixel=0 edge.BackgroundColor3=Color3.fromRGB(255,249,224) edge.ZIndex=panel.ZIndex edge.Parent=panel
		local edgeCorner=corner:Clone() edgeCorner.Parent=edge
		local face=Instance.new("Frame") face.Name="Face" face.Position=UDim2.fromOffset(2,2) face.Size=UDim2.new(1,-4,1,-4) face.BorderSizePixel=0 face.BackgroundColor3=color face.ZIndex=panel.ZIndex face.Parent=edge
		local faceCorner=corner:Clone() faceCorner.Parent=face
		panel.Parent=target
	end
	fallback(shell.CompactLevelPanel,Color3.fromRGB(255,249,224))
	fallback(shell.Wallet,Color3.fromRGB(255,249,224))
	for _,dock in {shell.CompactDock,portraitDock} do
		for _,name in {"Shop","Pets","Toys"} do fallback(dock[name],name=="Toys" and Color3.fromRGB(176,188,206) or Color3.fromRGB(255,205,57)) end
	end
	for _, gui in ui:GetChildren() do if gui:IsA("ScreenGui") then gui:SetAttribute("MobilePlacementVersion","20261011") end end
	return {portraitDock=portraitDock.Name,adminInSettings=true}
end


end)()
local changes=layout(ui)
return {backup=backup:GetFullName(),layout=changes}

