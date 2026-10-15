assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
assert(game.PlaceId == 95034648955135 and game.GameId == 10769034155, "Wrong experience")
local services = game:GetService("ServerScriptService")
assert(not services:FindFirstChild("HideAndSeekService"), "Inspect the existing Hide and Seek service before reinstalling")
local template = services:FindFirstChild("TagService")
assert(template and template:IsA("ModuleScript") and template.Sandboxed, "Tag permission template is missing")
assert(tostring(template.Capabilities) == "RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior", "Existing capability template changed")
local arena = workspace:FindFirstChild("Hide and Seek")
assert(arena and arena:FindFirstChild("Gameplay"), "Build the school map first")
local module = Instance.new("ModuleScript")
module.Name = "HideAndSeekService"
module.Sandboxed = true
module.Capabilities = template.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
module.Source = [======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Service = {}
Service.__index = Service
local runningService
local BAT_RAGDOLL_SECONDS = 1.35
local BAT_SAMPLE_MAX_AGE = 0.15
local BAT_FACING_DOT = 0.15
local MAX_STAMINA = 10

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



local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function alive(record)
	return record and record.ready and record.character and record.character.Parent
		and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end

local function parts(folder)
	local result = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then table.insert(result, child) end
	end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	self.hiderSpawns = parts(self.gameplay:WaitForChild("HiderSpawns"))
	self.seekerSpawns = parts(self.gameplay:WaitForChild("SeekerSpawns"))
	assert(#self.hiderSpawns >= 16 and #self.seekerSpawns > 0, "Hide and Seek needs 16 hider spawns and seeker spawns")
	self.state = state or ReplicatedStorage:FindFirstChild("HideAndSeekState")
	if not self.state then
		self.state = Instance.new("Folder")
		self.state.Name = "HideAndSeekState"
		self.state.Parent = ReplicatedStorage
	end
	self.records, self.connections, self.lockers = {}, {}, {}
	self.random = Random.new()
	self.active, self.running = false, false
	self.phase, self.mode, self.roundNumber = "Waiting", "Waiting", 0
	self.endsAt, self.hidingEndsAt, self.tickAccumulator = 0, 0, 0
	return self
end

function Service:_setting(name, fallback, minimum, maximum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = fallback end
	return math.clamp(value, minimum or 0, maximum or math.huge)
end

function Service:_phase(phase)
	self.phase = phase
	attribute(self.state, "Phase", phase)
	for _, locker in pairs(self.lockers) do locker.prompt.Enabled = self.active and (phase == "Hiding" or phase == "Seeking") end
end

function Service:_publish()
	local hiders, seekers, seekerIds = 0, 0, {}
	for player, record in pairs(self.records) do
		if record.participating and player.Parent == Players then
			if record.role == "Seeker" then seekers += 1 table.insert(seekerIds, player.UserId)
			elseif record.role == "Hider" then hiders += 1 end
		end
	end
	table.sort(seekerIds)
	attribute(self.state, "ParticipantCount", hiders + seekers)
	attribute(self.state, "HiderCount", hiders)
	attribute(self.state, "SeekerCount", seekers)
	attribute(self.state, "SeekerUserIds", table.concat(seekerIds, ","))
	return hiders, seekers
end

function Service:_movement(record)
	if not alive(record) then return end
	local locked = record.frozen or record.locker or record.ragdoll
	local allowed = record.participating and (self.phase == "Hiding" or self.phase == "Seeking") and not locked
	local sprinting = allowed and record.sprintHeld and record.stamina > 0
	local speed = record.role == "Seeker" and self:_setting("SeekerSpeed", 18, 8, 24) or self:_setting("BaseSpeed", 16, 8, 24)
	local anchor = record.locker ~= nil or (record.frozen and not record.ragdoll) or record.original.Anchored
	if record.root.Anchored ~= anchor then
		if anchor then pcall(function() record.root:SetNetworkOwner(nil) end) end
		record.root.Anchored = anchor
		if not anchor then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
	end
	record.humanoid.WalkSpeed = locked and 0 or (sprinting and 26 or speed)
	record.humanoid.JumpPower = locked and 0 or record.original.JumpPower
	record.humanoid.JumpHeight = locked and 0 or record.original.JumpHeight
	attribute(record.player, "HSSprinting", sprinting == true)
	attribute(record.player, "HSStamina", math.floor(record.stamina * 10) / 10)
	attribute(record.player, "HSMaxStamina", MAX_STAMINA)
end

function Service:_role(record, role)
	record.role = role
	attribute(record.player, "HSRole", role)
	attribute(record.player, "HSParticipating", record.participating == true)
	if record.character then attribute(record.character, "HSRole", role) end
	if record.participating then self:_concealLabels(record) end
	self:_movement(record)
end

function Service:_concealLabels(record)
	if not record.character or not record.humanoid then return end
	if not record.labels then
		record.labels = { character = record.character, humanoid = record.humanoid, objects = {},
			DisplayDistanceType = record.humanoid.DisplayDistanceType, HealthDisplayType = record.humanoid.HealthDisplayType }
	end
	record.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	record.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, object in ipairs(record.character:GetDescendants()) do
		if object:IsA("BillboardGui") then
			if not record.labels.objects[object] then record.labels.objects[object] = { Enabled = object.Enabled } end
			object.Enabled = false
		elseif object:IsA("Highlight") then
			if not record.labels.objects[object] then record.labels.objects[object] = { Enabled = object.Enabled, DepthMode = object.DepthMode } end
			object.DepthMode = Enum.HighlightDepthMode.Occluded
			object.Enabled = record.role == "Seeker" and record.labels.objects[object].Enabled or false
		end
	end
end

function Service:_restoreLabels(record)
	local saved = record.labels
	if not saved then return end
	record.labels = nil
	if saved.humanoid.Parent then
		saved.humanoid.DisplayDistanceType, saved.humanoid.HealthDisplayType = saved.DisplayDistanceType, saved.HealthDisplayType
	end
	for object, original in pairs(saved.objects) do
		if object.Parent then object.Enabled = original.Enabled if original.DepthMode then object.DepthMode = original.DepthMode end end
	end
end

function Service:_inBounds(record, margin)
	if not alive(record) then return false end
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size * 0.5
	return math.abs(point.X) <= half.X - (margin or 0) and math.abs(point.Z) <= half.Z - (margin or 0)
		and math.abs(point.Y) <= half.Y and record.root.Position.Y >= self:_setting("FloorY", 33, -100000) - 8
end

function Service:_releaseSeat(record)
	local seat = record.humanoid.SeatPart
	record.humanoid.Sit = false
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(record.character) then weld:Destroy() end
end

function Service:_teleport(record, target)
	if not alive(record) then return false end
	self:_releaseSeat(record)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	record.character:PivotTo(target * record.root.CFrame:Inverse() * record.character:GetPivot())
	return true
end

function Service:_spawn(index, seeker)
	local list = seeker and self.seekerSpawns or self.hiderSpawns
	return list[(index - 1) % #list + 1].CFrame
end

function Service:_rayParameters(extra)
	local ignored = { self.bounds, self.gameplay.HiderSpawns, self.gameplay.SeekerSpawns }
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(ignored, player.Character) end end
	if extra then table.insert(ignored, extra) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	return params
end

function Service:_restoreLocker(record, moveOutside)
	local saved = record.locker
	if not saved then return end
	record.locker = nil
	if saved.locker.occupant == record then saved.locker.occupant = nil end
	for part, original in pairs(saved.parts) do
		if part.Parent then part.CanCollide = original end
	end
	for object, original in pairs(saved.visuals) do
		if object.Parent then object[original.property] = original.value end
	end
	if saved.root.Parent then
		saved.root.Anchored = saved.anchored
		saved.root.AssemblyLinearVelocity = Vector3.zero
		saved.root.AssemblyAngularVelocity = Vector3.zero
	end
	attribute(record.player, "HSHiding", false)
	if saved.character.Parent then attribute(saved.character, "HSHiding", false) end
	if record.character == saved.character and alive(record) then
		if moveOutside then self:_teleport(record, saved.locker.exit.CFrame) end
		pcall(function() if saved.owner then saved.root:SetNetworkOwner(saved.owner) else saved.root:SetNetworkOwnershipAuto() end end)
		self:_movement(record)
	end
end

function Service:_concealLocker(record, added)
	local saved = record.locker
	if not saved or saved.character ~= record.character then return end
	local objects = added and { added } or record.character:GetDescendants()
	for _, object in ipairs(objects) do
		local property, value
		if object:IsA("BasePart") or object:IsA("Decal") then property, value = "Transparency", 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Highlight") then property, value = "Enabled", false end
		if property then
			if not saved.visuals[object] then saved.visuals[object] = { property = property, value = object[property] } end
			object[property] = value
		end
		if object:IsA("BasePart") then
			if saved.parts[object] == nil then saved.parts[object] = object.CanCollide end
			object.CanCollide = false
		end
	end
end

function Service:_enterLocker(record, locker)
	if locker.occupant or record.locker or not alive(record) or record.role ~= "Hider" then return false end
	local saved = { locker = locker, character = record.character, root = record.root, anchored = record.root.Anchored, parts = {}, visuals = {} }
	pcall(function() saved.owner = record.root:GetNetworkOwner() record.root:SetNetworkOwner(nil) end)
	record.locker, locker.occupant = saved, record
	record.sprintHeld, record.batSwing = false, nil
	self:_concealLabels(record)
	self:_concealLocker(record)
	self:_teleport(record, locker.hide.CFrame)
	record.root.Anchored = true
	attribute(record.player, "HSHiding", true)
	attribute(record.character, "HSHiding", true)
	self:_movement(record)
	return true
end

function Service:_exitClear(record, locker)
	local direction = locker.exit.Position - locker.hide.Position
	return direction.Magnitude <= 10 and not workspace:Raycast(locker.hide.Position, direction, self:_rayParameters(locker.model))
end

function Service:UseLocker(player, locker)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if not self.active or (self.phase ~= "Hiding" and self.phase ~= "Seeking") or player.Parent ~= Players
		or not record or not record.participating or not alive(record) or record.frozen or record.ragdoll
		or not locker or self.lockers[locker.model] ~= locker or not locker.door.Parent or not self:_inBounds(record)
		or now - (record.lastLockerAt or -math.huge) < 0.4 then return false end
	record.lastLockerAt = now
	if record.locker then
		if record.locker.locker ~= locker or not self:_exitClear(record, locker) then return false end
		self:_restoreLocker(record, true)
		return true
	end
	local offset = locker.door.Position - record.root.Position
	if offset.Magnitude > 6 or not self:_exitClear(record, locker)
		or workspace:Raycast(record.root.Position, offset, self:_rayParameters(locker.model)) then return false end
	if record.role == "Hider" then return self:_enterLocker(record, locker) end
	if record.role ~= "Seeker" or self.phase ~= "Seeking" or now < (record.batSwingReadyAt or 0) then return false end
	record.batSwingReadyAt = now + 0.75
	attribute(player, "PCBatSwingAt", now)
	attribute(player, "PCBatSwingSerial", (player:GetAttribute("PCBatSwingSerial") or 0) + 1)
	local target = locker.occupant
	if not target then return true end
	if self.records[target.player] ~= target or not alive(target) or not target.participating or target.role ~= "Hider"
		or not target.locker or target.locker.locker ~= locker
		or (target.root.Position - locker.hide.Position).Magnitude > 2 then return false end
	self:_restoreLocker(target, true)
	return self:_convert(target, record, now)
end

function Service:ExitLocker(player)
	local record = self.records[player]
	if not record or not record.locker then return false end
	return self:UseLocker(player, record.locker.locker)
end

function Service:_bindLockers()
	for _, model in ipairs(self.gameplay:WaitForChild("LockerSpots"):GetChildren()) do
		local door, hide, exit = model:FindFirstChild("Door"), model:FindFirstChild("HidePoint"), model:FindFirstChild("ExitPoint")
		local prompt = door and door:FindFirstChild("LockerPrompt")
		if model:IsA("Model") and door and door:IsA("BasePart") and hide and hide:IsA("BasePart")
			and exit and exit:IsA("BasePart") and prompt and prompt:IsA("ProximityPrompt")
			and (hide.Position - door.Position).Magnitude <= 6 and (exit.Position - door.Position).Magnitude <= 8 then
			local locker = { model = model, door = door, hide = hide, exit = exit, prompt = prompt }
			self.lockers[model] = locker
			prompt.ActionText, prompt.ObjectText = "Hide / Search / Exit", "Locker"
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Enabled = 6, false, false
			table.insert(self.connections, prompt.Triggered:Connect(function(player) self:UseLocker(player, locker) end))
		end
	end
	assert(next(self.lockers), "Hide and Seek needs usable lockers")
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
	attribute(saved.character, "HSRagdolled", false)
	attribute(record.player, "HSRagdolled", false)
	attribute(saved.character, "PCPushed", false)
	attribute(record.player, "PCPushed", false)
	if record.character == saved.character and record.participating then self:_movement(record) end
	if saved.root.Parent and not record.frozen then
		pcall(function()
			if record.isBot then saved.root:SetNetworkOwner(nil) else saved.root:SetNetworkOwnershipAuto() end
		end)
	end
end

function Service:_ragdoll(record, attacker, now, duration, kind)
	if not alive(record) then return false end
	kind = kind or "Bat"
	duration = duration or BAT_RAGDOLL_SECONDS
	local existing = record.ragdoll
	if existing and existing.character == record.character and existing.token == self.currentRound then
		if kind == "Push" then return false end
		existing.kind = "Bat"
		existing.endsAt = math.max(existing.endsAt, now + duration)

		attribute(record.character, "PCPushed", false)
		attribute(record.player, "PCPushed", false)
		return true
	end
	self:_restoreRagdoll(record, true)
	self:_releaseSeat(record)
	local character, humanoid, root = record.character, record.humanoid, record.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local saved = {
		character = character, humanoid = humanoid, root = root,
		endsAt = now + duration, token = self.currentRound, kind = kind, wasPush = kind == "Push",
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
		folder.Name = "HSRagdollConstraints"
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
						firstAttachment.Name = "HSRagdollA0"
						firstAttachment.CFrame = motor:IsA("Motor6D") and motor.C0 * motor.Transform or first.CFrame:ToObjectSpace(motor.Attachment0.WorldCFrame)
						firstAttachment.Parent = first
						table.insert(saved.created, firstAttachment)
						local secondAttachment = Instance.new("Attachment")
						secondAttachment.Name = "HSRagdollA1"
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
		attribute(record.player, "HSRagdolled", true)
		attribute(character, "HSRagdolled", true)
		attribute(character, "PCPushed", kind == "Push")
		attribute(record.player, "PCPushed", kind == "Push")
		table.insert(saved.connections, humanoid.Died:Connect(function()
			if record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
		table.insert(saved.connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent and record.ragdoll == saved then self:_restoreRagdoll(record, false) end
		end))
	end, debug.traceback)
	if not ok then
		self:_restoreRagdoll(record, true)
		warn("Hide and Seek ragdoll could not start: " .. tostring(failure))
	end
	return ok
end



function Service:TryBatSwing(player)
	local record, now = self.records[player], workspace:GetServerTimeNow()
	if player.Parent ~= Players or not self.active or self.phase ~= "Seeking" or now >= self.endsAt
		or not record or not record.participating or record.role ~= "Seeker" or not alive(record)
		or record.frozen or record.ragdoll or record.locker or not self:_inBounds(record)
		or now < (record.batSwingReadyAt or 0) then return false, "Cannot swing right now" end
	record.batSwingReadyAt = now + 0.75
	record.batSwing = { hitAt = now + 0.10, endsAt = now + 0.38, hit = false, character = record.character, token = self.currentRound }
	sampleBatSwing(record.batSwing, record, self.records, now)
	attribute(player, "PCBatSwingAt", now)
	attribute(player, "PCBatSwingSerial", (player:GetAttribute("PCBatSwingSerial") or 0) + 1)
	return true
end

function Service:CancelBatSwing(player)
	local record = self.records[player]
	if not record then return false end
	record.batSwing = nil
	return true
end

function Service:_convert(target, seeker, now)
	if not self.active or self.phase ~= "Seeking" or not target.participating or target.role ~= "Hider" then return false end
	self:_restoreLocker(target, true)
	target.sprintHeld, target.batSwing, target.stamina = false, nil, MAX_STAMINA
	target.batSwingReadyAt = now + BAT_RAGDOLL_SECONDS + 0.25
	attribute(target.player, "HSFoundAt", now)
	self:_role(target, "Seeker")
	if alive(target) then self:_ragdoll(target, seeker, now) end
	if seeker then
		seeker.tagsMade = (seeker.tagsMade or 0) + 1
		attribute(seeker.player, "PCBatHitSerial", (seeker.player:GetAttribute("PCBatHitSerial") or 0) + 1)
	end
	self:_publish()
	return true
end

function Service:SetSprint(player, enabled)
	local record, now = self.records[player], workspace:GetServerTimeNow()
	if typeof(enabled) ~= "boolean" or player.Parent ~= Players or not record then return false end
	if enabled and (not self.active or not record.participating or not alive(record) or record.frozen or record.ragdoll or record.locker
		or (self.phase ~= "Hiding" and self.phase ~= "Seeking") or now - (record.lastSprintAt or -math.huge) < 0.04) then return false end
	record.lastSprintAt, record.sprintHeld = now, enabled
	self:_movement(record)
	return true
end

function Service:_restoreCharacter(record)
	self:_restoreLocker(record, false)
	self:_restoreRagdoll(record, true)
	self:_restoreLabels(record)
	local saved = record.original
	if saved and record.humanoid and record.humanoid.Parent then
		record.humanoid.WalkSpeed, record.humanoid.JumpPower, record.humanoid.JumpHeight = saved.WalkSpeed, saved.JumpPower, saved.JumpHeight
		record.humanoid.AutoRotate, record.humanoid.PlatformStand = saved.AutoRotate, saved.PlatformStand
	end
	if saved and record.root and record.root.Parent then record.root.Anchored = saved.Anchored end
	record.sprintHeld, record.batSwing = false, nil
	attribute(record.player, "HSSprinting", false)
	attribute(record.player, "HSRagdolled", false)
end

function Service:_bindCharacter(record, character)
	self:_restoreCharacter(record)
	disconnect(record.characterConnections)
	record.character, record.ready = character, false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if record.character ~= character or not character.Parent or self.records[record.player] ~= record
		or not humanoid or not root or not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	record.original = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate, PlatformStand = humanoid.PlatformStand, Anchored = root.Anchored }
	attribute(character, "HSRole", record.role or "")
	attribute(character, "HSHiding", false)
	attribute(character, "HSRagdolled", false)
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(object)
		if record.participating and (object:IsA("BillboardGui") or object:IsA("Highlight")) then self:_concealLabels(record) end
		if record.locker then self:_concealLocker(record, object) end
	end))
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		self:_restoreLocker(record, false)
		self:_restoreRagdoll(record, false)
		record.batSwing, record.sprintHeld = nil, false
		if record.participating and record.role == "Hider" then
			if self.phase == "Seeking" then self:_convert(record, nil, workspace:GetServerTimeNow())
			else self:_role(record, "Seeker") self:_publish() end
		end
	end))
	if record.participating and self.active then
		record.frozen = self.phase == "Countdown" or self.phase == "Results" or (self.phase == "Hiding" and record.role == "Seeker")
		record.stamina = MAX_STAMINA
		self:_teleport(record, self:_spawn(record.spawnIndex or 1, record.role == "Seeker"))
		self:_concealLabels(record)
		self:_movement(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, ready = false, participating = false,
		role = "", stamina = MAX_STAMINA, sprintHeld = false }
	self.records[player] = record
	for name, value in pairs({ HSParticipating = false, HSRole = "", HSHiding = false, HSRagdolled = false,
		HSSprinting = false, HSStamina = MAX_STAMINA, HSMaxStamina = MAX_STAMINA, HSResult = "" }) do attribute(player, name, value) end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_bindCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character ~= character then return end
		self:_restoreCharacter(record)
		record.ready = false
		if record.participating and record.role == "Hider" then self:_role(record, "Seeker") self:_publish() end
	end))
	if player.Character then task.spawn(function() self:_bindCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	self:_restoreCharacter(record)
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self.records[player] = nil
	self:_publish()
end

function Service:_readyPlayers(selectedPlayers)
	local result, seen = {}, {}
	for _, player in ipairs(selectedPlayers or Players:GetPlayers()) do
		local record = self.records[player]
		if not seen[player] and player.Parent == Players and alive(record) and not record.participating
			and player:GetAttribute("PCDataReady") == true and not player:GetAttribute("PCAFK") and not player:GetAttribute("PCAFKRequested")
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") then
			seen[player] = true
			table.insert(result, player)
		end
	end
	for index = #result, 2, -1 do
		local other = self.random:NextInteger(1, index)
		result[index], result[other] = result[other], result[index]
	end
	while #result > math.floor(self:_setting("MaxPlayers", 16, 2, 16)) do table.remove(result) end
	return result
end

function Service:_finish(seekersWon, cancelled)
	if not self.active or self.phase == "Results" then return end
	local winners, winnerIds, participantIds = {}, {}, {}
	for player, record in pairs(self.records) do
		if record.participating and player.Parent == Players then
			self:_restoreLocker(record, true)
			self:_restoreRagdoll(record, true)
			record.frozen, record.sprintHeld, record.batSwing = true, false, nil
			local won = not cancelled and ((seekersWon and record.role == "Seeker") or (not seekersWon and record.role == "Hider"))
			attribute(player, "HSResult", cancelled and "Cancelled" or (won and "Won" or "Lost"))
			table.insert(participantIds, player.UserId)
			if won then table.insert(winnerIds, player.UserId) table.insert(winners, player.DisplayName) end
			self:_movement(record)
		end
	end
	table.sort(winnerIds) table.sort(participantIds) table.sort(winners)
	attribute(self.state, "WinnersText", cancelled and "Round cancelled" or (seekersWon and "Everybody found! Seekers win" or "Time's up! Hiders win"))
	attribute(self.state, "WinnerNames", table.concat(winners, ", "))
	attribute(self.state, "WinningRole", cancelled and "" or (seekersWon and "Seeker" or "Hider"))
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ","))
	attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ","))
	attribute(self.state, "LastResultPractice", cancelled == true)
	attribute(self.state, "LastResultRound", self.roundNumber)
	self.resultsEndsAt = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0, 15)
	attribute(self.state, "EndsAt", self.resultsEndsAt)
	self:_phase("Results")
	local event = self.state:FindFirstChild("RoundFinished")
	if event and event:IsA("BindableEvent") then event:Fire({ game = "HideAndSeek", roundNumber = self.roundNumber,
		winnerUserIds = winnerIds, participantUserIds = participantIds, practice = cancelled == true }) end
end

function Service:_ensureSeeker()
	local hiders, seekers = self:_publish()
	if seekers > 0 or hiders == 0 then return end
	local options = {}
	for _, record in pairs(self.records) do if record.participating and record.role == "Hider" then table.insert(options, record) end end
	local record = options[self.random:NextInteger(1, #options)]
	self:_restoreLocker(record, true)
	self:_role(record, "Seeker")
	record.frozen = self.phase == "Hiding" or self.phase == "Countdown"
	if alive(record) then self:_teleport(record, self:_spawn(record.spawnIndex or 1, true)) self:_movement(record) end
	self:_publish()
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	if self.phase == "Results" then
		if now >= self.resultsEndsAt then self:_cleanup(self.currentRound) end
		return
	end
	self:_ensureSeeker()
	local hiders, seekers = self:_publish()
	if hiders + seekers < 2 then self:_finish(false, true) return end
	if hiders == 0 and self.phase ~= "Seeking" then self:_finish(false, true) return end
	if self.phase == "Countdown" and now >= self.countdownEndsAt then
		self.hidingEndsAt = now + self:_setting("HideSeconds", 20, 5, 60)
		attribute(self.state, "HidingEndsAt", self.hidingEndsAt)
		attribute(self.state, "EndsAt", self.hidingEndsAt)
		attribute(self.state, "CountdownValue", 0)
		self:_phase("Hiding")
		for _, record in pairs(self.records) do if record.participating then record.frozen = record.role == "Seeker" self:_movement(record) end end
	elseif self.phase == "Countdown" then attribute(self.state, "CountdownValue", math.max(0, math.ceil(self.countdownEndsAt - now))) end
	if self.phase == "Hiding" and now >= self.hidingEndsAt then
		self.endsAt = now + self:_setting("RoundDuration", 180, 30, 600)
		attribute(self.state, "EndsAt", self.endsAt)
		self:_phase("Seeking")
		for _, record in pairs(self.records) do if record.participating then record.frozen = false self:_movement(record) end end
	end
	if self.phase ~= "Hiding" and self.phase ~= "Seeking" then return end
	for _, record in pairs(self.records) do
		if record.participating and record.humanoid and record.humanoid.Health <= 0 then
			self:_restoreLocker(record, false)
			self:_restoreRagdoll(record, false)
			record.batSwing, record.sprintHeld = nil, false
			if record.role == "Hider" then self:_role(record, "Seeker") end
		elseif record.participating and alive(record) then
			if record.ragdoll and now >= record.ragdoll.endsAt then self:_restoreRagdoll(record, true) end
			if record.locker and (record.locker.character ~= record.character
				or (record.root.Position - record.locker.locker.hide.Position).Magnitude > 2) then self:_restoreLocker(record, true) end
			if not self:_inBounds(record) and not record.ragdoll then self:_restoreLocker(record, false) self:_teleport(record, self:_spawn(record.spawnIndex or 1, record.role == "Seeker")) end
			local draining = not record.frozen and not record.locker and not record.ragdoll and record.sprintHeld and record.stamina > 0
			record.stamina = math.clamp(record.stamina + (draining and -1 or 1.5) * dt, 0, MAX_STAMINA)
			self:_movement(record)
		end
	end
	if self.phase ~= "Seeking" then return end
	if hiders == 0 then self:_finish(true) return end
	if now >= self.endsAt then self:_finish(false) return end
	local rayParameters = self:_rayParameters()
	for _, seeker in pairs(self.records) do
		local swing = seeker.batSwing
		if swing then
			if swing.hit or swing.character ~= seeker.character or swing.token ~= self.currentRound or now > swing.endsAt + BAT_SAMPLE_MAX_AGE
				or not alive(seeker) or not seeker.participating or seeker.role ~= "Seeker" or seeker.frozen or seeker.ragdoll or not self:_inBounds(seeker) then seeker.batSwing = nil
			else
				local nearest, best
				for _, target in pairs(self.records) do
					if target.participating and target.role == "Hider" and alive(target) and not target.locker and not target.ragdoll and self:_inBounds(target) then
						local hit, distance = batContact(swing, seeker, target, now, self:_setting("TagDistance", 10, 1, 10), rayParameters)
						if hit and (not best or distance < best) then nearest, best = target, distance end
					end
				end
				if nearest then swing.hit = true self:_convert(nearest, seeker, now) end
				sampleBatSwing(swing, seeker, self.records, now)
			end
		end
	end
	if self:_publish() == 0 then self:_finish(true) end
end

function Service:_begin(participants)
	self.active, self.mode, self.currentRound = true, "Round", {}
	self.roundNumber += 1
	self.endsAt, self.hidingEndsAt = 0, 0
	attribute(self.state, "Mode", "Round")
	attribute(self.state, "RoundNumber", self.roundNumber)
	attribute(self.state, "WinnersText", "")
	attribute(self.state, "WinningRole", "")
	attribute(self.state, "HidingEndsAt", 0)
	attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 180, 30, 600))
	local firstSeeker = participants[self.random:NextInteger(1, #participants)]
	self.countdownEndsAt = workspace:GetServerTimeNow() + self:_setting("CountdownSeconds", 3, 1, 10)
	attribute(self.state, "EndsAt", self.countdownEndsAt)
	self:_phase("Countdown")
	for index, player in ipairs(participants) do
		local record = self.records[player]
		record.participating, record.spawnIndex, record.frozen = true, index, true
		record.stamina, record.sprintHeld, record.tagsMade = MAX_STAMINA, false, 0
		record.batSwingReadyAt, record.lastLockerAt, record.lastSprintAt = 0, -math.huge, -math.huge
		attribute(player, "HSResult", "")
		self:_role(record, player == firstSeeker and "Seeker" or "Hider")
		self:_teleport(record, self:_spawn(index, player == firstSeeker))
	end
	self:_publish()
	return true
end

function Service:StartRound(selectedPlayers)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	local participants = self:_readyPlayers(selectedPlayers)
	if #participants < self:_setting("MinimumPlayers", 2, 2, 16) then return false, "Not enough ready players" end
	local ok, result = xpcall(function() return self:_begin(participants) end, debug.traceback)
	if not ok then self:_cleanup() warn("Hide and Seek could not start: " .. tostring(result)) return false, "The school could not prepare the round" end
	return result
end

function Service:_cleanup(token)
	if token and token ~= self.currentRound then return end
	for _, record in pairs(self.records) do
		if record.participating then
			self:_restoreCharacter(record)
			record.participating, record.frozen, record.role = false, false, ""
			attribute(record.player, "HSParticipating", false)
			attribute(record.player, "HSRole", "")
			if record.character then attribute(record.character, "HSRole", "") end
			if self.lobbySpawn and self.lobbySpawn.Parent and alive(record) then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y * 0.5 + 3, 0)) end
		end
	end
	for _, locker in pairs(self.lockers) do locker.occupant = nil end
	self.active, self.currentRound, self.mode, self.endsAt, self.hidingEndsAt = false, nil, "Waiting", 0, 0
	attribute(self.state, "Mode", "Waiting")
	attribute(self.state, "EndsAt", 0)
	attribute(self.state, "HidingEndsAt", 0)
	attribute(self.state, "CountdownValue", 0)
	self:_phase("Waiting")
	self:_publish()
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end
	self:_cleanup()
	attribute(self.state, "WinnersText", "Round stopped by admin")
	return true
end

function Service:Start()
	if self.running then return self end
	self.running, runningService = true, self
	self:_bindLockers()
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", EndsAt = 0, HidingEndsAt = 0, CountdownValue = 0,
		RoundNumber = 0, RoundDuration = self:_setting("RoundDuration", 180, 30, 600), HideSeconds = self:_setting("HideSeconds", 20, 5, 60),
		ParticipantCount = 0, SeekerCount = 0, HiderCount = 0, SeekerUserIds = "", WinnersText = "", WinningRole = "",
		LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0,
		MinimumPlayers = self:_setting("MinimumPlayers", 2, 2, 16), MaxPlayers = self:_setting("MaxPlayers", 16, 2, 16) }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator += dt
		if self.tickAccumulator < 0.05 then return end
		local elapsed = math.min(self.tickAccumulator, 0.15)
		self.tickAccumulator = 0
		local ok, failure = xpcall(function() self:_tick(elapsed) end, debug.traceback)
		if not ok then warn("Hide and Seek round failed: " .. tostring(failure)) self:_cleanup() end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	local remote = ReplicatedStorage:FindFirstChild("HideAndSeekSprintRequest")
	assert(remote and remote:IsA("RemoteEvent"), "Hide and Seek sprint remote is missing")
	table.insert(self.connections, remote.OnServerEvent:Connect(function(player, enabled) self:SetSprint(player, enabled) end))
	local lockerRemote = ReplicatedStorage:FindFirstChild("HideAndSeekActionRequest")
	assert(lockerRemote and lockerRemote:IsA("RemoteEvent"), "Hide and Seek locker remote is missing")
	table.insert(self.connections, lockerRemote.OnServerEvent:Connect(function(player, action)
		if action == "LeaveLocker" then self:ExitLocker(player) end
	end))
	return self
end

function Service:Stop()
	self.running = false
	self:_cleanup()
	disconnect(self.connections)
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end
	table.clear(self.records)
	table.clear(self.lockers)
	if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end
return Service
]======]
module:SetAttribute("BuildDate", "2026-10-10")
module:SetAttribute("NativeFixtureChecks", 131)
module.Parent = services
local ok, result = pcall(require, module)
if not ok or type(result) ~= "table" or type(result.new) ~= "function" or type(result.StartRound) ~= "function"
	or type(result.TryBatSwing) ~= "function" or type(result.ExitLocker) ~= "function" then
	module:Destroy()
	error("Hide and Seek installation failed: " .. tostring(result))
end
return { path = module:GetFullName(), capabilities = tostring(module.Capabilities), sourceLength = #module.Source, nativeChecks = 131 }
