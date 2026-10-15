local GroundCheck=require(game.ReplicatedStorage:WaitForChild("RunnerGroundCheck"))
local Recovery=require(game.ServerScriptService:WaitForChild("RunnerRecovery"))
local IdleRules=require(game.ServerScriptService:WaitForChild("RunnerIdleRules"))
local PlayerData = require(game.ServerScriptService:WaitForChild("PlayerData"))
local PetCatalog = require(game.ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local matchId = game:GetService("HttpService"):GenerateGUID(false)
local matchResults = {}
local matchPaid = false
local finalRanking
local RewardRules=require(game.ReplicatedStorage:WaitForChild("GBloxMatchRewardRules"))
local Podium=require(game.ServerScriptService:WaitForChild("GBloxPodium"))
local function payMatch()
 if matchPaid then return finalRanking end
 matchPaid=true
 finalRanking={}
 for player,result in matchResults do
  if player.Parent and result.rounds==5 then table.insert(finalRanking,{player=player,result=result}) end
 end
 RewardRules.Rank(finalRanking)
 for place,entry in finalRanking do
  local p,r=entry.player,entry.result
  local petList={}
  for _,id in PlayerData.GetEquippedPets(p) do
   local pet=PetCatalog.GetPet(id)
   if pet then table.insert(petList,{Id=id,CashMultiplier=pet.CashMultiplier,TrophyMultiplier=pet.TrophyMultiplier}) end
  end
  local breakdown=RewardRules.Build(place,#finalRanking,r,nil,nil,petList,PlayerData.GetCashMultiplier(p),PlayerData.GetTrophyMultiplier(p))
  p:SetAttribute("MatchFinalPlace",place)
  p:SetAttribute("MatchRewardRecorded",false)
  Podium.UpdateReward(p,breakdown,"Saving")
  task.spawn(function()
   local deadline=os.clock()+30
   while not PlayerData.Get(p) and p.Parent and os.clock()<deadline do task.wait(.2) end
   if not p.Parent then return end
   if r.finishes==5 then PlayerData.RecordTime(p,r.time) end
   local saved,recorded=PlayerData.AwardMatch(p,matchId,place,breakdown.cash,breakdown.trophies)
   p:SetAttribute("MatchRewardRecorded",recorded==true)
   Podium.UpdateReward(p,breakdown,saved and "Saved" or recorded and "SavePending" or "Unavailable")
   if not saved then warn("[MatchRewards] Save pending",p.UserId,matchId) end
  end)
 end
 return finalRanking
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CourseRegistry = require(game.ServerScriptService:WaitForChild("CourseRegistry"))
local readyGate = require(game.ServerScriptService:WaitForChild("RoundReadyGate")).new()
local RankingEmotes = require(game.ServerScriptService:WaitForChild("RankingEmotes"))

local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
local Motion=require(ReplicatedStorage:WaitForChild("RunnerMotion"))
local physics=game:GetService("PhysicsService")
pcall(function() physics:RegisterCollisionGroup("RunnerVisual") end)
for _,group in physics:GetRegisteredCollisionGroups() do
 physics:CollisionGroupSetCollidable("RunnerVisual",group.name,false)
end
if game.PlaceId ~= config.PlaceId then return end

local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local RaceVFX=require(game.ServerScriptService:WaitForChild("GBloxRaceVFXServer"))
local function showRaceVFX(player,data,kind,version,terminal)
 local ok,err=pcall(RaceVFX.Emit,player,data,kind,version,terminal)
 if not ok then warn("[RaceVFX]",err) end
end
local courseNumber = 1
local courseVersion = 1
local descriptor, courseError = CourseRegistry.Resolve(workspace, courseNumber, config.MaxPlayers)
assert(descriptor, courseError)
local course, spawnFolder = descriptor.course, descriptor.spawnFolder
local boundsFolder, endZone = descriptor.bounds, descriptor.finish
local boostFolder = descriptor.boosts
local courseConnections = {}
local bindCourse
local recoverPlayer
local checkRoundComplete
local beginCountdown
local checkIntermissionReady
local finishDeadline
local maxRounds = config.MatchRounds or 5
CourseRegistry.ActivateSpawns(workspace, descriptor)
workspace:SetAttribute("RunnerCourseNumber", courseNumber)
workspace:SetAttribute("RunnerCourseCenter", descriptor.center)
-- The side view is relative to the active course, never an old world-space marker.
workspace:SetAttribute("RunnerCameraOffset", config.CameraOffset or Vector3.new(-4.4,2.53,-94.86))
local forward = Vector3.new(-1, 0, 0)

local players = {}
local roundPhase = "Waiting"
local spectating=require(game.ServerScriptService:WaitForChild("RunnerSpectating")).new({
 Runners=players,Phase=function() return roundPhase end,RoundKey=function() return courseVersion end,
})
local countdownVersion = 0
local spikeModels = {}
local spikePivots = {}
local spikeGeometry = {}
local boostParts = {}
local boostOriginal = {}
local boostAvailable = true
local secondLifeTokens = {}
local expectedPlayers = 1
local receivedLobbyParty = false
local arrivalDeadline
local ArrivalRules=require(game.ServerScriptService:WaitForChild("RunnerArrivalRules"))

local roundStartedAt = 0
local roundWinner
local finishPlace = 0
local lastRankingPacket
RankingEmotes.SetAnimationReadyHandler(function(player,key,id)
 local data=players[player]
 if not data or data.leavingLobby or not player.Parent or roundPhase~="Intermission"
  or not lastRankingPacket or lastRankingPacket.courseVersion~=courseVersion
  or RankingEmotes.Selected(player)~=key then return end
 for _,row in lastRankingPacket.rows do
  if row.userId==player.UserId and row.emoteKey==key then
   row.emoteAnimationId=id
   event:FireAllClients("RankingEmoteChanged",{
    courseVersion=courseVersion,userId=player.UserId,key=key,animationId=id,
   })
   return
  end
 end
end)

local spawns = descriptor.spawns

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
 if status~="Running" then data.idleWatch=nil data.idleRecoveryUntil=nil end
 if status=="Loading" or status=="Running" then player:SetAttribute("RunnerOutReason",nil) end
	if status == "Out" or status == "Finished" or status == "Spectating" then
		data.secondLifeCourseVersion = nil
		player:SetAttribute(config.SecondLifeAttribute, 0)
	end
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
	-- Anchored assemblies have infinite mass; never feed infinity/NaN into a force.
	if root.Anchored then data.gravityForce.Force = Vector3.zero return end
	data.gravityForce.Force = Vector3.new(0,
		root.AssemblyMass * (workspace.Gravity-data.gravitySign*config.Gravity), 0)
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


local setSpeed
local abilityRemote=ReplicatedStorage:WaitForChild("GBloxAbilityEvent")
local abilityPractice=false

local abilityService=require(game.ServerScriptService:WaitForChild("GBloxGravitySwitch")).new({
 Runners=players,Phase=function() return roundPhase end,Now=function() return workspace:GetServerTimeNow() end,
 Practice=abilityPractice,Course=function() return course end,
 RoundKey=function() return courseVersion end,
 BoostMultiplier=config.BoostMultiplier,BoostSeconds=config.BoostSeconds,
 SetSpeed=function(data,multiplier) setSpeed(data,multiplier) end,
 Reserve=function(player,id)
  return PlayerData.ReserveAbilityGame(player,matchId,id)
 end,
 Flip=function(other)
  local data=players[other]
  local revision=(other:GetAttribute("RunnerAbilityRevision") or 0)+1
  other:SetAttribute("RunnerAbilityRevision",revision)
  data.lastAcceptedGroundTime=workspace:GetServerTimeNow()
  setGravity(other,-data.gravitySign,true)
  event:FireClient(other,"AbilityFlip",{sign=data.gravitySign,revision=revision,character=data.character,courseVersion=courseVersion})
 end,
 OnUsed=function(player) if matchResults[player] then matchResults[player].usedAbility=true end end,
 Announce=function(message) abilityRemote:FireAllClients("Announcement",message) end,
})
RunService.Heartbeat:Connect(function()
 abilityService.Step()
end)
local lastAbilityRequest={}
abilityRemote.OnServerEvent:Connect(function(player,action)
 if action~="Activate" then return end
 local now=os.clock()
 if now-(lastAbilityRequest[player] or -math.huge)<.15 then return end
 lastAbilityRequest[player]=now
 local ok,message,untilTime=abilityService.Activate(player)
 abilityRemote:FireClient(player,"Result",{ok=ok,message=message,cooldownUntil=untilTime})
end)
Players.PlayerRemoving:Connect(function(player)
 abilityService.Remove(player) lastAbilityRequest[player]=nil 
end)


setSpeed=function(data,multiplier)
 if (data.superUntil or 0)>workspace:GetServerTimeNow() then multiplier=math.max(multiplier,config.BoostMultiplier*2) end
 data.speedMultiplier=multiplier
 local speed=Motion.Speed(data.player and data.player:GetAttribute("RunnerRaceStartedAt"),multiplier)
 -- The owning client is the only continuous writer of movement velocity.
 if data.velocity and data.root and data.root.Anchored then data.velocity.LineVelocity=0 end
 if data.runTrack then data.runTrack:AdjustSpeed(speed/16) end
 if data.player then data.player:SetAttribute("RunnerSpeedMultiplier",multiplier) end
end

local function addRunnerForces(data)
	removeRunnerForces(data)
	local root = data.root
	if not root then return end
	for _, part in data.character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "RunnerPlayerCollider" then
			part.CanCollide = false
            part.CollisionGroup = "RunnerVisual"
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
	player:SetAttribute("RunnerCourseNumber", courseNumber)
	player:SetAttribute("RunnerCourseCenter", descriptor.center)
	player:SetAttribute("RunnerSpawnPosition", cframe.Position)
	player.RespawnLocation = data.spawn
	data.courseVersion = courseVersion
	data.courseStreamReady = nil
	data.spawnRevision = (data.spawnRevision or 0) + 1
	player:SetAttribute("RunnerStreamReadyRevision",nil)
	data.boostVersion = (data.boostVersion or 0) + 1
	data.lastFlip = nil
	data.recoveryVersion = (data.recoveryVersion or 0) + 1
	data.safePoints = { { cframe = cframe, x = cframe.Position.X, sign = sign, support = data.spawn, localCFrame = data.spawn.CFrame:ToObjectSpace(cframe) } }
	player:SetAttribute("RunnerRevivesThisRound", 0)
	player:SetAttribute("RunnerLastRevivePosition", nil)
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
	data.secondLifeCourseVersion = nil
	data.pendingRespawnVersion = nil
	data.recoveryPoint = nil
	data.ready = false
	data.speedMultiplier = 1
 data.superUntil=nil data.normalBoostUntil=nil data.antispikeUntil=nil data.freezeUntil=nil
	data.recovering = false
	data.invulnerableUntil = 0
	setStatus(player, "Loading")
	player:SetAttribute("RunnerAutoReady",data.readyForCourseVersion==courseVersion)
	addRunnerForces(data)
	data.velocity.LineVelocity = 0
	player:SetAttribute("RunnerCourseVersion", courseVersion)
	player:SetAttribute("RunnerSpawnRevision", data.spawnRevision)
end

local function assignSpawn(player)
	local data = players[player]
	if not data then return end
	if data.spawn and data.spawn:IsDescendantOf(spawnFolder) then return end
	data.spawn = nil
	local used = {}
	for other, otherData in players do
		if other ~= player and otherData.spawn then used[otherData.spawn] = true end
	end
	for index, spawn in spawns do
		if not used[spawn] then
			data.spawn = spawn
			data.spawnIndex = index
			player.RespawnLocation = spawn
			player:SetAttribute("RunnerSpawnIndex", index)
			return
		end
	end
	setStatus(player, "Spectating")
end

-- The same guarded recovery is used for hazards and a fully rebuilt R6 character.
local function resumeRecovery(player, data)
 data.idleWatch=nil
 data.idleRecoveryUntil=workspace:GetServerTimeNow()+config.RecoveryFreezeTime+1
	local version, root, recoveryVersion = courseVersion, data.root, data.recoveryVersion
	data.root.Anchored = true
	data.root.AssemblyLinearVelocity = Vector3.zero
	data.root.AssemblyAngularVelocity = Vector3.zero
	if data.velocity then data.velocity.LineVelocity = 0 end
	if data.runTrack then data.runTrack:AdjustSpeed(0) end
	task.delay(config.RecoveryFreezeTime, function()
		if courseVersion ~= version or roundPhase ~= "Running"
			or players[player] ~= data or data.status ~= "Running" or data.root ~= root
			or data.recoveryVersion ~= recoveryVersion or not player.Parent or not root.Parent
			or data.humanoid.Health <= 0 then return end
		root.Anchored = false
		pcall(function() root:SetNetworkOwner(player) end)
		setSpeed(data, data.speedMultiplier or 1)
		data.recovering = false
		data.pendingRespawnVersion = nil
		data.invulnerableUntil = workspace:GetServerTimeNow() + config.RecoveryProtectionSeconds
	end)
end

local function setupCharacter(player, character)
	local data = players[player]
	if not data then return end
	-- Character replacement is not a free way back into an active race.
	if data.character and data.character ~= character and data.status == "Running"
		and roundPhase == "Running" and data.pendingRespawnVersion ~= courseVersion then
		recoverPlayer(player, "Character replaced", true)
	end
	data.character = character
	data.humanoid = character:WaitForChild("Humanoid", 15)
	data.root = character:WaitForChild("HumanoidRootPart", 15)
	if not data.humanoid or not data.root or player.Character ~= character then return end
	data.humanoid.Died:Once(function()
		if players[player] == data and data.character == character then
			recoverPlayer(player, "Death", true)
		end
	end)
	if roundPhase=="MatchComplete" then
  removeRunnerForces(data)
  if Podium.PlaceCharacter(player,character) then data.status="Podium" return end
 end
	assignSpawn(player)
	if data.spawn then
		data.root.Anchored = true
		data.root.CFrame = spawnCFrame(data.spawn)
	end
	if roundPhase ~= "Waiting" and roundPhase ~= "Countdown"
		and (data.status ~= "Running" or data.pendingRespawnVersion ~= courseVersion) then
		setStatus(player, "Spectating")
		return
	end
	if data.spawn and (roundPhase=="Waiting" or roundPhase=="Countdown"
		or player:GetAttribute("GBloxCourseReady")) then
		if roundPhase == "Running" and data.pendingRespawnVersion == courseVersion
			and data.recoveryPoint then
			local safe = data.recoveryPoint
			data.gravitySign = safe.sign
			data.root.CFrame = safe.cframe
			data.humanoid.AutoRotate = false
			data.humanoid.PlatformStand = true
			addRunnerForces(data)
			playRunAnimation(data)
			setGravity(player, safe.sign, false)
			resumeRecovery(player, data)
		else
			placeAtSpawn(player)
		end
	end
end

local function allReady()
	local count, waiting = 0, false
	for player, data in players do
		if player.Parent==Players and data.status~="Spectating" then
			count+=1
			-- A connected/loading party member must never be skipped.
			if not player:GetAttribute("GBloxCourseReady") or not data.spawn
				or not data.root or not data.root.Parent or not data.humanoid
				or data.humanoid.Health<=0 or data.courseStreamReady~=courseVersion
				or not data.ready then waiting=true end
		end
	end
	return not waiting and count>=math.max(1,expectedPlayers), count
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
	local activeVersion = courseVersion
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
		table.insert(courseConnections, part.Touched:Connect(function(hit)
			if roundPhase ~= "Running" or activeVersion ~= courseVersion
				or not state.available or not token:IsDescendantOf(course) then return end
			local player = playerFromHit(hit)
			local data = player and players[player]
			if not data or data.status ~= "Running" or data.recovering
				or not data.humanoid or data.humanoid.Health <= 0 then return end
			-- One boolean charge, bound to this course version. Never stack.
			if data.secondLifeCourseVersion == courseVersion then return end
			state.available = false
			data.secondLifeCourseVersion = courseVersion
			player:SetAttribute(config.SecondLifeAttribute, 1)
			setSecondLifeTokenVisible(state, false)
			event:FireClient(player, "SecondLife", { lives = 1 })
		end))
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
	packet.courseNumber = courseNumber
	packet.courseVersion = courseVersion
	packet.courseCenter = descriptor.center
	packet.finishDeadline = finishDeadline
	workspace:SetAttribute("RunnerRoundPhase", roundPhase)
 spectating:Step()
	event:FireAllClients("State", packet)
end

local function resetRound()
	-- Called exactly once per transition. Never recycle old-course spawn references.
	local nextDescriptor, message = CourseRegistry.Resolve(workspace, courseNumber + 1, config.MaxPlayers)
	if courseNumber >= maxRounds then
		roundPhase = "MatchComplete"
		payMatch()
		broadcastState({ message = "MATCH COMPLETE" })
		return
	end
	if not nextDescriptor then
		roundPhase = "AwaitingCourse"
		warn("[Runner] " .. message)
		broadcastState({ message = message })
		return
	end
	local carryReady = {}
	for _,id in readyGate:Summary().readyIds do carryReady[id] = true end
	readyGate:Close()
	resetBoost()
	resetSecondLifeTokens()
	for _, connection in courseConnections do connection:Disconnect() end
	table.clear(courseConnections)
	table.clear(spikeModels)
	table.clear(spikePivots)
 table.clear(spikeGeometry)
	table.clear(boostParts)
	table.clear(boostOriginal)
	table.clear(secondLifeTokens)
	courseNumber += 1
	courseVersion += 1
	descriptor = nextDescriptor
	course, spawnFolder = descriptor.course, descriptor.spawnFolder
	boundsFolder, endZone, boostFolder = descriptor.bounds, descriptor.finish, descriptor.boosts
	spawns = descriptor.spawns
	CourseRegistry.ActivateSpawns(workspace, descriptor)
	workspace:SetAttribute("RunnerCourseCenter", descriptor.center)
	workspace:SetAttribute("RunnerCourseNumber", courseNumber)
	countdownVersion += 1
	roundPhase = "Waiting"
	roundStartedAt, finishPlace = 0, 0
	roundWinner, finishDeadline = nil, nil
	bindCourse()
	local ordered = Players:GetPlayers()
	table.sort(ordered, function(a, b) return a.UserId < b.UserId end)
	for _, player in ordered do
		local data = players[player]
		if data then
			data.spawn, data.spawnIndex = nil, nil
			data.safePoints = {}
			data.courseStreamReady = nil
			data.readyForCourseVersion = carryReady[player.UserId] and courseVersion or nil
			data.ready = false
			player:SetAttribute("RunnerNextRoundReady", false)
   player:SetAttribute("GBloxAbilityRoundKey",courseVersion)
		end
	end
	expectedPlayers = math.min(#ordered, config.MaxPlayers)
	for _, player in ordered do
		local data = players[player]
		if data then
			assignSpawn(player)
			if data.root and data.root.Parent and data.humanoid.Health > 0 then
				placeAtSpawn(player)
			else
				setStatus(player, "Loading")
			end
		end
	end
	broadcastState()
end

local function broadcastReadiness()
	local state=readyGate:Summary()
	if lastRankingPacket then lastRankingPacket.readiness=state end
	event:FireAllClients("RankingsReadiness",state)
end

checkIntermissionReady = function()
	if roundPhase~="Intermission" then return end
	broadcastReadiness()
	if readyGate:Summary().allReady then
		-- resetRound synchronously leaves Intermission; duplicate packets cannot advance twice.
		resetRound()
	end
end

local function currentRoundProgress(data)
 if data.roundFinishTime then return 1 end
 if not data.root or not data.roundStartX then return data.maxProgress or 0 end
 local span=data.roundStartX-endZone:GetPivot().Position.X
 if math.abs(span)<.01 then return 0 end
 return math.clamp((data.roundStartX-data.root.Position.X)/span,0,1)
end

local function sendRoundRankings()
 local rows={}
 for player,data in players do
  local total=matchResults[player]
  if total and data.scoredCourse==courseNumber then
   table.insert(rows,{
    userId=player.UserId,username=player.Name,displayName=player.DisplayName,
    emoteKey=RankingEmotes.Selected(player),
    emoteAnimationId=RankingEmotes.AnimationId(player,RankingEmotes.Selected(player)),
    totalScore=total.score,totalTime=total.time,
    roundScore=player:GetAttribute("RoundScore") or 0,
    finished=data.roundFinishTime~=nil,finishTime=data.roundFinishTime,
    progress=data.roundFinishTime and 1 or math.clamp(data.roundStoppedProgress or data.maxProgress or 0,0,.999),
    finishPlace=data.roundFinishPlace,
   })
  end
 end
 table.sort(rows,function(a,b)
  if a.finished~=b.finished then return a.finished end
  if a.finished then
   if a.finishPlace~=b.finishPlace then return (a.finishPlace or 99)<(b.finishPlace or 99) end
   if a.finishTime~=b.finishTime then return a.finishTime<b.finishTime end
  elseif a.progress~=b.progress then return a.progress>b.progress end
  return a.userId<b.userId
 end)
 for rank,row in rows do row.roundPlace=rank end
 table.sort(rows,function(a,b)
  if math.abs(a.totalScore-b.totalScore)>.00001 then return a.totalScore>b.totalScore end
  if a.totalTime~=b.totalTime then return a.totalTime<b.totalTime end
  return a.userId<b.userId
 end)
 for rank,row in rows do row.overallPlace=rank end
 local userIds={}
 for _,row in rows do table.insert(userIds,row.userId) end
 readyGate:Open(courseVersion,userIds)
 lastRankingPacket={
  courseNumber=courseNumber,courseVersion=courseVersion,totalRounds=maxRounds,
  rows=rows,continueAt=workspace:GetServerTimeNow()+1.3,
  readiness=readyGate:Summary(),
 }
 event:FireAllClients("RoundRankings",lastRankingPacket)
end

local function endRound()
	if roundPhase ~= "Running" then return end
	roundPhase = "Intermission"
	finishDeadline = nil
	countdownVersion += 1
	local version = courseVersion
	for player, data in players do
		local result=matchResults[player]
        if not data.roundFinishTime and data.roundStoppedProgress==nil then data.roundStoppedProgress=currentRoundProgress(data) end
		if result and data.scoredCourse~=courseNumber then
			data.scoredCourse=courseNumber
			local completion=data.roundFinishTime and 1 or math.clamp(data.roundStoppedProgress or data.maxProgress or 0,0,1)
			local bonus=data.roundFinishTime and math.max(0,3-.2*math.floor(math.max(0,data.roundFinishTime-(data.firstFinishTime or data.roundFinishTime)))) or 0
			local score=7*completion+bonus
			result.score+=score result.rounds+=1
			result.time+=data.roundFinishTime or math.max(0,workspace:GetServerTimeNow()-roundStartedAt)
			if data.roundFinishTime then result.finishes+=1 end
			player:SetAttribute("RoundScore",score)
			player:SetAttribute("MatchScore",result.score)
		end
		data.ready = false
		player:SetAttribute("RunnerNextRoundReady", false)
		data.secondLifeCourseVersion = nil
		data.pendingRespawnVersion = nil
		data.recoveryPoint = nil
		player:SetAttribute(config.SecondLifeAttribute, 0)
		data.recovering = false
		data.recoveryVersion = (data.recoveryVersion or 0) + 1
		data.boostVersion = (data.boostVersion or 0) + 1
		if data.status == "Running" then
			setStatus(player, "Out")
			event:FireClient(player, "Out", { reason = "Round ended" })
		end
		removeRunnerForces(data)
		if data.root and data.root.Parent then
			data.root.Anchored = true
			data.root.AssemblyLinearVelocity = Vector3.zero
			data.root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if courseNumber>=maxRounds then
  sendRoundRankings()
  roundPhase="MatchComplete"
  Podium.Start(payMatch(),matchId,courseVersion,players)
  broadcastState({message=""})
  return
 end
	sendRoundRankings()
	broadcastState({ message = "ROUND " .. courseNumber .. " COMPLETE" })
	-- Rankings stay open until every remaining participant confirms Ready.
	broadcastReadiness()
end

checkRoundComplete = function()
	if roundPhase ~= "Running" then return end
	for _, data in players do
		if data.status == "Running" then return end
	end
	endRound()
end

local function startRace(version)
	if version ~= countdownVersion then return end
	local ready = allReady()
	if not ready then return end
	roundPhase = "Running"

	lastRankingPacket=nil
	roundStartedAt = workspace:GetServerTimeNow()
	roundWinner = nil
	finishPlace = 0
	for player, data in players do
		if data.ready and data.root and data.root.Parent then
			player:SetAttribute("RunnerRaceStartedAt",workspace:GetServerTimeNow())
            setStatus(player, "Running")
            data.idleWatch=IdleRules.New(roundStartedAt,data.root.Position:Dot(forward),courseVersion)
            data.idleRecoveryUntil=nil
            data.readyForCourseVersion=nil
            player:SetAttribute("RunnerAutoReady",false)
            if courseNumber==1 then matchResults[player]={score=0,time=0,rounds=0,finishes=0,died=false,deaths=0,usedAbility=false} end
            data.roundStoppedProgress=nil data.roundFinishTime=nil data.roundFinishPlace=nil data.firstFinishTime=nil data.maxProgress=0 data.roundStartX=data.root.Position.X
            data.root.Anchored = false
			pcall(function() data.root:SetNetworkOwner(player) end)
			setSpeed(data, 1)
			playRunAnimation(data)
		end
	end
	broadcastState()
end

beginCountdown = function()
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
	local data = players[player]
	if roundPhase ~= "Running" or not data or data.status ~= "Running" then return false, false end
	-- Consume the pickup first; other recovery abilities keep their existing behavior.
	if data.secondLifeCourseVersion == courseVersion then
		data.secondLifeCourseVersion = nil
		player:SetAttribute(config.SecondLifeAttribute, 0)
		return true, true
	end
	if config.TutorialRecovery or player:GetAttribute(config.RepeaterAttribute) == true then
		return true, false
	end
	return false, false
end

local function recoveryPoint(data)
	local checked={}
	for index=#data.safePoints,1,-1 do
		local point=data.safePoints[index]
		local support=point.support
		if support then
			checked[support]=checked[support] or {}
			if not checked[support][point.sign] then
				checked[support][point.sign]=true
				local safe=Recovery.Center(support,point.sign,data.laneZ,course)
				if safe then
					for future=#data.safePoints,index+1,-1 do data.safePoints[future]=nil end
					data.safePoints[index]=safe
					return safe
				end
			end
		end
	end
end

recoverPlayer = function(player, reason, characterDeath)
	local data = players[player]
 if reason=="Spike" and data and data.antispikeRound==courseVersion and (data.antispikeUntil or 0)>workspace:GetServerTimeNow() then return end
	if roundPhase ~= "Running" or not data or data.status ~= "Running" then return end
	if not characterDeath and (data.recovering
		or workspace:GetServerTimeNow() < (data.invulnerableUntil or 0)) then return end
	if characterDeath and data.pendingRespawnVersion == courseVersion then return end
	if matchResults[player] then
  matchResults[player].died=true
  if not data.recovering then matchResults[player].deaths=(matchResults[player].deaths or 0)+1 end
 end
	local safe = data.recovering and data.recoveryPoint or recoveryPoint(data)
	local allowed, usedSecondLife
	if characterDeath and data.recovering then
		allowed, usedSecondLife = true, data.recoveryUsedSecondLife
	else
		allowed, usedSecondLife = canRecover(player)
	end
	if not data.recovering and (reason=="Spike" or reason=="Fall" or reason=="Death") then
  showRaceVFX(player,data,"DefaultDeath",courseVersion,not allowed or not safe)
 end
	if not allowed or not safe then
		data.roundStoppedProgress = currentRoundProgress(data)
		setStatus(player, "Out")
		removeRunnerForces(data)
		if data.root and data.root.Parent then data.root.Anchored = true end
		event:FireClient(player, "Out", { reason = reason })
		checkRoundComplete()
		return
	end
	data.recovering = true
 data.idleWatch=nil
 data.idleRecoveryUntil=workspace:GetServerTimeNow()+math.max(3,config.RecoveryFreezeTime+1)
	data.recoveryVersion = (data.recoveryVersion or 0) + 1
	data.recoveryPoint = safe
	data.recoveryUsedSecondLife = usedSecondLife
	data.gravitySign = safe.sign
	data.lastFlip=nil data.lastAcceptedGroundTime=nil
	player:SetAttribute("GravitySign",safe.sign)
	player:SetAttribute("RunnerRecoveryRevision",data.recoveryVersion)
	player:SetAttribute("RunnerLastRevivePosition", safe.cframe.Position)
	player:SetAttribute("RunnerRevivesThisRound", (player:GetAttribute("RunnerRevivesThisRound") or 0) + 1)
	event:FireClient(player, "Recover", {
		reason = reason, usedSecondLife = usedSecondLife, sign=safe.sign, recoveryRevision=data.recoveryVersion, courseVersion=courseVersion,
		protectionSeconds = config.RecoveryProtectionSeconds,
	})
	if characterDeath then
		data.pendingRespawnVersion = courseVersion
		removeRunnerForces(data)
		return -- R6CharacterLoader builds the body; setupCharacter completes this authorized revive.
	end
	data.root.CFrame = safe.cframe
	setGravity(player, safe.sign, false)
	resumeRecovery(player, data)
end

local function eliminateIdlePlayer(player, data)
 if roundPhase~="Running" or players[player]~=data or data.status~="Running" then return end
 data.roundStoppedProgress=currentRoundProgress(data)
 -- This is a forfeit of this round, not a hazard death or a paid/free revive.
 data.recovering=false data.pendingRespawnVersion=nil data.recoveryPoint=nil
 data.recoveryVersion=(data.recoveryVersion or 0)+1
 data.boostVersion=(data.boostVersion or 0)+1
 data.idleWatch=nil data.idleRecoveryUntil=nil
 setStatus(player,"Out")
 player:SetAttribute("RunnerOutReason","No forward progress for 15 seconds")
 abilityService.Remove(player)
 removeRunnerForces(data)
 if data.root and data.root.Parent then
  data.root.Anchored=true
  data.root.AssemblyLinearVelocity=Vector3.zero
  data.root.AssemblyAngularVelocity=Vector3.zero
 end
 event:FireClient(player,"Out",{reason="No forward progress for 15 seconds",idleTimeout=true})
 checkRoundComplete()
end

local function stepIdleTimeout(now)
 for player,data in players do
  local active=roundPhase=="Running" and data.status=="Running"
  local root=data.root
  local progress=root and root.Parent and root.Position:Dot(forward) or nil
  -- Recovery grace is bounded: a broken recovery must not hang the round forever.
  local paused=(data.freezeUntil or 0)>now or (data.idleRecoveryUntil or 0)>now
  local expired
  data.idleWatch,expired=IdleRules.Step(data.idleWatch,now,progress,courseVersion,active,paused)
  if expired then eliminateIdlePlayer(player,data) end
 end
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

	data.roundFinishTime=finishTime
    data.roundFinishPlace=finishPlace
    data.maxProgress=1
	local isWinner = roundWinner == nil
	if isWinner then
		roundWinner = player
		for _,other in players do other.firstFinishTime=finishTime end
		finishDeadline = workspace:GetServerTimeNow() + (config.FinishGraceSeconds or 15)
	end
 showRaceVFX(player,data,"GreenFinish",courseVersion,true)
	-- Finishing a course is not an overall match win; rewards belong to match results.
	event:FireClient(player, "Finished", {
		Place = finishPlace,
		IsWinner = isWinner,
		TimeMs = math.floor(finishTime * 1000 + 0.5),
		CourseNumber = courseNumber,
	})
	checkRoundComplete()
	if roundPhase == "Running" then broadcastState() end
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
 data.normalBoostUntil=workspace:GetServerTimeNow()+config.BoostSeconds
	setSpeed(data, config.BoostMultiplier)
	event:FireClient(player, "Boost", { seconds = config.BoostSeconds })
	task.delay(config.BoostSeconds, function()
		if players[player] == data and data.boostVersion == version
			and data.status == "Running" and roundPhase == "Running" then
			setSpeed(data, 1)
		end
	end)
end

local TeleportService=game:GetService("TeleportService")
local returnTravel=require(game.ServerScriptService:WaitForChild("GBloxTeleportRetry")).new({
 AttemptLimit=3,
 NewId=function() return game:GetService("HttpService"):GenerateGUID(false) end,
 IsPresent=function(player) return player.Parent==Players end,
 CopyOptions=function(old,payload)
  local options=Instance.new("TeleportOptions")
  if old.ReservedServerAccessCode~="" then options.ReservedServerAccessCode=old.ReservedServerAccessCode
  elseif old.ServerInstanceId~="" then options.ServerInstanceId=old.ServerInstanceId
  else options.ShouldReserveServer=old.ShouldReserveServer end
  options:SetTeleportData(payload)
  return options
 end,
 Reserve=function(placeId) return TeleportService:ReserveServerAsync(placeId) end,
 Teleport=function(placeId,members,options) return TeleportService:TeleportAsync(placeId,members,options) end,
 Spawn=task.spawn,Delay=task.delay,Wait=task.wait,
 Report=function(kind,player,placeId,attempt,message)
  if kind~="Initiated" then warn("[GBloxReturn]",kind,player.UserId,placeId,attempt,message) end
 end,
})
local leaveRules=require(ReplicatedStorage:WaitForChild("RankingLeaveRules"))
local function leaveFailure(player,data,message)
 if players[player]~=data then return end
 PlayerData.CancelPlaytimeTeleport(player,data.playtimeTicket)
 data.playtimeTicket=nil
 data.leavingLobby=false data.leaveRequestId=nil
 event:FireClient(player,"LeaveLobbyResult",{ok=false,message=message,courseVersion=courseVersion})
end
local function leaveRankings(player,version)
 local data=players[player]
 if not data or data.leavingLobby or not lastRankingPacket
  or not leaveRules.CanLeave(roundPhase,version,lastRankingPacket.courseVersion)
  or version~=courseVersion then return end
 if os.clock()-(data.lastLeaveAttempt or -math.huge)<3 then
  event:FireClient(player,"LeaveLobbyResult",{ok=false,message="Please wait a moment, then try again.",courseVersion=version})
  return
 end
 data.lastLeaveAttempt=os.clock()
 data.leavingLobby=true
 data.leaveRequestId=game:GetService("HttpService"):GenerateGUID(false)
 -- Stay unready until departure; the next race cannot start while a return is pending.
 if roundPhase=="Intermission" then
  readyGate:SetReady(player.UserId,version,false)
  player:SetAttribute("RunnerNextRoundReady",false)
  broadcastReadiness()
 end
 event:FireClient(player,"LeaveLobbyResult",{ok=true,courseVersion=version})
 task.spawn(function()
  if courseNumber>=maxRounds and matchResults[player] and matchResults[player].rounds>=maxRounds then
   payMatch()
   local deadline=os.clock()+30
   while player.Parent and not player:GetAttribute("MatchRewardRecorded") and os.clock()<deadline do task.wait(.1) end
   if not player:GetAttribute("MatchRewardRecorded") then
    leaveFailure(player,data,"Rewards are still saving. Please try again.") return
   end
  end
  local token,reason=PlayerData.PreparePlaytimeTeleport(player,74498603638770)
  if not token then
   leaveFailure(player,data,reason or "Save busy. Please try again.") return
  end
  data.playtimeTicket=token
  if player.Parent~=Players or players[player]~=data then return end
  local options=Instance.new("TeleportOptions")
  options:SetTeleportData({ReturnFromRankings=true,ReturnRequestId=data.leaveRequestId,GBloxPlaytimeTickets={[tostring(player.UserId)]=token}})
  local started=returnTravel:Start(74498603638770,{player},options,{
   Failed=function(failedPlayer)
    leaveFailure(failedPlayer,data,RunService:IsStudio() and "Lobby teleport requires the published game." or "Could not return to the lobby. Please try again.")
   end,
  })
  if not started then leaveFailure(player,data,"Travel is already in progress. Please try again shortly.") end
 end)
end
Podium.SetReturnHandler(leaveRankings)
TeleportService.TeleportInitFailed:Connect(function(player,result,message,placeId,options)
 returnTravel:Failed(player,result.Name,message,placeId,options)
end)

event.OnServerEvent:Connect(function(player, action, version, takeoff, support, groundPosition, groundTime, requestId, recoveryRevision, abilityRevision)
	local data = players[player]
	if not data then return end
	if action=="Spectate" then spectating:Select(player,version) return
	elseif action=="LeaveRankings" then leaveRankings(player,version) return
	elseif action=="RankingsReady" then
		if data.leavingLobby then return end
		if roundPhase~="Intermission" or version~=courseVersion or not lastRankingPacket
			or workspace:GetServerTimeNow() < lastRankingPacket.continueAt then return end
		if readyGate:SetReady(player.UserId,version,takeoff) then
			player:SetAttribute("RunnerNextRoundReady",takeoff)
			checkIntermissionReady()
		end
		return
	elseif action=="RequestRankingEmotes" then
		if os.clock()-(data.lastEmoteOptions or -math.huge)<1 then return end
		data.lastEmoteOptions=os.clock()
		event:FireClient(player,"RankingEmoteOptions",{options=RankingEmotes.Options(player),selected=RankingEmotes.Selected(player)})
		return
	elseif action=="SelectRankingEmote" then
		if roundPhase~="Intermission" or version~=courseVersion then return end
		if RankingEmotes.Select(player,takeoff) then
			if lastRankingPacket then
				for _,row in lastRankingPacket.rows do if row.userId==player.UserId then row.emoteKey=takeoff row.emoteAnimationId=RankingEmotes.AnimationId(player,takeoff) end end
			end
			event:FireAllClients("RankingEmoteChanged",{courseVersion=courseVersion,userId=player.UserId,key=takeoff,animationId=RankingEmotes.AnimationId(player,takeoff)})
		end
		return
	elseif action=="RequestRoundRankings" then
        if lastRankingPacket and roundPhase~="Running" and roundPhase~="Countdown" then
         event:FireClient(player,"RoundRankings",lastRankingPacket)
        end
        return
    elseif action == "CourseReady" then
		if version ~= courseVersion or data.courseVersion ~= courseVersion
			or takeoff ~= data.spawnRevision
			or not data.root or not data.root.Parent
			or not player:GetAttribute("GBloxCourseReady")
			or (roundPhase ~= "Waiting" and roundPhase ~= "Countdown") then return end
		data.courseStreamReady = version
		player:SetAttribute("RunnerStreamReadyRevision",data.spawnRevision)
		if data.readyForCourseVersion == version then
			data.ready = true
			player:SetAttribute("RunnerReady",true)
		end
		setStatus(player, "Waiting")
		broadcastState()
		if data.ready then beginCountdown() end
	elseif action == "Ready" and roundPhase == "Waiting"
		and player:GetAttribute("GBloxCourseReady") and data.spawn
		and data.courseStreamReady == courseVersion then
		data.ready = not data.ready
		player:SetAttribute("RunnerReady", data.ready)
		event:FireAllClients("ReadyChanged", {
			userId = player.UserId,
			ready = data.ready,
		})
		if data.ready then beginCountdown() end
	elseif action == "Flip" then
		local now = os.clock()
		local desiredSign = version
        local maxSpeed=(config.MaxRunSpeed+config.FlipForwardBonus)*math.max(config.BoostMultiplier,data.speedMultiplier or 1)
        if (data.status~="Waiting" and data.status~="Running")
         or typeof(requestId)~="number" or requestId~=requestId or requestId%1~=0 or requestId<=0 or requestId>1e9
         or abilityRevision~=(player:GetAttribute("RunnerAbilityRevision") or 0)
         or recoveryRevision~=(player:GetAttribute("RunnerRecoveryRevision") or 0)
         or (desiredSign~=1 and desiredSign~=-1) or desiredSign~=-data.gravitySign
         or not data.root or data.root.Anchored or data.recovering
         or not GroundCheck.ValidTakeoff(player.Character,data.root.Position,data.gravitySign,takeoff,support,groundPosition,groundTime,workspace:GetServerTimeNow(),maxSpeed,config.EdgeGraceSeconds)
         or groundTime<=(data.lastAcceptedGroundTime or -math.huge)
         or now-(data.lastFlip or -math.huge)<config.FlipCooldown then
         event:FireClient(player,"FlipAck",{sign=data.gravitySign,accepted=false,requestId=requestId,courseVersion=courseVersion,recoveryRevision=player:GetAttribute("RunnerRecoveryRevision") or 0,abilityRevision=player:GetAttribute("RunnerAbilityRevision") or 0})
         return
        end
        data.lastAcceptedGroundTime=groundTime
		data.lastFlip = now
		-- The owning client has already applied the impulse; never teleport it again.
		setGravity(player, desiredSign, false)
		event:FireClient(player, "FlipAck", { sign = desiredSign, accepted = true,requestId=requestId,courseVersion=courseVersion,recoveryRevision=player:GetAttribute("RunnerRecoveryRevision") or 0,abilityRevision=player:GetAttribute("RunnerAbilityRevision") or 0 })
	end
end)

local function addPlayer(player)
	local joinData = player:GetJoinData()
 if not receivedLobbyParty and courseNumber==1 and (roundPhase=="Waiting" or roundPhase=="Countdown") then
  local humanCount=ArrivalRules.Expected(joinData,74498603638770,game.GameId,config.MaxPlayers)
  if humanCount then
   expectedPlayers=math.max(expectedPlayers,humanCount)
   receivedLobbyParty=true
   arrivalDeadline=workspace:GetServerTimeNow()+60
  end
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
	RankingEmotes.Register(player)
 player:SetAttribute("GBloxAbilityRoundKey",courseVersion)
	player:SetAttribute("RunnerStatus", "Loading")
	player:SetAttribute("RunnerReady", false)
	player:SetAttribute("RunnerSpeedMultiplier", 1)
	if player:GetAttribute(config.RepeaterAttribute) == nil then
		player:SetAttribute(config.RepeaterAttribute, false)
	end
	player:SetAttribute(config.SecondLifeAttribute, 0)
	player:GetAttributeChangedSignal("GBloxCourseReady"):Connect(function()
		if player:GetAttribute("GBloxCourseReady") then
			if roundPhase ~= "Waiting" and roundPhase ~= "Countdown" then
				setStatus(player, "Spectating")
				return
			end
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
	assignSpawn(player)
	if player.Character then task.spawn(setupCharacter, player, player.Character) end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local departing=players[player]
 spectating:Remove(player)
 returnTravel:Remove(player)
	players[player] = nil
	RankingEmotes.Remove(player)
	readyGate:Remove(player.UserId)
	task.defer(checkIntermissionReady)
	-- Other members of the same teleport may still be on their way.
	if departing and departing.status~="Spectating" then
		expectedPlayers = math.max(1,expectedPlayers-1)
	end
	task.defer(checkRoundComplete)
	countdownVersion += 1
	if roundPhase == "Countdown" then
		roundPhase = "Waiting"
		broadcastState()
	end
	task.defer(beginCountdown)
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

bindCourse = function()
	local activeVersion = courseVersion
	local function connect(part, callback)
		table.insert(courseConnections, part.Touched:Connect(function(hit)
			if activeVersion ~= courseVersion or roundPhase ~= "Running" then return end
			local player = playerFromHit(hit)
			if player then callback(player) end
		end))
	end
	for _, object in course:GetDescendants() do
		if object:IsA("Model") and object.Name == "Red_Spiked_Wheel" then
			table.insert(spikeModels, object)
			local pivot=object:GetPivot()
   spikePivots[object] = pivot
   local teeth=object:FindFirstChild("RedWheel_Teeth",true)
   spikeGeometry[object]={
    center=CFrame.new(pivot.Position),rotation=pivot.Rotation,teeth=teeth,
    radiusSquared=teeth and (teeth.Size.Magnitude*.5+8)^2 or 0,
   }
			for _, part in object:GetDescendants() do
				if part:IsA("BasePart") then
					-- Art never blocks runners; only the teeth participate in contact queries.
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = part.Name == "RedWheel_Teeth"
				end
			end
		end
	end
	boostAvailable = true
	if boostFolder then
		for _, part in boostFolder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(boostParts, part)
				boostOriginal[part] = {
					transparency = part.Transparency,
					canCollide = part.CanCollide, canTouch = part.CanTouch,
				}
				connect(part, giveBoost)
			end
		end
	end
	for _, part in endZone:GetDescendants() do
		if part:IsA("BasePart") then connect(part, finishPlayer) end
	end
	for _, part in boundsFolder:GetDescendants() do
		if part:IsA("BasePart") then
			connect(part, function(player) recoverPlayer(player, "Fall") end)
		end
	end
	if descriptor.tokens then
		for _, token in descriptor.tokens:GetChildren() do registerSecondLifeToken(token) end
	end
end
bindCourse()

local raycast = RaycastParams.new()
raycast.FilterType = Enum.RaycastFilterType.Include
raycast.RespectCanCollide = true
local checkpointClock = 0
local spectatorClock = 0
local spinAngle = 0
local spikeContactClock = 0
local SpikeContact = require(game.ServerScriptService:WaitForChild("RunnerSpikeContact"))

RunService.Heartbeat:Connect(function(deltaTime)
 spectatorClock+=deltaTime
 if spectatorClock>=.25 then
  spectatorClock=0
  spectating:Step()
  if arrivalDeadline and workspace:GetServerTimeNow()>=arrivalDeadline then
   arrivalDeadline=nil
   if courseNumber==1 and (roundPhase=="Waiting" or roundPhase=="Countdown") then
    local _,count=allReady()
    local revised=ArrivalRules.AfterDeadline(expectedPlayers,count)
    if revised<expectedPlayers then
     warn("[RunnerArrival] Missing party members",expectedPlayers-count,"continuing with",count)
     expectedPlayers=revised
     broadcastState()
     task.defer(beginCountdown)
    end
   end
  end
 end
 stepIdleTimeout(workspace:GetServerTimeNow())
 if roundPhase=="Running" then
  local finishX=endZone:GetPivot().Position.X
  for player,data in players do
   if data.status=="Running" and data.root and data.roundStartX then
    local span=data.roundStartX-finishX
    if math.abs(span)>.01 then data.maxProgress=math.max(data.maxProgress or 0,math.clamp((data.roundStartX-data.root.Position.X)/span,0,1)) end
    if player:GetAttribute("AbilityUsedThisMatch")==true and matchResults[player] then matchResults[player].usedAbility=true end
   end
  end
 end
	if roundPhase == "Running" and finishDeadline
		and workspace:GetServerTimeNow() >= finishDeadline then endRound() end
	spinAngle += math.rad(config.SpikeDegreesPerSecond) * deltaTime
 local rotation=CFrame.fromAxisAngle(Vector3.zAxis,spinAngle)
	for _, model in spikeModels do
		if model.Parent then
   local geometry=spikeGeometry[model]
   model:PivotTo(geometry.center*rotation*geometry.rotation)
		end
	end

 -- PivotTo-spun anchored meshes do not reliably emit Touched, so check current geometry.
 spikeContactClock += deltaTime
 if roundPhase=="Running" and spikeContactClock>=1/30 then
  spikeContactClock=0
  for player,data in players do
   if data.status=="Running" and data.character and data.root and not data.recovering
    and workspace:GetServerTimeNow()>=(data.invulnerableUntil or 0)
    and not (data.antispikeRound==courseVersion and (data.antispikeUntil or 0)>workspace:GetServerTimeNow()) then
    for _,model in spikeModels do
     local geometry=spikeGeometry[model]
     local teeth=geometry.teeth
     local offset=teeth and teeth.Parent and (teeth.Position-data.root.Position)
     if offset and offset:Dot(offset)<geometry.radiusSquared
      and SpikeContact.HasContact(teeth,data.character,course) then
      recoverPlayer(player,"Spike")
      break
     end
    end
   end
  end
 end

	checkpointClock += deltaTime
	for player, data in players do
		if data.root and data.root.Parent and data.gravityForce then
			updateGravity(data)
		end

	end
	if checkpointClock < 0.15 then return end
	checkpointClock = 0

	for _, data in players do
		if data.status == "Running" and data.root and not data.recovering then
            if data.runTrack then data.runTrack:AdjustSpeed((data.freezeUntil or 0)>workspace:GetServerTimeNow() and 0 or Motion.Speed(data.player:GetAttribute("RunnerRaceStartedAt"),data.speedMultiplier)/16) end
			raycast.FilterDescendantsInstances = { course }
			local direction = Vector3.new(0, -data.gravitySign * 5.5, 0)
			local hit = workspace:Raycast(data.root.Position, direction, raycast)
			if hit and Recovery.IsPlatform(hit.Instance) and hit.Normal:Dot(gravityUp(data)) > 0.9
				and not hit.Instance:IsDescendantOf(boundsFolder)
				and (not descriptor.tokens or not hit.Instance:IsDescendantOf(descriptor.tokens))
				and (not boostFolder or not hit.Instance:IsDescendantOf(boostFolder)) then
				local onSpike = false
				for _, model in spikeModels do
					if hit.Instance:IsDescendantOf(model) then onSpike = true break end
				end
				if not onSpike then
					local previous = data.safePoints[#data.safePoints]
					if not previous or previous.support ~= hit.Instance or previous.sign ~= data.gravitySign
						or previous.x - data.root.Position.X >= 2 then
						local safePosition = Vector3.new(
							data.root.Position.X,
							data.root.Position.Y,
							data.laneZ
						)
						table.insert(data.safePoints, {
							cframe = runnerCFrame(safePosition, gravityUp(data)),
							x = data.root.Position.X,
							sign = data.gravitySign,
							support = hit.Instance,
							localCFrame = hit.Instance.CFrame:ToObjectSpace(runnerCFrame(safePosition, gravityUp(data))),
						})
						if #data.safePoints > 80 then table.remove(data.safePoints, 1) end
					end
				end
			end
		end
	end
end)

