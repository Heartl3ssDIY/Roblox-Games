return function()
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local staging = game.ServerStorage._PushActionChecks20261008
	local BB = require(staging.BritishBulldogService)
	local TG = require(staging.TagService)
	local Push = require(staging.PlaygroundPushService)
	local world = Instance.new("Folder")
	world.Name = "_PushPhysicsChecks20261008"
	world.Parent = workspace
	local checks, services, pushServices, temporaryPlayers = {}, {}, {}, {}
	local function check(name, condition)
		assert(condition, name)
		table.insert(checks, name)
	end
	local origin = Vector3.new(10000, 100, 10000)
	local function part(name, position, size)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Position, p.Size = name, true, position, size
		p.Parent = world
		return p
	end
	local ground = part("Ground", origin - Vector3.new(0, 4, 0), Vector3.new(120, 1, 120))
	local bounds = part("Bounds", origin, Vector3.new(100, 30, 100))
	bounds.CanCollide, bounds.CanQuery, bounds.Transparency = false, false, 1
	local north = part("SafeNorth", origin + Vector3.new(0, 0, -45), Vector3.new(100, 30, 10))
	local south = part("SafeSouth", origin + Vector3.new(0, 0, 45), Vector3.new(100, 30, 10))
	north.CanCollide, north.CanQuery, south.CanCollide, south.CanQuery = false, false, false, false
	local function makeService(kind)
		local service = setmetatable({
			arena = world, gameplay = { StartPads = north, FindFirstChild = function() return nil end }, taggerSpawn = south,
			state = Instance.new("Folder"), records = {}, running = true, active = true,
			phase = kind == "BB" and "Crossing" or "Playing", currentRound = {}, crossingNumber = kind == "BB" and 1 or nil,
			endsAt = workspace:GetServerTimeNow() + 1000, bounds = bounds, northZ = -40, southZ = 40,
			safeZones = kind == "BB" and { North = north, South = south } or nil, tagCount = 0,
			spawnPads = kind == "BB" and {} or { bounds },
		}, kind == "BB" and BB or TG)
		service.state.Parent = staging
		table.insert(services, service)
		return service
	end
	local serial = 0
	local function makeRecord(service, rig, position, role)
		serial += 1
		local character = game.ServerStorage.WeaponRigFixtures[rig]:Clone()
		character.Name = rig .. "PushFixture" .. serial
		for _, object in character:GetDescendants() do
			if object:IsA("LuaSourceContainer") then object:Destroy() end
		end
		local humanoid, root = character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
		character.Parent = world
		character:PivotTo(CFrame.new(position) * root.CFrame:Inverse() * character:GetPivot())
		local attrs = {}
		local player = { Character = character, DisplayName = character.Name, UserId = 987000 + serial }
		function player:GetAttribute(key) return attrs[key] end
		function player:SetAttribute(key, value) attrs[key] = value end
		local record = { player = player, character = character, humanoid = humanoid, root = root,
			role = role or "Runner", participating = true, departed = true, arrived = false, ready = true,
			isBot = true, originalGroups = {}, taggerSeconds = 0, spawnIndex = 1, connections = {}, characterConnections = {} }
		service.records[player] = record
		return record
	end
	local function move(record, position)
		record.character:PivotTo(CFrame.new(position) * record.root.CFrame:Inverse() * record.character:GetPivot())
	end
	local function newPush(bb, tg)
		local push = Push.new(bb, tg)
		push.running = true
		table.insert(pushServices, push)
		return push
	end
	local ok, err = xpcall(function()
		for _, kind in ipairs({ "BB", "TG" }) do
			for _, rig in ipairs({ "R6", "R15" }) do
				local label = kind .. " " .. rig
				local service = makeService(kind)
				local attacker = makeRecord(service, rig, origin, kind == "BB" and "Bulldog" or "Tagger")
				local victim = makeRecord(service, rig, origin + Vector3.new(0, 0, -4))
				service.tagger = kind == "TG" and attacker or nil
				local now = workspace:GetServerTimeNow()
				local collisions, joints, sockets = {}, {}, {}
				for _, object in victim.character:GetDescendants() do
					if object:IsA("BasePart") then collisions[object] = object.CanCollide
					elseif object:IsA("Motor6D") or object:IsA("AnimationConstraint") then joints[object] = object.Enabled
					elseif object:IsA("BallSocketConstraint") then sockets[object] = object.Enabled end
				end
				check(label .. " starts three-second push ragdoll", service:_ragdoll(victim, attacker, now, 3, "Push"))
				local saved = victim.ragdoll
				check(label .. " preserves runner role and marks push separately", victim.role == "Runner" and saved.kind == "Push" and victim.player:GetAttribute("PCPushed") == true)
				check(label .. " three-second deadline", math.abs(saved.endsAt - now - 3) < 0.001)
				check(label .. " does not damage", victim.humanoid.Health == 100)
				check(label .. " cannot chain push or extend countdown", not service:_ragdoll(victim, attacker, now + 1, 3, "Push") and victim.ragdoll == saved and saved.endsAt == now + 3)
				service:_updateRagdoll(victim, now + 2.99)
				check(label .. " stays down for full duration", victim.ragdoll == saved)
				service:_updateRagdoll(victim, now + 3.01)
				check(label .. " gets up without becoming tagged", not victim.ragdoll and not victim.frozen and victim.role == "Runner" and victim.player:GetAttribute("PCPushed") == false)
				local leg = victim.character:FindFirstChild("Left Leg")
				local standingY = ground.Position.Y + ground.Size.Y * 0.5 + victim.humanoid.HipHeight + victim.root.Size.Y * 0.5 + (leg and leg.Size.Y or 0) + 0.1
				check(label .. " recovers above floor at correct avatar height", math.abs(victim.root.Position.Y - standingY) < 0.01)
				for joint, enabled in pairs(joints) do check(label .. " restores joint " .. joint.Name, joint.Enabled == enabled) end
				for socket, enabled in pairs(sockets) do check(label .. " restores socket " .. socket.Name, socket.Enabled == enabled) end
				for body, collide in pairs(collisions) do assert(body.CanCollide == collide, label .. " collision restore " .. body.Name) end
				check(label .. " restores body collisions and state", not victim.humanoid.PlatformStand and victim.humanoid.RequiresNeck)
				move(victim, origin + Vector3.new(0, 0, -4))
				check(label .. " second push starts", service:_ragdoll(victim, attacker, now, 3, "Push"))
				saved = victim.ragdoll
				attacker.batSwing = { character = attacker.character, round = service.currentRound, token = service.currentRound,
					crossing = service.crossingNumber, hitAt = now, endsAt = now + 0.38 }
				if kind == "TG" then
					check(label .. " pushed runner remains eligible for tag", service:_tagEligible(attacker, victim, now + 0.2))
					check(label .. " bat transfers tag while victim is pushed", service:_transfer(victim, now + 0.2))
					check(label .. " target becomes Tagger", victim.role == "Tagger" and service.tagger == victim)
				else
					local params = newPush(service, nil):_rayParameters(service)
					service:_resolveBatSwings(now + 0.2, params)
					check(label .. " bat catches pushed runner", victim.role == "Tagged")
				end
				check(label .. " bat reuses existing ragdoll without early recovery", victim.ragdoll == saved and saved.kind == "Bat" and saved.endsAt >= now + 3)
				check(label .. " push flag clears after tag", victim.player:GetAttribute("PCPushed") == false)
				check(label .. " later impact extends recovery", service:_ragdoll(victim, attacker, now + 2.9) and saved.endsAt >= now + 4.24)
				service:_updateRagdoll(victim, now + 3.1)
				check(label .. " old push timer cannot release bat ragdoll", victim.ragdoll == saved)
				service:_updateRagdoll(victim, now + 4.3)
				check(label .. " merged ragdoll restores at its later deadline", victim.ragdoll == nil and (kind ~= "BB" or victim.frozen))
				service:_restoreRagdoll(victim, true)
				victim.character:Destroy()
				attacker.character:Destroy()
				table.clear(service.records)
			end
		end
		local bb, tg = makeService("BB"), makeService("TG")
		local push = newPush(bb, tg)
		local actor = makeRecord(bb, "R6", origin)
		local target = makeRecord(bb, "R15", origin + Vector3.new(0, 0, -4))
		local now = workspace:GetServerTimeNow()
		check("active BB runner can push", push:_eligible(bb, actor, now))
		bb.phase = "Countdown" check("countdown cannot push", not push:_eligible(bb, actor, now)) bb.phase = "Crossing"
		bb.active = false check("lobby cannot push", not push:_eligible(bb, actor, now)) bb.active = true
		actor.departed = false check("runner must leave safe zone", not push:_eligible(bb, actor, now)) actor.departed = true
		move(actor, north.Position) check("safe-zone occupants cannot push", not push:_eligible(bb, actor, now)) move(actor, origin)
		actor.arrived = true check("arrived runners cannot push", not push:_eligible(bb, actor, now)) actor.arrived = false
		actor.role = "Tagged" check("tagged prisoners cannot push", not push:_eligible(bb, actor, now)) actor.role = "Runner"
		actor.frozen = true check("frozen actor cannot push", not push:_eligible(bb, actor, now)) actor.frozen = false
		actor.ragdoll = {} check("ragdolled actor cannot push", not push:_eligible(bb, actor, now)) actor.ragdoll = nil
		actor.player:SetAttribute("MDParticipating", true) check("another game's participant cannot push", not push:_eligible(bb, actor, now)) actor.player:SetAttribute("MDParticipating", false)
		local function request()
			local r = { service = bb, attacker = actor, character = actor.character, round = bb.currentRound, crossing = bb.crossingNumber }
			push.pending[actor.player] = r
			return push:_resolve(actor.player, r)
		end
		move(target, origin + Vector3.new(0, 0, 4)) check("behind actor misses", not request())
		move(target, origin + Vector3.new(0, 0, -7)) check("beyond reach misses", not request())
		move(target, origin + Vector3.new(0, 0, -4))
		local wall = part("Wall", origin + Vector3.new(0, 0, -2), Vector3.new(12, 12, 1))
		check("wall blocks push", not request()) wall:Destroy()
		local old = bb.currentRound
		local pending = { service = bb, attacker = actor, character = actor.character, round = old, crossing = bb.crossingNumber }
		push.pending[actor.player] = pending bb.currentRound = {}
		check("round changes cancel windup", not push:_resolve(actor.player, pending)) bb.currentRound = old
		pending = { service = bb, attacker = actor, character = actor.character, round = old, crossing = bb.crossingNumber - 1 }
		push.pending[actor.player] = pending
		check("crossing changes cancel windup", not push:_resolve(actor.player, pending))
		local second = makeRecord(bb, "R6", origin + Vector3.new(1, 0, -5))
		check("valid front target is pushed", request())
		check("only nearest target is affected", target.ragdoll ~= nil and second.ragdoll == nil)
		check("already pushed target cannot be selected again", not push:_eligible(bb, target, now))
		bb:_updateRagdoll(target, workspace:GetServerTimeNow() + 3.1)
		local tagActor = makeRecord(tg, "R6", origin)
		check("active Tag runner can push", push:_eligible(tg, tagActor, now))
		tagActor.protectedEndsAt = now + 1
		check("Tag protection blocks attacker and victim", not push:_eligible(tg, tagActor, now))
		tagActor.protectedEndsAt = 0
		check("forged player input rejected", not push:Request(actor.player))
		local detached = Instance.new("Folder")
		table.insert(temporaryPlayers, detached)
		check("disconnected instance rejected", not push:Request(detached))
		detached.Name = "_PushInputFixture"
		detached.Parent = game:GetService("Players")
		bb.records[actor.player] = nil
		actor.character.Name = "Character"
		actor.character.Parent = detached
		actor.player, actor.isBot = detached, false
		bb.records[detached] = actor
		check("client-supplied target payload rejected", not push:Request(detached, target.character))
		check("legitimate request accepted", push:Request(detached))
		check("animation begins on server confirmation", actor.character:GetAttribute("PCPushAt") ~= nil)
		check("six-second cooldown published", detached:GetAttribute("PCPushReadyAt") >= workspace:GetServerTimeNow() + 5.9)
		check("bat swing blocked during push animation", actor.batSwingReadyAt >= workspace:GetServerTimeNow() + 0.5)
		check("spam request rejected", not push:Request(detached))
		push.pending[detached] = nil
		push.requests[detached] = -math.huge
		check("cooldown still enforced after rate limit", not push:Request(detached))
		push.cooldowns[detached] = 0
		push.requests[detached] = -math.huge
		actor.batSwing = {}
		check("bat windup cannot overlap push", not push:Request(detached))
		actor.batSwing = nil
		check("Play remained stopped", not game:GetService("RunService"):IsRunning())
	end, debug.traceback)
	for _, push in ipairs(pushServices) do push:Stop() end
	for _, service in ipairs(services) do
		for _, record in pairs(service.records) do service:_restoreRagdoll(record, false) end
		service.state:Destroy()
	end
	for _, player in ipairs(temporaryPlayers) do player:Destroy() end
	world:Destroy()
	return { passed = ok, checksPassed = #checks, checks = checks, error = ok and nil or err, playStarted = false }
end

