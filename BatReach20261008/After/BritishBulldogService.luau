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
local TAG_DISTANCE = 10
local BAT_RAGDOLL_SECONDS = 1.35

local BAT_SAMPLE_MAX_AGE = 0.15
local BAT_FACING_DOT = 0.15

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
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - BAT_FACING_DOT * BAT_FACING_DOT * facingLength[i] * horizontalLength[j] end
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
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= BAT_FACING_DOT - 1e-7)
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
			provider:CollisionGroupSetCollidable(first, second, true)
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
	if record.role == "Runner" and alive(record) and (self:_inside(self.safeZones.North, record.root.Position) or self:_inside(self.safeZones.South, record.root.Position)) then
		record.sprintRemaining = record.sprintMax
		record.sprintExhausted = false
	end
	record.sprinting = allowed and record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
		if record.sprintRemaining == 0 then record.sprintExhausted = true record.sprinting = false end
	elseif record.sprintExhausted or not record.sprintHeld then
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
		if record.sprintExhausted and record.sprintRemaining >= self:_setting("SprintResumeSeconds", 0.5, 0.05) then
			record.sprintExhausted = false
		end
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
	if self.arena:GetAttribute("DodgeEnabled") ~= true then return { ok = false, message = "Dodge is coming back soon." } end
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
					if runner ~= attacker and runner.participating and alive(runner) and (not runner.frozen or runner.ragdoll and runner.ragdoll.kind == "Push")
						and (not runner.ragdoll or runner.ragdoll.kind == "Push")
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
		if saved.wasPush then
			local parameters = RaycastParams.new()
			parameters.FilterType = Enum.RaycastFilterType.Exclude
			local ignored = { saved.character }
			for _, other in pairs(self.records) do
				if other.character then table.insert(ignored, other.character) end
			end
			parameters.FilterDescendantsInstances = ignored
			parameters.RespectCanCollide = true
			local position = saved.root.Position
			local floor = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), parameters)
			local leg = saved.character:FindFirstChild("Left Leg") or saved.character:FindFirstChild("Right Leg")
			local legHeight = humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") and leg.Size.Y or 0
			if floor then position = Vector3.new(position.X, floor.Position.Y + humanoid.HipHeight + legHeight + saved.root.Size.Y * 0.5 + 0.1, position.Z) end
			saved.standCFrame = CFrame.new(position) * saved.standCFrame.Rotation
		end
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
	setAttribute(saved.character, "PCPushed", false)
	setAttribute(record.player, "PCPushed", false)
	if record.character == saved.character then self:_lockJump(record) end
	if saved.root.Parent and not record.frozen then
		pcall(function()
			if record.isBot then saved.root:SetNetworkOwner(nil) else saved.root:SetNetworkOwnershipAuto() end
		end)
	end
end

function Service:_ragdoll(record, attacker, now, duration, kind)
	if not alive(record) then self:_freeze(record) return false end
	kind = kind or "Bat"
	duration = duration or BAT_RAGDOLL_SECONDS
	local existing = record.ragdoll
	if existing and existing.character == record.character and existing.token == self.currentRound then
		if kind == "Push" then return false end
		existing.kind = "Bat"
		existing.endsAt = math.max(existing.endsAt, now + duration)
		existing.freezeAfter = true
		record.frozen = true

		setAttribute(record.character, "PCPushed", false)
		setAttribute(record.player, "PCPushed", false)
		return true
	end
	self:_restoreRagdoll(record, true)
	self:_stopDodgeBurst(record)
	local character, humanoid, root = record.character, record.humanoid, record.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local saved = {
		character = character, humanoid = humanoid, root = root,
		endsAt = now + duration, token = self.currentRound, kind = kind, wasPush = kind == "Push", freezeAfter = kind ~= "Push",
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
					local existing = socketsByPart[first] and socketsByPart[first][second] or socketsByPart[second] and socketsByPart[second][first]
					if existing then
						for _, socket in ipairs(existing) do
							if saved.sockets[socket] == nil then saved.sockets[socket] = socket.Enabled end
							socket.Enabled = true
						end
					else
					local firstAttachment = Instance.new("Attachment")
					firstAttachment.Name = "BBRagdollA0"
					firstAttachment.CFrame = motor:IsA("Motor6D") and motor.C0 * motor.Transform or first.CFrame:ToObjectSpace(motor.Attachment0.WorldCFrame)
					firstAttachment.Parent = first
					table.insert(saved.created, firstAttachment)
					local secondAttachment = Instance.new("Attachment")
					secondAttachment.Name = "BBRagdollA1"
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
		setAttribute(character, "PCPushed", kind == "Push")
		setAttribute(record.player, "PCPushed", kind == "Push")
		table.insert(saved.connections, humanoid.Died:Connect(function()
			if record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
		table.insert(saved.connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent and record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
	end, debug.traceback)
	if not ok then
		self:_restoreRagdoll(record, true)
		if kind == "Push" then self:_unfreeze(record) else self:_freeze(record) end
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
					if runner.participating and alive(runner) and (not runner.ragdoll or runner.ragdoll.kind == "Push") and Rules.CanTag(self.phase, runner.role, runner.departed, runner.arrived, self:_inField(runner.root.Position), false) then
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
	local lastRunnerArrived = false
	if self.lastRunnerWins and runners == 1 then
		for _, record in pairs(self.records) do
			if record.participating and record.role == "Runner" and alive(record) then
				lastRunnerArrived = record.arrived == true and record.departed == true
				break
			end
		end
	end
	return Rules.Outcome(runners, bulldogs, tagged, participants, self.endsAt > 0 and workspace:GetServerTimeNow() >= self.endsAt,
		self.lastRunnerWins == true, lastRunnerArrived)
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
	for _, record in pairs(self.records) do
		if record.participating and record.role == "Bulldog" and alive(record) then
			self:_teleport(record, self:_spawnCFrame("Bulldog", record.spawnIndex or 1))
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
	local startingRunners = self:_counts()
	self.lastRunnerWins = startingRunners >= 2
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


