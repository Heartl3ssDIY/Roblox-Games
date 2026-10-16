local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RopeMath = require(ReplicatedStorage:WaitForChild("SkippingRopeMath"))

local Service = {}
Service.__index = Service
local runningService

local function attribute(object, name, value)
	if object:GetAttribute(name) ~= value then object:SetAttribute(name, value) end
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function alive(record)
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent
		and record.humanoid and record.humanoid.Parent and record.humanoid.Health > 0
end

local function parts(folder)
	local result = {}
	for _, object in ipairs(folder:GetChildren()) do if object:IsA("BasePart") then table.insert(result, object) end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end

function Service.new(arena, config)
	local self = setmetatable({}, Service)
	self.arena, self.config = arena, type(config) == "table" and config or {}
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spectatorSpawns = parts(self.gameplay:WaitForChild("SpectatorSpawns"))
	self.entrySpawns = parts(self.gameplay:WaitForChild("EntrySpawns"))
	assert(#self.spectatorSpawns > 0 and #self.entrySpawns > 0, "Skipping Rope needs spectator and entry spawns")
	self.spectatorSeats = {}
	local grounds = arena:FindFirstChild("Grounds")
	local benches = grounds and grounds:FindFirstChild("SpectatorBenches")
	if benches then
		for _, seat in ipairs(benches:GetDescendants()) do
			if seat:IsA("Seat") then
				local index = seat:GetAttribute("SKSpectatorIndex")
				if typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= 24 then
					assert(not self.spectatorSeats[index], "Duplicate spectator seat")
					self.spectatorSeats[index] = seat
				end
			end
		end
	end
	self.lanes = {}
	for _, lane in ipairs(self.gameplay:WaitForChild("Lanes"):GetChildren()) do
		local index, origin, spots = lane:GetAttribute("LaneIndex"), lane:FindFirstChild("RopeOrigin"), lane:FindFirstChild("Spots")
		if typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= 3 and origin and origin:IsA("BasePart") and spots then
			assert(not self.lanes[index], "Duplicate rope lane")
			local positions = parts(spots)
			assert(#positions == 8, "Each rope lane needs eight spots")
			self.lanes[index] = { model = lane, origin = origin, spots = positions, settings = {
				halfSpan = lane:GetAttribute("RopeHalfSpan") or 26, flatHalfSpan = lane:GetAttribute("RopeFlatHalfSpan") or 16,
				radius = lane:GetAttribute("RopeRadius") or 8, pivotHeight = lane:GetAttribute("RopePivotHeight") or 8.8,
				period = 3.6, stepSeconds = 10, speedFactor = 1.05,
			} }
		end
	end
	for index = 1, 3 do assert(self.lanes[index], "Skipping Rope needs three lanes") end
	self.state = typeof(config) == "Instance" and config:IsA("Folder") and config or ReplicatedStorage:FindFirstChild("SkippingRopeState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name, self.state.Parent = "SkippingRopeState", ReplicatedStorage end
	self.records, self.connections = {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.startedAt, self.endsAt, self.roundNumber = 0, 0, 0
	self.tickAccumulator = 0
	return self
end

function Service:_setting(name, fallback, minimum, maximum)
	local value = self.config[name]
	if value == nil then value = self.arena:GetAttribute(name) end
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = fallback end
	return math.clamp(value, minimum or 0, maximum or math.huge)
end

function Service:_publish()
	local total, living, lanes = 0, 0, {0, 0, 0}
	for player, record in pairs(self.records) do
		if record.inRound and player.Parent == Players then
			total += 1
			if record.participating then living += 1 lanes[record.laneIndex] += 1 end
		end
	end
	attribute(self.state, "ParticipantCount", total)
	attribute(self.state, "AliveCount", living)
	for index = 1, 3 do attribute(self.state, "Lane" .. index .. "AliveCount", lanes[index]) end
	return living, total
end

function Service:_phase(phase)
	self.phase = phase
	attribute(self.state, "Phase", phase)
	self:_publish()
end

function Service:_stand(record)
	if not record.humanoid then return end
	local seat = record.humanoid.SeatPart or record.spectatorSeat
	record.spectatorSeat = nil
	record.humanoid.Sit = false
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld and weld:IsA("Weld") and weld.Part1 and record.character and weld.Part1:IsDescendantOf(record.character) then weld:Destroy() end
end

function Service:_teleport(record, target)
	if not alive(record) then return end
	self:_stand(record)
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	record.character:PivotTo(target * record.root.CFrame:Inverse() * record.character:GetPivot())
end

function Service:_sendSpectator(record)
	if not alive(record) then return end
	local index = (record.spawnIndex - 1) % #self.spectatorSpawns + 1
	self:_teleport(record, self.spectatorSpawns[index].CFrame)
	local seat = self.spectatorSeats[index]
	if seat and seat.Parent and not seat.Disabled and not seat.Occupant then
		seat:Sit(record.humanoid)
		record.humanoid.Sit = true
		record.spectatorSeat = seat
	end
end

function Service:_movement(record)
	if not alive(record) or not record.inRound then return end
	local locked = self.phase ~= "Playing"
	record.humanoid.WalkSpeed = record.participating and 0 or locked and 0 or record.original.WalkSpeed
	record.humanoid.AutoRotate = not record.participating and record.original.AutoRotate
	record.humanoid.JumpPower = locked and 0 or record.participating and self:_setting("JumpPower", 50, 35, 60) or record.original.JumpPower
	record.humanoid.JumpHeight = locked and 0 or record.participating and self:_setting("JumpHeight", 7.2, 5, 10) or record.original.JumpHeight
	if locked then record.humanoid.Jump = false end
	record.root.Anchored = false
end

function Service:_role(record, role)
	record.role = role
	attribute(record.player, "SKRole", role)
	attribute(record.player, "SKParticipating", record.participating == true)
	if record.character then attribute(record.character, "SKRole", role) end
	self:_movement(record)
end

function Service:_restoreCharacter(record)
	self:_stand(record)
	local original = record.original
	if original and record.humanoid and record.humanoid.Parent then
		local humanoid = record.humanoid
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = original.WalkSpeed, original.JumpPower, original.JumpHeight
		humanoid.AutoRotate = original.AutoRotate
		humanoid.HealthDisplayType = original.HealthDisplayType
		if humanoid.Health > 0 then humanoid.Health = math.min(humanoid.MaxHealth, record.roundHealth or original.Health) end
	end
	if original and record.root and record.root.Parent then record.root.Anchored = original.Anchored end
	record.previousPosition, record.previousAt, record.roundHealth = nil, nil, nil
end

function Service:_retire(record, reason)
	if not record.participating then return false end
	record.participating, record.hits = false, 2
	attribute(record.player, "SKHits", 2)
	attribute(record.player, "SKHealthPercent", 0)
	attribute(record.player, "SKEliminated", true)
	attribute(record.player, "SKResult", "Out")
	attribute(record.player, "SKOutReason", reason or "Rope")
	self:_role(record, "Spectator")
	if alive(record) then
		self:_sendSpectator(record)
	end
	self:_publish()
	return true
end

function Service:_hit(record, cycle, now)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record.participating
		or not alive(record) or (record.lastHitCycle and cycle <= record.lastHitCycle) then return false end
	record.lastHitCycle = cycle
	record.hits = (record.hits or 0) + 1
	attribute(record.player, "SKHitAt", now)
	attribute(record.player, "SKHits", record.hits)
	attribute(record.player, "SKHealthPercent", math.max(0, 100 - record.hits * 50))
	if record.hits >= 2 then return self:_retire(record, "Rope") end
	record.humanoid.Health = math.max(1, math.min(record.humanoid.MaxHealth, record.humanoid.MaxHealth * 0.5))
	return true
end

function Service:_sample(record, now)
	if not record.participating or not alive(record) then return end
	local lane = self.lanes[record.laneIndex]
	local position = lane.origin.CFrame:PointToObjectSpace(record.root.Position)
	local expected = lane.origin.CFrame:PointToObjectSpace(record.spot.Position)
	if math.abs(position.X - expected.X) > 2.75 or math.abs(position.Z - expected.Z) > 2.75 or position.Y < -5 or position.Y > 22 then
		local height = math.clamp(position.Y, expected.Y, expected.Y + 8)
		local target = lane.origin.CFrame * CFrame.new(expected.X, height, expected.Z)
		self:_teleport(record, target)
		position = lane.origin.CFrame:PointToObjectSpace(record.root.Position)
		record.previousPosition, record.previousAt = position, now
	end
	local firstAt, firstPosition = record.previousAt or now, record.previousPosition or position
	if now - firstAt > 0.35 then firstAt, firstPosition = now - 0.18, position end
	local leg = record.character:FindFirstChild("Left Leg") or record.character:FindFirstChild("Right Leg")
	local legHeight = record.humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") and leg.Size.Y or 0
	local lower = -(record.humanoid.HipHeight + legHeight + record.root.Size.Y * 0.5)
	local head = record.character:FindFirstChild("Head")
	local upper = 2.8
	if head and head:IsA("BasePart") then
		local headPosition = lane.origin.CFrame:PointToObjectSpace(head.Position)
		upper = math.clamp(headPosition.Y + head.Size.Y * 0.5 - position.Y, 1.5, 5)
	end
	local halfWidth = math.clamp(record.root.Size.X * 0.5, 0.5, 2)
	local halfDepth = math.clamp(record.root.Size.Z * 0.5 + 0.4, 0.6, 1.6)
	for _, cycle in ipairs(RopeMath.SweepAvatar(math.max(0, firstAt - self.startedAt), math.max(0, now - self.startedAt),
		firstPosition, position, lower, upper, halfWidth, halfDepth, lane.settings)) do
		self:_hit(record, cycle, now)
	end
	record.previousPosition, record.previousAt = position, now
end

function Service:_guardSpectator(record)
	if not record.inRound or record.participating or not alive(record) then return end
	for _, lane in ipairs(self.lanes) do
		local position = lane.origin.CFrame:PointToObjectSpace(record.root.Position)
		if math.abs(position.X) < lane.settings.halfSpan + 3 and math.abs(position.Z) < lane.settings.radius + 5 and position.Y > -5 and position.Y < 25 then
			self:_sendSpectator(record)
			return
		end
	end
end

function Service:_bindCharacter(record, character)
	self:_restoreCharacter(record)
	disconnect(record.characterConnections)
	record.character, record.ready = character, false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if self.records[record.player] ~= record or record.character ~= character or not character.Parent
		or not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	record.original = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate, Anchored = root.Anchored, Health = humanoid.Health, HealthDisplayType = humanoid.HealthDisplayType }
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.inRound then self:_retire(record, "Reset") end
	end))
	if record.inRound then
		if record.participating then self:_retire(record, "Reset") end
		self:_role(record, "Spectator")
		self:_sendSpectator(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, ready = false,
		inRound = false, participating = false, role = "", hits = 0 }
	self.records[player] = record
	for name, value in pairs({ SKParticipating = false, SKRole = "", SKEliminated = false, SKHits = 0,
		SKHealthPercent = 100, SKLane = 0, SKSpot = 0, SKResult = "", SKOutReason = "", SKHitAt = 0 }) do attribute(player, name, value) end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_bindCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character ~= character then return end
		if record.inRound then self:_retire(record, "Reset") end
		self:_restoreCharacter(record)
		record.ready = false
	end))
	if player.Character then task.spawn(function() self:_bindCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	self:_restoreCharacter(record)
	disconnect(record.connections) disconnect(record.characterConnections)
	self.records[player] = nil
	self:_publish()
end

function Service:_readyPlayers(selected)
	local ready, seen = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if not seen[player] and player.Parent == Players and alive(record) and not record.inRound
			and player:GetAttribute("PCDataReady") == true and not player:GetAttribute("PCAFK") and not player:GetAttribute("PCAFKRequested")
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
			and not player:GetAttribute("MDParticipating") and not player:GetAttribute("HSParticipating")
			and not player:GetAttribute("DGParticipating") and not player:GetAttribute("DGEliminated") then
			seen[player] = true table.insert(ready, player)
		end
	end
	for index = #ready, 2, -1 do local other = self.random:NextInteger(1, index) ready[index], ready[other] = ready[other], ready[index] end
	while #ready > self:_setting("MaxPlayers", 24, 2, 24) do table.remove(ready) end
	return ready
end

function Service:_begin(participants, practice)
	self.active, self.mode, self.currentRound = true, practice and "Practice" or "Round", {}
	self.startedAt, self.endsAt = 0, 0
	self.roundNumber += 1
	attribute(self.state, "Mode", self.mode)
	attribute(self.state, "RoundNumber", self.roundNumber)
	attribute(self.state, "StartedAt", 0)
	attribute(self.state, "FinishedAt", 0)
	attribute(self.state, "WinnersText", "")
	self:_phase("Countdown")
	for index, player in ipairs(participants) do
		local record = self.records[player]
		local laneIndex, spotIndex = (index - 1) % 3 + 1, math.floor((index - 1) / 3) + 1
		record.roundHealth = record.humanoid.Health
		record.humanoid.Health = record.humanoid.MaxHealth
		record.inRound, record.participating, record.spawnIndex = true, true, index
		record.hits, record.lastHitCycle, record.laneIndex, record.spotIndex = 0, nil, laneIndex, spotIndex
		record.spot = self.lanes[laneIndex].spots[spotIndex]
		record.previousAt, record.previousPosition = nil, nil
		for name, value in pairs({ SKEliminated = false, SKHits = 0, SKHealthPercent = 100, SKLane = laneIndex,
			SKSpot = spotIndex, SKResult = "", SKOutReason = "", SKHitAt = 0 }) do attribute(player, name, value) end
		record.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		self:_role(record, "Jumper")
		self:_teleport(record, record.spot.CFrame)
	end
	self.countdownEndsAt = workspace:GetServerTimeNow() + self:_setting("CountdownSeconds", 8, 3, 15)
	attribute(self.state, "EndsAt", self.countdownEndsAt)
	attribute(self.state, "CountdownValue", math.ceil(self.countdownEndsAt - workspace:GetServerTimeNow()))
	self:_publish()
	return true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	local ready = self:_readyPlayers(selected)
	if #ready < self:_setting("MinimumPlayers", 2, 2, 24) then return false, "Not enough ready players" end
	local ok, result = xpcall(function() return self:_begin(ready) end, debug.traceback)
	if not ok then self:_cleanup() warn("Skipping Rope could not start: " .. tostring(result)) return false, "Skipping Rope could not prepare the round" end
	return result
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	if role ~= nil and role ~= "Jumper" then return false, "Choose the Jumper practice role" end
	if not self.records[player] then return false, "Player is not ready" end
	local ready = self:_readyPlayers({player})
	if #ready ~= 1 then return false, "Player is not ready for practice" end
	local ok, result = xpcall(function() return self:_begin(ready, true) end, debug.traceback)
	if not ok then self:_cleanup() warn("Skipping Rope practice could not start: " .. tostring(result)) return false, "Skipping Rope could not prepare practice" end
	return result
end

function Service:_finish(cancelled)
	if not self.active or self.phase == "Results" then return end
	local practice = cancelled == true or self.mode == "Practice"
	local winners, participants, names = {}, {}, {}
	for player, record in pairs(self.records) do
		if record.inRound and player.Parent == Players then
			local won = not cancelled and record.participating and alive(record)
			table.insert(participants, player.UserId)
			if won then table.insert(winners, player.UserId) table.insert(names, player.DisplayName) end
			attribute(player, "SKResult", cancelled and "Cancelled" or won and "Won" or "Lost")
		end
	end
	table.sort(winners) table.sort(participants) table.sort(names)
	attribute(self.state, "WinnersText", cancelled and "Round cancelled" or #winners > 0 and "Time's up! Jumpers win" or "Everybody is out")
	attribute(self.state, "WinnerNames", table.concat(names, ", "))
	attribute(self.state, "LastResultWinnerIds", table.concat(winners, ","))
	attribute(self.state, "LastResultParticipantIds", table.concat(participants, ","))
	attribute(self.state, "LastResultPractice", practice)
	attribute(self.state, "LastResultRound", self.roundNumber)
	local finishedAt = workspace:GetServerTimeNow()
	attribute(self.state, "FinishedAt", finishedAt)
	self.resultsEndsAt = finishedAt + self:_setting("ResultsSeconds", 7, 0, 15)
	attribute(self.state, "EndsAt", self.resultsEndsAt)
	self:_phase("Results")
	for _, record in pairs(self.records) do if record.inRound then self:_movement(record) end end
	local event = self.state:FindFirstChild("RoundFinished")
	if event and event:IsA("BindableEvent") then event:Fire({game = "SkippingRope", roundNumber = self.roundNumber,
		winnerUserIds = winners, participantUserIds = participants, practice = practice}) end
end

function Service:_tick()
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	if self.phase == "Results" then if now >= self.resultsEndsAt then self:_cleanup(self.currentRound) end return end
	local living, total = self:_publish()
	local minimum = self.mode == "Practice" and 1 or self:_setting("MinimumPlayers", 2, 2, 24)
	if total < minimum then self:_finish(true) return end
	if self.phase == "Countdown" then
		attribute(self.state, "CountdownValue", math.max(0, math.ceil(self.countdownEndsAt - now)))
		if now < self.countdownEndsAt then return end
		self.startedAt, self.endsAt = now, now + self:_setting("RoundDuration", 120, 120, 120)
		attribute(self.state, "StartedAt", now) attribute(self.state, "EndsAt", self.endsAt)
		self:_phase("Playing")
		for _, record in pairs(self.records) do
			if record.participating then record.previousAt = now self:_movement(record) end
		end
	end
	if self.phase ~= "Playing" then return end
	if now >= self.endsAt then self:_finish(false) return end
	attribute(self.state, "SpeedMultiplier", RopeMath.GetSpeedMultiplier(now - self.startedAt))
	for _, record in pairs(self.records) do
		if record.inRound then
			if record.participating and not alive(record) then self:_retire(record, "Reset")
			elseif record.participating then self:_movement(record) self:_sample(record, now)
			else self:_guardSpectator(record) end
		end
	end
	local survivors = self:_publish()
	if survivors == 0 then self:_finish(false) end
end

function Service:_cleanup(token)
	if token and token ~= self.currentRound then return end
	for _, record in pairs(self.records) do
		if record.inRound then
			self:_restoreCharacter(record)
			record.inRound, record.participating, record.role = false, false, ""
			record.spot, record.laneIndex, record.spotIndex = nil, nil, nil
			for name, value in pairs({ SKParticipating = false, SKRole = "", SKEliminated = false, SKHits = 0,
				SKHealthPercent = 100, SKLane = 0, SKSpot = 0 }) do attribute(record.player, name, value) end
			if record.character then attribute(record.character, "SKRole", "") end
			if self.lobbySpawn and self.lobbySpawn.Parent and alive(record) then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y * 0.5 + 3, 0)) end
		end
	end
	self.active, self.currentRound, self.mode, self.startedAt, self.endsAt = false, nil, "Waiting", 0, 0
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "StartedAt", 0) attribute(self.state, "EndsAt", 0)
	attribute(self.state, "FinishedAt", 0)
	attribute(self.state, "CountdownValue", 0) attribute(self.state, "SpeedMultiplier", 1)
	self:_phase("Waiting")
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end
	attribute(self.state, "LastResultPractice", true)
	attribute(self.state, "LastResultWinnerIds", "")
	self:_cleanup()
	attribute(self.state, "WinnersText", "Round stopped by admin")
	return true
end

function Service:Start()
	if self.running then return self end
	self.running, runningService = true, self
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", EndsAt = 0, StartedAt = 0, FinishedAt = 0, CountdownValue = 0,
		RoundNumber = 0, RoundDuration = 120, CountdownSeconds = self:_setting("CountdownSeconds", 8, 3, 15),
		MinimumPlayers = self:_setting("MinimumPlayers", 2, 2, 24), MaxPlayers = 24, ParticipantCount = 0, AliveCount = 0,
		SpeedMultiplier = 1, WinnersText = "", WinnerNames = "", LastResultWinnerIds = "", LastResultParticipantIds = "",
		LastResultPractice = true, LastResultRound = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator += dt
		if self.tickAccumulator < 0.033 then return end
		self.tickAccumulator = 0
		local ok, failure = xpcall(function() self:_tick() end, debug.traceback)
		if not ok then warn("Skipping Rope round failed: " .. tostring(failure)) self:_cleanup() end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Service:Stop()
	self.running = false
	self:_cleanup()
	disconnect(self.connections)
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end
	table.clear(self.records)
	if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end
return Service
