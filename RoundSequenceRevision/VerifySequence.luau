
local Registry = assert(loadstring([==[-- Course folders may contain spaces; their round number determines order.
local Registry = {}

function Registry.Number(name)
	return tonumber(string.lower(name):match("^%s*course%s*%-%s*round%s*(%d+)%s*$"))
end

function Registry.Resolve(root, number, capacity)
	local candidates = {}
	for _, child in root:GetChildren() do
		if Registry.Number(child.Name) == number then table.insert(candidates, child) end
	end
	if #candidates ~= 1 then
		return nil, #candidates == 0 and ("Course " .. number .. " has not been built yet.")
			or ("Multiple folders are named Course " .. number .. ".")
	end
	local course = candidates[1]
	local start = course:FindFirstChild("Start")
	local folder = start and start:FindFirstChild("Spawn locs")
	local finish = course:FindFirstChild("Green_EndZone")
	local bounds = course:FindFirstChild("out of bounds")
	if not folder or not finish or not bounds then
		return nil, ("Course %d needs Start/Spawn locs, Green_EndZone and out of bounds."):format(number)
	end
	local spawns = {}
	for _, part in folder:GetChildren() do
		if part:IsA("SpawnLocation") then table.insert(spawns, part) end
	end
	table.sort(spawns, function(a, b)
		-- SpawnLocation_2.1 means course 2, spawn 1.
		local an = tonumber(a.Name:match("(%d+)%s*$")) or math.huge
		local bn = tonumber(b.Name:match("(%d+)%s*$")) or math.huge
		if an ~= bn then return an < bn end
		return a.Name < b.Name
	end)
	if #spawns < capacity then
		return nil, ("Course %d needs %d spawn points; found %d."):format(number, capacity, #spawns)
	end
	local center = Vector3.zero
	for _, spawn in spawns do center += spawn.Position end
	center /= #spawns
	return {
		number = number, course = course, spawnFolder = folder, spawns = spawns,
		bounds = bounds, finish = finish, boosts = course:FindFirstChild("Speed boosts"),
		tokens = course:FindFirstChild("Second life tokens"), center = center,
	}
end

function Registry.ActivateSpawns(root, descriptor)
	for _, child in root:GetChildren() do
		if Registry.Number(child.Name) then
			for _, part in child:GetDescendants() do
				if part:IsA("SpawnLocation") then
					part.Enabled = part:IsDescendantOf(descriptor.spawnFolder)
				end
			end
		end
	end
end

return Registry
]==]))()
local realWorkspace = workspace
local descriptor, message = Registry.Resolve(realWorkspace, 1, 6)
assert(descriptor, message)
local nextDescriptor, message2 = Registry.Resolve(realWorkspace, 2, 6)
assert(nextDescriptor, message2)
assert(#descriptor.spawns >= 6 and #nextDescriptor.spawns >= 6)
for index, spawn in nextDescriptor.spawns do
 assert(tonumber(spawn.Name:match("(%d+)%s*$")) == index, "Course 2 spawn sorting")
end
local courseNumber, courseVersion = 1, 1
local course, spawnFolder = descriptor.course, descriptor.spawnFolder
local boundsFolder, endZone, boostFolder = descriptor.bounds, descriptor.finish, descriptor.boosts
local spawns = descriptor.spawns
local players, ordered, delayed, packets = {}, {}, {}, {}
local roundPhase, countdownVersion, expectedPlayers = "Waiting", 0, 6
local roundStartedAt, finishPlace = 0, 0
local roundWinner, finishDeadline
local maxRounds = 5
local now = 100
local boundNumber = 1
local courseConnections, spikeModels, spikePivots, boostParts, boostOriginal, secondLifeTokens = {}, {}, {}, {}, {}, {}
local workspace = {
 GetServerTimeNow = function() return now end,
 SetAttribute = function() end,
}
local CourseRegistry = {
 Resolve = function(_, number, capacity) return Registry.Resolve(realWorkspace, number, capacity) end,
 ActivateSpawns = function(_, active) assert(active.number == courseNumber) end,
}
local Players = {GetPlayers = function() return table.clone(ordered) end}
local config = {MaxPlayers=6,SecondLifeAttribute="SecondLives",RoundResetDelay=5,FinishGraceSeconds=15}
local task = {delay=function(seconds,callback) table.insert(delayed,{seconds=seconds,callback=callback}) end}
local event = {
 FireAllClients = function(_,action,packet) table.insert(packets,{action=action,packet=packet}) end,
 FireClient = function() end,
}
local function setStatus(player,status) players[player].status=status player:SetAttribute("RunnerStatus",status) end
local function removeRunnerForces(data) data.velocity=nil data.gravityForce=nil end
local function addRunnerForces(data) data.velocity={LineVelocity=0} end
local function setSpeed() end
local function playRunAnimation() end
local function resetBoost() end
local function resetSecondLifeTokens() end
local function runnerCFrame(position, up) return CFrame.lookAt(position,position+Vector3.new(-1,0,0),up) end
local function bindCourse() boundNumber=courseNumber end
local checkRoundComplete

local function spawnCFrame(spawn)
	local up = spawn.CFrame.UpVector.Y < 0 and -Vector3.yAxis or Vector3.yAxis
	return runnerCFrame(spawn.Position + up * 3.2, up), up.Y
end

local function placeAtSpawn(player)
	local data = players[player]
	if not data or not data.root or not data.spawn then return end
	local cframe, sign = spawnCFrame(data.spawn)
	data.gravitySign = sign
	data.laneZ = data.spawn.Position.Z
	player:SetAttribute("RunnerLaneZ", data.laneZ)
	player:SetAttribute("RunnerCourseNumber", courseNumber)
	player:SetAttribute("RunnerCourseCenter", descriptor.center)
	player:SetAttribute("RunnerSpawnPosition", cframe.Position)
	player.RespawnLocation = data.spawn
	data.courseVersion = courseVersion
	data.boostVersion = (data.boostVersion or 0) + 1
	data.lastFlip = nil
	data.recoveryVersion = (data.recoveryVersion or 0) + 1
	data.safePoints = { { cframe = cframe, x = cframe.Position.X, sign = sign } }
	data.root.CFrame = cframe
	data.root.AssemblyLinearVelocity = Vector3.zero
	data.root.AssemblyAngularVelocity = Vector3.zero
	data.root.Anchored = true
	data.humanoid.AutoRotate = false
	data.humanoid.JumpPower = 0
	data.humanoid.JumpHeight = 0
	data.humanoid.PlatformStand = true
	player:SetAttribute("GravitySign", sign)
	player:SetAttribute("RunnerReady", false)
	player:SetAttribute("RunnerSpeedMultiplier", 1)
	player:SetAttribute(config.SecondLifeAttribute, 0)
	data.ready = false
	data.speedMultiplier = 1
	data.recovering = false
	data.invulnerableUntil = 0
	setStatus(player, data.courseStreamReady == courseVersion
		and player:GetAttribute("GBloxCourseReady") and "Waiting" or "Loading")
	addRunnerForces(data)
	data.velocity.LineVelocity = 0
	player:SetAttribute("RunnerCourseVersion", courseVersion)
end

local function assignSpawn(player)
	local data = players[player]
	if not data then return end
	if data.spawn and data.spawn:IsDescendantOf(spawnFolder) then return end
	data.spawn = nil
	local used = {}
	for other, otherData in players do
		if other ~= player and otherData.spawn then used[otherData.spawn] = true end
	end
	for index, spawn in spawns do
		if not used[spawn] then
			data.spawn = spawn
			data.spawnIndex = index
			player.RespawnLocation = spawn
			player:SetAttribute("RunnerSpawnIndex", index)
			return
		end
	end
	setStatus(player, "Spectating")
end


local function allReady()
	local count = 0
	for player, data in players do
		if player:GetAttribute("GBloxCourseReady") and data.spawn
			and data.root and data.root.Parent and data.humanoid and data.humanoid.Health > 0
			and data.courseStreamReady == courseVersion then
			count += 1
			if not data.ready then return false, count end
		end
	end
	return count >= expectedPlayers, count
end


local function broadcastState(extra)
	local packet = extra or {}
	packet.phase = roundPhase
	packet.courseNumber = courseNumber
	packet.courseVersion = courseVersion
	packet.courseCenter = descriptor.center
	packet.finishDeadline = finishDeadline
	event:FireAllClients("State", packet)
end

local function resetRound()
	-- Called exactly once per transition. Never recycle old-course spawn references.
	local nextDescriptor, message = CourseRegistry.Resolve(workspace, courseNumber + 1, config.MaxPlayers)
	if courseNumber >= maxRounds then
		roundPhase = "MatchComplete"
		broadcastState({ message = "MATCH COMPLETE" })
		return
	end
	if not nextDescriptor then
		roundPhase = "AwaitingCourse"
		warn("[Runner] " .. message)
		broadcastState({ message = message })
		return
	end
	resetBoost()
	resetSecondLifeTokens()
	for _, connection in courseConnections do connection:Disconnect() end
	table.clear(courseConnections)
	table.clear(spikeModels)
	table.clear(spikePivots)
	table.clear(boostParts)
	table.clear(boostOriginal)
	table.clear(secondLifeTokens)
	courseNumber += 1
	courseVersion += 1
	descriptor = nextDescriptor
	course, spawnFolder = descriptor.course, descriptor.spawnFolder
	boundsFolder, endZone, boostFolder = descriptor.bounds, descriptor.finish, descriptor.boosts
	spawns = descriptor.spawns
	CourseRegistry.ActivateSpawns(workspace, descriptor)
	workspace:SetAttribute("RunnerCourseCenter", descriptor.center)
	workspace:SetAttribute("RunnerCourseNumber", courseNumber)
	countdownVersion += 1
	roundPhase = "Waiting"
	roundStartedAt, finishPlace = 0, 0
	roundWinner, finishDeadline = nil, nil
	bindCourse()
	local ordered = Players:GetPlayers()
	table.sort(ordered, function(a, b) return a.UserId < b.UserId end)
	for _, player in ordered do
		local data = players[player]
		if data then
			data.spawn, data.spawnIndex = nil, nil
			data.safePoints = {}
			data.courseStreamReady = nil
			data.ready = false
		end
	end
	expectedPlayers = math.min(#ordered, config.MaxPlayers)
	for _, player in ordered do
		local data = players[player]
		if data then
			assignSpawn(player)
			if data.root and data.root.Parent and data.humanoid.Health > 0 then
				placeAtSpawn(player)
			else
				setStatus(player, "Loading")
			end
		end
	end
	broadcastState()
end

local function endRound()
	if roundPhase ~= "Running" then return end
	roundPhase = "Intermission"
	finishDeadline = nil
	countdownVersion += 1
	local version = courseVersion
	for player, data in players do
		data.ready = false
		data.recovering = false
		data.recoveryVersion = (data.recoveryVersion or 0) + 1
		data.boostVersion = (data.boostVersion or 0) + 1
		if data.status == "Running" then
			setStatus(player, "Out")
			event:FireClient(player, "Out", { reason = "Round ended" })
		end
		removeRunnerForces(data)
		if data.root and data.root.Parent then
			data.root.Anchored = true
			data.root.AssemblyLinearVelocity = Vector3.zero
			data.root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	broadcastState({ message = "ROUND " .. courseNumber .. " COMPLETE" })
	task.delay(config.RoundResetDelay, function()
		if courseVersion == version and roundPhase == "Intermission" then resetRound() end
	end)
end

checkRoundComplete = function()
	if roundPhase ~= "Running" then return end
	for _, data in players do
		if data.status == "Running" then return end
	end
	endRound()
end

local function startRace(version)
	if version ~= countdownVersion then return end
	local ready = allReady()
	if not ready then return end
	roundPhase = "Running"

	roundStartedAt = workspace:GetServerTimeNow()
	roundWinner = nil
	finishPlace = 0
	for player, data in players do
		if data.ready and data.root and data.root.Parent then
			setStatus(player, "Running")
			data.root.Anchored = false
			setSpeed(data, 1)
			playRunAnimation(data)
		end
	end
	broadcastState()
end


local function finishPlayer(player)
	local data = players[player]
	if not data or data.status ~= "Running" then return end

	setStatus(player, "Finished")
	removeRunnerForces(data)
	data.root.Anchored = true

	finishPlace += 1

	local finishTime =
		math.max(
			workspace:GetServerTimeNow()
			- roundStartedAt,
			0
		)

	local isWinner = roundWinner == nil
	if isWinner then
		roundWinner = player
		finishDeadline = workspace:GetServerTimeNow() + (config.FinishGraceSeconds or 15)
	end
	-- Finishing a course is not an overall match win; rewards belong to match results.
	event:FireClient(player, "Finished", {
		Place = finishPlace,
		IsWinner = isWinner,
		TimeMs = math.floor(finishTime * 1000 + 0.5),
		CourseNumber = courseNumber,
	})
	checkRoundComplete()
	if roundPhase == "Running" then broadcastState() end
end


for index=1,6 do
 local player={UserId=100+index,Parent=true,attributes={GBloxCourseReady=true}}
 function player:SetAttribute(key,value) self.attributes[key]=value end
 function player:GetAttribute(key) return self.attributes[key] end
 table.insert(ordered,player)
 players[player]={player=player,status="Loading",ready=false,speedMultiplier=1,safePoints={},
  root={Parent=true},humanoid={Health=100}}
 assignSpawn(player)
 placeAtSpawn(player)
 assert(player.RespawnLocation==descriptor.spawns[index])
 assert(player.attributes.RunnerLaneZ==descriptor.spawns[index].Position.Z)
 assert(players[player].root.CFrame.Position==players[player].safePoints[1].cframe.Position)
end
assert(not allReady(), "Must wait for course streaming")
for player,data in players do data.courseStreamReady=courseVersion data.ready=true setStatus(player,"Waiting") end
assert(allReady())
startRace(countdownVersion)
assert(roundPhase=="Running")
finishPlayer(ordered[1])
assert(finishDeadline==115 and roundPhase=="Running", "First finish starts 15-second grace")
now=114.99
if finishDeadline and now>=finishDeadline then endRound() end
assert(roundPhase=="Running")
now=115
if finishDeadline and now>=finishDeadline then endRound() end
assert(roundPhase=="Intermission" and #delayed==1)
endRound()
assert(#delayed==1,"Transition must be scheduled once")
delayed[1].callback()
assert(courseNumber==2 and courseVersion==2 and roundPhase=="Waiting" and boundNumber==2)
local used={}
for player,data in players do
 assert(data.spawn:IsDescendantOf(nextDescriptor.spawnFolder))
 assert(not used[data.spawn], "Unique spawns")
 used[data.spawn]=true
 assert(player.RespawnLocation==data.spawn)
 assert(player.attributes.RunnerLaneZ < -4900)
 assert(data.safePoints[1].cframe.Position.Z==data.spawn.Position.Z)
 assert(data.status=="Loading" and data.courseStreamReady==nil)
 assert(not data.root.Anchored==false)
 data.courseStreamReady=2 data.ready=true setStatus(player,"Waiting")
end
assert(boundsFolder==nextDescriptor.bounds and endZone==nextDescriptor.finish)
startRace(countdownVersion)
for player in players do setStatus(player,"Out") end
checkRoundComplete()
assert(roundPhase=="Intermission" and #delayed==2, "All eliminated must end round")
delayed[2].callback()
assert(roundPhase=="AwaitingCourse" and courseNumber==2, "Missing course must not recycle Course 1")
courseNumber=5
roundPhase="Running"
endRound()
delayed[3].callback()
assert(roundPhase=="MatchComplete", "Stop after five rounds")
return "PASS: real course discovery; course-2 suffix sorting; six unique course-1 spawns; streaming gate; 15-second grace; one transition; six course-2 spawns; lane/checkpoint reset; active finish/bounds; all-out advance; missing-course hold; five-round stop."

