local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run InstallRuntime in Studio edit mode")

local sources = {
	["Rules"] = [=[local Rules = {}

function Rules.IsInside(x, y, z, halfX, halfY, halfZ)
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

function Rules.DepartureExpired(mustLeave, deadline, now)
	return mustLeave and deadline > 0 and now >= deadline
end

function Rules.CrossingResolved(unresolvedRunners)
	return unresolvedRunners == 0
end

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if timedOut or bulldogs + tagged == 0 then
		return "Runners"
	end
	return nil
end

function Rules.CanTag(phase, runnerRole, runnerDeparted, runnerArrived, inField, bulldogFrozen)
	return phase == "Crossing"
		and runnerRole == "Runner"
		and runnerDeparted
		and not runnerArrived
		and inField
		and not bulldogFrozen
end

return Rules
]=],
	["Service"] = [=[local Players = game:GetService("Players")
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
	self.mode = "Waiting"
	self.practiceOwner = nil
	self.botFolder = nil
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
	if record.isBot and record.character then
		local torso = record.character:FindFirstChild("Torso")
		if torso then
			torso.Color = role == "Bulldog" and BULLDOG_COLOR or RUNNER_COLOR
		end
	end
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
			if record.isBot then
				record.root:SetNetworkOwner(nil)
			else
				record.root:SetNetworkOwnershipAuto()
			end
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
	if self.practiceOwner == player then
		self:StopRound()
	end
	self:_publishCounts()
end

function Service:_readyPlayers()
	local players = {}
	for player, record in pairs(self.records) do
		if not record.isBot and player.Parent == Players and record.ready and alive(record) then
			table.insert(players, player)
		end
	end
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	return players
end

function Service:_createPracticeBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "BritishBulldogPracticeBots"
		self.botFolder:SetAttribute("BritishBulldogManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Bulldog" and "Practice Bulldog" or "Practice Runner " .. tostring(index) }
	function player:GetAttribute(name)
		return attributes[name]
	end
	function player:SetAttribute(name, value)
		attributes[name] = value
	end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("BBPracticeBot", true)
	local spawn = self:_spawnCFrame(role == "Bulldog" and "Bulldog" or "North", index + 1)
	local function bodyPart(name, size, offset, color, collidable)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = spawn * CFrame.new(offset)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = collidable
		part.CanTouch = false
		part.Parent = character
		return part
	end
	local bodyColor = role == "Bulldog" and BULLDOG_COLOR or RUNNER_COLOR
	local skin = Color3.fromRGB(255, 219, 119)
	local navy = Color3.fromRGB(33, 49, 74)
	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, false)
	root.Transparency = 1
	root.RootPriority = 127
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, true)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin, false)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin, false)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin, false)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), navy, false)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), navy, false)
	local function joint(name, first, second, offset)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = first
		motor.Part1 = second
		motor.C0 = CFrame.new(offset)
		motor.Parent = first
	end
	joint("RootJoint", root, torso, Vector3.zero)
	joint("Neck", torso, head, Vector3.new(0, 1.5, 0))
	joint("Right Shoulder", torso, rightArm, Vector3.new(1.5, 0, 0))
	joint("Left Shoulder", torso, leftArm, Vector3.new(-1.5, 0, 0))
	joint("Right Hip", torso, rightLeg, Vector3.new(0.5, -2, 0))
	joint("Left Hip", torso, leftLeg, Vector3.new(-0.5, -2, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = player.DisplayName
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 0
	humanoid.WalkSpeed = role == "Bulldog" and self:_setting("BulldogWalkSpeed", 18, 0) or self:_setting("RunnerWalkSpeed", 16, 0)
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = self.botFolder
	player.Character = character
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local record = {
		player = player,
		isBot = true,
		character = character,
		root = root,
		humanoid = humanoid,
		role = "Spectator",
		participating = false,
		ready = true,
		originalGroups = {},
		connections = {},
		characterConnections = {},
		spawnIndex = index + 1,
		arrived = false,
		departed = false,
		frozen = false,
		nextBotMoveAt = 0,
	}
	self.records[player] = record
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		self:_caught(record, "Practice bot eliminated")
	end))
	return player
end

function Service:_cleanupPracticeBots()
	local bots = {}
	for player, record in pairs(self.records) do
		if record.isBot then
			table.insert(bots, player)
		end
	end
	for _, player in ipairs(bots) do
		local record = self.records[player]
		disconnectAll(record.connections)
		disconnectAll(record.characterConnections)
		self.records[player] = nil
		if record.character then
			record.character:Destroy()
		end
	end
	if self.botFolder then
		self.botFolder:Destroy()
		self.botFolder = nil
	end
end

function Service:_drivePracticeBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target
			if bot.role == "Runner" and not bot.arrived then
				target = self:_spawnCFrame(self.destination, bot.spawnIndex).Position
			elseif bot.role == "Bulldog" then
				local nearest = math.huge
				for _, runner in pairs(self.records) do
					if runner.participating and alive(runner) and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local distance = (runner.root.Position - bot.root.Position).Magnitude
						if distance < nearest then
							nearest = distance
							target = runner.root.Position + runner.root.AssemblyLinearVelocity * 0.2
						end
					end
				end
				if target then
					local point = self.bounds.CFrame:PointToObjectSpace(target)
					local halfX = self.bounds.Size.X / 2 - 4
					target = self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -halfX, halfX), point.Y, math.clamp(point.Z, self.northZ + 4, self.southZ - 4)))
				end
			end
			if target then
				bot.humanoid:MoveTo(target)
			else
				bot.humanoid:MoveTo(bot.root.Position)
				bot.humanoid:Move(Vector3.zero)
			end
		end
	end
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
	self:_drivePracticeBots(now)
	local excluded = { self.bounds, self.safeZones.North, self.safeZones.South }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	for _, record in pairs(self.records) do
		if record.character then
			table.insert(excluded, record.character)
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
	self:_cleanupPracticeBots()
	self.active = false
	self.currentRound = nil
	self.mode = "Waiting"
	self.practiceOwner = nil
	self.endsAt = 0
	setAttribute(self.state, "EndsAt", 0)
	setAttribute(self.state, "CountdownValue", 0)
	setAttribute(self.state, "IntermissionEndsAt", 0)
	setAttribute(self.state, "Mode", self.mode)
	setAttribute(self.state, "PracticeOwnerUserId", 0)
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
			local role = token.roles and token.roles[player] or (index == firstBulldog and "Bulldog" or "Runner")
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
		if record and not record.isBot and not included[player] and player.Parent == Players and record.ready and alive(record) then
			included[player] = true
			table.insert(participants, player)
		end
	end
	if #participants < math.floor(self:_setting("MinimumPlayers", 2, 2)) then
		return false, "Not enough ready players"
	end
	return self:_beginRound(participants, "Round")
end

function Service:_beginRound(participants, mode, roles, owner)
	self.active = true
	local token = { roles = roles }
	self.currentRound = token
	self.mode = mode
	self.practiceOwner = owner
	setAttribute(self.state, "Mode", mode)
	setAttribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	setAttribute(self.state, "IntermissionEndsAt", 0)
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

function Service:StartPractice(player, role)
	if not self.running then
		return false, "Service is not running"
	end
	if self.active then
		return false, "A round is already running"
	end
	if role ~= "Runner" and role ~= "Bulldog" then
		return false, "Choose Runner or Bulldog practice"
	end
	local record = self.records[player]
	if not record or record.isBot or player.Parent ~= Players or not record.ready or not alive(record) then
		return false, "Your character is not ready yet"
	end
	local participants = { player }
	local roles = { [player] = role }
	local botRole = role == "Runner" and "Bulldog" or "Runner"
	local ok, failure = xpcall(function()
		for index = 1, role == "Runner" and 1 or 3 do
			local bot = self:_createPracticeBot(index, botRole)
			table.insert(participants, bot)
			roles[bot] = botRole
		end
	end, debug.traceback)
	if not ok then
		self:_cleanupPracticeBots()
		warn("British Bulldog practice failed: " .. tostring(failure))
		return false, "Practice bots could not be created"
	end
	return self:_beginRound(participants, "Practice" .. role, roles, player)
end

function Service:StopRound()
	if not self.active then
		return false, "No round is running"
	end
	self.currentRound = nil
	self:_cleanupRound()
	setAttribute(self.state, "WinnerTeam", "None")
	setAttribute(self.state, "WinnersText", "Round stopped by admin")
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
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", PracticeOwnerUserId = 0, EndsAt = 0, RoundDuration = self:_setting("RoundDuration", 180, 1), CountdownValue = 0, RunnerCount = 0, BulldogCount = 0, CrossingNumber = 0, RoundNumber = 0, WinnerTeam = "", WinnersText = "", Destination = "South", DepartureSeconds = self:_setting("DepartureSeconds", 5, 0.1), IntermissionEndsAt = 0 }) do
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
]=],
	["Bootstrap"] = [=[local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldogService = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local arena = workspace:WaitForChild("British Bulldog game")
local service = BritishBulldogService.new(arena)
local startRound = ServerScriptService:FindFirstChild("BritishBulldogStartRound")
if startRound then
	assert(startRound:IsA("BindableFunction"), "BritishBulldogStartRound must be a BindableFunction")
else
	startRound = Instance.new("BindableFunction")
	startRound.Name = "BritishBulldogStartRound"
	startRound.Parent = ServerScriptService
end
startRound:SetAttribute("Ready", false)
startRound.OnInvoke = function(selectedPlayers)
	if not startRound:GetAttribute("Ready") then
		return false, "British Bulldog service is not ready"
	end
	if selectedPlayers ~= nil and typeof(selectedPlayers) ~= "table" then
		return false, "Expected an array of players"
	end
	return service:StartRound(selectedPlayers)
end
service:Start()
local admin=require(ServerScriptService:WaitForChild("PlaygroundAdminService")).Start(service)
startRound:SetAttribute("Ready", true)
script:SetAttribute("Ready", true)
]=],
	["Admin"] = [=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")

local Admin={}
Admin.__index=Admin
local actions={StartRound=true,PracticeRunner=true,PracticeBulldog=true,StopRound=true,GetStatus=true}

function Admin.new(service,config,isStudio)
 return setmetatable({service=service,config=config,isStudio=isStudio,lastRequest={},lastStatus={},busy=false,connections={}},Admin)
end

function Admin:IsAuthorized(player)
 if self.isStudio then return true end
 local id=player.UserId
 if game.CreatorType==Enum.CreatorType.User and id==game.CreatorId then return true end
 if id==self.config:GetAttribute("AdminUserId") then return true end
 local extra=self.config:GetAttribute("ExtraAdminUserIds")
 if typeof(extra)=="string" then
  for value in string.gmatch(extra,"%d+") do if tonumber(value)==id then return true end end
 end
 return false
end

function Admin:Status(player,ok,message)
 return {
  ok=ok,
  message=message or "",
  phase=self.service.phase or "Waiting",
  mode=self.service.state:GetAttribute("Mode") or "Waiting",
  role=player:GetAttribute("BBRole") or "Spectator",
 }
end

function Admin:Handle(player,action)
 if not self:IsAuthorized(player) then return {ok=false,message="Admin access required."} end
 if typeof(action)~="string" or not actions[action] then return self:Status(player,false,"Unknown control.") end
 local now=os.clock()
 local timestamps=action=="GetStatus" and self.lastStatus or self.lastRequest
 local last=timestamps[player] or -math.huge
 local cooldown=action=="GetStatus" and 0.1 or 0.5
 if now-last<cooldown then return self:Status(player,false,"Please wait a moment.") end
 timestamps[player]=now
 if action=="GetStatus" then return self:Status(player,true,"Ready to play.") end
 if self.busy then return self:Status(player,false,"Another game command is finishing.") end
 self.busy=true
 local ok,success,message=pcall(function()
  if action=="StopRound" then
   return self.service:StopRound()
  elseif self.service.active then
   return false,"A game is running. Press Stop Game first."
  elseif action=="PracticeRunner" then
   local started,reason=self.service:StartPractice(player,"Runner")
   return started,started and "Starting as Runner against an AI Bulldog." or reason
  elseif action=="PracticeBulldog" then
   local started,reason=self.service:StartPractice(player,"Bulldog")
   return started,started and "Starting as Bulldog against AI Runners." or reason
  else
   local started,reason=self.service:StartRound()
   if not started and reason=="Not enough ready players" then
    reason="Play as Runner or Bulldog to test alone. A normal round needs two players."
   end
   return started,started and "Starting British Bulldog with all ready players." or reason
  end
 end)
 self.busy=false
 if not ok then
  warn("Playground admin command failed: "..tostring(success))
  return self:Status(player,false,"The game couldn't start. Try again.")
 end
 return self:Status(player,success==true,message or (success and "Done." or "The game is not ready yet."))
end

function Admin:Destroy()
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 table.clear(self.lastRequest)
 table.clear(self.lastStatus)
 if self.remote then self.remote.OnServerInvoke=nil end
end

function Admin.Start(service)
 local config=ServerStorage:WaitForChild("PlaygroundAdminConfig")
 local remote=ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
 local self=Admin.new(service,config,RunService:IsStudio())
 self.remote=remote
 remote.OnServerInvoke=function(player,action) return self:Handle(player,action) end
 local function bindPlayer(player)
  player:SetAttribute("PlaygroundAdmin",self:IsAuthorized(player))
 end
 table.insert(self.connections,Players.PlayerAdded:Connect(bindPlayer))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.lastRequest[player]=nil self.lastStatus[player]=nil end))
 for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
 table.insert(self.connections,config.AttributeChanged:Connect(function()
  for _,player in ipairs(Players:GetPlayers()) do bindPlayer(player) end
 end))
 return self
end

return Admin
]=],
	["Camera"] = [=[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local baseline
local currentDistance
local connections={}
local elapsed=0

local function restore()
 if not baseline then return end
 player.CameraMinZoomDistance=math.min(baseline.minimum,player.CameraMaxZoomDistance)
 player.CameraMaxZoomDistance=baseline.maximum
 player.CameraMinZoomDistance=baseline.minimum
 player.CameraMode=baseline.mode
 baseline=nil
 currentDistance=nil
end

local function update()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local inside=false
 if root and bounds and bounds:IsA("BasePart") then
  local point=bounds.CFrame:PointToObjectSpace(root.Position)
  local half=bounds.Size/2
  inside=math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z
 end
 if not inside and player:GetAttribute("BBParticipating")~=true then restore() return end
 local distance=arena and arena:GetAttribute("CameraZoomDistance")
 if typeof(distance)~="number" or distance~=distance then distance=30 end
 distance=math.clamp(distance,8,80)
 if not baseline then
  baseline={minimum=player.CameraMinZoomDistance,maximum=player.CameraMaxZoomDistance,mode=player.CameraMode}
 end
 if currentDistance~=distance then
  player.CameraMode=Enum.CameraMode.Classic
  player.CameraMinZoomDistance=math.min(distance,player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=distance
  player.CameraMinZoomDistance=distance
  currentDistance=distance
 end
end

table.insert(connections,player:GetAttributeChangedSignal("BBParticipating"):Connect(update))
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed>=0.2 then elapsed=0 update() end
end))
script.Destroying:Connect(function()
 for _,connection in ipairs(connections) do connection:Disconnect() end
 restore()
end)
update()
]=],
	["HUDController"] = [=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("BritishBulldogState")

local topCard = gui:WaitForChild("TopCard")
local topPanel = topCard:WaitForChild("Panel")
local timer = topPanel:WaitForChild("Timer")
local phaseLabel = topPanel:WaitForChild("PhaseLabel")
local bulldogChip = topPanel:WaitForChild("BulldogChip")
local runnerChip = topPanel:WaitForChild("RunnerChip")
local countdown = gui:WaitForChild("Countdown")
local rolePanel = gui:WaitForChild("RolePill"):WaitForChild("Panel")
local roleLabel = rolePanel:WaitForChild("RoleLabel")
local departure = gui:WaitForChild("Departure")
local departurePanel = departure:WaitForChild("Panel")
local departureSeconds = departurePanel:WaitForChild("SecondsBadge"):WaitForChild("Seconds")
local tagged = gui:WaitForChild("Tagged")
local taggedStatus = tagged:WaitForChild("Panel"):WaitForChild("Status")
local results = gui:WaitForChild("Results")
local resultPanel = results:WaitForChild("Panel")
local resultTitle = resultPanel:WaitForChild("Title")
local resultWinners = resultPanel:WaitForChild("WinnersScroll"):WaitForChild("Winners")

local colors = {
	Runner = Color3.fromRGB(42, 160, 255),
	Bulldog = Color3.fromRGB(255, 81, 92),
	Tagged = Color3.fromRGB(255, 204, 54),
	Spectator = Color3.fromRGB(122, 144, 177),
	Ink = Color3.fromRGB(24, 35, 62),
	White = Color3.fromRGB(255, 255, 255),
}

local previousPhase = nil
local previousRound = nil
local callEndsAt = 0
local musicStarted = false
local playingSound = nil
local playingSoundId = nil
local elapsed = 0
local connections = {}

local function numberAttribute(object, name, fallback)
	local value = object:GetAttribute(name)
	if typeof(value) == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	return fallback
end

local function textAttribute(object, name, fallback)
	local value = object:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end
	return fallback
end

local function stopMusic()
	if playingSound then
		playingSound:Stop()
	end
	playingSound = nil
	playingSoundId = nil
end

local function syncMusic(participating, phase)
	local sound = SoundService:FindFirstChild("BritishBulldogMusic")
	local canPlay = participating and musicStarted and (phase == "Countdown" or phase == "Crossing")
	canPlay = canPlay and sound and sound:IsA("Sound") and sound:GetAttribute("Enabled") == true
	canPlay = canPlay and sound.SoundId ~= "" and sound.SoundId ~= "rbxassetid://0"
	if not canPlay then
		stopMusic()
		return
	end
	if playingSound ~= sound or playingSoundId ~= sound.SoundId then
		stopMusic()
		playingSound = sound
		playingSoundId = sound.SoundId
		sound:Play()
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	local phase = textAttribute(state, "Phase", "Waiting")
	local round = numberAttribute(state, "RoundNumber", 0)
	local participating = player:GetAttribute("BBParticipating") == true
	local role = textAttribute(player, "BBRole", "Spectator")
	local active = phase == "Countdown" or phase == "Crossing" or phase == "Results"

	if round ~= previousRound then
		musicStarted = false
		callEndsAt = 0
		previousRound = round
	end
	if phase ~= previousPhase then
		if phase == "Crossing" then
			musicStarted = true
			if previousPhase == "Countdown" then
				callEndsAt = now + 0.9
			end
		elseif phase == "Waiting" or phase == "Intermission" or phase == "Results" then
			musicStarted = false
			callEndsAt = 0
		end
		previousPhase = phase
	end

	gui.Enabled = participating and active
	topCard.Visible = phase ~= "Results"
	gui.RolePill.Visible = phase ~= "Results"
	results.Visible = phase == "Results"
	tagged.Visible = role == "Tagged" and phase ~= "Results"

	local endsAt = numberAttribute(state, "EndsAt", 0)
	local timeLeft = math.max(0, math.ceil(endsAt - now))
	if phase == "Countdown" and endsAt <= 0 then
		timeLeft = math.max(0, math.ceil(numberAttribute(state, "RoundDuration", 180)))
	end
	local minutes = math.floor(timeLeft / 60)
	timer.Text = string.format("%d:%02d", minutes, timeLeft % 60)
	timer.TextColor3 = timeLeft <= 30 and colors.Bulldog or colors.Ink
	bulldogChip.Count.Text = tostring(math.max(0, math.floor(numberAttribute(state, "BulldogCount", 0))))
	runnerChip.Count.Text = tostring(math.max(0, math.floor(numberAttribute(state, "RunnerCount", 0))))
	bulldogChip.Caption.Text = numberAttribute(state, "BulldogCount", 0) == 1 and "BULLDOG" or "BULLDOGS"
	runnerChip.Caption.Text = numberAttribute(state, "RunnerCount", 0) == 1 and "RUNNER" or "RUNNERS"
	phaseLabel.Text = "CROSSING " .. tostring(math.max(1, math.floor(numberAttribute(state, "CrossingNumber", 1))))

	local roleColor = colors[role] or colors.Spectator
	rolePanel.BackgroundColor3 = roleColor
	roleLabel.TextColor3 = role == "Tagged" and colors.Ink or colors.White
	roleLabel.Text = string.upper(role)
	local status = textAttribute(player, "BBStatus", "")
	taggedStatus.Text = status ~= "" and status or "FROZEN"

	local deadline = numberAttribute(player, "BBDepartureEndsAt", 0)
	local departureTime = math.max(0, math.ceil(deadline - now))
	departure.Visible = participating and role == "Runner" and phase == "Crossing" and player:GetAttribute("BBMustLeave") == true and departureTime > 0
	departureSeconds.Text = tostring(departureTime)

	local count = math.floor(numberAttribute(state, "CountdownValue", 0))
	local counting = phase == "Countdown" and count >= 1 and count <= 3
	local called = phase == "Crossing" and now < callEndsAt
	countdown.Visible = counting or called
	countdown.Text = called and "BULLDOG!" or tostring(count)
	countdown.TextColor3 = called and colors.Tagged or colors.White

	local winnerTeam = textAttribute(state, "WinnerTeam", "None")
	if winnerTeam == "Bulldogs" then
		resultTitle.Text = "BULLDOGS WIN!"
		resultTitle.TextColor3 = colors.Bulldog
	elseif winnerTeam == "Runners" then
		resultTitle.Text = "SURVIVORS WIN!"
		resultTitle.TextColor3 = colors.Runner
	else
		resultTitle.Text = "ROUND FINISHED!"
		resultTitle.TextColor3 = colors.Ink
	end
	resultWinners.Text = textAttribute(state, "WinnersText", "")
	syncMusic(participating, phase)
end

table.insert(connections, state.AttributeChanged:Connect(update))
table.insert(connections, player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 2) == "BB" then
		update()
	end
end))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	elapsed += delta
	if elapsed >= 0.08 then
		elapsed = 0
		update()
	end
end))
script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	stopMusic()
end)

update()
]=],
	["AdminController"] = [=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local toggle = gui:WaitForChild("Toggle")
local panel = gui:WaitForChild("Panel")
local close = panel:WaitForChild("Close")
local content = panel:WaitForChild("Body"):WaitForChild("Content")
local card = content:WaitForChild("GameCard")
local status = card:WaitForChild("Status")
local message = content:WaitForChild("Message")
local buttons = {
	StartRound = card:WaitForChild("StartRound"),
	PracticeRunner = card:WaitForChild("PracticeRunner"),
	PracticeBulldog = card:WaitForChild("PracticeBulldog"),
	StopRound = content:WaitForChild("StopRound"),
}

local ink = Color3.fromRGB(24, 35, 62)
local muted = Color3.fromRGB(162, 169, 184)
local failureColor = Color3.fromRGB(171, 38, 57)
local busy = false
local lastResponse = {}
local state = nil
local stateConnections = {}
local connections = {}
local phaseNames = {
	Waiting = "Ready",
	Intermission = "Starting soon",
	Countdown = "Countdown",
	Crossing = "Playing",
	Results = "Round finished",
}
local modeNames = {
	Round = "Multiplayer",
	PracticeRunner = "Solo practice",
	PracticeBulldog = "Solo practice",
}

local function isAdmin()
	return player:GetAttribute("PlaygroundAdmin") == true
end

local function updateStatus()
	local phase = state and state:GetAttribute("Phase") or lastResponse.phase
	local mode = state and state:GetAttribute("Mode") or lastResponse.mode
	local role = player:GetAttribute("BBRole") or lastResponse.role
	local parts = {}
	if typeof(mode) == "string" and mode ~= "" then
		local friendlyMode = modeNames[mode]
		if friendlyMode then
			table.insert(parts, friendlyMode)
		end
	end
	if typeof(role) == "string" and role ~= "" and role ~= "Spectator" then
		table.insert(parts, role)
	end
	if typeof(phase) == "string" and phase ~= "" then
		table.insert(parts, phaseNames[phase] or phase)
	end
	status.Text = #parts > 0 and table.concat(parts, " · ") or "Waiting for server"
end

local function updateButtons()
	for _, control in pairs(buttons) do
		local enabled = isAdmin() and not busy
		control.Active = enabled
		control.Selectable = enabled
		control.AutoButtonColor = enabled
		local readyColor = control:GetAttribute("ReadyColor")
		control.BackgroundColor3 = enabled and readyColor or muted
	end
end

local function request(action)
	if not isAdmin() or busy then
		return
	end
	busy = true
	updateButtons()
	if action ~= "GetStatus" then
		message.Text = "Waiting for server..."
		message.TextColor3 = ink
	end

	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	local succeeded, response = false, nil
	if remote and remote:IsA("RemoteFunction") then
		succeeded, response = pcall(function()
			return remote:InvokeServer(action)
		end)
	end
	busy = false
	updateButtons()
	if not isAdmin() or not gui.Parent then
		return
	end
	if not succeeded or typeof(response) ~= "table" then
		message.Text = "Server unavailable. Try again."
		message.TextColor3 = failureColor
		return
	end

	lastResponse = response
	updateStatus()
	if typeof(response.message) == "string" and response.message ~= "" then
		message.Text = response.message
	else
		message.Text = response.ok == true and "Done." or "Could not start. Try again."
	end
	message.TextColor3 = response.ok == true and ink or failureColor
end

local function setOpen(open)
	panel.Visible = isAdmin() and open
	toggle.Text = panel.Visible and "CLOSE" or "ADMIN"
	if panel.Visible then
		updateStatus()
		task.spawn(request, "GetStatus")
	end
end

local function syncAccess()
	gui.Enabled = isAdmin()
	if not isAdmin() then
		setOpen(false)
	end
	updateButtons()
end

local function bindState(candidate)
	if candidate.Name ~= "BritishBulldogState" or state == candidate then
		return
	end
	for _, connection in ipairs(stateConnections) do
		connection:Disconnect()
	end
	table.clear(stateConnections)
	state = candidate
	for _, name in ipairs({ "Phase", "Mode" }) do
		table.insert(stateConnections, candidate:GetAttributeChangedSignal(name):Connect(updateStatus))
	end
	updateStatus()
end

for action, control in pairs(buttons) do
	table.insert(connections, control.Activated:Connect(function()
		request(action)
	end))
end
table.insert(connections, toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end))
table.insert(connections, close.Activated:Connect(function()
	setOpen(false)
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(syncAccess))
table.insert(connections, player:GetAttributeChangedSignal("BBRole"):Connect(updateStatus))
table.insert(connections, ReplicatedStorage.ChildAdded:Connect(bindState))
table.insert(connections, ReplicatedStorage.ChildRemoved:Connect(function(child)
	if child == state then
		for _, connection in ipairs(stateConnections) do
			connection:Disconnect()
		end
		table.clear(stateConnections)
		state = nil
		updateStatus()
	end
end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F6 and isAdmin() then
		setOpen(not panel.Visible)
	end
end))
table.insert(connections, script.Destroying:Connect(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(stateConnections) do
		connection:Disconnect()
	end
end))

local existingState = ReplicatedStorage:FindFirstChild("BritishBulldogState")
if existingState then
	bindState(existingState)
end
panel.Visible = false
syncAccess()
updateStatus()
]=],
}

local baseCaps = SecurityCapabilities.new(
	Enum.SecurityCapability.RunServerScript,
	Enum.SecurityCapability.RunClientScript,
	Enum.SecurityCapability.AccessOutsideWrite,
	Enum.SecurityCapability.CreateInstances,
	Enum.SecurityCapability.Basic,
	Enum.SecurityCapability.Physics,
	Enum.SecurityCapability.UI,
	Enum.SecurityCapability.Players,
	Enum.SecurityCapability.AvatarBehavior,
	Enum.SecurityCapability.AvatarAppearance,
	Enum.SecurityCapability.Environment,
	Enum.SecurityCapability.LegacySound,
	Enum.SecurityCapability.Audio
)
local remoteCaps = SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)
local adminClientAdditions = SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent, Enum.SecurityCapability.Input)
local installed = {}

local function install(className, name, source, parent, additions)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object:IsA(className), name .. " has an unexpected class")
		assert(object.Sandboxed, name .. " must retain its existing sandbox")
		if additions and not object.Capabilities:Contains(additions) then
			object.Capabilities = object.Capabilities:Add(additions)
		end
		object.Source = source
	else
		object = Instance.new(className)
		object.Name = name
		object.Capabilities = additions and baseCaps:Add(additions) or baseCaps
		object.Sandboxed = true
		object.Source = source
		object.Parent = parent
	end
	table.insert(installed, object:GetFullName())
	return object
end

local serverScripts = game:GetService("ServerScriptService")
local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")
local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local arena = workspace:FindFirstChild("British Bulldog game")
assert(arena, "British Bulldog arena is missing")

local config = serverStorage:FindFirstChild("PlaygroundAdminConfig")
if config then
	assert(config:IsA("Folder"), "PlaygroundAdminConfig must be a Folder")
else
	config = Instance.new("Folder")
	config.Name = "PlaygroundAdminConfig"
	config:SetAttribute("AdminUserId", 1201803949)
	config:SetAttribute("ExtraAdminUserIds", "")
	config.Parent = serverStorage
end
if config:GetAttribute("AdminUserId") == nil then
	config:SetAttribute("AdminUserId", 1201803949)
end
if config:GetAttribute("ExtraAdminUserIds") == nil then
	config:SetAttribute("ExtraAdminUserIds", "")
end

local remote = replicatedStorage:FindFirstChild("PlaygroundAdminRequest")
if remote then
	assert(remote:IsA("RemoteFunction"), "PlaygroundAdminRequest must be a RemoteFunction")
	assert(remote.Sandboxed, "PlaygroundAdminRequest must retain its sandbox")
	assert(remote.Capabilities:Contains(remoteCaps) and remoteCaps:Contains(remote.Capabilities),
		"PlaygroundAdminRequest must have only its existing RemoteEvent capability")
else
	remote = Instance.new("RemoteFunction")
	remote.Name = "PlaygroundAdminRequest"
	remote.Capabilities = remoteCaps
	remote.Sandboxed = true
	remote.Parent = replicatedStorage
end

local function buildHUD()
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local yellow = Color3.fromRGB(255, 204, 54)
local white = Color3.fromRGB(255, 255, 255)
local headlineFont = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local bodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent, thickness, mode, color)
	return make("UIStroke", "Outline", parent, {
		Color = color or ink,
		Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function label(parent, name, text, position, size, font, color, maxSize, minSize, zIndex)
	local object = make("TextLabel", name, parent, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or ink,
		FontFace = font or bodyFont,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = zIndex or 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = minSize or 10,
		MaxTextSize = maxSize or 32,
	})
	return object
end

local function card(parent, name, position, size, minSize, maxSize, color, zIndex)
	local container = make("Frame", name, parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex or 2,
	})
	make("UISizeConstraint", "SizeLimit", container, {
		MinSize = minSize,
		MaxSize = maxSize,
	})
	local shadow = make("Frame", "Shadow", container, {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		ZIndex = zIndex or 2,
	})
	corner(shadow, 16)
	local panel = make("Frame", "Panel", container, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or paper,
		BorderSizePixel = 0,
		ZIndex = (zIndex or 2) + 1,
	})
	corner(panel, 16)
	stroke(panel, 4)
	return container, panel
end

local assets = ReplicatedStorage:FindFirstChild("BritishBulldogAssets")
if not assets then
	assets = make("Folder", "BritishBulldogAssets", ReplicatedStorage)
end

local taggedTemplate = assets:FindFirstChild("TaggedTemplate")
if not taggedTemplate then
	taggedTemplate = make("BillboardGui", "TaggedTemplate", assets, {
		Size = UDim2.fromOffset(160, 54),
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
		AlwaysOnTop = false,
		MaxDistance = 85,
		Enabled = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local panel = make("Frame", "Panel", taggedTemplate, {
		Position = UDim2.fromScale(0.025, 0.06),
		Size = UDim2.fromScale(0.95, 0.84),
		BackgroundColor3 = yellow,
		BorderSizePixel = 0,
	})
	corner(panel, 13)
	stroke(panel, 3)
	label(panel, "TaggedLabel", "TAGGED", UDim2.fromScale(0.06, 0.10), UDim2.fromScale(0.88, 0.82), headlineFont, ink, 31, 12)
end

local music = SoundService:FindFirstChild("BritishBulldogMusic")
if not music then
	music = make("Sound", "BritishBulldogMusic", SoundService, {
		SoundId = "",
		Volume = 0.35,
		Looped = true,
		Playing = false,
	})
	music:SetAttribute("Enabled", false)
end

local existing = StarterGui:FindFirstChild("BritishBulldogHUD")
if existing then
	return {
		HUD = existing:GetFullName(),
		AlreadyExists = true,
		TaggedTemplate = taggedTemplate:GetFullName(),
		Music = music:GetFullName(),
	}
end

local gui = make("ScreenGui", "BritishBulldogHUD", StarterGui, {
	Enabled = false,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 15,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("LayoutVersion", 1)

local topCard, topPanel = card(gui, "TopCard", UDim2.fromScale(0.5, 0.025), UDim2.fromScale(0.44, 0.125), Vector2.new(290, 92), Vector2.new(600, 120), paper)
topCard.AnchorPoint = Vector2.new(0.5, 0)
label(topPanel, "GameTitle", "BRITISH BULLDOG", UDim2.fromScale(0.035, 0.06), UDim2.fromScale(0.93, 0.20), headlineFont, ink, 24, 12)

local bulldogChip = make("Frame", "BulldogChip", topPanel, {
	Position = UDim2.fromScale(0.025, 0.35),
	Size = UDim2.fromScale(0.30, 0.48),
	BackgroundColor3 = red,
	BorderSizePixel = 0,
	ZIndex = 4,
})
corner(bulldogChip, 11)
stroke(bulldogChip, 3)
label(bulldogChip, "Count", "1", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.29, 0.87), headlineFont, white, 38, 14, 5)
label(bulldogChip, "Caption", "BULLDOG", UDim2.fromScale(0.325, 0.23), UDim2.fromScale(0.635, 0.58), bodyFont, ink, 20, 9, 5)

local runnerChip = make("Frame", "RunnerChip", topPanel, {
	Position = UDim2.fromScale(0.675, 0.35),
	Size = UDim2.fromScale(0.30, 0.48),
	BackgroundColor3 = blue,
	BorderSizePixel = 0,
	ZIndex = 4,
})
corner(runnerChip, 11)
stroke(runnerChip, 3)
label(runnerChip, "Count", "23", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.29, 0.87), headlineFont, white, 38, 14, 5)
label(runnerChip, "Caption", "RUNNERS", UDim2.fromScale(0.325, 0.23), UDim2.fromScale(0.635, 0.58), bodyFont, ink, 20, 9, 5)

local timer = label(topPanel, "Timer", "3:00", UDim2.fromScale(0.35, 0.29), UDim2.fromScale(0.30, 0.48), headlineFont, ink, 51, 24)
label(topPanel, "PhaseLabel", "CROSSING 1", UDim2.fromScale(0.34, 0.79), UDim2.fromScale(0.32, 0.16), bodyFont, ink, 15, 9)

local countdown = label(gui, "Countdown", "3", UDim2.fromScale(0.225, 0.32), UDim2.fromScale(0.55, 0.24), headlineFont, white, 130, 20, 20)
countdown.Rotation = -3
countdown.Visible = false
stroke(countdown, 6, Enum.ApplyStrokeMode.Contextual)

local rolePill, rolePanel = card(gui, "RolePill", UDim2.fromScale(0.035, 0.965), UDim2.fromScale(0.23, 0.062), Vector2.new(150, 36), Vector2.new(300, 58), blue)
rolePill.AnchorPoint = Vector2.new(0, 1)
label(rolePanel, "RoleLabel", "RUNNER", UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.77), headlineFont, white, 31, 15)

local departure, departurePanel = card(gui, "Departure", UDim2.fromScale(0.5, 0.855), UDim2.fromScale(0.34, 0.092), Vector2.new(250, 62), Vector2.new(490, 100), yellow, 7)
departure.Visible = false
label(departurePanel, "Prompt", "LEAVE SAFE ZONE", UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.72, 0.78), bodyFont, ink, 28, 14, 9)
local secondsBadge = make("Frame", "SecondsBadge", departurePanel, {
	Position = UDim2.fromScale(0.795, 0.12),
	Size = UDim2.fromScale(0.175, 0.74),
	BackgroundColor3 = white,
	BorderSizePixel = 0,
	ZIndex = 9,
})
corner(secondsBadge, 11)
stroke(secondsBadge, 3)
label(secondsBadge, "Seconds", "5", UDim2.fromScale(0.10, 0.08), UDim2.fromScale(0.80, 0.84), headlineFont, ink, 52, 20, 10)

local tagged, taggedPanel = card(gui, "Tagged", UDim2.fromScale(0.5, 0.74), UDim2.fromScale(0.29, 0.12), Vector2.new(240, 74), Vector2.new(460, 120), yellow, 7)
tagged.Visible = false
label(taggedPanel, "Title", "TAGGED", UDim2.fromScale(0.06, 0.07), UDim2.fromScale(0.88, 0.54), headlineFont, ink, 46, 24, 9)
label(taggedPanel, "Status", "FROZEN", UDim2.fromScale(0.06, 0.65), UDim2.fromScale(0.88, 0.24), bodyFont, ink, 23, 12, 9)

local results, resultsPanel = card(gui, "Results", UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.55, 0.30), Vector2.new(290, 200), Vector2.new(720, 310), paper, 12)
results.Visible = false
label(resultsPanel, "RoundLabel", "ROUND FINISHED", UDim2.fromScale(0.08, 0.10), UDim2.fromScale(0.84, 0.13), bodyFont, ink, 23, 12, 14)
label(resultsPanel, "Title", "SURVIVORS WIN!", UDim2.fromScale(0.04, 0.28), UDim2.fromScale(0.92, 0.30), headlineFont, blue, 56, 24, 14)
local winnersScroll = make("ScrollingFrame", "WinnersScroll", resultsPanel, {
	Position = UDim2.fromScale(0.075, 0.63),
	Size = UDim2.fromScale(0.85, 0.29),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = ink,
	ZIndex = 14,
})
local winnersLabel = label(winnersScroll, "Winners", "Player names", UDim2.fromScale(0.03, 0), UDim2.fromScale(0.94, 0), bodyFont, ink, 28, 12, 15)
winnersLabel.TextScaled = false
winnersLabel.TextSize = 20
winnersLabel.AutomaticSize = Enum.AutomaticSize.Y
winnersLabel.TextYAlignment = Enum.TextYAlignment.Top

return {
	HUD = gui:GetFullName(),
	Descendants = #gui:GetDescendants(),
	Enabled = gui.Enabled,
	TaggedTemplate = taggedTemplate:GetFullName(),
	Music = music:GetFullName(),
	RuntimeScriptInstalled = false,
}

end
local function buildAdmin()
local StarterGui = game:GetService("StarterGui")

local existing = StarterGui:FindFirstChild("PlaygroundAdminPanel")
if existing then
	return { GUI = existing:GetFullName(), AlreadyExists = true }
end

local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local white = Color3.fromRGB(255, 255, 255)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local yellow = Color3.fromRGB(255, 204, 54)
local headlineFont = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local bodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent, thickness)
	make("UIStroke", "Outline", parent, {
		Color = ink,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function label(parent, name, text, position, size, font, color, maxTextSize)
	local object = make("TextLabel", name, parent, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or ink,
		FontFace = font or bodyFont,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = 10,
		MaxTextSize = maxTextSize or 24,
	})
	return object
end

local function button(parent, name, text, position, size, color, maxTextSize)
	local object = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = text,
		TextColor3 = ink,
		FontFace = headlineFont,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 4,
	})
	make("UITextSizeConstraint", "TextSizeLimit", object, {
		MinTextSize = 10,
		MaxTextSize = maxTextSize or 23,
	})
	make("UIPadding", "TextPadding", object, {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
	})
	corner(object, 11)
	stroke(object, 3)
	object:SetAttribute("ReadyColor", color)
	return object
end

local gui = make("ScreenGui", "PlaygroundAdminPanel", StarterGui, {
	Enabled = false,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("LayoutVersion", 2)

button(gui, "Toggle", "ADMIN", UDim2.fromOffset(16, 16), UDim2.fromOffset(112, 42), yellow, 24)

local panel = make("Frame", "Panel", gui, {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(0.34, 0, 0.72, 0),
	BackgroundColor3 = paper,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
})
make("UISizeConstraint", "SizeLimit", panel, {
	MinSize = Vector2.new(280, 190),
	MaxSize = Vector2.new(380, 470),
})
corner(panel, 16)
stroke(panel, 4)

label(panel, "Title", "PLAYGROUND ADMIN", UDim2.fromScale(0.055, 0.035), UDim2.fromScale(0.79, 0.075), headlineFont, ink, 28)
button(panel, "Close", "X", UDim2.fromScale(0.87, 0.025), UDim2.fromScale(0.085, 0.085), white, 23)

local body = make("ScrollingFrame", "Body", panel, {
	Position = UDim2.fromScale(0.045, 0.135),
	Size = UDim2.fromScale(0.91, 0.825),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = ink,
	ZIndex = 3,
})
local content = make("Frame", "Content", body, {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -14, 0, 380),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
})
local gameCard = make("Frame", "GameCard", content, {
	Size = UDim2.fromScale(1, 0.70),
	BackgroundColor3 = white,
	BorderSizePixel = 0,
	ZIndex = 3,
})
corner(gameCard, 13)
stroke(gameCard, 3)
label(gameCard, "GameTitle", "BRITISH BULLDOG", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.13), headlineFont, ink, 30)
label(gameCard, "Status", "Waiting for server", UDim2.fromScale(0.05, 0.18), UDim2.fromScale(0.9, 0.10), bodyFont, ink, 16)
button(gameCard, "StartRound", "START ROUND", UDim2.fromScale(0.05, 0.325), UDim2.fromScale(0.90, 0.18), yellow, 26)
label(gameCard, "StartCaption", "All ready players", UDim2.fromScale(0.05, 0.51), UDim2.fromScale(0.9, 0.065), bodyFont, ink, 14)
button(gameCard, "PracticeRunner", "PLAY AS RUNNER", UDim2.fromScale(0.05, 0.61), UDim2.fromScale(0.90, 0.16), blue, 23)
button(gameCard, "PracticeBulldog", "PLAY AS BULLDOG", UDim2.fromScale(0.05, 0.81), UDim2.fromScale(0.90, 0.16), red, 23)

button(content, "StopRound", "STOP / BACK TO LOBBY", UDim2.fromScale(0, 0.745), UDim2.fromScale(1, 0.12), red, 23)
local message = label(content, "Message", "Choose a mode to play.", UDim2.fromScale(0.01, 0.90), UDim2.fromScale(0.98, 0.09), bodyFont, ink, 16)
message.TextYAlignment = Enum.TextYAlignment.Top

return {
	GUI = gui:GetFullName(),
	Descendants = #gui:GetDescendants(),
	Enabled = gui.Enabled,
	RuntimeScriptInstalled = false,
}

end

if not starterGui:FindFirstChild("BritishBulldogHUD") then
	buildHUD()
end
if not starterGui:FindFirstChild("PlaygroundAdminPanel") then
	buildAdmin()
end
local hud = starterGui:FindFirstChild("BritishBulldogHUD")
local adminGui = starterGui:FindFirstChild("PlaygroundAdminPanel")
assert(hud and hud:IsA("ScreenGui"), "BritishBulldogHUD must be an editable ScreenGui")
assert(adminGui and adminGui:IsA("ScreenGui"), "PlaygroundAdminPanel must be an editable ScreenGui")
assert(adminGui:FindFirstChild("Panel") and adminGui.Panel:FindFirstChild("Body"),
	"PlaygroundAdminPanel needs the current authored scrolling layout")

install("ModuleScript", "BritishBulldogRules", sources.Rules, serverScripts)
install("ModuleScript", "BritishBulldogService", sources.Service, serverScripts)
install("ModuleScript", "PlaygroundAdminService", sources.Admin, serverScripts, remoteCaps)
install("LocalScript", "Controller", sources.HUDController, hud)
install("LocalScript", "Controller", sources.AdminController, adminGui, adminClientAdditions)
install("LocalScript", "BritishBulldogCamera", sources.Camera, starterPlayerScripts)
arena:SetAttribute("AutoStart", false)
install("Script", "BritishBulldogBootstrap", sources.Bootstrap, serverScripts, remoteCaps)

return {
	ScriptsInstalled = #installed,
	AdminGUI = adminGui:GetFullName(),
	AuthoredLayoutsPreserved = true,
	AutoStart = arena:GetAttribute("AutoStart"),
}
