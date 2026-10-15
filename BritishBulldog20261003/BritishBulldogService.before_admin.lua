local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Rules = require(script.Parent:WaitForChild("BritishBulldogRules"))

local Service = {}
Service.__index = Service
local runningService

local ROLE_GROUPS = { Runner = "BBRunner", Bulldog = "BBBulldog", Tagged = "BBTagged" }
local RUNNER_COLOR = Color3.fromRGB(49, 173, 255)
local BULLDOG_COLOR = Color3.fromRGB(255, 72, 86)
local TAG_DISTANCE = 4.5

local function setAttribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local function partsIn(folder)
	local parts = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function alive(record)
	return record.character and record.character.Parent and record.root and record.root.Parent
		and record.humanoid and record.humanoid.Health > 0
end

function Service.new(arena)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.safeZones = {
		North = self.gameplay:WaitForChild("SafeNorth"),
		South = self.gameplay:WaitForChild("SafeSouth"),
	}
	self.spawnPads = {
		North = partsIn(self.gameplay:WaitForChild("RunnersNorth")),
		South = partsIn(self.gameplay:WaitForChild("RunnersSouth")),
		Bulldog = partsIn(self.gameplay:WaitForChild("BulldogSpawns")),
	}
	self.northZ = self.bounds.CFrame:PointToObjectSpace(self.gameplay:WaitForChild("NorthLine").Position).Z
	self.southZ = self.bounds.CFrame:PointToObjectSpace(self.gameplay:WaitForChild("SouthLine").Position).Z
	assert(self.northZ < self.southZ, "NorthLine must precede SouthLine in ArenaBounds local Z")
	assert(#self.spawnPads.North > 0 and #self.spawnPads.South > 0 and #self.spawnPads.Bulldog > 0, "Missing British Bulldog spawn pads")
	self.records = {}
	self.connections = {}
	self.random = Random.new()
	self.active = false
	self.running = false
	self.runGeneration = 0
	self.currentRound = nil
	self.phase = "Waiting"
	self.source = "North"
	self.destination = "South"
	self.endsAt = 0
	self.crossingNumber = 0
	self.roundNumber = 0
	self.tickAccumulator = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(arena) then
			self.lobbySpawn = descendant
			break
		end
	end
	local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
	if not state then
		state = Instance.new("Folder")
		state.Name = "BritishBulldogState"
		state.Parent = ReplicatedStorage
	end
	self.state = state
	return self
end

function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.max(minimum or 0, value)
end

function Service:_inside(part, position)
	local point = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return Rules.IsInside(point.X, point.Y, point.Z, half.X, half.Y, half.Z)
end

function Service:_inField(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	return math.abs(point.X) <= self.bounds.Size.X / 2
		and math.abs(point.Y) <= self.bounds.Size.Y / 2
		and point.Z > self.northZ and point.Z < self.southZ
end

function Service:_pastSource(position)
	local z = self.bounds.CFrame:PointToObjectSpace(position).Z
	return self.source == "North" and z > self.northZ or self.source == "South" and z < self.southZ
end

function Service:_counts()
	local runners, bulldogs, tagged, participants, unresolved = 0, 0, 0, 0, 0
	for _, record in pairs(self.records) do
		if record.participating then
			participants = participants + 1
			if record.role == "Runner" then
				runners = runners + 1
				if not record.arrived then
					unresolved = unresolved + 1
				end
			elseif record.role == "Bulldog" then
				bulldogs = bulldogs + 1
			elseif record.role == "Tagged" then
				tagged = tagged + 1
			end
		end
	end
	return runners, bulldogs, tagged, participants, unresolved
end

function Service:_publishCounts()
	local runners, bulldogs = self:_counts()
	setAttribute(self.state, "RunnerCount", runners)
	setAttribute(self.state, "BulldogCount", bulldogs)
end

function Service:_setPhase(phase)
	self.phase = phase
	setAttribute(self.state, "Phase", phase)
end

function Service:_collisionGroups()
	local supportsWorldGroups = pcall(function()
		workspace:IsCollisionGroupRegistered("BBRunner")
	end)
	local provider = supportsWorldGroups and workspace or PhysicsService
	for _, name in ipairs({ "BBRunner", "BBBulldog", "BBTagged", "BBBarrier" }) do
		if not provider:IsCollisionGroupRegistered(name) then
			provider:RegisterCollisionGroup(name)
		end
	end
	local characterGroups = { "BBRunner", "BBBulldog", "BBTagged" }
	for _, first in ipairs(characterGroups) do
		for _, second in ipairs(characterGroups) do
			provider:CollisionGroupSetCollidable(first, second, false)
		end
		provider:CollisionGroupSetCollidable(first, "BBBarrier", first == "BBBulldog")
	end
	provider:CollisionGroupSetCollidable("Default", "BBBarrier", false)
	local barriers = self.gameplay:FindFirstChild("BulldogBarriers")
	if barriers then
		for _, part in ipairs(barriers:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "BBBarrier"
			end
		end
	end
end

function Service:_assignCollision(record, part)
	if not record.participating or not part:IsA("BasePart") then
		return
	end
	if record.originalGroups[part] == nil then
		record.originalGroups[part] = part.CollisionGroup
	end
	part.CollisionGroup = ROLE_GROUPS[record.role] or "Default"
end

function Service:_visuals(record)
	local character = record.character
	if not character or not character.Parent then
		return
	end
	local outline = character:FindFirstChild("BBOutline")
	if record.participating then
		if not outline then
			outline = Instance.new("Highlight")
			outline.Name = "BBOutline"
			outline.Adornee = character
			outline.FillTransparency = 1
			outline.OutlineTransparency = 0
			outline.DepthMode = Enum.HighlightDepthMode.Occluded
			outline.Parent = character
		end
		outline.OutlineColor = record.role == "Bulldog" and BULLDOG_COLOR or RUNNER_COLOR
	elseif outline then
		outline:Destroy()
	end
	local tagged = character:FindFirstChild("BBTaggedLabel")
	if record.role == "Tagged" and record.participating then
		if not tagged then
			local assets = ReplicatedStorage:FindFirstChild("BritishBulldogAssets")
			local template = assets and assets:FindFirstChild("TaggedTemplate")
			if template and template:IsA("BillboardGui") then
				tagged = template:Clone()
				tagged.Name = "BBTaggedLabel"
				tagged.Adornee = character:FindFirstChild("Head") or record.root
				tagged.Enabled = true
				tagged.Parent = character
			end
		end
	elseif tagged then
		tagged:Destroy()
	end
end

function Service:_setRole(record, role, status)
	record.role = role
	if record.participating and record.humanoid and record.humanoid.Parent then
		if not record.originalWalkSpeed then
			record.originalWalkSpeed = record.humanoid.WalkSpeed
		end
		local speed = role == "Bulldog" and self:_setting("BulldogWalkSpeed", 18, 0) or self:_setting("RunnerWalkSpeed", 16, 0)
		if record.movement then
			record.movement.WalkSpeed = speed
		else
			record.humanoid.WalkSpeed = speed
		end
	end
	setAttribute(record.player, "BBRole", role)
	setAttribute(record.player, "BBParticipating", record.participating)
	setAttribute(record.player, "BBStatus", status or "")
	if record.character then
		for _, part in ipairs(record.character:GetDescendants()) do
			self:_assignCollision(record, part)
		end
	end
	self:_visuals(record)
	self:_publishCounts()
end

function Service:_departure(record, mustLeave, deadline)
	record.mustLeave = mustLeave
	record.departureEndsAt = deadline or 0
	setAttribute(record.player, "BBMustLeave", mustLeave)
	setAttribute(record.player, "BBDepartureEndsAt", record.departureEndsAt)
end

function Service:_freeze(record)
	if not alive(record) then
		record.frozen = true
		return
	end
	local humanoid = record.humanoid
	if not record.movement then
		record.movement = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
		}
	end
	record.frozen = true
	record.lockedCFrame = record.root.CFrame
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.Jump = false
	pcall(function()
		record.root:SetNetworkOwner(nil)
	end)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
end

function Service:_unfreeze(record)
	if record.movement and record.humanoid and record.humanoid.Parent then
		for name, value in pairs(record.movement) do
			record.humanoid[name] = value
		end
	end
	record.movement = nil
	record.frozen = false
	record.lockedCFrame = nil
	if record.root and record.root.Parent then
		pcall(function()
			record.root:SetNetworkOwnershipAuto()
		end)
	end
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then
		return
	end
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	if record.frozen then
		record.lockedCFrame = record.root.CFrame
	end
end

function Service:_spawnCFrame(side, index)
	local pads = self.spawnPads[side]
	local pad = pads[(index - 1) % #pads + 1]
	local position = pad.Position
	local direction = side == "North" and -self.bounds.CFrame.LookVector or self.bounds.CFrame.LookVector
	return CFrame.lookAt(position, position + direction)
end

function Service:_returnLobby(record)
	if self.lobbySpawn and self.lobbySpawn.Parent then
		self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0))
	end
end

function Service:_restoreCharacter(record)
	self:_unfreeze(record)
	if record.originalWalkSpeed and record.humanoid and record.humanoid.Parent then
		record.humanoid.WalkSpeed = record.originalWalkSpeed
	end
	record.originalWalkSpeed = nil
	for part, group in pairs(record.originalGroups) do
		if part.Parent then
			pcall(function()
				part.CollisionGroup = group
			end)
		end
	end
	table.clear(record.originalGroups)
	if record.character then
		for _, name in ipairs({ "BBOutline", "BBTaggedLabel" }) do
			local instance = record.character:FindFirstChild(name)
			if instance then
				instance:Destroy()
			end
		end
	end
end

function Service:_caught(record, status, now)
	now = now or workspace:GetServerTimeNow()
	if not self.active or not record.participating or record.role ~= "Runner" or self.phase == "Results" or (self.endsAt > 0 and now >= self.endsAt) then
		return
	end
	record.arrived = false
	record.departed = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Tagged", status or "Tagged")
	self:_freeze(record)
end

function Service:_forfeit(record, now)
	if record.role ~= "Runner" or (self.endsAt > 0 and now >= self.endsAt) then
		return
	end
	record.pendingBulldog = true
	record.arrived = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Bulldog", "Departure expired")
	self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
	self:_freeze(record)
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then
		return
	end
	record.characterGeneration = (record.characterGeneration or 0) + 1
	local generation = record.characterGeneration
	disconnectAll(record.characterConnections)
	self:_restoreCharacter(record)
	record.character = character
	record.root = nil
	record.humanoid = nil
	record.ready = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.characterGeneration ~= generation or record.character ~= character or record.player.Character ~= character or not humanoid or not root or not character.Parent then
		return
	end
	record.root = root
	record.humanoid = humanoid
	record.ready = true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(descendant)
		self:_assignCollision(record, descendant)
	end))
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		self:_caught(record, "Reset or eliminated")
	end))
	if record.participating then
		self:_setRole(record, record.role)
		if record.role == "Runner" then
			self:_teleport(record, self:_spawnCFrame(self.source, record.spawnIndex))
		else
			self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
		end
		if record.role == "Tagged" or record.pendingBulldog or self.phase == "Countdown" or self.phase == "Results" then
			self:_freeze(record)
		end
	elseif self.active then
		self:_returnLobby(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then
		return
	end
	local record = {
		player = player,
		role = "Spectator",
		participating = false,
		ready = false,
		originalGroups = {},
		connections = {},
		characterConnections = {},
		spawnIndex = 1,
		arrived = false,
		departed = false,
		frozen = false,
	}
	self.records[player] = record
	self:_setRole(record, "Spectator", self.active and "Next round" or "Waiting")
	self:_departure(record, false, 0)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			self:_setupCharacter(record, character)
		end)
	end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			self:_caught(record, "Reset or eliminated")
			record.ready = false
		end
	end))
	if player.Character then
		task.spawn(function()
			self:_setupCharacter(record, player.Character)
		end)
	end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then
		return
	end
	record.participating = false
	self:_restoreCharacter(record)
	disconnectAll(record.connections)
	disconnectAll(record.characterConnections)
	self.records[player] = nil
	self:_publishCounts()
end

function Service:_readyPlayers()
	local players = {}
	for player, record in pairs(self.records) do
		if player.Parent == Players and record.ready and alive(record) then
			table.insert(players, player)
		end
	end
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	return players
end

function Service:_keepBulldogInField(record)
	local root = record.root
	local position = self.bounds.CFrame:PointToObjectSpace(root.Position)
	local halfX = self.bounds.Size.X / 2 - 4
	local safeY = self.bounds.CFrame:PointToObjectSpace(self.spawnPads.Bulldog[1].Position).Y
	local y = position.Y
	if y < safeY - 10 or y > self.bounds.Size.Y / 2 then
		y = safeY
	end
	local corrected = Vector3.new(math.clamp(position.X, -halfX, halfX), y, math.clamp(position.Z, self.northZ + 4, self.southZ - 4))
	if (corrected - position).Magnitude > 0.01 then
		local target = self.bounds.CFrame:PointToWorldSpace(corrected)
		self:_teleport(record, CFrame.new(target) * root.CFrame.Rotation)
	end
end

function Service:_keepRunnerLegal(record, now)
	local position = record.root.Position
	if not self:_inside(self.bounds, position) then
		self:_caught(record, "Left the arena", now)
		self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
		return
	end
	if record.arrived then
		if not self:_inside(self.safeZones[self.destination], position) then
			self:_teleport(record, record.safeCFrame or self:_spawnCFrame(self.destination, record.spawnIndex))
		end
		return
	end
	if not record.departed then
		if self:_pastSource(position) then
			record.departed = true
			self:_departure(record, false, 0)
			setAttribute(record.player, "BBStatus", "Crossing")
		elseif Rules.DepartureExpired(record.mustLeave, record.departureEndsAt, now) then
			self:_forfeit(record, now)
			return
		end
	end
	if record.departed then
		if self:_inside(self.safeZones[self.source], position) or not self:_pastSource(position) then
			local fallback = record.lastFieldCFrame
			if not fallback then
				local point = self.bounds.CFrame:PointToObjectSpace(position)
				local z = self.source == "North" and self.northZ + 4 or self.southZ - 4
				local world = self.bounds.CFrame:PointToWorldSpace(Vector3.new(point.X, point.Y, z))
				fallback = CFrame.new(world) * record.root.CFrame.Rotation
			end
			self:_teleport(record, fallback)
			position = record.root.Position
		end
		if self:_inside(self.safeZones[self.destination], position) then
			record.arrived = true
			record.safeCFrame = record.root.CFrame
			setAttribute(record.player, "BBStatus", "Safe")
		elseif self:_inField(position) then
			record.lastFieldCFrame = record.root.CFrame
		end
	end
end

function Service:_tick()
	if not self.active then
		return
	end
	local now = workspace:GetServerTimeNow()
	local gameplayActive = self.phase == "Crossing" and self.endsAt > 0 and now < self.endsAt
	for _, record in pairs(self.records) do
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then
				if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then
					self:_teleport(record, record.lockedCFrame)
				end
				record.root.AssemblyLinearVelocity = Vector3.zero
				record.root.AssemblyAngularVelocity = Vector3.zero
				record.humanoid:Move(Vector3.zero)
			elseif record.role == "Bulldog" then
				self:_keepBulldogInField(record)
			elseif record.role == "Runner" and gameplayActive then
				self:_keepRunnerLegal(record, now)
			end
		end
	end
	if not gameplayActive then
		return
	end
	local excluded = { self.bounds, self.safeZones.North, self.safeZones.South }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = excluded
	rayParams.RespectCanCollide = true
	for _, runner in pairs(self.records) do
		if runner.participating and alive(runner) and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
			for _, bulldog in pairs(self.records) do
				if bulldog.participating and bulldog.role == "Bulldog" and not bulldog.frozen and alive(bulldog) and self:_inField(bulldog.root.Position) then
					local offset = runner.root.Position - bulldog.root.Position
					if offset.Magnitude <= TAG_DISTANCE and not workspace:Raycast(bulldog.root.Position, offset, rayParams) then
						self:_caught(runner, "Tagged", now)
						break
					end
				end
			end
		end
	end
end

function Service:_outcome()
	local runners, bulldogs, tagged, participants = self:_counts()
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt)
end

function Service:_isRound(token)
	return self.running and self.active and self.currentRound == token
end

function Service:_countdown(token)
	if not self:_isRound(token) then
		return false
	end
	self:_setPhase("Countdown")
	self.crossingNumber = self.crossingNumber + 1
	setAttribute(self.state, "CrossingNumber", self.crossingNumber)
	setAttribute(self.state, "Destination", self.destination)
	for _, record in pairs(self.records) do
		if record.participating then
			record.arrived = false
			record.departed = false
			record.safeCFrame = nil
			record.lastFieldCFrame = nil
			self:_departure(record, false, 0)
			setAttribute(record.player, "BBStatus", record.role == "Runner" and "Get ready" or "Bulldog")
			self:_freeze(record)
		end
	end
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do
		if not self:_isRound(token) then
			return false
		end
		setAttribute(self.state, "CountdownValue", number)
		local untilTime = workspace:GetServerTimeNow() + 1
		repeat
			if not self:_isRound(token) or self:_outcome() then
				return false
			end
			task.wait(0.05)
		until workspace:GetServerTimeNow() >= untilTime or not self:_isRound(token)
	end
	if not self:_isRound(token) then
		return false
	end
	setAttribute(self.state, "CountdownValue", 0)
	local callTime = workspace:GetServerTimeNow()
	if self.endsAt == 0 then
		self.endsAt = callTime + self:_setting("RoundDuration", 180, 1)
		setAttribute(self.state, "EndsAt", self.endsAt)
	end
	self:_setPhase("Crossing")
	local departureSeconds = self:_setting("DepartureSeconds", 5, 0.1)
	setAttribute(self.state, "DepartureSeconds", departureSeconds)
	for _, record in pairs(self.records) do
		if record.participating and record.role ~= "Tagged" and not record.pendingBulldog then
			self:_unfreeze(record)
			if record.role == "Runner" then
				self:_departure(record, true, callTime + departureSeconds)
				setAttribute(record.player, "BBStatus", "Leave the safe zone")
			end
		end
	end
	return true
end

function Service:_finishCrossing()
	for _, record in pairs(self.records) do
		if record.participating and (record.role == "Tagged" or record.pendingBulldog) then
			record.pendingBulldog = false
			self:_setRole(record, "Bulldog", "Bulldog")
			if alive(record) and not self:_inField(record.root.Position) then
				self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
			end
			self:_unfreeze(record)
		end
	end
	self.source, self.destination = self.destination, self.source
end

function Service:_results(outcome, token)
	if not self:_isRound(token) then
		return
	end
	local winners = {}
	for _, record in pairs(self.records) do
		if record.participating then
			self:_departure(record, false, 0)
			if record.role == "Tagged" then
				record.pendingBulldog = false
				self:_setRole(record, "Bulldog", "Bulldog")
				if alive(record) and not self:_inField(record.root.Position) then
					self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
				end
			end
			self:_freeze(record)
			if outcome == "Runners" and record.role == "Runner" then
				table.insert(winners, record.player.DisplayName)
				setAttribute(record.player, "BBStatus", "Survivor winner")
			elseif outcome == "Bulldogs" and record.role == "Bulldog" then
				table.insert(winners, record.player.DisplayName)
				setAttribute(record.player, "BBStatus", "Bulldog winner")
			end
		end
	end
	table.sort(winners)
	setAttribute(self.state, "WinnerTeam", outcome)
	setAttribute(self.state, "WinnersText", outcome == "None" and "Round cancelled" or table.concat(winners, ", "))
	setAttribute(self.state, "CountdownValue", 0)
	self:_publishCounts()
	self:_setPhase("Results")
	local resultsEnd = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_isRound(token) and workspace:GetServerTimeNow() < resultsEnd do
		task.wait(0.1)
	end
end

function Service:_cleanupRound(token)
	if token and self.currentRound ~= token then
		return
	end
	for _, record in pairs(self.records) do
		if record.participating then
			record.participating = false
			record.pendingBulldog = false
			self:_restoreCharacter(record)
			self:_departure(record, false, 0)
			self:_setRole(record, "Spectator", "Waiting")
			self:_returnLobby(record)
		end
	end
	self.active = false
	self.currentRound = nil
	self.endsAt = 0
	setAttribute(self.state, "EndsAt", 0)
	self:_setPhase("Waiting")
	self:_publishCounts()
end

function Service:_runRound(participants, token)
	if not self:_isRound(token) then
		return
	end
	self.roundNumber = self.roundNumber + 1
	self.source = "North"
	self.destination = "South"
	self.crossingNumber = 0
	self.endsAt = 0
	setAttribute(self.state, "RoundNumber", self.roundNumber)
	setAttribute(self.state, "EndsAt", self.endsAt)
	setAttribute(self.state, "RoundDuration", self:_setting("RoundDuration", 180, 1))
	setAttribute(self.state, "WinnerTeam", "")
	setAttribute(self.state, "WinnersText", "")
	local firstBulldog = self.random:NextInteger(1, #participants)
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating = true
			record.spawnIndex = index
			record.pendingBulldog = false
			record.arrived = false
			local role = index == firstBulldog and "Bulldog" or "Runner"
			self:_setRole(record, role, role)
			self:_teleport(record, self:_spawnCFrame(role == "Bulldog" and "Bulldog" or "North", index))
		end
	end
	self:_publishCounts()
	while self:_isRound(token) and not self:_outcome() do
		if not self:_countdown(token) then
			break
		end
		while self:_isRound(token) and not self:_outcome() do
			local _, _, _, _, unresolved = self:_counts()
			if Rules.CrossingResolved(unresolved) then
				break
			end
			task.wait(0.05)
		end
		if not self:_isRound(token) or self:_outcome() then
			break
		end
		self:_finishCrossing()
	end
	if self:_isRound(token) then
		self:_results(self:_outcome() or "None", token)
		if self:_isRound(token) then
			self:_cleanupRound(token)
		end
	end
end

function Service:StartRound(selectedPlayers)
	if not self.running then
		return false, "Service is not running"
	end
	if self.active then
		return false, "A round is already running"
	end
	local participants, included = {}, {}
	for _, player in ipairs(selectedPlayers or self:_readyPlayers()) do
		local record = self.records[player]
		if record and not included[player] and player.Parent == Players and record.ready and alive(record) then
			included[player] = true
			table.insert(participants, player)
		end
	end
	if #participants < math.floor(self:_setting("MinimumPlayers", 2, 2)) then
		return false, "Not enough ready players"
	end
	self.active = true
	local token = {}
	self.currentRound = token
	task.spawn(function()
		local ok, failure = xpcall(function()
			self:_runRound(participants, token)
		end, debug.traceback)
		if not ok then
			warn("British Bulldog round failed: " .. tostring(failure))
			self:_cleanupRound(token)
		end
	end)
	return true
end

function Service:_autoLoop(generation)
	while self.running and self.runGeneration == generation do
		if not self.active and self.arena:GetAttribute("AutoStart") ~= false then
			local minimum = math.floor(self:_setting("MinimumPlayers", 2, 2))
			if #self:_readyPlayers() >= minimum then
				self:_setPhase("Intermission")
				local untilTime = workspace:GetServerTimeNow() + self:_setting("IntermissionSeconds", 12, 0)
				setAttribute(self.state, "IntermissionEndsAt", untilTime)
				while self.running and self.runGeneration == generation and not self.active and self.arena:GetAttribute("AutoStart") ~= false and #self:_readyPlayers() >= minimum and workspace:GetServerTimeNow() < untilTime do
					task.wait(0.2)
				end
				if not self.running or self.runGeneration ~= generation then
					return
				end
				if not self.active then
					if self.running and self.arena:GetAttribute("AutoStart") ~= false and #self:_readyPlayers() >= minimum then
						self:StartRound()
					else
						self:_setPhase("Waiting")
					end
				end
			end
		end
		task.wait(0.25)
	end
end

function Service:Start()
	if self.running then
		return
	end
	self.running = true
	runningService = self
	self.runGeneration = self.runGeneration + 1
	local generation = self.runGeneration
	self:_collisionGroups()
	for name, value in pairs({ Phase = "Waiting", EndsAt = 0, RoundDuration = self:_setting("RoundDuration", 180, 1), CountdownValue = 0, RunnerCount = 0, BulldogCount = 0, CrossingNumber = 0, RoundNumber = 0, WinnerTeam = "", WinnersText = "", Destination = "South", DepartureSeconds = self:_setting("DepartureSeconds", 5, 0.1), IntermissionEndsAt = 0 }) do
		setAttribute(self.state, name, value)
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player)
		self:_addPlayer(player)
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player)
	end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator = self.tickAccumulator + dt
		if self.tickAccumulator >= 0.05 then
			self.tickAccumulator = 0
			self:_tick()
		end
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		self:_addPlayer(player)
	end
	task.spawn(function()
		self:_autoLoop(generation)
	end)
end

function Service:Stop()
	self.running = false
	self.runGeneration = self.runGeneration + 1
	self.currentRound = nil
	disconnectAll(self.connections)
	self:_cleanupRound()
	for _, record in pairs(self.records) do
		disconnectAll(record.connections)
		disconnectAll(record.characterConnections)
	end
	table.clear(self.records)
	if runningService == self then
		runningService = nil
	end
end

function Service.GetRunningService()
	return runningService
end

return Service


