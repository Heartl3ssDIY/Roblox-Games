local result=(function()
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
assert(not game.StarterGui:FindFirstChild("SkippingRopeHUD"), "HUD already installed")
local source = game.StarterGui.DuckDuckGooseHUD
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SkippingRopeHUD", false, source.DisplayOrder
gui.ScreenInsets, gui.ZIndexBehavior = source.ScreenInsets, source.ZIndexBehavior
gui.ClipToDeviceSafeArea = source.ClipToDeviceSafeArea
gui:SetAttribute("GameId", "SkippingRope")
gui:SetAttribute("EditableGameHUD", true)
gui:SetAttribute("UIAuthoringVersion", "20261012")
local navy, cream = Color3.fromRGB(24, 35, 62), Color3.fromRGB(255, 249, 226)
local function label(parent, name, text, position, size, minimum, maximum)
	local l = Instance.new("TextLabel")
	l.Name, l.Text, l.Position, l.Size = name, text, position, size
	l.BackgroundTransparency, l.BorderSizePixel = 1, 0
	l.TextColor3, l.Font, l.TextScaled, l.TextWrapped = navy, Enum.Font.GothamBold, true, true
	l.ZIndex = parent.ZIndex + 1
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = minimum, maximum, l
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
local function button(parent, name, text, position, anchor)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position, b.AnchorPoint = name, "", UDim2.fromOffset(100, 44), position, anchor
	b.BackgroundColor3, b.BorderSizePixel, b.ZIndex = Color3.fromRGB(255, 213, 94), 0, 25
	local c = Instance.new("UICorner") c.CornerRadius, c.Parent = UDim.new(0, 11), b
	local s = Instance.new("UIStroke") s.Color, s.Thickness, s.Parent = navy, 2, b
	label(b, "Caption", text, UDim2.fromOffset(5, 3), UDim2.new(1, -10, 1, -6), 11, 17)
	b.Parent = parent
	return b
end
for _, spec in ipairs({{"Desktop",340,104,360,224},{"Compact",260,82,290,224},{"Portrait",240,88,272,244}}) do
	local name, width, height, cardWidth, cardHeight = table.unpack(spec)
	local header = source[name .. "Header"]:Clone()
	header.Size = UDim2.fromOffset(width, height)
	header.Title.Text, header.Timer.Text, header.Role.Text = "SKIPPING ROPE", "2:00", "ROPE 1"
	header.Role.Position, header.Role.Size = UDim2.fromScale(0.045,0.34), UDim2.fromScale(0.24,0.18)
	header.Counts.Position, header.Counts.Size = UDim2.fromScale(0.32,0.34), UDim2.fromScale(0.63,0.18)
	header.Counts.Text = "2 hits left  |  24 still in"
	header.Hint.Position, header.Hint.Size = UDim2.fromScale(0.04,0.73), UDim2.fromScale(0.92,0.18)
	header.Hint.Text = "Jump over the rope. Two hits and you're out!"
	label(header, "Speed", "SPEED 1.00x", UDim2.fromScale(0.04,0.53), UDim2.fromScale(0.92,0.15), 8, name=="Desktop" and 12 or 10)
	header.Visible, header.Parent = false, gui
	local card = panel(name .. "Rules", UDim2.fromOffset(cardWidth,cardHeight), UDim2.fromScale(0.5,0.48), Vector2.new(0.5,0.5))
	label(card,"Title","JUMP TO SURVIVE",UDim2.fromOffset(14,10),UDim2.new(1,-28,0,25),15,22)
	local lines = {"Stay on your numbered spot and jump over the rope.","First hit: half health. Second hit: you're OUT.","The rope gets 5% faster every 10 seconds.","Survive for TWO MINUTES to win!"}
	local lineHeight = (cardHeight-97)/4
	for index,text in ipairs(lines) do
		local row = label(card,"Rule"..index,text,UDim2.fromOffset(14,40+(index-1)*lineHeight),UDim2.new(1,-28,0,lineHeight-3),11,15)
		row.TextXAlignment = Enum.TextXAlignment.Left
	end
	button(card,"Close","GOT IT",UDim2.new(0.5,0,1,-8),Vector2.new(0.5,1))
end
local rules = button(gui,"RulesButton","RULES",UDim2.new(0.5,0,1,-14),Vector2.new(0.5,1))
rules.Size, rules.Visible = UDim2.fromOffset(64,44),false
for _,spec in ipairs({{"DesktopHitNotice",330,122},{"CompactHitNotice",270,104}}) do
	local p = panel(spec[1],UDim2.fromOffset(spec[2],38),UDim2.new(0.5,0,0,spec[3]),Vector2.new(0.5,0))
	local l=label(p,"Caption","ROPE HIT! ONE CHANCE LEFT",UDim2.fromOffset(8,5),UDim2.new(1,-16,1,-10),11,17)
	l.TextColor3=Color3.fromRGB(182,42,52)
end
gui.Parent = game.StarterGui
return {hud=gui:GetFullName(),layouts=3,mobileJump="Roblox jump button",authored=true}
end)()
local gui=game.StarterGui.SkippingRopeHUD
local caps=game.StarterGui.DuckDuckGooseHUD.Controller.Capabilities
local presentation=Instance.new("ModuleScript")
presentation.Name="Presentation"
presentation.Sandboxed=false
presentation.Capabilities=caps
presentation.Source=[========[local Presentation = {}

function Presentation.Get(values)
	local hits = math.clamp(values.hits or 0, 0, 2)
	local out = { title = "SKIPPING ROPE", role = "ROPE " .. tostring(values.lane or 1),
		counts = string.format("%d %s left  |  %d still in", 2 - hits, hits == 1 and "hit" or "hits", values.alive or 0),
		hint = "Jump over the rope. Two hits and you're out!", warning = false }
	if values.phase == "Countdown" then
		out.hint = "Get ready! Jump with Space, A or the jump button"
	elseif values.phase == "Results" then
		out.title, out.role = "ROUND FINISHED", values.result == "Won" and "SURVIVED!" or values.result == "Cancelled" and "CANCELLED" or "ROUND OVER"
		out.hint = values.result == "Won" and "You survived two minutes!" or values.result == "Cancelled" and "Round cancelled" or "Try again next round"
	elseif values.eliminated then
		out.role, out.hint, out.warning = "OUT", "Two hits! Watch from the benches until next round", true
	elseif hits == 1 then
		out.hint, out.warning = "One hit left! Watch the rope and jump", true
	end
	if values.watching then out.role, out.hint = "WATCHING", "Jumpers survive two minutes to win" end
	return out
end

return Presentation]========]
presentation.Parent=gui
local controller=Instance.new("LocalScript")
controller.Name="Controller"
controller.Sandboxed=false
controller.Capabilities=caps
controller.Source=[========[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player, gui = Players.LocalPlayer, script.Parent
local state = ReplicatedStorage:WaitForChild("SkippingRopeState")
local Presentation = require(gui:WaitForChild("Presentation"))
local headers = {gui.DesktopHeader, gui.CompactHeader, gui.PortraitHeader}
local cards = {gui.DesktopRules, gui.CompactRules, gui.PortraitRules}
local connections = {}
local rulesOpen, priorPhase, previousHits, hitNoticeUntil, elapsed = false, "", 0, 0, 0
local function connect(signal, callback) table.insert(connections, signal:Connect(callback)) end
local function finite(number, fallback)
	return typeof(number) == "number" and number == number and math.abs(number) ~= math.huge and number or fallback
end
local function clock(seconds) return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end
local function refresh()
	local phase = state:GetAttribute("Phase") or "Waiting"
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(viewport.X, viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400)
	local variant = compact and (viewport.Y > viewport.X and 3 or 2) or 1
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	local round = ReplicatedStorage:FindFirstChild("PlaygroundState")
	local muted = session and (session:GetAttribute("UIHidden") or session:GetAttribute("SessionMenuOpen"))
	local watching = session and session:GetAttribute("Spectating") and round and round:GetAttribute("ActiveGame") == "SkippingRope"
	local participating = player:GetAttribute("SKParticipating") == true
	local eliminated = player:GetAttribute("SKEliminated") == true and phase ~= "Waiting"
	local shown = gui.Enabled and not muted and (participating or eliminated or watching) and phase ~= "Waiting"
	local hits = math.clamp(finite(player:GetAttribute("SKHits"), 0), 0, 2)
	if phase ~= priorPhase then
		if phase == "Countdown" then rulesOpen = true
		elseif priorPhase == "Countdown" or phase == "Results" or phase == "Waiting" then rulesOpen = false end
	end
	if hits > previousHits then hitNoticeUntil = now + 3 end
	priorPhase, previousHits = phase, hits
	local seconds = math.max(0, math.ceil(finite(state:GetAttribute("EndsAt"), now) - now))
	local info = Presentation.Get({phase = phase, hits = hits, lane = player:GetAttribute("SKLane"),
		alive = state:GetAttribute("AliveCount"), eliminated = eliminated, watching = watching,
		result = player:GetAttribute("SKResult")})
	local activeSeconds = math.max(0, now - finite(state:GetAttribute("StartedAt"), now))
	local speed = phase == "Playing" and 1.05 ^ math.floor(math.min(activeSeconds, 119.999) / 10) or 1
	for index, header in headers do
		header.Visible = shown and index == variant
		header.Title.Text, header.Role.Text = info.title, info.role
		header.Timer.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or seconds) or phase == "Results" and "" or clock(seconds)
		header.Counts.Text, header.Hint.Text = info.counts, info.hint
		header.Hint.TextColor3 = info.warning and Color3.fromRGB(182, 42, 52) or Color3.fromRGB(24, 35, 62)
		header.Fallback.Visible = not header.ReusableSkin.IsLoaded
		header.Speed.Text = string.format("SPEED %.2fx", speed)
	end
	for index, card in cards do card.Visible = shown and rulesOpen and index == variant end
	gui.RulesButton.Visible = shown and phase ~= "Results"
	gui.DesktopHitNotice.Visible = shown and not compact and not rulesOpen and now < hitNoticeUntil and phase == "Playing"
	gui.CompactHitNotice.Visible = shown and compact and not rulesOpen and now < hitNoticeUntil and phase == "Playing"
	local hitText = hits >= 2 and "OUT! WATCH FROM THE BENCHES" or "ROPE HIT! ONE CHANCE LEFT"
	gui.DesktopHitNotice.Caption.Text, gui.CompactHitNotice.Caption.Text = hitText, hitText
end
for _, card in cards do connect(card.Close.Activated, function() rulesOpen = false refresh() end) end
connect(gui.RulesButton.Activated, function() rulesOpen = not rulesOpen refresh() end)
connect(state.AttributeChanged, refresh)
for _, name in {"SKParticipating", "SKEliminated", "SKHits", "SKRole", "SKLane", "SKSpot", "SKResult"} do
	connect(player:GetAttributeChangedSignal(name), refresh)
end
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(RunService.Heartbeat, function(dt) elapsed += dt if elapsed >= 0.1 then elapsed = 0 refresh() end end)
connect(script.Destroying, function() for _, connection in connections do connection:Disconnect() end end)
refresh()]========]
controller.Parent=gui
assert(not game.StarterPlayer.StarterPlayerScripts:FindFirstChild("SkippingRopeVisuals"),"Visual script already exists")
local visuals=Instance.new("LocalScript")
visuals.Name="SkippingRopeVisuals"
visuals.Sandboxed=false
visuals.Capabilities=caps
visuals.Source=[========[local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RopeMath = require(ReplicatedStorage:WaitForChild("SkippingRopeMath"))
local state = ReplicatedStorage:WaitForChild("SkippingRopeState")
local laneCache, connections = {}, {}
local accumulator, refreshAt = 0, 0
local function discover()
	local arena = workspace:FindFirstChild("Skipping Rope")
	local gameplay = arena and arena:FindFirstChild("Gameplay")
	local lanes = gameplay and gameplay:FindFirstChild("Lanes")
	for model in pairs(laneCache) do if not lanes or model.Parent ~= lanes then laneCache[model] = nil end end
	if not lanes then return end
	for _, model in lanes:GetChildren() do
		local origin, segments = model:FindFirstChild("RopeOrigin"), model:FindFirstChild("RopeSegments")
		if origin and origin:IsA("BasePart") and segments then
			local entry = laneCache[model]
			if not entry then entry = {model=model,origin=origin,parts={},arms={}} laneCache[model]=entry end
			entry.origin=origin
			entry.settings={halfSpan=model:GetAttribute("RopeHalfSpan") or 26,flatHalfSpan=model:GetAttribute("RopeFlatHalfSpan") or 16,
				radius=model:GetAttribute("RopeRadius") or 8,pivotHeight=model:GetAttribute("RopePivotHeight") or 8.8}
			entry.parts={}
			for _, part in segments:GetChildren() do if part:IsA("BasePart") then table.insert(entry.parts,part) end end
			table.sort(entry.parts,function(a,b) return a.Name<b.Name end)
			for _,name in {"LeftTurner","RightTurner"} do
				local turner=model:FindFirstChild(name)
				local arm=turner and turner:FindFirstChild("TurnArm")
				local pivot=turner and turner:FindFirstChild("TurnPivot")
				local previous=entry.arms[name]
				if arm and arm:IsA("Model") and pivot and pivot:IsA("BasePart") then
					if not previous or previous.arm~=arm or previous.pivot~=pivot then
						entry.arms[name]={arm=arm,pivot=pivot,base=arm:GetAttribute("TurnBaseCFrame") or arm:GetPivot()}
					end
				else entry.arms[name]=nil end
			end
		end
	end
end
local function cylinder(part, first, last, up)
	local offset=last-first
	if offset.Magnitude<0.001 then return end
	local right=offset.Unit
	local y=up-right*up:Dot(right)
	if y.Magnitude<0.001 then y=Vector3.zAxis-right*Vector3.zAxis:Dot(right) end
	y=y.Unit
	part.CFrame=CFrame.fromMatrix((first+last)*0.5,right,y,right:Cross(y))
	if math.abs(part.Size.X-offset.Magnitude-0.035)>0.001 then part.Size=Vector3.new(offset.Magnitude+0.035,part.Size.Y,part.Size.Z) end
end
local function render(dt)
	local now=workspace:GetServerTimeNow()
	if now>=refreshAt then discover() refreshAt=now+0.5 end
	if not next(laneCache) then return end
	local phase=state:GetAttribute("Phase")
	local active=phase=="Playing"
	accumulator+=dt
	if not active and accumulator<1/15 then return end
	accumulator=0
	local started=state:GetAttribute("StartedAt") or now
	local duration=state:GetAttribute("RoundDuration") or 120
	local finished=state:GetAttribute("FinishedAt") or started+duration
	local elapsed=active and math.clamp(now-started,0,duration) or phase=="Results" and math.clamp(finished-started,0,duration) or 0
	local angle=RopeMath.GetAngle(elapsed)
	for _,entry in pairs(laneCache) do
		local count=#entry.parts
		if count>0 and entry.origin.Parent then
			local origin, settings=entry.origin.CFrame,entry.settings
			for index,part in ipairs(entry.parts) do
				if part.Parent then
					local firstX=part:GetAttribute("RopeStartX") or (-settings.halfSpan+(index-1)*2*settings.halfSpan/count)
					local lastX=part:GetAttribute("RopeEndX") or (-settings.halfSpan+index*2*settings.halfSpan/count)
					cylinder(part,origin:PointToWorldSpace(RopeMath.Point(angle,firstX,settings)),origin:PointToWorldSpace(RopeMath.Point(angle,lastX,settings)),origin.UpVector)
				end
			end
			for _,rig in pairs(entry.arms) do
				if rig.arm.Parent and rig.pivot.Parent then
					local anchor=CFrame.new(rig.pivot.Position)
					local rotation=CFrame.fromAxisAngle(origin.RightVector,-(angle-math.pi))
					rig.arm:PivotTo(anchor*rotation*anchor:Inverse()*rig.base)
				end
			end
		end
	end
end
table.insert(connections,RunService.RenderStepped:Connect(render))
table.insert(connections,script.Destroying:Connect(function()
	for _,connection in connections do connection:Disconnect() end
	for _,entry in pairs(laneCache) do
		for _,rig in pairs(entry.arms) do if rig.arm.Parent then rig.arm:PivotTo(rig.base) end end
	end
	table.clear(laneCache)
end))
discover()]========]
visuals.Parent=game.StarterPlayer.StarterPlayerScripts
return result
