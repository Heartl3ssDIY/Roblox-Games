local gui=game.StarterGui.HideAndSeekHUD
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
assert(gui.Controller.Source==[======[local Players = game:GetService("Players")
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
	elseif phase == "Hiding" then instruction = role == "Seeker" and "Wait while players hide" or "Blend in before seekers are released"
	elseif phase == "Seeking" then instruction = role == "Seeker" and "Find props • Search cupboards and drawers" or "Stay hidden or run from seekers"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	local propName = player:GetAttribute("HSPropName")
	if role ~= "Seeker" and player:GetAttribute("HSPropMorphed") == true and typeof(propName) == "string" and phase ~= "Results" then
		instruction = "YOU ARE A " .. string.upper(propName)
	end
	if player:GetAttribute("HSHiding") == true then instruction = "Hidden inside • Leave to run" end
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
		local stamina = math.clamp((player:GetAttribute("HSStamina") or 0) / math.max(1, player:GetAttribute("HSMaxStamina") or 25), 0, 1)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(stamina, 1)
		button.StaminaText.Text = string.format("%.1f / %d", player:GetAttribute("HSStamina") or 0, player:GetAttribute("HSMaxStamina") or 25)
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
for _, name in { "HSParticipating", "HSRole", "HSHiding", "HSRagdolled", "HSStamina", "HSMaxStamina", "HSPropName", "HSPropMorphed" } do connect(player:GetAttributeChangedSignal(name), refresh) end
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
]======],"Hide and Seek UI changed since inspection")
assert(not gui:FindFirstChild("Abilities"),"Abilities already installed")
local backup=Instance.new("Folder")
backup.Name="HideSeekAbilitiesUIBackup20261012"
backup.Parent=game.ServerStorage
gui:Clone().Parent=backup
local templates=Instance.new("Folder")
templates.Name="AbilityTemplates"
templates.Parent=gui
local function buttonTemplate(name,image)
 local button=gui.LeaveLocker:Clone()
 button.Name=name
 button.Text=""
 button.Visible=false
 button.Active=false
 button.Selectable=false
 button.AnchorPoint=Vector2.zero
 button.Position=UDim2.fromOffset(0,0)
 button.Size=UDim2.fromOffset(104,44)
 button.ReusableSkin.Image=image
 button.ReusableSkin.ImageColor3=Color3.new(1,1,1)
 button.Caption.Text=name=="Primary" and "CHANGE PROP" or "DECOY"
 button.Hint.Text=name=="Primary" and "[E]" or "0/3 · [Q]"
 button.Parent=templates
 return button
end
local primaryTemplate=buttonTemplate("Primary",gui.DesktopSprint.ReusableSkin.Image)
local decoyTemplate=buttonTemplate("Decoy",gui.LeaveLocker.ReusableSkin.Image)
for _,spec in ipairs({
 {"Desktop",UDim2.new(0.5,-196,1,-18),UDim2.fromOffset(216,48)},
 {"Compact",UDim2.new(0.5,0,1,-18),UDim2.new(0.42,0,0,44)},
 {"Portrait",UDim2.new(0.5,0,1,-246),UDim2.new(0.6,0,0,44)}
}) do
 local bar=Instance.new("Frame")
 bar.Name=spec[1].."Abilities"
 bar.AnchorPoint=Vector2.new(0.5,1)
 bar.Position=spec[2]
 bar.Size=spec[3]
 bar.BackgroundTransparency=1
 bar.Visible=false
 bar.ZIndex=10
 if spec[1]~="Desktop" then local constraint=Instance.new("UISizeConstraint") constraint.MinSize=Vector2.new(180,44) constraint.MaxSize=Vector2.new(216,44) constraint.Parent=bar end
 for _,template in ipairs({primaryTemplate,decoyTemplate}) do
  local button=template:Clone()
  button.Visible=true
  button.Size=UDim2.new(0.5,-4,1,0)
  button.Position=template==primaryTemplate and UDim2.new(0.5,4,0,0) or UDim2.fromScale(0,0)
  button.ZIndex=11
  button.Parent=bar
 end
 bar.Parent=gui
 local notice=Instance.new("Frame")
 notice.Name=spec[1].."RevealNotice"
 notice.AnchorPoint=Vector2.new(0.5,0)
 notice.Position=UDim2.new(0.5,0,0,spec[1]=="Desktop" and 110 or spec[1]=="Compact" and 84 or 88)
 notice.Size=UDim2.fromOffset(spec[1]=="Desktop" and 340 or spec[1]=="Compact" and 260 or 240,40)
 notice.BackgroundColor3=Color3.fromRGB(153,26,43)
 notice.BorderSizePixel=0
 notice.Visible=false
 notice.ZIndex=20
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,10) corner.Parent=notice
 local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(26,29,48) stroke.Thickness=2 stroke.Parent=notice
 for _,entry in ipairs({{"Caption",3,20,16},{"Reason",23,14,12}}) do
  local text=Instance.new("TextLabel")
  text.Name=entry[1]
  text.BackgroundTransparency=1
  text.Position=UDim2.fromOffset(6,entry[2])
  text.Size=UDim2.new(1,-12,0,entry[3])
  text.Font=Enum.Font.GothamBold
  text.TextColor3=Color3.fromRGB(255,249,231)
  text.TextSize=entry[4]
  text.TextScaled=true
  text.Text=entry[1]=="Caption" and "REVEALED — MOVE!" or "A seeker is scanning"
  text.ZIndex=21
  local constraint=Instance.new("UITextSizeConstraint") constraint.MinTextSize=10 constraint.MaxTextSize=entry[4] constraint.Parent=text
  text.Parent=notice
 end
 notice.Parent=gui
end
gui.LeaveLocker.Hint.Text="F / X"
local module=Instance.new("ModuleScript")
module.Name="Abilities"
module.Capabilities=gui.Controller.Capabilities
module.Sandboxed=gui.Controller.Sandboxed
module.Source=[======[local Players = game:GetService("Players")
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
]======]
module.Parent=gui
gui.Controller.Source=[======[local Players = game:GetService("Players")
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
local stopAbilities = require(gui:WaitForChild("Abilities")).Start(gui, state, actionRemote)
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
	elseif phase == "Hiding" then instruction = role == "Seeker" and "Wait while players hide" or "Blend in before seekers are released"
	elseif phase == "Seeking" then instruction = role == "Seeker" and "Find props • Search cupboards and drawers" or "Stay hidden or run from seekers"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	local propName = player:GetAttribute("HSPropName")
	if role ~= "Seeker" and player:GetAttribute("HSPropMorphed") == true and typeof(propName) == "string" and phase ~= "Results" then
		instruction = "YOU ARE A " .. string.upper(propName)
	end
	if player:GetAttribute("HSHiding") == true then instruction = "Hidden inside • Leave to run" end
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
		local stamina = math.clamp((player:GetAttribute("HSStamina") or 0) / math.max(1, player:GetAttribute("HSMaxStamina") or 25), 0, 1)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(stamina, 1)
		button.StaminaText.Text = string.format("%.1f / %d", player:GetAttribute("HSStamina") or 0, player:GetAttribute("HSMaxStamina") or 25)
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
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
connect(state.AttributeChanged, refresh)
for _, name in { "HSParticipating", "HSRole", "HSHiding", "HSRagdolled", "HSStamina", "HSMaxStamina", "HSPropName", "HSPropMorphed" } do connect(player:GetAttributeChangedSignal(name), refresh) end
connect(player.CharacterRemoving, clearInputs)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	stopAbilities()
	clearInputs()
	ContextActionService:UnbindAction("HideAndSeekSprint")
	ContextActionService:UnbindAction("HideAndSeekLeaveLocker")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()
]======]
return {installed=true,backup=backup:GetFullName(),gui=gui:GetFullName()}
