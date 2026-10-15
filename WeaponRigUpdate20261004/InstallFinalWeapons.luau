assert(not game:GetService("RunService"):IsRunning(), "Keep Play stopped")
local function find(path)
 local target = game
 for segment in path:gmatch("[^.]+") do target = assert(target:FindFirstChild(segment), "Missing " .. path) end
 return target
end
local function normalize(source) return source:gsub("\r\n", "\n"):gsub("%s+$", "") end
local entries = {{path="ServerScriptService.BritishBulldogService", before=[====[local Players = game:GetService("Players")
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
local BAT_RAGDOLL_SECONDS = 1.35

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
		or record.frozen or record.ragdoll or record.pendingBulldog or not alive(record) then return false end
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
		if record.root == burst.root and burst.root.Parent and burst.direction then
			local current = burst.root.AssemblyLinearVelocity
			burst.root.AssemblyLinearVelocity = current - burst.direction * current:Dot(burst.direction)
		end
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.isBot then
			pcall(function() burst.root:SetNetworkOwnershipAuto() end)
		end
	end
end

function Service:_cancelMovement(record)
	self:_releaseSprint(record)
	self:_stopDodgeBurst(record)
	setAttribute(record.player, "BBDodgeStartedAt", 0)
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

local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
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
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity = Vector2.new(initial.X, initial.Z)
	velocity.Parent = root
	local burst = { root = root, attachment = attachment, velocity = velocity, direction = direction,
		token = self.currentRound, crossing = self.crossingNumber, endsAt = now + duration }
	record.dodgeBurst = burst
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity = initial + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or record.frozen or record.role ~= "Runner" or record.arrived or not alive(record) or time >= burst.endsAt then
			self:_stopDodgeBurst(record, burst)
			return
		end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		if step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.8, 4, 2.8), step, params) then
			self:_stopDodgeBurst(record, burst)
			return
		end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
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
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	if not self:_dodgeClear(record, travel.Unit, travel.Magnitude, params) then return { ok = false, message = "No room to dodge." } end
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + duration, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	record.dodgeReadyAt = now + self:_setting("DodgeCooldownSeconds", 4, 0.1)
	self:_publishMovement(record)
	return { ok = true, startedAt = now, direction = direction, duration = duration }
end

function Service:_restoreJump(record)
	local saved = record.jumpLock
	if not saved then return end
	record.jumpLock = nil
	local humanoid = saved.humanoid
	if humanoid and humanoid.Parent then
		humanoid.Jump = false
		humanoid.JumpPower = saved.JumpPower
		humanoid.JumpHeight = saved.JumpHeight
		humanoid.AutoJumpEnabled = saved.AutoJumpEnabled
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, saved.JumpingEnabled)
	end
end

function Service:_lockJump(record)
	local humanoid = record.humanoid
	if not record.participating or not humanoid or not humanoid.Parent then return end
	if record.jumpLock and record.jumpLock.humanoid ~= humanoid then
		self:_restoreJump(record)
	end
	if not record.jumpLock then
		record.jumpLock = {
			humanoid = humanoid,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoJumpEnabled = humanoid.AutoJumpEnabled,
			JumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		}
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoJumpEnabled = false
	humanoid.Jump = false
end

function Service:_setRole(record, role, status)
	self:_lockJump(record)
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

function Service:_restoreRagdoll(record, standUp)
	local saved = record.ragdoll
	if not saved then return end
	record.ragdoll = nil
	disconnectAll(saved.connections)
	for part, original in pairs(saved.parts) do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CanCollide = original.CanCollide
		end
	end
	for _, instance in ipairs(saved.created) do
		if instance.Parent then instance:Destroy() end
	end
	for _, original in ipairs(saved.motors) do
		if original.motor.Parent then original.motor.Enabled = original.Enabled end
	end
	local humanoid = saved.humanoid
	if standUp and humanoid.Parent and humanoid.Health > 0 and saved.character.Parent and saved.root.Parent then
		saved.character:PivotTo(saved.standCFrame * saved.root.CFrame:Inverse() * saved.character:GetPivot())
	end
	if humanoid.Parent then
		humanoid.RequiresNeck = saved.RequiresNeck
		humanoid.AutoRotate = saved.AutoRotate
		humanoid.PlatformStand = saved.PlatformStand
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, saved.GettingUpEnabled)
		if standUp and humanoid.Health > 0 and not saved.PlatformStand then
			humanoid:ChangeState(saved.GettingUpEnabled and Enum.HumanoidStateType.GettingUp or Enum.HumanoidStateType.Running)
		end
	end
	setAttribute(saved.character, "BBRagdolled", false)
	setAttribute(record.player, "BBRagdolled", false)
	if record.character == saved.character then self:_lockJump(record) end
	if saved.root.Parent and not record.frozen then
		pcall(function()
			if record.isBot then saved.root:SetNetworkOwner(nil) else saved.root:SetNetworkOwnershipAuto() end
		end)
	end
end

function Service:_ragdoll(record, attacker, now)
	if not alive(record) then self:_freeze(record) return false end
	self:_restoreRagdoll(record, true)
	local character, humanoid, root = record.character, record.humanoid, record.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local saved = {
		character = character, humanoid = humanoid, root = root,
		endsAt = now + BAT_RAGDOLL_SECONDS, token = self.currentRound, freezeAfter = true,
		standCFrame = CFrame.lookAt(root.Position, root.Position + look.Unit),
		RequiresNeck = humanoid.RequiresNeck, PlatformStand = humanoid.PlatformStand,
		AutoRotate = humanoid.AutoRotate, GettingUpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
		motors = {}, parts = {}, created = {}, connections = {},
	}
	self:_freeze(record)
	record.lockedCFrame = nil
	record.ragdoll = saved
	local ok, failure = xpcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "BBRagdollConstraints"
		folder.Parent = character
		table.insert(saved.created, folder)
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		for _, motor in ipairs(character:GetDescendants()) do
			if motor:IsA("Motor6D") and motor.Part0 and motor.Part1
				and motor.Part0.Parent == character and motor.Part1.Parent == character then
				local first, second = motor.Part0, motor.Part1
				for _, part in ipairs({ first, second }) do
					if not saved.parts[part] then saved.parts[part] = { CanCollide = part.CanCollide } end
				end
				table.insert(saved.motors, { motor = motor, Enabled = motor.Enabled })
				if motor.Enabled and first ~= root and second ~= root then
					local firstAttachment = Instance.new("Attachment")
					firstAttachment.Name = "BBRagdollA0"
					firstAttachment.CFrame = motor.C0 * motor.Transform
					firstAttachment.Parent = first
					table.insert(saved.created, firstAttachment)
					local secondAttachment = Instance.new("Attachment")
					secondAttachment.Name = "BBRagdollA1"
					secondAttachment.CFrame = motor.C1
					secondAttachment.Parent = second
					table.insert(saved.created, secondAttachment)
					local socket = Instance.new("BallSocketConstraint")
					socket.Name = motor.Name .. "Socket"
					socket.Attachment0 = firstAttachment
					socket.Attachment1 = secondAttachment
					socket.LimitsEnabled = true
					socket.TwistLimitsEnabled = true
					local name = motor.Name:lower()
					local restrained = name:find("neck") or name:find("waist") or name:find("wrist") or name:find("ankle")
					socket.UpperAngle = restrained and 25 or 65
					socket.TwistLowerAngle = restrained and -20 or -45
					socket.TwistUpperAngle = restrained and 20 or 45
					socket.MaxFrictionTorque = 4
					socket.Restitution = 0
					socket.Parent = folder
					local noCollision = Instance.new("NoCollisionConstraint")
					noCollision.Name = motor.Name .. "NoCollision"
					noCollision.Part0 = first
					noCollision.Part1 = second
					noCollision.Parent = folder
					motor.Enabled = false
				end
			end
		end
		for part in pairs(saved.parts) do
			part.CanCollide = part ~= root
			pcall(function() part:SetNetworkOwner(nil) end)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		local direction = attacker and attacker.root and root.Position - attacker.root.Position or -look
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.01 then direction = -look end
		direction = direction.Unit
		root.AssemblyLinearVelocity = direction * 8 + Vector3.new(0, 3, 0)
		root.AssemblyAngularVelocity = Vector3.new(direction.Z * 3, 0, -direction.X * 3)
		setAttribute(record.player, "BBRagdolled", true)
		setAttribute(character, "BBRagdolled", true)
		table.insert(saved.connections, humanoid.Died:Connect(function()
			if record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
		table.insert(saved.connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent and record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
	end, debug.traceback)
	if not ok then
		self:_restoreRagdoll(record, true)
		self:_freeze(record)
		warn("British Bulldog ragdoll could not start: " .. tostring(failure))
	end
	return ok
end

function Service:_updateRagdoll(record, now)
	local saved = record.ragdoll
	if not saved then return end
	if record.character ~= saved.character or not alive(record) or not record.participating
		or not self.active or self.currentRound ~= saved.token then
		self:_restoreRagdoll(record, alive(record) and record.character == saved.character)
	elseif now >= saved.endsAt then
		local freezeAfter = saved.freezeAfter
		self:_restoreRagdoll(record, true)
		if freezeAfter then self:_freeze(record) else self:_unfreeze(record) end
	end
end

function Service:_freeze(record)
	self:_lockJump(record)
	self:_cancelMovement(record)
	if record.ragdoll then
		record.ragdoll.freezeAfter = true
		record.frozen = true
		return
	end
	if not alive(record) then
		record.frozen = true
		return
	end
	local humanoid = record.humanoid
	if not record.movement then
		record.movement = {
			WalkSpeed = humanoid.WalkSpeed,
			AutoRotate = humanoid.AutoRotate,
		}
	end
	record.frozen = true
	record.lockedCFrame = record.root.CFrame
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.Jump = false
	pcall(function()
		record.root:SetNetworkOwner(nil)
	end)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
end

function Service:_unfreeze(record)
	if record.ragdoll then
		record.ragdoll.freezeAfter = false
		return
	end
	if record.movement and record.humanoid and record.humanoid.Parent then
		for name, value in pairs(record.movement) do
			record.humanoid[name] = value
		end
	end
	record.movement = nil
	record.frozen = false
	record.lockedCFrame = nil
	self:_lockJump(record)
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
	self:_restoreRagdoll(record, false)
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
	self:_restoreRagdoll(record, true)
	self:_cancelMovement(record)
	self:_unfreeze(record)
	self:_restoreJump(record)
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

function Service:_caught(record, status, now, attacker)
	now = now or workspace:GetServerTimeNow()
	if not self.active or not record.participating or record.role ~= "Runner" or self.phase == "Results" or (self.endsAt > 0 and now >= self.endsAt) then
		return false
	end
	record.arrived = false
	record.departed = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Tagged", status or "Tagged")
	if attacker and alive(record) then
		self:_ragdoll(record, attacker, now)
		local serial = attacker.player:GetAttribute("BBBatHitSerial")
		setAttribute(attacker.player, "BBBatHitSerial", (typeof(serial) == "number" and serial or 0) + 1)
	else
		self:_freeze(record)
	end
	return true
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
		self:_restoreRagdoll(record, false)
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
			self:_restoreRagdoll(record, false)
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
		self:_restoreRagdoll(record, false)
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
		self:_updateRagdoll(record, now)
		if record.participating and alive(record) then
			self:_lockJump(record)
			if record.ragdoll then
				record.humanoid:Move(Vector3.zero)
			elseif record.frozen and record.lockedCFrame then
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
						self:_caught(runner, "Tagged", now, bulldog)
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

return Service]====], after=[====[local Players = game:GetService("Players")
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
local BAT_RAGDOLL_SECONDS = 1.35
local BAT_SWING_COOLDOWN = 0.75
local BAT_SWING_CONTACT_START = 0.16
local BAT_SWING_CONTACT_END = 0.30
local BAT_SWING_FRONT_DOT = 0.25

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
		or record.frozen or record.ragdoll or record.pendingBulldog or not alive(record) then return false end
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
		if record.root == burst.root and burst.root.Parent and burst.direction then
			local current = burst.root.AssemblyLinearVelocity
			burst.root.AssemblyLinearVelocity = current - burst.direction * current:Dot(burst.direction)
		end
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.isBot then
			pcall(function() burst.root:SetNetworkOwnershipAuto() end)
		end
	end
end

function Service:_cancelMovement(record)
	self:_releaseSprint(record)
	self:_stopDodgeBurst(record)
	setAttribute(record.player, "BBDodgeStartedAt", 0)
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

local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
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
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity = Vector2.new(initial.X, initial.Z)
	velocity.Parent = root
	local burst = { root = root, attachment = attachment, velocity = velocity, direction = direction,
		token = self.currentRound, crossing = self.crossingNumber, endsAt = now + duration }
	record.dodgeBurst = burst
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity = initial + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or record.frozen or record.role ~= "Runner" or record.arrived or not alive(record) or time >= burst.endsAt then
			self:_stopDodgeBurst(record, burst)
			return
		end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		if step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.8, 4, 2.8), step, params) then
			self:_stopDodgeBurst(record, burst)
			return
		end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
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
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	if not self:_dodgeClear(record, travel.Unit, travel.Magnitude, params) then return { ok = false, message = "No room to dodge." } end
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + duration, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	record.dodgeReadyAt = now + self:_setting("DodgeCooldownSeconds", 4, 0.1)
	self:_publishMovement(record)
	return { ok = true, startedAt = now, direction = direction, duration = duration }
end

function Service:_restoreJump(record)
	local saved = record.jumpLock
	if not saved then return end
	record.jumpLock = nil
	local humanoid = saved.humanoid
	if humanoid and humanoid.Parent then
		humanoid.Jump = false
		humanoid.JumpPower = saved.JumpPower
		humanoid.JumpHeight = saved.JumpHeight
		humanoid.AutoJumpEnabled = saved.AutoJumpEnabled
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, saved.JumpingEnabled)
	end
end

function Service:_lockJump(record)
	local humanoid = record.humanoid
	if not record.participating or not humanoid or not humanoid.Parent then return end
	if record.jumpLock and record.jumpLock.humanoid ~= humanoid then
		self:_restoreJump(record)
	end
	if not record.jumpLock then
		record.jumpLock = {
			humanoid = humanoid,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoJumpEnabled = humanoid.AutoJumpEnabled,
			JumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		}
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoJumpEnabled = false
	humanoid.Jump = false
end

function Service:_setRole(record, role, status)
	record.batSwing = nil
	self:_lockJump(record)
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

function Service:_batSwingAllowed(record, now)
	return self.running and self.active and self.phase == "Crossing" and self.endsAt > now
		and record and record.ready and record.participating and record.role == "Bulldog"
		and not record.frozen and not record.ragdoll and not record.pendingBulldog and alive(record)
		and (record.isBot or record.player.Parent == Players) and self:_inField(record.root.Position)
end

function Service:TryBatSwing(player)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if not self:_batSwingAllowed(record, now) then return false, "Swing while playing as a Bulldog on the field." end
	if now < (record.batSwingReadyAt or 0) then return false, "Your bat is recovering." end
	record.batSwingReadyAt = now + BAT_SWING_COOLDOWN
	record.batSwing = {
		character = record.character, round = self.currentRound, crossing = self.crossingNumber,
		hitAt = now + BAT_SWING_CONTACT_START, endsAt = now + BAT_SWING_CONTACT_END,
	}
	local serial = player:GetAttribute("PCBatSwingSerial")
	setAttribute(player, "PCBatSwingAt", now)
	setAttribute(player, "PCBatSwingSerial", (typeof(serial) == "number" and serial or 0) + 1)
	return true, "Swinging."
end

function Service:CancelBatSwing(player)
	local record = self.records[player]
	if record then record.batSwing = nil end
end

function Service:_resolveBatSwings(now, rayParams)
	for _, attacker in pairs(self.records) do
		local swing = attacker.batSwing
		if swing then
			if not self:_batSwingAllowed(attacker, now) or swing.character ~= attacker.character
				or swing.round ~= self.currentRound or swing.crossing ~= self.crossingNumber or now > swing.endsAt then
				attacker.batSwing = nil
			elseif now >= swing.hitAt then
				local nearest, nearestDistance
				local forward = Vector3.new(attacker.root.CFrame.LookVector.X, 0, attacker.root.CFrame.LookVector.Z)
				for _, runner in pairs(self.records) do
					if runner ~= attacker and runner.participating and alive(runner)
						and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local offset = runner.root.Position - attacker.root.Position
						local horizontal = Vector3.new(offset.X, 0, offset.Z)
						local distance = offset.Magnitude
						local inFront = horizontal.Magnitude > 0.01 and forward.Magnitude > 0.01
							and forward.Unit:Dot(horizontal.Unit) >= BAT_SWING_FRONT_DOT
						if distance <= TAG_DISTANCE and inFront and (not nearestDistance or distance < nearestDistance)
							and not workspace:Raycast(attacker.root.Position, offset, rayParams) then
							nearest, nearestDistance = runner, distance
						end
					end
				end
				if nearest and self:_caught(nearest, "Tagged", now, attacker) then attacker.batSwing = nil end
			end
		end
	end
end

function Service:_restoreRagdoll(record, standUp)
	local saved = record.ragdoll
	if not saved then return end
	record.ragdoll = nil
	disconnectAll(saved.connections)
	for part, original in pairs(saved.parts) do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CanCollide = original.CanCollide
		end
	end
	for _, instance in ipairs(saved.created) do
		if instance.Parent then instance:Destroy() end
	end
	for _, original in ipairs(saved.motors) do
		if original.motor.Parent then original.motor.Enabled = original.Enabled end
	end
	for socket, enabled in pairs(saved.sockets or {}) do
		if socket.Parent then socket.Enabled = enabled end
	end
	local humanoid = saved.humanoid
	if standUp and humanoid.Parent and humanoid.Health > 0 and saved.character.Parent and saved.root.Parent then
		saved.character:PivotTo(saved.standCFrame * saved.root.CFrame:Inverse() * saved.character:GetPivot())
	end
	if humanoid.Parent then
		humanoid.RequiresNeck = saved.RequiresNeck
		humanoid.AutoRotate = saved.AutoRotate
		humanoid.PlatformStand = saved.PlatformStand
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, saved.GettingUpEnabled)
		if standUp and humanoid.Health > 0 and not saved.PlatformStand then
			humanoid:ChangeState(saved.GettingUpEnabled and Enum.HumanoidStateType.GettingUp or Enum.HumanoidStateType.Running)
		end
	end
	setAttribute(saved.character, "BBRagdolled", false)
	setAttribute(record.player, "BBRagdolled", false)
	if record.character == saved.character then self:_lockJump(record) end
	if saved.root.Parent and not record.frozen then
		pcall(function()
			if record.isBot then saved.root:SetNetworkOwner(nil) else saved.root:SetNetworkOwnershipAuto() end
		end)
	end
end

function Service:_ragdoll(record, attacker, now)
	if not alive(record) then self:_freeze(record) return false end
	self:_restoreRagdoll(record, true)
	local character, humanoid, root = record.character, record.humanoid, record.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local saved = {
		character = character, humanoid = humanoid, root = root,
		endsAt = now + BAT_RAGDOLL_SECONDS, token = self.currentRound, freezeAfter = true,
		standCFrame = CFrame.lookAt(root.Position, root.Position + look.Unit),
		RequiresNeck = humanoid.RequiresNeck, PlatformStand = humanoid.PlatformStand,
		AutoRotate = humanoid.AutoRotate, GettingUpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
		motors = {}, sockets = {}, parts = {}, created = {}, connections = {},
	}
	self:_freeze(record)
	record.lockedCFrame = nil
	record.ragdoll = saved
	local ok, failure = xpcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "BBRagdollConstraints"
		folder.Parent = character
		table.insert(saved.created, folder)
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		local socketsByPart = {}
		local function registerSocket(socket, first, second)
			socketsByPart[first] = socketsByPart[first] or {}
			socketsByPart[first][second] = socketsByPart[first][second] or {}
			table.insert(socketsByPart[first][second], socket)
		end
		for _, socket in ipairs(character:GetDescendants()) do
			if socket:IsA("BallSocketConstraint") and socket.Attachment0 and socket.Attachment1 then
				local first = socket.Attachment0:FindFirstAncestorWhichIsA("BasePart")
				local second = socket.Attachment1:FindFirstAncestorWhichIsA("BasePart")
				if first and second then registerSocket(socket, first, second) end
			end
		end
		for _, motor in ipairs(character:GetDescendants()) do
			if (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) and motor.Part0 and motor.Part1
				and motor.Part0.Parent == character and motor.Part1.Parent == character then
				local first, second = motor.Part0, motor.Part1
				for _, part in ipairs({ first, second }) do
					if not saved.parts[part] then saved.parts[part] = { CanCollide = part.CanCollide } end
				end
				table.insert(saved.motors, { motor = motor, Enabled = motor.Enabled })
				if motor.Enabled and first ~= root and second ~= root then
					local existing = socketsByPart[first] and socketsByPart[first][second] or socketsByPart[second] and socketsByPart[second][first]
					if existing then
						for _, socket in ipairs(existing) do
							if saved.sockets[socket] == nil then saved.sockets[socket] = socket.Enabled end
							socket.Enabled = true
						end
					else
					local firstAttachment = Instance.new("Attachment")
					firstAttachment.Name = "BBRagdollA0"
					firstAttachment.CFrame = motor.C0 * motor.Transform
					firstAttachment.Parent = first
					table.insert(saved.created, firstAttachment)
					local secondAttachment = Instance.new("Attachment")
					secondAttachment.Name = "BBRagdollA1"
					secondAttachment.CFrame = motor.C1
					secondAttachment.Parent = second
					table.insert(saved.created, secondAttachment)
					local socket = Instance.new("BallSocketConstraint")
					socket.Name = motor.Name .. "Socket"
					socket.Attachment0 = firstAttachment
					socket.Attachment1 = secondAttachment
					socket.LimitsEnabled = true
					socket.TwistLimitsEnabled = true
					local name = motor.Name:lower()
					local restrained = name:find("neck") or name:find("waist") or name:find("wrist") or name:find("ankle")
					socket.UpperAngle = restrained and 25 or 65
					socket.TwistLowerAngle = restrained and -20 or -45
					socket.TwistUpperAngle = restrained and 20 or 45
					socket.MaxFrictionTorque = 4
					socket.Restitution = 0
					socket.Parent = folder
					registerSocket(socket, first, second)
					local noCollision = Instance.new("NoCollisionConstraint")
					noCollision.Name = motor.Name .. "NoCollision"
					noCollision.Part0 = first
					noCollision.Part1 = second
					noCollision.Parent = folder
					end
					motor.Enabled = false
				end
			end
		end
		for part in pairs(saved.parts) do
			part.CanCollide = part ~= root
			pcall(function() part:SetNetworkOwner(nil) end)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		local direction = attacker and attacker.root and root.Position - attacker.root.Position or -look
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.01 then direction = -look end
		direction = direction.Unit
		root.AssemblyLinearVelocity = direction * 8 + Vector3.new(0, 3, 0)
		root.AssemblyAngularVelocity = Vector3.new(direction.Z * 3, 0, -direction.X * 3)
		setAttribute(record.player, "BBRagdolled", true)
		setAttribute(character, "BBRagdolled", true)
		table.insert(saved.connections, humanoid.Died:Connect(function()
			if record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
		table.insert(saved.connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent and record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
	end, debug.traceback)
	if not ok then
		self:_restoreRagdoll(record, true)
		self:_freeze(record)
		warn("British Bulldog ragdoll could not start: " .. tostring(failure))
	end
	return ok
end

function Service:_updateRagdoll(record, now)
	local saved = record.ragdoll
	if not saved then return end
	if record.character ~= saved.character or not alive(record) or not record.participating
		or not self.active or self.currentRound ~= saved.token then
		self:_restoreRagdoll(record, alive(record) and record.character == saved.character)
	elseif now >= saved.endsAt then
		local freezeAfter = saved.freezeAfter
		self:_restoreRagdoll(record, true)
		if freezeAfter then self:_freeze(record) else self:_unfreeze(record) end
	end
end

function Service:_freeze(record)
	record.batSwing = nil
	self:_lockJump(record)
	self:_cancelMovement(record)
	if record.ragdoll then
		record.ragdoll.freezeAfter = true
		record.frozen = true
		return
	end
	if not alive(record) then
		record.frozen = true
		return
	end
	local humanoid = record.humanoid
	if not record.movement then
		record.movement = {
			WalkSpeed = humanoid.WalkSpeed,
			AutoRotate = humanoid.AutoRotate,
		}
	end
	record.frozen = true
	record.lockedCFrame = record.root.CFrame
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.Jump = false
	pcall(function()
		record.root:SetNetworkOwner(nil)
	end)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
end

function Service:_unfreeze(record)
	if record.ragdoll then
		record.ragdoll.freezeAfter = false
		return
	end
	if record.movement and record.humanoid and record.humanoid.Parent then
		for name, value in pairs(record.movement) do
			record.humanoid[name] = value
		end
	end
	record.movement = nil
	record.frozen = false
	record.lockedCFrame = nil
	self:_lockJump(record)
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
	record.batSwing = nil
	if not record.root or not record.root.Parent or not record.character then
		return
	end
	self:_restoreRagdoll(record, false)
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
	record.batSwing = nil
	record.batSwingReadyAt = nil
	self:_restoreRagdoll(record, true)
	self:_cancelMovement(record)
	self:_unfreeze(record)
	self:_restoreJump(record)
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

function Service:_caught(record, status, now, attacker)
	now = now or workspace:GetServerTimeNow()
	if not self.active or not record.participating or record.role ~= "Runner" or self.phase == "Results" or (self.endsAt > 0 and now >= self.endsAt) then
		return false
	end
	record.arrived = false
	record.departed = false
	self:_departure(record, false, 0)
	self:_setRole(record, "Tagged", status or "Tagged")
	if attacker and alive(record) then
		self:_ragdoll(record, attacker, now)
		local serial = attacker.player:GetAttribute("PCBatHitSerial")
		setAttribute(attacker.player, "PCBatHitSerial", (typeof(serial) == "number" and serial or 0) + 1)
	else
		self:_freeze(record)
	end
	return true
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
		self:_restoreRagdoll(record, false)
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
			self:_restoreRagdoll(record, false)
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
		self:_restoreRagdoll(record, false)
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
					if nearest <= TAG_DISTANCE then self:TryBatSwing(bot.player) end
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
		self:_updateRagdoll(record, now)
		if record.participating and alive(record) then
			self:_lockJump(record)
			if record.ragdoll then
				record.humanoid:Move(Vector3.zero)
			elseif record.frozen and record.lockedCFrame then
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
	self:_resolveBatSwings(now, rayParams)
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

return Service]====]},
{path="ServerScriptService.PlaygroundAdminService", before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true, ClearPreview = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
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

function Admin:_target(player, payload)
	if payload ~= nil and typeof(payload) ~= "table" then return nil, "Choose a player in this server." end
	local id = player.UserId
	if payload and payload.targetUserId ~= nil then id = payload.targetUserId end
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id == 0 or math.abs(id) > 1000000000000 or (id < 0 and not self.isStudio) then
		return nil, "Choose a player in this server."
	end
	local target = self.players:GetPlayerByUserId(id)
	if not target then return nil, "That player is no longer in this server." end
	return target
end

function Admin:Status(player, ok, message, target)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
	reply.players = {}
	for _, online in ipairs(self.players:GetPlayers()) do
		table.insert(reply.players, { userId = online.UserId, name = online.Name, displayName = online.DisplayName, ready = online:GetAttribute("PCDataReady") == true })
	end
	table.sort(reply.players, function(a, b)
		if a.name == b.name then return a.userId < b.userId end
		return a.name:lower() < b.name:lower()
	end)
	local economy = self.coordinator.economy
	if economy then
		reply.limits = table.clone(economy.AdminLimits)
		if target == false then target = nil
		else target = target or self.players:GetPlayerByUserId(player.UserId) end
		if target then
			reply.targetUserId = target.UserId
			reply.target = economy:Status(target, true)
			reply.target.userId = target.UserId
			reply.target.name = target.Name
			reply.target.displayName = target.DisplayName
			reply.target.batPreview = target:GetAttribute("PCAdminBatPreview") == true
		end
	end
	return reply
end

function Admin:Handle(player, action, payload)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and not grants[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local target, targetError
	if grants[action] or action == "GetStatus" then
		if grants[action] and (typeof(payload) ~= "table" or payload.targetUserId == nil) then return self:Status(player, false, "Choose a target player for this action.") end
		target, targetError = self:_target(player, payload)
		if not target then return self:Status(player, false, targetError, false) end
	end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.", target) end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.", target) end
	if self.busy then return self:Status(player, false, "Another control is finishing.", target) end
	self.busy = true
	local ok, success, message = pcall(function()
		if grants[action] then
			local economy = self.coordinator.economy
			if not economy then return false, "The player economy is not ready." end
			if action == "ClearPreview" then
				target:SetAttribute("PCAdminBatPreview", false)
				return true, "Lobby bat preview hidden."
			end
			if typeof(payload) ~= "table" then return false, "Choose an item or grant amount." end
			if action == "GrantItem" then
				local granted, reason = economy:AdminGrantItem(target, payload.itemId, payload.equip)
				local item = typeof(payload.itemId) == "string" and Catalog.ById[payload.itemId]
				if granted and payload.equip == true and item and item.slot == "Bat" then target:SetAttribute("PCAdminBatPreview", true) end
				return granted, reason
			end
			if action == "GrantCoins" then return economy:AdminGrantCoins(target, payload.amount) end
			if action == "AddLevels" then return economy:AdminAddLevels(target, payload.amount) end
		end
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
		return self:Status(player, false, "That admin action could not finish. Try again.", target)
	end
	if success and grants[action] then print("Playground admin " .. player.UserId .. " used " .. action .. " for " .. target.UserId) end
	return self:Status(player, success == true, message, target)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action, payload) return self:Handle(player, action, payload) end
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

return Admin]====], after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
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

function Admin:_target(player, payload)
	if payload ~= nil and typeof(payload) ~= "table" then return nil, "Choose a player in this server." end
	local id = player.UserId
	if payload and payload.targetUserId ~= nil then id = payload.targetUserId end
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id == 0 or math.abs(id) > 1000000000000 or (id < 0 and not self.isStudio) then
		return nil, "Choose a player in this server."
	end
	local target = self.players:GetPlayerByUserId(id)
	if not target then return nil, "That player is no longer in this server." end
	return target
end

function Admin:Status(player, ok, message, target)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
	reply.players = {}
	for _, online in ipairs(self.players:GetPlayers()) do
		table.insert(reply.players, { userId = online.UserId, name = online.Name, displayName = online.DisplayName, ready = online:GetAttribute("PCDataReady") == true })
	end
	table.sort(reply.players, function(a, b)
		if a.name == b.name then return a.userId < b.userId end
		return a.name:lower() < b.name:lower()
	end)
	local economy = self.coordinator.economy
	if economy then
		reply.limits = table.clone(economy.AdminLimits)
		if target == false then target = nil
		else target = target or self.players:GetPlayerByUserId(player.UserId) end
		if target then
			reply.targetUserId = target.UserId
			reply.target = economy:Status(target, true)
			reply.target.userId = target.UserId
			reply.target.name = target.Name
			reply.target.displayName = target.DisplayName
		end
	end
	return reply
end

function Admin:Handle(player, action, payload)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and not grants[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local target, targetError
	if grants[action] or action == "GetStatus" then
		if grants[action] and (typeof(payload) ~= "table" or payload.targetUserId == nil) then return self:Status(player, false, "Choose a target player for this action.") end
		target, targetError = self:_target(player, payload)
		if not target then return self:Status(player, false, targetError, false) end
	end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.", target) end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.", target) end
	if self.busy then return self:Status(player, false, "Another control is finishing.", target) end
	self.busy = true
	local ok, success, message = pcall(function()
		if grants[action] then
			local economy = self.coordinator.economy
			if not economy then return false, "The player economy is not ready." end
			if typeof(payload) ~= "table" then return false, "Choose an item or grant amount." end
			if action == "GrantItem" then
				return economy:AdminGrantItem(target, payload.itemId, payload.equip)
			end
			if action == "GrantCoins" then return economy:AdminGrantCoins(target, payload.amount) end
			if action == "AddLevels" then return economy:AdminAddLevels(target, payload.amount) end
		end
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
		return self:Status(player, false, "That admin action could not finish. Try again.", target)
	end
	if success and grants[action] then print("Playground admin " .. player.UserId .. " used " .. action .. " for " .. target.UserId) end
	return self:Status(player, success == true, message, target)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action, payload) return self:Handle(player, action, payload) end
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

return Admin]====]},
{path="ServerScriptService.PlaygroundBootstrap", before=[====[local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		return Leaderboards.new(lobby):Start()
	end)
	if ok then
		economy.leaderboards = result
		script.Destroying:Connect(function() result:Stop() end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local equipment = Equipment.new():Start()
script.Destroying:Connect(function() equipment:Stop() end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)]====], after=[====[local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		return Leaderboards.new(lobby):Start()
	end)
	if ok then
		economy.leaderboards = result
		script.Destroying:Connect(function() result:Stop() end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()
local Equipment = require(ServerScriptService:WaitForChild("PlaygroundEquipmentService"))
local equipment = Equipment.new({ BritishBulldog = britishBulldog, TagYoureIt = tag }):Start()
script.Destroying:Connect(function() equipment:Stop() end)
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)]====]},
{path="ServerScriptService.PlaygroundEquipmentService", before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local Equipment = {}
Equipment.__index = Equipment

local sparkTexture = "rbxasset://textures/particles/sparkles_main.dds"
local smokeTexture = "rbxasset://textures/particles/smoke_main.dds"
local fireTexture = "rbxasset://textures/particles/fire_main.dds"
local starTexture = sparkTexture
local heartTexture = smokeTexture

local batEffects = {
	B01 = { name = "Sawdust Swirl", color = Color3.fromRGB(227, 169, 91), accent = Color3.fromRGB(255, 233, 185), texture = smokeTexture, rate = 5, speed = 0.55, size = 0.12, gravity = -0.8, spin = 75, glow = 0, squash = 0.6, trail = 0.12 },
	B02 = { name = "Alloy Glints", color = Color3.fromRGB(186, 231, 255), accent = Color3.new(1, 1, 1), texture = sparkTexture, rate = 3, speed = 0.12, size = 0.23, gravity = 0.1, spin = 15, glow = 0.55, lines = "alloy", trail = 0.14 },
	B03 = { name = "Varsity Confetti", color = Color3.fromRGB(255, 85, 105), accent = Color3.fromRGB(112, 195, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.16, gravity = -2.2, spin = 180, glow = 0, squash = 1.3, secondary = true, trail = 0.15 },
	B04 = { name = "Hazard Beacon", color = Color3.fromRGB(255, 153, 36), accent = Color3.fromRGB(255, 244, 172), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.2, gravity = 0.2, spin = 0, glow = 0.65, lines = "hazard", trail = 0.14 },
	B05 = { name = "Bubblegum Hearts", color = Color3.fromRGB(255, 136, 209), accent = Color3.fromRGB(255, 226, 250), texture = heartTexture, rate = 3, speed = 0.7, size = 0.26, gravity = 0.3, spin = 20, glow = 0.1, secondary = true, lines = "heart", trail = 0.19 },
	B06 = { name = "Muddy Droplets", color = Color3.fromRGB(139, 90, 45), accent = Color3.fromRGB(191, 156, 83), texture = smokeTexture, rate = 6, speed = 0.6, size = 0.22, gravity = -3, spin = 45, glow = 0, squash = 0.3, trail = 0.12 },
	B07 = { name = "Coil Embers", color = Color3.fromRGB(255, 97, 25), accent = Color3.fromRGB(255, 217, 70), texture = fireTexture, rate = 6, speed = 0.65, size = 0.29, gravity = 0.9, spin = 20, glow = 0.75, secondary = true, trail = 0.18 },
	B08 = { name = "Frost Crystals", color = Color3.fromRGB(124, 229, 255), accent = Color3.fromRGB(232, 255, 255), texture = sparkTexture, rate = 4, speed = 0.25, size = 0.24, gravity = -0.3, spin = 40, glow = 0.35, mist = true, trail = 0.22 },
	B09 = { name = "Circuit Arcs", color = Color3.fromRGB(77, 139, 255), accent = Color3.fromRGB(199, 253, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.12, gravity = 0, spin = 120, glow = 0.8, lines = "lightning", trail = 0.12 },
	B10 = { name = "Arcade Pixels", color = Color3.fromRGB(248, 89, 235), accent = Color3.fromRGB(87, 247, 219), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.35, spin = 0, glow = 0.5, squash = -0.4, lines = "pixels", trail = 0.1 },
	B11 = { name = "Orbit Stardust", color = Color3.fromRGB(176, 126, 255), accent = Color3.fromRGB(134, 222, 255), texture = starTexture, rate = 3, speed = 0.3, size = 0.19, gravity = 0.25, spin = 65, glow = 0.6, lines = "orbit", trail = 0.25 },
	B12 = { name = "Champion Stars", color = Color3.fromRGB(255, 213, 64), accent = Color3.fromRGB(255, 247, 180), texture = starTexture, rate = 4, speed = 0.55, size = 0.26, gravity = 0.45, spin = 30, glow = 0.45, lines = "crown", trail = 0.2 },
	B13 = { name = "Skatepark Ribbons", color = Color3.fromRGB(78, 228, 206), accent = Color3.fromRGB(255, 133, 140), texture = sparkTexture, rate = 3, speed = 0.35, size = 0.12, gravity = 0, spin = 80, glow = 0.25, ribbons = true, trail = 0.23 },
	B14 = { name = "Ocean Spray", color = Color3.fromRGB(62, 218, 214), accent = Color3.fromRGB(161, 247, 255), texture = smokeTexture, rate = 5, speed = 0.7, size = 0.19, gravity = 0.6, spin = 35, glow = 0.15, mist = true, lines = "wave", trail = 0.23 },
	B15 = { name = "Sunburst Rays", color = Color3.fromRGB(255, 175, 35), accent = Color3.fromRGB(255, 246, 112), texture = sparkTexture, rate = 5, speed = 0.6, size = 0.16, gravity = 0.45, spin = 60, glow = 0.65, lines = "sun", trail = 0.21 },
}

local function effectAttachment(anchor, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = anchor
	return attachment
end

local function effectEmitter(parent, name, effect, secondary)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = effect.texture
	emitter.Color = ColorSequence.new(secondary and effect.accent or effect.color, effect.accent)
	emitter.Rate = secondary and 2 or effect.rate
	emitter.Lifetime = NumberRange.new(0.45, 0.95)
	emitter.Speed = NumberRange.new(effect.speed * 0.5, effect.speed)
	emitter.Acceleration = Vector3.new(0, effect.gravity, 0)
	emitter.Drag = 1.5
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-effect.spin, effect.spin)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, effect.size * 0.3), NumberSequenceKeypoint.new(0.2, effect.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.15, 0.12), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = effect.glow
	emitter.LightInfluence = 0.2
	emitter.VelocityInheritance = 0.15
	emitter.Squash = NumberSequence.new(effect.squash or 0)
	emitter:SetAttribute("BatHitBurst", secondary and 4 or 8)
	emitter.Parent = parent
	return emitter
end

local function effectLine(anchor, folder, name, first, last, color, width)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = effectAttachment(anchor, name .. "A", first)
	beam.Attachment1 = effectAttachment(anchor, name .. "B", last)
	beam.Width0 = width or 0.035
	beam.Width1 = width or 0.035
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.22)
	beam.LightEmission = 0.65
	beam.LightInfluence = 0.1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = folder
	return beam
end

local function effectTrail(anchor, folder, name, first, last, color, lifetime)
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = effectAttachment(anchor, name .. "A", first)
	trail.Attachment1 = effectAttachment(anchor, name .. "B", last)
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = lifetime
	trail.MinLength = 0.06
	trail.FaceCamera = true
	trail.LightEmission = 0.35
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = folder
end

function Equipment:_attachBatEffects(carrier, anchor, item, sourceSize, gripHeight)
	local effect = batEffects[item.id]
	if not effect then return end
	carrier:SetAttribute("HeldEffect", effect.name)
	local folder = Instance.new("Folder")
	folder.Name = "HeldVFX"
	folder.Parent = carrier
	local top = sourceSize.Y - gripHeight
	local middle = top * 0.68
	local radius = math.clamp(math.max(sourceSize.X, sourceSize.Z) * 0.55, 0.18, 0.48)
	local tip = effectAttachment(anchor, "BatEffectTip", Vector3.new(0, top, 0))
	local barrel = effectAttachment(anchor, "BatEffectBarrel", Vector3.new(0, middle, 0))
	effectEmitter(tip, effect.name, effect, false)
	if effect.secondary then effectEmitter(barrel, effect.name .. "Accent", effect, true) end
	if effect.mist then
		local mist = effectEmitter(barrel, "SoftMist", effect, true)
		mist.Texture = smokeTexture
		mist.Size = NumberSequence.new(0.13, 0.4)
		mist.Transparency = NumberSequence.new(0.82, 1)
	end
	effectTrail(anchor, folder, "MotionRibbon", Vector3.new(-radius * 0.7, top, 0), Vector3.new(radius * 0.7, top, 0), effect.color, effect.trail)
	if effect.ribbons then
		for i = -1, 1, 2 do
			local point = Vector3.new(radius * i, middle, 0)
			effectTrail(anchor, folder, "SkateRibbon" .. i, point, point + Vector3.new(0, 0.14, 0), i == -1 and effect.accent or effect.color, 0.3)
		end
	end
	local style = effect.lines
	if style == "orbit" or style == "hazard" then
		local count = style == "orbit" and 16 or 8
		for i = 1, count do
			local a, b = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
			local tilt = style == "orbit" and 0.22 or 0
			local p = Vector3.new(math.cos(a) * radius * 1.3, middle + math.sin(a) * tilt, math.sin(a) * radius * 1.3)
			local q = Vector3.new(math.cos(b) * radius * 1.3, middle + math.sin(b) * tilt, math.sin(b) * radius * 1.3)
			effectLine(anchor, folder, "Ring" .. i, p, q, i % 2 == 0 and effect.color or effect.accent)
		end
	elseif style == "heart" then
		local function point(angle)
			local x = 16 * math.sin(angle) ^ 3
			local y = 13 * math.cos(angle) - 5 * math.cos(2 * angle) - 2 * math.cos(3 * angle) - math.cos(4 * angle)
			return Vector3.new(x / 16 * radius, top * 0.8 + y / 16 * radius, -radius * 1.25)
		end
		for i = 1, 20 do
			effectLine(anchor, folder, "Heart" .. i, point((i - 1) / 20 * math.pi * 2), point(i / 20 * math.pi * 2), effect.accent, 0.028)
		end
	elseif style == "lightning" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 5 do
				local nextPoint = Vector3.new((radius + (i % 2) * 0.1) * side, middle * 0.55 + i * top * 0.09, (i % 2 - 0.5) * 0.2)
				effectLine(anchor, folder, "Arc" .. side .. "_" .. i, previous, nextPoint, effect.accent, 0.028)
				previous = nextPoint
			end
		end
	elseif style == "sun" then
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			effectLine(anchor, folder, "Ray" .. i, Vector3.new(0, top * 0.87, 0) + direction * radius, Vector3.new(0, top * 0.87, 0) + direction * radius * 1.5, effect.accent, 0.04)
		end
	elseif style == "pixels" then
		for i = 1, 4 do
			local center = Vector3.new((i % 2 == 0 and -1 or 1) * radius * 1.3, middle + (i - 2.5) * 0.2, 0)
			local color = i % 2 == 0 and effect.color or effect.accent
			effectLine(anchor, folder, "Pixel" .. i, center, center + Vector3.new(0.07, 0, 0), color, 0.07)
		end
	elseif style == "wave" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 8 do
				local point = Vector3.new((radius + math.sin(i * 0.8) * 0.1) * side, middle * 0.55 + top * i * 0.06, 0)
				effectLine(anchor, folder, "Wave" .. side .. "_" .. i, previous, point, effect.accent, 0.025)
				previous = point
			end
		end
	elseif style == "alloy" then
		for side = -1, 1, 2 do
			effectLine(anchor, folder, "ChromeEdge" .. side, Vector3.new(radius * side, middle, 0), Vector3.new(radius * side * 0.8, top * 0.91, 0), effect.accent, 0.02)
		end
	elseif style == "crown" then
		local previous = Vector3.new(-radius, top * 0.85, -radius)
		for i = 1, 4 do
			local point = Vector3.new(-radius + i * radius * 0.5, top * 0.85 + (i % 2) * 0.15, -radius)
			effectLine(anchor, folder, "Crown" .. i, previous, point, effect.accent, 0.035)
			previous = point
		end
	end
end

function Equipment:_batHitEffect(record)
	if not record.bat or not record.bat.Parent then return end
	for _, emitter in ipairs(record.bat:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter:Emit(emitter:GetAttribute("BatHitBurst") or 6) end
	end
end


local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function participating(player)
	return player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return nil end
	return low, high
end

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Transparency = 1
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weldModel(model, anchor)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			local coatingWeld = child:GetAttribute("PCStudLayer") == true and child:FindFirstChild("StudFinishWeld")
			if not coatingWeld or not coatingWeld:IsA("WeldConstraint") or not coatingWeld.Part0 or not coatingWeld.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticGripWeld"
				weld.Part0 = anchor
				weld.Part1 = child
				weld.Parent = child
			end
		elseif child:IsA("Highlight") then child.Adornee = model end
	end
end

function Equipment.new()
	return setmetatable({ running = false, records = {}, connections = {} }, Equipment)
end

function Equipment:_clearBat(record)
	local model = record.bat
	record.bat = nil
	record.batId = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local gripAttachment = hand:FindFirstChild("RightGripAttachment")
	local handOffset = gripAttachment and gripAttachment:IsA("Attachment") and gripAttachment.Position or Vector3.new(0, -hand.Size.Y * 0.45, 0)
	local target = hand.CFrame * CFrame.new(handOffset) * CFrame.Angles(math.rad(-65), 0, math.rad(-8))
	local carrier = Instance.new("Model")
	carrier.Name = "PCCosmeticBat"
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("GripAnchor")
	anchor.CFrame = target
	anchor.Parent = carrier
	carrier.PrimaryPart = anchor
	visual.Name = "Visual"
	visual:PivotTo(target * CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	self:_attachBatEffects(carrier, anchor, item, size, math.min(size.Y * 0.14, 0.42))
	local handWeld = Instance.new("WeldConstraint")
	handWeld.Name = "RightHandGrip"
	handWeld.Part0 = hand
	handWeld.Part1 = anchor
	handWeld.Parent = anchor
	record.bat = carrier
	record.batId = item.id
	carrier.Parent = record.character
end

function Equipment:_makeGear(record, item, backpack, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local center = (low + high) * 0.5
	local size = high - low
	local grip = Vector3.new(center.X, low.Y + math.min(size.Y * 0.25, 0.45), center.Z + size.Z * 0.2)
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.name .. " · collectible toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = false
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("CosmeticOnly", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) end
	end))
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = typeof(batId) == "string" and Catalog.ById[batId]
	local bulldog = player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog"
	local preview = player:GetAttribute("PCAdminBatPreview") == true and not participating(player)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if (not bulldog and not preview) or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		self:_clearBat(record)
	elseif record.batId ~= bat.id or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset)
	end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	record.humanoid = nil
	local function bindHumanoid(child)
		if child:IsA("Humanoid") and record.humanoid ~= child then
			record.humanoid = child
			table.insert(record.characterConnections, child.Died:Connect(function()
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() else bindHumanoid(child) end
	end
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		bindHumanoid(child)
		if child:IsA("BasePart") or child:IsA("Humanoid") then self:_queue(record) end
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.bat or child:IsA("BasePart") then self:_queue(record) end
	end))
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, closed = false }
	self.records[player] = record
	table.insert(record.connections, player:GetAttributeChangedSignal("BBBatHitSerial"):Connect(function() self:_batHitEffect(record) end))
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "PCAdminBatPreview", "BBRole", "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function() self:_queue(record) end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_queue(record) end
	end))
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then for _, child in ipairs(backpack:GetChildren()) do if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() end end end
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Equipment:Stop()
	self.running = false
	disconnect(self.connections)
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:_removePlayer(player) end
end

return Equipment]====], after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local Equipment = {}
Equipment.__index = Equipment

local sparkTexture = "rbxasset://textures/particles/sparkles_main.dds"
local smokeTexture = "rbxasset://textures/particles/smoke_main.dds"
local fireTexture = "rbxasset://textures/particles/fire_main.dds"
local starTexture = sparkTexture
local heartTexture = smokeTexture

local batEffects = {
	B01 = { name = "Sawdust Swirl", color = Color3.fromRGB(227, 169, 91), accent = Color3.fromRGB(255, 233, 185), texture = smokeTexture, rate = 5, speed = 0.55, size = 0.12, gravity = -0.8, spin = 75, glow = 0, squash = 0.6, trail = 0.12 },
	B02 = { name = "Alloy Glints", color = Color3.fromRGB(186, 231, 255), accent = Color3.new(1, 1, 1), texture = sparkTexture, rate = 3, speed = 0.12, size = 0.23, gravity = 0.1, spin = 15, glow = 0.55, lines = "alloy", trail = 0.14 },
	B03 = { name = "Varsity Confetti", color = Color3.fromRGB(255, 85, 105), accent = Color3.fromRGB(112, 195, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.16, gravity = -2.2, spin = 180, glow = 0, squash = 1.3, secondary = true, trail = 0.15 },
	B04 = { name = "Hazard Beacon", color = Color3.fromRGB(255, 153, 36), accent = Color3.fromRGB(255, 244, 172), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.2, gravity = 0.2, spin = 0, glow = 0.65, lines = "hazard", trail = 0.14 },
	B05 = { name = "Bubblegum Hearts", color = Color3.fromRGB(255, 136, 209), accent = Color3.fromRGB(255, 226, 250), texture = heartTexture, rate = 3, speed = 0.7, size = 0.26, gravity = 0.3, spin = 20, glow = 0.1, secondary = true, lines = "heart", trail = 0.19 },
	B06 = { name = "Muddy Droplets", color = Color3.fromRGB(139, 90, 45), accent = Color3.fromRGB(191, 156, 83), texture = smokeTexture, rate = 6, speed = 0.6, size = 0.22, gravity = -3, spin = 45, glow = 0, squash = 0.3, trail = 0.12 },
	B07 = { name = "Coil Embers", color = Color3.fromRGB(255, 97, 25), accent = Color3.fromRGB(255, 217, 70), texture = fireTexture, rate = 6, speed = 0.65, size = 0.29, gravity = 0.9, spin = 20, glow = 0.75, secondary = true, trail = 0.18 },
	B08 = { name = "Frost Crystals", color = Color3.fromRGB(124, 229, 255), accent = Color3.fromRGB(232, 255, 255), texture = sparkTexture, rate = 4, speed = 0.25, size = 0.24, gravity = -0.3, spin = 40, glow = 0.35, mist = true, trail = 0.22 },
	B09 = { name = "Circuit Arcs", color = Color3.fromRGB(77, 139, 255), accent = Color3.fromRGB(199, 253, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.12, gravity = 0, spin = 120, glow = 0.8, lines = "lightning", trail = 0.12 },
	B10 = { name = "Arcade Pixels", color = Color3.fromRGB(248, 89, 235), accent = Color3.fromRGB(87, 247, 219), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.35, spin = 0, glow = 0.5, squash = -0.4, lines = "pixels", trail = 0.1 },
	B11 = { name = "Orbit Stardust", color = Color3.fromRGB(176, 126, 255), accent = Color3.fromRGB(134, 222, 255), texture = starTexture, rate = 3, speed = 0.3, size = 0.19, gravity = 0.25, spin = 65, glow = 0.6, lines = "orbit", trail = 0.25 },
	B12 = { name = "Champion Stars", color = Color3.fromRGB(255, 213, 64), accent = Color3.fromRGB(255, 247, 180), texture = starTexture, rate = 4, speed = 0.55, size = 0.26, gravity = 0.45, spin = 30, glow = 0.45, lines = "crown", trail = 0.2 },
	B13 = { name = "Skatepark Ribbons", color = Color3.fromRGB(78, 228, 206), accent = Color3.fromRGB(255, 133, 140), texture = sparkTexture, rate = 3, speed = 0.35, size = 0.12, gravity = 0, spin = 80, glow = 0.25, ribbons = true, trail = 0.23 },
	B14 = { name = "Ocean Spray", color = Color3.fromRGB(62, 218, 214), accent = Color3.fromRGB(161, 247, 255), texture = smokeTexture, rate = 5, speed = 0.7, size = 0.19, gravity = 0.6, spin = 35, glow = 0.15, mist = true, lines = "wave", trail = 0.23 },
	B15 = { name = "Sunburst Rays", color = Color3.fromRGB(255, 175, 35), accent = Color3.fromRGB(255, 246, 112), texture = sparkTexture, rate = 5, speed = 0.6, size = 0.16, gravity = 0.45, spin = 60, glow = 0.65, lines = "sun", trail = 0.21 },
}

local function effectAttachment(anchor, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = anchor
	return attachment
end

local function effectEmitter(parent, name, effect, secondary)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = effect.texture
	emitter.Color = ColorSequence.new(secondary and effect.accent or effect.color, effect.accent)
	emitter.Rate = secondary and 2 or effect.rate
	emitter.Lifetime = NumberRange.new(0.45, 0.95)
	emitter.Speed = NumberRange.new(effect.speed * 0.5, effect.speed)
	emitter.Acceleration = Vector3.new(0, effect.gravity, 0)
	emitter.Drag = 1.5
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-effect.spin, effect.spin)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, effect.size * 0.3), NumberSequenceKeypoint.new(0.2, effect.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.15, 0.12), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = effect.glow
	emitter.LightInfluence = 0.2
	emitter.VelocityInheritance = 0.15
	emitter.Squash = NumberSequence.new(effect.squash or 0)
	emitter:SetAttribute("BatHitBurst", secondary and 4 or 8)
	emitter.Parent = parent
	return emitter
end

local function effectLine(anchor, folder, name, first, last, color, width)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = effectAttachment(anchor, name .. "A", first)
	beam.Attachment1 = effectAttachment(anchor, name .. "B", last)
	beam.Width0 = width or 0.035
	beam.Width1 = width or 0.035
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.22)
	beam.LightEmission = 0.65
	beam.LightInfluence = 0.1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = folder
	return beam
end

local function effectTrail(anchor, folder, name, first, last, color, lifetime)
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = effectAttachment(anchor, name .. "A", first)
	trail.Attachment1 = effectAttachment(anchor, name .. "B", last)
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = lifetime
	trail.MinLength = 0.06
	trail.FaceCamera = true
	trail.LightEmission = 0.35
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = folder
end

function Equipment:_attachBatEffects(carrier, anchor, item, sourceSize, gripHeight)
	local effect = batEffects[item.id]
	if not effect then return end
	carrier:SetAttribute("HeldEffect", effect.name)
	local folder = Instance.new("Folder")
	folder.Name = "HeldVFX"
	folder.Parent = carrier
	local top = sourceSize.Y - gripHeight
	local middle = top * 0.68
	local radius = math.clamp(math.max(sourceSize.X, sourceSize.Z) * 0.55, 0.18, 0.48)
	local tip = effectAttachment(anchor, "BatEffectTip", Vector3.new(0, top, 0))
	local barrel = effectAttachment(anchor, "BatEffectBarrel", Vector3.new(0, middle, 0))
	effectEmitter(tip, effect.name, effect, false)
	if effect.secondary then effectEmitter(barrel, effect.name .. "Accent", effect, true) end
	if effect.mist then
		local mist = effectEmitter(barrel, "SoftMist", effect, true)
		mist.Texture = smokeTexture
		mist.Size = NumberSequence.new(0.13, 0.4)
		mist.Transparency = NumberSequence.new(0.82, 1)
	end
	effectTrail(anchor, folder, "MotionRibbon", Vector3.new(-radius * 0.7, top, 0), Vector3.new(radius * 0.7, top, 0), effect.color, effect.trail)
	if effect.ribbons then
		for i = -1, 1, 2 do
			local point = Vector3.new(radius * i, middle, 0)
			effectTrail(anchor, folder, "SkateRibbon" .. i, point, point + Vector3.new(0, 0.14, 0), i == -1 and effect.accent or effect.color, 0.3)
		end
	end
	local style = effect.lines
	if style == "orbit" or style == "hazard" then
		local count = style == "orbit" and 16 or 8
		for i = 1, count do
			local a, b = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
			local tilt = style == "orbit" and 0.22 or 0
			local p = Vector3.new(math.cos(a) * radius * 1.3, middle + math.sin(a) * tilt, math.sin(a) * radius * 1.3)
			local q = Vector3.new(math.cos(b) * radius * 1.3, middle + math.sin(b) * tilt, math.sin(b) * radius * 1.3)
			effectLine(anchor, folder, "Ring" .. i, p, q, i % 2 == 0 and effect.color or effect.accent)
		end
	elseif style == "heart" then
		local function point(angle)
			local x = 16 * math.sin(angle) ^ 3
			local y = 13 * math.cos(angle) - 5 * math.cos(2 * angle) - 2 * math.cos(3 * angle) - math.cos(4 * angle)
			return Vector3.new(x / 16 * radius, top * 0.8 + y / 16 * radius, -radius * 1.25)
		end
		for i = 1, 20 do
			effectLine(anchor, folder, "Heart" .. i, point((i - 1) / 20 * math.pi * 2), point(i / 20 * math.pi * 2), effect.accent, 0.028)
		end
	elseif style == "lightning" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 5 do
				local nextPoint = Vector3.new((radius + (i % 2) * 0.1) * side, middle * 0.55 + i * top * 0.09, (i % 2 - 0.5) * 0.2)
				effectLine(anchor, folder, "Arc" .. side .. "_" .. i, previous, nextPoint, effect.accent, 0.028)
				previous = nextPoint
			end
		end
	elseif style == "sun" then
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			effectLine(anchor, folder, "Ray" .. i, Vector3.new(0, top * 0.87, 0) + direction * radius, Vector3.new(0, top * 0.87, 0) + direction * radius * 1.5, effect.accent, 0.04)
		end
	elseif style == "pixels" then
		for i = 1, 4 do
			local center = Vector3.new((i % 2 == 0 and -1 or 1) * radius * 1.3, middle + (i - 2.5) * 0.2, 0)
			local color = i % 2 == 0 and effect.color or effect.accent
			effectLine(anchor, folder, "Pixel" .. i, center, center + Vector3.new(0.07, 0, 0), color, 0.07)
		end
	elseif style == "wave" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 8 do
				local point = Vector3.new((radius + math.sin(i * 0.8) * 0.1) * side, middle * 0.55 + top * i * 0.06, 0)
				effectLine(anchor, folder, "Wave" .. side .. "_" .. i, previous, point, effect.accent, 0.025)
				previous = point
			end
		end
	elseif style == "alloy" then
		for side = -1, 1, 2 do
			effectLine(anchor, folder, "ChromeEdge" .. side, Vector3.new(radius * side, middle, 0), Vector3.new(radius * side * 0.8, top * 0.91, 0), effect.accent, 0.02)
		end
	elseif style == "crown" then
		local previous = Vector3.new(-radius, top * 0.85, -radius)
		for i = 1, 4 do
			local point = Vector3.new(-radius + i * radius * 0.5, top * 0.85 + (i % 2) * 0.15, -radius)
			effectLine(anchor, folder, "Crown" .. i, previous, point, effect.accent, 0.035)
			previous = point
		end
	end
end

function Equipment:_batHitEffect(record)
	if not record.bat or not record.bat.Parent then return end
	for _, emitter in ipairs(record.bat:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter:Emit(emitter:GetAttribute("BatHitBurst") or 6) end
	end
end


local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function participating(player)
	return player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return nil end
	return low, high
end

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Transparency = 1
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weldModel(model, anchor)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			local coatingWeld = child:GetAttribute("PCStudLayer") == true and child:FindFirstChild("StudFinishWeld")
			if not coatingWeld or not coatingWeld:IsA("WeldConstraint") or not coatingWeld.Part0 or not coatingWeld.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticGripWeld"
				weld.Part0 = anchor
				weld.Part1 = child
				weld.Parent = child
			end
		elseif child:IsA("Highlight") then child.Adornee = model end
	end
end

function Equipment.new(batServices)
	return setmetatable({ running = false, records = {}, connections = {}, batServices = batServices or {} }, Equipment)
end

function Equipment:_weaponGame(player)
	if player:GetAttribute("MDParticipating") == true then return nil end
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then return "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then return "TagYoureIt" end
	end
	return nil
end

function Equipment:_batService(gameId)
	return self.batServices[gameId]
end

function Equipment:_cancelBatHit(record)
	if not record.batGame then return end
	local service = self:_batService(record.batGame)
	if service and service.CancelBatSwing then service:CancelBatSwing(record.player) end
end

function Equipment:_activateBat(record)
	local tool = record.bat
	local gameId = self:_weaponGame(record.player)
	if not tool or not tool.Enabled or tool.Parent ~= record.character or record.player.Character ~= record.character
		or not gameId or record.batGame ~= gameId or record.player:GetAttribute("PCDataReady") ~= true
		or record.player:GetAttribute("BBRagdolled") == true or record.player:GetAttribute("TGRagdolled") == true then return false end
	local service = self:_batService(gameId)
	if not service or not service.TryBatSwing then return false end
	local accepted = service:TryBatSwing(record.player)
	if accepted then
		tool:SetAttribute("BatSwingAt", workspace:GetServerTimeNow())
		task.delay(0.5, function() if not record.closed then self:_queue(record) end end)
	end
	return accepted == true
end

function Equipment:_clearBat(record)
	self:_cancelBatHit(record)
	if record.batConnections then disconnect(record.batConnections) end
	local model = record.bat
	record.bat = nil
	record.batId = nil
	record.batGame = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original, gameId)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local carrier = Instance.new("Tool")
	carrier.Name = item.name
	carrier.ToolTip = "Click / tap to swing"
	carrier.RequiresHandle = true
	carrier.CanBeDropped = false
	carrier.ManualActivationOnly = false
	carrier.Grip = CFrame.identity
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("PCBatWeapon", true)
	carrier:SetAttribute("WeaponGame", gameId)
	carrier:SetAttribute("BatSwingAt", 0)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("Handle")
	anchor.Parent = carrier
	local palm = Instance.new("Attachment")
	palm.Name = "RightGripAttachment"
	palm.CFrame = carrier.Grip
	palm.Parent = anchor
	visual.Name = "Visual"
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	self:_attachBatEffects(carrier, anchor, item, size, math.min(size.Y * 0.14, 0.42))
	record.bat = carrier
	record.batId = item.id
	record.batGame = gameId
	record.batConnections = record.batConnections or {}
	table.insert(record.batConnections, carrier.Activated:Connect(function() self:_activateBat(record) end))
	table.insert(record.batConnections, carrier.Unequipped:Connect(function()
		self:_cancelBatHit(record)
		self:_queue(record)
	end))
	table.insert(record.batConnections, carrier.Destroying:Connect(function() self:_cancelBatHit(record) end))
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	carrier.Parent = record.player:FindFirstChildOfClass("Backpack") or record.character
	if humanoid then humanoid:EquipTool(carrier) end
end

function Equipment:_makeGear(record, item, backpack, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local center = (low + high) * 0.5
	local size = high - low
	local grip = Vector3.new(center.X, low.Y + math.min(size.Y * 0.25, 0.45), center.Z + size.Z * 0.2)
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.name .. " · collectible toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = false
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("CosmeticOnly", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) end
	end))
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = typeof(batId) == "string" and Catalog.ById[batId]
	local gameId = self:_weaponGame(player)
	local ragdolled = player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if not gameId or ragdolled or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		local at = record.bat and record.bat:GetAttribute("BatSwingAt")
		local tagState = ReplicatedStorage:FindFirstChild("TagState")
		local finishing = record.batGame == "TagYoureIt" and player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Runner"
			and not ragdolled and tagState and tagState:GetAttribute("Phase") == "Playing" and typeof(at) == "number" and workspace:GetServerTimeNow() - at < 0.48
		if finishing then record.bat.Enabled = false self:_cancelBatHit(record) else self:_clearBat(record) end
	elseif record.batId ~= bat.id or record.batGame ~= gameId or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset, gameId)
	else
		record.bat.Enabled = true
	end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	record.humanoid = nil
	local function bindHumanoid(child)
		if child:IsA("Humanoid") and record.humanoid ~= child then
			record.humanoid = child
			table.insert(record.characterConnections, child.Died:Connect(function()
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() else bindHumanoid(child) end
	end
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		bindHumanoid(child)
		if child:IsA("BasePart") or child:IsA("Humanoid") then self:_queue(record) end
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.bat or child:IsA("BasePart") then self:_queue(record) end
	end))
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, batConnections = {}, closed = false }
	self.records[player] = record
	table.insert(record.connections, player:GetAttributeChangedSignal("PCBatHitSerial"):Connect(function() self:_batHitEffect(record) end))
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "BBRole", "BBParticipating", "TGRole", "TGParticipating", "MDParticipating", "BBRagdolled", "TGRagdolled" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function() self:_queue(record) end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_queue(record) end
	end))
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then for _, child in ipairs(backpack:GetChildren()) do if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() end end end
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	for _, name in ipairs({ "BritishBulldogState", "TagState" }) do
		local state = ReplicatedStorage:FindFirstChild(name)
		if state then table.insert(self.connections, state:GetAttributeChangedSignal("Phase"):Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end)) end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Equipment:Stop()
	self.running = false
	disconnect(self.connections)
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:_removePlayer(player) end
end

return Equipment]====]},
{path="ServerScriptService.StuckInTheMudService", before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local COLOR_NAMES = { "Red", "Blue", "Green", "Black", "Yellow", "Purple", "Orange", "Teal", "Pink", "Lime", "Lavender", "Brown" }
local TEAM_COLORS = { Red = COLORS.Tagger, Blue = COLORS.Runner, Green = Color3.fromRGB(90, 210, 114), Black = Color3.fromRGB(44, 49, 64), Yellow = Color3.fromRGB(255, 201, 72), Purple = Color3.fromRGB(174, 98, 229), Orange = Color3.fromRGB(255, 156, 77), Teal = Color3.fromRGB(85, 220, 202), Pink = Color3.fromRGB(234, 144, 204), Lime = Color3.fromRGB(179, 215, 91), Lavender = Color3.fromRGB(150, 158, 246), Brown = Color3.fromRGB(166, 111, 77) }
local PREFERENCE_COLORS = { Red = true, Blue = true, Green = true, Black = true }

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end
local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function parts(folder)
	local result = {}
	if folder then for _, child in ipairs(folder:GetChildren()) do if child:IsA("BasePart") then table.insert(result, child) end end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end
local function alive(record)
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end
local function direction(value)
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z
		or math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge or math.abs(value.Z) == math.huge
		or value.Magnitude < 0.01 or value.Magnitude > 10000 then return nil end
	return value.Unit
end
local function connectedPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spawnPads = parts(self.gameplay:WaitForChild("StartPads"))
	self.navNodes = parts(self.gameplay:FindFirstChild("NavigationNodes"))
	self.teamSpawns = {}
	local groups = self.gameplay:FindFirstChild("TeamSpawns")
	if groups then
		for _, group in ipairs(groups:GetChildren()) do if group:IsA("Folder") then table.insert(self.teamSpawns, group) end end
		table.sort(self.teamSpawns, function(a, b) return a.Name < b.Name end)
	end
	assert(#self.spawnPads > 0, "Mud needs StartPads")
	self.records, self.connections, self.projectiles, self.eliminatedTeams = {}, {}, {}, {}
	self.teamColors, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.endsAt, self.roundNumber, self.tickAccumulator, self.teamCount = 0, 0, 0, 2
	self.state = state or ReplicatedStorage:FindFirstChild("MudState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name = "MudState" self.state.Parent = ReplicatedStorage end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") and not object:IsDescendantOf(arena) then self.lobbySpawn = object break end
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

function Service.TeamAssignments(count, requested, maximum)
	if count < 2 then return {}, 0 end
	local teamCount = math.clamp(math.max(math.floor(requested), math.ceil(count / math.max(2, math.floor(maximum)))), 2, math.min(count, #COLOR_NAMES))
	local result = {}
	for index = 1, count do result[index] = (index - 1) % teamCount + 1 end
	return result, teamCount
end

function Service:_chooseTeamColors()
	local used = {}
	self.teamColors = {}
	for team = 1, self.teamCount do
		local counts = {}
		for _, record in pairs(self.records) do
			if record.participating and record.teamId == team then
				local preference = record.player:GetAttribute("MDColorPreference")
				if PREFERENCE_COLORS[preference] then counts[preference] = (counts[preference] or 0) + 1 end
			end
		end
		local choice, votes
		for _, name in ipairs(COLOR_NAMES) do
			if not used[name] and (not votes or (counts[name] or 0) > votes) then choice, votes = name, counts[name] or 0 end
		end
		self.teamColors[team], used[choice] = choice, true
	end
end

function Service:_colorName(team)
	return self.teamColors[team] or COLOR_NAMES[(math.max(team or 1, 1) - 1) % #COLOR_NAMES + 1]
end

function Service.ChooseTimeoutTeams(active, free, original)
	local best, winners = -1, {}
	for _, team in ipairs(active) do
		local amount = free[team] or 0
		if amount > 0 then
			local score = amount / math.max(original[team] or 0, 1)
			if score > best + 0.000001 then best, winners = score, { team }
			elseif math.abs(score - best) <= 0.000001 then table.insert(winners, team) end
		end
	end
	table.sort(winners)
	return winners
end

function Service:_timeoutWinners()
	local active, _, free = self:_teams(true)
	return Service.ChooseTimeoutTeams(active, free, self.originalTeamSizes)
end

function Service:_spawn(index, team)
	team = typeof(team) == "number" and team or 1
	local pads = self.spawnPads
	if #self.teamSpawns > 0 then
		local groupIndex = math.floor((team - 1) * #self.teamSpawns / math.max(self.teamCount, 1)) + 1
		local choices = parts(self.teamSpawns[math.clamp(groupIndex, 1, #self.teamSpawns)])
		if #choices > 0 then pads = choices end
	end
	local position = pads[(index - 1) % #pads + 1].Position
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_clearHeat(record, true)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_publishRecord(record)
	attribute(record.player, "MDParticipating", record.participating)
	attribute(record.player, "MDTeamId", record.teamId or 0)
	local colorName = record.participating and self:_colorName(record.teamId) or ""
	attribute(record.player, "MDTeamColorName", colorName)
	attribute(record.player, "MDTeamColor", TEAM_COLORS[colorName] or Color3.fromRGB(255, 255, 255))
	attribute(record.player, "MDTeamName", colorName ~= "" and colorName .. " Team" or "")
	attribute(record.player, "MDMuddy", record.muddy == true)
	attribute(record.player, "MDEliminated", record.eliminated == true)
	attribute(record.player, "MDRescueProgress", record.rescueProgress or 0)
	attribute(record.player, "MDSprintMax", record.sprintMax or 0)
	attribute(record.player, "MDSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	attribute(record.player, "MDSprinting", record.sprinting == true)
	attribute(record.player, "MDSprintExhausted", record.sprintExhausted == true)
	attribute(record.player, "MDFireReadyAt", record.fireReadyAt or 0)
	attribute(record.player, "MDHeatActive", record.heatTarget ~= nil)
	attribute(record.player, "MDHeatTargetUserId", record.heatTarget and (record.heatTarget.player.UserId or 0) or 0)
	attribute(record.player, "MDHeatProgress", record.heatProgress or 0)
	local tool = record.participating and record.character and record.character:FindFirstChildOfClass("Tool")
	attribute(record.player, "MDTool", tool and tool:GetAttribute("MDManaged") and tool.Name or "")
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_mudVisual(record)
	local coating = record.character:FindFirstChild("MDMudCoating")
	if not record.muddy then if coating then coating:Destroy() end return end
	if coating then return end
	coating = Instance.new("Folder") coating.Name = "MDMudCoating" coating.Parent = record.character
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = record.character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			local patch = Instance.new("Part") patch.Name = name == "Head" and "MudFaceMask" or "MudPatch"
			patch.Shape = Enum.PartType.Ball
			patch.Size = Vector3.new(math.max(0.3, body.Size.X * (name == "Head" and 0.75 or 0.7)), math.max(0.2, body.Size.Y * (name == "Head" and 0.3 or 0.37)), 0.18)
			patch.CFrame = body.CFrame * CFrame.new(name == "Head" and 0 or body.Size.X * (index % 2 == 0 and 0.1 or -0.1), body.Size.Y * (name == "Head" and -0.22 or -0.08), -body.Size.Z / 2 - 0.015)
			patch.Material = Enum.Material.SmoothPlastic patch.Color = index % 2 == 0 and Color3.fromRGB(114, 73, 43) or Color3.fromRGB(143, 95, 59)
			patch.Anchored, patch.Massless, patch.CanCollide, patch.CanTouch, patch.CanQuery = false, true, false, false, false
			patch.Parent = coating
			local weld = Instance.new("WeldConstraint") weld.Name = "MudWeld" weld.Part0, weld.Part1 = body, patch weld.Parent = patch
		end
	end
end

function Service:_role(record)
	self:_publishRecord(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("MDOutline")
		if not outline then
			outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Adornee = record.character
			outline.FillTransparency = 1 outline.OutlineTransparency = 0 outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = record.character
		end
		outline.OutlineColor = TEAM_COLORS[self:_colorName(record.teamId)]
		outline.FillColor = Color3.fromRGB(124, 83, 54)
		outline.FillTransparency = record.muddy and 0.55 or 1
		self:_mudVisual(record)
		local label = record.character:FindFirstChild("MDMuddyLabel")
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local template = assets and assets:FindFirstChild("MuddyTemplate")
		if record.muddy and not label and template then label = template:Clone() label.Name = "MDMuddyLabel" label.Adornee = record.character:FindFirstChild("Head") or record.root label.Enabled = true label.Parent = record.character
		elseif not record.muddy and label then label:Destroy() end
		local torso = record.isBot and record.character:FindFirstChild("Torso")
		if torso then torso.Color = record.muddy and Color3.fromRGB(124, 83, 54) or outline.OutlineColor end
	end
end

function Service:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_freeze(record, frozen)
	record.frozen = frozen
	if frozen then record.sprintHeld = false record.sprinting = false self:_clearHeat(record, true) else record.lockedCFrame = nil end
	self:_movement(record)
end

function Service:_destroyTools(record)
	if record.isBot then return end
	for _, tool in ipairs(record.managedTools or {}) do if tool.Parent then tool:Destroy() end end
	record.managedTools = {}
end

function Service:_giveTools(record)
	if record.isBot or not alive(record) then return end
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	self:_destroyTools(record)
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone() tool:SetAttribute("MDManaged", true) tool:SetAttribute("MDRound", self.roundNumber) tool.Parent = backpack
			table.insert(record.managedTools, tool)
			if name == "MudGun" then first = tool end
		end
	end
	if first then record.humanoid:EquipTool(first) end
end

function Service:_restore(record)
	self:_clearHeat(record, true)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
		spawnIndex = 1, rescueProgress = 0, sprintMax = 0, sprintRemaining = 0, fireReadyAt = 0, requests = {}, managedTools = {} }
	self.records[player] = record self:_publishRecord(record)
	return record
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then return end
	record.generation = (record.generation or 0) + 1
	local generation = record.generation
	disconnect(record.characterConnections) self:_restore(record)
	record.character, record.root, record.humanoid, record.ready = character, nil, nil, false
	local humanoid, root = character:WaitForChild("Humanoid", 10), character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.generation ~= generation or record.player.Character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(part) self:_collision(record, part) end))
	table.insert(record.characterConnections, humanoid.Died:Connect(function() if record.participating then self:_stick(record, nil) record.ready = false end end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character) if record.character == character then if record.participating then self:_stick(record, nil) end record.ready = false end end))
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player] if not record then return end
	record.participating = false self:_restore(record) disconnect(record.connections) disconnect(record.characterConnections) self.records[player] = nil
	if self.practiceOwner == player then self:StopRound() else self:_teams(true) end
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") then included[player] = true table.insert(result, player) end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_teams(mark)
	local totals, free = {}, {}
	for _, record in pairs(self.records) do
		if record.participating and (record.isBot or record.player.Parent == Players) then totals[record.teamId] = (totals[record.teamId] or 0) + 1 if not record.muddy and not record.eliminated then free[record.teamId] = (free[record.teamId] or 0) + 1 end end
	end
	if mark and self.phase == "Playing" and self.pendingWinners == nil then
		for team = 1, self.teamCount do
			if not free[team] and not self.eliminatedTeams[team] then
				self.eliminatedTeams[team] = true
				for _, record in pairs(self.records) do if record.participating and record.teamId == team then record.eliminated = true self:_freeze(record, true) self:_role(record) end end
			end
		end
	end
	local active = {}
	for team, amount in pairs(free) do if amount > 0 and not self.eliminatedTeams[team] then table.insert(active, team) end end
	table.sort(active)
	if mark and self.active and self.phase == "Playing" and self.pendingWinners == nil and #active <= 1 then
		self.pendingWinners = table.clone(active)
		for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) end end
	end
	attribute(self.state, "ActiveTeamCount", #active)
	attribute(self.state, "TeamCount", self.teamCount)
	local participants, muddy = 0, 0
	local summary = {}
	for team = 1, self.teamCount do
		participants += totals[team] or 0 muddy += (totals[team] or 0) - (free[team] or 0)
		attribute(self.state, "Team" .. team .. "Members", totals[team] or 0) attribute(self.state, "Team" .. team .. "Free", free[team] or 0)
		table.insert(summary, { teamId = team, colorName = self:_colorName(team), free = free[team] or 0, total = totals[team] or 0, originalTotal = self.originalTeamSizes[team] or 0, eliminated = self.eliminatedTeams[team] == true })
	end
	attribute(self.state, "TeamSummaryJSON", HttpService:JSONEncode(summary))
	attribute(self.state, "ParticipantCount", participants) attribute(self.state, "MuddyCount", muddy)
	return active, totals, free
end

function Service:_stick(record, shooter)
	if not self.active or self.phase ~= "Playing" or self.pendingWinners ~= nil or not record.participating or record.eliminated or (shooter and shooter.teamId == record.teamId) then return false end
	for _, saver in pairs(self.records) do if saver.heatTarget == record then self:_clearHeat(saver, false) end end
	record.muddy, record.rescueProgress = true, 0
	self:_freeze(record, true) self:_role(record) self:_teams(true)
	return true
end

function Service:_clearHeat(record, release)
	if record.heatTarget then record.heatTarget.rescueProgress = 0 attribute(record.heatTarget.player, "MDRescueProgress", 0) end
	record.heatTarget, record.heatStartedAt, record.heatProgress = nil, nil, 0
	if record.player then attribute(record.player, "MDHeatProgress", 0) attribute(record.player, "MDHeatActive", false) attribute(record.player, "MDHeatTargetUserId", 0) end
	if record.heatBeam then record.heatBeam:Destroy() record.heatBeam = nil end
	if release then record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = false, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
	return nil
end

function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
	if self.effects then table.insert(ignored, self.effects) end
	if source and source.character then table.insert(ignored, source.character) end
	if ignoreCharacters or not source then for _, record in pairs(self.records) do if record.character then table.insert(ignored, record.character) end end end
	local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances = ignored params.RespectCanCollide = ignoreCharacters == true or source == nil
	return params
end

function Service:_origin(record, kind, aim)
	local tool = self:_equipped(record, kind)
	if not tool then return nil end
	local origin = (record.character:FindFirstChild("Head") or record.root).Position + aim * 1.5
	if not record.isBot then
		local handle = tool:FindFirstChild("Handle") local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
		if not muzzle or not muzzle:IsA("Attachment") or (muzzle.WorldPosition - record.root.Position).Magnitude > 8 then return nil end
		origin = muzzle.WorldPosition
	end
	if workspace:Raycast(record.root.Position, origin - record.root.Position, self:_rayParameters(record, true)) then return nil end
	return origin
end

function Service:_hitRecord(part)
	for _, record in pairs(self.records) do if record.participating and record.character and part:IsDescendantOf(record.character) then return record end end
	return nil
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local origin = self:_origin(record, "Mud", aim) if not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = aim, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
	record.fireReadyAt = now + self:_setting("MudCooldownSeconds", 0.65, 0.1) self:_publishRecord(record)
	return true
end

function Service:_tickProjectiles(dt)
	for index = #self.projectiles, 1, -1 do
		local shot = self.projectiles[index]
		local remove = shot.token ~= self.currentRound or self.phase ~= "Playing" or not self.active or self.pendingWinners ~= nil
		if not remove then
			local length = math.min(shot.remaining, shot.speed * dt)
			local vector = shot.direction * length
			local hit = workspace:Raycast(shot.position, vector, self:_rayParameters(shot.source, false))
			if hit then local target = self:_hitRecord(hit.Instance) if target and target.teamId ~= shot.teamId then self:_stick(target, shot.source) end remove = true
			else shot.position += vector shot.remaining -= length shot.part.Position = shot.position remove = shot.remaining <= 0 end
		end
		if remove then shot.part:Destroy() table.remove(self.projectiles, index) end
	end
end

function Service:_heatTarget(record, now)
	if not self:_canAct(record, now) or not record.heatHeld or now >= (record.heatLeaseEndsAt or 0) or not record.heatDirection then return nil end
	local origin = self:_origin(record, "Heat", record.heatDirection) if not origin then return nil end
	local hit = workspace:Raycast(origin, record.heatDirection * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
	local target = hit and self:_hitRecord(hit.Instance)
	if not target or target == record or target.teamId ~= record.teamId or not target.muddy or target.eliminated or not alive(target) then return nil end
	if (target.root.Position - record.root.Position).Magnitude > self:_setting("HeatRange", 24, 1) + 2 then return nil end
	return target, origin, hit.Position
end

function Service:_tickHeat(now)
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = 0 end end
	local progress = {}
	for _, saver in pairs(self.records) do
		local target, origin, finish = self:_heatTarget(saver, now)
		if not target then self:_clearHeat(saver, false)
		else
			if saver.heatTarget ~= target then self:_clearHeat(saver, false) saver.heatTarget, saver.heatStartedAt = target, now end
			local elapsed = math.max(0, now - saver.heatStartedAt)
			saver.heatProgress = math.min(self:_setting("RescueSeconds", 5, 0.1), elapsed)
			progress[target] = math.max(progress[target] or 0, saver.heatProgress)
			if not saver.heatBeam then local beam = Instance.new("Part") beam.Name = "HeatBeam" beam.Anchored = true beam.CanCollide = false beam.CanTouch = false beam.CanQuery = false beam.Material = Enum.Material.Neon beam.Color = Color3.fromRGB(255, 184, 71) beam.Parent = self:_effects() saver.heatBeam = beam end
			saver.heatBeam.Size = Vector3.new(0.3, 0.3, (finish - origin).Magnitude) saver.heatBeam.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
			if elapsed >= self:_setting("RescueSeconds", 5, 0.1) then target.muddy, target.rescueProgress = false, 0 self:_freeze(target, false) self:_role(target) self:_clearHeat(saver, false) end
		end
	end
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = record.muddy and (progress[record] or 0) or 0 self:_publishRecord(record) end end
end

function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt) if record.sprintRemaining == 0 then record.sprintExhausted, record.sprinting = true, false end
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) if record.sprintRemaining >= record.sprintMax - 0.0001 then record.sprintRemaining, record.sprintExhausted = record.sprintMax, false end end
	self:_movement(record) self:_publishRecord(record)
end

function Service:_action(record, action, value, aim)
	local player = record.player
	if action == "ChooseColor" then
		if typeof(value) ~= "string" or not PREFERENCE_COLORS[value] then return { ok = false, message = "Choose Red, Blue, Green or Black." } end
		local now = workspace:GetServerTimeNow()
		if now - (record.requests.ChooseColor or -math.huge) < 0.2 then return { ok = false, message = "Slow down." } end
		record.requests.ChooseColor = now
		attribute(player, "MDColorPreference", value)
		if record.participating and self.phase == "Countdown" then
			for team, name in pairs(self.teamColors) do if team ~= record.teamId and name == value then return { ok = true, message = "Saved for the next round; that team color is in use." } end end
			self.teamColors[record.teamId] = value
			for _, teammate in pairs(self.records) do if teammate.participating and teammate.teamId == record.teamId then self:_role(teammate) end end
			self:_teams(false)
		end
		return { ok = true, message = "Color preference saved." }
	end
	if action == "Sprint" and value == false then record.sprintHeld, record.sprinting = false, false if record.participating then self:_movement(record) end self:_publishRecord(record) return { ok = true } end
	if action == "Heat" and value == false then self:_clearHeat(record, true) self:_publishRecord(record) return { ok = true } end
	if typeof(action) ~= "string" or (action ~= "Sprint" and action ~= "Fire" and action ~= "Heat") then return { ok = false, message = "Unknown action." } end
	local now = workspace:GetServerTimeNow()
	if now - (record.requests[action] or -math.huge) < 0.08 then return { ok = false, message = "Slow down." } end
	record.requests[action] = now
	if not self:_canAct(record, now) then return { ok = false, message = "Wait until you can move." } end
	if action == "Sprint" then if value ~= true then return { ok = false, message = "Invalid sprint." } end record.sprintHeld, record.sprintLeaseEndsAt = true, now + 1 self:_movement(record) return { ok = true } end
	local unit = direction(action == "Fire" and value or aim)
	if not unit then return { ok = false, message = "Aim toward the playground." } end
	if action == "Fire" then return { ok = self:_fire(record, unit, now), message = "Mud shot." } end
	if value ~= true or not self:_origin(record, "Heat", unit) then return { ok = false, message = "Equip the Heat Gun." } end
	record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = true, unit, now + 1
	return { ok = true }
end

function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position) local half = self.bounds.Size / 2
	local floor = self:_setting("FloorY", self.spawnPads[1].Position.Y - 3.5, -10000)
	if math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3 or record.root.Position.Y < floor - 7 or math.abs(point.Y) > half.Y then self:_stick(record, nil) self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then record.lastGoodCFrame = record.root.CFrame end
end

function Service:_newBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "MudPracticeBots"
		self.botFolder:SetAttribute("MudManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Tagger" and "Practice Rival" or "Practice Teammate " .. tostring(index), UserId = -index }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value) attributes[name] = value end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("MDPracticeBot", true)
	local spawn = self:_spawn(index + 1, role == "Tagger" and 2 or 1)
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
	humanoid.WalkSpeed = self:_setting("BaseSpeed", 16, 0)
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
	record.spawnIndex = index + 1
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
	record.frozen = record.muddy or record.eliminated or self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_freeze(record, record.frozen)
	self:_role(record)
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

function Service:_botTarget(bot)
	local teammate, teammateDistance, opponent, opponentDistance
	for _, candidate in pairs(self.records) do
		if candidate ~= bot and candidate.participating and not candidate.eliminated and alive(candidate) then
			local distance = (candidate.root.Position - bot.root.Position).Magnitude
			if candidate.teamId == bot.teamId and candidate.muddy and (not teammateDistance or distance < teammateDistance) then teammate, teammateDistance = candidate, distance
			elseif candidate.teamId ~= bot.teamId and not candidate.muddy and (not opponentDistance or distance < opponentDistance) then opponent, opponentDistance = candidate, distance end
		end
	end
	if teammate then return teammate, true, teammateDistance end
	return opponent, false, opponentDistance
end

function Service:_moveBot(bot, goal, now)
	local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
	local destination = goal
	if not direct then
		self:_path(bot, goal, now)
		local route, index = bot.route, bot.routeIndex or 1
		while route and route[index] and (route[index].Position - bot.root.Position).Magnitude < 4 do index += 1 end
		bot.routeIndex = index
		local waypoint = route and route[index]
		if waypoint then destination = waypoint.Position if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
		else destination = bot.root.Position end
	end
	if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 5 then
		bot.stuckSince += 0.2
		if bot.stuckSince > 0.8 then bot.humanoid.Jump = true bot.nextPathAt = 0 end
	else bot.stuckSince = 0 end
	bot.previousBotPosition = bot.root.Position
	bot.humanoid:MoveTo(destination)
end

function Service:_driveBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and self:_canAct(bot, now) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target, rescue, distance = self:_botTarget(bot)
			if target then
				local goal = target.root.Position
				local head = bot.character:FindFirstChild("Head") or bot.root
				local aim = direction(goal - head.Position)
				local heating = false
				if rescue and aim and distance <= self:_setting("HeatRange", 24, 1) - 2 then
					bot.heatHeld, bot.heatDirection, bot.heatLeaseEndsAt = true, aim, now + 1
					heating = self:_heatTarget(bot, now) == target
				end
				if not heating then self:_clearHeat(bot, true) end
				if heating then bot.humanoid:MoveTo(bot.root.Position)
				else
					local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
					if not rescue and direct and distance < math.min(self:_setting("MudRange", 130, 1) - 10, 80) then
						bot.humanoid:MoveTo(bot.root.Position)
						local interval = self:_setting("BotShotIntervalSeconds", 7, 0.2)
						bot.nextBotShotAt = bot.nextBotShotAt or now + interval * (0.6 + bot.spawnIndex * 0.3)
						if now >= bot.nextBotShotAt then
							local lead = math.min(distance / self:_setting("ProjectileSpeed", 115, 1), 1)
							local predicted = goal + target.root.AssemblyLinearVelocity * lead
							local shotDirection = direction(predicted - head.Position)
							if shotDirection then self:_fire(bot, shotDirection, now) end
							bot.nextBotShotAt = now + interval
						end
					else self:_moveBot(bot, goal, now) end
				end
			else self:_clearHeat(bot, true) bot.humanoid:MoveTo(bot.root.Position) end
		end
	end
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_stick(record, nil) self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
		self:_tickSprint(record, dt, now)
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now) self:_tickProjectiles(dt) self:_tickHeat(now) self:_teams(true)
end

function Service:_valid(token) return self.running and self.active and self.currentRound == token end

function Service:_results(token, winners, reason)
	local winnerSet, winnerIds, participantIds, names = {}, {}, {}, {}
	for _, id in ipairs(winners) do winnerSet[id] = true end
	for _, entry in ipairs(self.roundRoster) do if not entry.isBot then table.insert(participantIds, entry.userId) if winnerSet[entry.teamId] then table.insert(winnerIds, entry.userId) end end end
	for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) local won = winnerSet[record.teamId] == true attribute(record.player, "MDResult", won and "Won" or "Lost") if won then table.insert(names, record.player.DisplayName) end end end
	for _, shot in ipairs(self.projectiles) do shot.part:Destroy() end table.clear(self.projectiles)
	table.sort(winnerIds) table.sort(participantIds) table.sort(names)
	attribute(self.state, "WinnerTeamIds", table.concat(winners, ",")) attribute(self.state, "WinnerTeams", table.concat(winners, ",")) attribute(self.state, "WinnersText", table.concat(names, ", ")) attribute(self.state, "ResultReason", reason)
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ",")) attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ",")) attribute(self.state, "LastResultPractice", self.mode ~= "Round") attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber += 1 self.eliminatedTeams, self.originalTeamSizes, self.roundRoster, self.pendingWinners = {}, {}, {}, nil
	attribute(self.state, "RoundNumber", self.roundNumber) attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 1)) attribute(self.state, "RescueSeconds", self:_setting("RescueSeconds", 5, 0.1)) attribute(self.state, "WinnersText", "") attribute(self.state, "WinnerTeams", "") attribute(self.state, "WinnerTeamIds", "") attribute(self.state, "ResultReason", "")
	local assignments
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants, self:_setting("TeamCount", 2, 2), self:_setting("MaxTeamSize", 2, 2)) end
	local slots = {}
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating, record.teamId, record.muddy, record.eliminated = true, assignments[index], false, false slots[record.teamId] = (slots[record.teamId] or 0) + 1 record.spawnIndex = slots[record.teamId]
			self.originalTeamSizes[record.teamId] = (self.originalTeamSizes[record.teamId] or 0) + 1
			table.insert(self.roundRoster, { userId = player.UserId, teamId = record.teamId, isBot = record.isBot })
			record.sprintMax = self:_setting("SprintSeconds", 10, 0.1) record.sprintRemaining = record.sprintMax record.sprintExhausted, record.sprintHeld, record.fireReadyAt = false, false, 0
			record.rescueProgress, record.lastGoodCFrame, record.requests, record.nextBotShotAt = 0, nil, {}, nil attribute(player, "MDResult", "")
			local spawn = self:_spawn(record.spawnIndex, record.teamId)
			local practice = token.teams and parts(self.gameplay:FindFirstChild("PracticeSpawns"))
			if practice and #practice > 0 then spawn = practice[(index - 1) % #practice + 1].CFrame elseif token.teams then spawn = CFrame.new(self.bounds.Position.X + (record.teamId == 1 and -22 or 22), self.spawnPads[1].Position.Y, self.bounds.Position.Z + (record.spawnIndex - 1) * 17) end
			self:_teleport(record, spawn) self:_freeze(record, true) self:_giveTools(record) self:_role(record)
		end
	end
	self:_chooseTeamColors()
	for _, record in pairs(self.records) do if record.participating then self:_role(record) end end
	self:_teams(false) self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do if not self:_valid(token) then return end attribute(self.state, "CountdownValue", number) local untilTime = workspace:GetServerTimeNow() + 1 while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end end
	if not self:_valid(token) then return end
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 300, 1) attribute(self.state, "EndsAt", self.endsAt) attribute(self.state, "CountdownValue", 0) self:_phase("Playing")
	for _, record in pairs(self.records) do if record.participating and self.pendingWinners == nil then if not alive(record) or (record.isBot and record.practiceMedic and self.mode == "PracticeMedic") then self:_stick(record, nil) else self:_freeze(record, false) end end end
	local active = self:_teams(true)
	while self:_valid(token) and self.pendingWinners == nil and workspace:GetServerTimeNow() < self.endsAt do task.wait(0.05) active = self:_teams(true) end
	if self:_valid(token) then
		local reason
		if self.pendingWinners then active = self.pendingWinners reason = #active == 0 and "NoActiveTeams" or "LastTeamStanding"
		else active = self:_timeoutWinners() reason = #active > 1 and "TimeoutShared" or #active == 0 and "NoActiveTeams" or "Timeout" end
		self:_results(token, active, reason) self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, teams, owner)
	self.active, self.mode, self.practiceOwner = true, mode, owner
	local token = { teams = teams } self.currentRound = token
	attribute(self.state, "Mode", mode) attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function() local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback) if not ok then warn("Stuck in the Mud round failed: " .. tostring(failure)) self:_cleanup(token) end end)
	return true
end

function Service:_weaponsReady()
	local ok, ready = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local mud = assets and assets:FindFirstChild("MudGun")
		local heat = assets and assets:FindFirstChild("HeatGun")
		if not mud or not heat or not mud:IsA("Tool") or not heat:IsA("Tool") then return false end
		local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled
		return mudEnabled == true and heatEnabled == true
	end)
	return ok and ready == true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	local participants = self:_readyPlayers(selected)
	local minimum = math.clamp(math.floor(self:_setting("MinimumPlayers", 4, 2)), 2, 24)
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 4, 2)), 2, 24)
	if #participants < minimum or maximum < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
	while #participants > maximum do table.remove(participants) end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	if role ~= "Runner" and role ~= "Tagger" and role ~= "Shooter" and role ~= "Medic" then return false, "Choose Shooter or Medic practice" end
	local record = self.records[player] if not connectedPlayer(player) or not record or record.isBot or not alive(record) or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return false, "Your character is not ready" end
	local participants, teams = { player }, { 1 }
	local ok, failure = xpcall(function() for index = 1, 3 do local bot = self:_newBot(index, index == 1 and "Runner" or "Tagger") table.insert(participants, bot) table.insert(teams, index == 1 and 1 or 2) self.records[bot].practiceMedic = index == 1 end end, debug.traceback)
	if not ok then self:_clearBots() warn(tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, teams, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end self.currentRound = nil self:_cleanup() return true
end

function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, RescueSeconds = 5, ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 self:_tick(math.min(elapsed, 0.25)) end end))
	for _, value in ipairs(Players:GetPlayers()) do self:_addPlayer(value) end
	local remote = ReplicatedStorage:FindFirstChild("MudActionRequest") if remote and remote:IsA("RemoteFunction") then self.remote = remote remote.OnServerInvoke = function(value, action, argument, aim) return self:Action(value, action, argument, aim) end end
end

function Service:Stop()
	self.running, self.currentRound = false, nil disconnect(self.connections) self:_cleanup()
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end table.clear(self.records)
	if self.remote then self.remote.OnServerInvoke = nil end if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end

return Service]====], after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local COLOR_NAMES = { "Red", "Blue", "Green", "Black", "Yellow", "Purple", "Orange", "Teal", "Pink", "Lime", "Lavender", "Brown" }
local TEAM_COLORS = { Red = COLORS.Tagger, Blue = COLORS.Runner, Green = Color3.fromRGB(90, 210, 114), Black = Color3.fromRGB(44, 49, 64), Yellow = Color3.fromRGB(255, 201, 72), Purple = Color3.fromRGB(174, 98, 229), Orange = Color3.fromRGB(255, 156, 77), Teal = Color3.fromRGB(85, 220, 202), Pink = Color3.fromRGB(234, 144, 204), Lime = Color3.fromRGB(179, 215, 91), Lavender = Color3.fromRGB(150, 158, 246), Brown = Color3.fromRGB(166, 111, 77) }
local PREFERENCE_COLORS = { Red = true, Blue = true, Green = true, Black = true }

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end
local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function parts(folder)
	local result = {}
	if folder then for _, child in ipairs(folder:GetChildren()) do if child:IsA("BasePart") then table.insert(result, child) end end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end
local function alive(record)
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end
local function direction(value)
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z
		or math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge or math.abs(value.Z) == math.huge
		or value.Magnitude < 0.01 or value.Magnitude > 10000 then return nil end
	return value.Unit
end
local function connectedPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player") and value.Parent == Players
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.spawnPads = parts(self.gameplay:WaitForChild("StartPads"))
	self.navNodes = parts(self.gameplay:FindFirstChild("NavigationNodes"))
	self.teamSpawns = {}
	local groups = self.gameplay:FindFirstChild("TeamSpawns")
	if groups then
		for _, group in ipairs(groups:GetChildren()) do if group:IsA("Folder") then table.insert(self.teamSpawns, group) end end
		table.sort(self.teamSpawns, function(a, b) return a.Name < b.Name end)
	end
	assert(#self.spawnPads > 0, "Mud needs StartPads")
	self.records, self.connections, self.projectiles, self.eliminatedTeams = {}, {}, {}, {}
	self.teamColors, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.endsAt, self.roundNumber, self.tickAccumulator, self.teamCount = 0, 0, 0, 2
	self.state = state or ReplicatedStorage:FindFirstChild("MudState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name = "MudState" self.state.Parent = ReplicatedStorage end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("SpawnLocation") and not object:IsDescendantOf(arena) then self.lobbySpawn = object break end
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

function Service.TeamAssignments(count, requested, maximum)
	if count < 2 then return {}, 0 end
	local teamCount = math.clamp(math.max(math.floor(requested), math.ceil(count / math.max(2, math.floor(maximum)))), 2, math.min(count, #COLOR_NAMES))
	local result = {}
	for index = 1, count do result[index] = (index - 1) % teamCount + 1 end
	return result, teamCount
end

function Service:_chooseTeamColors()
	local used = {}
	self.teamColors = {}
	for team = 1, self.teamCount do
		local counts = {}
		for _, record in pairs(self.records) do
			if record.participating and record.teamId == team then
				local preference = record.player:GetAttribute("MDColorPreference")
				if PREFERENCE_COLORS[preference] then counts[preference] = (counts[preference] or 0) + 1 end
			end
		end
		local choice, votes
		for _, name in ipairs(COLOR_NAMES) do
			if not used[name] and (not votes or (counts[name] or 0) > votes) then choice, votes = name, counts[name] or 0 end
		end
		self.teamColors[team], used[choice] = choice, true
	end
end

function Service:_colorName(team)
	return self.teamColors[team] or COLOR_NAMES[(math.max(team or 1, 1) - 1) % #COLOR_NAMES + 1]
end

function Service.ChooseTimeoutTeams(active, free, original)
	local best, winners = -1, {}
	for _, team in ipairs(active) do
		local amount = free[team] or 0
		if amount > 0 then
			local score = amount / math.max(original[team] or 0, 1)
			if score > best + 0.000001 then best, winners = score, { team }
			elseif math.abs(score - best) <= 0.000001 then table.insert(winners, team) end
		end
	end
	table.sort(winners)
	return winners
end

function Service:_timeoutWinners()
	local active, _, free = self:_teams(true)
	return Service.ChooseTimeoutTeams(active, free, self.originalTeamSizes)
end

function Service:_spawn(index, team)
	team = typeof(team) == "number" and team or 1
	local pads = self.spawnPads
	if #self.teamSpawns > 0 then
		local groupIndex = math.floor((team - 1) * #self.teamSpawns / math.max(self.teamCount, 1)) + 1
		local choices = parts(self.teamSpawns[math.clamp(groupIndex, 1, #self.teamSpawns)])
		if #choices > 0 then pads = choices end
	end
	local position = pads[(index - 1) % #pads + 1].Position
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_clearHeat(record, true)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_publishRecord(record)
	attribute(record.player, "MDParticipating", record.participating)
	attribute(record.player, "MDTeamId", record.teamId or 0)
	local colorName = record.participating and self:_colorName(record.teamId) or ""
	attribute(record.player, "MDTeamColorName", colorName)
	attribute(record.player, "MDTeamColor", TEAM_COLORS[colorName] or Color3.fromRGB(255, 255, 255))
	attribute(record.player, "MDTeamName", colorName ~= "" and colorName .. " Team" or "")
	attribute(record.player, "MDMuddy", record.muddy == true)
	attribute(record.player, "MDEliminated", record.eliminated == true)
	attribute(record.player, "MDRescueProgress", record.rescueProgress or 0)
	attribute(record.player, "MDSprintMax", record.sprintMax or 0)
	attribute(record.player, "MDSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	attribute(record.player, "MDSprinting", record.sprinting == true)
	attribute(record.player, "MDSprintExhausted", record.sprintExhausted == true)
	attribute(record.player, "MDFireReadyAt", record.fireReadyAt or 0)
	attribute(record.player, "MDHeatActive", record.heatTarget ~= nil)
	attribute(record.player, "MDHeatTargetUserId", record.heatTarget and (record.heatTarget.player.UserId or 0) or 0)
	attribute(record.player, "MDHeatProgress", record.heatProgress or 0)
	local tool = record.participating and record.character and record.character:FindFirstChildOfClass("Tool")
	attribute(record.player, "MDTool", tool and tool:GetAttribute("MDManaged") and tool.Name or "")
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_mudVisual(record)
	local coating = record.character:FindFirstChild("MDMudCoating")
	if not record.muddy then if coating then coating:Destroy() end return end
	if coating then return end
	coating = Instance.new("Folder") coating.Name = "MDMudCoating" coating.Parent = record.character
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = record.character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			local patch = Instance.new("Part") patch.Name = name == "Head" and "MudFaceMask" or "MudPatch"
			patch.Shape = Enum.PartType.Ball
			patch.Size = Vector3.new(math.max(0.3, body.Size.X * (name == "Head" and 0.75 or 0.7)), math.max(0.2, body.Size.Y * (name == "Head" and 0.3 or 0.37)), 0.18)
			patch.CFrame = body.CFrame * CFrame.new(name == "Head" and 0 or body.Size.X * (index % 2 == 0 and 0.1 or -0.1), body.Size.Y * (name == "Head" and -0.22 or -0.08), -body.Size.Z / 2 - 0.015)
			patch.Material = Enum.Material.SmoothPlastic patch.Color = index % 2 == 0 and Color3.fromRGB(114, 73, 43) or Color3.fromRGB(143, 95, 59)
			patch.Anchored, patch.Massless, patch.CanCollide, patch.CanTouch, patch.CanQuery = false, true, false, false, false
			patch.Parent = coating
			local weld = Instance.new("WeldConstraint") weld.Name = "MudWeld" weld.Part0, weld.Part1 = body, patch weld.Parent = patch
		end
	end
end

function Service:_role(record)
	self:_publishRecord(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("MDOutline")
		if not outline then
			outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Adornee = record.character
			outline.FillTransparency = 1 outline.OutlineTransparency = 0 outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = record.character
		end
		outline.OutlineColor = TEAM_COLORS[self:_colorName(record.teamId)]
		outline.FillColor = Color3.fromRGB(124, 83, 54)
		outline.FillTransparency = record.muddy and 0.55 or 1
		self:_mudVisual(record)
		local label = record.character:FindFirstChild("MDMuddyLabel")
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local template = assets and assets:FindFirstChild("MuddyTemplate")
		if record.muddy and not label and template then label = template:Clone() label.Name = "MDMuddyLabel" label.Adornee = record.character:FindFirstChild("Head") or record.root label.Enabled = true label.Parent = record.character
		elseif not record.muddy and label then label:Destroy() end
		local torso = record.isBot and record.character:FindFirstChild("Torso")
		if torso then torso.Color = record.muddy and Color3.fromRGB(124, 83, 54) or outline.OutlineColor end
	end
end

function Service:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_freeze(record, frozen)
	record.frozen = frozen
	if frozen then record.sprintHeld = false record.sprinting = false self:_clearHeat(record, true) else record.lockedCFrame = nil end
	self:_movement(record)
end

local function managedGun(tool)
	return tool:IsA("Tool") and (tool.Name == "MudGun" or tool.Name == "HeatGun")
		and (tool:GetAttribute("MDManaged") == true or tool:GetAttribute("ManagedMudTemplate") == true)
end

function Service:_toolsAllowed(record)
	return not record.isBot and self.active and record.participating and alive(record)
		and record.player.Character == record.character
		and not record.player:GetAttribute("BBParticipating") and not record.player:GetAttribute("TGParticipating")
end

function Service:_destroyTools(record)
	if record.isBot then return end
	for _, tool in ipairs(record.managedTools or {}) do if tool.Parent then tool:Destroy() end end
	record.managedTools = {}
	local containers = { record.character, record.player.Character, record.player:FindFirstChild("Backpack"), record.player:FindFirstChild("StarterGear") }
	for _, container in pairs(containers) do
		for _, tool in ipairs(container:GetChildren()) do if managedGun(tool) then tool:Destroy() end end
	end
	attribute(record.player, "MDTool", "")
end

function Service:_watchTools(record, container, connections)
	local function validate(tool)
		if not managedGun(tool) then return end
		task.defer(function()
			if not tool.Parent or tool.Parent ~= container then return end
			if container.Name == "StarterGear" or not self:_toolsAllowed(record)
				or tool:GetAttribute("MDRound") ~= self.roundNumber or tool:GetAttribute("MDOwnerUserId") ~= record.player.UserId then
				tool:Destroy()
				self:_publishRecord(record)
			end
		end)
	end
	table.insert(connections, container.ChildAdded:Connect(validate))
	for _, tool in ipairs(container:GetChildren()) do validate(tool) end
end

function Service:_giveTools(record)
	self:_destroyTools(record)
	if not self:_toolsAllowed(record) then return end
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone()
			tool:SetAttribute("MDManaged", true)
			tool:SetAttribute("MDRound", self.roundNumber)
			tool:SetAttribute("MDOwnerUserId", record.player.UserId)
			tool.CanBeDropped = false
			table.insert(record.managedTools, tool)
			tool.Parent = backpack
			if name == "MudGun" then first = tool end
		end
	end
	if first then record.humanoid:EquipTool(first) end
end

function Service:_restore(record)
	self:_clearHeat(record, true)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
		spawnIndex = 1, rescueProgress = 0, sprintMax = 0, sprintRemaining = 0, fireReadyAt = 0, requests = {}, managedTools = {} }
	self.records[player] = record self:_publishRecord(record)
	return record
end

function Service:_setupCharacter(record, character)
	if self.records[record.player] ~= record or record.player.Character ~= character then return end
	record.generation = (record.generation or 0) + 1
	local generation = record.generation
	disconnect(record.characterConnections) self:_restore(record)
	record.character, record.root, record.humanoid, record.ready = character, nil, nil, false
	local humanoid, root = character:WaitForChild("Humanoid", 10), character:WaitForChild("HumanoidRootPart", 10)
	if self.records[record.player] ~= record or record.generation ~= generation or record.player.Character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(part) self:_collision(record, part) end))
	self:_watchTools(record, character, record.characterConnections)
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.participating then self:_stick(record, nil) end
		record.ready = false
		self:_destroyTools(record)
	end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			if record.participating then self:_stick(record, nil) end
			record.ready = false
			self:_destroyTools(record)
		end
	end))
	local function watchContainer(container)
		if container:IsA("Backpack") or container.Name == "StarterGear" then self:_watchTools(record, container, record.connections) end
	end
	table.insert(record.connections, player.ChildAdded:Connect(watchContainer))
	for _, container in ipairs(player:GetChildren()) do watchContainer(container) end
	for _, name in ipairs({ "BBParticipating", "TGParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute(name) then self:_destroyTools(record) end
		end))
	end
	self:_destroyTools(record)
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player] if not record then return end
	record.participating = false self:_restore(record) disconnect(record.connections) disconnect(record.characterConnections) self.records[player] = nil
	if self.practiceOwner == player then self:StopRound() else self:_teams(true) end
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") then included[player] = true table.insert(result, player) end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_teams(mark)
	local totals, free = {}, {}
	for _, record in pairs(self.records) do
		if record.participating and (record.isBot or record.player.Parent == Players) then totals[record.teamId] = (totals[record.teamId] or 0) + 1 if not record.muddy and not record.eliminated then free[record.teamId] = (free[record.teamId] or 0) + 1 end end
	end
	if mark and self.phase == "Playing" and self.pendingWinners == nil then
		for team = 1, self.teamCount do
			if not free[team] and not self.eliminatedTeams[team] then
				self.eliminatedTeams[team] = true
				for _, record in pairs(self.records) do if record.participating and record.teamId == team then record.eliminated = true self:_freeze(record, true) self:_role(record) end end
			end
		end
	end
	local active = {}
	for team, amount in pairs(free) do if amount > 0 and not self.eliminatedTeams[team] then table.insert(active, team) end end
	table.sort(active)
	if mark and self.active and self.phase == "Playing" and self.pendingWinners == nil and #active <= 1 then
		self.pendingWinners = table.clone(active)
		for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) end end
	end
	attribute(self.state, "ActiveTeamCount", #active)
	attribute(self.state, "TeamCount", self.teamCount)
	local participants, muddy = 0, 0
	local summary = {}
	for team = 1, self.teamCount do
		participants += totals[team] or 0 muddy += (totals[team] or 0) - (free[team] or 0)
		attribute(self.state, "Team" .. team .. "Members", totals[team] or 0) attribute(self.state, "Team" .. team .. "Free", free[team] or 0)
		table.insert(summary, { teamId = team, colorName = self:_colorName(team), free = free[team] or 0, total = totals[team] or 0, originalTotal = self.originalTeamSizes[team] or 0, eliminated = self.eliminatedTeams[team] == true })
	end
	attribute(self.state, "TeamSummaryJSON", HttpService:JSONEncode(summary))
	attribute(self.state, "ParticipantCount", participants) attribute(self.state, "MuddyCount", muddy)
	return active, totals, free
end

function Service:_stick(record, shooter)
	if not self.active or self.phase ~= "Playing" or self.pendingWinners ~= nil or not record.participating or record.eliminated or (shooter and shooter.teamId == record.teamId) then return false end
	for _, saver in pairs(self.records) do if saver.heatTarget == record then self:_clearHeat(saver, false) end end
	record.muddy, record.rescueProgress = true, 0
	self:_freeze(record, true) self:_role(record) self:_teams(true)
	return true
end

function Service:_clearHeat(record, release)
	if record.heatTarget then record.heatTarget.rescueProgress = 0 attribute(record.heatTarget.player, "MDRescueProgress", 0) end
	record.heatTarget, record.heatStartedAt, record.heatProgress = nil, nil, 0
	if record.player then attribute(record.player, "MDHeatProgress", 0) attribute(record.player, "MDHeatActive", false) attribute(record.player, "MDHeatTargetUserId", 0) end
	if record.heatBeam then record.heatBeam:Destroy() record.heatBeam = nil end
	if release then record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = false, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not self:_toolsAllowed(record) then return nil end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("MDOwnerUserId") == record.player.UserId and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
	return nil
end

function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
	if self.effects then table.insert(ignored, self.effects) end
	if source and source.character then table.insert(ignored, source.character) end
	if ignoreCharacters or not source then for _, record in pairs(self.records) do if record.character then table.insert(ignored, record.character) end end end
	local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances = ignored params.RespectCanCollide = ignoreCharacters == true or source == nil
	return params
end

function Service:_origin(record, kind, aim)
	local tool = self:_equipped(record, kind)
	if not tool then return nil end
	local origin = (record.character:FindFirstChild("Head") or record.root).Position + aim * 1.5
	if not record.isBot then
		local handle = tool:FindFirstChild("Handle") local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
		if not muzzle or not muzzle:IsA("Attachment") or (muzzle.WorldPosition - record.root.Position).Magnitude > 8 then return nil end
		origin = muzzle.WorldPosition
	end
	if workspace:Raycast(record.root.Position, origin - record.root.Position, self:_rayParameters(record, true)) then return nil end
	return origin
end

function Service:_hitRecord(part)
	for _, record in pairs(self.records) do if record.participating and record.character and part:IsDescendantOf(record.character) then return record end end
	return nil
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local origin = self:_origin(record, "Mud", aim) if not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = aim, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
	record.fireReadyAt = now + self:_setting("MudCooldownSeconds", 0.65, 0.1) self:_publishRecord(record)
	return true
end

function Service:_tickProjectiles(dt)
	for index = #self.projectiles, 1, -1 do
		local shot = self.projectiles[index]
		local remove = shot.token ~= self.currentRound or self.phase ~= "Playing" or not self.active or self.pendingWinners ~= nil
		if not remove then
			local length = math.min(shot.remaining, shot.speed * dt)
			local vector = shot.direction * length
			local hit = workspace:Raycast(shot.position, vector, self:_rayParameters(shot.source, false))
			if hit then local target = self:_hitRecord(hit.Instance) if target and target.teamId ~= shot.teamId then self:_stick(target, shot.source) end remove = true
			else shot.position += vector shot.remaining -= length shot.part.Position = shot.position remove = shot.remaining <= 0 end
		end
		if remove then shot.part:Destroy() table.remove(self.projectiles, index) end
	end
end

function Service:_heatTarget(record, now)
	if not self:_canAct(record, now) or not record.heatHeld or now >= (record.heatLeaseEndsAt or 0) or not record.heatDirection then return nil end
	local origin = self:_origin(record, "Heat", record.heatDirection) if not origin then return nil end
	local hit = workspace:Raycast(origin, record.heatDirection * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
	local target = hit and self:_hitRecord(hit.Instance)
	if not target or target == record or target.teamId ~= record.teamId or not target.muddy or target.eliminated or not alive(target) then return nil end
	if (target.root.Position - record.root.Position).Magnitude > self:_setting("HeatRange", 24, 1) + 2 then return nil end
	return target, origin, hit.Position
end

function Service:_tickHeat(now)
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = 0 end end
	local progress = {}
	for _, saver in pairs(self.records) do
		local target, origin, finish = self:_heatTarget(saver, now)
		if not target then self:_clearHeat(saver, false)
		else
			if saver.heatTarget ~= target then self:_clearHeat(saver, false) saver.heatTarget, saver.heatStartedAt = target, now end
			local elapsed = math.max(0, now - saver.heatStartedAt)
			saver.heatProgress = math.min(self:_setting("RescueSeconds", 5, 0.1), elapsed)
			progress[target] = math.max(progress[target] or 0, saver.heatProgress)
			if not saver.heatBeam then local beam = Instance.new("Part") beam.Name = "HeatBeam" beam.Anchored = true beam.CanCollide = false beam.CanTouch = false beam.CanQuery = false beam.Material = Enum.Material.Neon beam.Color = Color3.fromRGB(255, 184, 71) beam.Parent = self:_effects() saver.heatBeam = beam end
			saver.heatBeam.Size = Vector3.new(0.3, 0.3, (finish - origin).Magnitude) saver.heatBeam.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
			if elapsed >= self:_setting("RescueSeconds", 5, 0.1) then target.muddy, target.rescueProgress = false, 0 self:_freeze(target, false) self:_role(target) self:_clearHeat(saver, false) end
		end
	end
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = record.muddy and (progress[record] or 0) or 0 self:_publishRecord(record) end end
end

function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt) if record.sprintRemaining == 0 then record.sprintExhausted, record.sprinting = true, false end
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) if record.sprintRemaining >= record.sprintMax - 0.0001 then record.sprintRemaining, record.sprintExhausted = record.sprintMax, false end end
	self:_movement(record) self:_publishRecord(record)
end

function Service:_action(record, action, value, aim)
	local player = record.player
	if action == "ChooseColor" then
		if typeof(value) ~= "string" or not PREFERENCE_COLORS[value] then return { ok = false, message = "Choose Red, Blue, Green or Black." } end
		local now = workspace:GetServerTimeNow()
		if now - (record.requests.ChooseColor or -math.huge) < 0.2 then return { ok = false, message = "Slow down." } end
		record.requests.ChooseColor = now
		attribute(player, "MDColorPreference", value)
		if record.participating and self.phase == "Countdown" then
			for team, name in pairs(self.teamColors) do if team ~= record.teamId and name == value then return { ok = true, message = "Saved for the next round; that team color is in use." } end end
			self.teamColors[record.teamId] = value
			for _, teammate in pairs(self.records) do if teammate.participating and teammate.teamId == record.teamId then self:_role(teammate) end end
			self:_teams(false)
		end
		return { ok = true, message = "Color preference saved." }
	end
	if action == "Sprint" and value == false then record.sprintHeld, record.sprinting = false, false if record.participating then self:_movement(record) end self:_publishRecord(record) return { ok = true } end
	if action == "Heat" and value == false then self:_clearHeat(record, true) self:_publishRecord(record) return { ok = true } end
	if typeof(action) ~= "string" or (action ~= "Sprint" and action ~= "Fire" and action ~= "Heat") then return { ok = false, message = "Unknown action." } end
	local now = workspace:GetServerTimeNow()
	if now - (record.requests[action] or -math.huge) < 0.08 then return { ok = false, message = "Slow down." } end
	record.requests[action] = now
	if not self:_canAct(record, now) then return { ok = false, message = "Wait until you can move." } end
	if action == "Sprint" then if value ~= true then return { ok = false, message = "Invalid sprint." } end record.sprintHeld, record.sprintLeaseEndsAt = true, now + 1 self:_movement(record) return { ok = true } end
	local unit = direction(action == "Fire" and value or aim)
	if not unit then return { ok = false, message = "Aim toward the playground." } end
	if action == "Fire" then return { ok = self:_fire(record, unit, now), message = "Mud shot." } end
	if value ~= true or not self:_origin(record, "Heat", unit) then return { ok = false, message = "Equip the Heat Gun." } end
	record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = true, unit, now + 1
	return { ok = true }
end

function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position) local half = self.bounds.Size / 2
	local floor = self:_setting("FloorY", self.spawnPads[1].Position.Y - 3.5, -10000)
	if math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3 or record.root.Position.Y < floor - 7 or math.abs(point.Y) > half.Y then self:_stick(record, nil) self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then record.lastGoodCFrame = record.root.CFrame end
end

function Service:_newBot(index, role)
	if not self.botFolder then
		self.botFolder = Instance.new("Folder")
		self.botFolder.Name = "MudPracticeBots"
		self.botFolder:SetAttribute("MudManaged", true)
		self.botFolder.Parent = workspace
	end
	local attributes = {}
	local player = { DisplayName = role == "Tagger" and "Practice Rival" or "Practice Teammate " .. tostring(index), UserId = -index }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value) attributes[name] = value end
	local character = Instance.new("Model")
	character.Name = player.DisplayName
	character:SetAttribute("MDPracticeBot", true)
	local spawn = self:_spawn(index + 1, role == "Tagger" and 2 or 1)
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
	humanoid.WalkSpeed = self:_setting("BaseSpeed", 16, 0)
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
	record.spawnIndex = index + 1
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
	record.frozen = record.muddy or record.eliminated or self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_freeze(record, record.frozen)
	self:_role(record)
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

function Service:_botTarget(bot)
	local teammate, teammateDistance, opponent, opponentDistance
	for _, candidate in pairs(self.records) do
		if candidate ~= bot and candidate.participating and not candidate.eliminated and alive(candidate) then
			local distance = (candidate.root.Position - bot.root.Position).Magnitude
			if candidate.teamId == bot.teamId and candidate.muddy and (not teammateDistance or distance < teammateDistance) then teammate, teammateDistance = candidate, distance
			elseif candidate.teamId ~= bot.teamId and not candidate.muddy and (not opponentDistance or distance < opponentDistance) then opponent, opponentDistance = candidate, distance end
		end
	end
	if teammate then return teammate, true, teammateDistance end
	return opponent, false, opponentDistance
end

function Service:_moveBot(bot, goal, now)
	local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
	local destination = goal
	if not direct then
		self:_path(bot, goal, now)
		local route, index = bot.route, bot.routeIndex or 1
		while route and route[index] and (route[index].Position - bot.root.Position).Magnitude < 4 do index += 1 end
		bot.routeIndex = index
		local waypoint = route and route[index]
		if waypoint then destination = waypoint.Position if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
		else destination = bot.root.Position end
	end
	if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 5 then
		bot.stuckSince += 0.2
		if bot.stuckSince > 0.8 then bot.humanoid.Jump = true bot.nextPathAt = 0 end
	else bot.stuckSince = 0 end
	bot.previousBotPosition = bot.root.Position
	bot.humanoid:MoveTo(destination)
end

function Service:_driveBots(now)
	for _, bot in pairs(self.records) do
		if bot.isBot and self:_canAct(bot, now) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target, rescue, distance = self:_botTarget(bot)
			if target then
				local goal = target.root.Position
				local head = bot.character:FindFirstChild("Head") or bot.root
				local aim = direction(goal - head.Position)
				local heating = false
				if rescue and aim and distance <= self:_setting("HeatRange", 24, 1) - 2 then
					bot.heatHeld, bot.heatDirection, bot.heatLeaseEndsAt = true, aim, now + 1
					heating = self:_heatTarget(bot, now) == target
				end
				if not heating then self:_clearHeat(bot, true) end
				if heating then bot.humanoid:MoveTo(bot.root.Position)
				else
					local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
					if not rescue and direct and distance < math.min(self:_setting("MudRange", 130, 1) - 10, 80) then
						bot.humanoid:MoveTo(bot.root.Position)
						local interval = self:_setting("BotShotIntervalSeconds", 7, 0.2)
						bot.nextBotShotAt = bot.nextBotShotAt or now + interval * (0.6 + bot.spawnIndex * 0.3)
						if now >= bot.nextBotShotAt then
							local lead = math.min(distance / self:_setting("ProjectileSpeed", 115, 1), 1)
							local predicted = goal + target.root.AssemblyLinearVelocity * lead
							local shotDirection = direction(predicted - head.Position)
							if shotDirection then self:_fire(bot, shotDirection, now) end
							bot.nextBotShotAt = now + interval
						end
					else self:_moveBot(bot, goal, now) end
				end
			else self:_clearHeat(bot, true) bot.humanoid:MoveTo(bot.root.Position) end
		end
	end
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_stick(record, nil) self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
		self:_tickSprint(record, dt, now)
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now) self:_tickProjectiles(dt) self:_tickHeat(now) self:_teams(true)
end

function Service:_valid(token) return self.running and self.active and self.currentRound == token end

function Service:_results(token, winners, reason)
	local winnerSet, winnerIds, participantIds, names = {}, {}, {}, {}
	for _, id in ipairs(winners) do winnerSet[id] = true end
	for _, entry in ipairs(self.roundRoster) do if not entry.isBot then table.insert(participantIds, entry.userId) if winnerSet[entry.teamId] then table.insert(winnerIds, entry.userId) end end end
	for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) local won = winnerSet[record.teamId] == true attribute(record.player, "MDResult", won and "Won" or "Lost") if won then table.insert(names, record.player.DisplayName) end end end
	for _, shot in ipairs(self.projectiles) do shot.part:Destroy() end table.clear(self.projectiles)
	table.sort(winnerIds) table.sort(participantIds) table.sort(names)
	attribute(self.state, "WinnerTeamIds", table.concat(winners, ",")) attribute(self.state, "WinnerTeams", table.concat(winners, ",")) attribute(self.state, "WinnersText", table.concat(names, ", ")) attribute(self.state, "ResultReason", reason)
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ",")) attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ",")) attribute(self.state, "LastResultPractice", self.mode ~= "Round") attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do self:_destroyTools(record) end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber += 1 self.eliminatedTeams, self.originalTeamSizes, self.roundRoster, self.pendingWinners = {}, {}, {}, nil
	attribute(self.state, "RoundNumber", self.roundNumber) attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 1)) attribute(self.state, "RescueSeconds", self:_setting("RescueSeconds", 5, 0.1)) attribute(self.state, "WinnersText", "") attribute(self.state, "WinnerTeams", "") attribute(self.state, "WinnerTeamIds", "") attribute(self.state, "ResultReason", "")
	local assignments
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants, self:_setting("TeamCount", 2, 2), self:_setting("MaxTeamSize", 2, 2)) end
	local slots = {}
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating, record.teamId, record.muddy, record.eliminated = true, assignments[index], false, false slots[record.teamId] = (slots[record.teamId] or 0) + 1 record.spawnIndex = slots[record.teamId]
			self.originalTeamSizes[record.teamId] = (self.originalTeamSizes[record.teamId] or 0) + 1
			table.insert(self.roundRoster, { userId = player.UserId, teamId = record.teamId, isBot = record.isBot })
			record.sprintMax = self:_setting("SprintSeconds", 10, 0.1) record.sprintRemaining = record.sprintMax record.sprintExhausted, record.sprintHeld, record.fireReadyAt = false, false, 0
			record.rescueProgress, record.lastGoodCFrame, record.requests, record.nextBotShotAt = 0, nil, {}, nil attribute(player, "MDResult", "")
			local spawn = self:_spawn(record.spawnIndex, record.teamId)
			local practice = token.teams and parts(self.gameplay:FindFirstChild("PracticeSpawns"))
			if practice and #practice > 0 then spawn = practice[(index - 1) % #practice + 1].CFrame elseif token.teams then spawn = CFrame.new(self.bounds.Position.X + (record.teamId == 1 and -22 or 22), self.spawnPads[1].Position.Y, self.bounds.Position.Z + (record.spawnIndex - 1) * 17) end
			self:_teleport(record, spawn) self:_freeze(record, true) self:_giveTools(record) self:_role(record)
		end
	end
	self:_chooseTeamColors()
	for _, record in pairs(self.records) do if record.participating then self:_role(record) end end
	self:_teams(false) self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do if not self:_valid(token) then return end attribute(self.state, "CountdownValue", number) local untilTime = workspace:GetServerTimeNow() + 1 while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end end
	if not self:_valid(token) then return end
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 300, 1) attribute(self.state, "EndsAt", self.endsAt) attribute(self.state, "CountdownValue", 0) self:_phase("Playing")
	for _, record in pairs(self.records) do if record.participating and self.pendingWinners == nil then if not alive(record) or (record.isBot and record.practiceMedic and self.mode == "PracticeMedic") then self:_stick(record, nil) else self:_freeze(record, false) end end end
	local active = self:_teams(true)
	while self:_valid(token) and self.pendingWinners == nil and workspace:GetServerTimeNow() < self.endsAt do task.wait(0.05) active = self:_teams(true) end
	if self:_valid(token) then
		local reason
		if self.pendingWinners then active = self.pendingWinners reason = #active == 0 and "NoActiveTeams" or "LastTeamStanding"
		else active = self:_timeoutWinners() reason = #active > 1 and "TimeoutShared" or #active == 0 and "NoActiveTeams" or "Timeout" end
		self:_results(token, active, reason) self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, teams, owner)
	self.active, self.mode, self.practiceOwner = true, mode, owner
	local token = { teams = teams } self.currentRound = token
	attribute(self.state, "Mode", mode) attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function() local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback) if not ok then warn("Stuck in the Mud round failed: " .. tostring(failure)) self:_cleanup(token) end end)
	return true
end

function Service:_weaponsReady()
	local ok, ready = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local mud = assets and assets:FindFirstChild("MudGun")
		local heat = assets and assets:FindFirstChild("HeatGun")
		if not mud or not heat or not mud:IsA("Tool") or not heat:IsA("Tool") then return false end
		local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled
		return mudEnabled == true and heatEnabled == true
	end)
	return ok and ready == true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	local participants = self:_readyPlayers(selected)
	local minimum = math.clamp(math.floor(self:_setting("MinimumPlayers", 4, 2)), 2, 24)
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 4, 2)), 2, 24)
	if #participants < minimum or maximum < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
	while #participants > maximum do table.remove(participants) end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	if role ~= "Runner" and role ~= "Tagger" and role ~= "Shooter" and role ~= "Medic" then return false, "Choose Shooter or Medic practice" end
	local record = self.records[player] if not connectedPlayer(player) or not record or record.isBot or not alive(record) or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return false, "Your character is not ready" end
	local participants, teams = { player }, { 1 }
	local ok, failure = xpcall(function() for index = 1, 3 do local bot = self:_newBot(index, index == 1 and "Runner" or "Tagger") table.insert(participants, bot) table.insert(teams, index == 1 and 1 or 2) self.records[bot].practiceMedic = index == 1 end end, debug.traceback)
	if not ok then self:_clearBots() warn(tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, teams, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end self.currentRound = nil self:_cleanup() return true
end

function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, RescueSeconds = 5, ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 self:_tick(math.min(elapsed, 0.25)) end end))
	for _, value in ipairs(Players:GetPlayers()) do self:_addPlayer(value) end
	local remote = ReplicatedStorage:FindFirstChild("MudActionRequest") if remote and remote:IsA("RemoteFunction") then self.remote = remote remote.OnServerInvoke = function(value, action, argument, aim) return self:Action(value, action, argument, aim) end end
end

function Service:Stop()
	self.running, self.currentRound = false, nil disconnect(self.connections) self:_cleanup()
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end table.clear(self.records)
	if self.remote then self.remote.OnServerInvoke = nil end if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end

return Service]====]},
{path="ServerScriptService.TagService", before=[====[local Players = game:GetService("Players")
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
		if record and not record.isBot and not included[player] and player.Parent == Players and alive(record) and player:GetAttribute("BBParticipating") ~= true and player:GetAttribute("MDParticipating") ~= true then
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
	if not record or record.isBot or player.Parent ~= Players or not alive(record) or (player:GetAttribute("BBParticipating") == true or player:GetAttribute("MDParticipating") == true) then return false, "Your character is not ready yet" end
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

return Service]====], after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(54, 174, 255), Tagger = Color3.fromRGB(255, 83, 100) }
local BAT_RAGDOLL_SECONDS = 1.35

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

function Service:_restoreRagdoll(record, standUp)
	local saved = record.ragdoll
	if not saved then return end
	record.ragdoll = nil
	disconnect(saved.connections)
	for part, original in pairs(saved.parts) do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CanCollide = original.CanCollide
		end
	end
	for _, instance in ipairs(saved.created) do
		if instance.Parent then instance:Destroy() end
	end
	for socket, enabled in pairs(saved.sockets) do
		if socket.Parent then socket.Enabled = enabled end
	end
	for _, original in ipairs(saved.motors) do
		if original.motor.Parent and original.motor.Enabled ~= original.Enabled then original.motor.Enabled = original.Enabled end
	end
	local humanoid = saved.humanoid
	if standUp and humanoid.Parent and humanoid.Health > 0 and saved.character.Parent and saved.root.Parent then
		saved.character:PivotTo(saved.standCFrame * saved.root.CFrame:Inverse() * saved.character:GetPivot())
	end
	if humanoid.Parent then
		humanoid.RequiresNeck = saved.RequiresNeck
		humanoid.AutoRotate = saved.AutoRotate
		humanoid.PlatformStand = saved.PlatformStand
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, saved.GettingUpEnabled)
		if standUp and humanoid.Health > 0 and not saved.PlatformStand then
			humanoid:ChangeState(saved.GettingUpEnabled and Enum.HumanoidStateType.GettingUp or Enum.HumanoidStateType.Running)
		end
	end
	attribute(saved.character, "TGRagdolled", false)
	attribute(record.player, "TGRagdolled", false)
	if record.character == saved.character and record.participating then self:_movement(record) end
	if saved.root.Parent and not record.frozen then
		pcall(function()
			if record.isBot then saved.root:SetNetworkOwner(nil) else saved.root:SetNetworkOwnershipAuto() end
		end)
	end
end

function Service:_ragdoll(record, attacker, now)
	if not alive(record) then return false end
	self:_restoreRagdoll(record, true)
	local character, humanoid, root = record.character, record.humanoid, record.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local saved = {
		character = character, humanoid = humanoid, root = root,
		endsAt = now + BAT_RAGDOLL_SECONDS, token = self.currentRound,
		standCFrame = CFrame.lookAt(root.Position, root.Position + look.Unit),
		RequiresNeck = humanoid.RequiresNeck, PlatformStand = humanoid.PlatformStand,
		AutoRotate = humanoid.AutoRotate, GettingUpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
		motors = {}, sockets = {}, parts = {}, created = {}, connections = {},
	}
	self:_stopBurst(record)
	record.batSwing = nil
	record.ragdoll = saved
	self:_movement(record)
	record.lockedCFrame = nil
	local ok, failure = xpcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "TGRagdollConstraints"
		folder.Parent = character
		table.insert(saved.created, folder)
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		local authoredSockets = {}
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("BallSocketConstraint") and object.Attachment0 and object.Attachment1 then
				table.insert(authoredSockets, object)
			end
		end
		for _, motor in ipairs(character:GetDescendants()) do
			local first, second
			if motor:IsA("Motor6D") then
				first, second = motor.Part0, motor.Part1
			elseif motor:IsA("AnimationConstraint") and motor.Attachment0 and motor.Attachment1 then
				first = motor.Attachment0:FindFirstAncestorWhichIsA("BasePart")
				second = motor.Attachment1:FindFirstAncestorWhichIsA("BasePart")
			end
			if first and second and first.Parent == character and second.Parent == character then
				for _, part in ipairs({ first, second }) do
					if not saved.parts[part] then saved.parts[part] = { CanCollide = part.CanCollide } end
				end
				table.insert(saved.motors, { motor = motor, Enabled = motor.Enabled })
				if motor.Enabled and first ~= root and second ~= root then
					local authoredSocket
					if motor:IsA("AnimationConstraint") then
						for _, socket in ipairs(authoredSockets) do
							local part0 = socket.Attachment0:FindFirstAncestorWhichIsA("BasePart")
							local part1 = socket.Attachment1:FindFirstAncestorWhichIsA("BasePart")
							if (part0 == first and part1 == second) or (part0 == second and part1 == first) then
								authoredSocket = socket
								break
							end
						end
					end
					if authoredSocket then
						saved.sockets[authoredSocket] = authoredSocket.Enabled
						authoredSocket.Enabled = true
					else
						local firstAttachment = Instance.new("Attachment")
						firstAttachment.Name = "TGRagdollA0"
						firstAttachment.CFrame = motor:IsA("Motor6D") and motor.C0 * motor.Transform or first.CFrame:ToObjectSpace(motor.Attachment0.WorldCFrame)
						firstAttachment.Parent = first
						table.insert(saved.created, firstAttachment)
						local secondAttachment = Instance.new("Attachment")
						secondAttachment.Name = "TGRagdollA1"
						secondAttachment.CFrame = motor:IsA("Motor6D") and motor.C1 or second.CFrame:ToObjectSpace(motor.Attachment1.WorldCFrame)
						secondAttachment.Parent = second
						table.insert(saved.created, secondAttachment)
						local socket = Instance.new("BallSocketConstraint")
						socket.Name = motor.Name .. "Socket"
						socket.Attachment0 = firstAttachment
						socket.Attachment1 = secondAttachment
						socket.LimitsEnabled = true
						socket.TwistLimitsEnabled = true
						local name = motor.Name:lower()
						local restrained = name:find("neck") or name:find("waist") or name:find("wrist") or name:find("ankle")
						socket.UpperAngle = restrained and 25 or 65
						socket.TwistLowerAngle = restrained and -20 or -45
						socket.TwistUpperAngle = restrained and 20 or 45
						socket.MaxFrictionTorque = 4
						socket.Restitution = 0
						socket.Parent = folder
					end
					local noCollision = Instance.new("NoCollisionConstraint")
					noCollision.Name = motor.Name .. "NoCollision"
					noCollision.Part0 = first
					noCollision.Part1 = second
					noCollision.Parent = folder
					motor.Enabled = false
				end
			end
		end
		for part in pairs(saved.parts) do
			part.CanCollide = part ~= root
			pcall(function() part:SetNetworkOwner(nil) end)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		local direction = attacker and attacker.root and root.Position - attacker.root.Position or -look
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.01 then direction = -look end
		direction = direction.Unit
		root.AssemblyLinearVelocity = direction * 8 + Vector3.new(0, 3, 0)
		root.AssemblyAngularVelocity = Vector3.new(direction.Z * 3, 0, -direction.X * 3)
		attribute(record.player, "TGRagdolled", true)
		attribute(character, "TGRagdolled", true)
		table.insert(saved.connections, humanoid.Died:Connect(function()
			if record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
		table.insert(saved.connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent and record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
	end, debug.traceback)
	if not ok then
		self:_restoreRagdoll(record, true)
		warn("Tag ragdoll could not start: " .. tostring(failure))
	end
	return ok
end

function Service:_updateRagdoll(record, now)
	local saved = record.ragdoll
	if not saved then return end
	if record.character ~= saved.character or not alive(record) or not record.participating
		or not self.active or self.currentRound ~= saved.token then
		self:_restoreRagdoll(record, alive(record) and record.character == saved.character)
	elseif now >= saved.endsAt then
		self:_restoreRagdoll(record, true)
	end
end


function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_restoreRagdoll(record, false)
	record.batSwing = nil
	self:_stopBurst(record)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_restore(record)
	self:_restoreRagdoll(record, true)
	record.batSwing = nil
	record.batSwingReadyAt = 0
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
	local locked = record.frozen or record.ragdoll ~= nil
	humanoid.WalkSpeed = locked and 0 or self:_setting(record.role == "Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed", record.role == "Tagger" and 18 or 16, 0)
	humanoid.JumpPower = locked and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = locked and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not locked and record.originalMovement.AutoRotate
	if locked then record.batSwing = nil humanoid.Jump = false end
	if record.ragdoll then
		self:_stopBurst(record)
		record.lockedCFrame = nil
		return
	end
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
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.ragdoll and not record.isBot then
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
	if role ~= "Tagger" then record.batSwing = nil end
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
		self:_restoreRagdoll(record, false)
		record.batSwing = nil
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
		if record.character == character then
			self:_restoreRagdoll(record, false)
			record.batSwing = nil
			record.ready = false
		end
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
		if record and not record.isBot and not included[player] and player.Parent == Players and alive(record) and player:GetAttribute("BBParticipating") ~= true and player:GetAttribute("MDParticipating") ~= true then
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

function Service:_batInField(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size * 0.5
	return math.abs(point.X) <= half.X - 3 and math.abs(point.Z) <= half.Z - 3
		and math.abs(point.Y) <= half.Y and record.root.Position.Y >= self.spawnPads[1].Position.Y - 9
end

function Service:TryBatSwing(player)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record
		or not record.participating or record ~= self.tagger or record.role ~= "Tagger" or not alive(record) then
		return false, "Only the current Tagger can swing in an active Tag round"
	end
	if not record.isBot and (typeof(player) ~= "Instance" or player.Parent ~= Players) then return false, "Player is not connected" end
	if player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBParticipating") == true then return false, "Wrong game" end
	if record.frozen or record.ragdoll or not self:_batInField(record) then return false, "Cannot swing right now" end
	if now < (record.tagCooldownEndsAt or 0) or now < (record.batSwingReadyAt or 0) then return false, "Bat is recovering" end
	record.batSwing = { hitAt = now + 0.16, endsAt = now + 0.30, hit = false,
		character = record.character, token = self.currentRound }
	record.batSwingReadyAt = now + 0.75
	attribute(player, "PCBatSwingAt", now)
	local serial = player:GetAttribute("PCBatSwingSerial")
	attribute(player, "PCBatSwingSerial", (typeof(serial) == "number" and serial or 0) + 1)
	return true
end

function Service:CancelBatSwing(player)
	local record = self.records[player]
	if not record then return false end
	record.batSwing = nil
	return true
end

function Service:_swingCanHit(from, target, now)
	local swing = from and from.batSwing
	if not swing or swing.hit or now < swing.hitAt or now > swing.endsAt
		or swing.character ~= from.character or swing.token ~= self.currentRound then return false end
	local offset = target.root.Position - from.root.Position
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	local facing = Vector3.new(from.root.CFrame.LookVector.X, 0, from.root.CFrame.LookVector.Z)
	return horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25)
end

function Service:_canTag(from, target, now, rayParameters)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or from.role ~= "Tagger" or target.role ~= "Runner"
		or from.frozen or target.frozen or from.ragdoll or target.ragdoll
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	if not self:_batInField(from) or not self:_batInField(target) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= self:_setting("TagDistance", 4.5, 1)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

function Service:_transfer(target, now)
	local previous = self.tagger
	if not self:_canTag(previous, target, now) or not self:_swingCanHit(previous, target, now) then return false end
	previous.batSwing.hit = true
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
	self:_ragdoll(target, previous, now)
	local serial = previous.player:GetAttribute("PCBatHitSerial")
	attribute(previous.player, "PCBatHitSerial", (typeof(serial) == "number" and serial or 0) + 1)
	self.tagCount = self.tagCount + 1
	self:_publish()
	return true
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
			self:_restoreRagdoll(record, false)
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
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= bot.nextBotMoveAt then
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
			if bot == self.tagger then
				for _, target in pairs(self.records) do
					if self:_canTag(bot, target, now) then self:TryBatSwing(bot.player) break end
				end
			end
		end
	end
end

function Service:_tick()
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	self:_account(now)
	for _, record in pairs(self.records) do
		self:_updateRagdoll(record, now)
		if record.batSwing and now > record.batSwing.endsAt then record.batSwing = nil end
		if record.participating and record.isBot and not alive(record) then self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.ragdoll then
				record.humanoid:Move(Vector3.zero)
			elseif record.frozen and record.lockedCFrame then
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
		if self:_canTag(self.tagger, record, now, params) and self:_swingCanHit(self.tagger, record, now) then
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
	if record.frozen or record.ragdoll then return false, "Wait until you can move again" end
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
	if not record or record.isBot or player.Parent ~= Players or not alive(record) or (player:GetAttribute("BBParticipating") == true or player:GetAttribute("MDParticipating") == true) then return false, "Your character is not ready yet" end
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

return Service]====]},
{path="ServerScriptService.TagSprintService", before=[====[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Service={}
Service.__index=Service
local runningService

local function set(player,name,value)
 if player:GetAttribute(name)~=value then player:SetAttribute(name,value) end
end

function Service.new(tag)
 return setmetatable({tag=tag,arena=tag.arena,entries={},connections={},running=false},Service)
end

function Service:_setting(name,fallback,minimum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.max(minimum or 0,value)
end

function Service:_active(player,record)
 return self.tag.active and self.tag.phase=="Playing" and record and record.participating and not record.frozen
  and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent
  and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
end

function Service:Request(player,held)
 if typeof(held)~="boolean" then return {ok=false,message="Hold or release sprint."} end
 local record=self.tag.records[player]
 local entry=self.entries[player]
 if not held then
  if entry then entry.held=false entry.lease=0 end
  return {ok=true}
 end
 if player.Parent~=Players or not self:_active(player,record) then return {ok=false,message="Sprint is available during Tag."} end
 if not entry then return {ok=false,message="Sprint is getting ready."} end
 local now=workspace:GetServerTimeNow()
 if now-(entry.lastRequest or -math.huge)<0.075 then return {ok=false,message="Sprint request too soon."} end
 entry.lastRequest=now
 entry.held=true
 entry.lease=now+1
 return {ok=true}
end

function Service:_tick(delta)
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local record=self.tag.records[player]
  local participating=record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
  local entry=self.entries[player]
  if not participating then
   if entry then self.entries[player]=nil end
   set(player,"TGSprinting",false)
   set(player,"TGSprintExhausted",false)
   set(player,"TGSprintRemaining",self:_setting("SprintSeconds",10,0.1))
  else
   local maximum=self:_setting("SprintSeconds",10,0.1)
   local round=self.tag.currentRound or self.tag.roundNumber
   if not entry or entry.round~=round then
    entry={remaining=maximum,held=false,locked=false,lease=0,character=record.character,round=round}
    self.entries[player]=entry
   elseif entry.character~=record.character then
    entry.character=record.character
    entry.held=false entry.lease=0
   end
   entry.remaining=math.clamp(entry.remaining,0,maximum)
   if now>entry.lease then entry.held=false end
   local canMove=self:_active(player,record)
   local velocity=record.root and record.root.AssemblyLinearVelocity or Vector3.zero
   local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
   local sprinting=canMove and entry.held and not entry.locked and moving
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
    if entry.remaining<=0 then entry.locked=true sprinting=false end
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
    if entry.locked and entry.remaining>=maximum-0.00001 then entry.locked=false end
   end
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=record.frozen and 0 or base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end

function Service:Start()
 if self.running then return end
 self.running=true
 runningService=self
 self.remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
 self.remote.OnServerInvoke=function(player,held) return self:Request(player,held) end
 local accumulated=0
 table.insert(self.connections,RunService.Heartbeat:Connect(function(delta)
  accumulated+=delta
  if accumulated>=0.05 then local step=accumulated accumulated=0 self:_tick(math.min(step,0.25)) end
 end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.entries[player]=nil end))
end

function Service:Stop()
 self.running=false
 if self.remote then self.remote.OnServerInvoke=nil end
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 for player in pairs(self.entries) do
  local record=self.tag.records[player]
  if record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating") then self.tag:_movement(record) end
  set(player,"TGSprinting",false)
 end
 table.clear(self.entries)
 if runningService==self then runningService=nil end
end

function Service.GetRunningService() return runningService end

return Service]====], after=[====[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Service={}
Service.__index=Service
local runningService

local function set(player,name,value)
 if player:GetAttribute(name)~=value then player:SetAttribute(name,value) end
end

function Service.new(tag)
 return setmetatable({tag=tag,arena=tag.arena,entries={},connections={},running=false},Service)
end

function Service:_setting(name,fallback,minimum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.max(minimum or 0,value)
end

function Service:_active(player,record)
 return self.tag.active and self.tag.phase=="Playing" and record and record.participating and not record.frozen and not record.ragdoll and player:GetAttribute("TGRagdolled") ~= true
  and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent
  and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
end

function Service:Request(player,held)
 if typeof(held)~="boolean" then return {ok=false,message="Hold or release sprint."} end
 local record=self.tag.records[player]
 local entry=self.entries[player]
 if not held then
  if entry then entry.held=false entry.lease=0 end
  return {ok=true}
 end
 if player.Parent~=Players or not self:_active(player,record) then return {ok=false,message="Sprint is available during Tag."} end
 if not entry then return {ok=false,message="Sprint is getting ready."} end
 local now=workspace:GetServerTimeNow()
 if now-(entry.lastRequest or -math.huge)<0.075 then return {ok=false,message="Sprint request too soon."} end
 entry.lastRequest=now
 entry.held=true
 entry.lease=now+1
 return {ok=true}
end

function Service:_tick(delta)
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local record=self.tag.records[player]
  local participating=record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
  local entry=self.entries[player]
  if not participating then
   if entry then self.entries[player]=nil end
   set(player,"TGSprinting",false)
   set(player,"TGSprintExhausted",false)
   set(player,"TGSprintRemaining",self:_setting("SprintSeconds",10,0.1))
  else
   local maximum=self:_setting("SprintSeconds",10,0.1)
   local round=self.tag.currentRound or self.tag.roundNumber
   if not entry or entry.round~=round then
    entry={remaining=maximum,held=false,locked=false,lease=0,character=record.character,round=round}
    self.entries[player]=entry
   elseif entry.character~=record.character then
    entry.character=record.character
    entry.held=false entry.lease=0
   end
   entry.remaining=math.clamp(entry.remaining,0,maximum)
   if now>entry.lease then entry.held=false end
   local canMove=self:_active(player,record)
   local velocity=record.root and record.root.AssemblyLinearVelocity or Vector3.zero
   local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
   local sprinting=canMove and entry.held and not entry.locked and moving
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
    if entry.remaining<=0 then entry.locked=true sprinting=false end
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
    if entry.locked and entry.remaining>=maximum-0.00001 then entry.locked=false end
   end
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=(record.frozen or record.ragdoll or player:GetAttribute("TGRagdolled")==true) and 0 or base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end

function Service:Start()
 if self.running then return end
 self.running=true
 runningService=self
 self.remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
 self.remote.OnServerInvoke=function(player,held) return self:Request(player,held) end
 local accumulated=0
 table.insert(self.connections,RunService.Heartbeat:Connect(function(delta)
  accumulated+=delta
  if accumulated>=0.05 then local step=accumulated accumulated=0 self:_tick(math.min(step,0.25)) end
 end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.entries[player]=nil end))
end

function Service:Stop()
 self.running=false
 if self.remote then self.remote.OnServerInvoke=nil end
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 for player in pairs(self.entries) do
  local record=self.tag.records[player]
  if record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating") then self.tag:_movement(record) end
  set(player,"TGSprinting",false)
 end
 table.clear(self.entries)
 if runningService==self then runningService=nil end
end

function Service.GetRunningService() return runningService end

return Service]====]},
{path="StarterGui.PlaygroundAdminPanel.Controller", before=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
	enabled(itemsPage.Filters.ClearPreview, rewardReady() and targetData.batPreview == true)
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			local preview = equipped and item.slot == "Bat" and targetData.batPreview ~= true
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or preview and "SHOW BAT" or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and (not equipped or preview) and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Filters.ClearPreview.Activated, function() if rewardReady() then request("ClearPreview") end end)
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()]====], after=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and not equipped and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()]====]},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundEmotes", before=[====[local Players = game:GetService("Players")
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
end)]====], after=[====[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local records = {}
local function restore(record)
	for joint, entry in pairs(record.joints) do
		if joint.Parent and joint.Transform == entry.applied then joint.Transform = entry.original end
	end
	table.clear(record.joints)
end
local function pose(record, joint, offset)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local applied = original * offset
	joint.Transform = applied
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local batPoses = {
	{ time = 0, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
	{ time = 0.11, r6 = Vector3.new(115, -55, -15), r15 = Vector3.new(85, -55, -15), elbow = 35, wrist = -10 },
	{ time = 0.20, r6 = Vector3.new(75, 25, -10), r15 = Vector3.new(55, 25, -10), elbow = 20, wrist = 8 },
	{ time = 0.30, r6 = Vector3.new(60, 65, -12), r15 = Vector3.new(40, 65, -12), elbow = 25, wrist = 12 },
	{ time = 0.48, r6 = Vector3.new(90, 0, -8), r15 = Vector3.new(65, 0, -8), elbow = 25, wrist = 0 },
}
local function sampleBatPose(elapsed, classic)
	local key = classic and "r6" or "r15"
	if elapsed < 0 or elapsed >= 0.48 then return batPoses[1][key], batPoses[1].elbow, 0 end
	for index = 2, #batPoses do
		local first, last = batPoses[index - 1], batPoses[index]
		if elapsed <= last.time then
			local alpha = (elapsed - first.time) / (last.time - first.time)
			alpha = alpha * alpha * (3 - 2 * alpha)
			return first[key]:Lerp(last[key], alpha), first.elbow + (last.elbow - first.elbow) * alpha, first.wrist + (last.wrist - first.wrist) * alpha
		end
	end
end
local function weaponJoint(record, joint, angles, fade)
	if not joint or not joint.Parent or not joint.Enabled or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return end
	local original = joint.Transform
	local rotation = joint.C0.Rotation
	local target = rotation:Inverse() * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z)) * rotation
	local applied = original:Lerp(target, fade)
	joint.Transform = applied
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function animateBat(record, player, character, humanoid, now)
	local tool
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("PCBatWeapon") == true then tool = child break end
	end
	if not tool or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
		or (player:GetAttribute("BBParticipating") ~= true and player:GetAttribute("TGParticipating") ~= true) then
		record.weapon = nil
		return false
	end
	if record.weapon ~= tool then
		record.weapon = tool
		record.weaponAt = now
		record.shoulder = character:FindFirstChild(humanoid.RigType == Enum.HumanoidRigType.R6 and "Right Shoulder" or "RightShoulder", true)
		record.elbow = character:FindFirstChild("RightElbow", true)
		record.wrist = character:FindFirstChild("RightWrist", true)
	end
	local started = tool:GetAttribute("BatSwingAt")
	local elapsed = typeof(started) == "number" and now - started or math.huge
	local shoulder, elbow, wrist = sampleBatPose(elapsed, humanoid.RigType == Enum.HumanoidRigType.R6)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	weaponJoint(record, record.shoulder, shoulder, fade)
	weaponJoint(record, record.elbow, Vector3.new(elbow, 0, 0), fade)
	weaponJoint(record, record.wrist, Vector3.new(0, wrist, 0), fade)
	return true
end
local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
end)
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
		restore(record)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil continue end
		if animateBat(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			restore(record)
			continue
		end
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
	beforeAnimation:Disconnect()
	frame:Disconnect()
	removing:Disconnect()
	for _, record in pairs(records) do restore(record) end
end)]====]}}
for _,entry in ipairs(entries) do
 entry.target=find(entry.path)
 local current=normalize(entry.target.Source)
 assert(current==entry.before or current==entry.after, "Live source changed: "..entry.path)
 assert(loadstring(entry.after), "Cannot compile "..entry.path)
end
assert(tostring(game.ServerScriptService.PlaygroundBootstrap.Capabilities):find("Animation",1,true), "Launcher Animation approval required")
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("WeaponRigUpdateBackup20261004")
if not backup then backup=Instance.new("Folder") backup.Name="WeaponRigUpdateBackup20261004" backup.Parent=storage end
local report={playStarted=false, scripts={}}
for _,entry in ipairs(entries) do
 local target=entry.target
 local caps=tostring(target.Capabilities)
 local backupName=entry.path..".BeforeSource"
 if not backup:FindFirstChild(backupName) then
  local original=target:Clone() original.Name=backupName
  if original:IsA("BaseScript") then original.Enabled=false end
  original.Parent=backup
 end
 target.Source=entry.after.."\n"
 assert(normalize(target.Source)==entry.after,"Install mismatch "..entry.path)
 assert(tostring(target.Capabilities)==caps,"Capabilities changed "..entry.path)
 table.insert(report.scripts,{path=entry.path,bytes=#target.Source,capabilitiesPreserved=true})
end
return report
