local Guidance = {}

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

return Guidance