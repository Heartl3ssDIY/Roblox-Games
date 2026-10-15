local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")

local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
if game.PlaceId ~= config.PlaceId then return end

local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local course = workspace:WaitForChild(config.CourseName)
local spawnFolder = course:WaitForChild("Start"):WaitForChild("Spawn locs")
local boundsFolder = workspace:WaitForChild("out of bounds")
local endZone = course:WaitForChild("Green_EndZone")
local boostFolder = course:WaitForChild("Speed boosts")
local forward = Vector3.new(-1, 0, 0)

local players = {}
local roundPhase = "Waiting"
local countdownVersion = 0
local spikeModels = {}
local spikePivots = {}
local boostParts = {}
local boostOriginal = {}
local boostAvailable = true
local expectedPlayers = 1
local resetVersion = 0
local handleCharacterDeath
local progressStore = config.TutorialRecovery
	and DataStoreService:GetDataStore(config.ProgressStoreName)

local spawns = {}
for _, object in spawnFolder:GetChildren() do
	if object:IsA("SpawnLocation") then
		table.insert(spawns, object)
	end
end
table.sort(spawns, function(first, second)
	return tonumber(first.Name:match("%d+")) < tonumber(second.Name:match("%d+"))
end)

local function playerFromHit(hit)
	local current = hit
	while current and current ~= workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then return player end
		end
		current = current.Parent
	end
end

local function setStatus(player, status)
	local data = players[player]
	if not data then return end
	data.status = status
	player:SetAttribute("RunnerStatus", status)
end

local function removeRunnerForces(data)
	for _, object in { data.velocity, data.gravityForce, data.orientation,
		data.attachment, data.collider } do
		if object then object:Destroy() end
	end
	data.velocity = nil
	data.gravityForce = nil
	data.orientation = nil
	data.attachment = nil
	data.collider = nil
	if data.runTrack then
		data.runTrack:Stop(0.15)
		data.runTrack:Destroy()
		data.runTrack = nil
	end
end

local function gravityUp(data)
	return Vector3.new(0, data.gravitySign, 0)
end

local function runnerCFrame(position, up)
	return CFrame.lookAt(position, position + forward, up)
end

local function updateGravity(data)
	local root = data.root
	if not root or not data.gravityForce then return end
	local mass = 0
	for _, part in data.character:GetDescendants() do
		if part:IsA("BasePart") and part ~= data.collider then
			mass += part:GetMass()
		end
	end
	local upwardAcceleration = workspace.Gravity - data.gravitySign * config.Gravity
	data.gravityForce.Force = Vector3.new(0, mass * upwardAcceleration, 0)
	if data.orientation then
		data.orientation.CFrame = runnerCFrame(Vector3.zero, gravityUp(data)).Rotation
	end
end

local function setGravity(player, sign)
	local data = players[player]
	if not data or not data.root then return end
	data.gravitySign = sign
	player:SetAttribute("GravitySign", sign)
	updateGravity(data)
end

local function setSpeed(data, multiplier)
	data.speedMultiplier = multiplier
	local runSpeed = data.runSpeed or config.RunSpeed
	if data.velocity then
		data.velocity.LineVelocity = runSpeed * multiplier
	end
	if data.runTrack then
		data.runTrack:AdjustSpeed(runSpeed * multiplier / 16)
	end
	if data.player then
		data.player:SetAttribute("RunnerSpeedMultiplier", multiplier)
	end
end

local function addRunnerForces(data)
	removeRunnerForces(data)
	local root = data.root
	if not root then return end
	for _, part in data.character:GetDescendants() do
		if part:IsA("BasePart") then part.CanCollide = false end
	end

	local collider = Instance.new("Part")
	collider.Name = "RunnerCollider"
	collider.Size = Vector3.new(2, 5, 1.5)
	collider.CFrame = root.CFrame
	collider.Transparency = 1
	collider.CanCollide = true
	collider.CanTouch = true
	collider.CanQuery = false
	collider.Massless = true
	collider.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	collider.Parent = data.character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = collider
	weld.Parent = collider

	local attachment = Instance.new("Attachment")
	attachment.Name = "RunnerAttachment"
	attachment.Parent = root

	local gravityForce = Instance.new("VectorForce")
	gravityForce.Name = "RunnerGravity"
	gravityForce.Attachment0 = attachment
	gravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
	gravityForce.ApplyAtCenterOfMass = true
	gravityForce.Parent = root

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "RunnerOrientation"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.RigidityEnabled = false
	orientation.MaxTorque = 100000
	orientation.Responsiveness = 100
	orientation.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "RunnerForwardSpeed"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	velocity.LineDirection = forward
	velocity.LineVelocity = 0
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = 100000
	velocity.Parent = root

	data.attachment = attachment
	data.collider = collider
	data.gravityForce = gravityForce
	data.orientation = orientation
	data.velocity = velocity
	updateGravity(data)
end

local function playRunAnimation(data)
	local humanoid = data.humanoid
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = config.RunAnimationId
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	track:Play(0.15)
	data.runTrack = track
	setSpeed(data, data.speedMultiplier or 1)
end

local function spawnCFrame(spawn)
	local up = spawn.CFrame.UpVector.Y < 0 and -Vector3.yAxis or Vector3.yAxis
	return runnerCFrame(spawn.Position + up * 3.2, up), up.Y
end

local function placeAtSpawn(player)
	local data = players[player]
	if not data or not data.root or not data.spawn then return end
	local cframe, sign = spawnCFrame(data.spawn)
	data.gravitySign = sign
	data.laneZ = data.spawn.Position.Z
	player:SetAttribute("RunnerLaneZ", data.laneZ)
	data.safePoints = { { cframe = cframe, x = cframe.Position.X, sign = sign } }
	data.root.CFrame = cframe
	data.root.AssemblyLinearVelocity = Vector3.zero
	data.root.AssemblyAngularVelocity = Vector3.zero
	data.root.Anchored = true
	data.humanoid.AutoRotate = false
	data.humanoid.JumpPower = 0
	data.humanoid.JumpHeight = 0
	data.humanoid.PlatformStand = true
	player:SetAttribute("GravitySign", sign)
	player:SetAttribute("RunnerReady", false)
	player:SetAttribute("RunnerSpeedMultiplier", 1)
	data.ready = false
	data.speedMultiplier = 1
	data.runSpeed = config.RunSpeed
	setStatus(player, "Waiting")
	addRunnerForces(data)
	data.velocity.LineVelocity = 0
end

local function assignSpawn(player)
	local data = players[player]
	if not data or data.spawn then return end
	local used = {}
	for other, otherData in players do
		if other ~= player and otherData.spawn then used[otherData.spawn] = true end
	end
	for index, spawn in spawns do
		if not used[spawn] then
			data.spawn = spawn
			data.spawnIndex = index
			player:SetAttribute("RunnerSpawnIndex", index)
			return
		end
	end
	setStatus(player, "Spectating")
end

local function setupCharacter(player, character)
	local data = players[player]
	if not data then return end
	data.character = character
	data.humanoid = character:WaitForChild("Humanoid", 15)
	if not data.humanoid then return end
	data.humanoid.RequiresNeck = false
	data.humanoid.Died:Once(function()
		if handleCharacterDeath then handleCharacterDeath(player, character) end
	end)

	local appearanceDeadline = os.clock() + 10
	while player.Character == character
		and not character:FindFirstChildWhichIsA("Motor6D", true)
		and not character:FindFirstChildWhichIsA("AnimationConstraint", true)
		and os.clock() < appearanceDeadline do
		task.wait(0.1)
	end
	if player.Character ~= character then return end

	data.root = character:WaitForChild("HumanoidRootPart", 5)
	if not data.root then return end

	if player:GetAttribute("GBloxCourseReady") then
		assignSpawn(player)
		if data.spawn then
			if roundPhase == "Running" and data.status == "Running"
				and data.safePoints[1] then
				local safe = data.safePoints[#data.safePoints]
				data.gravitySign = safe.sign
				data.root.CFrame = safe.cframe
				data.root.AssemblyLinearVelocity = Vector3.zero
				data.root.Anchored = false
				data.humanoid.AutoRotate = false
				data.humanoid.PlatformStand = true
				addRunnerForces(data)
				setSpeed(data, data.speedMultiplier or 1)
				playRunAnimation(data)
			else
				placeAtSpawn(player)
			end
		end
	end
end

local function allReady()
	local count = 0
	for player, data in players do
		if player:GetAttribute("GBloxCourseReady") and data.spawn then
			count += 1
			if not data.ready then return false, count end
		end
	end
	return count >= expectedPlayers, count
end

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude

local function canFlipGravity(data)
	if not data.character or not data.root or data.root.Anchored then
		return data.status == "Waiting"
	end
	groundRay.FilterDescendantsInstances = { data.character }
	local direction = Vector3.new(0,
		-data.gravitySign * config.GroundCheckDistance, 0)
	local hit = workspace:Raycast(data.root.Position, direction, groundRay)
	return hit ~= nil and hit.Instance.CanCollide
		and not hit.Instance:IsDescendantOf(boundsFolder)
end

local function resetBoost()
	boostAvailable = true
	for part, properties in boostOriginal do
		if part.Parent then
			part.Transparency = properties.transparency
			part.CanCollide = properties.canCollide
			part.CanTouch = properties.canTouch
		end
	end
end

local function broadcastState(extra)
	local packet = extra or {}
	packet.phase = roundPhase
	event:FireAllClients("State", packet)
end

local function resetRound()
	resetVersion += 1
	countdownVersion += 1
	roundPhase = "Waiting"
	resetBoost()
	for player, data in players do
		if data.spawn and data.root and data.root.Parent
			and data.humanoid and data.humanoid.Health > 0 then
			placeAtSpawn(player)
		elseif data.spawn and player.Parent then
			player:SetAttribute("RunnerResetCharacter",
				(player:GetAttribute("RunnerResetCharacter") or 0) + 1)
		end
	end
	broadcastState()
end

local function scheduleRoundReset()
	if roundPhase ~= "Running" then return end
	for _, data in players do
		if data.status == "Running" then return end
	end

	resetVersion += 1
	local version = resetVersion
	task.delay(config.RoundResetDelay, function()
		if roundPhase == "Running" and version == resetVersion then
			resetRound()
		end
	end)
end

local function startRace(version)
	if version ~= countdownVersion then return end
	local ready = allReady()
	if not ready then return end
	roundPhase = "Running"
	for player, data in players do
		if data.ready and data.root and data.root.Parent then
			setStatus(player, "Running")
			data.root.Anchored = false
			setSpeed(data, 1)
			playRunAnimation(data)
		end
	end
	broadcastState()
end

local function beginCountdown()
	if roundPhase ~= "Waiting" then return end
	local ready = allReady()
	if not ready then return end
	roundPhase = "Countdown"
	countdownVersion += 1
	local version = countdownVersion
	task.spawn(function()
		for number = config.Countdown, 1, -1 do
			if version ~= countdownVersion then return end
			local stillReady = allReady()
			if not stillReady then
				roundPhase = "Waiting"
				broadcastState()
				return
			end
			broadcastState({ number = number })
			task.wait(1)
		end
		broadcastState({ number = "GO!" })
		task.wait(0.35)
		startRace(version)
	end)
end

local function recoverPlayer(player, reason)
	local data = players[player]
	if not data or data.recovering or data.status ~= "Running" then return end
	if not config.TutorialRecovery then
		setStatus(player, "Out")
		removeRunnerForces(data)
		data.root.Anchored = true
		event:FireClient(player, "Out", { reason = reason })
		broadcastState()
		scheduleRoundReset()
		return
	end

	data.recovering = true
	event:FireClient(player, "Recover", { reason = reason })
	local currentX = data.root.Position.X
	local safe = data.safePoints[1]
	for index = #data.safePoints, 1, -1 do
		local point = data.safePoints[index]
		if point.x >= currentX + config.RecoveryDistance then
			safe = point
			break
		end
	end

	data.root.Anchored = true
	if data.velocity then data.velocity.LineVelocity = 0 end
	if data.runTrack then data.runTrack:AdjustSpeed(0) end
	data.gravitySign = safe.sign
	data.root.CFrame = safe.cframe
	data.root.AssemblyLinearVelocity = Vector3.zero
	data.root.AssemblyAngularVelocity = Vector3.zero
	setGravity(player, safe.sign)
	task.delay(0.55, function()
		if not player.Parent or not data.root or not data.root.Parent then return end
		data.root.Anchored = false
		setSpeed(data, data.speedMultiplier > 1 and data.speedMultiplier or 1)
		data.recovering = false
	end)
end

handleCharacterDeath = function(player, character)
	local data = players[player]
	if not data or data.character ~= character or data.status ~= "Running" then return end
	if config.TutorialRecovery then return end
	setStatus(player, "Out")
	removeRunnerForces(data)
	event:FireClient(player, "Out", { reason = "Fall" })
	broadcastState()
	scheduleRoundReset()
end

local function saveTutorialCompletion(player)
	if not progressStore then return true end
	if RunService:IsStudio() then
		player:SetAttribute("TutorialCompleted", true)
		return true
	end
	for attempt = 1, 3 do
		local success = pcall(function()
			progressStore:UpdateAsync("player_" .. player.UserId, function(progress)
				progress = type(progress) == "table" and progress or {}
				progress.TutorialCompleted = true
				return progress
			end)
		end)
		if success then
			player:SetAttribute("TutorialCompleted", true)
			return true
		end
		if attempt < 3 then task.wait(attempt) end
	end
	warn("[G-Blox tutorial] Could not save completion for " .. player.Name)
	return false
end

local function finishPlayer(player)
	local data = players[player]
	if not data or data.status ~= "Running" then return end
	setStatus(player, "Finished")
	removeRunnerForces(data)
	data.root.Anchored = true
	event:FireClient(player, "Finished")
	broadcastState()

	if config.TutorialRecovery and config.MainPlaceId then
		task.spawn(function()
			if not saveTutorialCompletion(player) then
				event:FireClient(player, "SaveFailed")
				task.delay(config.RoundResetDelay, function()
					if player.Parent and data.status == "Finished" then resetRound() end
				end)
				return
			end
			task.wait(1.25)
			if not player.Parent or RunService:IsStudio() then return end
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ TutorialJustCompleted = true })
			local success, message = pcall(function()
				TeleportService:TeleportAsync(config.MainPlaceId, { player }, options)
			end)
			if not success then
				warn("[G-Blox tutorial] Could not return " .. player.Name
					.. " to the lobby: " .. tostring(message))
				event:FireClient(player, "ReturnFailed")
			end
		end)
	end
	scheduleRoundReset()
end

local function giveBoost(player)
	local data = players[player]
	if not boostAvailable or not data or data.status ~= "Running" then return end
	boostAvailable = false
	for _, part in boostParts do
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
	end
	data.boostVersion = (data.boostVersion or 0) + 1
	local version = data.boostVersion
	setSpeed(data, config.BoostMultiplier)
	event:FireClient(player, "Boost", { seconds = config.BoostSeconds })
	task.delay(config.BoostSeconds, function()
		if players[player] == data and data.boostVersion == version then
			setSpeed(data, 1)
		end
	end)
end

event.OnServerEvent:Connect(function(player, action)
	local data = players[player]
	if not data then return end
	if action == "Ready" and roundPhase == "Waiting"
		and player:GetAttribute("GBloxCourseReady") and data.spawn then
		data.ready = not data.ready
		player:SetAttribute("RunnerReady", data.ready)
		event:FireAllClients("ReadyChanged", {
			userId = player.UserId,
			ready = data.ready,
		})
		if data.ready then beginCountdown() end
	elseif action == "Flip" and (data.status == "Waiting" or data.status == "Running") then
		local now = os.clock()
		if now - (data.lastFlip or 0) < config.FlipCooldown then return end
		if not canFlipGravity(data) then return end
		data.lastFlip = now
		setGravity(player, -data.gravitySign)
	end
end)

local function addPlayer(player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if teleportData and tonumber(teleportData.HumanCount) then
		expectedPlayers = math.clamp(math.floor(teleportData.HumanCount), 1, config.MaxPlayers)
	end

	local data = {
		player = player,
		status = "Loading",
		gravitySign = -1,
		ready = false,
		speedMultiplier = 1,
		safePoints = {},
	}
	players[player] = data
	player:SetAttribute("RunnerStatus", "Loading")
	player:SetAttribute("RunnerReady", false)
	player:SetAttribute("RunnerSpeedMultiplier", 1)
	player:SetAttribute("RunnerResetCharacter", 0)
	player:GetAttributeChangedSignal("GBloxCourseReady"):Connect(function()
		if player:GetAttribute("GBloxCourseReady") then
			assignSpawn(player)
			if player.Character then
				if data.character == player.Character and data.root then
					if data.spawn then placeAtSpawn(player) end
				else
					setupCharacter(player, player.Character)
				end
			end
			broadcastState()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then task.spawn(setupCharacter, player, player.Character) end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	players[player] = nil
	countdownVersion += 1
	if roundPhase == "Countdown" then
		roundPhase = "Waiting"
		broadcastState()
	elseif roundPhase == "Running" then
		scheduleRoundReset()
	end
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

for _, object in course:GetDescendants() do
	if object:IsA("Model") and object.Name == "Red_Spiked_Wheel" then
		table.insert(spikeModels, object)
		spikePivots[object] = object:GetPivot()
		for _, part in object:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = true
				part.Touched:Connect(function(hit)
					local player = playerFromHit(hit)
					if player then recoverPlayer(player, "Spike") end
				end)
			end
		end
	end
end

for _, part in boostFolder:GetDescendants() do
	if part:IsA("BasePart") then
		table.insert(boostParts, part)
		boostOriginal[part] = {
			transparency = part.Transparency,
			canCollide = part.CanCollide,
			canTouch = part.CanTouch,
		}
		part.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then giveBoost(player) end
		end)
	end
end

for _, part in endZone:GetDescendants() do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then finishPlayer(player) end
		end)
	end
end

for _, part in boundsFolder:GetChildren() do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then recoverPlayer(player, "Fall") end
		end)
	end
end

local raycast = RaycastParams.new()
raycast.FilterType = Enum.RaycastFilterType.Exclude
local checkpointClock = 0
local spinAngle = 0

RunService.Heartbeat:Connect(function(deltaTime)
	spinAngle += math.rad(config.SpikeDegreesPerSecond) * deltaTime
	for _, model in spikeModels do
		if model.Parent then
			local original = spikePivots[model]
			local center = original.Position
			local rotation = CFrame.fromAxisAngle(Vector3.zAxis, spinAngle)
			model:PivotTo(CFrame.new(center) * rotation * (CFrame.new(center):Inverse() * original))
		end
	end

	checkpointClock += deltaTime
	if checkpointClock < 0.15 then return end
	local speedStep = checkpointClock
	checkpointClock = 0

	for _, data in players do
		if data.status == "Running" and data.root and not data.recovering then
			if math.abs(data.root.AssemblyLinearVelocity.X) < config.StuckSpeed then
				data.stuckTime = (data.stuckTime or 0) + speedStep
			else
				data.stuckTime = 0
			end
			if data.stuckTime >= config.StuckSeconds then
				data.stuckTime = 0
				recoverPlayer(data.player, "Obstacle")
				continue
			end

			data.runSpeed = math.min(config.MaxRunSpeed,
				(data.runSpeed or config.RunSpeed) + config.RunAcceleration * speedStep)
			if data.velocity then
				data.velocity.LineVelocity = data.runSpeed * data.speedMultiplier
			end
			if data.runTrack then
				data.runTrack:AdjustSpeed(data.runSpeed * data.speedMultiplier / 16)
			end

			raycast.FilterDescendantsInstances = { data.character }
			local direction = Vector3.new(0, -data.gravitySign * 5.5, 0)
			local hit = workspace:Raycast(data.root.Position, direction, raycast)
			if hit and not hit.Instance:IsDescendantOf(boundsFolder) then
				local onSpike = false
				for _, model in spikeModels do
					if hit.Instance:IsDescendantOf(model) then onSpike = true break end
				end
				if not onSpike then
					local previous = data.safePoints[#data.safePoints]
					if not previous or previous.x - data.root.Position.X >= 2 then
						local safePosition = Vector3.new(data.root.Position.X,
							data.root.Position.Y, data.laneZ)
						table.insert(data.safePoints, {
							cframe = runnerCFrame(safePosition, gravityUp(data)),
							x = data.root.Position.X,
							sign = data.gravitySign,
						})
						if #data.safePoints > 80 then table.remove(data.safePoints, 1) end
					end
				end
			end
		end
	end
end)
