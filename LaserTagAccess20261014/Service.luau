local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local TEAM_COLORS = { Red = Color3.fromRGB(255, 66, 85), Blue = Color3.fromRGB(65, 165, 255) }

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

local function managedGun(tool)
 return tool:IsA("Tool") and (tool.Name=="MudGun" or tool.Name=="HeatGun")
  and (tool:GetAttribute("MDManaged")==true or tool:GetAttribute("ManagedMudTemplate")==true)
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

function Service:_setting(name,fallback,minimum,maximum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then value=fallback end
 return math.clamp(value,minimum or 0,maximum or math.huge)
end
function Service:_phase(value)
	self.phase = value
	attribute(self.state, "Phase", value)
end

function Service.TeamAssignments(count)
 count = math.clamp(math.floor(count), 0, 60)
 if count < 2 then return {}, 0 end
 local result, offset = {}, count % 2 == 1 and math.random(0, 1) or 0
 for index=1,count do result[index]=(index-1+offset)%2+1 end
 return result, 2
end
function Service:_chooseTeamColors()
 self.teamCount, self.teamColors = 2, {"Red", "Blue"}
end
function Service:_colorName(team)
 return team == 2 and "Blue" or "Red"
end
function Service.ChooseTimeoutTeams(active, survivors, lives)
 local winners, bestAlive, bestLives = {}, -1, -1
 for _, team in ipairs(active) do
  local count, hearts = survivors[team] or 0, lives[team] or 0
  if count > 0 then
   if count > bestAlive or count == bestAlive and hearts > bestLives then
    winners, bestAlive, bestLives = {team}, count, hearts
   elseif count == bestAlive and hearts == bestLives then table.insert(winners,team) end
  end
 end
 table.sort(winners)
 return winners
end
function Service:_timeoutWinners()
 local active, _, survivors, lives = self:_teams(false)
 return Service.ChooseTimeoutTeams(active,survivors,lives)
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
	local ring = math.floor((index - 1) / #pads)
	if ring > 0 then
		local angle = ring * 2.4
		position += Vector3.new(math.cos(angle), 0, math.sin(angle)) * (4 * ring)
	end
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record,cframe)
 if not record.root or not record.root.Parent or not record.character then return end
 if record.humanoid then record.humanoid.Sit=false end
 record.character:PivotTo(cframe*record.root.CFrame:Inverse()*record.character:GetPivot())
 record.root.AssemblyLinearVelocity,record.root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 if record.frozen then record.lockedCFrame=record.root.CFrame end
end
function Service:_spectatorCFrame(record)
 local pads=parts(self.gameplay:FindFirstChild("SpectatorSpawns"))
 if #pads>0 then return pads[((record.spectatorIndex or record.spawnIndex or 1)-1)%#pads+1].CFrame end
 if self.lobbySpawn and self.lobbySpawn.Parent then return self.lobbySpawn.CFrame+Vector3.new(0,self.lobbySpawn.Size.Y/2+3,0) end
 return self.bounds.CFrame*CFrame.new(0,self.bounds.Size.Y/2+6,0)
end
function Service:_publishRecord(record)
 local colorName = record.participating and self:_colorName(record.teamId) or ""
 for name,value in pairs({
  MDParticipating=record.participating, MDTeamId=record.teamId or 0,
  MDTeamColorName=colorName, MDTeamColor=TEAM_COLORS[colorName] or Color3.new(1,1,1),
  MDTeamName=colorName~="" and colorName.." Team" or "",
  MDLives=record.lives or 0, MDMuddy=false, MDEliminated=record.eliminated==true,
  MDRescueProgress=0, MDHeatActive=false, MDHeatTargetUserId=0, MDHeatProgress=0,
  MDSprintMax=record.sprintMax or 0, MDSprintRemaining=math.floor((record.sprintRemaining or 0)*10)/10,
  MDSprinting=record.sprinting==true, MDSprintExhausted=record.sprintExhausted==true,
  MDFireReadyAt=record.fireReadyAt or 0
 }) do attribute(record.player,name,value) end
 local tool=record.participating and not record.eliminated and record.character and record.character:FindFirstChildOfClass("Tool")
 attribute(record.player,"MDTool",tool and managedGun(tool) and tool.Name or "")
end
function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_role(record)
 self:_publishRecord(record)
 if not record.character or not record.character.Parent then return end
 for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record,part) end
 if not record.participating then return end
 local outline=record.character:FindFirstChild("MDOutline")
 if not outline then
  outline=Instance.new("Highlight") outline.Name,outline.Adornee="MDOutline",record.character
  outline.FillTransparency,outline.OutlineTransparency=1,0
  outline.DepthMode=Enum.HighlightDepthMode.Occluded outline.Parent=record.character
 end
 outline.OutlineColor=TEAM_COLORS[self:_colorName(record.teamId)]
 outline.Enabled=not record.eliminated
 local label=record.character:FindFirstChild("MDLivesDisplay")
 local assets=ReplicatedStorage:FindFirstChild("MudAssets")
 local template=assets and assets:FindFirstChild("LaserLivesTemplate")
 if not label and template and template:IsA("BillboardGui") then
  label=template:Clone() label.Name="MDLivesDisplay"
  label.Adornee=record.character:FindFirstChild("Head") or record.root
  label.Enabled=true label.Parent=record.character
 end
 if label then
  for index=1,3 do
   local heart=label:FindFirstChild("Heart"..index,true)
   if heart and heart:IsA("TextLabel") then
    heart.Text=(record.lives or 0)>=index and "♥" or "♡"
    heart.TextColor3=(record.lives or 0)>=index and Color3.fromRGB(255,82,97) or Color3.fromRGB(105,109,128)
   end
  end
  local team=label:FindFirstChild("TeamName",true)
  if team and team:IsA("TextLabel") then team.Text=record.eliminated and "OUT" or self:_colorName(record.teamId):upper()
   team.TextColor3=record.eliminated and Color3.fromRGB(210,214,225) or TEAM_COLORS[self:_colorName(record.teamId)] end
 end
 local torso=record.isBot and record.character:FindFirstChild("Torso")
 if torso then torso.Color=TEAM_COLORS[self:_colorName(record.teamId)] end
end
function Service:_movement(record)
 if not record.participating or not alive(record) then return end
 local h=record.humanoid
 if not record.originalMovement then record.originalMovement={WalkSpeed=h.WalkSpeed,JumpPower=h.JumpPower,JumpHeight=h.JumpHeight,AutoRotate=h.AutoRotate} end
 local multiplier=not record.frozen and not record.eliminated and record.sprinting and (record.sprintRemaining or 0)>0
  and workspace:GetServerTimeNow()<(record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier",2.5,1,3) or 1
 h.WalkSpeed=record.frozen and 0 or self:_setting("BaseSpeed",16,0,30)*multiplier
 h.JumpPower=record.frozen and 0 or record.originalMovement.JumpPower
 h.JumpHeight=record.frozen and 0 or record.originalMovement.JumpHeight
 h.AutoRotate=not record.frozen and record.originalMovement.AutoRotate
 if record.frozen then record.lockedCFrame=record.lockedCFrame or record.root.CFrame h.Jump=false end
end
function Service:_freeze(record, frozen)
 record.frozen=frozen
 if frozen then record.sprintHeld,record.sprinting=false,false else record.lockedCFrame=nil end
 self:_movement(record)
end
function Service:_toolsAllowed(record)
 return not record.isBot and self.active and record.participating and not record.eliminated and alive(record)
  and record.player.Character==record.character and (record.teamId==1 or record.teamId==2)
  and not record.player:GetAttribute("BBParticipating") and not record.player:GetAttribute("TGParticipating")
  and not record.player:GetAttribute("HSParticipating") and not record.player:GetAttribute("DGParticipating")
  and not record.player:GetAttribute("SKParticipating")
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
				or tool:GetAttribute("MDRound") ~= self.roundNumber or tool:GetAttribute("MDOwnerUserId") ~= record.player.UserId
				or tool:GetAttribute("MDTeamId") ~= record.teamId or tool.Name ~= (record.teamId==1 and "HeatGun" or "MudGun") then
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
 local backpack=record.player:FindFirstChild("Backpack")
 local assets=ReplicatedStorage:FindFirstChild("MudAssets")
 local name=record.teamId==1 and "HeatGun" or "MudGun"
 local template=assets and assets:FindFirstChild(name)
 if not backpack or not template or not template:IsA("Tool") then return end
 record.humanoid:UnequipTools()
 local tool=template:Clone()
 tool:SetAttribute("MDManaged",true) tool:SetAttribute("MDRound",self.roundNumber)
 tool:SetAttribute("MDOwnerUserId",record.player.UserId) tool:SetAttribute("MDTeamId",record.teamId)
 tool.CanBeDropped=false tool.Enabled=true
 table.insert(record.managedTools,tool) tool.Parent=backpack
 record.humanoid:EquipTool(tool)
 self:_publishRecord(record)
end
function Service:_restore(record)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating", "MDLivesDisplay" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, lives = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
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
		if record.participating then self:_eliminate(record, "Reset") end
		record.ready = false
		self:_destroyTools(record)
	end))
	if record.participating then
		self:_eliminate(record, "Reset")
		self:_teleport(record, self:_spectatorCFrame(record))
		self:_freeze(record, self.phase ~= "Playing") self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			if record.participating then self:_eliminate(record, "Reset") end
			record.ready = false
			self:_destroyTools(record)
		end
	end))
	local function watchContainer(container)
		if container:IsA("Backpack") or container.Name == "StarterGear" then self:_watchTools(record, container, record.connections) end
	end
	table.insert(record.connections, player.ChildAdded:Connect(watchContainer))
	for _, container in ipairs(player:GetChildren()) do watchContainer(container) end
	for _, name in ipairs({ "BBParticipating", "TGParticipating", "HSParticipating", "DGParticipating", "SKParticipating" }) do
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
 local result,included={},{}
 for _,player in ipairs(selected or Players:GetPlayers()) do
  local record=self.records[player]
  if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
   and not record.participating and player:GetAttribute("PCDataReady")==true
   and not player:GetAttribute("PCAFK") and not player:GetAttribute("PCAFKRequested")
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
   and not player:GetAttribute("HSParticipating") and not player:GetAttribute("DGParticipating")
   and not player:GetAttribute("DGEliminated") and not player:GetAttribute("SKParticipating")
   and not player:GetAttribute("SKEliminated") then included[player]=true table.insert(result,player) end
 end
 table.sort(result,function(a,b)return a.UserId<b.UserId end)
 return result
end
function Service:_teams(mark)
 local totals,free,lives={0,0},{0,0},{0,0}
 for _,record in pairs(self.records) do
  if record.participating and (record.isBot or record.player.Parent==Players) then
   local team=record.teamId
   totals[team]+=1
   if not record.eliminated and (record.lives or 0)>0 and alive(record) then free[team]+=1 lives[team]+=record.lives end
  end
 end
 local active={}
 for team=1,2 do
  self.eliminatedTeams[team]=totals[team]>0 and free[team]==0
  if free[team]>0 then table.insert(active,team) end
 end
 if mark and self.active and self.phase=="Playing" and self.pendingWinners==nil and #active<=1 then self.pendingWinners=table.clone(active) end
 local summary={}
 for team=1,2 do
  local name=self:_colorName(team)
  attribute(self.state,"Team"..team.."Members",totals[team])
  attribute(self.state,"Team"..team.."Free",free[team])
  attribute(self.state,"Team"..team.."Alive",free[team])
  attribute(self.state,"Team"..team.."Lives",lives[team])
  attribute(self.state,name.."Alive",free[team])
  table.insert(summary,{teamId=team,name=name.." Team",colorName=name,alive=free[team],free=free[team],
   total=totals[team],lives=lives[team],originalTotal=self.originalTeamSizes[team] or 0,eliminated=free[team]==0})
 end
 attribute(self.state,"TeamSummaryJSON",HttpService:JSONEncode(summary))
 attribute(self.state,"TeamCount",2) attribute(self.state,"ActiveTeamCount",#active)
 attribute(self.state,"ParticipantCount",totals[1]+totals[2])
 attribute(self.state,"MuddyCount",0) attribute(self.state,"EliminatedCount",totals[1]+totals[2]-free[1]-free[2])
 return active,totals,free,lives
end
function Service:_eliminate(record, reason)
 if not record or not record.participating or record.eliminated then return false end
 record.lives,record.eliminated,record.muddy=0,true,false
 record.sprintHeld,record.sprinting,record.sprintLeaseEndsAt=false,false,0
 self:_destroyTools(record) self:_freeze(record,false)
 attribute(record.player,"MDOutReason",reason or "Laser")
 attribute(record.player,"MDResult","Out")
 if alive(record) then self:_teleport(record,self:_spectatorCFrame(record)) end
 self:_role(record) self:_teams(true)
 return true
end
function Service:_laserHit(target,shooter)
 local now=workspace:GetServerTimeNow()
 if not self.active or self.phase~="Playing" or self.pendingWinners~=nil or now>=self.endsAt
  or not target or not shooter or target==shooter or not target.participating or target.eliminated
  or not shooter.participating or shooter.eliminated or target.teamId==shooter.teamId
  or not alive(target) or not alive(shooter) then return false end
 target.lives=math.max(0,(target.lives or 3)-1)
 attribute(target.player,"MDLastHitAt",now)
 if target.lives==0 then self:_eliminate(target,"Laser") else self:_role(target) self:_teams(true) end
 return true
end
function Service:_canAct(record,now)
 return self.active and self.phase=="Playing" and self.pendingWinners==nil and now<self.endsAt
  and record and record.participating and not record.eliminated and (record.lives or 0)>0
  and not record.frozen and alive(record)
end
function Service:_equipped(record,kind)
 local expected=record.teamId==1 and "Heat" or "Mud"
 if kind~=expected then return nil end
 if record.isBot then return true end
 if not self:_toolsAllowed(record) then return nil end
 local name=kind=="Heat" and "HeatGun" or "MudGun"
 for _, tool in ipairs(record.character:GetChildren()) do
  if managedGun(tool) and tool.Name==name and tool:GetAttribute("MDManaged")==true
   and tool:GetAttribute("MDRound")==self.roundNumber and tool:GetAttribute("MDOwnerUserId")==record.player.UserId
   and tool:GetAttribute("MDTeamId")==record.teamId and tool:GetAttribute("GunKind")==kind and tool.Enabled then return tool end
 end
 return nil
end
function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns", "SpectatorSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
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
	if (cameraOrigin - head.Position).Magnitude > 32 then return nil end
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

function Service:_fire(record,aim,now)
 if not self:_canAct(record,now) or now<(record.fireReadyAt or 0) then return false end
 local kind=record.teamId==1 and "Heat" or "Mud"
 local unit,origin=self:_resolveAim(record,kind,aim)
 if not unit or not origin then return false end
 local pulse=Instance.new("Part")
 pulse.Name,pulse.Size="LaserPulse",Vector3.new(0.32,0.32,2.4)
 pulse.Material,pulse.Color=Enum.Material.Neon,TEAM_COLORS[self:_colorName(record.teamId)]
 pulse.Anchored,pulse.CanCollide,pulse.CanTouch,pulse.CanQuery=true,false,false,false
 pulse.CastShadow=false pulse.CFrame=CFrame.lookAt(origin,origin+unit)
 pulse:SetAttribute("MDTeamId",record.teamId) pulse.Parent=self:_effects()
 table.insert(self.projectiles,{part=pulse,position=origin,direction=unit,
  speed=self:_setting("ProjectileSpeed",150,50,250),remaining=self:_setting("LaserRange",200,30,300),
  source=record,teamId=record.teamId,token=self.currentRound})
 record.fireReadyAt=now+self:_setting("LaserCooldownSeconds",0.65,0.25,2)
 self:_publishRecord(record)
 return true
end
function Service:_tickProjectiles(dt)
 for index=#self.projectiles,1,-1 do
  local shot=self.projectiles[index]
  local remove=shot.token~=self.currentRound or self.phase~="Playing" or not self.active or self.pendingWinners~=nil
   or not shot.source.participating or shot.source.eliminated or not alive(shot.source)
  if not remove then
   local length=math.min(shot.remaining,shot.speed*math.clamp(dt,0,0.5))
   local vector=shot.direction*length
   local hit=workspace:Spherecast(shot.position,0.2,vector,self:_rayParameters(shot.source,false))
   if hit then
    local target=self:_hitRecord(hit.Instance)
    if target then self:_laserHit(target,shot.source) end
    remove=true
   else
    shot.position+=vector shot.remaining-=length
    shot.part.CFrame=CFrame.lookAt(shot.position,shot.position+shot.direction)
    remove=shot.remaining<=0
   end
  end
  if remove then if shot.part.Parent then shot.part:Destroy() end table.remove(self.projectiles,index) end
 end
end
function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	local draining = record.sprintHeld and record.sprintRemaining > 0 and speed > 1
	if draining then
		record.sprintRemaining = math.max(0, record.sprintRemaining - dt)
	else
		record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt)
	end
	record.sprintExhausted = record.sprintRemaining <= 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and speed > 1
	self:_movement(record)
	self:_publishRecord(record)
end

function Service:_action(record,action,value)
 if action=="Sprint" and value==false then
  record.sprintHeld,record.sprinting=false,false
  if record.participating then self:_movement(record) end
  self:_publishRecord(record) return {ok=true}
 end
 if action~="Sprint" and action~="Fire" and action~="Equip" then return {ok=false,message="Unknown laser tag action."} end
 local now=workspace:GetServerTimeNow()
 if now-(record.requests[action] or -math.huge)<0.08 then return {ok=false,message="Slow down."} end
 record.requests[action]=now
 if not self:_canAct(record,now) then return {ok=false,message="Wait until you can play."} end
 if action=="Equip" then
  local name=record.teamId==1 and "HeatGun" or "MudGun"
  if value~=name or not self:_toolsAllowed(record) then return {ok=false,message="Use your team blaster."} end
  local equipped=self:_equipped(record,record.teamId==1 and "Heat" or "Mud")
  if equipped then return {ok=true} end
  local backpack=record.player:FindFirstChild("Backpack")
  for _,tool in ipairs(backpack and backpack:GetChildren() or {}) do
   if managedGun(tool) and tool.Name==name and tool:GetAttribute("MDManaged")==true
    and tool:GetAttribute("MDOwnerUserId")==record.player.UserId and tool:GetAttribute("MDRound")==self.roundNumber
    and tool:GetAttribute("MDTeamId")==record.teamId and tool.Enabled then
    record.humanoid:EquipTool(tool) self:_publishRecord(record) return {ok=true}
   end
  end
  return {ok=false,message="Your team blaster is unavailable."}
 end
 if action=="Sprint" then
  if value~=true then return {ok=false,message="Invalid sprint."} end
  record.sprintHeld,record.sprintLeaseEndsAt=true,now+1
  self:_movement(record) return {ok=true}
 end
 local fired=self:_fire(record,value,now)
 return {ok=fired,message=fired and "Laser fired." or "Aim with your team blaster when it is ready."}
end
function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
 local point=self.bounds.CFrame:PointToObjectSpace(record.root.Position)
 local half=self.bounds.Size/2
 if record.eliminated then
  local viewing=self.gameplay:FindFirstChild("SpectatorBounds")
  local returned=math.abs(point.X)<half.X and math.abs(point.Z)<half.Z and math.abs(point.Y)<half.Y
  if viewing and viewing:IsA("BasePart") then
   local p=viewing.CFrame:PointToObjectSpace(record.root.Position)
   local h=viewing.Size/2
   returned=returned or math.abs(p.X)>h.X+3 or math.abs(p.Z)>h.Z+3 or p.Y < -h.Y-8
  end
  if returned then self:_teleport(record,self:_spectatorCFrame(record)) end
  return
 end
 local floor=self:_setting("FloorY",self.spawnPads[1].Position.Y-3.5,-10000)
 if math.abs(point.X)>half.X-3 or math.abs(point.Z)>half.Z-3 or record.root.Position.Y<floor-7 or math.abs(point.Y)>half.Y then
  self:_teleport(record,record.lastGoodCFrame or self:_spawn(record.spawnIndex,record.teamId))
 elseif record.humanoid.FloorMaterial~=Enum.Material.Air then record.lastGoodCFrame=record.root.CFrame end
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
 local opponent,distance
 for _,candidate in pairs(self.records) do
  if candidate~=bot and candidate.participating and not candidate.eliminated and candidate.teamId~=bot.teamId and alive(candidate) then
   local d=(candidate.root.Position-bot.root.Position).Magnitude
   if not distance or d<distance then opponent,distance=candidate,d end
  end
 end
 return opponent,distance
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
 for _,bot in pairs(self.records) do
  if bot.isBot and self:_canAct(bot,now) and now>=bot.nextBotMoveAt then
   bot.nextBotMoveAt=now+0.2
   local target,distance=self:_botTarget(bot)
   if target then
    local goal=target.root.Position
    local direct=not workspace:Raycast(bot.root.Position,goal-bot.root.Position,self:_rayParameters())
    if direct and distance<math.min(self:_setting("LaserRange",200,30,300)-10,90) then
     bot.humanoid:MoveTo(bot.root.Position)
     local interval=self:_setting("BotShotIntervalSeconds",4,0.8,15)
     bot.nextBotShotAt=bot.nextBotShotAt or now+interval*(0.6+bot.spawnIndex*0.3)
     if now>=bot.nextBotShotAt then
      local lead=math.min(distance/self:_setting("ProjectileSpeed",150,50,250),1)
      local head=bot.character:FindFirstChild("Head") or bot.root
      self:_fire(bot,goal+target.root.AssemblyLinearVelocity*lead-head.Position,now)
      bot.nextBotShotAt=now+interval
     end
    else self:_moveBot(bot,goal,now) end
   else bot.humanoid:MoveTo(bot.root.Position) end
  end
 end
end
function Service:_tick(dt)
 self.weaponCheckElapsed=(self.weaponCheckElapsed or 0)+dt
 if self.weaponCheckElapsed>=1 then self.weaponCheckElapsed=0 self:_refreshWeaponAccess() end
 if not self.active then return end
 local now=workspace:GetServerTimeNow()
 if self.phase=="Results" then if now>=self.resultsEndsAt then self:_cleanup(self.currentRound) end return end
 for _,record in pairs(self.records) do
  if record.participating then
   if not alive(record) then self:_eliminate(record,"Reset")
   elseif record.frozen and record.lockedCFrame then
    if (record.root.Position-record.lockedCFrame.Position).Magnitude>0.05 then self:_teleport(record,record.lockedCFrame) end
    record.root.AssemblyLinearVelocity,record.root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
    record.humanoid:Move(Vector3.zero)
   else self:_keepLegal(record) end
   self:_tickSprint(record,dt,now)
  end
 end
 if self.phase=="Countdown" then
  attribute(self.state,"CountdownValue",math.max(0,math.ceil(self.countdownEndsAt-now)))
  if now<self.countdownEndsAt then return end
  self.endsAt=now+300
  attribute(self.state,"EndsAt",self.endsAt) attribute(self.state,"CountdownValue",0)
  self:_phase("Playing")
  for _,record in pairs(self.records) do if record.participating then self:_freeze(record,false) end end
 end
 if self.phase~="Playing" then return end
 self:_teams(true)
 if self.pendingWinners~=nil then self:_results(self.currentRound,self.pendingWinners,#self.pendingWinners==0 and "NoActiveTeams" or "LastTeamStanding") return end
 if now>=self.endsAt then
  local winners=self:_timeoutWinners()
  self:_results(self.currentRound,winners,#winners>1 and "TimeoutShared" or #winners==0 and "NoActiveTeams" or "Timeout")
  return
 end
 self:_driveBots(now) self:_tickProjectiles(dt) self:_teams(true)
 if self.pendingWinners~=nil then self:_results(self.currentRound,self.pendingWinners,#self.pendingWinners==0 and "NoActiveTeams" or "LastTeamStanding") end
end
function Service:_results(token,winners,reason)
 if not self.active or self.currentRound~=token or self.phase=="Results" then return end
 local winnerSet,winnerIds,participantIds,names={},{},{},{}
 for _,team in ipairs(winners) do winnerSet[team]=true end
 for _,entry in ipairs(self.roundRoster) do
  if not entry.isBot then
   table.insert(participantIds,entry.userId)
   if winnerSet[entry.teamId] then table.insert(winnerIds,entry.userId) end
  end
 end
 for _,record in pairs(self.records) do
  if record.participating then
   self:_freeze(record,true) self:_destroyTools(record) self:_publishRecord(record)
   local won=winnerSet[record.teamId]==true
   attribute(record.player,"MDResult",won and "Won" or "Lost")
   if won then table.insert(names,record.player.DisplayName) end
  end
 end
 for _,shot in ipairs(self.projectiles) do if shot.part.Parent then shot.part:Destroy() end end
 table.clear(self.projectiles)
 table.sort(winnerIds) table.sort(participantIds) table.sort(names)
 attribute(self.state,"WinnerTeamIds",table.concat(winners,",")) attribute(self.state,"WinnerTeams",table.concat(winners,","))
 attribute(self.state,"WinnersText",table.concat(names,", ")) attribute(self.state,"ResultReason",reason)
 attribute(self.state,"LastResultWinnerIds",table.concat(winnerIds,",")) attribute(self.state,"LastResultParticipantIds",table.concat(participantIds,","))
 attribute(self.state,"LastResultPractice",self.mode~="Round") attribute(self.state,"LastResultRound",self.roundNumber)
 self.resultsEndsAt=workspace:GetServerTimeNow()+self:_setting("ResultsSeconds",7,0,15)
 attribute(self.state,"EndsAt",self.resultsEndsAt)
 self:_phase("Results")
end
function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do self:_destroyTools(record) end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.lives, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_begin(participants,mode,teams,owner)
 self.active,self.mode,self.practiceOwner=true,mode or "Round",owner
 self.currentRound={}
 self.roundNumber+=1
 self.eliminatedTeams,self.originalTeamSizes,self.roundRoster,self.pendingWinners={},{},{},nil
 self:_chooseTeamColors()
 attribute(self.state,"Mode",self.mode) attribute(self.state,"PracticeOwnerUserId",owner and owner.UserId or 0)
 attribute(self.state,"RoundNumber",self.roundNumber) attribute(self.state,"RoundDuration",300)
 attribute(self.state,"WinnersText","") attribute(self.state,"WinnerTeams","") attribute(self.state,"WinnerTeamIds","") attribute(self.state,"ResultReason","")
 local assignments=teams or Service.TeamAssignments(#participants)
 local slots={}
 for index,player in ipairs(participants) do
  local record=self.records[player]
  assert(record and assignments[index],"Participant was not ready")
  record.participating,record.teamId,record.lives,record.muddy,record.eliminated=true,assignments[index],3,false,false
  slots[record.teamId]=(slots[record.teamId] or 0)+1
  record.spawnIndex,record.spectatorIndex=slots[record.teamId],index
  self.originalTeamSizes[record.teamId]=(self.originalTeamSizes[record.teamId] or 0)+1
  table.insert(self.roundRoster,{userId=player.UserId,teamId=record.teamId,isBot=record.isBot})
  record.sprintMax=self:_setting("SprintSeconds",10,0.1,30) record.sprintRemaining=record.sprintMax
  record.sprintExhausted,record.sprintHeld,record.fireReadyAt=false,false,0
  record.rescueProgress,record.lastGoodCFrame,record.requests,record.nextBotShotAt=0,nil,{},nil
  attribute(player,"MDResult","") attribute(player,"MDOutReason","") attribute(player,"MDLastHitAt",0)
  local spawn=self:_spawn(record.spawnIndex,record.teamId)
  if teams then
   local practice=parts(self.gameplay:FindFirstChild("PracticeSpawns"))
   if #practice>0 then spawn=practice[(index-1)%#practice+1].CFrame end
  end
  self:_teleport(record,spawn) self:_freeze(record,true) self:_giveTools(record) self:_role(record)
 end
 self.countdownEndsAt=workspace:GetServerTimeNow()+self:_setting("CountdownSeconds",3,1,15)
 self.endsAt=0
 attribute(self.state,"EndsAt",self.countdownEndsAt)
 attribute(self.state,"CountdownValue",math.ceil(self.countdownEndsAt-workspace:GetServerTimeNow()))
 self:_phase("Countdown") self:_teams(false)
 return true
end
function Service:_weaponsReady()
	local ok, ready, reason = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		if not assets then return false, "Missing ReplicatedStorage.MudAssets." end
		for _, name in { "MudGun", "HeatGun" } do
			local tool = assets:FindFirstChild(name)
			if not tool or not tool:IsA("Tool") then return false, "Missing Tool: ReplicatedStorage.MudAssets." .. name end
			if not tool.Enabled then return false, "Disabled blaster: " .. name .. ". Enable its Tool template." end
		end
		return true
	end)
	if not ok then return false, "Laser Tag blasters: Access failed: " .. tostring(ready) end
	return ready == true, reason and ("Laser Tag blasters: " .. reason)
end

function Service:_refreshWeaponAccess()
	local ready, reason = self:_weaponsReady()
	reason = reason or ""
	attribute(self.state, "GunAccessError", reason)
	attribute(self.state, "GunAccessReady", ready)
	if not ready and reason ~= self.lastWeaponError then warn("Laser Tag: " .. reason) end
	self.lastWeaponError = reason
	return ready, reason
end

function Service:StartRound(selected)
 if not self.running then return false,"Service is not running" end
 if self.active then return false,"A round is already running" end
 local ready,reason=self:_refreshWeaponAccess()
 if not ready then return false,reason end
 local participants=self:_readyPlayers(selected)
 if #participants<2 then return false,"At least 2 ready players are needed." end
 for index=#participants,2,-1 do local other=self.random:NextInteger(1,index) participants[index],participants[other]=participants[other],participants[index] end
 local maximum=self:_setting("MaxPlayers",60,2,60)
 while #participants>maximum do table.remove(participants) end
 local ok,result=xpcall(function()return self:_begin(participants,"Round")end,debug.traceback)
 if not ok then self:_cleanup() warn("Laser Tag could not start: "..tostring(result)) return false,"Laser Tag could not prepare the round." end
 return result
end
function Service:StartPractice(player,role)
 if not self.running then return false,"Service is not running" end
 if self.active then return false,"A round is already running" end
 local team=(role=="Red" or role=="Shooter" or role=="Tagger") and 1 or (role=="Blue" or role=="Medic" or role=="Runner") and 2
 if not team then return false,"Choose Red or Blue practice." end
 local ready,reason=self:_refreshWeaponAccess()
 if not ready then return false,reason end
 local ready=self:_readyPlayers({player})
 if #ready~=1 then return false,"Your character is not ready." end
 local participants,teams={player},{team}
 local ok,result=xpcall(function()
  for index=1,3 do
   local botTeam=index==1 and team or 3-team
   local bot=self:_newBot(index,botTeam==1 and "Tagger" or "Runner")
   table.insert(participants,bot) table.insert(teams,botTeam)
  end
  return self:_begin(participants,team==1 and "PracticeRed" or "PracticeBlue",teams,player)
 end,debug.traceback)
 if not ok then self:_cleanup() warn("Laser Tag practice failed: "..tostring(result)) return false,"Practice could not be prepared." end
 return result
end
function Service:StopRound()
 if not self.active then return false,"No round is running" end
 attribute(self.state,"LastResultPractice",true)
 attribute(self.state,"LastResultWinnerIds","")
 self.currentRound=nil self:_cleanup()
 return true
end
function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", true)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, MudCooldownSeconds = self:_setting("LaserCooldownSeconds", 0.65, 0.25, 2), LaserCooldownSeconds = self:_setting("LaserCooldownSeconds", 0.65, 0.25, 2), RescueSeconds = 0, MinimumPlayers = 2, MaxPlayers = 60, DisplayName = "Laser Tag", ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	self:_refreshWeaponAccess()
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 local ok, failure = xpcall(function() self:_tick(math.min(elapsed, 0.25)) end, debug.traceback) if not ok then warn("Laser Tag round failed: "..tostring(failure)) self:_cleanup() end end end))
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

