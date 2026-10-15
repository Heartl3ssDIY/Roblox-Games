assert(not game.RunService:IsRunning(), "Edit mode required")
local changes={
{name="BritishBulldogService.luau",target=game.ServerScriptService.BritishBulldogService,before=[=[local Players = game:GetService("Players")
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

local BAT_SAMPLE_MAX_AGE = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - 0.0625 * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25 - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end

local function chaseGoal(bot, target)
	local delta = target.root.Position - bot.root.Position
	local velocity = target.root.AssemblyLinearVelocity
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * math.clamp(delta.Magnitude / 100, 0.08, 0.25)
	if lead.Magnitude > 4 then lead = lead.Unit * 4 end
	return target.root.Position + lead
end

local BAT_SWING_COOLDOWN = 0.75
local BAT_SWING_CONTACT_START = 0.10
local BAT_SWING_CONTACT_END = 0.38

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

function Service:_dodgeGrounded(record, params)
	local foot = record.humanoid.HipHeight + record.root.Size.Y * 0.5
	local leg = record.character:FindFirstChild("Left Leg")
	if leg then foot += leg.Size.Y end
	local hit = workspace:Raycast(record.root.Position, Vector3.new(0, -foot - 0.7, 0), params)
	return hit ~= nil and hit.Normal.Y > 0.45 and math.abs(record.root.AssemblyLinearVelocity.Y) < 12
end

function Service:_clipDodgeTravel(record, travel, params)
	local length = travel.Magnitude
	if length < 0.001 then return 0 end
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.CollisionGroup = params.CollisionGroup
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(CFrame.new(record.root.Position), Vector3.new(2.2, 3.4, 2.2), overlap) > 0 then return 0 end
	local origin = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local delta = self.bounds.CFrame:VectorToObjectSpace(travel)
	local half = self.bounds.Size * 0.5
	local lowerZ = self.northZ and self.northZ + 1.5 or -half.Z + 1.5
	local upperZ = self.southZ and self.southZ - 1.5 or half.Z - 1.5
	if math.abs(origin.X) > half.X - 1.5 or origin.Z < lowerZ or origin.Z > upperZ then return 0 end
	local fraction = 1
	if delta.X > 0 then fraction = math.min(fraction, (half.X - 1.5 - origin.X) / delta.X)
	elseif delta.X < 0 then fraction = math.min(fraction, (-half.X + 1.5 - origin.X) / delta.X) end
	if delta.Z > 0 then fraction = math.min(fraction, (upperZ - origin.Z) / delta.Z)
	elseif delta.Z < 0 then fraction = math.min(fraction, (lowerZ - origin.Z) / delta.Z) end
	local hit = workspace:Blockcast(CFrame.new(record.root.Position), Vector3.new(2.4, 3.6, 2.4), travel * math.clamp(fraction, 0, 1), params)
	if hit then fraction = math.min(fraction, math.max(0, hit.Distance - 0.18) / length) end
	return math.clamp(fraction, 0, 1)
end

function Service:_stopDodgeBurst(record, expected)
	local burst = expected or record.dodgeBurst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.dodgeBurst ~= burst then return end
	record.dodgeBurst = nil
	local root = burst.root
	if record.root ~= root or not root.Parent then return end
	local current = root.AssemblyLinearVelocity
	local excess = math.max(0, current:Dot(burst.direction))
	root.AssemblyLinearVelocity = current - burst.direction * excess
	if not record.frozen and not record.ragdoll then
		if record.humanoid == burst.humanoid and burst.humanoid.Parent then burst.humanoid.AutoRotate = burst.autoRotate end
		pcall(function()
			if burst.ownershipAuto then root:SetNetworkOwnershipAuto()
			else root:SetNetworkOwner(burst.owner and burst.owner.Parent == Players and burst.owner or nil) end
		end)
	end
end

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopDodgeBurst(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "BBDodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "BBDodgeVelocity", attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.ForceLimitsEnabled, velocity.ForceLimitMode = true, Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity, velocity.Parent = Vector2.new(initial.X, initial.Z), root
	local burst = {root=root,attachment=attachment,velocity=velocity,direction=direction,owner=owner,ownershipAuto=ownershipAuto,
		humanoid=record.humanoid,autoRotate=record.humanoid.AutoRotate,
		token=self.currentRound,crossing=self.crossingNumber,endsAt=now+duration}
	record.dodgeBurst = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or record.role ~= "Runner" or record.arrived or time >= burst.endsAt then self:_stopDodgeBurst(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_inside(self.bounds, root.Position) then self:_stopDodgeBurst(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
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
		then return { ok = false, message = "Dodge while crossing the field." } end
	if now < (record.dodgeReadyAt or 0) then return { ok = false, message = "Dodge is recharging." } end
	local right = self.bounds.CFrame.RightVector
	local direction = Vector3.new(right.X, 0, right.Z).Unit * value
	local params = self:_movementRayParameters()
	if not self:_dodgeGrounded(record, params) then return {ok=false,message="Dodge while on the ground."} end
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	local fraction = self:_clipDodgeTravel(record, travel, params)
	if distance * fraction < 0.75 then return {ok=false,message="No room to dodge."} end
	distance, forwardVelocity = distance * fraction, forwardVelocity * fraction
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + duration, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	if not self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params) then record.pendingEscape=nil return {ok=false,message="Your character cannot dodge yet."} end
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
	sampleBatSwing(record.batSwing, record, self.records, now)
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
				or swing.round ~= self.currentRound or swing.crossing ~= self.crossingNumber or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then
				attacker.batSwing = nil
			else
				local nearest, nearestDistance
				for _, runner in pairs(self.records) do
					if runner ~= attacker and runner.participating and alive(runner) and not runner.frozen and not runner.ragdoll
						and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local hit, distance = batContact(swing, attacker, runner, now, TAG_DISTANCE, rayParams)
						if hit and (not nearestDistance or distance < nearestDistance) then nearest, nearestDistance = runner, distance end
					end
				end
				if nearest and self:_caught(nearest, "Tagged", now, attacker) then attacker.batSwing = nil end
				if attacker.batSwing then
					if now >= swing.endsAt then attacker.batSwing = nil
					else sampleBatSwing(swing, attacker, self.records, now) end
				end
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
	self:_stopDodgeBurst(record)
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
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.1
			local target, chaseTarget
			if bot.role == "Runner" and not bot.arrived then
				target = self:_spawnCFrame(self.destination, bot.spawnIndex).Position
			elseif bot.role == "Bulldog" then
				local nearest = math.huge
				for _, runner in pairs(self.records) do
					if runner.participating and alive(runner) and not runner.ragdoll and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local distance = (runner.root.Position - bot.root.Position).Magnitude
						if distance < nearest then nearest, chaseTarget = distance, runner end
					end
				end
				if chaseTarget then
					local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, chaseTarget))
					local halfX = self.bounds.Size.X / 2 - 4
					target = self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -halfX, halfX), point.Y, math.clamp(point.Z, self.northZ + 4, self.southZ - 4)))
					if nearest <= TAG_DISTANCE + 0.75 then self:TryBatSwing(bot.player) end
				end
			end
			bot.sprintHeld = chaseTarget ~= nil and ((chaseTarget.root.Position - bot.root.Position).Magnitude > 12 or chaseTarget.root.AssemblyLinearVelocity.Magnitude > 19)
			bot.sprintLeaseEndsAt = bot.sprintHeld and now + 0.3 or 0
			self:_applyMovementSpeed(bot, now)
			if target then bot.humanoid:MoveTo(target)
			else bot.humanoid:MoveTo(bot.root.Position) bot.humanoid:Move(Vector3.zero) end
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

return Service

]=],after=[=[local Players = game:GetService("Players")
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

local BAT_SAMPLE_MAX_AGE = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - 0.0625 * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25 - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end

local function chaseGoal(bot, target)
	local delta = target.root.Position - bot.root.Position
	local velocity = target.root.AssemblyLinearVelocity
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * math.clamp(delta.Magnitude / 100, 0.08, 0.25)
	if lead.Magnitude > 4 then lead = lead.Unit * 4 end
	return target.root.Position + lead
end

local BAT_SWING_COOLDOWN = 0.75
local BAT_SWING_CONTACT_START = 0.10
local BAT_SWING_CONTACT_END = 0.38

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
		if record.sprintHeld and record.sprinting and now < (record.sprintLeaseEndsAt or 0) then
			multiplier = 1 + (self:_setting("SprintMultiplier", 2.5, 1) - 1) * (record.sprintFraction or 0)
		end
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
	record.sprintFraction = 0
	record.sprintLeaseEndsAt = 0
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

function Service:_dodgeGrounded(record, params)
	local foot = record.humanoid.HipHeight + record.root.Size.Y * 0.5
	local leg = record.character:FindFirstChild("Left Leg")
	if leg then foot += leg.Size.Y end
	local hit = workspace:Raycast(record.root.Position, Vector3.new(0, -foot - 0.7, 0), params)
	return hit ~= nil and hit.Normal.Y > 0.45 and math.abs(record.root.AssemblyLinearVelocity.Y) < 12
end

function Service:_clipDodgeTravel(record, travel, params)
	local length = travel.Magnitude
	if length < 0.001 then return 0 end
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.CollisionGroup = params.CollisionGroup
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(CFrame.new(record.root.Position), Vector3.new(2.2, 3.4, 2.2), overlap) > 0 then return 0 end
	local origin = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local delta = self.bounds.CFrame:VectorToObjectSpace(travel)
	local half = self.bounds.Size * 0.5
	local lowerZ = self.northZ and self.northZ + 1.5 or -half.Z + 1.5
	local upperZ = self.southZ and self.southZ - 1.5 or half.Z - 1.5
	if math.abs(origin.X) > half.X - 1.5 or origin.Z < lowerZ or origin.Z > upperZ then return 0 end
	local fraction = 1
	if delta.X > 0 then fraction = math.min(fraction, (half.X - 1.5 - origin.X) / delta.X)
	elseif delta.X < 0 then fraction = math.min(fraction, (-half.X + 1.5 - origin.X) / delta.X) end
	if delta.Z > 0 then fraction = math.min(fraction, (upperZ - origin.Z) / delta.Z)
	elseif delta.Z < 0 then fraction = math.min(fraction, (lowerZ - origin.Z) / delta.Z) end
	local hit = workspace:Blockcast(CFrame.new(record.root.Position), Vector3.new(2.4, 3.6, 2.4), travel * math.clamp(fraction, 0, 1), params)
	if hit then fraction = math.min(fraction, math.max(0, hit.Distance - 0.18) / length) end
	return math.clamp(fraction, 0, 1)
end

function Service:_stopDodgeBurst(record, expected)
	local burst = expected or record.dodgeBurst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.dodgeBurst ~= burst then return end
	record.dodgeBurst = nil
	local root = burst.root
	if record.root ~= root or not root.Parent then return end
	local current = root.AssemblyLinearVelocity
	local excess = math.max(0, current:Dot(burst.direction))
	root.AssemblyLinearVelocity = current - burst.direction * excess
	if not record.frozen and not record.ragdoll then
		if record.humanoid == burst.humanoid and burst.humanoid.Parent then burst.humanoid.AutoRotate = burst.autoRotate end
		pcall(function()
			if burst.ownershipAuto then root:SetNetworkOwnershipAuto()
			else root:SetNetworkOwner(burst.owner and burst.owner.Parent == Players and burst.owner or nil) end
		end)
	end
end

function Service:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopDodgeBurst(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "BBDodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "BBDodgeVelocity", attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.ForceLimitsEnabled, velocity.ForceLimitMode = true, Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity, velocity.Parent = Vector2.new(initial.X, initial.Z), root
	local burst = {root=root,attachment=attachment,velocity=velocity,direction=direction,owner=owner,ownershipAuto=ownershipAuto,
		humanoid=record.humanoid,autoRotate=record.humanoid.AutoRotate,
		token=self.currentRound,crossing=self.crossingNumber,endsAt=now+duration}
	record.dodgeBurst = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	setAttribute(record.player, "BBDodgeDirection", direction)
	setAttribute(record.player, "BBDodgeDuration", duration)
	setAttribute(record.player, "BBDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or self.crossingNumber ~= burst.crossing or self.phase ~= "Crossing"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or record.role ~= "Runner" or record.arrived or time >= burst.endsAt then self:_stopDodgeBurst(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_inside(self.bounds, root.Position) then self:_stopDodgeBurst(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
end

function Service:_updateMovement(record, dt, now)
	if not record.participating then return end
	dt = math.clamp(dt, 0, 0.25)
	self:_sprintCapacity(record)
	if record.sprintHeld and now >= (record.sprintLeaseEndsAt or 0) then self:_releaseSprint(record) end
	local allowed = self:_movementAllowed(record, now)
	if not allowed then self:_releaseSprint(record) end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = allowed and record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	record.sprintFraction = 0
	if record.sprinting then
		record.sprintFraction = math.min(1, record.sprintRemaining / math.max(dt, 0.0001))
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	elseif record.sprintRemaining <= 0 or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
	end
	record.sprintExhausted = record.sprintRemaining <= 0
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
	if action == "Dodge" then return { ok = false, message = "Dodge is temporarily disabled." } end
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
		then return { ok = false, message = "Dodge while crossing the field." } end
	if now < (record.dodgeReadyAt or 0) then return { ok = false, message = "Dodge is recharging." } end
	local right = self.bounds.CFrame.RightVector
	local direction = Vector3.new(right.X, 0, right.Z).Unit * value
	local params = self:_movementRayParameters()
	if not self:_dodgeGrounded(record, params) then return {ok=false,message="Dodge while on the ground."} end
	local duration = math.clamp(self:_setting("DodgeDurationSeconds", 0.32, 0.2), 0.2, 0.5)
	local distance = math.clamp(self:_setting("DodgeDistance", 8, 3), 3, 10)
	local look = self.bounds.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local forwardSpeed = math.clamp(record.root.AssemblyLinearVelocity:Dot(forward), -record.humanoid.WalkSpeed, record.humanoid.WalkSpeed)
	local forwardVelocity = forward * forwardSpeed
	local travel = direction * distance + forwardVelocity * duration
	local fraction = self:_clipDodgeTravel(record, travel, params)
	if distance * fraction < 0.75 then return {ok=false,message="No room to dodge."} end
	distance, forwardVelocity = distance * fraction, forwardVelocity * fraction
	local threatened = self:_threat(record, params)
	if threatened then
		record.pendingEscape = { checkAt = now + duration, token = self.currentRound, crossing = self.crossingNumber,
			character = record.character, startPosition = record.root.Position }
	end
	if not self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params) then record.pendingEscape=nil return {ok=false,message="Your character cannot dodge yet."} end
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
	sampleBatSwing(record.batSwing, record, self.records, now)
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
				or swing.round ~= self.currentRound or swing.crossing ~= self.crossingNumber or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then
				attacker.batSwing = nil
			else
				local nearest, nearestDistance
				for _, runner in pairs(self.records) do
					if runner ~= attacker and runner.participating and alive(runner) and not runner.frozen and not runner.ragdoll
						and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local hit, distance = batContact(swing, attacker, runner, now, TAG_DISTANCE, rayParams)
						if hit and (not nearestDistance or distance < nearestDistance) then nearest, nearestDistance = runner, distance end
					end
				end
				if nearest and self:_caught(nearest, "Tagged", now, attacker) then attacker.batSwing = nil end
				if attacker.batSwing then
					if now >= swing.endsAt then attacker.batSwing = nil
					else sampleBatSwing(swing, attacker, self.records, now) end
				end
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
	self:_stopDodgeBurst(record)
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
	if alive(record) and self:_outcome() == "Runners" then return false end
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
	if record.role ~= "Runner" or (self.endsAt > 0 and now >= self.endsAt) or self:_outcome() == "Runners" then
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
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.1
			local target, chaseTarget
			if bot.role == "Runner" and not bot.arrived then
				target = self:_spawnCFrame(self.destination, bot.spawnIndex).Position
			elseif bot.role == "Bulldog" then
				local nearest = math.huge
				for _, runner in pairs(self.records) do
					if runner.participating and alive(runner) and not runner.ragdoll and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
						local distance = (runner.root.Position - bot.root.Position).Magnitude
						if distance < nearest then nearest, chaseTarget = distance, runner end
					end
				end
				if chaseTarget then
					local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, chaseTarget))
					local halfX = self.bounds.Size.X / 2 - 4
					target = self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -halfX, halfX), point.Y, math.clamp(point.Z, self.northZ + 4, self.southZ - 4)))
					if nearest <= TAG_DISTANCE + 0.75 then self:TryBatSwing(bot.player) end
				end
			end
			bot.sprintHeld = chaseTarget ~= nil and ((chaseTarget.root.Position - bot.root.Position).Magnitude > 12 or chaseTarget.root.AssemblyLinearVelocity.Magnitude > 19)
			bot.sprintLeaseEndsAt = bot.sprintHeld and now + 0.3 or 0
			self:_applyMovementSpeed(bot, now)
			if target then bot.humanoid:MoveTo(target)
			else bot.humanoid:MoveTo(bot.root.Position) bot.humanoid:Move(Vector3.zero) end
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
			self:_sprintCapacity(record)
			record.sprintRemaining = record.sprintMax
			record.sprintExhausted = false
			self:_releaseSprint(record)
			self:_publishMovement(record)
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
	local lastRunnerWins = false
	if self.mode == "Round" and (self.initialRunnerCount or 0) > 1 and runners == 1 then
		for _, record in pairs(self.records) do
			if record.participating and record.role == "Runner" and alive(record) then
				lastRunnerWins = true
				break
			end
		end
	end
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt, lastRunnerWins)
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
	local departureSeconds = self:_setting("DepartureSeconds", 10, 0.1)
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
		if record.participating then
			if record.role == "Tagged" or record.pendingBulldog then
				record.pendingBulldog = false
				self:_setRole(record, "Bulldog", "Bulldog")
			end
			if record.role == "Bulldog" then
				if alive(record) then self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex)) end
				self:_unfreeze(record)
			end
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
			end
			if record.role == "Bulldog" and alive(record) then
				self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex))
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
	self.initialRunnerCount = self:_counts()
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
				local untilTime = workspace:GetServerTimeNow() + self:_setting("IntermissionSeconds", 35, 0)
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
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", PracticeOwnerUserId = 0, EndsAt = 0, RoundDuration = self:_setting("RoundDuration", 180, 1), CountdownValue = 0, RunnerCount = 0, BulldogCount = 0, CrossingNumber = 0, RoundNumber = 0, WinnerTeam = "", WinnersText = "", Destination = "South", DepartureSeconds = self:_setting("DepartureSeconds", 10, 0.1), IntermissionEndsAt = 0 }) do
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


]=]},
{name="BritishBulldogRules.luau",target=game.ServerScriptService.BritishBulldogRules,before=[=[local Rules = {}

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
]=],after=[=[local Rules = {}

function Rules.IsInside(x, y, z, halfX, halfY, halfZ)
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

function Rules.DepartureExpired(mustLeave, deadline, now)
	return mustLeave and deadline > 0 and now >= deadline
end

function Rules.CrossingResolved(unresolvedRunners)
	return unresolvedRunners == 0
end

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut, lastRunnerWins)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if lastRunnerWins or timedOut or bulldogs + tagged == 0 then
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

]=]},
{name="BritishBulldogHUD.MovementController.luau",target=game.StarterGui.BritishBulldogHUD.MovementController,before=[=[local Players=game:GetService("Players")
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
local sprintSerial=0
local requestedHeld=false
local dodgeBusy=false
local dodgeSerial=0
local dodgeNoticeUntil=0
local dodgeNotice=""
local lastDodgeDirection=1
local jumpHumanoid=nil
local jumpWasEnabled=nil
local jumpBound=false
local jumpActionName="BritishBulldogNoJump"
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

local function releaseJumpLock()
 if jumpHumanoid and jumpHumanoid.Parent and jumpWasEnabled~=nil then
  jumpHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,jumpWasEnabled)
 end
 jumpHumanoid=nil
 jumpWasEnabled=nil
 if jumpBound then ContextActionService:UnbindAction(jumpActionName) jumpBound=false end
end

local function syncJumpLock()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not alive or player:GetAttribute("BBParticipating")~=true or not humanoid then releaseJumpLock() return end
 if jumpHumanoid~=humanoid then
  releaseJumpLock()
  jumpHumanoid=humanoid
  jumpWasEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
 end
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 humanoid.Jump=false
 if not jumpBound then
  ContextActionService:BindActionAtPriority(jumpActionName,function()
   if alive and player:GetAttribute("BBParticipating")==true then return Enum.ContextActionResult.Sink end
   return Enum.ContextActionResult.Pass
  end,false,3000,Enum.PlayerActions.CharacterJump)
  jumpBound=true
 end
end

local function canSprint()
 local role=player:GetAttribute("BBRole")
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return inputContext() and phase()=="Crossing" and (role=="Runner" or role=="Bulldog")
  and player:GetAttribute("BBStatus")~="Safe" and player:GetAttribute("BBRagdolled")~=true and humanoid and humanoid.Health>0
end

local function requestSprint(value)
 requestPending=value==true
 if requestRunning or not alive then return end
 requestRunning=true sprintSerial+=1
 local serial=sprintSerial
 local worker=task.spawn(function()
  while requestPending~=nil and alive and serial==sprintSerial do
   local held=requestPending
   requestPending=nil
   local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
   if remote and remote:IsA("RemoteFunction") then
    pcall(function() remote:InvokeServer("Sprint",held) end)
   end
  end
  if serial==sprintSerial then requestRunning=false end
 end)
 task.delay(2,function()
  if serial==sprintSerial and requestRunning then sprintSerial+=1 requestRunning=false requestPending=nil pcall(task.cancel,worker) end
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

local function requestDodge()
 if dodgeBusy or not canSprint() or player:GetAttribute("BBRole")~="Runner" then return end
 if player:GetAttribute("BBStatus")~="Crossing" then return end
 if workspace:GetServerTimeNow()<numberAttribute(player,"BBDodgeReadyAt",0) then return end
 local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 dodgeBusy=true
 dodgeSerial+=1
 local serial=dodgeSerial
 lastDodgeDirection=dodgeDirection()
 local worker=task.spawn(function()
  local success,response=pcall(function() return remote:InvokeServer("Dodge",lastDodgeDirection) end)
  if not alive or serial~=dodgeSerial then return end
  dodgeBusy=false
  if not success or typeof(response)~="table" or not response.ok then
   dodgeNotice=success and typeof(response)=="table" and tostring(response.message or "TRY AGAIN") or "TRY AGAIN"
   dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
 task.delay(2,function()
  if serial==dodgeSerial and dodgeBusy then
   dodgeSerial+=1 dodgeBusy=false
   pcall(task.cancel,worker)
   dodgeNotice="TRY AGAIN" dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
end

local function refresh()
 syncJumpLock()
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
 dodge.Caption.Text=workspace:GetServerTimeNow()<dodgeNoticeUntil and ("DODGE\n"..dodgeNotice) or cooldown>0 and string.format("DODGE\n%.1fs",cooldown) or UserInputService.TouchEnabled and "DODGE\nTAP" or "DODGE\n[E]"
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
connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() end)
connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() syncJumpLock() end)
connect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)
connect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)
connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then
  elapsed=0
  refresh()
 end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 releaseHold()
 alive=false
 dodgeSerial+=1 sprintSerial+=1
 releaseJumpLock()
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]=],after=[=[local Players=game:GetService("Players")
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
local dodgeEnabled=false
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
local sprintSerial=0
local requestedHeld=false
local dodgeBusy=false
local dodgeSerial=0
local dodgeNoticeUntil=0
local dodgeNotice=""
local lastDodgeDirection=1
local jumpHumanoid=nil
local jumpWasEnabled=nil
local jumpBound=false
local jumpActionName="BritishBulldogNoJump"
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

local function releaseJumpLock()
 if jumpHumanoid and jumpHumanoid.Parent and jumpWasEnabled~=nil then
  jumpHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,jumpWasEnabled)
 end
 jumpHumanoid=nil
 jumpWasEnabled=nil
 if jumpBound then ContextActionService:UnbindAction(jumpActionName) jumpBound=false end
end

local function syncJumpLock()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not alive or player:GetAttribute("BBParticipating")~=true or not humanoid then releaseJumpLock() return end
 if jumpHumanoid~=humanoid then
  releaseJumpLock()
  jumpHumanoid=humanoid
  jumpWasEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
 end
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 humanoid.Jump=false
 if not jumpBound then
  ContextActionService:BindActionAtPriority(jumpActionName,function()
   if alive and player:GetAttribute("BBParticipating")==true then return Enum.ContextActionResult.Sink end
   return Enum.ContextActionResult.Pass
  end,false,3000,Enum.PlayerActions.CharacterJump)
  jumpBound=true
 end
end

local function canSprint()
 local role=player:GetAttribute("BBRole")
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return inputContext() and phase()=="Crossing" and (role=="Runner" or role=="Bulldog")
  and player:GetAttribute("BBStatus")~="Safe" and player:GetAttribute("BBRagdolled")~=true and humanoid and humanoid.Health>0
end

local function requestSprint(value)
 requestPending=value==true
 if requestRunning or not alive then return end
 requestRunning=true sprintSerial+=1
 local serial=sprintSerial
 local worker=task.spawn(function()
  while requestPending~=nil and alive and serial==sprintSerial do
   local held=requestPending
   requestPending=nil
   local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
   if remote and remote:IsA("RemoteFunction") then
    pcall(function() remote:InvokeServer("Sprint",held) end)
   end
  end
  if serial==sprintSerial then requestRunning=false end
 end)
 task.delay(2,function()
  if serial==sprintSerial and requestRunning then sprintSerial+=1 requestRunning=false requestPending=nil pcall(task.cancel,worker) end
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
 return Enum.ContextActionResult.Pass
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

local function requestDodge()
 if not dodgeEnabled then return end
 if dodgeBusy or not canSprint() or player:GetAttribute("BBRole")~="Runner" then return end
 if player:GetAttribute("BBStatus")~="Crossing" then return end
 if workspace:GetServerTimeNow()<numberAttribute(player,"BBDodgeReadyAt",0) then return end
 local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 dodgeBusy=true
 dodgeSerial+=1
 local serial=dodgeSerial
 lastDodgeDirection=dodgeDirection()
 local worker=task.spawn(function()
  local success,response=pcall(function() return remote:InvokeServer("Dodge",lastDodgeDirection) end)
  if not alive or serial~=dodgeSerial then return end
  dodgeBusy=false
  if not success or typeof(response)~="table" or not response.ok then
   dodgeNotice=success and typeof(response)=="table" and tostring(response.message or "TRY AGAIN") or "TRY AGAIN"
   dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
 task.delay(2,function()
  if serial==dodgeSerial and dodgeBusy then
   dodgeSerial+=1 dodgeBusy=false
   pcall(task.cancel,worker)
   dodgeNotice="TRY AGAIN" dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
end

local function refresh()
 syncJumpLock()
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
 sprint.Caption.Text=(player:GetAttribute("BBSprinting")==true and "SPRINTING" or exhausted and "RECHARGING" or "SPRINT").."\n"..holdHint
 sprint.AutoButtonColor=canSprint()==true
 dodge.Visible=false
 dodge.Active=false
 dodge.Interactable=false
 boost.Visible=role=="Runner" and numberAttribute(player,"BBBoostEndsAt",0)>workspace:GetServerTimeNow()
 local cooldown=math.max(0,numberAttribute(player,"BBDodgeReadyAt",0)-workspace:GetServerTimeNow())
 dodge.Caption.Text=workspace:GetServerTimeNow()<dodgeNoticeUntil and ("DODGE\n"..dodgeNotice) or cooldown>0 and string.format("DODGE\n%.1fs",cooldown) or UserInputService.TouchEnabled and "DODGE\nTAP" or "DODGE\n[E]"
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
connect(UserInputService.WindowFocusReleased,function() focused=false releaseHold() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,releaseHold)
connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() end)
connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() syncJumpLock() end)
connect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)
connect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)
connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then
  elapsed=0
  refresh()
 end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 releaseHold()
 alive=false
 dodgeSerial+=1 sprintSerial+=1
 releaseJumpLock()
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()


]=]},
{name="StuckInTheMudService.luau",target=game.ServerScriptService.StuckInTheMudService,before=[=[local Players = game:GetService("Players")
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
	if release then record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = false, nil, nil, 0 end
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

function Service:_resolveAim(record, kind, aim)
	if typeof(aim) == "Vector3" then
		local unit = direction(aim)
		if not unit then return nil end
		return unit, self:_origin(record, kind, unit)
	end
	if typeof(aim) ~= "table" then return nil end
	local cameraOrigin, unit = aim.cameraOrigin, direction(aim.cameraDirection)
	if not unit or typeof(cameraOrigin) ~= "Vector3" or cameraOrigin.X ~= cameraOrigin.X or cameraOrigin.Y ~= cameraOrigin.Y
		or cameraOrigin.Z ~= cameraOrigin.Z or math.abs(cameraOrigin.X) == math.huge or math.abs(cameraOrigin.Y) == math.huge
		or math.abs(cameraOrigin.Z) == math.huge then return nil end
	local head = record.character:FindFirstChild("Head") or record.root
	if (cameraOrigin - head.Position).Magnitude > 24 then return nil end
	if workspace:Raycast(head.Position, cameraOrigin - head.Position, self:_rayParameters(record, true)) then return nil end
	local origin = self:_origin(record, kind, unit)
	if not origin then return nil end
	local hit = workspace:Raycast(cameraOrigin, unit * 500, self:_rayParameters(record, false))
	local point = hit and hit.Position or cameraOrigin + unit * 500
	return direction(point - origin), origin
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local unit, origin = self:_resolveAim(record, "Mud", aim) if not unit or not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = unit, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
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
	local unit, origin = self:_resolveAim(record, "Heat", record.heatAim or record.heatDirection) if not unit or not origin then return nil end
	local hit = workspace:Raycast(origin, unit * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
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
	if action == "Fire" then return { ok = self:_fire(record, value, now), message = "Mud shot." } end
	local unit, origin = self:_resolveAim(record, "Heat", aim)
	if value ~= true or not unit or not origin then return { ok = false, message = "Equip the Heat Gun and aim toward the playground." } end
	record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = true, unit, typeof(aim) == "table" and aim or nil, now + 1
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

return Service

]=],after=[=[local Players = game:GetService("Players")
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

function Service.TeamAssignments(count)
	if count < 2 then return {}, 0 end
	local result = {}
	for index = 1, count do result[index] = (index - 1) % 2 + 1 end
	return result, 2
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
	self.spawnCache = self.spawnCache or {}
	local cache = self.spawnCache[team]
	if not cache then
		local pads = {}
		local groupCount = #self.teamSpawns
		if groupCount > 0 then
			local first = math.floor((team - 1) * groupCount / self.teamCount) + 1
			local last = math.max(first, math.floor(team * groupCount / self.teamCount))
			for group = first, math.min(last, groupCount) do
				for _, pad in ipairs(parts(self.teamSpawns[group])) do table.insert(pads, pad) end
			end
		end
		if #pads == 0 then
			for padIndex, pad in ipairs(self.spawnPads) do
				if (padIndex - 1) % self.teamCount + 1 == team then table.insert(pads, pad) end
			end
		end
		if #pads == 0 then pads = self.spawnPads end
		cache = { pads = pads, positions = {}, nextCandidate = 1 }
		self.spawnCache[team] = cache
	end
	local params = self:_rayParameters(nil, true)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	local half = self.bounds.Size * 0.5
	local attempts = 0
	while #cache.positions < index and attempts < #cache.pads * 16 do
		local candidateIndex = cache.nextCandidate
		cache.nextCandidate += 1
		attempts += 1
		local pad = cache.pads[(candidateIndex - 1) % #cache.pads + 1]
		local row = math.floor((candidateIndex - 1) / #cache.pads)
		local inward = Vector3.new(self.bounds.Position.X - pad.Position.X, 0, self.bounds.Position.Z - pad.Position.Z)
		local position = pad.Position + (inward.Magnitude > 0 and inward.Unit or Vector3.zero) * row * 24
		local point = self.bounds.CFrame:PointToObjectSpace(position)
		local clear = math.abs(point.X) < half.X - 4 and math.abs(point.Z) < half.Z - 4
		if clear and row > 0 then
			local floor = workspace:Raycast(position, Vector3.new(0, -8, 0), params)
			clear = floor ~= nil and floor.Normal.Y > 0.8 and position.Y - floor.Position.Y >= 2.8
		end
		if clear then clear = #workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(4, 5, 4), overlap) == 0 end
		if clear then
			for _, previous in ipairs(cache.positions) do
				if (position - previous).Magnitude < 5 then clear = false break end
			end
		end
		if clear then table.insert(cache.positions, position) end
	end
	local position = cache.positions[index] or cache.pads[(index - 1) % #cache.pads + 1].Position
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
	local multiplier = 1
	if not record.frozen and record.sprinting and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) then
		multiplier += (self:_setting("SprintMultiplier", 2.5, 1) - 1) * (record.sprintFraction or 1)
	end
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
	if release then record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = false, nil, nil, 0 end
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

function Service:_resolveAim(record, kind, aim)
	if typeof(aim) == "Vector3" then
		local unit = direction(aim)
		if not unit then return nil end
		return unit, self:_origin(record, kind, unit)
	end
	if typeof(aim) ~= "table" then return nil end
	local cameraOrigin, unit = aim.cameraOrigin, direction(aim.cameraDirection)
	if not unit or typeof(cameraOrigin) ~= "Vector3" or cameraOrigin.X ~= cameraOrigin.X or cameraOrigin.Y ~= cameraOrigin.Y
		or cameraOrigin.Z ~= cameraOrigin.Z or math.abs(cameraOrigin.X) == math.huge or math.abs(cameraOrigin.Y) == math.huge
		or math.abs(cameraOrigin.Z) == math.huge then return nil end
	local head = record.character:FindFirstChild("Head") or record.root
	if (cameraOrigin - head.Position).Magnitude > 24 then return nil end
	if workspace:Raycast(head.Position, cameraOrigin - head.Position, self:_rayParameters(record, true)) then return nil end
	local origin = self:_origin(record, kind, unit)
	if not origin then return nil end
	local hit = workspace:Raycast(cameraOrigin, unit * 500, self:_rayParameters(record, false))
	local point = hit and hit.Position or cameraOrigin + unit * 500
	return direction(point - origin), origin
end

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local unit, origin = self:_resolveAim(record, "Mud", aim) if not unit or not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = unit, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
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
	local unit, origin = self:_resolveAim(record, "Heat", record.heatAim or record.heatDirection) if not unit or not origin then return nil end
	local hit = workspace:Raycast(origin, unit * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
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
	record.sprinting = record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	record.sprintFraction = record.sprinting and math.min(1, record.sprintRemaining / math.max(dt, 0.0001)) or 0
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) end
	record.sprintExhausted = record.sprintRemaining <= 0
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
	if action == "Fire" then return { ok = self:_fire(record, value, now), message = "Mud shot." } end
	local unit, origin = self:_resolveAim(record, "Heat", aim)
	if value ~= true or not unit or not origin then return { ok = false, message = "Equip the Heat Gun and aim toward the playground." } end
	record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = true, unit, typeof(aim) == "table" and aim or nil, now + 1
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
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants) end
	self.spawnCache = nil
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
	local minimum = math.floor(self:_setting("MinimumPlayers", 2, 2))
	if #participants < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
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

return Service

]=]},
{name="MudHUD.Controller.luau",target=game.StarterGui.MudHUD.Controller,before=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
main.Visible=false
local controls=UserInputService.TouchEnabled and main.Controls or (main:FindFirstChild("DesktopControls") or main.Controls)
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  sprintKeys[input.KeyCode]=true sprintChange()
 end
 return Enum.ContextActionResult.Sink
end
local function aimViewportPoint(camera)
 local deviceArea=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local point=camera.ViewportSize*0.5
 if UserInputService.PreferredInput==Enum.PreferredInput.KeyboardAndMouse and UserInputService.MouseBehavior~=Enum.MouseBehavior.LockCenter then
  local fullArea=GuiService:GetInsetArea(Enum.ScreenInsets.None)
  point=UserInputService:GetMouseLocation()-(deviceArea.Min-fullArea.Min)
 end
 point=Vector2.new(math.clamp(point.X,0,camera.ViewportSize.X),math.clamp(point.Y,0,camera.ViewportSize.Y))
 return point,point+deviceArea.Min
end
local function updateCrosshair()
 local camera=workspace.CurrentCamera
 if not camera or not main.Crosshair.Visible then return end
 local _,screenPoint=aimViewportPoint(camera)
 local offset=screenPoint-main.AbsolutePosition
 local size=main.AbsoluteSize
 if size.X>0 and size.Y>0 then main.Crosshair.Position=UDim2.fromScale(offset.X/size.X,offset.Y/size.Y) end
end
local function aimRay()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local point=aimViewportPoint(camera)
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 return {cameraOrigin=ray.Origin,cameraDirection=ray.Direction}
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=focused and playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimRay()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
RunService:BindToRenderStep("MudAimReticle",Enum.RenderPriority.Camera.Value+1,updateCrosshair)
connect(script.Destroying,function()
 release()
 RunService:UnbindFromRenderStep("MudAimReticle")
 if binding then ContextActionService:UnbindAction("MudControls") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()

]=],after=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
main.Visible=false
local controls=UserInputService.TouchEnabled and main.Controls or (main:FindFirstChild("DesktopControls") or main.Controls)
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  sprintKeys[input.KeyCode]=true sprintChange()
 end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then return Enum.ContextActionResult.Pass end
 return Enum.ContextActionResult.Sink
end
local function aimViewportPoint(camera)
 local deviceArea=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local point=camera.ViewportSize*0.5
 if UserInputService.PreferredInput==Enum.PreferredInput.KeyboardAndMouse and UserInputService.MouseBehavior~=Enum.MouseBehavior.LockCenter then
  local fullArea=GuiService:GetInsetArea(Enum.ScreenInsets.None)
  point=UserInputService:GetMouseLocation()-(deviceArea.Min-fullArea.Min)
 end
 point=Vector2.new(math.clamp(point.X,0,camera.ViewportSize.X),math.clamp(point.Y,0,camera.ViewportSize.Y))
 return point,point+deviceArea.Min
end
local function updateCrosshair()
 local camera=workspace.CurrentCamera
 if not camera or not main.Crosshair.Visible then return end
 local _,screenPoint=aimViewportPoint(camera)
 local offset=screenPoint-main.AbsolutePosition
 local size=main.AbsoluteSize
 if size.X>0 and size.Y>0 then main.Crosshair.Position=UDim2.fromScale(offset.X/size.X,offset.Y/size.Y) end
end
local function aimRay()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local point=aimViewportPoint(camera)
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 return {cameraOrigin=ray.Origin,cameraDirection=ray.Direction}
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=focused and playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimRay()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
RunService:BindToRenderStep("MudAimReticle",Enum.RenderPriority.Camera.Value+1,updateCrosshair)
connect(script.Destroying,function()
 release()
 RunService:UnbindFromRenderStep("MudAimReticle")
 if binding then ContextActionService:UnbindAction("MudControls") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()

]=]},
{name="PlaygroundCoordinator.luau",target=game.ServerScriptService.PlaygroundCoordinator,before=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud" }

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
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id=="StuckInTheMud" and 4 or 2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }
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
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
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
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
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
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds, { gameId = "BritishBulldog" })
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "TagYoureIt" })
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{gameId="StuckInTheMud",winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
		local readyCount=#self:_readyPlayers()
		self:_availability(readyCount)
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
		elseif readyCount < 2 then
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
		self:_padVoting()
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
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Coordinator



]=],after=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud" }

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
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }
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
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
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
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
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
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds, { gameId = "BritishBulldog" })
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants, { gameId = "TagYoureIt" })
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{gameId="StuckInTheMud",winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
		local readyCount=#self:_readyPlayers()
		self:_availability(readyCount)
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
		elseif readyCount < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			local intermission = self.lobby:GetAttribute("IntermissionSeconds")
			if typeof(intermission) ~= "number" or intermission ~= intermission or math.abs(intermission) == math.huge then intermission = 35 end
			self.votingEndsAt = now + math.max(1, intermission)
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
		self:_padVoting()
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
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Coordinator



]=]},
{name="TagSprintService.luau",target=game.ServerScriptService.TagSprintService,before=[=[local Players=game:GetService("Players")
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

return Service

]=],after=[=[local Players=game:GetService("Players")
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
   local sprinting=canMove and entry.held and entry.remaining>0 and moving
   local sprintFraction=sprinting and math.min(1,entry.remaining/math.max(delta,0.00001)) or 0
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
   end
   entry.locked=entry.remaining<=0
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=(record.frozen or record.ragdoll or player:GetAttribute("TGRagdolled")==true) and 0 or base*(1+(self:_setting("SprintMultiplier",2.5,1)-1)*sprintFraction)
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

return Service

]=]},
{name="TagHUD.SprintController.luau",target=game.StarterGui.TagHUD.SprintController,before=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("SprintPanel")
local state=ReplicatedStorage:WaitForChild("TagState")
local remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
local keys={}
local touch
local held=false
local focused=true
local bound=false
local pending
local sending=false
local requestSerial=0
local alive=true
local elapsed=0
local lease=0
local connections={}
local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function active()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("TGParticipating")==true and player:GetAttribute("TGRagdolled")~=true and state:GetAttribute("Phase")=="Playing" and humanoid and humanoid.Health>0
end
local function inputContext()
 local phase=state:GetAttribute("Phase")
 return player:GetAttribute("TGParticipating")==true and (phase=="Playing" or phase=="Countdown")
end
local function request(value)
 pending=value
 if sending or not alive then return end
 sending=true requestSerial+=1
 local serial=requestSerial
 local worker=task.spawn(function()
  while pending~=nil and alive and serial==requestSerial do
   local value=pending pending=nil
   pcall(function() remote:InvokeServer(value) end)
  end
  if serial==requestSerial then sending=false end
 end)
 task.delay(2,function()
  if serial==requestSerial and sending then requestSerial+=1 sending=false pending=nil pcall(task.cancel,worker) end
 end)
end
local function updateHold()
 local value=focused and active() and (next(keys)~=nil or touch~=nil)
 if value~=held then held=value request(value) lease=os.clock() end
end
local function release()
 table.clear(keys) touch=nil
 if held then held=false request(false) end
end
local function action(_,phase,input)
 if not inputContext() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then keys[input.KeyCode]=nil
 elseif phase==Enum.UserInputState.Begin and focused and not UserInputService:GetFocusedTextBox() then keys[input.KeyCode]=true end
 updateHold()
 return Enum.ContextActionResult.Sink
end
local function progress(fraction)
 local gradient=panel.Meter.Track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local point=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(point-0.0001,0),NumberSequenceKeypoint.new(point+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function refresh()
 local participating=player:GetAttribute("TGParticipating")==true
 local phase=state:GetAttribute("Phase")
 panel.Visible=participating and (phase=="Playing" or phase=="Countdown")
 if inputContext() and not bound then ContextActionService:BindActionAtPriority("TagSprint",action,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift) bound=true
 elseif not inputContext() and bound then ContextActionService:UnbindAction("TagSprint") bound=false release() end
 if not panel.Visible then release() return end
 local maximum=player:GetAttribute("TGSprintMax") or 10
 local remaining=math.clamp(player:GetAttribute("TGSprintRemaining") or maximum,0,maximum)
 local tagger=player:GetAttribute("TGRole")=="Tagger"
 local color=tagger and Color3.fromRGB(255,81,92) or Color3.fromRGB(42,160,255)
 panel.Meter.Role.Text=tagger and "YOU'RE IT!" or "RUNNER"
 panel.Meter.Time.Text=string.format("IT: %.1fs",player:GetAttribute("TGTaggerSeconds") or 0)
 panel.Meter.Charge.Text=string.format("%.1fs / %ds",remaining,maximum)
 panel.Meter.Track.Fill.BackgroundColor3=color
 panel.Sprint.BackgroundColor3=color
 local caption=player:GetAttribute("TGSprintExhausted") and "RECHARGING" or player:GetAttribute("TGSprinting") and "SPRINTING" or "SPRINT"
 panel.Sprint.Text=caption.."\n"..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT")
 panel.Sprint.AutoButtonColor=active()
 progress(remaining/math.max(maximum,0.1))
 updateHold()
end
connect(panel.Sprint.InputBegan,function(input)
 if focused and active() and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then touch=input updateHold() end
end)
connect(UserInputService.InputEnded,function(input)
 if input==touch then touch=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then keys[input.KeyCode]=nil end
 updateHold()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touch and input.UserInputState==Enum.UserInputState.Cancel then touch=nil updateHold() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(player.CharacterRemoving,release)
connect(player.CharacterAdded,release)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then elapsed=0 refresh() end
 if held and os.clock()-lease>=0.3 then lease=os.clock() request(true) end
end)
connect(script.Destroying,function()
 release()
 alive=false requestSerial+=1
 if bound then ContextActionService:UnbindAction("TagSprint") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]=],after=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("SprintPanel")
local state=ReplicatedStorage:WaitForChild("TagState")
local remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
local keys={}
local touch
local held=false
local focused=true
local bound=false
local pending
local sending=false
local requestSerial=0
local alive=true
local elapsed=0
local lease=0
local connections={}
local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function active()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("TGParticipating")==true and player:GetAttribute("TGRagdolled")~=true and state:GetAttribute("Phase")=="Playing" and humanoid and humanoid.Health>0
end
local function inputContext()
 local phase=state:GetAttribute("Phase")
 return player:GetAttribute("TGParticipating")==true and (phase=="Playing" or phase=="Countdown")
end
local function request(value)
 pending=value
 if sending or not alive then return end
 sending=true requestSerial+=1
 local serial=requestSerial
 local worker=task.spawn(function()
  while pending~=nil and alive and serial==requestSerial do
   local value=pending pending=nil
   pcall(function() remote:InvokeServer(value) end)
  end
  if serial==requestSerial then sending=false end
 end)
 task.delay(2,function()
  if serial==requestSerial and sending then requestSerial+=1 sending=false pending=nil pcall(task.cancel,worker) end
 end)
end
local function updateHold()
 local value=focused and active() and (next(keys)~=nil or touch~=nil)
 if value~=held then held=value request(value) lease=os.clock() end
end
local function release()
 table.clear(keys) touch=nil
 if held then held=false request(false) end
end
local function action(_,phase,input)
 if not inputContext() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then keys[input.KeyCode]=nil
 elseif phase==Enum.UserInputState.Begin and focused and not UserInputService:GetFocusedTextBox() then keys[input.KeyCode]=true end
 updateHold()
 return Enum.ContextActionResult.Pass
end
local function progress(fraction)
 local gradient=panel.Meter.Track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local point=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(point-0.0001,0),NumberSequenceKeypoint.new(point+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function refresh()
 local participating=player:GetAttribute("TGParticipating")==true
 local phase=state:GetAttribute("Phase")
 panel.Visible=participating and (phase=="Playing" or phase=="Countdown")
 if inputContext() and not bound then ContextActionService:BindActionAtPriority("TagSprint",action,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift) bound=true
 elseif not inputContext() and bound then ContextActionService:UnbindAction("TagSprint") bound=false release() end
 if not panel.Visible then release() return end
 local maximum=player:GetAttribute("TGSprintMax") or 10
 local remaining=math.clamp(player:GetAttribute("TGSprintRemaining") or maximum,0,maximum)
 local tagger=player:GetAttribute("TGRole")=="Tagger"
 local color=tagger and Color3.fromRGB(255,81,92) or Color3.fromRGB(42,160,255)
 panel.Meter.Role.Text=tagger and "YOU'RE IT!" or "RUNNER"
 panel.Meter.Time.Text=string.format("IT: %.1fs",player:GetAttribute("TGTaggerSeconds") or 0)
 panel.Meter.Charge.Text=string.format("%.1fs / %ds",remaining,maximum)
 panel.Meter.Track.Fill.BackgroundColor3=color
 panel.Sprint.BackgroundColor3=color
 local caption=player:GetAttribute("TGSprinting") and "SPRINTING" or player:GetAttribute("TGSprintExhausted") and "RECHARGING" or "SPRINT"
 panel.Sprint.Text=caption.."\n"..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT")
 panel.Sprint.AutoButtonColor=active()
 progress(remaining/math.max(maximum,0.1))
 updateHold()
end
connect(panel.Sprint.InputBegan,function(input)
 if focused and active() and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then touch=input updateHold() end
end)
connect(UserInputService.InputEnded,function(input)
 if input==touch then touch=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then keys[input.KeyCode]=nil end
 updateHold()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touch and input.UserInputState==Enum.UserInputState.Cancel then touch=nil updateHold() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(player.CharacterRemoving,release)
connect(player.CharacterAdded,release)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then elapsed=0 refresh() end
 if held and os.clock()-lease>=0.3 then lease=os.clock() request(true) end
end)
connect(script.Destroying,function()
 release()
 alive=false requestSerial+=1
 if bound then ContextActionService:UnbindAction("TagSprint") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]=]},
{name="TagService.luau",target=game.ServerScriptService.TagService,before=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(54, 174, 255), Tagger = Color3.fromRGB(255, 83, 100) }
local BAT_RAGDOLL_SECONDS = 1.35

local BAT_SAMPLE_MAX_AGE = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - 0.0625 * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25 - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end

local function chaseGoal(bot, target)
	local delta = target.root.Position - bot.root.Position
	local velocity = target.root.AssemblyLinearVelocity
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * math.clamp(delta.Magnitude / 100, 0.08, 0.25)
	if lead.Magnitude > 4 then lead = lead.Unit * 4 end
	return target.root.Position + lead
end


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
	self:_stopBurst(record)
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



local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_dodgeGrounded(record, params)
	local foot = record.humanoid.HipHeight + record.root.Size.Y * 0.5
	local leg = record.character:FindFirstChild("Left Leg")
	if leg then foot += leg.Size.Y end
	local hit = workspace:Raycast(record.root.Position, Vector3.new(0, -foot - 0.7, 0), params)
	return hit ~= nil and hit.Normal.Y > 0.45 and math.abs(record.root.AssemblyLinearVelocity.Y) < 12
end

function Service:_clipDodgeTravel(record, travel, params)
	local length = travel.Magnitude
	if length < 0.001 then return 0 end
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.CollisionGroup = params.CollisionGroup
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(CFrame.new(record.root.Position), Vector3.new(2.2, 3.4, 2.2), overlap) > 0 then return 0 end
	local origin = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local delta = self.bounds.CFrame:VectorToObjectSpace(travel)
	local half = self.bounds.Size * 0.5
	local lowerZ = self.northZ and self.northZ + 1.5 or -half.Z + 1.5
	local upperZ = self.southZ and self.southZ - 1.5 or half.Z - 1.5
	if math.abs(origin.X) > half.X - 1.5 or origin.Z < lowerZ or origin.Z > upperZ then return 0 end
	local fraction = 1
	if delta.X > 0 then fraction = math.min(fraction, (half.X - 1.5 - origin.X) / delta.X)
	elseif delta.X < 0 then fraction = math.min(fraction, (-half.X + 1.5 - origin.X) / delta.X) end
	if delta.Z > 0 then fraction = math.min(fraction, (upperZ - origin.Z) / delta.Z)
	elseif delta.Z < 0 then fraction = math.min(fraction, (lowerZ - origin.Z) / delta.Z) end
	local hit = workspace:Blockcast(CFrame.new(record.root.Position), Vector3.new(2.4, 3.6, 2.4), travel * math.clamp(fraction, 0, 1), params)
	if hit then fraction = math.min(fraction, math.max(0, hit.Distance - 0.18) / length) end
	return math.clamp(fraction, 0, 1)
end

function Service:_stopBurst(record, expected)
	local burst = expected or record.burst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.burst ~= burst then return end
	record.burst = nil
	local root = burst.root
	if record.root ~= root or not root.Parent then return end
	local current = root.AssemblyLinearVelocity
	local excess = math.max(0, current:Dot(burst.direction))
	root.AssemblyLinearVelocity = current - burst.direction * excess
	if not record.frozen and not record.ragdoll then
		if record.humanoid == burst.humanoid and burst.humanoid.Parent then burst.humanoid.AutoRotate = burst.autoRotate end
		pcall(function()
			if burst.ownershipAuto then root:SetNetworkOwnershipAuto()
			else root:SetNetworkOwner(burst.owner and burst.owner.Parent == Players and burst.owner or nil) end
		end)
	end
end

function Service:_startBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopBurst(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "TGDodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "TGDodgeVelocity", attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.ForceLimitsEnabled, velocity.ForceLimitMode = true, Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity, velocity.Parent = Vector2.new(initial.X, initial.Z), root
	local burst = {root=root,attachment=attachment,velocity=velocity,direction=direction,owner=owner,ownershipAuto=ownershipAuto,
		humanoid=record.humanoid,autoRotate=record.humanoid.AutoRotate,
		token=self.currentRound,role=record.role,endsAt=now+duration}
	record.burst = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	attribute(record.player, "TGDodgeDirection", direction)
	attribute(record.player, "TGDodgeDuration", duration)
	attribute(record.player, "TGDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or record.role ~= burst.role or self.phase ~= "Playing"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or time >= burst.endsAt then self:_stopBurst(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_batInField(record) then self:_stopBurst(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
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
	record.batSwing = { hitAt = now + 0.10, endsAt = now + 0.38, hit = false,
		character = record.character, token = self.currentRound }
	sampleBatSwing(record.batSwing, record, self.records, now)
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

function Service:_swingCanHit(from, target, now, rayParameters)
	local swing = from and from.batSwing
	if not swing or swing.hit or swing.character ~= from.character or swing.token ~= self.currentRound
		or not self:_tagEligible(from, target, now) then return false end
	return batContact(swing, from, target, now, math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5), rayParameters or self:_rayParameters())
end

function Service:_tagEligible(from, target, now)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or from.role ~= "Tagger" or target.role ~= "Runner"
		or from.frozen or target.frozen or from.ragdoll or target.ragdoll
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	return self:_batInField(from) and self:_batInField(target)
end

function Service:_canTag(from, target, now, rayParameters)
	if not self:_tagEligible(from, target, now) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

function Service:_transfer(target, now)
	local previous = self.tagger
	if not self:_swingCanHit(previous, target, now) then return false end
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
	if self:_directBotRoute(startPosition, goal, params) then
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

function Service:_adoptBotRoute(bot, route)
	local chosen, best = route and #route > 1 and 2 or 1, math.huge
	if route and #route > 1 then
		local height = bot.humanoid.HipHeight + bot.root.Size.Y * 0.5
		if bot.humanoid.RigType == Enum.HumanoidRigType.R6 then height += 2 end
		local lift = Vector3.new(0, height, 0)
		local feet = bot.root.Position - lift
		local parameters = self:_rayParameters()
		for index = 1, #route - 1 do
			local start, delta = route[index].Position, route[index + 1].Position - route[index].Position
			local length = delta:Dot(delta)
			local alpha = length > 0.001 and math.clamp((feet - start):Dot(delta) / length, 0, 1) or 0
			local point = start + delta * alpha
			local distance = (feet - point).Magnitude
			if distance < best and distance < 8 and self:_directBotRoute(bot.root.Position, point + lift, parameters) then
				best, chosen = distance, index + 1
			end
		end
	end
	bot.route, bot.routeIndex = route, chosen
end

function Service:_path(bot, goal, now)
	if bot.pathBusy or now < (bot.nextPathAt or 0) then return end
	local request = {}
	bot.pathBusy = request
	bot.nextPathAt = now + (bot == self.tagger and 0.65 or 0.9)
	bot.pathGoal = goal
	local token, character, origin = self.currentRound, bot.character, bot.root.Position
	task.spawn(function()
		local route, path
		local ok = pcall(function()
			path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 4 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
		end)
		if path then path:Destroy() end
		if bot.pathBusy ~= request then return end
		bot.pathBusy = false
		if not self.active or self.currentRound ~= token or self.records[bot.player] ~= bot or bot.character ~= character then return end
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		self:_adoptBotRoute(bot, route)
	end)
end

function Service:_botTarget(bot, now)
	bot.chaseTarget = nil
	if bot == self.tagger then
		local nearest, target
		for _, runner in pairs(self.records) do
			if runner.participating and runner.role == "Runner" and alive(runner) and not runner.ragdoll and now >= (runner.protectedEndsAt or 0) then
				local distance = (runner.root.Position - bot.root.Position).Magnitude
				if not nearest or distance < nearest then nearest, target = distance, runner end
			end
		end
		bot.chaseTarget = target
		if target then
			local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, target))
			local half = self.bounds.Size * 0.5
			return self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -half.X + 4, half.X - 4), point.Y, math.clamp(point.Z, -half.Z + 4, half.Z - 4)))
		end
		return nil
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

function Service:_directBotRoute(origin, goal, parameters)
	local offset = goal - origin
	if math.abs(offset.Y) > 2.5 or offset.Magnitude > 45 then return false end
	if workspace:Blockcast(CFrame.new(origin), Vector3.new(3, 3, 2), offset, parameters) then return false end
	local count = math.max(1, math.ceil(offset.Magnitude / 4))
	for index = 0, count do
		local point = origin:Lerp(goal, index / count)
		local ground = workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), parameters)
		if not ground or ground.Normal.Y < 0.55 then return false end
	end
	return true
end

function Service:_botSprint(bot, now, wantsSprint)
	local dt = math.clamp(now - (bot.lastSprintAt or now), 0, 0.25)
	bot.lastSprintAt = now
	local capacity = math.clamp(self:_setting("SprintSeconds", 10, 1), 1, 30)
	bot.botSprintRemaining = math.clamp(bot.botSprintRemaining or capacity, 0, capacity)
	local sprinting = wantsSprint and not bot.botSprintExhausted and bot.botSprintRemaining > 0
	if sprinting then
		bot.botSprintRemaining = math.max(0, bot.botSprintRemaining - dt)
		if bot.botSprintRemaining <= 0 then bot.botSprintExhausted, sprinting = true, false end
	else
		bot.botSprintRemaining = math.min(capacity, bot.botSprintRemaining + dt * capacity / self:_setting("SprintRefillSeconds", 15, 1))
		if bot.botSprintRemaining >= capacity then bot.botSprintExhausted = false end
	end
	local speed = bot.role == "Tagger" and self:_setting("TaggerWalkSpeed", 18, 1) or self:_setting("RunnerWalkSpeed", 16, 1)
	bot.humanoid.WalkSpeed = speed * (sprinting and math.clamp(self:_setting("SprintMultiplier", 2.5, 1), 1, 2.5) or 1)
end

function Service:_driveBots(now)
	local parameters = self:_rayParameters()
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= (bot.nextBotMoveAt or 0) then
			bot.nextBotMoveAt = now + 0.1
			local goal = self:_botTarget(bot, now)
			local target = bot.chaseTarget
			local wantsSprint = target and ((target.root.Position - bot.root.Position).Magnitude > 12 or target.root.AssemblyLinearVelocity.Magnitude > 19)
			self:_botSprint(bot, now, wantsSprint == true)
			if goal then
				local direct = self:_directBotRoute(bot.root.Position, goal, parameters)
				local destination = goal
				if not direct then
					self:_path(bot, goal, now)
					local route, index = bot.route, bot.routeIndex or 1
					while route and route[index] do
						local offset = route[index].Position - bot.root.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude >= 2.5 or math.abs(offset.Y) > 4.5 then break end
						index = index + 1
					end
					bot.routeIndex = index
					local waypoint = route and route[index]
					if waypoint then
						destination = waypoint.Position
						if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
					else destination = bot.root.Position end
				end
				if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 3 then
					bot.stuckSince = (bot.stuckSince or 0) + 0.1
					if bot.stuckSince > 0.8 then bot.humanoid.Jump = true end
				else bot.stuckSince = 0 end
				bot.previousBotPosition = bot.root.Position
				bot.humanoid:MoveTo(destination)
			end
			if target and self:_tagEligible(bot, target, now) and (target.root.Position - bot.root.Position).Magnitude <= 5.25 then
				self:TryBatSwing(bot.player)
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
		if record.batSwing and now > record.batSwing.endsAt + BAT_SAMPLE_MAX_AGE then record.batSwing = nil end
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
		local hit, distance = self:_swingCanHit(self.tagger, record, now, params)
		if hit then
			if not nearest or distance < nearest then nearest, candidate = distance, record end
		end
	end
	if candidate then self:_transfer(candidate, now) end
	local attacker = self.tagger
	if attacker and attacker.batSwing then
		if now >= attacker.batSwing.endsAt then attacker.batSwing = nil
		else sampleBatSwing(attacker.batSwing, attacker, self.records, now) end
	end
end

function Service:Move(player, action, direction)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if action ~= "Dodge" or typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Y ~= direction.Y
		or direction.Z ~= direction.Z or math.abs(direction.Y) > 0.01 or direction.Magnitude < 0.99 or direction.Magnitude > 1.01 then return false, "Unknown move" end
	if player.Parent ~= Players or not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record
		or not record.participating or record.isBot or not alive(record) then return false, "Not in an active Tag game" end
	if record.frozen or record.ragdoll or not self:_batInField(record) then return false, "Wait until you can move again" end
	if now < (record.moveCooldowns.Dodge or 0) then return false, "Dodge is recharging" end
	local params = self:_rayParameters()
	params.CollisionGroup = "TGPlayer"
	if not self:_dodgeGrounded(record, params) then return false, "Dodge while on the ground" end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local right = direction
	local forward = Vector3.new(-right.Z,0,right.X).Unit
	local forwardVelocity = forward * math.clamp(record.root.AssemblyLinearVelocity:Dot(forward),-record.humanoid.WalkSpeed,record.humanoid.WalkSpeed)
	local duration, distance = 0.32, 8
	local fraction = self:_clipDodgeTravel(record,direction*distance+forwardVelocity*duration,params)
	if distance*fraction < 0.75 then return false, "No room to dodge" end
	if not self:_startBurst(record,direction,now,duration,distance*fraction,forwardVelocity*fraction,params) then return false, "Your character cannot dodge yet" end
	record.moveCooldowns.Dodge = now + 3
	attribute(player,"TGDodgeReadyAt",record.moveCooldowns.Dodge)
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
		remote.OnServerInvoke = function(player, action, direction) return self:Move(player, action, direction) end
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


]=],after=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(54, 174, 255), Tagger = Color3.fromRGB(255, 83, 100) }
local BAT_RAGDOLL_SECONDS = 1.35

local BAT_SAMPLE_MAX_AGE = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - 0.0625 * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25 - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end

local function chaseGoal(bot, target)
	local delta = target.root.Position - bot.root.Position
	local velocity = target.root.AssemblyLinearVelocity
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * math.clamp(delta.Magnitude / 100, 0.08, 0.25)
	if lead.Magnitude > 4 then lead = lead.Unit * 4 end
	return target.root.Position + lead
end


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
	self:_stopBurst(record)
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



local function dodgeSpeed(distance, duration, elapsed)
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local attack = 0.16
	local envelope = alpha < attack and (0.5 + 0.5 * math.sin(alpha / attack * math.pi / 2))
		or math.cos((alpha - attack) / (1 - attack) * math.pi / 2)
	local area = attack * (0.5 + 1 / math.pi) + (1 - attack) * 2 / math.pi
	return distance / duration * envelope / area
end

function Service:_dodgeGrounded(record, params)
	local foot = record.humanoid.HipHeight + record.root.Size.Y * 0.5
	local leg = record.character:FindFirstChild("Left Leg")
	if leg then foot += leg.Size.Y end
	local hit = workspace:Raycast(record.root.Position, Vector3.new(0, -foot - 0.7, 0), params)
	return hit ~= nil and hit.Normal.Y > 0.45 and math.abs(record.root.AssemblyLinearVelocity.Y) < 12
end

function Service:_clipDodgeTravel(record, travel, params)
	local length = travel.Magnitude
	if length < 0.001 then return 0 end
	local overlap = OverlapParams.new()
	overlap.FilterType = params.FilterType
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.CollisionGroup = params.CollisionGroup
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	if #workspace:GetPartBoundsInBox(CFrame.new(record.root.Position), Vector3.new(2.2, 3.4, 2.2), overlap) > 0 then return 0 end
	local origin = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local delta = self.bounds.CFrame:VectorToObjectSpace(travel)
	local half = self.bounds.Size * 0.5
	local lowerZ = self.northZ and self.northZ + 1.5 or -half.Z + 1.5
	local upperZ = self.southZ and self.southZ - 1.5 or half.Z - 1.5
	if math.abs(origin.X) > half.X - 1.5 or origin.Z < lowerZ or origin.Z > upperZ then return 0 end
	local fraction = 1
	if delta.X > 0 then fraction = math.min(fraction, (half.X - 1.5 - origin.X) / delta.X)
	elseif delta.X < 0 then fraction = math.min(fraction, (-half.X + 1.5 - origin.X) / delta.X) end
	if delta.Z > 0 then fraction = math.min(fraction, (upperZ - origin.Z) / delta.Z)
	elseif delta.Z < 0 then fraction = math.min(fraction, (lowerZ - origin.Z) / delta.Z) end
	local hit = workspace:Blockcast(CFrame.new(record.root.Position), Vector3.new(2.4, 3.6, 2.4), travel * math.clamp(fraction, 0, 1), params)
	if hit then fraction = math.min(fraction, math.max(0, hit.Distance - 0.18) / length) end
	return math.clamp(fraction, 0, 1)
end

function Service:_stopBurst(record, expected)
	local burst = expected or record.burst
	if not burst then return end
	if burst.connection then burst.connection:Disconnect() burst.connection = nil end
	if burst.velocity then burst.velocity:Destroy() burst.velocity = nil end
	if burst.attachment then burst.attachment:Destroy() burst.attachment = nil end
	if record.burst ~= burst then return end
	record.burst = nil
	local root = burst.root
	if record.root ~= root or not root.Parent then return end
	local current = root.AssemblyLinearVelocity
	local excess = math.max(0, current:Dot(burst.direction))
	root.AssemblyLinearVelocity = current - burst.direction * excess
	if not record.frozen and not record.ragdoll then
		if record.humanoid == burst.humanoid and burst.humanoid.Parent then burst.humanoid.AutoRotate = burst.autoRotate end
		pcall(function()
			if burst.ownershipAuto then root:SetNetworkOwnershipAuto()
			else root:SetNetworkOwner(burst.owner and burst.owner.Parent == Players and burst.owner or nil) end
		end)
	end
end

function Service:_startBurst(record, direction, now, duration, distance, forwardVelocity, params)
	self:_stopBurst(record)
	local root = record.root
	if root.Anchored then return false end
	local owner, ownershipAuto
	local ownershipOK = pcall(function()
		owner, ownershipAuto = root:GetNetworkOwner(), root:GetNetworkOwnershipAuto()
		root:SetNetworkOwner(nil)
	end)
	if not ownershipOK then return false end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "TGDodgeAttachment", root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name, velocity.Attachment0 = "TGDodgeVelocity", attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.PrimaryTangentAxis, velocity.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	velocity.ForceLimitsEnabled, velocity.ForceLimitMode = true, Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.max(root.AssemblyMass, 1) * 3000
	local initial = direction * dodgeSpeed(distance, duration, 0) + forwardVelocity
	velocity.PlaneVelocity, velocity.Parent = Vector2.new(initial.X, initial.Z), root
	local burst = {root=root,attachment=attachment,velocity=velocity,direction=direction,owner=owner,ownershipAuto=ownershipAuto,
		humanoid=record.humanoid,autoRotate=record.humanoid.AutoRotate,
		token=self.currentRound,role=record.role,endsAt=now+duration}
	record.burst = burst
	record.humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = initial + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	attribute(record.player, "TGDodgeDirection", direction)
	attribute(record.player, "TGDodgeDuration", duration)
	attribute(record.player, "TGDodgeStartedAt", now)
	burst.connection = RunService.PreSimulation:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		if self.records[record.player] ~= record or record.root ~= root or not root.Parent or not self.active
			or self.currentRound ~= burst.token or record.role ~= burst.role or self.phase ~= "Playing"
			or not record.participating or record.frozen or record.ragdoll or not alive(record) or time >= self.endsAt
			or time >= burst.endsAt then self:_stopBurst(record, burst) return end
		local desired = direction * dodgeSpeed(distance, duration, time - now) + forwardVelocity
		local step = desired * math.clamp(dt, 0, 0.05)
		local hit = step.Magnitude > 0 and workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2.4, 3.6, 2.4), step, params)
		if hit or not self:_batInField(record) then self:_stopBurst(record, burst) return end
		velocity.PlaneVelocity = Vector2.new(desired.X, desired.Z)
	end)
	return true
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
	record.batSwing = { hitAt = now + 0.10, endsAt = now + 0.38, hit = false,
		character = record.character, token = self.currentRound }
	sampleBatSwing(record.batSwing, record, self.records, now)
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

function Service:_swingCanHit(from, target, now, rayParameters)
	local swing = from and from.batSwing
	if not swing or swing.hit or swing.character ~= from.character or swing.token ~= self.currentRound
		or not self:_tagEligible(from, target, now) then return false end
	return batContact(swing, from, target, now, math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5), rayParameters or self:_rayParameters())
end

function Service:_tagEligible(from, target, now)
	if not self.active or self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or from.role ~= "Tagger" or target.role ~= "Runner"
		or from.frozen or target.frozen or from.ragdoll or target.ragdoll
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	return self:_batInField(from) and self:_batInField(target)
end

function Service:_canTag(from, target, now, rayParameters)
	if not self:_tagEligible(from, target, now) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

function Service:_transfer(target, now)
	local previous = self.tagger
	if not self:_swingCanHit(previous, target, now) then return false end
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
	if self:_directBotRoute(startPosition, goal, params) then
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

function Service:_adoptBotRoute(bot, route)
	local chosen, best = route and #route > 1 and 2 or 1, math.huge
	if route and #route > 1 then
		local height = bot.humanoid.HipHeight + bot.root.Size.Y * 0.5
		if bot.humanoid.RigType == Enum.HumanoidRigType.R6 then height += 2 end
		local lift = Vector3.new(0, height, 0)
		local feet = bot.root.Position - lift
		local parameters = self:_rayParameters()
		for index = 1, #route - 1 do
			local start, delta = route[index].Position, route[index + 1].Position - route[index].Position
			local length = delta:Dot(delta)
			local alpha = length > 0.001 and math.clamp((feet - start):Dot(delta) / length, 0, 1) or 0
			local point = start + delta * alpha
			local distance = (feet - point).Magnitude
			if distance < best and distance < 8 and self:_directBotRoute(bot.root.Position, point + lift, parameters) then
				best, chosen = distance, index + 1
			end
		end
	end
	bot.route, bot.routeIndex = route, chosen
end

function Service:_path(bot, goal, now)
	if bot.pathBusy or now < (bot.nextPathAt or 0) then return end
	local request = {}
	bot.pathBusy = request
	bot.nextPathAt = now + (bot == self.tagger and 0.65 or 0.9)
	bot.pathGoal = goal
	local token, character, origin = self.currentRound, bot.character, bot.root.Position
	task.spawn(function()
		local route, path
		local ok = pcall(function()
			path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 4 })
			path:ComputeAsync(origin, goal)
			if path.Status == Enum.PathStatus.Success then route = path:GetWaypoints() end
		end)
		if path then path:Destroy() end
		if bot.pathBusy ~= request then return end
		bot.pathBusy = false
		if not self.active or self.currentRound ~= token or self.records[bot.player] ~= bot or bot.character ~= character then return end
		if not ok or not route or #route == 0 then route = self:_fallbackRoute(origin, goal) end
		self:_adoptBotRoute(bot, route)
	end)
end

function Service:_botTarget(bot, now)
	bot.chaseTarget = nil
	if bot == self.tagger then
		local nearest, target
		for _, runner in pairs(self.records) do
			if runner.participating and runner.role == "Runner" and alive(runner) and not runner.ragdoll and now >= (runner.protectedEndsAt or 0) then
				local distance = (runner.root.Position - bot.root.Position).Magnitude
				if not nearest or distance < nearest then nearest, target = distance, runner end
			end
		end
		bot.chaseTarget = target
		if target then
			local point = self.bounds.CFrame:PointToObjectSpace(chaseGoal(bot, target))
			local half = self.bounds.Size * 0.5
			return self.bounds.CFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X, -half.X + 4, half.X - 4), point.Y, math.clamp(point.Z, -half.Z + 4, half.Z - 4)))
		end
		return nil
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

function Service:_directBotRoute(origin, goal, parameters)
	local offset = goal - origin
	if math.abs(offset.Y) > 2.5 or offset.Magnitude > 45 then return false end
	if workspace:Blockcast(CFrame.new(origin), Vector3.new(3, 3, 2), offset, parameters) then return false end
	local count = math.max(1, math.ceil(offset.Magnitude / 4))
	for index = 0, count do
		local point = origin:Lerp(goal, index / count)
		local ground = workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), parameters)
		if not ground or ground.Normal.Y < 0.55 then return false end
	end
	return true
end

function Service:_botSprint(bot, now, wantsSprint)
	local dt = math.clamp(now - (bot.lastSprintAt or now), 0, 0.25)
	bot.lastSprintAt = now
	local capacity = math.clamp(self:_setting("SprintSeconds", 10, 1), 1, 30)
	bot.botSprintRemaining = math.clamp(bot.botSprintRemaining or capacity, 0, capacity)
	local sprinting = wantsSprint and not bot.botSprintExhausted and bot.botSprintRemaining > 0
	if sprinting then
		bot.botSprintRemaining = math.max(0, bot.botSprintRemaining - dt)
		if bot.botSprintRemaining <= 0 then bot.botSprintExhausted, sprinting = true, false end
	else
		bot.botSprintRemaining = math.min(capacity, bot.botSprintRemaining + dt * capacity / self:_setting("SprintRefillSeconds", 15, 1))
		if bot.botSprintRemaining >= capacity then bot.botSprintExhausted = false end
	end
	local speed = bot.role == "Tagger" and self:_setting("TaggerWalkSpeed", 18, 1) or self:_setting("RunnerWalkSpeed", 16, 1)
	bot.humanoid.WalkSpeed = speed * (sprinting and math.clamp(self:_setting("SprintMultiplier", 2.5, 1), 1, 2.5) or 1)
end

function Service:_driveBots(now)
	local parameters = self:_rayParameters()
	for _, bot in pairs(self.records) do
		if bot.isBot and bot.participating and alive(bot) and not bot.frozen and not bot.ragdoll and now >= (bot.nextBotMoveAt or 0) then
			bot.nextBotMoveAt = now + 0.1
			local goal = self:_botTarget(bot, now)
			local target = bot.chaseTarget
			local wantsSprint = target and ((target.root.Position - bot.root.Position).Magnitude > 12 or target.root.AssemblyLinearVelocity.Magnitude > 19)
			self:_botSprint(bot, now, wantsSprint == true)
			if goal then
				local direct = self:_directBotRoute(bot.root.Position, goal, parameters)
				local destination = goal
				if not direct then
					self:_path(bot, goal, now)
					local route, index = bot.route, bot.routeIndex or 1
					while route and route[index] do
						local offset = route[index].Position - bot.root.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude >= 2.5 or math.abs(offset.Y) > 4.5 then break end
						index = index + 1
					end
					bot.routeIndex = index
					local waypoint = route and route[index]
					if waypoint then
						destination = waypoint.Position
						if waypoint.Action == Enum.PathWaypointAction.Jump then bot.humanoid.Jump = true end
					else destination = bot.root.Position end
				end
				if bot.previousBotPosition and (bot.root.Position - bot.previousBotPosition).Magnitude < 0.2 and (destination - bot.root.Position).Magnitude > 3 then
					bot.stuckSince = (bot.stuckSince or 0) + 0.1
					if bot.stuckSince > 0.8 then bot.humanoid.Jump = true end
				else bot.stuckSince = 0 end
				bot.previousBotPosition = bot.root.Position
				bot.humanoid:MoveTo(destination)
			end
			if target and self:_tagEligible(bot, target, now) and (target.root.Position - bot.root.Position).Magnitude <= 5.25 then
				self:TryBatSwing(bot.player)
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
		if record.batSwing and now > record.batSwing.endsAt + BAT_SAMPLE_MAX_AGE then record.batSwing = nil end
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
		local hit, distance = self:_swingCanHit(self.tagger, record, now, params)
		if hit then
			if not nearest or distance < nearest then nearest, candidate = distance, record end
		end
	end
	if candidate then self:_transfer(candidate, now) end
	local attacker = self.tagger
	if attacker and attacker.batSwing then
		if now >= attacker.batSwing.endsAt then attacker.batSwing = nil
		else sampleBatSwing(attacker.batSwing, attacker, self.records, now) end
	end
end

function Service:Move(player, action, direction)
	if action == "Dodge" then return false, "Dodge is temporarily disabled" end
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if action ~= "Dodge" or typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Y ~= direction.Y
		or direction.Z ~= direction.Z or math.abs(direction.Y) > 0.01 or direction.Magnitude < 0.99 or direction.Magnitude > 1.01 then return false, "Unknown move" end
	if player.Parent ~= Players or not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record
		or not record.participating or record.isBot or not alive(record) then return false, "Not in an active Tag game" end
	if record.frozen or record.ragdoll or not self:_batInField(record) then return false, "Wait until you can move again" end
	if now < (record.moveCooldowns.Dodge or 0) then return false, "Dodge is recharging" end
	local params = self:_rayParameters()
	params.CollisionGroup = "TGPlayer"
	if not self:_dodgeGrounded(record, params) then return false, "Dodge while on the ground" end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local right = direction
	local forward = Vector3.new(-right.Z,0,right.X).Unit
	local forwardVelocity = forward * math.clamp(record.root.AssemblyLinearVelocity:Dot(forward),-record.humanoid.WalkSpeed,record.humanoid.WalkSpeed)
	local duration, distance = 0.32, 8
	local fraction = self:_clipDodgeTravel(record,direction*distance+forwardVelocity*duration,params)
	if distance*fraction < 0.75 then return false, "No room to dodge" end
	if not self:_startBurst(record,direction,now,duration,distance*fraction,forwardVelocity*fraction,params) then return false, "Your character cannot dodge yet" end
	record.moveCooldowns.Dodge = now + 3
	attribute(player,"TGDodgeReadyAt",record.moveCooldowns.Dodge)
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
		remote.OnServerInvoke = function(player, action, direction) return self:Move(player, action, direction) end
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


]=]},
{name="TagHUD.Controller.luau",target=game.StarterGui.TagHUD.Controller,before=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
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
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local alive = true
local moveSerial = 0

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	local phase = state:GetAttribute("Phase") or "Waiting"
	gui.Enabled = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
	if not gui.Enabled then return end
	top.Visible = phase ~= "Results"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.Visible = not gui:FindFirstChild("SprintPanel")
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing" and now >= messageEndsAt
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	local button = controls.Dodge
	local cooldown = secondsRemaining(player:GetAttribute("TGDodgeReadyAt"), now)
	button.Text = "DODGE\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or UserInputService.TouchEnabled and "TAP" or "[E]")
	button.Active = cooldown == 0 and not busy and player:GetAttribute("TGRagdolled") ~= true

	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = Color3.fromRGB(255,248,221)
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end

local function dodgeDirection()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local axis = camera and camera.CFrame.RightVector or Vector3.xAxis
	local right = Vector3.new(axis.X, 0, axis.Z)
	if right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
	if not root then return right end
	local lateral = humanoid and humanoid.MoveDirection:Dot(right) or 0
	if math.abs(lateral)>0.12 then return right * (lateral<0 and -1 or 1) end
	local nearest, distance
	for _, other in ipairs(Players:GetPlayers()) do
		local candidate=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other~=player and candidate and other:GetAttribute("TGParticipating")==true and other:GetAttribute("TGRole")=="Tagger" then
			local delta=candidate.Position-root.Position
			if not distance or delta.Magnitude<distance then nearest,distance=candidate,delta.Magnitude end
		end
	end
	if nearest then local away=(root.Position-nearest.Position):Dot(right) if math.abs(away)>.1 then return right * (away<0 and -1 or 1) end end
	return right
end

local function move()
	if not alive or busy or player:GetAttribute("TGParticipating")~=true or player:GetAttribute("TGRagdolled")==true or state:GetAttribute("Phase")~="Playing" then return end
	if secondsRemaining(player:GetAttribute("TGDodgeReadyAt"),workspace:GetServerTimeNow())>0 then return end
	busy=true moveSerial+=1
	local serial=moveSerial
	local direction=dodgeDirection()
	local worker=task.spawn(function()
		local ok,accepted,message=pcall(function() return movement:InvokeServer("Dodge",direction) end)
		if not alive or serial~=moveSerial then return end
		busy=false
		if not ok or not accepted then
			gui.MoveMessage.Text=ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
			messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
		update()
	end)
	task.delay(2,function()
		if alive and serial==moveSerial and busy then
			moveSerial+=1 busy=false pcall(task.cancel,worker)
			gui.MoveMessage.Text="Move couldn't be sent. Try again." messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
	end)
end

controls.Dodge.Activated:Connect(move)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.X then move() end
end)
player.AttributeChanged:Connect(update)
state.AttributeChanged:Connect(update)
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator >= 0.1 then accumulator = 0 update() end
end)
script.Destroying:Connect(function() alive=false moveSerial+=1 end)
update()

]=],after=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
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
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local alive = true
local moveSerial = 0

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	local phase = state:GetAttribute("Phase") or "Waiting"
	gui.Enabled = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
	if not gui.Enabled then return end
	top.Visible = phase ~= "Results"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.Visible = not gui:FindFirstChild("SprintPanel")
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing" and now >= messageEndsAt
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	local button = controls.Dodge
	local cooldown = secondsRemaining(player:GetAttribute("TGDodgeReadyAt"), now)
	button.Text = "DODGE\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or UserInputService.TouchEnabled and "TAP" or "[E]")
	button.Active = false
	button.Interactable = false
	button.Visible = false

	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = Color3.fromRGB(255,248,221)
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end

local function dodgeDirection()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local axis = camera and camera.CFrame.RightVector or Vector3.xAxis
	local right = Vector3.new(axis.X, 0, axis.Z)
	if right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
	if not root then return right end
	local lateral = humanoid and humanoid.MoveDirection:Dot(right) or 0
	if math.abs(lateral)>0.12 then return right * (lateral<0 and -1 or 1) end
	local nearest, distance
	for _, other in ipairs(Players:GetPlayers()) do
		local candidate=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other~=player and candidate and other:GetAttribute("TGParticipating")==true and other:GetAttribute("TGRole")=="Tagger" then
			local delta=candidate.Position-root.Position
			if not distance or delta.Magnitude<distance then nearest,distance=candidate,delta.Magnitude end
		end
	end
	if nearest then local away=(root.Position-nearest.Position):Dot(right) if math.abs(away)>.1 then return right * (away<0 and -1 or 1) end end
	return right
end

local function move()
	if controls.Dodge.Interactable == false then return end
	if not alive or busy or player:GetAttribute("TGParticipating")~=true or player:GetAttribute("TGRagdolled")==true or state:GetAttribute("Phase")~="Playing" then return end
	if secondsRemaining(player:GetAttribute("TGDodgeReadyAt"),workspace:GetServerTimeNow())>0 then return end
	busy=true moveSerial+=1
	local serial=moveSerial
	local direction=dodgeDirection()
	local worker=task.spawn(function()
		local ok,accepted,message=pcall(function() return movement:InvokeServer("Dodge",direction) end)
		if not alive or serial~=moveSerial then return end
		busy=false
		if not ok or not accepted then
			gui.MoveMessage.Text=ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
			messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
		update()
	end)
	task.delay(2,function()
		if alive and serial==moveSerial and busy then
			moveSerial+=1 busy=false pcall(task.cancel,worker)
			gui.MoveMessage.Text="Move couldn't be sent. Try again." messageEndsAt=workspace:GetServerTimeNow()+1.8
		end
	end)
end

controls.Dodge.Activated:Connect(move)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.X then move() end
end)
player.AttributeChanged:Connect(update)
state.AttributeChanged:Connect(update)
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator >= 0.1 then accumulator = 0 update() end
end)
script.Destroying:Connect(function() alive=false moveSerial+=1 end)
update()

]=]},
{name="PlaygroundPodium.Controller.luau",target=game.StarterGui.PlaygroundPodium.Controller,before=[=[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function animationId(value)
	if typeof(value) == "number" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then return nil end
		value = string.format("%.0f", value)
	end
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return "rbxassetid://" .. digits
end

local function readableIsA(object, className)
	local ok, result = pcall(function() return object:IsA(className) end)
	return ok and result
end

local function bodyBounds(model)
	local low, high = math.huge, -math.huge
	for _, part in ipairs(model:GetChildren()) do
		if readableIsA(part, "BasePart") and part.Name ~= "HumanoidRootPart" then
			local half, frame = part.Size * 0.5, part.CFrame
			local extent = math.abs(frame.RightVector.Y) * half.X + math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
			low = math.min(low, part.Position.Y - extent)
			high = math.max(high, part.Position.Y + extent)
		end
	end
	return low, high
end

local function prepareModel(model)
	assert(model and model:IsA("Model"), "Avatar model unavailable")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar humanoid unavailable")
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar root unavailable")
	for _, object in ipairs(model:GetDescendants()) do
		if readableIsA(object, "LuaSourceContainer") then
			object:Destroy()
		elseif readableIsA(object, "BasePart") then
			object.Anchored = object == root
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Massless = true
		elseif readableIsA(object, "AnimationConstraint") then
			object.IsKinematic = true
			object.Enabled = true
		end
	end
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
	local low, high = bodyBounds(model)
	local height = high - low
	assert(finite(height) and height > 0.05 and height < 1000, "Avatar body dimensions unavailable")
	model:ScaleTo(model:GetScale() * 5.5 / height)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)))
	low = bodyBounds(model)
	local result = { model = model, root = root, humanoid = humanoid, animator = animator, floorOffset = -low, joints = {} }
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }) do
		local joint = model:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			result.joints[name] = { joint = joint, original = joint.Transform, rotation = joint.C0.Rotation }
		end
	end
	return result
end

local function poseJoint(avatar, name, x, y, z, fade)
	local entry = avatar.joints[name]
	if not entry or not entry.joint.Parent then return end
	local offset = entry.rotation:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * entry.rotation
	entry.joint.Transform = entry.original:Lerp(entry.original * offset, fade)
end

local function restorePose(avatar)
	for _, entry in pairs(avatar.joints) do if entry.joint.Parent then entry.joint.Transform = entry.original end end
end

local function animateModel(avatar, standingPoint, rank, elapsed, authored)
	local fade = math.clamp(elapsed / 0.35, 0, 1)
	local t = elapsed + rank * 0.7
	local bounce = authored and 0 or (1 - math.cos(elapsed * 3.6)) * 0.065 * fade
	local position = standingPoint.WorldPosition + Vector3.new(0, avatar.floorOffset + bounce, 0)
	avatar.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.045 * fade, 0))
	if authored then return end
	local wave = math.sin(t * 4.8)
	local right = avatar.joints["Right Shoulder"] and "Right Shoulder" or "RightShoulder"
	local left = avatar.joints["Left Shoulder"] and "Left Shoulder" or "LeftShoulder"
	if rank == 1 then
		poseJoint(avatar, right, 12, 0, 132 + wave * 10, fade)
		poseJoint(avatar, left, 12, 0, -132 + wave * 10, fade)
		poseJoint(avatar, "RightElbow", 35 + wave * 12, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 35 - wave * 12, 0, 0, fade)
	elseif rank == 2 then
		poseJoint(avatar, right, 10, 0, 140 + wave * 12, fade)
		poseJoint(avatar, left, 0, 0, -12 + math.sin(t * 2) * 5, fade)
		poseJoint(avatar, "RightElbow", 50, wave * 15, 0, fade)
	else
		poseJoint(avatar, right, 18 + wave * 8, 0, 48, fade)
		poseJoint(avatar, left, 18 - wave * 8, 0, -48, fade)
		poseJoint(avatar, "RightElbow", 55 + wave * 15, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 55 - wave * 15, 0, 0, fade)
	end
	poseJoint(avatar, "Waist", 0, 0, math.sin(t * 2.4) * 4, fade)
	poseJoint(avatar, "Neck", math.sin(t * 2.1) * 3, math.sin(t * 1.4) * 7, 0, fade)
	poseJoint(avatar, "RightWrist", 0, wave * 12, 0, fade)
	poseJoint(avatar, "LeftWrist", 0, -wave * 12, 0, fade)
end

local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	local token = avatar.animationToken
	if token then
		token.expired = true
		if token.worker and coroutine.status(token.worker) ~= "dead" and token.worker ~= coroutine.running() then pcall(task.cancel, token.worker) end
		avatar.animationToken = nil
	end
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(token.userId)
			local created, value = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
			description:Destroy()
			if not created then error(value) end
			return value
		end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function requestedAnimation(slot)
	local winner = slot.userId and Players:GetPlayerByUserId(slot.userId)
	local equipped, asset, rig
	if winner and winner:GetAttribute("PCDataReady") == true then
		equipped = winner:GetAttribute("PCEmote")
		asset = winner:GetAttribute("PCEquippedEmoteAnimationId")
		rig = winner:GetAttribute("PCEquippedEmoteRigType")
	else
		local entry = slot.entry
		equipped = entry and entry.emoteId
		asset = entry and entry.emoteAnimationId
		rig = entry and entry.emoteRigType
	end
	if typeof(equipped) == "string" and equipped ~= "" then
		return rig == "R15" and animationId(asset) or nil
	end
	return animationId(gui:GetAttribute("PodiumAnimationId"))
end

local function failedAnimation(slot, avatar)
	stopTrack(avatar)
	avatar.animationRetryAt = os.clock() + 15
	slot.display.StatusLabel.Text = avatar.animationAttempts >= 3 and "Dance unavailable" or "Dance is loading slowly"
end

local function updateAnimation(slot)
	local avatar = slot.avatar
	local requested = requestedAnimation(slot)
	if avatar.requestedAnimation ~= requested then
		stopTrack(avatar)
		avatar.requestedAnimation = requested
		avatar.animationAttempts, avatar.animationRetryAt = 0, 0
	end
	if not requested then return end
	local now = os.clock()
	if avatar.track then
		if avatar.track.Length > 0 and avatar.track.IsPlaying then
			avatar.animationAttempts, avatar.animationRetryAt = 0, 0
			return
		end
		if now - avatar.animationLoadedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if avatar.animationToken then
		if now - avatar.animationToken.startedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if (avatar.animationAttempts or 0) >= 3 or now < (avatar.animationRetryAt or 0) then return end
	avatar.animationAttempts = (avatar.animationAttempts or 0) + 1
	local token = {startedAt=now}
	avatar.animationToken = token
	local animation = Instance.new("Animation")
	animation.Name = "EquippedPodiumEmote"
	animation.AnimationId = requested
	avatar.animation, avatar.animationAsset = animation, requested
	token.worker = task.spawn(function()
		local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
		if not alive or token.expired or avatar.animationToken ~= token or slot.avatar ~= avatar or not avatar.model.Parent then
			if ok then track:Destroy() end
			return
		end
		avatar.animationToken = nil
		if not ok then failedAnimation(slot, avatar) return end
		avatar.track, avatar.animationLoadedAt = track, os.clock()
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.25)
		end)
		if not played then failedAnimation(slot, avatar)
		else slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or "" end
	end)
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else
		for _, slot in ipairs(slots) do if slot.avatar then stopTrack(slot.avatar) end end
		folder.Parent = nil
	end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(slot)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))



]=],after=[=[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function animationId(value)
	if typeof(value) == "number" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then return nil end
		value = string.format("%.0f", value)
	end
	if typeof(value) ~= "string" then return nil end
	local digits = value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$")
	if not digits or #digits > 18 or tonumber(digits) <= 0 then return nil end
	return "rbxassetid://" .. digits
end

local function readableIsA(object, className)
	local ok, result = pcall(function() return object:IsA(className) end)
	return ok and result
end

local function bodyBounds(model)
	local low, high = math.huge, -math.huge
	for _, part in ipairs(model:GetChildren()) do
		if readableIsA(part, "BasePart") and part.Name ~= "HumanoidRootPart" then
			local half, frame = part.Size * 0.5, part.CFrame
			local extent = math.abs(frame.RightVector.Y) * half.X + math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
			low = math.min(low, part.Position.Y - extent)
			high = math.max(high, part.Position.Y + extent)
		end
	end
	return low, high
end

local function prepareModel(model)
	assert(model and model:IsA("Model"), "Avatar model unavailable")
	local humanoid = assert(model:FindFirstChildOfClass("Humanoid"), "Avatar humanoid unavailable")
	local root = assert(model:FindFirstChild("HumanoidRootPart"), "Avatar root unavailable")
	for _, object in ipairs(model:GetDescendants()) do
		if readableIsA(object, "LuaSourceContainer") then
			object:Destroy()
		elseif readableIsA(object, "BasePart") then
			object.Anchored = object == root
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Massless = true
		elseif readableIsA(object, "AnimationConstraint") then
			object.IsKinematic = true
			object.Enabled = true
		end
	end
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator") animator.Parent = humanoid end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end
	local low, high = bodyBounds(model)
	local height = high - low
	assert(finite(height) and height > 0.05 and height < 1000, "Avatar body dimensions unavailable")
	local avatarHeight = script.Parent:GetAttribute("AvatarHeight")
	if not finite(avatarHeight) or avatarHeight <= 0 then avatarHeight = 27.5 end
	model:ScaleTo(model:GetScale() * avatarHeight / height)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)))
	low = bodyBounds(model)
	local result = { model = model, root = root, humanoid = humanoid, animator = animator, floorOffset = -low, joints = {} }
	for _, name in ipairs({ "Right Shoulder", "Left Shoulder", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }) do
		local joint = model:FindFirstChild(name, true)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			result.joints[name] = { joint = joint, original = joint.Transform, rotation = joint.C0.Rotation }
		end
	end
	return result
end

local function poseJoint(avatar, name, x, y, z, fade)
	local entry = avatar.joints[name]
	if not entry or not entry.joint.Parent then return end
	local offset = entry.rotation:Inverse() * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * entry.rotation
	entry.joint.Transform = entry.original:Lerp(entry.original * offset, fade)
end

local function restorePose(avatar)
	for _, entry in pairs(avatar.joints) do if entry.joint.Parent then entry.joint.Transform = entry.original end end
end

local function animateModel(avatar, standingPoint, rank, elapsed, authored)
	local fade = math.clamp(elapsed / 0.35, 0, 1)
	local t = elapsed + rank * 0.7
	local bounce = authored and 0 or (1 - math.cos(elapsed * 3.6)) * 0.065 * fade
	local position = standingPoint.WorldPosition + Vector3.new(0, avatar.floorOffset + bounce, 0)
	avatar.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.045 * fade, 0))
	if authored then return end
	local wave = math.sin(t * 4.8)
	local right = avatar.joints["Right Shoulder"] and "Right Shoulder" or "RightShoulder"
	local left = avatar.joints["Left Shoulder"] and "Left Shoulder" or "LeftShoulder"
	if rank == 1 then
		poseJoint(avatar, right, 12, 0, 132 + wave * 10, fade)
		poseJoint(avatar, left, 12, 0, -132 + wave * 10, fade)
		poseJoint(avatar, "RightElbow", 35 + wave * 12, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 35 - wave * 12, 0, 0, fade)
	elseif rank == 2 then
		poseJoint(avatar, right, 10, 0, 140 + wave * 12, fade)
		poseJoint(avatar, left, 0, 0, -12 + math.sin(t * 2) * 5, fade)
		poseJoint(avatar, "RightElbow", 50, wave * 15, 0, fade)
	else
		poseJoint(avatar, right, 18 + wave * 8, 0, 48, fade)
		poseJoint(avatar, left, 18 - wave * 8, 0, -48, fade)
		poseJoint(avatar, "RightElbow", 55 + wave * 15, 0, 0, fade)
		poseJoint(avatar, "LeftElbow", 55 - wave * 15, 0, 0, fade)
	end
	poseJoint(avatar, "Waist", 0, 0, math.sin(t * 2.4) * 4, fade)
	poseJoint(avatar, "Neck", math.sin(t * 2.1) * 3, math.sin(t * 1.4) * 7, 0, fade)
	poseJoint(avatar, "RightWrist", 0, wave * 12, 0, fade)
	poseJoint(avatar, "LeftWrist", 0, -wave * 12, 0, fade)
end

local gui = script.Parent
local playerGui = gui.Parent
local header = gui:WaitForChild("Header")
local slots, connections, selectionConnections = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "PlaygroundPodiumAvatars"
folder.Parent = workspace
local alive, activeLoads = true, 0
local selectionGui
local selectedScope, selectedBoard = "global", "MostWins"
local scopes = { global = true, server = true, region = true }
local boardNames = { MostWins = "MOST WINS", HighestLevel = "HIGHEST LEVEL" }
local packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil

local function disconnect(list)
	for _, connection in ipairs(list) do connection:Disconnect() end
	table.clear(list)
end

local function stopTrack(avatar)
	local token = avatar.animationToken
	if token then
		token.expired = true
		if token.worker and coroutine.status(token.worker) ~= "dead" and token.worker ~= coroutine.running() then pcall(task.cancel, token.worker) end
		avatar.animationToken = nil
	end
	if avatar.track then avatar.track:Stop(0) avatar.track:Destroy() avatar.track = nil end
	if avatar.animation then avatar.animation:Destroy() avatar.animation = nil end
	avatar.animationAsset = nil
	restorePose(avatar)
end

local function clearAvatar(slot)
	if slot.loadToken then slot.loadToken.expired = true slot.loadToken = nil end
	if slot.avatar then stopTrack(slot.avatar) slot.avatar.model:Destroy() slot.avatar = nil end
end

local function setEntry(slot, entry)
	local id = entry and entry.userId
	if slot.userId ~= id then
		clearAvatar(slot)
		slot.userId, slot.attempts, slot.retryAt = id, 0, 0
	end
	slot.entry = entry
	slot.display.NameLabel.Text = entry and entry.name or (packetState == "loading" and "Loading..." or "No winner yet")
	slot.display.ScoreLabel.Text = entry and (selectedBoard == "MostWins" and entry.value .. " WINS" or entry.value) or "—"
	if entry then
		slot.display.StatusLabel.Text = slot.avatar and (packetState == "stale" and "Saved ranking" or "") or (slot.attempts >= 3 and "Avatar unavailable" or "Loading avatar...")
	else
		slot.display.StatusLabel.Text = packetState == "loading" and "Waiting for rankings" or packetState == "unavailable" and "Rankings unavailable" or "Your next win could put you here"
	end
end

local function refreshHeading()
	header.Title.Text = boardNames[selectedBoard] .. " · TOP 3"
	local label = selectedScope == "region" and (packetRegion or "REGION") or selectedScope == "server" and "THIS SERVER" or "GLOBAL"
	header.Subtitle.Text = string.upper(label) .. (packetState == "loading" and " · LOADING" or packetState == "unavailable" and " · UNAVAILABLE" or packetState == "stale" and " · SAVED RANKINGS" or " · WINNERS")
end

local function readPacket()
	local encoded = selectionGui and selectionGui:GetAttribute("PodiumSnapshot")
	if typeof(encoded) ~= "string" or #encoded > 32768 then return end
	local ok, packet = pcall(function() return HttpService:JSONDecode(encoded) end)
	if not ok or typeof(packet) ~= "table" or packet.scope ~= selectedScope or packet.board ~= selectedBoard or typeof(packet.entries) ~= "table" then return end
	packetState = packet.state == "loading" and "loading" or packet.state == "unavailable" and "unavailable" or packet.state == "stale" and "stale" or "ready"
	packetStatus = typeof(packet.status) == "string" and packet.status or ""
	packetRegion = typeof(packet.region) == "string" and packet.region or nil
	local seen = {}
	for index, slot in ipairs(slots) do
		local entry = packet.entries[index]
		if typeof(entry) ~= "table" or not finite(entry.userId) or entry.userId <= 0 or entry.userId % 1 ~= 0 or seen[entry.userId]
			or typeof(entry.name) ~= "string" or typeof(entry.value) ~= "string" then entry = nil end
		if entry then seen[entry.userId] = true end
		setEntry(slot, entry)
	end
	refreshHeading()
end

local function readSelection()
	local scope = selectionGui and selectionGui:GetAttribute("PodiumScope")
	local board = selectionGui and selectionGui:GetAttribute("PodiumBoard")
	scope = scopes[scope] and scope or "global"
	board = boardNames[board] and board or "MostWins"
	if scope ~= selectedScope or board ~= selectedBoard then
		selectedScope, selectedBoard = scope, board
		packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
		for _, slot in ipairs(slots) do setEntry(slot, nil) end
		refreshHeading()
	end
	readPacket()
end

local function bindSelection()
	local source = playerGui:FindFirstChild("PlaygroundLeaderboards")
	if source == selectionGui then return end
	disconnect(selectionConnections)
	selectionGui = source
	packetState, packetStatus, packetRegion = "loading", "Loading winners...", nil
	for _, slot in ipairs(slots) do setEntry(slot, nil) end
	refreshHeading()
	if source then
		for _, attribute in ipairs({ "PodiumScope", "PodiumBoard", "PodiumSnapshot" }) do
			table.insert(selectionConnections, source:GetAttributeChangedSignal(attribute):Connect(attribute == "PodiumSnapshot" and readPacket or readSelection))
		end
	end
	readSelection()
end

local function bindPedestals()
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local podium = lobby and lobby:FindFirstChild("WinnerPodium")
	local headerFace = podium and podium:FindFirstChild("HeaderFace")
	if headerFace and headerFace:IsA("BasePart") then header.Adornee = headerFace end
	header.Enabled = gui.Enabled and headerFace ~= nil
	for index, slot in ipairs(slots) do
		local pedestal = podium and podium:FindFirstChild("Rank" .. index)
		local point = pedestal and pedestal:FindFirstChild("StandingPoint", true)
		local face = pedestal and pedestal:FindFirstChild("Face")
		slot.point = point and point:IsA("Attachment") and point or nil
		if face and face:IsA("BasePart") then slot.display.Adornee = face end
		slot.display.Enabled = gui.Enabled and slot.point ~= nil and face ~= nil
		if not slot.point and slot.avatar then clearAvatar(slot) end
	end
end

local function beginAvatar(slot)
	local token = { userId = slot.userId, startedAt = os.clock() }
	slot.loadToken = token
	slot.attempts += 1
	activeLoads += 1
	task.spawn(function()
		local ok, model = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(token.userId)
			local created, value = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
			description:Destroy()
			if not created then error(value) end
			return value
		end)
		activeLoads -= 1
		local current = alive and not token.expired and slot.loadToken == token and slot.userId == token.userId and slot.point and slot.point:IsDescendantOf(workspace)
		if slot.loadToken == token then slot.loadToken = nil end
		if not current then if ok and typeof(model) == "Instance" then model:Destroy() end return end
		local prepared, avatar = false, nil
		if ok and typeof(model) == "Instance" then prepared, avatar = pcall(prepareModel, model) end
		if not prepared then
			if ok and typeof(model) == "Instance" then model:Destroy() end
			slot.retryAt = os.clock() + math.min(60, slot.attempts * 15)
			slot.display.StatusLabel.Text = "Avatar unavailable"
			return
		end
		avatar.startedAt = os.clock()
		model.Name = "Rank" .. slot.rank .. "_" .. token.userId
		model:SetAttribute("PodiumUserId", token.userId)
		model.Parent = folder
		slot.avatar = avatar
		animateModel(avatar, slot.point, slot.rank, 0, false)
		slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or ""
	end)
end

local function requestedAnimation(slot)
	local winner = slot.userId and Players:GetPlayerByUserId(slot.userId)
	local equipped, asset, rig
	if winner and winner:GetAttribute("PCDataReady") == true then
		equipped = winner:GetAttribute("PCEmote")
		asset = winner:GetAttribute("PCEquippedEmoteAnimationId")
		rig = winner:GetAttribute("PCEquippedEmoteRigType")
	else
		local entry = slot.entry
		equipped = entry and entry.emoteId
		asset = entry and entry.emoteAnimationId
		rig = entry and entry.emoteRigType
	end
	if typeof(equipped) == "string" and equipped ~= "" then
		return rig == "R15" and animationId(asset) or nil
	end
	return animationId(gui:GetAttribute("PodiumAnimationId"))
end

local function failedAnimation(slot, avatar)
	stopTrack(avatar)
	avatar.animationRetryAt = os.clock() + 15
	slot.display.StatusLabel.Text = avatar.animationAttempts >= 3 and "Dance unavailable" or "Dance is loading slowly"
end

local function updateAnimation(slot)
	local avatar = slot.avatar
	local requested = requestedAnimation(slot)
	if avatar.requestedAnimation ~= requested then
		stopTrack(avatar)
		avatar.requestedAnimation = requested
		avatar.animationAttempts, avatar.animationRetryAt = 0, 0
	end
	if not requested then return end
	local now = os.clock()
	if avatar.track then
		if avatar.track.Length > 0 and avatar.track.IsPlaying then
			avatar.animationAttempts, avatar.animationRetryAt = 0, 0
			return
		end
		if now - avatar.animationLoadedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if avatar.animationToken then
		if now - avatar.animationToken.startedAt > 8 then failedAnimation(slot, avatar) end
		return
	end
	if (avatar.animationAttempts or 0) >= 3 or now < (avatar.animationRetryAt or 0) then return end
	avatar.animationAttempts = (avatar.animationAttempts or 0) + 1
	local token = {startedAt=now}
	avatar.animationToken = token
	local animation = Instance.new("Animation")
	animation.Name = "EquippedPodiumEmote"
	animation.AnimationId = requested
	avatar.animation, avatar.animationAsset = animation, requested
	token.worker = task.spawn(function()
		local ok, track = pcall(function() return avatar.animator:LoadAnimation(animation) end)
		if not alive or token.expired or avatar.animationToken ~= token or slot.avatar ~= avatar or not avatar.model.Parent then
			if ok then track:Destroy() end
			return
		end
		avatar.animationToken = nil
		if not ok then failedAnimation(slot, avatar) return end
		avatar.track, avatar.animationLoadedAt = track, os.clock()
		local played = pcall(function()
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.25)
		end)
		if not played then failedAnimation(slot, avatar)
		else slot.display.StatusLabel.Text = packetState == "stale" and "Saved ranking" or "" end
	end)
end

for index = 1, 3 do
	slots[index] = { rank = index, display = gui:WaitForChild("Rank" .. index), attempts = 0, retryAt = 0 }
	setEntry(slots[index], nil)
end
refreshHeading()
bindSelection()
readPacket()
bindPedestals()

local function cleanup()
	if not alive then return end
	alive = false
	disconnect(connections)
	disconnect(selectionConnections)
	for _, slot in ipairs(slots) do clearAvatar(slot) slot.display.Enabled = false end
	folder:Destroy()
end

table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then folder.Parent = workspace else
		for _, slot in ipairs(slots) do if slot.avatar then stopTrack(slot.avatar) end end
		folder.Parent = nil
	end
	bindPedestals()
end))
table.insert(connections, gui.Destroying:Connect(cleanup))
table.insert(connections, script.Destroying:Connect(cleanup))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	elapsed += dt
	if elapsed < 0.25 then return end
	elapsed = 0
	bindSelection()
	bindPedestals()
	if not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		if slot.loadToken and now - slot.loadToken.startedAt > 20 then slot.display.StatusLabel.Text = "Avatar is taking longer to load" end
		if slot.userId and slot.point and not slot.avatar and not slot.loadToken and slot.attempts < 3 and now >= slot.retryAt and activeLoads < 2 then beginAvatar(slot) end
	end
end))
table.insert(connections, RunService.PreAnimation:Connect(function()
	if not alive then return end
	for _, slot in ipairs(slots) do if slot.avatar then restorePose(slot.avatar) end end
end))
table.insert(connections, RunService.PreSimulation:Connect(function()
	if not alive or not gui.Enabled then return end
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local avatar = slot.avatar
		if avatar and slot.point and slot.point:IsDescendantOf(workspace) then
			updateAnimation(slot)
			local authored = avatar.track and avatar.track.IsPlaying and avatar.track.Length > 0
			animateModel(avatar, slot.point, slot.rank, now - avatar.startedAt, authored)
		end
	end
end))



]=]},
{name="PlaygroundCatalog.luau",target=game.ReplicatedStorage.PlaygroundCatalog,before=[=[local function item(id, name, category, slot, kind, amount, gameId, description, color)
	return {
		id = id,
		name = name,
		category = category,
		slot = slot,
		available = true,
		price = kind == "Coins" and amount or 0,
		unlock = { kind = kind, amount = amount, gameId = gameId },
		description = description,
		color = Color3.fromRGB(color[1], color[2], color[3]),
		assetId = id,
	}
end

local items = {
	item("B01", "Starter Slugger", "Bats", "Bat", "Starter", 0, nil, "Your first Bulldog bat. Ready from the start.", {218, 155, 76}),
	item("B02", "Schoolyard Alloy", "Bats", "Bat", "Coins", 750, nil, "A silver schoolyard classic with a blue grip.", {139, 185, 224}),
	item("B03", "Varsity Victory", "Bats", "Bat", "Level", 5, nil, "Earn your varsity colours by reaching level 5.", {241, 91, 101}),
	item("B04", "Street Cone", "Bats", "Bat", "Coins", 1250, nil, "Bold orange with bright playground stripes.", {255, 147, 57}),
	item("B05", "Bubblegum Bonker", "Bats", "Bat", "Level", 10, nil, "A sweet reward for reaching level 10.", {244, 113, 184}),
	item("B06", "Mudslinger", "Bats", "Bat", "Wins", 25, "StuckInTheMud", "Win 25 rounds of Stuck in the Mud.", {142, 126, 73}),
	item("B07", "Heat Coil", "Bats", "Bat", "Wins", 50, "StuckInTheMud", "A heated trophy for 50 Stuck in the Mud wins.", {255, 152, 67}),
	item("B08", "Frostbite", "Bats", "Bat", "Coins", 4000, nil, "A chunky ice-blue barrel and a deep blue grip.", {116, 225, 245}),
	item("B09", "Thunder Circuit", "Bats", "Bat", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {67, 143, 243}),
	item("B10", "Pixel Party", "Bats", "Bat", "Level", 20, nil, "Reach level 20 for this bright arcade bat.", {213, 97, 228}),
	item("B11", "Cosmic Orbit", "Bats", "Bat", "Coins", 10000, nil, "A violet barrel with a silver orbit ring.", {153, 120, 235}),
	item("B12", "Royal Champion", "Bats", "Bat", "Wins", 50, "BritishBulldog", "A crown for 50 British Bulldog wins.", {248, 209, 92}),
	item("B13", "Skatepark Stripe", "Bats", "Bat", "Coins", 2500, nil, "Blue, mint and coral playground style.", {82, 176, 226}),
	item("B14", "Deep Sea", "Bats", "Bat", "Coins", 6000, nil, "Ocean waves on a navy and turquoise barrel.", {71, 193, 191}),
	item("B15", "Sunburst", "Bats", "Bat", "Level", 30, nil, "A sunny reward for reaching level 30.", {255, 180, 63}),
	item("P01", "Pocket Bulldog", "Pets", "Pet", "Coins", 500, nil, "A cheerful little schoolyard companion.", {224, 184, 131}),
	item("P02", "Toast Capybara", "Pets", "Pet", "Level", 3, nil, "Reach level 3 for this sleepy toast-shaped friend.", {209, 153, 86}),
	item("P03", "Pancake Penguin", "Pets", "Pet", "Coins", 1000, nil, "A happy penguin with a pancake hat.", {118, 160, 214}),
	item("P04", "Jelly Axolotl", "Pets", "Pet", "Wins", 10, "StuckInTheMud", "Win 10 rounds of Stuck in the Mud.", {103, 221, 219}),
	item("P05", "Rocket Snail", "Pets", "Pet", "Level", 8, nil, "Reach level 8 for this tiny rocket rider.", {142, 224, 172}),
	item("P06", "Traffic Crab", "Pets", "Pet", "Coins", 1750, nil, "A blue crab wearing a bright traffic-cone hat.", {83, 176, 232}),
	item("P07", "Teapot Frog", "Pets", "Pet", "Coins", 2000, nil, "A little green frog with teapot charm.", {170, 208, 91}),
	item("P08", "Skater Shark", "Pets", "Pet", "Wins", 10, "TagYoureIt", "Win 10 rounds of Tag You're It.", {78, 203, 224}),
	item("P09", "Disco Duck", "Pets", "Pet", "Coins", 3000, nil, "A sunny duck that brings its own disco backpack.", {255, 216, 70}),
	item("P10", "Cloud Sheep", "Pets", "Pet", "Level", 12, nil, "A fluffy reward for reaching level 12.", {174, 216, 245}),
	item("P11", "Cactus Cat", "Pets", "Pet", "Coins", 4000, nil, "A cuddly cactus kitten with a pink flower.", {115, 202, 113}),
	item("P12", "UFO Jelly", "Pets", "Pet", "Level", 18, nil, "Reach level 18 for a visitor from the playground stars.", {185, 156, 233}),
	item("P13", "Pumpkin Bunny", "Pets", "Pet", "Coins", 5000, nil, "A pumpkin-shaped bunny with leafy ears.", {244, 156, 63}),
	item("P14", "Hoodie Ghost", "Pets", "Pet", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {174, 142, 224}),
	item("P15", "Marshmallow Dragon", "Pets", "Pet", "Coins", 7500, nil, "A soft-coloured little dragon with pink wings.", {247, 179, 205}),
	item("P16", "Banana Gorilla", "Pets", "Pet", "Wins", 25, "BritishBulldog", "Win 25 rounds of British Bulldog.", {238, 200, 65}),
	item("P17", "Gummy Rex", "Pets", "Pet", "Level", 25, nil, "Reach level 25 for a cheerful gummy dinosaur.", {163, 222, 88}),
	item("P18", "Lava Toaster", "Pets", "Pet", "Wins", 50, "StuckInTheMud", "Win 50 rounds of Stuck in the Mud.", {248, 134, 64}),
	item("P19", "Moon Moth", "Pets", "Pet", "Coins", 10000, nil, "A cream and violet companion with crescent wings.", {177, 160, 239}),
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all three games.", {100, 148, 237}),
	item("M01", "Playground Football", "Toys", "Gear", "Coins", 250, nil, "Lobby only. Kick a football that bounces for up to 5 seconds. Recharges in 5 seconds.", {224, 224, 208}),
	item("M02", "Playground Basketball", "Toys", "Gear", "Coins", 350, nil, "Lobby only. Lob a basketball high into the air. It lasts up to 5 seconds and recharges in 5 seconds.", {249, 147, 65}),
	item("M03", "Foam Bonker", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Swing a harmless foam bonker with a star burst on contact. Recharges in 0.8 seconds.", {233, 129, 208}),
	item("M04", "Tumble Barrel", "Toys", "Gear", "Coins", 1000, nil, "Lobby only. Throw a tumbling barrel that bounces for up to 5 seconds. Recharges in 5 seconds.", {191, 139, 84}),
	item("M05", "Zoom Juice", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink for 3 times your normal walking speed for 25 seconds. Recharges when the boost ends.", {69, 205, 220}),
	item("M06", "Spring Sip", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Drink to jump 5 times your normal height for 10 seconds. Recharges when the boost ends.", {176, 221, 76}),
	item("M07", "Ember Elixir", "Toys", "Gear", "Coins", 1250, nil, "Lobby only. Drink, then tap to breathe fire for 10 seconds. Hits burn for 1 damage a second for 10 seconds.", {250, 136, 63}),
	item("M08", "Surprise Present", "Toys", "Gear", "Coins", 500, nil, "Lobby only. Shake a present to release colourful confetti. Recharges in 3 seconds.", {103, 207, 208}),
	item("M09", "Plunger Popper", "Toys", "Gear", "Coins", 4000, nil, "Lobby collectible. You can own and equip this launcher; its action is on hold until the plunger model is ready.", {85, 191, 187}),
	item("M10", "Frost Ray", "Toys", "Gear", "Coins", 5000, nil, "Lobby only. Freeze another player for 2.5 seconds with an icy ray. Recharges in 5 seconds.", {107, 216, 239}),
	item("M11", "Paint Splash", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Throw colourful paint that leaves a splash for 10 seconds. Recharges in 2 seconds.", {225, 118, 204}),
	item("M12", "Eggsploit", "Toys", "Gear", "Coins", 300, nil, "Lobby only. Throw an egg that shakes on impact and pops into confetti. Recharges in 3 seconds.", {238, 226, 184}),
	item("M13", "Cake Toss", "Toys", "Gear", "Coins", 600, nil, "Lobby only. Throw a cake that leaves frosting for 5 seconds. Recharges in 3 seconds.", {204, 157, 122}),
	item("M14", "Camp Torch", "Toys", "Gear", "Coins", 2500, nil, "Lobby only. Touch another player with the held torch to burn for 1 damage a second for 10 seconds.", {253, 168, 64}),
	item("M15", "Bounce Pad", "Toys", "Gear", "Coins", 3000, nil, "Lobby only. Place a shared bounce pad for 15 seconds before it bursts into sparkles. Recharges when the pad expires.", {97, 210, 224}),
}

local emoteAnimations = {}
for _, dance in ipairs({
	{ id = "E01", name = "Dougie", kind = "Coins", amount = 500, catalogId = 114756515400742, animationId = 93650537970037 },
	{ id = "E02", name = "Street Glide", kind = "Coins", amount = 750, catalogId = 137284968787523, animationId = 82378883639086 },
	{ id = "E03", name = "Money Hop Switch", kind = "Coins", amount = 1000, catalogId = 134222090358172, animationId = 132555082396072 },
	{ id = "E04", name = "Coffin Walkout", kind = "Level", amount = 5, catalogId = 117302755748327, animationId = 126771729094882 },
	{ id = "E05", name = "The Tylil Dance", kind = "Coins", amount = 1500, catalogId = 107010273569673, animationId = 110494040742516 },
	{ id = "E06", name = "Scuba Trend", kind = "Level", amount = 8, catalogId = 135211326811898, animationId = 140349022227594 },
	{ id = "E08", name = "Rollie", kind = "Coins", amount = 2000, catalogId = 110827382619943, animationId = 117558759116256 },
	{ id = "E09", name = "Out West", kind = "Coins", amount = 2500, catalogId = 133595410032960, animationId = 103687288237641 },
	{ id = "E10", name = "Four Lokos Dance", kind = "Level", amount = 12, catalogId = 115906496196760, animationId = 105190540415890 },
	{ id = "E11", name = "Griddy", kind = "Coins", amount = 5000, catalogId = 77017926307035, animationId = 81913798511136 },
	{ id = "E12", name = "Gangstar Dance", kind = "Coins", amount = 3000, catalogId = 84110142550799, animationId = 93941266454007 },
	{ id = "E13", name = "Keep It Gangsta", kind = "Level", amount = 16, catalogId = 100951835636163, animationId = 92659655601730 },
	{ id = "E14", name = "Jabba Switchway", kind = "Coins", amount = 3500, catalogId = 104940682593173, animationId = 78280967285254 },
	{ id = "E15", name = "Billy Bounce", kind = "Level", amount = 20, catalogId = 93450937830334, animationId = 119280135350752 },
	{ id = "E16", name = "Jamal Brazil Groove", kind = "Coins", amount = 4000, catalogId = 117119421748582, animationId = 106865236633450 },
	{ id = "E17", name = "67", kind = "Level", amount = 25, catalogId = 100498935359536, animationId = 108639244526475 },
	{ id = "E18", name = "Orange Justice", kind = "Coins", amount = 6500, catalogId = 110064349530772, animationId = 95127716920692 },
	{ id = "E19", name = "Dab Steps", kind = "Coins", amount = 4500, catalogId = 126353729413555, animationId = 104609460346094 },
	{ id = "E20", name = "Creepin Dance", kind = "Coins", amount = 5000, catalogId = 80985588930231, animationId = 95428460379424 },
	{ id = "E21", name = "Nervy Dance", kind = "Level", amount = 30, catalogId = 125328720114284, animationId = 90018336892195 },
	{ id = "E22", name = "Pretty Young Thing", kind = "Coins", amount = 7500, catalogId = 137234266130963, animationId = 108374677470972 },
	{ id = "E23", name = "Party Rock Anthem", kind = "Coins", amount = 10000, catalogId = 105248382902194, animationId = 134459607456762 },
	{ id = "E24", name = "Passinho do Jamal", kind = "Level", amount = 35, catalogId = 137057022541237, animationId = 100468196980144 },
	{ id = "E25", name = "Camden Bop", kind = "Coins", amount = 6000, catalogId = 86411651121424, animationId = 134644266320983 },
	{ id = "E26", name = "Every Beat", kind = "Level", amount = 40, catalogId = 134311528115559, animationId = 136095999219650 },
	{ id = "E27", name = "One Hand Push Ups", kind = "Coins", amount = 8000, catalogId = 121644855433565, animationId = 74800678690946 },
	{ id = "E28", name = "Gangnam Style", kind = "Coins", amount = 12500, catalogId = 80923445784018, animationId = 131104967711844 },
	{ id = "E29", name = "Murda Bend", kind = "Coins", amount = 9000, catalogId = 96843993997234, animationId = 90158235751747 },
	{ id = "E30", name = "Monkey", kind = "Level", amount = 3, catalogId = 3716636630, animationId = 10714388352 },
	{ id = "E31", name = "NLE Choppa Demon", kind = "Coins", amount = 15000, catalogId = 96181123599016, animationId = 133898543831391 },
	{ id = "E32", name = "Brazilian Dance", kind = "Level", amount = 50, catalogId = 76636280785091, animationId = 138980897636026 },
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

local suppliedThumbnails = {
	["B01"] = "rbxassetid://103030924200276",
	["B02"] = "rbxassetid://113172886921867",
	["B03"] = "rbxassetid://125747852383163",
	["B04"] = "rbxassetid://127202176052176",
	["B05"] = "rbxassetid://96016591192959",
	["B06"] = "rbxassetid://128970507196840",
	["B07"] = "rbxassetid://108736504252281",
	["B08"] = "rbxassetid://89882889964123",
	["B09"] = "rbxassetid://77618462621016",
	["B10"] = "rbxassetid://132453529736998",
	["B11"] = "rbxassetid://77939197144871",
	["B12"] = "rbxassetid://125123911675366",
	["B13"] = "rbxassetid://103460237585059",
	["B14"] = "rbxassetid://123941198531759",
	["B15"] = "rbxassetid://103777401073836",
	["P01"] = "rbxassetid://111151667063771",
	["P02"] = "rbxassetid://74489993061441",
	["P03"] = "rbxassetid://79432424395104",
	["P04"] = "rbxassetid://84237840954591",
	["P05"] = "rbxassetid://76813277166260",
	["P06"] = "rbxassetid://128747986158558",
	["P07"] = "rbxassetid://130019925281001",
	["P08"] = "rbxassetid://122488839946964",
	["P09"] = "rbxassetid://72876142531984",
	["P10"] = "rbxassetid://83399670130730",
	["P11"] = "rbxassetid://138937113451446",
	["P12"] = "rbxassetid://91507747886254",
	["P13"] = "rbxassetid://76111324896677",
	["P14"] = "rbxassetid://74049460609660",
	["P15"] = "rbxassetid://71646045256380",
	["P16"] = "rbxassetid://74938519999469",
	["P17"] = "rbxassetid://74706180338952",
	["P18"] = "rbxassetid://115725394692957",
	["P19"] = "rbxassetid://117853703978463",
	["P20"] = "rbxassetid://113206048566146",
	["M01"] = "rbxassetid://76461123342040",
	["M02"] = "rbxassetid://87689116244271",
	["M03"] = "rbxassetid://102723663713155",
	["M04"] = "rbxassetid://108236395872604",
	["M05"] = "rbxassetid://135585921369557",
	["M06"] = "rbxassetid://100391547251774",
	["M07"] = "rbxassetid://114996802464499",
	["M08"] = "rbxassetid://93885559186954",
	["M09"] = "rbxassetid://95787089363505",
	["M10"] = "rbxassetid://86928317634247",
	["M11"] = "rbxassetid://78326564646666",
	["M12"] = "rbxassetid://108447275819300",
	["M13"] = "rbxassetid://115194745550655",
	["M14"] = "rbxassetid://120473663146818",
	["M15"] = "rbxassetid://91563971609941",
}
for _, entry in ipairs(items) do
	if suppliedThumbnails[entry.id] then
		entry.thumbnail = suppliedThumbnails[entry.id]
		entry.thumbnailSource = "UI-512"
	end
end

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= (entry.slot == "Emote" and 15000 or 10000), "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	MaxCoinPrice = 15000,
	MaxEquipmentCoinPrice = 10000,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", All = "total" },
}



]=],after=[=[local function item(id, name, category, slot, kind, amount, gameId, description, color)
	return {
		id = id,
		name = name,
		category = category,
		slot = slot,
		available = true,
		price = kind == "Coins" and amount or 0,
		unlock = { kind = kind, amount = amount, gameId = gameId },
		description = description,
		color = Color3.fromRGB(color[1], color[2], color[3]),
		assetId = id,
	}
end

local items = {
	item("B01", "Starter Slugger", "Bats", "Bat", "Starter", 0, nil, "Your first Bulldog bat. Ready from the start.", {218, 155, 76}),
	item("B02", "Schoolyard Alloy", "Bats", "Bat", "Coins", 2250, nil, "A silver schoolyard classic with a blue grip.", {139, 185, 224}),
	item("B03", "Varsity Victory", "Bats", "Bat", "Level", 5, nil, "Earn your varsity colours by reaching level 5.", {241, 91, 101}),
	item("B04", "Street Cone", "Bats", "Bat", "Coins", 3750, nil, "Bold orange with bright playground stripes.", {255, 147, 57}),
	item("B05", "Bubblegum Bonker", "Bats", "Bat", "Level", 10, nil, "A sweet reward for reaching level 10.", {244, 113, 184}),
	item("B06", "Mudslinger", "Bats", "Bat", "Wins", 25, "StuckInTheMud", "Win 25 rounds of Stuck in the Mud.", {142, 126, 73}),
	item("B07", "Heat Coil", "Bats", "Bat", "Wins", 50, "StuckInTheMud", "A heated trophy for 50 Stuck in the Mud wins.", {255, 152, 67}),
	item("B08", "Frostbite", "Bats", "Bat", "Coins", 12000, nil, "A chunky ice-blue barrel and a deep blue grip.", {116, 225, 245}),
	item("B09", "Thunder Circuit", "Bats", "Bat", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {67, 143, 243}),
	item("B10", "Pixel Party", "Bats", "Bat", "Level", 20, nil, "Reach level 20 for this bright arcade bat.", {213, 97, 228}),
	item("B11", "Cosmic Orbit", "Bats", "Bat", "Coins", 30000, nil, "A violet barrel with a silver orbit ring.", {153, 120, 235}),
	item("B12", "Royal Champion", "Bats", "Bat", "Wins", 50, "BritishBulldog", "A crown for 50 British Bulldog wins.", {248, 209, 92}),
	item("B13", "Skatepark Stripe", "Bats", "Bat", "Coins", 7500, nil, "Blue, mint and coral playground style.", {82, 176, 226}),
	item("B14", "Deep Sea", "Bats", "Bat", "Coins", 18000, nil, "Ocean waves on a navy and turquoise barrel.", {71, 193, 191}),
	item("B15", "Sunburst", "Bats", "Bat", "Level", 30, nil, "A sunny reward for reaching level 30.", {255, 180, 63}),
	item("P01", "Pocket Bulldog", "Pets", "Pet", "Coins", 1500, nil, "A cheerful little schoolyard companion.", {224, 184, 131}),
	item("P02", "Toast Capybara", "Pets", "Pet", "Level", 3, nil, "Reach level 3 for this sleepy toast-shaped friend.", {209, 153, 86}),
	item("P03", "Pancake Penguin", "Pets", "Pet", "Coins", 3000, nil, "A happy penguin with a pancake hat.", {118, 160, 214}),
	item("P04", "Jelly Axolotl", "Pets", "Pet", "Wins", 10, "StuckInTheMud", "Win 10 rounds of Stuck in the Mud.", {103, 221, 219}),
	item("P05", "Rocket Snail", "Pets", "Pet", "Level", 8, nil, "Reach level 8 for this tiny rocket rider.", {142, 224, 172}),
	item("P06", "Traffic Crab", "Pets", "Pet", "Coins", 5250, nil, "A blue crab wearing a bright traffic-cone hat.", {83, 176, 232}),
	item("P07", "Teapot Frog", "Pets", "Pet", "Coins", 6000, nil, "A little green frog with teapot charm.", {170, 208, 91}),
	item("P08", "Skater Shark", "Pets", "Pet", "Wins", 10, "TagYoureIt", "Win 10 rounds of Tag You're It.", {78, 203, 224}),
	item("P09", "Disco Duck", "Pets", "Pet", "Coins", 9000, nil, "A sunny duck that brings its own disco backpack.", {255, 216, 70}),
	item("P10", "Cloud Sheep", "Pets", "Pet", "Level", 12, nil, "A fluffy reward for reaching level 12.", {174, 216, 245}),
	item("P11", "Cactus Cat", "Pets", "Pet", "Coins", 12000, nil, "A cuddly cactus kitten with a pink flower.", {115, 202, 113}),
	item("P12", "UFO Jelly", "Pets", "Pet", "Level", 18, nil, "Reach level 18 for a visitor from the playground stars.", {185, 156, 233}),
	item("P13", "Pumpkin Bunny", "Pets", "Pet", "Coins", 15000, nil, "A pumpkin-shaped bunny with leafy ears.", {244, 156, 63}),
	item("P14", "Hoodie Ghost", "Pets", "Pet", "Wins", 25, "TagYoureIt", "Win 25 rounds of Tag You're It.", {174, 142, 224}),
	item("P15", "Marshmallow Dragon", "Pets", "Pet", "Coins", 22500, nil, "A soft-coloured little dragon with pink wings.", {247, 179, 205}),
	item("P16", "Banana Gorilla", "Pets", "Pet", "Wins", 25, "BritishBulldog", "Win 25 rounds of British Bulldog.", {238, 200, 65}),
	item("P17", "Gummy Rex", "Pets", "Pet", "Level", 25, nil, "Reach level 25 for a cheerful gummy dinosaur.", {163, 222, 88}),
	item("P18", "Lava Toaster", "Pets", "Pet", "Wins", 50, "StuckInTheMud", "Win 50 rounds of Stuck in the Mud.", {248, 134, 64}),
	item("P19", "Moon Moth", "Pets", "Pet", "Coins", 30000, nil, "A cream and violet companion with crescent wings.", {177, 160, 239}),
	item("P20", "Royal Slime", "Pets", "Pet", "Wins", 100, "All", "Win 100 rounds across all three games.", {100, 148, 237}),
	item("M01", "Playground Football", "Toys", "Gear", "Coins", 750, nil, "Lobby only. Kick a football that bounces for up to 5 seconds. Recharges in 5 seconds.", {224, 224, 208}),
	item("M02", "Playground Basketball", "Toys", "Gear", "Coins", 1050, nil, "Lobby only. Lob a basketball high into the air. It lasts up to 5 seconds and recharges in 5 seconds.", {249, 147, 65}),
	item("M03", "Foam Bonker", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Swing a harmless foam bonker with a star burst on contact. Recharges in 0.8 seconds.", {233, 129, 208}),
	item("M04", "Tumble Barrel", "Toys", "Gear", "Coins", 3000, nil, "Lobby only. Throw a tumbling barrel that bounces for up to 5 seconds. Recharges in 5 seconds.", {191, 139, 84}),
	item("M05", "Zoom Juice", "Toys", "Gear", "Coins", 2250, nil, "Lobby only. Drink for 3 times your normal walking speed for 25 seconds. Recharges when the boost ends.", {69, 205, 220}),
	item("M06", "Spring Sip", "Toys", "Gear", "Coins", 2250, nil, "Lobby only. Drink to jump 5 times your normal height for 10 seconds. Recharges when the boost ends.", {176, 221, 76}),
	item("M07", "Ember Elixir", "Toys", "Gear", "Coins", 3750, nil, "Lobby only. Drink, then tap to breathe fire for 10 seconds. Hits burn for 1 damage a second for 10 seconds.", {250, 136, 63}),
	item("M08", "Surprise Present", "Toys", "Gear", "Coins", 1500, nil, "Lobby only. Shake a present to release colourful confetti. Recharges in 3 seconds.", {103, 207, 208}),
	item("M09", "Plunger Popper", "Toys", "Gear", "Coins", 12000, nil, "Lobby collectible. You can own and equip this launcher; its action is on hold until the plunger model is ready.", {85, 191, 187}),
	item("M10", "Frost Ray", "Toys", "Gear", "Coins", 15000, nil, "Lobby only. Freeze another player for 2.5 seconds with an icy ray. Recharges in 5 seconds.", {107, 216, 239}),
	item("M11", "Paint Splash", "Toys", "Gear", "Coins", 4500, nil, "Lobby only. Throw colourful paint that leaves a splash for 10 seconds. Recharges in 2 seconds.", {225, 118, 204}),
	item("M12", "Eggsploit", "Toys", "Gear", "Coins", 900, nil, "Lobby only. Throw an egg that shakes on impact and pops into confetti. Recharges in 3 seconds.", {238, 226, 184}),
	item("M13", "Cake Toss", "Toys", "Gear", "Coins", 1800, nil, "Lobby only. Throw a cake that leaves frosting for 5 seconds. Recharges in 3 seconds.", {204, 157, 122}),
	item("M14", "Camp Torch", "Toys", "Gear", "Coins", 7500, nil, "Lobby only. Touch another player with the held torch to burn for 1 damage a second for 10 seconds.", {253, 168, 64}),
	item("M15", "Bounce Pad", "Toys", "Gear", "Coins", 9000, nil, "Lobby only. Place a shared bounce pad for 15 seconds before it bursts into sparkles. Recharges when the pad expires.", {97, 210, 224}),
	item("B16", "Fossil Slugger", "Bats", "Bat", "Coins", 12000, nil, "A recognisable long tapered baseball bat with a broad ivory fossil-bone barrel, three chunky tan rib-like rings fused around the upper barrel, dark navy collar and a dark brown wrapped grip.", {232, 213, 163}),
	item("B17", "Dragon Scale", "Bats", "Bat", "Level", 100, nil, "A long tapered baseball bat with a glossy emerald barrel clad in four broad overlapping rounded dragon-scale bands, golden end cap and collar, plum-purple grip and gold knob.", {71, 180, 119}),
	item("B18", "Breakfast Bonker", "Bats", "Bat", "Coins", 16000, nil, "A long baseball bat with a golden toasted waffle-patterned barrel, broad shallow 3-by-5 waffle grid following its rounded cylinder, a glossy caramel cap dripping a little onto the top third, cream butter-coloured rim.", {232, 170, 75}),
	item("B19", "Cloud Nine", "Bats", "Bat", "Level", 75, nil, "An elegant chunky baseball bat with a pearl-white rounded barrel, sky-blue lower taper, two broad embossed feather panels wrapping along the barrel and a lavender collar.", {225, 226, 255}),
	item("B20", "Bamboo Bruiser", "Bats", "Bat", "Wins", 100, "StuckInTheMud", "A recognisable baseball bat made of glossy jade-green bamboo-like segments, thick broad upper barrel and smoothly narrowing shaft, pale cream node bands, dark navy collar, tan rope-textured handgrip rendered as four simple broad wraps and flat green knob.", {121, 181, 93}),
	item("B21", "Arcade Combo", "Bats", "Bat", "Coins", 25000, nil, "A chunky baseball bat with a dark violet elongated cylindrical barrel with broad cyan edge rails and exactly three large glossy arcade buttons arranged lengthwise, red yellow and mint.", {90, 188, 247}),
	item("B22", "Honeycomb Hitter", "Bats", "Bat", "Coins", 30000, nil, "A warm amber baseball bat with a rounded barrel wrapped in five large golden hexagonal honeycomb panels, a few broad opaque golden honey drips moulded against its surface, cream tip cap, navy collar and black-and-yellow striped rubber grip.", {250, 196, 57}),
	item("B23", "Clockwork Clobber", "Bats", "Bat", "Coins", 40000, nil, "A copper and cream baseball bat with a long thick tapered barrel, two broad navy collars and one LARGE simple brass gear inset into the barrel side.", {192, 145, 85}),
	item("B24", "Patchwork Popper", "Bats", "Bat", "Level", 250, nil, "A long rounded baseball bat with purple and mint-green broad stitched fabric-like panels, simple cream cross stitches and one large round orange button mounted near the upper barrel.", {217, 122, 204}),
	item("B25", "Prism Champion", "Bats", "Bat", "Coins", 50000, nil, "A spectacular long baseball bat with an opaque faceted royal-purple and cyan crystal barrel, six broad flat facets, a blunt chamfered tip and two thick cream-and-gold reinforcing collars.", {119, 193, 243}),
	item("M16", "Snowglobe Sip", "Toys", "Gear", "Coins", 12000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {127, 214, 245}),
	item("M17", "Snowball Lobber", "Toys", "Gear", "Coins", 22000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {93, 162, 229}),
	item("M18", "Bubble Blower", "Toys", "Gear", "Coins", 15000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {246, 142, 196}),
	item("M19", "Slippy Banana", "Toys", "Gear", "Coins", 13000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {255, 216, 85}),
	item("M20", "Spring Glove", "Toys", "Gear", "Coins", 20000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {241, 112, 96}),
	item("M21", "Sticky Honey", "Toys", "Gear", "Coins", 18000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {240, 180, 73}),
	item("M22", "Whoopee Whump", "Toys", "Gear", "Coins", 16000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {242, 99, 103}),
	item("M23", "Magnet Mover", "Toys", "Gear", "Coins", 30000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {234, 94, 93}),
	item("M24", "Ricochet Flyer", "Toys", "Gear", "Coins", 35000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {89, 211, 234}),
	item("M25", "Pop-Up Surprise", "Toys", "Gear", "Coins", 40000, nil, "Lobby collectible. Own and equip this toy; its action is coming later.", {237, 126, 105}),
	item("P21", "Crystal Drake", "Pets", "Pet", "Coins", 50000, nil, "A chubby sapphire-blue baby dragon with an oversized friendly head, two short ivory horns, lavender wing membranes, a pale blue belly, four sturdy little feet and a curled tail.", {89, 170, 239}),
	item("P22", "Ember Wyrmling", "Pets", "Pet", "Wins", 150, "StuckInTheMud", "A squat brick-red baby dragon with broad orange folded wings, cream segmented belly, rounded charcoal horns and a short tail with a solid orange flame-shaped fin.", {233, 111, 69}),
	item("P23", "Cloud Pegasus", "Pets", "Pet", "Level", 150, nil, "An adorable pearl-white miniature winged horse, rounded lavender mane and curled tail, sky-blue hooves, two thick feathered white wings attached at the shoulders and a small gold collar.", {223, 210, 248}),
	item("P24", "Suncrest Griffin", "Pets", "Pet", "Wins", 200, "BritishBulldog", "A chubby baby griffin with a cream eagle head, chunky golden beak, small swept-back gold head feathers, caramel lion body, stout golden front talons and rounded lion rear paws.", {237, 186, 85}),
	item("P25", "Halo Cherub", "Pets", "Pet", "Level", 250, nil, "One tiny angel companion pet with a round cream face, two shiny navy eyes, a tiny smiling mouth, a simple pale-blue bell-shaped robe/body, stubby hands and feet, and two attached layered ivory wings.", {254, 225, 157}),
	item("P26", "Pebble Triceratops", "Pets", "Pet", "Coins", 18000, nil, "A chubby turquoise baby triceratops with a huge rounded head frill edged in chunky cream knobs, two short blunt cream brow horns and one smaller nose horn, four squat legs and a short tail.", {184, 206, 126}),
	item("P27", "Fern Stegosaurus", "Pets", "Pet", "Coins", 22000, nil, "A cheerful moss-green baby stegosaurus with a plump low body, small round head, four squat cream-toed legs and two rows of five broad orange leaf-shaped dorsal plates attached to its back.", {109, 184, 108}),
	item("P28", "Sky Pterodactyl", "Pets", "Pet", "Level", 100, nil, "A cute lavender baby pterosaur standing with two little feet and compact partially open wings, a long rounded peach beak, a small backward swept head crest and shiny navy eyes.", {156, 187, 231}),
	item("P29", "Tundra Mammoth", "Pets", "Pet", "Coins", 35000, nil, "A tiny shaggy cinnamon-brown woolly mammoth with a huge round head, short lifted trunk, two short curved ivory tusks, small caramel ears and four stubby feet.", {187, 150, 118}),
	item("P30", "Crowned Pig", "Pets", "Pet", "Coins", 45000, nil, "A lovable plump PINK PIG wearing a prominent GOLD CROWN with three broad points and one red square jewel, a playful Minecraft king-pig homage interpreted as an original rounded cartoon pet.", {247, 173, 191}),
	item("P31", "Waffle Tortoise", "Pets", "Pet", "Coins", 24000, nil, "One adorable little golden tortoise whose thick square-rounded shell is a golden waffle with a very clear simple 3-by-3 grid of recessed pockets, a glossy caramel syrup patch and one thick pale-yellow butter square attached on top.", {224, 177, 87}),
	item("P32", "Pancake Pal", "Pets", "Pet", "Level", 75, nil, "A cute living stack of THREE thick fluffy golden pancakes as one compact pet, glossy caramel syrup draped over the top edge and a pale-yellow butter cube fixed on top.", {234, 182, 101}),
	item("P33", "Velvet Jumper", "Pets", "Pet", "Coins", 28000, nil, "One cute plush-like jumping spider, a single round plum-purple body and smaller attached head with two oversized glossy navy front eyes plus two tiny eyes above.", {155, 113, 200}),
	item("P34", "Patchwork Zombie", "Pets", "Pet", "Wins", 150, "TagYoureIt", "A silly friendly chibi zombie companion with a large square-rounded mint-green head, one button-shaped eye and one shiny navy eye, a big goofy smile with two chunky teeth.", {139, 189, 112}),
	item("P35", "Sunfeather Phoenix", "Pets", "Pet", "Level", 500, nil, "One adorable baby phoenix with a rounded orange body, huge expressive navy eyes, short gold beak and feet, three broad swept orange-and-yellow crest feathers, attached compact red wings, and a dramatic fan of THREE thick layered flame-shaped tail feathers in yellow, orange and red.", {249, 170, 55}),
}

local emoteAnimations = {}
for _, dance in ipairs({
	{ id = "E01", name = "Dougie", kind = "Coins", amount = 1500, catalogId = 114756515400742, animationId = 93650537970037 },
	{ id = "E02", name = "Street Glide", kind = "Coins", amount = 2250, catalogId = 137284968787523, animationId = 82378883639086 },
	{ id = "E03", name = "Money Hop Switch", kind = "Coins", amount = 3000, catalogId = 134222090358172, animationId = 132555082396072 },
	{ id = "E04", name = "Coffin Walkout", kind = "Level", amount = 5, catalogId = 117302755748327, animationId = 126771729094882 },
	{ id = "E05", name = "The Tylil Dance", kind = "Coins", amount = 4500, catalogId = 107010273569673, animationId = 110494040742516 },
	{ id = "E06", name = "Scuba Trend", kind = "Level", amount = 8, catalogId = 135211326811898, animationId = 140349022227594 },
	{ id = "E08", name = "Rollie", kind = "Coins", amount = 6000, catalogId = 110827382619943, animationId = 117558759116256 },
	{ id = "E09", name = "Out West", kind = "Coins", amount = 7500, catalogId = 133595410032960, animationId = 103687288237641 },
	{ id = "E10", name = "Four Lokos Dance", kind = "Level", amount = 12, catalogId = 115906496196760, animationId = 105190540415890 },
	{ id = "E11", name = "Griddy", kind = "Coins", amount = 15000, catalogId = 77017926307035, animationId = 81913798511136 },
	{ id = "E12", name = "Gangstar Dance", kind = "Coins", amount = 9000, catalogId = 84110142550799, animationId = 93941266454007 },
	{ id = "E13", name = "Keep It Gangsta", kind = "Level", amount = 16, catalogId = 100951835636163, animationId = 92659655601730 },
	{ id = "E14", name = "Jabba Switchway", kind = "Coins", amount = 10500, catalogId = 104940682593173, animationId = 78280967285254 },
	{ id = "E15", name = "Billy Bounce", kind = "Level", amount = 20, catalogId = 93450937830334, animationId = 119280135350752 },
	{ id = "E16", name = "Jamal Brazil Groove", kind = "Coins", amount = 12000, catalogId = 117119421748582, animationId = 106865236633450 },
	{ id = "E17", name = "67", kind = "Level", amount = 25, catalogId = 100498935359536, animationId = 108639244526475 },
	{ id = "E18", name = "Orange Justice", kind = "Coins", amount = 19500, catalogId = 110064349530772, animationId = 95127716920692 },
	{ id = "E19", name = "Dab Steps", kind = "Coins", amount = 13500, catalogId = 126353729413555, animationId = 104609460346094 },
	{ id = "E20", name = "Creepin Dance", kind = "Coins", amount = 15000, catalogId = 80985588930231, animationId = 95428460379424 },
	{ id = "E21", name = "Nervy Dance", kind = "Level", amount = 30, catalogId = 125328720114284, animationId = 90018336892195 },
	{ id = "E22", name = "Pretty Young Thing", kind = "Coins", amount = 22500, catalogId = 137234266130963, animationId = 108374677470972 },
	{ id = "E23", name = "Party Rock Anthem", kind = "Coins", amount = 30000, catalogId = 105248382902194, animationId = 134459607456762 },
	{ id = "E24", name = "Passinho do Jamal", kind = "Level", amount = 35, catalogId = 137057022541237, animationId = 100468196980144 },
	{ id = "E25", name = "Camden Bop", kind = "Coins", amount = 18000, catalogId = 86411651121424, animationId = 134644266320983 },
	{ id = "E26", name = "Every Beat", kind = "Level", amount = 40, catalogId = 134311528115559, animationId = 136095999219650 },
	{ id = "E27", name = "One Hand Push Ups", kind = "Coins", amount = 24000, catalogId = 121644855433565, animationId = 74800678690946 },
	{ id = "E28", name = "Gangnam Style", kind = "Coins", amount = 37500, catalogId = 80923445784018, animationId = 131104967711844 },
	{ id = "E29", name = "Murda Bend", kind = "Coins", amount = 27000, catalogId = 96843993997234, animationId = 90158235751747 },
	{ id = "E30", name = "Monkey", kind = "Level", amount = 3, catalogId = 3716636630, animationId = 10714388352 },
	{ id = "E31", name = "NLE Choppa Demon", kind = "Coins", amount = 45000, catalogId = 96181123599016, animationId = 133898543831391 },
	{ id = "E32", name = "Brazilian Dance", kind = "Level", amount = 50, catalogId = 76636280785091, animationId = 138980897636026 },
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

local suppliedThumbnails = {
	["B16"] = "rbxassetid://93718576682762",
	["B17"] = "rbxassetid://90690876218946",
	["B18"] = "rbxassetid://136532648735315",
	["B19"] = "rbxassetid://74566241696564",
	["B20"] = "rbxassetid://89577365506241",
	["B21"] = "rbxassetid://87448555104310",
	["B22"] = "rbxassetid://121107988866639",
	["B23"] = "rbxassetid://124353995030650",
	["B24"] = "rbxassetid://122610247795492",
	["B25"] = "rbxassetid://84320288725225",
	["M16"] = "rbxassetid://137233677326237",
	["M17"] = "rbxassetid://100196340349310",
	["M18"] = "rbxassetid://108922005145390",
	["M19"] = "rbxassetid://138594944253005",
	["M20"] = "rbxassetid://113055348827876",
	["M21"] = "rbxassetid://87962378887990",
	["M22"] = "rbxassetid://87262880627267",
	["M23"] = "rbxassetid://72259913966212",
	["M24"] = "rbxassetid://71753510653959",
	["M25"] = "rbxassetid://70446171295062",
	["P21"] = "rbxassetid://102415565658167",
	["P22"] = "rbxassetid://124542948595389",
	["P23"] = "rbxassetid://136302530480282",
	["P24"] = "rbxassetid://83083028780532",
	["P25"] = "rbxassetid://112851232107682",
	["P26"] = "rbxassetid://106054275413428",
	["P27"] = "rbxassetid://98519809843976",
	["P28"] = "rbxassetid://83779715530699",
	["P29"] = "rbxassetid://92025994579959",
	["P30"] = "rbxassetid://134613010096847",
	["P31"] = "rbxassetid://119087155825550",
	["P32"] = "rbxassetid://133184161504265",
	["P33"] = "rbxassetid://77099692424415",
	["P34"] = "rbxassetid://139150635065122",
	["P35"] = "rbxassetid://124088547333228",
	["B01"] = "rbxassetid://103030924200276",
	["B02"] = "rbxassetid://113172886921867",
	["B03"] = "rbxassetid://125747852383163",
	["B04"] = "rbxassetid://127202176052176",
	["B05"] = "rbxassetid://96016591192959",
	["B06"] = "rbxassetid://128970507196840",
	["B07"] = "rbxassetid://108736504252281",
	["B08"] = "rbxassetid://89882889964123",
	["B09"] = "rbxassetid://77618462621016",
	["B10"] = "rbxassetid://132453529736998",
	["B11"] = "rbxassetid://77939197144871",
	["B12"] = "rbxassetid://125123911675366",
	["B13"] = "rbxassetid://103460237585059",
	["B14"] = "rbxassetid://123941198531759",
	["B15"] = "rbxassetid://103777401073836",
	["P01"] = "rbxassetid://111151667063771",
	["P02"] = "rbxassetid://74489993061441",
	["P03"] = "rbxassetid://79432424395104",
	["P04"] = "rbxassetid://84237840954591",
	["P05"] = "rbxassetid://76813277166260",
	["P06"] = "rbxassetid://128747986158558",
	["P07"] = "rbxassetid://130019925281001",
	["P08"] = "rbxassetid://122488839946964",
	["P09"] = "rbxassetid://72876142531984",
	["P10"] = "rbxassetid://83399670130730",
	["P11"] = "rbxassetid://138937113451446",
	["P12"] = "rbxassetid://91507747886254",
	["P13"] = "rbxassetid://76111324896677",
	["P14"] = "rbxassetid://74049460609660",
	["P15"] = "rbxassetid://71646045256380",
	["P16"] = "rbxassetid://74938519999469",
	["P17"] = "rbxassetid://74706180338952",
	["P18"] = "rbxassetid://115725394692957",
	["P19"] = "rbxassetid://117853703978463",
	["P20"] = "rbxassetid://113206048566146",
	["M01"] = "rbxassetid://76461123342040",
	["M02"] = "rbxassetid://87689116244271",
	["M03"] = "rbxassetid://102723663713155",
	["M04"] = "rbxassetid://108236395872604",
	["M05"] = "rbxassetid://135585921369557",
	["M06"] = "rbxassetid://100391547251774",
	["M07"] = "rbxassetid://114996802464499",
	["M08"] = "rbxassetid://93885559186954",
	["M09"] = "rbxassetid://95787089363505",
	["M10"] = "rbxassetid://86928317634247",
	["M11"] = "rbxassetid://78326564646666",
	["M12"] = "rbxassetid://108447275819300",
	["M13"] = "rbxassetid://115194745550655",
	["M14"] = "rbxassetid://120473663146818",
	["M15"] = "rbxassetid://91563971609941",
}
for _, entry in ipairs(items) do
	if suppliedThumbnails[entry.id] then
		entry.thumbnail = suppliedThumbnails[entry.id]
		entry.thumbnailSource = "UI-512"
	end
end

local byId = {}
for _, entry in ipairs(items) do
	assert(byId[entry.id] == nil, "Duplicate catalog ID: " .. entry.id)
	assert(entry.price >= 0 and entry.price <= 50000, "Catalog price exceeds the coin cap")
	byId[entry.id] = entry
end

byId.M09.toyActionPending = true
for index = 16, 25 do byId[string.format("M%02d", index)].toyActionPending = true end

return {
	Items = items,
	ById = byId,
	Categories = { "All", "Bats", "Pets", "Toys", "Emotes" },
	EmoteAnimations = emoteAnimations,
	StarterBat = "B01",
	PriceVersion = 20261007,
	MaxCoinPrice = 50000,
	MaxEquipmentCoinPrice = 50000,
	MaxToySlots = 4,
	GameNames = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud", All = "total" },
}



]=]},
{name="PlaygroundEquipmentService.luau",target=game.ServerScriptService.PlaygroundEquipmentService,before=[=[local Players = game:GetService("Players")
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

function Equipment.new(batServices, toys)
	return setmetatable({ running = false, records = {}, connections = {}, batServices = batServices or {}, toys = toys }, Equipment)
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
	if record.character then
		record.character:SetAttribute("PCBatHeld", false)
		record.character:SetAttribute("PCBatGame", nil)
	end
	self:_cancelBatHit(record)
	if record.batConnections then disconnect(record.batConnections) end
	local model = record.bat
	record.bat = nil
	record.batId = nil
	record.batGame = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	if self.toys then self.toys:CancelAction(record.player) end
	if record.character then record.character:SetAttribute("PCToyHeld", nil) end
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
	local function mirrorHeld(held)
		if record.bat ~= carrier or not record.character then return end
		record.character:SetAttribute("PCBatHeld", held)
		record.character:SetAttribute("PCBatGame", held and gameId or nil)
	end
	table.insert(record.batConnections, carrier.Equipped:Connect(function() mirrorHeld(true) end))
	table.insert(record.batConnections, carrier.Activated:Connect(function() self:_activateBat(record) end))
	table.insert(record.batConnections, carrier.Unequipped:Connect(function()
		mirrorHeld(false)
		self:_cancelBatHit(record)
		self:_queue(record)
	end))
	table.insert(record.batConnections, carrier.Destroying:Connect(function() mirrorHeld(false) self:_cancelBatHit(record) end))
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	carrier.Parent = record.player:FindFirstChildOfClass("Backpack") or record.character
	if humanoid then humanoid:EquipTool(carrier) end
	mirrorHeld(carrier.Parent == record.character)
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
	tool.ToolTip = item.name .. " · lobby toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = true
	tool.ManualActivationOnly = true
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("PCToy", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	local function mirrorHeld(held)
		if record.gear ~= tool or not record.character then return end
		record.character:SetAttribute("PCToyHeld", held and item.id or nil)
		if self.toys then
			if held then self.toys:Hold(record.player) else self.toys:CancelAction(record.player) end
		end
	end
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) else mirrorHeld(true) end
	end))
	table.insert(record.gearConnections, tool.Unequipped:Connect(function() mirrorHeld(false) end))
	if item.id == "M14" then
		local flame = anchorPart("TorchFlame")
		flame.CFrame = CFrame.new(0, size.Y - math.min(size.Y * 0.25, 0.45), -size.Z * 0.2)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, flame, flame
		local fire = Instance.new("Fire")
		fire.Name, fire.Size, fire.Heat, fire.Parent = "CampFlame", 2.4, 3, flame
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 170, 70), 0.6, 9, flame
	end
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	mirrorHeld(tool.Parent == record.character)
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		if self.toys then self.toys:ClearPlayer(player) end
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
		character:SetAttribute("PCBatHeld", true)
		character:SetAttribute("PCBatGame", gameId)
	end
	if participating(player) and self.toys then self.toys:ClearPlayer(player) end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	elseif record.gear.Parent ~= character then
		humanoid:EquipTool(record.gear)
		character:SetAttribute("PCToyHeld", gear.id)
		if self.toys then self.toys:Hold(player) end
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	if self.toys then self.toys:ClearPlayer(record.player) end
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	character:SetAttribute("PCBatHeld", false)
	character:SetAttribute("PCBatGame", nil)
	record.humanoid = nil
	local function bindHumanoid()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and record.humanoid ~= humanoid then
			record.humanoid = humanoid
			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				if self.toys then self.toys:ClearPlayer(record.player) end
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	bindHumanoid()
	table.insert(record.characterConnections, character.ChildAdded:Connect(function()
		bindHumanoid()
		self:_queue(record)
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function()
		self:_queue(record)
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
			if self.toys then self.toys:ClearPlayer(record.player) end
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
	if self.toys then self.toys:ClearPlayer(player) end
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:UseToy(player, aim)
	local record = self.records[player]
	if not self.running or not record or record.closed or not self.toys then return { ok = false, message = "Toys are loading." } end
	return self.toys:Use(player, record.gear, aim)
end

function Equipment:PrepareRound(selected)
	local players = typeof(selected) == "Instance" and { selected } or selected or Players:GetPlayers()
	for _, player in ipairs(players) do
		if player.Parent == Players then
			if self.toys then self.toys:ClearPlayer(player) end
			local record = self.records[player]
			if record then self:_clearGear(record) end
		end
	end
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

return Equipment





]=],after=[=[local Players = game:GetService("Players")
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
	B16 = { name = "Fossil Dust", color = Color3.fromRGB(218, 190, 134), accent = Color3.fromRGB(255, 240, 196), texture = smokeTexture, rate = 4, speed = 0.4, size = 0.14, gravity = -0.7, spin = 35, glow = 0, trail = 0.18, lines = "alloy" },
	B17 = { name = "Dragon Scales", color = Color3.fromRGB(65, 199, 116), accent = Color3.fromRGB(251, 213, 105), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.18, gravity = 0.3, spin = 45, glow = 0.3, trail = 0.18, lines = "wave" },
	B18 = { name = "Breakfast Crumbs", color = Color3.fromRGB(229, 165, 75), accent = Color3.fromRGB(255, 233, 158), texture = smokeTexture, rate = 4, speed = 0.6, size = 0.11, gravity = -1.2, spin = 95, glow = 0, trail = 0.18 },
	B19 = { name = "Cloud Wisps", color = Color3.fromRGB(197, 209, 253), accent = Color3.fromRGB(255, 249, 233), texture = smokeTexture, rate = 3, speed = 0.4, size = 0.25, gravity = 0.65, spin = 20, glow = 0.1, trail = 0.18, lines = "orbit" },
	B20 = { name = "Bamboo Leaves", color = Color3.fromRGB(130, 203, 103), accent = Color3.fromRGB(230, 236, 148), texture = sparkTexture, rate = 5, speed = 0.45, size = 0.14, gravity = -0.25, spin = 110, glow = 0.1, trail = 0.18, lines = "wave" },
	B21 = { name = "Combo Pixels", color = Color3.fromRGB(96, 202, 245), accent = Color3.fromRGB(254, 115, 174), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.2, spin = 0, glow = 0.45, trail = 0.18, lines = "pixels" },
	B22 = { name = "Honey Sparks", color = Color3.fromRGB(249, 191, 63), accent = Color3.fromRGB(255, 232, 142), texture = sparkTexture, rate = 4, speed = 0.4, size = 0.15, gravity = -0.15, spin = 35, glow = 0.35, trail = 0.18, lines = "hazard" },
	B23 = { name = "Clockwork Glints", color = Color3.fromRGB(202, 159, 90), accent = Color3.fromRGB(255, 230, 176), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.19, gravity = 0.05, spin = 65, glow = 0.3, trail = 0.18, lines = "orbit" },
	B24 = { name = "Patchwork Confetti", color = Color3.fromRGB(225, 133, 212), accent = Color3.fromRGB(108, 223, 226), texture = sparkTexture, rate = 6, speed = 0.7, size = 0.15, gravity = -0.5, spin = 180, glow = 0.2, trail = 0.18, lines = "pixels" },
	B25 = { name = "Prism Gleam", color = Color3.fromRGB(121, 199, 255), accent = Color3.fromRGB(252, 178, 250), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.19, gravity = 0.35, spin = 50, glow = 0.6, trail = 0.18, lines = "sun" },
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

function Equipment.new(batServices, toys)
	return setmetatable({ running = false, records = {}, connections = {}, batServices = batServices or {}, toys = toys }, Equipment)
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
	if record.character then
		record.character:SetAttribute("PCBatHeld", false)
		record.character:SetAttribute("PCBatGame", nil)
	end
	self:_cancelBatHit(record)
	if record.batConnections then disconnect(record.batConnections) end
	local model = record.bat
	record.bat = nil
	record.batId = nil
	record.batGame = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	if self.toys then self.toys:CancelAction(record.player) end
	if record.character then record.character:SetAttribute("PCToyHeld", nil) end
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
	local function mirrorHeld(held)
		if record.bat ~= carrier or not record.character then return end
		record.character:SetAttribute("PCBatHeld", held)
		record.character:SetAttribute("PCBatGame", held and gameId or nil)
	end
	table.insert(record.batConnections, carrier.Equipped:Connect(function() mirrorHeld(true) end))
	table.insert(record.batConnections, carrier.Activated:Connect(function() self:_activateBat(record) end))
	table.insert(record.batConnections, carrier.Unequipped:Connect(function()
		mirrorHeld(false)
		self:_cancelBatHit(record)
		self:_queue(record)
	end))
	table.insert(record.batConnections, carrier.Destroying:Connect(function() mirrorHeld(false) self:_cancelBatHit(record) end))
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	carrier.Parent = record.player:FindFirstChildOfClass("Backpack") or record.character
	if humanoid then humanoid:EquipTool(carrier) end
	mirrorHeld(carrier.Parent == record.character)
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
	tool.ToolTip = item.name .. " · lobby toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = true
	tool.ManualActivationOnly = true
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("PCToy", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	local function mirrorHeld(held)
		if record.gear ~= tool or not record.character then return end
		record.character:SetAttribute("PCToyHeld", held and item.id or nil)
		if self.toys then
			if held then self.toys:Hold(record.player) else self.toys:CancelAction(record.player) end
		end
	end
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) else mirrorHeld(true) end
	end))
	table.insert(record.gearConnections, tool.Unequipped:Connect(function() mirrorHeld(false) end))
	if item.id == "M14" then
		local flame = anchorPart("TorchFlame")
		flame.CFrame = CFrame.new(0, size.Y - math.min(size.Y * 0.25, 0.45), -size.Z * 0.2)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, flame, flame
		local fire = Instance.new("Fire")
		fire.Name, fire.Size, fire.Heat, fire.Parent = "CampFlame", 2.4, 3, flame
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 170, 70), 0.6, 9, flame
	end
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	mirrorHeld(tool.Parent == record.character)
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		if self.toys then self.toys:ClearPlayer(player) end
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
		character:SetAttribute("PCBatHeld", true)
		character:SetAttribute("PCBatGame", gameId)
	end
	if participating(player) and self.toys then self.toys:ClearPlayer(player) end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	elseif record.gear.Parent ~= character then
		humanoid:EquipTool(record.gear)
		character:SetAttribute("PCToyHeld", gear.id)
		if self.toys then self.toys:Hold(player) end
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	if self.toys then self.toys:ClearPlayer(record.player) end
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	character:SetAttribute("PCBatHeld", false)
	character:SetAttribute("PCBatGame", nil)
	record.humanoid = nil
	local function bindHumanoid()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and record.humanoid ~= humanoid then
			record.humanoid = humanoid
			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				if self.toys then self.toys:ClearPlayer(record.player) end
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	bindHumanoid()
	table.insert(record.characterConnections, character.ChildAdded:Connect(function()
		bindHumanoid()
		self:_queue(record)
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function()
		self:_queue(record)
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
			if self.toys then self.toys:ClearPlayer(record.player) end
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
	if self.toys then self.toys:ClearPlayer(player) end
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:UseToy(player, aim)
	local record = self.records[player]
	if not self.running or not record or record.closed or not self.toys then return { ok = false, message = "Toys are loading." } end
	return self.toys:Use(player, record.gear, aim)
end

function Equipment:PrepareRound(selected)
	local players = typeof(selected) == "Instance" and { selected } or selected or Players:GetPlayers()
	for _, player in ipairs(players) do
		if player.Parent == Players then
			if self.toys then self.toys:ClearPlayer(player) end
			local record = self.records[player]
			if record then self:_clearGear(record) end
		end
	end
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

return Equipment





]=]},
{name="PlaygroundPets.luau",target=game.StarterPlayer.StarterPlayerScripts.PlaygroundPets,before=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local visuals = Instance.new("Folder")
visuals.Name = "PlaygroundPetVisuals"
visuals.Parent = workspace

local states = {}
local connections = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = true

local MAX_DISTANCE = 150
local MAX_VISIBLE = 24
local MAX_SIZE = 3
local effectColours = {
	P04 = Color3.fromRGB(251, 165, 222),
	P09 = Color3.fromRGB(151, 212, 255),
	P12 = Color3.fromRGB(139, 255, 214),
	P15 = Color3.fromRGB(255, 206, 232),
	P18 = Color3.fromRGB(255, 164, 69),
	P19 = Color3.fromRGB(182, 190, 255),
	P20 = Color3.fromRGB(255, 224, 115),
}
local hoveringPets = { P10 = true, P12 = true, P14 = true, P19 = true }

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function smoothAlpha(speed, delta)
	return 1 - math.exp(-speed * delta)
end

local function visibleBounds(model)
	local lower = Vector3.new(math.huge, math.huge, math.huge)
	local upper = -lower
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			count += 1
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						lower = lower:Min(corner)
						upper = upper:Max(corner)
					end
				end
			end
		end
	end
	if count == 0 then return nil end
	return lower, upper
end

local function release(player)
	local state = states[player]
	if not state then return end
	states[player] = nil
	for _, track in state.tracks do
		track:Stop(0)
		track:Destroy()
	end
	state.model:Destroy()
end

local function prepareParts(model)
	local parts = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BaseScript") then
			object.Enabled = false
		elseif object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			object.Anchored = false
			table.insert(parts, object)
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.AutoRotate = false
		end
	end
	local root = model:FindFirstChild("RootPart", true) or model.PrimaryPart or parts[1]
	if not root or not root:IsA("BasePart") then return nil end
	local anchoredComponents = {}
	local function anchorComponent(part)
		if anchoredComponents[part] then return end
		anchoredComponents[part] = true
		for _, connected in part:GetConnectedParts(true) do
			anchoredComponents[connected] = true
		end
		part.Anchored = true
	end
	anchorComponent(root)
	for _, part in parts do anchorComponent(part) end
	return root
end

local function loadAnimations(state)
	local model = state.model
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChildWhichIsA("Humanoid", true)
	if not controller then return end
	local animator = controller:FindFirstChildOfClass("Animator")
	for _, animation in model:GetDescendants() do
		local name = animation.Name:lower()
		if animation:IsA("Animation") and animation.AnimationId ~= "" and (name == "idle" or name == "walk") then
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = controller
			end
			local success, track = pcall(function() return animator:LoadAnimation(animation) end)
			if success then
				if states[state.player] ~= state then track:Destroy() return end
				track.Looped = true
				track.Priority = name == "walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
				if state.tracks[name] then state.tracks[name]:Destroy() end
				state.tracks[name] = track
				track:Play(0.2, name == "idle" and 1 or 0)
			end
		end
	end
	if states[state.player] ~= state then return end
	if state.tracks.idle then state.tracks.idle:AdjustWeight(state.walkMode and state.tracks.walk and 0 or 1, 0.2) end
	if state.tracks.walk then state.tracks.walk:AdjustWeight(state.walkMode and 1 or 0, 0.2) end
end

local function addSparkles(state, root, lower, upper)
	local colour = effectColours[state.id]
	if not colour then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetSparkleOrigin"
	attachment.Position = root.CFrame:PointToObjectSpace(Vector3.new(
		(lower.X + upper.X) * 0.5, lower.Y + (upper.Y - lower.Y) * 0.7, (lower.Z + upper.Z) * 0.5
	))
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(160, 160)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.5
	emitter.Enabled = false
	emitter.Parent = attachment
	state.emitter = emitter
end

local function createState(player, id, character)
	local template = assets:FindFirstChild(id)
	if not template or not template:IsA("Model") then return end
	local model = template:Clone()
	model.Name = tostring(player.UserId) .. "_" .. id
	model:SetAttribute("PetOwnerUserId", player.UserId)
	local restRotation = model:GetPivot().Rotation
	model:PivotTo(restRotation)
	local lower, upper = visibleBounds(model)
	if not lower then model:Destroy() return end
	local size = upper - lower
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > MAX_SIZE then
		model:ScaleTo(model:GetScale() * MAX_SIZE / largest)
		lower, upper = visibleBounds(model)
	end
	model.Parent = visuals
	local root = prepareParts(model)
	if not root then model:Destroy() return end
	local state = {
		player = player, id = id, character = character, model = model, tracks = {},
		phase = (player.UserId % 97) * math.pi * 2 / 97,
		position = nil, ground = nil, groundClock = 1, movement = 0,
		facing = CFrame.identity, walkMode = false,
		restRotation = restRotation,
		centreOffset = CFrame.new(-(lower.X + upper.X) * 0.5, -lower.Y, -(lower.Z + upper.Z) * 0.5),
		facingOffset = CFrame.Angles(0, math.rad(tonumber(template:GetAttribute("PetFacingYaw")) or 0), 0),
	}
	states[player] = state
	addSparkles(state, root, lower, upper)
	task.spawn(loadAnimations, state)
	return state
end

local function characterRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function reconcile()
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local localRoot = characterRoot(localPlayer)
	if localRoot then origin = localRoot.Position end
	if not origin then return end
	local candidates = {}
	local exclusions = { visuals }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclusions, player.Character) end
		local id = player:GetAttribute("PCPet")
		local root, _, character = characterRoot(player)
		if type(id) == "string" and id:match("^P%d%d$") and root then
			local distance = (root.Position - origin).Magnitude
			if distance < MAX_DISTANCE or player == localPlayer then
				table.insert(candidates, { player = player, id = id, character = character,
					distance = player == localPlayer and -1 or distance })
			end
		end
	end
	raycastParams.FilterDescendantsInstances = exclusions
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local wanted = {}
	for index = 1, math.min(MAX_VISIBLE, #candidates) do
		local entry = candidates[index]
		wanted[entry.player] = true
		local state = states[entry.player]
		if state and (state.id ~= entry.id or state.character ~= entry.character or not state.model.Parent) then
			release(entry.player)
			state = nil
		end
		if not state then createState(entry.player, entry.id, entry.character) end
	end
	for player in states do
		if not wanted[player] then release(player) end
	end
end

local function updateState(state, delta, observer, reducedMotion, effectsEnabled)
	local root, humanoid, character = characterRoot(state.player)
	if not root or character ~= state.character then release(state.player) return end
	local side = state.player.UserId % 2 == 0 and 2.4 or -2.4
	local target = root.CFrame:PointToWorldSpace(Vector3.new(side, 0, 3.4))
	local from = root.Position
	local obstruction = workspace:Raycast(from, horizontal(target - from), raycastParams)
	if obstruction then
		target = obstruction.Position + obstruction.Normal * 0.9
	end
	target = horizontal(target)
	local teleported = not state.position or (target - state.position).Magnitude > 35
	if teleported then
		state.position = target
		state.ground = nil
		state.groundClock = 1
	end
	local previous = state.position
	state.position = previous:Lerp(target, smoothAlpha(7.5, delta))
	local speed = (state.position - previous).Magnitude / math.max(delta, 0.001)
	state.movement += (math.clamp(speed / 9, 0, 1) - state.movement) * smoothAlpha(7, delta)
	local direction = horizontal(target - previous)
	if direction.Magnitude < 0.35 then direction = horizontal(root.CFrame.LookVector) end
	if direction.Magnitude > 0.01 then
		local desiredFacing = CFrame.lookAt(Vector3.zero, direction.Unit)
		state.facing = teleported and desiredFacing or state.facing:Lerp(desiredFacing, smoothAlpha(9, delta))
	end
	state.groundClock += delta
	if state.groundClock >= 0.08 then
		state.groundClock = 0
		local rayOrigin = Vector3.new(state.position.X, root.Position.Y + 6, state.position.Z)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -64, 0), raycastParams)
		local foot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
		local floor = foot and foot:IsA("BasePart") and foot.Position.Y - foot.Size.Y * 0.5 or root.Position.Y - 3
		state.groundTarget = result and result.Position.Y or floor
	end
	local groundTarget = state.groundTarget or root.Position.Y - 3
	state.ground = state.ground and state.ground + (groundTarget - state.ground) * smoothAlpha(18, delta) or groundTarget
	state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
	local hover = hoveringPets[state.id]
	local hop = (1 - math.cos(state.phase)) * 0.5
	local bounce = hover and 0.35 + hop * 0.16 or hop * (0.06 + state.movement * 0.45)
	local roll = math.sin(state.phase * 0.5) * math.rad(1 + state.movement * 3)
	local pitch = math.sin(state.phase) * math.rad(state.movement * 3)
	if reducedMotion then bounce *= 0.2 roll = 0 pitch = 0 end
	local position = Vector3.new(state.position.X, state.ground + 0.12 + bounce, state.position.Z)
	state.model:PivotTo(CFrame.new(position) * state.facing * CFrame.Angles(pitch, 0, roll)
		* state.centreOffset * state.facingOffset * state.restRotation)
	local walking = state.movement > (state.walkMode and 0.12 or 0.25)
	if walking ~= state.walkMode then
		state.walkMode = walking
		if state.tracks.idle then state.tracks.idle:AdjustWeight(walking and state.tracks.walk and 0 or 1, 0.2) end
		if state.tracks.walk then state.tracks.walk:AdjustWeight(walking and 1 or 0, 0.2) end
	end
	if state.tracks.walk then state.tracks.walk:AdjustSpeed(math.clamp(speed / 8, 0.6, 1.6)) end
	if state.emitter then
		state.emitter.Enabled = effectsEnabled and not reducedMotion and (position - observer).Magnitude < 70
	end
end

local reconcileClock = 1
table.insert(connections, Players.PlayerRemoving:Connect(release))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	reconcileClock += delta
	if reconcileClock >= 0.3 then
		reconcileClock = 0
		reconcile()
	end
end))
table.insert(connections, RunService.RenderStepped:Connect(function(delta)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local reducedMotion = localPlayer:GetAttribute("PCReducedMotion") == true
	local effectsEnabled = localPlayer:GetAttribute("PCPetEffectsEnabled") ~= false
	for _, state in states do
		updateState(state, math.min(delta, 0.1), camera.CFrame.Position, reducedMotion, effectsEnabled)
	end
end))

script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
	for player in states do release(player) end
	visuals:Destroy()
end)


]=],after=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local visuals = Instance.new("Folder")
visuals.Name = "PlaygroundPetVisuals"
visuals.Parent = workspace

local states = {}
local connections = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = true

local MAX_DISTANCE = 150
local MAX_VISIBLE = 24
local MAX_SIZE = 3
local effectColours = {
	P04 = Color3.fromRGB(251, 165, 222),
	P09 = Color3.fromRGB(151, 212, 255),
	P12 = Color3.fromRGB(139, 255, 214),
	P15 = Color3.fromRGB(255, 206, 232),
	P18 = Color3.fromRGB(255, 164, 69),
	P19 = Color3.fromRGB(182, 190, 255),
	P20 = Color3.fromRGB(255, 224, 115),
	P21 = Color3.fromRGB(143, 217, 255),
	P22 = Color3.fromRGB(255, 177, 82),
	P25 = Color3.fromRGB(255, 231, 160),
	P35 = Color3.fromRGB(255, 194, 87),
}
local hoveringPets = { P10 = true, P12 = true, P14 = true, P19 = true, P23 = true, P25 = true, P28 = true, P35 = true }

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function smoothAlpha(speed, delta)
	return 1 - math.exp(-speed * delta)
end

local function visibleBounds(model)
	local lower = Vector3.new(math.huge, math.huge, math.huge)
	local upper = -lower
	local count = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			count += 1
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						lower = lower:Min(corner)
						upper = upper:Max(corner)
					end
				end
			end
		end
	end
	if count == 0 then return nil end
	return lower, upper
end

local function release(player)
	local state = states[player]
	if not state then return end
	states[player] = nil
	for _, track in state.tracks do
		track:Stop(0)
		track:Destroy()
	end
	state.model:Destroy()
end

local function prepareParts(model)
	local parts = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BaseScript") then
			object.Enabled = false
		elseif object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			object.Anchored = false
			table.insert(parts, object)
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.AutoRotate = false
		end
	end
	local root = model:FindFirstChild("RootPart", true) or model.PrimaryPart or parts[1]
	if not root or not root:IsA("BasePart") then return nil end
	local anchoredComponents = {}
	local function anchorComponent(part)
		if anchoredComponents[part] then return end
		anchoredComponents[part] = true
		for _, connected in part:GetConnectedParts(true) do
			anchoredComponents[connected] = true
		end
		part.Anchored = true
	end
	anchorComponent(root)
	for _, part in parts do anchorComponent(part) end
	return root
end

local function loadAnimations(state)
	local model = state.model
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
		or model:FindFirstChildWhichIsA("Humanoid", true)
	if not controller then return end
	local animator = controller:FindFirstChildOfClass("Animator")
	for _, animation in model:GetDescendants() do
		local name = animation.Name:lower()
		if animation:IsA("Animation") and animation.AnimationId ~= "" and (name == "idle" or name == "walk") then
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = controller
			end
			local success, track = pcall(function() return animator:LoadAnimation(animation) end)
			if success then
				if states[state.player] ~= state then track:Destroy() return end
				track.Looped = true
				track.Priority = name == "walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
				if state.tracks[name] then state.tracks[name]:Destroy() end
				state.tracks[name] = track
				track:Play(0.2, name == "idle" and 1 or 0)
			end
		end
	end
	if states[state.player] ~= state then return end
	if state.tracks.idle then state.tracks.idle:AdjustWeight(state.walkMode and state.tracks.walk and 0 or 1, 0.2) end
	if state.tracks.walk then state.tracks.walk:AdjustWeight(state.walkMode and 1 or 0, 0.2) end
end

local function addSparkles(state, root, lower, upper)
	local colour = effectColours[state.id]
	if not colour then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetSparkleOrigin"
	attachment.Position = root.CFrame:PointToObjectSpace(Vector3.new(
		(lower.X + upper.X) * 0.5, lower.Y + (upper.Y - lower.Y) * 0.7, (lower.Z + upper.Z) * 0.5
	))
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(160, 160)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-35, 35)
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.5
	emitter.Enabled = false
	emitter.Parent = attachment
	state.emitter = emitter
end

local function createState(player, id, character)
	local template = assets:FindFirstChild(id)
	if not template or not template:IsA("Model") then return end
	local model = template:Clone()
	model.Name = tostring(player.UserId) .. "_" .. id
	model:SetAttribute("PetOwnerUserId", player.UserId)
	local restRotation = model:GetPivot().Rotation
	model:PivotTo(restRotation)
	local lower, upper = visibleBounds(model)
	if not lower then model:Destroy() return end
	local size = upper - lower
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > MAX_SIZE then
		model:ScaleTo(model:GetScale() * MAX_SIZE / largest)
		lower, upper = visibleBounds(model)
	end
	model.Parent = visuals
	local root = prepareParts(model)
	if not root then model:Destroy() return end
	local state = {
		player = player, id = id, character = character, model = model, tracks = {},
		phase = (player.UserId % 97) * math.pi * 2 / 97,
		position = nil, ground = nil, groundClock = 1, movement = 0,
		facing = CFrame.identity, walkMode = false,
		restRotation = restRotation,
		centreOffset = CFrame.new(-(lower.X + upper.X) * 0.5, -lower.Y, -(lower.Z + upper.Z) * 0.5),
		facingOffset = CFrame.Angles(0, math.rad(tonumber(template:GetAttribute("PetFacingYaw")) or 0), 0),
	}
	states[player] = state
	addSparkles(state, root, lower, upper)
	task.spawn(loadAnimations, state)
	return state
end

local function characterRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function reconcile()
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local localRoot = characterRoot(localPlayer)
	if localRoot then origin = localRoot.Position end
	if not origin then return end
	local candidates = {}
	local exclusions = { visuals }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclusions, player.Character) end
		local id = player:GetAttribute("PCPet")
		local root, _, character = characterRoot(player)
		if type(id) == "string" and id:match("^P%d%d$") and root then
			local distance = (root.Position - origin).Magnitude
			if distance < MAX_DISTANCE or player == localPlayer then
				table.insert(candidates, { player = player, id = id, character = character,
					distance = player == localPlayer and -1 or distance })
			end
		end
	end
	raycastParams.FilterDescendantsInstances = exclusions
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local wanted = {}
	for index = 1, math.min(MAX_VISIBLE, #candidates) do
		local entry = candidates[index]
		wanted[entry.player] = true
		local state = states[entry.player]
		if state and (state.id ~= entry.id or state.character ~= entry.character or not state.model.Parent) then
			release(entry.player)
			state = nil
		end
		if not state then createState(entry.player, entry.id, entry.character) end
	end
	for player in states do
		if not wanted[player] then release(player) end
	end
end

local function updateState(state, delta, observer, reducedMotion, effectsEnabled)
	local root, humanoid, character = characterRoot(state.player)
	if not root or character ~= state.character then release(state.player) return end
	local side = state.player.UserId % 2 == 0 and 2.4 or -2.4
	local target = root.CFrame:PointToWorldSpace(Vector3.new(side, 0, 3.4))
	local from = root.Position
	local obstruction = workspace:Raycast(from, horizontal(target - from), raycastParams)
	if obstruction then
		target = obstruction.Position + obstruction.Normal * 0.9
	end
	target = horizontal(target)
	local teleported = not state.position or (target - state.position).Magnitude > 35
	if teleported then
		state.position = target
		state.ground = nil
		state.groundClock = 1
	end
	local previous = state.position
	state.position = previous:Lerp(target, smoothAlpha(7.5, delta))
	local speed = (state.position - previous).Magnitude / math.max(delta, 0.001)
	state.movement += (math.clamp(speed / 9, 0, 1) - state.movement) * smoothAlpha(7, delta)
	local direction = horizontal(target - previous)
	if direction.Magnitude < 0.35 then direction = horizontal(root.CFrame.LookVector) end
	if direction.Magnitude > 0.01 then
		local desiredFacing = CFrame.lookAt(Vector3.zero, direction.Unit)
		state.facing = teleported and desiredFacing or state.facing:Lerp(desiredFacing, smoothAlpha(9, delta))
	end
	state.groundClock += delta
	if state.groundClock >= 0.08 then
		state.groundClock = 0
		local rayOrigin = Vector3.new(state.position.X, root.Position.Y + 6, state.position.Z)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -64, 0), raycastParams)
		local foot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
		local floor = foot and foot:IsA("BasePart") and foot.Position.Y - foot.Size.Y * 0.5 or root.Position.Y - 3
		state.groundTarget = result and result.Position.Y or floor
	end
	local groundTarget = state.groundTarget or root.Position.Y - 3
	state.ground = state.ground and state.ground + (groundTarget - state.ground) * smoothAlpha(18, delta) or groundTarget
	state.phase += delta * math.pi * 2 * (0.85 + state.movement * 1.75)
	local hover = hoveringPets[state.id]
	local hop = (1 - math.cos(state.phase)) * 0.5
	local bounce = hover and 0.35 + hop * 0.16 or hop * (0.06 + state.movement * 0.45)
	local roll = math.sin(state.phase * 0.5) * math.rad(1 + state.movement * 3)
	local pitch = math.sin(state.phase) * math.rad(state.movement * 3)
	if reducedMotion then bounce *= 0.2 roll = 0 pitch = 0 end
	local position = Vector3.new(state.position.X, state.ground + 0.12 + bounce, state.position.Z)
	state.model:PivotTo(CFrame.new(position) * state.facing * CFrame.Angles(pitch, 0, roll)
		* state.centreOffset * state.facingOffset * state.restRotation)
	local walking = state.movement > (state.walkMode and 0.12 or 0.25)
	if walking ~= state.walkMode then
		state.walkMode = walking
		if state.tracks.idle then state.tracks.idle:AdjustWeight(walking and state.tracks.walk and 0 or 1, 0.2) end
		if state.tracks.walk then state.tracks.walk:AdjustWeight(walking and 1 or 0, 0.2) end
	end
	if state.tracks.walk then state.tracks.walk:AdjustSpeed(math.clamp(speed / 8, 0.6, 1.6)) end
	if state.emitter then
		state.emitter.Enabled = effectsEnabled and not reducedMotion and (position - observer).Magnitude < 70
	end
end

local reconcileClock = 1
table.insert(connections, Players.PlayerRemoving:Connect(release))
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	reconcileClock += delta
	if reconcileClock >= 0.3 then
		reconcileClock = 0
		reconcile()
	end
end))
table.insert(connections, RunService.RenderStepped:Connect(function(delta)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local reducedMotion = localPlayer:GetAttribute("PCReducedMotion") == true
	local effectsEnabled = localPlayer:GetAttribute("PCPetEffectsEnabled") ~= false
	for _, state in states do
		updateState(state, math.min(delta, 0.1), camera.CFrame.Position, reducedMotion, effectsEnabled)
	end
end))

script.Destroying:Connect(function()
	for _, connection in connections do connection:Disconnect() end
	for player in states do release(player) end
	visuals:Destroy()
end)


]=]},
{name="PlaygroundToyService.luau",target=game.ServerScriptService.PlaygroundToyService,before=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Toys = {}
Toys.__index = Toys

local actions = {
	M01 = { pose = "Kick", contact = 0.60, duration = 1.10, cooldown = 5 },
	M02 = { pose = "Lob", contact = 0.34, duration = 0.85, cooldown = 5 },
	M03 = { pose = "Bonk", contact = 0.23, duration = 0.58, cooldown = 0.8 },
	M04 = { pose = "BarrelThrow", contact = 0.52, duration = 1.10, cooldown = 5 },
	M05 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 25.82 },
	M06 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 10.82 },
	M07 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 15.82 },
	M08 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3 },
	M10 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 5 },
	M11 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 2 },
	M12 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M13 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M14 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 1 },
	M15 = { pose = "Place", contact = 0.46, duration = 1, cooldown = 15.46 },
}
local palette = { Color3.fromRGB(255, 93, 131), Color3.fromRGB(70, 201, 255), Color3.fromRGB(255, 212, 72), Color3.fromRGB(117, 228, 137), Color3.fromRGB(195, 122, 255) }

local function now() return workspace:GetServerTimeNow() end
local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1000000 and math.abs(value.Y) < 1000000 and math.abs(value.Z) < 1000000
end
local function setAttribute(object, key, value)
	if object:GetAttribute(key) ~= value then object:SetAttribute(key, value) end
end
local function part(name, size, color, parent)
	local object = Instance.new("Part")
	object.Name, object.Size, object.Color = name, size, color
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Material, object.TopSurface, object.BottomSurface = Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function Toys.new(options)
	options = options or {}
	return setmetatable({ records = {}, objects = {}, running = false, playBonk = options.playBonk, random = Random.new() }, Toys)
end

function Toys:_inside(position)
	local bounds = self.bounds
	if not bounds or not bounds.Parent or not finiteVector(position) then return false end
	local point, half = bounds.CFrame:PointToObjectSpace(position), bounds.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z and math.abs(point.Y) <= half.Y + 20
end

function Toys:_character(player)
	if not player or player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true or participating(player) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position) then return nil end
	return character, humanoid, root
end

function Toys:_record(player)
	local character, humanoid = self:_character(player)
	if not character then return nil end
	local record = self.records[player]
	if record and record.character ~= character then self:ClearPlayer(player) record = nil end
	if not record then
		record = { player = player, character = character, humanoid = humanoid, cooldowns = {}, serial = 0, speedUntil = 0, jumpUntil = 0, emberUntil = 0, freezeUntil = 0, burnUntil = 0, busyUntil = 0, nextFire = 0 }
		self.records[player] = record
	end
	return record
end

function Toys:Hold(player)
	return self:_record(player) ~= nil
end

function Toys:_restoreVisual(record)
	if not record.hidden then return end
	for object, transparency in pairs(record.hidden) do if object.Parent then object.Transparency = transparency end end
	record.hidden = nil
end

function Toys:_hideVisual(record, tool)
	self:_restoreVisual(record)
	local visual = tool:FindFirstChild("Visual")
	if not visual then return end
	record.hidden = {}
	for _, object in ipairs(visual:GetDescendants()) do
		if object:IsA("BasePart") then record.hidden[object] = object.Transparency object.Transparency = 1 end
	end
end

function Toys:_ray(origin, direction, owner, ignoreCharacters)
	local excludes = { self.folder }
	if owner and owner.Character then table.insert(excludes, owner.Character) end
	if ignoreCharacters then for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excludes, player.Character) end end end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excludes
	params.IgnoreWater = true
	return workspace:Raycast(origin, direction, params)
end

function Toys:_direction(root, aim)
	local direction = finiteVector(aim) and aim - root.Position or root.CFrame.LookVector
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	return direction.Unit
end

function Toys:_burst(position, color, kind, count)
	local anchor = part("ToyBurst", Vector3.new(0.1, 0.1, 0.1), color, self.folder)
	anchor.Transparency, anchor.Position = 1, position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = kind == "fire" and "rbxasset://textures/particles/fire_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color, kind == "fire" and Color3.fromRGB(255, 211, 80) or Color3.new(1, 1, 1))
	emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.35, 0.8), NumberRange.new(3, 8), Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(kind == "fire" and 0.65 or 0.22, 0)
	emitter.LightEmission, emitter.Parent = 0.3, anchor
	emitter:Emit(count or 16)
	Debris:AddItem(anchor, 1)
end

function Toys:_confetti(position, owner)
	for i = 1, 16 do
		local confetti = part("Confetti", Vector3.new(0.12, 0.05, 0.23), palette[(i - 1) % #palette + 1], self.folder)
		confetti.Position = position
		self:_object(owner, confetti, 2, { position = position, velocity = Vector3.new(self.random:NextNumber(-8, 8), self.random:NextNumber(7, 14), self.random:NextNumber(-8, 8)), gravity = 18, spin = Vector3.new(5, 3, 2), cosmetic = true })
	end
end

function Toys:_object(owner, object, lifetime, data)
	data = data or {}
	data.owner, data.object, data.expiresAt = owner, object, now() + lifetime
	data.bornAt, data.originalPivot = now(), object:GetPivot()
	data.visualOffset = object:GetAttribute("ToyVisualOffset") or CFrame.identity
	table.insert(self.objects, data)
	return data
end

function Toys:_visual(id, position, length)
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local source = assets and assets:FindFirstChild(id)
	if not source or not source:IsA("Model") then return nil end
	local clone = source:Clone()
	clone.Name = "Toy_" .. id
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery = true, false, false, false
		elseif child:IsA("Highlight") then child.Adornee = clone end
	end
	local box, size = clone:GetBoundingBox()
	clone:ScaleTo(clone:GetScale() * length / math.max(size.X, size.Y, size.Z, 0.1))
	box = clone:GetBoundingBox()
	local offset = box:Inverse() * clone:GetPivot()
	clone:SetAttribute("ToyVisualOffset", offset)
	clone:PivotTo(CFrame.new(position) * offset)
	clone.Parent = self.folder
	return clone
end

function Toys:_ground(root, distance)
	local horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) else horizontal = horizontal.Unit end
	local origin = root.Position + horizontal * distance + Vector3.new(0, 2, 0)
	local hit = self:_ray(origin, Vector3.new(0, -12, 0), nil, true)
	if hit and hit.Normal.Y > 0.75 and self:_inside(hit.Position) then return hit.Position end
	return nil
end

function Toys:_padGround(root)
	local position = self:_ground(root, 5)
	if not position then return nil end
	for x = -1, 1, 2 do for z = -1, 1, 2 do
		local corner = position + Vector3.new(x * 2.7, 0, z * 2.7)
		if not self:_inside(corner) then return nil end
		local ground = self:_ray(corner + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), nil, true)
		if not ground or ground.Normal.Y < 0.75 or math.abs(ground.Position.Y - position.Y) > 0.5 then return nil end
	end end
	return position
end

function Toys:_boundedRange(origin, direction, distance)
	local target = origin + direction * distance
	if self:_inside(target) then return distance end
	local low, high = 0, distance
	for _ = 1, 14 do
		local middle = (low + high) / 2
		if self:_inside(origin + direction * middle) then low = middle else high = middle end
	end
	return low
end

function Toys:_movement(record, time)
	local humanoid = record.humanoid
	local active = record.speedUntil > time or record.jumpUntil > time or record.freezeUntil > time
	if active and not record.base then
		record.base = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
		record.written = {}
	end
	if not record.base then return end
	local frozen = record.freezeUntil > time
	local values = {
		WalkSpeed = frozen and 0 or record.base.WalkSpeed * (record.speedUntil > time and 3 or 1),
		JumpPower = frozen and 0 or record.base.JumpPower * (record.jumpUntil > time and math.sqrt(5) or 1),
		JumpHeight = frozen and 0 or record.base.JumpHeight * (record.jumpUntil > time and 5 or 1),
		AutoRotate = not frozen and record.base.AutoRotate,
	}
	for key, value in pairs(values) do humanoid[key] = value record.written[key] = humanoid[key] end
	if frozen then humanoid.Jump = false end
	if not active then record.base, record.written = nil, nil end
end

function Toys:_burn(owner, target)
	if owner == target or not self:_character(owner) then return end
	local record = self:_record(target)
	if not record or now() < (record.burnImmuneUntil or 0) then return end
	record.burnUntil, record.nextBurn, record.burnImmuneUntil, record.burnOwner = now() + 10, now() + 1, now() + 12, owner
	setAttribute(target, "PCToyBurnUntil", record.burnUntil)
	local root = record.character:FindFirstChild("HumanoidRootPart")
	local fire = Instance.new("Fire")
	fire.Name, fire.Size, fire.Heat = "ToyCampfire", 3, 2
	fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 142, 45), Color3.fromRGB(255, 224, 102)
	fire.Parent, record.fire = root, fire
end

function Toys:_freeze(target)
	local record = self:_record(target)
	if not record or now() < (record.freezeImmuneUntil or 0) then return end
	record.freezeUntil, record.freezeImmuneUntil = now() + 2.5, now() + 6
	self:CancelAction(target)
	setAttribute(target, "PCToyFrozenUntil", record.freezeUntil)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "ToyFrost", record.character
	outline.FillColor, outline.FillTransparency = Color3.fromRGB(142, 233, 255), 0.35
	outline.OutlineColor, outline.DepthMode = Color3.fromRGB(214, 252, 255), Enum.HighlightDepthMode.Occluded
	outline.Parent, record.frost = record.character, outline
	self:_movement(record, now())
end

function Toys:_target(hit)
	if not hit then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = self:_character(player)
		if character and hit.Instance:IsDescendantOf(character) then return player end
	end
	return nil
end

function Toys:_beam(origin, destination, color)
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return end
	local beam = part("ToyRay", Vector3.new(0.14, 0.14, delta.Magnitude), color, self.folder)
	beam.Material, beam.CFrame = Enum.Material.Neon, CFrame.lookAt((origin + destination) / 2, destination)
	Debris:AddItem(beam, 0.16)
end

function Toys:_splat(position, normal, owner, cake)
	local color = cake and Color3.fromRGB(255, 238, 209) or palette[self.random:NextInteger(1, #palette)]
	local frame = CFrame.lookAt(position + normal * 0.04, position + normal)
	for i = 0, 6 do
		local size = i == 0 and 1.55 or self.random:NextNumber(0.25, 0.7)
		local blob = part(cake and "Frosting" or "PaintSplat", Vector3.new(size, size, 0.045), color, self.folder)
		blob.Shape = Enum.PartType.Ball
		local angle = i * math.pi / 3
		blob.CFrame = frame * CFrame.new(i == 0 and 0 or math.cos(angle) * 0.9, i == 0 and 0 or math.sin(angle) * 0.9, 0)
		self:_object(owner, blob, cake and 5 or 10)
	end
end

function Toys:_launch(record, id, root, direction)
	local position = root.Position + Vector3.new(0, 1.3, 0) + direction * 2
	local length, velocity = 1.6, direction * 48 + Vector3.new(0, 15, 0)
	if id == "M02" then velocity = direction * 20 + Vector3.new(0, 48, 0) length = 1.8 end
	if id == "M04" then position = root.Position + Vector3.new(0, 4, 0) velocity = direction * 38 + Vector3.new(0, 18, 0) length = 2.7 end
	if id == "M01" then
		local ground = self:_ground(root, 3)
		if not ground then return end
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		direction = forward.Magnitude > 0.1 and forward.Unit or Vector3.new(0, 0, -1)
		position, velocity = ground + Vector3.new(0, 0.9, 0), direction * 54 + Vector3.new(0, 5, 0)
		if record.stagedBall then
			local staged = record.stagedBall
			record.stagedBall = nil
			staged.kind, staged.position, staged.velocity, staged.gravity, staged.spin, staged.bounces = id, position, velocity, 60, Vector3.new(2, 1, 0), 0
			staged.expiresAt = now() + 5
			return
		end
	end
	local object
	if id == "M11" then
		object = part("FlyingPaint", Vector3.new(0.7, 0.7, 0.7), palette[self.random:NextInteger(1, #palette)], self.folder)
		object.Shape, object.Position = Enum.PartType.Ball, position
	else object = self:_visual(id, position, length) end
	if not object then return end
	self:_object(record.player, object, 5, { kind = id, position = position, velocity = velocity, gravity = 60, spin = Vector3.new(2, 1, 0), bounces = 0 })
end

function Toys:_placePad(record, root)
	local position = self:_padGround(root)
	if not position then return false end
	local model = self:_visual("M15", position + Vector3.new(0, 0.45, 0), 6)
	if not model then return false end
	local surface = part("BounceSurface", Vector3.new(5.2, 0.45, 5.2), Color3.fromRGB(73, 196, 228), model)
	surface.Transparency, surface.CanCollide, surface.CanQuery = 1, true, true
	surface.Position = position + Vector3.new(0, 0.45, 0)
	local entry = self:_object(record.player, model, 15, { kind = "Pad", surface = surface, nextBounce = {} })
	entry.padPosition = position
	setAttribute(record.player, "PCToyPadUntil", entry.expiresAt)
	return true
end

function Toys:_effect(record, id, aim, fireShot)
	local _, _, root = self:_character(record.player)
	if not root then return end
	local direction = self:_direction(root, aim)
	if id == "M05" then record.speedUntil = now() + 25 self:_movement(record, now()) setAttribute(record.player, "PCToySpeedUntil", record.speedUntil)
	elseif id == "M06" then record.jumpUntil = now() + 10 self:_movement(record, now()) setAttribute(record.player, "PCToyJumpUntil", record.jumpUntil)
	elseif id == "M07" and not fireShot then record.emberUntil = now() + 10 setAttribute(record.player, "PCToyEmberUntil", record.emberUntil)
	elseif id == "M07" or id == "M10" then
		local origin = root.Position + Vector3.new(0, 1.4, 0)
		local range = self:_boundedRange(origin, direction, id == "M10" and 55 or 32)
		local hit = self:_ray(origin, direction * range, record.player)
		local destination = hit and hit.Position or origin + direction * range
		self:_beam(origin, destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55))
		self:_burst(destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55), id == "M10" and "frost" or "fire", 12)
		local target = self:_target(hit)
		if target then if id == "M10" then self:_freeze(target) else self:_burn(record.player, target) end end
	elseif id == "M03" then
		local hit = self:_ray(root.Position + Vector3.new(0, 0.6, 0), direction * 6, record.player)
		if hit then self:_burst(hit.Position, Color3.fromRGB(255, 227, 96), "stars", 12) if self.playBonk then self.playBonk(hit.Position) end end
	elseif id == "M08" then
		self:_confetti(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), record.player)
	elseif id == "M14" then self:_burst(root.Position + direction * 2, Color3.fromRGB(255, 174, 65), "fire", 6)
	elseif id == "M15" then
		if not self:_placePad(record, root) then
			record.cooldowns.M15 = 0
			setAttribute(record.player, "PCToyCooldown_M15", 0)
			self:_restoreVisual(record)
		end
	else self:_launch(record, id, root, direction) end
end

function Toys:Use(player, tool, aim)
	local record = self:_record(player)
	if not self.running or not record then return { ok = false, message = "Toys are for the lobby." } end
	local id = player:GetAttribute("PCGear")
	if not tool or tool.Parent ~= record.character or tool:GetAttribute("CatalogId") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return { ok = false, message = "Choose a toy first." } end
	local config = actions[id]
	if not config then return { ok = false, message = "Plunger Popper is waiting for its plunger model." } end
	local time = now()
	if time < record.freezeUntil then return { ok = false, message = "Frozen for a moment!" } end
	if time < record.busyUntil then return { ok = false, message = "Finish this action first." } end
	local fireShot = id == "M07" and time < record.emberUntil
	local readyAt = fireShot and record.nextFire or (record.cooldowns[id] or 0)
	if time < readyAt then return { ok = false, message = "Recharging", cooldownEndsAt = readyAt } end
	if aim ~= nil and not finiteVector(aim) then return { ok = false, message = "Invalid aim." } end
	if id == "M15" then local _, _, root = self:_character(player) if not self:_padGround(root) then return { ok = false, message = "Place the pad on open ground." } end end
	local duration, contact, pose = config.duration, config.contact, config.pose
	if fireShot then
		duration, contact, pose = 0.8, 0.35, "Aim"
		record.nextFire = time + 0.8
		setAttribute(player, "PCToyEmberShotUntil", record.nextFire)
	else record.cooldowns[id] = time + config.cooldown end
	record.busyUntil, record.serial = time + duration, record.serial + 1
	local serial = record.serial
	player:SetAttribute("PCToyActionItem", id)
	player:SetAttribute("PCToyAction", pose)
	player:SetAttribute("PCToyActionAt", time)
	player:SetAttribute("PCToyCooldown_" .. id, record.cooldowns[id] or 0)
	local thrown = id == "M01" or id == "M02" or id == "M04" or id == "M12" or id == "M13" or id == "M15"
	if id == "M01" then
		task.delay(0.24, function()
			if self.records[player] ~= record or record.serial ~= serial or tool.Parent ~= record.character then return end
			local _, _, root = self:_character(player)
			local ground = root and self:_ground(root, 3)
			if ground then
				self:_hideVisual(record, tool)
				local object = self:_visual(id, ground + Vector3.new(0, 0.9, 0), 1.6)
				if object then record.stagedBall = self:_object(player, object, 5.4) end
			end
		end)
	end
	task.delay(contact, function()
		if not self.running or self.records[player] ~= record or record.serial ~= serial or not self:_character(player)
			or tool.Parent ~= record.character or player:GetAttribute("PCGear") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return end
		if now() < record.freezeUntil then return end
		if fireShot and now() >= record.emberUntil then return end
		if thrown then self:_hideVisual(record, tool) end
		self:_effect(record, id, aim, fireShot)
	end)
	if thrown then
		task.delay(id == "M15" and config.cooldown or duration, function()
			if self.records[player] == record and record.serial == serial then self:_restoreVisual(record) end
		end)
	end
	return { ok = true, cooldownEndsAt = fireShot and record.nextFire or record.cooldowns[id], message = id == "M07" and not fireShot and "Drink, then tap to breathe fire!" or "" }
end

function Toys:CancelAction(player)
	local record = self.records[player]
	if record then
		record.serial += 1 record.busyUntil = 0
		self:_restoreVisual(record)
		if record.stagedBall then record.stagedBall.object:Destroy() record.stagedBall = nil end
	end
	for _, key in ipairs({ "PCToyAction", "PCToyActionAt", "PCToyActionItem" }) do player:SetAttribute(key, nil) end
end

function Toys:ClearPlayer(player)
	self:CancelAction(player)
	local record = self.records[player]
	if record then
		if record.base and record.humanoid and record.humanoid.Parent then
			for key, value in pairs(record.base) do if record.humanoid[key] == record.written[key] then record.humanoid[key] = value end end
		end
		if record.fire then record.fire:Destroy() end
		if record.frost then record.frost:Destroy() end
		self.records[player] = nil
	end
	for i = #self.objects, 1, -1 do local entry = self.objects[i] if entry.owner == player then entry.object:Destroy() table.remove(self.objects, i) end end
	for _, target in pairs(self.records) do
		if target.burnOwner == player then target.burnUntil = 0 target.burnOwner = nil end
	end
	for _, key in ipairs({ "PCToySpeedUntil", "PCToyJumpUntil", "PCToyEmberUntil", "PCToyEmberShotUntil", "PCToyFrozenUntil", "PCToyBurnUntil", "PCToyPadUntil" }) do setAttribute(player, key, 0) end
	for id in pairs(actions) do setAttribute(player, "PCToyCooldown_" .. id, 0) end
end

function Toys:_tickPlayer(record, time)
	local player = record.player
	local _, _, root = self:_character(player)
	if not root or player.Character ~= record.character then self:ClearPlayer(player) return end
	self:_movement(record, time)
	if time >= record.freezeUntil and record.frost then record.frost:Destroy() record.frost = nil end
	if record.burnOwner and not self:_character(record.burnOwner) then record.burnUntil = 0 end
	if record.burnUntil > 0 and time >= record.nextBurn and record.nextBurn <= record.burnUntil then
		record.nextBurn += 1
		record.humanoid:TakeDamage(1)
	end
	if time >= record.burnUntil and record.fire then record.fire:Destroy() record.fire = nil setAttribute(player, "PCToyBurnUntil", 0) end
	if record.character:GetAttribute("PCToyHeld") == "M14" and time >= (record.nextTorch or 0) then
		record.nextTorch = time + 0.3
		local hand = record.character:FindFirstChild("RightHand") or record.character:FindFirstChild("Right Arm")
		local origin = hand and hand.Position or root.Position
		for _, target in ipairs(Players:GetPlayers()) do
			local _, _, targetRoot = self:_character(target)
			if target ~= player and targetRoot and (targetRoot.Position - origin).Magnitude <= 4 then
				local hit = self:_ray(origin, targetRoot.Position - origin, player)
				if hit and hit.Instance:IsDescendantOf(target.Character) then self:_burn(player, target) end
			end
		end
	end
end

function Toys:_tickObject(entry, time, dt)
	local object = entry.object
	if not object.Parent or time >= entry.expiresAt or not self:_character(entry.owner) then
		if entry.kind == "Pad" and object.Parent then self:_burst(entry.padPosition, Color3.fromRGB(100, 217, 240), "stars", 18) end
		return false
	end
	if entry.kind == "Pad" then
		for _, player in ipairs(Players:GetPlayers()) do
			local _, humanoid, root = self:_character(player)
			if root then
				local delta = root.Position - entry.surface.Position
				local footHeight = humanoid.HipHeight + root.Size.Y * 0.5
				local leg = player.Character:FindFirstChild("Left Leg")
				if leg then footHeight += leg.Size.Y end
				if math.abs(delta.X) < 2.8 and math.abs(delta.Z) < 2.8 and math.abs(delta.Y - footHeight) < 1.3 and root.AssemblyLinearVelocity.Y <= 2 and time >= (entry.nextBounce[player] or 0) then
					entry.nextBounce[player] = time + 0.9
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 75, velocity.Z)
					self:_burst(entry.surface.Position, Color3.fromRGB(105, 236, 242), "stars", 10)
				end
			end
		end
		return true
	end
	if entry.shakeUntil then
		if time >= entry.shakeUntil then self:_confetti(entry.position, entry.owner) return false end
		object:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, 0, math.sin(time * 38) * 0.13) * entry.visualOffset)
		return true
	end
	if not entry.velocity then return true end
	entry.velocity += Vector3.new(0, -(entry.gravity or 60) * dt, 0)
	local nextPosition = entry.position + entry.velocity * dt
	if not self:_inside(nextPosition) then return false end
	local hit = not entry.cosmetic and self:_ray(entry.position, nextPosition - entry.position, entry.owner)
	if hit then
		if entry.kind == "M11" or entry.kind == "M13" then self:_splat(hit.Position, hit.Normal, entry.owner, entry.kind == "M13") return false
		elseif entry.kind == "M12" then
			entry.position = hit.Position + hit.Normal * 0.35
			entry.originalPivot = CFrame.new(entry.position) * entry.visualOffset
			entry.velocity, entry.shakeUntil = nil, time + 0.65
			object:PivotTo(entry.originalPivot)
			return true
		else
			entry.bounces = (entry.bounces or 0) + 1
			if entry.bounces > 8 or entry.velocity.Magnitude < 3 then entry.velocity = nil return true end
			entry.velocity = (entry.velocity - 2 * entry.velocity:Dot(hit.Normal) * hit.Normal) * 0.6
			nextPosition = hit.Position + hit.Normal * (entry.kind == "M04" and 1.1 or 0.75)
		end
	end
	entry.position = nextPosition
	local angle = entry.spin and entry.spin * (time - entry.bornAt) or Vector3.zero
	object:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(angle.X, angle.Y, angle.Z) * entry.visualOffset)
	return true
end

function Toys:Start()
	if self.running then return self end
	local lobby = workspace:WaitForChild("Playground Lobby")
	self.bounds = lobby:WaitForChild("Gameplay"):WaitForChild("LobbyBounds")
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PlaygroundToyEffects", workspace
	self.running = true
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		local time = now()
		for _, record in pairs(self.records) do self:_tickPlayer(record, time) end
		for i = #self.objects, 1, -1 do local entry = self.objects[i] if not self:_tickObject(entry, time, math.min(dt, 0.1)) then entry.object:Destroy() table.remove(self.objects, i) end end
	end)
	self.leaving = Players.PlayerRemoving:Connect(function(player) self:ClearPlayer(player) end)
	return self
end

function Toys:Stop()
	self.running = false
	if self.heartbeat then self.heartbeat:Disconnect() end
	if self.leaving then self.leaving:Disconnect() end
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:ClearPlayer(player) end
	if self.folder then self.folder:Destroy() end
	table.clear(self.objects)
end

return Toys


]=],after=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Toys = {}
Toys.__index = Toys

local actions = {
	M01 = { pose = "Kick", contact = 0.60, duration = 1.10, cooldown = 5 },
	M02 = { pose = "Lob", contact = 0.34, duration = 0.85, cooldown = 5 },
	M03 = { pose = "Bonk", contact = 0.23, duration = 0.58, cooldown = 0.8 },
	M04 = { pose = "BarrelThrow", contact = 0.52, duration = 1.10, cooldown = 5 },
	M05 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 25.82 },
	M06 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 10.82 },
	M07 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 15.82 },
	M08 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3 },
	M10 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 5 },
	M11 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 2 },
	M12 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M13 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M14 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 1 },
	M15 = { pose = "Place", contact = 0.46, duration = 1, cooldown = 15.46 },
}
local palette = { Color3.fromRGB(255, 93, 131), Color3.fromRGB(70, 201, 255), Color3.fromRGB(255, 212, 72), Color3.fromRGB(117, 228, 137), Color3.fromRGB(195, 122, 255) }

local function now() return workspace:GetServerTimeNow() end
local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1000000 and math.abs(value.Y) < 1000000 and math.abs(value.Z) < 1000000
end
local function setAttribute(object, key, value)
	if object:GetAttribute(key) ~= value then object:SetAttribute(key, value) end
end
local function part(name, size, color, parent)
	local object = Instance.new("Part")
	object.Name, object.Size, object.Color = name, size, color
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Material, object.TopSurface, object.BottomSurface = Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function Toys.new(options)
	options = options or {}
	return setmetatable({ records = {}, objects = {}, running = false, playBonk = options.playBonk, random = Random.new() }, Toys)
end

function Toys:_inside(position)
	local bounds = self.bounds
	if not bounds or not bounds.Parent or not finiteVector(position) then return false end
	local point, half = bounds.CFrame:PointToObjectSpace(position), bounds.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z and math.abs(point.Y) <= half.Y + 20
end

function Toys:_character(player)
	if not player or player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true or participating(player) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position) then return nil end
	return character, humanoid, root
end

function Toys:_record(player)
	local character, humanoid = self:_character(player)
	if not character then return nil end
	local record = self.records[player]
	if record and record.character ~= character then self:ClearPlayer(player) record = nil end
	if not record then
		record = { player = player, character = character, humanoid = humanoid, cooldowns = {}, serial = 0, speedUntil = 0, jumpUntil = 0, emberUntil = 0, freezeUntil = 0, burnUntil = 0, busyUntil = 0, nextFire = 0 }
		self.records[player] = record
	end
	return record
end

function Toys:Hold(player)
	return self:_record(player) ~= nil
end

function Toys:_restoreVisual(record)
	if not record.hidden then return end
	for object, transparency in pairs(record.hidden) do if object.Parent then object.Transparency = transparency end end
	record.hidden = nil
end

function Toys:_hideVisual(record, tool)
	self:_restoreVisual(record)
	local visual = tool:FindFirstChild("Visual")
	if not visual then return end
	record.hidden = {}
	for _, object in ipairs(visual:GetDescendants()) do
		if object:IsA("BasePart") then record.hidden[object] = object.Transparency object.Transparency = 1 end
	end
end

function Toys:_ray(origin, direction, owner, ignoreCharacters)
	local excludes = { self.folder }
	if owner and owner.Character then table.insert(excludes, owner.Character) end
	if ignoreCharacters then for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excludes, player.Character) end end end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excludes
	params.IgnoreWater = true
	return workspace:Raycast(origin, direction, params)
end

function Toys:_direction(root, aim)
	local direction = finiteVector(aim) and aim - root.Position or root.CFrame.LookVector
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	return direction.Unit
end

function Toys:_burst(position, color, kind, count)
	local anchor = part("ToyBurst", Vector3.new(0.1, 0.1, 0.1), color, self.folder)
	anchor.Transparency, anchor.Position = 1, position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = kind == "fire" and "rbxasset://textures/particles/fire_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color, kind == "fire" and Color3.fromRGB(255, 211, 80) or Color3.new(1, 1, 1))
	emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.35, 0.8), NumberRange.new(3, 8), Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(kind == "fire" and 0.65 or 0.22, 0)
	emitter.LightEmission, emitter.Parent = 0.3, anchor
	emitter:Emit(count or 16)
	Debris:AddItem(anchor, 1)
end

function Toys:_confetti(position, owner)
	for i = 1, 16 do
		local confetti = part("Confetti", Vector3.new(0.12, 0.05, 0.23), palette[(i - 1) % #palette + 1], self.folder)
		confetti.Position = position
		self:_object(owner, confetti, 2, { position = position, velocity = Vector3.new(self.random:NextNumber(-8, 8), self.random:NextNumber(7, 14), self.random:NextNumber(-8, 8)), gravity = 18, spin = Vector3.new(5, 3, 2), cosmetic = true })
	end
end

function Toys:_object(owner, object, lifetime, data)
	data = data or {}
	data.owner, data.object, data.expiresAt = owner, object, now() + lifetime
	data.bornAt, data.originalPivot = now(), object:GetPivot()
	data.visualOffset = object:GetAttribute("ToyVisualOffset") or CFrame.identity
	table.insert(self.objects, data)
	return data
end

function Toys:_visual(id, position, length)
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local source = assets and assets:FindFirstChild(id)
	if not source or not source:IsA("Model") then return nil end
	local clone = source:Clone()
	clone.Name = "Toy_" .. id
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery = true, false, false, false
		elseif child:IsA("Highlight") then child.Adornee = clone end
	end
	local box, size = clone:GetBoundingBox()
	clone:ScaleTo(clone:GetScale() * length / math.max(size.X, size.Y, size.Z, 0.1))
	box = clone:GetBoundingBox()
	local offset = box:Inverse() * clone:GetPivot()
	clone:SetAttribute("ToyVisualOffset", offset)
	clone:PivotTo(CFrame.new(position) * offset)
	clone.Parent = self.folder
	return clone
end

function Toys:_ground(root, distance)
	local horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) else horizontal = horizontal.Unit end
	local origin = root.Position + horizontal * distance + Vector3.new(0, 2, 0)
	local hit = self:_ray(origin, Vector3.new(0, -12, 0), nil, true)
	if hit and hit.Normal.Y > 0.75 and self:_inside(hit.Position) then return hit.Position end
	return nil
end

function Toys:_padGround(root)
	local position = self:_ground(root, 5)
	if not position then return nil end
	for x = -1, 1, 2 do for z = -1, 1, 2 do
		local corner = position + Vector3.new(x * 2.7, 0, z * 2.7)
		if not self:_inside(corner) then return nil end
		local ground = self:_ray(corner + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), nil, true)
		if not ground or ground.Normal.Y < 0.75 or math.abs(ground.Position.Y - position.Y) > 0.5 then return nil end
	end end
	return position
end

function Toys:_boundedRange(origin, direction, distance)
	local target = origin + direction * distance
	if self:_inside(target) then return distance end
	local low, high = 0, distance
	for _ = 1, 14 do
		local middle = (low + high) / 2
		if self:_inside(origin + direction * middle) then low = middle else high = middle end
	end
	return low
end

function Toys:_movement(record, time)
	local humanoid = record.humanoid
	local active = record.speedUntil > time or record.jumpUntil > time or record.freezeUntil > time
	if active and not record.base then
		record.base = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
		record.written = {}
	end
	if not record.base then return end
	local frozen = record.freezeUntil > time
	local values = {
		WalkSpeed = frozen and 0 or record.base.WalkSpeed * (record.speedUntil > time and 3 or 1),
		JumpPower = frozen and 0 or record.base.JumpPower * (record.jumpUntil > time and math.sqrt(5) or 1),
		JumpHeight = frozen and 0 or record.base.JumpHeight * (record.jumpUntil > time and 5 or 1),
		AutoRotate = not frozen and record.base.AutoRotate,
	}
	for key, value in pairs(values) do humanoid[key] = value record.written[key] = humanoid[key] end
	if frozen then humanoid.Jump = false end
	if not active then record.base, record.written = nil, nil end
end

function Toys:_burn(owner, target)
	if owner == target or not self:_character(owner) then return end
	local record = self:_record(target)
	if not record or now() < (record.burnImmuneUntil or 0) then return end
	record.burnUntil, record.nextBurn, record.burnImmuneUntil, record.burnOwner = now() + 10, now() + 1, now() + 12, owner
	setAttribute(target, "PCToyBurnUntil", record.burnUntil)
	local root = record.character:FindFirstChild("HumanoidRootPart")
	local fire = Instance.new("Fire")
	fire.Name, fire.Size, fire.Heat = "ToyCampfire", 3, 2
	fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 142, 45), Color3.fromRGB(255, 224, 102)
	fire.Parent, record.fire = root, fire
end

function Toys:_freeze(target)
	local record = self:_record(target)
	if not record or now() < (record.freezeImmuneUntil or 0) then return end
	record.freezeUntil, record.freezeImmuneUntil = now() + 2.5, now() + 6
	self:CancelAction(target)
	setAttribute(target, "PCToyFrozenUntil", record.freezeUntil)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "ToyFrost", record.character
	outline.FillColor, outline.FillTransparency = Color3.fromRGB(142, 233, 255), 0.35
	outline.OutlineColor, outline.DepthMode = Color3.fromRGB(214, 252, 255), Enum.HighlightDepthMode.Occluded
	outline.Parent, record.frost = record.character, outline
	self:_movement(record, now())
end

function Toys:_target(hit)
	if not hit then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = self:_character(player)
		if character and hit.Instance:IsDescendantOf(character) then return player end
	end
	return nil
end

function Toys:_beam(origin, destination, color)
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return end
	local beam = part("ToyRay", Vector3.new(0.14, 0.14, delta.Magnitude), color, self.folder)
	beam.Material, beam.CFrame = Enum.Material.Neon, CFrame.lookAt((origin + destination) / 2, destination)
	Debris:AddItem(beam, 0.16)
end

function Toys:_splat(position, normal, owner, cake)
	local color = cake and Color3.fromRGB(255, 238, 209) or palette[self.random:NextInteger(1, #palette)]
	local frame = CFrame.lookAt(position + normal * 0.04, position + normal)
	for i = 0, 6 do
		local size = i == 0 and 1.55 or self.random:NextNumber(0.25, 0.7)
		local blob = part(cake and "Frosting" or "PaintSplat", Vector3.new(size, size, 0.045), color, self.folder)
		blob.Shape = Enum.PartType.Ball
		local angle = i * math.pi / 3
		blob.CFrame = frame * CFrame.new(i == 0 and 0 or math.cos(angle) * 0.9, i == 0 and 0 or math.sin(angle) * 0.9, 0)
		self:_object(owner, blob, cake and 5 or 10)
	end
end

function Toys:_launch(record, id, root, direction)
	local position = root.Position + Vector3.new(0, 1.3, 0) + direction * 2
	local length, velocity = 1.6, direction * 48 + Vector3.new(0, 15, 0)
	if id == "M02" then velocity = direction * 20 + Vector3.new(0, 48, 0) length = 1.8 end
	if id == "M04" then position = root.Position + Vector3.new(0, 4, 0) velocity = direction * 38 + Vector3.new(0, 18, 0) length = 2.7 end
	if id == "M01" then
		local ground = self:_ground(root, 3)
		if not ground then return end
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		direction = forward.Magnitude > 0.1 and forward.Unit or Vector3.new(0, 0, -1)
		position, velocity = ground + Vector3.new(0, 0.9, 0), direction * 54 + Vector3.new(0, 5, 0)
		if record.stagedBall then
			local staged = record.stagedBall
			record.stagedBall = nil
			staged.kind, staged.position, staged.velocity, staged.gravity, staged.spin, staged.bounces = id, position, velocity, 60, Vector3.new(2, 1, 0), 0
			staged.expiresAt = now() + 5
			return
		end
	end
	local object
	if id == "M11" then
		object = part("FlyingPaint", Vector3.new(0.7, 0.7, 0.7), palette[self.random:NextInteger(1, #palette)], self.folder)
		object.Shape, object.Position = Enum.PartType.Ball, position
	else object = self:_visual(id, position, length) end
	if not object then return end
	self:_object(record.player, object, 5, { kind = id, position = position, velocity = velocity, gravity = 60, spin = Vector3.new(2, 1, 0), bounces = 0 })
end

function Toys:_placePad(record, root)
	local position = self:_padGround(root)
	if not position then return false end
	local model = self:_visual("M15", position + Vector3.new(0, 0.45, 0), 6)
	if not model then return false end
	local surface = part("BounceSurface", Vector3.new(5.2, 0.45, 5.2), Color3.fromRGB(73, 196, 228), model)
	surface.Transparency, surface.CanCollide, surface.CanQuery = 1, true, true
	surface.Position = position + Vector3.new(0, 0.45, 0)
	local entry = self:_object(record.player, model, 15, { kind = "Pad", surface = surface, nextBounce = {} })
	entry.padPosition = position
	setAttribute(record.player, "PCToyPadUntil", entry.expiresAt)
	return true
end

function Toys:_effect(record, id, aim, fireShot)
	local _, _, root = self:_character(record.player)
	if not root then return end
	local direction = self:_direction(root, aim)
	if id == "M05" then record.speedUntil = now() + 25 self:_movement(record, now()) setAttribute(record.player, "PCToySpeedUntil", record.speedUntil)
	elseif id == "M06" then record.jumpUntil = now() + 10 self:_movement(record, now()) setAttribute(record.player, "PCToyJumpUntil", record.jumpUntil)
	elseif id == "M07" and not fireShot then record.emberUntil = now() + 10 setAttribute(record.player, "PCToyEmberUntil", record.emberUntil)
	elseif id == "M07" or id == "M10" then
		local origin = root.Position + Vector3.new(0, 1.4, 0)
		local range = self:_boundedRange(origin, direction, id == "M10" and 55 or 32)
		local hit = self:_ray(origin, direction * range, record.player)
		local destination = hit and hit.Position or origin + direction * range
		self:_beam(origin, destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55))
		self:_burst(destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55), id == "M10" and "frost" or "fire", 12)
		local target = self:_target(hit)
		if target then if id == "M10" then self:_freeze(target) else self:_burn(record.player, target) end end
	elseif id == "M03" then
		local hit = self:_ray(root.Position + Vector3.new(0, 0.6, 0), direction * 6, record.player)
		if hit then self:_burst(hit.Position, Color3.fromRGB(255, 227, 96), "stars", 12) if self.playBonk then self.playBonk(hit.Position) end end
	elseif id == "M08" then
		self:_confetti(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), record.player)
	elseif id == "M14" then self:_burst(root.Position + direction * 2, Color3.fromRGB(255, 174, 65), "fire", 6)
	elseif id == "M15" then
		if not self:_placePad(record, root) then
			record.cooldowns.M15 = 0
			setAttribute(record.player, "PCToyCooldown_M15", 0)
			self:_restoreVisual(record)
		end
	else self:_launch(record, id, root, direction) end
end

function Toys:Use(player, tool, aim)
	local record = self:_record(player)
	if not self.running or not record then return { ok = false, message = "Toys are for the lobby." } end
	local id = player:GetAttribute("PCGear")
	if not tool or tool.Parent ~= record.character or tool:GetAttribute("CatalogId") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return { ok = false, message = "Choose a toy first." } end
	local config = actions[id]
	if not config then return { ok = false, message = id == "M09" and "Plunger Popper is waiting for its plunger model." or "This toy's action is coming soon." } end
	local time = now()
	if time < record.freezeUntil then return { ok = false, message = "Frozen for a moment!" } end
	if time < record.busyUntil then return { ok = false, message = "Finish this action first." } end
	local fireShot = id == "M07" and time < record.emberUntil
	local readyAt = fireShot and record.nextFire or (record.cooldowns[id] or 0)
	if time < readyAt then return { ok = false, message = "Recharging", cooldownEndsAt = readyAt } end
	if aim ~= nil and not finiteVector(aim) then return { ok = false, message = "Invalid aim." } end
	if id == "M15" then local _, _, root = self:_character(player) if not self:_padGround(root) then return { ok = false, message = "Place the pad on open ground." } end end
	local duration, contact, pose = config.duration, config.contact, config.pose
	if fireShot then
		duration, contact, pose = 0.8, 0.35, "Aim"
		record.nextFire = time + 0.8
		setAttribute(player, "PCToyEmberShotUntil", record.nextFire)
	else record.cooldowns[id] = time + config.cooldown end
	record.busyUntil, record.serial = time + duration, record.serial + 1
	local serial = record.serial
	player:SetAttribute("PCToyActionItem", id)
	player:SetAttribute("PCToyAction", pose)
	player:SetAttribute("PCToyActionAt", time)
	player:SetAttribute("PCToyCooldown_" .. id, record.cooldowns[id] or 0)
	local thrown = id == "M01" or id == "M02" or id == "M04" or id == "M12" or id == "M13" or id == "M15"
	if id == "M01" then
		task.delay(0.24, function()
			if self.records[player] ~= record or record.serial ~= serial or tool.Parent ~= record.character then return end
			local _, _, root = self:_character(player)
			local ground = root and self:_ground(root, 3)
			if ground then
				self:_hideVisual(record, tool)
				local object = self:_visual(id, ground + Vector3.new(0, 0.9, 0), 1.6)
				if object then record.stagedBall = self:_object(player, object, 5.4) end
			end
		end)
	end
	task.delay(contact, function()
		if not self.running or self.records[player] ~= record or record.serial ~= serial or not self:_character(player)
			or tool.Parent ~= record.character or player:GetAttribute("PCGear") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return end
		if now() < record.freezeUntil then return end
		if fireShot and now() >= record.emberUntil then return end
		if thrown then self:_hideVisual(record, tool) end
		self:_effect(record, id, aim, fireShot)
	end)
	if thrown then
		task.delay(id == "M15" and config.cooldown or duration, function()
			if self.records[player] == record and record.serial == serial then self:_restoreVisual(record) end
		end)
	end
	return { ok = true, cooldownEndsAt = fireShot and record.nextFire or record.cooldowns[id], message = id == "M07" and not fireShot and "Drink, then tap to breathe fire!" or "" }
end

function Toys:CancelAction(player)
	local record = self.records[player]
	if record then
		record.serial += 1 record.busyUntil = 0
		self:_restoreVisual(record)
		if record.stagedBall then record.stagedBall.object:Destroy() record.stagedBall = nil end
	end
	for _, key in ipairs({ "PCToyAction", "PCToyActionAt", "PCToyActionItem" }) do player:SetAttribute(key, nil) end
end

function Toys:ClearPlayer(player)
	self:CancelAction(player)
	local record = self.records[player]
	if record then
		if record.base and record.humanoid and record.humanoid.Parent then
			for key, value in pairs(record.base) do if record.humanoid[key] == record.written[key] then record.humanoid[key] = value end end
		end
		if record.fire then record.fire:Destroy() end
		if record.frost then record.frost:Destroy() end
		self.records[player] = nil
	end
	for i = #self.objects, 1, -1 do local entry = self.objects[i] if entry.owner == player then entry.object:Destroy() table.remove(self.objects, i) end end
	for _, target in pairs(self.records) do
		if target.burnOwner == player then target.burnUntil = 0 target.burnOwner = nil end
	end
	for _, key in ipairs({ "PCToySpeedUntil", "PCToyJumpUntil", "PCToyEmberUntil", "PCToyEmberShotUntil", "PCToyFrozenUntil", "PCToyBurnUntil", "PCToyPadUntil" }) do setAttribute(player, key, 0) end
	for id in pairs(actions) do setAttribute(player, "PCToyCooldown_" .. id, 0) end
end

function Toys:_tickPlayer(record, time)
	local player = record.player
	local _, _, root = self:_character(player)
	if not root or player.Character ~= record.character then self:ClearPlayer(player) return end
	self:_movement(record, time)
	if time >= record.freezeUntil and record.frost then record.frost:Destroy() record.frost = nil end
	if record.burnOwner and not self:_character(record.burnOwner) then record.burnUntil = 0 end
	if record.burnUntil > 0 and time >= record.nextBurn and record.nextBurn <= record.burnUntil then
		record.nextBurn += 1
		record.humanoid:TakeDamage(1)
	end
	if time >= record.burnUntil and record.fire then record.fire:Destroy() record.fire = nil setAttribute(player, "PCToyBurnUntil", 0) end
	if record.character:GetAttribute("PCToyHeld") == "M14" and time >= (record.nextTorch or 0) then
		record.nextTorch = time + 0.3
		local hand = record.character:FindFirstChild("RightHand") or record.character:FindFirstChild("Right Arm")
		local origin = hand and hand.Position or root.Position
		for _, target in ipairs(Players:GetPlayers()) do
			local _, _, targetRoot = self:_character(target)
			if target ~= player and targetRoot and (targetRoot.Position - origin).Magnitude <= 4 then
				local hit = self:_ray(origin, targetRoot.Position - origin, player)
				if hit and hit.Instance:IsDescendantOf(target.Character) then self:_burn(player, target) end
			end
		end
	end
end

function Toys:_tickObject(entry, time, dt)
	local object = entry.object
	if not object.Parent or time >= entry.expiresAt or not self:_character(entry.owner) then
		if entry.kind == "Pad" and object.Parent then self:_burst(entry.padPosition, Color3.fromRGB(100, 217, 240), "stars", 18) end
		return false
	end
	if entry.kind == "Pad" then
		for _, player in ipairs(Players:GetPlayers()) do
			local _, humanoid, root = self:_character(player)
			if root then
				local delta = root.Position - entry.surface.Position
				local footHeight = humanoid.HipHeight + root.Size.Y * 0.5
				local leg = player.Character:FindFirstChild("Left Leg")
				if leg then footHeight += leg.Size.Y end
				if math.abs(delta.X) < 2.8 and math.abs(delta.Z) < 2.8 and math.abs(delta.Y - footHeight) < 1.3 and root.AssemblyLinearVelocity.Y <= 2 and time >= (entry.nextBounce[player] or 0) then
					entry.nextBounce[player] = time + 0.9
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 75, velocity.Z)
					self:_burst(entry.surface.Position, Color3.fromRGB(105, 236, 242), "stars", 10)
				end
			end
		end
		return true
	end
	if entry.shakeUntil then
		if time >= entry.shakeUntil then self:_confetti(entry.position, entry.owner) return false end
		object:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, 0, math.sin(time * 38) * 0.13) * entry.visualOffset)
		return true
	end
	if not entry.velocity then return true end
	entry.velocity += Vector3.new(0, -(entry.gravity or 60) * dt, 0)
	local nextPosition = entry.position + entry.velocity * dt
	if not self:_inside(nextPosition) then return false end
	local hit = not entry.cosmetic and self:_ray(entry.position, nextPosition - entry.position, entry.owner)
	if hit then
		if entry.kind == "M11" or entry.kind == "M13" then self:_splat(hit.Position, hit.Normal, entry.owner, entry.kind == "M13") return false
		elseif entry.kind == "M12" then
			entry.position = hit.Position + hit.Normal * 0.35
			entry.originalPivot = CFrame.new(entry.position) * entry.visualOffset
			entry.velocity, entry.shakeUntil = nil, time + 0.65
			object:PivotTo(entry.originalPivot)
			return true
		else
			entry.bounces = (entry.bounces or 0) + 1
			if entry.bounces > 8 or entry.velocity.Magnitude < 3 then entry.velocity = nil return true end
			entry.velocity = (entry.velocity - 2 * entry.velocity:Dot(hit.Normal) * hit.Normal) * 0.6
			nextPosition = hit.Position + hit.Normal * (entry.kind == "M04" and 1.1 or 0.75)
		end
	end
	entry.position = nextPosition
	local angle = entry.spin and entry.spin * (time - entry.bornAt) or Vector3.zero
	object:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(angle.X, angle.Y, angle.Z) * entry.visualOffset)
	return true
end

function Toys:Start()
	if self.running then return self end
	local lobby = workspace:WaitForChild("Playground Lobby")
	self.bounds = lobby:WaitForChild("Gameplay"):WaitForChild("LobbyBounds")
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PlaygroundToyEffects", workspace
	self.running = true
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		local time = now()
		for _, record in pairs(self.records) do self:_tickPlayer(record, time) end
		for i = #self.objects, 1, -1 do local entry = self.objects[i] if not self:_tickObject(entry, time, math.min(dt, 0.1)) then entry.object:Destroy() table.remove(self.objects, i) end end
	end)
	self.leaving = Players.PlayerRemoving:Connect(function(player) self:ClearPlayer(player) end)
	return self
end

function Toys:Stop()
	self.running = false
	if self.heartbeat then self.heartbeat:Disconnect() end
	if self.leaving then self.leaving:Disconnect() end
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:ClearPlayer(player) end
	if self.folder then self.folder:Destroy() end
	table.clear(self.objects)
end

return Toys


]=]}
}
for _,c in ipairs(changes) do assert(c.target.Source==c.before, "Source changed: "..c.name) end
local bb=workspace["British Bulldog game"]
local mud=workspace["Stuck in the Mud"]
local lobby=workspace["Playground Lobby"]
assert(bb:GetAttribute("DepartureSeconds")==5 and bb:GetAttribute("IntermissionSeconds")==12,"Bulldog settings changed")
assert(mud:GetAttribute("MinimumPlayers")==4 and mud:GetAttribute("TeamCount")==2 and mud:GetAttribute("MaxPlayers")==4 and mud:GetAttribute("MaxTeamSize")==2,"Mud settings changed")
assert(lobby:GetAttribute("IntermissionSeconds")==nil,"Lobby intermission changed")
local SS=game.ServerStorage
assert(not SS:FindFirstChild("PriorityPassBackup20261007"),"Already installed; inspect before repeating")
local backup=Instance.new("Folder") backup.Name="PriorityPassBackup20261007"
for _,c in ipairs(changes) do local old=c.target:Clone() old.Name=c.name old:SetAttribute("OriginalPath",c.target:GetFullName()) old.Parent=backup end
local settings=Instance.new("StringValue") settings.Name="PreviousConfiguration"
settings.Value=game.HttpService:JSONEncode({departure=5,bulldogIntermission=12,mudMinimum=4,mudMaxPlayers=4,mudMaxTeamSize=2,mudTeams=2,mouseLock=game.StarterPlayer.EnableMouseLockOption}) settings.Parent=backup
backup.Parent=SS
local report={}
for _,c in ipairs(changes) do c.target.Source=c.after assert(c.target.Source==c.after,"Source write mismatch: "..c.name) table.insert(report,c.name) end
bb:SetAttribute("DepartureSeconds",10) bb:SetAttribute("IntermissionSeconds",35)
lobby:SetAttribute("IntermissionSeconds",35)
mud:SetAttribute("MinimumPlayers",2) mud:SetAttribute("TeamCount",2) mud:SetAttribute("MaxPlayers",nil) mud:SetAttribute("MaxTeamSize",nil)
game.StarterPlayer.EnableMouseLockOption=true
game.StarterGui.PlaygroundPodium:SetAttribute("AvatarHeight",27.5)
for _,button in ipairs({game.StarterGui.BritishBulldogHUD.MovementControls.Dodge,game.StarterGui.TagHUD.Controls.Dodge}) do
 button:SetAttribute("PriorityPreviousVisible",button.Visible) button:SetAttribute("PriorityPreviousActive",button.Active) button:SetAttribute("PriorityPreviousInteractable",button.Interactable)
 button.Visible=false button.Active=false button.Interactable=false
end
game.ChangeHistoryService:SetWaypoint("Playground priorities October 7")
return game.HttpService:JSONEncode({installed=report,backup=backup:GetFullName(),play=game.RunService:IsRunning()})
