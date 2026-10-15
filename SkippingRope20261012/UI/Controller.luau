local Players = game:GetService("Players")
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
refresh()
