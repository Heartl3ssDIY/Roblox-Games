return function(animationSource)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local source = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local module = Instance.new("ModuleScript")
	module.Name = "_ReviewEmotesCapabilities"
	module.Source = assert((animationSource or source.Source):match("^(.-)local beforeAnimation ="))
		.. "\nreturn { sample = sampleBatPose, apply = weaponJoint, restore = restore }"
	module.Capabilities = source.Capabilities
	module.Sandboxed = source.Sandboxed
	module.Parent = game.ServerStorage
	local report = { playStarted = false, capabilities = tostring(source.Capabilities), rigs = {} }
	local ok, methods = pcall(require, module)
	report.required = ok
	if ok then
		for _, rigName in ipairs({ "R6", "R15" }) do
			local rig = game.ServerStorage.WeaponRigFixtures[rigName]:Clone()
			rig.Parent = game.ServerStorage
			local joint = rig:FindFirstChild(rigName == "R6" and "Right Shoulder" or "RightShoulder", true)
			local record = { joints = {} }
			local success, problem = pcall(function()
				local original = joint.Transform
				methods.apply(record, joint, methods.sample(0.16, rigName == "R6"), 1)
				assert(joint.Transform ~= original, "Pose did not change")
				methods.restore(record)
				assert(joint.Transform == original, "Pose was not restored")
			end)
			report.rigs[rigName] = { success = success, error = not success and tostring(problem) or nil }
			rig:Destroy()
		end
	else
		report.error = tostring(methods)
	end
	module:Destroy()
	report.passed = report.required and report.rigs.R6 and report.rigs.R6.success and report.rigs.R15 and report.rigs.R15.success or false
	return report
end
