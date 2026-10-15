return function(source)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local folder = Instance.new("Folder")
	folder.Name = "BulldogNativeRagdollChecks"
	folder.Parent = game.ServerStorage
	local rules = game.ServerScriptService.BritishBulldogRules:Clone()
	rules.Parent = folder
	local live = game.ServerScriptService.BritishBulldogService
	local module = live:Clone()
	module.Name = "Service"
	module.Source = source or live.Source
	module.Parent = folder
	local checks = {}
	local success, result = xpcall(function()
		local Service = require(module)
		local function check(name, value) assert(value, name) table.insert(checks, name) end
		for _, fixtureName in ipairs({ "R6", "R15" }) do
			local original = game.ServerStorage.WeaponRigFixtures:FindFirstChild(fixtureName)
			assert(original, fixtureName .. " fixture missing")
			local character = original:Clone()
			character.Parent = folder
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			local attributes = {}
			local player = { UserId = 19991, Character = character }
			function player:GetAttribute(name) return attributes[name] end
			function player:SetAttribute(name, value) attributes[name] = value end
			local record = { player = player, character = character, humanoid = humanoid, root = root, participating = true, ready = true, role = "Tagged", originalGroups = {} }
			local service = setmetatable({ arena = folder, records = {}, active = true, running = true, currentRound = {}, phase = "Crossing", endsAt = workspace:GetServerTimeNow() + 500 }, Service)
			service.records[player] = record
			local joints, sockets, collision = {}, {}, {}
			local totalSockets, animationCount = 0, 0
			for _, object in ipairs(character:GetDescendants()) do
				if object:IsA("Motor6D") or object:IsA("AnimationConstraint") then
					if object.Part0 and object.Part1 and object.Part0.Parent == character and object.Part1.Parent == character then
						joints[object] = object.Enabled
						if object:IsA("AnimationConstraint") then animationCount += 1 end
					end
				elseif object:IsA("BallSocketConstraint") then sockets[object] = object.Enabled totalSockets += 1
				elseif object:IsA("BasePart") then collision[object] = object.CanCollide end
			end
			check(fixtureName .. " contains editable body joints", next(joints) ~= nil)
			if fixtureName == "R15" then check("actual R15 uses AnimationConstraints", animationCount > 0) end
			local requiresNeck, platformStand, autoRotate = humanoid.RequiresNeck, humanoid.PlatformStand, humanoid.AutoRotate
			local now = workspace:GetServerTimeNow()
			check(fixtureName .. " ragdoll starts", service:_ragdoll(record, nil, now))
			check(fixtureName .. " ragdoll state published", record.ragdoll ~= nil and attributes.BBRagdolled == true)
			local released = 0
			for joint, enabled in pairs(joints) do
				if joint.Part0 ~= root and joint.Part1 ~= root and enabled then
					check(fixtureName .. " releases " .. joint.Name, joint.Enabled == false)
					released += 1
				else check(fixtureName .. " preserves root or disabled " .. joint.Name, joint.Enabled == enabled) end
			end
			check(fixtureName .. " releases limb joints", released >= 5)
			if fixtureName == "R15" then
				local count = 0
				for _, object in ipairs(character:GetDescendants()) do if object:IsA("BallSocketConstraint") then count += 1 end end
				check("native R15 sockets reused without duplicates", count == totalSockets)
			end
			service:_restoreRagdoll(record, true)
			for joint, enabled in pairs(joints) do check(fixtureName .. " restores " .. joint.Name, joint.Enabled == enabled) end
			for socket, enabled in pairs(sockets) do check(fixtureName .. " preserves native " .. socket.Name, socket.Enabled == enabled) end
			for part, canCollide in pairs(collision) do assert(part.CanCollide == canCollide, fixtureName .. " collision mismatch " .. part.Name) end
			check(fixtureName .. " restores humanoid state", humanoid.RequiresNeck == requiresNeck and humanoid.PlatformStand == platformStand and humanoid.AutoRotate == autoRotate)
			check(fixtureName .. " removes owned constraints and flags", character:FindFirstChild("BBRagdollConstraints") == nil and record.ragdoll == nil and attributes.BBRagdolled == false)
			service:_restoreRagdoll(record, true)
			check(fixtureName .. " repeated cleanup is safe", record.ragdoll == nil)
			character:Destroy()
		end
		return {
			passed = #checks, checks = checks, playStarted = false, originalRigsMutated = false,
			exactLiveCapabilities = module.Capabilities == live.Capabilities,
			sandboxed = module.Sandboxed, capabilities = tostring(module.Capabilities),
		}
	end, debug.traceback)
	folder:Destroy()
	assert(success, result)
	return result
end
