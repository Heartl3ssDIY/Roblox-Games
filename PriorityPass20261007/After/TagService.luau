local Players = game:GetService("Players")
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


