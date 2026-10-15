local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local module = ServerScriptService.StuckInTheMudService:Clone()
module.Name = "MudFixtureModule"
module.Parent = ServerScriptService
local folder = Instance.new("Folder")
folder.Name = "MudFixtures"
folder.Parent = workspace
local controller
local checks, authored = {}, {}
local function expect(value, name)
	assert(value, name)
	table.insert(checks, name)
end
local function near(a, b) return math.abs(a - b) < 0.002 end
local function tune(name, value)
	if not authored[name] then authored[name] = { value = controller.arena:GetAttribute(name) } end
	controller.arena:SetAttribute(name, value)
end
local ok, failure = xpcall(function()
	local Service = require(module)
	local assignments, count = Service.TeamAssignments(24, 2, 12)
	local sizes = {}
	for _, id in ipairs(assignments) do sizes[id] = (sizes[id] or 0) + 1 end
	expect(count == 2 and sizes[1] == 12 and sizes[2] == 12, "24 players form two balanced teams")
	assignments, count = Service.TeamAssignments(23, 2, 12)
	sizes = {} for _, id in ipairs(assignments) do sizes[id] = (sizes[id] or 0) + 1 end
	expect(count == 2 and sizes[1] == 12 and sizes[2] == 11, "Odd lobby is balanced by one player")
	assignments, count = Service.TeamAssignments(24, 4, 6)
	sizes = {} for _, id in ipairs(assignments) do sizes[id] = (sizes[id] or 0) + 1 end
	expect(count == 4 and sizes[1] == 6 and sizes[4] == 6, "Four authored teams are supported")
	assignments, count = Service.TeamAssignments(24, 2, 2)
	sizes = {} for _, id in ipairs(assignments) do sizes[id] = (sizes[id] or 0) + 1 end
	expect(count == 12 and sizes[1] == 2 and sizes[12] == 2, "Pair mode caps every team at two")
	assignments, count = Service.TeamAssignments(1, 2, 12)
	expect(count == 0 and #assignments == 0, "Single-player normal round cannot assign teams")
	assignments, count = Service.TeamAssignments(3, 12, 2)
	expect(count == 3 and #assignments == 3, "Requested team count cannot exceed roster")

	local state = Instance.new("Folder") state.Parent = folder
	controller = Service.new(workspace["Stuck in the Mud"], state)
	local provider = PhysicsService
	if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end
	provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	controller.running, controller.active, controller.phase, controller.mode = true, true, "Playing", "Round"
	controller.currentRound, controller.roundNumber, controller.teamCount = {}, 71, 2
	local now = workspace:GetServerTimeNow()
	controller.endsAt = now + 1000
	local center = Vector3.new(controller.bounds.Position.X, controller.spawnPads[1].Position.Y, controller.bounds.Position.Z)
	local function actor(name, team, offset, id)
		local values = {}
		local backpack = Instance.new("Folder") backpack.Name = name .. "Backpack" backpack.Parent = folder
		local player = { DisplayName = name, UserId = id, Parent = Players }
		function player:GetAttribute(key) return values[key] end
		function player:SetAttribute(key, value) values[key] = value end
		function player:FindFirstChild(key) return key == "Backpack" and backpack or nil end
		local character = Instance.new("Model") character.Name = name character.Parent = folder
		local root = Instance.new("Part") root.Name = "HumanoidRootPart" root.Size = Vector3.new(2, 2, 1) root.Position = center + offset root.CanCollide, root.CanQuery = false, false root.Parent = character character.PrimaryPart = root
		local body = Instance.new("Part") body.Name = "Torso" body.Size = Vector3.new(2, 2, 1) body.Position = root.Position body.Anchored, body.CanCollide = true, false body.Parent = character
		local head = Instance.new("Part") head.Name = "Head" head.Size = Vector3.new(2, 1, 1) head.Position = root.Position + Vector3.new(0, 1.5, 0) head.Anchored, head.CanCollide = true, false head.Parent = character
		local humanoid = { Parent = character, Health = 100, WalkSpeed = 20, JumpPower = 54, JumpHeight = 8, AutoRotate = true, FloorMaterial = Enum.Material.Grass }
		function humanoid:Move() end
		function humanoid:MoveTo(point) self.lastMoveTo = point end
		player.Character = character
		local record = controller:_record(player, true)
		record.character, record.root, record.humanoid, record.ready, record.participating, record.teamId = character, root, humanoid, true, true, team
		record.sprintMax, record.sprintRemaining = 10, 10
		record.nextBotMoveAt, record.nextPathAt, record.stuckSince = now + 1000, 0, 0
		controller:_role(record) controller:_freeze(record, false)
		return record
	end
	local shooter = actor("Shooter", 1, Vector3.zero, 1001)
	local victim = actor("Teammate", 1, Vector3.new(14, 0, 0), 1002)
	local saver = actor("SecondSaver", 1, Vector3.new(2, 0, 3), 1003)
	local rival = actor("Rival", 2, Vector3.new(60, 0, 0), 1004)
	local rival2 = actor("SecondRival", 2, Vector3.new(-60, 0, 0), 1005)
	controller.originalTeamSizes = { 3, 2 }
	local actors = { shooter, victim, saver, rival, rival2 }
	local function place(record, offset)
		controller:_teleport(record, CFrame.new(center + offset))
	end
	local function free(record)
		record.muddy, record.eliminated, record.rescueProgress = false, false, 0
		controller:_freeze(record, false) controller:_role(record)
	end
	local function reset()
		controller.phase, controller.endsAt = "Playing", now + 1000
		controller.eliminatedTeams, controller.pendingWinners = {}, nil
		for _, record in ipairs(actors) do record.participating = true controller:_clearHeat(record, true) free(record) end
		place(shooter, Vector3.zero) place(victim, Vector3.new(14, 0, 0)) place(saver, Vector3.new(2, 0, 3)) place(rival, Vector3.new(100, 0, 100)) place(rival2, Vector3.new(-100, 0, 100))
		for _, shot in ipairs(controller.projectiles) do shot.part:Destroy() end table.clear(controller.projectiles)
	end
	local function heat(record, target, timestamp)
		local head = record.character.Head
		record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = true, (target.root.Position - head.Position).Unit, timestamp + 1000
	end
	local function wall(offset, size)
		local part = Instance.new("Part") part.Name = "FixtureWall" part.Size = size or Vector3.new(1, 10, 8) part.Position = center + offset part.Anchored = true part.Parent = folder return part
	end
	local function weapon(record, name, kind)
		local tool = Instance.new("Tool") tool.Name = name tool:SetAttribute("MDManaged", true) tool:SetAttribute("MDRound", controller.roundNumber) tool:SetAttribute("GunKind", kind)
		local handle = Instance.new("Part") handle.Name = "Handle" handle.Size = Vector3.one handle.CFrame = record.root.CFrame handle.Anchored, handle.CanCollide, handle.CanQuery = true, false, false handle.Parent = tool
		local muzzle = Instance.new("Attachment") muzzle.Name = "MuzzleAttachment" muzzle.Position = Vector3.new(1, 1, 0) muzzle.Parent = handle tool.Parent = record.character
		return tool, muzzle
	end

	shooter.player:SetAttribute("MDColorPreference", "Blue") rival.player:SetAttribute("MDColorPreference", "Red")
	controller:_chooseTeamColors()
	for _, record in ipairs(actors) do controller:_role(record) end
	expect(shooter.player:GetAttribute("MDTeamColorName") == "Blue" and rival.player:GetAttribute("MDTeamColorName") == "Red", "Color preferences choose opposing unique colors")
	expect(typeof(shooter.player:GetAttribute("MDTeamColor")) == "Color3" and shooter.player:GetAttribute("MDTeamName") == "Blue Team", "HUD receives actual team color and name")
	expect(not controller:Action(shooter.player, "Sprint", true).ok, "Public action refuses a table posing as Player")
	controller.phase = "Countdown"
	expect(controller:_action(shooter, "ChooseColor", "Green").ok and controller.teamColors[1] == "Green", "Countdown changes own team to unused color")
	expect(victim.player:GetAttribute("MDTeamColorName") == "Green", "Countdown team color updates every teammate")
	shooter.requests.ChooseColor = nil
	expect(controller:_action(shooter, "ChooseColor", "Red").ok and controller.teamColors[1] == "Green" and shooter.player:GetAttribute("MDColorPreference") == "Red", "Occupied color saves preference without merging team colors")
	shooter.requests.ChooseColor = nil controller.phase = "Playing"
	expect(controller:_action(shooter, "ChooseColor", "Black").ok and controller.teamColors[1] == "Green", "Playing color choice applies next round")
	expect(not controller:_action(shooter, "ChooseColor", "Rainbow").ok, "Unsupported color preference rejected")
	controller.teamCount = 12
	controller:_chooseTeamColors()
	local distinct = {} for _, name in pairs(controller.teamColors) do distinct[name] = true end
	local colorCount = 0 for _ in pairs(distinct) do colorCount += 1 end
	expect(colorCount == 12, "Twelve pair teams all have unique color names")
	controller.teamCount = 2 controller:_chooseTeamColors()
	local active = controller:_teams(false)
	local summary = HttpService:JSONDecode(controller.state:GetAttribute("TeamSummaryJSON"))
	expect(#active == 2 and summary[1].free == 3 and summary[2].total == 2 and summary[1].originalTotal == 3, "Team JSON includes connected counts and original roster")
	local group1, group2 = controller:_spawn(1, 1).Position, controller:_spawn(1, 2).Position
	expect((group1 - group2).Magnitude > controller.bounds.Size.X * 0.5, "Two teams spawn in opposite arena groups")
	local selectBefore, beginBefore = controller._readyPlayers, controller._begin
	local weaponsBefore = controller._weaponsReady
	local batch, selectedBatch = {}, nil
	for index = 1, 24 do batch[index] = { UserId = index } end
	controller._readyPlayers = function() return table.clone(batch) end
	controller._begin = function(_, selected) selectedBatch = selected return true end
	controller._weaponsReady = function() return true end
	controller.active = false tune("MinimumPlayers", 2) tune("MaxPlayers", 4)
	expect(controller:StartRound() and #selectedBatch == 4, "MaxPlayers4 selects exactly a 2v2-sized roster")
	tune("MaxPlayers", 100)
	expect(controller:StartRound() and #selectedBatch == 24, "MaxPlayers cannot exceed24")
	tune("MaxPlayers", 1)
	expect(controller:StartRound() and #selectedBatch == 2, "MaxPlayers cannot select fewer than two")
	controller._readyPlayers, controller._begin, controller.active = selectBefore, beginBefore, true
	controller._weaponsReady = weaponsBefore

	reset()
	expect(not controller:_stick(victim, shooter), "Friendly mud cannot stick teammate")
	expect(controller:_stick(victim, rival) and victim.muddy and victim.frozen, "Enemy impact immobilizes victim")
	expect(victim.humanoid.WalkSpeed == 0 and victim.humanoid.JumpPower == 0 and not victim.humanoid.AutoRotate, "Muddy victim cannot walk jump or rotate")
	expect(victim.player:GetAttribute("MDMuddy") == true, "Muddy state publishes immediately")
	expect(victim.character.MDOutline.FillTransparency == 0.55 and victim.character.MDOutline.OutlineColor == victim.player:GetAttribute("MDTeamColor"), "Mud tint remains distinguishable without erasing team outline")
	local coating = victim.character:FindFirstChild("MDMudCoating")
	expect(coating and #coating:GetChildren() >= 2, "Muddy character has visible welded body patch and face mask")
	local faceMask = coating:FindFirstChild("MudFaceMask")
	expect(faceMask and faceMask.Massless and not faceMask.CanCollide and not faceMask.CanTouch and not faceMask.CanQuery and faceMask.MudWeld.Part0 == victim.character.Head, "Mud face mask follows Head without affecting collisions or hit rays")
	expect(not controller:_canAct(victim, now), "Muddy player cannot shoot heat or sprint")
	heat(shooter, victim, now)
	controller:_tickHeat(now) controller:_tickHeat(now + 4.99)
	expect(victim.muddy and near(victim.rescueProgress, 4.99), "Continuous rescue does not finish before five seconds")
	expect(near(victim.player:GetAttribute("MDRescueProgress"), 4.99) and near(shooter.player:GetAttribute("MDHeatProgress"), 4.99), "Victim and rescuer UI progress publish seconds rather than fraction")
	controller:_tickHeat(now + 5)
	expect(not victim.muddy and not victim.frozen and victim.humanoid.WalkSpeed == 16 and victim.humanoid.JumpPower == 54, "Five uninterrupted seconds rescue and restore jump settings")
	expect(shooter.heatTarget == nil and shooter.heatBeam == nil and victim.rescueProgress == 0 and shooter.player:GetAttribute("MDHeatProgress") == 0, "Successful rescue clears beam victim progress and rescuer seconds")
	expect(victim.character:FindFirstChild("MDMudCoating") == nil, "Rescue removes every welded mud patch")

	reset() controller:_stick(victim, rival) heat(shooter, victim, now)
	controller:_tickHeat(now) controller:_tickHeat(now + 2)
	controller:_action(shooter, "Heat", false)
	expect(victim.muddy and victim.rescueProgress == 0 and not shooter.heatHeld and shooter.player:GetAttribute("MDHeatProgress") == 0 and shooter.player:GetAttribute("MDHeatTargetUserId") == 0, "Release interrupts rescue and clears both players' progress and target")
	heat(shooter, victim, now + 3) controller:_tickHeat(now + 3) controller:_tickHeat(now + 6)
	expect(victim.muddy and near(victim.rescueProgress, 3), "Re-press starts a fresh continuous five seconds")
	shooter.heatLeaseEndsAt = now + 6.1 controller:_tickHeat(now + 6.2)
	expect(victim.muddy and victim.rescueProgress == 0 and shooter.heatTarget == nil, "Expired heat heartbeat lease interrupts channel")

	reset() controller:_stick(victim, rival) heat(shooter, victim, now)
	controller:_tickHeat(now) controller:_tickHeat(now + 2)
	local obstruction = wall(Vector3.new(7, 1, 0))
	controller:_tickHeat(now + 3)
	expect(victim.muddy and victim.rescueProgress == 0 and shooter.heatTarget == nil, "Cover interrupts rescue line of sight")
	obstruction:Destroy() controller:_tickHeat(now + 4) controller:_tickHeat(now + 7)
	expect(victim.muddy and near(victim.rescueProgress, 3), "Restored sight begins a new rescue timer")
	place(victim, Vector3.new(40, 0, 0)) controller:_tickHeat(now + 8)
	expect(victim.muddy and victim.rescueProgress == 0, "Out-of-range target interrupts rescue")

	reset() controller:_stick(victim, rival) heat(shooter, victim, now)
	controller:_tickHeat(now) controller:_tickHeat(now + 2)
	controller:_stick(victim, rival2)
	expect(victim.muddy and victim.rescueProgress == 0 and shooter.heatTarget == nil, "Fresh enemy impact resets a victim's active rescue")
	controller:_tickHeat(now + 2.1) controller:_tickHeat(now + 5.1)
	expect(victim.muddy and near(victim.rescueProgress, 3), "Hit rescue cannot retain pre-hit progress")
	controller:_stick(shooter, rival)
	expect(not shooter.heatHeld and shooter.heatTarget == nil and not controller:_canAct(shooter, now), "Hitting rescuer cancels held heat immediately")
	expect(not controller:_action(shooter, "Fire", Vector3.xAxis).ok and not controller:_action(shooter, "Sprint", true).ok, "Frozen action requests are rejected")
	expect(controller:_action(shooter, "Heat", false).ok and controller:_action(shooter, "Sprint", false).ok, "Release remains safe while frozen")

	reset() controller:_stick(victim, rival) heat(shooter, victim, now)
	controller:_tickHeat(now) heat(saver, victim, now + 2)
	controller:_tickHeat(now + 2) controller:_tickHeat(now + 4.9)
	expect(victim.muddy and near(victim.rescueProgress, 4.9), "Two rescuers do not add elapsed times for a faster rescue")
	saver.heatLeaseEndsAt = now + 4.95 controller:_tickHeat(now + 4.96)
	expect(near(victim.rescueProgress, 4.96), "Invalid second channel does not erase valid first-channel progress")
	controller:_tickHeat(now + 5)
	expect(not victim.muddy, "First valid channel still completes after five seconds")
	reset() place(rival, Vector3.new(14, 0, 0)) place(victim, Vector3.new(100, 0, 100)) controller:_stick(rival, shooter) heat(shooter, rival, now)
	controller:_tickHeat(now) controller:_tickHeat(now + 10)
	expect(rival.muddy and shooter.heatTarget == nil, "Heat cannot rescue an opposing player")

	reset() shooter.isBot = false
	local heatTool, muzzle = weapon(shooter, "HeatGun", "Heat")
	local acceptsEnabled = controller:_equipped(shooter, "Heat") == heatTool and controller:_equipped(shooter, "Mud") == nil
	heatTool.Enabled = false
	local rejectsDisabled = controller:_equipped(shooter, "Heat") == nil
	heatTool.Enabled = true
	expect(acceptsEnabled and rejectsDisabled, "Heat requires actual enabled equipped HeatGun")
	heatTool.Name = "FakeHeatGun"
	expect(controller:_equipped(shooter, "Heat") == nil, "GunKind alone cannot impersonate named tool")
	heatTool.Name = "HeatGun" heatTool:SetAttribute("MDRound", 70)
	expect(controller:_equipped(shooter, "Heat") == nil, "Tool from previous round cannot be used")
	heatTool:SetAttribute("MDRound", 71) muzzle.Position = Vector3.new(0, 1, -20)
	expect(controller:_origin(shooter, "Heat", Vector3.xAxis) == nil, "Detached muzzle beyond body reach rejected")
	muzzle.Position = Vector3.new(1, 1, 0)
	controller:_stick(victim, rival) heat(shooter, victim, now) controller:_tickHeat(now) controller:_tickHeat(now + 2)
	expect(near(victim.rescueProgress, 2), "Equipped valid HeatGun starts real rescue channel")
	heatTool.Parent = shooter.player:FindFirstChild("Backpack") controller:_tickHeat(now + 3)
	expect(victim.muddy and victim.rescueProgress == 0 and shooter.heatTarget == nil, "Unequipping HeatGun interrupts rescue")
	heatTool:Destroy() shooter.isBot = true

	reset() place(victim, Vector3.new(100, 0, -100)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(60, 0, 0))
	shooter.fireReadyAt = 0
	expect(controller:_fire(shooter, Vector3.xAxis, now), "Valid mud shot creates projectile")
	expect(#controller.projectiles == 1 and not rival.muddy, "Firing does not precompute a victim impact")
	expect(not controller:_fire(shooter, Vector3.xAxis, now + 0.1), "Mud cooldown rejects rapid second shot")
	controller:_tickProjectiles(0.1)
	expect(not rival.muddy and #controller.projectiles == 1, "Short travel time leaves distant victim free")
	for _ = 1, 5 do controller:_tickProjectiles(0.1) end
	expect(rival.muddy and #controller.projectiles == 0, "Swept projectile hits enemy at arrival and is consumed")

	reset() place(victim, Vector3.new(100, 0, -100)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(60, 0, 0))
	shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now)
	controller:_tickProjectiles(0.1) place(rival, Vector3.new(60, 9, 0))
	for _ = 1, 6 do controller:_tickProjectiles(0.1) end
	expect(not rival.muddy, "Target jumping above incoming mud avoids the shot")
	reset() place(victim, Vector3.new(100, 0, -100)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(60, 0, 10))
	shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now) controller:_tickProjectiles(0.1) place(rival, Vector3.new(60, 0, 0))
	for _ = 1, 5 do controller:_tickProjectiles(0.1) end
	expect(rival.muddy, "Player entering the shot later is evaluated at impact")
	reset() place(victim, Vector3.new(100, 0, -100)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(60, 0, 0))
	obstruction = wall(Vector3.new(30, 1, 0)) shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now)
	for _ = 1, 6 do controller:_tickProjectiles(0.1) end
	expect(not rival.muddy and #controller.projectiles == 0, "Solid cover consumes mud before enemy impact")
	obstruction:Destroy()
	reset() place(victim, Vector3.new(30, 0, 0)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(60, 0, 0))
	shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now)
	for _ = 1, 6 do controller:_tickProjectiles(0.1) end
	expect(not victim.muddy and not rival.muddy and #controller.projectiles == 0, "Friendly body blocks mud without friendly stick")
	reset() place(victim, Vector3.new(100, 0, -100)) place(saver, Vector3.new(-100, 0, -100)) place(rival, Vector3.new(150, 0, 0))
	shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now)
	for _ = 1, 13 do controller:_tickProjectiles(0.1) end
	expect(not rival.muddy and #controller.projectiles == 0, "Projectile expires at authored range")
	shooter.fireReadyAt = 0 controller:_fire(shooter, Vector3.xAxis, now) local oldToken = controller.currentRound controller.currentRound = {}
	controller:_tickProjectiles(0.1)
	expect(#controller.projectiles == 0, "Projectile from old token cannot affect a later round")
	controller.currentRound = oldToken

	reset()
	shooter.participating = false
	controller:_restore(shooter)
	shooter.humanoid.WalkSpeed, shooter.humanoid.JumpPower, shooter.humanoid.JumpHeight, shooter.humanoid.AutoRotate = 48, 72, 10, false
	controller:_action(shooter, "Sprint", false) controller:_movement(shooter)
	expect(shooter.humanoid.WalkSpeed == 48 and shooter.humanoid.JumpPower == 72 and shooter.humanoid.JumpHeight == 10 and not shooter.humanoid.AutoRotate, "Inactive Mud release preserves Tag BB or lobby movement")
	expect(shooter.originalMovement == nil, "Inactive Mud release does not capture foreign movement settings")
	shooter.humanoid.WalkSpeed, shooter.humanoid.JumpPower, shooter.humanoid.JumpHeight, shooter.humanoid.AutoRotate = 20, 54, 8, true
	shooter.participating = true controller:_movement(shooter)
	expect(not controller:_action(shooter, "Fire", Vector3.zero).ok, "Zero aim vector rejected")
	shooter.requests.Fire = nil
	expect(not controller:_action(shooter, "Fire", Vector3.new(math.huge, 0, 0)).ok, "Infinite aim vector rejected")
	shooter.requests.Fire = nil
	expect(not controller:_action(shooter, "Fire", Vector3.new(0 / 0, 0, 0)).ok, "NaN aim vector rejected")
	expect(not controller:_action(shooter, "Sprint", 1).ok, "Numeric sprint flag rejected")
	expect(not controller:_action(shooter, "Rescue", victim.player).ok, "Client cannot submit a target rescue action")
	shooter.requests.Sprint = nil
	expect(controller:_action(shooter, "Sprint", true).ok and not controller:_action(shooter, "Sprint", true).ok, "Sprint hold is accepted with request rate limit")
	shooter.sprintLeaseEndsAt = now + 1000 shooter.sprintRemaining = 8 shooter.root.AssemblyLinearVelocity = Vector3.zero
	controller:_tickSprint(shooter, 1.5, now)
	expect(near(shooter.sprintRemaining, 9) and not shooter.sprinting and shooter.humanoid.WalkSpeed == 16, "Idle while holding refills stamina at base speed")
	shooter.root.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
	controller:_tickSprint(shooter, 1, now + 1)
	expect(near(shooter.sprintRemaining, 8) and shooter.sprinting and shooter.humanoid.WalkSpeed == 40, "Moving sprint drains one second and applies 2.5 speed")
	shooter.sprintRemaining = 0.1 controller:_tickSprint(shooter, 0.1, now + 2)
	expect(shooter.sprintRemaining == 0 and shooter.sprintExhausted and shooter.humanoid.WalkSpeed == 16, "Empty stamina locks sprint and restores base speed")
	controller:_tickSprint(shooter, 7.5, now + 9.5)
	expect(near(shooter.sprintRemaining, 5) and shooter.sprintExhausted and not shooter.sprinting, "Held exhausted sprint refills half in 7.5 seconds")
	controller:_tickSprint(shooter, 7.5, now + 17)
	expect(near(shooter.sprintRemaining, 10) and not shooter.sprintExhausted, "Full 15-second refill unlocks exhausted sprint")
	controller:_tickSprint(shooter, 0.1, now + 17.1)
	expect(shooter.sprinting and near(shooter.sprintRemaining, 9.9), "Continuous valid hold automatically resumes at full refill")
	controller:_action(shooter, "Sprint", false) controller:_tickSprint(shooter, 3, now + 20)
	expect(near(shooter.sprintRemaining, 10) and not shooter.sprinting and shooter.humanoid.WalkSpeed == 16, "Release starts refill and clears speed immediately")
	shooter.sprintHeld, shooter.sprintLeaseEndsAt = true, now + 20.1 controller:_tickSprint(shooter, 0.1, now + 20.2)
	expect(not shooter.sprintHeld and not shooter.sprinting, "Expired hold lease cannot leave sprint stuck")
	shooter.sprintHeld, shooter.sprintLeaseEndsAt, shooter.sprintRemaining = true, now + 1000, 6
	controller:_stick(shooter, rival) controller:_tickSprint(shooter, 1.5, now + 21)
	expect(not shooter.sprintHeld and not shooter.sprinting and near(shooter.sprintRemaining, 7) and shooter.humanoid.WalkSpeed == 0, "Mud clears sprint hold while stamina safely refills")
	free(shooter) tune("SprintMultiplier", 3)
	shooter.sprintHeld, shooter.sprintLeaseEndsAt = true, now + 1000 controller:_tickSprint(shooter, 0.1, now + 22)
	expect(shooter.humanoid.WalkSpeed == 48, "Authored sprint multiplier changes actual moving speed")
	tune("SprintMultiplier", 2.5)

	reset() controller:_stick(victim, rival) controller:_stick(shooter, rival)
	expect(not controller.eliminatedTeams[1], "One free teammate keeps team active")
	controller:_stick(saver, rival)
	expect(controller.eliminatedTeams[1] and shooter.eliminated and victim.eliminated and saver.eliminated, "All muddy members eliminate their team together")
	expect(controller.pendingWinners and #controller.pendingWinners == 1 and controller.pendingWinners[1] == 2 and rival.frozen and rival2.frozen, "Last free team is latched and all players freeze immediately")
	expect(not controller:_stick(rival, shooter) and not rival.muddy and not controller:_fire(rival, Vector3.xAxis, now), "Later same-tick damage cannot eliminate the latched winning team")
	heat(shooter, victim, now) controller:_tickHeat(now + 20)
	expect(victim.muddy and victim.eliminated, "Eliminated team cannot revive itself")
	active = controller:_teams(true)
	expect(#active == 1 and active[1] == 2, "Last surviving team is identified immediately")
	reset() shooter.participating, victim.participating, saver.participating = false, false, false
	active = controller:_teams(true)
	expect(controller.eliminatedTeams[1] and #active == 1 and active[1] == 2, "Empty disconnected team is eliminated")
	reset() controller:_stick(victim, rival) controller:_stick(saver, rival) controller:_stick(rival2, shooter)
	controller.originalTeamSizes = { 3, 2 }
	local winners = controller:_timeoutWinners()
	expect(#winners == 1 and winners[1] == 2, "Timeout compares free-member proportion against original sizes")
	controller.originalTeamSizes = { 4, 2 } free(victim)
	winners = controller:_timeoutWinners()
	expect(#winners == 2 and winners[1] == 1 and winners[2] == 2, "Equal proportions share win despite different original roster sizes")
	victim.participating = false winners = controller:_timeoutWinners()
	expect(#winners == 1 and winners[1] == 2 and controller.originalTeamSizes[1] == 4, "Leaving does not shrink timeout denominator or improve score")

	reset()
	local botPlayer = controller:_newBot(7, "Runner")
	local bot = controller.records[botPlayer]
	bot.participating, bot.teamId, bot.sprintMax, bot.sprintRemaining = true, 1, 10, 10
	controller:_teleport(bot, CFrame.new(center + Vector3.new(0, 0, 30))) controller:_freeze(bot, false) controller:_role(bot)
	controller:_stick(bot, rival)
	local oldCharacter = bot.character oldCharacter:Destroy() controller:_respawnBot(bot)
	expect(bot.character ~= oldCharacter and bot.ready and bot.muddy and bot.frozen and bot.humanoid.WalkSpeed == 0, "Practice bot respawn keeps mud and immobilization")
	expect(bot.root:GetNetworkOwner() == nil, "Practice bot physics remain server-owned")
	bot.participating = false
	controller.phase = "Countdown" shooter.muddy = true
	local replacement = Instance.new("Model") replacement.Name = "ResetCharacter" replacement.Parent = folder
	local replacementRoot = Instance.new("Part") replacementRoot.Name = "HumanoidRootPart" replacementRoot.Position = center replacementRoot.Parent = replacement replacement.PrimaryPart = replacementRoot
	local replacementHumanoid = Instance.new("Humanoid") replacementHumanoid.Parent = replacement
	shooter.player.Character = replacement
	controller:_setupCharacter(shooter, replacement)
	expect(shooter.character == replacement and shooter.muddy and shooter.frozen and replacementHumanoid.WalkSpeed == 0, "Player reset reattaches new character without escaping mud")
	controller.phase = "Playing" replacementHumanoid.Health = 0
	expect(shooter.muddy, "Player death retains mud instead of restoring freedom")
	shooter.participating = false
	controller.currentRound = {}
	local stoppedToken = {} controller:_cleanup(stoppedToken)
	expect(controller.active and controller.currentRound ~= nil, "Cleanup from stale token cannot stop new round")

	controller.phase = "Playing" controller.roundNumber = 72 controller.mode = "Round"
	controller.roundRoster = { { userId = 1001, teamId = 1, isBot = false }, { userId = 1002, teamId = 1, isBot = false }, { userId = 1004, teamId = 2, isBot = false }, { userId = -7, teamId = 1, isBot = true } }
	tune("ResultsSeconds", 0)
	controller:_results(controller.currentRound, { 1 }, "Timeout")
	expect(controller.state:GetAttribute("LastResultWinnerIds") == "1001,1002" and controller.state:GetAttribute("LastResultParticipantIds") == "1001,1002,1004", "Results snapshot includes assigned real IDs and excludes bots")
	expect(controller.state:GetAttribute("LastResultRound") == 72 and controller.state:GetAttribute("LastResultPractice") == false, "Result reward key contains round and practice state")
	expect(controller.state:GetAttribute("WinnerTeamIds") == "1" and controller.state:GetAttribute("ResultReason") == "Timeout" and controller.phase == "Results", "Result UI receives team IDs and timeout reason")
	controller:_cleanup()
	expect(not controller.active and controller.phase == "Waiting" and controller.currentRound == nil and controller.botFolder == nil and controller.effects == nil, "Stop cleanup removes bots effects and active round")
	expect(victim.humanoid.WalkSpeed == 20 and victim.humanoid.JumpPower == 54 and victim.root.CollisionGroup == "Default", "Cleanup restores authored movement and collision group")
	expect(victim.player:GetAttribute("MDParticipating") == false and victim.player:GetAttribute("MDTeamId") == 0, "Cleanup clears participant team metadata")
	expect(victim.player:GetAttribute("MDSprintMax") == 0 and victim.player:GetAttribute("MDSprintExhausted") == false and victim.player:GetAttribute("MDFireReadyAt") == 0, "Cleanup clears stamina exhaustion leases and shot cooldown")
	expect(victim.character:FindFirstChild("MDMudCoating") == nil and victim.character:FindFirstChild("MDOutline") == nil, "Cleanup removes all mud geometry and team highlighting")
	expect(next(controller.originalTeamSizes) == nil and next(controller.eliminatedTeams) == nil and next(controller.records) == nil, "Cleanup clears bot records elimination and timeout snapshots")
end, debug.traceback)
if controller then
	pcall(function() controller:_cleanup() end)
	for name, before in pairs(authored) do controller.arena:SetAttribute(name, before.value) end
end
folder:Destroy() module:Destroy()
assert(ok, failure)
return { passed = #checks, checks = checks }
