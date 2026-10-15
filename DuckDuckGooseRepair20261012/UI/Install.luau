local gui=game.StarterGui.DuckDuckGooseHUD
assert(gui.Controller.Source==[========[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("DuckDuckGooseState")
local sprintRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseActionRequest")
local headers = {gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader}
local sprintButtons = {gui.DesktopSprint, gui.MobileSprint}
local connections, keysHeld, pointersHeld = {}, {}, {}
local focused, sprintRequested = true, false
local sprintContext
local elapsed, nextChoose = 0, 0
local function finite(value, fallback)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge and value or fallback
end
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function sessionFlags()
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local round = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true
		and round and round:GetAttribute("ActiveGame") == "DuckDuckGoose"
	return muted == true, watching == true
end
local function inputReady()
	return focused and gui.Enabled and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local role = player:GetAttribute("DGRole")
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and state:GetAttribute("Phase") == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
		and player:GetAttribute("DGRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value, force)
	value = value == true and canSprint() == true
	if value == sprintRequested and not force then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(pointersHeld)
	requestSprint(false)
end
local function canChoose()
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and player:GetAttribute("DGRole") == "Picker" and state:GetAttribute("Phase") == "Playing"
		and state:GetAttribute("TurnPhase") == "Choosing"
end
local function nearestDuck()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, distance = nil, 10
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("DGParticipating") == true and other:GetAttribute("DGRole") == "Duck" then
			local targetRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if targetRoot and humanoid and humanoid.Health > 0 then
				local separation = (targetRoot.Position - root.Position).Magnitude
				if separation <= distance then nearest, distance = other, separation end
			end
		end
	end
	return nearest
end
local function chooseGoose()
	if not canChoose() or os.clock() < nextChoose then return end
	local target = nearestDuck()
	if not target then return end
	nextChoose = os.clock() + 0.35
	actionRemote:FireServer("ChooseGoose", target.UserId)
end
local function refreshPrompts()
	local arena = workspace:FindFirstChild("Duck Duck Goose")
	local seats = arena and arena:FindFirstChild("Gameplay") and arena.Gameplay:FindFirstChild("Seats")
	if not seats then return end
	local enabled = canChoose()
	for _, model in seats:GetChildren() do
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and prompt:GetAttribute("DGGoosePrompt") == true then
			local occupant = model:GetAttribute("DGSeatedUserId")
			prompt.Enabled = enabled and typeof(occupant) == "number" and occupant > 0 and occupant ~= player.UserId
		end
	end
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local muted, watching = sessionFlags()
	local phase, turn = state:GetAttribute("Phase"), state:GetAttribute("TurnPhase")
	local participating = player:GetAttribute("DGParticipating") == true
	local eliminated = player:GetAttribute("DGEliminated") == true and phase ~= "Waiting"
	local shown = gui.Enabled and (participating or eliminated or watching) and not muted
	local role = player:GetAttribute("DGRole") or "Duck"
	local now = workspace:GetServerTimeNow()
	local seconds = math.max(0, math.ceil(finite(state:GetAttribute("EndsAt"), now) - now))
	local alive = finite(state:GetAttribute("AliveCount"), 0)
	local lap = math.clamp(finite(state:GetAttribute("LapProgress"), 0), 0, 1)
	local instruction = "Stay seated until you are chosen"
	if role == "Picker" then instruction = "Walk to a duck and call GOOSE!"
	elseif role == "Runner" then instruction = lap >= 1 and "Take the gold seat!" or "Run CLOCKWISE, then take the gold seat"
	elseif role == "Goose" then instruction = "Chase CLOCKWISE. Swing your bat to tag!" end
	if eliminated then instruction = "You are out. Watch the remaining ducks!" end
	if turn == "FinalDuck" then instruction = "You are the last duck standing!" end
	if watching then instruction = "Watching Duck Duck Goose" end
	if phase == "Countdown" then instruction = "Get ready! One player will choose a goose"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	local counts = string.format("%d still in", alive)
	if phase == "Playing" and turn == "Chasing" then counts = string.format("%d in · LAP %d%%", alive, math.floor(lap * 100))
	elseif phase == "Playing" and turn == "Choosing" then
		local choiceSeconds = math.max(0, math.ceil(finite(state:GetAttribute("TurnEndsAt"), now) - now))
		counts = string.format("%d in · Choose: %ds", alive, choiceSeconds)
	end
	for _, header in headers do
		header.Visible = shown and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "DUCK DUCK GOOSE"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3)
			or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or eliminated and "OUT" or string.upper(role)
		header.Role.TextColor3 = (role == "Picker" or role == "Runner") and Color3.fromRGB(185, 55, 73)
			or role == "Goose" and Color3.fromRGB(152, 94, 27) or Color3.fromRGB(38, 105, 133)
		header.Counts.Text, header.Hint.Text = counts, instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	local context = tostring(phase) .. ":" .. tostring(turn) .. ":" .. role
	if not active then
		clearInputs()
	elseif sprintContext ~= context then
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil, true)
	end
	sprintContext = context
	for _, button in sprintButtons do
		button.Visible = shown and participating and phase == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
			and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local maximum = math.max(0.1, finite(player:GetAttribute("DGMaxStamina"), 5))
		local current = math.clamp(finite(player:GetAttribute("DGStamina"), 0), 0, maximum)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(current / maximum, 1)
		button.StaminaText.Text = string.format("%.1f / %d", current, maximum)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(150, 157, 170)
		button.ArtFallback.Visible = not button.ReusableSkin.IsLoaded
	end
	gui.ChooseGoose.Visible = shown and participating and role == "Picker" and phase == "Playing" and turn == "Choosing"
	gui.ChooseGoose.Active = canChoose() and nearestDuck() ~= nil
	gui.ChooseGoose.Selectable = gui.ChooseGoose.Active
	gui.ChooseGoose.Hint.Text = gui.ChooseGoose.Active and "CHOOSE NEARBY" or "MOVE CLOSER"
	gui.ChooseGoose.Fallback.Visible = not gui.ChooseGoose.ReusableSkin.IsLoaded
	refreshPrompts()
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointersHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if pointersHeld[input] then
		pointersHeld[input] = nil
		requestSprint(next(pointersHeld) ~= nil or next(keysHeld) ~= nil)
	end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.ChooseGoose.Activated, chooseGoose)
ContextActionService:BindAction("DuckDuckGooseSprint", function(_, inputState, input)
	if player:GetAttribute("DGParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		keysHeld[input.KeyCode] = true
		requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		keysHeld[input.KeyCode] = nil
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
connect(state.AttributeChanged, refresh)
for _, name in {"DGParticipating", "DGRole", "DGEliminated", "DGRagdolled", "DGStamina", "DGMaxStamina"} do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterRemoving, clearInputs)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	clearInputs()
	ContextActionService:UnbindAction("DuckDuckGooseSprint")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()]========],"Controller changed; refresh snapshot")
local result=(function()
local gui = game.StarterGui.DuckDuckGooseHUD
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(not gui:FindFirstChild("Guidance"), "Guidance already installed")
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "DuckDuckGooseGuidanceBackup20261012", game.ServerStorage
gui:Clone().Parent = backup
local arena = workspace["Duck Duck Goose"]
local track = arena.Grounds.CircularRunningTrack
track.TrackDirections:Clone().Parent = backup
backup:SetAttribute("CountdownSeconds", arena:GetAttribute("CountdownSeconds"))
arena:SetAttribute("CountdownSeconds", 8)
local navy, cream = Color3.fromRGB(24, 35, 62), Color3.fromRGB(255, 249, 226)
local function label(parent, name, text, position, size, minSize, maxSize)
	local l = Instance.new("TextLabel")
	l.Name, l.Text, l.Position, l.Size = name, text, position, size
	l.BackgroundTransparency, l.BorderSizePixel = 1, 0
	l.TextColor3, l.Font, l.TextScaled, l.TextWrapped = navy, Enum.Font.GothamBold, true, true
	l.ZIndex = parent.ZIndex + 1
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = minSize, maxSize, l
	l.Parent = parent
	return l
end
local function panel(name, size, position, anchor)
	local p = Instance.new("Frame")
	p.Name, p.Size, p.Position, p.AnchorPoint = name, size, position, anchor
	p.BackgroundColor3, p.BorderSizePixel, p.ZIndex, p.Visible = cream, 0, 20, false
	local c = Instance.new("UICorner") c.CornerRadius, c.Parent = UDim.new(0, 13), p
	local s = Instance.new("UIStroke") s.Color, s.Thickness, s.Parent = navy, 2, p
	p.Parent = gui
	return p
end
local function button(parent, name, text, size, position, anchor)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position, b.AnchorPoint = name, "", size, position, anchor
	b.BackgroundColor3, b.BorderSizePixel, b.ZIndex = Color3.fromRGB(255, 213, 94), 0, parent:IsA("GuiObject") and parent.ZIndex + 2 or 20
	local corner = Instance.new("UICorner") corner.CornerRadius, corner.Parent = UDim.new(0, 11), b
	local stroke = Instance.new("UIStroke") stroke.Color, stroke.Thickness, stroke.Parent = navy, 2, b
	label(b, "Caption", text, UDim2.fromOffset(5, 3), UDim2.new(1, -10, 1, -6), 11, 17)
	b.Parent = parent
	return b
end
local lines = {
	"1  PICKER: choose a duck to call GOOSE!",
	"2  RUNNER: follow arrows for ONE LAP, then sit in the gold chair.",
	"3  GOOSE: chase the arrows. Keep running and swing to tag.",
	"4  TAGGED = OUT. Watch outside. At 3:00, picker/runner loses.",
}
for _, spec in ipairs({{"Desktop", 360, 232, 112, 330}, {"Compact", 290, 218, 86, 278}, {"Portrait", 272, 244, 90, 264}}) do
	local prefix, width, height, noticeY, noticeWidth = table.unpack(spec)
	local card = panel(prefix .. "Rules", UDim2.fromOffset(width, height), UDim2.fromScale(0.5, 0.48), Vector2.new(0.5, 0.5))
	label(card, "Title", "HOW TO PLAY", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 25), 15, 22)
	local lineHeight = (height - 97) / 4
	for index, text in ipairs(lines) do
		local l = label(card, "Rule" .. index, text, UDim2.fromOffset(14, 40 + (index - 1) * lineHeight), UDim2.new(1, -28, 0, lineHeight - 3), 11, 15)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	button(card, "Close", "GOT IT", UDim2.fromOffset(104, 44), UDim2.new(0.5, 0, 1, -8), Vector2.new(0.5, 1))
	local notice = panel(prefix .. "Notice", UDim2.fromOffset(noticeWidth, 38), UDim2.new(0.5, 0, 0, noticeY), Vector2.new(0.5, 0))
	label(notice, "Caption", "FOLLOW THE GLOWING ARROWS", UDim2.fromOffset(8, 5), UDim2.new(1, -16, 1, -10), 12, 17)
end
local desktop = button(gui, "DesktopRulesButton", "RULES", UDim2.fromOffset(64, 44), UDim2.new(0.5, -120, 1, -18), Vector2.new(0.5, 1))
local touch = button(gui, "TouchRulesButton", "RULES", UDim2.fromOffset(64, 44), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
desktop.Visible, touch.Visible = false, false
local templates = Instance.new("Folder") templates.Name, templates.Parent = "GuidanceTemplates", gui
local world = Instance.new("BillboardGui")
world.Name, world.Size, world.StudsOffsetWorldSpace = "WorldNotice", UDim2.fromOffset(180, 40), Vector3.new(0, 4, 0)
world.AlwaysOnTop, world.MaxDistance, world.Enabled = true, 150, false
local caption = Instance.new("TextLabel")
caption.Name, caption.Size, caption.BackgroundColor3 = "Caption", UDim2.fromScale(1, 1), cream
caption.TextColor3, caption.Text, caption.Font = navy, "ONE LAP, THEN THIS CHAIR", Enum.Font.GothamBold
caption.BorderSizePixel, caption.TextScaled, caption.TextWrapped = 0, true, true
local corner = Instance.new("UICorner") corner.CornerRadius, corner.Parent = UDim.new(0, 10), caption
local stroke = Instance.new("UIStroke") stroke.ApplyStrokeMode, stroke.Color, stroke.Thickness, stroke.Parent = Enum.ApplyStrokeMode.Border, navy, 2, caption
local padding = Instance.new("UIPadding") padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 4), UDim.new(0, 4) padding.Parent = caption
local textSize = Instance.new("UITextSizeConstraint") textSize.MinTextSize, textSize.MaxTextSize, textSize.Parent = 11, 15, caption
caption.Parent, world.Parent = world, templates
local origin = arena.Gameplay.CircleCenter.CFrame
local surface = track.StuddedTanTrack
local top = origin:PointToObjectSpace(surface.Position).Y + surface.Size.X / 2
local old = track.TrackDirections
old.Parent = nil
local directions = Instance.new("Model")
directions.Name = "TrackDirections"
directions:SetAttribute("DGPaintedDirections", true)
directions:SetAttribute("DGGuidanceVersion", "20261012")
for index = 1, 24 do
	local angle = (index - 1) * math.pi * 2 / 24
	local radial, forward = Vector3.new(math.sin(angle), 0, -math.cos(angle)), Vector3.new(math.cos(angle), 0, math.sin(angle))
	local arrow = Instance.new("Model") arrow.Name = string.format("Chevron%02d", index)
	arrow:SetAttribute("ClockwiseAngle", angle)
	for _, side in ipairs({-1, 1}) do
		local tip = radial * 30.5 + forward * 1.15 + radial * (side * 0.15) + Vector3.new(0, top + 0.06, 0)
		local tail = radial * 30.5 - forward * 1.15 + radial * (side * 1.65) + Vector3.new(0, top + 0.06, 0)
		local arm = tip - tail
		local part = Instance.new("Part")
		part.Name, part.Size = side == -1 and "InnerArm" or "OuterArm", Vector3.new(arm.Magnitude, 0.05, 0.55)
		part.CFrame = CFrame.fromMatrix(origin:PointToWorldSpace((tip + tail) / 2), origin:VectorToWorldSpace(arm.Unit), origin.UpVector)
		part.Color, part.Material = Color3.fromRGB(250, 225, 131), Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part:SetAttribute("DGDuckMap", true) part:SetAttribute("DGDecorative", true)
		part.Parent = arrow
	end
	arrow.Parent = directions
end
directions.Parent = track
old:Destroy()
gui:SetAttribute("DGGuidanceVersion", "20261012")
return {arrows = 24, rulesLayouts = 3, rulesButton = true, editable = true}
end)()
local module=Instance.new("ModuleScript")
module.Name="Guidance"
module.Sandboxed=false
module.Capabilities=gui.Controller.Capabilities
module.Source=[========[local Guidance = {}

function Guidance.Describe(role, status, ready, eliminated)
	if eliminated then return "TAGGED - YOU'RE OUT", "Watch from outside the circle until next round" end
	if role == "Duck" then return "DUCK", "Stay seated. Chosen as goose? Chase the runner!" end
	if role == "Picker" then return "PICKER", "Choose a duck, then follow the glowing arrows" end
	if status == "WrongWay" then return "FOLLOW THE ARROWS", "Turn around and run clockwise" end
	if status == "OffTrack" or status == "ReturnToTrack" then
		return "RETURN TO THE TRACK", "Go to the RETURN HERE marker, then follow arrows"
	end
	if ready and role == "Runner" then return "LAP COMPLETE", "Go to the glowing gold chair to be safe!" end
	if role == "Runner" then return "RUNNER", "One clockwise lap, then sit in the gold chair" end
	if role == "Goose" then return "CHASER", "Run after them! Keep moving forward to tag" end
	return "WATCHING", "Runner: one lap. Chaser: follow and tag!"
end

function Guidance.Start(gui, state, player)
	local templates = gui:WaitForChild("GuidanceTemplates")
	local rules = {gui.DesktopRules, gui.CompactRules, gui.PortraitRules}
	local notices = {gui.DesktopNotice, gui.CompactNotice, gui.PortraitNotice}
	local buttons = {gui.DesktopRulesButton, gui.TouchRulesButton}
	local connections, paints = {}, {}
	local open, priorPhase, priorRole, priorEliminated, noticeUntil = false, "", "", false, 0
	local noticeText = ""
	local directions, arena, seatMarker, returnMarker, returnPart
	local disposed = false
	local function connect(signal, callback)
		table.insert(connections, signal:Connect(callback))
	end
	for _, button in buttons do connect(button.Activated, function() open = not open end) end
	for _, card in rules do connect(card.Close.Activated, function() open = false end) end
	local function restorePaints()
		for part, original in pairs(paints) do
			if part.Parent then part.Color, part.Material, part.Transparency = original.color, original.material, original.transparency end
		end
	end
	local function findDirections()
		local previous = directions
		arena = workspace:FindFirstChild("Duck Duck Goose")
		local grounds = arena and arena:FindFirstChild("Grounds")
		local track = grounds and grounds:FindFirstChild("CircularRunningTrack")
		directions = track and track:FindFirstChild("TrackDirections")
		if directions ~= previous then restorePaints() table.clear(paints) end
		for part in pairs(paints) do if not directions or not part:IsDescendantOf(directions) then paints[part] = nil end end
		if directions then
			for _, arrow in directions:GetChildren() do
				for _, part in arrow:GetChildren() do
					if part:IsA("BasePart") and not paints[part] then
						paints[part] = {color = part.Color, material = part.Material, transparency = part.Transparency,
							angle = arrow:GetAttribute("ClockwiseAngle") or 0}
					end
				end
			end
		end
	end
	local function worldMarker(name)
		local marker = templates.WorldNotice:Clone()
		marker.Name, marker.Parent = name, gui
		return marker
	end
	local function clearWorldMarkers()
		if seatMarker then seatMarker:Destroy() seatMarker = nil end
		if returnMarker then returnMarker:Destroy() returnMarker = nil end
		if returnPart then returnPart:Destroy() returnPart = nil end
	end
	local handle = {}
	function handle.Update(context)
		if disposed then return end
		local now = workspace:GetServerTimeNow()
		local phase, role = context.phase, context.role
		local eliminated = context.eliminated
		if phase ~= priorPhase then
			if phase == "Countdown" then open = true
			elseif priorPhase == "Countdown" or phase == "Waiting" or phase == "Results" then open = false end
		end
		if eliminated and not priorEliminated then
			noticeText, noticeUntil = "TAGGED! YOU'RE OUT", now + 4
		elseif phase == "Playing" and role ~= priorRole then
			if role == "Runner" then noticeText, noticeUntil = "RUN! ONE LAP, THEN THE GOLD CHAIR", now + 3
			elseif role == "Goose" then noticeText, noticeUntil = "YOU'RE THE GOOSE! CHASE AND TAG", now + 3
			elseif role == "Duck" and priorRole == "Runner" then noticeText, noticeUntil = "SAFE! YOU MADE IT BACK", now + 3 end
		end
		priorPhase, priorRole, priorEliminated = phase, role, eliminated
		local variant = context.portrait and 3 or context.compact and 2 or 1
		local status = player:GetAttribute("DGRouteStatus")
		local attention = (role == "Runner" or role == "Goose") and (status == "WrongWay" or status == "OffTrack" or status == "ReturnToTrack" or status == "Ready")
		local routeTitle = Guidance.Describe(role, status, player:GetAttribute("DGSeatReady"), eliminated)
		for index, card in rules do card.Visible = context.shown and open and index == variant end
		for index, card in notices do
			card.Visible = context.shown and not open and (now < noticeUntil or attention) and index == variant and phase == "Playing"
			card.Caption.Text = now < noticeUntil and noticeText or routeTitle
			card.Caption.TextColor3 = eliminated and Color3.fromRGB(173, 35, 51) or Color3.fromRGB(24, 35, 62)
		end
		buttons[1].Visible = context.shown and not context.touch and phase ~= "Results"
		buttons[2].Visible = context.shown and context.touch and phase ~= "Results"
		findDirections()
		local chase = phase == "Playing" and context.turn == "Chasing"
		local glow = chase and context.shown
		for part, original in pairs(paints) do
			if part.Parent then
				if glow then
					local wave = (now * 2.8 - original.angle) % (math.pi * 2)
					local pulse = math.max(0, 1 - wave / 1.8)
					part.Material = Enum.Material.Neon
					part.Color = Color3.fromRGB(241, 170, 38):Lerp(Color3.fromRGB(255, 252, 176), pulse)
					part.Transparency = 0.12 * (1 - pulse)
				else part.Color, part.Material, part.Transparency = original.color, original.material, original.transparency end
			end
		end
		if not chase or not context.shown or (role ~= "Runner" and role ~= "Goose") then clearWorldMarkers() return end
		local gameplay = arena and arena:FindFirstChild("Gameplay")
		local seats = gameplay and gameplay:FindFirstChild("Seats")
		local targetIndex = state:GetAttribute("EmptySeatIndex")
		local target
		if seats and role == "Runner" then
			for _, model in seats:GetChildren() do
				if model:GetAttribute("DGSeatIndex") == targetIndex then target = model:FindFirstChild("Seat") break end
			end
		end
		local recovering = status == "ReturnToTrack" or status == "OffTrack" or status == "WrongWay"
		if target and not recovering then
			seatMarker = seatMarker or worldMarker("DGGoalNotice")
			seatMarker.Adornee, seatMarker.Enabled = target, true
			seatMarker.Caption.Text = player:GetAttribute("DGSeatReady") and "LAP DONE - SIT HERE!" or "ONE LAP, THEN THIS CHAIR"
		elseif seatMarker then seatMarker:Destroy() seatMarker = nil end
		local returnPoint = player:GetAttribute("DGReturnPoint")
		local status = player:GetAttribute("DGRouteStatus")
		if typeof(returnPoint) == "Vector3" and (status == "ReturnToTrack" or status == "OffTrack") then
			if not returnPart then
				returnPart = Instance.new("Part")
				returnPart.Name, returnPart.Size = "DGLocalReturnPoint", Vector3.new(0.1, 0.1, 0.1)
				returnPart.Anchored, returnPart.CanCollide, returnPart.CanTouch, returnPart.CanQuery = true, false, false, false
				returnPart.Transparency, returnPart.Parent = 1, workspace
			end
			returnPart.Position = returnPoint
			returnMarker = returnMarker or worldMarker("DGReturnNotice")
			returnMarker.Adornee, returnMarker.Enabled = returnPart, true
			returnMarker.Caption.Text, returnMarker.Caption.TextColor3 = "RETURN HERE", Color3.fromRGB(193, 59, 35)
		elseif returnMarker or returnPart then
			if returnMarker then returnMarker:Destroy() returnMarker = nil end
			if returnPart then returnPart:Destroy() returnPart = nil end
		end
	end
	function handle.Destroy()
		if disposed then return end
		disposed = true
		restorePaints()
		clearWorldMarkers()
		for _, connection in connections do connection:Disconnect() end
	end
	return handle
end

return Guidance]========]
module.Parent=gui
 gui.Controller.Source=[========[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("DuckDuckGooseState")
local sprintRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseSprintRequest")
local actionRemote = ReplicatedStorage:WaitForChild("DuckDuckGooseActionRequest")
local headers = {gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader}
local sprintButtons = {gui.DesktopSprint, gui.MobileSprint}
local connections, keysHeld, pointersHeld = {}, {}, {}
local focused, sprintRequested = true, false
local sprintContext
local elapsed, nextChoose = 0, 0
local Guidance = require(gui:WaitForChild("Guidance"))
local guidance = Guidance.Start(gui, state, player)
local function finite(value, fallback)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge and value or fallback
end
local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function sessionFlags()
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local muted = session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true)
	local round = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local watching = session and session:GetAttribute("Spectating") == true
		and round and round:GetAttribute("ActiveGame") == "DuckDuckGoose"
	return muted == true, watching == true
end
local function inputReady()
	return focused and gui.Enabled and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end
local function canSprint()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local role = player:GetAttribute("DGRole")
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and state:GetAttribute("Phase") == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
		and player:GetAttribute("DGRagdolled") ~= true and humanoid and humanoid.Health > 0
end
local function requestSprint(value, force)
	value = value == true and canSprint() == true
	if value == sprintRequested and not force then return end
	sprintRequested = value
	sprintRemote:FireServer(value)
end
local function clearInputs()
	table.clear(keysHeld)
	table.clear(pointersHeld)
	requestSprint(false)
end
local function canChoose()
	local muted, watching = sessionFlags()
	return inputReady() and not muted and not watching and player:GetAttribute("DGParticipating") == true
		and player:GetAttribute("DGRole") == "Picker" and state:GetAttribute("Phase") == "Playing"
		and state:GetAttribute("TurnPhase") == "Choosing"
end
local function nearestDuck()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, distance = nil, 10
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("DGParticipating") == true and other:GetAttribute("DGRole") == "Duck" then
			local targetRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if targetRoot and humanoid and humanoid.Health > 0 then
				local separation = (targetRoot.Position - root.Position).Magnitude
				if separation <= distance then nearest, distance = other, separation end
			end
		end
	end
	return nearest
end
local function chooseGoose()
	if not canChoose() or os.clock() < nextChoose then return end
	local target = nearestDuck()
	if not target then return end
	nextChoose = os.clock() + 0.35
	actionRemote:FireServer("ChooseGoose", target.UserId)
end
local function refreshPrompts()
	local arena = workspace:FindFirstChild("Duck Duck Goose")
	local seats = arena and arena:FindFirstChild("Gameplay") and arena.Gameplay:FindFirstChild("Seats")
	if not seats then return end
	local enabled = canChoose()
	for _, model in seats:GetChildren() do
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and prompt:GetAttribute("DGGoosePrompt") == true then
			local occupant = model:GetAttribute("DGSeatedUserId")
			prompt.Enabled = enabled and typeof(occupant) == "number" and occupant > 0 and occupant ~= player.UserId
		end
	end
end
local function refresh()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local selectedHeader = not compact and gui.DesktopHeader or viewport.Y > viewport.X and gui.PortraitHeader or gui.CompactHeader
	local muted, watching = sessionFlags()
	local phase, turn = state:GetAttribute("Phase"), state:GetAttribute("TurnPhase")
	local participating = player:GetAttribute("DGParticipating") == true
	local eliminated = player:GetAttribute("DGEliminated") == true and phase ~= "Waiting"
	local shown = gui.Enabled and (participating or eliminated or watching) and not muted
	local role = player:GetAttribute("DGRole") or "Duck"
	local now = workspace:GetServerTimeNow()
	local seconds = math.max(0, math.ceil(finite(state:GetAttribute("EndsAt"), now) - now))
	local alive = finite(state:GetAttribute("AliveCount"), 0)
	local ownLap = role == "Runner" or role == "Goose"
	local lap = math.clamp(finite(ownLap and player:GetAttribute("DGLapProgress") or state:GetAttribute("LapProgress"), 0), 0, 1)
	local _, instruction = Guidance.Describe(role, player:GetAttribute("DGRouteStatus"),
		player:GetAttribute("DGSeatReady") == true, eliminated)
	if turn == "FinalDuck" and participating and not eliminated then instruction = "You are the last duck standing!" end
	if watching then instruction = "Watching Duck Duck Goose" end
	if phase == "Countdown" then instruction = "Get ready! One player will choose a goose"
	elseif phase == "Results" then instruction = state:GetAttribute("WinnersText") or "Round finished" end
	local counts = string.format("%d still in", alive)
	if phase == "Playing" and turn == "Chasing" then counts = string.format("%d in · LAP %d%%", alive, math.floor(lap * 100))
	elseif phase == "Playing" and turn == "Choosing" then
		local choiceSeconds = math.max(0, math.ceil(finite(state:GetAttribute("TurnEndsAt"), now) - now))
		counts = string.format("%d in · Choose: %ds", alive, choiceSeconds)
	end
	for _, header in headers do
		header.Visible = shown and header == selectedHeader
		header.Title.Text = phase == "Results" and "ROUND FINISHED" or "DUCK DUCK GOOSE"
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 8)
			or phase == "Results" and "" or clock(seconds)
		header.Role.Text = watching and "WATCHING" or eliminated and "OUT" or role == "Goose" and "CHASER" or string.upper(role)
		header.Role.TextColor3 = (role == "Picker" or role == "Runner") and Color3.fromRGB(185, 55, 73)
			or role == "Goose" and Color3.fromRGB(152, 94, 27) or Color3.fromRGB(38, 105, 133)
		header.Counts.Text, header.Hint.Text = counts, instruction
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
	end
	local active = canSprint() == true
	local context = tostring(phase) .. ":" .. tostring(turn) .. ":" .. role
	if not active then
		clearInputs()
	elseif sprintContext ~= context then
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil, true)
	end
	sprintContext = context
	for _, button in sprintButtons do
		button.Visible = shown and participating and phase == "Playing" and (role == "Picker" or role == "Runner" or role == "Goose")
			and button == (UserInputService.TouchEnabled and gui.MobileSprint or gui.DesktopSprint)
		button.Active = active
		button.Selectable = not UserInputService.TouchEnabled and active
		local maximum = math.max(0.1, finite(player:GetAttribute("DGMaxStamina"), 5))
		local current = math.clamp(finite(player:GetAttribute("DGStamina"), 0), 0, maximum)
		button.StaminaTrack.StaminaFill.Size = UDim2.fromScale(current / maximum, 1)
		button.StaminaText.Text = string.format("%.1f / %d", current, maximum)
		button.ReusableSkin.ImageColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(150, 157, 170)
		button.ArtFallback.Visible = not button.ReusableSkin.IsLoaded
	end
	gui.ChooseGoose.Visible = shown and participating and role == "Picker" and phase == "Playing" and turn == "Choosing"
	gui.ChooseGoose.Active = canChoose() and nearestDuck() ~= nil
	gui.ChooseGoose.Selectable = gui.ChooseGoose.Active
	gui.ChooseGoose.Hint.Text = gui.ChooseGoose.Active and "CHOOSE NEARBY" or "MOVE CLOSER"
	gui.ChooseGoose.Fallback.Visible = not gui.ChooseGoose.ReusableSkin.IsLoaded
	refreshPrompts()
	guidance.Update({shown = shown, phase = phase, turn = turn, role = role, eliminated = eliminated,
		compact = compact, portrait = compact and viewport.Y > viewport.X, touch = UserInputService.TouchEnabled})
end
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
for _, button in sprintButtons do
	connect(button.InputBegan, function(input)
		if not button.Visible or not button.Active then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointersHeld[input] = true
			requestSprint(true)
		end
	end)
end
connect(UserInputService.InputEnded, function(input)
	if pointersHeld[input] then
		pointersHeld[input] = nil
		requestSprint(next(pointersHeld) ~= nil or next(keysHeld) ~= nil)
	end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false clearInputs() end)
connect(UserInputService.WindowFocused, function() focused = true refresh() end)
connect(gui.ChooseGoose.Activated, chooseGoose)
ContextActionService:BindAction("DuckDuckGooseSprint", function(_, inputState, input)
	if player:GetAttribute("DGParticipating") ~= true then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		keysHeld[input.KeyCode] = true
		requestSprint(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		keysHeld[input.KeyCode] = nil
		requestSprint(next(keysHeld) ~= nil or next(pointersHeld) ~= nil)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
connect(state.AttributeChanged, refresh)
for _, name in {"DGParticipating", "DGRole", "DGEliminated", "DGRagdolled", "DGStamina", "DGMaxStamina", "DGRouteStatus", "DGSeatReady", "DGReturnPoint", "DGLapProgress"} do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(player.CharacterRemoving, clearInputs)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(delta)
	elapsed += delta
	if elapsed >= 0.1 then elapsed = 0 refresh() end
end)
connect(script.Destroying, function()
	guidance.Destroy()
	clearInputs()
	ContextActionService:UnbindAction("DuckDuckGooseSprint")
	for _, connection in connections do connection:Disconnect() end
end)
refresh()]========]
return result