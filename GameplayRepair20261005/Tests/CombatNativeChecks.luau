local Tag = require(script.Parent.TagCandidate)
local BB = require(script.Parent.BBCandidate)
local H = Tag._CombatTest
local results = {}
local fixture = Instance.new("Folder")
fixture.Name = "GameplayRepairCombatAudit"
fixture.Parent = workspace
local origin = Vector3.new(42000, 12000, 42000)
local function check(name, callback)
	local ok, reason = pcall(callback)
	table.insert(results, { name = name, passed = ok, error = not ok and tostring(reason) or nil })
end
local function part(name, position, size)
	local value = Instance.new("Part")
	value.Name, value.Anchored, value.Size = name, true, size or Vector3.one
	value.Position, value.Parent = position, fixture
	return value
end
local function makeRecord(rig, position, role)
	local character = game:GetService("ServerStorage").WeaponRigFixtures[rig]:Clone()
	character.Parent = fixture
	local root, humanoid = character.HumanoidRootPart, character:FindFirstChildOfClass("Humanoid")
	for _, value in character:GetDescendants() do
		if value:IsA("BasePart") then value.Anchored, value.CanCollide, value.CanQuery = true, false, false end
	end
	root.CFrame = CFrame.new(position)
	local attrs = {}
	local player = { Character = character, DisplayName = "Practice Tagger", UserId = -1 }
	function player:GetAttribute(key) return attrs[key] end
	function player:SetAttribute(key, value) attrs[key] = value end
	return { player = player, character = character, root = root, humanoid = humanoid, ready = true,
		isBot = true, participating = true, role = role, departed = true, arrived = false, frozen = false }
end
local attacker = makeRecord("R6", origin, "Tagger")
local target = makeRecord("R15", origin + Vector3.new(0, 0, -3), "Runner")
local records = { [attacker.player] = attacker, [target.player] = target }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { attacker.character, target.character }
params.RespectCanCollide = true
local function at(record, position, facing)
	record.root.CFrame = CFrame.lookAt(origin + position, origin + position + (facing or Vector3.new(0, 0, -1)))
end
local function swing(startPosition, finishPosition, startTime, endTime)
	at(attacker, Vector3.zero)
	at(target, startPosition)
	local s = { hitAt = 0.1, endsAt = 0.38 }
	H.sample(s, attacker, records, startTime or 0.12)
	at(target, finishPosition or startPosition)
	return H.contact(s, attacker, target, endTime or 0.17, 4.5, params)
end
local ok, failure = xpcall(function()
	check("Native R6 attacker / R15 close front target", function() assert(swing(Vector3.new(0, 0, -3))) end)
	check("Fast runner crossing between samples hits", function() assert(swing(Vector3.new(-5, 0, -2), Vector3.new(5, 0, -2))) end)
	check("Close circling runner at swing edge hits", function() assert(swing(Vector3.new(-4.4, 0, -1), Vector3.new(-3.6, 0, -2.5))) end)
	check("Diagonal dodge enters cone and reach only between old sample points", function()
		assert(swing(Vector3.new(-4.7, 0, -1.65), Vector3.new(-0.7, 0, 0.95), 0.12, 0.26))
	end)
	check("Turning attacker catches a stationary target entering its front arc", function()
		at(attacker, Vector3.zero, Vector3.new(0, 0, -1)) at(target, Vector3.new(-3, 0, 0))
		local s = { hitAt = 0.1, endsAt = 0.38 }
		H.sample(s, attacker, records, 0.12)
		at(attacker, Vector3.zero, Vector3.new(-1, 0, 0))
		assert(H.contact(s, attacker, target, 0.26, 4.5, params))
	end)
	check("Rotating attacker never reaches a target behind its whole arc", function()
		at(attacker, Vector3.zero, Vector3.new(0, 0, -1)) at(target, Vector3.new(3, 0, 3))
		local s = { hitAt = 0.1, endsAt = 0.38 }
		H.sample(s, attacker, records, 0.12)
		at(attacker, Vector3.zero, Vector3.new(-1, 0, 0))
		assert(not H.contact(s, attacker, target, 0.26, 4.5, params))
	end)
	check("Degenerate opposite-facing interpolation cannot produce side contact", function()
		at(attacker, Vector3.zero, Vector3.new(1, 0, 0)) at(target, Vector3.new(0, 0, -3))
		local s = { hitAt = 0.1, endsAt = 0.38 }
		H.sample(s, attacker, records, 0.12)
		at(attacker, Vector3.zero, Vector3.new(-1, 0, 0))
		assert(not H.contact(s, attacker, target, 0.26, 4.5, params))
	end)
	check("Moving rotating sweeps include every dense-oracle contact across 160 cases", function()
		local random = Random.new(381209)
		for case = 1, 160 do
			local firstAngle = random:NextNumber(-math.pi, math.pi)
			local lastAngle = firstAngle + random:NextNumber(-math.pi * 0.75, math.pi * 0.75)
			local firstFacing = Vector3.new(math.sin(firstAngle), 0, -math.cos(firstAngle))
			local lastFacing = Vector3.new(math.sin(lastAngle), 0, -math.cos(lastAngle))
			local firstPosition = Vector3.new(random:NextNumber(-6,6), 0, random:NextNumber(-6,6))
			local lastPosition = firstPosition + Vector3.new(random:NextNumber(-6,6), 0, random:NextNumber(-6,6))
			at(attacker, Vector3.zero, firstFacing) at(target, firstPosition)
			local s = { hitAt = 0.1, endsAt = 0.38 }
			H.sample(s, attacker, records, 0.12)
			at(attacker, Vector3.zero, lastFacing) at(target, lastPosition)
			local old = s.sample.targets[target].position - s.sample.origin
			local current = target.root.Position - attacker.root.Position
			local dense = false
			for index = 0, 512 do
				local alpha = index / 512
				local offset = old:Lerp(current, alpha)
				local facing = s.sample.forward:Lerp(attacker.root.CFrame.LookVector, alpha)
				if offset.Magnitude < 4.499 and offset.Magnitude > 0.01 and facing.Magnitude > 0.01 and facing.Unit:Dot(offset.Unit) >= 0.25001 then dense = true break end
			end
			local found = H.contact(s, attacker, target, 0.26, 4.5, params)
			assert(not dense or found, "missed rotating sweep " .. tostring(case))
		end
	end)
	check("Moving attacker and moving target use relative sweep", function()
		at(attacker, Vector3.new(-3, 0, 0)) at(target, Vector3.new(3, 0, -2))
		local s = { hitAt = 0.1, endsAt = 0.38 }
		H.sample(s, attacker, records, 0.12)
		at(attacker, Vector3.new(3, 0, 0)) at(target, Vector3.new(-3, 0, -2))
		assert(H.contact(s, attacker, target, 0.17, 4.5, params))
	end)
	check("Behind attacker misses", function() assert(not swing(Vector3.new(0, 0, 3))) end)
	check("Outside short reach misses", function() assert(not swing(Vector3.new(0, 0, -4.51))) end)
	check("Large vertical separation misses", function() assert(not swing(Vector3.new(0, 5, -1))) end)
	check("Protected-time portion cannot hit", function()
		target.protectedEndsAt = 0.169
		assert(not swing(Vector3.new(-5, 0, -2), Vector3.new(5, 0, -2)))
		target.protectedEndsAt = nil
	end)
	target.protectedEndsAt = nil
	check("Contact before windup only misses", function() assert(not swing(Vector3.new(0, 0, -2), Vector3.new(8, 0, -2), 0.02, 0.12)) end)
	check("No contact after window closes", function() assert(not swing(Vector3.new(-6, 0, -2), Vector3.new(0, 0, -2), 0.39, 0.44)) end)
	check("Final overlapping interval is not dropped", function() assert(swing(Vector3.new(-5, 0, -2), Vector3.new(5, 0, -2), 0.35, 0.40)) end)
	check("Stale sample cannot sweep", function() assert(not swing(Vector3.new(-5, 0, -2), Vector3.new(5, 0, -2), 0.12, 0.30)) end)
	check("Teleport path cannot create hit", function() assert(not swing(Vector3.new(-15, 0, -2), Vector3.new(15, 0, -2))) end)
	check("Replacement character cannot reuse historical positions", function()
		at(attacker, Vector3.zero) at(target, Vector3.new(-5, 0, -2))
		local s = { hitAt = 0.1, endsAt = 0.38 }
		H.sample(s, attacker, records, 0.12)
		s.sample.targets[target].character = attacker.character
		at(target, Vector3.new(5, 0, -2))
		assert(not H.contact(s, attacker, target, 0.17, 4.5, params))
	end)
	local wall = part("Wall", origin + Vector3.new(0, 0, -1.5), Vector3.new(14, 10, 0.5))
	check("Native physical wall blocks stationary contact", function() assert(not swing(Vector3.new(0, 0, -3))) end)
	check("Native physical wall blocks swept contact", function() assert(not swing(Vector3.new(-5, 0, -2), Vector3.new(5, 0, -2))) end)
	wall:Destroy()
	local bounds = part("Bounds", origin, Vector3.new(150, 80, 150)) bounds.CanCollide, bounds.CanQuery = false, false
	local arena = Instance.new("Folder") arena.Parent = fixture
	local service = setmetatable({ active = true, running = true, phase = "Playing", endsAt = workspace:GetServerTimeNow() + 100,
		currentRound = 12, records = records, tagger = attacker, bounds = bounds, spawnPads = { { Position = origin } }, arena = arena }, Tag)
	service._rayParameters = function() return params end
	local now = workspace:GetServerTimeNow()
	local function reset()
		attacker.role, target.role, service.tagger = "Tagger", "Runner", attacker
		attacker.ragdoll, target.ragdoll, attacker.frozen, target.frozen = nil, nil, false, false
		attacker.batSwing, attacker.batSwingReadyAt, attacker.tagCooldownEndsAt = nil, 0, 0
		target.protectedEndsAt = 0
		at(attacker, Vector3.zero) at(target, Vector3.new(0, 0, -3))
	end
	reset()
	check("Native close dummy eligibility ignores static practice name", function() assert(service:_tagEligible(attacker, target, now)) end)
	check("Contact without manual swing never tags", function() assert(not service:_swingCanHit(attacker, target, now)) end)
	check("Accepted swing publishes timestamp and one serial", function()
		assert(service:TryBatSwing(attacker.player))
		assert(attacker.player:GetAttribute("PCBatSwingAt") and attacker.player:GetAttribute("PCBatSwingSerial") == 1)
	end)
	check("Repeated click obeys cooldown", function() assert(not service:TryBatSwing(attacker.player)) end)
	check("Wrong role cannot swing", function() assert(not service:TryBatSwing(target.player)) end)
	check("Cancelled swing cannot hit", function() service:CancelBatSwing(attacker.player) assert(not service:_swingCanHit(attacker, target, now)) end)
	check("Protected target remains immune", function() target.protectedEndsAt = now + 10 assert(not service:_tagEligible(attacker, target, now)) end)
	reset()
	check("Ragdolled attacker cannot swing", function() attacker.ragdoll = {} assert(not service:TryBatSwing(attacker.player)) end)
	reset()
	check("Frozen target cannot be hit", function() target.frozen = true assert(not service:_tagEligible(attacker, target, now)) end)
	reset()
	check("Wrong round swing cannot hit", function()
		attacker.batSwing = { character = attacker.character, token = 11, hitAt = now - 0.1, endsAt = now + 0.1 }
		assert(not service:_swingCanHit(attacker, target, now))
	end)
	reset()
	check("Live Tag transfer accepts swept moving target once", function()
		at(target, Vector3.new(-5, 0, -2))
		attacker.batSwing = { character = attacker.character, token = 12, hitAt = now - 0.1, endsAt = now + 0.1 }
		H.sample(attacker.batSwing, attacker, records, now - 0.05)
		at(target, Vector3.new(5, 0, -2))
		service.state, service.tagCount = arena, 0
		service._account, service._publish, service._ragdoll = function() end, function() end, function() end
		service._role = function(_, record, role) record.role = role record.batSwing = nil end
		assert(service:_transfer(target, now))
		assert(service.tagger == target and service.tagCount == 1 and attacker.player:GetAttribute("PCBatHitSerial") == 1)
		assert(not service:_transfer(attacker, now))
	end)
	reset()
	local bulldog = setmetatable({ running = true, active = true, phase = "Crossing", endsAt = now + 100,
		currentRound = 1, crossingNumber = 1, records = records }, BB)
	bulldog._inField = function() return true end
	attacker.role = "Bulldog"
	check("Bulldog manual swing accepts native R6", function() assert(bulldog:TryBatSwing(attacker.player)) end)
	check("Bulldog cooldown rejects repeat", function() assert(not bulldog:TryBatSwing(attacker.player)) end)
	check("Bulldog swept runner caught once", function()
		at(target, Vector3.new(-5, 0, -2))
		attacker.batSwing.hitAt, attacker.batSwing.endsAt = now - 0.1, now + 0.1
		H.sample(attacker.batSwing, attacker, records, now - 0.05)
		at(target, Vector3.new(5, 0, -2))
		local hits = 0
		bulldog._caught = function(_, record) assert(record == target) hits += 1 return true end
		bulldog:_resolveBatSwings(now, params) bulldog:_resolveBatSwings(now + 0.01, params)
		assert(hits == 1)
	end)
	check("Bulldog arrived-safe runner cannot be caught", function()
		at(target, Vector3.new(0, 0, -3)) target.arrived = true
		attacker.batSwing = { character = attacker.character, round = 1, crossing = 1, hitAt = now - 0.1, endsAt = now + 0.1 }
		bulldog._caught = function() error("safe runner tagged") end
		bulldog:_resolveBatSwings(now, params)
		target.arrived = false
	end)
	check("Chase prediction is horizontal and capped at four studs", function()
		target.root.AssemblyLinearVelocity = Vector3.new(100, 80, 100)
		local goal = H.chase(attacker, target)
		assert((goal - target.root.Position).Magnitude <= 4.001 and goal.Y == target.root.Position.Y)
		target.root.AssemblyLinearVelocity = Vector3.zero
	end)
	local floor = part("Ground", origin + Vector3.new(0, -3.5, 0), Vector3.new(100, 1, 100))
	check("Supported same-level corridor allows direct pursuit", function() assert(service:_directBotRoute(origin, origin + Vector3.new(20, 0, 0), params)) end)
	check("Open chest ray to raised platform still requires path", function() assert(not service:_directBotRoute(origin, origin + Vector3.new(20, 8, 0), params)) end)
	floor.Size = Vector3.new(8, 1, 100)
	check("Missing ground ahead requires path", function() assert(not service:_directBotRoute(origin, origin + Vector3.new(20, 0, 0), params)) end)
	floor.Size = Vector3.new(100, 1, 100)
	check("New path resumes ahead of a moving bot instead of backtracking", function()
		at(attacker, Vector3.new(14, 0, 0))
		local route = {}
		for index = 0, 7 do table.insert(route, { Position = origin + Vector3.new(index * 4, -3, 0), Action = Enum.PathWaypointAction.Walk }) end
		service:_adoptBotRoute(attacker, route)
		assert(attacker.routeIndex >= 5 and attacker.routeIndex <= 6, tostring(attacker.routeIndex))
	end)
	floor:Destroy()
	attacker.role = "Tagger" attacker.botSprintRemaining, attacker.botSprintExhausted, attacker.lastSprintAt = 10, false, 0
	check("Practice sprint matches human maximum speed", function() service:_botSprint(attacker, 0.1, true) assert(attacker.humanoid.WalkSpeed == 45) end)
	check("Practice sprint exhausts after bounded duration", function()
		for index = 2, 110 do service:_botSprint(attacker, index * 0.1, true) end
		assert(attacker.botSprintExhausted and attacker.humanoid.WalkSpeed == 18)
	end)
	check("Exhausted practice sprint must refill fully", function()
		for index = 111, 200 do service:_botSprint(attacker, index * 0.1, true) end
		assert(attacker.botSprintExhausted and attacker.humanoid.WalkSpeed == 18)
		for index = 201, 270 do service:_botSprint(attacker, index * 0.1, false) end
		assert(not attacker.botSprintExhausted and attacker.botSprintRemaining == 10)
	end)
	check("Path request busy flag prevents duplicate compute", function()
		attacker.pathBusy = {} local token = attacker.pathBusy
		service:_path(attacker, origin, now)
		assert(attacker.pathBusy == token)
		attacker.pathBusy = false
	end)
	check("Path request respects repath deadline", function()
		attacker.nextPathAt = now + 1 service:_path(attacker, origin, now)
		assert(attacker.pathBusy == false)
	end)
	check("Async native path cancels stale round without replacing route", function()
		attacker.root.CFrame = CFrame.new(6500, 36.5, 4534)
		local preserved = attacker.route
		attacker.nextPathAt = 0
		service:_path(attacker, Vector3.new(6350, 47.9, 4636), now)
		service.currentRound += 1
		local deadline = os.clock() + 8
		while attacker.pathBusy and os.clock() < deadline do task.wait(0.05) end
		assert(attacker.pathBusy == false, "native path did not finish within 8 seconds")
		assert(attacker.route == preserved, "stale route was installed")
	end)
	for _, entry in ipairs({ { name = "Tag", module = Tag, field = "burst" }, { name = "Bulldog", module = BB, field = "dodgeBurst" } }) do
		check(entry.name .. " ragdoll snapshots restored AutoRotate after cancelling dodge", function()
			local record = makeRecord("R15", origin + Vector3.new(30,0,0), "Runner")
			record.humanoid.AutoRotate = false
			record[entry.field] = { root = record.root, humanoid = record.humanoid, autoRotate = true, direction = Vector3.xAxis, ownershipAuto = true }
			local owner = setmetatable({ currentRound = 1 }, entry.module)
			owner._movement, owner._lockJump, owner._freeze = function() end, function() end, function() end
			local started = entry.module._ragdoll(owner, record, nil, now)
			local saved = record.ragdoll
			local restored = saved and saved.AutoRotate
			owner:_restoreRagdoll(record, false)
			assert(started and restored == true and record.humanoid.AutoRotate == true)
			record.character:Destroy()
		end)
	end
end, debug.traceback)
fixture:Destroy()
if not ok then table.insert(results, { name = "Fixture completed", passed = false, error = failure }) end
local passed = 0
for _, result in ipairs(results) do if result.passed then passed += 1 end end
return { passed = passed, total = #results, checks = results }
