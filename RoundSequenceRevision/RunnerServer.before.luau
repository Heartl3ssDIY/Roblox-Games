local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerData = require(
	game.ServerScriptService:WaitForChild(
		"PlayerData"
	)
)

local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
if game.PlaceId ~= config.PlaceId then return end

local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local course = workspace:WaitForChild(" Course -  round 1")
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
local secondLifeTokens = {}
local expectedPlayers = 1

local roundStartedAt = 0
local roundWinner
local finishPlace = 0

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
	local multiplier = 1 - data.gravitySign
	data.gravityForce.Force = Vector3.new(0,
		root.AssemblyMass * config.Gravity * multiplier, 0)
	if data.orientation then
		data.orientation.CFrame = runnerCFrame(Vector3.zero, gravityUp(data)).Rotation
	end
end

local function setGravity(player, sign, instant)
	local data = players[player]
	if not data or not data.root then return end
	data.gravitySign = sign
	player:SetAttribute("GravitySign", sign)
	updateGravity(data)

	if instant then
		local root = data.root
		root.CFrame = runnerCFrame(root.Position, gravityUp(data))
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X,
			-sign * config.FlipVelocity, 0)
	end
end

local function setSpeed(data, multiplier)
	data.speedMultiplier = multiplier
	if data.velocity then
		data.velocity.LineVelocity = config.RunSpeed * multiplier
	end
	if data.runTrack then
		data.runTrack:AdjustSpeed(config.RunSpeed * multiplier / 16)
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
		if part:IsA("BasePart") and part.Name ~= "RunnerPlayerCollider" then
			part.CanCollide = false
		end
	end

	local collider = Instance.new("Part")
	collider.Name = "RunnerCollider"
	collider.Size = Vector3.new(2, 6, 1.5)
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
	player:SetAttribute(config.SecondLifeAttribute, 0)
	data.ready = false
	data.speedMultiplier = 1
	data.recovering = false
	data.invulnerableUntil = 0
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
	data.root = character:WaitForChild("HumanoidRootPart", 15)
	if not data.humanoid or not data.root then return end

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

local function setSecondLifeTokenVisible(state, visible)
	for part, original in state.parts do
		if part.Parent then
			part.Transparency = visible and original.transparency or 1
			part.CanCollide = visible and original.canCollide or false
			part.CanTouch = visible
		end
	end
end

local function registerSecondLifeToken(token)
	if secondLifeTokens[token] then return end
	local state = {
		available = true,
		parts = {},
	}
	if token:IsA("BasePart") then
		state.parts[token] = {
			transparency = token.Transparency,
			canCollide = token.CanCollide,
		}
	end
	for _, part in token:GetDescendants() do
		if part:IsA("BasePart") then
			state.parts[part] = {
				transparency = part.Transparency,
				canCollide = part.CanCollide,
			}
		end
	end
	if not next(state.parts) then return end
	secondLifeTokens[token] = state

	for part in state.parts do
		part.CanTouch = true
		part.Touched:Connect(function(hit)
			if not state.available then return end
			local player = playerFromHit(hit)
			local data = player and players[player]
			if not data or data.status ~= "Running" then return end

			local lives = math.max(math.floor(tonumber(
				player:GetAttribute(config.SecondLifeAttribute)
			) or 0), 0)
			if lives >= config.MaxSecondLives then return end
			state.available = false
			player:SetAttribute(config.SecondLifeAttribute, lives + 1)
			setSecondLifeTokenVisible(state, false)
			event:FireClient(player, "SecondLife", { lives = lives + 1 })
		end)
	end
end

local function resetSecondLifeTokens()
	for _, state in secondLifeTokens do
		state.available = true
		setSecondLifeTokenVisible(state, true)
	end
end

local function broadcastState(extra)
	local packet = extra or {}
	packet.phase = roundPhase
	event:FireAllClients("State", packet)
end

local function resetRound()
	countdownVersion += 1
	roundPhase = "Waiting"

	roundStartedAt = 0
	roundWinner = nil
	finishPlace = 0
	resetBoost()
	resetSecondLifeTokens()
	for player, data in players do
		if data.spawn and data.root and data.root.Parent then
			placeAtSpawn(player)
		end
	end
	broadcastState()
end

local function startRace(version)
	if version ~= countdownVersion then return end
	local ready = allReady()
	if not ready then return end
	roundPhase = "Running"

	roundStartedAt = workspace:GetServerTimeNow()
	roundWinner = nil
	finishPlace = 0
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

local function canRecover(player)
	if config.TutorialRecovery then return true, false end
	if player:GetAttribute(config.RepeaterAttribute) == true then
		return true, false
	end

	local lives = math.max(math.floor(tonumber(
		player:GetAttribute(config.SecondLifeAttribute)
	) or 0), 0)
	if lives > 0 then
		player:SetAttribute(config.SecondLifeAttribute, lives - 1)
		return true, true
	end
	return false, false
end

local function recoverPlayer(player, reason)
	local data = players[player]
	if not data or data.recovering or data.status ~= "Running" then return end
	if workspace:GetServerTimeNow() < (data.invulnerableUntil or 0) then return end

	local allowed, usedSecondLife = canRecover(player)
	if not allowed then
		setStatus(player, "Out")
		removeRunnerForces(data)
		data.root.Anchored = true
		event:FireClient(player, "Out", { reason = reason })
		return
	end

	data.recovering = true
	event:FireClient(player, "Recover", {
		reason = reason,
		usedSecondLife = usedSecondLife,
		protectionSeconds = config.RecoveryProtectionSeconds,
	})

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
	setGravity(player, safe.sign, false)

	task.delay(config.RecoveryFreezeTime, function()
		if not player.Parent or not data.root or not data.root.Parent then return end
		data.root.Anchored = false
		setSpeed(data, data.speedMultiplier > 1 and data.speedMultiplier or 1)
		data.recovering = false
		data.invulnerableUntil = workspace:GetServerTimeNow()
			+ config.RecoveryProtectionSeconds
	end)
end

local function finishPlayer(player)
	local data = players[player]
	if not data or data.status ~= "Running" then return end

	setStatus(player, "Finished")
	removeRunnerForces(data)
	data.root.Anchored = true

	finishPlace += 1

	local finishTime =
		math.max(
			workspace:GetServerTimeNow()
			- roundStartedAt,
			0
		)

	local isWinner = roundWinner == nil
	local cashReward = isWinner and 250 or 100
	local result

	if isWinner then
		roundWinner = player
		result =
			PlayerData.AwardWin(
				player,
				finishTime,
				cashReward
			)
	else
		PlayerData.AddCash(
			player,
			cashReward
		)

		task.spawn(
			PlayerData.Save,
			player
		)

		local profile = PlayerData.Get(player)
		result = {
			Cash = profile and profile.Cash or 0,
			Trophies = profile and profile.Trophies or 0,
			Wins = profile and profile.Wins or 0,
			Reward = cashReward,
			TimeMs = math.floor(
				finishTime * 1000 + 0.5
			),
		}
	end

	result.Place = finishPlace
	result.IsWinner = isWinner

	event:FireClient(
		player,
		"Finished",
		result
	)

	broadcastState()

	for _, otherData in players do
		if otherData.status == "Running" then
			return
		end
	end

	task.delay(
		config.RoundResetDelay,
		function()
			if roundPhase == "Running" then
				resetRound()
			end
		end
	)
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
		data.lastFlip = now
		setGravity(player, -data.gravitySign, true)
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
		invulnerableUntil = 0,
		safePoints = {},
	}
	players[player] = data
	player:SetAttribute("RunnerStatus", "Loading")
	player:SetAttribute("RunnerReady", false)
	player:SetAttribute("RunnerSpeedMultiplier", 1)
	if player:GetAttribute(config.RepeaterAttribute) == nil then
		player:SetAttribute(config.RepeaterAttribute, false)
	end
	player:SetAttribute(config.SecondLifeAttribute, 0)
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
	end
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

for _, object in course:GetDescendants() do
	if object:IsA("Model") and object.Name == "Red_Spiked_Wheel" then
		table.insert(spikeModels, object)
		spikePivots[object] = object:GetPivot()
		for _, part in object:GetDescendants() do
			if part:IsA("BasePart") then
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
	for player, data in players do
		if data.root and data.root.Parent and data.gravityForce then
			updateGravity(data)
		end
		if data.status == "Running" and data.root and data.root.Parent then
			local velocity = data.root.AssemblyLinearVelocity
			if velocity.X > 2 then
				data.root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			end
		end
	end
	if checkpointClock < 0.15 then return end
	checkpointClock = 0

	for _, data in players do
		if data.status == "Running" and data.root and not data.recovering then
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
						local safePosition = Vector3.new(
							data.root.Position.X,
							data.root.Position.Y,
							data.laneZ
						)
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

