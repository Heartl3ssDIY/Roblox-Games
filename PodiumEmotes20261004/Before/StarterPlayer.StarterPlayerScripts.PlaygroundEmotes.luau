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
	local applied = original * offset
	joint.Transform = applied
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local batPoses = {
	{ time = 0, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
	{ time = 0.11, r6 = Vector3.new(115, -55, -15), r15 = Vector3.new(85, -55, -15), elbow = 35, wrist = -10 },
	{ time = 0.20, r6 = Vector3.new(75, 25, -10), r15 = Vector3.new(55, 25, -10), elbow = 20, wrist = 8 },
	{ time = 0.30, r6 = Vector3.new(60, 65, -12), r15 = Vector3.new(40, 65, -12), elbow = 25, wrist = 12 },
	{ time = 0.48, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
}
local function sampleBatPose(elapsed, classic)
	local key = classic and "r6" or "r15"
	if elapsed < 0 or elapsed >= 0.48 then return batPoses[1][key], batPoses[1].elbow, 0 end
	for index = 2, #batPoses do
		local first, last = batPoses[index - 1], batPoses[index]
		if elapsed <= last.time then
			local alpha = (elapsed - first.time) / (last.time - first.time)
			alpha = alpha * alpha * (3 - 2 * alpha)
			return first[key]:Lerp(last[key], alpha), first.elbow + (last.elbow - first.elbow) * alpha, first.wrist + (last.wrist - first.wrist) * alpha
		end
	end
end
local function weaponJoint(record, joint, angles, fade)
	if not joint or not joint.Parent or not joint.Enabled or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local original = joint.Transform
	local rotation = joint.C0.Rotation
	local target = rotation:Inverse() * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z)) * rotation
	local applied = original:Lerp(target, fade)
	joint.Transform = applied
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function animateBat(record, player, character, humanoid, now)
	local tool
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("PCBatWeapon") == true then tool = child break end
	end
	if not tool or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
		or (player:GetAttribute("BBParticipating") ~= true and player:GetAttribute("TGParticipating") ~= true) then
		record.weapon = nil
		return false
	end
	if record.weapon ~= tool then
		record.weapon = tool
		record.weaponAt = now
		record.shoulder = character:FindFirstChild(humanoid.RigType == Enum.HumanoidRigType.R6 and "Right Shoulder" or "RightShoulder", true)
		record.elbow = character:FindFirstChild("RightElbow", true)
		record.wrist = character:FindFirstChild("RightWrist", true)
	end
	local started = tool:GetAttribute("BatSwingAt")
	local elapsed = typeof(started) == "number" and now - started or math.huge
	local shoulder, elbow, wrist = sampleBatPose(elapsed, humanoid.RigType == Enum.HumanoidRigType.R6)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	weaponJoint(record, record.shoulder, shoulder, fade)
	weaponJoint(record, record.elbow, Vector3.new(elbow, 0, 0), fade)
	weaponJoint(record, record.wrist, Vector3.new(0, wrist, 0), fade)
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
			restore(record)
			continue
		end
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = character:FindFirstChild(classic and "Right Shoulder" or "RightShoulder", true)
		local left = character:FindFirstChild(classic and "Left Shoulder" or "LeftShoulder", true)
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, character:FindFirstChild("RightElbow", true), CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, character:FindFirstChild("Waist", true), CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
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
