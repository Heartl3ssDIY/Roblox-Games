local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Service = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local arena = workspace["British Bulldog game"]:Clone()
arena.Name = "BritishBulldogPracticeTestArena"
arena.Parent = ServerStorage
arena:SetAttribute("AutoStart", false)
arena:SetAttribute("CountdownSeconds", 1)
arena:SetAttribute("RoundDuration", 30)
arena:SetAttribute("ResultsSeconds", 0)
local state = Instance.new("Folder")
state.Name = "BritishBulldogPracticeTestState"
state.Parent = ServerStorage
local fixtureFolder = Instance.new("Folder")
fixtureFolder.Name = "BritishBulldogPracticeHumanFixture"
fixtureFolder.Parent = workspace
local controller = Service.new(arena)
controller.state = state
controller.lobbySpawn = nil
controller.running = true
controller:_collisionGroups()
local checks = {}
local connection
local function expect(condition, label)
	assert(condition, label)
	table.insert(checks, label)
end
local function waitFor(predicate, seconds, label)
	local deadline = os.clock() + seconds
	while not predicate() and os.clock() < deadline do
		task.wait(0.05)
	end
	expect(predicate(), label)
end
local function bots()
	local records = {}
	for _, record in pairs(controller.records) do
		if record.isBot then
			table.insert(records, record)
		end
	end
	return records
end
local function fieldCFrame(x, z)
	local y = controller.bounds.CFrame:PointToObjectSpace(controller.spawnPads.Bulldog[1].Position).Y
	return CFrame.new(controller.bounds.CFrame:PointToWorldSpace(Vector3.new(x, y, z)))
end
local ok, failure = xpcall(function()
	local player = controller:_createPracticeBot(90, "Runner")
	player.DisplayName = "Human fixture"
	player.UserId = -90001
	player.Parent = Players
	local human = controller.records[player]
	human.isBot = false
	human.character.Parent = fixtureFolder
	local baselineSpeed = human.humanoid.WalkSpeed
	connection = RunService.Heartbeat:Connect(function()
		controller:_tick()
	end)
	expect(not controller:StartRound({ player }), "Normal rounds still reject a single human")
	expect(not controller:StartPractice(player, "Spectator"), "Practice rejects unsupported roles")
	expect(#bots() == 0, "Failed start creates no bots")
	expect(controller:StartPractice(player, "Runner"), "Runner practice starts for one ready human")
	waitFor(function()
		return controller.phase == "Countdown"
	end, 1, "Runner practice reaches its countdown")
	local botRecords = bots()
	local bulldog = botRecords[1]
	expect(#botRecords == 1 and bulldog.role == "Bulldog" and human.role == "Runner", "Runner practice has one human runner and one AI Bulldog")
	local runners, bulldogs, _, participants = controller:_counts()
	expect(runners == 1 and bulldogs == 1 and participants == 2 and controller:_outcome() == nil, "Practice avoids an immediate one-player result")
	expect(state:GetAttribute("Mode") == "PracticeRunner" and state:GetAttribute("PracticeOwnerUserId") == player.UserId, "Practice publishes its mode and owner")
	expect(#controller:_readyPlayers() == 1, "Bots are excluded from real ready-player selection")
	expect(human.frozen and bulldog.frozen, "Practice freezes both roles during the countdown")
	expect(bulldog.character.PrimaryPart == bulldog.root and bulldog.character:FindFirstChild("Head") and bulldog.character:FindFirstChild("Torso") and bulldog.character:FindFirstChild("Right Leg"), "AI has a physical R6 body and root")
	local motorCount = 0
	for _, item in ipairs(bulldog.character:GetDescendants()) do
		if item:IsA("Motor6D") then
			motorCount = motorCount + 1
		end
	end
	expect(motorCount == 6, "AI body uses six connected R6 joints")
	waitFor(function()
		return controller.phase == "Crossing"
	end, 3, "Runner practice reaches the Bulldog call")
	expect(human.player:GetAttribute("BBMustLeave") and not human.frozen and not bulldog.frozen, "The call releases movement and starts the five-second departure rule")
	controller:_drivePracticeBots(workspace:GetServerTimeNow() + 1)
	expect((bulldog.humanoid.WalkToPoint - bulldog.root.Position).Magnitude < 0.1, "AI Bulldog waits while the runner is protected")
	controller:_teleport(human, fieldCFrame(0, (controller.northZ + controller.southZ) / 2))
	controller:_tick()
	controller:_drivePracticeBots(workspace:GetServerTimeNow() + 2)
	expect(human.departed and not human.mustLeave, "A runner leaving the source zone clears its individual deadline")
	expect(controller:_inField(bulldog.humanoid.WalkToPoint), "AI Bulldog chases an eligible runner inside field bounds")
	controller:_teleport(bulldog, human.root.CFrame + Vector3.new(2, 0, 0))
	controller:_tick()
	expect(human.role == "Tagged" and human.frozen, "AI Bulldog can tag and freeze a real-player adapter")
	local oldToken = controller.currentRound
	local oldCharacter = bulldog.character
	expect(controller:StopRound(), "Admin can stop the active practice round")
	expect(controller.running and not controller.active and controller.currentRound == nil, "Stopping a round preserves the running service")
	expect(oldCharacter.Parent == nil and #bots() == 0 and controller.botFolder == nil, "Stopping destroys all owned practice rigs and records")
	expect(human.role == "Spectator" and not human.frozen and human.humanoid.WalkSpeed == baselineSpeed and not human.mustLeave, "Stopping restores the human's original movement and participation")
	expect(state:GetAttribute("Mode") == "Waiting" and state:GetAttribute("PracticeOwnerUserId") == 0, "Stopping clears practice metadata")
	expect(controller:StartPractice(player, "Bulldog"), "Bulldog practice can start immediately after stopping")
	waitFor(function()
		return controller.phase == "Countdown"
	end, 1, "Bulldog practice reaches its countdown")
	controller:_cleanupRound(oldToken)
	expect(controller.active and state:GetAttribute("Mode") == "PracticeBulldog", "Old round cleanup cannot cancel a newer practice token")
	botRecords = bots()
	expect(#botRecords == 3 and human.role == "Bulldog", "Bulldog practice spawns three AI runners")
	for _, bot in ipairs(botRecords) do
		expect(bot.role == "Runner" and bot.frozen, "AI runner waits for the countdown")
	end
	waitFor(function()
		return controller.phase == "Crossing"
	end, 3, "Bulldog practice reaches the Bulldog call")
	controller:_drivePracticeBots(workspace:GetServerTimeNow() + 3)
	for _, bot in ipairs(botRecords) do
		expect((bot.humanoid.WalkToPoint - controller:_spawnCFrame("South", bot.spawnIndex).Position).Magnitude < 0.1, "AI runner moves toward the opposite safe zone")
	end
	if RunService:IsRunning() then
		local movingBot = botRecords[1]
		local origin = movingBot.root.Position
		expect(movingBot.humanoid.RootPart == movingBot.root and movingBot.humanoid.Health > 0, "Physics recognizes the bot's Humanoid root assembly")
		waitFor(function()
			return (movingBot.root.Position - origin).Magnitude > 3
		end, 2, "A server-owned AI runner physically walks several studs")
	end
	for _, bot in ipairs(botRecords) do
		controller:_teleport(bot, fieldCFrame(bot.spawnIndex * 14, (controller.northZ + controller.southZ) / 2))
	end
	controller:_tick()
	for _, bot in ipairs(botRecords) do
		controller:_teleport(bot, controller:_spawnCFrame("South", bot.spawnIndex))
	end
	controller:_tick()
	waitFor(function()
		return controller.phase == "Countdown" and controller.crossingNumber == 2
	end, 2, "Practice alternates once all AI runners reach safety")
	expect(controller.source == "South" and controller.destination == "North", "Second crossing swaps the source and destination")
	waitFor(function()
		return controller.phase == "Crossing" and controller.crossingNumber == 2
	end, 3, "Second crossing waits for another Bulldog call")
	controller:_drivePracticeBots(workspace:GetServerTimeNow() + 6)
	for _, bot in ipairs(botRecords) do
		expect((bot.humanoid.WalkToPoint - controller:_spawnCFrame("North", bot.spawnIndex).Position).Magnitude < 0.1, "AI runner reverses toward the new safe destination")
	end
	controller:_teleport(human, fieldCFrame(0, (controller.northZ + controller.southZ) / 2))
	for _, bot in ipairs(botRecords) do
		controller:_teleport(bot, human.root.CFrame + Vector3.new(2, 0, 0))
	end
	controller:_tick()
	for _, bot in ipairs(botRecords) do
		expect(bot.role == "Tagged" and bot.frozen, "Human Bulldog can tag a physical AI runner")
	end
	waitFor(function()
		return not controller.active
	end, 2, "Catching all AI runners completes the practice round")
	expect(state:GetAttribute("WinnerTeam") == "Bulldogs" and string.find(state:GetAttribute("WinnersText"), "Human fixture", 1, true), "Practice results include the human Bulldog winner")
	expect(#bots() == 0 and controller.botFolder == nil and human.role == "Spectator", "Completed results remove bot rigs and restore the human")
	expect(controller:StartPractice(player, "Runner"), "A completed round allows another practice start")
	waitFor(function()
		return controller.phase == "Countdown"
	end, 1, "Disconnect fixture reaches its countdown")
	controller:_removePlayer(player)
	expect(not controller.active and #bots() == 0 and controller.practiceOwner == nil and controller.running, "Practice owner disconnect cancels the round and removes bots")
	expect(not controller:StopRound(), "Stopping an idle round reports no active round")
end, debug.traceback)
if connection then
	connection:Disconnect()
end
controller:Stop()
fixtureFolder:Destroy()
state:Destroy()
arena:Destroy()
assert(ok, failure)
return { passed = #checks, checks = checks, physicsRunning = RunService:IsRunning(), fixtureType = "Practice public APIs with one player adapter and physical bot rigs; movement targets and tagging verified, no live-player input" }
