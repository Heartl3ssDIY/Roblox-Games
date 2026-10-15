local function prepareRigMotion(state)
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
