local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Install movement and rewards in Studio edit mode")
local sources={
 ["BritishBulldogService"]=[=[local Players = game:GetService("Players")
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

function Service:_sprintCapacity(record)
	local maximum = record.participating and (record.role == "Bulldog" and record.initialBulldog
		and self:_setting("InitialBulldogSprintSeconds", 15, 0.1) or self:_setting("RunnerSprintSeconds", 10, 0.1)) or 0
	record.sprintMax = maximum
	record.sprintRemaining = math.clamp(record.sprintRemaining or maximum, 0, maximum)
	setAttribute(record.player, "BBInitialBulldog", record.initialBulldog == true)
	setAttribute(record.player, "BBSprintMax", maximum)
	setAttribute(record.player, "BBSprintRemaining", math.floor(record.sprintRemaining * 10) / 10)
end

function Service:_movementAllowed(record, now)
	if not self.active or self.phase ~= "Crossing" or now >= self.endsAt or not record.participating
		or record.frozen or record.pendingBulldog or not alive(record) then return false end
	if record.role == "Bulldog" then return self:_inField(record.root.Position) end
	return record.role == "Runner" and not record.arrived and self:_inside(self.bounds, record.root.Position)
end

function Service:_applyMovementSpeed(record, now)
	if not record.participating or not record.humanoid or not record.humanoid.Parent then return end
	local base = record.role == "Bulldog" and self:_setting("BulldogWalkSpeed", 18, 0) or self:_setting("RunnerWalkSpeed", 16, 0)
	local multiplier = 1
	if self:_movementAllowed(record, now) then
		if record.sprintHeld and not record.sprintExhausted and (record.sprintRemaining or 0) > 0
			and now < (record.sprintLeaseEndsAt or 0) then multiplier = self:_setting("SprintMultiplier", 2.5, 1) end
		if now < (record.boostEndsAt or 0) then multiplier = math.max(multiplier, self:_setting("DodgeBoostMultiplier", 2, 1)) end
	end
	if record.movement then record.movement.WalkSpeed = base end
	record.humanoid.WalkSpeed = record.frozen and 0 or base * multiplier
end

function Service:_publishMovement(record)
	setAttribute(record.player, "BBSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	setAttribute(record.player, "BBSprintMax", record.sprintMax or 0)
	setAttribute(record.player, "BBSprinting", record.sprinting == true)
	setAttribute(record.player, "BBSprintExhausted", record.sprintExhausted == true)
	setAttribute(record.player, "BBDodgeReadyAt", record.dodgeReadyAt or 0)
	setAttribute(record.player, "BBBoostEndsAt", record.boostEndsAt or 0)
end

function Service:_releaseSprint(record)
	record.sprintHeld = false
	record.sprinting = false
	record.sprintLeaseEndsAt = 0
end

function Service:_stopDodgeBurst(record, expected)
	local burst = expected or record.dodgeBurst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.dodgeBurst == burst then
		record.dodgeBurst = nil
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.isBot then
			pcall(function() burst.root:SetNetworkOwnershipAuto() end)
		end
	end
end

function Service:_cancelMovement(record)
	self:_releaseSprint(record)
	self:_stopDodgeBurst(record)
	record.boostEndsAt = 0
	record.pendingEscape = nil
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, workspace:GetServerTimeNow())
end

function Service:_movementRayParameters()
	local ignored = { self.bounds, self.safeZones.North, self.safeZones.South,
		self.gameplay.RunnersNorth, self.gameplay.RunnersSouth, self.gameplay.BulldogSpawns }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(ignored, player.Character) end
	end
	for _, record in pairs(self.records) do
		if record.character then table.insert(ignored, record.character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	params.CollisionGroup = "BBRunner"
	return params
end

function Service:_dodgeClear(record, direction, distance, params)
	local start = record.root.Position
	local finish = start + direction * distance
	local point = self.bounds.CFrame:PointToObjectSpace(finish)
	if math.abs(point.X) > self.bounds.Size.X / 2 - 3 or not self:_inField(finish) then return false end
	if workspace:Raycast(start, direction * (distance + 1.4), params) then return false end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	overlap.CollisionGroup = "BBRunner"
	local center = (start + finish) / 2
	local box = CFrame.lookAt(center, center + direction)
	return #workspace:GetPartBoundsInBox(box, Vector3.new(2.8, 5, distance + 2.8), overlap) == 0
end

function Service:_threat(record, params)
	for _, bulldog in pairs(self.records) do
		if bulldog.participating and bulldog.role == "Bulldog" and not bulldog.frozen and alive(bulldog)
			and self:_inField(bulldog.root.Position) then
			local offset = bulldog.root.Position - record.root.Position
			if offset.Magnitude <= 8 and not workspace:Raycast(record.root.Position, offset, params) then return true end
		end
	end
	return false
end

function Service:_startDodgeBurst(record, direction, now)
	self:_stopDodgeBurst(record)
	local root = record.root
	local attachment = Instance.new("Attachment")
	attachment.Name = "BBDodgeAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BBDodgeVelocity"
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X * 32, direction.Z * 32)
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	velocity.Parent = root
	local burst = { root = root, attachment = attachment, velocity = velocity,
		token = self.currentRound, crossing = self.crossingNumber, endsAt = now + 0.25 }
	record.dodgeBurst = burst
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity = direction * 32 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	burst.connection = RunService.Heartbeat:Connect(function()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or record.frozen or record.role ~= "Runner" or record.arrived or not alive(record)
			or workspace:GetServerTimeNow() >= burst.endsAt then self:_stopDodgeBurst(record, burst) end
	end)
end

function Service:_updateMovement(record, dt, now)
	if not record.participating then return end
	dt = math.clamp(dt, 0, 0.25)
	self:_sprintCapacity(record)
	if record.sprintHeld and now >= (record.sprintLeaseEndsAt or 0) then self:_releaseSprint(record) end
	local allowed = self:_movementAllowed(record, now)
	if not allowed then self:_releaseSprint(record) end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = allowed and record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
		if record.sprintRemaining == 0 then record.sprintExhausted = true record.sprinting = false end
	elseif record.sprintExhausted or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
		if record.sprintRemaining >= record.sprintMax - 0.0001 then
			record.sprintRemaining = record.sprintMax
			record.sprintExhausted = false
		end
	end
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, now)
end

function Service:_confirmEscape(record, now)
	local escape = record.pendingEscape
	if escape and now >= escape.checkAt then
		record.pendingEscape = nil
		if self:_movementAllowed(record, now) and record.role == "Runner" and self.currentRound == escape.token
			and self.crossingNumber == escape.crossing and record.character == escape.character
			and (record.root.Position - escape.startPosition).Magnitude >= 2 then
			record.boostEndsAt = now + self:_setting("DodgeBoostSeconds", 1.5, 0)
			setAttribute(record.player, "BBDodgeConfirmedAt", now)
		end
	end
	self:_publishMovement(record)
	self:_applyMovementSpeed(record, now)
end

function Service:Move(player, action, value)
	local record = self.records[player]
	if not record or record.isBot or player.Parent ~= Players then return { ok = false, message = "Your character is not ready." } end
	if action == "Sprint" and value == false then
		self:_releaseSprint(record)
		self:_publishMovement(record)
		self:_applyMovementSpeed(record, workspace:GetServerTimeNow())
		return { ok = true }
	end
	local now = workspace:GetServerTimeNow()
	if not self:_movementAllowed(record, now) then return { ok = false, message = "Wait for the crossing." } end
	if action == "Sprint" then
		if typeof(value) ~= "boolean" then return { ok = false, message = "Unknown sprint request." } end
		record.sprintHeld = true
		record.sprintLeaseEndsAt = now + 1
		self:_applyMovementSpeed(record, now)
		return { ok = true }
	end
	if action ~= "Dodge" or (value ~= -1 and value ~= 1) then return { ok = false, message = "Unknown move." } end
	if record.role ~= "Runner" or not record.departed or record.arrived or not self:_inField(record.root.Position)
		or record.humanoid.FloorMaterial == Enum.Material.Air then return { ok = false, message = "Dodge while crossing the field." } end
	if now < (record.dodgeReadyAt or 0) then return { ok = false, message = "Dodge is recharging." } end
	local right = self.bounds.CFrame.RightVector
	local direction = Vector3.new(right.X, 0, right.Z).Unit * value
	local params = self:_movementRayParameters()
	if not self:_dodgeClear(record, direction, 8, params) then return { ok = false, message = "No room to dodge." } end
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + 0.25, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	self:_startDodgeBurst(record, direction, now)
	record.dodgeReadyAt = now + self:_setting("DodgeCooldownSeconds", 4, 0.1)
	self:_publishMovement(record)
	return { ok = true }
end

function Service:_setRole(record, role, status)
	if record.participating and record.humanoid and record.humanoid.Parent and not record.originalWalkSpeed then
		record.originalWalkSpeed = record.humanoid.WalkSpeed
	end
	if record.role ~= role then self:_cancelMovement(record) end
	record.role = role
	if role == "Spectator" then record.initialBulldog = false record.sprintExhausted = false end
	self:_sprintCapacity(record)
	if record.participating and record.humanoid and record.humanoid.Parent then
		if not record.originalWalkSpeed then
			record.originalWalkSpeed = record.humanoid.WalkSpeed
		end
		self:_applyMovementSpeed(record, workspace:GetServerTimeNow())
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
	self:_cancelMovement(record)
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
	self:_applyMovementSpeed(record, workspace:GetServerTimeNow())
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
	self:_stopDodgeBurst(record)
	record.pendingEscape = nil
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
	self:_cancelMovement(record)
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

function Service:_tick(dt)
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
		self:_updateMovement(record, dt or 0.05, now)
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
	for _, record in pairs(self.records) do self:_confirmEscape(record, now) end
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
			record.initialBulldog = role == "Bulldog"
			record.sprintMax = role == "Bulldog" and self:_setting("InitialBulldogSprintSeconds", 15, 0.1) or self:_setting("RunnerSprintSeconds", 10, 0.1)
			record.sprintRemaining = record.sprintMax
			record.sprintHeld = false
			record.sprintExhausted = false
			record.sprintLeaseEndsAt = 0
			record.boostEndsAt = 0
			record.dodgeReadyAt = 0
			setAttribute(player, "BBDodgeConfirmedAt", 0)
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
			local elapsed = self.tickAccumulator
			self.tickAccumulator = 0
			self:_tick(elapsed)
		end
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		self:_addPlayer(player)
	end
	local movementRemote = ReplicatedStorage:FindFirstChild("BBMovementRequest")
	if movementRemote and movementRemote:IsA("RemoteFunction") then
		self.movementRemote = movementRemote
		movementRemote.OnServerInvoke = function(player, action, value) return self:Move(player, action, value) end
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
	if self.movementRemote then self.movementRemote.OnServerInvoke = nil end
	if runningService == self then
		runningService = nil
	end
end

function Service.GetRunningService()
	return runningService
end

return Service
]=],
 ["BritishBulldogHUD"]=[=[local Players = game:GetService("Players")
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
	gui.RolePill.Visible = phase ~= "Results" and not gui:FindFirstChild("MovementControls")
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
	local showDeparture = participating and role == "Runner" and phase == "Crossing" and player:GetAttribute("BBMustLeave") == true and departureTime > 0
	local compactDeparture = gui:FindFirstChild("CompactDeparture")
	local camera = workspace.CurrentCamera
	local useCompactDeparture = compactDeparture and camera and (camera.ViewportSize.X < 980 or camera.ViewportSize.Y < 450)
	departure.Visible = showDeparture and not useCompactDeparture
	if compactDeparture then
		compactDeparture.Visible = showDeparture and useCompactDeparture == true
		compactDeparture.Panel.SecondsBadge.Seconds.Text = tostring(departureTime)
	end
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
 ["TagService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(54, 174, 255), Tagger = Color3.fromRGB(255, 83, 100) }

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local function parts(folder)
	local result = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then table.insert(result, child) end
		end
	end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function alive(record)
	return record and record.ready and record.character and record.character.Parent
		and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end

function Service.new(arena)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spawnPads = parts(self.gameplay:WaitForChild("StartPads"))
	self.taggerSpawn = self.gameplay:WaitForChild("TaggerSpawn")
	self.navNodes = parts(self.gameplay:FindFirstChild("NavigationNodes"))
	assert(#self.spawnPads > 0, "Tag needs perimeter start pads")
	self.records = {}
	self.connections = {}
	self.random = Random.new()
	self.running = false
	self.active = false
	self.phase = "Waiting"
	self.mode = "Waiting"
	self.endsAt = 0
	self.roundNumber = 0
	self.lastTick = 0
	self.tickAccumulator = 0
	self.state = ReplicatedStorage:FindFirstChild("TagState")
	if not self.state then
		self.state = Instance.new("Folder")
		self.state.Name = "TagState"
		self.state.Parent = ReplicatedStorage
	end
	self.roundFinished = self.state:FindFirstChild("RoundFinished")
	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("SpawnLocation") and not instance:IsDescendantOf(arena) then
			self.lobbySpawn = instance
			break
		end
	end
	return self
end

function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(minimum or 0, value)
end

function Service:_phase(value)
	self.phase = value
	attribute(self.state, "Phase", value)
end

function Service:_counts()
	local count = 0
	for _, record in pairs(self.records) do
		if record.participating then count = count + 1 end
	end
	return count
end

function Service:_publish()
	attribute(self.state, "ParticipantCount", self:_counts())
	attribute(self.state, "RunnerCount", math.max(0, self:_counts() - (self.tagger and 1 or 0)))
	attribute(self.state, "TaggerName", self.tagger and self.tagger.player.DisplayName or "")
	attribute(self.state, "TaggerUserId", self.tagger and (self.tagger.player.UserId or 0) or 0)
	attribute(self.state, "TagCount", self.tagCount or 0)
end

function Service:_spawn(index, tagger)
	local pad = tagger and self.taggerSpawn or self.spawnPads[(index - 1) % #self.spawnPads + 1]
	local position = pad.Position
	local direction = self.taggerSpawn.Position - position
	if direction.Magnitude < 1 then direction = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, position + Vector3.new(direction.X, 0, direction.Z))
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_stopBurst(record)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_restore(record)
	self:_stopBurst(record)
	if record.originalMovement and record.humanoid and record.humanoid.Parent then
		for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end
	end
	record.originalMovement = nil
	record.frozen = false
	record.lockedCFrame = nil
	for part, group in pairs(record.originalGroups) do
		if part.Parent then pcall(function() part.CollisionGroup = group end) end
	end
	table.clear(record.originalGroups)
	if record.character then
		for _, name in ipairs({ "TGOutline", "TGTaggerLabel" }) do
			local object = record.character:FindFirstChild(name)
			if object then object:Destroy() end
		end
	end
	if record.root and record.root.Parent and not record.isBot then
		pcall(function() record.root:SetNetworkOwnershipAuto() end)
	end
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "TGPlayer"
end

function Service:_movement(record)
	if not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then
		record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
	end
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting(record.role == "Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed", record.role == "Tagger" and 18 or 16, 0)
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		self:_stopBurst(record)
		record.lockedCFrame = record.root.CFrame
		record.humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot and not record.burst then
		pcall(function() record.root:SetNetworkOwnershipAuto() end)
	end
end

function Service:_stopBurst(record, expected)
	local burst = expected or record.burst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.burst == burst then
		record.burst = nil
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.isBot then
			pcall(function() burst.root:SetNetworkOwnershipAuto() end)
		end
	end
end

function Service:_startBurst(record, horizontalVelocity, duration)
	self:_stopBurst(record)
	local root = record.root
	local attachment = Instance.new("Attachment")
	attachment.Name = "TGBurstAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "TGBurstVelocity"
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(horizontalVelocity.X, horizontalVelocity.Z)
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	velocity.Parent = root
	local burst = { root = root, attachment = attachment, velocity = velocity, token = self.currentRound,
		endsAt = workspace:GetServerTimeNow() + duration }
	record.burst = burst
	pcall(function() root:SetNetworkOwner(nil) end)
	burst.connection = RunService.Heartbeat:Connect(function()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.phase ~= "Playing" or record.frozen or not alive(record)
			or workspace:GetServerTimeNow() >= burst.endsAt then
			self:_stopBurst(record, burst)
		end
	end)
end

function Service:_role(record, role)
	record.role = role
	attribute(record.player, "TGParticipating", record.participating)
	attribute(record.player, "TGRole", role)
	attribute(record.player, "TGTaggerSeconds", record.taggerSeconds or 0)
	attribute(record.player, "TGProtectedEndsAt", record.protectedEndsAt or 0)
	self:_movement(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("TGOutline")
		if not outline then
			outline = Instance.new("Highlight")
			outline.Name = "TGOutline"
			outline.FillTransparency = 1
			outline.OutlineTransparency = 0
			outline.Adornee = record.character
			outline.DepthMode = Enum.HighlightDepthMode.Occluded
			outline.Parent = record.character
		end
		outline.OutlineColor = COLORS[role] or COLORS.Runner
		local assets = ReplicatedStorage:FindFirstChild("TagAssets")
		local label = record.character:FindFirstChild("TGTaggerLabel")
		if role == "Tagger" and not label and assets and assets:FindFirstChild("TaggerTemplate") then
			label = assets.TaggerTemplate:Clone()
			label.Name = "TGTaggerLabel"
			label.Adornee = record.character:FindFirstChild("Head") or record.root
			label.Enabled = true
			label.Parent = record.character
		elseif role ~= "Tagger" and label then label:Destroy() end
		if record.isBot and record.character:FindFirstChild("Torso") then
			record.character.Torso.Color = COLORS[role] or COLORS.Runner
		end
	end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, participating = false, role = "Spectator", ready = false,
		originalGroups = {}, connections = {}, characterConnections = {}, spawnIndex = 1,
		taggerSeconds = 0, protectedEndsAt = 0, moveCooldowns = {}, lastGoodCFrame = nil }
	self.records[player] = record
	self:_role(record, "Spectator")
	return record
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then return end
	record.generation = (record.generation or 0) + 1
	local generation = record.generation
	disconnect(record.characterConnections)
	self:_restore(record)
	record.character = character
	record.ready = false
	record.root = nil
	record.humanoid = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.generation ~= generation or record.player.Character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid = humanoid
	record.root = root
	record.ready = true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(part) self:_collision(record, part) end))
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.participating then
			record.ready = false
			record.taggerSeconds = record.taggerSeconds + self:_setting("RespawnPenaltySeconds", 5, 0)
			attribute(record.player, "TGTaggerSeconds", record.taggerSeconds)
		end
	end))
	if record.participating then
		record.frozen = self.phase ~= "Playing"
		record.protectedEndsAt = workspace:GetServerTimeNow() + 2
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.role == "Tagger"))
		self:_role(record, record.role)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function() self:_setupCharacter(record, character) end)
	end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then record.ready = false end
	end))
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	self:_account(workspace:GetServerTimeNow())
	record.participating = false
	self:_restore(record)
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self.records[player] = nil
	if self.practiceOwner == player then
		self:StopRound()
	elseif self.tagger == record then
		self.tagger = nil
		self:_replaceTagger(workspace:GetServerTimeNow())
	end
	self:_publish()
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and player.Parent == Players and alive(record) and player:GetAttribute("BBParticipating") ~= true then
			included[player] = true
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_account(now)
	if self.phase == "Playing" and self.tagger and self.tagger.participating then
		local untilTime = math.min(now, self.endsAt)
		local startedAt = math.max(self.lastAccountAt or untilTime, self.initialGraceEndsAt or 0)
		local elapsed = math.max(0, untilTime - startedAt)
		self.tagger.taggerSeconds = self.tagger.taggerSeconds + elapsed
		attribute(self.tagger.player, "TGTaggerSeconds", math.floor(self.tagger.taggerSeconds * 10) / 10)
	end
	self.lastAccountAt = now
end

function Service:_replaceTagger(now)
	local options = {}
	for _, record in pairs(self.records) do
		if record.participating then table.insert(options, record) end
	end
	if #options == 0 then return end
	table.sort(options, function(a, b)
		if a.taggerSeconds ~= b.taggerSeconds then return a.taggerSeconds < b.taggerSeconds end
		return a.spawnIndex < b.spawnIndex
	end)
	self.tagger = options[1]
	self.tagger.tagCooldownEndsAt = now + 1.2
	self:_role(self.tagger, "Tagger")
	self:_publish()
end

function Service:_rayParameters()
	local ignored = { self.bounds, self.taggerSpawn, self.gameplay.StartPads }
	local navigation = self.gameplay:FindFirstChild("NavigationNodes")
	if navigation then table.insert(ignored, navigation) end
	for _, record in pairs(self.records) do
		if record.character then table.insert(ignored, record.character) end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(ignored, player.Character) end
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = ignored
	parameters.RespectCanCollide = true
	return parameters
end

function Service:_canTag(from, target, now, rayParameters)
	if self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or target.role ~= "Runner"
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= self:_setting("TagDistance", 4.5, 1)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

function Service:_transfer(target, now)
	local previous = self.tagger
	self:_account(now)
	self.initialGraceEndsAt = 0
	attribute(self.state, "InitialGraceEndsAt", 0)
	previous.protectedEndsAt = now + self:_setting("TagBackProtectionSeconds", 2, 0.5)
	self:_role(previous, "Runner")
	self.tagger = target
	target.tagsMade = (target.tagsMade or 0)
	previous.tagsMade = (previous.tagsMade or 0) + 1
	target.protectedEndsAt = 0
	target.tagCooldownEndsAt = now + self:_setting("TagCooldownSeconds", 1.2, 0.5)
	self:_role(target, "Tagger")
	self.tagCount = self.tagCount + 1
	self:_publish()
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size / 2
	local spawnY = self.spawnPads[1].Position.Y
	local outside = math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3
	local wrongY = record.root.Position.Y < spawnY - 9 or math.abs(point.Y) > half.Y
	if outside or wrongY then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.role == "Tagger"))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then
		record.lastGoodCFrame = record.root.CFrame
	end
end

function Service:_newBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "TagPracticeBots"
		self.botFolder:SetAttribute("TagManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Tagger" and "Practice Tagger" or "Practice Runner " .. tostring(index), UserId = -index }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value) attributes[name] = value end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("TGPracticeBot", true)
	local spawn = self:_spawn(index * 5 + 1, role == "Tagger")
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
	local bodyColor = COLORS[role]
	local skin, navy = Color3.fromRGB(255, 219, 119), Color3.fromRGB(33, 49, 74)
	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, false)
	root.Transparency = 1
	root.RootPriority = 127
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.zero, bodyColor, true)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin, false)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin, false)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin, false)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), navy, false)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), navy, false)
	local function motor(name, first, second, offset)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0, joint.Part1 = first, second
		joint.C0 = CFrame.new(offset)
		joint.Parent = first
	end
	motor("RootJoint", root, torso, Vector3.zero)
	motor("Neck", torso, head, Vector3.new(0, 1.5, 0))
	motor("Right Shoulder", torso, rightArm, Vector3.new(1.5, 0, 0))
	motor("Left Shoulder", torso, leftArm, Vector3.new(-1.5, 0, 0))
	motor("Right Hip", torso, rightLeg, Vector3.new(0.5, -2, 0))
	motor("Left Hip", torso, leftLeg, Vector3.new(-0.5, -2, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = player.DisplayName
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = role == "Tagger" and 18 or 16
	humanoid.Parent = character
	character.PrimaryPart = root
	player.Character = character
	character.Parent = self.botFolder
	pcall(function() root:SetNetworkOwner(nil) end)
	local record = self:_record(player, true)
	record.character, record.root, record.humanoid, record.ready = character, root, humanoid, true
	record.nextBotMoveAt = 0
	record.nextPathAt = 0
	record.stuckSince = 0
	record.spawnIndex = index * 5 + 1
	record.template = character:Clone()
	return player
end

function Service:_respawnBot(record)
	if record.respawning or not record.template or not self.botFolder or not self.active then return end
	record.respawning = true
	self:_restore(record)
	disconnect(record.characterConnections)
	if record.character then record.character:Destroy() end
	local character = record.template:Clone()
	character.Parent = self.botFolder
	record.player.Character = character
	record.character = character
	record.root = character:FindFirstChild("HumanoidRootPart")
	record.humanoid = character:FindFirstChild("Humanoid")
	record.ready = true
	record.route = nil
	record.pathBusy = false
	record.nextPathAt = 0
	record.frozen = self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.role == "Tagger"))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_role(record, record.role)
	record.respawning = false
end

function Service:_clearBots()
	local remove = {}
	for player, record in pairs(self.records) do
		if record.isBot then
			disconnect(record.connections)
			disconnect(record.characterConnections)
			if record.template then record.template:Destroy() end
			table.insert(remove, player)
		end
	end
	for _, player in ipairs(remove) do self.records[player] = nil end
	if self.botFolder then self.botFolder:Destroy() self.botFolder = nil end
end

function Service:_fallbackRoute(startPosition, goal)
	local params = self:_rayParameters()
	if not workspace:Raycast(startPosition, goal - startPosition, params) then
		return { { Position = goal, Action = Enum.PathWaypointAction.Walk } }
	end
	local nodes, distances, previous, done = self.navNodes, {}, {}, {}
	local start, finish, startDistance, finishDistance
	for index, node in ipairs(nodes) do
		local first = (node.Position - startPosition).Magnitude
		local second = (node.Position - goal).Magnitude
		if not workspace:Raycast(startPosition, node.Position - startPosition, params) and (not startDistance or first < startDistance) then start, startDistance = index, first end
		if not workspace:Raycast(node.Position, goal - node.Position, params) and (not finishDistance or second < finishDistance) then finish, finishDistance = index, second end
	end
	if not start or not finish then return nil end
	distances[start] = 0
	local byName = {}
	for index, node in ipairs(nodes) do byName[node.Name] = index end
	for _ = 1, #nodes do
		local current, cost
		for index, distance in pairs(distances) do
			if not done[index] and (not cost or distance < cost) then current, cost = index, distance end
		end
		if not current or current == finish then break end
		done[current] = true
		local neighborNames = nodes[current]:GetAttribute("Neighbors") or nodes[current]:GetAttribute("Neighbor") or ""
		for name in string.gmatch(neighborNames, "[^,%s]+") do
			local neighbor = byName[name]
			if neighbor and not done[neighbor] then
				local alternative = cost + (nodes[neighbor].Position - nodes[current].Position).Magnitude
				if not distances[neighbor] or alternative < distances[neighbor] then
					distances[neighbor], previous[neighbor] = alternative, current
				end
			end
		end
	end
	if not distances[finish] then return nil end
	local reversed, current = {}, finish
	while current do
		table.insert(reversed, { Position = nodes[current].Position, Action = Enum.PathWaypointAction.Walk })
		current = previous[current]
	end
	local route = {}
	for index = #reversed, 1, -1 do table.insert(route, reversed[index]) end
	table.insert(route, { Position = goal, Action = Enum.PathWaypointAction.Walk })
	return route
end

function Service:_path(bot, goal, now)
	if bot.pathBusy or now < bot.nextPathAt then return end
	bot.pathBusy = true
	bot.nextPathAt = now + 1.2
	bot.pathGoal = goal
	local token = self.currentRound
	local character = bot.character
	local origin = bot.root.Position
	task.spawn(function()
		local route
		local ok = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
			path:Destroy()
		end)
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		if self.currentRound == token and self.records[bot.player] == bot and bot.character == character then
			bot.route, bot.routeIndex = route, 2
			if route and #route == 1 then bot.routeIndex = 1 end
			bot.pathBusy = false
		end
	end)
end

function Service:_botTarget(bot, now)
	if bot == self.tagger then
		local nearest, target
		for _, runner in pairs(self.records) do
			if runner.participating and runner.role == "Runner" and alive(runner) and now >= (runner.protectedEndsAt or 0) then
				local distance = (runner.root.Position - bot.root.Position).Magnitude
				if not nearest or distance < nearest then nearest, target = distance, runner.root.Position + runner.root.AssemblyLinearVelocity * 0.15 end
			end
		end
		return target
	end
	if not bot.escapeGoal or now >= (bot.nextEscapeAt or 0) or (bot.escapeGoal - bot.root.Position).Magnitude < 8 then
		local best, bestScore
		for _, pad in ipairs(self.spawnPads) do
			local taggerDistance = self.tagger and alive(self.tagger) and (pad.Position - self.tagger.root.Position).Magnitude or 100
			local travel = (pad.Position - bot.root.Position).Magnitude
			local score = taggerDistance - travel * 0.18 + self.random:NextNumber(0, 30)
			if travel > 24 and (not bestScore or score > bestScore) then best, bestScore = pad.Position, score end
		end
		bot.escapeGoal = best
		bot.nextEscapeAt = now + 5
	end
	return bot.escapeGoal
end

function Service:_driveBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local goal = self:_botTarget(bot, now)
			if goal then
				local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
				local destination = goal
				if not direct then
					self:_path(bot, goal, now)
					local route, index = bot.route, bot.routeIndex or 1
					while route and route[index] and (route[index].Position - bot.root.Position).Magnitude < 4 do index = index + 1 end
					bot.routeIndex = index
					local waypoint = route and route[index]
					if waypoint then
						destination = waypoint.Position
						if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
					else destination = bot.root.Position end
				end
				if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 then
					bot.stuckSince = bot.stuckSince + 0.2
					if bot.stuckSince > 0.8 then bot.humanoid.Jump = true bot.nextPathAt = 0 end
				else bot.stuckSince = 0 end
				bot.previousBotPosition = bot.root.Position
				bot.humanoid:MoveTo(destination)
			end
		end
	end
end

function Service:_tick()
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	self:_account(now)
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then
				if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end
				record.root.AssemblyLinearVelocity = Vector3.zero
				record.root.AssemblyAngularVelocity = Vector3.zero
				record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now)
	local params = self:_rayParameters()
	local nearest, candidate
	for _, record in pairs(self.records) do
		if self:_canTag(self.tagger, record, now, params) then
			local distance = (record.root.Position - self.tagger.root.Position).Magnitude
			if not nearest or distance < nearest then nearest, candidate = distance, record end
		end
	end
	if candidate then self:_transfer(candidate, now) end
end

function Service:Move(player, action)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if typeof(action) ~= "string" or (action ~= "Dodge" and action ~= "Vault") then return false, "Unknown move" end
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record or not record.participating or record.isBot or not alive(record) then return false, "Not in an active Tag game" end
	if now < (record.moveCooldowns[action] or 0) or record.humanoid.FloorMaterial == Enum.Material.Air then return false, "Move is not ready" end
	local forward = Vector3.new(record.root.CFrame.LookVector.X, 0, record.root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.1 then return false, "Face a direction first" end
	forward = forward.Unit
	local parameters = self:_rayParameters()
	local velocity, cooldown, duration
	if action == "Vault" then
		local feet = record.root.Position - Vector3.new(0, 2, 0)
		local obstruction = workspace:Raycast(feet, forward * 4.5, parameters)
		if not obstruction or not obstruction.Instance:IsA("BasePart") then return false, "Move near a low obstacle" end
		local top = workspace:Raycast(obstruction.Position + forward * 0.8 + Vector3.new(0, 7, 0), Vector3.new(0, -8, 0), parameters)
		if not top or top.Position.Y > feet.Y + 3 or top.Position.Y < feet.Y + 0.4 then return false, "That obstacle is too tall" end
		if workspace:Raycast(record.root.Position + Vector3.new(0, 5, 0), forward * 5, parameters) then return false, "No room to vault" end
		record.humanoid.Jump = true
		velocity, cooldown, duration = forward * 25 + Vector3.new(0, math.sqrt(2 * workspace.Gravity * 4.5), 0), 1.8, 0.40
	else
		if workspace:Raycast(record.root.Position, forward * 3, parameters) then return false, "No room to dodge" end
		velocity, cooldown, duration = forward * 32 + Vector3.new(0, math.max(0, record.root.AssemblyLinearVelocity.Y), 0), 3, 0.24
	end
	local root = record.root
	self:_startBurst(record, Vector3.new(velocity.X, 0, velocity.Z), duration)
	root.AssemblyLinearVelocity = velocity
	record.moveCooldowns[action] = now + cooldown
	attribute(player, "TG" .. action .. "ReadyAt", record.moveCooldowns[action])
	return true
end

function Service:_valid(token)
	return self.running and self.active and self.currentRound == token
end

function Service.SelectLosers(records, rule, tagger)
	local losers = {}
	if rule == "LastTagger" then
		if tagger and tagger.participating then losers[tagger] = true end
		return losers
	end
	local maximum = -1
	for _, record in pairs(records) do
		if record.participating then maximum = math.max(maximum, record.taggerSeconds or 0) end
	end
	if maximum < 0.001 and tagger and tagger.participating then
		losers[tagger] = true
		return losers
	end
	for _, record in pairs(records) do
		if record.participating and math.abs((record.taggerSeconds or 0) - maximum) < 0.001 then losers[record] = true end
	end
	return losers
end

function Service:_results(token)
	self:_account(self.endsAt)
	local losers = Service.SelectLosers(self.records, self.winRule, self.tagger)
	local winnerNames, loserNames, winnerIds, participantIds = {}, {}, {}, {}
	for _, record in pairs(self.records) do
		if record.participating then
			record.frozen = true
			self:_movement(record)
			if not record.isBot and record.player.Parent == Players then table.insert(participantIds, record.player.UserId) end
			attribute(record.player, "TGResult", losers[record] and "Lost" or "Won")
			if losers[record] then table.insert(loserNames, record.player.DisplayName)
			else
				table.insert(winnerNames, record.player.DisplayName)
				if not record.isBot and record.player.Parent == Players then table.insert(winnerIds, record.player.UserId) end
			end
		end
	end
	table.sort(winnerNames)
	table.sort(loserNames)
	table.sort(winnerIds)
	table.sort(participantIds)
	attribute(self.state, "WinnersText", table.concat(winnerNames, ", "))
	attribute(self.state, "LosersText", table.concat(loserNames, ", "))
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ","))
	attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ","))
	attribute(self.state, "LastResultPractice", self.mode ~= "Round")
	attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	if self.roundFinished and self.roundFinished:IsA("BindableEvent") then
		self.roundFinished:Fire({ roundNumber = self.roundNumber, winnerUserIds = winnerIds, participantUserIds = participantIds, practice = self.mode ~= "Round", game = "Tag" })
	end
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do
		if record.participating then
			record.participating = false
			self:_restore(record)
			record.protectedEndsAt = 0
			self:_role(record, "Spectator")
			if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then
				self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0))
			end
		end
	end
	self:_clearBots()
	self.active = false
	self.currentRound = nil
	self.tagger = nil
	self.mode = "Waiting"
	self.practiceOwner = nil
	self.endsAt = 0
	attribute(self.state, "Mode", "Waiting")
	attribute(self.state, "PracticeOwnerUserId", 0)
	attribute(self.state, "EndsAt", 0)
	attribute(self.state, "CountdownValue", 0)
	attribute(self.state, "InitialGraceEndsAt", 0)
	self:_phase("Waiting")
	self:_publish()
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber = self.roundNumber + 1
	self.tagCount = 0
	self.winRule = self.arena:GetAttribute("WinRule") == "LastTagger" and "LastTagger" or "MostTaggerTime"
	attribute(self.state, "RoundNumber", self.roundNumber)
	attribute(self.state, "WinRule", self.winRule)
	attribute(self.state, "WinnersText", "")
	attribute(self.state, "LosersText", "")
	attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 180, 1))
	local initial = token.firstTagger or participants[self.random:NextInteger(1, #participants)]
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating = true
			record.spawnIndex = record.isBot and record.spawnIndex or index
			record.taggerSeconds = 0
			record.tagsMade = 0
			record.protectedEndsAt = 0
			record.tagCooldownEndsAt = 0
			record.moveCooldowns = {}
			record.lastGoodCFrame = nil
			attribute(player, "TGResult", "")
			attribute(player, "TGVaultReadyAt", 0)
			attribute(player, "TGDodgeReadyAt", 0)
			record.frozen = true
			if player == initial then self.tagger = record end
			self:_role(record, player == initial and "Tagger" or "Runner")
			self:_teleport(record, self:_spawn(record.spawnIndex, player == initial))
		end
	end
	self:_publish()
	self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do
		if not self:_valid(token) then return end
		attribute(self.state, "CountdownValue", number)
		local untilTime = workspace:GetServerTimeNow() + 1
		while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end
	end
	if not self:_valid(token) then return end
	attribute(self.state, "CountdownValue", 0)
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 180, 1)
	self.lastAccountAt = workspace:GetServerTimeNow()
	self.initialGraceEndsAt = self.winRule == "MostTaggerTime" and self.lastAccountAt + self:_setting("InitialTaggerGraceSeconds", 8, 0) or 0
	attribute(self.state, "InitialGraceEndsAt", self.initialGraceEndsAt)
	attribute(self.state, "EndsAt", self.endsAt)
	self:_phase("Playing")
	for _, record in pairs(self.records) do
		if record.participating then record.frozen = false self:_movement(record) end
	end
	while self:_valid(token) and workspace:GetServerTimeNow() < self.endsAt and self:_counts() > 1 do task.wait(0.05) end
	if self:_valid(token) then
		if self:_counts() > 1 then self:_results(token) end
		self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, firstTagger, owner)
	self.active = true
	self.mode = mode
	self.practiceOwner = owner
	local token = { firstTagger = firstTagger }
	self.currentRound = token
	attribute(self.state, "Mode", mode)
	attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function()
		local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback)
		if not ok then warn("Tag round failed: " .. tostring(failure)) self:_cleanup(token) end
	end)
	return true
end

function Service:StartRound(selectedPlayers)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	local participants = self:_readyPlayers(selectedPlayers)
	if #participants < math.floor(self:_setting("MinimumPlayers", 2, 2)) then return false, "Not enough ready players" end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	if role ~= "Runner" and role ~= "Tagger" then return false, "Choose Runner or Tagger practice" end
	local record = self.records[player]
	if not record or record.isBot or player.Parent ~= Players or not alive(record) or player:GetAttribute("BBParticipating") == true then return false, "Your character is not ready yet" end
	local participants = { player }
	local firstTagger = role == "Tagger" and player or nil
	local ok, failure = xpcall(function()
		for index = 1, role == "Runner" and 1 or 3 do
			local bot = self:_newBot(index, role == "Runner" and "Tagger" or "Runner")
			table.insert(participants, bot)
			if role == "Runner" then firstTagger = bot end
		end
	end, debug.traceback)
	if not ok then self:_clearBots() warn("Tag practice failed: " .. tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, firstTagger, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end
	self.currentRound = nil
	self:_cleanup()
	attribute(self.state, "WinnersText", "Round stopped by admin")
	return true
end

function Service:Start()
	if self.running then return end
	self.running = true
	runningService = self
	local provider = PhysicsService
	local ok = pcall(function() workspace:IsCollisionGroupRegistered("TGPlayer") end)
	if ok then provider = workspace end
	if not provider:IsCollisionGroupRegistered("TGPlayer") then provider:RegisterCollisionGroup("TGPlayer") end
	provider:CollisionGroupSetCollidable("TGPlayer", "TGPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", EndsAt = 0, CountdownValue = 0, RoundNumber = 0,
		RoundDuration = self:_setting("RoundDuration", 180, 1), TaggerName = "", TaggerUserId = 0, RunnerCount = 0,
		ParticipantCount = 0, TagCount = 0, WinnersText = "", LosersText = "", PracticeOwnerUserId = 0,
		LastResultRound = 0, LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, WinRule = "MostTaggerTime", InitialGraceEndsAt = 0 }) do
		attribute(self.state, name, value)
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator = self.tickAccumulator + dt
		if self.tickAccumulator >= 0.05 then self.tickAccumulator = 0 self:_tick() end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	local remote = ReplicatedStorage:FindFirstChild("TagMovementRequest")
	if remote and remote:IsA("RemoteFunction") then
		self.movementRemote = remote
		remote.OnServerInvoke = function(player, action) return self:Move(player, action) end
	end
end

function Service:Stop()
	self.running = false
	self.currentRound = nil
	disconnect(self.connections)
	self:_cleanup()
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end
	table.clear(self.records)
	if self.movementRemote then self.movementRemote.OnServerInvoke = nil end
	if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end

return Service
]=],
 ["PlaygroundEconomyService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, UseEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
	local completed = 0
	local function cost(count) return count * base + step * count * (count - 1) / 2 end
	if step == 0 then
		completed = math.floor(xp / base)
	elseif xp > 0 then
		local linear = base - step / 2
		local root = math.sqrt(linear * linear + 2 * step * xp)
		completed = math.floor(linear >= 0 and 2 * xp / (root + linear) or (root - linear) / step)
		if cost(completed) > xp then completed = math.max(0, completed - 1) end
		if cost(completed + 1) <= xp then completed += 1 end
	end
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, Version = 2 }
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = Catalog.ById[id]
			if slots[slot] and item and item.slot == slot and result.Owned[id] then result.Equipped[slot] = id end
		end
	end
	return result
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 100), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do player:SetAttribute("PC" .. slot, profile.data.Equipped[slot] or "") end
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = profile.data.Equipped
	if equipped.Pet then
		local asset = self.assets:FindFirstChild(equipped.Pet)
		if asset then
			profile.pet = asset:Clone()
			profile.pet.Name = "Pet_" .. profile.player.UserId
			profile.pet.Parent = self.effects
			profile.pet:PivotTo(root.CFrame * CFrame.new(3, 0.5, 3))
		end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or profile.player:GetAttribute("TGParticipating") == true)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Coins", "Level" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_sync(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	return { ok = ok, message = message or "", coins = profile and profile.data.Coins or 0, xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP, owned = profile and table.clone(profile.data.Owned) or {}, equipped = profile and table.clone(profile.data.Equipped) or {}, ready = profile and profile.ready == true }
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "Unequip" then
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is coming soon.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!")
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return self:Status(player, false, "Try this between rounds.") end
		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:AwardRound(key, winnerIds, practice, participantIds)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", won and 100 or 25)
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then profile.data.Wins = integer(profile.data.Wins + 1, 0) end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin = Instance.new("Part")
			coin.Name = "Coin_" .. marker.Name
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.65, 2.8, 2.8)
			coin.Color = Color3.fromRGB(255, 207, 59)
			coin.Material = Enum.Material.SmoothPlastic
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanTouch = false
			coin.CanQuery = false
			coin.CFrame = marker.CFrame
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = math.clamp(integer(marker:GetAttribute("Value"), 2), 1, 10),
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin,
			})
		end
	end
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		coin.visual.CFrame = coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #coin.id) * 0.3, 0) * CFrame.Angles(0, now, 0)
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed then
			local participating = player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			if profile.pet and profile.pet.Parent then
				local target = root.CFrame * CFrame.new(3.4, math.sin(now * 3) * 0.3, 3)
				profile.pet:PivotTo(profile.pet:GetPivot():Lerp(target, 0.55))
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					if (root.Position - coin.marker.Position).Magnitude <= 5.5 and now - (profile.pickups[coin.id] or -math.huge) >= coin.cooldown then
						profile.pickups[coin.id] = now
						local beforeCoins = profile.data.Coins
						profile.data.Coins = integer(beforeCoins + coin.value, 0)
						self:_touch(profile)
						self:_publishReward(profile, profile.data.Coins - beforeCoins, 0, false, false)
					end
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if not profile.closed then self:_sync(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
return Economy
]=],
 ["PlaygroundCoordinator"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id].active then return id end end
	return nil
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and counts[id] then counts[id] += 1 end
	end
	for id, count in pairs(counts) do self.state:SetAttribute("Votes" .. id, count) end
	return counts
end

function Coordinator:_clearVotes()
	for player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute("PCVote", "") end end
	table.clear(self.votes)
	self:_counts()
end

function Coordinator:SetAutoEnabled(enabled)
	self.autoEnabled = enabled == true
	self.votingEndsAt = 0
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("VotingEndsAt", 0)
	if not self:ActiveGame() then
		self.state:SetAttribute("Phase", self.autoEnabled and "Waiting" or "Paused")
		self:_clearVotes()
	end
end

function Coordinator:Vote(player, id)
	if typeof(id) ~= "string" or not self.services[id] then return { ok = false, message = "Choose an available game." } end
	if self.state:GetAttribute("Phase") ~= "Voting" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = "Voting opens between rounds." } end
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, message = "Your character is loading." } end
	local now = os.clock()
	if now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = "Please wait a moment." } end
	self.lastVote[player] = now
	self.votes[player] = id
	player:SetAttribute("PCVote", id)
	self:_counts()
	return { ok = true, message = "Vote saved." }
end

function Coordinator:StartGame(id, player, role, automatic)
	local service = self.services[id]
	if not service then return false, "This game is not available yet." end
	if self:ActiveGame() then return false, "A game is running. Stop it first." end
	if not automatic then self:SetAutoEnabled(false) end
	self.votingEndsAt = 0
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_clearVotes()
	local started, reason
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.lastGame = id
		self.state:SetAttribute("ActiveGame", id)
		self.state:SetAttribute("GameTitle", titles[id])
		self.state:SetAttribute("Phase", "Playing")
	end
	return started, reason
end

function Coordinator:StopGame()
	local stopped = false
	for _, id in ipairs(games) do
		if self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local maximum = math.max(counts.BritishBulldog, counts.TagYoureIt)
	local tied = {}
	for _, id in ipairs(games) do if counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return tied[self.random:NextInteger(1, #tied)]
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	if team ~= "Runners" and team ~= "Bulldogs" then return end
	local winnerIds, participantIds = {}, {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and player.Parent == Players then
			table.insert(participantIds, player.UserId)
			if (team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog") then table.insert(winnerIds, player.UserId) end
		end
	end
	table.sort(winnerIds)
	table.sort(participantIds)
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds)
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants)
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
		local now = workspace:GetServerTimeNow()
		if active then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Playing")
			self.state:SetAttribute("ActiveGame", active)
			self.state:SetAttribute("GameTitle", titles[active])
			self.state:SetAttribute("VotingEndsAt", 0)
		elseif not self.autoEnabled then
			self.state:SetAttribute("Phase", "Paused")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
		elseif #self:_readyPlayers() < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			self.votingEndsAt = now + 20
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", true)
	self.state:SetAttribute("Phase", "Waiting")
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_counts()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundVoteRequest")
	remote.OnServerInvoke = function(player, id) return self:Vote(player, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Coordinator
]=],
 ["BBMovement"]=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local gui=script.Parent
local controls=gui:WaitForChild("MovementControls")
local meter=controls:WaitForChild("Meter")
local sprint=controls:WaitForChild("Sprint")
local dodge=controls:WaitForChild("Dodge")
local boost=controls:WaitForChild("EscapeBoost")
local gradient=meter.Track.Fill.Progress
local blue=Color3.fromRGB(42,160,255)
local red=Color3.fromRGB(255,81,92)
local yellow=Color3.fromRGB(255,204,54)
local actionName="BritishBulldogSprintHold"
local connections={}
local shiftKeys={}
local touchHold=nil
local focused=true
local alive=true
local bound=false
local lastKeepalive=0
local requestPending=nil
local requestRunning=false
local requestedHeld=false
local dodgeBusy=false
local lastDodgeDirection=1
local animation=nil
local lastConfirmed=player:GetAttribute("BBDodgeConfirmedAt") or 0

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(object,name,fallback)
 local value=object and object:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function phase()
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 return state and state:GetAttribute("Phase") or "Waiting"
end

local function inputContext()
 local current=phase()
 return player:GetAttribute("BBParticipating")==true and (current=="Countdown" or current=="Crossing")
end

local function canSprint()
 local role=player:GetAttribute("BBRole")
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return inputContext() and phase()=="Crossing" and (role=="Runner" or role=="Bulldog")
  and player:GetAttribute("BBStatus")~="Safe" and humanoid and humanoid.Health>0
end

local function requestSprint(value)
 requestPending=value==true
 if requestRunning then return end
 requestRunning=true
 task.spawn(function()
  while requestPending~=nil do
   local held=requestPending
   requestPending=nil
   local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
   if remote and remote:IsA("RemoteFunction") then
    pcall(function() remote:InvokeServer("Sprint",held) end)
   end
  end
  requestRunning=false
 end)
end

local function releaseHold()
 table.clear(shiftKeys)
 touchHold=nil
 requestedHeld=false
 requestSprint(false)
end

local function holdChanged()
 local held=focused and (next(shiftKeys)~=nil or touchHold~=nil) and canSprint()==true
 if held~=requestedHeld then
  requestedHeld=held
  requestSprint(held)
  lastKeepalive=os.clock()
 end
end

local function sprintAction(_,inputState,input)
 if not alive or not inputContext() then return Enum.ContextActionResult.Pass end
 if inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then
  shiftKeys[input.KeyCode]=nil
  holdChanged()
 elseif inputState==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  shiftKeys[input.KeyCode]=true
  holdChanged()
 end
 return Enum.ContextActionResult.Sink
end

local function syncBinding()
 local active=alive and inputContext()
 if active and not bound then
  ContextActionService:BindActionAtPriority(actionName,sprintAction,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  bound=true
 elseif not active and bound then
  ContextActionService:UnbindAction(actionName)
  bound=false
  releaseHold()
 end
end

local function progress(fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,0),
   NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),
   NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),
   NumberSequenceKeypoint.new(1,1),
  })
 end
end

local function arenaRight()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 return bounds and bounds:IsA("BasePart") and bounds.CFrame.RightVector or Vector3.xAxis
end

local function dodgeDirection()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local right=arenaRight()
 if humanoid then
  local lateral=humanoid.MoveDirection:Dot(right)
  if math.abs(lateral)>0.12 then return lateral<0 and -1 or 1 end
 end
 if not root then return 1 end
 local nearest=nil
 local distance=math.huge
 local function consider(candidate)
  local target=candidate and candidate:FindFirstChild("HumanoidRootPart")
  if target then
   local delta=target.Position-root.Position
   local squared=delta:Dot(delta)
   if squared<distance then distance=squared nearest=target end
  end
 end
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=player and other:GetAttribute("BBParticipating")==true and other:GetAttribute("BBRole")=="Bulldog" then consider(other.Character) end
 end
 local bots=workspace:FindFirstChild("BritishBulldogPracticeBots")
 if bots then
  for _,bot in ipairs(bots:GetChildren()) do
   local outline=bot:FindFirstChild("BBOutline")
   if outline and outline:IsA("Highlight") and outline.OutlineColor.R>outline.OutlineColor.B then consider(bot) end
  end
 end
 if nearest then
  local away=(root.Position-nearest.Position):Dot(right)
  if math.abs(away)>0.1 then return away<0 and -1 or 1 end
 end
 return 1
end

local function restorePose()
 if animation then
  for motor,base in pairs(animation.bases) do if motor.Parent then motor.Transform=base end end
  table.clear(animation.bases)
 end
end

local function beginPose(direction)
 restorePose()
 local character=player.Character
 if not character then animation=nil return end
 local motors={}
 for _,descendant in ipairs(character:GetDescendants()) do
  if descendant:IsA("Motor6D") then
   if descendant.Name=="RootJoint" or descendant.Name=="Root" or descendant.Name=="Waist" then motors[descendant]="Body"
   elseif descendant.Name=="RightShoulder" or descendant.Name=="Right Shoulder" then motors[descendant]="Right"
   elseif descendant.Name=="LeftShoulder" or descendant.Name=="Left Shoulder" then motors[descendant]="Left" end
  end
 end
 animation={started=os.clock(),direction=direction,motors=motors,bases={}}
end

local function requestDodge()
 if dodgeBusy or not canSprint() or player:GetAttribute("BBRole")~="Runner" then return end
 if player:GetAttribute("BBStatus")~="Crossing" then return end
 if workspace:GetServerTimeNow()<numberAttribute(player,"BBDodgeReadyAt",0) then return end
 local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 dodgeBusy=true
 lastDodgeDirection=dodgeDirection()
 task.spawn(function()
  local success,response=pcall(function() return remote:InvokeServer("Dodge",lastDodgeDirection) end)
  if alive and success and typeof(response)=="table" and response.ok then beginPose(lastDodgeDirection) end
  dodgeBusy=false
 end)
end

local function refresh()
 syncBinding()
 local role=player:GetAttribute("BBRole") or "Spectator"
 local visible=inputContext() and role~="Tagged"
 controls.Visible=visible
 if not visible then if requestedHeld then releaseHold() end return end
 local maximum=math.max(0.1,numberAttribute(player,"BBSprintMax",role=="Bulldog" and 15 or 10))
 local remaining=math.clamp(numberAttribute(player,"BBSprintRemaining",maximum),0,maximum)
 local exhausted=player:GetAttribute("BBSprintExhausted")==true
 local color=role=="Bulldog" and red or role=="Tagged" and yellow or blue
 meter.Role.Text=role=="Bulldog" and "BULLDOG" or role=="Tagged" and "TAGGED" or "RUNNER"
 meter.Charge.Text=string.format("%.1fs / %ds",remaining,math.floor(maximum+0.5))
 meter.Track.Fill.BackgroundColor3=color
 progress(remaining/maximum)
 sprint.BackgroundColor3=color
 local holdHint=UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"
 sprint.Caption.Text=(exhausted and "RECHARGING" or player:GetAttribute("BBSprinting")==true and "SPRINTING" or "SPRINT").."\n"..holdHint
 sprint.AutoButtonColor=canSprint()==true
 dodge.Visible=role=="Runner"
 boost.Visible=role=="Runner" and numberAttribute(player,"BBBoostEndsAt",0)>workspace:GetServerTimeNow()
 local cooldown=math.max(0,numberAttribute(player,"BBDodgeReadyAt",0)-workspace:GetServerTimeNow())
 dodge.Caption.Text=cooldown>0 and string.format("DODGE\n%.1fs",cooldown) or UserInputService.TouchEnabled and "DODGE\nTAP" or "DODGE\n[E]"
 dodge.AutoButtonColor=canSprint()==true and player:GetAttribute("BBStatus")=="Crossing" and cooldown<=0
 if not canSprint() and requestedHeld then releaseHold() end
 holdChanged()
 local confirmed=numberAttribute(player,"BBDodgeConfirmedAt",0)
 if confirmed>lastConfirmed then lastConfirmed=confirmed end
end

connect(sprint.InputBegan,function(input)
 if not focused or not canSprint() then return end
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  touchHold=input
  holdChanged()
 end
end)
connect(sprint.InputEnded,function(input)
 if input==touchHold then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputEnded,function(input)
 if input==touchHold then touchHold=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then shiftKeys[input.KeyCode]=nil end
 holdChanged()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touchHold and (input.UserInputState==Enum.UserInputState.Cancel or input.UserInputState==Enum.UserInputState.End) then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputBegan,function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.E and focused and not UserInputService:GetFocusedTextBox() then requestDodge() end
end)
connect(dodge.Activated,requestDodge)
connect(UserInputService.WindowFocusReleased,function() focused=false releaseHold() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,releaseHold)
connect(player.CharacterRemoving,function() releaseHold() restorePose() animation=nil end)
connect(player.CharacterAdded,function() releaseHold() restorePose() animation=nil end)
connect(RunService.PreAnimation,restorePose)
connect(RunService.PreSimulation,function()
 if not animation then return end
 local elapsed=os.clock()-animation.started
 if elapsed>=0.4 or not inputContext() or player:GetAttribute("BBRole")~="Runner" then restorePose() animation=nil return end
 local strength=math.sin(math.clamp(elapsed/0.4,0,1)*math.pi)
 for motor,kind in pairs(animation.motors) do
  if motor.Parent then
   local base=motor.Transform
   animation.bases[motor]=base
   local direction=animation.direction
   local pose=kind=="Body" and CFrame.Angles(math.rad(-12)*strength,math.rad(24)*strength*direction,math.rad(-20)*strength*direction)
    or CFrame.Angles(math.rad(-20)*strength,0,math.rad(kind=="Right" and 25 or -25)*strength)
   motor.Transform=base*pose
  end
 end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then elapsed=0 refresh() end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 alive=false
 releaseHold()
 restorePose()
 animation=nil
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()
]=],
 ["PlayerLevel"]=[=[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("LevelPanel")
local compact=gui:WaitForChild("CompactLevelPanel")
local panels={panel,compact}
local connections={}
local alive=true
local previewGeneration=0
local previewCharacter=nil
local previewPending=false

for _,target in ipairs(panels) do
 local viewport=target:WaitForChild("FacePreview")
 local camera=viewport:FindFirstChild("Camera")
 if not camera then
  camera=Instance.new("Camera")
  camera.Name="Camera"
  camera.FieldOfView=viewport:GetAttribute("PreviewFieldOfView") or 32
  camera.CFrame=viewport:GetAttribute("PreviewCameraCFrame") or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))
  camera.Parent=viewport
 end
 viewport.CurrentCamera=camera
end

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function progress(gradient,fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),NumberSequenceKeypoint.new(1,1)})
 end
end

local function sanitize(object)
 for _,descendant in ipairs(object:GetDescendants()) do
  local keep=descendant:IsA("BasePart") or descendant:IsA("DataModelMesh") or descendant:IsA("Decal") or descendant:IsA("Texture")
   or descendant:IsA("SurfaceAppearance") or descendant:IsA("Attachment") or descendant:IsA("Bone")
  if not keep then descendant:Destroy() end
 end
 local parts={}
 if object:IsA("BasePart") then table.insert(parts,object) end
 for _,descendant in ipairs(object:GetDescendants()) do if descendant:IsA("BasePart") then table.insert(parts,descendant) end end
 for _,part in ipairs(parts) do part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false part.CastShadow=false end
 return parts
end

local function clonePart(source)
 local ok,clone=pcall(function() return source:Clone() end)
 return ok and clone or nil
end

local function rebuildPreview()
 if not alive then return end
 local character=player.Character
 local head=character and character:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") then return end
 local generation=previewGeneration
 local headAttachments={}
 for _,attachment in ipairs(head:GetChildren()) do if attachment:IsA("Attachment") then headAttachments[attachment.Name]=true end end
 local prototype=Instance.new("Model")
 prototype.Name="AvatarPreview"
 local headClone=clonePart(head)
 if not headClone then prototype:Destroy() return end
 local headOrigin=head.CFrame
 local headParts=sanitize(headClone)
 for _,part in ipairs(headParts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
 headClone.Parent=prototype
 prototype.PrimaryPart=headClone
 for _,accessory in ipairs(character:GetChildren()) do
  if accessory:IsA("Accessory") then
   local handle=accessory:FindFirstChild("Handle")
   if handle and handle:IsA("BasePart") then
    local attachedToHead=false
    for _,attachment in ipairs(handle:GetChildren()) do
     if attachment:IsA("Attachment") and headAttachments[attachment.Name] then attachedToHead=true break end
     if attachment:IsA("Weld") and (attachment.Part0==head or attachment.Part1==head) then attachedToHead=true break end
    end
    if attachedToHead then
     local clone=clonePart(handle)
     if clone then
      clone.Name=accessory.Name
      local parts=sanitize(clone)
      for _,part in ipairs(parts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
      clone.Parent=prototype
     end
    end
   end
  end
 end
 if not alive or generation~=previewGeneration or character~=player.Character then prototype:Destroy() return end
 for _,target in ipairs(panels) do
  local viewport=target.FacePreview
  local world=viewport.World
  local clone=prototype:Clone()
  if clone then
   local old=world:FindFirstChild("AvatarPreview")
   if old then old:Destroy() end
   clone.Parent=world
   viewport.CurrentCamera=viewport.Camera
  end
 end
 prototype:Destroy()
end

local function schedulePreview()
 if previewPending then return end
 previewPending=true
 task.delay(0.12,function()
  previewPending=false
  rebuildPreview()
 end)
end

local characterConnection=nil
local function bindCharacter(character)
 previewGeneration+=1
 previewCharacter=character
 if characterConnection then characterConnection:Disconnect() characterConnection=nil end
 if character then
  characterConnection=character.DescendantAdded:Connect(function(descendant)
   if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Attachment") or descendant:IsA("SpecialMesh") then schedulePreview() end
  end)
 end
 schedulePreview()
end

local function refresh()
 local level=math.max(1,math.floor(numberAttribute("PCLevel",1)))
 local required=math.max(1,numberAttribute("PCLevelXPRequired",100+50*(level-1)))
 local xp=math.clamp(numberAttribute("PCLevelXP",0),0,required)
 panel.Level.Text="LEVEL "..tostring(level)
 compact.Level.Text="LV "..tostring(level)
 panel.XP.Text=string.format("%d / %d XP",math.floor(xp),math.floor(required))
 compact.XP.Text=string.format("%d / %d",math.floor(xp),math.floor(required))
 for _,target in ipairs(panels) do progress(target.XPTrack.Fill.Progress,xp/required) end
 local shop=gui:FindFirstChild("ShopPanel")
 local vote=gui:FindFirstChild("VotePanel")
 local modal=(shop and shop.Visible) or (vote and vote.Visible)
 local camera=workspace.CurrentCamera
 local narrow=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true
 local useCompact=narrow and inGame
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact
 if player.Character~=previewCharacter then bindCharacter(player.Character) end
end

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","BBParticipating","TGParticipating"}) do connect(player:GetAttributeChangedSignal(name),refresh) end
connect(player.CharacterAdded,bindCharacter)
connect(player.CharacterRemoving,function() bindCharacter(nil) end)
connect(player.CharacterAppearanceLoaded,function(character) if character==player.Character then schedulePreview() end end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.15 then elapsed=0 refresh() end
end)
connect(script.Destroying,function()
 alive=false
 previewGeneration+=1
 if characterConnection then characterConnection:Disconnect() end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
bindCharacter(player.Character)
refresh()
]=],
}
local function upgradeBritishBulldogControls()
local gui=assert(game:GetService("StarterGui"):FindFirstChild("BritishBulldogHUD"),"Editable British Bulldog HUD missing")
local existing=gui:FindFirstChild("MovementControls")
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local white=Color3.fromRGB(255,255,255)
local blue=Color3.fromRGB(42,160,255)
local red=Color3.fromRGB(255,81,92)
local yellow=Color3.fromRGB(255,204,54)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,properties)
 local object=Instance.new(class)
 object.Name=name
 for key,value in pairs(properties or {}) do object[key]=value end
 object.Parent=parent
 return object
end
local function finish(object,radius,thickness)
 make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius or 12)})
 make("UIStroke","Outline",object,{Thickness=thickness or 3,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function label(parent,name,value,position,size,font,max,z)
 local object=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font or body,TextColor3=ink,TextScaled=true,TextWrapped=true,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z or 5})
 make("UITextSizeConstraint","TextLimit",object,{MinTextSize=9,MaxTextSize=max or 23})
 return object
end
local function control(parent,name,value,position,size,color)
 local object=make("TextButton",name,parent,{Position=position,Size=size,Text="",AutoButtonColor=true,BackgroundColor3=color,BorderSizePixel=0,ZIndex=5})
 finish(object,12,3)
 label(object,"Caption",value,UDim2.new(0,33,0,2),UDim2.new(1,-38,1,-4),headline,21,6)
 local icon=make("ImageLabel","Icon",object,{Position=UDim2.fromOffset(7,8),Size=UDim2.fromOffset(25,25),BackgroundTransparency=1,BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Fit,ZIndex=6})
 label(object,"IconFallback",name=="Sprint" and "ϟ" or "↔",UDim2.fromOffset(5,5),UDim2.fromOffset(28,30),body,26,6)
 return object
end
local function addBoost(controls)
 if controls:FindFirstChild("EscapeBoost") then return end
 local badge=make("Frame","EscapeBoost",controls,{Position=UDim2.new(0.84,0,0,60),Size=UDim2.new(0.16,0,0,48),BackgroundColor3=yellow,BorderSizePixel=0,Visible=false,ZIndex=5})
 finish(badge,10,3)
 label(badge,"Caption","2×\nBOOST",UDim2.fromOffset(3,2),UDim2.new(1,-6,1,-4),headline,19,6)
end
local function addCompactDeparture()
 if gui:FindFirstChild("CompactDeparture") then return end
 local original=gui:FindFirstChild("Departure")
 if not original then return end
 local compact=original:Clone()
 compact.Name="CompactDeparture"
 compact.AnchorPoint=Vector2.new(0,1)
 compact.Position=UDim2.new(0,16,1,-140)
 compact.Size=UDim2.fromOffset(115,52)
 compact.Visible=false
 local limit=compact:FindFirstChildOfClass("UISizeConstraint")
 if limit then limit.MinSize=Vector2.new(115,52) limit.MaxSize=Vector2.new(115,52) end
 local prompt=compact.Panel.Prompt
 prompt.Text="LEAVE!"
 local textLimit=prompt:FindFirstChildOfClass("UITextSizeConstraint")
 if textLimit then textLimit.MinTextSize=9 textLimit.MaxTextSize=18 end
 compact.Parent=gui
end
addCompactDeparture()
if existing then addBoost(existing) return {created=false,preserved=true} end
local top=gui:FindFirstChild("TopCard")
local panel=top and top:FindFirstChild("Panel")
if panel then
 local bulldogs=panel:FindFirstChild("BulldogChip")
 local runners=panel:FindFirstChild("RunnerChip")
 if bulldogs and runners then
  bulldogs.BackgroundColor3=red
  runners.BackgroundColor3=blue
  if bulldogs.Position.X.Scale>runners.Position.X.Scale then local position=bulldogs.Position bulldogs.Position=runners.Position runners.Position=position end
 end
end
local controls=make("Frame","MovementControls",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.new(0.45,0,0,110),BackgroundTransparency=1,BorderSizePixel=0,Visible=true,ZIndex=4})
make("UISizeConstraint","SizeLimit",controls,{MinSize=Vector2.new(280,110),MaxSize=Vector2.new(375,110)})
local meter=make("Frame","Meter",controls,{Size=UDim2.new(1,0,0,48),BackgroundColor3=paper,BorderSizePixel=0,ZIndex=5})
finish(meter,13,4)
label(meter,"Role","RUNNER",UDim2.fromOffset(12,4),UDim2.new(0.52,0,0,18),headline,20,6).TextXAlignment=Enum.TextXAlignment.Left
label(meter,"Charge","10.0s / 10s",UDim2.new(1,-120,0,5),UDim2.fromOffset(107,17),body,15,6).TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame","Track",meter,{Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,10),BackgroundColor3=Color3.fromRGB(211,217,216),BorderSizePixel=0,ZIndex=6})
finish(track,6,2)
local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=7})
make("UICorner","Corner",fill,{CornerRadius=UDim.new(0,6)})
make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0),Rotation=0})
control(controls,"Sprint","SPRINT\nHOLD SHIFT",UDim2.fromOffset(0,60),UDim2.new(0.52,0,0,48),blue)
control(controls,"Dodge","DODGE\n[E]",UDim2.new(0.56,0,0,60),UDim2.new(0.25,0,0,48),yellow)
addBoost(controls)
local departure=gui:FindFirstChild("Departure")
if departure then departure.AnchorPoint=Vector2.new(0.5,1) departure.Position=UDim2.new(0.5,0,1,-146) end
local tagged=gui:FindFirstChild("Tagged")
if tagged then
 tagged.AnchorPoint=Vector2.new(0.5,1)
 tagged.Position=UDim2.new(0.5,0,1,-18)
 tagged.Size=UDim2.new(0.29,0,0,74)
 local sizeLimit=tagged:FindFirstChildOfClass("UISizeConstraint")
 if sizeLimit then sizeLimit.MinSize=Vector2.new(240,74) sizeLimit.MaxSize=Vector2.new(460,74) end
end
local oldRole=gui:FindFirstChild("RolePill")
if oldRole then oldRole.Visible=false end
gui.Enabled=true
gui:SetAttribute("MovementLayoutVersion",2)
return {created=true,controls=controls:GetFullName(),authoringVisible=gui.Enabled,layoutVersion=2}

end
local function upgradePlayerLevel()
local gui=assert(game:GetService("StarterGui"):FindFirstChild("PlaygroundShell"),"Editable Playground shell missing")
local function cameraSettings(viewport)
 local camera=viewport:FindFirstChild("Camera")
 if viewport:GetAttribute("PreviewCameraCFrame")==nil then viewport:SetAttribute("PreviewCameraCFrame",camera and camera.CFrame or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))) end
 if viewport:GetAttribute("PreviewFieldOfView")==nil then viewport:SetAttribute("PreviewFieldOfView",camera and camera.FieldOfView or 32) end
end
for _,name in ipairs({"LevelPanel","CompactLevelPanel"}) do
 local panel=gui:FindFirstChild(name)
 local viewport=panel and panel:FindFirstChild("FacePreview")
 if viewport then cameraSettings(viewport) end
end
if gui:FindFirstChild("LevelPanel") then return {created=false,preserved=true} end
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local yellow=Color3.fromRGB(255,204,54)
local blue=Color3.fromRGB(42,160,255)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,properties)
 local object=Instance.new(class)
 object.Name=name
 for key,value in pairs(properties or {}) do object[key]=value end
 object.Parent=parent
 return object
end
local function finish(object,radius,thickness)
 make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius)})
 make("UIStroke","Outline",object,{Thickness=thickness,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function label(parent,name,value,position,size,font,max)
 local object=make("TextLabel",name,parent,{Position=position,Size=size,BackgroundTransparency=1,BorderSizePixel=0,FontFace=font,Text=value,TextScaled=true,TextWrapped=true,TextColor3=ink,ZIndex=7})
 make("UITextSizeConstraint","TextLimit",object,{MinTextSize=8,MaxTextSize=max})
 return object
end
local function preview(parent,position,size)
 local viewport=make("ViewportFrame","FacePreview",parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(194,233,243),BorderSizePixel=0,Ambient=Color3.fromRGB(195,199,205),LightColor=Color3.fromRGB(255,255,255),LightDirection=Vector3.new(0.4,-1,0.5),ZIndex=7})
 finish(viewport,11,2)
 local world=make("WorldModel","World",viewport)
 local camera=make("Camera","Camera",viewport,{FieldOfView=32,CFrame=CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))})
 viewport.CurrentCamera=camera
 cameraSettings(viewport)
 local model=make("Model","AvatarPreview",world)
 local head=make("Part","Head",model,{Shape=Enum.PartType.Ball,Size=Vector3.new(1.8,1.6,1.5),Color=Color3.fromRGB(255,213,145),Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 model.PrimaryPart=head
 for _,side in ipairs({-1,1}) do make("Part","Eye",model,{Shape=Enum.PartType.Ball,Size=Vector3.new(0.15,0.18,0.10),Position=Vector3.new(side*0.33,0.18,-0.70),Color=ink,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false}) end
 make("Part","Smile",model,{Size=Vector3.new(0.28,0.08,0.08),Position=Vector3.new(0,-0.26,-0.75),Color=ink,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 return viewport
end
local function progress(parent,position,size)
 local track=make("Frame","XPTrack",parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(211,217,216),BorderSizePixel=0,ZIndex=7})
 finish(track,5,2)
 local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=8})
 make("UICorner","Corner",fill,{CornerRadius=UDim.new(0,5)})
 make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(1)})
end
local panel=make("Frame","LevelPanel",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-82),Size=UDim2.fromOffset(264,80),BackgroundColor3=paper,BorderSizePixel=0,Visible=true,ZIndex=6})
finish(panel,16,4)
preview(panel,UDim2.fromOffset(9,10),UDim2.fromOffset(60,60))
local star=make("ImageLabel","LevelIcon",panel,{Position=UDim2.fromOffset(80,10),Size=UDim2.fromOffset(21,21),BackgroundTransparency=1,BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Fit,ZIndex=7})
label(panel,"IconFallback","★",UDim2.fromOffset(80,8),UDim2.fromOffset(21,23),body,22).TextColor3=yellow
label(panel,"Level","LEVEL 1",UDim2.fromOffset(105,8),UDim2.fromOffset(147,26),headline,26).TextXAlignment=Enum.TextXAlignment.Left
label(panel,"XP","0 / 100 XP",UDim2.fromOffset(82,36),UDim2.fromOffset(171,17),body,15).TextXAlignment=Enum.TextXAlignment.Left
progress(panel,UDim2.fromOffset(82,59),UDim2.fromOffset(169,10))
local compact=make("Frame","CompactLevelPanel",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-201),Size=UDim2.fromOffset(115,52),BackgroundColor3=paper,BorderSizePixel=0,Visible=false,ZIndex=6})
finish(compact,11,3)
preview(compact,UDim2.fromOffset(5,5),UDim2.fromOffset(41,41))
label(compact,"Level","LV 1",UDim2.fromOffset(51,4),UDim2.fromOffset(60,20),headline,18).TextXAlignment=Enum.TextXAlignment.Left
label(compact,"XP","0 / 100",UDim2.fromOffset(51,24),UDim2.fromOffset(59,11),body,10).TextXAlignment=Enum.TextXAlignment.Left
progress(compact,UDim2.fromOffset(51,40),UDim2.fromOffset(56,6))
gui:SetAttribute("LevelLayoutVersion",1)
return {created=true,levelPanel=panel:GetFullName(),compactPanel=compact:GetFullName(),avatarViewports=2}

end
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Install British Bulldog before this upgrade")
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Install Playground Expansion before this upgrade")
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Install Playground Expansion before this upgrade")
assert(britishBulldog:FindFirstChild("Gameplay") and lobby:FindFirstChild("Gameplay") and tag:FindFirstChild("Gameplay"),"Required game geometry is incomplete")
assert(lobby.Gameplay:FindFirstChild("LobbySpawn"),"Lobby spawn is missing")
for _,name in ipairs({"BritishBulldogRules","BritishBulldogService","TagService","PlaygroundEconomyService","PlaygroundCoordinator","PlaygroundAdminService"}) do
 local object=ServerScriptService:FindFirstChild(name)
 assert(object and object:IsA("ModuleScript") and object.Sandboxed,"Install the sandboxed Playground Expansion first: "..name)
end
for _,name in ipairs({"BritishBulldogState","TagState","PlaygroundState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("Folder"),"Install Playground Expansion first: "..name)
end
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("RemoteFunction") and object.Sandboxed,"Install Playground Expansion first: "..name)
end
local britishBulldogHUD=assert(StarterGui:FindFirstChild("BritishBulldogHUD"),"Editable British Bulldog HUD is missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Editable Playground shell is missing")
assert(britishBulldogHUD:IsA("ScreenGui") and shell:IsA("ScreenGui"),"Editable HUDs must be ScreenGui objects")
local bootstrap=assert(ServerScriptService:FindFirstChild("PlaygroundBootstrap"),"Install Playground Expansion before this upgrade")
assert(bootstrap:IsA("Script") and bootstrap.Sandboxed,"PlaygroundBootstrap must retain its sandbox")
local baseCaps=SecurityCapabilities.new(
 Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.RunClientScript,
 Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.CreateInstances,
 Enum.SecurityCapability.Basic,Enum.SecurityCapability.Physics,Enum.SecurityCapability.UI,
 Enum.SecurityCapability.Players,Enum.SecurityCapability.AvatarBehavior,Enum.SecurityCapability.AvatarAppearance,
 Enum.SecurityCapability.Environment,Enum.SecurityCapability.LegacySound,Enum.SecurityCapability.Audio)
local remoteCaps=SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)
local rpcCaps=baseCaps:Add(remoteCaps)
local inputRpcCaps=rpcCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
local previewCaps=baseCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Animation))
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeMovementRewards20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeMovementRewards20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Movement backup container must be a Folder")
local savedSources=backups:FindFirstChild("InstallerSourceBackups")
if not savedSources then
 savedSources=Instance.new("Folder")
 savedSources.Name="InstallerSourceBackups"
 savedSources.Parent=backups
end
assert(savedSources:IsA("Folder"),"Source backup container must be a Folder")
local guiBackups=backups:FindFirstChild("AuthoredGuiBackups")
if not guiBackups then
 guiBackups=Instance.new("Folder")
 guiBackups.Name="AuthoredGuiBackups"
 guiBackups.Parent=backups
end
assert(guiBackups:IsA("Folder"),"GUI backup container must be a Folder")
local installed={}
local function saveSource(object)
 local key=object:GetFullName():gsub("[^%w_]","_")
 if savedSources:FindFirstChild(key) then return end
 local value=Instance.new("StringValue")
 value.Name=key
 value.Value=object.Source
 value:SetAttribute("OriginalPath",object:GetFullName())
 value:SetAttribute("OriginalClass",object.ClassName)
 value:SetAttribute("Sandboxed",object.Sandboxed)
 value:SetAttribute("Capabilities",tostring(object.Capabilities))
 if object:IsA("BaseScript") then value:SetAttribute("Disabled",object.Disabled) end
 value.Parent=savedSources
end
local function saveGui(gui)
 if guiBackups:FindFirstChild(gui.Name) then return end
 local copy=assert(gui:Clone(),gui.Name.." must be archivable for the first backup")
 copy:SetAttribute("OriginalPath",gui:GetFullName())
 copy.Enabled=false
 for _,object in ipairs(copy:GetDescendants()) do if object:IsA("BaseScript") then object.Disabled=true end end
 copy.Parent=guiBackups
end
local function install(className,name,source,parent,caps)
 local object=parent:FindFirstChild(name)
 if object then
  assert(object:IsA(className),name.." has an unexpected class")
  assert(object.Sandboxed,name.." must retain its sandbox")
  saveSource(object)
  object.Capabilities=caps or baseCaps
  object.Source=source
 else
  object=Instance.new(className)
  object.Name=name
  object.Capabilities=caps or baseCaps
  object.Sandboxed=true
  if object:IsA("BaseScript") then object.Disabled=true end
  object.Source=source
  object.Parent=parent
 end
 table.insert(installed,object:GetFullName())
 return object
end
local function remote(name)
 local object=ReplicatedStorage:FindFirstChild(name)
 if object then
  assert(object:IsA("RemoteFunction"),name.." must be a RemoteFunction")
  assert(object.Sandboxed,name.." must retain its sandbox")
  assert(remoteCaps:Contains(object.Capabilities) and object.Capabilities:Contains(remoteCaps),name.." must have only RemoteEvent capability")
 else
  object=Instance.new("RemoteFunction")
  object.Name=name
  object.Capabilities=remoteCaps
  object.Sandboxed=true
  object.Parent=ReplicatedStorage
 end
 return object
end
saveGui(britishBulldogHUD)
saveGui(shell)
saveSource(bootstrap)
remote("BBMovementRequest")
if lobby:GetAttribute("WinnerCoins")==nil then lobby:SetAttribute("WinnerCoins",150) end
if lobby:GetAttribute("LoserCoins")==nil then lobby:SetAttribute("LoserCoins",50) end
if lobby:GetAttribute("WinnerXP")==nil then lobby:SetAttribute("WinnerXP",100) end
if lobby:GetAttribute("LoserXP")==nil then lobby:SetAttribute("LoserXP",25) end
if lobby:GetAttribute("BaseLevelXP")==nil then lobby:SetAttribute("BaseLevelXP",100) end
if lobby:GetAttribute("LevelXPStep")==nil then lobby:SetAttribute("LevelXPStep",50) end
if britishBulldog:GetAttribute("RunnerSprintSeconds")==nil then britishBulldog:SetAttribute("RunnerSprintSeconds",10) end
if britishBulldog:GetAttribute("InitialBulldogSprintSeconds")==nil then britishBulldog:SetAttribute("InitialBulldogSprintSeconds",15) end
if britishBulldog:GetAttribute("SprintRefillSeconds")==nil then britishBulldog:SetAttribute("SprintRefillSeconds",15) end
if britishBulldog:GetAttribute("SprintMultiplier")==nil then britishBulldog:SetAttribute("SprintMultiplier",2.5) end
if britishBulldog:GetAttribute("DodgeCooldownSeconds")==nil then britishBulldog:SetAttribute("DodgeCooldownSeconds",4) end
if britishBulldog:GetAttribute("DodgeBoostMultiplier")==nil then britishBulldog:SetAttribute("DodgeBoostMultiplier",2) end
if britishBulldog:GetAttribute("DodgeBoostSeconds")==nil then britishBulldog:SetAttribute("DodgeBoostSeconds",1.5) end
local movementResult=upgradeBritishBulldogControls()
local levelResult=upgradePlayerLevel()
assert(shell:FindFirstChild("LevelPanel") and shell:FindFirstChild("CompactLevelPanel"),"Existing level layout is incomplete and was preserved")
local iconAssetJson=[=[{
  "Sprint": "rbxassetid://86080260918857",
  "Dodge": "rbxassetid://99567482512995",
  "Level": "rbxassetid://99215209137796"
}
]=]
local iconAssets={
 ["Sprint"]=[=[rbxassetid://86080260918857]=],
 ["Dodge"]=[=[rbxassetid://99567482512995]=],
 ["Level"]=[=[rbxassetid://99215209137796]=],
}
local function importIcon(parent,imageName,key)
 local image=parent and parent:FindFirstChild(imageName)
 if not image then return end
 assert(image:IsA("ImageLabel"),key.." icon must be an ImageLabel")
 if image.Image=="" and iconAssets[key] then image.Image=iconAssets[key] end
 local fallback=parent:FindFirstChild("IconFallback")
 if fallback and image.Image~="" then fallback.Visible=false end
end
local movementControls=assert(britishBulldogHUD:FindFirstChild("MovementControls"),"Movement controls are missing")
importIcon(movementControls:FindFirstChild("Sprint"),"Icon","Sprint")
importIcon(movementControls:FindFirstChild("Dodge"),"Icon","Dodge")
importIcon(shell:FindFirstChild("LevelPanel"),"LevelIcon","Level")
install("ModuleScript","BritishBulldogService",sources.BritishBulldogService,ServerScriptService,rpcCaps)
install("ModuleScript","TagService",sources.TagService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundEconomyService",sources.PlaygroundEconomyService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundCoordinator",sources.PlaygroundCoordinator,ServerScriptService,rpcCaps)
local clients={
 install("LocalScript","Controller",sources.BritishBulldogHUD,britishBulldogHUD,baseCaps),
 install("LocalScript","MovementController",sources.BBMovement,britishBulldogHUD,inputRpcCaps),
 install("LocalScript","PlayerLevelController",sources.PlayerLevel,shell,previewCaps),
}
for _,object in ipairs(clients) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
if backups:GetAttribute("BritishBulldogAutoStart")==nil then backups:SetAttribute("BritishBulldogAutoStart",britishBulldog:GetAttribute("AutoStart")) end
britishBulldog:SetAttribute("AutoStart",false)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("MovementRewardsInstalled",true)
backups:SetAttribute("MovementRewardsVersion",1)
return {installed=true,scripts=#installed,movement=movementResult,levels=levelResult,authoredLayoutsPreserved=true,geometryPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
