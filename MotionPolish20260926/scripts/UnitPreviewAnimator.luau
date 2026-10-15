local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local PreviewAnimator = {}
local states = {}
local connection
local preferenceConnection
local reducedMotion = GuiService.ReducedMotionEnabled

local function smoothstep(value)
	local t = math.clamp(value, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function rotation(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function idle(state, time)
	local breath = state.reduced and 0 or math.sin(time * 2.5 + state.phase)
	local sway = state.reduced and 0 or math.sin(time * 1.65 + state.phase)
	local pose = {
		RootJoint = CFrame.new(sway * 0.035, -0.1 + breath * 0.025, 0) * rotation(-3, 14 + sway * 2, -2),
		Root = CFrame.new(sway * 0.025, -0.09 + breath * 0.025, 0) * rotation(-2, 12 + sway * 2, -1),
		Waist = rotation(-5 + breath, 7, -2),
		Neck = rotation(3 - breath, -12, 1),
		LeftHip = rotation(-12 + breath, -7, -8),
		RightHip = rotation(9 - breath, 9, 9),
		LeftKnee = rotation(-14, 0, 0),
		RightKnee = rotation(-18, 0, 0),
		LeftAnkle = rotation(6, 0, 0),
		RightAnkle = rotation(7, 0, 0),
	}
	if state.r15 then
		pose.LeftShoulder = rotation(40 + breath * 2, -15, -16)
		pose.RightShoulder = rotation(35 - breath * 2, 12, 18)
		pose.LeftElbow = rotation(100 + breath * 2, 0, 0)
		pose.RightElbow = rotation(110 - breath * 2, 0, 0)
		pose.LeftWrist = rotation(-8, 0, -8)
		pose.RightWrist = rotation(-8, 0, 8)
	else
		pose.LeftShoulder = rotation(105 + breath * 2, -18, -19)
		pose.RightShoulder = rotation(119 - breath * 2, 15, 22)
	end
	return pose
end

local function actions(state)
	local high = state.r15 and 45 or 112
	return {
		{time = 0, pose = {}},
		{time = 0.22, pose = {
			RootJoint = rotation(-4, 26, -4), Waist = rotation(-6, 20, -4),
			LeftShoulder = rotation(high, -32, -25),
		}},
		{time = 0.34, pose = {
			RootJoint = CFrame.new(0, -0.07, -0.16) * rotation(-7, -12, 0),
			Waist = rotation(-8, -20, 0), Root = CFrame.new(0, -0.07, -0.12) * rotation(-4, -8, 0),
			LeftShoulder = rotation(88, 2, -4), LeftElbow = rotation(8, 0, 0), LeftWrist = CFrame.identity,
		}},
		{time = 0.52, pose = {}},
		{time = 0.66, pose = {
			RootJoint = rotation(-3, -20, 3), Waist = rotation(-4, -22, 3),
			RightShoulder = rotation(high, 35, 25),
		}},
		{time = 0.80, pose = {
			RootJoint = CFrame.new(0, -0.08, -0.2) * rotation(-9, 32, -2),
			Root = CFrame.new(0, -0.08, -0.14) * rotation(-5, 18, 0), Waist = rotation(-9, 28, -2),
			RightShoulder = rotation(91, -4, 5), RightElbow = rotation(5, 0, 0), RightWrist = CFrame.identity,
		}},
		{time = 1.02, pose = {}},
		{time = 1.25, pose = {
			RootJoint = CFrame.new(-0.08, 0.03, 0.02) * rotation(8, 5, -5),
			Root = CFrame.new(-0.07, 0.03, 0.02) * rotation(8, 5, -4), Waist = rotation(7, -4, 0),
			RightHip = rotation(62, 3, 4), RightKnee = rotation(-85, 0, 0), LeftHip = rotation(-5, 0, -4),
		}},
		{time = 1.40, pose = {
			RootJoint = CFrame.new(-0.1, 0.02, 0.05) * rotation(12, -6, -6),
			Root = CFrame.new(-0.08, 0.02, 0.05) * rotation(10, -5, -4), Waist = rotation(9, -6, 0),
			RightHip = rotation(90, 2, 4), RightKnee = rotation(-5, 0, 0), RightAnkle = rotation(-10, 0, 0),
			LeftHip = rotation(-8, 0, -5),
		}},
		{time = 1.65, pose = {
			RightHip = rotation(50, 5, 5), RightKnee = rotation(-65, 0, 0),
		}},
		{time = 2.12, pose = {}},
	}
end

local function visibility(viewport)
	local reduced = reducedMotion
	local node = viewport
	local position, size = viewport.AbsolutePosition, viewport.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 or viewport.ImageTransparency >= 1 then
		return false, reduced
	end
	while node do
		if node:GetAttribute("ReducedMotion") == true then reduced = true end
		if node:IsA("GuiObject") then
			if not node.Visible then return false, reduced end
			if node:IsA("CanvasGroup") and node.GroupTransparency >= 1 then return false, reduced end
			if node.ClipsDescendants then
				local p, s = node.AbsolutePosition, node.AbsoluteSize
				if position.Y + size.Y <= p.Y or position.Y >= p.Y + s.Y
					or position.X + size.X <= p.X or position.X >= p.X + s.X then
					return false, reduced
				end
			end
		elseif node:IsA("ScreenGui") and not node.Enabled then
			return false, reduced
		end
		node = node.Parent
	end
	return true, reduced
end

local function displayedPose(state)
	local pose = {}
	for _, entry in ipairs(state.joints) do pose[entry.name] = entry.current end
	return pose
end

local function setMode(state, mode)
	if state.viewport:GetAttribute("PreviewMode") ~= mode then
		state.viewport:SetAttribute("PreviewMode", mode)
	end
end

local function transition(state, seconds)
	state.transition = {start = state.clock, duration = seconds, pose = displayedPose(state)}
end

local function apply(state)
	local pose = idle(state, state.clock)
	local a, b, alpha
	if state.combo then
		local time = state.clock - state.combo
		local frames = state.frames
		if time >= frames[#frames].time then
			state.combo = nil
			state.comboStart = nil
			setMode(state, "FightingIdle")
		else
			for index = 2, #frames do
				if time <= frames[index].time then
					a = index == 2 and state.comboStart or frames[index - 1].pose
					b = frames[index].pose
					alpha = smoothstep((time - frames[index - 1].time)
						/ (frames[index].time - frames[index - 1].time))
					break
				end
			end
		end
	end
	local blend = state.transition
	local blendAlpha = blend and smoothstep((state.clock - blend.start) / blend.duration)
	for _, entry in ipairs(state.joints) do
		if entry.joint.Parent then
			local target = pose[entry.name] or CFrame.identity
			if a then target = (a[entry.name] or target):Lerp(b[entry.name] or target, alpha) end
			if blend then target = (blend.pose[entry.name] or CFrame.identity):Lerp(target, blendAlpha) end
			entry.current = target
			-- Preserve the authored pose axes while keeping C0 unchanged.
			entry.joint.Transform = entry.inverseRotation * target * entry.rotation
		end
	end
	if blend and blendAlpha >= 1 then state.transition = nil end
end

local function stopTrack(track)
	track:Stop(0)
end

local function ownAnimator(state, animator)
	if state.animators[animator] then return end
	state.animators[animator] = true
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do stopTrack(track) end
	table.insert(state.connections, animator.AnimationPlayed:Connect(stopTrack))
end

local function update()
	local now = os.clock()
	for viewport, state in pairs(states) do
		local elapsed = math.max(0, now - state.lastUpdate)
		state.lastUpdate = now
		if not viewport.Parent or not state.model:IsDescendantOf(viewport) then
			PreviewAnimator.detach(viewport)
		elseif state.visible or now >= state.nextVisibilityCheck then
			local isVisible, isReduced = visibility(viewport)
			state.visible = isVisible
			state.nextVisibilityCheck = now + 0.1
			if isVisible then
				state.clock += elapsed
				if state.reduced ~= isReduced then
					state.reduced = isReduced
					state.combo = nil
					state.comboStart = nil
					transition(state, 0.24)
					setMode(state, "FightingIdle")
				end
				if not state.reduced or state.transition then apply(state) end
			end
		end
	end
end

function PreviewAnimator.attach(viewport, model)
	PreviewAnimator.detach(viewport)
	if not viewport:IsA("ViewportFrame") or not model:IsDescendantOf(viewport) then return false end
	local _, isReduced = visibility(viewport)
	local state = {
		viewport = viewport, model = model, joints = {}, clock = 0, phase = 0,
		r15 = model:FindFirstChild("UpperTorso") ~= nil, reduced = isReduced,
		connections = {}, animators = {}, lastUpdate = os.clock(), nextVisibilityCheck = 0,
	}
	for index = 1, #model.Name do state.phase += string.byte(model.Name, index) * 0.17 end
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local rotationFrame = joint.C0.Rotation
			table.insert(state.joints, {
				joint = joint, name = joint.Name:gsub(" ", ""),
				rotation = rotationFrame, inverseRotation = rotationFrame:Inverse(),
				originalTransform = joint.Transform,
				current = rotationFrame * joint.Transform * rotationFrame:Inverse(),
			})
		end
	end
	state.frames = actions(state)
	states[viewport] = state
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animator") then ownAnimator(state, descendant) end
	end
	table.insert(state.connections, model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Animator") then ownAnimator(state, descendant) end
	end))
	table.insert(state.connections, viewport.Destroying:Connect(function() PreviewAnimator.detach(viewport) end))
	transition(state, 0.3)
	setMode(state, "FightingIdle")
	viewport:SetAttribute("PreviewRig", state.r15 and "R15" or "R6")
	if not connection then
		reducedMotion = GuiService.ReducedMotionEnabled
		preferenceConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			reducedMotion = GuiService.ReducedMotionEnabled
		end)
		connection = RunService.PreSimulation:Connect(update)
	end
	return true
end

function PreviewAnimator.playCombo(viewport)
	local state = states[viewport]
	if not state then return false end
	local _, isReduced = visibility(viewport)
	if isReduced then return false end
	state.transition = nil
	state.comboStart = displayedPose(state)
	state.combo = state.clock
	setMode(state, "Combo")
	return true
end

function PreviewAnimator.detach(viewport)
	local state = states[viewport]
	if not state then return end
	states[viewport] = nil
	for _, listener in ipairs(state.connections) do listener:Disconnect() end
	for _, entry in ipairs(state.joints) do
		if entry.joint.Parent then entry.joint.Transform = entry.originalTransform end
	end
	if not next(states) then
		if connection then connection:Disconnect(); connection = nil end
		if preferenceConnection then preferenceConnection:Disconnect(); preferenceConnection = nil end
	end
end

return PreviewAnimator

