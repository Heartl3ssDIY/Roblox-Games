return function(source)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local storage, players = game:GetService("ServerStorage"), game:GetService("Players")
	local prototype = game.ServerScriptService.PlaygroundEquipmentService
	local fixture = Instance.new("Folder")
	fixture.Name = "ToyCandidateAudit"
	fixture.Parent = storage
	local report = { checks = {}, failed = {}, playStartedOrStopped = false, externalDataStoreCalls = 0 }
	local function check(name, condition)
		table.insert(report.checks, name)
		if not condition then table.insert(report.failed, name) end
	end
	local service
	local ok, problem = xpcall(function()
		local module = prototype:Clone()
		module.Name = "ToyCandidateAudit"
		module.Source = source
		module.Parent = fixture
		check("exact existing Equipment capabilities and sandbox", module.Capabilities == prototype.Capabilities and module.Sandboxed == prototype.Sandboxed)
		report.capabilities = tostring(module.Capabilities)
		local Toys = require(module)
		check("candidate module requires without new capabilities", typeof(Toys) == "table")
		service = Toys.new()
		service.running = true
		service.folder = Instance.new("Folder")
		service.folder.Name = "Effects"
		service.folder.Parent = fixture
		service.bounds = Instance.new("Part")
		service.bounds.Name = "IsolatedBounds"
		service.bounds.Anchored = true
		service.bounds.Size = Vector3.new(320, 80, 304)
		service.bounds.CFrame = CFrame.new(100000, 40, 100000)
		service.bounds.Parent = fixture
		local function playerFixture(name, offset)
			local model = Instance.new("Model")
			model.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Size = Vector3.new(2, 2, 1)
			root.Position = Vector3.new(100000 + offset, 5, 100000)
			root.Parent = model
			local humanoid = Instance.new("Humanoid")
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 16, 50, 7.2
			humanoid.AutoRotate = true
			humanoid.RequiresNeck = false
			humanoid.Parent = model
			model.Parent = fixture
			local player = { Parent = players, Character = model, attributes = { PCDataReady = true } }
			function player:GetAttribute(key) return self.attributes[key] end
			function player:SetAttribute(key, value) self.attributes[key] = value end
			return player, humanoid, root
		end
		local owner, humanoid, root = playerFixture("Owner", 0)
		local target, targetHumanoid = playerFixture("Target", 5)
		local base = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
		local record = service:_record(owner)
		local time = workspace:GetServerTimeNow()
		record.speedUntil, record.jumpUntil = time + 25, time + 10
		service:_movement(record, time)
		check("native speed potion gives exactly three times base speed", humanoid.WalkSpeed == base.WalkSpeed * 3)
		check("native JumpPower gives five times ballistic height", math.abs(humanoid.JumpPower - base.JumpPower * math.sqrt(5)) < 0.001)
		check("native JumpHeight gives five times base height", math.abs(humanoid.JumpHeight - base.JumpHeight * 5) < 0.001)
		service:ClearPlayer(owner)
		check("round-preparation clear restores native speed", humanoid.WalkSpeed == base.WalkSpeed)
		check("round-preparation clear restores native JumpPower", humanoid.JumpPower == base.JumpPower)
		check("round-preparation clear restores native JumpHeight", humanoid.JumpHeight == base.JumpHeight)
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = base.WalkSpeed, base.JumpPower, base.JumpHeight
		record = service:_record(owner)
		record.speedUntil, record.jumpUntil, record.freezeUntil = time + 25, time + 10, time + 2.5
		service:_movement(record, time)
		check("native freeze blocks walking jumping and rotation", humanoid.WalkSpeed == 0 and humanoid.JumpPower == 0 and humanoid.JumpHeight == 0 and not humanoid.AutoRotate)
		service:_movement(record, time + 3)
		check("thaw resumes existing speed and jump effects", humanoid.WalkSpeed == 48 and math.abs(humanoid.JumpPower - 50 * math.sqrt(5)) < 0.001 and humanoid.AutoRotate)
		service:_movement(record, time + 30)
		check("expiration restores all native movement properties", humanoid.WalkSpeed == base.WalkSpeed and humanoid.JumpPower == base.JumpPower and humanoid.JumpHeight == base.JumpHeight and humanoid.AutoRotate == base.AutoRotate and record.base == nil)
		record.speedUntil = time + 20
		service:_movement(record, time)
		humanoid.WalkSpeed = 21
		service:ClearPlayer(owner)
		check("clear preserves a later unrelated native movement write", humanoid.WalkSpeed == 21)
		humanoid.WalkSpeed = base.WalkSpeed
		record = service:_record(owner)
		for index = 1, 15 do
			local id = string.format("M%02d", index)
			local position = root.Position + Vector3.new(index * 2, 4, 0)
			local model = service:_visual(id, position, 2.8)
			check(id .. " imported visual exists", model ~= nil)
			if model then
				local box, size = model:GetBoundingBox()
				check(id .. " visual center and scale preserved", (box.Position - position).Magnitude < 0.03 and math.abs(math.max(size.X, size.Y, size.Z) - 2.8) < 0.03)
				check(id .. " stores its imported pivot offset", typeof(model:GetAttribute("ToyVisualOffset")) == "CFrame")
				local noninteractive = true
				for _, object in ipairs(model:GetDescendants()) do
					if object:IsA("BasePart") and (not object.Anchored or object.CanCollide or object.CanTouch or object.CanQuery) then noninteractive = false end
				end
				check(id .. " all visual parts are anchored and noninteractive", noninteractive)
				local entry = service:_object(owner, model, 5, { position = position, velocity = Vector3.new(1, 0, 0), gravity = 0, cosmetic = true })
				service:_tickObject(entry, time, 0.1)
				box = model:GetBoundingBox()
				check(id .. " projectile update retains visual pivot offset", (box.Position - entry.position).Magnitude < 0.03)
			end
		end
		local before = #service.objects
		service:_confetti(root.Position, owner)
		check("confetti creates sixteen bounded objects", #service.objects - before == 16)
		before = #service.objects
		service:_splat(root.Position, Vector3.yAxis, owner, false)
		check("paint splat creates seven ten-second pieces", #service.objects - before == 7 and math.abs(service.objects[#service.objects].expiresAt - workspace:GetServerTimeNow() - 10) < 1)
		before = #service.objects
		service:_splat(root.Position, Vector3.yAxis, owner, true)
		check("cake splat creates seven five-second pieces", #service.objects - before == 7 and math.abs(service.objects[#service.objects].expiresAt - workspace:GetServerTimeNow() - 5) < 1)
		service:_burst(root.Position, Color3.fromRGB(255, 120, 50), "fire", 12)
		service:_burst(root.Position, Color3.fromRGB(100, 220, 255), "frost", 12)
		local emitters = 0
		for _, object in ipairs(service.folder:GetDescendants()) do if object:IsA("ParticleEmitter") then emitters += 1 end end
		check("native fire and frost particles create successfully", emitters == 2)
		service:_beam(root.Position, root.Position + Vector3.new(0, 0, 10), Color3.fromRGB(100, 220, 255))
		check("native ray visual creates successfully", service.folder:FindFirstChild("ToyRay") ~= nil)
		service:_freeze(target)
		local frozen = service.records[target]
		check("native freeze creates outline and immobilizes target", frozen and frozen.frost and frozen.frost.Adornee == target.Character and targetHumanoid.WalkSpeed == 0 and target:GetAttribute("PCToyFrozenUntil") > time)
		service:ClearPlayer(target)
		check("native freeze cleanup restores target and destroys outline", targetHumanoid.WalkSpeed == 16 and targetHumanoid.JumpPower == 50 and target.Character:FindFirstChild("ToyFrost") == nil)
		service:_burn(owner, target)
		local burning = service.records[target]
		check("native burn creates fire and ten-second timer", burning and burning.fire and burning.fire.Parent == target.Character.HumanoidRootPart and math.abs(burning.burnUntil - workspace:GetServerTimeNow() - 10) < 1)
		local healthBefore = targetHumanoid.Health
		service:_tickPlayer(burning, burning.nextBurn)
		check("native burn tick applies one damage only to isolated humanoid", targetHumanoid.Health == healthBefore - 1)
		service:ClearPlayer(owner)
		check("owner cleanup removes projectiles splats confetti and target burn ownership", #service.objects == 0 and burning.burnUntil == 0 and burning.burnOwner == nil)
		service:_tickPlayer(burning, workspace:GetServerTimeNow())
		check("cancelled burn removes native fire", target.Character.HumanoidRootPart:FindFirstChild("ToyCampfire") == nil)
		service:ClearPlayer(target)
		check("all fake player records are cleared", next(service.records) == nil)
		check("fixture effects stayed outside live Workspace", not fixture:IsDescendantOf(workspace))
	end, debug.traceback)
	local cleanupOk, cleanupError = pcall(function() if service then service:Stop() end end)
	fixture:Destroy()
	report.passed = ok and cleanupOk and #report.failed == 0
	report.error = not ok and problem or not cleanupOk and cleanupError or nil
	report.fixtureDestroyed = fixture.Parent == nil
	report.checkCount = #report.checks
	return report
end
