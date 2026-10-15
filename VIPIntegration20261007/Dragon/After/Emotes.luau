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
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
	M16 = { action = "Drink", duration = 1.3, contactAt = 0.82 },
	M17 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M18 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M19 = { action = "Place", duration = 1, contactAt = 0.46 },
	M20 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M21 = { action = "Throw", duration = 0.78, contactAt = 0.3 },
	M22 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M23 = { action = "Aim", duration = 0.8, contactAt = 0.35 },
	M24 = { action = "Throw", duration = 0.78, contactAt = 0.3 },
	M25 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
	M16 = toyPose(),
	M17 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.6}),
	M18 = toyPose({right=vector(75,4,-12),elbow=20}),
	M19 = toyPose({right=vector(52,0,-12)}),
	M20 = toyPose({right=vector(80,0,-10),elbow=25}),
	M21 = toyPose(),
	M22 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.7}),
	M23 = toyPose({right=vector(75,4,-12),elbow=20}),
	M24 = toyPose(),
	M25 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
	return true
end
local function animateDodge(record, player, character, humanoid, now)
	if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("MDParticipating") == true then return false end
	local prefix
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Runner"
		and player:GetAttribute("BBStatus") == "Crossing" then prefix = "BB"
	elseif player:GetAttribute("TGParticipating") == true then prefix = "TG" end
	if not prefix then return false end
	local states = game:GetService("ReplicatedStorage")
	local state = states:FindFirstChild(prefix == "BB" and "BritishBulldogState" or "TagState")
	if not state or state:GetAttribute("Phase") ~= (prefix == "BB" and "Crossing" or "Playing") then return false end
	local started = player:GetAttribute(prefix .. "DodgeStartedAt")
	local duration = player:GetAttribute(prefix .. "DodgeDuration")
	local direction = player:GetAttribute(prefix .. "DodgeDirection")
	if typeof(started) ~= "number" or started ~= started or started <= 0 or typeof(duration) ~= "number"
		or duration ~= duration or duration < 0.15 or duration > 0.5 or typeof(direction) ~= "Vector3" then return false end
	local elapsed = now - started
	duration += 0.14
	if elapsed < 0 or elapsed >= duration then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local side = math.clamp(root.CFrame:VectorToObjectSpace(direction).X, -1, 1)
	if side ~= side then return false end
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local strength = alpha < 0.22 and math.sin(alpha / 0.22 * math.pi / 2)
		or math.cos((alpha - 0.22) / 0.78 * math.pi / 2)^2
	local joints = bodyJoints(record, character, now)
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local lean = vector(-9, 8 * side, -26 * side)
	weaponJoint(record, joints.RootJoint or joints.Root, lean, strength * (classic and 1 or 0.65), true)
	weaponJoint(record, joints.Waist, lean, strength * 0.35, true)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-12,0,18), strength, true)
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(-12,0,-18), strength, true)
	return true
end


local botRecords = {}
local function animatePracticeBots(now)
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("TagState")
	local folder = workspace:FindFirstChild("TagPracticeBots")
	local playing = state and state:GetAttribute("Phase") == "Playing"
	for character, record in pairs(botRecords) do
		restore(record)
		if not playing or not folder or character.Parent ~= folder then botRecords[character] = nil end
	end
	if not playing or not folder then return end
	for _, character in ipairs(folder:GetChildren()) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.PlatformStand then continue end
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if speed < 0.1 then continue end
		local record = botRecords[character]
		if not record then record = { character = character, joints = {} } botRecords[character] = record end
		local joints = bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 24
		weaponJoint(record, joints[classic and "Right Hip" or "RightHip"], vector(swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(swing,0,0), 1, true)
	end
end

local catalogEmote
local lastEmoteSerial = 0
local retiredEmotes = {}

local function emoteAnimationId(value)
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return value
end

local function emoteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function emoteStatus(status, message)
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute("PCEmotePlaybackMessage", message or "")
		player:SetAttribute("PCEmotePlaybackStatus", status)
	end
end

local function disposeEmote(track, animation)
	if track then pcall(function() track:Destroy() end) end
	if animation then animation:Destroy() end
end

local function cleanRetiredEmotes(force)
	for index = #retiredEmotes, 1, -1 do
		local entry = retiredEmotes[index]
		if force or os.clock() >= entry.destroyAt then
			disposeEmote(entry.track, entry.animation)
			table.remove(retiredEmotes, index)
		end
	end
end

local function stopCatalogEmote(message, failed)
	local request = catalogEmote
	if not request then return end
	catalogEmote = nil
	request.expired = true
	if request.worker and coroutine.status(request.worker) ~= "dead" and request.worker ~= coroutine.running() then pcall(task.cancel, request.worker) end
	if request.track then
		pcall(function() request.track:Stop(0.12) end)
		table.insert(retiredEmotes, {track=request.track,animation=request.animation,destroyAt=os.clock()+0.2})
	else disposeEmote(nil, request.animation) end
	emoteStatus(failed and "failed" or "stopped", message)
end

local function emoteCanContinue(player, character, humanoid)
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand
		or humanoid.RigType ~= Enum.HumanoidRigType.R15 or player:GetAttribute("PCDataReady") ~= true then return false end
	if player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or character:GetAttribute("PCBatHeld") == true then return false end
	local toy = character:GetAttribute("PCToyHeld")
	if typeof(toy) == "string" and toy ~= "" then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or humanoid.MoveDirection.Magnitude > 0.08 or humanoid.Jump then return false end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1.5 then return false end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Climbing and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Seated and state ~= Enum.HumanoidStateType.Dead
end

local function updateCatalogEmote(now)
	cleanRetiredEmotes(false)
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local serial = player:GetAttribute("PCEmoteSerial")
	local expires = player:GetAttribute("PCEmoteUntil")
	if catalogEmote and (catalogEmote.character ~= character or serial ~= catalogEmote.serial
		or not emoteNumber(expires) or now >= expires or not emoteCanContinue(player, character, humanoid)
		or (tonumber(player:GetAttribute("PCToyActionAt")) or 0) > catalogEmote.startedAt) then
		stopCatalogEmote("Dance stopped")
	end
	if emoteNumber(serial) and serial > 0 and serial % 1 == 0 and serial ~= lastEmoteSerial then
		lastEmoteSerial = serial
		local asset = emoteAnimationId(player:GetAttribute("PCEmoteAnimationId"))
		local started = player:GetAttribute("PCEmoteStartedAt")
		if not asset or player:GetAttribute("PCEmoteRigType") ~= "R15" or not emoteNumber(started)
			or not emoteNumber(expires) or started > now + 0.5 or expires <= now or expires - started > 35
			or not emoteCanContinue(player, character, humanoid) then return end
		catalogEmote = {serial=serial,character=character,humanoid=humanoid,asset=asset,startedAt=started,loadAt=os.clock()}
		emoteStatus("loading", "Loading dance...")
	end
	local request = catalogEmote
	if not request then return end
	if os.clock() - request.loadAt > 8 and (not request.track or request.track.Length <= 0) then
		stopCatalogEmote("This dance couldn't load. Try playing it again.", true)
		return
	end
	if request.track then
		if request.track.Length > 0 then
			if not request.track.IsPlaying then stopCatalogEmote("Dance stopped")
			elseif not request.ready then request.ready = true emoteStatus("playing", "Move or jump to stop dancing") end
		end
		return
	end
	if request.loading then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	request.loading = true
	local animation = Instance.new("Animation")
	animation.Name = "PlaygroundCatalogEmote"
	animation.AnimationId = request.asset
	request.animation = animation
	request.worker = task.spawn(function()
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if catalogEmote ~= request or request.expired then
			if ok then disposeEmote(track, nil) end
			return
		end
		if not ok then stopCatalogEmote("This dance couldn't load. Try playing it again.", true) return end
		request.track = track
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.2)
		end)
		if not played then stopCatalogEmote("This dance couldn't play. Try again.", true) end
	end)
end


local petClipCache = {}
local function loadPetClips(name)
	if petClipCache[name] then return petClipCache[name] end
	local root = game.ReplicatedStorage:FindFirstChild("PlaygroundPetAnimations")
	local source = root and root:FindFirstChild(name)
	if not source then return nil end
	local clips = {referenceScale = tonumber(source:GetAttribute("ReferenceScale")) or 1}
	for _, sequence in source:GetChildren() do
		if sequence:IsA("KeyframeSequence") and sequence:GetAttribute("NormalizedBoneTransforms") == true then
			local frames = {}
			for _, keyframe in sequence:GetKeyframes() do
				local poses = {}
				for _, pose in keyframe:GetChildren() do
					if pose:IsA("Pose") then poses[pose.Name] = pose.CFrame end
				end
				table.insert(frames, {time = keyframe.Time, poses = poses})
			end
			table.sort(frames, function(a, b) return a.time < b.time end)
			if #frames >= 2 and frames[#frames].time > 0 then
				clips[sequence.Name] = {frames = frames, duration = frames[#frames].time}
			end
		end
	end
	if not clips.Idle then return nil end
	petClipCache[name] = clips
	return clips
end

local function petClipPose(clip, phase, boneName)
	local frames = clip.frames
	local time = phase * clip.duration
	local low, high = 1, #frames
	while low + 1 < high do
		local middle = math.floor((low + high) * 0.5)
		if frames[middle].time <= time then low = middle else high = middle end
	end
	local a, b = frames[low], frames[high]
	local from = a.poses[boneName] or CFrame.identity
	local to = b.poses[boneName] or from
	return from:Lerp(to, math.clamp((time - a.time) / math.max(b.time - a.time, 0.0001), 0, 1))
end

local function prepareAuthoredMotion(state)
	local name = state.model:GetAttribute("PCPetClipSet")
	if type(name) ~= "string" then return end
	local clips = loadPetClips(name)
	if not clips then return end
	state.authored = {clips = clips, bones = {}, phase = 0, scale = state.model:GetScale() / clips.referenceScale}
	for _, bone in state.model:GetDescendants() do
		if bone:IsA("Bone") then
			table.insert(state.authored.bones, {bone = bone, name = bone.Name, rest = bone.Transform})
		end
	end
end

local function updateAuthoredMotion(state, reducedMotion)
	local authored = state.authored
	local idle, fly = authored.clips.Idle, authored.clips.Fly or authored.clips.Idle
	local blend = state.model:GetAttribute("PCDisplayPet") == true and 0 or state.movement
	local phase = reducedMotion and 0.25 or authored.phase
	for _, entry in authored.bones do
		local transform = petClipPose(idle, phase, entry.name):Lerp(petClipPose(fly, phase, entry.name), blend)
		entry.bone.Transform = entry.rest * (transform.Rotation + transform.Position * authored.scale)
	end
end


local hoveringPets = { P23 = true, P25 = true, P28 = true, P35 = true }
local function prepareRigMotion(state)
	prepareAuthoredMotion(state)
	state.bones, state.skinBones = {}, {}
	local pivot = state.model:GetPivot()
	for _, bone in ipairs(state.model:GetDescendants()) do
		if bone:IsA("Bone") then
			local source = bone:FindFirstChild("PCSourceBone")
			if source and source:IsA("ObjectValue") and source.Value then
				table.insert(state.skinBones, { bone = bone, source = source.Value })
			elseif state.model:GetAttribute("PCProceduralPetRig") == true then
				local frame = bone.WorldCFrame
				table.insert(state.bones, {
					bone = bone, name = bone.Name, rest = bone.Transform,
					pitch = frame:VectorToObjectSpace(pivot.RightVector),
					yaw = frame:VectorToObjectSpace(pivot.UpVector),
					roll = frame:VectorToObjectSpace(pivot.LookVector),
				})
			end
		end
	end
end

local function updateRigMotion(state, reducedMotion)
	if state.authored then updateAuthoredMotion(state, reducedMotion) return end
	if not state.tracks.idle and not state.tracks.walk then
		local phase, movement = state.phase, state.movement
		local intensity = reducedMotion and 0 or 1
		for _, entry in ipairs(state.bones) do
			local name, pitch, yaw, roll = entry.name, 0, 0, 0
			local right = name:find("R") ~= nil
			if name == "Head" then
				pitch = math.sin(phase * 0.5) * 3
				yaw = math.sin(phase * 0.29) * 5
			elseif name == "Tail" then
				yaw = math.sin(phase * 0.8) * (7 + movement * 9)
				pitch = math.sin(phase * 0.4) * 3
			elseif name:find("Wing") then
				roll = math.sin(phase) * (hoveringPets[state.id] and 22 or 10) * (right and -1 or 1)
			elseif name:find("Leg") or name:find("Arm") then
				local offset = right and math.pi or 0
				if name:find("Back") then offset += math.pi end
				local number = tonumber(name:match("(%d+)$"))
				if number then offset += (number - 1) * math.pi end
				pitch = math.sin(phase + offset) * (2 + movement * 18)
			elseif name == "Body" then
				pitch = math.sin(phase * 0.5) * 1.5
			end
			entry.bone.Transform = entry.rest
				* CFrame.fromAxisAngle(entry.pitch, math.rad(pitch * intensity))
				* CFrame.fromAxisAngle(entry.yaw, math.rad(yaw * intensity))
				* CFrame.fromAxisAngle(entry.roll, math.rad(roll * intensity))
		end
	end
	for _, entry in ipairs(state.skinBones) do
		entry.bone.Transform = entry.source.Transform
	end
end

local petRigStates = {}
local petRigClock = 1
local function updatePetRigs(delta)
	petRigClock += delta
	if petRigClock >= 0.3 then
		petRigClock = 0
		local display = workspace:FindFirstChild("VIP-Dragon-Rigged-display")
		if display and display:IsA("Model") and display:GetAttribute("PCDisplayPet") == true and not petRigStates[display] then
			local state = {model = display, id = "P36", tracks = {}, movement = 0, phase = 0}
			prepareRigMotion(state)
			petRigStates[display] = state
		end
		local folder = workspace:FindFirstChild("PlaygroundPetVisuals")
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") and (model:GetAttribute("PCProceduralPetRig") == true or type(model:GetAttribute("PCPetClipSet")) == "string") and not petRigStates[model] then
					local userId = tonumber(model:GetAttribute("PetOwnerUserId")) or 0
					local state = {model = model, id = model:GetAttribute("CatalogId"), tracks = {}, movement = 0, phase = (userId % 97) * math.pi * 2 / 97}
					prepareRigMotion(state)
					petRigStates[model] = state
				end
			end
		end
	end
	local reducedMotion = Players.LocalPlayer:GetAttribute("PCReducedMotion") == true
	for model, state in pairs(petRigStates) do
		if not model.Parent then
			petRigStates[model] = nil
		else
			state.movement = math.clamp(tonumber(model:GetAttribute("PCPetMovement")) or 0, 0, 1)
			state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
			if state.authored and not reducedMotion then
				local clips = state.authored.clips
				local blend = model:GetAttribute("PCDisplayPet") == true and 0 or state.movement
				local duration = clips.Idle.duration + ((clips.Fly or clips.Idle).duration - clips.Idle.duration) * blend
				state.authored.phase = (state.authored.phase + delta / duration) % 1
			end
			updateRigMotion(state, reducedMotion)
		end
	end
end

local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
end)
local frame = RunService.PreSimulation:Connect(function(delta)
	updatePetRigs(math.min(delta, 0.1))
	local now = workspace:GetServerTimeNow()
	updateCatalogEmote(now)
	animatePracticeBots(now)
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
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil record.toy = nil continue end
		if player == Players.LocalPlayer and catalogEmote and catalogEmote.character == character then continue end
		if animateDodge(record, player, character, humanoid, now) then continue end
		if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end
		if animateToy(record, player, character, humanoid, now) then continue end
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
	stopCatalogEmote("Dance stopped")
	cleanRetiredEmotes(true)
	beforeAnimation:Disconnect()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
	table.clear(botRecords)
	for model, state in pairs(petRigStates) do
		if model.Parent then
			if state.authored then
				for _, entry in state.authored.bones do entry.bone.Transform = entry.rest end
			else updateRigMotion(state, true) end
		end
	end
	table.clear(petRigStates)
end)






