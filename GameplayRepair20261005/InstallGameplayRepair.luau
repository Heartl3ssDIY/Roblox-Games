assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local function normalize(s) return (s:gsub("\r",""):gsub("%s+$","")) end
local entries={}
table.insert(entries,{target=game.ServerScriptService.TagService,before=[====[local Players = game:GetService("Players")
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

return Service

]====],after=[====[local Players = game:GetService("Players")
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

]====]})
table.insert(entries,{target=game.ServerScriptService.BritishBulldogService,before=[====[local Players = game:GetService("Players")
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

return Service

]====],after=[====[local Players = game:GetService("Players")
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

]====]})
table.insert(entries,{target=game.StarterGui.TagHUD.Controller,before=[====[local Players = game:GetService("Players")
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
	for _, action in ipairs({ "Vault", "Dodge" }) do
		local button = controls[action]
		local cooldown = secondsRemaining(player:GetAttribute("TG" .. action .. "ReadyAt"), now)
		local shortcut = action == "Vault" and "[Q]" or "[X]"
		button.Text = string.upper(action) .. "\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or shortcut)
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
]====],after=[====[local Players = game:GetService("Players")
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
]====]})
table.insert(entries,{target=game.StarterGui.TagHUD.SprintController,before=[====[local Players=game:GetService("Players")
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
local elapsed=0
local lease=0
local connections={}
local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function active() return player:GetAttribute("TGParticipating")==true and state:GetAttribute("Phase")=="Playing" end
local function inputContext()
 local phase=state:GetAttribute("Phase")
 return player:GetAttribute("TGParticipating")==true and (phase=="Playing" or phase=="Countdown")
end
local function request(value)
 pending=value
 if sending then return end
 sending=true
 task.spawn(function()
  while pending~=nil do
   local value=pending pending=nil
   pcall(function() remote:InvokeServer(value) end)
  end
  sending=false
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
 if not panel.Visible then return end
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
 if bound then ContextActionService:UnbindAction("TagSprint") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()
]====],after=[====[local Players=game:GetService("Players")
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
]====]})
table.insert(entries,{target=game.StarterGui.BritishBulldogHUD.MovementController,before=[====[local Players=game:GetService("Players")
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
local animations={}
local observers={}
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

local function restorePose(animation)
 if animation then
  for motor,base in pairs(animation.bases) do if motor.Parent then motor.Transform=base end end
  table.clear(animation.bases)
 end
end

local function stopPose(target)
 restorePose(animations[target])
 animations[target]=nil
end

local function poseAllowed(target)
 local character=target.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return alive and target.Parent==Players and target:GetAttribute("BBParticipating")==true
  and target:GetAttribute("BBRole")=="Runner" and target:GetAttribute("BBStatus")=="Crossing"
  and phase()=="Crossing" and humanoid and humanoid.Health>0
end

local function beginPose(target,direction,startedAt,duration)
 local character=target.Character
 local current=animations[target]
 if current and current.character==character and current.started==startedAt
  and current.worldDirection==direction and current.duration==duration then return end
 stopPose(target)
 if not character then return end
 local motors={}
 local hasWaist=character:FindFirstChild("Waist",true)~=nil
 for _,descendant in ipairs(character:GetDescendants()) do
  if descendant:IsA("Motor6D") then
   if descendant.Name=="RootJoint" or descendant.Name=="Root" then motors[descendant]=hasWaist and "Root" or "Body"
   elseif descendant.Name=="Waist" then motors[descendant]="Waist"
   elseif descendant.Name=="RightShoulder" or descendant.Name=="Right Shoulder" then motors[descendant]="Right"
   elseif descendant.Name=="LeftShoulder" or descendant.Name=="Left Shoulder" then motors[descendant]="Left" end
  end
 end
 local root=character:FindFirstChild("HumanoidRootPart")
 if not root or next(motors)==nil then return end
 local localDirection=root.CFrame:VectorToObjectSpace(direction)
 animations[target]={started=startedAt,duration=duration,worldDirection=direction,
  direction=localDirection.X,motors=motors,bases={},character=character}
end

local function syncDodgePose(target)
 local observer=observers[target]
 if not observer or observer.character~=target.Character or not poseAllowed(target) then stopPose(target) return end
 local started=numberAttribute(target,"BBDodgeStartedAt",0)
 local duration=math.clamp(numberAttribute(target,"BBDodgeDuration",0.32),0.2,0.5)+0.14
 local elapsed=workspace:GetServerTimeNow()-started
 local direction=target:GetAttribute("BBDodgeDirection")
 if started<=0 or elapsed<0 or elapsed>=duration or typeof(direction)~="Vector3" then stopPose(target) return end
 beginPose(target,direction,started,duration)
end

local function unobservePlayer(target)
 local observer=observers[target]
 if observer then
  for _,connection in ipairs(observer.connections) do connection:Disconnect() end
  observers[target]=nil
 end
 stopPose(target)
end

local function observePlayer(target)
 if observers[target] then return end
 local observer={character=target.Character,connections={}}
 observers[target]=observer
 for _,name in ipairs({"BBDodgeStartedAt","BBDodgeDirection","BBDodgeDuration","BBParticipating","BBRole","BBStatus"}) do
  table.insert(observer.connections,target:GetAttributeChangedSignal(name):Connect(function() syncDodgePose(target) end))
 end
 table.insert(observer.connections,target.CharacterRemoving:Connect(function(character)
  if observer.character==character then observer.character=nil end
  stopPose(target)
 end))
 table.insert(observer.connections,target.CharacterAdded:Connect(function(character)
  stopPose(target)
  observer.character=character
  syncDodgePose(target)
 end))
 syncDodgePose(target)
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
  if alive and success and typeof(response)=="table" and response.ok and canSprint()
   and player:GetAttribute("BBStatus")=="Crossing" then
   syncDodgePose(player)
  end
  dodgeBusy=false
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
connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() stopPose(player) end)
connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() stopPose(player) syncJumpLock() end)
connect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)
connect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)
connect(Players.PlayerAdded,observePlayer)
connect(Players.PlayerRemoving,unobservePlayer)
for _,target in ipairs(Players:GetPlayers()) do observePlayer(target) end
connect(RunService.PreAnimation,function()
 for _,animation in pairs(animations) do restorePose(animation) end
end)
connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
 for target,animation in pairs(animations) do
  local elapsed=workspace:GetServerTimeNow()-animation.started
  if elapsed>=animation.duration or not poseAllowed(target) or target.Character~=animation.character then
   stopPose(target)
   continue
  end
  local alpha=math.clamp(elapsed/animation.duration,0,1)
  local strength=alpha<0.22 and math.sin(alpha/0.22*math.pi/2)
   or math.cos((alpha-0.22)/0.78*math.pi/2)^2
  for motor,kind in pairs(animation.motors) do
   if motor.Parent then
    local base=motor.Transform
    animation.bases[motor]=base
    local direction=animation.direction
    local weight=kind=="Root" and 0.65 or kind=="Waist" and 0.35 or 1
    local body=kind=="Body" or kind=="Root" or kind=="Waist"
    local pose=body and CFrame.new(0,-0.16*strength*weight,0)
      *CFrame.Angles(math.rad(-9)*strength*weight,math.rad(8)*strength*direction*weight,math.rad(-26)*strength*direction*weight)
     or CFrame.Angles(math.rad(-12)*strength,0,math.rad(kind=="Right" and 18 or -18)*strength)
    if body then
     local jointRotation=motor.C0.Rotation
     pose=jointRotation:Inverse()*pose*jointRotation
    end
    motor.Transform=base*pose
   end
  end
 end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then
  elapsed=0
  refresh()
  for target in pairs(observers) do syncDodgePose(target) end
 end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 alive=false
 releaseHold()
 releaseJumpLock()
 for target in pairs(observers) do unobservePlayer(target) end
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]====],after=[====[local Players=game:GetService("Players")
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

]====]})
table.insert(entries,{target=game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes,before=[====[local Players = game:GetService("Players")
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
	joint.Transform = original * offset
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local bodyNames = {
	"HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local function collectJoints(character)
	local joints = {}
	for _, name in ipairs(bodyNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then joints[child.Name] = child end
			end
		end
	end
	return joints
end
local function bodyJoints(record, character, now)
	if not record.bodyJoints or now - (record.jointsAt or -math.huge) >= 0.5 then
		record.bodyJoints = collectJoints(character)
		record.jointsAt = now
	end
	return record.bodyJoints
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
local batPoses = {
	{ time = 0, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
	{ time = 0.105, r6 = vector(116, 4, -40), r15 = vector(91, 4, -35), elbow = 42,
		wrist = vector(-6, -12, -8), root = vector(3, -16, -3), waist = vector(2, -19, -2),
		guide = vector(106, -60, 10), guideElbow = 15, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.15, r6 = vector(111, 4, -35), r15 = vector(87, 4, -30), elbow = 36,
		wrist = vector(-9, -9, -5), root = vector(1, -9, -2), waist = vector(0, -12, -1),
		guide = vector(100, -60, 10), guideElbow = 8, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.22, r6 = vector(45, 28, -16), r15 = vector(36, 28, -16), elbow = 9,
		wrist = vector(-7, 3, 2), root = vector(-5, 9, 4), waist = vector(-3, 15, 2),
		guide = vector(56, -68, 10), guideElbow = 5, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.30, r6 = vector(74, 84, -24), r15 = vector(54, 80, -19), elbow = 33,
		wrist = vector(8, 13, 10), root = vector(-2, 18, 5), waist = vector(-1, 23, 3),
		guide = vector(53, -8, 15), guideElbow = 35, guideWeight = 0.5, bodyWeight = 1 },
	{ time = 0.365, r6 = vector(88, 62, -18), r15 = vector(65, 56, -15), elbow = 37,
		wrist = vector(4, 8, 4), root = vector(0, 13, 3), waist = vector(0, 15, 2),
		guide = vector(41, -4, 9), guideElbow = 28, guideWeight = 0.25, bodyWeight = 0.65 },
	{ time = 0.48, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
}
local function tangent(index, key)
	if index == 1 or index == #batPoses then return batPoses[index][key] * 0 end
	local before, current, after = batPoses[index - 1], batPoses[index], batPoses[index + 1]
	local incoming = (current[key] - before[key]) / (current.time - before.time)
	local outgoing = (after[key] - current[key]) / (after.time - current.time)
	return (incoming + outgoing) * 0.35
end
local function sampleBatPose(elapsed, classic)
	local first = batPoses[1]
	if elapsed < 0 or elapsed >= 0.48 then elapsed = 0 end
	local index = 2
	while index < #batPoses and elapsed > batPoses[index].time do index += 1 end
	local start, finish = batPoses[index - 1], batPoses[index]
	local duration = finish.time - start.time
	local t = math.clamp((elapsed - start.time) / duration, 0, 1)
	local t2, t3 = t * t, t * t * t
	local result = {}
	for key, value in pairs(first) do
		if key ~= "time" then
			result[key] = start[key] * (2 * t3 - 3 * t2 + 1)
				+ tangent(index - 1, key) * duration * (t3 - 2 * t2 + t)
				+ finish[key] * (-2 * t3 + 3 * t2)
				+ tangent(index, key) * duration * (t3 - t2)
		end
	end
	result.shoulder = result[classic and "r6" or "r15"]
	result.guideWeight = math.clamp(result.guideWeight, 0, 1)
	result.bodyWeight = math.clamp(result.bodyWeight, 0, 1)
	return result
end
local function weaponJoint(record, joint, angles, weight, additive)
	if not joint or not joint.Parent or weight <= 0
		or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) or not joint.Enabled then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local basis = joint.C0.Rotation
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local target = basis:Inverse() * rotation * basis
	if additive then target = original * target end
	joint.Transform = original:Lerp(target, math.clamp(weight, 0, 1))
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function applyBatPose(record, joints, sampled, classic, fade)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], sampled.shoulder, fade)
	weaponJoint(record, joints.RightElbow, vector(sampled.elbow, 0, 0), fade)
	weaponJoint(record, joints.RightWrist, sampled.wrist, fade)
	local guide = sampled.guideWeight * fade
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], sampled.guide, guide)
	weaponJoint(record, joints.LeftElbow, vector(sampled.guideElbow, 0, 0), guide)
	weaponJoint(record, joints.LeftWrist, vector(0, 10, -8), guide)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record, joints.RootJoint or joints.Root, root, fade, true)
	if not classic then weaponJoint(record, joints.Waist, sampled.waist, fade, true) end
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record, joints.Neck, vector(-chest.X * 0.4, -chest.Y * 0.6, -chest.Z * 0.5), fade, true)
	local weight = sampled.bodyWeight
	weaponJoint(record, joints[classic and "Right Hip" or "RightHip"],
		vector(-root.X + 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"],
		vector(-root.X - 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints.RightKnee, vector(-3 * weight, 0, 0), fade, true)
	weaponJoint(record, joints.LeftKnee, vector(-5 * weight, 0, 0), fade, true)
end
local function animateBat(record, player, character, humanoid, now)
	local gameName = character:GetAttribute("PCBatGame")
	local participating = (gameName == "BritishBulldog" and player:GetAttribute("BBParticipating") == true)
		or (gameName == "TagYoureIt" and player:GetAttribute("TGParticipating") == true)
	if humanoid.Health <= 0 or character:GetAttribute("PCBatHeld") ~= true or not participating
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true then
		record.weapon = nil
		return false
	end
	if record.weapon ~= gameName then
		record.weapon = gameName
		record.weaponAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCBatSwingAt")
	local elapsed = typeof(started) == "number" and started == started and now - started or math.huge
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local sampled = sampleBatPose(elapsed, classic)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	applyBatPose(record, bodyJoints(record, character, now), sampled, classic, fade)
	return true
end
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
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
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil record.toy = nil continue end
		if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end
		if animateToy(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			continue
		end
		bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = record.bodyJoints[classic and "Right Shoulder" or "RightShoulder"]
		local left = record.bodyJoints[classic and "Left Shoulder" or "LeftShoulder"]
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, record.bodyJoints.RightElbow, CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, record.bodyJoints.Waist, CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
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
end)


]====],after=[====[local Players = game:GetService("Players")
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
	joint.Transform = original * offset
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local bodyNames = {
	"HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local function collectJoints(character)
	local joints = {}
	for _, name in ipairs(bodyNames) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then joints[child.Name] = child end
			end
		end
	end
	return joints
end
local function bodyJoints(record, character, now)
	if not record.bodyJoints or now - (record.jointsAt or -math.huge) >= 0.5 then
		record.bodyJoints = collectJoints(character)
		record.jointsAt = now
	end
	return record.bodyJoints
end
local function vector(x, y, z) return Vector3.new(x, y, z) end
local batPoses = {
	{ time = 0, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
	{ time = 0.105, r6 = vector(116, 4, -40), r15 = vector(91, 4, -35), elbow = 42,
		wrist = vector(-6, -12, -8), root = vector(3, -16, -3), waist = vector(2, -19, -2),
		guide = vector(106, -60, 10), guideElbow = 15, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.15, r6 = vector(111, 4, -35), r15 = vector(87, 4, -30), elbow = 36,
		wrist = vector(-9, -9, -5), root = vector(1, -9, -2), waist = vector(0, -12, -1),
		guide = vector(100, -60, 10), guideElbow = 8, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.22, r6 = vector(45, 28, -16), r15 = vector(36, 28, -16), elbow = 9,
		wrist = vector(-7, 3, 2), root = vector(-5, 9, 4), waist = vector(-3, 15, 2),
		guide = vector(56, -68, 10), guideElbow = 5, guideWeight = 1, bodyWeight = 1 },
	{ time = 0.30, r6 = vector(74, 84, -24), r15 = vector(54, 80, -19), elbow = 33,
		wrist = vector(8, 13, 10), root = vector(-2, 18, 5), waist = vector(-1, 23, 3),
		guide = vector(53, -8, 15), guideElbow = 35, guideWeight = 0.5, bodyWeight = 1 },
	{ time = 0.365, r6 = vector(88, 62, -18), r15 = vector(65, 56, -15), elbow = 37,
		wrist = vector(4, 8, 4), root = vector(0, 13, 3), waist = vector(0, 15, 2),
		guide = vector(41, -4, 9), guideElbow = 28, guideWeight = 0.25, bodyWeight = 0.65 },
	{ time = 0.48, r6 = vector(90, 0, -8), r15 = vector(65, 0, -8), elbow = 25,
		wrist = vector(0, 0, 0), root = vector(0, 0, 0), waist = vector(0, 0, 0),
		guide = vector(75, -30, 16), guideElbow = 48, guideWeight = 0, bodyWeight = 0 },
}
local function tangent(index, key)
	if index == 1 or index == #batPoses then return batPoses[index][key] * 0 end
	local before, current, after = batPoses[index - 1], batPoses[index], batPoses[index + 1]
	local incoming = (current[key] - before[key]) / (current.time - before.time)
	local outgoing = (after[key] - current[key]) / (after.time - current.time)
	return (incoming + outgoing) * 0.35
end
local function sampleBatPose(elapsed, classic)
	local first = batPoses[1]
	if elapsed < 0 or elapsed >= 0.48 then elapsed = 0 end
	local index = 2
	while index < #batPoses and elapsed > batPoses[index].time do index += 1 end
	local start, finish = batPoses[index - 1], batPoses[index]
	local duration = finish.time - start.time
	local t = math.clamp((elapsed - start.time) / duration, 0, 1)
	local t2, t3 = t * t, t * t * t
	local result = {}
	for key, value in pairs(first) do
		if key ~= "time" then
			result[key] = start[key] * (2 * t3 - 3 * t2 + 1)
				+ tangent(index - 1, key) * duration * (t3 - 2 * t2 + t)
				+ finish[key] * (-2 * t3 + 3 * t2)
				+ tangent(index, key) * duration * (t3 - t2)
		end
	end
	result.shoulder = result[classic and "r6" or "r15"]
	result.guideWeight = math.clamp(result.guideWeight, 0, 1)
	result.bodyWeight = math.clamp(result.bodyWeight, 0, 1)
	return result
end
local function weaponJoint(record, joint, angles, weight, additive)
	if not joint or not joint.Parent or weight <= 0
		or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) or not joint.Enabled then return end
	local previous = record.joints[joint]
	local original = joint.Transform
	if previous and original == previous.applied then original = previous.original end
	local basis = joint.C0.Rotation
	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local target = basis:Inverse() * rotation * basis
	if additive then target = original * target end
	joint.Transform = original:Lerp(target, math.clamp(weight, 0, 1))
	record.joints[joint] = { original = original, applied = joint.Transform }
end
local function applyBatPose(record, joints, sampled, classic, fade)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], sampled.shoulder, fade)
	weaponJoint(record, joints.RightElbow, vector(sampled.elbow, 0, 0), fade)
	weaponJoint(record, joints.RightWrist, sampled.wrist, fade)
	local guide = sampled.guideWeight * fade
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], sampled.guide, guide)
	weaponJoint(record, joints.LeftElbow, vector(sampled.guideElbow, 0, 0), guide)
	weaponJoint(record, joints.LeftWrist, vector(0, 10, -8), guide)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record, joints.RootJoint or joints.Root, root, fade, true)
	if not classic then weaponJoint(record, joints.Waist, sampled.waist, fade, true) end
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record, joints.Neck, vector(-chest.X * 0.4, -chest.Y * 0.6, -chest.Z * 0.5), fade, true)
	local weight = sampled.bodyWeight
	weaponJoint(record, joints[classic and "Right Hip" or "RightHip"],
		vector(-root.X + 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"],
		vector(-root.X - 2 * weight, -root.Y * 0.8, -root.Z), fade, true)
	weaponJoint(record, joints.RightKnee, vector(-3 * weight, 0, 0), fade, true)
	weaponJoint(record, joints.LeftKnee, vector(-5 * weight, 0, 0), fade, true)
end
local function animateBat(record, player, character, humanoid, now)
	local gameName = character:GetAttribute("PCBatGame")
	local participating = (gameName == "BritishBulldog" and player:GetAttribute("BBParticipating") == true)
		or (gameName == "TagYoureIt" and player:GetAttribute("TGParticipating") == true)
	if humanoid.Health <= 0 or character:GetAttribute("PCBatHeld") ~= true or not participating
		or player:GetAttribute("MDParticipating") == true
		or player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true then
		record.weapon = nil
		return false
	end
	if record.weapon ~= gameName then
		record.weapon = gameName
		record.weaponAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCBatSwingAt")
	local elapsed = typeof(started) == "number" and started == started and now - started or math.huge
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local sampled = sampleBatPose(elapsed, classic)
	local fade = math.clamp((now - record.weaponAt) / 0.1, 0, 1)
	applyBatPose(record, bodyJoints(record, character, now), sampled, classic, fade)
	return true
end
local toyActions = {
	M01 = { action = "Kick", duration = 1.10, placeAt = 0.24, contactAt = 0.60 },
	M02 = { action = "Lob", duration = 0.85, contactAt = 0.34 },
	M03 = { action = "Bonk", duration = 0.58, contactAt = 0.23 },
	M04 = { action = "BarrelThrow", duration = 1.10, contactAt = 0.52 },
	M05 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M06 = { action = "Drink", duration = 1.30, contactAt = 0.82 },
	M07 = { action = "Drink", duration = 1.30, contactAt = 0.82, alternateAction = "Aim", alternateDuration = 0.80 },
	M08 = { action = "Shake", duration = 1.05, contactAt = 0.65 },
	M10 = { action = "Aim", duration = 0.80, contactAt = 0.35 },
	M11 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M12 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M13 = { action = "Throw", duration = 0.78, contactAt = 0.30 },
	M14 = { action = "Carry", duration = 0 },
	M15 = { action = "Place", duration = 1.00, contactAt = 0.46 },
}
local function toyPose(values)
	local result = {
		right = vector(64, 0, -8), elbow = 20, wrist = Vector3.zero,
		left = vector(55, -32, 10), leftElbow = 20, leftWeight = 0,
		root = Vector3.zero, waist = Vector3.zero,
		rightHip = Vector3.zero, leftHip = Vector3.zero,
		rightKnee = 0, leftKnee = 0,
		barrelLift = 0, drinkTip = 0,
	}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end
local toyIdle = {
	M01 = toyPose({right=vector(52,0,-12)}),
	M02 = toyPose({right=vector(65,8,-20),elbow=25,left=vector(65,-34,14),leftElbow=24,leftWeight=0.65}),
	M03 = toyPose({right=vector(82,0,-10),elbow=25}),
	M04 = toyPose({right=vector(63,14,-25),elbow=18,left=vector(65,-34,18),leftElbow=18,leftWeight=1}),
	M05 = toyPose(), M06 = toyPose(), M07 = toyPose(),
	M08 = toyPose({right=vector(65,12,-24),elbow=24,left=vector(65,-34,18),leftElbow=24,leftWeight=0.85}),
	M10 = toyPose({right=vector(75,4,-12),elbow=20,left=vector(63,-35,15),leftElbow=25,leftWeight=0.45}),
	M11 = toyPose(), M12 = toyPose(), M13 = toyPose(),
	M14 = toyPose({right=vector(90,-6,-17),elbow=23}),
	M15 = toyPose({right=vector(52,12,-20),elbow=16,left=vector(53,-36,17),leftElbow=16,leftWeight=1}),
}
local function toyKey(time, values) return { time=time, pose=toyPose(values) } end
local toyTracks = {
	Kick = {
		toyKey(0),
		toyKey(0.24,{right=vector(48,8,-18),elbow=6,root=vector(-28,0,0),waist=vector(-14,0,0),
			left=vector(20,-5,18),leftWeight=.7,rightHip=vector(22,0,0),leftHip=vector(22,0,0),rightKnee=-24,leftKnee=-24}),
		toyKey(0.43,{right=vector(20,-4,-22),elbow=6,root=vector(-2,-5,-3),
			left=vector(18,0,25),leftWeight=.7,rightHip=vector(-26,0,-3),rightKnee=-32}),
		toyKey(0.60,{right=vector(27,-5,-28),elbow=8,root=vector(8,8,3),waist=vector(5,5,0),
			left=vector(25,0,28),leftWeight=.85,rightHip=vector(72,0,-3),leftHip=vector(-5,0,0),rightKnee=-4}),
		toyKey(0.76,{right=vector(30,0,-19),elbow=12,root=vector(4,6,2),
			left=vector(24,0,18),leftWeight=.5,rightHip=vector(38,0,0),rightKnee=-12}),
		toyKey(1.10),
	},
	Lob = {
		toyKey(0),
		toyKey(0.19,{right=vector(122,8,-22),elbow=48,left=vector(125,-27,19),leftElbow=44,leftWeight=1,
			root=vector(5,0,0),waist=vector(4,0,0),rightKnee=-9,leftKnee=-9}),
		toyKey(0.34,{right=vector(153,7,-15),elbow=8,left=vector(151,-18,14),leftElbow=8,leftWeight=1,
			root=vector(-3,0,0),waist=vector(-3,0,0)}),
		toyKey(0.48,{right=vector(132,9,-17),elbow=12,wrist=vector(14,0,0),
			left=vector(126,-20,15),leftElbow=14,leftWeight=.8,root=vector(-4,0,0)}),
		toyKey(0.85),
	},
	Bonk = {
		toyKey(0),
		toyKey(0.12,{right=vector(118,-24,-32),elbow=36,root=vector(3,-15,-3),waist=vector(0,-12,0),
			left=vector(75,-47,16),leftElbow=30,leftWeight=.65}),
		toyKey(0.23,{right=vector(47,28,-17),elbow=9,wrist=vector(-9,5,0),
			root=vector(-5,10,4),waist=vector(-3,13,0),left=vector(43,-28,18),leftElbow=12,leftWeight=.4}),
		toyKey(0.34,{right=vector(71,76,-23),elbow=28,root=vector(-2,17,4),waist=vector(0,19,0)}),
		toyKey(0.58),
	},
	BarrelThrow = {
		toyKey(0),
		toyKey(0.23,{right=vector(102,8,-20),elbow=35,left=vector(104,-29,19),leftElbow=35,leftWeight=1,
			root=vector(-8,0,0),waist=vector(-5,0,0),rightKnee=-13,leftKnee=-13}),
		toyKey(0.40,{right=vector(164,8,-18),elbow=22,left=vector(163,-20,17),leftElbow=22,leftWeight=1,barrelLift=1,
			root=vector(7,0,0),waist=vector(6,0,0)}),
		toyKey(0.52,{right=vector(104,5,-15),elbow=5,left=vector(103,-20,16),leftElbow=5,leftWeight=1,
			root=vector(-13,0,0),waist=vector(-8,0,0)}),
		toyKey(0.69,{right=vector(69,9,-18),elbow=9,left=vector(68,-25,18),leftElbow=9,leftWeight=.8,
			root=vector(-10,0,0),waist=vector(-5,0,0)}),
		toyKey(1.10),
	},
	Drink = {
		toyKey(0),
		toyKey(0.32,{right=vector(128,8,-37),elbow=58,wrist=vector(-14,0,-8),root=vector(2,0,0)}),
		toyKey(0.60,{right=vector(136,7,-39),elbow=65,wrist=vector(-31,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(0.82,{right=vector(135,7,-39),elbow=64,wrist=vector(-35,0,-8),root=vector(4,0,0),waist=vector(2,0,0),drinkTip=1}),
		toyKey(1.02,{right=vector(113,8,-27),elbow=44,wrist=vector(-10,0,-3),root=vector(1,0,0)}),
		toyKey(1.30),
	},
	Shake = {
		toyKey(0),
		toyKey(0.20,{right=vector(94,13,-28),elbow=34,left=vector(93,-35,20),leftElbow=33,leftWeight=1}),
		toyKey(0.35,{right=vector(103,6,-31),elbow=39,left=vector(103,-41,23),leftElbow=38,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.48,{right=vector(82,20,-23),elbow=26,left=vector(82,-28,17),leftElbow=25,leftWeight=1,root=vector(0,3,2)}),
		toyKey(0.65,{right=vector(105,7,-32),elbow=40,left=vector(104,-40,23),leftElbow=39,leftWeight=1,root=vector(0,-3,-2)}),
		toyKey(0.78,{right=vector(83,18,-24),elbow=28,left=vector(84,-30,18),leftElbow=27,leftWeight=.9,root=vector(0,2,1)}),
		toyKey(1.05),
	},
	Aim = {
		toyKey(0),
		toyKey(0.22,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.35,{right=vector(89,5,-11),elbow=14,left=vector(81,-37,19),leftElbow=32,leftWeight=.9,
			root=vector(-3,-5,0),waist=vector(0,-5,0)}),
		toyKey(0.41,{right=vector(97,3,-14),elbow=24,left=vector(85,-38,20),leftElbow=38,leftWeight=.9,
			root=vector(1,-5,0),waist=vector(2,-5,0)}),
		toyKey(0.80),
	},
	Throw = {
		toyKey(0),
		toyKey(0.17,{right=vector(136,-31,-32),elbow=44,root=vector(4,-14,-3),waist=vector(2,-14,0),
			left=vector(62,6,16),leftWeight=.6}),
		toyKey(0.30,{right=vector(90,11,-16),elbow=5,wrist=vector(12,0,0),
			root=vector(-7,10,3),waist=vector(-4,12,0),left=vector(32,-7,19),leftWeight=.4}),
		toyKey(0.45,{right=vector(57,49,-25),elbow=16,root=vector(-5,15,3),waist=vector(-3,12,0)}),
		toyKey(0.78),
	},
	Place = {
		toyKey(0),
		toyKey(0.24,{right=vector(47,12,-21),elbow=12,left=vector(49,-36,18),leftElbow=12,leftWeight=1,
			root=vector(-18,0,0),waist=vector(-12,0,0),rightHip=vector(15,0,0),leftHip=vector(15,0,0),rightKnee=-20,leftKnee=-20}),
		toyKey(0.46,{right=vector(41,12,-20),elbow=3,left=vector(42,-35,17),leftElbow=3,leftWeight=1,
			root=vector(-29,0,0),waist=vector(-16,0,0),rightHip=vector(26,0,0),leftHip=vector(26,0,0),rightKnee=-30,leftKnee=-30}),
		toyKey(0.64,{right=vector(31,6,-20),elbow=8,left=vector(32,-21,18),leftElbow=8,leftWeight=.7,
			root=vector(-16,0,0),waist=vector(-8,0,0),rightHip=vector(13,0,0),leftHip=vector(13,0,0),rightKnee=-16,leftKnee=-16}),
		toyKey(1.00),
	},
}
local function sampleToyPose(id, action, elapsed)
	local idle = toyIdle[id]
	local definition = toyActions[id]
	if not idle or not definition then return nil end
	local track = toyTracks[action]
	local duration = action == definition.action and definition.duration or action == definition.alternateAction and definition.alternateDuration
	if not duration or not track or elapsed ~= elapsed or elapsed < 0 or elapsed >= duration then return idle end
	local index = 2
	while index < #track and elapsed > track[index].time do index += 1 end
	local before, after = track[index - 1], track[index]
	local alpha = math.clamp((elapsed - before.time) / (after.time - before.time), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local first = index == 2 and idle or before.pose
	local last = index == #track and idle or after.pose
	local sampled = {}
	for key, value in pairs(first) do sampled[key] = value + (last[key] - value) * alpha end
	return sampled
end
local function applyToyPose(record, joints, sampled, classic, fade)
	local right = sampled.right - vector(classic and 0 or sampled.elbow,0,0)
	local left = sampled.left - vector(classic and 0 or sampled.leftElbow,0,0)
	if classic then
		right += vector(-24,32,-12) * sampled.barrelLift
		left += vector(-23,-20,13) * sampled.barrelLift
	end
	local wrist = sampled.wrist + (classic and Vector3.zero or vector(45,80,38) * sampled.drinkTip)
	weaponJoint(record,joints[classic and "Right Shoulder" or "RightShoulder"],right,fade)
	weaponJoint(record,joints.RightElbow,vector(sampled.elbow,0,0),fade)
	weaponJoint(record,joints.RightWrist,wrist,fade)
	weaponJoint(record,joints[classic and "Left Shoulder" or "LeftShoulder"],left,fade*sampled.leftWeight)
	weaponJoint(record,joints.LeftElbow,vector(sampled.leftElbow,0,0),fade*sampled.leftWeight)
	local root = sampled.root * (classic and 1 or 0.55)
	weaponJoint(record,joints.RootJoint or joints.Root,root,fade,true)
	weaponJoint(record,joints.Waist,sampled.waist,fade,true)
	local chest = root + (classic and Vector3.zero or sampled.waist)
	weaponJoint(record,joints.Neck,vector(-chest.X*.35,-chest.Y*.5,-chest.Z*.4),fade,true)
	weaponJoint(record,joints[classic and "Right Hip" or "RightHip"],sampled.rightHip,fade,true)
	weaponJoint(record,joints[classic and "Left Hip" or "LeftHip"],sampled.leftHip,fade,true)
	weaponJoint(record,joints.RightKnee,vector(sampled.rightKnee,0,0),fade,true)
	weaponJoint(record,joints.LeftKnee,vector(sampled.leftKnee,0,0),fade,true)
end
local function animateToy(record, player, character, humanoid, now)
	local id = character:GetAttribute("PCToyHeld")
	if typeof(id) ~= "string" or not toyActions[id] or humanoid.Health <= 0
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true then
		record.toy = nil
		return false
	end
	if record.toy ~= id then
		record.toy = id
		record.toyAt = now
		record.jointsAt = nil
	end
	local started = player:GetAttribute("PCToyActionAt")
	local action = player:GetAttribute("PCToyAction")
	local matches = player:GetAttribute("PCToyActionItem") == id
	local elapsed = matches and typeof(started) == "number" and started == started and now - started or math.huge
	local sampled = sampleToyPose(id, action, elapsed)
	local fade = math.clamp((now-record.toyAt)/0.12,0,1)
	applyToyPose(record,bodyJoints(record,character,now),sampled,humanoid.RigType==Enum.HumanoidRigType.R6,fade)
	return true
end
local function animateDodge(record, player, character, humanoid, now)
	if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("BBRagdolled") == true
		or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("MDParticipating") == true then return false end
	local prefix
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Runner"
		and player:GetAttribute("BBStatus") == "Crossing" then prefix = "BB"
	elseif player:GetAttribute("TGParticipating") == true then prefix = "TG" end
	if not prefix then return false end
	local states = game:GetService("ReplicatedStorage")
	local state = states:FindFirstChild(prefix == "BB" and "BritishBulldogState" or "TagState")
	if not state or state:GetAttribute("Phase") ~= (prefix == "BB" and "Crossing" or "Playing") then return false end
	local started = player:GetAttribute(prefix .. "DodgeStartedAt")
	local duration = player:GetAttribute(prefix .. "DodgeDuration")
	local direction = player:GetAttribute(prefix .. "DodgeDirection")
	if typeof(started) ~= "number" or started ~= started or started <= 0 or typeof(duration) ~= "number"
		or duration ~= duration or duration < 0.15 or duration > 0.5 or typeof(direction) ~= "Vector3" then return false end
	local elapsed = now - started
	duration += 0.14
	if elapsed < 0 or elapsed >= duration then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local side = math.clamp(root.CFrame:VectorToObjectSpace(direction).X, -1, 1)
	if side ~= side then return false end
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local strength = alpha < 0.22 and math.sin(alpha / 0.22 * math.pi / 2)
		or math.cos((alpha - 0.22) / 0.78 * math.pi / 2)^2
	local joints = bodyJoints(record, character, now)
	local classic = humanoid.RigType == Enum.HumanoidRigType.R6
	local lean = vector(-9, 8 * side, -26 * side)
	weaponJoint(record, joints.RootJoint or joints.Root, lean, strength * (classic and 1 or 0.65), true)
	weaponJoint(record, joints.Waist, lean, strength * 0.35, true)
	weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-12,0,18), strength, true)
	weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(-12,0,-18), strength, true)
	return true
end


local botRecords = {}
local function animatePracticeBots(now)
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("TagState")
	local folder = workspace:FindFirstChild("TagPracticeBots")
	local playing = state and state:GetAttribute("Phase") == "Playing"
	for character, record in pairs(botRecords) do
		restore(record)
		if not playing or not folder or character.Parent ~= folder then botRecords[character] = nil end
	end
	if not playing or not folder then return end
	for _, character in ipairs(folder:GetChildren()) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.PlatformStand then continue end
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if speed < 0.1 then continue end
		local record = botRecords[character]
		if not record then record = { character = character, joints = {} } botRecords[character] = record end
		local joints = bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local swing = math.sin(now * 10) * math.min(speed / 16, 1) * 24
		weaponJoint(record, joints[classic and "Right Hip" or "RightHip"], vector(swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Hip" or "LeftHip"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Right Shoulder" or "RightShoulder"], vector(-swing,0,0), 1, true)
		weaponJoint(record, joints[classic and "Left Shoulder" or "LeftShoulder"], vector(swing,0,0), 1, true)
	end
end

local beforeAnimation = RunService.PreAnimation:Connect(function()
	for _, record in pairs(records) do restore(record) end
	for _, record in pairs(botRecords) do restore(record) end
end)
local frame = RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	animatePracticeBots(now)
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
		if not humanoid or humanoid.Health <= 0 then record.weapon = nil record.toy = nil continue end
		if animateDodge(record, player, character, humanoid, now) then continue end
		if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end
		if animateToy(record, player, character, humanoid, now) then continue end
		local untilTime = player:GetAttribute("PCEmoteUntil")
		local action = player:GetAttribute("PCEmoteAction")
		if not character or typeof(untilTime) ~= "number" or now >= untilTime or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then
			continue
		end
		bodyJoints(record, character, now)
		local classic = humanoid.RigType == Enum.HumanoidRigType.R6
		local right = record.bodyJoints[classic and "Right Shoulder" or "RightShoulder"]
		local left = record.bodyJoints[classic and "Left Shoulder" or "LeftShoulder"]
		local t = 2.4 - (untilTime - now)
		local fade = math.min(1, t / 0.18, (untilTime - now) / 0.2)
		if action == "Wave" then
			local swing = math.sin(t * 13) * 20
			pose(record, right, classic and CFrame.Angles(math.rad(-110 * fade), math.rad(swing * fade), 0) or CFrame.Angles(math.rad(20 * fade), 0, math.rad((125 + swing) * fade)))
			pose(record, record.bodyJoints.RightElbow, CFrame.Angles(math.rad(-25 * fade), 0, 0))
		elseif action == "Cheer" then
			local rise = (145 + math.sin(t * 8) * 12) * fade
			pose(record, right, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(rise)))
			pose(record, left, classic and CFrame.Angles(math.rad(-rise), 0, 0) or CFrame.Angles(math.rad(12 * fade), 0, math.rad(-rise)))
			pose(record, record.bodyJoints.Waist, CFrame.Angles(math.rad(math.sin(t * 8) * 4 * fade), 0, 0))
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
	for _, record in pairs(botRecords) do restore(record) end
	table.clear(botRecords)
end)


]====]})
for _,entry in ipairs(entries) do assert(normalize(entry.target.Source)==normalize(entry.before),"Source changed since backup: "..entry.target:GetFullName()) end
local backup=Instance.new("Folder")
backup.Name="GameplayRepairSourcesBackup20261005"
backup.Parent=game.ServerStorage
local results={}
for _,entry in ipairs(entries) do
 local capabilities=entry.target.Capabilities
 local sandboxed=entry.target.Sandboxed
 local original=entry.target:Clone()
 original.Name=entry.target:GetFullName()
 original.Parent=backup
 entry.target.Source=entry.after
 assert(entry.target.Source==entry.after,"Readback mismatch")
 assert(entry.target.Capabilities==capabilities and entry.target.Sandboxed==sandboxed,"Permissions changed")
 table.insert(results,{path=entry.target:GetFullName(),sourceMatched=true,permissionsPreserved=true})
end
return {installed=results,backup=backup:GetFullName(),playStarted=false}
