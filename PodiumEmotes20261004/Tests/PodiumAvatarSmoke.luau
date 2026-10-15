return function(source)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local report = { playStarted = false, requested = false, completed = false }
	if game.CreatorType ~= Enum.CreatorType.User or game.CreatorId <= 0 then
		report.limitation = "Place creator is not a user; no real avatar lookup attempted"
		return report
	end
	local prototype = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local fixture = Instance.new("Folder")
	fixture.Name = "_PodiumAvatarSmoke"
	fixture.Parent = game.ServerStorage
	local helper = Instance.new("ModuleScript")
	helper.Name = "AvatarSmokeHelper"
	helper.Capabilities, helper.Sandboxed = prototype.Capabilities, prototype.Sandboxed
	helper.Source = assert(source:match("^(.-)local gui = script.Parent")) .. [[
return function(userId, parent)
	local model = Players:CreateHumanoidModelFromUserIdAsync(userId)
	local ok, result = xpcall(function()
		local avatar = prepareModel(model)
		model.Parent = parent
		local low, high = bodyBounds(model)
		assert(math.abs(high - low - 5.5) < 0.01, "Created avatar height mismatch")
		local parts, joints = 0, 0
		for _, object in ipairs(model:GetDescendants()) do
			if readableIsA(object, "BasePart") then
				assert(not object.CanCollide and not object.CanTouch and not object.CanQuery and object.Massless, "Interactive avatar part")
				parts += 1
			elseif readableIsA(object, "AnimationConstraint") then
				assert(object.IsKinematic and object.Enabled, "Animation constraint inactive")
				joints += 1
			end
		end
		return { bodyHeight = high - low, bodyAndAccessoryParts = parts, nativeAnimationConstraints = joints, rootAnchored = avatar.root.Anchored }
	end, debug.traceback)
	model:Destroy()
	if not ok then error(result) end
	return result
end
]]
	helper.Parent = fixture
	report.capabilities = tostring(helper.Capabilities)
	report.exactCapabilities = helper.Capabilities == prototype.Capabilities and helper.Sandboxed == prototype.Sandboxed
	report.creatorUserId = game.CreatorId
	report.requested = true
	local startedAt = os.clock()
	local expired = false
	task.spawn(function()
		local ok, result = xpcall(function() return require(helper)(game.CreatorId, fixture) end, debug.traceback)
		if not expired then
			report.completed = true
			report.passed = ok
			if ok then report.avatar = result else report.error = result end
		end
		fixture:Destroy()
	end)
	while not report.completed and os.clock() - startedAt < 20 do task.wait(0.1) end
	report.elapsedSeconds = os.clock() - startedAt
	if not report.completed then
		expired = true
		report.limitation = "Avatar API did not complete within 20 seconds; late result cleanup remains active"
		fixture:Destroy()
	end
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
