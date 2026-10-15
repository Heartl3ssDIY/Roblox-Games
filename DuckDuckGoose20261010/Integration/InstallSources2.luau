assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = { {path="StarterGui.PlaygroundShell.Controller",expected=1831593661,after=297437938,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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




]==]},
 {path="StarterGui.PlaygroundShell.PlayerLevelController",expected=2047788710,after=1924872173,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("LevelPanel")
local compact=gui:WaitForChild("CompactLevelPanel")
local panels={panel,compact}
local notice=gui:WaitForChild("LevelUpNotice")
local noticeScale=notice:WaitForChild("NoticeScale")
local noticeGeneration=0
local noticeTweens={}
local lastAnnouncedLevel=nil
local refreshPending=false
local connections={}
local alive=true
local previewGeneration=0
local previewCharacter=nil
local previewPending=false

for _,target in ipairs(panels) do
 local viewport=target:WaitForChild("FacePreview")
 local camera=viewport:FindFirstChild("Camera")
 if not camera then
  camera=Instance.new("Camera")
  camera.Name="Camera"
  camera.FieldOfView=viewport:GetAttribute("PreviewFieldOfView") or 32
  camera.CFrame=viewport:GetAttribute("PreviewCameraCFrame") or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))
  camera.Parent=viewport
 end
 viewport.CurrentCamera=camera
end

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function progress(gradient,fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),NumberSequenceKeypoint.new(1,1)})
 end
end

local function integerText(value)
 local text=string.format("%.0f",math.max(0,math.floor(value)))
 local formatted=text:reverse():gsub("(%d%d%d)","%1,"):reverse()
 return formatted:gsub("^,","")
end

local function clearNoticeTweens()
 for _,tween in ipairs(noticeTweens) do tween:Cancel() tween:Destroy() end
 table.clear(noticeTweens)
end

local function hideNotice()
 noticeGeneration+=1
 clearNoticeTweens()
 notice.Visible=false
 notice.GroupTransparency=1
 noticeScale.Scale=1
end

local function tweenNotice(object,duration,properties)
 local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
 table.insert(noticeTweens,tween)
 tween:Play()
end

local function announceLevel(level)
 local controls=gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")
 if controls and (controls:GetAttribute("UIHidden")==true or controls:GetAttribute("Spectating")==true or controls:GetAttribute("SessionMenuOpen")==true) then return end
 noticeGeneration+=1
 local generation=noticeGeneration
 clearNoticeTweens()
 notice.Level.Text="LEVEL "..integerText(level)
 notice.Title.Text="LEVEL UP!"
 notice.GroupTransparency=1
 noticeScale.Scale=0.92
 notice.Visible=true
 tweenNotice(notice,0.2,{GroupTransparency=0})
 tweenNotice(noticeScale,0.24,{Scale=1})
 local hold=notice:GetAttribute("HoldSeconds")
 if typeof(hold)~="number" or hold~=hold or math.abs(hold)==math.huge then hold=3 end
 task.delay(math.clamp(hold,1.5,6),function()
  if not alive or generation~=noticeGeneration or not notice.Parent then return end
  clearNoticeTweens()
  tweenNotice(notice,0.2,{GroupTransparency=1})
  task.delay(0.22,function()
   if alive and generation==noticeGeneration and notice.Parent then hideNotice() end
  end)
 end)
end

local function observeLevel(level,ready)
 if not ready then
  lastAnnouncedLevel=nil
  if notice.Visible then hideNotice() end
  return
 end
 if lastAnnouncedLevel==nil then lastAnnouncedLevel=level return end
 if level>lastAnnouncedLevel then
  lastAnnouncedLevel=level
  announceLevel(level)
 end
end

local function sanitize(object)
 for _,descendant in ipairs(object:GetDescendants()) do
  local keep=descendant:IsA("BasePart") or descendant:IsA("DataModelMesh") or descendant:IsA("Decal") or descendant:IsA("Texture")
   or descendant:IsA("SurfaceAppearance") or descendant:IsA("Attachment") or descendant:IsA("Bone")
  if not keep then descendant:Destroy() end
 end
 local parts={}
 if object:IsA("BasePart") then table.insert(parts,object) end
 for _,descendant in ipairs(object:GetDescendants()) do if descendant:IsA("BasePart") then table.insert(parts,descendant) end end
 for _,part in ipairs(parts) do part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false part.CastShadow=false end
 return parts
end

local function clonePart(source)
 local ok,clone=pcall(function() return source:Clone() end)
 return ok and clone or nil
end

local function rebuildPreview()
 if not alive then return end
 local character=player.Character
 local head=character and character:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") then return end
 local generation=previewGeneration
 local headAttachments={}
 for _,attachment in ipairs(head:GetChildren()) do if attachment:IsA("Attachment") then headAttachments[attachment.Name]=true end end
 local prototype=Instance.new("Model")
 prototype.Name="AvatarPreview"
 local headClone=clonePart(head)
 if not headClone then prototype:Destroy() return end
 local headOrigin=head.CFrame
 local headParts=sanitize(headClone)
 for _,part in ipairs(headParts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
 headClone.Parent=prototype
 prototype.PrimaryPart=headClone
 for _,accessory in ipairs(character:GetChildren()) do
  if accessory:IsA("Accessory") then
   local handle=accessory:FindFirstChild("Handle")
   if handle and handle:IsA("BasePart") then
    local attachedToHead=false
    for _,attachment in ipairs(handle:GetChildren()) do
     if attachment:IsA("Attachment") and headAttachments[attachment.Name] then attachedToHead=true break end
     if attachment:IsA("Weld") and (attachment.Part0==head or attachment.Part1==head) then attachedToHead=true break end
    end
    if attachedToHead then
     local clone=clonePart(handle)
     if clone then
      clone.Name=accessory.Name
      local parts=sanitize(clone)
      for _,part in ipairs(parts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
      clone.Parent=prototype
     end
    end
   end
  end
 end
 if not alive or generation~=previewGeneration or character~=player.Character then prototype:Destroy() return end
 for _,target in ipairs(panels) do
  local viewport=target.FacePreview
  local world=viewport.World
  local clone=prototype:Clone()
  if clone then
   local old=world:FindFirstChild("AvatarPreview")
   if old then old:Destroy() end
   clone.Parent=world
   viewport.CurrentCamera=viewport.Camera
  end
 end
 prototype:Destroy()
end

local function schedulePreview()
 if previewPending then return end
 previewPending=true
 task.delay(0.12,function()
  previewPending=false
  rebuildPreview()
 end)
end

local characterConnection=nil
local function bindCharacter(character)
 previewGeneration+=1
 previewCharacter=character
 if characterConnection then characterConnection:Disconnect() characterConnection=nil end
 if character then
  characterConnection=character.DescendantAdded:Connect(function(descendant)
   if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Attachment") or descendant:IsA("SpecialMesh") then schedulePreview() end
  end)
 end
 schedulePreview()
end

local function refresh()
 if not alive then return end
 local levelValue=numberAttribute("PCLevel",0)
 local ready=player:GetAttribute("PCDataReady")==true and levelValue>=1
 local level=math.max(1,math.floor(levelValue))
 local required=math.max(1,numberAttribute("PCLevelXPRequired",200+50*(level-1)))
 local xp=math.clamp(numberAttribute("PCLevelXP",0),0,required)
 panel.Level.Text=ready and "LEVEL "..integerText(level) or "LEVEL —"
 compact.Level.Text=ready and "LV "..integerText(level) or "LV —"
 panel.NextLevel.Text=ready and "NEXT: LEVEL "..integerText(level+1) or "LOADING PROGRESS"
 compact.NextLevel.Text=ready and "NEXT: LV "..integerText(level+1) or "LOADING"
 local xpText=ready and integerText(xp).." / "..integerText(required).." XP" or "Loading..."
 panel.XP.Text=xpText
 compact.XP.Text=xpText
 for _,target in ipairs(panels) do
  local fill=target.XPTrack.Fill
  progress(fill.Progress,ready and xp/required or 0)
  local skin=fill:FindFirstChild("ReusableSkin")
  local skinProgress=skin and skin:FindFirstChild("Progress")
  if skinProgress then skinProgress.Transparency=fill.Progress.Transparency end
 end
 observeLevel(level,ready)
 local shop=gui:FindFirstChild("ShopPanel")
 local vote=gui:FindFirstChild("VotePanel")
 local compactVote=gui:FindFirstChild("CompactVotePanel")
 local mudHUD=gui.Parent and gui.Parent:FindFirstChild("MudHUD")
 local palette=mudHUD and mudHUD:FindFirstChild("ColourPicker")
 local controls=gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")
 local watching=controls and (controls:GetAttribute("Spectating")==true or controls:GetAttribute("UIHidden")==true or controls:GetAttribute("SessionMenuOpen")==true)
 local modal=watching or (shop and shop.Visible) or (vote and vote.Visible) or (compactVote and compactVote.Visible) or (mudHUD and mudHUD.Enabled and palette and palette.Visible)
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local narrow=viewport.X<=900 or math.min(viewport.X,viewport.Y)<=600
  or (math.min(viewport.X,viewport.Y)<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
 local useCompact=narrow
 if modal and notice.Visible then hideNotice() end
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact and not inGame
 if player.Character~=previewCharacter then bindCharacter(player.Character) end
end

local function scheduleRefresh()
 if refreshPending or not alive then return end
 refreshPending=true
 task.defer(function()
  refreshPending=false
  if alive then refresh() end
 end)
end

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","PCDataReady","BBParticipating","TGParticipating","MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated"}) do
 connect(player:GetAttributeChangedSignal(name),function()
  if name=="PCDataReady" and player:GetAttribute("PCDataReady")~=true then
   lastAnnouncedLevel=nil
   hideNotice()
  end
  scheduleRefresh()
 end)
end
local spectatorConnection
local function bindSpectatorControls(controls)
 if controls.Name~="PlaygroundSessionControls" then return end
 if spectatorConnection then spectatorConnection:Disconnect() end
 spectatorConnection=connect(controls.AttributeChanged,function(name)
  if name=="Spectating" or name=="UIHidden" or name=="SessionMenuOpen" then scheduleRefresh() end
 end)
 scheduleRefresh()
end
connect(player.PlayerGui.ChildAdded,bindSpectatorControls)
local sessionControls=player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end
connect(player.CharacterAdded,bindCharacter)
connect(player.CharacterRemoving,function() bindCharacter(nil) end)
connect(player.CharacterAppearanceLoaded,function(character) if character==player.Character then schedulePreview() end end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.15 then elapsed=0 refresh() end
end)
local function cleanup()
 if not alive then return end
 alive=false
 hideNotice()
 previewGeneration+=1
 if characterConnection then characterConnection:Disconnect() end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
end
connect(script.Destroying,cleanup)
connect(gui.Destroying,cleanup)
hideNotice()
bindCharacter(player.Character)
refresh()
]==]},
 {path="StarterGui.PlaygroundShell.CommerceController",expected=954923208,after=1938774835,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase",sandboxed=true,source=[==[local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local panel = shop:WaitForChild("BuyCoinsPanel")
local config = ReplicatedStorage:WaitForChild("PlaygroundCommerce")
local result = ReplicatedStorage:WaitForChild("PlaygroundCommerceResult")
local offers = {}
local connections = {}
local alive = true
local pending
local loading = false
local reloadQueued = false
local ownership = { VIP = "PCVIP", DoubleCoins = "PCDoubleCoins", DoubleXP = "PCDoubleXP" }

local function connect(signal, callback)
 local connection = signal:Connect(callback)
 table.insert(connections, connection)
 return connection
end

local function inRound()
 return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function caption(button, text)
 button.Text = text
 button.LiveCaption.Text = text
end

local function owned(name)
 local attribute = ownership[name]
 return attribute and player:GetAttribute(attribute) == true
end

local function included(name)
 return name ~= "VIP" and ownership[name] ~= nil and player:GetAttribute("PCVIP") == true
end

local function refresh()
 for name, offer in pairs(offers) do
  local card = offer.card
  local entry = config:FindFirstChild(name)
  local configured = entry and entry:IsA("IntValue") and entry.Value > 0
  local ready = config:GetAttribute("Ready") == true and player:GetAttribute("PCDataReady") == true
  local valid = configured and offer.id == entry.Value and offer.price ~= nil
  local isOwned, isIncluded = owned(name), included(name)
  local canBuy = ready and valid and not isOwned and not isIncluded and pending == nil and not inRound()
  card.Buy.Active = canBuy
  card.Buy.Selectable = canBuy
  card.Buy.AutoButtonColor = canBuy
  caption(card.Buy, isOwned and "OWNED" or isIncluded and "IN VIP" or tostring(offer.price or entry and entry:GetAttribute("Robux") or offer.plannedPrice) .. " ROBUX")
  card.Availability.Text = isOwned and "OWNED" or isIncluded and "INCLUDED WITH VIP" or not configured and "COMING SOON" or not valid and "UNAVAILABLE" or not ready and "GETTING READY" or "AVAILABLE"
  card.Buy.ReusableSkin.ImageColor3 = canBuy and Color3.new(1, 1, 1) or Color3.fromRGB(190, 196, 208)
 end
end

local function loadOffers()
 if loading then reloadQueued = true return end
 loading = true
 local available = 0
 for name, offer in pairs(offers) do
  local entry = config:FindFirstChild(name)
  local id = entry and entry:IsA("IntValue") and entry.Value or 0
  offer.id, offer.price = id, nil
  offer.kind = entry and entry:GetAttribute("Kind")
  if id > 0 then
   local infoType = offer.kind == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
   local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(id, infoType) end)
   if not alive then return end
   if entry.Value == id and ok and typeof(info) == "table" and info.IsForSale ~= false and typeof(info.PriceInRobux) == "number" and info.PriceInRobux >= 1 then
    offer.price = info.PriceInRobux
    available += 1
   end
  end
 end
 loading = false
 refresh()
 if not pending then
  panel.Status.Text = available > 0 and "Roblox confirms the price before you buy." or "Purchases are coming soon."
 end
 if reloadQueued then reloadQueued = false task.defer(loadOffers) end
end

local function buy(name)
 local offer = offers[name]
 local entry = config:FindFirstChild(name)
 if not alive or not shop.Visible or not panel.Visible or pending or inRound() or not offer or not offer.card.Buy.Active then return end
 if not entry or entry.Value ~= offer.id or offer.id <= 0 or not offer.price or config:GetAttribute("Ready") ~= true or player:GetAttribute("PCDataReady") ~= true or owned(name) or included(name) then refresh() return end
 pending = { id = offer.id, kind = offer.kind }
 panel.Status.Text = "Confirm your purchase in the Roblox window."
 refresh()
 local ok = pcall(function()
  if offer.kind == "GamePass" then MarketplaceService:PromptGamePassPurchase(player, offer.id)
  else MarketplaceService:PromptProductPurchase(player, offer.id) end
 end)
 if not ok and alive then
  pending = nil
  panel.Status.Text = "Roblox couldn't open the purchase. Please try again."
  refresh()
 end
end

for _, card in panel.Offers:GetChildren() do
 if card:IsA("Frame") and card:FindFirstChild("Buy") then
  local entry = config:FindFirstChild(card.Name)
  offers[card.Name] = { card = card, plannedPrice = entry and entry:GetAttribute("Robux") or 0 }
  connect(card.Buy.Activated, function() buy(card.Name) end)
 end
end

local function bindEntry(entry)
 if not entry:IsA("IntValue") or not offers[entry.Name] then return end
 connect(entry.Changed, function() task.spawn(loadOffers) end)
 connect(entry.AttributeChanged, function() task.spawn(loadOffers) end)
 task.spawn(loadOffers)
end
for _, entry in config:GetChildren() do bindEntry(entry) end
connect(config.ChildAdded, bindEntry)
connect(config.ChildRemoved, function() task.spawn(loadOffers) end)
connect(config:GetAttributeChangedSignal("Ready"), refresh)
for _, attribute in { "PCDataReady", "PCVIP", "PCDoubleCoins", "PCDoubleXP", "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" } do
 connect(player:GetAttributeChangedSignal(attribute), refresh)
end
connect(panel:GetPropertyChangedSignal("Visible"), function()
 if panel.Visible then task.spawn(loadOffers) end
end)
connect(shop:GetPropertyChangedSignal("Visible"), function()
 if shop.Visible and panel.Visible then task.spawn(loadOffers) end
end)
connect(MarketplaceService.PromptProductPurchaseFinished, function(userId, productId, purchased)
 if userId ~= player.UserId or not pending or pending.kind == "GamePass" or productId ~= pending.id then return end
 pending = nil
 panel.Status.Text = purchased and "Waiting for Roblox to confirm your coins..." or "Purchase cancelled."
 refresh()
end)
connect(MarketplaceService.PromptGamePassPurchaseFinished, function(who, passId, purchased)
 if who ~= player or not pending or pending.kind ~= "GamePass" or passId ~= pending.id then return end
 pending = nil
 panel.Status.Text = purchased and "Waiting for Roblox to confirm your pass..." or "Purchase cancelled."
 refresh()
end)
connect(result.OnClientEvent, function(message)
 if typeof(message) == "string" then
  pending = nil
  panel.Status.Text = message
 end
 refresh()
end)
script.Destroying:Connect(function()
 alive = false
 for _, connection in connections do connection:Disconnect() end
 table.clear(connections)
end)
refresh()
task.spawn(loadOffers)
]==]},
 {path="StarterGui.PlaygroundAdminPanel.Controller",expected=1332480643,after=288410300,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
]==]}}
local function fingerprint(source)
 source = string.gsub(source,"\r\n","\n")
 local value=0
 for index=1,#source do value=(value*31+string.byte(source,index))%2147483647 end
 return value
end
local objects={}
for _,entry in entries do
 local object=game
 for name in string.gmatch(entry.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..entry.path) end
 local hash=fingerprint(object.Source)
 assert(hash==entry.expected or hash==entry.after,"Source changed: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
 objects[entry.path]=object
end
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("DuckDuckGooseIntegrationBackup20261010")
if not backup then backup=Instance.new("Folder") backup.Name,backup.Parent="DuckDuckGooseIntegrationBackup20261010",storage end
local changed=0
for _,entry in entries do
 local object=objects[entry.path]
 if fingerprint(object.Source)~=entry.after then
  local snapshot=object:Clone()
  snapshot.Name=entry.path
  if snapshot:IsA("BaseScript") then snapshot.Enabled=false end
  snapshot.Parent=backup
  object.Source=entry.source
  object:SetAttribute("DuckDuckGooseIntegrated20261010",true)
  changed+=1
 end
end
return {patched=changed,capabilitiesPreserved=true,backup=backup:GetFullName()}
