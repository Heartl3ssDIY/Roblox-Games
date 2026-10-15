local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local Abilities = {}

local function remaining(player, name, now)
	local value = player:GetAttribute(name)
	return typeof(value) == "number" and value == value and value < math.huge and math.max(0, value - now) or 0
end

function Abilities.Describe(player, phase, now)
	local role = player:GetAttribute("HSRole")
	local participating = player:GetAttribute("HSParticipating") == true
	local active = participating and (phase == "Hiding" or phase == "Seeking")
	local mobile = active and player:GetAttribute("HSHiding") ~= true and player:GetAttribute("HSRagdolled") ~= true
	local hider = active and role == "Hider" and player:GetAttribute("HSPropMorphed") == true
	local seeker = active and role == "Seeker" and phase == "Seeking"
	local primary = hider and "ChangeProp" or seeker and "Scan" or nil
	local primaryWait = remaining(player, hider and "HSSwitchReadyAt" or "HSScanReadyAt", now)
	local scanTime = seeker and remaining(player, "HSScanActiveUntil", now) or 0
	local decoyWait = remaining(player, "HSDecoyReadyAt", now)
	return {
		primary = primary, primaryReady = mobile and primary ~= nil and primaryWait <= 0,
		primaryWait = primaryWait, scanTime = scanTime,
		decoy = hider, decoyReady = mobile and hider and decoyWait <= 0,
		decoyWait = decoyWait, decoyCount = math.clamp(tonumber(player:GetAttribute("HSDecoyCount")) or 0, 0, 3),
		revealed = active and role == "Hider" and remaining(player, "HSRevealedUntil", now) or 0,
		hidden = player:GetAttribute("HSHiding") == true,
	}
end

function Abilities.Layout(viewport, touch)
	if viewport.Y > viewport.X then return "Portrait" end
	local short, long = math.min(viewport.X, viewport.Y), math.max(viewport.X, viewport.Y)
	if touch or viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400) then return "Compact" end
	return "Desktop"
end

function Abilities.Start(gui, state, remote)
	local player = Players.LocalPlayer
	local connections, reveals = {}, {}
	local running, focused, elapsed, nextSendAt = true, true, 0, 0
	local actionName = "HideSeekPropAbilities"
	local bars = { Desktop = gui.DesktopAbilities, Compact = gui.CompactAbilities, Portrait = gui.PortraitAbilities }
	local notices = { Desktop = gui.DesktopRevealNotice, Compact = gui.CompactRevealNotice, Portrait = gui.PortraitRevealNotice }
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "LocalHideSeekRevealEffects"
	effectFolder.Parent = workspace

	local function connect(signal, callback)
		table.insert(connections, signal:Connect(callback))
	end
	local function session()
		return gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")
	end
	local function inputReady()
		local controls = session()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		return running and focused and gui.Enabled and not GuiService.MenuIsOpen
			and not UserInputService:GetFocusedTextBox() and humanoid and humanoid.Health > 0
			and not (controls and controls:GetAttribute("SessionMenuOpen") == true)
	end
	local function keyHint(pc, gamepad)
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "TAP" end
		if last.Name:find("Gamepad", 1, true) then
			local label = UserInputService:GetStringForKeyCode(gamepad)
			return label ~= "" and label or gamepad.Name:gsub("Button", "")
		end
		return "[" .. pc .. "]"
	end
	local function dropEffect(target)
		local record = reveals[target]
		if not record then return end
		record.folder:Destroy()
		if record.sourceAttachment then record.sourceAttachment:Destroy() end
		if record.targetAttachment then record.targetAttachment:Destroy() end
		reveals[target] = nil
	end
	local function clearEffects()
		for target in pairs(reveals) do dropEffect(target) end
	end
	local function lockerModel(target)
		local name = target:GetAttribute("HSLockerName")
		if target:GetAttribute("HSHiding") ~= true or typeof(name) ~= "string" or name == "" then return nil end
		local arena = workspace:FindFirstChild("Hide and Seek")
		local gameplay = arena and arena:FindFirstChild("Gameplay")
		local lockers = gameplay and gameplay:FindFirstChild("LockerSpots")
		return lockers and lockers:FindFirstChild(name)
	end
	local function makeEffect(target, character, root)
		local folder = Instance.new("Folder")
		folder.Name = tostring(target.UserId)
		folder.Parent = effectFolder
		local highlight = Instance.new("Highlight")
		highlight.Name = "RevealedHider"
		highlight.FillColor = Color3.fromRGB(255, 44, 62)
		highlight.OutlineColor = Color3.fromRGB(255, 45, 58)
		highlight.FillTransparency = 0.83
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = folder
		local marker = Instance.new("BillboardGui")
		marker.Name = "RevealMarker"
		marker.Size = UDim2.fromOffset(106, 26)
		marker.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 1800
		marker.Adornee = root
		marker.Parent = folder
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(133, 22, 38)
		label.BackgroundTransparency = 0.12
		label.TextColor3 = Color3.fromRGB(255, 249, 230)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Text = "REVEALED"
		label.Parent = marker
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		local attachment = Instance.new("Attachment")
		attachment.Name = "LocalRevealTarget"
		attachment.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "RedRevealBeam"
		beam.Attachment1 = attachment
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 45, 62))
		beam.Transparency = NumberSequence.new(0.35)
		beam.Width0, beam.Width1 = 0.09, 0.16
		beam.FaceCamera = true
		beam.LightEmission = 0.8
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = folder
		local record = { folder = folder, character = character, root = root, highlight = highlight, marker = marker, label = label, beam = beam, targetAttachment = attachment }
		reveals[target] = record
		return record
	end
	local function updateEffects(now)
		local phase = state:GetAttribute("Phase")
		local participating = player:GetAttribute("HSParticipating") == true
		local viewing = participating and (phase == "Hiding" or phase == "Seeking")
		if not viewing then clearEffects() return end
		local seeker = player:GetAttribute("HSRole") == "Seeker" and phase == "Seeking"
		local seen = {}
		for _, target in ipairs(Players:GetPlayers()) do
			local seconds = remaining(target, "HSRevealedUntil", now)
			local character = target.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if (seeker or target == player) and target:GetAttribute("HSParticipating") == true
				and target:GetAttribute("HSRole") == "Hider" and seconds > 0 and root and humanoid and humanoid.Health > 0 then
				seen[target] = true
				local record = reveals[target]
				if record and (record.character ~= character or record.root ~= root) then dropEffect(target) record = nil end
				record = record or makeEffect(target, character, root)
				record.highlight.Adornee = lockerModel(target) or character:FindFirstChild("SchoolPropMorph") or character
				record.highlight.OutlineTransparency = 0.1 + 0.12 * (0.5 + 0.5 * math.sin(now * 6))
				record.label.Text = "REVEALED " .. math.ceil(seconds) .. "s"
				local sourceId = target:GetAttribute("HSRevealSource")
				local source = typeof(sourceId) == "number" and Players:GetPlayerByUserId(sourceId)
				local sourceRoot = source and source.Character and source.Character:FindFirstChild("HumanoidRootPart")
				if sourceRoot ~= record.sourceRoot then
					if record.sourceAttachment then record.sourceAttachment:Destroy() end
					record.sourceRoot, record.sourceAttachment = sourceRoot, nil
					if sourceRoot then
						local attachment = Instance.new("Attachment")
						attachment.Name = "LocalRevealSource"
						attachment.Position = Vector3.new(0, 1, 0)
						attachment.Parent = sourceRoot
						record.sourceAttachment = attachment
					end
					record.beam.Attachment0 = record.sourceAttachment
				end
				record.beam.Enabled = sourceRoot ~= nil and record.sourceAttachment ~= nil
			end
		end
		for target in pairs(reveals) do if not seen[target] then dropEffect(target) end end
	end
	local refresh
	local function send(action)
		if not inputReady() or os.clock() < nextSendAt then return end
		local data = Abilities.Describe(player, state:GetAttribute("Phase"), workspace:GetServerTimeNow())
		if action == "Primary" then action = data.primary end
		if action == "DropDecoy" and not data.decoyReady or action ~= "DropDecoy" and (action ~= data.primary or not data.primaryReady) then return end
		nextSendAt = os.clock() + 0.2
		remote:FireServer(action)
		refresh()
	end
	refresh = function()
		if not running or not gui.Parent then return end
		local camera = workspace.CurrentCamera
		local variant = Abilities.Layout(camera and camera.ViewportSize or Vector2.new(1280,720), UserInputService.TouchEnabled)
		local now = workspace:GetServerTimeNow()
		local data = Abilities.Describe(player, state:GetAttribute("Phase"), now)
		local controls = session()
		local shown = gui.Enabled and not (controls and (controls:GetAttribute("UIHidden") == true or controls:GetAttribute("SessionMenuOpen") == true))
		local ready = inputReady() == true
		for name, bar in pairs(bars) do
			bar.Visible = shown and name == variant and data.primary ~= nil and not data.hidden
			local primary = bar.Primary
			local decoy = bar.Decoy
			primary.Caption.Text = data.primary == "Scan" and (data.scanTime > 0 and "SCANNING" or "SCAN") or "CHANGE PROP"
			primary.Hint.Text = data.scanTime > 0 and (math.ceil(data.scanTime) .. "s ACTIVE")
				or data.primaryWait > 0 and (math.ceil(data.primaryWait) .. "s")
				or keyHint("E", Enum.KeyCode.ButtonY)
			primary.Active = ready and data.primaryReady
			primary.Selectable = primary.Active and not UserInputService.TouchEnabled
			primary.ReusableSkin.ImageColor3 = primary.Active and Color3.new(1,1,1) or Color3.fromRGB(150,155,170)
			primary.Fallback.Visible = not primary.ReusableSkin.IsLoaded
			decoy.Visible = data.decoy == true
			decoy.Caption.Text = data.decoyCount >= 3 and "REPLACE DECOY" or "DECOY"
			decoy.Hint.Text = string.format("%d/3 · %s", data.decoyCount, data.decoyWait > 0 and (math.ceil(data.decoyWait) .. "s") or keyHint("Q", Enum.KeyCode.ButtonB))
			decoy.Active = ready and data.decoyReady
			decoy.Selectable = decoy.Active and not UserInputService.TouchEnabled
			decoy.ReusableSkin.ImageColor3 = decoy.Active and Color3.new(1,1,1) or Color3.fromRGB(150,155,170)
			decoy.Fallback.Visible = not decoy.ReusableSkin.IsLoaded
		end
		for name, notice in pairs(notices) do
			notice.Visible = shown and name == variant and data.revealed > 0
			notice.Caption.Text = "REVEALED — MOVE! " .. math.ceil(data.revealed) .. "s"
			notice.Reason.Text = player:GetAttribute("HSRevealReason") == "Decoy" and "A seeker hit your decoy" or "A seeker is scanning"
		end
		updateEffects(now)
	end
	for _,bar in pairs(bars) do
		connect(bar.Primary.Activated, function() send("Primary") end)
		connect(bar.Decoy.Activated, function() send("DropDecoy") end)
	end
	ContextActionService:BindActionAtPriority(actionName, function(_, inputState, input)
		if not inputReady() or player:GetAttribute("HSParticipating") ~= true then return Enum.ContextActionResult.Pass end
		local data = Abilities.Describe(player, state:GetAttribute("Phase"), workspace:GetServerTimeNow())
		local decoy = input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB
		if not data.primary or data.hidden or decoy and not data.decoy then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then send(decoy and "DropDecoy" or "Primary") end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value + 1, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)
	connect(UserInputService.WindowFocusReleased, function() focused = false refresh() end)
	connect(UserInputService.WindowFocused, function() focused = true refresh() end)
	connect(UserInputService.LastInputTypeChanged, refresh)
	connect(player.CharacterRemoving, clearEffects)
	connect(Players.PlayerRemoving, dropEffect)
	connect(RunService.Heartbeat, function(dt)
		elapsed += dt
		if elapsed >= 0.1 then elapsed = 0 refresh() end
	end)
	local function destroy()
		if not running then return end
		running = false
		ContextActionService:UnbindAction(actionName)
		clearEffects()
		effectFolder:Destroy()
		for _,connection in ipairs(connections) do connection:Disconnect() end
		for _,bar in pairs(bars) do bar.Visible = false end
		for _,notice in pairs(notices) do notice.Visible = false end
	end
	connect(gui.Destroying, destroy)
	refresh()
	return destroy
end

return Abilities

