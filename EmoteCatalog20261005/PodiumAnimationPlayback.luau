local function requestedAnimation(slot)
	local winner = slot.userId and Players:GetPlayerByUserId(slot.userId)
	local equipped, asset, rig
	if winner and winner:GetAttribute("PCDataReady") == true then
		equipped = winner:GetAttribute("PCEmote")
		asset = winner:GetAttribute("PCEquippedEmoteAnimationId")
		rig = winner:GetAttribute("PCEquippedEmoteRigType")
	else
		local entry = slot.entry
		equipped = entry and entry.emoteId
		asset = entry and entry.emoteAnimationId
		rig = entry and entry.emoteRigType
	end
	if typeof(equipped) == "string" and equipped ~= "" then
		return rig == "R15" and animationId(asset) or nil
	end
	return animationId(gui:GetAttribute("PodiumAnimationId"))
end

local function failedAnimation(slot, avatar)
	stopTrack(avatar)
	avatar.animationRetryAt = os.clock() + 15
	slot.display.StatusLabel.Text = avatar.animationAttempts >= 3 and "Dance unavailable" or "Dance is loading slowly"
end

local function updateAnimation(slot)
	local avatar = slot.avatar
	local requested = requestedAnimation(slot)
	if avatar.requestedAnimation ~= requested then
		stopTrack(avatar)
		avatar.requestedAnimation = requested
		avatar.animationAttempts, avatar.animationRetryAt = 0, 0
	end
	if not requested then return end
	local now = os.clock()
	if avatar.track then
		if avatar.track.Length > 0 and avatar.track.IsPlaying then
			avatar.animationAttempts, avatar.animationRetryAt = 0, 0
			return
		end
		if now - avatar.animationLoadedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if avatar.animationToken then
		if now - avatar.animationToken.startedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if (avatar.animationAttempts or 0) >= 3 or now < (avatar.animationRetryAt or 0) then return end
	avatar.animationAttempts = (avatar.animationAttempts or 0) + 1
	local token = {startedAt=now}
	avatar.animationToken = token
	local animation = Instance.new("Animation")
	animation.Name = "EquippedPodiumEmote"
	animation.AnimationId = requested
	avatar.animation, avatar.animationAsset = animation, requested
	token.worker = task.spawn(function()
		local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
		if not alive or token.expired or avatar.animationToken ~= token or slot.avatar ~= avatar or not avatar.model.Parent then
			if ok then track:Destroy() end
			return
		end
		avatar.animationToken = nil
		if not ok then failedAnimation(slot, avatar) return end
		avatar.track, avatar.animationLoadedAt = track, os.clock()
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.25)
		end)
		if not played then failedAnimation(slot, avatar)
		else slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or "" end
	end)
end
