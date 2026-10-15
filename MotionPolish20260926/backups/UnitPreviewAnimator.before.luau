local RunService = game:GetService("RunService")

local PreviewAnimator = {}
local states = {}
local connection

local function rotation(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function idle(state, time)
	local breath = math.sin(time * 2.5 + state.phase)
	local sway = math.sin(time * 1.65 + state.phase)
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

local function visible(viewport)
	local node = viewport
	local position, size = viewport.AbsolutePosition, viewport.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return false end
	while node do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("ScreenGui") and not node.Enabled then return false end
		if node:IsA("ScrollingFrame") then
			local p, s = node.AbsolutePosition, node.AbsoluteSize
			if position.Y + size.Y < p.Y or position.Y > p.Y + s.Y
				or position.X + size.X < p.X or position.X > p.X + s.X then return false end
		end
		node = node.Parent
	end
	return true
end

local function apply(state)
	local pose = idle(state, state.clock)
	local a, b, alpha
	if state.combo then
		local time = state.clock - state.combo
		local frames = state.frames
		if time >= frames[#frames].time then
			state.combo = nil
			state.viewport:SetAttribute("PreviewMode", "FightingIdle")
		else
			for index = 2, #frames do
				if time <= frames[index].time then
					a, b = frames[index - 1].pose, frames[index].pose
					alpha = (time - frames[index - 1].time) / (frames[index].time - frames[index - 1].time)
					alpha = alpha * alpha * (3 - 2 * alpha)
					break
				end
			end
		end
	end
	for _, entry in ipairs(state.joints) do
		local transform = pose[entry.name] or CFrame.identity
		if a then transform = (a[entry.name] or transform):Lerp(b[entry.name] or transform, alpha) end
		entry.joint.C0 = CFrame.new(entry.rest.Position) * transform * entry.rest.Rotation
	end
end

local function update(dt)
	for viewport, state in pairs(states) do
		if not viewport.Parent or not state.model.Parent then
			PreviewAnimator.detach(viewport)
		elseif visible(viewport) then
			state.clock += math.min(dt, 0.1)
			apply(state)
		end
	end
end

function PreviewAnimator.attach(viewport, model)
	PreviewAnimator.detach(viewport)
	local state = {viewport = viewport, model = model, joints = {}, clock = 0, phase = 0,
		r15 = model:FindFirstChild("UpperTorso") ~= nil}
	for index = 1, #model.Name do state.phase += string.byte(model.Name, index) * 0.17 end
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			table.insert(state.joints, {joint = joint, name = joint.Name:gsub(" ", ""), rest = joint.C0})
		end
	end
	state.frames = actions(state)
	states[viewport] = state
	state.destroying = viewport.Destroying:Connect(function() PreviewAnimator.detach(viewport) end)
	viewport:SetAttribute("PreviewMode", "FightingIdle")
	viewport:SetAttribute("PreviewRig", state.r15 and "R15" or "R6")
	apply(state)
	if not connection then connection = RunService.RenderStepped:Connect(update) end
end

function PreviewAnimator.playCombo(viewport)
	local state = states[viewport]
	if not state then return end
	state.combo = state.clock
	viewport:SetAttribute("PreviewMode", "Combo")
end

function PreviewAnimator.detach(viewport)
	local state = states[viewport]
	if not state then return end
	if state.destroying then state.destroying:Disconnect() end
	for _, entry in ipairs(state.joints) do
		if entry.joint.Parent then entry.joint.C0 = entry.rest end
	end
	states[viewport] = nil
	if not next(states) and connection then
		connection:Disconnect()
		connection = nil
	end
end

return PreviewAnimator

