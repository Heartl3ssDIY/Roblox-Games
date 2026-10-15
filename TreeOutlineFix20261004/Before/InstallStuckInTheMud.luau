local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Install Stuck in the Mud in Studio edit mode")
local approvedMudService=game:GetService("ServerScriptService"):FindFirstChild("StuckInTheMudService")
local requiredMudInput=SecurityCapabilities.new(Enum.SecurityCapability.Input)
assert(approvedMudService and approvedMudService:IsA("ModuleScript") and approvedMudService.Sandboxed and approvedMudService.Capabilities:Contains(requiredMudInput),"Installation pending explicit approval: StuckInTheMudService must receive Input through the normal approval mechanism first; this installer cannot grant it")
local sources={
 ["StuckInTheMudService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(66, 174, 255), Tagger = Color3.fromRGB(255, 105, 119) }
local COLOR_NAMES = { "Red", "Blue", "Green", "Black", "Yellow", "Purple", "Orange", "Teal", "Pink", "Lime", "Lavender", "Brown" }
local TEAM_COLORS = { Red = COLORS.Tagger, Blue = COLORS.Runner, Green = Color3.fromRGB(90, 210, 114), Black = Color3.fromRGB(44, 49, 64), Yellow = Color3.fromRGB(255, 201, 72), Purple = Color3.fromRGB(174, 98, 229), Orange = Color3.fromRGB(255, 156, 77), Teal = Color3.fromRGB(85, 220, 202), Pink = Color3.fromRGB(234, 144, 204), Lime = Color3.fromRGB(179, 215, 91), Lavender = Color3.fromRGB(150, 158, 246), Brown = Color3.fromRGB(166, 111, 77) }
local PREFERENCE_COLORS = { Red = true, Blue = true, Green = true, Black = true }

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

function Service:_setting(name, fallback, minimum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.max(minimum or 0, value)
end

function Service:_phase(value)
	self.phase = value
	attribute(self.state, "Phase", value)
end

function Service.TeamAssignments(count, requested, maximum)
	if count < 2 then return {}, 0 end
	local teamCount = math.clamp(math.max(math.floor(requested), math.ceil(count / math.max(2, math.floor(maximum)))), 2, math.min(count, #COLOR_NAMES))
	local result = {}
	for index = 1, count do result[index] = (index - 1) % teamCount + 1 end
	return result, teamCount
end

function Service:_chooseTeamColors()
	local used = {}
	self.teamColors = {}
	for team = 1, self.teamCount do
		local counts = {}
		for _, record in pairs(self.records) do
			if record.participating and record.teamId == team then
				local preference = record.player:GetAttribute("MDColorPreference")
				if PREFERENCE_COLORS[preference] then counts[preference] = (counts[preference] or 0) + 1 end
			end
		end
		local choice, votes
		for _, name in ipairs(COLOR_NAMES) do
			if not used[name] and (not votes or (counts[name] or 0) > votes) then choice, votes = name, counts[name] or 0 end
		end
		self.teamColors[team], used[choice] = choice, true
	end
end

function Service:_colorName(team)
	return self.teamColors[team] or COLOR_NAMES[(math.max(team or 1, 1) - 1) % #COLOR_NAMES + 1]
end

function Service.ChooseTimeoutTeams(active, free, original)
	local best, winners = -1, {}
	for _, team in ipairs(active) do
		local amount = free[team] or 0
		if amount > 0 then
			local score = amount / math.max(original[team] or 0, 1)
			if score > best + 0.000001 then best, winners = score, { team }
			elseif math.abs(score - best) <= 0.000001 then table.insert(winners, team) end
		end
	end
	table.sort(winners)
	return winners
end

function Service:_timeoutWinners()
	local active, _, free = self:_teams(true)
	return Service.ChooseTimeoutTeams(active, free, self.originalTeamSizes)
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
	local target = Vector3.new(self.bounds.Position.X, position.Y, self.bounds.Position.Z)
	if (target - position).Magnitude < 1 then target = position + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(position, target)
end

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_clearHeat(record, true)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_publishRecord(record)
	attribute(record.player, "MDParticipating", record.participating)
	attribute(record.player, "MDTeamId", record.teamId or 0)
	local colorName = record.participating and self:_colorName(record.teamId) or ""
	attribute(record.player, "MDTeamColorName", colorName)
	attribute(record.player, "MDTeamColor", TEAM_COLORS[colorName] or Color3.fromRGB(255, 255, 255))
	attribute(record.player, "MDTeamName", colorName ~= "" and colorName .. " Team" or "")
	attribute(record.player, "MDMuddy", record.muddy == true)
	attribute(record.player, "MDEliminated", record.eliminated == true)
	attribute(record.player, "MDRescueProgress", record.rescueProgress or 0)
	attribute(record.player, "MDSprintMax", record.sprintMax or 0)
	attribute(record.player, "MDSprintRemaining", math.floor((record.sprintRemaining or 0) * 10) / 10)
	attribute(record.player, "MDSprinting", record.sprinting == true)
	attribute(record.player, "MDSprintExhausted", record.sprintExhausted == true)
	attribute(record.player, "MDFireReadyAt", record.fireReadyAt or 0)
	attribute(record.player, "MDHeatActive", record.heatTarget ~= nil)
	attribute(record.player, "MDHeatTargetUserId", record.heatTarget and (record.heatTarget.player.UserId or 0) or 0)
	attribute(record.player, "MDHeatProgress", record.heatProgress or 0)
	local tool = record.participating and record.character and record.character:FindFirstChildOfClass("Tool")
	attribute(record.player, "MDTool", tool and tool:GetAttribute("MDManaged") and tool.Name or "")
end

function Service:_collision(record, part)
	if not record.participating or not part:IsA("BasePart") then return end
	if not record.originalGroups[part] then record.originalGroups[part] = part.CollisionGroup end
	part.CollisionGroup = "MudPlayer"
end

function Service:_mudVisual(record)
	local coating = record.character:FindFirstChild("MDMudCoating")
	if not record.muddy then if coating then coating:Destroy() end return end
	if coating then return end
	coating = Instance.new("Folder") coating.Name = "MDMudCoating" coating.Parent = record.character
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = record.character:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			local patch = Instance.new("Part") patch.Name = name == "Head" and "MudFaceMask" or "MudPatch"
			patch.Shape = Enum.PartType.Ball
			patch.Size = Vector3.new(math.max(0.3, body.Size.X * (name == "Head" and 0.75 or 0.7)), math.max(0.2, body.Size.Y * (name == "Head" and 0.3 or 0.37)), 0.18)
			patch.CFrame = body.CFrame * CFrame.new(name == "Head" and 0 or body.Size.X * (index % 2 == 0 and 0.1 or -0.1), body.Size.Y * (name == "Head" and -0.22 or -0.08), -body.Size.Z / 2 - 0.015)
			patch.Material = Enum.Material.SmoothPlastic patch.Color = index % 2 == 0 and Color3.fromRGB(114, 73, 43) or Color3.fromRGB(143, 95, 59)
			patch.Anchored, patch.Massless, patch.CanCollide, patch.CanTouch, patch.CanQuery = false, true, false, false, false
			patch.Parent = coating
			local weld = Instance.new("WeldConstraint") weld.Name = "MudWeld" weld.Part0, weld.Part1 = body, patch weld.Parent = patch
		end
	end
end

function Service:_role(record)
	self:_publishRecord(record)
	if not record.character or not record.character.Parent then return end
	for _, part in ipairs(record.character:GetDescendants()) do self:_collision(record, part) end
	if record.participating then
		local outline = record.character:FindFirstChild("MDOutline")
		if not outline then
			outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Adornee = record.character
			outline.FillTransparency = 1 outline.OutlineTransparency = 0 outline.DepthMode = Enum.HighlightDepthMode.Occluded outline.Parent = record.character
		end
		outline.OutlineColor = TEAM_COLORS[self:_colorName(record.teamId)]
		outline.FillColor = Color3.fromRGB(124, 83, 54)
		outline.FillTransparency = record.muddy and 0.55 or 1
		self:_mudVisual(record)
		local label = record.character:FindFirstChild("MDMuddyLabel")
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local template = assets and assets:FindFirstChild("MuddyTemplate")
		if record.muddy and not label and template then label = template:Clone() label.Name = "MDMuddyLabel" label.Adornee = record.character:FindFirstChild("Head") or record.root label.Enabled = true label.Parent = record.character
		elseif not record.muddy and label then label:Destroy() end
		local torso = record.isBot and record.character:FindFirstChild("Torso")
		if torso then torso.Color = record.muddy and Color3.fromRGB(124, 83, 54) or outline.OutlineColor end
	end
end

function Service:_movement(record)
	if not record.participating or not alive(record) then return end
	local humanoid = record.humanoid
	if not record.originalMovement then record.originalMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate } end
	local multiplier = not record.frozen and record.sprinting and not record.sprintExhausted and (record.sprintRemaining or 0) > 0 and workspace:GetServerTimeNow() < (record.sprintLeaseEndsAt or 0) and self:_setting("SprintMultiplier", 2.5, 1) or 1
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting("BaseSpeed", 16, 0) * multiplier
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
	if record.frozen then
		record.lockedCFrame = record.lockedCFrame or record.root.CFrame
		humanoid.Jump = false
		pcall(function() record.root:SetNetworkOwner(nil) end)
	elseif not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_freeze(record, frozen)
	record.frozen = frozen
	if frozen then record.sprintHeld = false record.sprinting = false self:_clearHeat(record, true) else record.lockedCFrame = nil end
	self:_movement(record)
end

function Service:_destroyTools(record)
	if record.isBot then return end
	for _, tool in ipairs(record.managedTools or {}) do if tool.Parent then tool:Destroy() end end
	record.managedTools = {}
end

function Service:_giveTools(record)
	if record.isBot or not alive(record) then return end
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	self:_destroyTools(record)
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone() tool:SetAttribute("MDManaged", true) tool:SetAttribute("MDRound", self.roundNumber) tool.Parent = backpack
			table.insert(record.managedTools, tool)
			if name == "MudGun" then first = tool end
		end
	end
	if first then record.humanoid:EquipTool(first) end
end

function Service:_restore(record)
	self:_clearHeat(record, true)
	record.sprintHeld, record.sprinting = false, false
	if record.originalMovement and record.humanoid and record.humanoid.Parent then for name, value in pairs(record.originalMovement) do record.humanoid[name] = value end end
	record.originalMovement, record.frozen, record.lockedCFrame = nil, false, nil
	for part, group in pairs(record.originalGroups) do if part.Parent then pcall(function() part.CollisionGroup = group end) end end
	table.clear(record.originalGroups)
	if record.character then for _, name in ipairs({ "MDOutline", "MDMuddyLabel", "MDMudCoating" }) do local object = record.character:FindFirstChild(name) if object then object:Destroy() end end end
	self:_destroyTools(record)
	if record.root and record.root.Parent and not record.isBot then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
end

function Service:_record(player, isBot)
	local record = { player = player, isBot = isBot, role = "Runner", ready = false, participating = false,
		teamId = 0, muddy = false, eliminated = false, originalGroups = {}, connections = {}, characterConnections = {},
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
	table.insert(record.characterConnections, humanoid.Died:Connect(function() if record.participating then self:_stick(record, nil) record.ready = false end end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character) if record.character == character then if record.participating then self:_stick(record, nil) end record.ready = false end end))
	if player.Character then task.spawn(function() self:_setupCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player] if not record then return end
	record.participating = false self:_restore(record) disconnect(record.connections) disconnect(record.characterConnections) self.records[player] = nil
	if self.practiceOwner == player then self:StopRound() else self:_teams(true) end
end

function Service:_readyPlayers(selected)
	local result, included = {}, {}
	for _, player in ipairs(selected or Players:GetPlayers()) do
		local record = self.records[player]
		if record and not record.isBot and not included[player] and connectedPlayer(player) and alive(record)
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") then included[player] = true table.insert(result, player) end
	end
	table.sort(result, function(a, b) return a.UserId < b.UserId end)
	return result
end

function Service:_teams(mark)
	local totals, free = {}, {}
	for _, record in pairs(self.records) do
		if record.participating and (record.isBot or record.player.Parent == Players) then totals[record.teamId] = (totals[record.teamId] or 0) + 1 if not record.muddy and not record.eliminated then free[record.teamId] = (free[record.teamId] or 0) + 1 end end
	end
	if mark and self.phase == "Playing" and self.pendingWinners == nil then
		for team = 1, self.teamCount do
			if not free[team] and not self.eliminatedTeams[team] then
				self.eliminatedTeams[team] = true
				for _, record in pairs(self.records) do if record.participating and record.teamId == team then record.eliminated = true self:_freeze(record, true) self:_role(record) end end
			end
		end
	end
	local active = {}
	for team, amount in pairs(free) do if amount > 0 and not self.eliminatedTeams[team] then table.insert(active, team) end end
	table.sort(active)
	if mark and self.active and self.phase == "Playing" and self.pendingWinners == nil and #active <= 1 then
		self.pendingWinners = table.clone(active)
		for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) end end
	end
	attribute(self.state, "ActiveTeamCount", #active)
	attribute(self.state, "TeamCount", self.teamCount)
	local participants, muddy = 0, 0
	local summary = {}
	for team = 1, self.teamCount do
		participants += totals[team] or 0 muddy += (totals[team] or 0) - (free[team] or 0)
		attribute(self.state, "Team" .. team .. "Members", totals[team] or 0) attribute(self.state, "Team" .. team .. "Free", free[team] or 0)
		table.insert(summary, { teamId = team, colorName = self:_colorName(team), free = free[team] or 0, total = totals[team] or 0, originalTotal = self.originalTeamSizes[team] or 0, eliminated = self.eliminatedTeams[team] == true })
	end
	attribute(self.state, "TeamSummaryJSON", HttpService:JSONEncode(summary))
	attribute(self.state, "ParticipantCount", participants) attribute(self.state, "MuddyCount", muddy)
	return active, totals, free
end

function Service:_stick(record, shooter)
	if not self.active or self.phase ~= "Playing" or self.pendingWinners ~= nil or not record.participating or record.eliminated or (shooter and shooter.teamId == record.teamId) then return false end
	for _, saver in pairs(self.records) do if saver.heatTarget == record then self:_clearHeat(saver, false) end end
	record.muddy, record.rescueProgress = true, 0
	self:_freeze(record, true) self:_role(record) self:_teams(true)
	return true
end

function Service:_clearHeat(record, release)
	if record.heatTarget then record.heatTarget.rescueProgress = 0 attribute(record.heatTarget.player, "MDRescueProgress", 0) end
	record.heatTarget, record.heatStartedAt, record.heatProgress = nil, nil, 0
	if record.player then attribute(record.player, "MDHeatProgress", 0) attribute(record.player, "MDHeatActive", false) attribute(record.player, "MDHeatTargetUserId", 0) end
	if record.heatBeam then record.heatBeam:Destroy() record.heatBeam = nil end
	if release then record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = false, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
	return nil
end

function Service:_rayParameters(source, ignoreCharacters)
	local ignored = { self.bounds }
	for _, name in ipairs({ "StartPads", "TeamSpawns", "NavigationNodes", "CoverVolumes", "RescueAreas", "PracticeSpawns" }) do local folder = self.gameplay:FindFirstChild(name) if folder then table.insert(ignored, folder) end end
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

function Service:_effects()
	if not self.effects then self.effects = Instance.new("Folder") self.effects.Name = "MudRoundEffects" self.effects.Parent = workspace end
	return self.effects
end

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local origin = self:_origin(record, "Mud", aim) if not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = aim, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
	record.fireReadyAt = now + self:_setting("MudCooldownSeconds", 0.65, 0.1) self:_publishRecord(record)
	return true
end

function Service:_tickProjectiles(dt)
	for index = #self.projectiles, 1, -1 do
		local shot = self.projectiles[index]
		local remove = shot.token ~= self.currentRound or self.phase ~= "Playing" or not self.active or self.pendingWinners ~= nil
		if not remove then
			local length = math.min(shot.remaining, shot.speed * dt)
			local vector = shot.direction * length
			local hit = workspace:Raycast(shot.position, vector, self:_rayParameters(shot.source, false))
			if hit then local target = self:_hitRecord(hit.Instance) if target and target.teamId ~= shot.teamId then self:_stick(target, shot.source) end remove = true
			else shot.position += vector shot.remaining -= length shot.part.Position = shot.position remove = shot.remaining <= 0 end
		end
		if remove then shot.part:Destroy() table.remove(self.projectiles, index) end
	end
end

function Service:_heatTarget(record, now)
	if not self:_canAct(record, now) or not record.heatHeld or now >= (record.heatLeaseEndsAt or 0) or not record.heatDirection then return nil end
	local origin = self:_origin(record, "Heat", record.heatDirection) if not origin then return nil end
	local hit = workspace:Raycast(origin, record.heatDirection * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
	local target = hit and self:_hitRecord(hit.Instance)
	if not target or target == record or target.teamId ~= record.teamId or not target.muddy or target.eliminated or not alive(target) then return nil end
	if (target.root.Position - record.root.Position).Magnitude > self:_setting("HeatRange", 24, 1) + 2 then return nil end
	return target, origin, hit.Position
end

function Service:_tickHeat(now)
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = 0 end end
	local progress = {}
	for _, saver in pairs(self.records) do
		local target, origin, finish = self:_heatTarget(saver, now)
		if not target then self:_clearHeat(saver, false)
		else
			if saver.heatTarget ~= target then self:_clearHeat(saver, false) saver.heatTarget, saver.heatStartedAt = target, now end
			local elapsed = math.max(0, now - saver.heatStartedAt)
			saver.heatProgress = math.min(self:_setting("RescueSeconds", 5, 0.1), elapsed)
			progress[target] = math.max(progress[target] or 0, saver.heatProgress)
			if not saver.heatBeam then local beam = Instance.new("Part") beam.Name = "HeatBeam" beam.Anchored = true beam.CanCollide = false beam.CanTouch = false beam.CanQuery = false beam.Material = Enum.Material.Neon beam.Color = Color3.fromRGB(255, 184, 71) beam.Parent = self:_effects() saver.heatBeam = beam end
			saver.heatBeam.Size = Vector3.new(0.3, 0.3, (finish - origin).Magnitude) saver.heatBeam.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
			if elapsed >= self:_setting("RescueSeconds", 5, 0.1) then target.muddy, target.rescueProgress = false, 0 self:_freeze(target, false) self:_role(target) self:_clearHeat(saver, false) end
		end
	end
	for _, record in pairs(self.records) do if record.participating then record.rescueProgress = record.muddy and (progress[record] or 0) or 0 self:_publishRecord(record) end end
end

function Service:_tickSprint(record, dt, now)
	if not record.participating then return end
	if now >= (record.sprintLeaseEndsAt or 0) or not self:_canAct(record, now) then record.sprintHeld = false end
	local speed = alive(record) and Vector3.new(record.root.AssemblyLinearVelocity.X, 0, record.root.AssemblyLinearVelocity.Z).Magnitude or 0
	record.sprinting = record.sprintHeld and not record.sprintExhausted and record.sprintRemaining > 0 and speed > 1
	if record.sprinting then record.sprintRemaining = math.max(0, record.sprintRemaining - dt) if record.sprintRemaining == 0 then record.sprintExhausted, record.sprinting = true, false end
	else record.sprintRemaining = math.min(record.sprintMax, record.sprintRemaining + record.sprintMax / self:_setting("SprintRefillSeconds", 15, 0.1) * dt) if record.sprintRemaining >= record.sprintMax - 0.0001 then record.sprintRemaining, record.sprintExhausted = record.sprintMax, false end end
	self:_movement(record) self:_publishRecord(record)
end

function Service:_action(record, action, value, aim)
	local player = record.player
	if action == "ChooseColor" then
		if typeof(value) ~= "string" or not PREFERENCE_COLORS[value] then return { ok = false, message = "Choose Red, Blue, Green or Black." } end
		local now = workspace:GetServerTimeNow()
		if now - (record.requests.ChooseColor or -math.huge) < 0.2 then return { ok = false, message = "Slow down." } end
		record.requests.ChooseColor = now
		attribute(player, "MDColorPreference", value)
		if record.participating and self.phase == "Countdown" then
			for team, name in pairs(self.teamColors) do if team ~= record.teamId and name == value then return { ok = true, message = "Saved for the next round; that team color is in use." } end end
			self.teamColors[record.teamId] = value
			for _, teammate in pairs(self.records) do if teammate.participating and teammate.teamId == record.teamId then self:_role(teammate) end end
			self:_teams(false)
		end
		return { ok = true, message = "Color preference saved." }
	end
	if action == "Sprint" and value == false then record.sprintHeld, record.sprinting = false, false if record.participating then self:_movement(record) end self:_publishRecord(record) return { ok = true } end
	if action == "Heat" and value == false then self:_clearHeat(record, true) self:_publishRecord(record) return { ok = true } end
	if typeof(action) ~= "string" or (action ~= "Sprint" and action ~= "Fire" and action ~= "Heat") then return { ok = false, message = "Unknown action." } end
	local now = workspace:GetServerTimeNow()
	if now - (record.requests[action] or -math.huge) < 0.08 then return { ok = false, message = "Slow down." } end
	record.requests[action] = now
	if not self:_canAct(record, now) then return { ok = false, message = "Wait until you can move." } end
	if action == "Sprint" then if value ~= true then return { ok = false, message = "Invalid sprint." } end record.sprintHeld, record.sprintLeaseEndsAt = true, now + 1 self:_movement(record) return { ok = true } end
	local unit = direction(action == "Fire" and value or aim)
	if not unit then return { ok = false, message = "Aim toward the playground." } end
	if action == "Fire" then return { ok = self:_fire(record, unit, now), message = "Mud shot." } end
	if value ~= true or not self:_origin(record, "Heat", unit) then return { ok = false, message = "Equip the Heat Gun." } end
	record.heatHeld, record.heatDirection, record.heatLeaseEndsAt = true, unit, now + 1
	return { ok = true }
end

function Service:Action(player, action, value, aim)
	local record = self.records[player]
	if not connectedPlayer(player) or not record or record.isBot then return { ok = false, message = "Your character is loading." } end
	return self:_action(record, action, value, aim)
end

function Service:_keepLegal(record)
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position) local half = self.bounds.Size / 2
	local floor = self:_setting("FloorY", self.spawnPads[1].Position.Y - 3.5, -10000)
	if math.abs(point.X) > half.X - 3 or math.abs(point.Z) > half.Z - 3 or record.root.Position.Y < floor - 7 or math.abs(point.Y) > half.Y then self:_stick(record, nil) self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	elseif record.humanoid.FloorMaterial ~= Enum.Material.Air then record.lastGoodCFrame = record.root.CFrame end
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
	record.frozen = record.muddy or record.eliminated or self.phase ~= "Playing"
	self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
	pcall(function() record.root:SetNetworkOwner(nil) end)
	self:_freeze(record, record.frozen)
	self:_role(record)
	record.respawning = false
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
	local teammate, teammateDistance, opponent, opponentDistance
	for _, candidate in pairs(self.records) do
		if candidate ~= bot and candidate.participating and not candidate.eliminated and alive(candidate) then
			local distance = (candidate.root.Position - bot.root.Position).Magnitude
			if candidate.teamId == bot.teamId and candidate.muddy and (not teammateDistance or distance < teammateDistance) then teammate, teammateDistance = candidate, distance
			elseif candidate.teamId ~= bot.teamId and not candidate.muddy and (not opponentDistance or distance < opponentDistance) then opponent, opponentDistance = candidate, distance end
		end
	end
	if teammate then return teammate, true, teammateDistance end
	return opponent, false, opponentDistance
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
	for _, bot in pairs(self.records) do
		if bot.isBot and self:_canAct(bot, now) and now >= bot.nextBotMoveAt then
			bot.nextBotMoveAt = now + 0.2
			local target, rescue, distance = self:_botTarget(bot)
			if target then
				local goal = target.root.Position
				local head = bot.character:FindFirstChild("Head") or bot.root
				local aim = direction(goal - head.Position)
				local heating = false
				if rescue and aim and distance <= self:_setting("HeatRange", 24, 1) - 2 then
					bot.heatHeld, bot.heatDirection, bot.heatLeaseEndsAt = true, aim, now + 1
					heating = self:_heatTarget(bot, now) == target
				end
				if not heating then self:_clearHeat(bot, true) end
				if heating then bot.humanoid:MoveTo(bot.root.Position)
				else
					local direct = not workspace:Raycast(bot.root.Position, goal - bot.root.Position, self:_rayParameters())
					if not rescue and direct and distance < math.min(self:_setting("MudRange", 130, 1) - 10, 80) then
						bot.humanoid:MoveTo(bot.root.Position)
						local interval = self:_setting("BotShotIntervalSeconds", 7, 0.2)
						bot.nextBotShotAt = bot.nextBotShotAt or now + interval * (0.6 + bot.spawnIndex * 0.3)
						if now >= bot.nextBotShotAt then
							local lead = math.min(distance / self:_setting("ProjectileSpeed", 115, 1), 1)
							local predicted = goal + target.root.AssemblyLinearVelocity * lead
							local shotDirection = direction(predicted - head.Position)
							if shotDirection then self:_fire(bot, shotDirection, now) end
							bot.nextBotShotAt = now + interval
						end
					else self:_moveBot(bot, goal, now) end
				end
			else self:_clearHeat(bot, true) bot.humanoid:MoveTo(bot.root.Position) end
		end
	end
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_stick(record, nil) self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then if (record.root.Position - record.lockedCFrame.Position).Magnitude > 0.05 then self:_teleport(record, record.lockedCFrame) end record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero record.humanoid:Move(Vector3.zero)
			else self:_keepLegal(record) end
		end
		self:_tickSprint(record, dt, now)
	end
	if self.phase ~= "Playing" or now >= self.endsAt then return end
	self:_driveBots(now) self:_tickProjectiles(dt) self:_tickHeat(now) self:_teams(true)
end

function Service:_valid(token) return self.running and self.active and self.currentRound == token end

function Service:_results(token, winners, reason)
	local winnerSet, winnerIds, participantIds, names = {}, {}, {}, {}
	for _, id in ipairs(winners) do winnerSet[id] = true end
	for _, entry in ipairs(self.roundRoster) do if not entry.isBot then table.insert(participantIds, entry.userId) if winnerSet[entry.teamId] then table.insert(winnerIds, entry.userId) end end end
	for _, record in pairs(self.records) do if record.participating then self:_freeze(record, true) self:_publishRecord(record) local won = winnerSet[record.teamId] == true attribute(record.player, "MDResult", won and "Won" or "Lost") if won then table.insert(names, record.player.DisplayName) end end end
	for _, shot in ipairs(self.projectiles) do shot.part:Destroy() end table.clear(self.projectiles)
	table.sort(winnerIds) table.sort(participantIds) table.sort(names)
	attribute(self.state, "WinnerTeamIds", table.concat(winners, ",")) attribute(self.state, "WinnerTeams", table.concat(winners, ",")) attribute(self.state, "WinnersText", table.concat(names, ", ")) attribute(self.state, "ResultReason", reason)
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ",")) attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ",")) attribute(self.state, "LastResultPractice", self.mode ~= "Round") attribute(self.state, "LastResultRound", self.roundNumber)
	self:_phase("Results")
	local untilTime = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0)
	while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.1) end
end

function Service:_cleanup(token)
	if token and self.currentRound ~= token then return end
	for _, record in pairs(self.records) do if record.participating then record.participating = false self:_restore(record) record.teamId, record.muddy, record.eliminated, record.rescueProgress, record.sprintMax, record.sprintRemaining = 0, false, false, 0, 0, 0 record.sprintExhausted, record.sprintLeaseEndsAt, record.fireReadyAt = false, 0, 0 self:_publishRecord(record) if not record.isBot and self.lobbySpawn and self.lobbySpawn.Parent then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y / 2 + 3, 0)) end end end
	self:_clearBots() table.clear(self.projectiles) if self.effects then self.effects:Destroy() self.effects = nil end
	self.active, self.currentRound, self.practiceOwner, self.mode, self.endsAt = false, nil, nil, "Waiting", 0
	self.pendingWinners = nil
	self.eliminatedTeams, self.originalTeamSizes, self.roundRoster = {}, {}, {}
	attribute(self.state, "Mode", "Waiting") attribute(self.state, "EndsAt", 0) attribute(self.state, "PracticeOwnerUserId", 0) attribute(self.state, "CountdownValue", 0) self:_phase("Waiting") self:_teams(false)
end

function Service:_run(participants, token)
	if not self:_valid(token) then return end
	self.roundNumber += 1 self.eliminatedTeams, self.originalTeamSizes, self.roundRoster, self.pendingWinners = {}, {}, {}, nil
	attribute(self.state, "RoundNumber", self.roundNumber) attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 1)) attribute(self.state, "RescueSeconds", self:_setting("RescueSeconds", 5, 0.1)) attribute(self.state, "WinnersText", "") attribute(self.state, "WinnerTeams", "") attribute(self.state, "WinnerTeamIds", "") attribute(self.state, "ResultReason", "")
	local assignments
	if token.teams then assignments, self.teamCount = token.teams, 2 else assignments, self.teamCount = Service.TeamAssignments(#participants, self:_setting("TeamCount", 2, 2), self:_setting("MaxTeamSize", 2, 2)) end
	local slots = {}
	for index, player in ipairs(participants) do
		local record = self.records[player]
		if record then
			record.participating, record.teamId, record.muddy, record.eliminated = true, assignments[index], false, false slots[record.teamId] = (slots[record.teamId] or 0) + 1 record.spawnIndex = slots[record.teamId]
			self.originalTeamSizes[record.teamId] = (self.originalTeamSizes[record.teamId] or 0) + 1
			table.insert(self.roundRoster, { userId = player.UserId, teamId = record.teamId, isBot = record.isBot })
			record.sprintMax = self:_setting("SprintSeconds", 10, 0.1) record.sprintRemaining = record.sprintMax record.sprintExhausted, record.sprintHeld, record.fireReadyAt = false, false, 0
			record.rescueProgress, record.lastGoodCFrame, record.requests, record.nextBotShotAt = 0, nil, {}, nil attribute(player, "MDResult", "")
			local spawn = self:_spawn(record.spawnIndex, record.teamId)
			local practice = token.teams and parts(self.gameplay:FindFirstChild("PracticeSpawns"))
			if practice and #practice > 0 then spawn = practice[(index - 1) % #practice + 1].CFrame elseif token.teams then spawn = CFrame.new(self.bounds.Position.X + (record.teamId == 1 and -22 or 22), self.spawnPads[1].Position.Y, self.bounds.Position.Z + (record.spawnIndex - 1) * 17) end
			self:_teleport(record, spawn) self:_freeze(record, true) self:_giveTools(record) self:_role(record)
		end
	end
	self:_chooseTeamColors()
	for _, record in pairs(self.records) do if record.participating then self:_role(record) end end
	self:_teams(false) self:_phase("Countdown")
	for number = math.floor(self:_setting("CountdownSeconds", 3, 1)), 1, -1 do if not self:_valid(token) then return end attribute(self.state, "CountdownValue", number) local untilTime = workspace:GetServerTimeNow() + 1 while self:_valid(token) and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end end
	if not self:_valid(token) then return end
	self.endsAt = workspace:GetServerTimeNow() + self:_setting("RoundDuration", 300, 1) attribute(self.state, "EndsAt", self.endsAt) attribute(self.state, "CountdownValue", 0) self:_phase("Playing")
	for _, record in pairs(self.records) do if record.participating and self.pendingWinners == nil then if not alive(record) or (record.isBot and record.practiceMedic and self.mode == "PracticeMedic") then self:_stick(record, nil) else self:_freeze(record, false) end end end
	local active = self:_teams(true)
	while self:_valid(token) and self.pendingWinners == nil and workspace:GetServerTimeNow() < self.endsAt do task.wait(0.05) active = self:_teams(true) end
	if self:_valid(token) then
		local reason
		if self.pendingWinners then active = self.pendingWinners reason = #active == 0 and "NoActiveTeams" or "LastTeamStanding"
		else active = self:_timeoutWinners() reason = #active > 1 and "TimeoutShared" or #active == 0 and "NoActiveTeams" or "Timeout" end
		self:_results(token, active, reason) self:_cleanup(token)
	end
end

function Service:_begin(participants, mode, teams, owner)
	self.active, self.mode, self.practiceOwner = true, mode, owner
	local token = { teams = teams } self.currentRound = token
	attribute(self.state, "Mode", mode) attribute(self.state, "PracticeOwnerUserId", owner and owner.UserId or 0)
	task.spawn(function() local ok, failure = xpcall(function() self:_run(participants, token) end, debug.traceback) if not ok then warn("Stuck in the Mud round failed: " .. tostring(failure)) self:_cleanup(token) end end)
	return true
end

function Service:_weaponsReady()
	local ok, ready = pcall(function()
		local assets = ReplicatedStorage:FindFirstChild("MudAssets")
		local mud = assets and assets:FindFirstChild("MudGun")
		local heat = assets and assets:FindFirstChild("HeatGun")
		if not mud or not heat or not mud:IsA("Tool") or not heat:IsA("Tool") then return false end
		local mudEnabled, heatEnabled = mud.Enabled, heat.Enabled
		return mudEnabled == true and heatEnabled == true
	end)
	return ok and ready == true
end

function Service:StartRound(selected)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	local participants = self:_readyPlayers(selected)
	local minimum = math.clamp(math.floor(self:_setting("MinimumPlayers", 4, 2)), 2, 24)
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 4, 2)), 2, 24)
	if #participants < minimum or maximum < minimum then return false, "At least " .. minimum .. " ready players are needed." end
	for index = #participants, 2, -1 do local other = self.random:NextInteger(1, index) participants[index], participants[other] = participants[other], participants[index] end
	while #participants > maximum do table.remove(participants) end
	return self:_begin(participants, "Round")
end

function Service:StartPractice(player, role)
	if not self.running then return false, "Service is not running" end if self.active then return false, "A round is already running" end
	local ready = self:_weaponsReady() attribute(self.state, "GunAccessReady", ready)
	if not ready then return false, "Mud gun access is awaiting approval." end
	if role ~= "Runner" and role ~= "Tagger" and role ~= "Shooter" and role ~= "Medic" then return false, "Choose Shooter or Medic practice" end
	local record = self.records[player] if not connectedPlayer(player) or not record or record.isBot or not alive(record) or player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") then return false, "Your character is not ready" end
	local participants, teams = { player }, { 1 }
	local ok, failure = xpcall(function() for index = 1, 3 do local bot = self:_newBot(index, index == 1 and "Runner" or "Tagger") table.insert(participants, bot) table.insert(teams, index == 1 and 1 or 2) self.records[bot].practiceMedic = index == 1 end end, debug.traceback)
	if not ok then self:_clearBots() warn(tostring(failure)) return false, "Practice bots could not be created" end
	return self:_begin(participants, "Practice" .. role, teams, player)
end

function Service:StopRound()
	if not self.active then return false, "No round is running" end self.currentRound = nil self:_cleanup() return true
end

function Service:Start(player, role)
	if player then if not self.running then self:Start() end return self:StartPractice(player, role or "Shooter") end
	if self.running then return end self.running, runningService = true, self
	local provider = PhysicsService if pcall(function() workspace:IsCollisionGroupRegistered("MudPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", GunAccessReady = self:_weaponsReady(), EndsAt = 0, CountdownValue = 0, RoundNumber = 0, RoundDuration = 300, RescueSeconds = 5, ActiveTeamCount = 0, ParticipantCount = 0, MuddyCount = 0, TeamCount = 2, TeamSummaryJSON = "[]", WinnersText = "", WinnerTeams = "", WinnerTeamIds = "", ResultReason = "", LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0, PracticeOwnerUserId = 0 }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(value) self:_addPlayer(value) end)) table.insert(self.connections, Players.PlayerRemoving:Connect(function(value) self:_removePlayer(value) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self.tickAccumulator += dt if self.tickAccumulator >= 0.05 then local elapsed = self.tickAccumulator self.tickAccumulator = 0 self:_tick(math.min(elapsed, 0.25)) end end))
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
]=],
 ["TagSprintService"]=[=[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Service={}
Service.__index=Service
local runningService

local function set(player,name,value)
 if player:GetAttribute(name)~=value then player:SetAttribute(name,value) end
end

function Service.new(tag)
 return setmetatable({tag=tag,arena=tag.arena,entries={},connections={},running=false},Service)
end

function Service:_setting(name,fallback,minimum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.max(minimum or 0,value)
end

function Service:_active(player,record)
 return self.tag.active and self.tag.phase=="Playing" and record and record.participating and not record.frozen
  and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent
  and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
end

function Service:Request(player,held)
 if typeof(held)~="boolean" then return {ok=false,message="Hold or release sprint."} end
 local record=self.tag.records[player]
 local entry=self.entries[player]
 if not held then
  if entry then entry.held=false entry.lease=0 end
  return {ok=true}
 end
 if player.Parent~=Players or not self:_active(player,record) then return {ok=false,message="Sprint is available during Tag."} end
 if not entry then return {ok=false,message="Sprint is getting ready."} end
 local now=workspace:GetServerTimeNow()
 if now-(entry.lastRequest or -math.huge)<0.075 then return {ok=false,message="Sprint request too soon."} end
 entry.lastRequest=now
 entry.held=true
 entry.lease=now+1
 return {ok=true}
end

function Service:_tick(delta)
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local record=self.tag.records[player]
  local participating=record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
  local entry=self.entries[player]
  if not participating then
   if entry then self.entries[player]=nil end
   set(player,"TGSprinting",false)
   set(player,"TGSprintExhausted",false)
   set(player,"TGSprintRemaining",self:_setting("SprintSeconds",10,0.1))
  else
   local maximum=self:_setting("SprintSeconds",10,0.1)
   local round=self.tag.currentRound or self.tag.roundNumber
   if not entry or entry.round~=round then
    entry={remaining=maximum,held=false,locked=false,lease=0,character=record.character,round=round}
    self.entries[player]=entry
   elseif entry.character~=record.character then
    entry.character=record.character
    entry.held=false entry.lease=0
   end
   entry.remaining=math.clamp(entry.remaining,0,maximum)
   if now>entry.lease then entry.held=false end
   local canMove=self:_active(player,record)
   local velocity=record.root and record.root.AssemblyLinearVelocity or Vector3.zero
   local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
   local sprinting=canMove and entry.held and not entry.locked and moving
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
    if entry.remaining<=0 then entry.locked=true sprinting=false end
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
    if entry.locked and entry.remaining>=maximum-0.00001 then entry.locked=false end
   end
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=record.frozen and 0 or base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end

function Service:Start()
 if self.running then return end
 self.running=true
 runningService=self
 self.remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
 self.remote.OnServerInvoke=function(player,held) return self:Request(player,held) end
 local accumulated=0
 table.insert(self.connections,RunService.Heartbeat:Connect(function(delta)
  accumulated+=delta
  if accumulated>=0.05 then local step=accumulated accumulated=0 self:_tick(math.min(step,0.25)) end
 end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.entries[player]=nil end))
end

function Service:Stop()
 self.running=false
 if self.remote then self.remote.OnServerInvoke=nil end
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 for player in pairs(self.entries) do
  local record=self.tag.records[player]
  if record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating") then self.tag:_movement(record) end
  set(player,"TGSprinting",false)
 end
 table.clear(self.entries)
 if runningService==self then runningService=nil end
end

function Service.GetRunningService() return runningService end

return Service
]=],
 ["PlaygroundCoordinator"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coordinator = {}
Coordinator.__index = Coordinator
local games = { "BritishBulldog", "TagYoureIt", "StuckInTheMud" }
local titles = { BritishBulldog = "British Bulldog", TagYoureIt = "Tag You're It", StuckInTheMud = "Stuck in the Mud" }

function Coordinator.new(services, lobby, economy)
	local self = setmetatable({}, Coordinator)
	self.services = services
	self.lobby = lobby
	self.economy = economy
	self.zone = lobby.Gameplay.VoteZone
	self.state = ReplicatedStorage:WaitForChild("PlaygroundState")
	self.votes = {}
	self.lastVote = {}
	self.connections = {}
	self.running = false
	self.autoEnabled = true
	self.votingEndsAt = 0
	self.random = Random.new()
	self.lastGame = nil
	return self
end

function Coordinator:ActiveGame()
	for _, id in ipairs(games) do if self.services[id] and self.services[id].active then return id end end
	return nil
end

function Coordinator:_readyPlayers()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating") and player:GetAttribute("PCDataReady") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Coordinator:MinimumPlayers(id)
	local service=self.services[id]
	local minimum=service and service.arena and service.arena:GetAttribute("MinimumPlayers")
	if typeof(minimum)~="number" or minimum~=minimum or math.abs(minimum)==math.huge then minimum=id=="StuckInTheMud" and 4 or 2 end
	return math.max(2,math.floor(minimum))
end

function Coordinator:GameAvailable(id, readyCount)
	local service=self.services[id]
	if not service then return false end
	if id=="StuckInTheMud" and service.state:GetAttribute("GunAccessReady")==false then return false end
	return (readyCount or #self:_readyPlayers())>=self:MinimumPlayers(id)
end

function Coordinator:_availability(readyCount)
	self.state:SetAttribute("ReadyPlayerCount",readyCount)
	for _,id in ipairs(games) do
	 self.state:SetAttribute("Available"..id,self:GameAvailable(id,readyCount))
	 if self.services[id] then self.state:SetAttribute("Minimum"..id,self:MinimumPlayers(id)) end
	end
end

function Coordinator:_insideZone(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local point = self.zone.CFrame:PointToObjectSpace(root.Position)
	local half = self.zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Coordinator:_counts()
	local counts = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 }
	for player, id in pairs(self.votes) do
		if player.Parent == Players and counts[id] then counts[id] += 1 end
	end
	for id, count in pairs(counts) do self.state:SetAttribute("Votes" .. id, count) end
	return counts
end

function Coordinator:_clearVotes()
	for player in pairs(self.votes) do if player.Parent == Players then player:SetAttribute("PCVote", "") end end
	table.clear(self.votes)
	self:_counts()
end

function Coordinator:SetAutoEnabled(enabled)
	self.autoEnabled = enabled == true
	self.votingEndsAt = 0
	self.state:SetAttribute("AutomaticRounds", self.autoEnabled)
	self.state:SetAttribute("VotingEndsAt", 0)
	if not self:ActiveGame() then
		self.state:SetAttribute("Phase", self.autoEnabled and "Waiting" or "Paused")
		self:_clearVotes()
	end
end

function Coordinator:Vote(player, id)
	if typeof(id) ~= "string" or not self.services[id] then return { ok = false, message = "Choose an available game." } end
	if self.state:GetAttribute("Phase") ~= "Voting" or self:ActiveGame() or not self.autoEnabled then return { ok = false, message = "Voting opens between rounds." } end
	if player:GetAttribute("PCDataReady") ~= true then return { ok = false, message = "Your player data is loading." } end
	if not self:GameAvailable(id) then return {ok=false,message="This game is not ready for the next round."} end
	if player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating") or not self:_insideZone(player) then return { ok = false, message = "Walk into the voting area first." } end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return { ok = false, message = "Your character is loading." } end
	local now = os.clock()
	if now - (self.lastVote[player] or -math.huge) < 0.35 then return { ok = false, message = "Please wait a moment." } end
	self.lastVote[player] = now
	self.votes[player] = id
	player:SetAttribute("PCVote", id)
	self:_counts()
	return { ok = true, message = "Vote saved." }
end

function Coordinator:StartGame(id, player, role, automatic)
	local service = self.services[id]
	if not service then return false, "This game is not available yet." end
	if self:ActiveGame() then return false, "A game is running. Stop it first." end
	if not automatic then self:SetAutoEnabled(false) end
	self.votingEndsAt = 0
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_clearVotes()
	local started, reason
	if role then started, reason = service:StartPractice(player, role)
	else started, reason = service:StartRound(self:_readyPlayers()) end
	if started then
		self.lastGame = id
		self.state:SetAttribute("ActiveGame", id)
		self.state:SetAttribute("GameTitle", titles[id])
		self.state:SetAttribute("Phase", "Playing")
	end
	return started, reason
end

function Coordinator:StopGame()
	local stopped = false
	for _, id in ipairs(games) do
		if self.services[id] and self.services[id].active then self.services[id]:StopRound() stopped = true end
	end
	self:SetAutoEnabled(false)
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("GameTitle", "")
	return true, stopped and "Back in the lobby." or "Ready in the lobby."
end

function Coordinator:_chooseGame()
	local counts = self:_counts()
	local readyCount=#self:_readyPlayers()
	local maximum = 0
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) then maximum = math.max(maximum, counts[id]) end end
	local tied = {}
	for _, id in ipairs(games) do if self:GameAvailable(id,readyCount) and counts[id] == maximum then table.insert(tied, id) end end
	if maximum == 0 and self.lastGame then
		for _, id in ipairs(tied) do if id ~= self.lastGame then return id end end
	end
	return #tied>0 and tied[self.random:NextInteger(1, #tied)] or nil
end

function Coordinator:_rewardBulldog()
	local service = self.services.BritishBulldog
	if service.phase ~= "Results" then return end
	local state = service.state
	local team = state:GetAttribute("WinnerTeam")
	if team ~= "Runners" and team ~= "Bulldogs" then return end
	local winnerIds, participantIds = {}, {}
	for player, record in pairs(service.records) do
		if not record.isBot and record.participating and player.Parent == Players then
			table.insert(participantIds, player.UserId)
			if (team == "Runners" and record.role == "Runner") or (team == "Bulldogs" and record.role == "Bulldog") then table.insert(winnerIds, player.UserId) end
		end
	end
	table.sort(winnerIds)
	table.sort(participantIds)
	self.economy:AwardRound("BB:" .. tostring(state:GetAttribute("RoundNumber")), winnerIds, string.find(state:GetAttribute("Mode") or "", "Practice", 1, true) ~= nil, participantIds)
end

function Coordinator:_rewardTag()
	local state = self.services.TagYoureIt.state
	local ids, participants = {}, {}
	for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids, tonumber(value)) end
	for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants, tonumber(value)) end
	self.economy:AwardRound("TAG:" .. tostring(state:GetAttribute("LastResultRound")), ids, state:GetAttribute("LastResultPractice") == true, participants)
end

function Coordinator:_rewardMud()
 local service=self.services.StuckInTheMud
 if not service then return end
 local state=service.state
 local ids,participants={},{}
 for value in string.gmatch(state:GetAttribute("LastResultWinnerIds") or "", "%-?%d+") do table.insert(ids,tonumber(value)) end
 for value in string.gmatch(state:GetAttribute("LastResultParticipantIds") or "", "%-?%d+") do table.insert(participants,tonumber(value)) end
 self.economy:AwardRound("MUD:"..tostring(state:GetAttribute("LastResultRound")),ids,state:GetAttribute("LastResultPractice")==true,participants,{winnerXP=50,loserXP=50})
end

function Coordinator:_padVoting()
 self.padChoices=self.padChoices or {}
 if self.state:GetAttribute("Phase")~="Voting" then table.clear(self.padChoices) return end
 local choices=self.lobby.Gameplay:FindFirstChild("VoteChoices")
 if not choices then return end
 for _,player in ipairs(Players:GetPlayers()) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local choice
  if root and self:_insideZone(player) then
   for _,pad in ipairs(choices:GetChildren()) do
    if pad:IsA("BasePart") and pad:GetAttribute("Available")~=false then
     local point=pad.CFrame:PointToObjectSpace(root.Position)
     local half=pad.Size/2
     if math.abs(point.X)<=half.X and math.abs(point.Y)<=half.Y and math.abs(point.Z)<=half.Z then choice=pad:GetAttribute("GameId") break end
    end
   end
  end
  if choice and not self:GameAvailable(choice) then choice=nil end
  if choice~=self.padChoices[player] then
   self.padChoices[player]=choice
   if choice then self:Vote(player,choice) end
  end
 end
end

function Coordinator:_loop()
	while self.running do
		local active = self:ActiveGame()
		local readyCount=#self:_readyPlayers()
		self:_availability(readyCount)
		local now = workspace:GetServerTimeNow()
		if active then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Playing")
			self.state:SetAttribute("ActiveGame", active)
			self.state:SetAttribute("GameTitle", titles[active])
			self.state:SetAttribute("VotingEndsAt", 0)
		elseif not self.autoEnabled then
			self.state:SetAttribute("Phase", "Paused")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
		elseif readyCount < 2 then
			self.votingEndsAt = 0
			self.state:SetAttribute("Phase", "Waiting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("GameTitle", "")
			self.state:SetAttribute("VotingEndsAt", 0)
			self:_clearVotes()
		elseif self.votingEndsAt == 0 then
			self:_clearVotes()
			self.votingEndsAt = now + 20
			self.state:SetAttribute("Phase", "Voting")
			self.state:SetAttribute("ActiveGame", "")
			self.state:SetAttribute("VotingEndsAt", self.votingEndsAt)
		elseif now >= self.votingEndsAt then
			local selected = self:_chooseGame()
			self.votingEndsAt = 0
			local started = self:StartGame(selected, nil, nil, true)
			if not started then self.state:SetAttribute("Phase", "Waiting") end
		end
		self:_padVoting()
		task.wait(0.25)
	end
end

function Coordinator:Start()
	if self.running then return end
	self.running = true
	self.state:SetAttribute("AutomaticRounds", true)
	self.state:SetAttribute("Phase", "Waiting")
	self.state:SetAttribute("ActiveGame", "")
	self.state:SetAttribute("VotingEndsAt", 0)
	self:_counts()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundVoteRequest")
	remote.OnServerInvoke = function(player, id) return self:Vote(player, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		self.votes[player] = nil
		self.lastVote[player] = nil
		self:_counts()
	end))
	table.insert(self.connections, self.services.BritishBulldog.state:GetAttributeChangedSignal("Phase"):Connect(function() self:_rewardBulldog() end))
	table.insert(self.connections, self.services.TagYoureIt.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardTag() end))
	if self.services.StuckInTheMud then table.insert(self.connections,self.services.StuckInTheMud.state:GetAttributeChangedSignal("LastResultRound"):Connect(function() self:_rewardMud() end)) end
	task.spawn(function() self:_loop() end)
end

function Coordinator:Stop()
	self.running = false
	self:StopGame()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Coordinator
]=],
 ["PlaygroundEconomyService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))

local Economy = {}
Economy.__index = Economy
local slots = { Pet = true, Emote = true, Emoji = true, Trail = true, Highlight = true, Gear = true }
local actions = { GetStatus = true, Buy = true, Equip = true, Unequip = true, UseEmote = true, UseEmoji = true }
local ink = Color3.fromRGB(24, 35, 62)

local function integer(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, 1000000000)
end

local function timestamp(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.clamp(math.floor(value), 0, 1000000000000)
end

local function levelProgress(xp, base, step)
	xp = integer(xp, 0)
	base = math.max(1, integer(base, 100))
	step = integer(step, 50)
	local completed = 0
	local function cost(count) return count * base + step * count * (count - 1) / 2 end
	if step == 0 then
		completed = math.floor(xp / base)
	elseif xp > 0 then
		local linear = base - step / 2
		local root = math.sqrt(linear * linear + 2 * step * xp)
		completed = math.floor(linear >= 0 and 2 * xp / (root + linear) or (root - linear) / step)
		if cost(completed) > xp then completed = math.max(0, completed - 1) end
		if cost(completed + 1) <= xp then completed += 1 end
	end
	return completed + 1, xp - cost(completed), base + step * completed
end

local function cleanData(value)
	value = typeof(value) == "table" and value or {}
	local result = { Coins = integer(value.Coins, 0), Wins = integer(value.Wins, 0), XP = integer(value.XP, 0), Owned = {}, Equipped = {}, Version = 2 }
	if typeof(value.Owned) == "table" then
		for id, owned in pairs(value.Owned) do
			if typeof(id) == "string" and #id <= 48 and owned == true then result.Owned[id] = true end
		end
	end
	if typeof(value.Equipped) == "table" then
		for slot, id in pairs(value.Equipped) do
			local item = Catalog.ById[id]
			if slots[slot] and item and item.slot == slot and result.Owned[id] then result.Equipped[slot] = id end
		end
	end
	return result
end

function Economy:_setting(name, fallback)
	return integer(self.lobby:GetAttribute(name), fallback)
end

function Economy:LevelProgress(xp)
	return levelProgress(xp, self:_setting("BaseLevelXP", 200), self:_setting("LevelXPStep", 50))
end

function Economy.new(lobby, storeOverride, studioOverride)
	local self = setmetatable({}, Economy)
	self.lobby = lobby
	self.bounds = lobby.Gameplay.LobbyBounds
	self.profiles = {}
	self.connections = {}
	self.awarded = {}
	self.isStudio = studioOverride == nil and RunService:IsStudio() or studioOverride
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.store = storeOverride
	if not self.isStudio and not self.store then
		local ok, store = pcall(function() return DataStoreService:GetDataStore("PlaygroundClassics_Profiles_v1") end)
		if ok then self.store = store end
	end
	self.sessionOnly = not self.isStudio and self.store == nil
	self.assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
	self.effects = Instance.new("Folder")
	self.effects.Name = "PlaygroundCosmeticEffects"
	self.effects.Parent = workspace
	self.coins = {}
	self.running = false
	self.elapsed = 0
	self.lastSave = os.clock()
	return self
end

function Economy:_sync(profile)
	local player = profile.player
	profile.data.XP = integer(profile.data.XP, 0)
	local level, levelXP, requiredXP = self:LevelProgress(profile.data.XP)
	player:SetAttribute("PCCoins", profile.data.Coins)
	player:SetAttribute("PCWins", profile.data.Wins)
	player:SetAttribute("PCXP", profile.data.XP)
	player:SetAttribute("PCLevel", level)
	player:SetAttribute("PCLevelXP", levelXP)
	player:SetAttribute("PCLevelXPRequired", requiredXP)
	player:SetAttribute("PCDataReady", profile.ready == true)
	player:SetAttribute("PCDataMode", self.isStudio and "Studio" or self.sessionOnly and "Session" or "Persistent")
	for slot in pairs(slots) do player:SetAttribute("PC" .. slot, profile.data.Equipped[slot] or "") end
	local board = player:FindFirstChild("leaderstats")
	if board then
		local wins = board:FindFirstChild("Wins")
		local coins = board:FindFirstChild("Coins")
		local levelCounter = board:FindFirstChild("Level")
		if wins then wins.Value = profile.data.Wins end
		if coins then coins.Value = profile.data.Coins end
		if levelCounter then levelCounter.Value = level end
	end
end

function Economy:_claim(profile)
	if self.isStudio or self.sessionOnly then
		profile.data = cleanData({ Coins = self.isStudio and 150 or 0 })
		profile.ready = true
		return true
	end
	local ok, value = pcall(function()
		return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
			old = typeof(old) == "table" and old or {}
			local lease = old.Session
			if typeof(lease) == "table" and lease.Id ~= self.sessionId and timestamp(lease.Expires) > os.time() then return nil end
			local data = cleanData(old)
			data.Session = { Id = self.sessionId, Expires = os.time() + 180 }
			return data
		end)
	end)
	if ok and typeof(value) == "table" and value.Session and value.Session.Id == self.sessionId then
		profile.data = cleanData(value)
		profile.ready = true
		return true
	end
	return false
end

function Economy:_save(profile, release)
	if self.isStudio or self.sessionOnly or not profile.ready or profile.released then return true end
	local untilTime = os.clock() + 8
	while profile.saving and os.clock() < untilTime do task.wait(0.1) end
	if profile.released then return true end
	if profile.saving then return false end
	profile.saving = true
	local version = profile.version
	local snapshot = cleanData(profile.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return self.store:UpdateAsync("u:" .. profile.player.UserId, function(old)
				if typeof(old) ~= "table" or typeof(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
				local data = cleanData(snapshot)
				if not release then data.Session = { Id = self.sessionId, Expires = os.time() + 180 } end
				return data
			end)
		end)
		if ok and typeof(value) == "table" then saved = true break end
		if ok and value == nil then
			profile.ready = false
			self:_sync(profile)
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	profile.saving = false
	if saved and release then profile.released = true end
	if saved and version == profile.version then profile.dirty = false end
	if not saved then warn("Playground profile save is pending for user " .. profile.player.UserId) end
	return saved
end

function Economy:_touch(profile)
	profile.version += 1
	profile.dirty = true
	self:_sync(profile)
end

function Economy:_clearAppearance(profile)
	if profile.pet then profile.pet:Destroy() profile.pet = nil end
	local character = profile.player.Character
	if character then
		for _, name in ipairs({ "PCOutline", "PCTrail", "PCTrailTop", "PCTrailBottom" }) do
			local object = character:FindFirstChild(name, true)
			if object then object:Destroy() end
		end
	end
end

function Economy:_applyAppearance(profile)
	self:_clearAppearance(profile)
	local character = profile.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not profile.ready or profile.closed then return end
	local equipped = profile.data.Equipped
	if equipped.Pet then
		local asset = self.assets:FindFirstChild(equipped.Pet)
		if asset then
			profile.pet = asset:Clone()
			profile.pet.Name = "Pet_" .. profile.player.UserId
			profile.pet.Parent = self.effects
			profile.pet:PivotTo(root.CFrame * CFrame.new(3, 0.5, 3))
		end
	end
	local outlineItem = Catalog.ById[equipped.Highlight]
	if outlineItem then
		local outline = Instance.new("Highlight")
		outline.Name = "PCOutline"
		outline.Adornee = character
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = outlineItem.color
		outline.Enabled = not (profile.player:GetAttribute("BBParticipating") == true or (profile.player:GetAttribute("TGParticipating") == true or profile.player:GetAttribute("MDParticipating") == true))
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
	end
	local trailItem = Catalog.ById[equipped.Trail]
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "PCTrailTop"
		top.Position = Vector3.new(0, 0.6, 1)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "PCTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 1)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PCTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = equipped.Trail == "RainbowTrail" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 93, 124)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 219, 64)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(75, 213, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(118, 126, 255)),
		}) or ColorSequence.new(trailItem.color, Color3.fromRGB(255, 94, 139))
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Parent = root
	end
end

function Economy:_bindPlayer(player)
	if self.profiles[player] then return end
	local profile = { player = player, data = cleanData(nil), ready = false, version = 0, pickups = {}, connections = {}, lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	self.profiles[player] = profile
	local board = player:FindFirstChild("leaderstats")
	if not board then board = Instance.new("Folder") board.Name = "leaderstats" board.Parent = player end
	for _, name in ipairs({ "Wins", "Coins", "Level" }) do
		if not board:FindFirstChild(name) then local counter = Instance.new("IntValue") counter.Name = name counter.Parent = board end
	end
	self:_sync(profile)
	table.insert(profile.connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 10)
			if self.profiles[player] == profile and character == player.Character and not profile.closed then self:_applyAppearance(profile) end
		end)
	end))
	task.spawn(function()
		while self.running and self.profiles[player] == profile and player.Parent == Players and not profile.ready do
			if self:_claim(profile) then
				if self.profiles[player] == profile and player.Parent == Players and not profile.closed then
					self:_sync(profile)
					self:_applyAppearance(profile)
				else
					self:_save(profile, true)
				end
				break
			end
			task.wait(10)
		end
	end)
end

function Economy:Status(player, ok, message)
	local profile = self.profiles[player]
	local xp = profile and integer(profile.data.XP, 0) or 0
	local level, levelXP, requiredXP = self:LevelProgress(xp)
	return { ok = ok, message = message or "", coins = profile and profile.data.Coins or 0, xp = xp, level = level, levelXP = levelXP, levelXPRequired = requiredXP, owned = profile and table.clone(profile.data.Owned) or {}, equipped = profile and table.clone(profile.data.Equipped) or {}, ready = profile and profile.ready == true }
end

function Economy:Handle(player, action, id)
	local profile = self.profiles[player]
	if not profile or profile.closed or not profile.ready then return self:Status(player, false, "Your items are still loading.") end
	if typeof(action) ~= "string" or not actions[action] then return self:Status(player, false, "Unknown shop control.") end
	local now = os.clock()
	local key = action == "GetStatus" and "lastStatus" or "lastMutation"
	if now - profile[key] < (action == "GetStatus" and 0.1 or 0.35) then return self:Status(player, false, "Please wait a moment.") end
	profile[key] = now
	if action == "GetStatus" then return self:Status(player, true) end
	if action == "Unequip" then
		if typeof(id) ~= "string" or not slots[id] then return self:Status(player, false, "Choose an item first.") end
		profile.data.Equipped[id] = nil
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Unequipped.")
	end
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not item or item.available == false then return self:Status(player, false, "This item is coming soon.") end
	if action == "Buy" then
		if profile.data.Owned[id] then return self:Status(player, false, "You already own this.") end
		if profile.data.Coins < item.price then return self:Status(player, false, "Collect a few more coins first.") end
		profile.data.Coins -= item.price
		profile.data.Owned[id] = true
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, item.name .. " is yours!")
	end
	if not profile.data.Owned[id] then return self:Status(player, false, "You don't own this yet.") end
	if action == "Equip" then
		profile.data.Equipped[item.slot] = id
		self:_touch(profile)
		self:_applyAppearance(profile)
		return self:Status(player, true, "Equipped " .. item.name .. ".")
	end
	if action == "UseEmote" or action == "UseEmoji" then
		if now - profile.lastExpression < 4 then return self:Status(player, false, "Give it a moment.") end
		if player:GetAttribute("BBParticipating") or (player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")) then return self:Status(player, false, "Try this between rounds.") end
		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end
		if item.slot ~= "Emoji" then return self:Status(player, false, "Choose an emoji.") end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then return self:Status(player, false, "Your character is loading.") end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "PCEmojiBubble"
		bubble.Size = UDim2.fromOffset(80, 80)
		bubble.StudsOffset = Vector3.new(0, 3.5, 0)
		bubble.AlwaysOnTop = false
		bubble.Adornee = head
		bubble.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = item.emoji
		text.TextColor3 = item.color
		text.TextStrokeColor3 = ink
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Parent = bubble
		Debris:AddItem(bubble, 2.5)
		return self:Status(player, true)
	end
	return self:Status(player, false, "Unknown shop control.")
end

function Economy:_publishReward(profile, coins, xp, won, roundReward)
	local player = profile.player
	profile.rewardSerial = (profile.rewardSerial or 0) + 1
	player:SetAttribute("PCRewardCoins", coins)
	player:SetAttribute("PCRewardXP", xp)
	player:SetAttribute("PCRewardWon", won == true)
	local message = "+" .. coins .. " coins"
	if roundReward then message ..= " · +" .. xp .. " XP · " .. (won and "Round won!" or "Round complete") end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardSerial", profile.rewardSerial)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Economy:_profileByUserId(id)
	for player, profile in pairs(self.profiles) do
		if player.UserId == id and player.Parent == Players then return profile end
	end
	return nil
end

function Economy:AwardRound(key, winnerIds, practice, participantIds, rewardOptions)
	if practice or typeof(key) ~= "string" or #key > 96 or self.awarded[key] or typeof(winnerIds) ~= "table" or typeof(participantIds) ~= "table" then return 0 end
	local participants, winners = {}, {}
	local function validId(id) return typeof(id) == "number" and id == id and id % 1 == 0 and math.abs(id) <= 1000000000000 end
	for _, id in ipairs(participantIds) do if validId(id) then participants[id] = true end end
	for _, id in ipairs(winnerIds) do if validId(id) and participants[id] then winners[id] = true end end
	if next(participants) == nil then return 0 end
	self.awarded[key] = true
	local rewarded = 0
	for id in pairs(participants) do
		local profile = self:_profileByUserId(id)
		if profile and profile.ready and not profile.closed and not profile.released then
			local won = winners[id] == true
			local coins = self:_setting(won and "WinnerCoins" or "LoserCoins", won and 150 or 50)
			local xp = self:_setting(won and "WinnerXP" or "LoserXP", 50)
			if typeof(rewardOptions) == "table" then xp = integer(won and rewardOptions.winnerXP or rewardOptions.loserXP, xp) end
			local beforeCoins = integer(profile.data.Coins, 0)
			local beforeXP = integer(profile.data.XP, 0)
			profile.data.Coins = integer(beforeCoins + coins, 0)
			profile.data.XP = integer(beforeXP + xp, 0)
			if won then profile.data.Wins = integer(profile.data.Wins + 1, 0) end
			self:_touch(profile)
			self:_publishReward(profile, profile.data.Coins - beforeCoins, profile.data.XP - beforeXP, won, true)
			rewarded += 1
		end
	end
	return rewarded
end

function Economy:_inside(position)
	local point = self.bounds.CFrame:PointToObjectSpace(position)
	local half = self.bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Economy:_buildCoins()
	for _, marker in ipairs(self.lobby.Gameplay.CoinSpawns:GetChildren()) do
		if marker:IsA("BasePart") then
			local coin = Instance.new("Part")
			coin.Name = "Coin_" .. marker.Name
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.65, 2.8, 2.8)
			coin.Color = Color3.fromRGB(255, 207, 59)
			coin.Material = Enum.Material.SmoothPlastic
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanTouch = false
			coin.CanQuery = false
			coin.CFrame = marker.CFrame
			coin.Parent = self.effects
			table.insert(self.coins, {
				id = marker:GetAttribute("PickupId") or marker.Name,
				value = math.clamp(integer(marker:GetAttribute("Value"), 2), 1, 10),
				cooldown = math.clamp(integer(marker:GetAttribute("RespawnSeconds"), 45), 15, 300),
				marker = marker, visual = coin,
			})
		end
	end
end

function Economy:_tick(dt)
	self.elapsed += dt
	if self.elapsed < 0.15 then return end
	self.elapsed = 0
	local now = workspace:GetServerTimeNow()
	for _, coin in ipairs(self.coins) do
		coin.visual.CFrame = coin.marker.CFrame * CFrame.new(0, math.sin(now * 2 + #coin.id) * 0.3, 0) * CFrame.Angles(0, now, 0)
	end
	for player, profile in pairs(self.profiles) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and profile.ready and not profile.closed then
			local participating = player:GetAttribute("BBParticipating") == true or (player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true)
			local outline = character:FindFirstChild("PCOutline")
			if outline then
				outline.Enabled = not participating
				if profile.data.Equipped.Highlight == "RainbowOutline" then outline.OutlineColor = Color3.fromHSV(now * 0.12 % 1, 0.72, 1) end
			end
			if profile.pet and profile.pet.Parent then
				local target = root.CFrame * CFrame.new(3.4, math.sin(now * 3) * 0.3, 3)
				profile.pet:PivotTo(profile.pet:GetPivot():Lerp(target, 0.55))
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not participating and humanoid and humanoid.Health > 0 and self:_inside(root.Position) then
				for _, coin in ipairs(self.coins) do
					if (root.Position - coin.marker.Position).Magnitude <= 5.5 and now - (profile.pickups[coin.id] or -math.huge) >= coin.cooldown then
						profile.pickups[coin.id] = now
						local beforeCoins = profile.data.Coins
						profile.data.Coins = integer(beforeCoins + coin.value, 0)
						self:_touch(profile)
						self:_publishReward(profile, profile.data.Coins - beforeCoins, 0, false, false)
					end
				end
			end
		end
	end
	if os.clock() - self.lastSave >= 60 then
		self.lastSave = os.clock()
		for _, profile in pairs(self.profiles) do task.spawn(function() self:_save(profile, false) end) end
	end
end

function Economy:Start()
	if self.running then return end
	self.running = true
	self:_buildCoins()
	local remote = ReplicatedStorage:WaitForChild("PlaygroundShopRequest")
	remote.OnServerInvoke = function(player, action, id) return self:Handle(player, action, id) end
	self.remote = remote
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local profile = self.profiles[player]
		if not profile then return end
		profile.closed = true
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
		self.profiles[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_bindPlayer(player) end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:_tick(dt) end))
	for _, attributeName in ipairs({"BaseLevelXP", "LevelXPStep"}) do
		table.insert(self.connections, self.lobby:GetAttributeChangedSignal(attributeName):Connect(function()
			for _, profile in pairs(self.profiles) do if not profile.closed then self:_sync(profile) end end
		end))
	end
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(self.profiles) do
			profile.closed = true
			pending += 1
			task.spawn(function() self:_save(profile, true) pending -= 1 end)
		end
		local untilTime = os.clock() + 25
		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
	end)
end

function Economy:Stop()
	self.running = false
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
	for _, profile in pairs(self.profiles) do profile.closed = true end
	for _, profile in pairs(self.profiles) do
		for _, connection in ipairs(profile.connections) do connection:Disconnect() end
		self:_clearAppearance(profile)
		self:_save(profile, true)
	end
	self.effects:Destroy()
	table.clear(self.profiles)
end

Economy.CleanData = cleanData
Economy.CalculateLevelProgress = levelProgress
return Economy
]=],
 ["PlaygroundAdminService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }

function Admin.new(coordinator, config, isStudio)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	if self.isStudio then return true end
	local id = player.UserId
	if game.CreatorType == Enum.CreatorType.User and id == game.CreatorId then return true end
	if id == self.config:GetAttribute("AdminUserId") then return true end
	local extra = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extra) == "string" then
		for value in string.gmatch(extra, "%d+") do if tonumber(value) == id then return true end end
	end
	return false
end

function Admin:Status(player, ok, message)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	return { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
end

function Admin:Handle(player, action)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.") end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.") end
	if self.busy then return self:Status(player, false, "Another control is finishing.") end
	self.busy = true
	local ok, success, message = pcall(function()
		if action == "StopRound" then return self.coordinator:StopGame() end
		if action == "ToggleAutomatic" then
			self.coordinator:SetAutoEnabled(not self.coordinator.autoEnabled)
			return true, self.coordinator.autoEnabled and "Automatic voting rounds are on." or "Automatic rounds paused."
		end
		local control = controls[action]
		local started, reason = self.coordinator:StartGame(control.game, player, control.role, false)
		if not started and reason == "Not enough ready players" then reason = "Use a solo button to test alone. Normal rounds need two players." end
		return started, started and "Starting your game." or reason
	end)
	self.busy = false
	if not ok then
		warn("Playground admin command failed: " .. tostring(success))
		return self:Status(player, false, "The game couldn't start. Try again.")
	end
	return self:Status(player, success == true, message)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action) return self:Handle(player, action) end
	local function bind(player) player:SetAttribute("PlaygroundAdmin", self:IsAuthorized(player)) end
	table.insert(self.connections, Players.PlayerAdded:Connect(bind))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastRequest[player] = nil self.lastStatus[player] = nil end))
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	table.insert(self.connections, config.AttributeChanged:Connect(function() for _, player in ipairs(Players:GetPlayers()) do bind(player) end end))
	return self
end

function Admin:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Admin
]=],
 ["TagService"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
Service.__index = Service
local runningService
local COLORS = { Runner = Color3.fromRGB(54, 174, 255), Tagger = Color3.fromRGB(255, 83, 100) }

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

function Service:_teleport(record, cframe)
	if not record.root or not record.root.Parent or not record.character then return end
	self:_stopBurst(record)
	record.character:PivotTo(cframe * record.root.CFrame:Inverse() * record.character:GetPivot())
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	if record.frozen then record.lockedCFrame = record.root.CFrame end
end

function Service:_restore(record)
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
	humanoid.WalkSpeed = record.frozen and 0 or self:_setting(record.role == "Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed", record.role == "Tagger" and 18 or 16, 0)
	humanoid.JumpPower = record.frozen and 0 or record.originalMovement.JumpPower
	humanoid.JumpHeight = record.frozen and 0 or record.originalMovement.JumpHeight
	humanoid.AutoRotate = not record.frozen and record.originalMovement.AutoRotate
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
		if record.root == burst.root and burst.root.Parent and not record.frozen and not record.isBot then
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
		if record.character == character then record.ready = false end
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

function Service:_canTag(from, target, now, rayParameters)
	if self.phase ~= "Playing" or now >= self.endsAt or not alive(from) or not alive(target)
		or not from.participating or not target.participating or from ~= self.tagger or target.role ~= "Runner"
		or now < (from.tagCooldownEndsAt or 0) or now < (target.protectedEndsAt or 0) then return false end
	local offset = target.root.Position - from.root.Position
	return offset.Magnitude <= self:_setting("TagDistance", 4.5, 1)
		and not workspace:Raycast(from.root.Position, offset, rayParameters or self:_rayParameters())
end

function Service:_transfer(target, now)
	local previous = self.tagger
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
	self.tagCount = self.tagCount + 1
	self:_publish()
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
		if bot.isBot and bot.participating and alive(bot) and now >= bot.nextBotMoveAt then
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
		end
	end
end

function Service:_tick()
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	self:_account(now)
	for _, record in pairs(self.records) do
		if record.participating and record.isBot and not alive(record) then self:_respawnBot(record) end
		if record.participating and alive(record) then
			if record.frozen and record.lockedCFrame then
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
		if self:_canTag(self.tagger, record, now, params) then
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
]=],
 ["MudHUD"]=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
local controls=main.Controls
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}
local previousZoom

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  if input.KeyCode==Enum.KeyCode.One then equip("MudGun")
  elseif input.KeyCode==Enum.KeyCode.Two then equip("HeatGun")
  else sprintKeys[input.KeyCode]=true sprintChange() end
 end
 return Enum.ContextActionResult.Sink
end
local function aimDirection()
 local camera=workspace.CurrentCamera
 local character=player.Character
 if not camera or not character then return nil end
 local tool=character:FindFirstChildOfClass("Tool")
 local handle=tool and tool:FindFirstChild("Handle")
 local muzzle=handle and handle:FindFirstChild("MuzzleAttachment")
 local root=character:FindFirstChild("HumanoidRootPart")
 if not muzzle and not root then return nil end
 local ray
 if UserInputService.TouchEnabled then
  ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
 else
  local pointer=UserInputService:GetMouseLocation()
  ray=camera:ScreenPointToRay(pointer.X,pointer.Y)
 end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 local target=hit and hit.Position or ray.Origin+ray.Direction*500
 local origin=muzzle and muzzle.WorldPosition or root.Position+Vector3.new(0,1,0)
 local direction=target-origin
 return direction.Magnitude>0.001 and direction.Unit or nil
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local participating=player:GetAttribute("MDParticipating")==true
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=participating
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift,Enum.KeyCode.One,Enum.KeyCode.Two)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if participating and not previousZoom then
  previousZoom={player.CameraMinZoomDistance,player.CameraMaxZoomDistance}
  player.CameraMinZoomDistance=math.min(12,player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=math.max(28,player.CameraMinZoomDistance)
 elseif not participating and previousZoom then
  player.CameraMinZoomDistance=math.min(previousZoom[1],player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=previousZoom[2]
  player.CameraMinZoomDistance=previousZoom[1]
  previousZoom=nil
 end
 if not participating then return end
 local phase=state:GetAttribute("Phase")
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 main.Top.Team.Text=string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or "")
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 controls.Visible=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 controls.Sprint.Text=(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT")
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Fire.Text=equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!"
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimDirection()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
connect(script.Destroying,function()
 release()
 if binding then ContextActionService:UnbindAction("MudControls") end
 if previousZoom then
  player.CameraMinZoomDistance=math.min(previousZoom[1],player.CameraMaxZoomDistance)
  player.CameraMaxZoomDistance=previousZoom[2]
  player.CameraMinZoomDistance=previousZoom[1]
 end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()
]=],
 ["TagSprint"]=[=[local Players=game:GetService("Players")
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
]=],
 ["TagHUD"]=[=[local Players = game:GetService("Players")
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
]=],
 ["PlaygroundAdminPanel"]=[=[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local compact = gui:WaitForChild("CompactPanel")
local panels = { panel, compact }
local toggles = { gui.Toggle, gui:WaitForChild("CompactToggle") }
local contents = { panel.Body.Content, compact.Body.Content }
local controls = {}
local function addControl(control)
	controls[control.Name] = controls[control.Name] or {}
	table.insert(controls[control.Name], control)
end
for index, content in ipairs(contents) do
	for _, card in ipairs(content:GetChildren()) do
		if card:IsA("Frame") then
			for _, control in ipairs(card:GetChildren()) do if control:IsA("TextButton") then addControl(control) end end
		end
	end
	local footer = index == 1 and panel or content
	addControl(footer.StopRound)
	addControl(footer.ToggleAutomatic)
end
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local busy = false
local opened = false
local connections = {}
local ink = Color3.fromRGB(24, 35, 62)
local failure = Color3.fromRGB(171, 38, 57)
local state = ReplicatedStorage:WaitForChild("PlaygroundState")
local bb = ReplicatedStorage:WaitForChild("BritishBulldogState")
local tag = ReplicatedStorage:WaitForChild("TagState")
local mud = ReplicatedStorage:WaitForChild("MudState")
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local function admin() return player:GetAttribute("PlaygroundAdmin") == true end
local function compactView()
	local camera = workspace.CurrentCamera
	return camera and (camera.ViewportSize.X < 980 or camera.ViewportSize.Y < 450) or false
end
local function syncVisibility()
	local enabled = admin()
	gui.Enabled = enabled
	if not enabled then opened = false end
	local useCompact = compactView()
	panel.Visible = enabled and opened and not useCompact
	compact.Visible = enabled and opened and useCompact
	gui.Toggle.Visible = not useCompact
	gui.CompactToggle.Visible = useCompact
	for _, toggle in ipairs(toggles) do toggle.Text = opened and "CLOSE" or "ADMIN" end
end
local function sync()
	syncVisibility()
	for action, duplicates in pairs(controls) do
		for _, control in ipairs(duplicates) do
			local enabled = admin() and not busy and (not mudActions[action] or mud:GetAttribute("GunAccessReady") == true)
			control.Active = enabled
			control.Selectable = enabled
			control.AutoButtonColor = enabled
			control.BackgroundColor3 = enabled and control:GetAttribute("ReadyColor") or Color3.fromRGB(162, 169, 184)
		end
	end
	for id, gameState in pairs({ BritishBulldog = bb, TagYoureIt = tag, StuckInTheMud = mud }) do
		local phase = gameState:GetAttribute("Phase") or "Waiting"
		local mode = gameState:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and mud:GetAttribute("GunAccessReady") ~= true then text = "Gun access pending" end
		for _, content in ipairs(contents) do content[id].Status.Text = text end
	end
	local text = state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF"
	for _, control in ipairs(controls.ToggleAutomatic) do control.Text = text end
end
local function request(action)
	if not admin() or busy then return end
	if mudActions[action] and mud:GetAttribute("GunAccessReady") ~= true then return end
	busy = true
	sync()
	local ok, response = pcall(function() return ReplicatedStorage.PlaygroundAdminRequest:InvokeServer(action) end)
	busy = false
	if admin() and gui.Parent then
		local text = ok and typeof(response) == "table" and response.message or "Server unavailable. Try again."
		local color = ok and typeof(response) == "table" and response.ok and ink or failure
		panel.Message.Text = text
		panel.Message.TextColor3 = color
		compact.Body.Content.Message.Text = text
		compact.Body.Content.Message.TextColor3 = color
	end
	sync()
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then task.spawn(request, "GetStatus") end
end
for action, duplicates in pairs(controls) do
	for _, control in ipairs(duplicates) do table.insert(connections, control.Activated:Connect(function() request(action) end)) end
end
for _, button in ipairs(toggles) do table.insert(connections, button.Activated:Connect(toggle)) end
for _, target in ipairs(panels) do table.insert(connections, target.Close.Activated:Connect(function() opened = false syncVisibility() end)) end
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end))
table.insert(connections, player:GetAttributeChangedSignal("PlaygroundAdmin"):Connect(sync))
for _, object in ipairs({ state, bb, tag, mud }) do table.insert(connections, object.AttributeChanged:Connect(sync)) end
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(delta)
	elapsed += delta
	if elapsed >= 0.15 then elapsed = 0 syncVisibility() end
end))
script.Destroying:Connect(function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
sync()
]=],
 ["PlaygroundShell"]=[=[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local shop=gui:WaitForChild("ShopPanel")
local vote=gui:WaitForChild("VotePanel")
local compactVote=gui:WaitForChild("CompactVotePanel")
local votePanels={vote,compactVote}
local wallet=gui:WaitForChild("Wallet")
local dock=gui:WaitForChild("Dock")
local toast=gui:WaitForChild("RewardToast")
local catalogObject=ReplicatedStorage:WaitForChild("PlaygroundCatalog",10)
if not catalogObject then warn("Playground catalog is unavailable") return end
local catalog=require(catalogObject)
local ink=Color3.fromRGB(27,45,61)
local white=Color3.fromRGB(255,255,248)
local gold=Color3.fromRGB(255,211,78)
local blue=Color3.fromRGB(89,193,244)
local pink=Color3.fromRGB(255,153,166)
local mint=Color3.fromRGB(130,225,180)
local muted=Color3.fromRGB(220,225,215)
local data={coins=player:GetAttribute("PCCoins") or 0,ready=player:GetAttribute("PCDataReady")==true,owned={},equipped={}}
local category="All"
local busy=false
local voteBusy=false
local toastToken=0
local cards={}
local previews={}
local lastReward=player:GetAttribute("PCRewardAt")
local wasInsideShop=false
local state=nil
local stateConnection=nil

local function showToast(message,duration)
 toastToken+=1
 local token=toastToken
 toast.Message.Text=tostring(message)
 toast.Visible=true
 task.delay(duration or 3.2,function()
  if token==toastToken and toast.Parent then toast.Visible=false end
 end)
end
local function refreshWallet()
 local coins=data.ready and tostring(data.coins or 0) or "..."
 wallet.Coins.Text=coins
 wallet.Wins.Text=tostring(player:GetAttribute("PCWins") or 0).." wins"
 shop.Coins.Text=coins.." coins"
end
local function refreshCards()
 refreshWallet()
 for _,item in ipairs(catalog.Items) do
  local card=cards[item.id]
  if card then
   local owned=data.owned[item.id]==true
   local equipped=data.equipped[item.slot]==item.id
   card.Visible=category=="All" or item.category==category
   card.Price.Text=item.available==false and "Coming later" or owned and (equipped and "Equipped" or "Owned") or tostring(item.price).." coins"
   card.Action.Text=item.available==false and "COMING SOON" or not data.ready and "LOADING" or equipped and "UNEQUIP" or owned and "EQUIP" or "BUY"
   card.Action.BackgroundColor3=(item.available==false or not data.ready) and muted or equipped and mint or owned and blue or gold
   card.Action.Active=not busy and data.ready and item.available~=false
   card.Action.Selectable=card.Action.Active
   card.Try.Visible=owned and (item.category=="Emotes" or item.category=="Emojis")
   card.Try.Active=not busy and data.ready
   card.Try.Selectable=card.Try.Active
   card.Outline.Color=equipped and gold or ink
  end
 end
 for _,button in ipairs(shop.Categories:GetChildren()) do
  if button:IsA("TextButton") then button.BackgroundColor3=button.Name==category and gold or white end
 end
end
local function applyReply(reply)
 if typeof(reply)~="table" then return end
 if typeof(reply.coins)=="number" then data.coins=reply.coins end
 if typeof(reply.ready)=="boolean" then data.ready=reply.ready or player:GetAttribute("PCDataReady")==true end
 if typeof(reply.owned)=="table" then data.owned=reply.owned end
 if typeof(reply.equipped)=="table" then data.equipped=reply.equipped end
 refreshCards()
end
local function playEmote(name)
 if typeof(name)~="string" then return end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not humanoid then return end
 local ok,played=pcall(function() return humanoid:PlayEmote(name) end)
 if not ok or not played then showToast("Your avatar could not play that emote.") end
end
local function request(action,id,quiet)
 if busy then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundShopRequest")
 if not remote or not remote:IsA("RemoteFunction") then
  if not quiet then
   shop.Status.Text="The shop is getting ready. Try again in a moment."
   if not shop.Visible then showToast("The shop is getting ready.") end
  end
  return
 end
 busy=true
 refreshCards()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(action,id) end)
  busy=false
  if ok and typeof(reply)=="table" then
   applyReply(reply)
   if not quiet or not reply.ok then shop.Status.Text=tostring(reply.message or (reply.ok and "All set!" or "Try again in a moment.")) end
   if not reply.ok and not shop.Visible and not quiet then showToast(reply.message or "Try again in a moment.") end
   if reply.ok and reply.emote then playEmote(reply.emote) end
  else
   refreshCards()
   if not quiet then
    shop.Status.Text="That did not go through. Try again in a moment."
    if not shop.Visible then showToast("Try again in a moment.") end
   end
  end
 end)
end
local function setShop(visible)
 shop.Visible=visible
 gui.Backdrop.Visible=visible
 if visible then
  shop.Status.Text=data.ready and "Pick a little something for your next round." or "Your coins are loading..."
  request("GetStatus",nil,true)
 end
end
local function setCategory(value)
 category=value
 refreshCards()
end
for _,card in ipairs(shop.Cards:GetChildren()) do
 if card:IsA("Frame") and card:GetAttribute("CatalogId") then
  local id=card:GetAttribute("CatalogId")
  local item=catalog.ById[id]
  if item then
   cards[id]=card
   local model=card.Preview.World:FindFirstChild("ItemModel")
   if model then table.insert(previews,{model=model,pivot=model:GetPivot()}) end
   card.Action.Activated:Connect(function()
    if busy or not data.ready or item.available==false then return end
    if data.equipped[item.slot]==id then request("Unequip",item.slot)
    elseif data.owned[id] then request("Equip",id)
    else request("Buy",id) end
   end)
   card.Try.Activated:Connect(function()
    if item.category=="Emotes" then request("UseEmote",id)
    elseif item.category=="Emojis" then request("UseEmoji",id) end
   end)
  end
 end
end
for _,button in ipairs(shop.Categories:GetChildren()) do
 if button:IsA("TextButton") then button.Activated:Connect(function() setCategory(button.Name) end) end
end
dock.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
shop.Close.Activated:Connect(function() setShop(false) end)
gui.Backdrop.Activated:Connect(function() setShop(false) end)
dock.Emote.Activated:Connect(function()
 local id=data.equipped.Emote
 if id then request("UseEmote",id)
 else setCategory("Emotes") setShop(true) shop.Status.Text="Equip an emote, then use it here." end
end)
dock.Emoji.Activated:Connect(function()
 local id=data.equipped.Emoji
 if id then request("UseEmoji",id)
 else setCategory("Emojis") setShop(true) shop.Status.Text="Equip an emoji, then use it here." end
end)
for _,attribute in ipairs({"PCCoins","PCWins","PCDataReady"}) do
 player:GetAttributeChangedSignal(attribute):Connect(function()
  local wasReady=data.ready
  data.coins=player:GetAttribute("PCCoins") or data.coins
  data.ready=player:GetAttribute("PCDataReady")==true
  refreshCards()
  if data.ready and not wasReady then request("GetStatus",nil,true) end
 end)
end
player:GetAttributeChangedSignal("PCRewardAt"):Connect(function()
 local now=player:GetAttribute("PCRewardAt")
 if now and now~=lastReward then
  lastReward=now
  local message=player:GetAttribute("PCRewardText")
  if typeof(message)=="string" and message~="" then showToast(message,4) end
 end
end)
local function insideZone(zone,root)
 if not zone or not zone:IsA("BasePart") or not root then return false end
 local point=zone.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X)<=zone.Size.X/2 and math.abs(point.Y)<=zone.Size.Y/2 and math.abs(point.Z)<=zone.Size.Z/2
end
local function votesText(count)
 return tostring(count)..(count==1 and " vote" or " votes")
end
local function refreshVotes()
 local phase=state and state:GetAttribute("Phase") or "Waiting"
 local voting=phase=="Voting"
 local chosen=player:GetAttribute("PCVote")
 for _,vote in ipairs(votePanels) do
 vote.Title.Text=voting and "PICK THE NEXT ROUND" or "NEXT ROUND"
 local ending=state and state:GetAttribute("VotingEndsAt") or 0
 vote.Timer.Text=voting and tostring(math.max(0,math.ceil(ending-workspace:GetServerTimeNow()))).."s" or phase=="Playing" and "PLAYING" or phase=="Paused" and "PAUSED" or "WAITING"
 vote.VotesBritishBulldog.Text=votesText(state and state:GetAttribute("VotesBritishBulldog") or 0)
 vote.VotesTagYoureIt.Text=votesText(state and state:GetAttribute("VotesTagYoureIt") or 0)
 vote.VotesStuckInTheMud.Text=votesText(state and state:GetAttribute("VotesStuckInTheMud") or 0)
 vote.BritishBulldog.BackgroundColor3=chosen=="BritishBulldog" and gold or blue
 vote.TagYoureIt.BackgroundColor3=chosen=="TagYoureIt" and gold or pink
 vote.StuckInTheMud.BackgroundColor3=chosen=="StuckInTheMud" and gold or mint
 vote.BritishBulldog.Active=voting and not voteBusy
 vote.TagYoureIt.Active=voting and not voteBusy
 local mudAvailable=state and state:GetAttribute("AvailableStuckInTheMud")~=false
 vote.StuckInTheMud.Active=voting and not voteBusy and mudAvailable
 if not mudAvailable then
  vote.StuckInTheMud.BackgroundColor3=Color3.fromRGB(162,169,184)
  local minimum=state:GetAttribute("MinimumStuckInTheMud") or 4
  vote.VotesStuckInTheMud.Text=(state:GetAttribute("ReadyPlayerCount") or 0)<minimum and "Needs "..tostring(minimum).." players" or "Unavailable"
 end
 vote.StuckInTheMud.Selectable=vote.StuckInTheMud.Active
 vote.BritishBulldog.Selectable=vote.BritishBulldog.Active
 vote.TagYoureIt.Selectable=vote.TagYoureIt.Active
 if not voteBusy then
  vote.Message.Text=voting and (chosen and chosen~="" and "Your vote is saved. You can change it." or "Step onto a card to vote, or tap it here.") or phase=="Playing" and "Another round is underway." or phase=="Paused" and "The next round is paused." or "Voting opens when the next round is ready."
 end
 end
end
local function bindState(object)
 if not object or object==state then return end
 if stateConnection then stateConnection:Disconnect() end
 state=object
 stateConnection=state.AttributeChanged:Connect(refreshVotes)
 refreshVotes()
end
bindState(ReplicatedStorage:FindFirstChild("PlaygroundState"))
ReplicatedStorage.ChildAdded:Connect(function(child) if child.Name=="PlaygroundState" then bindState(child) end end)
player:GetAttributeChangedSignal("PCVote"):Connect(refreshVotes)
local function castVote(id)
 if voteBusy or not state or state:GetAttribute("Phase")~="Voting" then return end
 local remote=ReplicatedStorage:FindFirstChild("PlaygroundVoteRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 voteBusy=true
 refreshVotes()
 task.spawn(function()
  local ok,reply=pcall(function() return remote:InvokeServer(id) end)
  voteBusy=false
  refreshVotes()
  if not ok then
   for _,panel in ipairs(votePanels) do panel.Message.Text="That vote did not go through. Try again." end
  elseif typeof(reply)=="table" and reply.ok==false then
   for _,panel in ipairs(votePanels) do panel.Message.Text=tostring(reply.message or "Step into the voting area first.") end
  end
 end)
end
for _,panel in ipairs(votePanels) do
 for _,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do panel[id].Activated:Connect(function() castVote(id) end) end
end
player.CharacterAdded:Connect(function() wasInsideShop=false end)
local elapsed=0
local previewTime=0
RunService.Heartbeat:Connect(function(delta)
 elapsed+=delta
 previewTime+=delta
 if elapsed<0.15 then return end
 elapsed=0
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local lobby=workspace:FindFirstChild("Playground Lobby")
 local gameplay=lobby and lobby:FindFirstChild("Gameplay")
 local participating=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 wallet.Visible=not participating
 dock.Visible=not participating
 if participating and shop.Visible then setShop(false) end
 local shopZone=gameplay and gameplay:FindFirstChild("ShopZone")
 local voteZone=gameplay and gameplay:FindFirstChild("VoteZone")
 local inShop=insideZone(shopZone,root)
 if inShop and not wasInsideShop and not participating then setShop(true) end
 wasInsideShop=inShop
 local showVote=not participating and insideZone(voteZone,root) and not shop.Visible
 local camera=workspace.CurrentCamera
 local useCompactVote=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 vote.Visible=showVote and not useCompactVote
 compactVote.Visible=showVote and useCompactVote
 if showVote then refreshVotes() end
 if shop.Visible then
  local rotation=math.sin(previewTime*0.45)*0.30
  for _,preview in ipairs(previews) do
   if preview.model.Parent then preview.model:PivotTo(preview.pivot*CFrame.Angles(0,rotation,0)) end
  end
 end
end)
refreshCards()
refreshVotes()
request("GetStatus",nil,true)
]=],
 ["PlayerLevel"]=[=[local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("LevelPanel")
local compact=gui:WaitForChild("CompactLevelPanel")
local panels={panel,compact}
local connections={}
local alive=true
local previewGeneration=0
local previewCharacter=nil
local previewPending=false

for _,target in ipairs(panels) do
 local viewport=target:WaitForChild("FacePreview")
 local camera=viewport:FindFirstChild("Camera")
 if not camera then
  camera=Instance.new("Camera")
  camera.Name="Camera"
  camera.FieldOfView=viewport:GetAttribute("PreviewFieldOfView") or 32
  camera.CFrame=viewport:GetAttribute("PreviewCameraCFrame") or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))
  camera.Parent=viewport
 end
 viewport.CurrentCamera=camera
end

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function progress(gradient,fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),NumberSequenceKeypoint.new(1,1)})
 end
end

local function sanitize(object)
 for _,descendant in ipairs(object:GetDescendants()) do
  local keep=descendant:IsA("BasePart") or descendant:IsA("DataModelMesh") or descendant:IsA("Decal") or descendant:IsA("Texture")
   or descendant:IsA("SurfaceAppearance") or descendant:IsA("Attachment") or descendant:IsA("Bone")
  if not keep then descendant:Destroy() end
 end
 local parts={}
 if object:IsA("BasePart") then table.insert(parts,object) end
 for _,descendant in ipairs(object:GetDescendants()) do if descendant:IsA("BasePart") then table.insert(parts,descendant) end end
 for _,part in ipairs(parts) do part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false part.CastShadow=false end
 return parts
end

local function clonePart(source)
 local ok,clone=pcall(function() return source:Clone() end)
 return ok and clone or nil
end

local function rebuildPreview()
 if not alive then return end
 local character=player.Character
 local head=character and character:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") then return end
 local generation=previewGeneration
 local headAttachments={}
 for _,attachment in ipairs(head:GetChildren()) do if attachment:IsA("Attachment") then headAttachments[attachment.Name]=true end end
 local prototype=Instance.new("Model")
 prototype.Name="AvatarPreview"
 local headClone=clonePart(head)
 if not headClone then prototype:Destroy() return end
 local headOrigin=head.CFrame
 local headParts=sanitize(headClone)
 for _,part in ipairs(headParts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
 headClone.Parent=prototype
 prototype.PrimaryPart=headClone
 for _,accessory in ipairs(character:GetChildren()) do
  if accessory:IsA("Accessory") then
   local handle=accessory:FindFirstChild("Handle")
   if handle and handle:IsA("BasePart") then
    local attachedToHead=false
    for _,attachment in ipairs(handle:GetChildren()) do
     if attachment:IsA("Attachment") and headAttachments[attachment.Name] then attachedToHead=true break end
     if attachment:IsA("Weld") and (attachment.Part0==head or attachment.Part1==head) then attachedToHead=true break end
    end
    if attachedToHead then
     local clone=clonePart(handle)
     if clone then
      clone.Name=accessory.Name
      local parts=sanitize(clone)
      for _,part in ipairs(parts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
      clone.Parent=prototype
     end
    end
   end
  end
 end
 if not alive or generation~=previewGeneration or character~=player.Character then prototype:Destroy() return end
 for _,target in ipairs(panels) do
  local viewport=target.FacePreview
  local world=viewport.World
  local clone=prototype:Clone()
  if clone then
   local old=world:FindFirstChild("AvatarPreview")
   if old then old:Destroy() end
   clone.Parent=world
   viewport.CurrentCamera=viewport.Camera
  end
 end
 prototype:Destroy()
end

local function schedulePreview()
 if previewPending then return end
 previewPending=true
 task.delay(0.12,function()
  previewPending=false
  rebuildPreview()
 end)
end

local characterConnection=nil
local function bindCharacter(character)
 previewGeneration+=1
 previewCharacter=character
 if characterConnection then characterConnection:Disconnect() characterConnection=nil end
 if character then
  characterConnection=character.DescendantAdded:Connect(function(descendant)
   if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Attachment") or descendant:IsA("SpecialMesh") then schedulePreview() end
  end)
 end
 schedulePreview()
end

local function refresh()
 local level=math.max(1,math.floor(numberAttribute("PCLevel",1)))
 local required=math.max(1,numberAttribute("PCLevelXPRequired",200+50*(level-1)))
 local xp=math.clamp(numberAttribute("PCLevelXP",0),0,required)
 panel.Level.Text="LEVEL "..tostring(level)
 compact.Level.Text="LV "..tostring(level)
 panel.XP.Text=string.format("%d / %d XP",math.floor(xp),math.floor(required))
 compact.XP.Text=string.format("%d / %d",math.floor(xp),math.floor(required))
 for _,target in ipairs(panels) do progress(target.XPTrack.Fill.Progress,xp/required) end
 local shop=gui:FindFirstChild("ShopPanel")
 local vote=gui:FindFirstChild("VotePanel")
 local compactVote=gui:FindFirstChild("CompactVotePanel")
 local mudHUD=gui.Parent and gui.Parent:FindFirstChild("MudHUD")
 local palette=mudHUD and mudHUD:FindFirstChild("ColourPicker")
 local modal=(shop and shop.Visible) or (vote and vote.Visible) or (compactVote and compactVote.Visible) or (mudHUD and mudHUD.Enabled and palette and palette.Visible)
 local camera=workspace.CurrentCamera
 local narrow=camera and (camera.ViewportSize.X<980 or camera.ViewportSize.Y<450) or false
 local inGame=player:GetAttribute("BBParticipating")==true or (player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true)
 local useCompact=narrow and inGame
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact
 if player.Character~=previewCharacter then bindCharacter(player.Character) end
end

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","BBParticipating","TGParticipating","MDParticipating"}) do connect(player:GetAttributeChangedSignal(name),refresh) end
connect(player.CharacterAdded,bindCharacter)
connect(player.CharacterRemoving,function() bindCharacter(nil) end)
connect(player.CharacterAppearanceLoaded,function(character) if character==player.Character then schedulePreview() end end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.15 then elapsed=0 refresh() end
end)
connect(script.Destroying,function()
 alive=false
 previewGeneration+=1
 if characterConnection then characterConnection:Disconnect() end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
bindCharacter(player.Character)
refresh()
]=],
 ["PlaygroundBootstrap"]=[=[local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldog = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local Tag = require(ServerScriptService:WaitForChild("TagService"))
local Mud = require(ServerScriptService:WaitForChild("StuckInTheMudService"))
local TagSprint = require(ServerScriptService:WaitForChild("TagSprintService"))
local Economy = require(ServerScriptService:WaitForChild("PlaygroundEconomyService"))
local Coordinator = require(ServerScriptService:WaitForChild("PlaygroundCoordinator"))
local Admin = require(ServerScriptService:WaitForChild("PlaygroundAdminService"))

local lobby = workspace:WaitForChild("Playground Lobby")
local britishBulldog = BritishBulldog.new(workspace:WaitForChild("British Bulldog game"))
local tag = Tag.new(workspace:WaitForChild("Tag You're It"))
local mud = Mud.new(workspace:WaitForChild("Stuck in the Mud"))
local tagSprint = TagSprint.new(tag)
local spawn = lobby.Gameplay.LobbySpawn
britishBulldog.lobbySpawn = spawn
tag.lobbySpawn = spawn
mud.lobbySpawn = spawn
britishBulldog:Start()
tag:Start()
mud:Start()
tagSprint:Start()
local economy = Economy.new(lobby)
economy:Start()
local coordinator = Coordinator.new({ BritishBulldog = britishBulldog, TagYoureIt = tag, StuckInTheMud = mud }, lobby, economy)
coordinator:Start()
local admin = Admin.Start(coordinator)
script:SetAttribute("Ready", true)
]=],
}
local function buildMudArena()
local name="Stuck in the Mud"
local existing=workspace:FindFirstChild(name)
if existing then return {built=false,preserved=true,folder=existing:GetFullName()} end
local center=Vector3.new(8800,32.9,4534)
local ink=Color3.fromRGB(28,43,62)
local cream=Color3.fromRGB(255,239,194)
local white=Color3.fromRGB(255,253,235)
local grass=Color3.fromRGB(134,194,83)
local grassLight=Color3.fromRGB(149,205,97)
local paving=Color3.fromRGB(217,209,183)
local brick=Color3.fromRGB(234,143,112)
local blue=Color3.fromRGB(88,174,224)
local coral=Color3.fromRGB(247,127,113)
local gold=Color3.fromRGB(255,205,77)
local mint=Color3.fromRGB(111,196,151)
local purple=Color3.fromRGB(175,149,218)
local arena=Instance.new("Folder")
arena.Name=name
local function folder(label,parent)
 local object=Instance.new("Folder") object.Name=label object.Parent=parent return object
end
local geometry=folder("Geometry",arena)
local scenery=folder("Scenery",arena)
local gameplay=folder("Gameplay",arena)
local perimeter=folder("Perimeter",geometry)
local artwork=folder("FloorArtwork",geometry)
local landmarks=folder("Landmarks",geometry)
local coverFolder=folder("DistributedCover",geometry)
local elevated=folder("ElevatedRoutes",geometry)
local coverVolumes=folder("CoverVolumes",gameplay)
local rescueAreas=folder("RescueAreas",gameplay)
local obstacleBoxes={}
local coverPositions={}
local partCount=0
local cubbyCount=0
local coverCount=0
local function obstacle(part)
 if not part.CanCollide then return end
 local lo=Vector3.new(math.huge,math.huge,math.huge)
 local hi=Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
  local point=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-center
  lo=Vector3.new(math.min(lo.X,point.X),math.min(lo.Y,point.Y),math.min(lo.Z,point.Z))
  hi=Vector3.new(math.max(hi.X,point.X),math.max(hi.Y,point.Y),math.max(hi.Z,point.Z))
 end end end
 if lo.Y<7.8 and hi.Y>0.2 then table.insert(obstacleBoxes,{x1=lo.X-3.2,x2=hi.X+3.2,z1=lo.Z-3.2,z2=hi.Z+3.2}) end
end
local function part(label,size,position,color,parent,collide,shape,rotation)
 local object=Instance.new("Part")
 object.Name=label object.Size=size object.CFrame=CFrame.new(center+position)*(rotation or CFrame.identity)
 object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
 object.CanCollide=collide==true object.CanTouch=false object.CanQuery=collide==true object.CastShadow=collide==true
 object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth
 if shape then object.Shape=shape end
 object.Parent=parent partCount+=1 obstacle(object) return object
end
local function block(label,x,y,z,px,py,pz,color,parent,collide)
 return part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,collide)
end
local function ball(label,x,y,z,px,py,pz,color,parent)
 return part(label,Vector3.new(x,y,z),Vector3.new(px,py,pz),color,parent,false,Enum.PartType.Ball)
end
local function cylinder(label,diameter,height,position,color,parent,collide)
 return part(label,Vector3.new(height,diameter,diameter),position,color,parent,collide,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
end
local function paint(label,x,z,px,pz,color,y)
 return block(label,x,0.06,z,px,y or 0.045,pz,color,artwork,false)
end
local function line(label,a,b,width,color,y)
 local delta=b-a
 local object=part(label,Vector3.new(width,0.07,delta.Magnitude),Vector3.new((a.X+b.X)/2,y or 0.08,(a.Z+b.Z)/2),color,artwork,false)
 object.CFrame=CFrame.lookAt(object.Position,center+Vector3.new(b.X,y or 0.08,b.Z))
 return object
end
local function surface(label,x,z,px,pz,top,color,parent,route,width)
 local object=block(label.."Ink",x,1.4,z,px,top-0.7,pz,ink,parent,true)
 object:SetAttribute("Walkable",true) object:SetAttribute("RouteId",route) object:SetAttribute("TopHeight",top)
 object:SetAttribute("PathWidth",width or math.min(x,z)) object:SetAttribute("JumpGap",0)
 block(label.."Surface",x-0.5,0.1,z-0.5,px,top+0.05,pz,color,parent,false)
 return object
end
local function ramp(label,p0,p1,width,color,parent,route)
 local a,b=center+p0,center+p1 local delta=b-a
 local frame=CFrame.lookAt((a+b)/2,b)
 local object=Instance.new("Part") object.Name=label.."Ink" object.Size=Vector3.new(width,1.4,delta.Magnitude)
 object.CFrame=frame-frame.UpVector*0.7 object.Color=ink object.Material=Enum.Material.SmoothPlastic
 object.Anchored=true object.CanCollide=true object.CanTouch=false object.CanQuery=true object.Parent=parent
 partCount+=1 obstacle(object)
 object:SetAttribute("Walkable",true) object:SetAttribute("IsRamp",true) object:SetAttribute("RouteId",route)
 object:SetAttribute("PathWidth",width) object:SetAttribute("Rise",math.abs(p1.Y-p0.Y))
 object:SetAttribute("Run",Vector2.new(p1.X-p0.X,p1.Z-p0.Z).Magnitude)
 object:SetAttribute("FromHeight",p0.Y) object:SetAttribute("ToHeight",p1.Y) object:SetAttribute("JumpGap",0)
 local fill=part(label.."Surface",Vector3.new(width-0.6,0.12,delta.Magnitude-0.1),Vector3.zero,color,parent,false)
 fill.CFrame=frame+frame.UpVector*0.06
 for _,side in ipairs({-1,1}) do
  local trim=part(label.."CreamEdge",Vector3.new(0.5,0.14,delta.Magnitude-0.2),Vector3.zero,cream,parent,false)
  trim.CFrame=frame+frame.RightVector*(side*(width/2-0.7))+frame.UpVector*0.15
 end
 return object
end
local function marker(label,position,size,parent)
 local object=part(label,size,position,white,parent,false) object.Transparency=1 object.CastShadow=false return object
end
local function coverVolume(label,position,size,kind)
 local object=marker(label,position,size,coverVolumes)
 object:SetAttribute("CoverKind",kind) object:SetAttribute("NearbyRescueSpace",true)
 coverCount+=1 table.insert(coverPositions,Vector2.new(position.X,position.Z)) return object
end

block("EarthIsland",864,40,864,0,-30,0,Color3.fromRGB(149,104,70),geometry,true)
block("IslandInk",864,8,864,0,-4,0,ink,geometry,true)
block("PlaygroundFloor",832,2,832,0,-1,0,grass,geometry,true)
for index=-8,8 do paint("MownStripe"..index,48,832,index*48,0,index%2==0 and grassLight or grass) end
paint("CentralNorthSouthInk",30,792,0,0,ink,0.1)
paint("CentralNorthSouthPaving",24,788,0,0,cream,0.15)
paint("CentralEastWestInk",792,30,0,0,ink,0.1)
paint("CentralEastWestPaving",788,24,0,0,cream,0.15)
for _,side in ipairs({-1,1}) do
 paint("PerimeterPathX",22,788,side*370,0,paving,0.12)
 paint("PerimeterPathZ",788,22,0,side*370,paving,0.12)
 block("FenceXInk",6,34,844,side*419,17,0,ink,perimeter,true)
 block("FenceZInk",844,34,6,0,17,side*419,ink,perimeter,true)
 block("FenceXPanels",0.3,26,832,side*415.8,16,0,blue,perimeter,false)
 block("FenceZPanels",832,26,0.3,0,16,side*415.8,blue,perimeter,false)
 block("FenceXCap",7.8,1.4,846,side*419,34,0,cream,perimeter,false)
 block("FenceZCap",846,1.4,7.8,0,34,side*419,cream,perimeter,false)
 for index=-8,8 do
  block("FenceXPost",1,30,2,side*415.5,16,index*48,cream,perimeter,false)
  block("FenceZPost",2,30,1,index*48,16,side*415.5,cream,perimeter,false)
 end
end
cylinder("CentralMeetingInk",52,0.12,Vector3.new(0,0.23,0),ink,artwork,false)
cylinder("CentralMeetingCream",48,0.12,Vector3.new(0,0.30,0),cream,artwork,false)
cylinder("CentralMeetingGold",29,0.12,Vector3.new(0,0.37,0),gold,artwork,false)
for index=1,8 do
 local angle=index*math.pi/4
 cylinder("MeetingDot",3.2,0.08,Vector3.new(math.cos(angle)*19,0.41,math.sin(angle)*19),white,artwork,false)
end

local function classroom(index,x,color)
 local room=folder(string.format("Classroom%02d",index),landmarks)
 room:SetAttribute("Landmark","Classroom") room:SetAttribute("TwoExits",true) room:SetAttribute("ExitWidth",16)
 paint("ClassroomPaving",102,82,x,-312,paving,0.07)
 for _,side in ipairs({-1,1}) do
  block("SideWallInk",2.5,21,58,x+side*45,10.5,-312,ink,room,true)
  block("SideWallBrick",0.2,19,56,x+side*43.65,10.5,-312,color,room,false)
  for _,half in ipairs({-1,1}) do
   block("DoorWallInk",36,21,2.5,x+half*27,10.5,-312+side*29,ink,room,true)
   block("DoorWallColor",34,19,0.22,x+half*27,10.5,-312+side*27.65,color,room,false)
  end
  block("DoorLintelInk",18,4,2.7,x,19,-312+side*29,ink,room,true)
  for _,windowX in ipairs({-27,27}) do
   block("WindowInk",19,10,0.25,x+windowX,13,-312+side*30.4,ink,room,false)
   block("WindowCream",16.4,7.6,0.28,x+windowX,13,-312+side*30.6,cream,room,false)
   block("WindowBlue",14.2,5.4,0.30,x+windowX,13,-312+side*30.8,Color3.fromRGB(154,217,231),room,false)
   block("WindowMullion",0.65,5.5,0.35,x+windowX,13,-312+side*31,cream,room,false)
  end
 end
 block("RoofInk",96,4,66,x,23,-312,ink,room,false):SetAttribute("DecorativeRoof",true)
 block("RoofCream",93,2,63,x,24.5,-312,cream,room,false):SetAttribute("DecorativeRoof",true)
 for _,side in ipairs({-1,1}) do
  block("DeskInk",20,3,8,x+side*26,1.5,-308,ink,room,true)
  block("DeskWood",19,0.4,7.5,x+side*26,3.2,-308,gold,room,false)
  block("BookcaseInk",14,7,3,x+side*34,3.5,-329,ink,room,true)
  for row=1,3 do
   for book=1,6 do block("BookSpine",1.7,1.6,0.25,x+side*34-5.2+book*1.6,row*1.8,-327.3,({blue,coral,gold,mint,purple,cream})[book],room,false) end
  end
 end
 marker("DoorA",Vector3.new(x,3.6,-344),Vector3.new(14,1,10),room)
 marker("DoorB",Vector3.new(x,3.6,-280),Vector3.new(14,1,10),room)
 coverVolume(room.Name,Vector3.new(x,10,-312),Vector3.new(92,20,60),"Classroom")
end
classroom(1,-120,brick) classroom(2,0,gold) classroom(3,120,coral)
paint("ClassroomCourtyardInk",348,84,0,-228,ink,0.11)
paint("ClassroomCourtyard",340,76,0,-228,paving,0.17)
for _,x in ipairs({-144,-96,-48,48,96,144}) do
 cylinder("CourtyardPlanterInk",15,3.2,Vector3.new(x,1.6,-246),ink,landmarks,true)
 cylinder("CourtyardPlanterTerracotta",13,1.1,Vector3.new(x,3.1,-246),coral,landmarks,false)
 ball("CourtyardShrub",14,7,14,x,6,-246,mint,scenery)
 coverVolume("CourtyardPlanter",Vector3.new(x,3,-246),Vector3.new(15,6,15),"Planter")
end

local function playfort(index,cx,cz,color)
 local route=folder(string.format("Playfort%02d",index),elevated)
 local id=route.Name
 route:SetAttribute("RouteId",id) route:SetAttribute("GroundRouteConnected",true)
 route:SetAttribute("IndependentAccesses",4) route:SetAttribute("MaximumHeight",12)
 paint("PlayfortSoftFallInk",242,142,cx,cz,ink,0.10)
 paint("PlayfortSoftFall",234,134,cx,cz,color,0.16)
 surface("WestLoop",18,120,cx-51,cz,12,color,route,id,18)
 surface("EastLoop",18,120,cx+51,cz,12,color,route,id,18)
 surface("NorthLoop",84,18,cx,cz-51,12,color,route,id,18)
 surface("SouthLoop",84,18,cx,cz+51,12,color,route,id,18)
 for _,dx in ipairs({-48,48}) do for _,dz in ipairs({-48,48}) do
  block("SupportInk",4,10.6,4,cx+dx,5.3,cz+dz,ink,route,true)
  block("SupportCream",2.8,10,4.2,cx+dx,5.3,cz+dz,cream,route,false)
  ball("SupportButton",5.6,5.6,5.6,cx+dx,15.2,cz+dz,color,scenery)
 end end
 ramp("WestAccess",Vector3.new(cx-108,0.18,cz-30),Vector3.new(cx-60,12,cz-30),16,color,route,id)
 ramp("EastAccess",Vector3.new(cx+108,0.18,cz+30),Vector3.new(cx+60,12,cz+30),16,color,route,id)
 ramp("WideSlide",Vector3.new(cx,0.18,cz-108),Vector3.new(cx,12,cz-60),14,gold,route,id)
 for step=1,4 do
  local top=step*3 local z=cz+96-step*8
  local object=block("Step"..step.."Ink",14,top,8,cx-24,top/2,z,ink,route,true)
  object:SetAttribute("Walkable",true) object:SetAttribute("RouteId",id) object:SetAttribute("PathWidth",14)
  object:SetAttribute("IsStep",true) object:SetAttribute("StepRise",3) object:SetAttribute("TopHeight",top) object:SetAttribute("JumpGap",0)
  block("Step"..step.."Color",13.5,0.12,7.5,cx-24,top+0.06,z,color,route,false)
 end
 for _,side in ipairs({-1,1}) do
  block("LoopEdgeCreamX",0.7,0.16,114,cx+side*58,12.18,cz,cream,route,false)
  block("LoopEdgeCreamZ",114,0.16,0.7,cx,12.18,cz+side*58,cream,route,false)
 end
 for _,dx in ipairs({-24,24}) do
  block("UnderFortScreenInk",14,7,3,cx+dx,3.5,cz,ink,route,true)
  block("UnderFortScreenColor",12.5,5.5,0.25,cx+dx,3.5,cz+1.7,color,route,false)
 end
 coverVolume(id,Vector3.new(cx,6,cz),Vector3.new(120,12,120),"Playfort")
end
playfort(1,-228,-156,blue) playfort(2,228,-156,mint)
playfort(3,-228,156,coral) playfort(4,228,156,purple)

local monkey=folder("MonkeyBars",landmarks) monkey:SetAttribute("Landmark","MonkeyBars")
paint("MonkeySoftFall",102,48,-300,0,gold,0.2)
for _,dx in ipairs({-38,38}) do for _,dz in ipairs({-18,18}) do
 block("MonkeyPostInk",3.6,11,3.6,-300+dx,5.5,dz,ink,monkey,true)
 block("MonkeyPostColor",2.4,10.6,3.8,-300+dx,5.5,dz,blue,monkey,false)
end end
for _,dz in ipairs({-18,18}) do block("MonkeyHeader",84,2,2.8,-300,10,dz,coral,monkey,false) end
for rung=1,9 do block("MonkeyRung",1.4,1.4,37,-340+rung*8,10,0,cream,monkey,false) end
coverVolume("MonkeyBars",Vector3.new(-300,5,0),Vector3.new(84,10,40),"PlayEquipment")
local swings=folder("Swings",landmarks) swings:SetAttribute("Landmark","Swings")
paint("SwingSoftFall",106,56,300,0,coral,0.22)
for _,dx in ipairs({-44,44}) do for _,dz in ipairs({-22,22}) do
 block("SwingPostInk",3.6,14,3.6,300+dx,7,dz,ink,swings,true)
 block("SwingPostColor",2.4,13.5,3.8,300+dx,7,dz,gold,swings,false)
end end
block("SwingHeaderInk",92,3,4,300,13.5,0,ink,swings,false)
block("SwingHeaderCream",89,1.5,4.2,300,14.3,0,cream,swings,false)
for _,dx in ipairs({-25,0,25}) do
 for _,side in ipairs({-1,1}) do block("SwingRope",0.35,10.6,0.35,300+dx+side*5,7.8,0,ink,swings,false) end
 block("SwingSeatInk",14,1,6,300+dx,2.3,0,ink,swings,false)
 block("SwingSeatColor",12.5,0.6,5,300+dx,2.8,0,blue,swings,false)
end
coverVolume("Swings",Vector3.new(300,6,0),Vector3.new(92,12,48),"PlayEquipment")

local pitch=folder("RoundersPitch",landmarks) pitch:SetAttribute("Landmark","Rounders")
paint("RoundersMownField",270,116,0,304,grassLight,0.20)
local bases={Vector3.new(0,0,250),Vector3.new(88,0,304),Vector3.new(0,0,356),Vector3.new(-88,0,304)}
for index=1,4 do
 line("RoundersDiamond",bases[index],bases[index%4+1],1.4,cream,0.25)
 cylinder("RoundersBaseInk",11,0.12,bases[index]+Vector3.new(0,0.30,0),ink,artwork,false)
 cylinder("RoundersBase",8.5,0.12,bases[index]+Vector3.new(0,0.38,0),white,artwork,false)
end
for side=-1,1,2 do
 block("PitchEquipmentBoxInk",28,5,9,side*110,2.5,304,ink,pitch,true)
 block("PitchEquipmentBoxCream",26,3.5,9.2,side*110,2.7,304,cream,pitch,false)
 coverVolume("PitchEquipment",Vector3.new(side*110,2.5,304),Vector3.new(28,5,9),"SportsStorage")
end
local games=folder("PaintedGames",landmarks) games:SetAttribute("Landmark","HopscotchBeanbags")
for index=1,10 do
 local z=42+index*9 local x=index%3==0 and 8 or -8
 paint("HopscotchInk",8.2,8.2,-52+x,z,ink,0.24)
 paint("HopscotchTile",6.6,6.6,-52+x,z,({blue,gold,coral,mint})[index%4+1],0.3)
 for dot=1,index do cylinder("HopscotchDot",0.75,0.08,Vector3.new(-52+x-2+(dot-1)%4*1.3,0.36,z-2+math.floor((dot-1)/4)*1.3),white,artwork,false) end
end
for _,z in ipairs({-66,66}) do
 cylinder("BeanbagTargetInk",18,0.12,Vector3.new(54,0.30,z),ink,artwork,false)
 cylinder("BeanbagTargetCream",14,0.12,Vector3.new(54,0.38,z),cream,artwork,false)
 cylinder("BeanbagTargetColor",7,0.12,Vector3.new(54,0.46,z),gold,artwork,false)
end

local function bench(label,x,z,color,parent,turn)
 local rotation=CFrame.Angles(0,turn or 0,0)
 local function add(n,size,offset,c,collide)
  return part(n,size,Vector3.new(x,0,z)+rotation:VectorToWorldSpace(offset),c,parent,collide,nil,rotation)
 end
 add(label.."SeatInk",Vector3.new(24,2.8,7),Vector3.new(0,1.4,0),ink,true)
 add(label.."SeatColor",Vector3.new(22.5,0.6,6),Vector3.new(0,3,0),color,false)
 add(label.."BackInk",Vector3.new(24,6,2.2),Vector3.new(0,3,-3.5),ink,true)
 add(label.."BackCream",Vector3.new(22,4.5,0.22),Vector3.new(0,3,-2.25),cream,false)
 coverVolume(label,Vector3.new(x,3,z),Vector3.new(26,6,12),"Bench")
end
local function cubby(label,x,z,color,turn)
 cubbyCount+=1
 local model=folder(label,coverFolder)
 model:SetAttribute("CoverCubby",true) model:SetAttribute("TwoExits",true) model:SetAttribute("ExitWidth",20)
 model:SetAttribute("ClearInteriorHeight",10) model:SetAttribute("GroundRouteConnected",true)
 local rotation=CFrame.Angles(0,turn or 0,0)
 local origin=Vector3.new(x,0,z)
 for _,side in ipairs({-1,1}) do
  local wall=part("CubbyWallInk",Vector3.new(2,10,24),origin+rotation:VectorToWorldSpace(Vector3.new(side*11,5,0)),ink,model,true,nil,rotation)
  part("CubbyWallColor",Vector3.new(0.2,8.4,22),origin+rotation:VectorToWorldSpace(Vector3.new(side*9.9,5,0)),color,model,false,nil,rotation)
  for rung=1,3 do part("CubbyWallPanel",Vector3.new(0.24,0.45,21),origin+rotation:VectorToWorldSpace(Vector3.new(side*9.7,rung*2.7,0)),cream,model,false,nil,rotation) end
 end
 part("CubbyRoofInk",Vector3.new(26,1.2,28),origin+Vector3.new(0,10.6,0),ink,model,false,nil,rotation):SetAttribute("DecorativeRoof",true)
 part("CubbyRoofColor",Vector3.new(24.5,0.8,26.5),origin+Vector3.new(0,11.2,0),color,model,false,nil,rotation):SetAttribute("DecorativeRoof",true)
 for _,side in ipairs({-1,1}) do
  local door=marker(side==-1 and "DoorA" or "DoorB",origin+rotation:VectorToWorldSpace(Vector3.new(0,3.6,side*17)),Vector3.new(20,1,10),model)
  door.CFrame=CFrame.new(door.Position)*rotation door:SetAttribute("ExitWidth",20)
 end
 coverVolume(label,origin+Vector3.new(0,5,0),Vector3.new(26,10,28),"TwoExitCubby")
end
local function storage(label,x,z,color)
 local model=folder(label,coverFolder)
 block("StorageInk",18,8,8,x,4,z,ink,model,true)
 block("StorageColor",16.5,6.5,0.2,x,4,z+4.15,color,model,false)
 for side=-1,1,2 do
  block("StorageDoorTrim",0.5,6.5,0.3,x+side*4,4,z+4.3,cream,model,false)
  block("StorageHandle",0.6,1.6,0.5,x+side*2,4,z+4.5,ink,model,false)
 end
 coverVolume(label,Vector3.new(x,4,z),Vector3.new(18,8,8),"Storage")
end
local function beanbags(label,x,z,color)
 local model=folder(label,coverFolder)
 for _,dx in ipairs({-6,6}) do
  local bag=part("BeanbagInk",Vector3.new(14,4,12),Vector3.new(x+dx,2,z),ink,model,true,Enum.PartType.Ball)
  ball("BeanbagColor",12.6,3.2,10.6,x+dx,2.3,z,color,model)
 end
 block("BeanbagScreenInk",22,5,2,x,2.5,z-6,ink,model,true)
 block("BeanbagScreenColor",20.5,3.5,0.22,x,2.5,z-4.85,color,model,false)
 coverVolume(label,Vector3.new(x,2.5,z),Vector3.new(26,5,16),"Beanbags")
end
local function excluded(x,z)
 if math.abs(x)<18 or math.abs(z)<18 then return true end
 if math.abs(x)<181 and z>-358 and z<-185 then return true end
 for _,cx in ipairs({-228,228}) do for _,cz in ipairs({-156,156}) do
  if math.abs(x-cx)<126 and math.abs(z-cz)<118 then return true end
 end end
 if math.abs(x+300)<58 and math.abs(z)<44 then return true end
 if math.abs(x-300)<60 and math.abs(z)<50 then return true end
 return false
end
local station=0
for ix=-7,7 do for iz=-7,7 do
 local x,z=ix*48,iz*48
 if not excluded(x,z) then
  station+=1 local color=({blue,coral,gold,mint,purple})[station%5+1]
  local label=string.format("SchoolyardCover%03d",station)
  if station%4==0 then cubby(label,x,z,color,station%8==0 and math.pi/2 or 0)
  elseif station%4==1 then bench(label,x,z,color,coverFolder,station%2==0 and math.pi/2 or 0)
  elseif station%4==2 then storage(label,x,z,color)
  else beanbags(label,x,z,color) end
 end
end end
for _,x in ipairs({-348,-300,-252,-204,-156,-108,-60,60,108,156,204,252,300,348}) do
 bench("OuterSchoolBench",x,-360,({blue,coral,gold,mint})[math.floor(math.abs(x)/12)%4+1],coverFolder,0)
end
for _,x in ipairs({-348,-252,-156,-60,60,156,252,348}) do
 storage("SouthernSchoolStorage",x,362,({blue,coral,gold,mint})[math.floor(math.abs(x)/12)%4+1])
end
for _,x in ipairs({-96,-48,48,96}) do
 bench("CourtyardBench",x,-198,coral,landmarks,0)
end
for _,x in ipairs({-364,364}) do for _,z in ipairs({-144,144}) do
 local label="OuterSideCubby"..(x<0 and "West" or "East")..(z<0 and "North" or "South")
 cubby(label,x,z,x<0 and blue or mint,0)
end end
for _,side in ipairs({-1,1}) do
 for index=-3,3 do
  local x,z=side*399,index*104
  block("TreeTrunkInk",5,11,5,x,5.5,z,ink,scenery,false)
  block("TreeTrunkBrown",3.6,10.5,5.2,x,5.5,z,Color3.fromRGB(148,97,68),scenery,false)
  ball("TreeCrownInk",28,23,28,x,21,z,ink,scenery)
  ball("TreeCrownGreen",25,21,25,x,21.5,z,mint,scenery)
  ball("TreeCrownLight",14,12,14,x-4,26,z-3,grassLight,scenery)
 end
end

local bounds=marker("ArenaBounds",Vector3.new(0,60,0),Vector3.new(832,120,832),gameplay)
local groups=folder("TeamSpawns",gameplay)
local starts=folder("StartPads",gameplay)
local spawnList={Vector3.new(-264,0,-388),Vector3.new(0,0,-388),Vector3.new(264,0,-388),Vector3.new(388,0,-264),Vector3.new(388,0,0),Vector3.new(388,0,264),Vector3.new(264,0,388),Vector3.new(0,0,388),Vector3.new(-264,0,388),Vector3.new(-388,0,264),Vector3.new(-388,0,0),Vector3.new(-388,0,-264)}
for index,position in ipairs(spawnList) do
 local group=folder(string.format("Group%02d",index),groups)
 group:SetAttribute("TeamId",index) group:SetAttribute("TeamIndex",index) group:SetAttribute("Capacity",12)
 cylinder("SpawnCircleInk",35,0.1,position+Vector3.new(0,0.23,0),ink,artwork,false)
 cylinder("SpawnCircleCream",31,0.1,position+Vector3.new(0,0.30,0),cream,artwork,false)
 cylinder("SpawnCircleColor",23,0.1,position+Vector3.new(0,0.37,0),({blue,coral,gold,mint,purple})[index%5+1],artwork,false)
 local facing=CFrame.lookAt(center+position,center+Vector3.new(0,0,0))
 for padIndex=1,12 do
  local column=(padIndex-1)%4 local row=math.floor((padIndex-1)/4)
  local p=position+facing.RightVector*((column-1.5)*6)+facing.LookVector*((row-1)*6)+Vector3.new(0,3.6,0)
  local pad=marker(string.format("%02d",padIndex),p,Vector3.new(3,1,3),group)
  pad.CFrame=CFrame.lookAt(pad.Position,Vector3.new(center.X,pad.Position.Y,center.Z))
  pad:SetAttribute("TeamId",index) pad:SetAttribute("TeamIndex",index)
  if padIndex==4 or padIndex==9 then
   local start=pad:Clone() start.Name=string.format("%02d",(index-1)*2+(padIndex==4 and 1 or 2)) start.Parent=starts partCount+=1
  end
 end
end
local practice=folder("PracticeSpawns",gameplay)
for index,position in ipairs({Vector3.new(-20,3.6,0),Vector3.new(0,3.6,20),Vector3.new(20,3.6,0),Vector3.new(0,3.6,-20)}) do
 marker(string.format("%02d",index),position,Vector3.new(3,1,3),practice)
end
for index,position in ipairs({Vector3.new(-72,0,72),Vector3.new(72,0,-72),Vector3.new(-72,0,-72),Vector3.new(72,0,72)}) do
 local zone=marker(string.format("RescueArea%02d",index),position+Vector3.new(0,4,0),Vector3.new(20,8,20),rescueAreas)
 zone:SetAttribute("OptionalLandmark",true)
end

local function pointClear(x,z)
 for _,box in ipairs(obstacleBoxes) do if x>=box.x1 and x<=box.x2 and z>=box.z1 and z<=box.z2 then return false end end
 return true
end
local function segmentClear(a,b)
 local dx,dz=b.x-a.x,b.z-a.z
 for _,box in ipairs(obstacleBoxes) do
  local low,high=0,1
  local function clip(origin,delta,minimum,maximum)
   if math.abs(delta)<0.0001 then return origin>=minimum and origin<=maximum end
   local first,last=(minimum-origin)/delta,(maximum-origin)/delta
   if first>last then first,last=last,first end
   low=math.max(low,first) high=math.min(high,last) return low<=high
  end
  if clip(a.x,dx,box.x1,box.x2) and clip(a.z,dz,box.z1,box.z2) then return false end
 end
 return true
end
local nav=folder("NavigationNodes",gameplay)
local candidates={} local lookup={}
for ix=-16,16 do for iz=-16,16 do
 local x,z=ix*24,iz*24
 if pointClear(x,z) then
  local item={x=x,z=z,ix=ix,iz=iz,neighbors={}}
  table.insert(candidates,item) lookup[ix..":"..iz]=item
 end
end end
for _,item in ipairs(candidates) do
 for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}) do
  local neighbor=lookup[(item.ix+offset[1])..":"..(item.iz+offset[2])]
  if neighbor and segmentClear(item,neighbor) then table.insert(item.neighbors,neighbor) end
 end
end
local visited={} local queue={} local largest={}
for _,item in ipairs(candidates) do
 if not visited[item] then
  queue={item} visited[item]=true local at=1
  while queue[at] do
   local current=queue[at] at+=1
   for _,neighbor in ipairs(current.neighbors) do if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end end
  end
  if #queue>#largest then largest=queue end
 end
end
local retained={}
for index,item in ipairs(largest) do
 retained[item]=true item.name=string.format("N%04d",index)
 item.object=marker(item.name,Vector3.new(item.x,3.6,item.z),Vector3.new(1,1,1),nav)
 item.object:SetAttribute("GroundNode",true) item.object:SetAttribute("LaneWidth",6.4)
end
local edges=0
for _,item in ipairs(largest) do
 local neighborNames={}
 for _,neighbor in ipairs(item.neighbors) do if retained[neighbor] then table.insert(neighborNames,neighbor.name) edges+=1 end end
 table.sort(neighborNames) item.object:SetAttribute("Neighbors",table.concat(neighborNames,","))
end
for _,pad in ipairs(starts:GetChildren()) do
 local best,distance=nil,math.huge
 local p=pad.Position-center
 for _,item in ipairs(largest) do
  local squared=(item.x-p.X)^2+(item.z-p.Z)^2
  if squared<distance and segmentClear({x=p.X,z=p.Z},item) then best=item distance=squared end
 end
 assert(best,"Starting pad lacks a connected clear ground approach")
 pad:SetAttribute("NavigationNode",best.name)
end
for _,pad in ipairs(practice:GetChildren()) do
 local p=pad.Position-center local best,distance=nil,math.huge
 for _,item in ipairs(largest) do
  local squared=(item.x-p.X)^2+(item.z-p.Z)^2
  if squared<distance and segmentClear({x=p.X,z=p.Z},item) then best=item distance=squared end
 end
 assert(best,"Practice pad lacks navigation") pad:SetAttribute("NavigationNode",best.name)
end
arena:SetAttribute("FloorY",center.Y) arena:SetAttribute("CenterX",center.X) arena:SetAttribute("CenterZ",center.Z)
arena:SetAttribute("CourtWidth",832) arena:SetAttribute("CourtLength",832) arena:SetAttribute("MapStyle","SchoolPlayground")
arena:SetAttribute("RoundDuration",300) arena:SetAttribute("MaxPlayers",4) arena:SetAttribute("BaseSpeed",16)
arena:SetAttribute("MinimumPlayers",4) arena:SetAttribute("MaxTeamSize",2) arena:SetAttribute("TeamCount",2)
arena:SetAttribute("SprintMultiplier",2.5) arena:SetAttribute("SprintSeconds",10) arena:SetAttribute("SprintRefillSeconds",15)
arena:SetAttribute("MaximumRouteHeight",12) arena:SetAttribute("MinimumPathWidth",6.4)
arena:SetAttribute("CoverStations",coverCount) arena:SetAttribute("TwoExitCubbies",cubbyCount)
arena:SetAttribute("NavigationNodes",#largest) arena:SetAttribute("NavigationEdges",edges/2)
arena:SetAttribute("DiscardedNavigationNodes",#candidates-#largest) arena:SetAttribute("LayoutVersion",1)
arena:SetAttribute("MudGeometryRepairVersion",2)
arena.Parent=workspace
return {built=true,folder=arena:GetFullName(),parts=partCount,coverStations=coverCount,twoExitCubbies=cubbyCount,playfortLoops=4,navigationNodes=#largest,navigationEdges=edges/2,discardedNavigationNodes=#candidates-#largest,linearScaleFromTag=2,areaScaleFromTag=4}

end
local function repairMudArena()
local arena=assert(workspace:FindFirstChild("Stuck in the Mud"),"Mud map missing")
if (arena:GetAttribute("MudGeometryRepairVersion") or 0)>=2 then return {repaired=false,preserved=true,version=2} end
local geometry=assert(arena:FindFirstChild("Geometry"),"Mud geometry missing")
local gameplay=assert(arena:FindFirstChild("Gameplay"),"Mud gameplay missing")
local floorY=arena:GetAttribute("FloorY")
local center=Vector3.new(arena:GetAttribute("CenterX"),floorY,arena:GetAttribute("CenterZ"))
local moved,markers=0,0
for _,model in ipairs(geometry.DistributedCover:GetChildren()) do
 if model.Name=="SouthernSchoolStorage" then
  local reference=model:FindFirstChild("StorageInk")
  if reference and math.abs(reference.Position.Z-center.Z-348)<0.1 then
   for _,object in ipairs(model:GetDescendants()) do if object:IsA("BasePart") then object.CFrame+=Vector3.new(0,0,14) end end
   moved+=1
  end
 end
end
for _,volume in ipairs(gameplay.CoverVolumes:GetChildren()) do
 if volume.Name=="SouthernSchoolStorage" and math.abs(volume.Position.Z-center.Z-348)<0.1 then volume.CFrame+=Vector3.new(0,0,14) markers+=1 end
end
local ink=Color3.fromRGB(28,43,62)
local cream=Color3.fromRGB(255,239,194)
local createdCubbies=0
local function makePart(label,size,position,color,parent,collide)
 local object=Instance.new("Part") object.Name=label object.Size=size object.Position=center+position
 object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
 object.CanCollide=collide==true object.CanTouch=false object.CanQuery=collide==true object.CastShadow=collide==true
 object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth object.Parent=parent return object
end
for _,x in ipairs({-364,364}) do for _,z in ipairs({-144,144}) do
 local label="OuterSideCubby"..(x<0 and "West" or "East")..(z<0 and "North" or "South")
 if not geometry.DistributedCover:FindFirstChild(label) then
  local model=Instance.new("Folder") model.Name=label model.Parent=geometry.DistributedCover
  model:SetAttribute("CoverCubby",true) model:SetAttribute("TwoExits",true) model:SetAttribute("ExitWidth",20)
  model:SetAttribute("ClearInteriorHeight",10) model:SetAttribute("GroundRouteConnected",true)
  local color=x<0 and Color3.fromRGB(88,174,224) or Color3.fromRGB(111,196,151)
  for _,side in ipairs({-1,1}) do
   makePart("CubbyWallInk",Vector3.new(2,10,24),Vector3.new(x+side*11,5,z),ink,model,true)
   makePart("CubbyWallColor",Vector3.new(0.2,8.4,22),Vector3.new(x+side*9.9,5,z),color,model,false)
   for rung=1,3 do makePart("CubbyWallPanel",Vector3.new(0.24,0.45,21),Vector3.new(x+side*9.7,rung*2.7,z),cream,model,false) end
  end
  makePart("CubbyRoofInk",Vector3.new(26,1.2,28),Vector3.new(x,10.6,z),ink,model,false):SetAttribute("DecorativeRoof",true)
  makePart("CubbyRoofColor",Vector3.new(24.5,0.8,26.5),Vector3.new(x,11.2,z),color,model,false):SetAttribute("DecorativeRoof",true)
  for _,side in ipairs({-1,1}) do
   local door=makePart(side<0 and "DoorA" or "DoorB",Vector3.new(20,1,10),Vector3.new(x,3.6,z+side*17),cream,model,false)
   door.Transparency=1 door:SetAttribute("ExitWidth",20)
  end
  local volume=makePart(label,Vector3.new(26,10,28),Vector3.new(x,5,z),cream,gameplay.CoverVolumes,false)
  volume.Transparency=1 volume:SetAttribute("CoverKind","TwoExitCubby") volume:SetAttribute("NearbyRescueSpace",true)
  createdCubbies+=1
 end
end end
local boxes={}
for _,part in ipairs(geometry:GetDescendants()) do
 if part:IsA("BasePart") and part.CanCollide then
  local low=Vector3.new(math.huge,math.huge,math.huge) local high=Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
   local point=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-center
   low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
   high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z))
  end end end
  if low.Y<7.8 and high.Y>0.2 then table.insert(boxes,{x1=low.X-3.2,x2=high.X+3.2,z1=low.Z-3.2,z2=high.Z+3.2}) end
 end
end
local function pointClear(x,z)
 for _,box in ipairs(boxes) do if x>=box.x1 and x<=box.x2 and z>=box.z1 and z<=box.z2 then return false end end
 return true
end
local function segmentClear(a,b)
 local dx,dz=b.x-a.x,b.z-a.z
 for _,box in ipairs(boxes) do
  local low,high=0,1
  local function clip(origin,delta,minimum,maximum)
   if math.abs(delta)<0.0001 then return origin>=minimum and origin<=maximum end
   local first,last=(minimum-origin)/delta,(maximum-origin)/delta
   if first>last then first,last=last,first end
   low=math.max(low,first) high=math.min(high,last) return low<=high
  end
  if clip(a.x,dx,box.x1,box.x2) and clip(a.z,dz,box.z1,box.z2) then return false end
 end
 return true
end
local candidates={} local lookup={}
for ix=-16,16 do for iz=-16,16 do
 local x,z=ix*24,iz*24
 if pointClear(x,z) then
  local item={x=x,z=z,ix=ix,iz=iz,neighbors={}}
  table.insert(candidates,item) lookup[ix..":"..iz]=item
 end
end end
for _,item in ipairs(candidates) do
 for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}) do
  local neighbor=lookup[(item.ix+offset[1])..":"..(item.iz+offset[2])]
  if neighbor and segmentClear(item,neighbor) then table.insert(item.neighbors,neighbor) end
 end
end
local visited={} local largest={}
for _,item in ipairs(candidates) do
 if not visited[item] then
  local queue={item} visited[item]=true local at=1
  while queue[at] do
   local current=queue[at] at+=1
   for _,neighbor in ipairs(current.neighbors) do if not visited[neighbor] then visited[neighbor]=true table.insert(queue,neighbor) end end
  end
  if #queue>#largest then largest=queue end
 end
end
local nav=assert(gameplay:FindFirstChild("NavigationNodes"),"Generated navigation missing")
for _,object in ipairs(nav:GetChildren()) do assert(object:IsA("BasePart") and object:GetAttribute("GroundNode")==true,"Navigation contains an unrecognized authored object") end
nav:ClearAllChildren()
local retained={} local edges=0
for index,item in ipairs(largest) do
 retained[item]=true item.name=string.format("N%04d",index)
 local node=Instance.new("Part") node.Name=item.name node.Size=Vector3.one
 node.Position=center+Vector3.new(item.x,3.6,item.z) node.Anchored=true node.CanCollide=false node.CanTouch=false node.CanQuery=false node.Transparency=1
 node:SetAttribute("GroundNode",true) node:SetAttribute("LaneWidth",6.4) node.Parent=nav item.object=node
end
for _,item in ipairs(largest) do
 local names={}
 for _,neighbor in ipairs(item.neighbors) do if retained[neighbor] then table.insert(names,neighbor.name) edges+=1 end end
 table.sort(names) item.object:SetAttribute("Neighbors",table.concat(names,","))
end
for _,label in ipairs({"StartPads","PracticeSpawns"}) do
 for _,pad in ipairs(gameplay[label]:GetChildren()) do
  local best,distance=nil,math.huge local point=pad.Position-center
  for _,item in ipairs(largest) do
   local squared=(item.x-point.X)^2+(item.z-point.Z)^2
   if squared<distance and segmentClear({x=point.X,z=point.Z},item) then best=item distance=squared end
  end
  assert(best,"Repaired spawn approach missing") pad:SetAttribute("NavigationNode",best.name)
 end
end
arena:SetAttribute("NavigationNodes",#largest) arena:SetAttribute("NavigationEdges",edges/2)
local cubbies=0
for _,object in ipairs(geometry.DistributedCover:GetChildren()) do if object:GetAttribute("CoverCubby")==true then cubbies+=1 end end
arena:SetAttribute("CoverStations",#gameplay.CoverVolumes:GetChildren()) arena:SetAttribute("TwoExitCubbies",cubbies)
arena:SetAttribute("DiscardedNavigationNodes",#candidates-#largest) arena:SetAttribute("MudGeometryRepairVersion",2)
return {repaired=true,version=2,movedStorageModels=moved,movedCoverMarkers=markers,createdCubbies=createdCubbies,navigationNodes=#largest,navigationEdges=edges/2,preservedGeometry=true}

end
local function buildMudGunTemplates()
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local assets=ReplicatedStorage:FindFirstChild("MudAssets")
if not assets then
 assets=Instance.new("Folder")
 assets.Name="MudAssets"
 assets.Parent=ReplicatedStorage
end
assert(assets:IsA("Folder"),"MudAssets must be a Folder")
local ink=Color3.fromRGB(24,35,62)
local cream=Color3.fromRGB(255,246,216)
local soil=Color3.fromRGB(127,79,42)
local mud=Color3.fromRGB(161,108,62)
local green=Color3.fromRGB(112,177,88)
local orange=Color3.fromRGB(255,126,48)
local yellow=Color3.fromRGB(255,212,73)
local cylinderRotation=CFrame.Angles(0,math.pi/2,0)
local tankRotation=CFrame.Angles(0,0,math.pi/2)
local function build(name,kind)
 local old=assets:FindFirstChild(name)
 if old then
  assert(old:IsA("Tool") and old:GetAttribute("ManagedMudTemplate")==true,name.." already exists and was preserved")
  return {created=false,preserved=true,parts=#old:GetDescendants()}
 end
 local tool=Instance.new("Tool")
 tool.Name=name
 tool.RequiresHandle=true
 tool.CanBeDropped=false
 tool.ToolTip=kind=="Mud" and "Mud blaster" or "Warm blaster"
 tool.Grip=CFrame.new(0,-0.15,0)
 tool:SetAttribute("GunKind",kind)
 tool:SetAttribute("TemplateVersion",1)
 tool:SetAttribute("ManagedMudTemplate",true)
 tool:SetAttribute("MeshArtReplaceable",true)
 local handle=Instance.new("Part")
 handle.Name="Handle"
 handle.Size=Vector3.new(0.55,1.5,0.68)
 handle.Material=Enum.Material.SmoothPlastic
 handle.Color=kind=="Mud" and green or orange
 handle.Anchored=false
 handle.Massless=true
 handle.CanCollide=false
 handle.CanTouch=false
 handle.CanQuery=false
 handle.CastShadow=false
 handle.Parent=tool
 local art=Instance.new("Folder")
 art.Name="Art"
 art.Parent=tool
 local muzzle=Instance.new("Attachment")
 muzzle.Name="MuzzleAttachment"
 muzzle.CFrame=CFrame.new(0,1,-2.65)
 muzzle.Parent=handle
 local count=1
 local function part(partName,size,cframe,color,shape,material)
  local object=Instance.new("Part")
  object.Name=partName
  object.Size=size
  object.CFrame=cframe
  object.Material=material or Enum.Material.SmoothPlastic
  object.Color=color
  if shape then object.Shape=shape end
  object.Anchored=false
  object.Massless=true
  object.CanCollide=false
  object.CanTouch=false
  object.CanQuery=false
  object.CastShadow=false
  object.Parent=art
  local weld=Instance.new("WeldConstraint")
  weld.Name="HandleWeld"
  weld.Part0=handle
  weld.Part1=object
  weld.Parent=object
  count+=1
  return object
 end
 local function box(partName,size,position,color)
  return part(partName,size,CFrame.new(position),color)
 end
 local function ball(partName,size,position,color)
  return part(partName,size,CFrame.new(position),color,Enum.PartType.Ball)
 end
 local function barrel(partName,length,diameter,position,color)
  return part(partName,Vector3.new(length,diameter,diameter),CFrame.new(position)*cylinderRotation,color,Enum.PartType.Cylinder)
 end
 box("Body",Vector3.new(1.35,1.2,2.1),Vector3.new(0,1,-0.55),kind=="Mud" and green or orange)
 box("Belly",Vector3.new(1.4,0.28,1.55),Vector3.new(0,0.58,-0.4),cream)
 box("BackBumper",Vector3.new(1.45,0.92,0.24),Vector3.new(0,1,0.58),ink)
 box("TopRim",Vector3.new(1.42,0.09,2.15),Vector3.new(0,1.62,-0.55),ink)
 box("BottomRim",Vector3.new(1.42,0.09,2.15),Vector3.new(0,0.4,-0.55),ink)
 for _,side in ipairs({-1,1}) do
  box("SidePanel",Vector3.new(0.08,0.75,1.25),Vector3.new(side*0.715,1,-0.35),cream)
  for _,z in ipairs({-0.85,0.15}) do ball("ToyBolt",Vector3.new(0.14,0.16,0.16),Vector3.new(side*0.77,1.23,z),ink) end
 end
 for _,y in ipairs({-0.58,-0.3,0,0.28}) do box("GripRib",Vector3.new(0.6,0.055,0.73),Vector3.new(0,y,0),ink) end
 box("GripFoot",Vector3.new(0.69,0.16,0.8),Vector3.new(0,-0.74,0),cream)
 ball("ThumbButton",Vector3.new(0.42,0.32,0.38),Vector3.new(0,0.42,-0.73),kind=="Mud" and mud or yellow)
 barrel("NozzleCollar",0.32,1.06,Vector3.new(0,1,-1.63),ink)
 barrel("WideNozzle",0.66,1.38,Vector3.new(0,1,-2.08),kind=="Mud" and mud or yellow)
 barrel("NozzleRim",0.12,1.47,Vector3.new(0,1,-2.45),ink)
 barrel("NozzleFace",0.13,1.24,Vector3.new(0,1,-2.53),kind=="Mud" and soil or orange)
 if kind=="Mud" then
  part("MuddyTank",Vector3.new(1.12,1.15,1.15),CFrame.new(0,2.05,0.1)*tankRotation,soil,Enum.PartType.Cylinder)
  part("TankCap",Vector3.new(0.16,1.25,1.25),CFrame.new(0,2.67,0.1)*tankRotation,green,Enum.PartType.Cylinder)
  ball("TankKnob",Vector3.new(0.48,0.3,0.48),Vector3.new(0,2.84,0.1),cream)
  box("TankWindow",Vector3.new(0.11,0.68,0.6),Vector3.new(0.62,2.03,0.1),mud)
  for index,position in ipairs({Vector3.new(-0.48,0.61,-2.5),Vector3.new(0.35,0.5,-2.52),Vector3.new(0.63,0.84,-2.5)}) do
   ball("MudDrip"..index,Vector3.new(0.24,0.42,0.26),position,soil)
  end
  for _,side in ipairs({-1,1}) do
   ball("MudBadge",Vector3.new(0.09,0.49,0.65),Vector3.new(side*0.77,0.97,-0.3),mud)
   ball("MudBadgeDot",Vector3.new(0.1,0.18,0.18),Vector3.new(side*0.82,1.18,-0.66),soil)
  end
 else
  part("WarmCore",Vector3.new(1.0,0.72,0.72),CFrame.new(0,2.0,0.1)*tankRotation,orange,Enum.PartType.Cylinder)
  for index=1,5 do
   part("WarmCoil"..index,Vector3.new(0.095,1.08,1.08),CFrame.new(0,1.62+index*0.18,0.1)*tankRotation,yellow,Enum.PartType.Cylinder)
  end
  part("CoilCap",Vector3.new(0.15,1.18,1.18),CFrame.new(0,2.62,0.1)*tankRotation,ink,Enum.PartType.Cylinder)
  ball("WarmKnob",Vector3.new(0.48,0.32,0.48),Vector3.new(0,2.81,0.1),yellow)
  for _,side in ipairs({-1,1}) do
   ball("SunBadge",Vector3.new(0.1,0.48,0.48),Vector3.new(side*0.78,0.97,-0.3),yellow)
   for _,y in ipairs({0.65,1.29}) do box("SunRay",Vector3.new(0.09,0.16,0.13),Vector3.new(side*0.79,y,-0.3),orange) end
  end
 end
 tool.Parent=assets
 return {created=true,parts=count,muzzle=muzzle:GetFullName()}
end
return {MudGun=build("MudGun","Mud"),HeatGun=build("HeatGun","Heat"),folder=assets:GetFullName(),scripts=0,forward="Handle local -Z",muzzleOffset=Vector3.new(0,1,-2.65)}

end
local function buildMudHUD()
local StarterGui=game:GetService("StarterGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local soil=Color3.fromRGB(161,108,62)
local orange=Color3.fromRGB(255,150,58)
local blue=Color3.fromRGB(42,160,255)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name for key,value in pairs(props or {}) do o[key]=value end o.Parent=parent return o
end
local function finish(o,color,radius,thickness)
 o.BackgroundColor3=color o.BorderSizePixel=0
 make("UICorner","Corner",o,{CornerRadius=UDim.new(0,radius or 12)})
 make("UIStroke","Outline",o,{Color=ink,Thickness=thickness or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function text(parent,name,value,position,size,font,maximum)
 local o=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font or body,TextColor3=ink,BackgroundTransparency=1,TextScaled=true,TextWrapped=true,ZIndex=5})
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=9,MaxTextSize=maximum or 20}) return o
end
local function button(parent,name,value,position,size,color,maximum)
 local o=make("TextButton",name,parent,{Position=position,Size=size,Text=value,FontFace=headline,TextColor3=ink,TextScaled=true,TextWrapped=true,AutoButtonColor=true,ZIndex=5})
 finish(o,color)
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=10,MaxTextSize=maximum or 20}) return o
end
local function meter(parent,name,position,size,color)
 local track=make("Frame",name,parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(203,212,209),BorderSizePixel=0,ZIndex=5})
 make("UICorner","Corner",track,{CornerRadius=UDim.new(1,0)})
 local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=color,BorderSizePixel=0,ZIndex=6})
 make("UICorner","Corner",fill,{CornerRadius=UDim.new(1,0)})
 make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0)})
 return track
end
local assets=ReplicatedStorage:FindFirstChild("MudAssets")
if not assets then assets=make("Folder","MudAssets",ReplicatedStorage) end
if not assets:FindFirstChild("MuddyTemplate") then
 local marker=make("BillboardGui","MuddyTemplate",assets,{Size=UDim2.fromOffset(170,42),StudsOffset=Vector3.new(0,3.8,0),AlwaysOnTop=false,MaxDistance=160,Enabled=false})
 local card=make("Frame","Card",marker,{Size=UDim2.fromScale(1,1)})
 finish(card,paper,12,3)
 local title=text(card,"Title","STUCK!",UDim2.fromOffset(7,4),UDim2.new(1,-14,1,-8),headline,30)
 title.TextColor3=soil
end
if StarterGui:FindFirstChild("MudHUD") then return {preserved=true,muddyTemplate=true} end
local gui=make("ScreenGui","MudHUD",StarterGui,{Enabled=true,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=17,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
gui:SetAttribute("LayoutVersion",1)
local main=make("Frame","Main",gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,Visible=true})
local top=make("Frame","Top",main,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,68),Size=UDim2.new(0.44,0,0,74),ZIndex=4})
finish(top,paper,14,4)
make("UISizeConstraint","SizeLimit",top,{MinSize=Vector2.new(290,74),MaxSize=Vector2.new(600,74)})
text(top,"Title","STUCK IN THE MUD",UDim2.fromScale(0.04,0.03),UDim2.fromScale(0.92,0.25),headline,24)
button(top,"Team","BLUE\n2 / 2 FREE",UDim2.fromScale(0.025,0.37),UDim2.fromScale(0.30,0.48),blue,15).TextColor3=Color3.new(1,1,1)
text(top,"Timer","5:00",UDim2.fromScale(0.35,0.28),UDim2.fromScale(0.30,0.53),headline,39)
text(top,"Other","TEAMS LEFT: 2",UDim2.fromScale(0.68,0.39),UDim2.fromScale(0.29,0.42),body,15)
local controls=make("Frame","Controls",main,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,146),BackgroundTransparency=1,BorderSizePixel=0})
local charge=make("Frame","Meter",controls,{Size=UDim2.new(1,0,0,36),ZIndex=4})
finish(charge,paper,12)
text(charge,"Charge","SPRINT 10.0s / 10s",UDim2.fromOffset(10,3),UDim2.new(1,-20,0,19),body,17)
meter(charge,"Track",UDim2.fromOffset(10,26),UDim2.new(1,-20,0,6),blue)
button(controls,"Mud","MUD\n[1]",UDim2.fromOffset(0,44),UDim2.fromOffset(93,48),soil,19)
button(controls,"Heat","HEAT\n[2]",UDim2.fromOffset(100,44),UDim2.fromOffset(93,48),orange,19)
button(controls,"Fire","SPLAT!",UDim2.fromOffset(200,44),UDim2.fromOffset(80,48),Color3.fromRGB(255,205,77),18)
button(controls,"Sprint","SPRINT · HOLD SHIFT",UDim2.fromOffset(0,98),UDim2.fromOffset(280,48),blue,20)
local frozen=make("Frame","Frozen",main,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,96),Visible=false,ZIndex=4})
finish(frozen,paper,15,4)
text(frozen,"Title","STUCK IN THE MUD!",UDim2.fromOffset(8,6),UDim2.new(1,-16,0,28),headline,25)
text(frozen,"Status","TEAMMATE HEAT: 0.0 / 5s",UDim2.fromOffset(10,39),UDim2.new(1,-20,0,22),body,17)
meter(frozen,"RescueTrack",UDim2.fromOffset(12,73),UDim2.new(1,-24,0,10),orange)
local countdown=text(main,"Countdown","3",UDim2.new(0.5,-110,0.5,-60),UDim2.fromOffset(220,120),headline,98)
countdown.Visible=false countdown.TextColor3=paper
make("UIStroke","Outline",countdown,{Thickness=5,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
local aim=make("Frame","Crosshair",main,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,BorderSizePixel=0})
make("Frame","Horizontal",aim,{Position=UDim2.fromOffset(0,6),Size=UDim2.fromOffset(14,2),BackgroundColor3=paper,BorderSizePixel=0})
make("Frame","Vertical",aim,{Position=UDim2.fromOffset(6,0),Size=UDim2.fromOffset(2,14),BackgroundColor3=paper,BorderSizePixel=0})
local results=make("Frame","Results",main,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.52),Size=UDim2.new(0.65,0,0,190),Visible=false,ZIndex=10})
finish(results,paper,18,4)
make("UISizeConstraint","SizeLimit",results,{MinSize=Vector2.new(280,190),MaxSize=Vector2.new(630,190)})
text(results,"Title","YOUR TEAM WINS!",UDim2.fromScale(0.04,0.07),UDim2.fromScale(0.92,0.27),headline,35)
text(results,"Reason","EVERY OPPONENT IS STUCK",UDim2.fromScale(0.05,0.38),UDim2.fromScale(0.90,0.16),body,18)
text(results,"Rewards","+150 COINS · +50 XP",UDim2.fromScale(0.05,0.63),UDim2.fromScale(0.90,0.24),headline,26)
button(gui,"ColourToggle","TEAM",UDim2.new(0,300,1,-62),UDim2.fromOffset(44,44),paper,13)
local palette=make("Frame","ColourPicker",gui,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.52),Size=UDim2.fromOffset(280,138),Visible=false,Active=true,ZIndex=20})
finish(palette,paper,15,4)
text(palette,"Title","TEAM COLOUR",UDim2.fromOffset(10,9),UDim2.fromOffset(209,24),headline,25).ZIndex=21
button(palette,"Close","X",UDim2.fromOffset(231,6),UDim2.fromOffset(40,40),Color3.new(1,1,1),22).ZIndex=22
local paletteColors={{"Red",Color3.fromRGB(255,81,92)},{"Blue",blue},{"Green",Color3.fromRGB(90,185,111)},{"Black",Color3.fromRGB(43,48,57)}}
for index,item in ipairs(paletteColors) do
 local b=button(palette,item[1],item[1]:upper(),UDim2.fromOffset(10+(index-1)*66,49),UDim2.fromOffset(60,48),item[2],14)
 b.TextColor3=Color3.new(1,1,1) b.ZIndex=22
end
text(palette,"Message","Pick a colour for your next team.",UDim2.fromOffset(10,108),UDim2.fromOffset(260,21),body,13).ZIndex=21
return {gui=gui:GetFullName(),editable=true}

end
local function buildTagSprintUI()
local gui=assert(game.StarterGui:FindFirstChild("TagHUD"),"Tag HUD missing")
local function authorNotices()
 for _,name in ipairs({"Protection","MoveMessage"}) do
  local notice=gui[name]
  notice.AnchorPoint=Vector2.new(0.5,1)
  notice.Position=UDim2.new(0.5,0,1,-126)
  notice.Size=UDim2.fromOffset(name=="Protection" and 240 or 280,16)
 end
 gui:SetAttribute("SprintLayoutVersion",2)
end
if gui:FindFirstChild("SprintPanel") then
 if (gui:GetAttribute("SprintLayoutVersion") or 0)<2 then authorNotices() return {preserved=true,noticesUpdated=true} end
 return {preserved=true}
end
local ink=Color3.fromRGB(24,35,62)
local blue=Color3.fromRGB(42,160,255)
local paper=Color3.fromRGB(255,250,226)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name for key,value in pairs(props or {}) do o[key]=value end o.Parent=parent return o
end
local function finish(o,color)
 o.BackgroundColor3=color o.BorderSizePixel=0
 make("UICorner","Corner",o,{CornerRadius=UDim.new(0,12)})
 make("UIStroke","Outline",o,{Color=ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function text(parent,name,value,position,size,font,maximum)
 local o=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font,TextColor3=ink,BackgroundTransparency=1,TextScaled=true,ZIndex=6})
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=9,MaxTextSize=maximum}) return o
end
local frame=make("Frame","SprintPanel",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,100),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4,Visible=true})
local meter=make("Frame","Meter",frame,{Size=UDim2.new(1,0,0,44),ZIndex=5})
finish(meter,paper)
text(meter,"Role","RUNNER",UDim2.fromOffset(10,4),UDim2.new(0.55,0,0,17),headline,19).TextXAlignment=Enum.TextXAlignment.Left
text(meter,"Time","IT: 0.0s",UDim2.fromOffset(10,20),UDim2.new(0.55,0,0,12),body,11).TextXAlignment=Enum.TextXAlignment.Left
text(meter,"Charge","10.0s",UDim2.new(1,-94,0,6),UDim2.fromOffset(83,22),body,16).TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame","Track",meter,{Position=UDim2.fromOffset(10,34),Size=UDim2.new(1,-20,0,6),BackgroundColor3=Color3.fromRGB(195,211,211),BorderSizePixel=0,ZIndex=6})
make("UICorner","Corner",track,{CornerRadius=UDim.new(1,0)})
local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=7})
make("UICorner","Corner",fill,{CornerRadius=UDim.new(1,0)})
make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0)})
local sprint=make("TextButton","Sprint",frame,{Position=UDim2.fromOffset(0,52),Size=UDim2.new(0.52,0,0,48),Text="SPRINT\nHOLD SHIFT",FontFace=headline,TextColor3=ink,TextScaled=true,ZIndex=5})
finish(sprint,blue)
make("UITextSizeConstraint","TextLimit",sprint,{MinTextSize=10,MaxTextSize=21})
local controls=gui.Controls
controls.AnchorPoint=Vector2.new(0.5,1)
controls.Position=UDim2.new(0.5,0,1,-18)
controls.Size=UDim2.fromOffset(280,48)
controls.ZIndex=5
for index,name in ipairs({"Vault","Dodge"}) do
 local button=controls[name]
 button.Position=UDim2.new(index==1 and 0.56 or 0.79,0,0,0)
 button.Size=UDim2.new(0.21,0,0,48)
 button.TextWrapped=true
 button.ZIndex=6
end
gui.Role.Visible=false
authorNotices()
return {created=true}

end
local function upgradeThirdGameLobby()
local lobby=workspace["Playground Lobby"]
local gui=game.StarterGui.PlaygroundShell
local vote=gui.VotePanel
local colors={BritishBulldog=Color3.fromRGB(42,160,255),TagYoureIt=Color3.fromRGB(255,130,181),StuckInTheMud=Color3.fromRGB(111,196,151)}
local function textLimit(label,minimum,maximum)
 local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit=Instance.new("UITextSizeConstraint") limit.Name="TextSizeLimit" limit.Parent=label end
 limit.MinTextSize=minimum limit.MaxTextSize=maximum
 return limit
end
if not vote:FindFirstChild("StuckInTheMud") then
 local clone=vote.TagYoureIt:Clone()
 clone.Name="StuckInTheMud"
 clone.Text="STUCK IN\nTHE MUD"
 clone.BackgroundColor3=colors.StuckInTheMud
 clone.Parent=vote
 local label=vote.VotesTagYoureIt:Clone()
 label.Name="VotesStuckInTheMud"
 label.Text="0 votes"
 label.Parent=vote
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  vote[id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.28,0)
  vote[id].Size=UDim2.fromScale(0.30,0.45)
  vote[id].TextWrapped=true
  vote["Votes"..id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.77,0)
  vote["Votes"..id].Size=UDim2.fromScale(0.30,0.13)
 end
end
if not gui:FindFirstChild("CompactVotePanel") then
 local compactVote=vote:Clone()
 compactVote.Name="CompactVotePanel"
 compactVote.Position=UDim2.new(0.5,0,1,-74)
 compactVote.Size=UDim2.new(0.62,0,0,176)
 compactVote.SizeLimit.MinSize=Vector2.new(280,176)
 compactVote.SizeLimit.MaxSize=Vector2.new(660,176)
 compactVote.Visible=false
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  compactVote[id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.28,0)
  compactVote[id].Size=UDim2.fromScale(0.28,0.42)
  compactVote["Votes"..id].Position=UDim2.new(0.035+(index-1)*0.315,0,0.73,0)
  compactVote["Votes"..id].Size=UDim2.fromScale(0.28,0.11)
 end
 compactVote.Message.Position=UDim2.new(0,10,0,150)
 compactVote.Message.Size=UDim2.new(1,-20,0,20)
 textLimit(compactVote.Message,9,11)
 compactVote.Parent=gui
 gui:SetAttribute("CompactVoteLayoutVersion",1)
end
local admin=game.StarterGui.PlaygroundAdminPanel.Panel.Body
local content=admin.Content
if not content:FindFirstChild("StuckInTheMud") then
 local clone=content.TagYoureIt:Clone()
 clone.Name="StuckInTheMud"
 clone.Position=UDim2.fromOffset(0,436)
 clone.Title.Text="STUCK IN THE MUD"
 clone.TagStart.Name="MudStart"
 clone.TagRunner.Name="MudShooter"
 clone.TagTagger.Name="MudMedic"
 clone.MudShooter.Text="SOLO MUD GUN"
 clone.MudMedic.Text="SOLO RESCUE"
 clone.Parent=content
 content.Size=UDim2.new(content.Size.X.Scale,content.Size.X.Offset,0,644)
 admin.CanvasSize=UDim2.fromOffset(0,652)
end
local adminGui=game.StarterGui.PlaygroundAdminPanel
if not adminGui:FindFirstChild("CompactPanel") then
 local originalPanel=adminGui.Panel
 local compact=Instance.new("Frame")
 compact.Name="CompactPanel"
 compact.Position=UDim2.new(0.012,0,0,64)
 compact.Size=UDim2.new(0.29,0,1,-82)
 compact.BackgroundColor3=originalPanel.BackgroundColor3
 compact.BorderSizePixel=0
 compact.Active=true
 compact.Visible=false
 compact.Parent=adminGui
 for _,name in ipairs({"Corner","Stroke"}) do
  local source=originalPanel:FindFirstChild(name)
  if source then source:Clone().Parent=compact end
 end
 local limit=Instance.new("UISizeConstraint")
 limit.Name="SizeLimit"
 limit.MinSize=Vector2.new(300,0)
 limit.MaxSize=Vector2.new(390,650)
 limit.Parent=compact
 local title=originalPanel.Title:Clone()
 title.Position=UDim2.fromOffset(12,10)
 title.Size=UDim2.new(1,-76,0,38)
 title.Parent=compact
 textLimit(title,10,23)
 local close=originalPanel.Close:Clone()
 close.Position=UDim2.new(1,-54,0,8)
 close.Size=UDim2.fromOffset(44,44)
 close.Parent=compact
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name="Body"
 scroll.Position=UDim2.fromOffset(10,58)
 scroll.Size=UDim2.new(1,-20,1,-68)
 scroll.BackgroundTransparency=1
 scroll.BorderSizePixel=0
 scroll.Active=true
 scroll.CanvasSize=UDim2.fromOffset(0,936)
 scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
 scroll.ScrollingDirection=Enum.ScrollingDirection.Y
 scroll.ScrollBarThickness=4
 scroll.ScrollBarImageColor3=Color3.fromRGB(24,35,62)
 scroll.ClipsDescendants=true
 scroll.Parent=compact
 local compactContent=Instance.new("Frame")
 compactContent.Name="Content"
 compactContent.Position=UDim2.fromOffset(4,4)
 compactContent.Size=UDim2.new(1,-12,0,924)
 compactContent.BackgroundTransparency=1
 compactContent.Parent=scroll
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  local card=content[id]:Clone()
  card.Position=UDim2.fromOffset(0,(index-1)*252)
  card.Size=UDim2.new(1,0,0,238)
  card.Title.Position=UDim2.fromOffset(10,6)
  card.Title.Size=UDim2.new(1,-20,0,32)
  textLimit(card.Title,10,24)
  card.Status.Position=UDim2.fromOffset(10,42)
  card.Status.Size=UDim2.new(1,-20,0,24)
  local buttons={}
  for _,object in ipairs(card:GetChildren()) do if object:IsA("TextButton") then table.insert(buttons,object) end end
  table.sort(buttons,function(a,b)
   if a.Position.Y.Scale~=b.Position.Y.Scale then return a.Position.Y.Scale<b.Position.Y.Scale end
   return a.Position.Y.Offset<b.Position.Y.Offset
  end)
  for buttonIndex,button in ipairs(buttons) do
   button.Position=UDim2.fromOffset(10,75+(buttonIndex-1)*55)
   button.Size=UDim2.new(1,-20,0,48)
  end
  card.Parent=compactContent
 end
 for index,name in ipairs({"StopRound","ToggleAutomatic"}) do
  local button=originalPanel[name]:Clone()
  button.Position=UDim2.fromOffset(10,756+(index-1)*60)
  button.Size=UDim2.new(1,-20,0,48)
  button.Parent=compactContent
 end
 local message=originalPanel.Message:Clone()
 message.Position=UDim2.fromOffset(10,876)
 message.Size=UDim2.new(1,-20,0,42)
 message.Parent=compactContent
 local toggle=adminGui.Toggle:Clone()
 toggle.Name="CompactToggle"
 toggle.Position=UDim2.new(0.012,0,0,8)
 toggle.Size=UDim2.fromOffset(112,44)
 toggle.Visible=false
 toggle.Parent=adminGui
 adminGui:SetAttribute("CompactLayoutVersion",1)
end
local voting=lobby.VotingAlcove
local gameplay=lobby.Gameplay
if not gameplay.VoteChoices:FindFirstChild("StuckInTheMud") then
 local backup=game.ServerStorage.PlaygroundBeforeMud20261003
 if not backup:FindFirstChild("LobbyVotingBeforeMud") then
  local copy=voting:Clone() copy.Name="LobbyVotingBeforeMud" copy.Parent=backup
  copy=gameplay.VoteChoices:Clone() copy.Name="VoteChoicesBeforeMud" copy.Parent=backup
 end
 for index,id in ipairs({"BritishBulldog","TagYoureIt"}) do
  local stand=voting:FindFirstChild(id.."Stand")
  if stand then
   stand:ScaleTo(stand:GetScale()*0.76)
   local pad=stand:FindFirstChild("ChoicePad")
   local translation=Vector3.new(index==1 and 62 or 88,4.82-pad.Size.Y/2,-84)-pad.Position
   stand:PivotTo(stand:GetPivot()+translation)
  end
 end
 local original=voting:FindFirstChild("BritishBulldogStand")
 if original then
  local stand=original:Clone()
  stand.Name="StuckInTheMudStand"
  stand:PivotTo(stand:GetPivot()+Vector3.new(52,0,0))
  stand.ChoicePad.Color=colors.StuckInTheMud
  stand.ChoiceCardFace.Color=colors.StuckInTheMud
  local face=stand.ChoiceCardFace:FindFirstChild("GameName")
  if face then face.Label.Text="Stuck in the Mud" end
  stand.Parent=voting
 end
 for index,id in ipairs({"BritishBulldog","TagYoureIt","StuckInTheMud"}) do
  local pad=gameplay.VoteChoices:FindFirstChild(id)
  if not pad then pad=gameplay.VoteChoices.BritishBulldog:Clone() pad.Name=id pad.Parent=gameplay.VoteChoices end
  pad.Position=Vector3.new(62+(index-1)*26,8.6,-84)
  pad.Size=Vector3.new(20,8,23)
  pad:SetAttribute("GameId",id)
  pad:SetAttribute("Available",true)
  if id=="StuckInTheMud" then pad:SetAttribute("DisplayName","Stuck in the Mud") end
 end
end
gameplay.VoteZone:SetAttribute("AvailableGames","BritishBulldog,TagYoureIt,StuckInTheMud")
gui:SetAttribute("ThirdGameVersion",2)
return {thirdGameVote=true,adminCard=true,compactAdmin=true,compactVoting=true}

end
local function buildSchoolScenery()
local ink=Color3.fromRGB(27,45,61)
local cream=Color3.fromRGB(255,243,200)
local brick=Color3.fromRGB(239,169,111)
local blue=Color3.fromRGB(76,182,238)
local coral=Color3.fromRGB(255,127,121)
local gold=Color3.fromRGB(255,203,68)
local mint=Color3.fromRGB(92,209,166)
local green=Color3.fromRGB(129,201,76)
local white=Color3.fromRGB(255,253,240)
local font=Font.new("rbxasset://fonts/families/FredokaOne.json")

local function build(arena)
 if not arena then return {built=false,reason="Arena is absent"} end
 local existing=arena:FindFirstChild("SchoolScenery")
 if existing then return {built=false,preserved=true,folder=existing:GetFullName()} end
 local gameplay=assert(arena:FindFirstChild("Gameplay"),"Arena gameplay is missing")
 local bounds=assert(gameplay:FindFirstChild("ArenaBounds"),"Arena bounds are missing")
 assert(bounds:IsA("BasePart") and bounds.CFrame.UpVector:Dot(Vector3.yAxis)>0.999,"School scenery needs horizontal arena bounds")
 local floorY=arena:GetAttribute("FloorY")
 if typeof(floorY)~="number" then
  local floor=arena:FindFirstChild("CourtFloor",true)
  floorY=floor and floor.Position.Y+floor.Size.Y/2 or bounds.Position.Y-bounds.Size.Y/2
 end
 assert(floorY==floorY and math.abs(floorY)<100000,"Arena floor is invalid")
 local base=CFrame.new(bounds.Position.X,floorY,bounds.Position.Z)*bounds.CFrame.Rotation
 local halfWidth,halfLength=bounds.Size.X/2,bounds.Size.Z/2
 local scenery=Instance.new("Folder")
 scenery.Name="SchoolScenery"
 scenery:SetAttribute("SchoolStyleVersion",1)
 scenery:SetAttribute("DecorationOnly",true)
 scenery:SetAttribute("MinimumArenaClearance",24)
 scenery:SetAttribute("SourceArenaBounds",bounds.CFrame)
 scenery:SetAttribute("SourceArenaSize",bounds.Size)
 local count=0
 local function folder(name)
  local object=Instance.new("Folder") object.Name=name object.Parent=scenery return object
 end
 local function part(name,size,position,color,parent,rotation,shape)
  local object=Instance.new("Part")
  object.Name=name object.Size=size object.CFrame=base*CFrame.new(position)*(rotation or CFrame.identity)
  object.Color=color object.Material=Enum.Material.SmoothPlastic object.Anchored=true
  object.CanCollide=false object.CanTouch=false object.CanQuery=false object.CastShadow=true
  object.TopSurface=Enum.SurfaceType.Smooth object.BottomSurface=Enum.SurfaceType.Smooth
  if shape then object.Shape=shape end
  object.Parent=parent count+=1 return object
 end
 local function label(object,value,face)
  local gui=Instance.new("SurfaceGui")
  gui.Name="ClassDetail" gui.Face=face gui.LightInfluence=0.3 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
  gui.PixelsPerStud=32 gui.AlwaysOnTop=false gui.Parent=object
  local text=Instance.new("TextLabel")
  text.Name="Label" text.Size=UDim2.fromScale(1,1) text.BackgroundTransparency=1 text.Text=value
  text.TextColor3=ink text.FontFace=font text.TextScaled=true text.TextWrapped=true text.Parent=gui
 end
 local school=folder("ClassroomFacade")
 local schoolZ=-halfLength-74
 local schoolWidth=math.clamp(bounds.Size.X*0.8,180,256)
 part("SchoolIslandSoil",Vector3.new(schoolWidth+26,36,58),Vector3.new(0,-22,schoolZ),Color3.fromRGB(159,102,65),school)
 part("SchoolIslandInk",Vector3.new(schoolWidth+28,8,60),Vector3.new(0,-4,schoolZ),ink,school)
 part("SchoolIslandGrass",Vector3.new(schoolWidth+24,0.8,56),Vector3.new(0,0.1,schoolZ),green,school)
 part("FacadeInk",Vector3.new(schoolWidth+4,56,30),Vector3.new(0,28,schoolZ),ink,school)
 part("WarmSchoolWall",Vector3.new(schoolWidth,53,0.7),Vector3.new(0,27.5,schoolZ+15.4),brick,school)
 part("FoundationCream",Vector3.new(schoolWidth+2,3,31),Vector3.new(0,1.5,schoolZ),cream,school)
 part("RoofInk",Vector3.new(schoolWidth+12,4,38),Vector3.new(0,57,schoolZ),ink,school)
 part("RoofCream",Vector3.new(schoolWidth+9,2.2,35),Vector3.new(0,58.7,schoolZ),cream,school)
 for _,side in ipairs({-1,1}) do
  part("FacadeColumn",Vector3.new(5,54,1.4),Vector3.new(side*(schoolWidth/2-4),28,schoolZ+15.9),cream,school)
  part("ColumnCap",Vector3.new(8,2,3),Vector3.new(side*(schoolWidth/2-4),55,schoolZ+16),gold,school)
 end
 for _,height in ipairs({16,38}) do for column=-3,3 do
  if height~=16 or column~=0 then
   local x=column*(schoolWidth-28)/7
   part("WindowInk",Vector3.new(21,13,1.2),Vector3.new(x,height,schoolZ+16),ink,school)
   part("WindowGlass",Vector3.new(18.4,10.4,1.25),Vector3.new(x,height,schoolZ+16.75),blue,school)
   part("WindowCrossVertical",Vector3.new(0.7,10.6,0.3),Vector3.new(x,height,schoolZ+17.55),cream,school)
   part("WindowCrossHorizontal",Vector3.new(18.6,0.7,0.3),Vector3.new(x,height,schoolZ+17.55),cream,school)
   part("WindowSill",Vector3.new(23,1.3,2.4),Vector3.new(x,height-7.2,schoolZ+16.8),cream,school)
  end
 end end
 part("DoorInk",Vector3.new(22,25,1.4),Vector3.new(0,12.5,schoolZ+16),ink,school)
 part("DoorColor",Vector3.new(19.6,22.6,1.45),Vector3.new(0,12.5,schoolZ+16.8),mint,school)
 part("DoorWindow",Vector3.new(13,10,0.3),Vector3.new(0,17,schoolZ+17.8),blue,school)
 part("DoorDivider",Vector3.new(0.7,23,0.35),Vector3.new(0,12.5,schoolZ+17.8),cream,school)
 for _,side in ipairs({-1,1}) do
  part("DoorHandle",Vector3.new(0.8,3,0.5),Vector3.new(side*1.8,9,schoolZ+18),gold,school)
 end
 local plaque=part("RoomPlaque",Vector3.new(11,2.6,0.5),Vector3.new(0,28.8,schoolZ+16.6),cream,school)
 label(plaque,"ROOM 4",Enum.NormalId.Back)
 part("SchoolClockInk",Vector3.new(0.7,10,10),Vector3.new(0,50,schoolZ+16.1),ink,school,CFrame.Angles(0,math.pi/2,0),Enum.PartType.Cylinder)
 part("SchoolClockFace",Vector3.new(0.8,8.5,8.5),Vector3.new(0,50,schoolZ+16.8),cream,school,CFrame.Angles(0,math.pi/2,0),Enum.PartType.Cylinder)
 part("ClockMinuteHand",Vector3.new(0.5,3.7,0.25),Vector3.new(0,51.2,schoolZ+17.4),ink,school)
 part("ClockHourHand",Vector3.new(2.8,0.5,0.25),Vector3.new(1.2,50,schoolZ+17.4),ink,school)
 for index=0,3 do
  local angle=index*math.pi/2
  part("ClockTick",Vector3.new(0.6,0.6,0.2),Vector3.new(math.sin(angle)*3.3,50+math.cos(angle)*3.3,schoolZ+17.4),ink,school)
 end

 local recreation=folder("PaintedSchoolGames")
 local courtX=halfWidth+72
 part("SchoolCourtSoil",Vector3.new(69,26,129),Vector3.new(courtX,-13.5,0),Color3.fromRGB(159,102,65),recreation)
 part("HopscotchCourtInk",Vector3.new(72,0.8,132),Vector3.new(courtX,-0.4,0),ink,recreation)
 part("HopscotchCourtColor",Vector3.new(69,0.18,129),Vector3.new(courtX,0.05,0),Color3.fromRGB(225,199,150),recreation)
 local squares={{0,-27},{-3,-20},{3,-20},{0,-13},{-3,-6},{3,-6},{0,1},{0,8}}
 for index,offset in ipairs(squares) do
  local position=Vector3.new(courtX+offset[1],0.2,offset[2])
  part("HopscotchOutline",Vector3.new(5.4,0.12,5.4),position,ink,recreation)
  local square=part("HopscotchSquare",Vector3.new(4.6,0.13,4.6),position+Vector3.new(0,0.08,0),index%3==0 and mint or index%3==1 and gold or coral,recreation)
  label(square,tostring(index),Enum.NormalId.Top)
 end
 local beanZ=halfLength+62
 part("BeanbagCourtSoil",Vector3.new(93,26,41),Vector3.new(0,-13.5,beanZ),Color3.fromRGB(159,102,65),recreation)
 part("BeanbagCourtInk",Vector3.new(96,0.8,44),Vector3.new(0,-0.4,beanZ),ink,recreation)
 part("BeanbagCourtGreen",Vector3.new(93,0.18,41),Vector3.new(0,0.05,beanZ),green,recreation)
 for index,color in ipairs({blue,coral,mint}) do
  local x=(index-2)*25
  part("BeanbagTargetInk",Vector3.new(13,0.15,13),Vector3.new(x,0.2,beanZ-3),ink,recreation)
  part("BeanbagTarget",Vector3.new(10.5,0.16,10.5),Vector3.new(x,0.3,beanZ-3),color,recreation)
  part("TargetCenter",Vector3.new(3,0.17,3),Vector3.new(x,0.4,beanZ-3),cream,recreation)
  part("SoftBeanbag",Vector3.new(4.2,2,4.2),Vector3.new(x+7,1.2,beanZ+11),color,recreation,CFrame.Angles(0,index*0.4,0),Enum.PartType.Ball)
 end
 for _,side in ipairs({-1,1}) do
  part("BeanbagCourtStripe",Vector3.new(88,0.12,0.6),Vector3.new(0,0.2,beanZ+side*18),white,recreation)
 end
 local benches=folder("Benches")
 for _,side in ipairs({-1,1}) do
  local x,z=courtX,side*54
  part("BenchSeatInk",Vector3.new(22,2,7),Vector3.new(x,4,z),ink,benches)
  for plank=-1,1 do part("BenchSeatPlank",Vector3.new(20.5,1,1.7),Vector3.new(x,4.7,z+plank*2),gold,benches) end
  part("BenchBackInk",Vector3.new(22,5.5,1.8),Vector3.new(x,7.4,z+side*3.7),ink,benches)
  part("BenchBackColor",Vector3.new(20.5,4,1.9),Vector3.new(x,7.4,z+side*3.8),cream,benches)
  for _,leg in ipairs({-1,1}) do part("BenchLeg",Vector3.new(2,4,5),Vector3.new(x+leg*8,2,z),ink,benches) end
 end
 local details=folder("ClassNoticeboard")
 local boardX=-halfWidth-66
 local facing=CFrame.Angles(0,math.pi/2,0)
 part("NoticeboardSoil",Vector3.new(34,26,28),Vector3.new(boardX,-13.5,0),Color3.fromRGB(159,102,65),details)
 part("NoticeboardPaving",Vector3.new(38,0.8,32),Vector3.new(boardX,-0.4,0),cream,details)
 part("NoticeboardInk",Vector3.new(18,12,1.6),Vector3.new(boardX,14,0),ink,details,facing)
 part("NoticeboardCork",Vector3.new(15.8,9.8,1.7),Vector3.new(boardX+0.9,14,0),brick,details,facing)
 for _,side in ipairs({-1,1}) do
  part("NoticeboardPost",Vector3.new(1.8,14,1.8),Vector3.new(boardX,7,side*6.5),ink,details)
  local paper=part("PinnedClassPaper",Vector3.new(5.2,6,0.2),Vector3.new(boardX+1.9,14,side*4),cream,details,facing)
  label(paper,side<0 and "CLASS\n4B" or "SPORTS\nDAY",Enum.NormalId.Back)
  part("NoticePin",Vector3.new(0.4,0.9,0.9),Vector3.new(boardX+2.2,16.2,side*4),coral,details,nil,Enum.PartType.Ball)
 end
 local plants=folder("SchoolPlanters")
 for _,side in ipairs({-1,1}) do
  for _,z in ipairs({-halfLength*0.48,halfLength*0.48}) do
   local x=side*(halfWidth+44)
   part("PlanterPedestal",Vector3.new(14,28,14),Vector3.new(x,-14,z),Color3.fromRGB(159,102,65),plants)
   part("PlanterInk",Vector3.new(13,4.5,13),Vector3.new(x,2.25,z),ink,plants)
   part("PlanterCream",Vector3.new(11.5,3.6,11.5),Vector3.new(x,2.5,z),cream,plants)
   part("PlantSoil",Vector3.new(10.8,0.3,10.8),Vector3.new(x,4.5,z),Color3.fromRGB(113,77,52),plants)
   for tuft=-1,1 do
    part("RoundShrub",Vector3.new(6.4,6.7,6.4),Vector3.new(x+tuft*2.8,7,z),tuft==0 and mint or green,plants,nil,Enum.PartType.Ball)
   end
  end
 end
 local checks=0
 for _,object in ipairs(scenery:GetDescendants()) do
  assert(not object:IsA("BaseScript") and not object:IsA("ModuleScript"),"School scenery must be scriptless")
  if object:IsA("BasePart") then
   assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,"School scenery must not affect gameplay")
   local minX,minZ,maxX,maxZ=math.huge,math.huge,-math.huge,-math.huge
   for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
    local point=base:PointToObjectSpace(object.CFrame:PointToWorldSpace(Vector3.new(x*object.Size.X/2,y*object.Size.Y/2,z*object.Size.Z/2)))
    minX=math.min(minX,point.X) maxX=math.max(maxX,point.X)
    minZ=math.min(minZ,point.Z) maxZ=math.max(maxZ,point.Z)
   end end end
   assert(minX>=halfWidth+24 or maxX<=-halfWidth-24 or minZ>=halfLength+24 or maxZ<=-halfLength-24,"School scenery intrudes into the arena: "..object.Name)
   checks+=1
  end
 end
 scenery:SetAttribute("PartCount",count)
 scenery:SetAttribute("ClearanceChecks",checks)
 scenery.Parent=arena
 return {built=true,folder=scenery:GetFullName(),parts=count,clearanceChecks=checks}
end

return {
 BritishBulldog=build(workspace:FindFirstChild("British Bulldog game") or workspace:FindFirstChild("British Bulldog Game")),
 TagYoureIt=build(workspace:FindFirstChild("Tag You're It")),
}

end
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local britishBulldog=assert(workspace:FindFirstChild("British Bulldog game"),"Install British Bulldog before this upgrade")
local lobby=assert(workspace:FindFirstChild("Playground Lobby"),"Install Playground Expansion before this upgrade")
local tag=assert(workspace:FindFirstChild("Tag You're It"),"Install Playground Expansion before this upgrade")
assert(britishBulldog:FindFirstChild("Gameplay") and lobby:FindFirstChild("Gameplay") and tag:FindFirstChild("Gameplay"),"Required existing game geometry is incomplete")
assert(lobby.Gameplay:FindFirstChild("LobbySpawn") and lobby.Gameplay:FindFirstChild("VoteZone") and lobby.Gameplay:FindFirstChild("VoteChoices"),"Lobby gameplay markers are incomplete")
assert(lobby:FindFirstChild("VotingAlcove"),"Lobby voting alcove is missing")
for _,name in ipairs({"BritishBulldogService","TagService","PlaygroundEconomyService","PlaygroundCoordinator","PlaygroundAdminService"}) do
 local object=ServerScriptService:FindFirstChild(name)
 assert(object and object:IsA("ModuleScript") and object.Sandboxed,"Install the sandboxed Playground Expansion first: "..name)
end
for _,name in ipairs({"BritishBulldogState","TagState","PlaygroundState"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("Folder"),"Install Playground Expansion first: "..name)
end
for _,name in ipairs({"PlaygroundAdminRequest","PlaygroundShopRequest","PlaygroundVoteRequest","TagMovementRequest","BBMovementRequest"}) do
 local object=ReplicatedStorage:FindFirstChild(name)
 assert(object and object:IsA("RemoteFunction") and object.Sandboxed,"Install Playground Expansion and movement first: "..name)
end
local tagHUD=assert(StarterGui:FindFirstChild("TagHUD"),"Editable Tag HUD is missing")
local adminHUD=assert(StarterGui:FindFirstChild("PlaygroundAdminPanel"),"Editable admin panel is missing")
local shell=assert(StarterGui:FindFirstChild("PlaygroundShell"),"Editable Playground shell is missing")
for _,gui in ipairs({tagHUD,adminHUD,shell}) do assert(gui:IsA("ScreenGui"),gui.Name.." must be a ScreenGui") end
assert(shell:FindFirstChild("LevelPanel") and shell:FindFirstChild("CompactLevelPanel"),"Install movement and rewards before this upgrade")
assert(shell:FindFirstChild("VotePanel") and shell.VotePanel:FindFirstChild("TagYoureIt") and shell.VotePanel:FindFirstChild("VotesTagYoureIt"),"Authored vote UI is incomplete")
assert(adminHUD:FindFirstChild("Panel") and adminHUD.Panel:FindFirstChild("Body") and adminHUD.Panel.Body:FindFirstChild("Content") and adminHUD.Panel.Body.Content:FindFirstChild("TagYoureIt"),"Authored admin UI is incomplete")
local bootstrap=assert(ServerScriptService:FindFirstChild("PlaygroundBootstrap"),"Install Playground Expansion before this upgrade")
assert(bootstrap:IsA("Script") and bootstrap.Sandboxed,"PlaygroundBootstrap must retain its sandbox")
local baseCaps=SecurityCapabilities.new(
 Enum.SecurityCapability.RunServerScript,Enum.SecurityCapability.RunClientScript,
 Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.CreateInstances,
 Enum.SecurityCapability.Basic,Enum.SecurityCapability.Physics,Enum.SecurityCapability.UI,
 Enum.SecurityCapability.Players,Enum.SecurityCapability.AvatarBehavior,Enum.SecurityCapability.AvatarAppearance,
 Enum.SecurityCapability.Environment,Enum.SecurityCapability.LegacySound,Enum.SecurityCapability.Audio)
local remoteCaps=SecurityCapabilities.new(Enum.SecurityCapability.RemoteEvent)
local rpcCaps=baseCaps:Add(remoteCaps)
local inputRpcCaps=rpcCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
local previewCaps=baseCaps:Add(SecurityCapabilities.new(Enum.SecurityCapability.Animation))
local approvedMudCaps=approvedMudService.Capabilities
assert(inputRpcCaps:Contains(approvedMudCaps) and approvedMudCaps:Contains(inputRpcCaps),"Approved mud capabilities must match the reviewed base plus RemoteEvent and Input")
local backups=ServerStorage:FindFirstChild("PlaygroundBeforeMud20261003")
if not backups then
 backups=Instance.new("Folder")
 backups.Name="PlaygroundBeforeMud20261003"
 backups.Parent=ServerStorage
end
assert(backups:IsA("Folder"),"Mud backup container must be a Folder")
local function backupFolder(name)
 local object=backups:FindFirstChild(name)
 if not object then object=Instance.new("Folder") object.Name=name object.Parent=backups end
 assert(object:IsA("Folder"),name.." must be a Folder")
 return object
end
local savedSources=backupFolder("InstallerSourceBackups")
local guiBackups=backupFolder("AuthoredGuiBackups")
local configBackups=backupFolder("SettingsBeforeMud")
local installed={}
local function saveSource(object)
 local key=object:GetFullName():gsub("[^%w_]","_")
 if savedSources:FindFirstChild(key) then return end
 local value=Instance.new("StringValue")
 value.Name=key
 value.Value=object.Source
 value:SetAttribute("OriginalPath",object:GetFullName())
 value:SetAttribute("OriginalClass",object.ClassName)
 value:SetAttribute("Sandboxed",object.Sandboxed)
 value:SetAttribute("Capabilities",tostring(object.Capabilities))
 if object:IsA("BaseScript") then value:SetAttribute("Disabled",object.Disabled) end
 value.Parent=savedSources
end
local function saveGui(gui)
 if guiBackups:FindFirstChild(gui.Name) then return end
 local copy=assert(gui:Clone(),gui.Name.." must be archivable for the first backup")
 copy:SetAttribute("OriginalPath",gui:GetFullName())
 copy.Enabled=false
 for _,object in ipairs(copy:GetDescendants()) do if object:IsA("BaseScript") then object.Disabled=true end end
 copy.Parent=guiBackups
end
local function saveSettings(object)
 if configBackups:FindFirstChild(object.Name) then return end
 local copy=Instance.new("Folder")
 copy.Name=object.Name
 for name,value in pairs(object:GetAttributes()) do copy:SetAttribute(name,value) end
 copy:SetAttribute("OriginalPath",object:GetFullName())
 copy.Parent=configBackups
end
local function install(className,name,source,parent,caps)
 local object=parent:FindFirstChild(name)
 if name=="StuckInTheMudService" then
  assert(object==approvedMudService,"The approved mud service changed during installation")
  assert(object.Capabilities:Contains(approvedMudCaps) and approvedMudCaps:Contains(object.Capabilities),"Approved mud capabilities changed during installation")
 end
 if object then
  assert(object:IsA(className),name.." has an unexpected class")
  assert(object.Sandboxed,name.." must retain its sandbox")
  saveSource(object)
  if object~=approvedMudService then object.Capabilities=caps end
  object.Source=source
 else
  object=Instance.new(className)
  object.Name=name
  object.Capabilities=caps
  object.Sandboxed=true
  if object:IsA("BaseScript") then object.Disabled=true end
  object.Source=source
  object.Parent=parent
 end
 table.insert(installed,object:GetFullName())
 return object
end
local function remote(name)
 local object=ReplicatedStorage:FindFirstChild(name)
 if object then
  assert(object:IsA("RemoteFunction"),name.." must be a RemoteFunction")
  assert(object.Sandboxed,name.." must retain its sandbox")
  assert(remoteCaps:Contains(object.Capabilities) and object.Capabilities:Contains(remoteCaps),name.." must have only RemoteEvent capability")
 else
  object=Instance.new("RemoteFunction")
  object.Name=name
  object.Capabilities=remoteCaps
  object.Sandboxed=true
  object.Parent=ReplicatedStorage
 end
 return object
end
local function state(name)
 local object=ReplicatedStorage:FindFirstChild(name)
 if not object then object=Instance.new("Folder") object.Name=name object:SetAttribute("Phase","Waiting") object.Parent=ReplicatedStorage end
 assert(object:IsA("Folder"),name.." must be a Folder")
 return object
end
for _,gui in ipairs({tagHUD,adminHUD,shell}) do saveGui(gui) end
local previousMudHUD=StarterGui:FindFirstChild("MudHUD")
if previousMudHUD then assert(previousMudHUD:IsA("ScreenGui"),"MudHUD must be a ScreenGui") saveGui(previousMudHUD) end
saveSource(bootstrap)
saveSettings(lobby)
saveSettings(tag)
bootstrap.Disabled=true
remote("MudActionRequest")
remote("TagSprintRequest")
state("MudState")
local arenaResult=buildMudArena()
local mud=assert(workspace:FindFirstChild("Stuck in the Mud"),"Mud arena creation failed")
assert(mud:FindFirstChild("Gameplay") and mud:FindFirstChild("Geometry"),"Existing Mud arena geometry is incomplete and was preserved")
for _,name in ipairs({"ArenaBounds","StartPads","TeamSpawns","NavigationNodes","CoverVolumes","RescueAreas","PracticeSpawns"}) do
 assert(mud.Gameplay:FindFirstChild(name),"Mud Gameplay."..name.." is missing; existing geometry was preserved")
end
saveSettings(mud)
local repairResult=repairMudArena()
local sceneryResult=buildSchoolScenery()
local toolsResult=buildMudGunTemplates()
local hudResult=buildMudHUD()
local sprintResult=buildTagSprintUI()
local voteResult=upgradeThirdGameLobby()
local mudHUD=assert(StarterGui:FindFirstChild("MudHUD"),"Editable Mud HUD is missing")
assert(mudHUD:IsA("ScreenGui") and mudHUD:FindFirstChild("Main"),"Existing Mud HUD is incomplete and was preserved")
assert(tagHUD:FindFirstChild("SprintPanel"),"Editable Tag sprint controls are missing")
assert(shell.VotePanel:FindFirstChild("StuckInTheMud") and adminHUD.Panel.Body.Content:FindFirstChild("StuckInTheMud"),"Editable third-game controls are missing")
assert(shell:FindFirstChild("CompactVotePanel"),"Editable compact voting panel is missing")
assert(adminHUD:FindFirstChild("CompactPanel") and adminHUD:FindFirstChild("CompactToggle"),"Editable compact admin controls are missing")
local assets=assert(ReplicatedStorage:FindFirstChild("MudAssets"),"Mud assets are missing")
for _,name in ipairs({"MudGun","HeatGun"}) do
 local tool=assets:FindFirstChild(name)
 assert(tool and tool:IsA("Tool") and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("MuzzleAttachment"),name.." requires its native Handle and MuzzleAttachment")
end
lobby:SetAttribute("WinnerCoins",150)
lobby:SetAttribute("LoserCoins",50)
lobby:SetAttribute("WinnerXP",50)
lobby:SetAttribute("LoserXP",50)
lobby:SetAttribute("BaseLevelXP",200)
lobby:SetAttribute("LevelXPStep",50)
if mud:GetAttribute("TeamCount")==nil then mud:SetAttribute("TeamCount",2) end
if mud:GetAttribute("MaxTeamSize")==nil then mud:SetAttribute("MaxTeamSize",2) end
if mud:GetAttribute("MaxPlayers")==nil then mud:SetAttribute("MaxPlayers",4) end
if mud:GetAttribute("MinimumPlayers")==nil then mud:SetAttribute("MinimumPlayers",4) end
if mud:GetAttribute("RoundDuration")==nil then mud:SetAttribute("RoundDuration",300) end
if mud:GetAttribute("SprintSeconds")==nil then mud:SetAttribute("SprintSeconds",10) end
if mud:GetAttribute("SprintMultiplier")==nil then mud:SetAttribute("SprintMultiplier",2.5) end
if mud:GetAttribute("SprintRefillSeconds")==nil then mud:SetAttribute("SprintRefillSeconds",15) end
if mud:GetAttribute("RescueSeconds")==nil then mud:SetAttribute("RescueSeconds",5) end
if mud:GetAttribute("ProjectileSpeed")==nil then mud:SetAttribute("ProjectileSpeed",115) end
if mud:GetAttribute("MudRange")==nil then mud:SetAttribute("MudRange",130) end
if mud:GetAttribute("MudCooldownSeconds")==nil then mud:SetAttribute("MudCooldownSeconds",0.65) end
if mud:GetAttribute("HeatRange")==nil then mud:SetAttribute("HeatRange",24) end
if tag:GetAttribute("SprintSeconds")==nil then tag:SetAttribute("SprintSeconds",10) end
if tag:GetAttribute("SprintMultiplier")==nil then tag:SetAttribute("SprintMultiplier",2.5) end
if tag:GetAttribute("SprintRefillSeconds")==nil then tag:SetAttribute("SprintRefillSeconds",15) end
install("ModuleScript","StuckInTheMudService",sources.StuckInTheMudService,ServerScriptService,approvedMudCaps)
install("ModuleScript","TagSprintService",sources.TagSprintService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundCoordinator",sources.PlaygroundCoordinator,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundEconomyService",sources.PlaygroundEconomyService,ServerScriptService,rpcCaps)
install("ModuleScript","PlaygroundAdminService",sources.PlaygroundAdminService,ServerScriptService,rpcCaps)
install("ModuleScript","TagService",sources.TagService,ServerScriptService,rpcCaps)
local clients={
 install("LocalScript","Controller",sources.MudHUD,mudHUD,inputRpcCaps),
 install("LocalScript","SprintController",sources.TagSprint,tagHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.TagHUD,tagHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundAdminPanel,adminHUD,inputRpcCaps),
 install("LocalScript","Controller",sources.PlaygroundShell,shell,rpcCaps),
 install("LocalScript","PlayerLevelController",sources.PlayerLevel,shell,previewCaps),
}
for _,object in ipairs(clients) do object.Disabled=false end
local oldBootstrap=ServerScriptService:FindFirstChild("BritishBulldogBootstrap")
if oldBootstrap and oldBootstrap:IsA("Script") then
 saveSource(oldBootstrap)
 oldBootstrap.Disabled=true
end
britishBulldog:SetAttribute("AutoStart",false)
lobby.Gameplay.LobbySpawn.Enabled=true
bootstrap=install("Script","PlaygroundBootstrap",sources.PlaygroundBootstrap,ServerScriptService,rpcCaps)
bootstrap:SetAttribute("Ready",false)
bootstrap.Disabled=false
backups:SetAttribute("MudInstalled",true)
backups:SetAttribute("MudVersion",1)
return {installed=true,scripts=#installed,arena=arenaResult,repair=repairResult,scenery=sceneryResult,tools=toolsResult,hud=hudResult,sprint=sprintResult,voting=voteResult,authoredLayoutsPreserved=true,dataStoreCapabilityGranted=false,bootstrap=bootstrap:GetFullName()}
