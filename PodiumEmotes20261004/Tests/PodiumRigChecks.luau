return function(source)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local storage = game:GetService("ServerStorage")
	local prototype = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local fixture = Instance.new("Folder")
	fixture.Name = "_PodiumRigChecks"
	fixture.Parent = storage
	local report = { checks = {}, playStarted = false, avatarsFetched = 0 }
	local function check(name, value) assert(value, name) table.insert(report.checks, name) end
	local ok, problem = xpcall(function()
		local helpers = Instance.new("ModuleScript")
		helpers.Name = "PodiumHelpers"
		helpers.Source = assert(source:match("^(.-)local gui = script.Parent"))
			.. "\nreturn { prepare = prepareModel, animate = animateModel, restore = restorePose, bounds = bodyBounds, animationId = animationId }"
		helpers.Capabilities = prototype.Capabilities
		helpers.Sandboxed = prototype.Sandboxed
		helpers.Parent = fixture
		local functions = require(helpers)
		check("exact Emotes sandbox and capabilities", helpers.Capabilities == prototype.Capabilities and helpers.Sandboxed == prototype.Sandboxed)
		report.capabilities = tostring(helpers.Capabilities)
		check("numeric authored animation ids normalize", functions.animationId(12345) == "rbxassetid://12345" and functions.animationId("12345") == "rbxassetid://12345" and functions.animationId("rbxassetid://12345") == "rbxassetid://12345")
		for _, value in ipairs({ "", "0", "https://example.com/123", "abc", "123.5", "-1", math.huge, 0 / 0 }) do
			check("reject invalid animation id " .. tostring(value), functions.animationId(value) == nil)
		end
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Position = Vector3.new(100000, 500, 100000)
		floor.Parent = fixture
		local point = Instance.new("Attachment")
		point.Parent = floor
		for _, rigName in ipairs({ "R6", "R15" }) do
			local model = assert(storage.WeaponRigFixtures:FindFirstChild(rigName), "Native rig fixture missing"):Clone()
			model.Parent = fixture
			local accessory = Instance.new("Accessory")
			accessory.Name = "OversizedHatCheck"
			accessory.Parent = model
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(20, 20, 20)
			handle.Position = model.HumanoidRootPart.Position + Vector3.new(0, 40, 0)
			handle.Parent = accessory
			local stray = Instance.new("LocalScript")
			stray.Enabled = false
			stray.Parent = model
			local tool = Instance.new("Tool")
			tool.Parent = model
			local avatar = functions.prepare(model)
			local low, high = functions.bounds(model)
			check(rigName .. " body height is 5.5 excluding oversized accessory", math.abs(high - low - 5.5) < 0.002)
			check(rigName .. " generated scripts removed", stray.Parent == nil)
			check(rigName .. " inaccessible extra instance safely ignored", tool.Parent == model)
			check(rigName .. " root anchored and humanoid display hidden", avatar.root.Anchored and avatar.humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None and not avatar.humanoid.EvaluateStateMachine)
			for _, object in ipairs(model:GetDescendants()) do
				if object:IsA("BasePart") then
					assert(not object.CanCollide and not object.CanTouch and not object.CanQuery and object.Massless, object.Name .. " remained interactive")
					assert(object.Anchored == (object == avatar.root), object.Name .. " has incorrect anchoring")
				elseif object:IsA("AnimationConstraint") then assert(object.Enabled and object.IsKinematic, "Native joint must follow animation") end
			end
			check(rigName .. " every body and accessory part is noninteractive", true)
			functions.animate(avatar, point, 1, 0, false)
			low = functions.bounds(model)
			check(rigName .. " feet fit standing point", math.abs(low - point.WorldPosition.Y) < 0.003)
			check(rigName .. " faces podium front positive Z", avatar.root.CFrame.LookVector:Dot(Vector3.new(0, 0, 1)) > 0.999)
			local right = avatar.joints[rigName == "R6" and "Right Shoulder" or "RightShoulder"]
			assert(right, "Right shoulder missing")
			for rank = 1, 3 do
				functions.animate(avatar, point, rank, 0.8, false)
				check(rigName .. " rank " .. rank .. " celebration poses shoulder", right.joint.Transform ~= right.original)
				functions.restore(avatar)
				check(rigName .. " rank " .. rank .. " pose restores exactly", right.joint.Transform == right.original)
			end
			functions.animate(avatar, point, 1, 2, true)
			check(rigName .. " authored animation bypasses procedural joint pose", right.joint.Transform == right.original)
			model:Destroy()
		end
	end, debug.traceback)
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and problem or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
