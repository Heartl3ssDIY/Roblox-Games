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
	local offset = (count % 2 == 1 and teamCount == 2) and math.random(0, 1) or 0
	for index = 1, count do result[index] = (index - 1 + offset) % teamCount + 1 end
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
	local ring = math.floor((index - 1) / #pads)
	if ring > 0 then
		local angle = ring * 2.4
		position += Vector3.new(math.cos(angle), 0, math.sin(angle)) * (4 * ring)
	end
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

local function managedGun(tool)
	return tool:IsA("Tool") and (tool.Name == "MudGun" or tool.Name == "HeatGun")
		and (tool:GetAttribute("MDManaged") == true or tool:GetAttribute("ManagedMudTemplate") == true)
end

function Service:_toolsAllowed(record)
	return not record.isBot and self.active and record.participating and alive(record)
		and record.player.Character == record.character
		and not record.player:GetAttribute("BBParticipating") and not record.player:GetAttribute("TGParticipating")
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
				or tool:GetAttribute("MDRound") ~= self.roundNumber or tool:GetAttribute("MDOwnerUserId") ~= record.player.UserId then
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
	local backpack = record.player:FindFirstChild("Backpack")
	local assets = ReplicatedStorage:FindFirstChild("MudAssets")
	if not backpack or not assets then return end
	record.humanoid:UnequipTools()
	local first
	for _, name in ipairs({ "MudGun", "HeatGun" }) do
		local template = assets:FindFirstChild(name)
		if template and template:IsA("Tool") then
			local tool = template:Clone()
			tool:SetAttribute("MDManaged", true)
			tool:SetAttribute("MDRound", self.roundNumber)
			tool:SetAttribute("MDOwnerUserId", record.player.UserId)
			tool.CanBeDropped = false
			table.insert(record.managedTools, tool)
			tool.Parent = backpack
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
	self:_watchTools(record, character, record.characterConnections)
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		if record.participating then self:_stick(record, nil) end
		record.ready = false
		self:_destroyTools(record)
	end))
	if record.participating then
		self:_teleport(record, record.lastGoodCFrame or self:_spawn(record.spawnIndex, record.teamId))
		self:_freeze(record, record.muddy or record.eliminated or self.phase ~= "Playing") self:_giveTools(record) self:_role(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = self:_record(player, false)
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_setupCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character == character then
			if record.participating then self:_stick(record, nil) end
			record.ready = false
			self:_destroyTools(record)
		end
	end))
	local function watchContainer(container)
		if container:IsA("Backpack") or container.Name == "StarterGear" then self:_watchTools(record, container, record.connections) end
	end
	table.insert(record.connections, player.ChildAdded:Connect(watchContainer))
	for _, container in ipairs(player:GetChildren()) do watchContainer(container) end
	for _, name in ipairs({ "BBParticipating", "TGParticipating" }) do
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
	if release then record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = false, nil, nil, 0 end
end

function Service:_canAct(record, now)
	return self.active and self.phase == "Playing" and self.pendingWinners == nil and now < self.endsAt and record.participating
		and not record.muddy and not record.eliminated and not record.frozen and alive(record)
end

function Service:_equipped(record, kind)
	if record.isBot then return true end
	if not self:_toolsAllowed(record) then return nil end
	if not record.character then return nil end
	local name = kind == "Mud" and "MudGun" or "HeatGun"
	for _, tool in ipairs(record.character:GetChildren()) do if tool:IsA("Tool") and tool.Name == name and tool:GetAttribute("MDManaged") == true and tool:GetAttribute("MDRound") == self.roundNumber and tool:GetAttribute("MDOwnerUserId") == record.player.UserId and tool:GetAttribute("GunKind") == kind and tool.Enabled == true then return tool end end
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

function Service:_fire(record, aim, now)
	if not self:_canAct(record, now) or now < (record.fireReadyAt or 0) then return false end
	local unit, origin = self:_resolveAim(record, "Mud", aim) if not unit or not origin then return false end
	local glob = Instance.new("Part") glob.Name = "MudGlob" glob.Shape = Enum.PartType.Ball glob.Size = Vector3.new(1.1, 1.1, 1.1)
	glob.Material = Enum.Material.SmoothPlastic glob.Color = Color3.fromRGB(132, 88, 57) glob.Anchored = true glob.CanCollide = false glob.CanTouch = false glob.CanQuery = false glob.Position = origin glob.Parent = self:_effects()
	table.insert(self.projectiles, { part = glob, position = origin, direction = unit, speed = self:_setting("ProjectileSpeed", 115, 1), remaining = self:_setting("MudRange", 130, 1), source = record, teamId = record.teamId, token = self.currentRound })
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
	local unit, origin = self:_resolveAim(record, "Heat", record.heatAim or record.heatDirection) if not unit or not origin then return nil end
	local hit = workspace:Raycast(origin, unit * self:_setting("HeatRange", 24, 1), self:_rayParameters(record, false))
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
	if action == "Fire" then return { ok = self:_fire(record, value, now), message = "Mud shot." } end
	local unit, origin = self:_resolveAim(record, "Heat", aim)
	if value ~= true or not unit or not origin then return { ok = false, message = "Equip the Heat Gun and aim toward the playground." } end
	record.heatHeld, record.heatDirection, record.heatAim, record.heatLeaseEndsAt = true, unit, typeof(aim) == "table" and aim or nil, now + 1
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
	for _, record in pairs(self.records) do self:_destroyTools(record) end
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
	local maximum = math.clamp(math.floor(self:_setting("MaxPlayers", 1000, 2)), 2, 1000)
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
	if not provider:IsCollisionGroupRegistered("MudPlayer") then provider:RegisterCollisionGroup("MudPlayer") end provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", true)
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


