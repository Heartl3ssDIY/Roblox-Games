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
