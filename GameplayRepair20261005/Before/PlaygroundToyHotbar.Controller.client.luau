local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end

local function usable()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("PCDataReady") == true and not inRound() and humanoid and humanoid.Health > 0
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

local function bounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return Vector3.zero, Vector3.one end
	return (low + high) * 0.5, high - low
end

local function framePreview(record)
	if not record.model or not record.model.Parent then return end
	local viewport = record.button.Preview
	local camera = viewport.PreviewCamera
	local aspect = math.max(0.2, viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y))
	local angle = math.rad(camera.FieldOfView * 0.5)
	local distance = record.radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.1
	camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
	viewport.CurrentCamera = camera
end

local function preview(record, id)
	if record.id == id and (id == "" or record.model) then return end
	record.id = id
	record.generation += 1
	local generation = record.generation
	local world = record.button.Preview.World
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	record.model = nil
	record.button.Preview.Visible = id ~= ""
	record.button.PreviewNote.Visible = false
	if id == "" then return end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local original = assets and assets:FindFirstChild(id)
	if not original or not original:IsA("Model") then
		record.button.PreviewNote.Text = "NO PREVIEW"
		record.button.PreviewNote.Visible = true
		return
	end
	local model = original:Clone()
	model.Name = "ToyPreview"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
	end
	local center, size = bounds(model)
	model:PivotTo(CFrame.new(-center) * model:GetPivot())
	model.Parent = world
	record.model = model
	record.radius = math.max(0.05, size.Magnitude * 0.5)
	framePreview(record)
	local complete = false
	task.delay(8, function()
		if alive and generation == record.generation and not complete then
			record.button.PreviewNote.Text = "PREVIEW DELAYED"
			record.button.PreviewNote.Visible = true
		end
	end)
	task.spawn(function()
		local loaded = true
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ model }, function(contentId, status)
				if contentId ~= "" and status ~= Enum.AssetFetchStatus.Success then loaded = false end
			end)
		end)
		complete = true
		if not alive or generation ~= record.generation or not world.Parent then return end
		record.button.PreviewNote.Visible = not ok or not loaded
		record.button.PreviewNote.Text = "PREVIEW DELAYED"
		model.Parent = nil
		model.Parent = world
		framePreview(record)
	end)
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
	bar.Visible = hasToy and player:GetAttribute("PCDataReady") == true and not inRound() and not modalOpen()
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
	connect(button.Preview:GetPropertyChangedSignal("AbsoluteSize"), function() framePreview(record) end)
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
for _, key in ipairs({ "PCDataReady", "BBParticipating", "TGParticipating", "MDParticipating", "PCToyEmberUntil", "PCToyEmberShotUntil" }) do
	connect(player:GetAttributeChangedSignal(key), refresh)
end
for index = 1, 15 do connect(player:GetAttributeChangedSignal(string.format("PCToyCooldown_M%02d", index)), refresh) end
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
		if record.model then record.model:Destroy() end
	end
end)
syncLoadout()
