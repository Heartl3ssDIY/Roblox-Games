local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = require(game:GetService("ServerScriptService").StuckInTheMudService)
local controller = Service.GetRunningService()
assert(controller and controller.running, "Start PlaygroundBootstrap before live checks")
assert(not controller.active, "Stop the current round before live checks")
local player = Players:GetPlayers()[1]
assert(player, "Live checks need one connected Play client")
local checks, modified = {}, {}
local function expect(condition, name)
	assert(condition, name)
	table.insert(checks, name)
end
local function waitUntil(predicate, timeout)
	local ends = workspace:GetServerTimeNow() + timeout
	while not predicate() and workspace:GetServerTimeNow() < ends do task.wait(0.05) end
	return predicate()
end
local function disableAI(record)
	modified[record] = { nextBotMoveAt = record.nextBotMoveAt, nextBotShotAt = record.nextBotShotAt }
	record.nextBotMoveAt, record.nextBotShotAt = math.huge, math.huge
	if record.humanoid then record.humanoid:MoveTo(record.root.Position) end
end
local ok, failure = xpcall(function()
	local accepted, reason = controller:StartPractice(player, "Medic")
	expect(accepted, "Medic practice starts: " .. tostring(reason))
	expect(waitUntil(function() return controller.phase == "Playing" end, 7), "Practice countdown releases into Playing")
	local human, friend, enemies = controller.records[player], nil, {}
	for _, record in pairs(controller.records) do
		if record.participating and record.isBot then disableAI(record) if record.teamId == human.teamId then friend = record else table.insert(enemies, record) end end
	end
	table.sort(enemies, function(a, b) return a.player.UserId < b.player.UserId end)
	expect(friend and #enemies == 2 and friend.muddy, "Medic practice has a muddy teammate and two opposing bots")
	local rootY = controller.spawnPads[1].Position.Y
	local center = Vector3.new(controller.bounds.Position.X, rootY, controller.bounds.Position.Z)
	controller:_teleport(human, CFrame.lookAt(center + Vector3.new(-12, 0, 0), center))
	controller:_teleport(friend, CFrame.new(center + Vector3.new(8, 0, 0)))
	controller:_teleport(enemies[1], CFrame.new(center + Vector3.new(60, 0, 0)))
	controller:_teleport(enemies[2], CFrame.new(center + Vector3.new(0, 0, 80)))
	for _, record in ipairs({ friend, enemies[1], enemies[2] }) do record.humanoid:MoveTo(record.root.Position) end
	task.wait(0.2)
	local backpack = player:FindFirstChild("Backpack")
	local heat = backpack and backpack:FindFirstChild("HeatGun")
	expect(heat and player.Character:FindFirstChild("MudGun"), "Real player receives both tools and equips MudGun by default")
	human.humanoid:EquipTool(heat) task.wait(0.15)
	expect(controller:_equipped(human, "Heat") == heat and player:GetAttribute("MDTool") == "HeatGun", "Equipping real HeatGun publishes tool state")
	local muzzle = heat.Handle.MuzzleAttachment
	local dir = (friend.root.Position - muzzle.WorldPosition).Unit
	expect(controller:Action(player, "Heat", true, dir).ok, "Actual connected player starts heat from real muzzle")
	local started = workspace:GetServerTimeNow()
	while workspace:GetServerTimeNow() - started < 2 do dir = (friend.root.Position - muzzle.WorldPosition).Unit controller:Action(player, "Heat", true, dir) task.wait(0.2) end
	expect(friend.muddy and friend.rescueProgress > 1.5 and friend.rescueProgress < 3, "Live rescue advances in seconds without freeing early")
	controller:Action(player, "Heat", false) task.wait(0.15)
	expect(friend.muddy and friend.rescueProgress == 0, "Live release clears partial rescue")
	started = workspace:GetServerTimeNow()
	while friend.muddy and workspace:GetServerTimeNow() - started < 6 do dir = (friend.root.Position - muzzle.WorldPosition).Unit controller:Action(player, "Heat", true, dir) task.wait(0.2) end
	expect(not friend.muddy and not friend.frozen and friend.humanoid.WalkSpeed == 16, "Continuous physical heat rescues after five seconds")
	controller:Action(player, "Heat", false)
	local sprintStart = friend.root.Position
	friend.sprintHeld, friend.sprintLeaseEndsAt = true, workspace:GetServerTimeNow() + 3
	friend.humanoid:MoveTo(sprintStart + Vector3.new(30, 0, 0))
	task.wait(0.75)
	expect(friend.sprinting and friend.humanoid.WalkSpeed == 40 and friend.sprintRemaining < 9.5 and (friend.root.Position - sprintStart).Magnitude > 12, "Live moving sprint produces physical speed and stamina drain")
	friend.sprintHeld, friend.sprinting = false, false controller:_movement(friend)
	controller:_teleport(friend, CFrame.new(center + Vector3.new(0, 0, 40)))
	friend.humanoid:MoveTo(friend.root.Position)
	local mud = backpack:FindFirstChild("MudGun")
	expect(mud ~= nil, "MudGun remains in Backpack after heat equip")
	human.humanoid:EquipTool(mud) task.wait(0.15)
	muzzle = mud.Handle.MuzzleAttachment
	local target = enemies[1]
	dir = (target.root.Position - muzzle.WorldPosition).Unit
	expect(controller:Action(player, "Fire", dir).ok, "Real equipped MudGun launches a swept projectile")
	expect(not target.muddy, "Live shot does not stick distant enemy before travel")
	expect(waitUntil(function() return target.muddy end, 2), "Live projectile reaches and immobilizes enemy")
	local locked = target.root.Position
	target.root.AssemblyLinearVelocity = Vector3.new(30, 15, 0)
	task.wait(0.3)
	expect((target.root.Position - locked).Magnitude < 0.3 and target.humanoid.WalkSpeed == 0, "Server mud freeze resists forced linear movement")
	local template = ReplicatedStorage.MudAssets.MudGun
	expect(template.Parent == ReplicatedStorage.MudAssets and template:GetAttribute("MDManaged") == nil, "Gameplay clones preserve editable weapon template")
	local body = target.character
	body:Destroy()
	expect(waitUntil(function() return target.character ~= body and target.ready end, 2), "Destroyed practice character is recreated")
	expect(target.muddy and target.frozen and target.humanoid.WalkSpeed == 0, "Live respawn cannot escape mud")
	controller:_teleport(target, CFrame.new(center + Vector3.new(60, 0, 40)))
	expect(player:GetAttribute("MDParticipating") and controller.state:GetAttribute("ActiveTeamCount") == 2, "Round remains active while each team has a free member")
	task.wait(0.7)
	target = enemies[2]
	controller:_teleport(target, CFrame.new(center + Vector3.new(60, 0, 0)))
	target.humanoid:MoveTo(target.root.Position)
	dir = (target.root.Position - muzzle.WorldPosition).Unit
	expect(controller:Action(player, "Fire", dir).ok, "Second live shot respects cooldown and launches")
	expect(waitUntil(function() return controller.phase == "Results" end, 3), "Final opposing stick produces Results immediately")
	expect(controller.state:GetAttribute("WinnerTeamIds") == tostring(human.teamId) and controller.state:GetAttribute("ResultReason") == "LastTeamStanding", "Live last standing team wins")
	expect(controller.state:GetAttribute("LastResultPractice") == true and controller.state:GetAttribute("LastResultWinnerIds") == tostring(player.UserId), "Practice result records real player without enabling normal rewards")
end, debug.traceback)
for record, old in pairs(modified) do record.nextBotMoveAt, record.nextBotShotAt = old.nextBotMoveAt, old.nextBotShotAt end
if controller.active then controller:StopRound() end
local leftovers = (player.Character and player.Character:FindFirstChild("MudGun")) or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("MudGun"))
if ok then expect(not leftovers and player:GetAttribute("MDParticipating") == false and controller.phase == "Waiting", "Live stop removes tools and participant state") end
assert(ok, failure)
return { passed = #checks, checks = checks }
