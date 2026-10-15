return function(rig, entries)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "R15 fixture has no Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	local content = game:GetService("ContentProvider")
	local results = {}
	for _, entry in ipairs(entries) do
		local result = { catalogId = entry.catalogId, animationId = entry.animationId, loadStatus = "pending", playable = false }
		table.insert(results, result)
		local animation, track
		local ok, failure = xpcall(function()
			animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. tostring(entry.animationId)
			local statuses = {}
			if content then
				content:PreloadAsync({ animation }, function(assetId, status)
					table.insert(statuses, { assetId = assetId, status = tostring(status) })
				end)
			else result.preloadStatus = "service_unavailable_in_existing_capabilities" end
			result.preload = statuses
			track = animator:LoadAnimation(animation)
			track.Priority, track.Looped = Enum.AnimationPriority.Action, true
			track:Play(0)
			local deadline = os.clock() + 5
			while track.Length <= 0 and os.clock() < deadline do task.wait(0.05) end
			result.duration = track.Length
			result.isPlaying = track.IsPlaying
			result.playable = track.Length > 0 and track.IsPlaying
			result.loadStatus = result.playable and "verified_native_r15" or "track_not_ready"
		end, debug.traceback)
		if track then pcall(function() track:Stop(0) track:Destroy() end) end
		if animation then animation:Destroy() end
		if not ok then result.loadStatus, result.loadError = "failed", tostring(failure) end
	end
	return results
end
