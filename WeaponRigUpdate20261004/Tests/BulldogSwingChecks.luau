return function(serviceSource)
	assert(not game:GetService("RunService"):IsRunning(), "Edit checks only")
	local Players = game:GetService("Players")
	local folder = Instance.new("Folder")
	folder.Name = "BulldogSwingChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
	folder.Parent = game.ServerStorage
	local rules = game.ServerScriptService.BritishBulldogRules:Clone()
	rules.Parent = folder
	local module = Instance.new("ModuleScript")
	module.Name = "Service"
	module.Source = serviceSource or game.ServerScriptService.BritishBulldogService.Source
	module.Parent = folder
	local wall
	local passed = {}
	local ok, result = xpcall(function()
		local Service = require(module)
		local function check(name, value) assert(value, name) table.insert(passed, name) end
		local origin = Vector3.new(100000, 500, 100000)
		local function record(id, role, offset)
			local character = Instance.new("Model")
			character.Parent = folder
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.new(origin + offset)
			root.Parent = character
			character.PrimaryPart = root
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			local player = { UserId = id, Parent = Players, Character = character, Attributes = {} }
			function player:GetAttribute(key) return self.Attributes[key] end
			function player:SetAttribute(key, value) self.Attributes[key] = value end
			return { player = player, character = character, root = root, humanoid = humanoid, role = role, ready = true, participating = true, departed = true, arrived = false, frozen = false, originalGroups = {} }
		end
		local attacker = record(12001, "Bulldog", Vector3.zero)
		local victim = record(12002, "Runner", Vector3.new(0, 0, -3))
		local other = record(12003, "Runner", Vector3.new(0, 0, -4))
		local arena = Instance.new("Folder")
		arena.Parent = folder
		local state = Instance.new("Folder")
		state.Parent = folder
		local service = setmetatable({ running = true, active = true, phase = "Crossing", endsAt = workspace:GetServerTimeNow() + 1000, currentRound = {}, crossingNumber = 1, records = {}, arena = arena, state = state, fieldAllowed = true }, Service)
		for _, value in ipairs({ attacker, victim, other }) do service.records[value.player] = value end
		function service:_inField(position) return self.fieldAllowed and position.X < origin.X + 10 end
		function service:_departure() end
		function service:_setRole(value, role) value.role = role value.batSwing = nil end
		local ragdolls = 0
		function service:_ragdoll(value, hitter) ragdolls += 1 value.ragdoll = { hitter = hitter } return true end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder }
		params.RespectCanCollide = true
		local function reset()
			attacker.batSwing = nil attacker.batSwingReadyAt = -math.huge
			attacker.root.CFrame = CFrame.new(origin)
			victim.root.CFrame = CFrame.new(origin + Vector3.new(0, 0, -3))
			other.root.CFrame = CFrame.new(origin + Vector3.new(0, 0, -4))
			for _, target in ipairs({ victim, other }) do target.role = "Runner" target.participating = true target.arrived = false target.departed = true target.ragdoll = nil end
		end
		local function start()
			check("accepted swing", service:TryBatSwing(attacker.player))
			return attacker.batSwing
		end
		service:_resolveBatSwings(workspace:GetServerTimeNow(), params)
		check("contact alone never tags", victim.role == "Runner" and other.role == "Runner" and ragdolls == 0)
		for _, rule in ipairs({
			{ service, "active", false }, { service, "running", false }, { service, "phase", "Countdown" },
			{ attacker, "role", "Runner" }, { attacker, "ready", false }, { attacker, "participating", false },
			{ attacker, "frozen", true }, { attacker, "ragdoll", {} }, { attacker, "pendingBulldog", true },
			{ service, "fieldAllowed", false }, { attacker.player, "Parent", false },
		}) do
			local object, key, value = rule[1], rule[2], rule[3]
			local previous = object[key]
			object[key] = value
			check("reject swing when " .. key .. " is invalid", not service:TryBatSwing(attacker.player))
			object[key] = previous
		end
		local endsAt = service.endsAt
		service.endsAt = workspace:GetServerTimeNow() - 1
		check("expired round rejects swings", not service:TryBatSwing(attacker.player))
		service.endsAt = endsAt
		check("unknown player rejects swings", not service:TryBatSwing({}))
		local swing = start()
		check("swing publishes timestamp before contact and a serial", attacker.player:GetAttribute("PCBatSwingSerial") == 1 and math.abs(swing.hitAt - attacker.player:GetAttribute("PCBatSwingAt") - 0.16) < 0.0001)
		check("cooldown rejects repeated clicks", not service:TryBatSwing(attacker.player) and attacker.batSwing == swing)
		service:_resolveBatSwings(swing.hitAt - 0.001, params)
		check("windup does not hit", victim.role == "Runner" and ragdolls == 0)
		service:_resolveBatSwings(swing.hitAt, params)
		check("nearest forward target ragdolls during hit window", victim.role == "Tagged" and victim.ragdoll.hitter == attacker and ragdolls == 1)
		check("one target per swing", other.role == "Runner" and attacker.batSwing == nil)
		check("confirmed hit publishes shared VFX serial", attacker.player:GetAttribute("PCBatHitSerial") == 1 and attacker.player:GetAttribute("BBBatHitSerial") == nil)
		service:_resolveBatSwings(swing.hitAt + 0.01, params)
		check("consumed swing cannot hit twice", ragdolls == 1)
		reset()
		swing = start()
		service:CancelBatSwing(attacker.player)
		service:_resolveBatSwings(swing.hitAt, params)
		check("unequip cancellation removes pending contact", victim.role == "Runner" and attacker.batSwing == nil)
		check("cancellation does not bypass cooldown", not service:TryBatSwing(attacker.player))
		reset()
		swing = start()
		service:_resolveBatSwings(swing.endsAt + 0.001, params)
		check("expired swing cannot hit", attacker.batSwing == nil and victim.role == "Runner")
		for _, mode in ipairs({ "behind", "range", "safe", "notDeparted", "outsideField", "vertical" }) do
			reset() other.participating = false
			if mode == "behind" then victim.root.CFrame = CFrame.new(origin + Vector3.new(0, 0, 2))
			elseif mode == "range" then victim.root.CFrame = CFrame.new(origin + Vector3.new(0, 0, -5))
			elseif mode == "safe" then victim.arrived = true
			elseif mode == "notDeparted" then victim.departed = false
			elseif mode == "outsideField" then victim.root.CFrame = CFrame.new(origin + Vector3.new(11, 0, -2))
			elseif mode == "vertical" then victim.root.CFrame = CFrame.new(origin + Vector3.new(0, 5, -1)) end
			swing = start()
			service:_resolveBatSwings(swing.hitAt, params)
			check("reject target " .. mode, victim.role == "Runner")
		end
		reset() other.participating = false
		wall = Instance.new("Part")
		wall.Name = "_BulldogSwingCheckWall"
		wall.Anchored = true
		wall.Size = Vector3.new(8, 8, 0.5)
		wall.CFrame = CFrame.new(origin + Vector3.new(0, 0, -1.5))
		wall.Parent = workspace
		swing = start()
		service:_resolveBatSwings(swing.hitAt, params)
		check("wall blocks contact", victim.role == "Runner")
		wall:Destroy() wall = nil
		for _, change in ipairs({ "round", "crossing", "character", "role", "phase" }) do
			reset()
			swing = start()
			local oldRound, oldCrossing, oldCharacter, oldRole, oldPhase = service.currentRound, service.crossingNumber, attacker.character, attacker.role, service.phase
			if change == "round" then service.currentRound = {}
			elseif change == "crossing" then service.crossingNumber += 1
			elseif change == "character" then attacker.character = victim.character
			elseif change == "role" then attacker.role = "Runner"
			elseif change == "phase" then service.phase = "Results" end
			service:_resolveBatSwings(swing.hitAt, params)
			check("invalidate pending swing after " .. change, attacker.batSwing == nil and victim.role == "Runner")
			service.currentRound, service.crossingNumber, attacker.character, attacker.role, service.phase = oldRound, oldCrossing, oldCharacter, oldRole, oldPhase
		end
		reset()
		swing = start()
		Service._teleport(service, attacker, CFrame.new(origin))
		check("teleport cancels pending swing", attacker.batSwing == nil)
		reset()
		swing = start()
		Service._freeze(service, attacker)
		check("freeze cancels pending swing", attacker.batSwing == nil and attacker.frozen)
		attacker.frozen = false
		reset() attacker.isBot = true attacker.player.Parent = nil
		check("practice bots use the validated swing API", service:TryBatSwing(attacker.player))
		check("practice bots respect cooldown", not service:TryBatSwing(attacker.player))
		return { passed = #passed, checks = passed, playStarted = false, realPlayersMutated = 0 }
	end, debug.traceback)
	if wall then wall:Destroy() end
	folder:Destroy()
	assert(ok, result)
	return result
end
