local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Animator = require(ReplicatedStorage:WaitForChild("AttackAnimator"))
local Timeline = require(ReplicatedStorage:WaitForChild("AttackTimeline"))
assert(type(Animator.sample) == "function", "Installed AttackAnimator.sample is unavailable")
local template = assert(ReplicatedStorage:WaitForChild("UnitModels"):FindFirstChild("Master Roshu"), "Master Roshu template is missing")
local clone = template:Clone()
clone.Parent = nil
local ok, result = pcall(function()
	local root = assert(clone:FindFirstChild("HumanoidRootPart"), "Roshu has no HumanoidRootPart")
	local torso = clone:FindFirstChild("UpperTorso") or assert(clone:FindFirstChild("Torso"), "Roshu torso is missing")
	local left = clone:FindFirstChild("LeftHand") or assert(clone:FindFirstChild("Left Arm"), "Roshu left arm is missing")
	local right = clone:FindFirstChild("RightHand") or assert(clone:FindFirstChild("Right Arm"), "Roshu right arm is missing")
	local originalRoot = root.CFrame
	local originalSourceRoot = template.HumanoidRootPart.CFrame
	local r15 = clone:FindFirstChild("UpperTorso") ~= nil
	local joints, byPart, rootJoint = {}, {}, nil
	for _, joint in ipairs(clone:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local name = joint.Name:gsub(" ", "")
			if joint.Part0 == root then
				name = r15 and "Root" or "RootJoint"
				rootJoint = joint
			end
			table.insert(joints, {
				joint = joint, name = name,
				position = CFrame.new(joint.C0.Position), rotation = joint.C0.Rotation,
			})
			byPart[joint.Part1] = joint
		end
	end
	assert(rootJoint, "Roshu root motor is missing")
	local function place(pose)
		for _, entry in ipairs(joints) do
			entry.joint.C0 = entry.position * (pose[entry.name] or CFrame.identity) * entry.rotation
			entry.joint.Transform = CFrame.identity
		end
	end
	local function posed(part, visited)
		local joint = byPart[part]
		if not joint then return part.CFrame end
		visited = visited or {}
		assert(not visited[part], "Cyclic Roshu motor hierarchy")
		visited[part] = true
		return posed(joint.Part0, visited) * joint.C0 * joint.Transform * joint.C1:Inverse()
	end
	local function values(vector)
		return {vector.X, vector.Y, vector.Z}
	end
	local function palm(part, tip)
		return posed(part):PointToWorldSpace(tip and Vector3.new(0, -part.Size.Y * 0.5, 0)
			or Vector3.new(0, -part.Size.Y * 0.4, -0.08))
	end
	place({})
	local restTorso = posed(torso).Position
	local profile = Timeline.get("Master Roshu", "Tank", 5.3)
	local samples = {}
	for _, time in ipairs({0.68, 1.25, 1.35, 2.09, 2.25}) do
		local pose, phase = Animator.sample(profile, time, r15)
		place(pose)
		local l, r = palm(left), palm(right)
		local lt, rt = palm(left, true), palm(right, true)
		local unchanged = root.CFrame == originalRoot
		assert(unchanged, "Logical root moved during static pose sampling")
		table.insert(samples, {
			time = time, phase = phase,
			leftPalmRootLocal = values(originalRoot:PointToObjectSpace(l)),
			rightPalmRootLocal = values(originalRoot:PointToObjectSpace(r)),
			emissionMidpointRootLocal = values(originalRoot:PointToObjectSpace((l + r) / 2)),
			controllerPalmGap = (l - r).Magnitude,
			canonicalTipGap = (lt - rt).Magnitude,
			torsoLift = (posed(torso).Position - restTorso).Y,
			logicalRootUnchanged = unchanged,
		})
	end
	assert(template.HumanoidRootPart.CFrame == originalSourceRoot, "Source template moved")
	return {
		passed = true, rig = r15 and "R15" or "R6", jointCount = #joints,
		primaryPartIsHumanoidRootPart = clone.PrimaryPart == root,
		cloneUnparented = clone.Parent == nil, sourceTemplateUnchanged = true,
		timing = profile, samples = samples,
		scope = "Static sampled poses on an unparented real-template clone; analytic Motor6D hierarchy evaluation. No Play mode, physics stepping, listeners, animation playback or live scene writes.",
	}
end)
clone:Destroy()
if not ok then error(result) end
return result

