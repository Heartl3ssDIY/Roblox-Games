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


