local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Install only while Play is stopped")
assert(game.PlaceId==95034648955135,"Wrong place")
local StarterGui=game:GetService("StarterGui")
local compactDock=assert(StarterGui.PlaygroundShell:FindFirstChild("CompactDock"),"Build CompactDock first")
for _,name in {"Shop","Pets","Toys"} do assert(compactDock:FindFirstChild(name) and compactDock[name]:IsA("GuiButton"),"Missing compact "..name.." button") end
local portrait=assert(StarterGui.PlaygroundIntermissionHUD:FindFirstChild("Portrait"),"Build Portrait intermission card first")
for _,name in {"Title","Timer","Detail","ReusableSkin","Fallback"} do assert(portrait:FindFirstChild(name),"Missing Portrait "..name) end
for _,name in {"DesktopDock","CompactDock","PortraitDock","RoundDock"} do
 local dock=assert(StarterGui.PlaygroundFishingHUD:FindFirstChild(name),"Build fishing "..name.." first")
 for _,row in {"Coins","XP"}do assert(dock:FindFirstChild(row) and dock[row]:FindFirstChild("Timer"),"Missing fishing boost row")end
end
local changes={
{path="StarterGui.PlaygroundShell.Controller",before=[[local Players = game:GetService("Players")
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
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

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
			value = math.clamp(value, 0.75, 1)
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
		and player:GetAttribute("MDParticipating") ~= true
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
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
dock.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
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
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
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
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local function refreshSpectatorVisibility()
    local watching = lobbyHudSuppressed()
    local participating = player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
    dock.Visible = not participating and not watching
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
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating and not lobbyHudSuppressed()
 dock.Visible=not participating and not lobbyHudSuppressed()
 if (participating or lobbyHudSuppressed()) and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and not lobbyHudSuppressed() and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)




]],after=[[local Players = game:GetService("Players")
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
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }

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
		and player:GetAttribute("MDParticipating") ~= true
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
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
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
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local function refreshSpectatorVisibility()
    local watching = lobbyHudSuppressed()
    local participating = player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
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
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
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




]]},
{path="StarterGui.PlaygroundShell.PlayerLevelController",before=[[local Players=game:GetService("Players")
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
 local narrow=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 local inGame=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 local useCompact=narrow and inGame
 if modal and notice.Visible then hideNotice() end
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact
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

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","PCDataReady","BBParticipating","TGParticipating","MDParticipating"}) do
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
]],after=[[local Players=game:GetService("Players")
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
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true
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

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","PCDataReady","BBParticipating","TGParticipating","MDParticipating"}) do
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
]]},
{path="StarterGui.PlaygroundIntermissionHUD.Controller",before=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local connections = {}
local elapsed = 0

local function render()
	local phase = state:GetAttribute("Phase")
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local compact = viewport.X < 900 or viewport.Y < 600
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local shown = not participating and phase ~= "Playing"
	local shell = gui.Parent:FindFirstChild("PlaygroundShell")
	local toast = shell and shell:FindFirstChild("RewardToast")
	local backdrop = shell and shell:FindFirstChild("Backdrop")
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	if backdrop and backdrop.Visible then shown = false end
	if session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true) then shown = false end
	if compact and toast and toast.Visible then shown = false end
	local title, timer, detail = "NEXT ROUND", "", "Preparing the lobby..."
	local status = state:GetAttribute("IntermissionStatus")
	if phase == "Voting" then
		local endsAt = state:GetAttribute("VotingEndsAt")
		if typeof(endsAt) == "number" and endsAt == endsAt and math.abs(endsAt) < math.huge then
			local seconds = math.max(0,math.ceil(endsAt-workspace:GetServerTimeNow()))
			timer = string.format("%d:%02d",math.floor(seconds/60),seconds%60)
		end
		title = "INTERMISSION"
		detail = status == "Next round starts in" and "Vote for the next game!" or status or "Vote for the next game!"
	elseif phase == "Paused" then
		title, detail = "ROUNDS PAUSED", "Automatic rounds paused by an admin"
	elseif phase == "Waiting" then
		title = "WAITING FOR PLAYERS"
		local count = state:GetAttribute("ReadyPlayerCount") or 0
		local minimum = state:GetAttribute("MinimumReadyPlayers") or 2
		detail = typeof(status) == "string" and status ~= "" and status or string.format("%d / %d players ready",count,minimum)
	end
	for _,card in {gui.Desktop,gui.Compact} do
		card.Visible = shown and (card == gui.Compact) == compact
		card.Title.Text = card == gui.Compact and phase == "Waiting" and "WAITING" or title
		card.Timer.Text, card.Detail.Text = timer, detail
		card.Fallback.Visible = not card.ReusableSkin.IsLoaded
	end
end

table.insert(connections,state.AttributeChanged:Connect(render))
table.insert(connections,player.AttributeChanged:Connect(render))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.1 then elapsed=0 render() end
end))
table.insert(connections,script.Destroying:Connect(function()
	for _,connection in connections do connection:Disconnect() end
end))
render()]],after=[[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local connections = {}
local elapsed = 0

local function render()
	local phase = state:GetAttribute("Phase")
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local short = math.min(viewport.X,viewport.Y)
	local compact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local portrait = compact and viewport.Y > viewport.X
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local shown = not participating and phase ~= "Playing"
	local shell = gui.Parent:FindFirstChild("PlaygroundShell")
	local toast = shell and shell:FindFirstChild("RewardToast")
	local backdrop = shell and shell:FindFirstChild("Backdrop")
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	if backdrop and backdrop.Visible then shown = false end
	if session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true) then shown = false end
	if compact and toast and toast.Visible then shown = false end
	for name, panels in pairs({ PlaygroundEmoteWheel = { "Panel" }, PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" } }) do
		local screen = gui.Parent:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, name in ipairs(panels) do
				local panel = screen:FindFirstChild(name)
				if panel and panel.Visible then shown = false end
			end
		end
	end
	local title, timer, detail = "NEXT ROUND", "", "Preparing the lobby..."
	local status = state:GetAttribute("IntermissionStatus")
	if phase == "Voting" then
		local endsAt = state:GetAttribute("VotingEndsAt")
		if typeof(endsAt) == "number" and endsAt == endsAt and math.abs(endsAt) < math.huge then
			local seconds = math.max(0,math.ceil(endsAt-workspace:GetServerTimeNow()))
			timer = string.format("%d:%02d",math.floor(seconds/60),seconds%60)
		end
		title = "INTERMISSION"
		detail = status == "Next round starts in" and "Vote for the next game!" or status or "Vote for the next game!"
	elseif phase == "Paused" then
		title, detail = "ROUNDS PAUSED", "Automatic rounds paused by an admin"
	elseif phase == "Waiting" then
		title = "WAITING FOR PLAYERS"
		local count = state:GetAttribute("ReadyPlayerCount") or 0
		local minimum = state:GetAttribute("MinimumReadyPlayers") or 2
		detail = typeof(status) == "string" and status ~= "" and status or string.format("%d / %d players ready",count,minimum)
	end
	local compactDetail = detail
	if phase == "Waiting" then
		compactDetail = typeof(status) == "string" and string.find(string.lower(status),"data",1,true)
			and "Loading player data" or string.format("Players ready: %d/%d",state:GetAttribute("ReadyPlayerCount") or 0,state:GetAttribute("MinimumReadyPlayers") or 2)
	elseif phase == "Paused" then
		compactDetail = "Paused by an admin"
	elseif phase == "Voting" and status ~= nil and status ~= "Next round starts in" then
		compactDetail = "Retrying next round"
	end
	for _,card in {gui.Desktop,gui.Compact,gui.Portrait} do
		card.Visible = shown and (card == gui.Desktop and not compact
			or card == gui.Compact and compact and not portrait
			or card == gui.Portrait and portrait)
		card.Title.Text = card ~= gui.Desktop and phase == "Waiting" and "WAITING" or title
		card.Timer.Text = timer
		card.Detail.Text = card == gui.Desktop and detail or compactDetail
		card.Fallback.Visible = not card.ReusableSkin.IsLoaded
	end
end

table.insert(connections,state.AttributeChanged:Connect(render))
table.insert(connections,player.AttributeChanged:Connect(render))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.1 then elapsed=0 render() end
end))
table.insert(connections,script.Destroying:Connect(function()
	for _,connection in connections do connection:Disconnect() end
end))
render()]]},
{path="StarterGui.PlaygroundFishingHUD.Controller",before=[[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local desktop = gui:WaitForChild("DesktopDock")
local compact = gui:WaitForChild("CompactDock")
local connections = {}
local attributes = { Coins = "PCFishingCoinsExpires", XP = "PCFishingXPExpires" }

local function remaining(expires, now)
	if typeof(expires) ~= "number" or expires ~= expires then return 0 end
	return math.max(0, math.ceil(expires - now))
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function refresh()
	local playerGui = gui.Parent
	local session = playerGui:FindFirstChild("PlaygroundSessionControls")
	local hidden = session and session:GetAttribute("UIHidden") == true
	local shell = playerGui:FindFirstChild("PlaygroundShell")
	local shop = shell and shell:FindFirstChild("ShopPanel")
	local donations = playerGui:FindFirstChild("PlaygroundDonations")
	local donationPanel = donations and donations:FindFirstChild("Panel")
	hidden = hidden or (shop and shop.Visible) or (donationPanel and donationPanel.Visible)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local isCompact = (UserInputService and UserInputService.TouchEnabled) or viewport.X < 800 or viewport.Y < 500
	compact.LayoutScale.Scale = math.clamp(math.min(viewport.X / 390, viewport.Y / 340), 0.85, 1)
	desktop.Visible = not hidden and not isCompact
	compact.Visible = not hidden and isCompact
	local now = workspace:GetServerTimeNow()
	for name, attribute in pairs(attributes) do
		local seconds = remaining(player:GetAttribute(attribute), now)
		for _, dock in { desktop, compact } do
			local row = dock[name]
			row.Visible = seconds > 0
			row.Timer.Text = formatTime(seconds)
		end
	end
end

for _, attribute in pairs(attributes) do
	table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		refresh()
	end
end))
script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
end)
refresh()

]],after=[[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local desktop = gui:WaitForChild("DesktopDock")
local compact = gui:WaitForChild("CompactDock")
local portrait = gui:WaitForChild("PortraitDock")
local round = gui:WaitForChild("RoundDock")
local docks = { desktop, compact, portrait, round }
local connections = {}
local attributes = { Coins = "PCFishingCoinsExpires", XP = "PCFishingXPExpires" }

local function remaining(expires, now)
	if typeof(expires) ~= "number" or expires ~= expires or math.abs(expires) == math.huge then return 0 end
	return math.max(0, math.ceil(expires - now))
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function modalOpen(playerGui)
	local panels = {
		PlaygroundShell = { "ShopPanel", "VotePanel", "CompactVotePanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
		PlaygroundSessionControls = { "Dock" },
		MudHUD = { "ColourPicker" },
	}
	for name, children in pairs(panels) do
		local screen = playerGui:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, child in ipairs(children) do
				local panel = screen:FindFirstChild(child)
				if panel and panel.Visible then return true end
			end
		end
	end
	return false
end

local function refresh()
	local playerGui = gui.Parent
	local session = playerGui:FindFirstChild("PlaygroundSessionControls")
	local hidden = session and (session:GetAttribute("UIHidden") == true
		or session:GetAttribute("Spectating") == true or session:GetAttribute("SessionMenuOpen") == true)
	hidden = hidden or modalOpen(playerGui)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local short = math.min(viewport.X,viewport.Y)
	local isCompact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local selected = not isCompact and desktop or participating and round
		or viewport.Y > viewport.X and portrait or compact
	for _, dock in docks do dock.Visible = not hidden and dock == selected end
	local now = workspace:GetServerTimeNow()
	for name, attribute in pairs(attributes) do
		local seconds = remaining(player:GetAttribute(attribute),now)
		for _, dock in docks do
			local row = dock[name]
			row.Visible = seconds > 0
			row.Timer.Text = formatTime(seconds)
		end
	end
end

for _, attribute in pairs(attributes) do
	table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
	table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(refresh))
end
local elapsed = 0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then elapsed = 0 refresh() end
end))
script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
]]}
}
local targets={}
local function canonical(source)return string.gsub(source,"\r\n","\n")end
for _,change in changes do
 local object=game
 for name in string.gmatch(change.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..change.path) end
 assert(object:IsA("LocalScript"),"Unexpected script class")
 assert(canonical(object.Source)==canonical(change.before),"Source changed; rebase "..change.path)
 table.insert(targets,{object=object,before=object.Source,source=change.after})
end
local ServerStorage=game:GetService("ServerStorage")
assert(not ServerStorage:FindFirstChild("PhoneHudRuntimeBackup20261009"),"Runtime backup already exists")
local backup=Instance.new("Folder")
backup.Name="PhoneHudRuntimeBackup20261009"
backup.Parent=ServerStorage
for _,target in targets do
 local copy=target.object:Clone()
 copy.Name=target.object.Parent.Name.."_"..target.object.Name
 copy.Enabled=false
 copy.Parent=backup
end
local ok,err=pcall(function()
 for _,target in targets do
  target.object.Source=target.source
  assert(target.object.Source==target.source,"Source write failed")
 end
end)
if not ok then
 for _,target in targets do target.object.Source=target.before end
 error(err)
end
return {changed=#targets,backup=backup:GetFullName()}

