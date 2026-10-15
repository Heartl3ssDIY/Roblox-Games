local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local module = ServerScriptService.BritishBulldogService:Clone()
module.Name = "BBMovementFixtureModule"
module.Parent = ServerScriptService
local folder = Instance.new("Folder")
folder.Name = "BBMovementFixtures"
folder.Parent = workspace
local controller
local checks = {}
local authoredBefore = {}
local function tune(name, value)
	if not authoredBefore[name] then authoredBefore[name] = { value = controller.arena:GetAttribute(name) } end
	controller.arena:SetAttribute(name, value)
end
local function expect(condition, name)
	assert(condition, name)
	table.insert(checks, name)
end
local ok, failure = xpcall(function()
	local Service = require(module)
	controller = Service.new(workspace["British Bulldog game"])
	controller.state = Instance.new("Folder")
	controller.state.Parent = folder
	controller:_collisionGroups()
	controller.running, controller.active, controller.phase = true, true, "Crossing"
	controller.currentRound, controller.crossingNumber = {}, 1
	local now = workspace:GetServerTimeNow()
	controller.endsAt = now + 1000
	local groundY = controller.spawnPads.Bulldog[1].Position.Y
	local center = Vector3.new(controller.bounds.Position.X, groundY, controller.bounds.Position.Z)
	local function actor(name, role, offset, initial)
		local attributes = {}
		local player = { DisplayName = name, Parent = Players }
		function player:GetAttribute(key) return attributes[key] end
		function player:SetAttribute(key, value) attributes[key] = value end
		local character = Instance.new("Model")
		character.Name = name
		character.Parent = folder
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = CFrame.new(center + offset)
		root.CanCollide, root.CanQuery = false, false
		root.Parent = character
		character.PrimaryPart = root
		local humanoid = { Parent = character, Health = 100, WalkSpeed = 20, JumpPower = 50,
			JumpHeight = 7.2, AutoRotate = true, FloorMaterial = Enum.Material.Grass }
		function humanoid:Move() end
		local record = { player = player, character = character, root = root, humanoid = humanoid,
			ready = true, role = "Spectator", participating = true, originalGroups = {},
			characterConnections = {}, connections = {}, spawnIndex = 1, departed = true,
			arrived = false, frozen = false, initialBulldog = initial, sprintRemaining = initial and 15 or 10 }
		player.Character = character
		controller.records[player] = record
		controller:_setRole(record, role)
		return record
	end
	local runner = actor("Runner", "Runner", Vector3.zero, false)
	local bulldog = actor("InitialBulldog", "Bulldog", Vector3.new(0, 0, 20), true)
	expect(runner.sprintMax == 10 and runner.sprintRemaining == 10, "Runner starts with10s capacity")
	expect(bulldog.sprintMax == 15 and bulldog.sprintRemaining == 15, "Initial Bulldog starts with15s capacity")
	expect(bulldog.player:GetAttribute("BBInitialBulldog") == true, "Initial Bulldog identity published")
	expect(runner.originalWalkSpeed == 20, "Custom original speed captured before round movement")
	expect(controller:Move(runner.player, "Sprint", true).ok, "Valid sprint hold accepted")
	expect(runner.humanoid.WalkSpeed == 40, "Runner sprint is2.5x base speed")
	expect(controller:Move(bulldog.player, "Sprint", true).ok and bulldog.humanoid.WalkSpeed == 45, "Bulldog sprint is2.5x base speed")
	expect(not controller:Move(runner.player, "Sprint", 1).ok, "Nonboolean sprint request refused")
	local function hold(record)
		record.sprintHeld = true
		record.sprintLeaseEndsAt = now + 2000
	end
	hold(runner)
	runner.root.AssemblyLinearVelocity = Vector3.zero
	controller:_updateMovement(runner, 0.25, now + 0.25)
	expect(runner.sprintRemaining == 10 and not runner.sprinting, "Standing still consumes no stamina")
	runner.root.AssemblyLinearVelocity = Vector3.new(16, 0, 0)
	for index = 1, 4 do controller:_updateMovement(runner, 0.25, now + index * 0.25) end
	expect(math.abs(runner.sprintRemaining - 9) < 0.001 and runner.sprinting, "One moving second consumes one stamina second")
	controller:Move(runner.player, "Sprint", false)
	controller:_updateMovement(runner, 0.25, now + 1.25)
	expect(math.abs(runner.sprintRemaining - (9 + 1 / 6)) < 0.001, "Early release permits partial recharge")
	expect(controller:Move(runner.player, "Sprint", true).ok and runner.humanoid.WalkSpeed == 40, "Partial stamina can resume before exhaustion")
	hold(runner)
	runner.sprintRemaining = 0.05
	controller:_updateMovement(runner, 0.1, now + 2)
	expect(runner.sprintRemaining == 0 and runner.sprintExhausted and runner.humanoid.WalkSpeed == 16, "Empty stamina locks sprint at base speed")
	controller:Move(runner.player, "Sprint", false)
	expect(runner.sprintExhausted, "Release cannot bypass exhaustion lock")
	hold(runner)
	for index = 1, 59 do controller:_updateMovement(runner, 0.25, now + 2 + index * 0.25) end
	expect(runner.sprintExhausted and runner.sprintRemaining < 10 and runner.humanoid.WalkSpeed == 16, "Held sprint stays locked throughout refill")
	controller:_updateMovement(runner, 0.25, now + 17)
	expect(not runner.sprintExhausted and runner.sprintRemaining == 10 and runner.humanoid.WalkSpeed == 40, "Full15s refill unlocks held sprint automatically")
	controller:_updateMovement(runner, 0.1, now + 17.1)
	expect(runner.sprinting and math.abs(runner.sprintRemaining - 9.9) < 0.001, "Held sprint drains again after full recharge")
	runner.sprintLeaseEndsAt = now + 18
	controller:_updateMovement(runner, 0.1, now + 18.1)
	expect(not runner.sprintHeld and runner.humanoid.WalkSpeed == 16, "Expired hold lease restores base speed")
	controller:_freeze(runner)
	expect(runner.frozen and runner.humanoid.WalkSpeed == 0 and not runner.sprintHeld, "Freeze cancels sprint and stops movement")
	controller:_unfreeze(runner)
	expect(runner.humanoid.WalkSpeed == 16, "Unfreeze cannot restore a stale sprint speed")
	controller.phase = "Countdown"
	expect(not controller:Move(runner.player, "Sprint", true).ok, "Countdown cannot sprint")
	controller.phase = "Crossing"
	runner.root.CFrame = controller:_spawnCFrame("North", 1)
	runner.departed = false
	expect(controller:Move(runner.player, "Sprint", true).ok, "Runner may sprint out of source safe zone")
	expect(not controller:Move(runner.player, "Dodge", 1).ok, "Safe-zone runner cannot dodge")
	controller:Move(runner.player, "Sprint", false)
	runner.root.CFrame = CFrame.new(center)
	runner.departed = true
	runner.arrived = true
	expect(not controller:Move(runner.player, "Sprint", true).ok and not controller:Move(runner.player, "Dodge", 1).ok, "Arrived runner has no movement abilities")
	runner.arrived = false
	expect(not controller:Move(bulldog.player, "Dodge", 1).ok, "Bulldogs cannot dodge")
	expect(not controller:Move(runner.player, "Dodge", 0).ok, "Invalid dodge direction refused")
	local wall = Instance.new("Part")
	wall.Anchored, wall.CanCollide = true, true
	wall.Size = Vector3.new(1, 8, 5)
	wall.Position = center + controller.bounds.CFrame.RightVector * 4
	wall.Parent = folder
	expect(not controller:Move(runner.player, "Dodge", 1).ok, "Dodge sweep refuses solid wall")
	wall:Destroy()
	runner.root.CFrame = CFrame.new(controller.bounds.CFrame:PointToWorldSpace(Vector3.new(controller.bounds.Size.X / 2 - 4, center.Y - controller.bounds.Position.Y, 0)))
	expect(not controller:Move(runner.player, "Dodge", 1).ok, "Dodge cannot pass arena side boundary")
	runner.root.CFrame = CFrame.new(center)
	bulldog.root.CFrame = CFrame.new(center + Vector3.new(0, 0, 20))
	expect(controller:Move(runner.player, "Dodge", 1).ok, "Clear field dodge accepted")
	expect(runner.root:FindFirstChild("BBDodgeVelocity") and runner.root:FindFirstChild("BBDodgeAttachment"), "Dodge uses physical plane actuator")
	expect(runner.pendingEscape == nil and (runner.boostEndsAt or 0) == 0, "Unthreatened dodge grants no free boost")
	expect(not controller:Move(runner.player, "Dodge", -1).ok, "Dodge cannot repeat during4s cooldown")
	expect(runner.dodgeReadyAt > workspace:GetServerTimeNow() + 3.8, "Dodge cooldown deadline is4s")
	controller:_stopDodgeBurst(runner)
	expect(not runner.root:FindFirstChild("BBDodgeVelocity") and not runner.root:FindFirstChild("BBDodgeAttachment"), "Dodge cleanup removes constraint and attachment")
	runner.dodgeReadyAt = 0
	bulldog.root.CFrame = CFrame.new(center + Vector3.new(0, 0, 7))
	expect(controller:Move(runner.player, "Dodge", 1).ok and runner.pendingEscape, "Threat within8schedules escape verification")
	local escape = runner.pendingEscape
	runner.root.Position = runner.root.Position + Vector3.new(3, 0, 0)
	controller:_confirmEscape(runner, escape.checkAt + 0.01)
	expect(runner.boostEndsAt > escape.checkAt + 1.4 and runner.humanoid.WalkSpeed == 32, "Survived close escape grants2x speed for1.5s")
	expect(runner.player:GetAttribute("BBDodgeConfirmedAt") > 0, "Successful dodge result published")
	controller:Move(runner.player, "Sprint", true)
	expect(runner.humanoid.WalkSpeed == 40, "Sprint and dodge boost use max multiplier without stacking")
	controller:Move(runner.player, "Sprint", false)
	controller:_stopDodgeBurst(runner)
	controller:_updateMovement(runner, 0.1, runner.boostEndsAt + 0.1)
	expect(runner.humanoid.WalkSpeed == 16, "Temporary boost expires to base speed")
	tune("SprintMultiplier", 3)
	tune("DodgeBoostMultiplier", 4)
	runner.boostEndsAt = workspace:GetServerTimeNow() + 3
	controller:Move(runner.player, "Sprint", true)
	expect(runner.humanoid.WalkSpeed == 64, "Authored multipliers apply and choose max without stacking")
	controller:Move(runner.player, "Sprint", false)
	runner.boostEndsAt = 0
	controller:_applyMovementSpeed(runner, workspace:GetServerTimeNow())
	tune("SprintMultiplier", 2.5)
	tune("DodgeBoostMultiplier", 2)
	tune("DodgeBoostSeconds", 0.75)
	tune("DodgeCooldownSeconds", 2)
	runner.root.CFrame = CFrame.new(center)
	runner.dodgeReadyAt = 0
	bulldog.root.CFrame = CFrame.new(center + Vector3.new(0, 0, 7))
	local requestedAt = workspace:GetServerTimeNow()
	expect(controller:Move(runner.player, "Dodge", 1).ok and runner.dodgeReadyAt >= requestedAt + 1.9
		and runner.dodgeReadyAt <= requestedAt + 2.1, "Authored dodge cooldown controls deadline")
	escape = runner.pendingEscape
	runner.root.Position = runner.root.Position + Vector3.new(3, 0, 0)
	local confirmedAt = escape.checkAt + 0.01
	controller:_confirmEscape(runner, confirmedAt)
	expect(math.abs(runner.boostEndsAt - confirmedAt - 0.75) < 0.001, "Authored boost duration controls expiry")
	controller:_stopDodgeBurst(runner)
	runner.root.CFrame = CFrame.new(center)
	bulldog.root.CFrame = CFrame.new(center + Vector3.new(3, 0, 0))
	runner.pendingEscape = { checkAt = workspace:GetServerTimeNow() - 0.01, token = controller.currentRound,
		crossing = controller.crossingNumber, character = runner.character, startPosition = center - Vector3.new(3, 0, 0) }
	controller:_tick(0.05)
	expect(runner.role == "Tagged" and runner.frozen and (runner.boostEndsAt or 0) == 0, "Real tag in escape window defeats dodge without invulnerability")
	expect(runner.pendingEscape == nil and not runner.dodgeBurst, "Caught runner loses pending escape and physical burst")
	controller:_finishCrossing()
	expect(runner.role == "Bulldog" and runner.sprintMax == 10 and not runner.initialBulldog, "Converted Bulldog receives runner10s capacity")
	controller:_restoreCharacter(runner)
	expect(runner.humanoid.WalkSpeed == 20, "Round cleanup restores custom original walking speed")
end, debug.traceback)
if controller then
	controller.active = false
	for _, record in pairs(controller.records) do controller:_restoreCharacter(record) end
	for name, entry in pairs(authoredBefore) do controller.arena:SetAttribute(name, entry.value) end
end
folder:Destroy()
module:Destroy()
assert(ok, failure)
return { passed = #checks, checks = checks, fixtureType = "Server rule fixtures with real roots and actuators; grounded Humanoid adapters. Live player movement still requires Play QA." }
