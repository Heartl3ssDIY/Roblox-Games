return function()
	local staging = script.Parent
	local baseline = require(staging.Baseline)
	local candidate = require(staging.Candidate)
	local world = Instance.new("Folder")
	world.Name = "_MudGunPhysicsChecks20261008"
	world.Parent = workspace
	local checks = {}
	local function check(name, condition)
		assert(condition, name)
		table.insert(checks, name)
	end
	local function part(name, position, size)
		local object = Instance.new("Part")
		object.Name, object.Anchored, object.Position, object.Size = name, true, position, size
		object.Parent = world
		return object
	end
	local serial = 0
	local function makeRecord(service, rig, position, team)
		serial += 1
		local character = game.ServerStorage.WeaponRigFixtures[rig]:Clone()
		for _, object in character:GetDescendants() do
			if object:IsA("LuaSourceContainer") then object:Destroy() end
		end
		character.Parent = world
		local root = character.HumanoidRootPart
		character:PivotTo(CFrame.new(position) * root.CFrame:Inverse() * character:GetPivot())
		local attrs = {}
		local player = { Character = character, UserId = 9873000 + serial, Parent = game.Players }
		function player:GetAttribute(name) return attrs[name] end
		function player:SetAttribute(name, value) attrs[name] = value end
		local record = { player = player, character = character, root = root, humanoid = character.Humanoid,
			ready = true, participating = true, teamId = team, originalGroups = {}, requests = {},
			sprintMax = 10, sprintRemaining = 10, rescueProgress = 0, fireReadyAt = 0 }
		service.records[player] = record
		return record
	end
	local function equip(service, record, kind)
		for _, tool in record.character:GetChildren() do if tool:IsA("Tool") then tool:Destroy() end end
		local tool = game.ReplicatedStorage.MudAssets[kind .. "Gun"]:Clone()
		tool:SetAttribute("MDManaged", true)
		tool:SetAttribute("MDRound", service.roundNumber)
		tool:SetAttribute("MDOwnerUserId", record.player.UserId)
		local offset = CFrame.new(record.root.Position + Vector3.new(1, 1, -1))
		for _, object in tool:GetDescendants() do if object:IsA("BasePart") then object.CFrame = offset * object.CFrame end end
		tool.Parent = record.character
		return tool
	end
	local function cameraAim(record, target, distance)
		local cameraOrigin = record.character.Head.Position + Vector3.new(0, 0, distance)
		return { cameraOrigin = cameraOrigin, cameraDirection = (target - cameraOrigin).Unit }
	end
	local function clearEffects(service)
		for _, shot in service.projectiles do shot.part:Destroy() end
		table.clear(service.projectiles)
	end
	local ok, result = xpcall(function()
		for rigIndex, rig in ipairs({ "R6", "R15" }) do
			local origin = Vector3.new(-16000 - rigIndex * 300, 1000, 0)
			local bounds = part(rig .. "Bounds", origin, Vector3.new(120, 40, 120))
			bounds.CanCollide, bounds.CanQuery, bounds.Transparency = false, false, 1
			local arena = Instance.new("Folder") arena.Parent = world
			local state = Instance.new("Folder") state.Parent = staging
			local service = setmetatable({ arena = arena, gameplay = arena, bounds = bounds, state = state,
				records = {}, projectiles = {}, active = true, phase = "Playing", teamCount = 2,
				endsAt = workspace:GetServerTimeNow() + 1000, roundNumber = 1, currentRound = {},
				teamColors = { "Red", "Blue" }, eliminatedTeams = {}, originalTeamSizes = { 2, 2 } }, candidate)
			local shooter = makeRecord(service, rig, origin, 1)
			local opponent = makeRecord(service, rig, origin + Vector3.new(0, 0, -18), 2)
			local teammate = makeRecord(service, rig, origin + Vector3.new(12, 0, -18), 1)
			makeRecord(service, rig, origin + Vector3.new(30, 0, -18), 2)
			local mud = equip(service, shooter, "Mud")
			local torso = opponent.character:FindFirstChild("UpperTorso") or opponent.character.Torso
			local aim = cameraAim(shooter, torso.Position, 25)
			local now = workspace:GetServerTimeNow()
			setmetatable(service, baseline)
			check(rig .. " baseline rejects allowed 25-stud camera", service:_resolveAim(shooter, "Mud", aim) == nil)
			check(rig .. " baseline rejects firing from allowed zoom", not service:_fire(shooter, aim, now))
			check(rig .. " baseline close camera works", service:_resolveAim(shooter, "Mud", cameraAim(shooter, torso.Position, 5)) ~= nil)
			setmetatable(service, candidate)
			check(rig .. " allows 25-stud camera aim", service:_resolveAim(shooter, "Mud", aim) ~= nil)
			check(rig .. " fire succeeds", service:_fire(shooter, aim, now))
			check(rig .. " creates one visible mud projectile", #service.projectiles == 1 and service.projectiles[1].part.Parent ~= nil)
			check(rig .. " cooldown rejects duplicate shot", not service:_fire(shooter, aim, now + 0.1) and #service.projectiles == 1)
			for _ = 1, 10 do service:_tickProjectiles(0.05) end
			check(rig .. " mud projectile hits the aimed opponent", opponent.muddy == true and opponent.frozen == true)
			check(rig .. " hit keeps teams active", service.pendingWinners == nil and opponent.eliminated ~= true)
			check(rig .. " hit removes projectile", #service.projectiles == 0)
			check(rig .. " refuses far camera spoof", service:_resolveAim(shooter, "Mud", cameraAim(shooter, torso.Position, 100)) == nil)
			check(rig .. " refuses nonfinite camera origin", service:_resolveAim(shooter, "Mud", { cameraOrigin = Vector3.new(math.huge, 0, 0), cameraDirection = Vector3.new(0, 0, -1) }) == nil)
			check(rig .. " refuses invalid direction", service:_resolveAim(shooter, "Mud", { cameraOrigin = shooter.character.Head.Position, cameraDirection = Vector3.zero }) == nil)
			mud:SetAttribute("MDOwnerUserId", shooter.player.UserId + 1)
			check(rig .. " refuses foreign-owned gun", service:_resolveAim(shooter, "Mud", aim) == nil)
			mud:SetAttribute("MDOwnerUserId", shooter.player.UserId)
			mud:SetAttribute("MDRound", 0)
			check(rig .. " refuses gun from old round", service:_resolveAim(shooter, "Mud", aim) == nil)
			mud:SetAttribute("MDRound", 1)
			local cameraWall = part("CameraWall", shooter.character.Head.Position + Vector3.new(0, 0, 12), Vector3.new(15, 15, 1))
			check(rig .. " refuses camera through wall", service:_resolveAim(shooter, "Mud", aim) == nil)
			cameraWall:Destroy()
			local muzzleWall = part("MuzzleWall", shooter.root.Position + Vector3.new(0.5, 1, -1.8), Vector3.new(0.4, 4, 3))
			check(rig .. " refuses muzzle through wall", service:_resolveAim(shooter, "Mud", aim) == nil)
			muzzleWall:Destroy()
			local originalMuzzle = mud.Handle.MuzzleAttachment.Position
			mud.Handle.MuzzleAttachment.Position = Vector3.new(0, 0, -40)
			check(rig .. " refuses displaced muzzle", service:_resolveAim(shooter, "Mud", aim) == nil)
			mud.Handle.MuzzleAttachment.Position = originalMuzzle
			local heat = equip(service, shooter, "Heat")
			check(rig .. " wrong equipped weapon cannot fire mud", not service:_fire(shooter, aim, now + 1))
			teammate.muddy = true
			service:_freeze(teammate, true)
			local teammateTorso = teammate.character:FindFirstChild("UpperTorso") or teammate.character.Torso
			local heatAim = cameraAim(shooter, teammateTorso.Position, 25)
			check(rig .. " heat activation from allowed zoom", service:_action(shooter, "Heat", true, heatAim).ok)
			check(rig .. " heat aims at muddy teammate", service:_heatTarget(shooter, now) == teammate)
			service:_tickHeat(now)
			check(rig .. " begins heat progress", shooter.heatTarget == teammate and shooter.heatBeam ~= nil)
			shooter.heatLeaseEndsAt = now + 10
			service:_tickHeat(now + 4.99)
			check(rig .. " rescue takes the full five seconds", teammate.muddy == true and teammate.rescueProgress > 4.9)
			service:_tickHeat(now + 5.01)
			check(rig .. " heat rescues teammate after five seconds", teammate.muddy == false and teammate.frozen == false and shooter.heatBeam == nil)
			shooter.heatDirection, shooter.heatAim, shooter.heatHeld, shooter.heatLeaseEndsAt = heatAim.cameraDirection, heatAim, true, now + 10
			check(rig .. " heat cannot freeze or rescue a free teammate", service:_heatTarget(shooter, now + 6) == nil)
			shooter.heatAim = cameraAim(shooter, torso.Position, 25)
			check(rig .. " heat cannot rescue opponents", service:_heatTarget(shooter, now + 6) == nil)
			clearEffects(service)
			if service.effects then service.effects:Destroy() end
			for _, record in service.records do record.character:Destroy() end
			arena:Destroy() bounds:Destroy() state:Destroy()
		end
		return { checks = #checks, details = checks, rigs = { "R6", "R15" }, serverCameraAllowance = 32, editOnly = true }
	end, debug.traceback)
	world:Destroy()
	assert(ok, result)
	return result
end
