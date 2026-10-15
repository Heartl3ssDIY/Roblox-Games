local Players = game:GetService("Players")
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
local catalogObject = ReplicatedStorage:WaitForChild("PlaygroundCatalog", 10)
if not catalogObject then toggle.Visible = false return end
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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function otherModalOpen()
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

connect(toggle.Activated, function() setOpen(not panel.Visible) end)
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

for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
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

task.spawn(function()
	while alive do
		local blocked = inRound() or otherModalOpen() or not gui.Enabled
		toggle.Visible = not blocked and not panel.Visible
		if blocked then setOpen(false) end
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

