local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Install Playground Expansion in Studio edit mode")
local sources={
 ["BritishBulldogRules"]=[=[local Rules = {}

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
 ["BritishBulldogCamera"]=[=[local Players=game:GetService("Players")
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
 ["PlaygroundCatalog"]=[=[local items = {
	{ id = "BubbleBee", name = "Bubble Bee", category = "Pets", slot = "Pet", price = 45, color = Color3.fromRGB(255, 207, 59), preview = "Bee" },
	{ id = "CloudPup", name = "Cloud Pup", category = "Pets", slot = "Pet", price = 70, color = Color3.fromRGB(205, 235, 255), preview = "Cloud" },
	{ id = "Wave", name = "Hello Wave", category = "Emotes", slot = "Emote", price = 30, color = Color3.fromRGB(107, 204, 255), preview = "Wave" },
	{ id = "Cheer", name = "Big Cheer", category = "Emotes", slot = "Emote", price = 45, color = Color3.fromRGB(255, 130, 181), preview = "Cheer" },
	{ id = "Star", name = "Starstruck", category = "Emojis", slot = "Emoji", price = 25, color = Color3.fromRGB(255, 212, 74), preview = "Star", emoji = "★" },
	{ id = "Heart", name = "Sending Love", category = "Emojis", slot = "Emoji", price = 25, color = Color3.fromRGB(255, 103, 146), preview = "Heart", emoji = "♥" },
	{ id = "SunsetTrail", name = "Sunset Ribbon", category = "Trails", slot = "Trail", price = 40, color = Color3.fromRGB(255, 157, 67), preview = "Ribbon" },
	{ id = "RainbowTrail", name = "Rainbow Ribbon", category = "Trails", slot = "Trail", price = 70, color = Color3.fromRGB(128, 113, 255), preview = "Rainbow" },
	{ id = "SkyOutline", name = "Sky Outline", category = "Highlights", slot = "Highlight", price = 40, color = Color3.fromRGB(53, 168, 255), preview = "Outline" },
	{ id = "RainbowOutline", name = "Rainbow Outline", category = "Highlights", slot = "Highlight", price = 90, color = Color3.fromRGB(147, 115, 255), preview = "Outline" },
	{ id = "SnowPotion", name = "Snow Potion", category = "Gear", slot = "Gear", price = 75, color = Color3.fromRGB(148, 228, 255), preview = "Potion", available = false },
	{ id = "StarWand", name = "Star Wand", category = "Gear", slot = "Gear", price = 75, color = Color3.fromRGB(255, 207, 59), preview = "Wand", available = false },
}
local byId = {}
for _, item in ipairs(items) do
	byId[item.id] = item
end
return { Items = items, ById = byId, Categories = { "All", "Pets", "Emotes", "Emojis", "Trails", "Highlights", "Gear" } }
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
 ["PlaygroundAdminService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
}
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }

function Admin.new(coordinator, config, isStudio)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	if self.isStudio then return true end
	local id = player.UserId
	if game.CreatorType == Enum.CreatorType.User and id == game.CreatorId then return true end
	if id == self.config:GetAttribute("AdminUserId") then return true end
	local extra = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extra) == "string" then
		for value in string.gmatch(extra, "%d+") do if tonumber(value) == id then return true end end
	end
	return false
end

function Admin:Status(player, ok, message)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	return { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
end

function Admin:Handle(player, action)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.") end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.") end
	if self.busy then return self:Status(player, false, "Another control is finishing.") end
	self.busy = true
	local ok, success, message = pcall(function()
		if action == "StopRound" then return self.coordinator:StopGame() end
		if action == "ToggleAutomatic" then
			self.coordinator:SetAutoEnabled(not self.coordinator.autoEnabled)
			return true, self.coordinator.autoEnabled and "Automatic voting rounds are on." or "Automatic rounds paused."
		end
		local control = controls[action]
		local started, reason = self.coordinator:StartGame(control.game, player, control.role, false)
		if not started and reason == "Not enough ready players" then reason = "Use a solo button to test alone. Normal rounds need two players." end
		return started, started and "Starting your game." or reason
	end)
	self.busy = false
	if not ok then
		warn("Playground admin command failed: " .. tostring(success))
		return self:Status(player, false, "The game couldn't start. Try again.")
	end
	return self:Status(player, success == true, message)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action) return self:Handle(player, action) end
	local function bind(player) player:SetAttribute("PlaygroundAdmin", self:IsAuthorized(player)) end
	table.insert(self.connections, Players.PlayerAdded:Connect(bind))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastRequest[player] = nil self.lastStatus[player] = nil end))
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	table.insert(self.connections, config.AttributeChanged:Connect(function() for _, player in ipairs(Players:GetPlayers()) do bind(player) end end))
	return self
end

function Admin:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Admin
]=],
 ["PlaygroundBootstrap"]=[=[local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
local economy = Economy.new(lobby)
economy:Start()
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)
]=],
 ["PlaygroundAdminController"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local content = panel.Body.Content
local controls = {}
for _, card in ipairs(content:GetChildren()) do
	if card:IsA("Frame") then
		for _, control in ipairs(card:GetChildren()) do if control:IsA("TextButton") then controls[control.Name] = control end end
	end
end
controls.StopRound = panel.StopRound
controls.ToggleAutomatic = panel.ToggleAutomatic
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local busy = false
local connections = {}
local ink = Color3.fromRGB(24, 35, 62)
local failure = Color3.fromRGB(171, 38, 57)
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local bb = ReplicatedStorage:WaitForChild("BritishBulldogState")
local tag = ReplicatedStorage:WaitForChild("TagState")
local function admin() return player:GetAttribute("PlaygroundAdmin") == true end
local function sync()
	gui.Enabled = admin()
	if not admin() then panel.Visible = false end
	for name, control in pairs(controls) do
		local enabled = admin() and not busy
		control.Active = enabled
		control.Selectable = enabled
		control.AutoButtonColor = enabled
		control.BackgroundColor3 = enabled and control:GetAttribute("ReadyColor") or Color3.fromRGB(162, 169, 184)
	end
	for id, gameState in pairs({ BritishBulldog = bb, TagYoureIt = tag }) do
		local phase = gameState:GetAttribute("Phase") or "Waiting"
		local mode = gameState:GetAttribute("Mode") or ""
		content[id].Status.Text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
	end
	panel.ToggleAutomatic.Text = state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF"
end
local function request(action)
	if not admin() or busy then return end
	busy = true
	sync()
	local ok, response = pcall(function() return ReplicatedStorage.PlaygroundAdminRequest:InvokeServer(action) end)
	busy = false
	if admin() and gui.Parent then
		panel.Message.Text = ok and typeof(response) == "table" and response.message or "Server unavailable. Try again."
		panel.Message.TextColor3 = ok and response and response.ok and ink or failure
	end
	sync()
end
local function toggle()
	if not admin() then return end
	panel.Visible = not panel.Visible
	gui.Toggle.Text = panel.Visible and "CLOSE" or "ADMIN"
	if panel.Visible then task.spawn(request, "GetStatus") end
end
for action, control in pairs(controls) do table.insert(connections, control.Activated:Connect(function() request(action) end)) end
table.insert(connections, gui.Toggle.Activated:Connect(toggle))
table.insert(connections, panel.Close.Activated:Connect(function() panel.Visible = false gui.Toggle.Text = "ADMIN" end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(sync))
for _, object in ipairs({ state, bb, tag }) do table.insert(connections, object.AttributeChanged:Connect(sync)) end
script.Destroying:Connect(function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
panel.Visible = false
sync()
]=],
 ["TagHUDController"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local state = ReplicatedStorage:WaitForChild("TagState")
local movement = ReplicatedStorage:WaitForChild("TagMovementRequest")
local top = gui:WaitForChild("Top")
local taggerName = top:WaitForChild("TaggerChip"):WaitForChild("Name")
local rolePanel = gui:WaitForChild("Role")
local controls = gui:WaitForChild("Controls")
local results = gui:WaitForChild("Results")
local blue = Color3.fromRGB(54, 174, 255)
local red = Color3.fromRGB(255, 83, 100)
local yellow = Color3.fromRGB(255, 204, 54)
local messageEndsAt = 0
local busy = false
local previousCamera
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local movePose

local function camera(active)
	if active and not previousCamera then
		previousCamera = { minimum = player.CameraMinZoomDistance, maximum = player.CameraMaxZoomDistance }
		player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 28)
		player.CameraMinZoomDistance = 28
		player.CameraMaxZoomDistance = 28
	elseif not active and previousCamera then
		player.CameraMinZoomDistance = math.min(previousCamera.minimum, player.CameraMaxZoomDistance)
		player.CameraMaxZoomDistance = previousCamera.maximum
		player.CameraMinZoomDistance = previousCamera.minimum
		previousCamera = nil
	end
end

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	gui.Enabled = participating
	camera(participating)
	if not participating then return end
	local phase = state:GetAttribute("Phase") or "Waiting"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing"
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	for _, action in ipairs({ "Vault", "Dodge" }) do
		local button = controls[action]
		local cooldown = secondsRemaining(player:GetAttribute("TG" .. action .. "ReadyAt"), now)
		local shortcut = action == "Vault" and "[Q]" or "[X]"
		button.Text = string.upper(action) .. " " .. (cooldown > 0 and string.format("%.1fs", cooldown) or shortcut)
		button.BackgroundColor3 = cooldown > 0 and Color3.fromRGB(194, 201, 206) or action == "Vault" and yellow or blue
		button.Active = cooldown == 0 and not busy
	end
	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = won and blue or red
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end

local function move(action)
	if busy or player:GetAttribute("TGParticipating") ~= true or state:GetAttribute("Phase") ~= "Playing" then return end
	busy = true
	task.spawn(function()
		local ok, accepted, message = pcall(function() return movement:InvokeServer(action) end)
		busy = false
		if not ok or not accepted then
			gui.MoveMessage.Text = ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
			messageEndsAt = workspace:GetServerTimeNow() + 1.8
		else
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				for _, joint in ipairs(character:GetDescendants()) do
					if joint:IsA("Motor6D") and joint.Part0 == root then
						movePose = { joint = joint, action = action, startedAt = workspace:GetServerTimeNow() }
						break
					end
				end
			end
		end
		update()
	end)
end

controls.Vault.Activated:Connect(function() move("Vault") end)
controls.Dodge.Activated:Connect(function() move("Dodge") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Q then move("Vault")
	elseif input.KeyCode == Enum.KeyCode.X then move("Dodge") end
end)
player.AttributeChanged:Connect(update)
state.AttributeChanged:Connect(update)
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator >= 0.1 then accumulator = 0 update() end
end)
RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	if movePose then
		local progress = (now - movePose.startedAt) / 0.38
		if progress >= 1 or not movePose.joint.Parent or player:GetAttribute("TGParticipating") ~= true then
			if movePose.joint.Parent then movePose.joint.Transform = CFrame.identity end
			movePose = nil
		else
			local blend = math.sin(math.pi * math.clamp(progress, 0, 1))
			local tilt = movePose.action == "Vault" and -0.32 or -0.25
			movePose.joint.Transform = CFrame.Angles(tilt * blend, 0, movePose.action == "Dodge" and 0.12 * blend or 0)
		end
	end
	local bots = workspace:FindFirstChild("TagPracticeBots")
	if bots then
		for _, character in ipairs(bots:GetChildren()) do
			local root = character:FindFirstChild("HumanoidRootPart")
			local torso = character:FindFirstChild("Torso")
			if root and torso then
				local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 0.42
				for _, joint in ipairs(torso:GetChildren()) do
					if joint:IsA("Motor6D") then
						local sign = (joint.Name == "Right Hip" or joint.Name == "Left Shoulder") and 1 or -1
						if string.find(joint.Name, "Hip") or string.find(joint.Name, "Shoulder") then
							joint.Transform = CFrame.Angles(swing * sign, 0, 0)
						end
					end
				end
			end
		end
	end
end)
script.Destroying:Connect(function() camera(false) end)
update()
]=],
 ["PlaygroundShellController"]=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local shop=gui:WaitForChild("ShopPanel")
local vote=gui:WaitForChild("VotePanel")
local wallet=gui:WaitForChild("Wallet")
local dock=gui:WaitForChild("Dock")
local toast=gui:WaitForChild("RewardToast")
local catalogObject=ReplicatedStorage:WaitForChild("PlaygroundCatalog",10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog=require(catalogObject)
local ink=Color3.fromRGB(27,45,61)
local white=Color3.fromRGB(255,255,248)
local gold=Color3.fromRGB(255,211,78)
local blue=Color3.fromRGB(89,193,244)
local pink=Color3.fromRGB(255,153,166)
local mint=Color3.fromRGB(130,225,180)
local muted=Color3.fromRGB(220,225,215)
local data={coins=player:GetAttribute("PCCoins") or 0,ready=player:GetAttribute("PCDataReady")==true,owned={},equipped={}}
local category="All"
local busy=false
local voteBusy=false
local toastToken=0
local cards={}
local previews={}
local lastReward=player:GetAttribute("PCRewardAt")
local wasInsideShop=false
local state=nil
local stateConnection=nil

local function showToast(message,duration)
 toastToken+=1
 local token=toastToken
 toast.Message.Text=tostring(message)
 toast.Visible=true
 task.delay(duration or 3.2,function()
  if token==toastToken and toast.Parent then toast.Visible=false end
 end)
end
local function refreshWallet()
 local coins=data.ready and tostring(data.coins or 0) or "..."
 wallet.Coins.Text=coins
 wallet.Wins.Text=tostring(player:GetAttribute("PCWins") or 0).." wins"
 shop.Coins.Text=coins.." coins"
end
local function refreshCards()
 refreshWallet()
 for _,item in ipairs(catalog.Items) do
  local card=cards[item.id]
  if card then
   local owned=data.owned[item.id]==true
   local equipped=data.equipped[item.slot]==item.id
   card.Visible=category=="All" or item.category==category
   card.Price.Text=item.available==false and "Coming later" or owned and (equipped and "Equipped" or "Owned") or tostring(item.price).." coins"
   card.Action.Text=item.available==false and "COMING SOON" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or "BUY"
   card.Action.BackgroundColor3=(item.available==false or not data.ready) and muted or equipped and mint or owned and blue or gold
   card.Action.Active=not busy and data.ready and item.available~=false
   card.Action.Selectable=card.Action.Active
   card.Try.Visible=owned and (item.category=="Emotes" or item.category=="Emojis")
   card.Try.Active=not busy and data.ready
   card.Try.Selectable=card.Try.Active
   card.Outline.Color=equipped and gold or ink
  end
 end
 for _,button in ipairs(shop.Categories:GetChildren()) do
  if button:IsA("TextButton") then button.BackgroundColor3=button.Name==category and gold or white end
 end
end
local function applyReply(reply)
 if typeof(reply)~="table" then return end
 if typeof(reply.coins)=="number" then data.coins=reply.coins end
 if typeof(reply.ready)=="boolean" then data.ready=reply.ready or player:GetAttribute("PCDataReady")==true end
 if typeof(reply.owned)=="table" then data.owned=reply.owned end
 if typeof(reply.equipped)=="table" then data.equipped=reply.equipped end
 refreshCards()
end
local function playEmote(name)
 if typeof(name)~="string" then return end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid then return end
 local ok,played=pcall(function() return humanoid:PlayEmote(name) end)
 if not ok or not played then showToast("Your avatar could not play that emote.") end
end
local function request(action,id,quiet)
 if busy then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
 if not remote or not remote:IsA("RemoteFunction") then
  if not quiet then
   shop.Status.Text="The shop is getting ready. Try again in a moment."
   if not shop.Visible then showToast("The shop is getting ready.") end
  end
  return
 end
 busy=true
 refreshCards()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(action,id) end)
  busy=false
  if ok and typeof(reply)=="table" then
   applyReply(reply)
   if not quiet or not reply.ok then shop.Status.Text=tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
   if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
   if reply.ok and reply.emote then playEmote(reply.emote) end
  else
   refreshCards()
   if not quiet then
    shop.Status.Text="That did not go through. Try again in a moment."
    if not shop.Visible then showToast("Try again in a moment.") end
   end
  end
 end)
end
local function setShop(visible)
 shop.Visible=visible
 gui.Backdrop.Visible=visible
 if visible then
  shop.Status.Text=data.ready and "Pick a little something for your next round." or "Your coins are loading..."
  request("GetStatus",nil,true)
 end
end
local function setCategory(value)
 category=value
 refreshCards()
end
for _,card in ipairs(shop.Cards:GetChildren()) do
 if card:IsA("Frame") and card:GetAttribute("CatalogId") then
  local id=card:GetAttribute("CatalogId")
  local item=catalog.ById[id]
  if item then
   cards[id]=card
   local model=card.Preview.World:FindFirstChild("ItemModel")
   if model then table.insert(previews,{model=model,pivot=model:GetPivot()}) end
   card.Action.Activated:Connect(function()
    if busy or not data.ready or item.available==false then return end
    if data.equipped[item.slot]==id then request("Unequip",item.slot)
    elseif data.owned[id] then request("Equip",id)
    else request("Buy",id) end
   end)
   card.Try.Activated:Connect(function()
    if item.category=="Emotes" then request("UseEmote",id)
    elseif item.category=="Emojis" then request("UseEmoji",id) end
   end)
  end
 end
end
for _,button in ipairs(shop.Categories:GetChildren()) do
 if button:IsA("TextButton") then button.Activated:Connect(function() setCategory(button.Name) end) end
end
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Emote.Activated:Connect(function()
 local id=data.equipped.Emote
 if id then request("UseEmote",id)
 else setCategory("Emotes") setShop(true) shop.Status.Text="Equip an emote, then use it here." end
end)
dock.Emoji.Activated:Connect(function()
 local id=data.equipped.Emoji
 if id then request("UseEmoji",id)
 else setCategory("Emojis") setShop(true) shop.Status.Text="Equip an emoji, then use it here." end
end)
for _,attribute in ipairs({"PCCoins","PCWins","PCDataReady"}) do
 player:GetAttributeChangedSignal(attribute):Connect(function()
  local wasReady=data.ready
  data.coins=player:GetAttribute("PCCoins") or data.coins
  data.ready=player:GetAttribute("PCDataReady")==true
  refreshCards()
  if data.ready and not wasReady then request("GetStatus",nil,true) end
 end)
end
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
 local now=player:GetAttribute("PCRewardAt")
 if now and now~=lastReward then
  lastReward=now
  local message=player:GetAttribute("PCRewardText")
  if typeof(message)=="string" and message~="" then showToast(message,4) end
 end
end)
local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then vote.Message.Text="That vote did not go through. Try again."
  elseif typeof(reply)=="table" and reply.ok==false then vote.Message.Text=tostring(reply.message or "Step into the voting area first.") end
 end)
end
vote.BritishBulldog.Activated:Connect(function() castVote("BritishBulldog") end)
vote.TagYoureIt.Activated:Connect(function() castVote("TagYoureIt") end)
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 vote.Visible=not participating and insideZone(voteZone,root) and not shop.Visible
 if vote.Visible then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in ipairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(preview.pivot*CFrame.Angles(0,rotation,0)) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)
]=],
 ["PlaygroundEmotes"]=[=[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local records = {}
local function restore(record)
	for joint, entry in pairs(record.joints) do
		if joint.Parent and joint.Transform == entry.applied then joint.Transform = entry.original end
	end
	table.clear(record.joints)
end
local function pose(record, joint, offset)
	if not joint or not joint:IsA("Motor6D") then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local applied = original * offset
	joint.Transform = applied
	record.joints[joint] = { original = original, applied = applied }
end
local frame = RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local record = records[player]
		if not record or record.character ~= character then
			if record then restore(record) end
			record = { character = character, joints = {} }
			records[player] = record
		end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			restore(record)
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then restore(record) continue end
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = character:FindFirstChild(classic and "Right Shoulder" or "RightShoulder", true)
		local left = character:FindFirstChild(classic and "Left Shoulder" or "LeftShoulder", true)
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, character:FindFirstChild("RightElbow", true), CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, character:FindFirstChild("Waist", true), CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
		end
	end
end)
local removing = Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if record then restore(record) records[player] = nil end
end)
script.Destroying:Connect(function()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
end)
]=],
 ["PlaygroundLobbyAtmosphere"]=[=[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local baseline
local elapsed = 0
local function restore()
	if not baseline then return end
	for name, value in pairs(baseline) do Lighting[name] = value end
	baseline = nil
end
local function update()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local gameplay = lobby and lobby:FindFirstChild("Gameplay")
	local bounds = gameplay and gameplay:FindFirstChild("LobbyBounds")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = false
	if bounds and root then
		local point = bounds.CFrame:PointToObjectSpace(root.Position)
		local half = bounds.Size / 2
		inside = math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
	end
	inside = inside and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
	if not inside then restore() return end
	if baseline then return end
	baseline = {
		Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation, ClockTime = Lighting.ClockTime,
	}
	Lighting.Ambient = Color3.fromRGB(110, 122, 136)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 145, 154)
	Lighting.Brightness = 2.2
	Lighting.ExposureCompensation = 0
	Lighting.ClockTime = 13.5
end
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.3 then elapsed = 0 update() end
end)
script.Destroying:Connect(function() heartbeat:Disconnect() restore() end)
update()
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
local function buildLobby()
local Workspace = game:GetService("Workspace")
local existing = Workspace:FindFirstChild("Playground Lobby")
if existing then
	assert(existing:GetAttribute("PlaygroundManaged") == true, "An unowned Playground Lobby already exists")
	return {created = false, folder = existing:GetFullName(), version = existing:GetAttribute("BuilderVersion")}
end

local root = Instance.new("Folder")
root.Name = "Playground Lobby"
root:SetAttribute("PlaygroundManaged", true)
root:SetAttribute("BuilderVersion", 1)
root:SetAttribute("FloorY", 4)
root:SetAttribute("BoundsSize", Vector3.new(320, 80, 304))
root:SetAttribute("VoteZoneCenter", Vector3.new(88, 10, -82))
root:SetAttribute("VoteZoneSize", Vector3.new(74, 12, 60))
root.Parent = Workspace

local colors = {
	ink = Color3.fromRGB(29, 46, 72),
	grass = Color3.fromRGB(125, 208, 133),
	grassLight = Color3.fromRGB(157, 225, 142),
	grassDark = Color3.fromRGB(104, 187, 129),
	mint = Color3.fromRGB(106, 219, 177),
	cream = Color3.fromRGB(255, 242, 197),
	path = Color3.fromRGB(247, 218, 166),
	wood = Color3.fromRGB(184, 119, 77),
	gold = Color3.fromRGB(255, 207, 88),
	blue = Color3.fromRGB(94, 179, 232),
	pink = Color3.fromRGB(250, 154, 177),
	lilac = Color3.fromRGB(182, 163, 233),
	leaf = Color3.fromRGB(71, 179, 130),
	leafLight = Color3.fromRGB(113, 213, 143),
	water = Color3.fromRGB(87, 191, 223),
	white = Color3.fromRGB(255, 251, 232),
}

local partCount = 0
local function folder(name, parent)
	local value = Instance.new("Folder")
	value.Name = name
	value.Parent = parent or root
	return value
end

local island = folder("Island")
local paths = folder("Paths")
local nature = folder("Nature")
local furniture = folder("Furniture")
local pond = folder("Pond")
local terrace = folder("PicnicTerrace")
local shop = folder("ShopNook")
local voting = folder("VotingAlcove")
local gameplay = folder("Gameplay")
local coinSpawns = folder("CoinSpawns", gameplay)
local voteChoices = folder("VoteChoices", gameplay)

local function part(name, size, position, color, parent, collide, shape)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	value.Color = color
	value.Anchored = true
	value.CanCollide = collide ~= false
	value.CanTouch = false
	value.CanQuery = true
	value.Material = Enum.Material.SmoothPlastic
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	if shape then value.Shape = shape end
	value.Parent = parent
	partCount += 1
	return value
end

local function disc(name, diameter, height, position, color, parent, collide)
	return part(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, parent, collide, Enum.PartType.Cylinder)
end

local function ball(name, size, position, color, parent, collide)
	return part(name, size, position, color, parent, collide, Enum.PartType.Ball)
end

local function model(name, parent)
	local value = Instance.new("Model")
	value.Name = name
	value.Parent = parent
	return value
end

local function outline(value)
	local highlight = Instance.new("Highlight")
	highlight.Name = "CartoonOutline"
	highlight.Adornee = value
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = colors.ink
	highlight.Parent = value
end

local function slab(name, size, top, x, z, color, parent)
	part(name .. "Rim", Vector3.new(size.X + 1.2, size.Y, size.Z + 1.2), Vector3.new(x, top - size.Y / 2 - 0.12, z), colors.ink, parent)
	return part(name, size, Vector3.new(x, top - size.Y / 2, z), color, parent)
end

local function marker(name, size, position, parent)
	local value = part(name, size, position, colors.white, parent, false)
	value.Transparency = 1
	value.CanQuery = false
	value.CastShadow = false
	return value
end

part("MainOutline", Vector3.new(284, 8, 308), Vector3.new(0, -1.15, 0), colors.ink, island)
part("WestOutline", Vector3.new(22, 8, 264), Vector3.new(-153, -1.15, 0), colors.ink, island)
part("EastOutline", Vector3.new(22, 8, 264), Vector3.new(153, -1.15, 0), colors.ink, island)
part("MainGrass", Vector3.new(280, 8, 304), Vector3.new(0, 0, 0), colors.grass, island)
part("WestGrass", Vector3.new(20, 8, 260), Vector3.new(-150, 0, 0), colors.grass, island)
part("EastGrass", Vector3.new(20, 8, 260), Vector3.new(150, 0, 0), colors.grass, island)
for _, side in ipairs({-1, 1}) do
	for _, endSide in ipairs({-1, 1}) do
		part("CornerGrass", Vector3.new(22, 8, 22), CFrame.new(side * 139, 0, endSide * 130) * CFrame.Angles(0, math.pi / 4, 0), colors.grass, island)
	end
end

disc("PlazaInk", 68, 0.12, Vector3.new(0, 4.01, 0), colors.ink, paths, false)
disc("PlazaMint", 66.6, 0.12, Vector3.new(0, 4.08, 0), colors.mint, paths, false)
disc("PlazaCream", 61, 0.12, Vector3.new(0, 4.15, 0), colors.cream, paths, false)
disc("PlazaCenter", 15, 0.10, Vector3.new(0, 4.21, 0), colors.path, paths, false)
for index = 1, 8 do
	local angle = index * math.pi / 4
	local dot = disc("PlazaInlay" .. index, 2.1, 0.08, Vector3.new(math.cos(angle) * 24.5, 4.24, math.sin(angle) * 24.5), colors.gold, paths, false)
	dot.CastShadow = false
end

local pathRoutes = {
	{Vector3.new(18, 0, -18), Vector3.new(38, 0, -38), Vector3.new(58, 0, -59), Vector3.new(70, 0, -69)},
	{Vector3.new(-28, 0, -6), Vector3.new(-51, 0, -12), Vector3.new(-76, 0, -25), Vector3.new(-95, 0, -31)},
	{Vector3.new(-18, 0, 24), Vector3.new(-32, 0, 42), Vector3.new(-52, 0, 50), Vector3.new(-62, 0, 50)},
	{Vector3.new(29, 0, 17), Vector3.new(51, 0, 29), Vector3.new(73, 0, 43), Vector3.new(90, 0, 50)},
	{Vector3.new(-102, 0, -32), Vector3.new(-104, 0, -76), Vector3.new(-69, 0, -110), Vector3.new(-15, 0, -118), Vector3.new(44, 0, -116), Vector3.new(73, 0, -107)},
	{Vector3.new(-62, 0, 115), Vector3.new(-37, 0, 127), Vector3.new(8, 0, 129), Vector3.new(50, 0, 122), Vector3.new(67, 0, 114)},
	{Vector3.new(0, 0, 29), Vector3.new(0, 0, 60), Vector3.new(11, 0, 85), Vector3.new(8, 0, 129)},
}

local function route(points, number)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local midpoint = (a + b) / 2
		local length = (a - b).Magnitude
		local yaw = math.atan2(b.X - a.X, b.Z - a.Z)
		local frame = CFrame.new(midpoint.X, 4.025, midpoint.Z) * CFrame.Angles(0, yaw, 0)
		part("PathInk" .. number .. "_" .. index, Vector3.new(10.2, 0.10, length + 1), frame, colors.ink, paths, false).CastShadow = false
		part("Path" .. number .. "_" .. index, Vector3.new(8.8, 0.10, length + 1.3), frame + Vector3.new(0, 0.075, 0), colors.path, paths, false).CastShadow = false
	end
	for index, point in ipairs(points) do
		disc("PathInkJoin" .. number .. "_" .. index, 10.2, 0.10, Vector3.new(point.X, 4.025, point.Z), colors.ink, paths, false).CastShadow = false
		disc("PathJoin" .. number .. "_" .. index, 8.8, 0.10, Vector3.new(point.X, 4.10, point.Z), colors.path, paths, false).CastShadow = false
	end
end
for index, points in ipairs(pathRoutes) do route(points, index) end

local function tree(name, x, z, height, scale, tint, ground)
	ground = ground or 4
	local value = model(name, nature)
	local trunkHeight = height * 0.45
	part("Trunk", Vector3.new(2.6 * scale, trunkHeight, 2.6 * scale), Vector3.new(x, ground + trunkHeight / 2, z), colors.wood, value)
	local canopyY = ground + height * 0.70
	ball("Crown", Vector3.new(13 * scale, 11 * scale, 12 * scale), Vector3.new(x, canopyY, z), tint, value, false)
	ball("CrownLeft", Vector3.new(8 * scale, 8 * scale, 8 * scale), Vector3.new(x - 4.5 * scale, canopyY - scale, z + 0.5 * scale), colors.leaf, value, false)
	ball("CrownRight", Vector3.new(9 * scale, 8 * scale, 8 * scale), Vector3.new(x + 4.2 * scale, canopyY + 1.2 * scale, z - 0.6 * scale), colors.leafLight, value, false)
	outline(value)
	return value
end

local treeSites = {
	{-138, -106, 21, 1.10}, {-122, -125, 19, 0.95}, {-85, -130, 22, 1.1},
	{-43, -137, 18, 0.9}, {13, -136, 22, 1.1}, {52, -135, 18, 0.9},
	{137, -121, 24, 1.15}, {143, -82, 20, 1.0}, {139, -28, 22, 1.1},
	{144, 20, 19, 0.95}, {144, 58, 24, 1.15}, {139, 113, 22, 1.0},
	{106, 138, 21, 1.1}, {38, 142, 19, 0.9}, {-12, 141, 22, 1.0},
	{-107, 128, 23, 1.1}, {-138, 95, 19, 0.9}, {-140, 52, 22, 1.1},
	{-141, 4, 20, 1.0}, {-130, -61, 23, 1.1}, {-57, -70, 18, 0.9},
	{-29, -48, 18, 0.85}, {27, -67, 20, 0.95}, {51, -10, 17, 0.85},
	{-33, 72, 17, 0.8}, {32, 62, 19, 0.85}, {-112, 70, 19, 0.9},
}
for index, site in ipairs(treeSites) do
	tree("Tree" .. index, site[1], site[2], site[3], site[4], index % 3 == 0 and colors.leafLight or colors.leaf)
end

local function shrub(name, x, z, width, tint, ground)
	ground = ground or 4
	local value = model(name, nature)
	ball("Bush", Vector3.new(width, width * 0.58, width * 0.78), Vector3.new(x, ground + width * 0.20, z), tint or colors.leaf, value, false)
	ball("BushSide", Vector3.new(width * 0.55, width * 0.44, width * 0.60), Vector3.new(x + width * 0.32, ground + width * 0.13, z + width * 0.08), colors.leafLight, value, false)
	return value
end

for index, site in ipairs({{-117,-98,9},{-66,-130,10},{-10,-133,8},{114,-122,10},{138,-54,9},{134,47,10},{126,134,11},{61,140,8},{-76,131,8},{-135,114,10},{-131,30,10},{-90,8,9},{-66,-50,8},{44,-50,10},{59,15,8},{-28,92,9}}) do
	shrub("Shrub" .. index, site[1], site[2], site[3], index % 3 == 0 and colors.mint or colors.leaf)
end

local function flowerCluster(name, x, z, count, ground)
	ground = ground or 4
	local value = model(name, nature)
	for index = 1, count do
		local angle = index * 2.4
		local distance = 1.1 + (index % 3) * 1.1
		local fx, fz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
		part("Stem" .. index, Vector3.new(0.20, 1.3, 0.20), Vector3.new(fx, ground + 0.65, fz), colors.leaf, value, false)
		local tint = index % 3 == 0 and colors.pink or (index % 2 == 0 and colors.lilac or colors.white)
		for petal = 1, 4 do
			local theta = petal * math.pi / 2
			ball("Petal", Vector3.new(0.8, 0.45, 0.8), Vector3.new(fx + math.cos(theta) * 0.35, ground + 1.3, fz + math.sin(theta) * 0.35), tint, value, false)
		end
		ball("Center", Vector3.new(0.45, 0.42, 0.45), Vector3.new(fx, ground + 1.5, fz), colors.gold, value, false)
	end
	return value
end
for index, site in ipairs({{-120,-108},{-84,-119},{-51,-124},{23,-129},{128,-58},{127,28},{120,132},{29,135},{-22,133},{-123,106},{-132,23},{-92,-2},{-34,-39},{43,-37},{-29,103},{41,69}}) do
	flowerCluster("FlowerBed" .. index, site[1], site[2], 3)
end

local function bench(name, x, z, yaw, ground, tint)
	ground = ground or 4
	local value = model(name, furniture)
	local base = CFrame.new(x, ground, z) * CFrame.Angles(0, yaw, 0)
	for _, side in ipairs({-1, 1}) do
		part("Leg", Vector3.new(0.65, 2, 2.5), base * CFrame.new(side * 3.5, 1, 0), colors.ink, value)
	end
	part("Seat", Vector3.new(9, 0.60, 3), base * CFrame.new(0, 2, 0), tint or colors.cream, value)
	part("Back", Vector3.new(9, 2.1, 0.6), base * CFrame.new(0, 3.4, 1.2), tint or colors.cream, value)
	outline(value)
	return value
end
bench("PlazaBenchWest", -34, -15, math.pi / 2)
bench("PlazaBenchEast", 34, -16, -math.pi / 2)
bench("PromenadeBench", -19, -106, 0, 4, colors.mint)
bench("PondBench", -101, 115, math.pi, 4, colors.pink)
bench("SouthBench", 32, 115, math.pi, 4, colors.lilac)

local function rock(name, x, z, size, ground)
	ground = ground or 4
	local value = model(name, nature)
	local base = part("Stone", size, CFrame.new(x, ground + size.Y / 2, z) * CFrame.Angles(0, math.rad((x + z) % 45), 0), Color3.fromRGB(184, 204, 204), value)
	part("StoneCap", Vector3.new(size.X * 0.85, 0.3, size.Z * 0.86), base.CFrame * CFrame.new(0, size.Y / 2 + 0.1, 0), colors.cream, value)
	outline(value)
	return value
end
rock("LowRock", -105, 14, Vector3.new(9, 1.2, 8))
rock("MiddleRock", -111, 23, Vector3.new(10, 2.2, 8))
rock("WideRock", -101, 33, Vector3.new(12, 1.6, 8))
rock("PondRockWest", -108, 86, Vector3.new(5, 1.2, 4))
rock("PondRockEast", -20, 87, Vector3.new(6, 1.8, 5))
rock("NorthRock", 9, -95, Vector3.new(8, 1.4, 6))

local log = model("FallenLog", nature)
part("Log", Vector3.new(21, 3, 3), CFrame.new(-110, 5.5, 46) * CFrame.Angles(0, math.rad(-12), 0), colors.wood, log, true, Enum.PartType.Cylinder)
for _, side in ipairs({-1, 1}) do
	part("CutEnd", Vector3.new(0.14, 2.65, 2.65), CFrame.new(-110, 5.5, 46) * CFrame.Angles(0, math.rad(-12), 0) * CFrame.new(side * 10.6, 0, 0), colors.path, log, false, Enum.PartType.Cylinder)
end
outline(log)

part("PondBorder", Vector3.new(44, 0.14, 39.8), Vector3.new(-62, 4.00, 82), colors.ink, pond, false)
disc("PondBorderWest", 39.8, 0.14, Vector3.new(-84, 4.00, 82), colors.ink, pond, false)
disc("PondBorderEast", 39.8, 0.14, Vector3.new(-40, 4.00, 82), colors.ink, pond, false)
part("ShallowBottom", Vector3.new(44, 0.14, 37.4), Vector3.new(-62, 4.09, 82), colors.path, pond, false)
disc("ShallowBottomWest", 37.4, 0.14, Vector3.new(-84, 4.09, 82), colors.path, pond, false)
disc("ShallowBottomEast", 37.4, 0.14, Vector3.new(-40, 4.09, 82), colors.path, pond, false)
local waterSurfaces = {
	part("Water", Vector3.new(44, 0.12, 37), Vector3.new(-62, 4.18, 82), colors.water, pond, false),
	disc("WaterWest", 37, 0.12, Vector3.new(-84, 4.18, 82), colors.water, pond, false),
	disc("WaterEast", 37, 0.12, Vector3.new(-40, 4.18, 82), colors.water, pond, false),
}
for _, surface in ipairs(waterSurfaces) do
	surface.Transparency = 0.28
	surface.CastShadow = false
end
for index, site in ipairs({{-88,75},{-89,91},{-41,72},{-35,86},{-51,94}}) do
	disc("LilyPad" .. index, index % 2 == 0 and 3.4 or 2.8, 0.12, Vector3.new(site[1], 4.30, site[2]), colors.leaf, pond, false)
	if index % 2 == 0 then
		ball("LilyFlower", Vector3.new(0.9, 0.6, 0.9), Vector3.new(site[1], 4.65, site[2]), colors.pink, pond, false)
	end
end
for index, site in ipairs({{-94,68},{-95,97},{-32,68},{-29,99}}) do
	local reeds = model("Reeds" .. index, pond)
	for stem = 1, 3 do
		local rx, rz = site[1] + (stem - 2) * 0.6, site[2] + (stem % 2) * 0.7
		part("Stem", Vector3.new(0.16, 2.6, 0.16), Vector3.new(rx, 5.3, rz), colors.leaf, reeds, false)
		part("Tip", Vector3.new(0.40, 0.9, 0.4), Vector3.new(rx, 6.35, rz), colors.wood, reeds, false)
	end
end

local bridge = model("Footbridge", pond)
part("BridgeBase", Vector3.new(14, 0.60, 40), Vector3.new(-62, 6.08, 82), colors.ink, bridge)
for index = 1, 10 do
	part("Plank" .. index, Vector3.new(13.2, 0.30, 3.86), Vector3.new(-62, 6.25, 62 + (index - 0.5) * 4), index % 2 == 0 and colors.cream or colors.path, bridge)
end
for index = 1, 4 do
	local top = 4 + index * 0.6
	local northZ = 48.5 + index * 3
	local southZ = 115.5 - index * 3
	slab("NorthBridgeStep" .. index, Vector3.new(13.2, top - 4, 3), top, -62, northZ, colors.path, bridge)
	slab("SouthBridgeStep" .. index, Vector3.new(13.2, top - 4, 3), top, -62, southZ, colors.path, bridge)
end
for _, side in ipairs({-1, 1}) do
	part("SideRail", Vector3.new(0.70, 0.75, 40), Vector3.new(-62 + side * 6.6, 8.65, 82), colors.cream, bridge)
	for index = 0, 4 do
		part("Post", Vector3.new(0.9, 3.1, 0.9), Vector3.new(-62 + side * 6.6, 7.50, 63 + index * 9.5), colors.blue, bridge)
		ball("RoundCap", Vector3.new(1.1, 1.1, 1.1), Vector3.new(-62 + side * 6.6, 9.15, 63 + index * 9.5), colors.gold, bridge, false)
	end
end
outline(bridge)

local duck = model("PondDuck", pond)
ball("Body", Vector3.new(2.8, 1.3, 1.8), Vector3.new(-82, 4.9, 85), colors.white, duck, false)
ball("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(-83.0, 5.6, 85), colors.white, duck, false)
part("Beak", Vector3.new(0.8, 0.25, 0.65), Vector3.new(-83.7, 5.45, 85), colors.gold, duck, false)
ball("Eye", Vector3.new(0.16, 0.16, 0.16), Vector3.new(-83.13, 5.76, 84.51), colors.ink, duck, false)
outline(duck)

local terraceTops = {7, 10, 13, 16}
local terraceSizes = {Vector3.new(76, 3, 68), Vector3.new(60, 3, 56), Vector3.new(44, 3, 44), Vector3.new(28, 3, 32)}
local terraceCenters = {96, 102, 108, 114}
for index, top in ipairs(terraceTops) do
	slab("GrassTerrace" .. index, terraceSizes[index], top, 90, terraceCenters[index], index % 2 == 0 and colors.grassLight or colors.grass, terrace)
end
for index = 1, 16 do
	local top = 4 + index * 0.75
	slab("TerraceStep" .. index, Vector3.new(10, top - 4, 3), top, 90, 48.5 + index * 3, colors.path, terrace)
end
disc("PicnicPadInk", 24, 0.14, Vector3.new(90, 16.05, 114), colors.ink, terrace, false)
disc("PicnicPad", 22.7, 0.14, Vector3.new(90, 16.15, 114), colors.cream, terrace, false)
local picnic = model("PicnicTable", terrace)
part("TableTop", Vector3.new(10, 0.65, 4.4), Vector3.new(90, 19, 114), colors.path, picnic)
for _, side in ipairs({-1, 1}) do
	part("TableLeg", Vector3.new(0.7, 2.8, 3.8), Vector3.new(90 + side * 3.1, 17.55, 114), colors.ink, picnic)
	part("BenchSeat", Vector3.new(10, 0.60, 1.6), Vector3.new(90, 17.65, 114 + side * 3.5), colors.mint, picnic)
	for _, endSide in ipairs({-1, 1}) do
		part("BenchLeg", Vector3.new(0.6, 1.7, 1.3), Vector3.new(90 + endSide * 3.4, 16.85, 114 + side * 3.5), colors.ink, picnic)
	end
end
outline(picnic)
tree("TerraceTree", 115, 113, 16, 0.85, colors.leafLight, 10)
flowerCluster("TerraceFlowersWest", 69, 111, 4, 10)
flowerCluster("TerraceFlowersEast", 110, 123, 3, 13)

slab("ShopPaving", Vector3.new(42, 0.24, 38), 4.26, -111, -31, colors.cream, shop)
local kiosk = model("Kiosk", shop)
part("CounterBody", Vector3.new(7.5, 3.2, 25), Vector3.new(-120, 5.85, -31), colors.mint, kiosk)
part("CounterRim", Vector3.new(8.4, 0.6, 26), Vector3.new(-120, 7.5, -31), colors.ink, kiosk)
part("CounterTop", Vector3.new(8.0, 0.32, 25.4), Vector3.new(-120, 7.85, -31), colors.cream, kiosk)
for _, side in ipairs({-1, 1}) do
	part("AwningPost", Vector3.new(0.9, 8.8, 0.9), Vector3.new(-122.8, 8.65, -31 + side * 12), colors.blue, kiosk)
end
part("CanopyRim", Vector3.new(13.3, 0.9, 27), Vector3.new(-120, 13.10, -31), colors.ink, kiosk)
for index = 1, 6 do
	part("CanopyStripe" .. index, Vector3.new(12.6, 0.7, 4.35), Vector3.new(-120, 13.38, -44.05 + (index - 0.5) * 4.35), index % 2 == 0 and colors.pink or colors.cream, kiosk)
end
for index = 1, 3 do
	disc("DisplayPlinth" .. index, 3.8, 0.5, Vector3.new(-120, 8.25, -39 + (index - 1) * 8), colors.blue, kiosk)
	ball("DisplayBubble" .. index, Vector3.new(2.3, 2.3, 2.3), Vector3.new(-120, 9.6, -39 + (index - 1) * 8), index == 1 and colors.gold or (index == 2 and colors.pink or colors.lilac), kiosk, false)
end
outline(kiosk)
bench("ShopBench", -97, -43, -math.pi / 2, 4.26, colors.lilac)
marker("ShopZone", Vector3.new(34, 12, 38), Vector3.new(-107, 10, -31), gameplay)

slab("VotingPaving", Vector3.new(68, 0.26, 54), 4.28, 88, -82, colors.lilac, voting)
slab("VotingInner", Vector3.new(63, 0.18, 49), 4.46, 88, -82, colors.cream, voting)
for _, site in ipairs({{56,-105},{120,-105},{56,-59},{120,-59}}) do
	disc("PlanterBase", 5.5, 1.0, Vector3.new(site[1], 4.75, site[2]), colors.ink, voting)
	disc("Planter", 4.9, 1.0, Vector3.new(site[1], 5.10, site[2]), colors.path, voting)
	shrub("VotingShrub", site[1], site[2], 5.7, colors.mint, 5.2)
end

local choiceData = {
	{key = "BritishBulldog", label = "British Bulldog", x = 71, color = colors.blue},
	{key = "TagYoureIt", label = "Tag You're It", x = 105, color = colors.pink},
}
for _, data in ipairs(choiceData) do
	local stand = model(data.key .. "Stand", voting)
	slab("ChoicePad", Vector3.new(25, 0.24, 28), 4.70, data.x, -84, data.color, stand)
	for _, side in ipairs({-1, 1}) do
		part("ArchPost", Vector3.new(1.3, 10, 1.3), Vector3.new(data.x + side * 11.4, 9.70, -96), colors.blue, stand)
		ball("ArchCap", Vector3.new(1.6, 1.6, 1.6), Vector3.new(data.x + side * 11.4, 14.80, -96), colors.gold, stand, false)
	end
	part("ArchTop", Vector3.new(24.5, 1.5, 2.1), Vector3.new(data.x, 14.15, -96), colors.cream, stand)
	part("ChoiceCard", Vector3.new(19, 5.0, 0.65), Vector3.new(data.x, 10.65, -96), colors.ink, stand)
	part("ChoiceCardFace", Vector3.new(18.3, 4.35, 0.20), Vector3.new(data.x, 10.65, -95.55), data.color, stand)
	local pad = marker(data.key, Vector3.new(25, 8, 28), Vector3.new(data.x, 8.6, -84), voteChoices)
	pad:SetAttribute("GameId", data.key)
	pad:SetAttribute("DisplayName", data.label)
	pad:SetAttribute("Available", true)
	local label = Instance.new("SurfaceGui")
	label.Name = "GameName"
	label.Face = Enum.NormalId.Back
	label.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	label.PixelsPerStud = 38
	label.AlwaysOnTop = false
	label.LightInfluence = 0
	label.Parent = stand.ChoiceCardFace
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.Text = data.label
	text.TextColor3 = colors.white
	text.TextStrokeColor3 = colors.ink
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.TextWrapped = true
	text.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = text
	outline(stand)
end

local voteZone = marker("VoteZone", Vector3.new(74, 12, 60), Vector3.new(88, 10, -82), gameplay)
voteZone:SetAttribute("IsVotingArea", true)
voteZone:SetAttribute("AvailableGames", "BritishBulldog,TagYoureIt")
marker("LobbyBounds", Vector3.new(320, 80, 304), Vector3.new(0, 40, 0), gameplay)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 4.6, 0)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanTouch = false
spawn.CanQuery = false
spawn.Enabled = true
spawn.Neutral = true
spawn.Duration = 0
spawn.AllowTeamChangeOnTouch = false
spawn:SetAttribute("PlaygroundLobbySpawn", true)
spawn.Parent = gameplay
partCount += 1

local coinSites = {
	Vector3.new(0, 6.4, 43), Vector3.new(-39, 6.4, -9), Vector3.new(-84, 6.4, -27),
	Vector3.new(-88, 6.4, -94), Vector3.new(7, 6.4, -118), Vector3.new(66, 6.4, -114),
	Vector3.new(-62, 8.7, 82), Vector3.new(-101, 7.8, 33), Vector3.new(90, 18.4, 100),
	Vector3.new(34, 6.4, 126),
}
for index, position in ipairs(coinSites) do
	local value = marker(string.format("Coin%02d", index), Vector3.new(1, 1, 1), position, coinSpawns)
	value:SetAttribute("PickupId", "LobbyCoin" .. index)
	value:SetAttribute("Value", 1)
	value:SetAttribute("RespawnSeconds", 45)
end

root:SetAttribute("PartCount", partCount)
root:SetAttribute("NavigationStepHeight", 0.75)
root:SetAttribute("BridgeStepHeight", 0.6)
root:SetAttribute("MainPathWidth", 8.8)
root:SetAttribute("SpawnPlazaDiameter", 61)
root:SetAttribute("WaterIsDecorative", true)

return {
	created = true,
	folder = root:GetFullName(),
	parts = partCount,
	bounds = {320, 80, 304},
	floorY = 4,
	spawn = {0, 4.6, 0},
	voteZone = {center = {88, 10, -82}, size = {74, 12, 60}},
	shopZone = {center = {-107, 10, -31}, size = {34, 12, 38}},
	coinSpawns = #coinSites,
	navigation = {pathWidth = 8.8, bridgeWidth = 13.2, terraceStep = 0.75, bridgeStep = 0.6, highestFloor = 16},
}

end
local function buildLobbyDepth()
local lobby = workspace:FindFirstChild("Playground Lobby")
assert(lobby and lobby:GetAttribute("PlaygroundManaged") == true, "Install the managed Playground Lobby first")
local existing = lobby:FindFirstChild("Improvements20261003")
if existing then
	assert(existing:GetAttribute("PlaygroundManaged") == true, "Unmanaged lobby improvements already exist")
	return {created = false, applied = existing:GetAttribute("Applied") == true, version = existing:GetAttribute("Version")}
end

local root = Instance.new("Folder")
root.Name = "Improvements20261003"
root:SetAttribute("PlaygroundManaged", true)
root:SetAttribute("Version", 1)
root:SetAttribute("Applied", false)
root.Parent = lobby

local palette = {
	ink = Color3.fromRGB(62, 65, 50),
	rock = Color3.fromRGB(147, 111, 82),
	rockDark = Color3.fromRGB(119, 87, 66),
	rockLight = Color3.fromRGB(173, 131, 94),
	grass = Color3.fromRGB(88, 165, 83),
	grassBright = Color3.fromRGB(108, 181, 91),
	grassDark = Color3.fromRGB(66, 145, 72),
	leaf = Color3.fromRGB(44, 138, 65),
	leafBright = Color3.fromRGB(74, 166, 69),
	leafDark = Color3.fromRGB(33, 116, 62),
	wood = Color3.fromRGB(139, 93, 55),
	woodDark = Color3.fromRGB(88, 61, 40),
	woodLight = Color3.fromRGB(189, 145, 91),
	cream = Color3.fromRGB(246, 227, 184),
	sand = Color3.fromRGB(228, 204, 157),
	water = Color3.fromRGB(77, 175, 193),
	waterLight = Color3.fromRGB(147, 221, 227),
	foam = Color3.fromRGB(229, 250, 239),
	coral = Color3.fromRGB(205, 88, 72),
	gold = Color3.fromRGB(239, 188, 65),
	blue = Color3.fromRGB(70, 157, 191),
	pink = Color3.fromRGB(224, 139, 160),
}

local count = 0
local function folder(name, parent)
	local value = Instance.new("Folder")
	value.Name = name
	value.Parent = parent or root
	return value
end
local cliffs = folder("PerimeterCliffs")
local ledges = folder("GreenLedges")
local waterfall = folder("WaterfallAndStream")
local cave = folder("CaveAlcove")
local architecture = folder("SocialBuilding")
local tower = folder("LookoutTower")
local greenery = folder("TreeAndFlowerGroups")
local routeDetails = folder("RoutesAndFurniture")

local function part(name, size, frame, color, parent, collide, shape, className)
	local value = Instance.new(className or "Part")
	value.Name = name
	value.Size = size
	value.CFrame = typeof(frame) == "CFrame" and frame or CFrame.new(frame)
	value.Color = color
	value.Material = Enum.Material.SmoothPlastic
	value.Anchored = true
	value.CanCollide = collide ~= false
	value.CanTouch = false
	value.CanQuery = collide ~= false
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	if shape then value.Shape = shape end
	value.Parent = parent
	count += 1
	return value
end
local function disc(name, diameter, height, position, color, parent, collide)
	return part(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, parent, collide, Enum.PartType.Cylinder)
end
local function ball(name, size, frame, color, parent, collide)
	return part(name, size, frame, color, parent, collide, Enum.PartType.Ball)
end
local function model(name, parent)
	local value = Instance.new("Model")
	value.Name = name
	value.Parent = parent
	return value
end
local function outline(value)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SoftCartoonOutline"
	highlight.Adornee = value
	highlight.FillTransparency = 1
	highlight.OutlineColor = palette.ink
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = value
end
local function beam(name, a, b, width, height, color, parent, collide)
	return part(name, Vector3.new(width, height, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, parent, collide)
end
local function patch(name, x, z, top, width, depth, parent, tint)
	part(name .. "Soil", Vector3.new(width + 0.5, 0.40, depth + 0.5), Vector3.new(x, top - 0.20, z), palette.rockDark, parent)
	return part(name, Vector3.new(width, 0.28, depth), Vector3.new(x, top + 0.02, z), tint or palette.grass, parent)
end

for _, value in ipairs(lobby.Island:GetChildren()) do
	if value:IsA("BasePart") then
		value.Color = string.find(value.Name, "Grass", 1, true) and palette.grass or palette.rockDark
	end
end
for _, value in ipairs(lobby.Paths:GetDescendants()) do
	if value:IsA("BasePart") then
		if string.find(value.Name, "Ink", 1, true) then value.Color = Color3.fromRGB(94, 107, 77)
		elseif string.find(value.Name, "Mint", 1, true) then value.Color = palette.grassBright
		elseif string.find(value.Name, "Inlay", 1, true) then value.Color = palette.gold
		else value.Color = value.Name == "PlazaCenter" and palette.woodLight or palette.sand end
	end
end
for _, value in ipairs(lobby.PicnicTerrace:GetDescendants()) do
	if value:IsA("BasePart") and string.find(value.Name, "GrassTerrace", 1, true) then
		value.Color = string.find(value.Name, "Rim", 1, true) and palette.rockDark or palette.grassBright
	elseif value:IsA("BasePart") and string.find(value.Name, "TerraceStep", 1, true) then
		value.Color = string.find(value.Name, "Rim", 1, true) and palette.woodDark or palette.sand
	end
end
for _, value in ipairs(lobby.Nature:GetDescendants()) do
	if value:IsA("BasePart") then
		if value.Name == "Trunk" or value.Name == "Log" then value.Color = palette.wood
		elseif value.Name == "Crown" then value.Color = palette.leaf
		elseif value.Name == "CrownLeft" then value.Color = palette.leafDark
		elseif value.Name == "CrownRight" then value.Color = palette.leafBright
		elseif string.find(value.Name, "Bush", 1, true) then value.Color = palette.leaf
		elseif string.find(value.Name, "Stem", 1, true) then value.Color = palette.leafDark end
	elseif value:IsA("Highlight") then
		value.OutlineColor = palette.ink
		value.OutlineTransparency = 0.35
	end
end
for _, value in ipairs(lobby.Pond:GetDescendants()) do
	if value:IsA("BasePart") and string.sub(value.Name, 1, 5) == "Water" then
		value.Color = palette.water
		value.Transparency = 0.18
	end
end

local cliffTops = {}
local function cliffColumn(name, x, z, width, depth, height, yaw, facing, number)
	local value = model(name, cliffs)
	local cf = CFrame.new(x, 4 + height / 2, z) * CFrame.Angles(0, yaw, 0)
	part("RockMass", Vector3.new(width, height, depth), cf, number % 3 == 0 and palette.rockDark or palette.rock, value)
	part("Crest", Vector3.new(width * 0.91, 3.8, depth * 0.93), CFrame.new(x, 4 + height + 0.8, z) * CFrame.Angles(0, yaw + math.rad(10), 0), palette.rockLight, value)
	local front = Vector3.new(x, 4 + height * 0.42, z) + facing * (math.min(width, depth) / 2 + 0.6)
	local faceSize = math.abs(facing.X) > 0.5 and Vector3.new(5, height * 0.53, depth * 0.45) or Vector3.new(width * 0.44, height * 0.53, 5)
	part("BrokenFace", faceSize, CFrame.new(front) * CFrame.Angles(0, yaw + math.rad(number % 2 == 0 and 9 or -7), 0), number % 2 == 0 and palette.rockLight or palette.rockDark, value)
	if number % 2 == 0 then
		local top = 4 + height + 2.9
		patch("CrestGrass", x + facing.X * 4, z + facing.Z * 4, top, width * 0.56, depth * 0.53, value, palette.grassBright)
	end
	table.insert(cliffTops, {x = x, z = z, y = 4 + height})
	return value
end
for index = 0, 10 do
	local x = -160 + index * 32
	local northHeight = 44 + (index * 7 % 6) * 5
	local southHeight = 43 + (index * 11 % 5) * 6
	cliffColumn("North" .. index, x, -160, 42, 38, northHeight, math.rad(index % 2 == 0 and 5 or -5), Vector3.new(0, 0, 1), index)
	cliffColumn("South" .. index, x, 160, 42, 38, southHeight, math.rad(index % 2 == 0 and -4 or 4), Vector3.new(0, 0, -1), index + 11)
end
for index = 0, 8 do
	local z = -128 + index * 32
	local westHeight = 48 + (index * 7 % 5) * 6
	local eastHeight = 46 + (index * 3 % 6) * 5
	cliffColumn("West" .. index, -164, z, 40, 42, westHeight, math.rad(index % 2 == 0 and 4 or -4), Vector3.new(1, 0, 0), index + 22)
	cliffColumn("East" .. index, 164, z, 40, 42, eastHeight, math.rad(index % 2 == 0 and -5 or 5), Vector3.new(-1, 0, 0), index + 31)
end
for _, x in ipairs({-160, 160}) do
	for _, z in ipairs({-152, 152}) do
		part("CornerMass", Vector3.new(54, 59, 54), CFrame.new(x, 33.5, z) * CFrame.Angles(0, math.pi / 4, 0), palette.rock, cliffs)
		part("CornerCrest", Vector3.new(43, 4, 43), CFrame.new(x, 65, z) * CFrame.Angles(0, math.pi / 4, 0), palette.rockLight, cliffs)
	end
end

part("NorthLedgeBase", Vector3.new(248, 23, 18), Vector3.new(-5, 15.5, -132), palette.rock, ledges)
patch("NorthLedgeGrass", -5, -132, 27, 248, 18, ledges)
part("WestGardenBase", Vector3.new(28, 10, 32), Vector3.new(-122, 9, 116), palette.rock, ledges)
patch("WestGardenGrass", -122, 116, 14, 28, 32, ledges, palette.grassBright)
part("WestTreeShelf", Vector3.new(12, 15, 64), Vector3.new(-138, 11.5, 4), palette.rockDark, ledges)
patch("WestTreeShelfGrass", -138, 4, 19, 12, 64, ledges)
part("EastTreeShelf", Vector3.new(12, 20, 120), Vector3.new(138, 14, 12), palette.rock, ledges)
patch("EastTreeShelfGrass", 138, 12, 24, 12, 120, ledges)
part("SouthTreeShelf", Vector3.new(136, 19, 12), Vector3.new(12, 13.5, 136), palette.rockDark, ledges)
patch("SouthTreeShelfGrass", 12, 136, 23, 136, 12, ledges)

local stairsData = {}
local function stairs(name, start, direction, steps, run, rise, width, parent)
	local value = model(name, parent)
	local right = Vector3.new(-direction.Z, 0, direction.X)
	local yaw = math.atan2(direction.X, direction.Z)
	local previous = {}
	for index = 1, steps do
		local center = start + direction * ((index - 0.5) * run) + Vector3.new(0, index * rise - 0.3, 0)
		part("Step" .. index, Vector3.new(width, 0.6, run + 0.12), CFrame.new(center) * CFrame.Angles(0, yaw, 0), index % 2 == 0 and palette.woodLight or palette.sand, value)
		part("StepNose" .. index, Vector3.new(width, 0.12, 0.22), CFrame.new(center + direction * (-run / 2 + 0.08) + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, yaw, 0), palette.woodDark, value, false)
		if index == 1 or index == steps or index % 4 == 0 then
			for _, side in ipairs({-1, 1}) do
				local railPoint = center + right * (side * (width / 2 - 0.35)) + Vector3.new(0, 2.9, 0)
				part("RailPost", Vector3.new(0.6, 3.0, 0.6), railPoint - Vector3.new(0, 1.1, 0), palette.woodDark, value)
				ball("PostCap", Vector3.new(0.85, 0.85, 0.85), railPoint + Vector3.new(0, 0.3, 0), palette.cream, value, false)
				if previous[side] then beam("Handrail", previous[side], railPoint, 0.45, 0.55, palette.cream, value) end
				previous[side] = railPoint
				if index % 8 == 0 then
					local height = center.Y - 4
					part("Trestle", Vector3.new(0.8, height, 0.8), Vector3.new(railPoint.X, 4 + height / 2, railPoint.Z), palette.woodDark, value)
				end
			end
		end
	end
	local finish = start + direction * (steps * run) + Vector3.new(0, steps * rise, 0)
	table.insert(stairsData, {name = name, count = steps, rise = rise, run = run, width = width, start = {start.X, start.Y, start.Z}, finish = {finish.X, finish.Y, finish.Z}})
	return value, finish
end
stairs("NorthGardenStairs", Vector3.new(-65, 4, -36), Vector3.new(0, 0, -1), 30, 2.8, 23 / 30, 14, ledges)
part("NorthLanding", Vector3.new(14, 0.60, 6), Vector3.new(-65, 26.7, -123), palette.sand, ledges)
stairs("WestGardenStairs", Vector3.new(-119, 4, 65), Vector3.new(0, 0, 1), 14, 2.5, 10 / 14, 14, ledges)

for _, value in ipairs(lobby.Nature:GetChildren()) do
	if value:IsA("Model") then
		local trunk = value:FindFirstChild("Trunk")
		if trunk and trunk:IsA("BasePart") then
			local position = trunk.Position
			local offset = Vector3.zero
			if position.Z <= -120 then
				offset = Vector3.new(math.clamp(position.X, -119, 110) - position.X, 23.15, -132 - position.Z)
			elseif position.X >= 130 then
				if position.Z < -48 or position.Z > 72 then
					local height = position.Z < -48 and 30 or 32
					part(value.Name .. "Perch", Vector3.new(18, height - 4, 20), Vector3.new(136, 4 + (height - 4) / 2, position.Z), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", 136, position.Z, height, 18, 20, ledges)
					offset = Vector3.new(136 - position.X, height - 4 + 0.15, 0)
				else
					offset = Vector3.new(136 - position.X, 20.15, 0)
				end
			elseif position.X <= -130 then
				if position.Z >= 90 then offset = Vector3.new(-127 - position.X, 10.15, 118 - position.Z)
				elseif position.Z >= -28 and position.Z <= 35 then offset = Vector3.new(-136 - position.X, 15.15, 0)
				else
					local z = math.clamp(position.Z, -100, 100)
					part(value.Name .. "Perch", Vector3.new(26, 8, 22), Vector3.new(-139, 46, z), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", -139, z, 50, 26, 22, ledges)
					offset = Vector3.new(-135 - position.X, 46.15, z - position.Z)
				end
			elseif position.Z >= 130 then
				if position.X < -56 or position.X > 80 then
					part(value.Name .. "Perch", Vector3.new(22, 24, 14), Vector3.new(position.X, 16, 135), palette.rock, ledges)
					patch(value.Name .. "PerchGrass", position.X, 135, 28, 22, 14, ledges)
					offset = Vector3.new(0, 24.15, 135 - position.Z)
				else offset = Vector3.new(0, 19.15, 135 - position.Z) end
			end
			if value.Name == "Tree21" then offset += Vector3.new(10, 0, 0) end
			if value.Name == "Tree27" then offset += Vector3.new(5, 0, 0) end
			if offset ~= Vector3.zero then value:PivotTo(value:GetPivot() + offset) end
		elseif string.find(value.Name, "FlowerBed", 1, true) or string.find(value.Name, "Shrub", 1, true) then
			local cf = value:GetBoundingBox()
			if cf.Position.Z < -122 then value:PivotTo(value:GetPivot() + Vector3.new(0, 23.2, -132 - cf.Position.Z))
			elseif cf.Position.X > 130 then value:PivotTo(value:GetPivot() + Vector3.new(136 - cf.Position.X, 20.2, math.clamp(cf.Position.Z, -43, 68) - cf.Position.Z))
			elseif cf.Position.X < -128 and cf.Position.Z > 99 then value:PivotTo(value:GetPivot() + Vector3.new(-127 - cf.Position.X, 10.2, 117 - cf.Position.Z))
			elseif cf.Position.X < -130 and cf.Position.Z >= -28 and cf.Position.Z <= 35 then value:PivotTo(value:GetPivot() + Vector3.new(-136 - cf.Position.X, 15.2, 0))
			elseif cf.Position.Z > 130 and cf.Position.X >= -56 and cf.Position.X <= 80 then value:PivotTo(value:GetPivot() + Vector3.new(0, 19.2, 135 - cf.Position.Z))
			elseif cf.Position.Z > 130 and cf.Position.X > 80 then value:PivotTo(value:GetPivot() + Vector3.new(116 - cf.Position.X, 6.2, 125 - cf.Position.Z)) end
		end
	end
end

local function tree(name, x, z, ground, scale, style)
	local value = model(name, greenery)
	part("Trunk", Vector3.new(2.4 * scale, 8.2 * scale, 2.4 * scale), Vector3.new(x, ground + 4.1 * scale, z), palette.wood, value)
	if style == "Fir" then
		for index = 1, 4 do
			local width = (15 - index * 2.7) * scale
			part("FirTier" .. index, Vector3.new(width, 4.7 * scale, width), CFrame.new(x, ground + (7 + index * 3.1) * scale, z) * CFrame.Angles(0, math.pi / 4, 0), index % 2 == 0 and palette.leaf or palette.leafBright, value, false)
		end
	else
		part("Branch", Vector3.new(1.1 * scale, 5.7 * scale, 1.1 * scale), CFrame.new(x + 1.6 * scale, ground + 7 * scale, z) * CFrame.Angles(0, 0, math.rad(-33)), palette.wood, value)
		for index, site in ipairs({{0,12,0,12,7,11},{-4,10,1,9,6,8},{4,14,-1,9,6,9}}) do
			part("FacetedCrown" .. index, Vector3.new(site[4], site[5], site[6]) * scale, CFrame.new(x + site[1] * scale, ground + site[2] * scale, z + site[3] * scale) * CFrame.Angles(0, math.rad(index * 17), 0), index == 2 and palette.leafDark or palette.leafBright, value, false)
		end
	end
	outline(value)
	return value
end
local treeSites = {
	{"NorthFir1",-100,-132,27,0.85,"Fir"}, {"NorthFir2",-79,-133,27,1.0,"Fir"}, {"NorthTree1",-33,-132,27,1.1,"Round"},
	{"NorthFir3",27,-132,27,0.9,"Fir"}, {"NorthTree2",82,-132,27,1.0,"Round"},
	{"TowerFir",111,-25,4,0.9,"Fir"}, {"TowerTree",114,9,4,1.1,"Round"},
	{"VoteFir",132,-106,4,0.88,"Fir"}, {"ShopFir",-128,-69,4,1.0,"Fir"},
	{"PondFir",-30,110,4,0.9,"Fir"}, {"WaterfallTree",-137,93,38,0.9,"Round"},
	{"WestGardenTree",-126,122,14,0.95,"Round"}, {"CaveRoofFir",-140,51,17.2,0.74,"Fir"},
	{"SouthFir",-22,136,23,0.9,"Fir"}, {"SouthTree",49,136,23,0.9,"Round"},
	{"EastFir",136,39,24,0.85,"Fir"}, {"EastTree",136,-15,24,0.95,"Round"},
}
for _, site in ipairs(treeSites) do tree(site[1], site[2], site[3], site[4], site[5], site[6]) end

part("WaterfallRock", Vector3.new(22, 34, 26), CFrame.new(-140, 21, 84) * CFrame.Angles(0, math.rad(-5), 0), palette.rockDark, waterfall)
part("WaterfallUpperShelf", Vector3.new(26, 4.4, 32), Vector3.new(-140, 35.8, 84), palette.rock, waterfall)
patch("WaterfallShelfGrass", -140, 84, 38, 26, 32, waterfall)
local upperWater = part("UpperPool", Vector3.new(15, 0.18, 16), Vector3.new(-134, 38.25, 84), palette.water, waterfall, false)
upperWater.Transparency = 0.10
local sheet = part("FallingWater", Vector3.new(0.45, 34.4, 10), Vector3.new(-128.05, 21.0, 84), palette.water, waterfall, false)
sheet.Transparency = 0.10
for index = 1, 5 do
	local stripe = part("WaterRibbon" .. index, Vector3.new(0.16, 32.6 - (index % 2) * 1.8, 0.8 + (index % 2) * 0.3), Vector3.new(-127.75, 21.0, 79.7 + index * 1.4), index % 2 == 0 and palette.waterLight or palette.foam, waterfall, false)
	stripe.Transparency = index % 2 == 0 and 0.12 or 0.30
end
part("StreamBed", Vector3.new(28, 0.14, 12), Vector3.new(-114, 4.08, 84), palette.rockDark, waterfall, false)
local stream = part("Stream", Vector3.new(28, 0.15, 10.5), Vector3.new(-114, 4.20, 84), palette.water, waterfall, false)
stream.Transparency = 0.12
disc("SplashPool", 15.5, 0.16, Vector3.new(-126, 4.26, 84), palette.waterLight, waterfall, false)
for index = 1, 7 do
	local theta = index * math.pi * 2 / 7
	ball("Foam", Vector3.new(2.6, 0.75, 1.8), Vector3.new(-126 + math.cos(theta) * 5, 4.65, 84 + math.sin(theta) * 4), palette.foam, waterfall, false)
end
for _, side in ipairs({-1, 1}) do
	part("StreamBank", Vector3.new(27, 0.55, 2.0), CFrame.new(-114, 4.25, 84 + side * 6.2) * CFrame.Angles(0, math.rad(side * 3), 0), palette.rock, waterfall, false)
	for index = 1, 3 do
		ball("RiverRock", Vector3.new(2.8, 1.6, 2.3), Vector3.new(-130 + index * 8, 4.60, 84 + side * 7.2), palette.rockLight, waterfall)
	end
end

part("CaveBack", Vector3.new(2.4, 11.4, 24), Vector3.new(-143, 9.7, 54), palette.woodDark, cave)
part("CaveWestWall", Vector3.new(18, 11.4, 3.8), CFrame.new(-134.8, 9.7, 41.7) * CFrame.Angles(0, math.rad(-4), 0), palette.rock, cave)
part("CaveEastWall", Vector3.new(18, 11.4, 3.8), CFrame.new(-134.8, 9.7, 66.3) * CFrame.Angles(0, math.rad(3), 0), palette.rockDark, cave)
part("CaveRoof", Vector3.new(21, 3.0, 28), Vector3.new(-134.5, 15.55, 54), palette.rock, cave)
patch("CaveRoofGrass", -134.5, 54, 17.1, 21, 28, cave)
part("CaveFloor", Vector3.new(18, 0.30, 20), Vector3.new(-134.2, 4.15, 54), palette.sand, cave)
part("CaveFrontLeft", Vector3.new(3.5, 9.6, 4.5), CFrame.new(-126.7, 8.8, 42.8) * CFrame.Angles(0, 0, math.rad(-6)), palette.rockLight, cave)
part("CaveFrontRight", Vector3.new(3.5, 9.6, 4.5), CFrame.new(-126.7, 8.8, 65.2) * CFrame.Angles(0, 0, math.rad(5)), palette.rockLight, cave)
part("CaveFrontTop", Vector3.new(3.5, 2.4, 24), Vector3.new(-126.7, 13.8, 54), palette.rockLight, cave)
part("CaveBench", Vector3.new(3, 0.65, 10), Vector3.new(-139, 6.15, 54), palette.woodLight, cave)
for _, z in ipairs({50, 58}) do part("CaveBenchLeg", Vector3.new(2.4, 2.0, 0.65), Vector3.new(-139, 5.0, z), palette.woodDark, cave) end
local lantern = part("CaveLantern", Vector3.new(1.1, 1.5, 1.1), Vector3.new(-139.5, 9.2, 44.3), palette.gold, cave, false)
local light = Instance.new("PointLight")
light.Name = "WarmLantern"
light.Color = palette.cream
light.Range = 18
light.Brightness = 0.6
light.Shadows = false
light.Parent = lantern
beam("CaveApproach", Vector3.new(-124, 4.12, 54), Vector3.new(-104, 4.12, 54), 8.3, 0.20, palette.sand, routeDetails, false)

part("BuildingFoundation", Vector3.new(34, 0.65, 44), Vector3.new(-123.5, 4.35, -31), palette.rockDark, architecture)
part("BuildingFloor", Vector3.new(32, 0.30, 42), Vector3.new(-123.5, 4.73, -31), palette.woodLight, architecture)
part("BackWall", Vector3.new(1.5, 11.5, 42), Vector3.new(-138.5, 10.25, -31), palette.cream, architecture)
for _, z in ipairs({-52, -10}) do
	part("SideWall", Vector3.new(32, 11.5, 1.5), Vector3.new(-123.5, 10.25, z), palette.cream, architecture)
	part("SideBaseTrim", Vector3.new(32.5, 1.5, 1.9), Vector3.new(-123.5, 5.3, z), palette.woodDark, architecture)
	part("SideTopTrim", Vector3.new(33, 0.65, 1.9), Vector3.new(-123.5, 15.95, z), palette.woodDark, architecture)
	part("SideWindowFrame", Vector3.new(15, 5.3, 0.5), Vector3.new(-124, 10.6, z + (z < -31 and -0.80 or 0.80)), palette.woodDark, architecture, false)
	local glass = part("SideWindow", Vector3.new(14.1, 4.4, 0.22), Vector3.new(-124, 10.6, z + (z < -31 and -1.08 or 1.08)), palette.waterLight, architecture, false)
	glass.Transparency = 0.35
	for index = -1, 1 do part("WindowMullion", Vector3.new(0.3, 4.5, 0.26), Vector3.new(-124 + index * 4.4, 10.6, z + (z < -31 and -1.25 or 1.25)), palette.woodDark, architecture, false) end
end
for _, side in ipairs({-1, 1}) do
	local z = -31 + side * 14.2
	part("FrontWall", Vector3.new(1.5, 11.5, 13.4), Vector3.new(-108.5, 10.25, z), palette.cream, architecture)
	part("FrontBaseTrim", Vector3.new(1.95, 1.5, 13.4), Vector3.new(-108.5, 5.3, z), palette.woodDark, architecture)
	part("FrontWindowFrame", Vector3.new(0.5, 5.1, 9.0), Vector3.new(-107.55, 10.55, z), palette.woodDark, architecture, false)
	local glass = part("FrontWindow", Vector3.new(0.22, 4.3, 8.3), Vector3.new(-107.15, 10.55, z), palette.waterLight, architecture, false)
	glass.Transparency = 0.35
	part("FrontWindowCross", Vector3.new(0.3, 4.5, 0.3), Vector3.new(-107.0, 10.55, z), palette.woodDark, architecture, false)
	part("FrontWindowCrossHorizontal", Vector3.new(0.3, 0.3, 8.4), Vector3.new(-107.0, 10.55, z), palette.woodDark, architecture, false)
end
part("DoorLintel", Vector3.new(2.0, 2.7, 15), Vector3.new(-108.4, 14.35, -31), palette.wood, architecture)
for _, z in ipairs({-38.4, -23.6}) do part("DoorFrame", Vector3.new(2.0, 8.3, 0.80), Vector3.new(-108.25, 8.7, z), palette.woodDark, architecture) end
part("FrontHeader", Vector3.new(2, 0.8, 44), Vector3.new(-108.5, 15.95, -31), palette.woodDark, architecture)
local roofPitch = math.atan(4.2 / 24)
part("NorthRoofSlope", Vector3.new(36, 0.95, 24.4), CFrame.new(-123.5, 18.50, -43) * CFrame.Angles(-roofPitch, 0, 0), palette.wood, architecture)
part("SouthRoofSlope", Vector3.new(36, 0.95, 24.4), CFrame.new(-123.5, 18.50, -19) * CFrame.Angles(roofPitch, 0, 0), palette.wood, architecture)
part("RoofRidge", Vector3.new(36.3, 0.75, 1.0), Vector3.new(-123.5, 20.6, -31), palette.woodDark, architecture)
for _, z in ipairs({-55, -7}) do part("EaveBeam", Vector3.new(36.6, 0.70, 1.0), Vector3.new(-123.5, 16.45, z), palette.woodDark, architecture) end
part("PorchFloor", Vector3.new(13.5, 0.65, 26), Vector3.new(-102.5, 4.55, -31), palette.woodLight, architecture)
part("PorchRoof", Vector3.new(14.4, 0.75, 27.2), CFrame.new(-102.4, 12.3, -31) * CFrame.Angles(0, 0, math.rad(3)), palette.wood, architecture)
part("PorchFrontBeam", Vector3.new(1.0, 1.0, 27.6), Vector3.new(-96.2, 12.0, -31), palette.woodDark, architecture)
for _, z in ipairs({-43.6, -18.4}) do
	part("PorchPost", Vector3.new(0.95, 7.8, 0.95), Vector3.new(-97, 8.1, z), palette.cream, architecture)
	part("PorchPostFoot", Vector3.new(1.5, 0.75, 1.5), Vector3.new(-97, 5.12, z), palette.woodDark, architecture)
	part("PorchBracket", Vector3.new(0.8, 2.2, 0.8), CFrame.new(-98.0, 11.3, z) * CFrame.Angles(0, 0, math.rad(-40)), palette.woodDark, architecture, false)
end
part("PorchEntryStep", Vector3.new(3.0, 0.35, 14), Vector3.new(-94.4, 4.2, -31), palette.sand, architecture)
part("PorchEntryStepTop", Vector3.new(2.4, 0.30, 14), Vector3.new(-96.0, 4.5, -31), palette.sand, architecture)
local oldBench = lobby.Furniture:FindFirstChild("ShopBench")
if oldBench and oldBench:IsA("Model") then oldBench:PivotTo(oldBench:GetPivot() + Vector3.new(5, -0.26, -6)) end
for _, side in ipairs({-1, 1}) do
	local box = model("PorchFlowerBox", architecture)
	part("Box", Vector3.new(2.4, 1.3, 6.5), Vector3.new(-101, 5.7, -31 + side * 11.7), palette.woodDark, box)
	for index = 1, 4 do
		ball("BoxLeaves", Vector3.new(2.3, 1.8, 2.2), Vector3.new(-101, 6.8, -34 + side * 11.7 + index * 1.4), palette.leaf, box, false)
		ball("Blossom", Vector3.new(0.9, 0.85, 0.9), Vector3.new(-100.9, 7.4, -34 + side * 11.7 + index * 1.4), index % 2 == 0 and palette.gold or palette.pink, box, false)
	end
end

local towerX, towerZ = 80, -14
disc("TowerFoundation", 25, 0.7, Vector3.new(towerX, 4.35, towerZ), palette.rockDark, tower)
for index = 1, 5 do
	disc("TowerStripe" .. index, 18, 10.8, Vector3.new(towerX, 4 + (index - 0.5) * 10.8, towerZ), index % 2 == 0 and palette.cream or palette.coral, tower)
end
disc("TowerBaseTrim", 19.6, 1.3, Vector3.new(towerX, 4.65, towerZ), palette.woodDark, tower)
local innerRails, outerRails = {}, {}
for index = 1, 72 do
	local theta = math.pi + index * math.pi * 2 / 24
	local top = 4 + index * 0.75
	local center = Vector3.new(towerX + math.cos(theta) * 15, top - 0.30, towerZ + math.sin(theta) * 15)
	part("LookoutStep" .. index, Vector3.new(8, 0.60, 5.7), CFrame.new(center) * CFrame.Angles(0, -theta, 0), index % 2 == 0 and palette.woodLight or palette.sand, tower)
	if index == 1 or index % 3 == 0 then
		for _, data in ipairs({{radius = 10.9, previous = innerRails}, {radius = 19.1, previous = outerRails}}) do
			if data.radius == 10.9 or index < 72 then
				local point = Vector3.new(towerX + math.cos(theta) * data.radius, top + 2.7, towerZ + math.sin(theta) * data.radius)
				local post = part("SpiralRailPost", Vector3.new(0.55, 2.8, 0.55), point - Vector3.new(0, 1.15, 0), palette.woodDark, tower)
				post:SetAttribute("RailSide", data.radius == 10.9 and "Inner" or "Outer")
				post:SetAttribute("RailStep", index)
				post:SetAttribute("RailRadius", data.radius)
				if data.previous.point then
					local rail = beam("SpiralHandrail", data.previous.point, point, 0.42, 0.50, palette.cream, tower)
					rail:SetAttribute("RailSide", data.radius == 10.9 and "Inner" or "Outer")
					rail:SetAttribute("RailStep", index)
					rail:SetAttribute("RailRadius", data.radius)
				end
				data.previous.point = point
			end
		end
	end
end
for index = 1, 24 do
	local theta = index * math.pi * 2 / 24
	local center = Vector3.new(towerX + math.cos(theta) * 21, 58.10, towerZ + math.sin(theta) * 21)
	part("ObservationRim" .. index, Vector3.new(8.6, 0.80, 8.3), CFrame.new(center) * CFrame.Angles(0, -theta, 0), palette.woodDark, tower)
	part("ObservationDeck" .. index, Vector3.new(8.0, 0.60, 7.9), CFrame.new(center + Vector3.new(0, 0.30, 0)) * CFrame.Angles(0, -theta, 0), palette.woodLight, tower)
end
local previousPoint
for index = 0, 12 do
	local theta = index * math.pi * 2 / 12
	local point = Vector3.new(towerX + math.cos(theta) * 24, 61.15, towerZ + math.sin(theta) * 24)
	part("ObservationPost", Vector3.new(0.80, 3.0, 0.80), point - Vector3.new(0, 1.1, 0), palette.cream, tower)
	if previousPoint then beam("ObservationRail", previousPoint, point, 0.6, 0.65, palette.woodDark, tower) end
	previousPoint = point
end
local innerPrevious
for index = 0, 24 do
	local theta = index * math.pi * 2 / 24
	local point = Vector3.new(towerX + math.cos(theta) * 17, 61.15, towerZ + math.sin(theta) * 17)
	if index == 11 or index == 12 or index == 13 then
		innerPrevious = nil
	else
		part("ObservationInnerPost", Vector3.new(0.65, 2.9, 0.65), point - Vector3.new(0, 1.1, 0), palette.woodDark, tower)
		if innerPrevious then beam("ObservationInnerRail", innerPrevious, point, 0.45, 0.55, palette.cream, tower) end
		innerPrevious = point
	end
end
for index = 1, 6 do
	local theta = index * math.pi * 2 / 6
	part("CanopyPost", Vector3.new(1.0, 7.5, 1.0), Vector3.new(towerX + math.cos(theta) * 22, 62.2, towerZ + math.sin(theta) * 22), palette.woodDark, tower)
end
disc("TowerRoofEave", 51.2, 1.0, Vector3.new(towerX, 66.3, towerZ), palette.woodDark, tower)
disc("TowerRoofLower", 49.0, 1.3, Vector3.new(towerX, 67.1, towerZ), palette.coral, tower)
disc("TowerRoofMiddle", 35.0, 1.4, Vector3.new(towerX, 68.3, towerZ), palette.coral, tower)
disc("TowerRoofUpper", 20.0, 1.4, Vector3.new(towerX, 69.5, towerZ), palette.wood, tower)
ball("TowerFinial", Vector3.new(3.2, 3.2, 3.2), Vector3.new(towerX, 71.4, towerZ), palette.gold, tower, false)
for _, side in ipairs({-1, 1}) do
	part("TowerWindowFrame", Vector3.new(0.4, 6.4, 3.8), Vector3.new(towerX + side * 9.05, 30, towerZ), palette.woodDark, tower, false)
	local glass = part("TowerWindow", Vector3.new(0.12, 5.6, 3.0), Vector3.new(towerX + side * 9.32, 30, towerZ), palette.waterLight, tower, false)
	glass.Transparency = 0.25
end

local function flowerGroup(name, x, z, ground, tint)
	local value = model(name, greenery)
	for index = 1, 6 do
		local theta = index * 2.4
		local distance = 1.2 + index % 3
		local position = Vector3.new(x + math.cos(theta) * distance, ground + 0.9, z + math.sin(theta) * distance)
		part("Stem", Vector3.new(0.18, 1.8, 0.18), position, palette.leafDark, value, false)
		ball("Leaf", Vector3.new(1.0, 0.35, 0.6), position + Vector3.new(0.3, -0.3, 0), palette.leaf, value, false)
		for petal = 1, 4 do
			local angle = petal * math.pi / 2
			ball("Petal", Vector3.new(0.7, 0.38, 0.7), position + Vector3.new(math.cos(angle) * 0.35, 0.9, math.sin(angle) * 0.35), tint, value, false)
		end
		ball("FlowerCenter", Vector3.new(0.45, 0.40, 0.45), position + Vector3.new(0, 1.05, 0), palette.gold, value, false)
	end
end
for index, data in ipairs({{-81,-131,27},{-37,-130,27},{23,-132,27},{92,-131,27},{-123,122,14},{-134,58,17.2},{-103,-63,4},{-84,-46,4},{-39,22,4},{-23,48,4},{17,72,4},{42,95,4},{110,11,4},{122,-70,4},{40,-91,4}}) do
	flowerGroup("FlowerGroup" .. index, data[1], data[2], data[3], index % 3 == 0 and palette.cream or (index % 2 == 0 and palette.pink or palette.waterLight))
end

local function bench(name, x, z, floor, yaw)
	local value = model(name, routeDetails)
	local base = CFrame.new(x, floor, z) * CFrame.Angles(0, yaw, 0)
	part("Seat", Vector3.new(10, 0.6, 3), base * CFrame.new(0, 2.0, 0), palette.woodLight, value)
	part("Back", Vector3.new(10, 2.2, 0.55), base * CFrame.new(0, 3.4, 1.2), palette.woodLight, value)
	for _, side in ipairs({-1, 1}) do part("Leg", Vector3.new(0.6, 2.0, 2.5), base * CFrame.new(side * 3.6, 1, 0), palette.woodDark, value) end
end
bench("NorthLookoutBench", -31, -131, 27.16, 0)
bench("NorthLookoutBench2", 48, -132, 27.16, 0)
bench("WestGardenBench", -118, 114, 14.16, -math.pi / 2)

local buntingColors = {palette.coral, palette.gold, palette.blue, palette.cream, palette.pink}
for index, pair in ipairs({{Vector3.new(-98, 16, -23), Vector3.new(-38, 17, -36)}, {Vector3.new(44, 17, -44), Vector3.new(119, 18, -62)}}) do
	local a, b = pair[1], pair[2]
	beam("BuntingRope" .. index, a, b, 0.12, 0.12, palette.woodDark, routeDetails, false)
	for flag = 1, 14 do
		local point = a:Lerp(b, flag / 15) - Vector3.new(0, 1.0 + math.sin(flag / 15 * math.pi) * 0.55, 0)
		part("BuntingFlag", Vector3.new(1.4, 1.8, 0.12), CFrame.new(point) * CFrame.Angles(0, math.atan2(b.X - a.X, b.Z - a.Z), math.rad(8)), buntingColors[(flag - 1) % #buntingColors + 1], routeDetails, false, nil, "WedgePart")
	end
end

root:SetAttribute("PartCount", count)
root:SetAttribute("Applied", true)
root:SetAttribute("HighestWalkableFloor", 58.7)
root:SetAttribute("CliffMaximumHeight", 80)
root:SetAttribute("MainStairWidth", 14)
root:SetAttribute("MaximumStairRise", 0.766667)
lobby:SetAttribute("DepthPassVersion", 1)

return {
	created = true, parts = count, floorY = 4, boundsUnchanged = true,
	spawnPlazaUnchanged = true, voteAndShopZonesUnchanged = true, coinMarkersUnchanged = true,
	stairs = stairsData,
	lookout = {center = {80, -14}, steps = 72, stepRise = 0.75, stairWidth = 8, observationFloor = 58.7, roofTop = 73},
	waterfall = {position = {-128.05, 21, 84}, sourceFloor = 38, drop = 34.4, decorative = true},
	cave = {center = {-135, 4.3, 54}, doorCenter = {-125, 8, 54}, clearWidth = 18, clearHeight = 8.3},
	shop = {doorCenter = {-108.5, 8.7, -31}, clearWidth = 14, clearHeight = 8.3},
	cameras = {
		{position = {220, 184, 224}, target = {0, 22, 0}},
		{position = {32, 10, 20}, target = {-118, 17, 30}},
		{position = {-92, 10, 115}, target = {-137, 27, 83}},
		{position = {12, 10, -61}, target = {80, 30, -14}},
	},
}

end
local function buildTagArena()
local name = "Tag You're It"
local existing = workspace:FindFirstChild(name)
if existing then
 return {built=false,reason="Existing Tag You're It folder preserved",folder=existing:GetFullName()}
end

local center = Vector3.new(6500,32.9,4534)
local navy = Color3.fromRGB(27,45,61)
local cream = Color3.fromRGB(255,243,200)
local white = Color3.fromRGB(255,253,240)
local grass = Color3.fromRGB(129,201,76)
local grassLight = Color3.fromRGB(142,213,88)
local blue = Color3.fromRGB(76,182,238)
local coral = Color3.fromRGB(255,127,121)
local gold = Color3.fromRGB(255,203,68)
local mint = Color3.fromRGB(92,209,166)
local purple = Color3.fromRGB(181,153,236)
local arena = Instance.new("Folder")
arena.Name = name
local function folder(label,parent)
 local result = Instance.new("Folder")
 result.Name = label
 result.Parent = parent
 return result
end
local geometry = folder("Geometry",arena)
local scenery = folder("Scenery",arena)
local gameplay = folder("Gameplay",arena)
local perimeter = folder("Perimeter",geometry)
local floorArt = folder("FloorArtwork",geometry)
local routes = folder("ParkourRoutes",geometry)
local vaults = folder("VaultObstacles",gameplay)
local navObstacles = {}
local routeStats = {}
local totalParts = 0

local function recordObstacle(p)
 if not p.CanCollide then return end
 local minimum = Vector3.new(math.huge,math.huge,math.huge)
 local maximum = Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,x in ipairs({-1,1}) do
  for _,y in ipairs({-1,1}) do
   for _,z in ipairs({-1,1}) do
    local q = p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2))-center
    minimum = Vector3.new(math.min(minimum.X,q.X),math.min(minimum.Y,q.Y),math.min(minimum.Z,q.Z))
    maximum = Vector3.new(math.max(maximum.X,q.X),math.max(maximum.Y,q.Y),math.max(maximum.Z,q.Z))
   end
  end
 end
 if minimum.Y < 7.8 and maximum.Y > 0.2 then
  table.insert(navObstacles,{x1=minimum.X-3.3,x2=maximum.X+3.3,z1=minimum.Z-3.3,z2=maximum.Z+3.3})
 end
end
local function part(label,size,position,color,parent,collidable,shape)
 local p = Instance.new("Part")
 p.Name = label
 p.Size = size
 p.Position = center+position
 p.Color = color
 p.Material = Enum.Material.SmoothPlastic
 p.Anchored = true
 p.CanCollide = collidable == true
 p.CanTouch = false
 p.CanQuery = collidable == true
 p.CastShadow = collidable == true
 p.TopSurface = Enum.SurfaceType.Smooth
 p.BottomSurface = Enum.SurfaceType.Smooth
 if shape then p.Shape = shape end
 p.Parent = parent
 totalParts += 1
 return p
end
local function block(label,x,y,z,px,py,pz,color,parent,collidable)
 local p = part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,collidable)
 recordObstacle(p)
 return p
end
local function cylinder(label,diameter,height,position,color,parent,collidable)
 local p = part(label,Vector3.new(height,diameter,diameter),position,color,parent,collidable,Enum.PartType.Cylinder)
 p.CFrame = CFrame.new(p.Position)*CFrame.Angles(0,0,math.pi/2)
 recordObstacle(p)
 return p
end
local function sphere(label,size,position,color,parent)
 return part(label,size,position,color,parent,false,Enum.PartType.Ball)
end
local function paint(label,x,z,px,pz,color,parent,y)
 return block(label,x,0.06,z,px,y or 0.035,pz,color,parent,false)
end
local function deck(label,x,z,px,pz,top,color,parent,routeId,width)
 local p = block(label.."Ink",x,1.2,z,px,top-0.6,pz,navy,parent,true)
 p:SetAttribute("Walkable",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("TopHeight",top)
 p:SetAttribute("PathWidth",width or math.min(x,z))
 block(label.."Surface",x-0.55,0.12,z-0.55,px,top+0.06,pz,color,parent,false)
 return p
end
local function support(label,px,pz,height,parent)
 block(label.."Ink",3.4,height,3.4,px,height/2,pz,navy,parent,true)
 block(label.."Cream",2.5,height-0.5,3.5,px,height/2,pz,cream,parent,false)
end
local function ramp(label,p0,p1,width,color,parent,routeId)
 local a,b = center+p0,center+p1
 local direction = b-a
 local frame = CFrame.lookAt((a+b)/2,b)
 frame -= frame.UpVector*0.7
 local p = part(label.."Ink",Vector3.new(width,1.4,direction.Magnitude),Vector3.zero,navy,parent,true)
 p.CFrame = frame
 p:SetAttribute("Walkable",true)
 p:SetAttribute("IsRamp",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("PathWidth",width)
 p:SetAttribute("Rise",math.abs(p1.Y-p0.Y))
 p:SetAttribute("Run",Vector2.new(p1.X-p0.X,p1.Z-p0.Z).Magnitude)
 p:SetAttribute("FromHeight",p0.Y)
 p:SetAttribute("ToHeight",p1.Y)
 recordObstacle(p)
 local surface = part(label.."Surface",Vector3.new(width-0.6,0.1,direction.Magnitude-0.2),Vector3.zero,color,parent,false)
 surface.CFrame = frame+frame.UpVector*0.75
 for _,side in ipairs({-1,1}) do
  local rail = part(label.."Edge",Vector3.new(0.5,0.08,direction.Magnitude-0.4),Vector3.zero,cream,parent,false)
  rail.CFrame = frame+frame.UpVector*0.84+frame.RightVector*(side*(width/2-0.8))
 end
 return p
end
local function stair(label,x,z,px,pz,top,color,parent,routeId)
 local p = block(label.."Ink",x,top,z,px,top/2,pz,navy,parent,true)
 p:SetAttribute("Walkable",true)
 p:SetAttribute("IsStep",true)
 p:SetAttribute("RouteId",routeId)
 p:SetAttribute("TopHeight",top)
 p:SetAttribute("StepRise",4)
 p:SetAttribute("PathWidth",math.min(x,z))
 block(label.."Surface",x-0.35,0.1,z-0.35,px,top+0.05,pz,color,parent,false)
 return p
end

block("IslandEarth",448,48,448,0,-34,0,Color3.fromRGB(159,102,65),geometry,true)
block("IslandInk",448,10,448,0,-5,0,navy,geometry,true)
block("GrassCourt",416,2,416,0,-1,0,grass,geometry,true)
for _,side in ipairs({-1,1}) do
 block("GrassLipX",8,4,440,side*221,-3,0,Color3.fromRGB(96,172,63),geometry,false)
 block("GrassLipZ",448,4,8,0,-3,side*221,Color3.fromRGB(96,172,63),geometry,false)
 block("EarthStripeX",0.2,10,448,side*224.1,-38,0,Color3.fromRGB(194,140,92),geometry,false)
 block("EarthStripeZ",448,10,0.2,0,-38,side*224.1,Color3.fromRGB(194,140,92),geometry,false)
end
for index=-6,6 do
 paint("MownGrass"..index,30,416,index*32,0,index%2==0 and grassLight or grass,floorArt)
end
paint("NorthSouthPathInk",30,380,0,0,Color3.fromRGB(107,174,73),floorArt,0.10)
paint("NorthSouthPath",24,376,0,0,cream,floorArt,0.15)
paint("EastWestPathInk",380,30,0,0,Color3.fromRGB(107,174,73),floorArt,0.10)
paint("EastWestPath",376,24,0,0,cream,floorArt,0.15)
cylinder("CentralPlazaInk",92,0.10,Vector3.new(0,0.22,0),navy,floorArt,false)
cylinder("CentralPlazaCream",88,0.10,Vector3.new(0,0.29,0),cream,floorArt,false)
cylinder("CentralPlazaMint",68,0.10,Vector3.new(0,0.36,0),Color3.fromRGB(202,236,164),floorArt,false)
cylinder("TaggerCircleInk",22,0.10,Vector3.new(0,0.43,0),navy,floorArt,false)
cylinder("TaggerCircleWhite",18,0.10,Vector3.new(0,0.50,0),white,floorArt,false)
cylinder("TaggerCircleGold",12,0.10,Vector3.new(0,0.57,0),gold,floorArt,false)
for index=1,12 do
 local angle = index*math.pi/6
 cylinder("PlazaDot"..index,3.5,0.08,Vector3.new(math.cos(angle)*39,0.39,math.sin(angle)*39),index%2==0 and white or gold,floorArt,false)
end

for _,side in ipairs({-1,1}) do
 paint("StartingBorderInk",386,6.5,0,side*190,navy,floorArt,0.18)
 paint("StartingBorderWhite",382,4,0,side*190,white,floorArt,0.25)
 paint("StartingBorderInk",6.5,374,side*190,0,navy,floorArt,0.18)
 paint("StartingBorderWhite",4,376,side*190,0,white,floorArt,0.25)
 local x,z = side*212,side*212
 block("WestEastFenceInk",8,16,432,x,8,0,navy,perimeter,true)
 block("WestEastFenceBlue",0.25,11,420,x-side*4.15,8,0,blue,perimeter,false)
 block("WestEastFenceCapInk",10,2.8,434,x,16.7,0,navy,perimeter,false)
 block("WestEastFenceCapCream",8.8,1.6,432,x,17.2,0,cream,perimeter,false)
 block("NorthSouthFenceInk",432,16,8,0,8,z,navy,perimeter,true)
 block("NorthSouthFenceBlue",420,11,0.25,0,8,z-side*4.15,blue,perimeter,false)
 block("NorthSouthFenceCapInk",434,2.8,10,0,16.7,z,navy,perimeter,false)
 block("NorthSouthFenceCapCream",432,1.6,8.8,0,17.2,z,cream,perimeter,false)
 for index=-6,6 do
  local coordinate = index*32
  block("FenceColumnInk",8.5,19,6,x,9.5,coordinate,navy,perimeter,false)
  block("FenceColumnCream",8.6,17,4,x,9.6,coordinate,cream,perimeter,false)
  block("FenceColumnInk",6,19,8.5,coordinate,9.5,z,navy,perimeter,false)
  block("FenceColumnCream",4,17,8.6,coordinate,9.6,z,cream,perimeter,false)
  sphere("FenceButton",Vector3.new(6,6,6),Vector3.new(x,21,coordinate),index%2==0 and gold or white,perimeter)
  sphere("FenceButton",Vector3.new(6,6,6),Vector3.new(coordinate,21,z),index%2==0 and gold or white,perimeter)
 end
end

local courses = {
 {id="Sunbeam",x=-102,z=-102,color=gold,accent=Color3.fromRGB(255,231,143),kind="Steps"},
 {id="CoralRoofs",x=102,z=-102,color=coral,accent=Color3.fromRGB(255,183,165),kind="Roof"},
 {id="Wavewalk",x=-102,z=102,color=blue,accent=Color3.fromRGB(155,221,250),kind="Stones"},
 {id="MintTerrace",x=102,z=102,color=mint,accent=Color3.fromRGB(168,237,194),kind="Terrace"},
}
for _,course in ipairs(courses) do
 local c = folder(course.id,routes)
 c:SetAttribute("RouteId",course.id)
 c:SetAttribute("MainHeight",12)
 c:SetAttribute("MainWidth",16)
 c:SetAttribute("AccessCount",2)
 c:SetAttribute("MaximumStepRise",4)
 c:SetAttribute("MaximumJumpGap",4)
 c:SetAttribute("ContinuousGroundRoute",true)
 c:SetAttribute("CenterX",course.x)
 c:SetAttribute("CenterZ",course.z)
 local x,z = course.x,course.z
 paint("GardenPatchInk",120,120,x,z,Color3.fromRGB(103,172,70),c,0.1)
 paint("GardenPatch",116,116,x,z,Color3.fromRGB(176,221,118),c,0.15)
 paint("PatioInk",74,74,x,z,navy,c,0.22)
 paint("Patio",70,70,x,z,course.accent,c,0.29)
 for _,side in ipairs({-1,1}) do
  deck("LoopNorthSouth"..side,112,16,x,z+side*48,12,course.color,c,course.id,16)
  deck("LoopWestEast"..side,16,80,x+side*48,z,12,course.color,c,course.id,16)
  paint("LoopLane",100,1.0,x,z+side*48,cream,c,12.16)
  paint("LoopLane",1.0,70,x+side*48,z,cream,c,12.16)
  for _,other in ipairs({-1,1}) do support("LoopPillar",x+side*48,z+other*48,10.8,c) end
 end
 local signX,signZ = math.sign(x),math.sign(z)
 ramp("OuterWestEastRamp",Vector3.new(x+signX*80,0.18,z),Vector3.new(x+signX*48,12,z),18,course.color,c,course.id)
 ramp("OuterNorthSouthRamp",Vector3.new(x,0.18,z+signZ*80),Vector3.new(x,12,z+signZ*48),18,course.color,c,course.id)
 for index=1,3 do
  local pz = z+signZ*(17+index*8)
  local access=stair("PatioAccess"..index,14,8,x,pz,index*4,course.color,c,course.id)
  access:SetAttribute("PathWidth",14)
 end
 for _,side in ipairs({-1,1}) do
  local vaultX = x+side*22
  local vault = block(course.id.."Vault"..side,24,2.8,3,vaultX,1.4,z+side*26,navy,vaults,true)
  vault:SetAttribute("Vaultable",true)
  vault:SetAttribute("VaultHeight",2.8)
  vault:SetAttribute("RouteId",course.id)
  vault:SetAttribute("ApproachClearance",10)
  block("VaultFace",23.4,1.9,3.1,vaultX,1.7,z+side*26,course.color,vaults,false)
  block("VaultTop",23.6,0.3,3.2,vaultX,2.95,z+side*26,cream,vaults,false)
 end
 local maximumHeight = 12
 if course.kind == "Steps" then
  for index=1,5 do
   local top = math.min(index*3,12)
   local px = x-34+(index-1)*18
   local p = stair("SkippingStep"..index,14,14,px,z,top,course.color,c,course.id)
   p:SetAttribute("StepRise",3)
   p:SetAttribute("JumpGap",4)
   paint("StepDot",4,4,px,z,cream,c,top+0.14)
  end
 elseif course.kind == "Roof" then
  maximumHeight = 20
  deck("CoralRoof",28,32,x,z,20,course.color,c,course.id,28)
  for _,side in ipairs({-1,1}) do
   deck("RoofLanding",16,16,x+side*34,z,16,course.accent,c,course.id,16)
   deck("RoofApproach",12,16,x+side*20,z,20,course.color,c,course.id,12)
   support("RoofPillar",x+side*10,z-12,18.8,c)
   support("RoofPillar",x+side*10,z+12,18.8,c)
  end
  paint("RoofStripe",4,25,x,z,cream,c,20.16)
 elseif course.kind == "Stones" then
  paint("BluePatioInk",66,40,x,z,navy,c,0.34)
  paint("BluePatio",62,36,x,z,Color3.fromRGB(103,205,238),c,0.41)
  for index=1,4 do
   local top = 2+(index-1)*3
   local px = x-30+(index-1)*20
   local p = cylinder("SkippingStoneInk"..index,16,top,Vector3.new(px,top/2,z),navy,c,true)
   p:SetAttribute("Walkable",true)
   p:SetAttribute("RouteId",course.id)
   p:SetAttribute("PathWidth",16)
   p:SetAttribute("TopHeight",top)
   p:SetAttribute("JumpGap",4)
   p:SetAttribute("StepRise",3)
   cylinder("SkippingStoneTop"..index,15.4,0.12,Vector3.new(px,top+0.06,z),course.accent,c,false)
   cylinder("SkippingStoneDot"..index,4,0.1,Vector3.new(px,top+0.16,z),white,c,false)
  end
 elseif course.kind == "Terrace" then
  maximumHeight = 24
  deck("MintTopDeck",32,32,x,z,24,purple,c,course.id,32)
  for _,side in ipairs({-1,1}) do
   deck("TerraceStep1",12,16,x+side*34,z,16,course.accent,c,course.id,12)
   deck("TerraceStep2",12,16,x+side*22,z,20,course.color,c,course.id,12)
   support("TerracePillar",x+side*12,z-12,22.8,c)
   support("TerracePillar",x+side*12,z+12,22.8,c)
  end
  cylinder("TerraceMedallionInk",15,0.08,Vector3.new(x,24.18,z),navy,c,false)
  cylinder("TerraceMedallion",12,0.09,Vector3.new(x,24.25,z),cream,c,false)
 end
 c:SetAttribute("MaximumHeight",maximumHeight)
 table.insert(routeStats,{id=course.id,mainHeight=12,maximumHeight=maximumHeight,width=16,accesses=2,maxGap=4,maxStepRise=4})
 for _,offset in ipairs({Vector3.new(-29,0,-29),Vector3.new(29,0,29)}) do
  local px,pz = x+offset.X,z+offset.Z
  cylinder("PlanterInk",12,1.0,Vector3.new(px,0.5,pz),navy,c,false)
  cylinder("PlanterCream",10.5,0.8,Vector3.new(px,0.9,pz),cream,c,false)
  for index=-1,1 do
   sphere("SoftShrub",Vector3.new(7,6,7),Vector3.new(px+index*3.5,3.8,pz),index==0 and Color3.fromRGB(166,218,85) or Color3.fromRGB(95,170,77),c)
  end
 end
end

local bridges = folder("LinkBridges",routes)
for _,side in ipairs({-1,1}) do
 deck("NorthSouthLink"..side,96,16,0,side*102,12,white,bridges,"SharedLinks",16)
 deck("WestEastLink"..side,16,96,side*102,0,12,white,bridges,"SharedLinks",16)
 paint("LinkStripe",86,3,0,side*102,gold,bridges,12.16)
 paint("LinkStripe",3,86,side*102,0,gold,bridges,12.16)
 for _,other in ipairs({-1,1}) do
  support("LinkPillar",other*31,side*102,10.8,bridges)
  support("LinkPillar",side*102,other*31,10.8,bridges)
 end
end

local trees = folder("BubbleTrees",scenery)
local function tree(index,px,pz)
 local model = Instance.new("Model")
 model.Name = "BubbleTree"..string.format("%02d",index)
 model.Parent = trees
 local height = 22+(index%4)*3
 block("TrunkInk",6.0,height,6.0,px,height/2,pz,Color3.fromRGB(68,82,54),model,false)
 block("Trunk",4.5,height,4.5,px,height/2,pz,Color3.fromRGB(158,110,70),model,false)
 for branch,offset in ipairs({Vector3.new(0,height+7,0),Vector3.new(-7,height+1,3),Vector3.new(7,height+3,-2)}) do
  local q = Vector3.new(px,0,pz)+offset
  sphere("LeafInk"..branch,Vector3.new(23,23,23),q,Color3.fromRGB(50,115,63),model)
  sphere("Leaf"..branch,Vector3.new(22.5,22.5,22.5),q+Vector3.new(0,1.7,0),branch==2 and Color3.fromRGB(168,219,79) or Color3.fromRGB(112,190,76),model)
 end
end
local treeIndex = 0
for _,side in ipairs({-1,1}) do
 for index=-5,5 do
  treeIndex += 1
  tree(treeIndex,side*(238+(index%3)*7),index*43)
  treeIndex += 1
  tree(treeIndex,index*43,side*(238+((index+1)%3)*7))
 end
end
for index=1,24 do
 local side = index%4
 local along = -165+math.floor((index-1)/4)*66
 local px,pz
 if side==0 then px,pz=-201,along elseif side==1 then px,pz=201,along elseif side==2 then px,pz=along,-201 else px,pz=along,201 end
 for petal=1,4 do
  local angle = petal*math.pi/2
  sphere("FlowerPetal",Vector3.new(2.3,1.2,2.3),Vector3.new(px+math.cos(angle)*1.4,0.7,pz+math.sin(angle)*1.4),index%3==0 and coral or index%3==1 and purple or white,scenery)
 end
 sphere("FlowerCenter",Vector3.new(1.6,1.2,1.6),Vector3.new(px,1.0,pz),gold,scenery)
end

local bounds = block("ArenaBounds",416,100,416,0,50,0,navy,gameplay,false)
bounds.Transparency = 1
local pads = folder("StartPads",gameplay)
local spawnLocations = {}
for side=1,4 do
 for index=1,6 do
  local along = -150+(index-1)*60
  local x,z
  if side==1 then x,z=along,-190 elseif side==2 then x,z=190,along elseif side==3 then x,z=-along,190 else x,z=-190,-along end
  local id = (side-1)*6+index
  local pad = block(string.format("%02d",id),1,1,1,x,3.6,z,white,pads,false)
  pad.Transparency = 1
  pad.CFrame = CFrame.lookAt(pad.Position,Vector3.new(center.X,pad.Position.Y,center.Z))
  table.insert(spawnLocations,{x=x,z=z})
  cylinder("BorderStartInk"..id,8.2,0.08,Vector3.new(x,0.32,z),navy,floorArt,false)
  cylinder("BorderStartWhite"..id,6.7,0.08,Vector3.new(x,0.40,z),white,floorArt,false)
  cylinder("BorderStartBlue"..id,3.2,0.08,Vector3.new(x,0.48,z),blue,floorArt,false)
 end
end
local taggerSpawn = block("TaggerSpawn",1,1,1,0,3.6,0,coral,gameplay,false)
taggerSpawn.Transparency = 1

local function pointClear(x,z)
 for _,obstacle in ipairs(navObstacles) do
  if x>=obstacle.x1 and x<=obstacle.x2 and z>=obstacle.z1 and z<=obstacle.z2 then return false end
 end
 return true
end
local function segmentClear(a,b)
 local dx,dz = b.x-a.x,b.z-a.z
 for _,obstacle in ipairs(navObstacles) do
  local lo,hi = 0,1
  for _,axis in ipairs({{a.x,dx,obstacle.x1,obstacle.x2},{a.z,dz,obstacle.z1,obstacle.z2}}) do
   if math.abs(axis[2])<0.0001 then
    if axis[1]<axis[3] or axis[1]>axis[4] then lo=2 break end
   else
    local u,v = (axis[3]-axis[1])/axis[2],(axis[4]-axis[1])/axis[2]
    lo,hi = math.max(lo,math.min(u,v)),math.min(hi,math.max(u,v))
   end
  end
  if lo<=hi and lo<=1 and hi>=0 then return false end
 end
 return true
end
local navigation = folder("NavigationNodes",gameplay)
local nodeData = {}
local function node(x,z,isSpawn)
 if not pointClear(x,z) then return end
 local id = string.format("NN%03d",#nodeData+1)
 local p = block(id,0.7,0.7,0.7,x,3.6,z,navy,navigation,false)
 p.Transparency = 1
 p:SetAttribute("GroundNode",true)
 p:SetAttribute("SpawnNode",isSpawn==true)
 table.insert(nodeData,{x=x,z=z,part=p,neighbors={}})
end
for x=-180,180,30 do for z=-180,180,30 do node(x,z,false) end end
for _,q in ipairs(spawnLocations) do node(q.x,q.z,true) end
for a=1,#nodeData do
 for b=a+1,#nodeData do
  local q,r = nodeData[a],nodeData[b]
  local distance = Vector2.new(q.x-r.x,q.z-r.z).Magnitude
  if distance<=64 and segmentClear(q,r) then
   table.insert(q.neighbors,r.part.Name)
   table.insert(r.neighbors,q.part.Name)
  end
 end
end
local lookup = {}
for _,q in ipairs(nodeData) do
 table.sort(q.neighbors)
 q.part:SetAttribute("Neighbors",table.concat(q.neighbors,","))
 q.part:SetAttribute("Neighbor",table.concat(q.neighbors,","))
 lookup[q.part.Name] = q
end
local visited,queue = {},{}
if #nodeData>0 then visited[nodeData[1].part.Name]=true queue[1]=nodeData[1] end
local at = 1
while queue[at] do
 local q = queue[at]
 at += 1
 for _,neighbor in ipairs(q.neighbors) do
  if not visited[neighbor] then visited[neighbor]=true table.insert(queue,lookup[neighbor]) end
 end
end
assert(#queue==#nodeData,"Tag navigation graph is disconnected; build was not installed")
assert(#nodeData>=100,"Tag arena has too few ground navigation nodes")
assert(#pads:GetChildren()==24,"Tag arena must have 24 starting pads")
for key,value in pairs({RoundDuration=180,CountdownSeconds=3,ResultsSeconds=7,TaggerWalkSpeed=18,RunnerWalkSpeed=16,MinimumPlayers=2,AutoStart=false,WinRule="MostTaggerTime",CourtWidth=416,CourtLength=416,FloorY=32.9,MaximumRouteHeight=24,BuildVersion="20261003"}) do arena:SetAttribute(key,value) end
arena:SetAttribute("NavigationNodeCount",#nodeData)
arena:SetAttribute("ParkourRouteCount",4)
arena:SetAttribute("GroundNavigationConnected",true)
arena.Parent = workspace
return {built=true,folder=arena:GetFullName(),parts=totalParts,width=416,length=416,area=173056,areaRatioToBulldog=173056/(224*368),floorY=center.Y,startPads=24,navigationNodes=#nodeData,navigationConnected=true,routes=routeStats,vaults=#vaults:GetChildren()/3}

end
local function buildBritishBulldogHUD()
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
local function buildTagHUD()
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ink = Color3.fromRGB(24, 35, 62)
local paper = Color3.fromRGB(255, 250, 226)
local blue = Color3.fromRGB(54, 174, 255)
local red = Color3.fromRGB(255, 83, 100)
local yellow = Color3.fromRGB(255, 204, 54)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function finish(object, color, radius)
	make("UICorner", "Corner", object, { CornerRadius = UDim.new(0, radius or 16) })
	make("UIStroke", "Outline", object, { Color = ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	object.BackgroundColor3 = color
	object.BorderSizePixel = 0
end

local function text(parent, name, value, position, size, font, color, maxSize)
	local label = make("TextLabel", name, parent, { BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = position, Size = size, Text = value, TextColor3 = color or ink,
		FontFace = font or body, TextScaled = true, TextWrapped = true, ZIndex = 4 })
	make("UITextSizeConstraint", "TextLimit", label, { MinTextSize = 10, MaxTextSize = maxSize or 30 })
	return label
end

local assets = ReplicatedStorage:FindFirstChild("TagAssets") or make("Folder", "TagAssets", ReplicatedStorage)
if not assets:FindFirstChild("TaggerTemplate") then
	local billboard = make("BillboardGui", "TaggerTemplate", assets, { Size = UDim2.fromOffset(120, 48),
		StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0), AlwaysOnTop = false, MaxDistance = 100,
		Enabled = true, LightInfluence = 0, ResetOnSpawn = false })
	local panel = make("Frame", "Panel", billboard, { Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.85) })
	finish(panel, red, 12)
	text(panel, "Title", "YOU'RE IT!", UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.83), headline, Color3.new(1, 1, 1), 28)
end
if StarterGui:FindFirstChild("TagHUD") then return { AlreadyExists = true, GUI = "StarterGui.TagHUD" } end
local gui = make("ScreenGui", "TagHUD", StarterGui, { Enabled = false, ResetOnSpawn = false,
	IgnoreGuiInset = false, DisplayOrder = 16, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("LayoutVersion", 1)
local top = make("Frame", "Top", gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.024), Size = UDim2.fromScale(0.44, 0.14) })
finish(top, paper)
make("UISizeConstraint", "SizeLimit", top, { MinSize = Vector2.new(290, 102), MaxSize = Vector2.new(620, 134) })
text(top, "Title", "TAG, YOU'RE IT!", UDim2.fromScale(0.035, 0.035), UDim2.fromScale(0.65, 0.27), headline, ink, 27)
text(top, "Timer", "3:00", UDim2.fromScale(0.73, 0.07), UDim2.fromScale(0.235, 0.47), headline, ink, 45)
local chip = make("Frame", "TaggerChip", top, { Position = UDim2.fromScale(0.035, 0.34), Size = UDim2.fromScale(0.65, 0.29) })
finish(chip, red, 10)
text(chip, "Name", "IT: PLAYER", UDim2.fromScale(0.035, 0.07), UDim2.fromScale(0.93, 0.85), body, Color3.new(1, 1, 1), 23)
text(top, "Rule", "LEAST TIME AS IT = SAFER", UDim2.fromScale(0.035, 0.72), UDim2.fromScale(0.93, 0.21), body, ink, 17)
local countdown = text(gui, "Countdown", "3", UDim2.fromScale(0.25, 0.34), UDim2.fromScale(0.5, 0.24), headline, Color3.new(1, 1, 1), 126)
countdown.Visible = false
countdown.Rotation = -3
make("UIStroke", "Outline", countdown, { Thickness = 6, Color = ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local role = make("Frame", "Role", gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.025, 0.955), Size = UDim2.fromScale(0.23, 0.085) })
finish(role, blue, 13)
make("UISizeConstraint", "SizeLimit", role, { MinSize = Vector2.new(145, 56), MaxSize = Vector2.new(285, 82) })
text(role, "Title", "RUNNER", UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.43), headline, Color3.new(1, 1, 1), 29)
text(role, "Time", "TIME AS IT: 0.0s", UDim2.fromScale(0.04, 0.59), UDim2.fromScale(0.92, 0.28), body, ink, 18)
local protection = text(gui, "Protection", "TAGBACK SHIELD: 2s", UDim2.fromScale(0.30, 0.81), UDim2.fromScale(0.4, 0.055), body, yellow, 24)
protection.Visible = false
make("UIStroke", "Outline", protection, { Color = ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local controls = make("Frame", "Controls", gui, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.975, 0.77),
	Size = UDim2.fromOffset(166, 132), BackgroundTransparency = 1, BorderSizePixel = 0 })
for index, action in ipairs({ "Vault", "Dodge" }) do
	local button = make("TextButton", action, controls, { Position = UDim2.fromOffset(0, (index - 1) * 69),
		Size = UDim2.fromOffset(166, 59), Text = action == "Vault" and "VAULT [Q]" or "DODGE [X]",
		FontFace = headline, TextScaled = true, TextColor3 = ink, AutoButtonColor = false })
	finish(button, action == "Vault" and yellow or blue, 14)
	make("UITextSizeConstraint", "TextLimit", button, { MinTextSize = 12, MaxTextSize = 25 })
end
local message = text(gui, "MoveMessage", "", UDim2.fromScale(0.23, 0.89), UDim2.fromScale(0.54, 0.05), body, Color3.new(1, 1, 1), 22)
make("UIStroke", "Outline", message, { Color = ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
local results = make("Frame", "Results", gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromScale(0.56, 0.39), Visible = false, ZIndex = 10 })
finish(results, paper)
make("UISizeConstraint", "SizeLimit", results, { MinSize = Vector2.new(290, 215), MaxSize = Vector2.new(720, 350) })
text(results, "Title", "YOU WIN!", UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.92, 0.25), headline, blue, 54)
text(results, "Loser", "MOST TIME AS IT: PLAYER", UDim2.fromScale(0.07, 0.36), UDim2.fromScale(0.86, 0.19), body, red, 23)
local scroll = make("ScrollingFrame", "WinnersScroll", results, { Position = UDim2.fromScale(0.065, 0.61), Size = UDim2.fromScale(0.87, 0.31),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = ink })
local winners = text(scroll, "Winners", "Winners", UDim2.fromScale(0.02, 0), UDim2.fromScale(0.96, 0), body, ink, 23)
winners.TextScaled = false
winners.TextSize = 20
winners.AutomaticSize = Enum.AutomaticSize.Y
winners.TextYAlignment = Enum.TextYAlignment.Top
return { GUI = gui:GetFullName(), Descendants = #gui:GetDescendants(), Template = assets.TaggerTemplate:GetFullName() }

end
local function buildAdmin()
local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local old = StarterGui:FindFirstChild("PlaygroundAdminPanel")
if old and old:GetAttribute("ExpansionVersion") == 1 then return { created = false, preserved = true } end
if old then
	local backups = ServerStorage:WaitForChild("PlaygroundBeforeExpansion20261003")
	if not backups:FindFirstChild("AdminPanelBeforeExpansion") then local backup = old:Clone() backup.Name = "AdminPanelBeforeExpansion" backup.Parent = backups end
	old:Destroy()
end
local ink = Color3.fromRGB(24, 35, 62)
local cream = Color3.fromRGB(255, 250, 226)
local yellow = Color3.fromRGB(255, 207, 59)
local blue = Color3.fromRGB(42, 160, 255)
local red = Color3.fromRGB(255, 81, 92)
local mint = Color3.fromRGB(101, 218, 177)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local bodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class, name, parent, properties)
	local object = Instance.new(class)
	object.Name = name
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function border(parent, thickness)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, 14) })
	make("UIStroke", "Stroke", parent, { Color = ink, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function label(parent, name, text, position, size, font, maximum)
	local object = make("TextLabel", name, parent, { Position = position, Size = size, BackgroundTransparency = 1, Text = text, TextColor3 = ink, FontFace = font or bodyFont, TextScaled = true, TextWrapped = true })
	make("UITextSizeConstraint", "TextLimit", object, { MinTextSize = 10, MaxTextSize = maximum or 24 })
	return object
end
local function button(parent, name, text, position, size, color, max)
	local object = make("TextButton", name, parent, { Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, Text = text, FontFace = headline, TextColor3 = ink, TextScaled = true, TextWrapped = true, AutoButtonColor = true })
	object:SetAttribute("ReadyColor", color)
	border(object, 3)
	make("UITextSizeConstraint", "TextLimit", object, { MinTextSize = 11, MaxTextSize = max or 24 })
	return object
end
local gui = make("ScreenGui", "PlaygroundAdminPanel", StarterGui, { Enabled = false, ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("ExpansionVersion", 1)
button(gui, "Toggle", "ADMIN", UDim2.fromScale(0.012, 0.045), UDim2.fromOffset(112, 44), yellow)
local panel = make("Frame", "Panel", gui, { Position = UDim2.fromScale(0.012, 0.125), Size = UDim2.fromScale(0.29, 0.86), BackgroundColor3 = cream, BorderSizePixel = 0, Visible = false })
make("UISizeConstraint", "SizeLimit", panel, { MinSize = Vector2.new(300, 450), MaxSize = Vector2.new(390, 650) })
border(panel, 4)
label(panel, "Title", "PLAYGROUND ADMIN", UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.77, 0.075), headline, 28)
button(panel, "Close", "X", UDim2.fromScale(0.865, 0.025), UDim2.fromScale(0.09, 0.07), Color3.new(1, 1, 1), 24)
local scroll = make("ScrollingFrame", "Body", panel, { Position = UDim2.fromScale(0.045, 0.12), Size = UDim2.fromScale(0.91, 0.625), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 434), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true })
local content = make("Frame", "Content", scroll, { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -14, 0, 426), BackgroundTransparency = 1 })
local function card(name, title, offset, start, first, second, firstText, secondText)
	local frame = make("Frame", name, content, { Position = UDim2.fromOffset(0, offset), Size = UDim2.new(1, 0, 0, 204), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	border(frame)
	label(frame, "Title", title, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.17), headline, 29)
	label(frame, "Status", "Ready", UDim2.fromScale(0.04, 0.21), UDim2.fromScale(0.92, 0.12), bodyFont, 14)
	button(frame, start, "START ROUND", UDim2.fromScale(0.04, 0.35), UDim2.fromScale(0.92, 0.185), yellow, 23)
	button(frame, first, firstText, UDim2.fromScale(0.04, 0.565), UDim2.fromScale(0.92, 0.185), blue, 22)
	button(frame, second, secondText, UDim2.fromScale(0.04, 0.78), UDim2.fromScale(0.92, 0.185), red, 22)
end
card("BritishBulldog", "BRITISH BULLDOG", 0, "BBStart", "BBRunner", "BBBulldog", "SOLO RUNNER", "SOLO BULLDOG")
card("TagYoureIt", "TAG YOU'RE IT", 218, "TagStart", "TagRunner", "TagTagger", "SOLO RUNNER", "SOLO TAGGER")
button(panel, "StopRound", "STOP / BACK TO LOBBY", UDim2.fromScale(0.055, 0.78), UDim2.fromScale(0.89, 0.075), red, 22)
button(panel, "ToggleAutomatic", "AUTO ROUNDS: ON", UDim2.fromScale(0.055, 0.875), UDim2.fromScale(0.89, 0.06), mint, 19)
label(panel, "Message", "Choose a game to test.", UDim2.fromScale(0.05, 0.947), UDim2.fromScale(0.9, 0.042), bodyFont, 14)
return { created = true, panel = gui:GetFullName(), games = 2 }

end
local function buildShell()
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local existing = StarterGui:FindFirstChild("PlaygroundShell")
local catalog = require(assert(ReplicatedStorage:FindFirstChild("PlaygroundCatalog"),"Install PlaygroundCatalog before the shell"))
local ink = Color3.fromRGB(27,45,61)
local cream = Color3.fromRGB(255,247,219)
local white = Color3.fromRGB(255,255,248)
local blue = Color3.fromRGB(89,193,244)
local gold = Color3.fromRGB(255,211,78)
local mint = Color3.fromRGB(130,225,180)
local pink = Color3.fromRGB(255,153,166)
local headline = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(className,name,parent,properties)
 local object = Instance.new(className)
 object.Name = name
 for key,value in pairs(properties or {}) do object[key]=value end
 object.Parent = parent
 return object
end
local function corner(parent,radius)
 return make("UICorner","Corner",parent,{CornerRadius=UDim.new(0,radius)})
end
local function stroke(parent,thickness,color)
 return make("UIStroke","Outline",parent,{Color=color or ink,Thickness=thickness or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function text(parent,name,value,position,size,font,maxSize,color,z)
 local object = make("TextLabel",name,parent,{BackgroundTransparency=1,BorderSizePixel=0,Position=position,Size=size,Text=value,TextColor3=color or ink,FontFace=font or body,TextScaled=true,TextWrapped=true,ZIndex=z or 4})
 make("UITextSizeConstraint","TextSizeLimit",object,{MinTextSize=9,MaxTextSize=maxSize or 22})
 return object
end
local function button(parent,name,value,position,size,color,maxSize,z)
 local object = make("TextButton",name,parent,{Position=position,Size=size,BackgroundColor3=color or gold,BorderSizePixel=0,Text=value,TextColor3=ink,FontFace=headline,TextScaled=true,TextWrapped=true,AutoButtonColor=true,ZIndex=z or 4})
 make("UITextSizeConstraint","TextSizeLimit",object,{MinTextSize=9,MaxTextSize=maxSize or 24})
 make("UIPadding","TextPadding",object,{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5),PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,3)})
 corner(object,11)
 stroke(object,3)
 return object
end
local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets") or make("Folder","PlaygroundCosmeticAssets",ReplicatedStorage)
local assetCount = 0
local function modelPart(model,name,size,position,color,shape,transparency)
 local object = make("Part",name,model,{Size=size,Position=position,Color=color,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Transparency=transparency or 0,TopSurface=Enum.SurfaceType.Smooth,BottomSurface=Enum.SurfaceType.Smooth})
 if shape then object.Shape=shape end
 if not model.PrimaryPart then model.PrimaryPart=object end
 return object
end
local function ball(model,name,size,position,color,transparency)
 return modelPart(model,name,size,position,color,Enum.PartType.Ball,transparency)
end
local function rod(model,name,a,b,width,color)
 local p = modelPart(model,name,Vector3.new(width,width,(b-a).Magnitude),(a+b)/2,color)
 p.CFrame=CFrame.lookAt(p.Position,b)
 return p
end
local function triangle(model,a,b,c,color,thickness)
 local ab,ac,bc=b-a,c-a,c-b
 if ab.Magnitude>ac.Magnitude and ab.Magnitude>bc.Magnitude then c,a=a,c
 elseif ac.Magnitude>bc.Magnitude then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local right=ac:Cross(ab).Unit
 local back=bc.Unit
 local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 local p=make("WedgePart","StarFacet",model,{Size=Vector3.new(thickness,height,math.abs(ab:Dot(back))),CFrame=CFrame.fromMatrix((a+b)/2,right,up,back),Color=color,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 local q=p:Clone()
 q.Size=Vector3.new(thickness,height,math.abs(ac:Dot(back)))
 q.CFrame=CFrame.fromMatrix((a+c)/2,-right,up,-back)
 q.Parent=model
 if not model.PrimaryPart then model.PrimaryPart=p end
end
local function star(model,origin,scale,color,thickness)
 local points={}
 for index=1,10 do
  local angle=math.pi/2+(index-1)*math.pi/5
  local radius=index%2==1 and 2*scale or 0.88*scale
  points[index]=origin+Vector3.new(math.cos(angle)*radius,math.sin(angle)*radius,0)
 end
 for index=1,10 do triangle(model,origin,points[index],points[index%10+1],color,thickness or 0.32) end
end
local function avatar(model,pose,outlineColor,rainbow)
 local skin=Color3.fromRGB(255,213,145)
 local shirt=Color3.fromRGB(88,179,232)
 local torso=modelPart(model,"Torso",Vector3.new(1.7,1.8,0.85),Vector3.new(0,0,0),shirt)
 local head=ball(model,"Head",Vector3.new(1.5,1.5,1.5),Vector3.new(0,1.63,0),skin)
 modelPart(model,"LeftLeg",Vector3.new(0.68,1.4,0.8),Vector3.new(-0.44,-1.6,0),ink)
 modelPart(model,"RightLeg",Vector3.new(0.68,1.4,0.8),Vector3.new(0.44,-1.6,0),ink)
 local leftA,leftB=Vector3.new(-1.03,0.58,0),Vector3.new(-1.25,-0.83,0)
 local rightA,rightB=Vector3.new(1.03,0.58,0),Vector3.new(1.25,-0.83,0)
 if pose=="Wave" or pose=="Cheer" then rightB=Vector3.new(1.62,2.25,0) end
 if pose=="Cheer" then leftB=Vector3.new(-1.62,2.25,0) end
 rod(model,"LeftArm",leftA,leftB,0.58,skin)
 rod(model,"RightArm",rightA,rightB,0.58,skin)
 ball(model,"LeftEye",Vector3.new(0.15,0.18,0.10),Vector3.new(-0.27,1.73,0.71),ink)
 ball(model,"RightEye",Vector3.new(0.15,0.18,0.10),Vector3.new(0.27,1.73,0.71),ink)
 modelPart(model,"Smile",Vector3.new(0.30,0.08,0.10),Vector3.new(0,1.40,0.75),ink)
 if outlineColor then
  for index,p in ipairs({torso,head,model.LeftLeg,model.RightLeg,model.LeftArm,model.RightArm}) do
   local shell=p:Clone()
   shell.Name=p.Name.."Outline"
   shell.Size=p.Size+Vector3.new(0.24,0.24,0.24)
   shell.Color=rainbow and ({gold,mint,pink,Color3.fromRGB(185,153,242),blue,Color3.fromRGB(255,156,76)})[index] or outlineColor
   shell.CFrame=p.CFrame-Vector3.new(0,0,0.16)
   shell.Parent=model
  end
 end
end
local function createAsset(item)
 local old=assets:FindFirstChild(item.id)
 if old then return old end
 local model=make("Model",item.id,assets)
 model:SetAttribute("CatalogId",item.id)
 model:SetAttribute("Category",item.category)
 if item.preview=="Bee" then
  ball(model,"Body",Vector3.new(2.7,2.1,2.0),Vector3.zero,item.color)
  for _,side in ipairs({-1,1}) do
   local band=modelPart(model,"BeeStripe",Vector3.new(0.18,2.13,2.03),Vector3.new(side*0.60,0,0),ink,Enum.PartType.Cylinder)
   band.CFrame=CFrame.new(band.Position)
   local wing=ball(model,"Wing",Vector3.new(1.55,0.24,1.8),Vector3.new(side*1.05,1.00,-0.45),white,0.12)
   wing.CFrame=wing.CFrame*CFrame.Angles(0,0,side*0.25)
   ball(model,"Eye",Vector3.new(0.20,0.25,0.13),Vector3.new(side*0.45,0.30,0.97),ink)
   rod(model,"Antenna",Vector3.new(side*0.50,0.90,0.35),Vector3.new(side*0.72,1.70,0.35),0.11,ink)
   ball(model,"AntennaTip",Vector3.new(0.25,0.25,0.25),Vector3.new(side*0.72,1.70,0.35),gold)
  end
  modelPart(model,"Smile",Vector3.new(0.35,0.10,0.10),Vector3.new(0,-0.03,1.02),ink)
 elseif item.preview=="Cloud" then
  for index,q in ipairs({Vector3.zero,Vector3.new(-0.8,0.22,0),Vector3.new(0.8,0.22,0),Vector3.new(0,0.65,-0.12)}) do
   ball(model,"CloudPuff"..index,Vector3.new(1.8,1.7,1.65),q,index%2==0 and white or item.color)
  end
  for _,side in ipairs({-1,1}) do
   ball(model,"Ear",Vector3.new(0.68,1.30,0.65),Vector3.new(side*1.15,1.00,0.2),Color3.fromRGB(124,191,232))
   ball(model,"Eye",Vector3.new(0.18,0.22,0.12),Vector3.new(side*0.47,0.47,0.87),ink)
   ball(model,"Paw",Vector3.new(0.62,0.53,0.63),Vector3.new(side*0.78,-0.79,0.45),white)
  end
  ball(model,"Muzzle",Vector3.new(0.98,0.64,0.52),Vector3.new(0,0.1,0.85),white)
  ball(model,"Nose",Vector3.new(0.23,0.18,0.16),Vector3.new(0,0.28,1.12),ink)
 elseif item.preview=="Wave" or item.preview=="Cheer" then
  avatar(model,item.preview)
 elseif item.preview=="Star" then
  star(model,Vector3.new(0,0,-0.13),1.05,ink,0.38)
  star(model,Vector3.new(0,0,0.12),0.94,item.color,0.33)
  ball(model,"Shine",Vector3.new(0.23,0.23,0.10),Vector3.new(-0.45,0.70,0.32),white)
 elseif item.preview=="Heart" then
  triangle(model,Vector3.new(-1.45,0.30,0),Vector3.new(1.45,0.30,0),Vector3.new(0,-1.50,0),item.color,0.7)
  for _,side in ipairs({-1,1}) do ball(model,"HeartLobe",Vector3.new(1.65,1.55,0.90),Vector3.new(side*0.69,0.57,0),item.color) end
  ball(model,"HeartShine",Vector3.new(0.18,0.45,0.09),Vector3.new(-0.91,0.85,0.44),white)
 elseif item.preview=="Ribbon" or item.preview=="Rainbow" then
  local colors={Color3.fromRGB(255,106,138),Color3.fromRGB(255,170,68),gold,mint,blue,Color3.fromRGB(143,131,245)}
  for index=1,12 do
   local t0,t1=(index-1)/12,index/12
   local a=Vector3.new(-2.15+t0*4.3,math.sin(t0*math.pi*2)*0.65,-0.45+t0*0.9)
   local b=Vector3.new(-2.15+t1*4.3,math.sin(t1*math.pi*2)*0.65,-0.45+t1*0.9)
   local color=item.preview=="Rainbow" and colors[math.floor(t0*#colors)+1] or item.color:Lerp(pink,t0)
   rod(model,"RibbonSegment",a,b,0.40,color)
  end
  ball(model,"RibbonSpark",Vector3.new(0.5,0.5,0.5),Vector3.new(2.15,0,0.45),white)
 elseif item.preview=="Outline" then
  avatar(model,"Idle",item.color,item.id=="RainbowOutline")
 elseif item.preview=="Potion" then
  local bottle=modelPart(model,"Bottle",Vector3.new(2.0,1.55,1.55),Vector3.new(0,-0.05,0),item.color,Enum.PartType.Cylinder,0.32)
  bottle.CFrame=bottle.CFrame*CFrame.Angles(0,0,math.pi/2)
  local liquid=modelPart(model,"SnowLiquid",Vector3.new(1.35,1.33,1.33),Vector3.new(0,-0.28,0),blue,Enum.PartType.Cylinder)
  liquid.CFrame=liquid.CFrame*CFrame.Angles(0,0,math.pi/2)
  local neck=modelPart(model,"BottleNeck",Vector3.new(0.55,0.64,0.64),Vector3.new(0,1.15,0),item.color,Enum.PartType.Cylinder,0.22)
  neck.CFrame=neck.CFrame*CFrame.Angles(0,0,math.pi/2)
  local cork=modelPart(model,"Cork",Vector3.new(0.27,0.74,0.74),Vector3.new(0,1.53,0),ink,Enum.PartType.Cylinder)
  cork.CFrame=cork.CFrame*CFrame.Angles(0,0,math.pi/2)
  for index=1,3 do
   local angle=index*math.pi/3
   rod(model,"Snowflake",Vector3.new(-math.cos(angle)*0.40,-math.sin(angle)*0.40,0.82),Vector3.new(math.cos(angle)*0.40,math.sin(angle)*0.40,0.82),0.07,white)
  end
 elseif item.preview=="Wand" then
  rod(model,"WandHandle",Vector3.new(-0.95,-1.80,0),Vector3.new(0.67,1.05,0),0.23,ink)
  rod(model,"WandGrip",Vector3.new(-0.90,-1.72,0.01),Vector3.new(-0.53,-1.06,0.01),0.30,pink)
  star(model,Vector3.new(0.79,1.26,0),0.57,item.color,0.28)
 end
 assetCount+=1
 return model
end
for _,item in ipairs(catalog.Items) do createAsset(item) end
if existing then return {built=false,reason="Existing editable PlaygroundShell preserved",createdAssets=assetCount} end

local gui=make("ScreenGui","PlaygroundShell",StarterGui,{Enabled=true,ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=25,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
gui:SetAttribute("LayoutVersion",1)
local wallet=make("Frame","Wallet",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,14),Size=UDim2.new(0.24,0,0,64),BackgroundColor3=cream,BorderSizePixel=0,ZIndex=3})
make("UISizeConstraint","SizeLimit",wallet,{MinSize=Vector2.new(158,58),MaxSize=Vector2.new(248,64)})
corner(wallet,16) stroke(wallet,4)
local coin=make("Frame","Coin",wallet,{Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(37,37),BackgroundColor3=gold,BorderSizePixel=0,ZIndex=4})
corner(coin,100) stroke(coin,3)
text(coin,"Symbol","★",UDim2.fromScale(0.08,0.04),UDim2.fromScale(0.84,0.84),body,25,ink,5)
text(wallet,"Coins","...",UDim2.fromOffset(58,8),UDim2.new(1,-68,0,29),headline,27).TextXAlignment=Enum.TextXAlignment.Left
text(wallet,"Wins","0 wins",UDim2.fromOffset(59,37),UDim2.new(1,-69,0,17),body,14).TextXAlignment=Enum.TextXAlignment.Left
local dock=make("Frame","Dock",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-18),Size=UDim2.fromOffset(268,48),BackgroundTransparency=1,ZIndex=3})
button(dock,"Shop","SHOP",UDim2.fromOffset(0,0),UDim2.fromOffset(118,46),gold,27)
button(dock,"Emote","HI!",UDim2.fromOffset(132,0),UDim2.fromOffset(56,46),blue,20)
button(dock,"Emoji","♥",UDim2.fromOffset(202,0),UDim2.fromOffset(56,46),pink,27)
local toast=make("Frame","RewardToast",gui,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,84),Size=UDim2.new(0.38,0,0,50),BackgroundColor3=gold,BorderSizePixel=0,Visible=false,ZIndex=12})
make("UISizeConstraint","SizeLimit",toast,{MinSize=Vector2.new(240,50),MaxSize=Vector2.new(420,50)})
corner(toast,14) stroke(toast,4)
text(toast,"Message","+15 COINS",UDim2.fromScale(0.03,0.1),UDim2.fromScale(0.94,0.8),headline,25,ink,13)
local backdrop=make("TextButton","Backdrop",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=ink,BackgroundTransparency=0.38,Text="",AutoButtonColor=false,BorderSizePixel=0,Visible=false,ZIndex=20})
local shop=make("Frame","ShopPanel",gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.92,0.86),BackgroundColor3=cream,BorderSizePixel=0,Visible=false,ZIndex=21})
make("UISizeConstraint","SizeLimit",shop,{MinSize=Vector2.new(310,300),MaxSize=Vector2.new(1120,750)})
corner(shop,21) stroke(shop,5)
text(shop,"Title","GOODIES",UDim2.fromOffset(20,9),UDim2.new(1,-190,0,39),headline,31,ink,22).TextXAlignment=Enum.TextXAlignment.Left
text(shop,"Coins","... coins",UDim2.new(1,-162,0,17),UDim2.fromOffset(101,25),body,18,ink,22)
button(shop,"Close","X",UDim2.new(1,-51,0,12),UDim2.fromOffset(36,36),white,23,22)
local categories=make("ScrollingFrame","Categories",shop,{Position=UDim2.fromOffset(16,58),Size=UDim2.new(1,-32,0,42),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromScale(0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=3,ScrollBarImageColor3=ink,ZIndex=22})
make("UIListLayout","CategoryLayout",categories,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Left,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
for index,category in ipairs(catalog.Categories) do
 local b=button(categories,category,string.upper(category),UDim2.fromOffset(0,0),UDim2.fromOffset(category=="Highlights" and 123 or category=="All" and 64 or 95,33),category=="All" and gold or white,18,23)
 b.LayoutOrder=index
end
local cards=make("ScrollingFrame","Cards",shop,{Position=UDim2.fromOffset(14,113),Size=UDim2.new(1,-28,1,-169),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromScale(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=5,ScrollBarImageColor3=ink,ZIndex=22})
make("UIPadding","CardPadding",cards,{PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5)})
make("UIGridLayout","CardLayout",cards,{CellSize=UDim2.fromOffset(242,238),CellPadding=UDim2.fromOffset(12,12),FillDirectionMaxCells=4,HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
text(shop,"Status","Pick a little something for your next round.",UDim2.new(0,20,1,-42),UDim2.new(1,-40,0,31),body,17,ink,22)
local templates=make("Folder","Templates",gui)
local template=make("Frame","ItemCard",templates,{Size=UDim2.fromOffset(242,238),BackgroundColor3=white,BorderSizePixel=0,Visible=false,ZIndex=23})
corner(template,15) stroke(template,3)
text(template,"Name","ITEM",UDim2.fromOffset(12,8),UDim2.fromOffset(218,28),headline,22,ink,24)
local viewport=make("ViewportFrame","Preview",template,{Position=UDim2.fromOffset(12,43),Size=UDim2.fromOffset(218,122),BackgroundColor3=Color3.fromRGB(210,239,232),BorderSizePixel=0,Ambient=Color3.fromRGB(195,199,205),LightColor=Color3.fromRGB(255,255,255),LightDirection=Vector3.new(-0.4,-1,-0.5),ZIndex=24})
corner(viewport,11)
local world=make("WorldModel","World",viewport)
local camera=make("Camera","Camera",viewport,{FieldOfView=37,CFrame=CFrame.lookAt(Vector3.new(5,3.0,7),Vector3.new(0,0.05,0))})
viewport.CurrentCamera=camera
local pedestal=make("Part","PreviewPedestal",world,{Size=Vector3.new(0.22,4.8,4.8),CFrame=CFrame.new(0,-2.38,0)*CFrame.Angles(0,0,math.pi/2),Color=cream,Material=Enum.Material.SmoothPlastic,Shape=Enum.PartType.Cylinder,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
text(template,"Price","45 coins",UDim2.fromOffset(12,174),UDim2.fromOffset(105,19),body,15,ink,24).TextXAlignment=Enum.TextXAlignment.Left
text(template,"Category","PETS",UDim2.fromOffset(127,175),UDim2.fromOffset(103,17),body,12,Color3.fromRGB(85,111,112),24).TextXAlignment=Enum.TextXAlignment.Right
button(template,"Action","BUY",UDim2.fromOffset(12,202),UDim2.fromOffset(158,27),gold,18,24)
button(template,"Try","USE",UDim2.fromOffset(179,202),UDim2.fromOffset(51,27),blue,14,24).Visible=false
for index,item in ipairs(catalog.Items) do
 local card=template:Clone()
 card.Name=string.format("Slot%02d",index)
 card.LayoutOrder=index
 card.Visible=true
 card:SetAttribute("CatalogId",item.id)
 card:SetAttribute("Category",item.category)
 card:FindFirstChild("Name").Text=item.name
 card.Price.Text=tostring(item.price).." coins"
 card.Category.Text=string.upper(item.category)
 card.Preview.BackgroundColor3=item.color:Lerp(white,0.67)
 local preview=createAsset(item):Clone()
 preview.Name="ItemModel"
 preview.Parent=card.Preview.World
 card.Preview.CurrentCamera=card.Preview.Camera
 if item.available==false then card.Action.Text="COMING SOON" card.Action.BackgroundColor3=Color3.fromRGB(221,227,218) end
 card.Parent=cards
end
local vote=make("Frame","VotePanel",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-82),Size=UDim2.new(0.62,0,0.29,0),BackgroundColor3=cream,BorderSizePixel=0,Visible=false,ZIndex=8})
make("UISizeConstraint","SizeLimit",vote,{MinSize=Vector2.new(280,176),MaxSize=Vector2.new(660,222)})
corner(vote,18) stroke(vote,4)
text(vote,"Title","PICK THE NEXT ROUND",UDim2.fromScale(0.04,0.04),UDim2.fromScale(0.72,0.18),headline,24,ink,9).TextXAlignment=Enum.TextXAlignment.Left
text(vote,"Timer","12s",UDim2.fromScale(0.80,0.06),UDim2.fromScale(0.16,0.14),headline,23,ink,9)
local bb=button(vote,"BritishBulldog","BRITISH\nBULLDOG",UDim2.fromScale(0.04,0.28),UDim2.fromScale(0.44,0.45),blue,24,9)
local tag=button(vote,"TagYoureIt","TAG\nYOU'RE IT",UDim2.fromScale(0.52,0.28),UDim2.fromScale(0.44,0.45),pink,24,9)
text(vote,"VotesBritishBulldog","0 votes",UDim2.fromScale(0.04,0.77),UDim2.fromScale(0.44,0.13),body,16,ink,9)
text(vote,"VotesTagYoureIt","0 votes",UDim2.fromScale(0.52,0.77),UDim2.fromScale(0.44,0.13),body,16,ink,9)
text(vote,"Message","Step onto a card to vote, or tap it here.",UDim2.fromScale(0.03,0.91),UDim2.fromScale(0.94,0.065),body,12,ink,9)
return {built=true,gui=gui:GetFullName(),slots=#catalog.Items,viewportFrames=#catalog.Items,createdAssets=assetCount,authoredTemplate=template:GetFullName()}

end
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
local StarterPlayerScripts=game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Existing British Bulldog arena is required")
assert(britishBulldog:FindFirstChild("Gameplay"),"British Bulldog Gameplay is missing; existing geometry was preserved")
for _,name in ipairs({"ArenaBounds","SafeNorth","SafeSouth","RunnersNorth","RunnersSouth","BulldogSpawns","NorthLine","SouthLine"}) do
 assert(britishBulldog.Gameplay:FindFirstChild(name),"British Bulldog Gameplay."..name.." is missing; existing geometry was preserved")
end
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
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeExpansion20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeExpansion20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Expansion backup container must be a Folder")
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
 if not gui or guiBackups:FindFirstChild(gui.Name) then return end
 assert(gui:IsA("ScreenGui"),gui.Name.." must be a ScreenGui")
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
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest","BBMovementRequest"}) do remote(name) end
local state=ReplicatedStorage:FindFirstChild("PlaygroundState")
if not state then
 state=Instance.new("Folder")
 state.Name="PlaygroundState"
 for name,value in pairs({Phase="Waiting",VotingEndsAt=0,VotesBritishBulldog=0,VotesTagYoureIt=0,AutomaticRounds=true}) do state:SetAttribute(name,value) end
 state.Parent=ReplicatedStorage
else assert(state:IsA("Folder"),"PlaygroundState must be a Folder") end
for _,name in ipairs({"BritishBulldogState","TagState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 if not object then
  object=Instance.new("Folder")
  object.Name=name
  object:SetAttribute("Phase","Waiting")
  object.Parent=ReplicatedStorage
 else assert(object:IsA("Folder"),name.." must be a Folder") end
end
local config=ServerStorage:FindFirstChild("PlaygroundAdminConfig")
if not config then
 config=Instance.new("Folder")
 config.Name="PlaygroundAdminConfig"
 config.Parent=ServerStorage
end
assert(config:IsA("Folder"),"PlaygroundAdminConfig must be a Folder")
if config:GetAttribute("AdminUserId")==nil then config:SetAttribute("AdminUserId",1201803949) end
if config:GetAttribute("ExtraAdminUserIds")==nil then config:SetAttribute("ExtraAdminUserIds","") end
for _,name in ipairs({"BritishBulldogHUD","TagHUD","PlaygroundAdminPanel","PlaygroundShell"}) do saveGui(StarterGui:FindFirstChild(name)) end
install("ModuleScript","PlaygroundCatalog",sources.PlaygroundCatalog,ReplicatedStorage,baseCaps)
local lobbyResult=buildLobby()
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Lobby creation failed")
assert(lobby:FindFirstChild("Gameplay") and lobby.Gameplay:FindFirstChild("LobbySpawn"),"Lobby gameplay spawn is missing")
local depthResult=buildLobbyDepth()
local improvements=lobby:FindFirstChild("Improvements20261003")
assert(improvements and improvements:GetAttribute("Applied")==true,"Existing lobby depth pass is incomplete; it was preserved")
local tagResult=buildTagArena()
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Tag arena creation failed")
assert(tag:FindFirstChild("Gameplay") and tag.Gameplay:FindFirstChild("ArenaBounds"),"Existing Tag geometry lacks required Gameplay; it was preserved")
for _,name in ipairs({"StartPads","TaggerSpawn","NavigationNodes"}) do
 assert(tag.Gameplay:FindFirstChild(name),"Tag Gameplay."..name.." is missing; existing geometry was preserved")
end
if not StarterGui:FindFirstChild("BritishBulldogHUD") then buildBritishBulldogHUD() end
buildTagHUD()
buildAdmin()
buildShell()
local cosmeticAssets=assert(ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets"),"Cosmetic asset folder missing")
assert(cosmeticAssets:IsA("Folder"),"PlaygroundCosmeticAssets must be a Folder")
local britishBulldogHUD=assert(StarterGui:FindFirstChild("BritishBulldogHUD"),"British Bulldog HUD missing")
local tagHUD=assert(StarterGui:FindFirstChild("TagHUD"),"Tag HUD missing")
local adminHUD=assert(StarterGui:FindFirstChild("PlaygroundAdminPanel"),"Admin panel missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Playground shell missing")
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

install("ModuleScript","BritishBulldogRules",sources.BritishBulldogRules,ServerScriptService,baseCaps)
install("ModuleScript","BritishBulldogService",sources.BritishBulldogService,ServerScriptService,rpcCaps)
install("ModuleScript","TagService",sources.TagService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundEconomyService",sources.PlaygroundEconomyService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundCoordinator",sources.PlaygroundCoordinator,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundAdminService",sources.PlaygroundAdminService,ServerScriptService,rpcCaps)
local clientScripts={
 install("LocalScript","Controller",sources.BritishBulldogHUD,britishBulldogHUD,baseCaps),
 install("LocalScript","BritishBulldogCamera",sources.BritishBulldogCamera,StarterPlayerScripts,baseCaps),
 install("LocalScript","Controller",sources.TagHUDController,tagHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundAdminController,adminHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundShellController,shell,rpcCaps),
 install("LocalScript","PlaygroundEmotes",sources.PlaygroundEmotes,StarterPlayerScripts,baseCaps),
 install("LocalScript","PlaygroundLobbyAtmosphere",sources.PlaygroundLobbyAtmosphere,StarterPlayerScripts,baseCaps),
 install("LocalScript","MovementController",sources.BBMovement,britishBulldogHUD,inputRpcCaps),
 install("LocalScript","PlayerLevelController",sources.PlayerLevel,shell,previewCaps),
}
for _,object in ipairs(clientScripts) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 if backups:GetAttribute("LegacyBootstrapDisabled")==nil then backups:SetAttribute("LegacyBootstrapDisabled",oldBootstrap.Disabled) end
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
local oldSpawn=workspace:FindFirstChild("SpawnLocation")
if oldSpawn and oldSpawn:IsA("SpawnLocation") then
 if backups:GetAttribute("LegacySpawnEnabled")==nil then backups:SetAttribute("LegacySpawnEnabled",oldSpawn.Enabled) end
 oldSpawn.Enabled=false
end
lobby.Gameplay.LobbySpawn.Enabled=true
if backups:GetAttribute("BritishBulldogAutoStart")==nil then backups:SetAttribute("BritishBulldogAutoStart",britishBulldog:GetAttribute("AutoStart")) end
britishBulldog:SetAttribute("AutoStart",false)
local bootstrap=install("Script","PlaygroundBootstrap",sources.PlaygroundBootstrap,ServerScriptService,rpcCaps)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("ExpansionInstalled",true)
backups:SetAttribute("ExpansionVersion",1)
backups:SetAttribute("MovementRewardsInstalled",true)
return {installed=true,scripts=#installed,lobby=lobbyResult,depth=depthResult,tag=tagResult,movement=movementResult,levels=levelResult,authoredLayoutsPreserved=true,britishBulldogGeometryPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
