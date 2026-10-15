local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchClock = require(ReplicatedStorage:WaitForChild("MatchClock"))
local AttackTimeline = require(ReplicatedStorage:WaitForChild("AttackTimeline"))
local RunService = game:GetService("RunService")
local AttackAnimator = {}
local states = {}
local connection

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function rotation(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function body(r15, y, z, pitch, yaw, roll, joints)
	local pose = joints or {}
	local root = CFrame.new(0, y or 0, z or 0) * rotation(pitch, r15 and (yaw or 0) * 0.45 or yaw, roll)
	pose.Root, pose.RootJoint = root, root
	if r15 then pose.Waist = rotation((pitch or 0) * 0.35, (yaw or 0) * 0.55, (roll or 0) * 0.35) end
	return pose
end

local function r6Palm(side, target, offset)
	local lever = Vector3.new(side * 0.5, -1.5, 0).Unit
	local shoulder = Vector3.new(side, 0.5, 0) + offset
	local direction = (target - shoulder).Unit
	local axis = lever:Cross(direction)
	local turn = CFrame.identity
	if axis.Magnitude > 0.00001 then
		turn = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(lever:Dot(direction), -1, 1)))
	end
	return CFrame.new(offset) * turn
end

local function chargeArms(r15)
	if r15 then
		return {
			LeftShoulder = rotation(38, -14, 38), LeftElbow = rotation(95, 0, 0),
			LeftWrist = rotation(-15, -20, -15),
			RightShoulder = rotation(-18, 8, -8), RightElbow = rotation(115, 0, 0),
			RightWrist = rotation(10, 20, 18),
		}
	end
	return {
		LeftShoulder = r6Palm(-1, Vector3.new(0.22, -0.23, -0.90), Vector3.new(0.18, -0.15, 0.10)),
		RightShoulder = r6Palm(1, Vector3.new(0.59, -0.38, -0.97), Vector3.new(-0.10, 0.12, 0.05)),
	}
end

local function blastArms(r15, pitch)
	if not r15 then
		local angle = math.rad((pitch or 90) - 90)
		local height, reach = 0.4 + math.sin(angle) * 1.38, -math.cos(angle) * 1.38
		return {
			LeftShoulder = r6Palm(-1, Vector3.new(-0.20, height, reach), Vector3.new(0.08, 0, 0)),
			RightShoulder = r6Palm(1, Vector3.new(0.20, height, reach), Vector3.new(-0.08, 0, 0)),
		}
	end
	return {
		LeftShoulder = CFrame.new(r15 and 0.04 or 0.12, 0, 0) * rotation(pitch or 90, 0, 9),
		RightShoulder = CFrame.new(r15 and -0.04 or -0.12, 0, 0) * rotation(pitch or 90, 0, -9),
		LeftElbow = rotation(6, 0, 0), RightElbow = rotation(6, 0, 0),
		LeftWrist = rotation(0, -8, 0), RightWrist = rotation(0, 8, 0),
	}
end

local function lifted(pose, r15, fold)
	pose.LeftHip = rotation(fold or 28, -5, -12)
	pose.RightHip = rotation((fold or 28) - 12, 6, 12)
	if r15 then
		pose.LeftKnee, pose.RightKnee = rotation(-62, 0, 0), rotation(-48, 0, 0)
		pose.LeftAnkle, pose.RightAnkle = rotation(18, 0, 0), rotation(14, 0, 0)
	end
	return pose
end

local function frame(time, phase, pose)
	return {time = time, phase = phase, pose = pose or {}}
end

local function makeFrames(kind, r15)
	if kind == "Roshi" then
		local crouch = body(r15, -0.32, 0, 12, -8, 0, {
			LeftShoulder = rotation(-20, 0, -12), RightShoulder = rotation(-26, 0, 12),
			LeftHip = rotation(-26, 0, -14), RightHip = rotation(-26, 0, 14),
			LeftKnee = rotation(-38, 0, 0), RightKnee = rotation(-38, 0, 0),
		})
		local ascent = lifted(body(r15, 1.95, 0.06, -7, -18, -2, chargeArms(r15)), r15, 46)
		local charge = lifted(body(r15, 2.80, 0.05, -4, -28, -3, chargeArms(r15)), r15, 30)
		charge.Neck = rotation(3, 24, 2)
		local gather = lifted(body(r15, 2.80, 0.07, -6, -32, -3, chargeArms(r15)), r15, 30)
		gather.Neck = rotation(4, 27, 1)
		local ready = lifted(body(r15, 2.78, 0.06, -5, -30, -2, chargeArms(r15)), r15, 29)
		ready.Neck = rotation(3, 25, 1)
		local fire = lifted(body(r15, 2.72, 0.10, 2, 2, 0, blastArms(r15, 91)), r15, 26)
		local recoil = lifted(body(r15, 2.63, 0.24, -9, -2, 0, blastArms(r15, 98)), r15, 32)
		local hold = lifted(body(r15, 2.48, 0.18, -5, 0, 0, blastArms(r15, 95)), r15, 24)
		local descend = body(r15, 1.03, 0.08, 5, 0, 0, {
			LeftShoulder = rotation(32, 0, -14), RightShoulder = rotation(32, 0, 14),
			LeftHip = rotation(-8, 0, -10), RightHip = rotation(-8, 0, 10),
			LeftKnee = rotation(-24, 0, 0), RightKnee = rotation(-24, 0, 0),
		})
		local landing = body(r15, -0.24, 0, 10, 0, 0, {
			LeftShoulder = rotation(15, 0, -22), RightShoulder = rotation(15, 0, 22),
			LeftHip = rotation(-20, 0, -12), RightHip = rotation(-20, 0, 12),
			LeftKnee = rotation(-34, 0, 0), RightKnee = rotation(-34, 0, 0),
		})
		return {
			frame(0, "Windup"), frame(0.16, "Takeoff", crouch),
			frame(0.42, "Jump", ascent), frame(0.68, "Charge", charge),
			frame(1.05, "Charge", gather), frame(1.25, "Charge", ready),
			frame(1.35, "Release", fire), frame(1.46, "Fire", recoil),
			frame(1.73, "Fire", hold), frame(1.96, "Landing", descend),
			frame(2.09, "Landing", landing), frame(2.25, "Idle"),
		}
	elseif kind == "Melee" then
		local pull = body(r15, -0.04, 0.03, -3, -18, 1, {
			RightShoulder = rotation(-35, -12, 12), RightElbow = rotation(95, 0, 0),
			LeftShoulder = rotation(r15 and 34 or 62, 0, -16), LeftElbow = rotation(90, 0, 0),
			Neck = rotation(0, 14, 0),
		})
		local strike = body(r15, -0.07, -0.18, 8, 20, 0, {
			RightShoulder = rotation(96, -4, -5), RightElbow = rotation(4, 0, 0),
			LeftShoulder = rotation(28, 0, -15), LeftElbow = rotation(95, 0, 0),
			Neck = rotation(-3, -14, 0), LeftHip = rotation(-10, 0, 0), RightHip = rotation(13, 0, 0),
		})
		return {
			frame(0, "Windup"), frame(0.13, "Windup", pull),
			frame(0.22, "Release", strike), frame(0.29, "Recovery", strike), frame(0.50, "Idle"),
		}
	elseif kind == "Pikkolo" then
		local gather = body(r15, -0.04, 0.02, -3, -17, 0, {
			RightShoulder = rotation(r15 and 108 or 138, 8, -14),
			RightElbow = rotation(r15 and 65 or 0, 0, 0), RightWrist = rotation(-15, 0, 0),
			LeftShoulder = rotation(-10, 0, -12), Neck = rotation(0, 14, 0),
		})
		local fire = body(r15, -0.03, -0.04, 3, 8, 0, {
			RightShoulder = rotation(94, 0, -5), RightElbow = rotation(6, 0, 0),
			LeftShoulder = rotation(-12, 0, -16), Neck = rotation(-1, -7, 0),
		})
		return {
			frame(0, "Windup"), frame(0.16, "Charge", gather), frame(0.28, "Charge", gather),
			frame(0.38, "Release", fire), frame(0.54, "Recovery", fire), frame(0.73, "Idle"),
		}
	elseif kind == "Tein" then
		local gather = body(r15, -0.10, 0.02, -3, 0, 0, {
			LeftShoulder = rotation(r15 and 62 or 109, 0, 27),
			RightShoulder = rotation(r15 and 62 or 109, 0, -27),
			LeftElbow = rotation(66, 0, 0), RightElbow = rotation(66, 0, 0),
			LeftWrist = rotation(0, -22, -15), RightWrist = rotation(0, 22, 15),
			LeftHip = rotation(-10, 0, -10), RightHip = rotation(-10, 0, 10),
		})
		local fire = body(r15, -0.04, 0.04, -4, 0, 0, blastArms(r15, 100))
		return {
			frame(0, "Windup"), frame(0.21, "Charge", gather), frame(0.39, "Charge", gather),
			frame(0.50, "Release", fire), frame(0.68, "Recovery", fire), frame(0.93, "Idle"),
		}
	elseif kind == "Bluma" then
		local aim = body(r15, -0.02, 0, 0, -8, 0, {
			RightShoulder = rotation(77, 0, -5), RightElbow = rotation(22, 0, 0),
			LeftShoulder = rotation(59, 8, 26), LeftElbow = rotation(60, 0, 0),
			Neck = rotation(0, 8, 0),
		})
		local fire = body(r15, -0.02, 0, 0, -3, 0, {
			RightShoulder = rotation(91, 0, -5), RightElbow = rotation(8, 0, 0),
			LeftShoulder = rotation(66, 4, 23), LeftElbow = rotation(48, 0, 0),
		})
		local recoil = body(r15, -0.02, 0.06, -4, -4, 0, {
			RightShoulder = rotation(106, 0, -5), RightElbow = rotation(18, 0, 0),
			LeftShoulder = rotation(76, 4, 23), LeftElbow = rotation(54, 0, 0),
		})
		return {
			frame(0, "Windup"), frame(0.17, "Aim", aim), frame(0.30, "Release", fire),
			frame(0.36, "Recoil", recoil), frame(0.43, "Recovery", fire), frame(0.62, "Idle"),
		}
	end
	local pull = body(r15, -0.03, 0.03, -4, -20, 0, {
		RightShoulder = rotation(-28, -12, 14), RightElbow = rotation(104, 0, 0),
		RightWrist = rotation(-12, 0, 0),
		LeftShoulder = rotation(r15 and 22 or 42, 0, -18), LeftElbow = rotation(82, 0, 0),
		Neck = rotation(0, 16, 0),
	})
	local fire = body(r15, -0.04, -0.04, 4, 11, 0, {
		RightShoulder = rotation(93, -3, -6), RightElbow = rotation(5, 0, 0),
		LeftShoulder = rotation(4, 0, -16), LeftElbow = rotation(42, 0, 0),
		Neck = rotation(-2, -9, 0),
	})
	local recoil = body(r15, -0.04, 0.07, -4, 6, 0, {
		RightShoulder = rotation(101, -3, -6), RightElbow = rotation(11, 0, 0),
		LeftShoulder = rotation(2, 0, -16), LeftElbow = rotation(42, 0, 0),
		Neck = rotation(1, -6, 0),
	})
	return {
		frame(0, "Windup"), frame(0.19, "Charge", pull), frame(0.35, "Charge", pull),
		frame(0.46, "Release", fire), frame(0.53, "Recoil", recoil),
		frame(0.62, "Recovery", fire), frame(0.89, "Idle"),
	}
end

local frameSets = {}
for _, kind in ipairs({"Roshi", "Melee", "Pikkolo", "Tein", "Bluma", "Ranged"}) do
	frameSets[kind] = {R6 = makeFrames(kind, false), R15 = makeFrames(kind, true)}
end

function AttackAnimator.sample(profile, elapsed, r15)
	local set = frameSets[profile.kind] or frameSets.Ranged
	local frames = set[r15 and "R15" or "R6"]
	local age = math.max(0, tonumber(elapsed) or 0)
	if age >= frames[#frames].time then return {}, "Idle" end
	for index = 2, #frames do
		local a, b = frames[index - 1], frames[index]
		if age <= b.time then
			local alpha = ease((age - a.time) / (b.time - a.time))
			local pose = {}
			for name, value in pairs(a.pose) do
				pose[name] = value:Lerp(b.pose[name] or CFrame.identity, alpha)
			end
			for name, value in pairs(b.pose) do
				if not pose[name] then pose[name] = CFrame.identity:Lerp(value, alpha) end
			end
			return pose, age == b.time and b.phase or a.phase
		end
	end
	return {}, "Idle"
end

local function walkingPose(state, now)
	local swing = math.sin((now - state.walkEpoch) * 11) * 0.40 * state.walkWeight
	return {
		RightHip = CFrame.Angles(swing, 0, 0), LeftHip = CFrame.Angles(-swing, 0, 0),
		LeftShoulder = CFrame.Angles(swing * 0.75, 0, 0), RightShoulder = CFrame.Angles(-swing * 0.75, 0, 0),
	}
end

local function apply(state, now, elapsed)
	local pose, phase
	local attack = state.attack
	if attack then
		local age = elapsed or math.max(0, now - attack.startedAt)
		pose, phase = AttackAnimator.sample(attack.profile, age, state.r15)
		if age >= attack.profile.duration then
			state.attack = nil
		else
			local blend = ease(age / 0.10)
			if blend < 1 then
				for name, origin in pairs(attack.from) do
					pose[name] = origin:Lerp(pose[name] or CFrame.identity, blend)
				end
			end
		end
	else
		pose, phase = walkingPose(state, now), "Idle"
	end
	for _, entry in ipairs(state.joints) do
		if entry.joint.Parent then
			local offset = pose[entry.name] or CFrame.identity
			entry.current = offset
			-- Pose translations and rotations use Part0's body axes, including R6's rotated rest joints.
			entry.joint.C0 = entry.position * offset * entry.rotation
			entry.joint.Transform = CFrame.identity
		end
	end
	return phase
end

local function update()
	local paused = MatchClock.isPaused()
	local now = MatchClock.now()
	for model, state in pairs(states) do
		if not model.Parent then
			AttackAnimator.stop(model)
		elseif paused then
			-- Animator tracks still evaluate while MatchClock is paused.
			for _, entry in ipairs(state.joints) do
				if entry.joint.Parent then entry.joint.Transform = CFrame.identity end
			end
		else
			local dt = math.max(0, now - state.updatedAt)
			state.updatedAt = now
			local target = state.walking and not state.attack and 1 or 0
			state.walkWeight += (target - state.walkWeight) * (1 - math.exp(-12 * dt))
			apply(state, now)
		end
	end
end

local function getState(model)
	if states[model] then return states[model] end
	local now = MatchClock.now()
	local state = {
		model = model, r15 = model:FindFirstChild("UpperTorso") ~= nil,
		joints = {}, walking = false, walkWeight = 0, walkEpoch = now, updatedAt = now,
	}
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local name = joint.Name:gsub(" ", "")
			if joint.Part0.Name == "HumanoidRootPart" then name = state.r15 and "Root" or "RootJoint" end
			table.insert(state.joints, {
				joint = joint, name = name, original = joint.C0, originalTransform = joint.Transform,
				position = CFrame.new(joint.C0.Position), rotation = joint.C0.Rotation,
				current = CFrame.identity,
			})
		end
	end
	states[model] = state
	state.destroying = model.Destroying:Connect(function() AttackAnimator.stop(model) end)
	return state
end

local function start()
	if not connection then connection = RunService.PreSimulation:Connect(update) end
end

function AttackAnimator.setWalking(model, walking)
	getState(model).walking = walking == true
	start()
end

function AttackAnimator.play(model, unitName, profile, startedAt)
	local state = getState(model)
	local now = MatchClock.now()
	if state.attack and now - state.attack.startedAt < state.attack.profile.duration then return false end
	profile = profile or AttackTimeline.get(unitName, nil, nil)
	local from = {}
	for _, entry in ipairs(state.joints) do from[entry.name] = entry.current end
	state.attack = {profile = profile, startedAt = startedAt or now, from = from}
	state.walking = false
	start()
	apply(state, now)
	return true
end

function AttackAnimator.poseNow(model, elapsed)
	local state = states[model]
	if not state then return false end
	if MatchClock.isPaused() then return false end
	return true, apply(state, MatchClock.now(), elapsed)
end

function AttackAnimator.stop(model)
	local state = states[model]
	if not state then return end
	states[model] = nil
	if state.destroying then state.destroying:Disconnect() end
	for _, entry in ipairs(state.joints) do
		if entry.joint.Parent then
			entry.joint.C0 = entry.original
			entry.joint.Transform = entry.originalTransform
		end
	end
	if not next(states) and connection then
		connection:Disconnect()
		connection = nil
	end
end

function AttackAnimator.stopAll()
	local models = {}
	for model in pairs(states) do table.insert(models, model) end
	for _, model in ipairs(models) do AttackAnimator.stop(model) end
end

return AttackAnimator

