local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Service = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local arena = workspace["British Bulldog game"]:Clone()
arena.Name = "BritishBulldogTestArena"
arena.Parent = ServerStorage
local attributeNames = { "RoundDuration", "CountdownSeconds", "ResultsSeconds", "AutoStart" }
local originalAttributes = {}
local checks = {}
local controllers = {}
local connections = {}
local fixtureFolder = Instance.new("Folder")
fixtureFolder.Name = "BritishBulldogFullRoundFixtures"
fixtureFolder.Parent = workspace
local stateFolder = Instance.new("Folder")
stateFolder.Name = "BritishBulldogFullRoundStates"
stateFolder.Parent = ServerStorage

for _, name in ipairs(attributeNames) do
	originalAttributes[name] = { value = arena:GetAttribute(name) }
end

local function expect(condition, label)
	assert(condition, label)
	table.insert(checks, label)
end

local function makeRecord(controller, name, index)
	local attributes = {}
	local player = { DisplayName = name }
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:SetAttribute(key, value)
		attributes[key] = value
	end
	local character = Instance.new("Model")
	character.Name = name
	character.Parent = fixtureFolder
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = controller:_spawnCFrame("North", index)
	root.CanQuery = false
	root.CanCollide = true
	root.Parent = character
	character.PrimaryPart = root
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = root.CFrame + Vector3.new(0, 2, 0)
	head.CanQuery = false
	head.CanCollide = false
	head.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.WalkSpeed = 16 + index
	humanoid.JumpPower = 40 + index
	humanoid.JumpHeight = 6 + index / 10
	humanoid.AutoRotate = index % 2 == 0
	humanoid.Parent = character
	local baseline = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate,
	}
	local record = {
		player = player,
		character = character,
		root = root,
		humanoid = humanoid,
		role = "Spectator",
		participating = false,
		ready = true,
		originalGroups = {},
		connections = {},
		characterConnections = {},
		spawnIndex = index,
		arrived = false,
		departed = false,
		frozen = false,
	}
	player.Character = character
	controller.records[player] = record
	return record, baseline
end

local function makeController(prefix)
	local controller = Service.new(arena)
	local state = Instance.new("Folder")
	state.Name = prefix .. "State"
	state.Parent = stateFolder
	controller.state = state
	controller.lobbySpawn = nil
	controller:_collisionGroups()
	controller.random = { NextInteger = function()
		return 1
	end }
	controller.running = true
	controller.active = true
	controller.currentRound = {}
	local records, baselines, players = {}, {}, {}
	for index = 1, 4 do
		local record, baseline = makeRecord(controller, prefix .. tostring(index), index)
		table.insert(records, record)
		table.insert(baselines, baseline)
		table.insert(players, record.player)
	end
	table.insert(controllers, controller)
	return controller, records, baselines, players
end

local function checkCleanup(controller, records, baselines, label)
	expect(controller.phase == "Waiting" and not controller.active and controller.currentRound == nil, label .. " returns to Waiting")
	expect(controller.state:GetAttribute("EndsAt") == 0, label .. " clears the match deadline")
	for index, record in ipairs(records) do
		local baseline = baselines[index]
		expect(record.role == "Spectator" and record.player:GetAttribute("BBRole") == "Spectator" and not record.player:GetAttribute("BBParticipating"), label .. " clears participation for fixture " .. tostring(index))
		expect(not record.frozen and record.humanoid.WalkSpeed == baseline.WalkSpeed and record.humanoid.JumpPower == baseline.JumpPower and math.abs(record.humanoid.JumpHeight - baseline.JumpHeight) < 0.001 and record.humanoid.AutoRotate == baseline.AutoRotate, label .. " restores baseline movement for fixture " .. tostring(index))
		expect(record.root.CollisionGroup == "Default" and record.character:FindFirstChild("BBOutline") == nil and record.character:FindFirstChild("BBTaggedLabel") == nil, label .. " restores collision and visuals for fixture " .. tostring(index))
		expect(record.player:GetAttribute("BBMustLeave") == false and record.player:GetAttribute("BBDepartureEndsAt") == 0, label .. " clears departure timer for fixture " .. tostring(index))
	end
end

local function connectDriver(controller, driver)
	local failure
	local connection = RunService.Heartbeat:Connect(function()
		if not controller.active then
			return
		end
		local ok, message = xpcall(function()
			driver()
			controller:_tick()
		end, debug.traceback)
		if not ok then
			failure = message
			controller.running = false
		end
	end)
	table.insert(connections, connection)
	return connection, function()
		return failure
	end
end

local ok, failure = xpcall(function()
	arena:SetAttribute("RoundDuration", 2)
	arena:SetAttribute("CountdownSeconds", 1)
	arena:SetAttribute("ResultsSeconds", 0)
	arena:SetAttribute("AutoStart", false)
	local controller, records, baselines, players = makeController("SurvivorFixture")
	local sawInitialCountdown = false
	local firstCallDeadline
	local deadlineChanged = false
	local laterCountdowns = 0
	local connection, getDriverFailure = connectDriver(controller, function()
		if controller.phase == "Countdown" then
			if controller.crossingNumber == 1 then
				sawInitialCountdown = controller.endsAt == 0 and controller.state:GetAttribute("EndsAt") == 0 and records[2].frozen
			else
				laterCountdowns = laterCountdowns + 1
			end
		end
		if controller.endsAt > 0 then
			if not firstCallDeadline then
				firstCallDeadline = controller.endsAt
				expect(math.abs(firstCallDeadline - workspace:GetServerTimeNow() - 2) < 0.2, "Global timer begins at the first Bulldog call")
			elseif controller.endsAt ~= firstCallDeadline then
				deadlineChanged = true
			end
		end
		if controller.phase == "Crossing" then
			for index = 2, 4 do
				local record = records[index]
				if record.role == "Runner" and not record.arrived then
					if not record.departed then
						local sourceZ = controller.source == "North" and controller.northZ + 4 or controller.southZ - 4
						local spawnY = controller.bounds.CFrame:PointToObjectSpace(controller.spawnPads.North[1].Position).Y
						local world = controller.bounds.CFrame:PointToWorldSpace(Vector3.new(index * 24 - 72, spawnY, sourceZ))
						controller:_teleport(record, CFrame.new(world))
					else
						controller:_teleport(record, controller:_spawnCFrame(controller.destination, index))
					end
				end
			end
		end
	end)
	controller:_runRound(players, controller.currentRound)
	connection:Disconnect()
	assert(not getDriverFailure(), getDriverFailure())
	expect(sawInitialCountdown, "Initial countdown freezes runners without consuming the global timer")
	expect(firstCallDeadline ~= nil and not deadlineChanged and laterCountdowns > 0, "Later crossing countdowns preserve the first match deadline")
	expect(controller.crossingNumber >= 2, "Full round alternates to additional crossings")
	expect(controller.state:GetAttribute("WinnerTeam") == "Runners", "Timeout awards the surviving Runner team")
	local survivorNames = { players[2].DisplayName, players[3].DisplayName, players[4].DisplayName }
	table.sort(survivorNames)
	expect(controller.state:GetAttribute("WinnersText") == table.concat(survivorNames, ", "), "Timeout publishes all three surviving names")
	checkCleanup(controller, records, baselines, "Survivor round")
	controller.running = false

	local caughtController, caughtRecords, caughtBaselines, caughtPlayers = makeController("CaughtFixture")
	local didCatch = false
	local caughtConnection, getCaughtFailure = connectDriver(caughtController, function()
		if caughtController.phase == "Crossing" and not didCatch then
			didCatch = true
			for index = 2, 4 do
				local record = caughtRecords[index]
				caughtController:_teleport(record, caughtController:_spawnCFrame("Bulldog", index))
				caughtController:_caught(record, "Fixture tag")
			end
		end
	end)
	caughtController:_runRound(caughtPlayers, caughtController.currentRound)
	caughtConnection:Disconnect()
	assert(not getCaughtFailure(), getCaughtFailure())
	expect(didCatch, "All-caught fixture reaches the Bulldog call")
	expect(caughtController.state:GetAttribute("WinnerTeam") == "Bulldogs", "Catching the last runner ends the full round for Bulldogs")
	local bulldogNames = {}
	for _, player in ipairs(caughtPlayers) do
		table.insert(bulldogNames, player.DisplayName)
	end
	table.sort(bulldogNames)
	expect(caughtController.state:GetAttribute("WinnersText") == table.concat(bulldogNames, ", "), "All caught players convert before publishing Bulldog team winners")
	checkCleanup(caughtController, caughtRecords, caughtBaselines, "All-caught round")
	caughtController.running = false
end, debug.traceback)

for _, connection in ipairs(connections) do
	connection:Disconnect()
end
for _, controller in ipairs(controllers) do
	controller.running = false
	controller.currentRound = nil
	controller.active = false
	for _, record in pairs(controller.records) do
		pcall(function()
			controller:_restoreCharacter(record)
		end)
	end
end
for _, name in ipairs(attributeNames) do
	arena:SetAttribute(name, originalAttributes[name].value)
end
fixtureFolder:Destroy()
stateFolder:Destroy()
arena:Destroy()
assert(ok, failure)
return { passed = #checks, checks = checks, fixtureType = "Full server round with four player adapters and physical rigs; not a multiplayer session" }
