assert(not game:GetService("RunService"):IsRunning(),"Stop Play before completing voting visuals")
assert(game.PlaceId==95034648955135,"Wrong experience")
local shell=game:GetService("StarterGui").PlaygroundShell
local controller=shell.Controller
local expected,afterHash=1019411618,297437938
local function hash(s)
 s=s:gsub("\r\n","\n")local v=0 for i=1,#s do v=(v*31+s:byte(i))%2147483647 end return v
end
local current=hash(controller.Source)
assert(current==expected or current==afterHash,"Shell controller changed")
assert(tostring(controller.Capabilities)=="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior" and controller.Sandboxed==true,"Shell permissions changed")
for _,panel in {shell.VotePanel,shell.CompactVotePanel}do assert(panel:GetAttribute("DuckDuckGooseVoting20261010")==true,"Voting UI missing")end
local storage=game:GetService("ServerStorage")
if not storage:FindFirstChild("DuckDuckGooseFinalUiBackup20261010") then
 local backup=Instance.new("Folder")backup.Name,backup.Parent="DuckDuckGooseFinalUiBackup20261010",storage
 for _,object in {shell.VotePanel,shell.CompactVotePanel,controller}do local saved=object:Clone()if saved:IsA("BaseScript")then saved.Enabled=false end saved.Parent=backup end
end
local builder=(function()
local Builder = {}
local ids = { "BritishBulldog", "TagYoureIt", "StuckInTheMud", "HideAndSeek", "DuckDuckGoose" }
local navy = Color3.fromRGB(24,35,62)
local gold = Color3.fromRGB(246,189,62)

function Builder.Fallback(button)
	local old = button:FindFirstChild("ArtFallback")
	if old then old:Destroy() end
	for _, child in button:GetChildren() do if child:IsA("UIStroke") then child.Enabled=false end end
	local back = Instance.new("Frame")
	back.Name,back.Size,back.Position = "ArtFallback",UDim2.fromScale(1,1),UDim2.fromScale(0,0)
	back.BackgroundColor3,back.BorderSizePixel,back.ZIndex = navy,0,8
	back.Active,back.Selectable,back.Visible = false,false,not button.ReusableSkin.IsLoaded
	local corner=Instance.new("UICorner")corner.CornerRadius,corner.Parent=UDim.new(0,10),back
	local border=Instance.new("UIStroke")border.Color,border.Thickness,border.Parent=Color3.fromRGB(255,249,224),1.5,back
	local face=Instance.new("Frame")
	face.Name,face.Position,face.Size="Face",UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-8)
	face.BackgroundColor3,face.BorderSizePixel,face.ZIndex=button.BackgroundColor3,0,8
	face.Active,face.Selectable,face.Parent=false,false,back
	local innerCorner=Instance.new("UICorner")innerCorner.CornerRadius,innerCorner.Parent=UDim.new(0,7),face
	local innerBorder=Instance.new("UIStroke")innerBorder.Color,innerBorder.Thickness,innerBorder.Parent=Color3.fromRGB(255,249,224),1.2,face
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(195,195,195)),90,face
	back.Parent=button
	return back
end

function Builder.Hint(hint)
	for _, child in hint:GetDescendants() do if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then child:Destroy() end end
	hint.Text,hint.TextColor3,hint.TextStrokeTransparency="SWIPE OR SCROLL FOR ALL 5 GAMES",navy,1
	hint.Font,hint.ZIndex=Enum.Font.GothamMedium,13
	hint.TextTruncate,hint.TextWrapped,hint.TextScaled=Enum.TextTruncate.None,false,false
	hint.TextSize=13
end

local function readable(label, maximum)
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not limit then limit = Instance.new("UITextSizeConstraint") limit.Parent = label end
	limit.MinTextSize, limit.MaxTextSize = 10,maximum
	label.TextScaled = true
end

function Builder.Panel(panel)
	assert(not panel:FindFirstChild("Choices"), "Voting row already exists")
	local compact = panel.Name == "CompactVotePanel"
	local width, gap = compact and 128 or 154, 8
	local buttons, counters = {},{}
	for _, id in ids do
		local sourceId = id == "DuckDuckGoose" and "HideAndSeek" or id
		buttons[id], counters[id] = panel[sourceId]:Clone(),panel["Votes"..sourceId]:Clone()
	end
	for _, id in ids do
		local button, counter = panel:FindFirstChild(id),panel:FindFirstChild("Votes"..id)
		if button then button:Destroy() end
		if counter then counter:Destroy() end
	end
	panel.Size = UDim2.new(compact and .94 or .62,0,0,166)
	panel.Title.Position, panel.Title.Size = UDim2.new(0,14,0,9),UDim2.new(1,-112,0,25)
	panel.Timer.Position, panel.Timer.Size = UDim2.new(1,-88,0,10),UDim2.fromOffset(72,24)
	panel.Message.Position, panel.Message.Size = UDim2.new(0,14,1,-29),UDim2.new(1,-28,0,17)
	readable(panel.Title,22)
	readable(panel.Timer,22)
	readable(panel.Message,13)
	local choices = Instance.new("ScrollingFrame")
	choices.Name, choices.BackgroundTransparency, choices.BorderSizePixel = "Choices",1,0
	choices.Position, choices.Size = UDim2.fromOffset(14,39),UDim2.new(1,-28,0,82)
	choices.CanvasSize, choices.ScrollingDirection = UDim2.fromOffset(#ids*(width+gap)-gap,82),Enum.ScrollingDirection.X
	choices.AutomaticCanvasSize, choices.ScrollBarThickness = Enum.AutomaticSize.None,6
	choices.ScrollBarImageColor3, choices.ElasticBehavior = navy,Enum.ElasticBehavior.WhenScrollable
	choices.ClipsDescendants, choices.Selectable, choices.Parent = true,false,panel
	choices.ZIndex = 9
	local hint = panel.Message:Clone()
	hint.Name, hint.Text, hint.TextColor3 = "ScrollHint","SWIPE OR SCROLL FOR ALL 5 GAMES",navy
	hint.Position, hint.Size = UDim2.fromOffset(14,124),UDim2.new(1,-28,0,16)
	Builder.Hint(hint)
	hint.Parent = panel
	for index,id in ids do
		local card = Instance.new("Frame")
		card.Name, card.BackgroundTransparency, card.BorderSizePixel = id,1,0
		card.Position, card.Size, card.LayoutOrder = UDim2.fromOffset((index-1)*(width+gap),0),UDim2.fromOffset(width,73),index
		card.Parent = choices
		card.ZIndex = 9
		local button, counter = buttons[id],counters[id]
		button.Name, button.Position, button.Size = "Button",UDim2.fromOffset(0,0),UDim2.fromOffset(width,48)
		button.Text, button.TextTransparency = "",1
		button.Parent = card
		if id == "DuckDuckGoose" then
			button.BackgroundColor3 = gold
			button:SetAttribute("UISkinAssetKey","PNG/07-Resizable-Skins/gold-normal.png")
			button.LiveCaption.Text = "DUCK DUCK\nGOOSE"
			button.ReusableSkin.Image = "rbxassetid://84589903135132"
			button.ReusableSkin:SetAttribute("DefaultImage",button.ReusableSkin.Image)
		end
		button.ReusableSkin.ScaleType, button.ReusableSkin.SliceCenter = Enum.ScaleType.Slice,Rect.new(88,88,424,232)
		Builder.Fallback(button)
		readable(button.LiveCaption,compact and 16 or 19)
		counter.Name, counter.Position, counter.Size = "VoteCount",UDim2.fromOffset(0,51),UDim2.fromOffset(width,19)
		counter.Text, counter.Parent = "0 votes",card
		readable(counter,14)
	end
	for index,id in ids do
		local button = choices[id].Button
		button.NextSelectionLeft = choices[ids[math.max(1,index-1)]].Button
		button.NextSelectionRight = choices[ids[math.min(#ids,index+1)]].Button
	end
	panel:SetAttribute("DuckDuckGooseVoting20261010",true)
	return panel
end

function Builder.Admin(rounds)
	assert(not rounds:FindFirstChild("DuckDuckGoose"), "Admin card already exists")
	local card = rounds.HideAndSeek:Clone()
	card.Name, card.LayoutOrder = "DuckDuckGoose",5
	card.Title.Text, card.Status.Text = "DUCK DUCK GOOSE","Ready • 2–16 players"
	card.HSStart.Name = "DGStart"
	card.DGStart.Text, card.DGStart.LiveCaption.Text = "","START GOOSE ROUND"
	readable(card.Title,26)
	readable(card.Status,18)
	readable(card.DGStart.LiveCaption,22)
	card.Parent = rounds
	rounds.RoundSettings.LayoutOrder = 6
	return card
end

return Builder

end)()
for _,panel in {shell.VotePanel,shell.CompactVotePanel}do
 builder.Hint(panel.ScrollHint)
 for _,id in {"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}do builder.Fallback(panel.Choices[id].Button)end
 panel:SetAttribute("DuckDuckGooseVotingFallback20261010",true)
end
controller.Source=[==[local Players = game:GetService("Players")
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




]==]
return {fallbackCards=10,plainScrollHint=true,originalPNGsPreserved=true,capabilitiesPreserved=true}
