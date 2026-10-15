assert(game.PlaceId==106769122906103)
local es=game:GetService("ScriptEditorService")
local backup=assert(game.ServerStorage:FindFirstChild("BeforeHalloweenCourseOne_20261003_080454"))
for _,name in ipairs({"RunnerServer","GBloxAbilityEffects","GBloxGravitySwitch"}) do
 assert(es:GetEditorSource(game.ServerScriptService[name])==backup[name.."_Source"].Value,"Source changed: "..name)
end
local sources={
["RunnerServer"]=[=[local GroundCheck=require(game.ReplicatedStorage:WaitForChild("RunnerGroundCheck"))
local Recovery=require(game.ServerScriptService:WaitForChild("RunnerRecovery"))
local IdleRules=require(game.ServerScriptService:WaitForChild("RunnerIdleRules"))
local PlayerData = require(game.ServerScriptService:WaitForChild("PlayerData"))
local PetCatalog = require(game.ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local matchId = game:GetService("HttpService"):GenerateGUID(false)
local matchResults = {}
local matchPaid = false
local matchHumanCount
local matchWinEligible=false
local roundHumanCount=0
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
  breakdown.competitive=matchWinEligible
  breakdown.humanCount=matchHumanCount or 0
  if not matchWinEligible then
   for _,row in breakdown.rows do
    if row.label=="Won without abilities" then row.label="Completed without abilities"
    elseif row.label=="Podium bonus" then row.label="Completion bonus"
    elseif row.label:sub(1,8)=="Placing " then row.label="Practice completion" end
   end
  end
  p:SetAttribute("MatchWinEligible",matchWinEligible)
  p:SetAttribute("MatchFinalPlace",place)
  p:SetAttribute("MatchRewardRecorded",false)
  Podium.UpdateReward(p,breakdown,"Saving")
  task.spawn(function()
   local deadline=os.clock()+30
   while not PlayerData.Get(p) and p.Parent and os.clock()<deadline do task.wait(.2) end
   if not p.Parent then return end
   if r.finishes==5 then PlayerData.RecordTime(p,r.time) end
   local saved,recorded=PlayerData.AwardMatch(p,matchId,place,breakdown.cash,breakdown.trophies,matchWinEligible)
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
local raceProgress
local halloweenService
local eliminateHalloweenPlayer
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
 if status~="Running" and halloweenService then halloweenService:Remove(player) end
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
 if raceProgress then raceProgress:Publish() end
end

local function resetRound()
 if halloweenService then halloweenService:Clear() end
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

raceProgress=require(game.ServerScriptService:WaitForChild("GBloxRaceProgressServer")).new({
 Runners=players,Phase=function() return roundPhase end,RoundKey=function() return courseVersion end,
 CourseNumber=function() return courseNumber end,Progress=currentRoundProgress,
 IsPresent=function(player) return player.Parent==Players end,
 Broadcast=function(packet) event:FireAllClients("RaceProgress",packet) end,
})

local halloweenSettings=ReplicatedStorage:WaitForChild("GBloxHalloweenSettings")
local halloweenRemote=ReplicatedStorage:WaitForChild("GBloxHalloweenEvent")
local halloweenRequestAt={}
halloweenService=require(game.ServerScriptService:WaitForChild("GBloxHalloweenService")).new({
 Runners=players,Phase=function() return roundPhase end,RoundKey=function() return courseVersion end,
 CourseNumber=function() return courseNumber end,Course=function() return course end,
 Now=function() return workspace:GetServerTimeNow() end,Progress=currentRoundProgress,
 Settings=halloweenSettings,Templates=ReplicatedStorage:WaitForChild("GBloxHalloweenAssets"),
 IsPlatform=function(part)
  return Recovery.IsPlatform(part) and not part:IsDescendantOf(boundsFolder)
   and not (boostFolder and part:IsDescendantOf(boostFolder))
   and not (descriptor.tokens and part:IsDescendantOf(descriptor.tokens))
 end,
 Freeze=function(player,seconds) return abilityService.FreezeSeasonal(player,seconds) end,
 ClearFreeze=function(player) abilityService.ClearSeasonalFreeze(player) end,
 Eliminate=function(player,reason) if eliminateHalloweenPlayer then eliminateHalloweenPlayer(player,reason) end end,
 Send=function(player,action,packet) if player.Parent==Players then halloweenRemote:FireClient(player,action,packet) end end,
 Broadcast=function(action,packet) halloweenRemote:FireAllClients(action,packet) end,
 OnUsed=function(player)
  if matchResults[player] then matchResults[player].usedAbility=true end
  player:SetAttribute("AbilityUsedThisMatch",true)
 end,
})
halloweenRemote.OnServerEvent:Connect(function(player,action)
 if action~="Web" and action~="Pumpkin" then return end
 if not players[player] then return end
 local now=os.clock()
 if now-(halloweenRequestAt[player] or -math.huge)<.15 then return end
 halloweenRequestAt[player]=now
 local ok,message,cooldownUntil=halloweenService:Activate(player,action)
 if player.Parent==Players then
  halloweenRemote:FireClient(player,"HalloweenResult",{action=action,ok=ok,message=message,cooldownUntil=cooldownUntil,roundKey=courseVersion})
 end
end)

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
 if halloweenService then halloweenService:Clear() end
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
  Podium.Start(payMatch(),matchId,courseVersion,players,{competitive=matchWinEligible,humanCount=matchHumanCount or 0})
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
 local starterIds={}
 for player,data in players do
  if player.Parent==Players and data.ready and data.status~="Spectating" and data.root and data.root.Parent then
   starterIds[player.UserId]=true
  end
 end
 roundHumanCount=0
 for _ in starterIds do roundHumanCount+=1 end
 if courseNumber==1 and matchHumanCount==nil then
  matchHumanCount=roundHumanCount
  matchWinEligible=matchHumanCount>=2
  workspace:SetAttribute("RunnerMatchHumanCount",matchHumanCount)
  workspace:SetAttribute("RunnerMatchCompetitive",matchWinEligible)
 end
 workspace:SetAttribute("RunnerRoundHumanCount",roundHumanCount)
	roundPhase = "Running"

	lastRankingPacket=nil
	roundStartedAt = workspace:GetServerTimeNow()
	roundWinner = nil
	finishPlace = 0
	for player, data in players do
		if player.Parent==Players and data.ready and data.status~="Spectating" and data.root and data.root.Parent then
			player:SetAttribute("RunnerRaceStartedAt",workspace:GetServerTimeNow())
            setStatus(player, "Running")
            data.idleWatch=IdleRules.New(roundStartedAt,data.root.Position:Dot(forward),courseVersion)
            data.idleRecoveryUntil=nil
            data.readyForCourseVersion=nil
            player:SetAttribute("RunnerAutoReady",false)
            if courseNumber==1 then matchResults[player]={score=0,time=0,rounds=0,finishes=0,died=false,deaths=0,usedAbility=false} end
            data.roundStoppedProgress=nil data.roundFinishTime=nil data.roundFinishPlace=nil data.firstFinishTime=nil data.maxProgress=0 data.roundStartX=data.root.Position.X
            raceProgress:MarkStarted(player,courseVersion)
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
 if halloweenService then halloweenService:Remove(player) end
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

eliminateHalloweenPlayer=function(player,reason)
 local data=players[player]
 if roundPhase~="Running" or not data or data.status~="Running"
  or courseNumber~=1 or data.recovering then return end
 data.roundStoppedProgress=currentRoundProgress(data)
 if matchResults[player] then
  matchResults[player].died=true
  matchResults[player].deaths=(matchResults[player].deaths or 0)+1
 end
 showRaceVFX(player,data,"DefaultDeath",courseVersion,true)
 data.recovering=false data.pendingRespawnVersion=nil data.recoveryPoint=nil
 data.recoveryVersion=(data.recoveryVersion or 0)+1
 data.boostVersion=(data.boostVersion or 0)+1
 data.idleWatch=nil data.idleRecoveryUntil=nil
 setStatus(player,"Out")
 player:SetAttribute("RunnerOutReason",reason)
 abilityService.Remove(player)
 removeRunnerForces(data)
 if data.root and data.root.Parent then
  data.root.Anchored=true
  data.root.AssemblyLinearVelocity=Vector3.zero
  data.root.AssemblyAngularVelocity=Vector3.zero
 end
 event:FireClient(player,"Out",{reason=reason,halloween=true})
 checkRoundComplete()
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
		IsWinner = isWinner and roundHumanCount>=2,
  Competitive = matchWinEligible,
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
 halloweenRequestAt[player]=nil
 if halloweenService then halloweenService:Remove(player) end
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
 halloweenService:Step(deltaTime)
 raceProgress:Step(deltaTime)
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


]=],
["GBloxAbilityEffects"]=[=[local M={}
function M.new(context)
 local states={}
 local self={}
 local function state(player)
  local data=context.Runners[player]
  if not data or not data.root then return end
  local s=states[player]
  if not s or s.root~=data.root or s.round~=context.RoundKey() then
   s={data=data,root=data.root,round=context.RoundKey()}
   states[player]=s
  end
  return s
 end
 local function syncFreeze(player,s)
  local now=context.Now()
  local previous=s.frozenUntil
  if (s.abilityFrozenUntil or 0)<=now then s.abilityFrozenUntil=nil end
  if (s.seasonalFrozenUntil or 0)<=now then s.seasonalFrozenUntil=nil end
  local untilTime=math.max(s.abilityFrozenUntil or 0,s.seasonalFrozenUntil or 0)
  s.frozenUntil=untilTime>now and untilTime or nil
  s.data.freezeUntil=s.frozenUntil
  player:SetAttribute("GBloxFrozenUntil",s.frozenUntil)
  player:SetAttribute("GBloxHalloweenHeldUntil",s.seasonalFrozenUntil)
  if s.frozenUntil then
   s.root.AssemblyLinearVelocity=Vector3.zero
   s.root.AssemblyAngularVelocity=Vector3.zero
   s.root.Anchored=true
   if s.data.velocity then s.data.velocity.LineVelocity=0 end
   if s.data.runTrack then s.data.runTrack:AdjustSpeed(0) end
  elseif previous and context.Runners[player]==s.data and s.data.root==s.root
   and s.root.Parent and s.data.status=="Running" and not s.data.recovering
   and context.RoundKey()==s.round and context.Phase()=="Running"
   and s.data.humanoid and s.data.humanoid.Health>0 then
   s.root.AssemblyLinearVelocity=Vector3.zero
   s.root.AssemblyAngularVelocity=Vector3.zero
   s.root.Anchored=false
   pcall(function() s.root:SetNetworkOwner(player) end)
  end
 end
 function self.Freeze(player,seconds)
  local s=state(player)
  if not s then return end
  s.abilityFrozenUntil=math.max(s.abilityFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
 end
 function self.FreezeSeasonal(player,seconds)
  local s=state(player)
  if not s then return end
  s.seasonalFrozenUntil=math.max(s.seasonalFrozenUntil or 0,context.Now()+seconds)
  syncFreeze(player,s)
  return s.seasonalFrozenUntil
 end
 function self.ClearSeasonalFreeze(player)
  local s=states[player]
  if not s then
   player:SetAttribute("GBloxHalloweenHeldUntil",nil)
   return
  end
  s.seasonalFrozenUntil=nil
  syncFreeze(player,s)
 end
 function self.Superspeed(player,seconds)
  local s=state(player)
  s.superUntil=context.Now()+seconds
  s.data.superUntil=s.superUntil
  player:SetAttribute("GBloxSuperspeedUntil",s.superUntil)
  context.SetSpeed(s.data,context.BoostMultiplier*2)
 end
 function self.Antispike(player,seconds)
  local s=state(player)
  s.antiUntil=context.Now()+seconds
  s.data.antispikeUntil=s.antiUntil
  s.data.antispikeRound=s.round
  player:SetAttribute("GBloxAntispikeUntil",s.antiUntil)
 end
 local function clear(player,s)
  local hadSuper=s.data.superUntil~=nil
  s.data.freezeUntil=nil s.data.superUntil=nil s.data.antispikeUntil=nil s.data.antispikeRound=nil
  if hadSuper then context.SetSpeed(s.data,(s.data.normalBoostUntil or 0)>context.Now() and context.BoostMultiplier or 1) end
  for _,name in {"GBloxFrozenUntil","GBloxHalloweenHeldUntil","GBloxSuperspeedUntil","GBloxAntispikeUntil"} do player:SetAttribute(name,nil) end
  states[player]=nil
 end
 function self.Step()
  local now=context.Now()
  for player,s in states do
   local data=context.Runners[player]
   if not player.Parent or data~=s.data or data.root~=s.root or not s.root.Parent
    or context.RoundKey()~=s.round or context.Phase()~="Running" or data.status~="Running" or data.recovering
    or not data.humanoid or data.humanoid.Health<=0 then
    clear(player,s)
   else
    syncFreeze(player,s)
    if s.superUntil and now>=s.superUntil then
     s.superUntil=nil data.superUntil=nil player:SetAttribute("GBloxSuperspeedUntil",nil)
     context.SetSpeed(data,(data.normalBoostUntil or 0)>now and context.BoostMultiplier or 1)
    end
    if s.antiUntil and now>=s.antiUntil then
     s.antiUntil=nil data.antispikeUntil=nil data.antispikeRound=nil player:SetAttribute("GBloxAntispikeUntil",nil)
    end
    if not s.frozenUntil and not s.superUntil and not s.antiUntil then states[player]=nil end
   end
  end
 end
 function self.Remove(player) local s=states[player] if s then clear(player,s) end end
 return self
end
return M


]=],
["GBloxGravitySwitch"]=[=[local Rules=require(game.ReplicatedStorage:WaitForChild("GBloxAbilityRules"))
local Platforms=require(script.Parent:WaitForChild("GBloxPlatBeGone"))
local Effects=require(script.Parent:WaitForChild("GBloxAbilityEffects"))
local Service={}
function Service.new(context)
 local cooldowns={}
 local roundUses={}
 local effects=Effects.new(context)
 local self={}
 function self.Activate(player)
  local now=context.Now()
  local actor=context.Runners[player]
  if context.Phase()~="Running" or not Rules.Eligible(actor) then return false,"Use your ability while racing." end
  local id=player:GetAttribute("GBloxEquippedAbility")
  local definition=Rules.Definitions[id]
  if not definition then return false,"Equip an available ability in the lobby." end
  if now<(cooldowns[player] or 0) then return false,definition.Name.." is cooling down.",cooldowns[player] end
  if definition.OncePerRound and roundUses[player]==context.RoundKey() then return false,"Already used this round." end
  local targets={}
  local platform
  if id=="GravitySwitch" or id=="Freeze" then
   for other,data in context.Runners do
    if other~=player and Rules.Eligible(data) then table.insert(targets,other) end
   end
   if #targets==0 and not context.Practice then return false,"No other active racers to affect." end
  elseif id=="PlatBeGone" then
   platform=Platforms.Find(context.Course(),actor.root.Position)
   if not platform then return false,"No available platform in the zone behind you." end
  end
  -- Reserve and apply without yielding, so racing requests cannot double-spend.
  local ok,message=context.Reserve(player,id)
  if not ok then return false,message end
  cooldowns[player]=now+definition.Cooldown
  player:SetAttribute("GBloxAbilityCooldownUntil",cooldowns[player])
  player:SetAttribute("GBloxAbilityActiveThisGame",true)
  if id=="PlatBeGone" then Platforms.Hide(platform,3)
  elseif id=="GravitySwitch" then for _,other in targets do context.Flip(other) end
  elseif id=="Freeze" then for _,other in targets do effects.Freeze(other,5) end
  elseif id=="Antispike" then effects.Antispike(player,7)
  elseif id=="Superspeed" then
   roundUses[player]=context.RoundKey()
   player:SetAttribute("GBloxAbilityUsedRound",context.RoundKey())
   effects.Superspeed(player,context.BoostSeconds)
  end
  if context.OnUsed then context.OnUsed(player) end
  context.Announce(player.DisplayName.." used "..definition.Name)
  return true,definition.Name.." used!",cooldowns[player]
 end
 function self.FreezeSeasonal(player,seconds) return effects.FreezeSeasonal(player,seconds) end
 function self.ClearSeasonalFreeze(player) effects.ClearSeasonalFreeze(player) end
 function self.Step() effects.Step() end
 function self.Remove(player) cooldowns[player]=nil roundUses[player]=nil effects.Remove(player) end
 return self
end
return Service


]=],
["GBloxHalloweenService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Service = {}

local defaults = {
 Enabled = true,
 PollInterval = 0.1,
 WebHoldSeconds = 5,
 WebCooldown = 30,
 WebLifetime = 8,
 WebRadius = 7,
 WebMaxActive = 6,
 CornerWebHoldSeconds = 5,
 CornerWebImmunity = 3,
 GraveStuckSeconds = 1,
 GraveHoldSeconds = 5,
 GraveStillRadius = 0.75,
 GraveStillSpeed = 2.5,
 GhostInitialDelay = 8,
 GhostBaseSpeed = 24,
 GhostMaxSpeed = 60,
 GhostSpeedIncrease = 1.1,
 GhostSpeedInterval = 1.1,
 GhostSpawnBehind = 22,
 GhostCatchRadius = 3.2,
 PumpkinCooldown = 10,
 PumpkinRange = 70,
 PumpkinSpeed = 70,
 PumpkinLifetime = 2,
 PumpkinHitRadius = 3,
 PumpkinSplatSeconds = 3,
}

local limits = {
 PollInterval = {0.1, 0.5},
 WebHoldSeconds = {0.5, 10},
 WebCooldown = {1, 120},
 WebLifetime = {1, 20},
 WebRadius = {2, 12},
 WebMaxActive = {1, 12},
 CornerWebHoldSeconds = {0.5, 10},
 CornerWebImmunity = {0.5, 15},
 GraveStuckSeconds = {0.5, 5},
 GraveHoldSeconds = {1, 10},
 GraveStillRadius = {0.1, 2},
 GraveStillSpeed = {0.5, 5},
 GhostInitialDelay = {2, 30},
 GhostBaseSpeed = {5, 60},
 GhostMaxSpeed = {5, 100},
 GhostSpeedIncrease = {0, 5},
 GhostSpeedInterval = {0.5, 10},
 GhostSpawnBehind = {12, 50},
 GhostCatchRadius = {1, 5},
 PumpkinCooldown = {1, 120},
 PumpkinRange = {10, 100},
 PumpkinSpeed = {20, 100},
 PumpkinLifetime = {0.5, 4},
 PumpkinHitRadius = {1, 4},
 PumpkinSplatSeconds = {0.5, 5},
}

local function validNumber(value)
 return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function destroy(instance)
 if instance then instance:Destroy() end
end

local function pivot(instance, cframe)
 if instance:IsA("Model") then instance:PivotTo(cframe)
 elseif instance:IsA("BasePart") then instance.CFrame = cframe end
end

local function assetPivot(instance)
 if instance:IsA("Model") then return instance:GetPivot() end
 return instance.CFrame
end

local function assetSize(instance)
 if instance:IsA("Model") then
  local _, size = instance:GetBoundingBox()
  return size
 end
 return instance.Size
end

local function visibleClone(source, name, parent, maximumSize, centered)
 if not source or (not source:IsA("Model") and not source:IsA("BasePart")) then return nil end
 local clone = source:Clone()
 clone.Name = name
 clone:SetAttribute("HalloweenRestHidden", nil)
 local parts = clone:GetDescendants()
 if clone:IsA("BasePart") then table.insert(parts, clone) end
 for _, object in parts do
  if object:IsA("BasePart") then
   object.Anchored = true
   object.CanCollide = false
   object.CanTouch = false
   object.CanQuery = false
   object.CastShadow = false
   object:SetAttribute("HalloweenRestHidden", nil)
   local visible = object:GetAttribute("HalloweenVisibleTransparency")
   if validNumber(visible) then object.Transparency = math.clamp(visible, 0, 1) end
  elseif object:IsA("Script") or object:IsA("LocalScript") then
   object:Destroy()
  end
 end
 if maximumSize then
  local size = assetSize(clone)
  local largest = math.max(size.X, size.Y, size.Z)
  if largest > 0.01 then
   local scale = maximumSize / largest
   if clone:IsA("Model") then clone:ScaleTo(clone:GetScale() * scale)
   else clone.Size *= scale end
  end
 end
 if centered and clone:IsA("Model") then
  local center = clone:GetBoundingBox()
  local rotation = assetPivot(clone).Rotation
  clone.PrimaryPart = nil
  clone.WorldPivot = CFrame.new(center.Position) * rotation
 end
 clone.Parent = parent
 return clone
end

local function frameAt(position, sign)
 return CFrame.lookAt(position, position - Vector3.xAxis, Vector3.new(0, sign, 0))
end

local function contains(sensor, data)
 local collider = data.collider or data.root
 local half = collider.Size * 0.5
 local colliderFrame = sensor.CFrame:ToObjectSpace(collider.CFrame)
 local right, up, back = colliderFrame.RightVector, colliderFrame.UpVector, colliderFrame.ZVector
 local extent = Vector3.new(
  math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
  math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
  math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
 )
 local offset = sensor.CFrame:PointToObjectSpace(data.root.Position)
 local bounds = sensor.Size * 0.5 + extent
 return math.abs(offset.X) <= bounds.X and math.abs(offset.Y) <= bounds.Y and math.abs(offset.Z) <= bounds.Z
end

local function segmentDistanceSquared(point, from, to)
 local delta = to - from
 local lengthSquared = delta:Dot(delta)
 local alpha = lengthSquared > 0.0001 and math.clamp((point - from):Dot(delta) / lengthSquared, 0, 1) or 0
 local offset = point - (from + delta * alpha)
 return offset:Dot(offset)
end

function Service.new(context)
 local self = {}
 local runtime
 local activeRound
 local activeCourse
 local activeSince
 local previousRound
 local spentRound
 local clock = 0
 local ghost
 local webs = {}
 local projectiles = {}
 local traps = {}
 local holds = {}
 local frozen = {}
 local cooldowns = {}
 local lastRequest = {}
 local nextId = 0
 local raycast = RaycastParams.new()
 raycast.FilterType = Enum.RaycastFilterType.Include
 raycast.RespectCanCollide = true

 local function setting(name)
  local value = context.Settings and context.Settings:GetAttribute(name)
  if name == "Enabled" then return value ~= false end
  if not validNumber(value) then value = defaults[name] end
  local bounds = limits[name]
  return bounds and math.clamp(value, bounds[1], bounds[2]) or value
 end

 local function enabled()
  local theme = ReplicatedStorage:FindFirstChild("GBloxCourseTheme")
  return setting("Enabled") and theme and theme:GetAttribute("ActiveTheme") == "Halloween"
   and context.CourseNumber() == 1 and context.Phase() == "Running"
 end

 local function validRunner(player, data, allowFrozen)
  if not data or context.Runners[player] ~= data or player.Parent ~= Players
   or data.status ~= "Running" or data.recovering or data.courseVersion ~= context.RoundKey()
   or not data.character or data.character ~= player.Character
   or not data.root or not data.root.Parent or not data.root:IsDescendantOf(data.character)
   or not data.humanoid or data.humanoid.Health <= 0
   or (data.invulnerableUntil or 0) > context.Now() then return false end
  if not allowFrozen and (data.root.Anchored or (data.freezeUntil or 0) > context.Now()) then return false end
  return data.gravitySign == 1 or data.gravitySign == -1
 end

 local function source(name)
  return context.Templates and context.Templates:FindFirstChild(name)
 end

 local function allocateId()
  nextId += 1
  return nextId
 end

 local function makeRuntime()
  if runtime and runtime.Parent then return runtime end
  runtime = Instance.new("Folder")
  runtime.Name = "GBloxHalloweenRuntime"
  runtime:SetAttribute("CourseVersion", context.RoundKey())
  runtime.Parent = Workspace
  return runtime
 end

 local function clearFreeze(player)
  if not frozen[player] then return end
  frozen[player] = nil
  if context.ClearFreeze then context.ClearFreeze(player) end
  player:SetAttribute("GBloxHalloweenTrappedUntil", nil)
 end

 local function freeze(player, data, seconds)
  local untilTime = context.Now() + seconds
  local acceptedUntil = context.Freeze(player, seconds)
  if validNumber(acceptedUntil) then untilTime = acceptedUntil end
  frozen[player] = {data = data, root = data.root, round = context.RoundKey(), untilTime = untilTime}
  player:SetAttribute("GBloxHalloweenTrappedUntil", untilTime)
  return untilTime
 end

 local function clearHold(player)
  local hold = holds[player]
  if not hold then return end
  holds[player] = nil
  destroy(hold.hand)
  player:SetAttribute("GBloxHalloweenGraveUntil", nil)
 end

 local function supportHit(data)
  if not activeCourse or not activeCourse.Parent then return nil end
  raycast.FilterDescendantsInstances = {activeCourse}
  local up = Vector3.new(0, data.gravitySign, 0)
  local result = Workspace:Raycast(data.root.Position, -up * 6.5, raycast)
  if not result or result.Normal:Dot(up) < 0.9 then return nil end
  if context.IsPlatform then
   if not context.IsPlatform(result.Instance) then return nil end
  elseif result.Instance.Name ~= "Flat_Platform_RunSurface" and not result.Instance:IsA("SpawnLocation") then
   return nil
  end
  return result
 end

 local function trapGrounded(trap, data)
  local sign = trap.model:GetAttribute("SurfaceNormalY")
  if sign and sign ~= data.gravitySign then return false end
  local hit = supportHit(data)
  if not hit then return false end
  local reference = trap.model:FindFirstChild("Support")
  local support = reference and reference:IsA("ObjectValue") and reference.Value
  return not support or hit.Instance == support or hit.Instance:IsDescendantOf(support)
 end

 local function loadTraps()
  traps = {}
  local gameplay = activeCourse and activeCourse:FindFirstChild("HalloweenGameplay")
  local folder = gameplay and gameplay:FindFirstChild("Traps")
  if not folder then return end
  for _, model in folder:GetChildren() do
   local kind = model:GetAttribute("TrapType")
   local sensor = model:FindFirstChild("Sensor")
   if (kind == "CornerWeb" or kind == "Grave") and sensor and sensor:IsA("BasePart") then
    table.insert(traps, {model = model, sensor = sensor, kind = kind, dwell = {}, immune = {}})
   end
  end
 end

 local function begin()
  activeRound = context.RoundKey()
  activeCourse = context.Course()
  activeSince = context.Now()
  makeRuntime()
  loadTraps()
 end

 local function animateHand(hold, now)
  if not hold.hand or not hold.hand.Parent then return end
  local rise = math.clamp((now - hold.startedAt) / 0.6, 0, 1)
  local sink = math.clamp((now - (hold.untilTime - 0.7)) / 0.7, 0, 1)
  local up = Vector3.new(0, hold.sign, 0)
  local handFrame = frameAt(hold.position - up * (0.35 + (1 - rise) * 3 + sink * 3), hold.sign)
   * CFrame.new(-hold.palmOffset)
  pivot(hold.hand, handFrame)
  local curl = math.clamp((now - hold.startedAt - 0.3) / 0.6, 0, 1)
  for _, finger in hold.fingers do
   if finger.model.Parent then
    finger.model:PivotTo(handFrame * finger.localPivot * CFrame.Angles(math.rad(finger.degrees) * curl, 0, 0))
   end
  end
 end

 local function captureGrave(trap, player, data, now)
  local nested = trap.model:FindFirstChild("ZombieHand")
  local hand = visibleClone(nested or source("Zombie_Hand"), "GraveGrab_" .. player.UserId, makeRuntime(), 5.5)
  local hold = {
   data = data, root = data.root, round = activeRound, sign = data.gravitySign,
   position = data.root.Position, startedAt = now, untilTime = now + setting("GraveHoldSeconds"),
   hand = hand, fingers = {}, palmOffset = Vector3.zero,
  }
  if hand and hand:IsA("Model") then
   local handFrame = assetPivot(hand)
   local palm = hand:FindFirstChild("Halloween_Palm", true)
   if palm and palm:IsA("BasePart") then hold.palmOffset = handFrame:PointToObjectSpace(palm.Position) end
   for _, object in hand:GetDescendants() do
    if object:IsA("Model") and (object.Name:match("^Finger%d+$") or object.Name == "Thumb") then
     local degrees = object:GetAttribute("CurlDegrees")
     table.insert(hold.fingers, {model = object, localPivot = handFrame:ToObjectSpace(object:GetPivot()), degrees = validNumber(degrees) and degrees or -55})
    end
   end
  end
  holds[player] = hold
  trap.dwell[player] = nil
  freeze(player, data, setting("GraveHoldSeconds"))
  player:SetAttribute("GBloxHalloweenGraveUntil", hold.untilTime)
  animateHand(hold, now)
  context.Broadcast("GraveGrab", {
   userId = player.UserId, position = hold.position, gravitySign = hold.sign,
   startedAt = now, untilTime = hold.untilTime, roundKey = activeRound,
  })
 end

 local function stepHolds(now)
  for player, hold in holds do
   if not validRunner(player, hold.data, true) or hold.root ~= hold.data.root
    or hold.round ~= activeRound or hold.sign ~= hold.data.gravitySign then
    clearHold(player)
    clearFreeze(player)
   elseif now >= hold.untilTime then
    clearHold(player)
    clearFreeze(player)
    context.Eliminate(player, "A zombie hand pulled you into the grave")
   else
    animateHand(hold, now)
   end
  end
 end

 local function stepTraps(now)
  for _, trap in traps do
   if not trap.model.Parent or not trap.sensor.Parent then continue end
   for player, data in context.Runners do
    local inTrap = validRunner(player, data, false) and not holds[player]
     and contains(trap.sensor, data) and trapGrounded(trap, data)
    if trap.kind == "CornerWeb" then
     if inTrap and now >= (trap.immune[player] or 0) then
      local seconds = setting("CornerWebHoldSeconds")
      trap.immune[player] = now + seconds + setting("CornerWebImmunity")
      freeze(player, data, seconds)
     end
    elseif not inTrap then
     trap.dwell[player] = nil
    else
     local dwell = trap.dwell[player]
     local radius = setting("GraveStillRadius")
     local stationary = data.root.AssemblyLinearVelocity.Magnitude <= setting("GraveStillSpeed")
     if not stationary or not dwell or dwell.root ~= data.root or dwell.sign ~= data.gravitySign
      or (data.root.Position - dwell.position).Magnitude > radius then
      trap.dwell[player] = stationary and {root = data.root, sign = data.gravitySign, since = now, position = data.root.Position} or nil
     elseif now - dwell.since >= setting("GraveStuckSeconds") then
      captureGrave(trap, player, data, now)
     end
    end
   end
  end
 end

 local function removeWeb(id)
  local web = webs[id]
  if web then webs[id] = nil destroy(web.model) end
 end

 local function stepWebs(now)
  for id, web in webs do
   if now >= web.untilTime or not web.model.Parent or not web.support.Parent then
    removeWeb(id)
   else
    local moved = web.support.CFrame * web.localFrame
    pivot(web.model, moved)
    web.frame = moved
    for player, data in context.Runners do
     if player ~= web.owner and not web.victims[player] and validRunner(player, data, false)
      and data.gravitySign == web.sign and not holds[player] then
      local position = web.frame:PointToObjectSpace(data.root.Position)
      if position.X * position.X + position.Z * position.Z <= web.radius * web.radius
       and position.Y >= 1 and position.Y <= 5.5 then
       local hit = supportHit(data)
       if hit and hit.Instance == web.support then
        web.victims[player] = true
        freeze(player, data, setting("WebHoldSeconds"))
       end
      end
     end
    end
   end
  end
 end

 local function leastProgress()
  local selectedPlayer, selectedData, selectedProgress
  for player, data in context.Runners do
   if validRunner(player, data, true) then
    local progress = context.Progress(data)
    if validNumber(progress) and (not selectedPlayer or progress < selectedProgress
     or (progress == selectedProgress and player.UserId < selectedPlayer.UserId)) then
     selectedPlayer, selectedData, selectedProgress = player, data, progress
    end
   end
  end
  return selectedPlayer, selectedData
 end

 local function stepGhost(now, dt)
  if spentRound == activeRound or now - activeSince < setting("GhostInitialDelay") then return end
  local player, data = leastProgress()
  if not player then destroy(ghost and ghost.model) ghost = nil return end
  if not ghost then
   local model = visibleClone(source("Ghost"), "LastPlaceGhost", makeRuntime(), 8, true)
   if not model then return end
   ghost = {model = model, position = data.root.Position + Vector3.xAxis * setting("GhostSpawnBehind")}
  end
  local elapsed = math.max(0, now - activeSince - setting("GhostInitialDelay"))
  local speed = math.min(setting("GhostMaxSpeed"), setting("GhostBaseSpeed")
   + math.floor(elapsed / setting("GhostSpeedInterval")) * setting("GhostSpeedIncrease"))
  local targetPosition = data.root.Position
  local previousPosition = ghost.position
  local offset = targetPosition - previousPosition
  local distance = offset.Magnitude
  if distance > 0.001 then ghost.position += offset.Unit * math.min(speed * dt, distance) end
  ghost.model:SetAttribute("TargetUserId", player.UserId)
  ghost.model:SetAttribute("Speed", speed)
  pivot(ghost.model, frameAt(ghost.position, data.gravitySign))
  local radius = setting("GhostCatchRadius")
  if segmentDistanceSquared(targetPosition, previousPosition, ghost.position) <= radius * radius then
   spentRound = activeRound
   destroy(ghost.model)
   ghost = nil
   clearHold(player)
   clearFreeze(player)
   context.Eliminate(player, "The ghost caught the last racer")
  end
 end

 local function removeProjectile(id)
  local projectile = projectiles[id]
  if projectile then projectiles[id] = nil destroy(projectile.model) end
 end

 local function stepProjectiles(now, dt)
  for id, projectile in projectiles do
   local data = projectile.data
   if now >= projectile.untilTime or not validRunner(projectile.target, data, true)
    or data.root ~= projectile.root or projectile.round ~= activeRound
    or data.gravitySign ~= projectile.sign or not projectile.model.Parent then
    removeProjectile(id)
   else
    local targetPosition = data.root.Position
    local previousPosition = projectile.position
    local offset = targetPosition - previousPosition
    if offset.Magnitude > 0.001 then
     projectile.position += offset.Unit * math.min(setting("PumpkinSpeed") * dt, offset.Magnitude)
    end
    pivot(projectile.model, frameAt(projectile.position, projectile.sign) * CFrame.Angles(0, 0, (now - projectile.startedAt) * 8))
    local radius = setting("PumpkinHitRadius")
    local relativeFrom = previousPosition - projectile.lastTargetPosition
    local relativeTo = projectile.position - targetPosition
    if segmentDistanceSquared(Vector3.zero, relativeFrom, relativeTo) <= radius * radius then
     context.Send(projectile.target, "PumpkinSplat", {
      duration = setting("PumpkinSplatSeconds"), sourceUserId = projectile.owner.UserId, roundKey = activeRound,
     })
     removeProjectile(id)
    else
     projectile.lastTargetPosition = targetPosition
    end
   end
  end
 end

 local function activateWeb(player, data, now)
  local count = 0
  for _, web in webs do
   count += 1
   if web.owner == player then return false, "Your previous web is still active." end
  end
  if count >= math.floor(setting("WebMaxActive")) then return false, "Too many webs are active. Try again shortly." end
  local hit = supportHit(data)
  if not hit then return false, "Place the web while touching a platform." end
  local frame = frameAt(hit.Position + hit.Normal * 0.12, data.gravitySign)
  local model = visibleClone(source("Trap_Web"), "PlayerWeb_" .. player.UserId, makeRuntime(), setting("WebRadius") * 2)
  if not model then return false, "The web artwork is not ready." end
  pivot(model, frame)
  model:SetAttribute("OwnerUserId", player.UserId)
  model:SetAttribute("ExpiresAt", now + setting("WebLifetime"))
  webs[allocateId()] = {
   model = model, owner = player, support = hit.Instance, localFrame = hit.Instance.CFrame:ToObjectSpace(frame),
   frame = frame, sign = data.gravitySign, radius = setting("WebRadius"), victims = {},
   untilTime = now + setting("WebLifetime"),
  }
  return true, "Web placed!", now + setting("WebCooldown")
 end

 local function activatePumpkin(player, data, now)
  local count = 0
  for _, projectile in projectiles do
   count += 1
   if projectile.owner == player then return false, "Your previous pumpkin is still flying." end
  end
  if count >= 12 then return false, "Too many pumpkins are flying. Try again shortly." end
  local target, targetData, nearest
  local range = setting("PumpkinRange")
  for other, otherData in context.Runners do
   if other ~= player and validRunner(other, otherData, true) and otherData.gravitySign == data.gravitySign
    and otherData.root.Position.X < data.root.Position.X - 0.1 then
    local distance = (otherData.root.Position - data.root.Position).Magnitude
    if distance <= range and (not nearest or distance < nearest
     or (distance == nearest and other.UserId < target.UserId)) then
     target, targetData, nearest = other, otherData, distance
    end
   end
  end
  if not target then return false, "No racer ahead is in pumpkin range." end
  local model = visibleClone(source("Throwable_Pumpkin"), "ThrownPumpkin_" .. player.UserId, makeRuntime(), 2.5, true)
  if not model then return false, "The pumpkin artwork is not ready." end
  local position = data.root.Position - Vector3.xAxis * 2
  pivot(model, frameAt(position, data.gravitySign))
  projectiles[allocateId()] = {
   owner = player, target = target, data = targetData, root = targetData.root, sign = targetData.gravitySign,
   round = activeRound, model = model, position = position, lastTargetPosition = targetData.root.Position,
   startedAt = now, untilTime = now + setting("PumpkinLifetime"),
  }
  return true, "Pumpkin thrown!", now + setting("PumpkinCooldown")
 end

 function self:Activate(player, action)
  if action ~= "Web" and action ~= "Pumpkin" then return false, "Unknown Halloween ability." end
  local now = context.Now()
  if now - (lastRequest[player] or -math.huge) < 0.15 then return false, "Please wait a moment." end
  lastRequest[player] = now
  if not enabled() or activeRound ~= context.RoundKey() then return false, "Halloween abilities are available in Halloween Course 1." end
  local data = context.Runners[player]
  if not validRunner(player, data, false) or holds[player] then return false, "You cannot use that ability right now." end
  local state = cooldowns[player] or {}
  cooldowns[player] = state
  if now < (state[action] or 0) then return false, "That ability is cooling down.", state[action] end
  local ok, message, untilTime
  if action == "Web" then ok, message, untilTime = activateWeb(player, data, now)
  else ok, message, untilTime = activatePumpkin(player, data, now) end
  if ok then
   state[action] = untilTime
   player:SetAttribute("GBloxHalloween" .. action .. "CooldownUntil", untilTime)
   if context.OnUsed then context.OnUsed(player) end
  end
  return ok, message, untilTime
 end

 function self:Remove(player)
  clearHold(player)
  clearFreeze(player)
  for id, web in webs do if web.owner == player then removeWeb(id) end end
  for id, projectile in projectiles do
   if projectile.owner == player or projectile.target == player then removeProjectile(id) end
  end
  for _, trap in traps do trap.dwell[player] = nil trap.immune[player] = nil end
  if player.Parent ~= Players then cooldowns[player] = nil lastRequest[player] = nil end
 end

 function self:Clear()
  local hadActiveRound = activeRound
  activeRound = nil
  activeCourse = nil
  activeSince = nil
  clock = 0
  for player in holds do clearHold(player) end
  for player in frozen do clearFreeze(player) end
  for player in cooldowns do
   player:SetAttribute("GBloxHalloweenWebCooldownUntil", nil)
   player:SetAttribute("GBloxHalloweenPumpkinCooldownUntil", nil)
  end
  cooldowns = {}
  lastRequest = {}
  holds = {}
  frozen = {}
  webs = {}
  projectiles = {}
  traps = {}
  ghost = nil
  destroy(runtime)
  runtime = nil
  if hadActiveRound then context.Broadcast("HalloweenClear", {roundKey = hadActiveRound}) end
 end

 function self:Step(dt)
  if not validNumber(dt) or dt <= 0 then return end
  local round = context.RoundKey()
  if previousRound ~= round then
   self:Clear()
   previousRound = round
   spentRound = nil
  end
  if not enabled() then
   if activeRound then self:Clear() end
   return
  end
  if activeRound ~= round or activeCourse ~= context.Course() then
   self:Clear()
   begin()
  end
  clock += math.min(dt, 0.5)
  if clock < setting("PollInterval") then return end
  local elapsed = math.min(clock, 0.25)
  clock = 0
  local now = context.Now()
  for player, entry in frozen do
   if now >= entry.untilTime or entry.round ~= activeRound or not validRunner(player, entry.data, true)
    or entry.root ~= entry.data.root then clearFreeze(player) end
  end
  stepHolds(now)
  if not activeRound or not enabled() or activeRound ~= context.RoundKey() then return end
  stepTraps(now)
  stepWebs(now)
  stepProjectiles(now, elapsed)
  stepGhost(now, elapsed)
 end

 return self
end

Service.Defaults = defaults
return Service

]=],
["GBloxHalloweenAppearance"]=[=[local ReplicatedStorage=game:GetService("ReplicatedStorage")
local settings=ReplicatedStorage:WaitForChild("GBloxHalloweenSettings")
local theme=ReplicatedStorage:WaitForChild("GBloxCourseTheme")
local root=workspace:WaitForChild(" Course -  round 1"):WaitForChild("HalloweenGameplay")
local parts={}
local lights={}
local function register(instance)
 if instance:IsA("BasePart") then
  local visible=instance:GetAttribute("HalloweenVisibleTransparency")
  if typeof(visible)~="number" then visible=instance.Transparency end
  parts[instance]=visible
 elseif instance:IsA("Light") then
  local visible=instance:GetAttribute("HalloweenVisibleEnabled")
  lights[instance]=visible~=false
 end
end
for _,instance in root:GetDescendants() do register(instance) end
local function appearance()
 local visible=settings:GetAttribute("Enabled")==true and theme:GetAttribute("ActiveTheme")=="Halloween"
 for part,transparency in parts do
  if part.Parent then part.Transparency=(visible and not part:GetAttribute("HalloweenRestHidden")) and transparency or 1 else parts[part]=nil end
 end
 for light,enabled in lights do
  if light.Parent then light.Enabled=visible and enabled else lights[light]=nil end
 end
end
root.DescendantAdded:Connect(function(instance) register(instance) appearance() end)
settings:GetAttributeChangedSignal("Enabled"):Connect(appearance)
theme:GetAttributeChangedSignal("ActiveTheme"):Connect(appearance)
appearance()
local keys={
 "Enabled",
 "PollInterval",
 "WebHoldSeconds",
 "WebCooldown",
 "WebLifetime",
 "WebRadius",
 "WebMaxActive",
 "CornerWebHoldSeconds",
 "CornerWebImmunity",
 "GraveStuckSeconds",
 "GraveHoldSeconds",
 "GraveStillRadius",
 "GraveStillSpeed",
 "GhostInitialDelay",
 "GhostBaseSpeed",
 "GhostMaxSpeed",
 "GhostSpeedIncrease",
 "GhostSpeedInterval",
 "GhostSpawnBehind",
 "GhostCatchRadius",
 "PumpkinCooldown",
 "PumpkinRange",
 "PumpkinSpeed",
 "PumpkinLifetime",
 "PumpkinHitRadius",
 "PumpkinSplatSeconds",
}
local snapshot
local pending=false
local connection
local function applySnapshot()
 if not snapshot or settings:GetAttribute("UsePublishedConfig")~=true then return end
 if workspace:GetAttribute("RunnerRoundPhase")=="Running" then pending=true return end
 pending=false
 for _,name in keys do
  local ok,value=pcall(function() return snapshot:GetValue("GBloxHalloween."..name) end)
  if ok and value~=nil then
   local current=settings:GetAttribute(name)
   if typeof(value)==typeof(current) and (typeof(value)~="number" or (value==value and math.abs(value)<math.huge)) then
    settings:SetAttribute(name,value)
   end
  end
 end
end
local function loadPublished()
 if settings:GetAttribute("UsePublishedConfig")~=true or snapshot then return end
 task.spawn(function()
  local ok,result=pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
  if not ok then
   warn("[GBloxHalloween] Published config unavailable; using Studio attributes.")
   return
  end
  snapshot=result
  connection=snapshot.UpdateAvailable:Connect(function()
   local refreshed=pcall(function() snapshot:Refresh() end)
   if refreshed then applySnapshot() end
  end)
  applySnapshot()
 end)
end
settings:GetAttributeChangedSignal("UsePublishedConfig"):Connect(loadPublished)
workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(function()
 if pending then applySnapshot() end
end)
script.Destroying:Connect(function() if connection then connection:Disconnect() end end)
loadPublished()


]=],
["HalloweenController"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent
local controls = gui:WaitForChild("Controls")
local splat = gui:WaitForChild("PumpkinSplat")
local artwork = splat:WaitForChild("Artwork")
local fallback = splat:WaitForChild("Fallback")
local status = controls:WaitForChild("Status")
local buttons = {Web = controls:WaitForChild("Web"), Pumpkin = controls:WaitForChild("Pumpkin")}
local remote = ReplicatedStorage:WaitForChild("GBloxHalloweenEvent", 10)
local theme = ReplicatedStorage:WaitForChild("GBloxCourseTheme", 10)
local settings = ReplicatedStorage:WaitForChild("GBloxHalloweenSettings", 10)

if not remote or not remote:IsA("RemoteEvent") or not theme or not settings then
	controls.Visible = false
	splat.Visible = false
	warn("Halloween Course 1 controls could not find their seasonal service")
	return
end

local connections = {}
local alive = true
local clockConnection
local clockAccumulator = 0
local active = false
local currentRound = player:GetAttribute("RunnerCourseVersion")
local currentCharacter = player.Character
local pending = {}
local resultCooldown = {}
local lastRequest = -math.huge
local splatUntil = 0
local graveUntil = 0
local messageUntil = 0
local message = ""
local actionNames = {Web = "GBloxHalloweenPlaceWeb", Pumpkin = "GBloxHalloweenThrowPumpkin"}
local cooldownAttributes = {Web = "GBloxHalloweenWebCooldownUntil", Pumpkin = "GBloxHalloweenPumpkinCooldownUntil"}
local refresh
local updateClock

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function serverTime()
	return workspace:GetServerTimeNow()
end

local function available()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then return false end
	return gui.Enabled
		and settings:GetAttribute("Enabled") == true
		and theme:GetAttribute("ActiveTheme") == "Halloween"
		and player:GetAttribute("RunnerCourseNumber") == 1
		and player:GetAttribute("RunnerStatus") == "Running"
end

local function cooldownUntil(action)
	local attribute = player:GetAttribute(cooldownAttributes[action])
	local result = resultCooldown[action]
	return math.max(finite(attribute) and attribute or 0, finite(result) and result or 0)
end

local function updateArtwork()
	fallback.Visible = gui:GetAttribute("FallbackSplatEnabled") ~= false and (artwork.Image == "" or not artwork.IsLoaded)
end

local function clearTransient()
	pending = {}
	resultCooldown = {}
	splatUntil = 0
	graveUntil = 0
	messageUntil = 0
	message = ""
	splat.Visible = false
	status.Text = ""
end

local function updateButtons(now)
	for action, button in pairs(buttons) do
		local requestExpiry = pending[action]
		if requestExpiry and now >= requestExpiry then
			pending[action] = nil
			message = "NO RESPONSE — TRY AGAIN"
			messageUntil = now + 2
		end
		local remaining = math.max(0, cooldownUntil(action) - now)
		button.Cooldown.Text = remaining > 0 and (tostring(math.ceil(remaining)) .. "s") or (pending[action] and "..." or "READY")
		button.Active = active and remaining <= 0 and not pending[action]
		button.AutoButtonColor = button.Active
	end
end

local function ensureClock()
	local needed = alive and (active or splat.Visible)
	if needed and not clockConnection then
		clockAccumulator = 0
		clockConnection = RunService.Heartbeat:Connect(function(delta)
			clockAccumulator += delta
			if clockAccumulator >= 0.1 then
				clockAccumulator = 0
				updateClock()
			end
		end)
	elseif not needed and clockConnection then
		clockConnection:Disconnect()
		clockConnection = nil
	end
end

updateClock = function()
	if not alive then return end
	if not available() then
		refresh()
		return
	end
	local now = serverTime()
	updateButtons(now)
	if splat.Visible and now >= splatUntil then splat.Visible = false end
	if graveUntil > now then
		status.Text = "ZOMBIE GRAB · " .. tostring(math.ceil(graveUntil - now)) .. "s"
	else
		status.Text = now < messageUntil and message or ""
	end
	ensureClock()
end

refresh = function()
	if not alive then return end
	local round = player:GetAttribute("RunnerCourseVersion")
	local character = player.Character
	local nextActive = available()
	if round ~= currentRound or character ~= currentCharacter or (active and not nextActive) then
		clearTransient()
	end
	currentRound = round
	currentCharacter = character
	active = nextActive
	controls.Visible = active
	if not active then splat.Visible = false end
	updateButtons(serverTime())
	ensureClock()
end

local function request(action)
	if not alive or not active or not available() or UserInputService:GetFocusedTextBox() then return end
	local now = serverTime()
	if now - lastRequest < 0.15 or pending[action] or cooldownUntil(action) > now then return end
	lastRequest = now
	pending[action] = now + 2
	updateButtons(now)
	remote:FireServer(action)
end

for action, button in pairs(buttons) do
	connect(button.Activated, function() request(action) end)
end

local function bind(action, keys)
	ContextActionService:BindActionAtPriority(actionNames[action], function(_, inputState)
		if not active or not available() or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then request(action) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(keys))
end
bind("Web", {Enum.KeyCode.V, Enum.KeyCode.ButtonL1})
bind("Pumpkin", {Enum.KeyCode.B, Enum.KeyCode.ButtonR1})

connect(remote.OnClientEvent, function(kind, packet)
	if not alive or typeof(packet) ~= "table" or not active or not available() then return end
	if kind == "HalloweenClear" then
		if packet.roundKey ~= nil and packet.roundKey ~= currentRound then return end
		clearTransient()
		updateClock()
		return
	end
	if packet.roundKey ~= currentRound then return end
	local now = serverTime()
	if kind == "HalloweenResult" then
		local action = packet.action
		if not buttons[action] then return end
		pending[action] = nil
		if finite(packet.cooldownUntil) then resultCooldown[action] = packet.cooldownUntil end
		if typeof(packet.message) == "string" then
			message = string.sub(packet.message, 1, 100)
			messageUntil = now + 2.5
		end
		updateClock()
	elseif kind == "PumpkinSplat" then
		local duration = finite(packet.duration) and math.clamp(packet.duration, 0, 5) or 3
		splatUntil = math.max(splatUntil, now + duration)
		splat.Visible = duration > 0
		updateArtwork()
		ensureClock()
	elseif kind == "GraveGrab" and packet.userId == player.UserId then
		graveUntil = finite(packet.untilTime) and math.clamp(packet.untilTime, now, now + 6) or now + 5
		updateClock()
	end
end)

for _, attribute in ipairs({"RunnerCourseNumber", "RunnerCourseVersion", "RunnerStatus", "GBloxHalloweenWebCooldownUntil", "GBloxHalloweenPumpkinCooldownUntil"}) do
	connect(player:GetAttributeChangedSignal(attribute), refresh)
end
connect(player.CharacterAdded, refresh)
connect(player.CharacterRemoving, function()
	clearTransient()
	active = false
	controls.Visible = false
	ensureClock()
end)
connect(settings:GetAttributeChangedSignal("Enabled"), refresh)
connect(theme:GetAttributeChangedSignal("ActiveTheme"), refresh)
connect(gui:GetPropertyChangedSignal("Enabled"), refresh)
connect(gui:GetAttributeChangedSignal("FallbackSplatEnabled"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("Image"), updateArtwork)
connect(artwork:GetPropertyChangedSignal("IsLoaded"), updateArtwork)

connect(script.Destroying, function()
	alive = false
	if clockConnection then clockConnection:Disconnect() clockConnection = nil end
	for _, name in pairs(actionNames) do ContextActionService:UnbindAction(name) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	clearTransient()
	controls.Visible = false
end)

updateArtwork()
refresh()

]=],
}
for name,src in pairs(sources) do local chunk,err=loadstring(src,"Check_"..name) assert(chunk,err) end
local uiBuilderSource=[=[local function build(parent)
	assert(parent and parent:IsA("StarterGui"), "A StarterGui parent is required")
	assert(not parent:FindFirstChild("GBloxHalloweenControls"), "GBloxHalloweenControls already exists")
	local gui = Instance.new("ScreenGui")
	gui.Name = "GBloxHalloweenControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 45
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("FallbackSplatEnabled", true)
	gui:SetAttribute("Purpose", "Free seasonal Course 1 controls; upload your orange splat to PumpkinSplat.Artwork.Image")

	local function make(class, name, owner, properties)
		local object = Instance.new(class)
		object.Name = name
		for key, value in pairs(properties or {}) do object[key] = value end
		object.Parent = owner
		return object
	end
	local function corner(owner, radius)
		make("UICorner", "Corner", owner, {CornerRadius = UDim.new(0, radius)})
	end
	local function label(name, owner, text, position, size, colour)
		return make("TextLabel", name, owner, {
			BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
			Position = position, Size = size, Text = text, Font = Enum.Font.Arcade,
			TextSize = 12, TextColor3 = colour or Color3.fromRGB(223, 251, 255),
			TextStrokeColor3 = Color3.fromRGB(5, 21, 29), TextStrokeTransparency = 0.5,
			TextWrapped = true, ZIndex = 3,
		})
	end

	local controls = make("Frame", "Controls", gui, {
		Position = UDim2.new(0, 16, 0.28, 0), Size = UDim2.fromOffset(116, 160),
		BackgroundColor3 = Color3.fromRGB(10, 31, 42), BackgroundTransparency = 0.18,
		BorderSizePixel = 0, Visible = false, Active = false,
	})
	corner(controls, 10)
	make("UIStroke", "Outline", controls, {Color = Color3.fromRGB(20, 166, 181), Thickness = 1.5, Transparency = 0.15})
	label("Heading", controls, "HALLOWEEN", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 18), Color3.fromRGB(255, 183, 76))

	local function ability(name, y, title, key, info)
		local button = make("TextButton", name, controls, {
			Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(100, 40),
			BackgroundColor3 = Color3.fromRGB(17, 87, 105), BorderSizePixel = 0,
			Text = "", AutoButtonColor = true, Selectable = true,
			Active = true, ZIndex = 2,
		})
		corner(button, 8)
		make("UIStroke", "Outline", button, {Color = Color3.fromRGB(33, 212, 220), Thickness = 1})
		label("Caption", button, title, UDim2.fromOffset(4, 3), UDim2.new(1, -8, 0, 14))
		local keyLabel = label("Key", button, key, UDim2.fromOffset(4, 17), UDim2.new(1, -8, 0, 10), Color3.fromRGB(255, 197, 123))
		keyLabel.TextSize = 10
		local cooldown = label("Cooldown", button, "READY", UDim2.fromOffset(4, 27), UDim2.new(1, -8, 0, 11))
		cooldown.TextSize = 10
		local help = label(name .. "Help", controls, info, UDim2.fromOffset(8, y + 41), UDim2.fromOffset(100, 17))
		help.TextSize = 10
		return button
	end
	local web = ability("Web", 24, "PLACE WEB", "V / L1", "TRAP 5s · CD 30s")
	local pumpkin = ability("Pumpkin", 82, "PUMPKIN", "B / R1", "THROW · SPLAT 3s")
	web.NextSelectionDown = pumpkin
	pumpkin.NextSelectionUp = web
	local status = label("Status", controls, "", UDim2.fromOffset(8, 140), UDim2.new(1, -16, 0, 18), Color3.fromRGB(255, 197, 123))
	status.TextSize = 10

	local splat = make("Frame", "PumpkinSplat", gui, {
		Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
		Visible = false, ZIndex = 70,
	})
	local fallback = make("Frame", "Fallback", splat, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.58, 0.65), BackgroundTransparency = 1,
		BorderSizePixel = 0, Active = false, ZIndex = 70,
	})
	make("UIAspectRatioConstraint", "Aspect", fallback, {AspectRatio = 1.25})
	local blobs = {
		{0.50, 0.50, 0.70, 0.65, -8}, {0.26, 0.27, 0.38, 0.38, 14},
		{0.75, 0.34, 0.40, 0.35, -18}, {0.67, 0.76, 0.38, 0.40, 12},
		{0.24, 0.70, 0.35, 0.35, -24}, {0.10, 0.44, 0.12, 0.16, 5},
		{0.87, 0.68, 0.15, 0.12, -8}, {0.48, 0.10, 0.13, 0.14, 0},
	}
	for i, blob in ipairs(blobs) do
		local part = make("Frame", "Splat" .. i, fallback, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(blob[1], blob[2]),
			Size = UDim2.fromScale(blob[3], blob[4]), Rotation = blob[5],
			BackgroundColor3 = Color3.fromRGB(239, 108, 24), BackgroundTransparency = 0.12,
			BorderSizePixel = 0, Active = false, ZIndex = 70,
		})
		make("UICorner", "Corner", part, {CornerRadius = UDim.new(0.5, 0)})
	end
	make("ImageLabel", "Artwork", splat, {
		Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit,
		Active = false, ZIndex = 71,
	})
	local splatNotice = label("Notice", splat, "PUMPKIN SPLAT", UDim2.new(0.5, -130, 0.77, 0), UDim2.fromOffset(260, 28), Color3.fromRGB(255, 235, 208))
	splatNotice.TextSize = 17
	splatNotice.ZIndex = 72
	gui.Parent = parent
	return gui
end

return build

]=]
local uiChunk,uiError=loadstring(uiBuilderSource,"BuildHalloweenUI")
assert(uiChunk,uiError)
assert(not game.ReplicatedStorage:FindFirstChild("GBloxHalloweenSettings"))
assert(not game.ReplicatedStorage:FindFirstChild("GBloxHalloweenEvent"))
assert(not game.ServerScriptService:FindFirstChild("GBloxHalloweenService"))
assert(not game.ServerScriptService:FindFirstChild("GBloxHalloweenAppearance"))
assert(not game.StarterGui:FindFirstChild("GBloxHalloweenControls"))
local settings=Instance.new("Folder")
settings.Name="GBloxHalloweenSettings"
settings:SetAttribute([=[Enabled]=],true)
settings:SetAttribute([=[UsePublishedConfig]=],false)
settings:SetAttribute([=[PollInterval]=],0.1)
settings:SetAttribute([=[WebHoldSeconds]=],5)
settings:SetAttribute([=[WebCooldown]=],30)
settings:SetAttribute([=[WebLifetime]=],8)
settings:SetAttribute([=[WebRadius]=],7)
settings:SetAttribute([=[WebMaxActive]=],6)
settings:SetAttribute([=[CornerWebHoldSeconds]=],5)
settings:SetAttribute([=[CornerWebImmunity]=],3)
settings:SetAttribute([=[GraveStuckSeconds]=],1)
settings:SetAttribute([=[GraveHoldSeconds]=],5)
settings:SetAttribute([=[GraveStillRadius]=],0.75)
settings:SetAttribute([=[GraveStillSpeed]=],2.5)
settings:SetAttribute([=[GhostInitialDelay]=],8)
settings:SetAttribute([=[GhostBaseSpeed]=],24)
settings:SetAttribute([=[GhostMaxSpeed]=],60)
settings:SetAttribute([=[GhostSpeedIncrease]=],1.1)
settings:SetAttribute([=[GhostSpeedInterval]=],1.1)
settings:SetAttribute([=[GhostSpawnBehind]=],22)
settings:SetAttribute([=[GhostCatchRadius]=],3.2)
settings:SetAttribute([=[PumpkinCooldown]=],10)
settings:SetAttribute([=[PumpkinRange]=],70)
settings:SetAttribute([=[PumpkinSpeed]=],70)
settings:SetAttribute([=[PumpkinLifetime]=],2)
settings:SetAttribute([=[PumpkinHitRadius]=],3)
settings:SetAttribute([=[PumpkinSplatSeconds]=],3)
settings:SetAttribute("CourseNumber",1)
settings:SetAttribute("BuildVersion","20261003-1")
settings.Parent=game.ReplicatedStorage
local remote=Instance.new("RemoteEvent")
remote.Name="GBloxHalloweenEvent"
remote.Parent=game.ReplicatedStorage
local function install(class,name,src,parent)
 local script=Instance.new(class)
 script.Name=name
 script.Source=src
 script.Parent=parent
 return script
end
install("ModuleScript","GBloxHalloweenService",sources.GBloxHalloweenService,game.ServerScriptService)
install("Script","GBloxHalloweenAppearance",sources.GBloxHalloweenAppearance,game.ServerScriptService)
local builder=uiChunk()
local ui=builder(game.StarterGui)
install("LocalScript","Controller",sources.HalloweenController,ui)
for _,name in ipairs({"GBloxAbilityEffects","GBloxGravitySwitch","RunnerServer"}) do
 es:UpdateSourceAsync(game.ServerScriptService[name],function(current)
  assert(current==backup[name.."_Source"].Value,"Source changed during update: "..name)
  return sources[name]
 end)
end
backup:SetAttribute("Installed",true)
game:GetService("ChangeHistoryService"):SetWaypoint("Course 1 Halloween gameplay installed")
return game.HttpService:JSONEncode({placeId=game.PlaceId,settings=settings:GetFullName(),ui=ui:GetFullName(),modifiedScripts=3,newScripts=3,published=false,playtestStarted=false})
