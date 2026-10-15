local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Service = {}
Service.__index = Service
local runningService
local BAT_SAMPLE_MAX_AGE, BAT_FACING_DOT, BAT_RAGDOLL_SECONDS = 0.15, 0.15, 1.35
local TAU, MAX_STAMINA = math.pi * 2, 5

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
	return record and record.ready and record.character and record.character.Parent and record.root and record.root.Parent
		and record.humanoid and record.humanoid.Health > 0
end
local function angularChange(first, last)
	return (last - first + math.pi) % TAU - math.pi
end
local function allParts(folder)
	local result = {}
	for _, part in ipairs(folder:GetChildren()) do if part:IsA("BasePart") then table.insert(result, part) end end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end

function Service.new(arena, config)
	local self = setmetatable({}, Service)
	self.arena, self.config = arena, config or {}
	self.gameplay = arena:WaitForChild("Gameplay")
	self.center, self.bounds = self.gameplay:WaitForChild("CircleCenter"), self.gameplay:WaitForChild("ArenaBounds")
	self.entrySpawns = allParts(self.gameplay:WaitForChild("EntrySpawns"))
	self.spectatorSpawns = allParts(self.gameplay:WaitForChild("SpectatorSpawns"))
	assert(#self.entrySpawns > 0 and #self.spectatorSpawns > 0, "Duck Duck Goose needs entry and spectator spawns")
	self.seats = {}
	for _, model in ipairs(self.gameplay:WaitForChild("Seats"):GetChildren()) do
		local seat, spot, stand = model:FindFirstChild("Seat"), model:FindFirstChild("Spot"), model:FindFirstChild("StandPoint")
		local index = model:GetAttribute("DGSeatIndex") or (seat and seat:GetAttribute("DGSeatIndex"))
		if seat and seat:IsA("Seat") and spot and spot:IsA("BasePart") and stand and stand:IsA("BasePart")
			and typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= 16 then
			assert(not self.seats[index], "Duplicate Duck Duck Goose seat index")
			local saved = { Disabled = seat.Disabled, visuals = {} }
			for _, object in ipairs(model:GetDescendants()) do
				if object:IsA("BasePart") then saved.visuals[object] = { Transparency = object.Transparency, CanCollide = object.CanCollide, CanTouch = object.CanTouch, CanQuery = object.CanQuery }
				elseif object:IsA("Decal") then saved.visuals[object] = { Transparency = object.Transparency }
				elseif object:IsA("SurfaceGui") or object:IsA("BillboardGui") then saved.visuals[object] = { Enabled = object.Enabled } end
			end
			self.seats[index] = { model = model, seat = seat, spot = spot, stand = stand, index = index, original = saved }
		end
	end
	for index = 1, 16 do assert(self.seats[index], "Duck Duck Goose needs 16 indexed seats") end
	self.state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")
	if not self.state then self.state = Instance.new("Folder") self.state.Name, self.state.Parent = "DuckDuckGooseState", ReplicatedStorage end
	self.records, self.connections = {}, {}
	self.random = Random.new()
	self.active, self.running, self.phase, self.mode = false, false, "Waiting", "Waiting"
	self.roundNumber, self.endsAt, self.tickAccumulator = 0, 0, 0
	return self
end

function Service:_setting(name, fallback, minimum, maximum)
	local value = self.config[name]
	if value == nil then value = self.arena:GetAttribute(name) end
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = fallback end
	return math.clamp(value, minimum or 0, maximum or math.huge)
end

function Service:_phase(phase)
	self.phase = phase
	attribute(self.state, "Phase", phase)
	self:_publish()
end

function Service:_publish()
	local total, living = 0, 0
	for player, record in pairs(self.records) do
		if record.inRound and player.Parent == Players then total += 1 if record.participating then living += 1 end end
	end
	attribute(self.state, "ParticipantCount", total)
	attribute(self.state, "AliveCount", living)
	attribute(self.state, "PickerUserId", self.picker and self.picker.player.UserId or 0)
	attribute(self.state, "RunnerUserId", self.turn and self.turn.runner.player.UserId or 0)
	attribute(self.state, "GooseUserId", self.turn and self.turn.goose.player.UserId or 0)
	attribute(self.state, "EmptySeatIndex", self.turn and self.turn.seat.index or 0)
	attribute(self.state, "TurnPhase", self.turnPhase or "")
	attribute(self.state, "TurnEndsAt", self.turnDeadline or 0)
	attribute(self.state, "LapProgress", self.turn and math.clamp(self.turn.progress / TAU, 0, 1) or 0)
	attribute(self.state, "FinalDuckUserId", self.finalDuck and self.finalDuck.player.UserId or 0)
	for _, slot in ipairs(self.seats) do
		attribute(slot.seat, "DGSeatedUserId", slot.record and slot.record.player.UserId or 0)
		attribute(slot.model, "DGSeatedUserId", slot.record and slot.record.player.UserId or 0)
		attribute(slot.model, "DGClaimSeat", self.turn and self.turn.seat == slot and self.phase == "Playing" or false)
		if slot.claimMarker then slot.claimMarker.Enabled = self.turn ~= nil and self.turn.seat == slot and self.phase == "Playing" and self.turnPhase == "Chasing" end
		if slot.prompt then slot.prompt.Enabled = self.active and self.phase == "Playing" and self.turnPhase == "Choosing" and slot.record ~= nil end
	end
	return living, total
end

function Service:_standUp(record)
	if not record.humanoid then return end
	record.humanoid.Sit = false
	for _, slot in ipairs(self.seats) do
		for _, weld in ipairs(slot.seat:GetChildren()) do
			if weld.Name == "SeatWeld" and weld:IsA("Weld") and weld.Part1 and record.character and weld.Part1:IsDescendantOf(record.character) then weld:Destroy() end
		end
	end
end

function Service:_teleport(record, target)
	if not alive(record) then return false end
	self:_standUp(record)
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	record.character:PivotTo(target * record.root.CFrame:Inverse() * record.character:GetPivot())
	return true
end

function Service:_movement(record)
	if not alive(record) then return end
	local sitting = record.participating and record.role == "Duck"
	local locked = sitting or record.frozen or record.ragdoll
	local allowed = record.participating and self.phase == "Playing" and not locked and (record.role == "Picker" or record.role == "Runner" or record.role == "Goose")
	local sprinting = allowed and record.sprintHeld and record.stamina > 0
	local anchor = sitting or (record.frozen and not record.ragdoll) or record.original.Anchored
	if record.root.Anchored ~= anchor then
		if anchor then pcall(function() record.root:SetNetworkOwner(nil) end) end
		record.root.Anchored = anchor
		if not anchor then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
	end
	record.humanoid.WalkSpeed = locked and 0 or sprinting and 26 or self:_setting("BaseSpeed", 16, 8, 24)
	record.humanoid.JumpPower, record.humanoid.JumpHeight = locked and 0 or record.original.JumpPower, locked and 0 or record.original.JumpHeight
	attribute(record.player, "DGSprinting", sprinting == true)
	attribute(record.player, "DGStamina", math.floor(record.stamina * 10) / 10)
	attribute(record.player, "DGMaxStamina", MAX_STAMINA)
end

function Service:_role(record, role)
	record.role = role
	attribute(record.player, "DGRole", role)
	attribute(record.player, "DGParticipating", record.participating == true)
	if record.character then attribute(record.character, "DGRole", role) end
	self:_roleMarker(record)
	self:_movement(record)
end

function Service:_clearRoleMarker(record)
	if record.roleMarker then record.roleMarker:Destroy() record.roleMarker = nil end
end

function Service:_roleMarker(record)
	local active = record.participating and (record.role == "Picker" or record.role == "Runner" or record.role == "Goose")
	if not active or not record.character or not record.character.Parent then self:_clearRoleMarker(record) return end
	local marker = record.roleMarker
	if not marker or marker.Parent ~= record.character then
		self:_clearRoleMarker(record)
		marker = Instance.new("Highlight")
		marker.Name, marker.Adornee, marker.DepthMode = "DGActiveRole", record.character, Enum.HighlightDepthMode.Occluded
		marker.FillTransparency, marker.OutlineTransparency, marker.Parent = 0.82, 0.08, record.character
		record.roleMarker = marker
	end
	marker.FillColor = record.role == "Goose" and Color3.fromRGB(255, 202, 65) or Color3.fromRGB(255, 100, 115)
	marker.OutlineColor = record.role == "Goose" and Color3.fromRGB(159, 97, 23) or Color3.fromRGB(145, 32, 48)
end

function Service:_inBounds(record)
	if not alive(record) then return false end
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Service:_polar(position)
	local point = self.center.CFrame:PointToObjectSpace(position)
	return math.sqrt(point.X * point.X + point.Z * point.Z), math.atan2(point.X, -point.Z), point.Y
end

function Service:_trackPosition(angle, radius)
	return self.center.CFrame:PointToWorldSpace(Vector3.new(math.sin(angle) * radius, 3, -math.cos(angle) * radius))
end

function Service:_outsideSeat(slot, radius)
	local _, angle = self:_polar(slot.stand.Position)
	local position = self:_trackPosition(angle, radius or 30)
	local nextPosition = self:_trackPosition(angle + 0.05, radius or 30)
	return CFrame.lookAt(position, nextPosition)
end

function Service:_seatVisibility(active)
	for _, slot in ipairs(self.seats) do
		slot.visible = active[slot.index] == true
		for object, original in pairs(slot.original.visuals) do
			if object.Parent then
				if original.Transparency ~= nil then object.Transparency = slot.visible and original.Transparency or 1 end
				if original.Enabled ~= nil then object.Enabled = slot.visible and original.Enabled end
				if object:IsA("BasePart") then
					object.CanCollide, object.CanTouch, object.CanQuery = slot.visible and original.CanCollide, slot.visible and original.CanTouch, slot.visible and original.CanQuery
				end
			end
		end
		slot.seat.Disabled = true
	end
end

function Service:_seatRecord(record, slot)
	if not alive(record) or (slot.record and slot.record ~= record) then return false end
	if record.seat and record.seat.record == record then record.seat.record = nil record.seat.seat.Disabled = true end
	record.seat, slot.record, record.seatIndex = slot, record, slot.index
	record.sprintHeld, record.batSwing = false, nil
	self:_standUp(record)
	record.root.Anchored = false
	self:_teleport(record, slot.spot.CFrame)
	slot.seat.Disabled = false
	slot.seat:Sit(record.humanoid)
	record.humanoid.Sit = true
	self:_role(record, "Duck")
	return true
end

function Service:_releaseSeat(record)
	self:_standUp(record)
	if record.seat and record.seat.record == record then record.seat.record = nil record.seat.seat.Disabled = true end
	record.seat = nil
end

function Service:_seatedDuck(record)
	return record and record.participating and record.role == "Duck" and alive(record) and record.seat
		and record.seat.record == record and record.humanoid.Sit and (record.root.Position - record.seat.spot.Position).Magnitude <= 6
end

function Service:_picker(record)
	self.turn, self.finalDuck = nil, nil
	self.picker, self.turnPhase = record, "Choosing"
	self.turnDeadline = workspace:GetServerTimeNow() + self:_setting("SelectionSeconds", 15, 5, 30)
	self:_releaseSeat(record)
	record.stamina, record.sprintHeld, record.batSwing, record.frozen = MAX_STAMINA, false, nil, false
	self:_role(record, "Picker")
	self:_teleport(record, self:_outsideSeat(self.seats[record.seatIndex], 30))
	attribute(record.player, "DGLapProgress", 0)
	self:_publish()
end

function Service:_choose(record, target, automatic)
	if not self.active or self.phase ~= "Playing" or self.turnPhase ~= "Choosing" or record ~= self.picker
		or not record or not record.participating or record.role ~= "Picker" or not alive(record) or not self:_seatedDuck(target)
		or target == record or not self:_inBounds(record) or not self:_inBounds(target) then return false end
	local now = workspace:GetServerTimeNow()
	if now - (record.lastChooseAt or -math.huge) < 0.3 then return false end
	if not automatic and (record.root.Position - target.seat.spot.Position).Magnitude > self:_setting("ChooseDistance", 10, 3, 10) then return false end
	record.lastChooseAt = now
	local targetSlot = target.seat
	self:_releaseSeat(target)
	self:_role(record, "Runner")
	self:_role(target, "Goose")
	record.stamina, target.stamina = MAX_STAMINA, MAX_STAMINA
	record.sprintHeld, target.sprintHeld = false, false
	self:_teleport(record, self:_outsideSeat(targetSlot, 30))
	self:_teleport(target, self:_outsideSeat(targetSlot, 25.5))
	local _, angle = self:_polar(record.root.Position)
	self.turn = { runner = record, goose = target, seat = targetSlot, oldRunnerSeatIndex = record.seatIndex,
		startedAt = now, lastAt = now, lastPosition = record.root.Position, lastAngle = angle,
		progress = 0, direction = 1, pathDistance = 0, credit = 6, ready = false, round = self.currentRound,
		gooseAt = now, gooseStartedAt = now, goosePosition = target.root.Position, gooseAngle = angle, gooseDistance = 0, gooseCredit = 6 }
	self.picker, self.turnPhase, self.turnDeadline = nil, "Chasing", 0
	target.batSwingReadyAt = now + 0.75
	attribute(record.player, "DGLapProgress", 0)
	self:_publish()
	return true
end

function Service:ChooseGoose(player, targetId)
	if player.Parent ~= Players or typeof(targetId) ~= "number" or targetId ~= targetId or targetId % 1 ~= 0 then return false end
	local targetPlayer = Players:GetPlayerByUserId(targetId)
	return self:_choose(self.records[player], targetPlayer and self.records[targetPlayer], false)
end

function Service:_resetLap(turn)
	turn.progress, turn.direction, turn.pathDistance, turn.ready = 0, 1, 0, false
	turn.credit = 6
	turn.startedAt, turn.lastAt = workspace:GetServerTimeNow(), workspace:GetServerTimeNow()
	self:_teleport(turn.runner, self:_outsideSeat(turn.seat, 30))
	turn.lastPosition = turn.runner.root.Position
	local _, angle = self:_polar(turn.lastPosition)
	turn.lastAngle = angle
	attribute(turn.runner.player, "DGLapProgress", 0)
end

function Service:_lap(turn, now)
	local runner = turn.runner
	local position = runner.root.Position
	local radius, angle, height = self:_polar(position)
	local elapsed = now - turn.lastAt
	if elapsed <= 0 then return end
	local offset = position - turn.lastPosition
	local travel = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local available = turn.credit + 30 * elapsed
	local minimum = self:_setting("LapInnerRadius", 25, 20, 34)
	local maximum = self:_setting("LapOuterRadius", 36, minimum + 2, 50)
	local invalid = not self:_inBounds(runner) or height < -3 or height > 18 or radius > maximum
		or (not turn.ready and radius < minimum - 0.5)
		or travel > 32 * elapsed + 1.5 or turn.pathDistance + travel > (now - turn.startedAt) * 30 + 6
		or travel > available
		or angularChange(turn.lastAngle, angle) < -0.025
	if invalid then self:_resetLap(turn) return end
	if not turn.ready then
		local delta = angularChange(turn.lastAngle, angle)
		if turn.direction == 0 and math.abs(delta) > 0.005 then turn.direction = delta > 0 and 1 or -1 end
		if turn.direction ~= 0 then turn.progress = math.clamp(turn.progress + delta * turn.direction, 0, TAU) end
		turn.ready = turn.progress >= TAU - 0.03 and now - turn.startedAt >= TAU * minimum / 32
	end
	turn.pathDistance += travel
	turn.credit = math.min(6, available - travel)
	turn.lastPosition, turn.lastAngle, turn.lastAt = position, angle, now
	attribute(runner.player, "DGLapProgress", turn.ready and 1 or math.clamp(turn.progress / TAU, 0, 1))
end

function Service:_guardGoose(turn, now)
	local goose = turn.goose
	local radius, angle, height = self:_polar(goose.root.Position)
	local elapsed = now - turn.gooseAt
	if elapsed <= 0 then return true end
	local offset = goose.root.Position - turn.goosePosition
	local travel = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local available = turn.gooseCredit + 30 * elapsed
	local valid = self:_inBounds(goose) and radius >= self:_setting("LapInnerRadius", 25, 20, 34) - 0.5
		and radius <= self:_setting("LapOuterRadius", 36, 27, 50) and height >= -3 and height <= 18
		and travel <= 32 * elapsed + 1.5 and angularChange(turn.gooseAngle, angle) >= -0.025
		and turn.gooseDistance + travel <= (now - turn.gooseStartedAt) * 30 + 6
		and travel <= available
	if not valid then
		local previousRadius, previousAngle = self:_polar(turn.goosePosition)
		local nextPosition = self:_trackPosition(previousAngle + 0.05, previousRadius)
		nextPosition = Vector3.new(nextPosition.X, turn.goosePosition.Y, nextPosition.Z)
		self:_teleport(goose, CFrame.lookAt(turn.goosePosition, nextPosition))
		goose.batSwing = nil
		goose.batSwingReadyAt = math.max(goose.batSwingReadyAt or 0, now + 0.3)
		turn.gooseCredit = math.min(6, available)
	else
		turn.goosePosition, turn.gooseAngle = goose.root.Position, angle
		turn.gooseDistance += travel
		turn.gooseCredit = math.min(6, available - travel)
	end
	turn.gooseAt = now
	return valid
end

function Service:ClaimSeat(player)
	local turn = self.turn
	local now = workspace:GetServerTimeNow()
	if player.Parent ~= Players or not self.active or self.phase ~= "Playing" or self.turnPhase ~= "Chasing"
		or now >= self.endsAt
		or not turn or turn.round ~= self.currentRound or turn.runner.player ~= player or not turn.ready
		or not turn.runner.participating or not alive(turn.runner) or turn.runner.ragdoll or turn.seat.record
		or (turn.runner.root.Position - turn.seat.spot.Position).Magnitude > 5 then return false end
	local elapsed = math.max(0, now - turn.lastAt)
	local offset = turn.runner.root.Position - turn.lastPosition
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > 32 * elapsed + 1.5 then self:_resetLap(turn) return false end
	self:_lap(turn, now)
	if self.turn ~= turn or not turn.ready or turn.round ~= self.currentRound then return false end
	local runner, goose = turn.runner, turn.goose
	runner.seatIndex = turn.seat.index
	goose.seatIndex = turn.oldRunnerSeatIndex
	if not self:_seatRecord(runner, turn.seat) then return false end
	self.turn = nil
	self:_picker(goose)
	return true
end

function Service:_rayParameters()
	local ignored = { self.bounds, self.center, self.gameplay.EntrySpawns, self.gameplay.SpectatorSpawns }
	for _, slot in ipairs(self.seats) do table.insert(ignored, slot.spot) table.insert(ignored, slot.stand) end
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(ignored, player.Character) end end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, ignored, true
	return params
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
	attribute(saved.character, "DGRagdolled", false)
	attribute(record.player, "DGRagdolled", false)
	attribute(saved.character, "PCPushed", false)
	attribute(record.player, "PCPushed", false)
	if record.character == saved.character and record.inRound then self:_movement(record) end
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
	self:_standUp(record)
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
		folder.Name = "DGRagdollConstraints"
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
						firstAttachment.Name = "DGRagdollA0"
						firstAttachment.CFrame = motor:IsA("Motor6D") and motor.C0 * motor.Transform or first.CFrame:ToObjectSpace(motor.Attachment0.WorldCFrame)
						firstAttachment.Parent = first
						table.insert(saved.created, firstAttachment)
						local secondAttachment = Instance.new("Attachment")
						secondAttachment.Name = "DGRagdollA1"
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
		attribute(record.player, "DGRagdolled", true)
		attribute(character, "DGRagdolled", true)
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
		warn("Duck Duck Goose ragdoll could not start: " .. tostring(failure))
	end
	return ok
end



function Service:TryBatSwing(player)
	local record, turn, now = self.records[player], self.turn, workspace:GetServerTimeNow()
	if player.Parent ~= Players or not self.active or self.phase ~= "Playing" or self.turnPhase ~= "Chasing"
		or now >= self.endsAt or not turn or turn.goose ~= record or not alive(record) or not record.participating
		or record.role ~= "Goose" or record.frozen or record.ragdoll or not self:_inBounds(record)
		or now < (record.batSwingReadyAt or 0) then return false end
	local radius = self:_polar(record.root.Position)
	if radius < self:_setting("LapInnerRadius", 25, 20, 34) - 0.5 or radius > self:_setting("LapOuterRadius", 36, 27, 50) then return false end
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

function Service:_retire(record)
	self:_releaseSeat(record)
	record.participating, record.sprintHeld, record.batSwing, record.frozen = false, false, nil, false
	if record.root and record.root.Parent and not record.ragdoll then record.root.Anchored = record.original.Anchored end
	attribute(record.player, "DGEliminated", true)
	self:_role(record, "Spectator")
end

function Service:_catch(turn, now)
	if self.turn ~= turn or not turn.runner.participating or not turn.goose.participating then return false end
	local runner, goose = turn.runner, turn.goose
	self:_standUp(runner)
	self:_ragdoll(runner, goose, now)
	self:_retire(runner)
	runner.afterRagdoll = self.spectatorSpawns[(runner.spawnIndex - 1) % #self.spectatorSpawns + 1].CFrame
	attribute(goose.player, "PCBatHitSerial", (goose.player:GetAttribute("PCBatHitSerial") or 0) + 1)
	self.turn = nil
	local count = self:_publish()
	if count == 1 then
		self.picker, self.turnPhase, self.turnDeadline, self.finalDuck = nil, "FinalDuck", 0, goose
		self:_seatRecord(goose, self.seats[goose.seatIndex])
		self:_publish()
	else self:_picker(goose) end
	return true
end

function Service:SetSprint(player, enabled)
	local record, now = self.records[player], workspace:GetServerTimeNow()
	if player.Parent ~= Players or typeof(enabled) ~= "boolean" or not record then return false end
	if enabled and (not self.active or self.phase ~= "Playing" or not record.participating or not alive(record)
		or record.role == "Duck" or record.ragdoll or record.frozen or now - (record.lastSprintAt or -math.huge) < 0.04) then return false end
	record.sprintHeld, record.lastSprintAt = enabled, now
	self:_movement(record)
	return true
end

function Service:_lost(record)
	if not record.participating then return end
	local wasPicker, turn = self.picker == record, self.turn
	self:_retire(record)
	if not self.active or self.phase == "Results" then self:_publish() return end
	local count = self:_publish()
	if count < self:_setting("MinimumPlayers", 2, 2, 16) then self:_finish(true) return end
	if turn and (turn.runner == record or turn.goose == record) then
		local nextPicker = turn.runner == record and turn.goose or turn.runner
		self.turn = nil
		self:_picker(nextPicker)
	elseif wasPicker then
		local options = {}
		for _, candidate in pairs(self.records) do if candidate.participating and alive(candidate) then table.insert(options, candidate) end end
		self:_picker(options[self.random:NextInteger(1, #options)])
	end
end

function Service:_restoreCharacter(record)
	self:_clearRoleMarker(record)
	self:_restoreRagdoll(record, true)
	self:_standUp(record)
	local saved = record.original
	if saved and record.humanoid and record.humanoid.Parent then
		record.humanoid.WalkSpeed, record.humanoid.JumpPower, record.humanoid.JumpHeight = saved.WalkSpeed, saved.JumpPower, saved.JumpHeight
		record.humanoid.AutoRotate, record.humanoid.PlatformStand = saved.AutoRotate, saved.PlatformStand
	end
	if saved and record.root and record.root.Parent then record.root.Anchored = saved.Anchored end
	record.sprintHeld, record.batSwing = false, nil
	attribute(record.player, "DGRagdolled", false)
	attribute(record.player, "DGSprinting", false)
end

function Service:_bindCharacter(record, character)
	self:_restoreCharacter(record)
	disconnect(record.characterConnections)
	record.character, record.ready = character, false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if self.records[record.player] ~= record or record.character ~= character or not character.Parent or not humanoid or not root then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	record.original = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate, PlatformStand = humanoid.PlatformStand, Anchored = root.Anchored }
	attribute(character, "DGRole", record.role)
	table.insert(record.characterConnections, humanoid.Died:Connect(function() if record.inRound then self:_lost(record) end end))
	if record.inRound then
		if record.participating then self:_lost(record) end
		self:_teleport(record, self.spectatorSpawns[(record.spawnIndex - 1) % #self.spectatorSpawns + 1].CFrame)
		self:_movement(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, stamina = MAX_STAMINA,
		ready = false, participating = false, inRound = false, role = "", sprintHeld = false }
	self.records[player] = record
	for name, value in pairs({ DGParticipating = false, DGRole = "", DGEliminated = false, DGStamina = MAX_STAMINA,
		DGMaxStamina = MAX_STAMINA, DGSprinting = false, DGRagdolled = false, DGResult = "", DGLapProgress = 0 }) do attribute(player, name, value) end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_bindCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character ~= record.character then return end
		if record.inRound then self:_lost(record) end
		self:_restoreCharacter(record)
		record.ready = false
	end))
	if player.Character then task.spawn(function() self:_bindCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	self:_lost(record)
	self:_restoreCharacter(record)
	self:_releaseSeat(record)
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
			and not player:GetAttribute("MDParticipating") and not player:GetAttribute("HSParticipating") then seen[player] = true table.insert(ready, player) end
	end
	for index = #ready, 2, -1 do local other = self.random:NextInteger(1, index) ready[index], ready[other] = ready[other], ready[index] end
	while #ready > self:_setting("MaxPlayers", 16, 2, 16) do table.remove(ready) end
	return ready
end

function Service:_finish(cancelled)
	if not self.active or self.phase == "Results" then return end
	local ids, participants, names = {}, {}, {}
	for player, record in pairs(self.records) do
		if record.inRound and player.Parent == Players then
			local won = not cancelled and record.participating and record.role ~= "Picker" and record.role ~= "Runner"
			table.insert(participants, player.UserId)
			if won then table.insert(ids, player.UserId) table.insert(names, player.DisplayName) end
			attribute(player, "DGResult", cancelled and "Cancelled" or won and "Won" or "Lost")
			record.frozen, record.sprintHeld, record.batSwing = true, false, nil
			self:_restoreRagdoll(record, true)
			self:_movement(record)
		end
	end
	table.sort(ids) table.sort(participants) table.sort(names)
	attribute(self.state, "WinnersText", cancelled and "Round cancelled" or "Time's up! Ducks win")
	attribute(self.state, "WinnerNames", table.concat(names, ", "))
	attribute(self.state, "LastResultWinnerIds", table.concat(ids, ","))
	attribute(self.state, "LastResultParticipantIds", table.concat(participants, ","))
	attribute(self.state, "LastResultPractice", cancelled == true)
	attribute(self.state, "LastResultRound", self.roundNumber)
	self.resultsEndsAt = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0, 15)
	attribute(self.state, "EndsAt", self.resultsEndsAt)
	self:_phase("Results")
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	if self.phase == "Results" then if now >= self.resultsEndsAt then self:_cleanup(self.currentRound) end return end
	for _, record in pairs(self.records) do
		if record.inRound and record.humanoid and record.humanoid.Health <= 0 then self:_lost(record) end
		if record.inRound and alive(record) then
			if record.ragdoll and now >= record.ragdoll.endsAt then
				self:_restoreRagdoll(record, true)
				if record.afterRagdoll then self:_teleport(record, record.afterRagdoll) record.afterRagdoll = nil end
			end
			local draining = record.participating and record.role ~= "Duck" and not record.frozen and not record.ragdoll and record.sprintHeld and record.stamina > 0
			record.stamina = math.clamp(record.stamina + (draining and -1 or 1.5) * dt, 0, MAX_STAMINA)
			self:_movement(record)
			if record.participating and record.role == "Duck" and record.seat and (not record.humanoid.Sit or (record.root.Position - record.seat.spot.Position).Magnitude > 4) then self:_seatRecord(record, record.seat) end
		end
	end
	if self.phase == "Results" then return end
	if self.phase == "Countdown" then
		attribute(self.state, "CountdownValue", math.max(0, math.ceil(self.countdownEndsAt - now)))
		if now >= self.countdownEndsAt then
			self.endsAt = now + self:_setting("RoundDuration", 180, 30, 600)
			attribute(self.state, "EndsAt", self.endsAt)
			self:_phase("Playing")
			for _, record in pairs(self.records) do if record.participating then record.frozen = false self:_movement(record) end end
			self:_picker(self.initialPicker)
		end
		return
	end
	if now >= self.endsAt then self:_finish(false) return end
	if self.turnPhase == "Choosing" then
		if self.picker and now >= self.turnDeadline then
			local closest, distance
			for _, candidate in pairs(self.records) do
				if self:_seatedDuck(candidate) then local gap = (candidate.root.Position - self.picker.root.Position).Magnitude if not distance or gap < distance then closest, distance = candidate, gap end end
			end
			if closest then self:_choose(self.picker, closest, true) end
		end
	elseif self.turnPhase == "Chasing" and self.turn then
		local turn = self.turn
		if not alive(turn.runner) or not alive(turn.goose) then return end
		self:_lap(turn, now)
		local legalGoose = self:_guardGoose(turn, now)
		if self:ClaimSeat(turn.runner.player) then return end
		local goose = turn.goose
		local swing = goose.batSwing
		if swing then
			if swing.hit or swing.character ~= goose.character or swing.token ~= self.currentRound or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then goose.batSwing = nil
			elseif legalGoose and not goose.ragdoll and self:_inBounds(goose) and self:_inBounds(turn.runner) then
				if batContact(swing, goose, turn.runner, now, self:_setting("TagDistance", 10, 1, 10), self:_rayParameters()) then swing.hit = true self:_catch(turn, now)
				else sampleBatSwing(swing, goose, self.records, now) end
			end
		end
	end
	self:_publish()
end

function Service:_begin(participants)
	self.active, self.mode, self.currentRound = true, "Round", {}
	self.roundNumber += 1
	self.endsAt, self.picker, self.turn, self.finalDuck, self.turnPhase = 0, nil, nil, nil, ""
	attribute(self.state, "Mode", "Round") attribute(self.state, "RoundNumber", self.roundNumber)
	attribute(self.state, "WinnersText", "")
	local activeSeats = {}
	for index, player in ipairs(participants) do activeSeats[math.floor((index - 1) * 16 / #participants) + 1] = true end
	self:_seatVisibility(activeSeats)
	for index, player in ipairs(participants) do
		local record = self.records[player]
		record.inRound, record.participating, record.spawnIndex, record.frozen = true, true, index, true
		record.stamina, record.lastChooseAt, record.lastSprintAt = MAX_STAMINA, -math.huge, -math.huge
		record.seatIndex = math.floor((index - 1) * 16 / #participants) + 1
		attribute(player, "DGEliminated", false) attribute(player, "DGResult", "") attribute(player, "DGLapProgress", 0)
		self:_seatRecord(record, self.seats[record.seatIndex])
	end
	self.initialPicker = self.records[participants[self.random:NextInteger(1, #participants)]]
	self.countdownEndsAt = workspace:GetServerTimeNow() + self:_setting("CountdownSeconds", 3, 1, 10)
	attribute(self.state, "EndsAt", self.countdownEndsAt)
	self:_phase("Countdown")
	return true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	local ready = self:_readyPlayers(selected)
	if #ready < self:_setting("MinimumPlayers", 2, 2, 16) then return false, "Not enough ready players" end
	local ok, result = xpcall(function() return self:_begin(ready) end, debug.traceback)
	if not ok then self:_cleanup() warn("Duck Duck Goose could not start: " .. tostring(result)) return false, "The circle could not prepare the round" end
	return result
end

function Service:_cleanup(token)
	if token and token ~= self.currentRound then return end
	for _, record in pairs(self.records) do
		if record.inRound then
			self:_releaseSeat(record)
			self:_restoreCharacter(record)
			record.inRound, record.participating, record.frozen, record.role, record.afterRagdoll = false, false, false, "", nil
			attribute(record.player, "DGParticipating", false) attribute(record.player, "DGRole", "") attribute(record.player, "DGEliminated", false)
			if record.character then attribute(record.character, "DGRole", "") end
			if self.lobbySpawn and self.lobbySpawn.Parent and alive(record) then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y * 0.5 + 3, 0)) end
		end
	end
	for _, slot in ipairs(self.seats) do
		slot.record = nil
		for object, original in pairs(slot.original.visuals) do if object.Parent then for property, value in pairs(original) do object[property] = value end end end
		slot.seat.Disabled = slot.original.Disabled
		if slot.prompt then slot.prompt.Enabled = false end
	end
	self.active, self.currentRound, self.picker, self.turn, self.finalDuck, self.turnPhase = false, nil, nil, nil, nil, ""
	self.endsAt, self.turnDeadline, self.mode = 0, 0, "Waiting"
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "CountdownValue", 0)
	self:_phase("Waiting")
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
	for _, slot in ipairs(self.seats) do
		local marker = Instance.new("Highlight")
		marker.Name, marker.Adornee, marker.DepthMode = "EmptyGooseSpot", slot.model, Enum.HighlightDepthMode.Occluded
		marker.FillColor, marker.OutlineColor = Color3.fromRGB(255, 215, 75), Color3.fromRGB(255, 236, 121)
		marker.FillTransparency, marker.OutlineTransparency, marker.Enabled, marker.Parent = 0.85, 0, false, slot.model
		slot.claimMarker = marker
		local prompt = slot.seat:FindFirstChild("SelectGoosePrompt")
		slot.createdPrompt = not prompt
		if not prompt then prompt = Instance.new("ProximityPrompt") prompt.Name, prompt.Parent = "SelectGoosePrompt", slot.seat
		else slot.originalPrompt = { ActionText = prompt.ActionText, ObjectText = prompt.ObjectText, MaxActivationDistance = prompt.MaxActivationDistance,
			KeyboardKeyCode = prompt.KeyboardKeyCode, GamepadKeyCode = prompt.GamepadKeyCode, RequiresLineOfSight = prompt.RequiresLineOfSight, Enabled = prompt.Enabled,
			gooseAttribute = prompt:GetAttribute("DGGoosePrompt") } end
		prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance = "GOOSE!", "Choose this duck", 10
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonY
		prompt.RequiresLineOfSight, prompt.Enabled = false, false
		prompt:SetAttribute("DGGoosePrompt", true)
		slot.prompt = prompt
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			if slot.record then self:ChooseGoose(player, slot.record.player.UserId) end
		end))
	end
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", EndsAt = 0, TurnPhase = "", TurnEndsAt = 0,
		PickerUserId = 0, RunnerUserId = 0, GooseUserId = 0, EmptySeatIndex = 0, FinalDuckUserId = 0,
		AliveCount = 0, ParticipantCount = 0, LapProgress = 0, CountdownValue = 0, RoundNumber = 0,
		RoundDuration = self:_setting("RoundDuration", 180, 30, 600), MinimumPlayers = self:_setting("MinimumPlayers", 2, 2, 16),
		LapDirection = "Clockwise",
		MaxPlayers = self:_setting("MaxPlayers", 16, 2, 16), WinnersText = "", LastResultWinnerIds = "",
		LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator += dt
		if self.tickAccumulator < 0.05 then return end
		local elapsed = math.min(self.tickAccumulator, 0.15) self.tickAccumulator = 0
		local ok, failure = xpcall(function() self:_tick(elapsed) end, debug.traceback)
		if not ok then warn("Duck Duck Goose round failed: " .. tostring(failure)) self:_cleanup() end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	local sprint = ReplicatedStorage:FindFirstChild("DuckDuckGooseSprintRequest")
	local action = ReplicatedStorage:FindFirstChild("DuckDuckGooseActionRequest")
	assert(sprint and sprint:IsA("RemoteEvent") and action and action:IsA("RemoteEvent"), "Duck Duck Goose remotes are missing")
	table.insert(self.connections, sprint.OnServerEvent:Connect(function(player, enabled) self:SetSprint(player, enabled) end))
	table.insert(self.connections, action.OnServerEvent:Connect(function(player, name, value)
		if name == "ChooseGoose" then self:ChooseGoose(player, value) elseif name == "ClaimSeat" then self:ClaimSeat(player) end
	end))
	return self
end

function Service:Stop()
	self.running = false
	self:_cleanup()
	disconnect(self.connections)
	for _, slot in ipairs(self.seats) do
		if slot.claimMarker then slot.claimMarker:Destroy() slot.claimMarker = nil end
		if slot.prompt and slot.prompt.Parent then
			if slot.createdPrompt then slot.prompt:Destroy()
			else
				for property, value in pairs(slot.originalPrompt) do if property ~= "gooseAttribute" then slot.prompt[property] = value end end
				slot.prompt:SetAttribute("DGGoosePrompt", slot.originalPrompt.gooseAttribute)
			end
		end
		slot.prompt, slot.createdPrompt, slot.originalPrompt = nil, nil, nil
	end
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end
	table.clear(self.records)
	if runningService == self then runningService = nil end
end
function Service.GetRunningService() return runningService end
return Service
