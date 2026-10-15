assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = { {path="StarterGui.PlaygroundToyHotbar.Controller",expected=1886663257,after=674598432,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local bar = gui:WaitForChild("Bar")
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then bar.Visible = false return end
local catalog = require(catalogObject)
local connections = {}
local slots = {}
local alive = true
local pending = false
local requestToken = 0
local notice = ""
local noticeUntil = 0
local activeIndex = 0
local activeId = ""
local refresh
local backpackSuppressed = false
local savedBackpackState = nil

local function showNativeBackpack(show)
	if not show and not backpackSuppressed then
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok then return end
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if applied then savedBackpackState = previous backpackSuppressed = true end
	elseif show and backpackSuppressed then
		local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackState) end)
		if applied then backpackSuppressed = false savedBackpackState = nil end
	end
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("PCToyRoundPreparing") == true or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local wheel = player.PlayerGui:FindFirstChild("PlaygroundEmoteWheel")
	local wheelPanel = wheel and wheel:FindFirstChild("Panel")
	if wheel and wheel.Enabled and wheelPanel and wheelPanel.Visible then return true end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function sessionControlsBusy()
	local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
	return controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("SessionMenuOpen") == true or controls:GetAttribute("UIHidden") == true)
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and not sessionControlsBusy() and humanoid and humanoid.Health > 0
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = workspace:GetServerTimeNow() + (seconds or 3)
end

local function cooldownEndsAt(id)
	local now = workspace:GetServerTimeNow()
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	local attribute = id == "M07" and ember > now and "PCToyEmberShotUntil" or "PCToyCooldown_" .. id
	return tonumber(player:GetAttribute(attribute)) or 0
end

local function refreshThumbnail(record)
	if not alive or not record.button.Parent then return end
	local thumbnail = record.button.Thumbnail
	local note = record.button.PreviewNote
	note.Visible = thumbnail.Visible and (thumbnail.Image == "" or not thumbnail.IsLoaded)
	note.Text = (thumbnail.Image == "" or record.thumbnailTimedOut) and "NO PREVIEW" or "LOADING..."
end

local function preview(record, id)
	local item = catalog.ById[id]
	local image = item and typeof(item.thumbnail) == "string" and item.thumbnail or ""
	if record.id == id and record.button.Thumbnail.Image == image then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	record.thumbnailTimedOut = false
	record.button.Preview.Visible = false
	record.button.Thumbnail.Image = image
	record.button.Thumbnail.Visible = id ~= ""
	refreshThumbnail(record)
	if id ~= "" and image ~= "" and not record.button.Thumbnail.IsLoaded then
		task.delay(8, function()
			if alive and generation == record.generation and record.button.Parent and record.button.Thumbnail.Image == image then
				record.thumbnailTimedOut = true
				refreshThumbnail(record)
			end
		end)
	end
end

local function syncLoadout()
	if not alive then return end
	for index, record in ipairs(slots) do
		local id = player:GetAttribute("PCToySlot" .. tostring(index))
		if typeof(id) ~= "string" or not catalog.ById[id] then id = "" end
		preview(record, id)
		record.button.ItemName.Text = id ~= "" and catalog.ById[id].name or "EMPTY"
	end
	activeIndex = math.clamp(math.floor(tonumber(player:GetAttribute("PCToyIndex")) or 0), 0, 4)
	activeId = slots[activeIndex] and slots[activeIndex].id or ""
	refresh()
end

local function invoke(remoteName, action, payload, itemId)
	if pending or not alive then return end
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if not remote or not remote:IsA("RemoteFunction") then tell("Toys are getting ready.") refresh() return end
	pending = true
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if not alive or requestToken ~= token or not pending then return end
		requestToken += 1
		pending = false
		tell("That took too long. Try again.")
		refresh()
	end)
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		if not alive or requestToken ~= token then return end
		pending = false
		if ok and typeof(reply) == "table" then
			if reply.message then tell(reply.message) elseif not reply.ok then tell("That did not go through.") end
		else
			tell("That did not go through. Try again.")
		end
		refresh()
	end)
end

local function aimAt(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local position = screenPosition or camera.ViewportSize * 0.5
	local ray = screenPosition and camera:ScreenPointToRay(position.X, position.Y) or camera:ViewportPointToRay(position.X, position.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return hit and hit.Position or ray.Origin + ray.Direction * 150
end

local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end

refresh = function()
	if not alive then return end
	local hasToy = false
	for _, record in ipairs(slots) do if record.id ~= "" then hasToy = true break end end
	local available = usable()
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not sessionControlsBusy() and not modalOpen()
	showNativeBackpack(not (hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and gui.Enabled))
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, cooldownEndsAt(activeId) - now)
	local item = catalog.ById[activeId]
	local actionPending = item and item.toyActionPending == true
	local character = player.Character
	local heldTool = character and character:FindFirstChildOfClass("Tool")
	local heldId = heldTool and heldTool:GetAttribute("CatalogId")
	for index, record in ipairs(slots) do
		local selected = index == activeIndex and record.id ~= ""
		local selectionTag = record.button:FindFirstChild("Selected")
		selectionTag.Visible = selected
		selectionTag.Text = selected and heldId == record.id and "HELD" or "READY"
		record.button.Key.TextColor3 = selected and Color3.fromRGB(255, 215, 74) or Color3.fromRGB(255, 249, 224)
		record.button.Active = available and not pending and record.id ~= ""
		record.button.Selectable = record.button.Active
		record.button.ReusableSkin.ImageColor3 = record.id == "" and Color3.fromRGB(155, 155, 155) or Color3.new(1, 1, 1)
	end
	bar.Use.Active = available and not pending and activeId ~= "" and remaining <= 0 and not actionPending
	bar.Use.Selectable = bar.Use.Active
	local label = pending and "WAIT..." or actionPending and "SOON" or remaining > 0 and string.format("%.1fs", remaining) or "USE"
	bar.Use.Text = label
	bar.Use.LiveCaption.Text = label
	bar.Use.ReusableSkin.ImageColor3 = bar.Use.Active and Color3.new(1, 1, 1) or Color3.fromRGB(165, 165, 165)
	bar.Status.Text = now < noticeUntil and notice or not available and "Respawning..." or activeId == "" and "Select a toy" or actionPending and "Action coming soon" or UserInputService.TouchEnabled and "Tap a slot, then USE" or "1–4 select • click to use"
	local ember = tonumber(player:GetAttribute("PCToyEmberUntil")) or 0
	gui.Crosshair.Visible = bar.Visible and available and (activeId == "M10" or activeId == "M07" and ember > now)
end

for index = 1, 4 do
	local button = bar.Slots:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, id = nil, generation = 0 }
	table.insert(slots, record)
	connect(button.Activated, function() selectToy(index) end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() refreshThumbnail(record) end)
end
connect(bar.Use.Activated, function() useToy(nil) end)
local numberKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local index = numberKeys[input.KeyCode]
	if index then selectToy(index)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then useToy(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then useToy(nil) end
end)
connect(UserInputService.TouchTapInWorld, function(position, processed)
	if not processed and not UserInputService:GetFocusedTextBox() then useToy(position) end
end)
connect(player:GetAttributeChangedSignal("PCToyLoadoutVersion"), syncLoadout)
for _, key in ipairs({ "PCDataReady", "PCToyRoundPreparing", "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 25 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	alive = false
	showNativeBackpack(true)
	bar.Visible = false
	gui.Crosshair.Visible = false
	requestToken += 1
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, record in ipairs(slots) do
		record.generation += 1
	end
end)
syncLoadout()


]==]},
 {path="StarterGui.PlaygroundEmoteWheel.Controller",expected=1530477875,after=487787175,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local backdrop = gui:WaitForChild("Backdrop")
local toggle = gui:WaitForChild("Toggle")
local compactToggle = gui:WaitForChild("CompactEmoteToggle")
local portraitToggle = gui:WaitForChild("PortraitEmoteToggle")
local launchers = { toggle, compactToggle, portraitToggle }
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then for _, launcher in ipairs(launchers) do launcher.Visible = false end return end
local catalog = require(catalogObject)
local alive = true
local connections = {}
local slots = {}
local owned = {}
local equipped = {}
local ready = false
local page = 1
local pageCount = 1
local dances = {}
local busy = false
local requestSerial = 0
local requestWorker
local refreshQueued = false
local lastFetch = -math.huge
local notice = ""
local noticeUntil = 0
local previousSelection
local nativeSuppressed = false
local savedNativeState
local render
local request
local setOpen
local actionName = "PlaygroundEmoteWheelControls"
local numberKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function otherModalOpen()
    local controls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
    if controls and (controls:GetAttribute("Spectating") == true or controls:GetAttribute("UIHidden") == true or controls:GetAttribute("SessionMenuOpen") == true) then return true end
	if GuiService.MenuIsOpen then return true end
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local object = shell:FindFirstChild(name)
			if object and object.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local hub = admin and admin:FindFirstChild("AdminHub")
	return admin and admin.Enabled and hub and hub.Visible or false
end

local function isPlaying()
	local status = player:GetAttribute("PCEmotePlaybackStatus")
	return (status == "playing" or status == "loading") and (player:GetAttribute("PCEmoteUntil") or 0) > workspace:GetServerTimeNow()
end

local function tell(message, seconds)
	notice = tostring(message or "")
	noticeUntil = os.clock() + (seconds or 4)
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

local function buttonState(button, enabled, selected)
	button.Active = enabled
	button.Selectable = enabled
	local skin = button:FindFirstChild("ReusableSkin")
	local attribute = not enabled and "DisabledImage" or selected and "SelectedImage" or "NormalImage"
	local image = button:GetAttribute(attribute)
	if skin and typeof(image) == "string" then skin.Image = image end
end

local function restoreSelection()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
	previousSelection = nil
end

local function selectFirst()
	if not gamepadActive() then return end
	for _, record in ipairs(slots) do
		if record.button.Visible and record.button.Selectable then GuiService.SelectedObject = record.button return end
	end
	GuiService.SelectedObject = panel.ShopButton
end

local function imageState(record)
	if not record.item then return end
	if record.button.Thumbnail.IsLoaded then
		record.imageStatus = ""
	else
		if panel.Visible and not record.imageStartedAt then record.imageStartedAt = os.clock() end
		record.imageStatus = record.imageStartedAt and os.clock() - record.imageStartedAt >= 8 and "IMAGE UNAVAILABLE" or "LOADING IMAGE"
	end
end

local function setImage(record, item)
	if record.item == item then imageState(record) return end
	record.item = item
	record.imageStartedAt = nil
	record.imageStatus = ""
	local thumbnail = record.button.Thumbnail
	thumbnail.Image = item and item.thumbnail or ""
	thumbnail.Visible = item ~= nil
	if not item then return end
	imageState(record)
end

render = function()
	if not alive then return end
	dances = {}
	for _, item in ipairs(catalog.Items) do
		if item.slot == "Emote" and item.playable == true and item.available ~= false and owned[item.id] == true then
			table.insert(dances, item)
		end
	end
	pageCount = math.max(1, math.ceil(#dances / 8))
	page = math.clamp(page, 1, pageCount)
	local active = isPlaying() and player:GetAttribute("PCEmoteAction") or ""
	for index, record in ipairs(slots) do
		local item = dances[(page - 1) * 8 + index]
		setImage(record, item)
		local button = record.button
		button.Visible = item ~= nil
		buttonState(button, item ~= nil and ready and not busy, item ~= nil and (active == item.id or record.hovered == true))
		button.ItemName.Text = item and item.name or ""
		record.selected.Visible = item ~= nil and (active == item.id or record.hovered == true)
		button.State.Text = item and (active == item.id and "PLAYING" or record.imageStatus ~= "" and record.imageStatus or equipped.Emote == item.id and "PODIUM EMOTE" or "") or ""
	end
	panel.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	buttonState(panel.Previous, not busy and page > 1)
	buttonState(panel.Next, not busy and page < pageCount)
	buttonState(panel.StopButton, not busy and isPlaying())
	panel.StopButton.Visible = isPlaying()
	if notice ~= "" and os.clock() < noticeUntil then panel.Status.Text = notice
	elseif busy then panel.Status.Text = "Loading..."
	elseif not ready then panel.Status.Text = "Your emotes are getting ready."
	elseif #dances == 0 then panel.Status.Text = "No emotes yet. Unlock dances in the shop."
	else panel.Status.Text = tostring(#dances) .. " owned • Move or jump to stop" end
	panel.Hint.Text = not ready and "LOADING\nEMOTES" or #dances == 0 and "UNLOCK DANCES\nIN THE SHOP" or gamepadActive() and "A TO PLAY\nB TO CLOSE" or UserInputService.TouchEnabled and "TAP A\nDANCE" or "CLICK OR 1–8\nTO DANCE"
	local caption = toggle:FindFirstChild("LiveCaption")
	if caption then caption.Text = gamepadActive() and "EMOTES [D-PAD]" or UserInputService.TouchEnabled and "EMOTES" or "EMOTES [ . ]" end
end

local function acceptStatus(reply)
	if typeof(reply) ~= "table" then return false end
	if typeof(reply.owned) == "table" and typeof(reply.equipped) == "table" and typeof(reply.ready) == "boolean" then
		owned, equipped, ready = reply.owned, reply.equipped, reply.ready
		return true
	end
	return false
end

request = function(action, id)
	if not alive then return end
	if busy then
		if action == "GetStatus" then refreshQueued = true end
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
	if not remote or not remote:IsA("RemoteFunction") then tell("The emote shop is getting ready.") render() return end
	if action == "GetStatus" and os.clock() - lastFetch < 0.2 then
		refreshQueued = true
		return
	end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	if action == "GetStatus" then lastFetch = os.clock() end
	render()
	task.delay(8, function()
		if not alive or serial ~= requestSerial or not busy then return end
		requestSerial += 1
		busy = false
		if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
		tell("That took too long. Open the wheel to try again.")
		render()
	end)
	requestWorker = task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, id) end)
		if not alive or serial ~= requestSerial then return end
		requestWorker = nil
		busy = false
		local valid = ok and acceptStatus(reply)
		if not valid then
			tell("The emote shop could not respond. Try again.")
		elseif action == "UseEmote" and reply.ok == true then
			notice = ""
			setOpen(false)
		elseif action ~= "GetStatus" then
			tell(reply.message ~= "" and reply.message or (reply.ok and "Done." or "Try again in a moment."))
		end
		render()
		if panel.Visible then selectFirst() end
	end)
end

setOpen = function(show)
	if not alive then return end
	if show and (not gui.Enabled or inRound() or otherModalOpen()) then return end
	if show == panel.Visible then return end
	panel.Visible = show
	backdrop.Visible = show
	if show then
		previousSelection = GuiService.SelectedObject
		notice = ""
		render()
		selectFirst()
		request("GetStatus")
	else
		restoreSelection()
	end
end

local function playSlot(index)
	local record = slots[index]
	if not panel.Visible or busy or not ready or inRound() or otherModalOpen() or not record or not record.item then return end
	request("UseEmote", record.item.id)
end

for index = 1, 8 do
	local button = panel.Wheel:WaitForChild("Slot" .. tostring(index))
	local record = { button = button, selected = button:WaitForChild("Selected"), imageStatus = "", hovered = false }
	table.insert(slots, record)
	connect(button.Activated, function() playSlot(index) end)
	connect(button.MouseEnter, function() record.hovered = true render() end)
	connect(button.MouseLeave, function() record.hovered = false render() end)
	connect(button.SelectionGained, function() record.hovered = true render() end)
	connect(button.SelectionLost, function() record.hovered = false render() end)
	connect(button.Thumbnail:GetPropertyChangedSignal("IsLoaded"), function() imageState(record) render() end)
end

local function movePage(delta)
	if busy then return end
	page = math.clamp(page + delta, 1, pageCount)
	for _, record in ipairs(slots) do record.hovered = false end
	render()
	selectFirst()
end

for _, launcher in ipairs(launchers) do connect(launcher.Activated, function() setOpen(not panel.Visible) end) end
connect(panel.Close.Activated, function() setOpen(false) end)
connect(backdrop.Activated, function() setOpen(false) end)
connect(panel.Previous.Activated, function() movePage(-1) end)
connect(panel.Next.Activated, function() movePage(1) end)
connect(panel.StopButton.Activated, function() if not busy then request("StopEmote") end end)
connect(panel.ShopButton.Activated, function()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if not shell then tell("The shop is getting ready.") render() return end
	setOpen(false)
	shell:SetAttribute("OpenEmoteShopSerial", (tonumber(shell:GetAttribute("OpenEmoteShopSerial")) or 0) + 1)
end)

local function inputAction(_, state, input)
	if not gui.Enabled or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	local key = input.KeyCode
	if key == Enum.KeyCode.DPadDown and panel.Visible then return Enum.ContextActionResult.Pass end
	if key == Enum.KeyCode.Period or key == Enum.KeyCode.DPadDown then
		if inRound() or otherModalOpen() then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then setOpen(not panel.Visible) end
		return Enum.ContextActionResult.Sink
	end
	if not panel.Visible then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.ButtonB then setOpen(false)
		elseif key == Enum.KeyCode.ButtonL1 then movePage(-1)
		elseif key == Enum.KeyCode.ButtonR1 then movePage(1)
		else
			local index = table.find(numberKeys, key)
			if index then playSlot(index) end
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(actionName, inputAction, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Period, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, table.unpack(numberKeys))

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" }) do
	connect(player:GetAttributeChangedSignal(attribute), function() if inRound() then setOpen(false) end render() end)
end
for _, attribute in ipairs({ "PCInventoryVersion", "PCDataReady" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if player:GetAttribute("PCDataReady") ~= true then ready = false end
		refreshQueued = true
		render()
	end)
end
for _, attribute in ipairs({ "PCEmotePlaybackStatus", "PCEmoteAction", "PCEmoteUntil", "PCEmote" }) do
	connect(player:GetAttributeChangedSignal(attribute), function()
		if attribute == "PCEmotePlaybackStatus" and player:GetAttribute(attribute) == "failed" then
			tell(player:GetAttribute("PCEmotePlaybackMessage") or "This dance could not load.", 5)
		end
		render()
	end)
end
connect(UserInputService.LastInputTypeChanged, function() render() end)
connect(player.CharacterAdded, function() setOpen(false) refreshQueued = true end)
connect(player.CharacterRemoving, function() setOpen(false) end)
connect(gui:GetPropertyChangedSignal("Enabled"), function() if not gui.Enabled then setOpen(false) end end)
connect(ReplicatedStorage.ChildAdded, function(child) if child.Name == "PlaygroundShopRequest" then refreshQueued = true end end)

panel.Visible = false
backdrop.Visible = false
render()
refreshQueued = true

task.spawn(function()
	for _ = 1, 10 do
		if not alive then return end
		local ok, previous = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu) end)
		if ok then
			local applied = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)
			if applied then savedNativeState = previous nativeSuppressed = true return end
		end
		task.wait(0.5)
	end
	warn("Playground emote wheel could not hide the native emote menu")
end)

local function refreshAvailability()
    local blocked = inRound() or otherModalOpen() or not gui.Enabled
    local compact, portrait = compactLayout()
    local show = not blocked and not panel.Visible
    toggle.Visible = show and not compact
    compactToggle.Visible = show and compact and not portrait
    portraitToggle.Visible = show and compact and portrait
    if blocked then setOpen(false) end
end
local spectatorConnection
local function bindSpectatorControls(controls)
    if controls.Name ~= "PlaygroundSessionControls" then return end
    if spectatorConnection then spectatorConnection:Disconnect() end
    spectatorConnection = connect(controls.AttributeChanged, function(name)
        if name == "Spectating" or name == "UIHidden" or name == "SessionMenuOpen" then refreshAvailability() end
    end)
    refreshAvailability()
end
connect(player.PlayerGui.ChildAdded, bindSpectatorControls)
local sessionControls = player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end

task.spawn(function()
	while alive do
		refreshAvailability()
		if refreshQueued and not busy and os.clock() - lastFetch >= 0.2 then
			refreshQueued = false
			request("GetStatus")
		end
		if panel.Visible then render() end
		task.wait(0.2)
	end
end)

connect(script.Destroying, function()
	setOpen(false)
	alive = false
	requestSerial += 1
	if requestWorker then pcall(task.cancel, requestWorker) requestWorker = nil end
	ContextActionService:UnbindAction(actionName)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if nativeSuppressed then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, savedNativeState) end) end
end)
]==]},
 {path="StarterGui.PlaygroundSessionControls.Controller",expected=1535613685,after=1835871687,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
refresh()]==]},
 {path="StarterGui.PlaygroundDonations.Controller",expected=2014600268,after=369871353,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase",sandboxed=true,source=[==[local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui.Panel
local config = ReplicatedStorage:WaitForChild("PlaygroundDonationProducts")
local commerce = ReplicatedStorage:WaitForChild("PlaygroundCommerce")
local result = ReplicatedStorage:WaitForChild("PlaygroundDonationResult")
local offers, loading, pending, previousSelection = {}, false, nil, nil

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function close()
	panel.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
end

local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	panel.Fit.Scale = math.min(1, math.max(0.25, (viewport.X - 32) / 460), math.max(0.25, (viewport.Y - 100) / 460))
end

local function buy(offer)
	if not panel.Visible or inRound() or pending then return end
	if commerce:GetAttribute("Ready") ~= true then panel.Status.Text = "Donations are not available right now." return end
	if not offer then panel.Status.Text = "That amount isn't available yet. Choose an available button." return end
	pending = offer.id
	panel.Status.Text = "Confirm your donation in the Roblox window."
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, offer.id) end)
	if not ok then pending = nil panel.Status.Text = "Roblox couldn't open the purchase. Please try again." end
end

local function loadOffers()
	if loading then return end
	loading = true
	table.clear(offers)
	panel.Status.Text = "Checking donation options..."
	for _, button in panel.Amounts:GetChildren() do
		if button:IsA("GuiButton") then button.Active = false button:SetAttribute("ProductId", nil) end
	end
	local count = 0
	for _, entry in config:GetChildren() do
		if not entry:IsA("IntValue") or entry.Value <= 0 then continue end
		local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(entry.Value, Enum.InfoType.Product) end)
		if not ok or typeof(info) ~= "table" or info.IsForSale == false or typeof(info.PriceInRobux) ~= "number" or info.PriceInRobux < 1 then continue end
		local offer = { id = entry.Value, price = info.PriceInRobux }
		table.insert(offers, offer)
		count += 1
		local button = panel.Amounts:FindFirstChild(entry.Name)
		if button then
			button.Label.Text = tostring(offer.price) .. " ROBUX"
			button:SetAttribute("ProductId", offer.id)
			button.Active = true
		end
	end
	loading = false
	panel.Status.Text = count > 0 and "Every donation helps. Thank you!" or "Donations are coming soon."
end

for _, button in panel.Amounts:GetChildren() do
	if button:IsA("GuiButton") then
		button.Activated:Connect(function()
			local id = button:GetAttribute("ProductId")
			for _, offer in offers do if offer.id == id then buy(offer) return end end
			panel.Status.Text = "This donation option is not available yet."
		end)
	end
end

panel.OtherDonate.Activated:Connect(function()
	local text = panel.OtherAmount.Text:match("^%s*(%d+)%s*$")
	local amount = text and tonumber(text)
	if not amount or amount < 1 or amount > 1000000000 then panel.Status.Text = "Enter a whole Robux amount." return end
	for _, offer in offers do if offer.price == amount then buy(offer) return end end
	buy(nil)
end)
panel.Close.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if not panel.Visible or processed then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player or inRound() or prompt:GetAttribute("PlaygroundDonationBoard") ~= true then return end
	previousSelection = GuiService.SelectedObject
	panel.Visible = true
	fit()
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = panel.Amounts.Donation50 end
	task.spawn(loadOffers)
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if userId ~= player.UserId or productId ~= pending then return end
	pending = nil
	panel.Status.Text = purchased and "Waiting for Roblox to confirm your donation..." or "Purchase cancelled. You haven't donated."
end)
result.OnClientEvent:Connect(function(message)
	if typeof(message) == "string" then pending = nil panel.Status.Text = message end
end)
for _, attribute in { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" } do
	player:GetAttributeChangedSignal(attribute):Connect(function() if inRound() then close() end end)
end
local viewportConnection
local function bindCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
panel.Visible = false

]==]},
 {path="StarterGui.PlaygroundFishingHUD.Controller",expected=1670076257,after=991157405,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
		or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
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
for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" }) do
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
]==]},
 {path="StarterGui.PlaygroundBatControls.Controller",expected=1909341071,after=1263330899,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local button = gui:WaitForChild("Swing")
local skin = button:WaitForChild("ReusableSkin")
local fallback = button:WaitForChild("Fallback")
local connections = {}
local nextTapAt = 0
local focused = true
local elapsed = 0

local function equippedBat()
	if not UserInputService.TouchEnabled or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("MDParticipating") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("HSRagdolled") == true or player:GetAttribute("DGRagdolled") == true then return nil end
	local gameId
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then gameId = "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then gameId = "TagYoureIt" end
	elseif player:GetAttribute("HSParticipating") == true and player:GetAttribute("HSRole") == "Seeker" then
		local state = ReplicatedStorage:FindFirstChild("HideAndSeekState")
		if state and state:GetAttribute("Phase") == "Seeking" then gameId = "HideAndSeek" end
	elseif player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose" then
		local state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")
		if state and state:GetAttribute("Phase") == "Playing" and state:GetAttribute("TurnPhase") == "Chasing" then gameId = "DuckDuckGoose" end
	end
	if not gameId then return nil end
	for _, tool in character:GetChildren() do
		if tool:IsA("Tool") and tool.Enabled and tool:GetAttribute("PCBatWeapon") == true
			and tool:GetAttribute("WeaponGame") == gameId then return tool end
	end
	return nil
end

local function remainingCooldown()
	local at = player:GetAttribute("PCBatSwingAt")
	local serverRemaining = typeof(at) == "number" and at > 0 and at + 0.75 - workspace:GetServerTimeNow() or 0
	return math.max(0, nextTapAt - os.clock(), serverRemaining)
end

local function refresh()
	local bat = equippedBat()
	button.Visible = bat ~= nil
	local ready = bat ~= nil and focused and not GuiService.MenuIsOpen
		and not UserInputService:GetFocusedTextBox() and remainingCooldown() <= 0
	button.Active = ready
	button.Selectable = false
	skin.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(164, 170, 184)
	button.Hint.Text = remainingCooldown() > 0 and string.format("%.1fs", remainingCooldown()) or "TAP"
	fallback.Visible = not skin.IsLoaded
end

local function swing()
	local bat = equippedBat()
	if not button.Visible or not gui.Enabled or not bat or not focused or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() or remainingCooldown() > 0 then return end
	nextTapAt = os.clock() + 0.75
	local ok = pcall(function()
		bat:Activate()
		bat:Deactivate()
	end)
	if not ok then nextTapAt = 0 end
	refresh()
end

local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
connect(button.Activated, swing)
connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), refresh)
connect(player.CharacterRemoving, function() nextTapAt = 0 button.Visible = false end)
connect(player.CharacterAdded, function() nextTapAt = 0 refresh() end)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.05 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	for _, connection in connections do connection:Disconnect() end
	button.Visible = false
end)
refresh()
]==]},
 {path="StarterGui.PlaygroundIntermissionHUD.Controller",expected=1058767317,after=94519385,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Players",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
		or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
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
render()]==]}}
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
