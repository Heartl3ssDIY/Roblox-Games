local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local records = {}
local function restore(record)
	for joint, entry in pairs(record.joints) do
		if joint.Parent and joint.Transform == entry.applied then joint.Transform = entry.original end
	end
	table.clear(record.joints)
end
local function pose(record, joint, offset)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	joint.Transform = original * offset
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local bodyNames = {
	"HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local function collectJoints(character)
	local joints = {}
	for _, name in ipairs(bodyNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then joints[child.Name] = child end
			end
		end
	end
	return joints
end
local function bodyJoints(record, character, now)
	if not record.bodyJoints or now - (record.jointsAt or -math.huge) >= 0.5 then
		record.bodyJoints = collectJoints(character)
		record.jointsAt = now
	end
	return record.bodyJoints
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
local batPoses = {
	{ time = 0, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
	{ time = 0.105, r6 = vector(116, 4, -40), r15 = vector(91, 4, -35), elbow = 42,
		wrist = vector(-6, -12, -8), root = vector(3, -16, -3), waist = vector(2, -19, -2),
		guide = vector(106, -60, 10), guideElbow = 15, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.15, r6 = vector(111, 4, -35), r15 = vector(87, 4, -30), elbow = 36,
		wrist = vector(-9, -9, -5), root = vector(1, -9, -2), waist = vector(0, -12, -1),
		guide = vector(100, -60, 10), guideElbow = 8, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.22, r6 = vector(45, 28, -16), r15 = vector(36, 28, -16), elbow = 9,
		wrist = vector(-7, 3, 2), root = vector(-5, 9, 4), waist = vector(-3, 15, 2),
		guide = vector(56, -68, 10), guideElbow = 5, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.30, r6 = vector(74, 84, -24), r15 = vector(54, 80, -19), elbow = 33,
		wrist = vector(8, 13, 10), root = vector(-2, 18, 5), waist = vector(-1, 23, 3),
		guide = vector(53, -8, 15), guideElbow = 35, guideWeight = 0.5, bodyWeight = 1 },
	{ time = 0.365, r6 = vector(88, 62, -18), r15 = vector(65, 56, -15), elbow = 37,
		wrist = vector(4, 8, 4), root = vector(0, 13, 3), waist = vector(0, 15, 2),
		guide = vector(41, -4, 9), guideElbow = 28, guideWeight = 0.25, bodyWeight = 0.65 },
	{ time = 0.48, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
}
local function tangent(index, key)
	if index == 1 or index == #batPoses then return batPoses[index][key] * 0 end
	local before, current, after = batPoses[index - 1], batPoses[index], batPoses[index + 1]
	local incoming = (current[key] - before[key]) / (current.time - before.time)
	local outgoing = (after[key] - current[key]) / (after.time - current.time)
	return (incoming + outgoing) * 0.35
end
local function sampleBatPose(elapsed, classic)
	local first = batPoses[1]
	if elapsed < 0 or elapsed >= 0.48 then elapsed = 0 end
	local index = 2
	while index < #batPoses and elapsed > batPoses[index].time do index += 1 end
	local start, finish = batPoses[index - 1], batPoses[index]
	local duration = finish.time - start.time
	local t = math.clamp((elapsed - start.time) / duration, 0, 1)
	local t2, t3 = t * t, t * t * t
	local result = {}
	for key, value in pairs(first) do
		if key ~= "time" then
			result[key] = start[key] * (2 * t3 - 3 * t2 + 1)
				+ tangent(index - 1, key) * duration * (t3 - 2 * t2 + t)
				+ finish[key] * (-2 * t3 + 3 * t2)
				+ tangent(index, key) * duration * (t3 - t2)
		end
	end
	result.shoulder = result[classic and "r6" or "r15"]
	result.guideWeight = math.clamp(result.guideWeight, 0, 1)
	result.bodyWeight = math.clamp(result.bodyWeight, 0, 1)
	return result
end
local function weaponJoint(record, joint, angles, weight, additive)
	if not joint or not joint.Parent or weight <= 0
		or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) or not joint.Enabled then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local basis = joint.C0.Rotation
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local target = basis:Inverse() * rotation * basis
	if additive then target = original * target end
	joint.Transform = original:Lerp(target, math.clamp(weight, 0, 1))
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function applyBatPose(record, joints, sampled, classic, fade)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], sampled.shoulder, fade)
	weaponJoint(record, joints.RightElbow, vector(sampled.elbow, 0, 0), fade)
	weaponJoint(record, joints.RightWrist, sampled.wrist, fade)
	local guide = sampled.guideWeight * fade
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], sampled.guide, guide)
	weaponJoint(record, joints.LeftElbow, vector(sampled.guideElbow, 0, 0), guide)
	weaponJoint(record, joints.LeftWrist, vector(0, 10, -8), guide)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record, joints.RootJoint or joints.Root, root, fade, true)
	if not classic then weaponJoint(record, joints.Waist, sampled.waist, fade, true) end
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record, joints.Neck, vector(-chest.X * 0.4, -chest.Y * 0.6, -chest.Z * 0.5), fade, true)
	local weight = sampled.bodyWeight
	weaponJoint(record, joints[classic and "Right Hip" or "RightHip"],
		vector(-root.X + 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"],
		vector(-root.X - 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints.RightKnee, vector(-3 * weight, 0, 0), fade, true)
	weaponJoint(record, joints.LeftKnee, vector(-5 * weight, 0, 0), fade, true)
end
local function animateBat(record, player, character, humanoid, now)
	local gameName = character:GetAttribute("PCBatGame")
	local participating = (gameName == "BritishBulldog" and player:GetAttribute("BBParticipating") == true)
		or (gameName == "TagYoureIt" and player:GetAttribute("TGParticipating") == true)
	if humanoid.Health <= 0 or character:GetAttribute("PCBatHeld") ~= true or not participating
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true then
		record.weapon = nil
		return false
	end
	if record.weapon ~= gameName then
		record.weapon = gameName
		record.weaponAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCBatSwingAt")
	local elapsed = typeof(started) == "number" and started == started and now - started or math.huge
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local sampled = sampleBatPose(elapsed, classic)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	applyBatPose(record, bodyJoints(record, character, now), sampled, classic, fade)
	return true
end
local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
end)
local frame = RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local record = records[player]
		if not record or record.character ~= character then
			if record then restore(record) end
			record = { character = character, joints = {} }
			records[player] = record
		end
		restore(record)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil continue end
		if animateBat(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			continue
		end
		bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = record.bodyJoints[classic and "Right Shoulder" or "RightShoulder"]
		local left = record.bodyJoints[classic and "Left Shoulder" or "LeftShoulder"]
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, record.bodyJoints.RightElbow, CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, record.bodyJoints.Waist, CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
		end
	end
end)
local removing = Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if record then restore(record) records[player] = nil end
end)
script.Destroying:Connect(function()
	beforeAnimation:Disconnect()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
end)


