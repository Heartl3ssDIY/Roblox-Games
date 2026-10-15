assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local realWorkspace = workspace
local realStorage = game:GetService("ServerStorage")
local container = Instance.new("Folder")
container.Name = "HideSeekAbilityNativeChecks20261012"
container.Parent = realWorkspace
local report = { checks = {}, errors = {} }
local function check(name, condition)
	table.insert(report.checks, { name = name, passed = condition == true })
	assert(condition, name)
end
local function signal()
	local entries = {}
	return {
		Connect = function(_, callback)
			local entry = { callback = callback, active = true }
			table.insert(entries, entry)
			return { Disconnect = function() entry.active = false end }
		end,
		Fire = function(_, ...) for _, entry in ipairs(entries) do if entry.active then entry.callback(...) end end end,
	}
end
local services, players, now = {}, {}, 100
local playersService = { PlayerAdded = signal(), PlayerRemoving = signal() }
function playersService:GetPlayers() return players end
local function player(index)
	local attrs = { PCDataReady = true }
	local object = { UserId = 990000 + index, Name = "SchoolFixture" .. index, DisplayName = "SchoolFixture" .. index,
		Parent = playersService, CharacterAdded = signal(), CharacterRemoving = signal() }
	function object:GetAttribute(name) return attrs[name] end
	function object:SetAttribute(name, value) attrs[name] = value end
	return object
end
local function part(parent, name, position, size, collidable)
	local object = Instance.new("Part")
	object.Name, object.Size, object.Position = name, size or Vector3.one, position
	object.Anchored, object.CanCollide, object.CanQuery = true, collidable == true, collidable == true
	object.Parent = parent
	return object
end
local origin = Vector3.new(-28000, 1033, 4500)
local arena = Instance.new("Folder")
arena.Name = "Hide and Seek"
arena.Parent = container
for name, value in pairs({ FloorY = origin.Y, MinimumPlayers = 2, MaxPlayers = 16, RoundDuration = 300,
	HideSeconds = 30, CountdownSeconds = 3, ResultsSeconds = 7, BaseSpeed = 16, SeekerSpeed = 18, TagDistance = 10 }) do arena:SetAttribute(name, value) end
local gameplay = Instance.new("Folder")
gameplay.Name, gameplay.Parent = "Gameplay", arena
local bounds = part(gameplay, "ArenaBounds", origin + Vector3.new(0, 42, 0), Vector3.new(208, 84, 204))
for name, count in pairs({ HiderSpawns = 16, SeekerSpawns = 4 }) do
	local folder = Instance.new("Folder") folder.Name, folder.Parent = name, gameplay
	for index = 1, count do part(folder, "Spawn" .. string.format("%02d", index), origin + Vector3.new(index * 4 - 36, 3, name == "SeekerSpawns" and -50 or 0)) end
end
local lockerSpots = Instance.new("Folder") lockerSpots.Name, lockerSpots.Parent = "LockerSpots", gameplay
local lockerModel = Instance.new("Model") lockerModel.Name, lockerModel.Parent = "FixtureLocker", lockerSpots
local door = part(lockerModel, "Door", origin + Vector3.new(20, 3, -12), Vector3.new(4, 6, 0.25), true)
part(lockerModel, "HidePoint", origin + Vector3.new(20, 3, -14))
part(lockerModel, "ExitPoint", origin + Vector3.new(20, 3, -6))
local prompt = Instance.new("ProximityPrompt") prompt.Name, prompt.Parent = "LockerPrompt", door
part(container, "AbilityTestFloor", origin + Vector3.new(0,-0.5,0), Vector3.new(200,1,200), true)
local state = Instance.new("Folder") state.Name, state.Parent = "HideAndSeekState", container
local templates = Instance.new("Folder") templates.Name, templates.Parent = "SchoolPropTemplates", container
local function template(name, size, eligible)
    local model = Instance.new("Model") model.Name, model.Parent = name, templates
    model:SetAttribute("HSPropId", name) model:SetAttribute("HSPropEligible", eligible) model:SetAttribute("DisplayName", name)
    local body = part(model, "PropBody", Vector3.new(0, size.Y * 0.5, 0), size, true)
    model:PivotTo(CFrame.identity)
    return model
end
local usableTemplate = template("SA01 School chair", Vector3.new(3, 4, 3), true)
template("SA31 Broadleaf plant", Vector3.new(3, 4, 3), true)
template("SA09 Pencil", Vector3.new(0.2, 0.2, 3), true)
template("SA21 Wardrobe", Vector3.new(3, 5, 3), true)
template("SA22 Tray drawer", Vector3.new(4, 4, 3), true)
template("SA99 Tiny", Vector3.new(0.4, 1.5, 0.4), true)
template("SA20 Not enabled", Vector3.new(3, 4, 3), false)
lockerModel:SetAttribute("HSHidingSpotName", "Wardrobe")
local remote = { OnServerEvent = signal(), IsA = function(_, class) return class == "RemoteEvent" end }
services.Players = playersService
services.RunService = { Heartbeat = signal() }
services.ReplicatedStorage = { FindFirstChild = function(_, name) if name == "SchoolPropTemplates" then return templates elseif name == "HideAndSeekState" then return state elseif name == "HideAndSeekSprintRequest" or name == "HideAndSeekActionRequest" then return remote end end }
local env = {
	game = { GetService = function(_, name) return assert(services[name], "Missing service " .. name) end },
	workspace = setmetatable({ GetServerTimeNow = function() return now end }, { __index = function(_, key)
		if key == "Raycast" then return function(_, ...) return realWorkspace:Raycast(...) end end
		return realWorkspace[key]
	end }),
}
local module = Instance.new("ModuleScript")
module.Name = "ExactHideSeekCapabilityFixture"
module.Sandboxed = true
module.Capabilities = game.ServerScriptService.HideAndSeekService.Capabilities
module.Source = "return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\n" .. [======[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Service = {}
Service.__index = Service
local runningService
local BAT_RAGDOLL_SECONDS = 1.35
local BAT_SAMPLE_MAX_AGE = 0.15
local BAT_FACING_DOT = 0.15
local MAX_STAMINA = 25

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
	return record and record.ready and record.character and record.character.Parent
		and record.root and record.root.Parent and record.humanoid and record.humanoid.Health > 0
end

local function parts(folder)
	local result = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then table.insert(result, child) end
	end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end

function Service.new(arena, state)
	local self = setmetatable({}, Service)
	self.arena = arena
	self.gameplay = arena:WaitForChild("Gameplay")
	self.bounds = self.gameplay:WaitForChild("ArenaBounds")
	local bell = arena:FindFirstChild("SchoolBell", true)
	self.schoolBell = bell and bell:IsA("Sound") and bell or nil
	self.hiderSpawns = parts(self.gameplay:WaitForChild("HiderSpawns"))
	self.seekerSpawns = parts(self.gameplay:WaitForChild("SeekerSpawns"))
	assert(#self.hiderSpawns >= 16 and #self.seekerSpawns > 0, "Hide and Seek needs 16 hider spawns and seeker spawns")
	self.state = state or ReplicatedStorage:FindFirstChild("HideAndSeekState")
	if not self.state then
		self.state = Instance.new("Folder")
		self.state.Name = "HideAndSeekState"
		self.state.Parent = ReplicatedStorage
	end
	self.records, self.connections, self.lockers, self.decoys = {}, {}, {}, {}
	self.random = Random.new()
	self.active, self.running = false, false
	self.phase, self.mode, self.roundNumber = "Waiting", "Waiting", 0
	self.endsAt, self.hidingEndsAt, self.tickAccumulator = 0, 0, 0
	return self
end

function Service:_setting(name, fallback, minimum, maximum)
	local value = self.arena:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = fallback end
	return math.clamp(value, minimum or 0, maximum or math.huge)
end

function Service:_ringSchoolBell()
	local bell = self.schoolBell
	if not bell or not bell.Parent then return end
	bell:Stop()
	bell.TimePosition = 0
	bell:Play()
end

function Service:_phase(phase)
	self.phase = phase
	attribute(self.state, "Phase", phase)
	for _, locker in pairs(self.lockers) do locker.prompt.Enabled = self.active and (phase == "Hiding" or phase == "Seeking") end
end

function Service:_publish()
	local hiders, seekers, seekerIds = 0, 0, {}
	for player, record in pairs(self.records) do
		if record.participating and player.Parent == Players then
			if record.role == "Seeker" then seekers += 1 table.insert(seekerIds, player.UserId)
			elseif record.role == "Hider" then hiders += 1 end
		end
	end
	table.sort(seekerIds)
	attribute(self.state, "ParticipantCount", hiders + seekers)
	attribute(self.state, "HiderCount", hiders)
	attribute(self.state, "SeekerCount", seekers)
	attribute(self.state, "SeekerUserIds", table.concat(seekerIds, ","))
	return hiders, seekers
end

function Service:_movement(record)
	if not alive(record) then return end
	local locked = record.frozen or record.locker or record.ragdoll
	local allowed = record.participating and (self.phase == "Hiding" or self.phase == "Seeking") and not locked
	local sprinting = allowed and record.sprintHeld and record.stamina > 0
	local speed = record.role == "Seeker" and self:_setting("SeekerSpeed", 18, 8, 24) or self:_setting("BaseSpeed", 16, 8, 24)
	local anchor = record.locker ~= nil or (record.frozen and not record.ragdoll) or record.original.Anchored
	if record.root.Anchored ~= anchor then
		if anchor then pcall(function() record.root:SetNetworkOwner(nil) end) end
		record.root.Anchored = anchor
		if not anchor then pcall(function() record.root:SetNetworkOwnershipAuto() end) end
	end
	record.humanoid.WalkSpeed = locked and 0 or (sprinting and 26 or speed)
	record.humanoid.JumpPower = locked and 0 or record.original.JumpPower
	record.humanoid.JumpHeight = locked and 0 or record.original.JumpHeight
	attribute(record.player, "HSSprinting", sprinting == true)
	attribute(record.player, "HSStamina", math.floor(record.stamina * 10) / 10)
	attribute(record.player, "HSMaxStamina", MAX_STAMINA)
end

function Service:_role(record, role)
	if role ~= "Hider" then self:_clearAbilityEffects(record) self:_restorePropMorph(record) end
	record.role = role
	attribute(record.player, "HSRole", role)
	attribute(record.player, "HSParticipating", record.participating == true)
	if record.character then attribute(record.character, "HSRole", role) end
	if record.participating then self:_concealLabels(record) end
	self:_movement(record)
end

function Service:_propTemplates()
	local folder = ReplicatedStorage:FindFirstChild("SchoolPropTemplates")
	local result = {}
	if not folder then return result end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("HSPropEligible") == true
			and type(model:GetAttribute("HSPropId")) == "string" then
			local _, size = model:GetBoundingBox()
			local label = string.lower(model.Name .. " " .. tostring(model:GetAttribute("DisplayName") or ""))
			local forbidden = label:find("pencil", 1, true) or label:find("wardrobe", 1, true)
				or label:find("drawer", 1, true) or label:find("cupboard", 1, true) or label:find("tray", 1, true)
			if not forbidden and size.Y >= 1.4 and math.max(size.X, size.Z) >= 1.8
				and size.X * size.Y * size.Z >= 4 and math.max(size.X, size.Y, size.Z) <= 8
				and model:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(result, model)
			end
		end
	end
	table.sort(result, function(first, second) return first.Name < second.Name end)
	return result
end

function Service:_concealPropAvatar(record, added)
	local saved = record.propMorph
	if not saved or saved.character ~= record.character then return end
	local objects = added and { added } or record.character:GetDescendants()
	for _, object in ipairs(objects) do
		if object ~= saved.model and not object:IsDescendantOf(saved.model) then
			local property, value
			if object:IsA("BasePart") or object:IsA("Decal") then property, value = "Transparency", 1
			elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
				or object:IsA("Highlight") or object:IsA("BillboardGui") or object:IsA("SurfaceGui")
				or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles") then
				property, value = "Enabled", false
			end
			if property then
				if not saved.visuals[object] then saved.visuals[object] = { property = property, value = object[property] } end
				object[property] = value
			end
		end
	end
end

function Service:_restorePropMorph(record)
	local saved = record.propMorph
	record.propMorph = nil
	if saved then
		for object, original in pairs(saved.visuals) do
			if object.Parent then object[original.property] = original.value end
		end
		if saved.model then saved.model:Destroy() end
		if saved.character.Parent then
			attribute(saved.character, "HSPropMorphed", false)
			attribute(saved.character, "HSPropId", "")
		end
	end
	attribute(record.player, "HSPropMorphed", false)
	attribute(record.player, "HSPropId", "")
	attribute(record.player, "HSPropName", "")
end

function Service:_applyPropMorph(record, excludeId)
	if not alive(record) or record.role ~= "Hider" then return false end
	local options = self:_propTemplates()
	if #options == 0 then return false end
	if excludeId and #options > 1 then
		for index = #options, 1, -1 do
			if options[index]:GetAttribute("HSPropId") == excludeId then table.remove(options, index) end
		end
	end
	self:_restorePropMorph(record)
	local template = options[self.random:NextInteger(1, #options)]
	local model
	local ok, failure = xpcall(function()
		model = template:Clone()
		assert(model, "School prop could not be cloned")
		model.Name = "SchoolPropMorph"
		model.PrimaryPart = nil
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("LuaSourceContainer") or object:IsA("Humanoid") or object:IsA("AnimationController")
				or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("JointInstance")
				or object:IsA("Constraint") or object:IsA("WeldConstraint") then object:Destroy() end
		end
		model:PivotTo(CFrame.identity)
		local box, size = model:GetBoundingBox()
		local leg = record.character:FindFirstChild("Left Leg") or record.character:FindFirstChild("Right Leg")
		local legHeight = record.humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") and leg.Size.Y or 0
		local floorOffset = record.humanoid.HipHeight + legHeight + record.root.Size.Y * 0.5
		local bottom = CFrame.new(box.Position.X, box.Position.Y - size.Y * 0.5, box.Position.Z)
		model:PivotTo(record.root.CFrame * CFrame.new(0, -floorOffset, 0) * bottom:Inverse() * model:GetPivot())
		local count = 0
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("BasePart") then
				object.Anchored, object.Massless = false, true
				object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
				if object:IsA("Seat") or object:IsA("VehicleSeat") then object.Disabled = true end
				local weld = Instance.new("WeldConstraint")
				weld.Name, weld.Part0, weld.Part1, weld.Parent = "SchoolPropWeld", record.root, object, object
				count += 1
			end
		end
		assert(count > 0, "School prop has no visible parts")
		local outline = Instance.new("Highlight")
		outline.Name, outline.Adornee = "SchoolPropOutline", model
		outline.FillTransparency, outline.OutlineTransparency = 1, 0
		outline.OutlineColor = Color3.new(0, 0, 0)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
		record.propMorph = { model = model, character = record.character, visuals = {} }
		model.Parent = record.character
		self:_concealPropAvatar(record)
		attribute(record.player, "HSPropMorphed", true)
		attribute(record.player, "HSPropId", template:GetAttribute("HSPropId"))
		attribute(record.player, "HSPropName", template:GetAttribute("DisplayName") or template.Name)
		attribute(record.character, "HSPropMorphed", true)
		attribute(record.character, "HSPropId", template:GetAttribute("HSPropId"))
	end, debug.traceback)
	if not ok then
		self:_restorePropMorph(record)
		if model then model:Destroy() end
		warn("School prop could not prepare a hider: " .. tostring(failure))
	end
	return ok
end

function Service:_abilityRecord(player, role)
	local record = self.records[player]
	if player.Parent ~= Players or not self.running or not self.active
		or (self.phase ~= "Hiding" and self.phase ~= "Seeking")
		or (self.phase == "Seeking" and workspace:GetServerTimeNow() >= self.endsAt)
		or not record or not record.participating or record.role ~= role or not alive(record)
		or record.frozen or record.ragdoll or record.locker or not self:_inBounds(record) then return nil end
	return record
end

function Service:_batTargets()
	local targets = {}
	for _, record in pairs(self.records) do table.insert(targets, record) end
	for _, decoy in pairs(self.decoys) do table.insert(targets, decoy) end
	return targets
end

function Service:_removeDecoy(decoy)
	if self.decoys[decoy.character] ~= decoy then return end
	self.decoys[decoy.character] = nil
	if decoy.character.Parent then decoy.character:Destroy() end
	local record = decoy.owner
	if record.decoys then
		local index = table.find(record.decoys, decoy)
		if index then table.remove(record.decoys, index) end
	end
	attribute(record.player, "HSDecoyCount", record.decoys and #record.decoys or 0)
end

function Service:_clearAbilityEffects(record)
	for index = #(record.decoys or {}), 1, -1 do self:_removeDecoy(record.decoys[index]) end
	record.decoys = {}
	record.scanActiveUntil = 0
	attribute(record.player, "HSDecoyCount", 0)
	attribute(record.player, "HSScanActiveUntil", 0)
	attribute(record.player, "HSRevealedUntil", 0)
	attribute(record.player, "HSRevealReason", "")
	attribute(record.player, "HSRevealSource", 0)
end

function Service:_resetAbilities(record)
	self:_clearAbilityEffects(record)
	record.switchReadyAt, record.decoyReadyAt, record.scanReadyAt = 0, 0, 0
	attribute(record.player, "HSSwitchReadyAt", 0)
	attribute(record.player, "HSDecoyReadyAt", 0)
	attribute(record.player, "HSScanReadyAt", 0)
end

function Service:_reveal(record, untilTime, reason, source)
	if not record.participating or record.role ~= "Hider" or not alive(record) then return false end
	if untilTime >= (record.player:GetAttribute("HSRevealedUntil") or 0) then
		attribute(record.player, "HSRevealedUntil", untilTime)
		attribute(record.player, "HSRevealReason", reason)
		attribute(record.player, "HSRevealSource", source and source.player.UserId or 0)
	end
	return true
end

function Service:ChangeProp(player)
	local record, now = self:_abilityRecord(player, "Hider"), workspace:GetServerTimeNow()
	if not record or now < (record.switchReadyAt or 0) then return false end
	local previous = player:GetAttribute("HSPropId")
	if not self:_applyPropMorph(record, previous) then return false end
	record.switchReadyAt = now + 3
	attribute(player, "HSSwitchReadyAt", record.switchReadyAt)
	return true
end

function Service:DropDecoy(player)
	local record, now = self:_abilityRecord(player, "Hider"), workspace:GetServerTimeNow()
	if not record or now < (record.decoyReadyAt or 0) or not record.propMorph
		or record.propMorph.model.Parent ~= record.character then return false end
	local ground = workspace:Raycast(record.root.Position, Vector3.new(0, -8, 0), self:_rayParameters())
	if not ground or ground.Normal.Y < 0.7 then return false end
	local source = record.propMorph.model
	local box, size = source:GetBoundingBox()
	local bottom = box.Position.Y - size.Y * 0.5
	if math.abs(bottom - ground.Position.Y) > 2 then return false end
	local model
	local ok, failure = xpcall(function()
		model = source:Clone()
		assert(model, "School decoy could not be cloned")
		model.Name = "SchoolPropDecoy"
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("LuaSourceContainer") or object:IsA("Humanoid") or object:IsA("AnimationController")
				or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("JointInstance")
				or object:IsA("Constraint") or object:IsA("WeldConstraint") then object:Destroy()
			elseif object:IsA("BasePart") then
				object.Anchored, object.Massless = true, true
				object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
				if object:IsA("Seat") or object:IsA("VehicleSeat") then object.Disabled = true end
			end
		end
		model:PivotTo(source:GetPivot() + Vector3.new(0, ground.Position.Y - bottom, 0))
		local root = Instance.new("Part")
		root.Name, root.Size, root.Transparency = "DecoyHitRoot", Vector3.one, 1
		root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
		root.CFrame = record.root.CFrame + Vector3.new(0, ground.Position.Y - bottom, 0)
		root.Parent = model
		model:SetAttribute("HSDecoy", true)
		model:SetAttribute("HSDecoyOwnerId", player.UserId)
		model:SetAttribute("HSPropId", player:GetAttribute("HSPropId"))
		if not self.decoyFolder or not self.decoyFolder.Parent then
			self.decoyFolder = Instance.new("Folder")
			self.decoyFolder.Name, self.decoyFolder.Parent = "HideAndSeekDecoys", self.arena
		end
		model.Parent = self.decoyFolder
		local decoy = { owner = record, root = root, character = model, createdAt = now, token = self.currentRound }
		self.decoys[model] = decoy
		record.decoys = record.decoys or {}
		table.insert(record.decoys, decoy)
		while #record.decoys > 3 do self:_removeDecoy(record.decoys[1]) end
	end, debug.traceback)
	if not ok then
		if model then model:Destroy() end
		warn("School decoy could not prepare: " .. tostring(failure))
		return false
	end
	record.decoyReadyAt = now + 10
	attribute(player, "HSDecoyReadyAt", record.decoyReadyAt)
	attribute(player, "HSDecoyCount", #record.decoys)
	return true
end

function Service:Scan(player)
	local record, now = self:_abilityRecord(player, "Seeker"), workspace:GetServerTimeNow()
	if not record or self.phase ~= "Seeking" or now < (record.scanReadyAt or 0) then return false end
	record.scanActiveUntil, record.scanReadyAt = now + 10, now + 70
	attribute(player, "HSScanActiveUntil", record.scanActiveUntil)
	attribute(player, "HSScanReadyAt", record.scanReadyAt)
	for _, target in pairs(self.records) do self:_reveal(target, record.scanActiveUntil, "Scan", record) end
	return true
end

function Service:_hitDecoy(decoy, seeker, now)
	local owner = decoy.owner
	if self.decoys[decoy.character] ~= decoy or decoy.token ~= self.currentRound
		or self.records[owner.player] ~= owner or not owner.participating or owner.role ~= "Hider" or not alive(owner) then return false end
	self:_removeDecoy(decoy)
	self:_reveal(owner, now + 5, "Decoy", seeker)
	attribute(seeker.player, "PCBatHitSerial", (seeker.player:GetAttribute("PCBatHitSerial") or 0) + 1)
	return true
end

function Service:HandleAction(player, action)
	if typeof(action) ~= "string" then return false end
	if action == "LeaveLocker" then return self:ExitLocker(player) end
	if action == "ChangeProp" then return self:ChangeProp(player) end
	if action == "DropDecoy" then return self:DropDecoy(player) end
	if action == "Scan" then return self:Scan(player) end
	return false
end

function Service:_concealLabels(record)
	if not record.character or not record.humanoid then return end
	if not record.labels then
		record.labels = { character = record.character, humanoid = record.humanoid, objects = {},
			DisplayDistanceType = record.humanoid.DisplayDistanceType, HealthDisplayType = record.humanoid.HealthDisplayType }
	end
	record.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	record.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, object in ipairs(record.character:GetDescendants()) do
		if record.propMorph and object:IsDescendantOf(record.propMorph.model) then continue end
		if object:IsA("BillboardGui") then
			if not record.labels.objects[object] then record.labels.objects[object] = { Enabled = object.Enabled } end
			object.Enabled = false
		elseif object:IsA("Highlight") then
			if not record.labels.objects[object] then record.labels.objects[object] = { Enabled = object.Enabled, DepthMode = object.DepthMode } end
			object.DepthMode = Enum.HighlightDepthMode.Occluded
			object.Enabled = record.role == "Seeker" and record.labels.objects[object].Enabled or false
		end
	end
end

function Service:_restoreLabels(record)
	local saved = record.labels
	if not saved then return end
	record.labels = nil
	if saved.humanoid.Parent then
		saved.humanoid.DisplayDistanceType, saved.humanoid.HealthDisplayType = saved.DisplayDistanceType, saved.HealthDisplayType
	end
	for object, original in pairs(saved.objects) do
		if object.Parent then object.Enabled = original.Enabled if original.DepthMode then object.DepthMode = original.DepthMode end end
	end
end

function Service:_inBounds(record, margin)
	if not alive(record) then return false end
	local point = self.bounds.CFrame:PointToObjectSpace(record.root.Position)
	local half = self.bounds.Size * 0.5
	return math.abs(point.X) <= half.X - (margin or 0) and math.abs(point.Z) <= half.Z - (margin or 0)
		and math.abs(point.Y) <= half.Y and record.root.Position.Y >= self:_setting("FloorY", 33, -100000) - 8
end

function Service:_releaseSeat(record)
	local seat = record.humanoid.SeatPart
	record.humanoid.Sit = false
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(record.character) then weld:Destroy() end
end

function Service:_teleport(record, target)
	if not alive(record) then return false end
	self:_releaseSeat(record)
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	record.character:PivotTo(target * record.root.CFrame:Inverse() * record.character:GetPivot())
	return true
end

function Service:_spawn(index, seeker)
	local list = seeker and self.seekerSpawns or self.hiderSpawns
	return list[(index - 1) % #list + 1].CFrame
end

function Service:_rayParameters(extra)
	local ignored = { self.bounds, self.gameplay.HiderSpawns, self.gameplay.SeekerSpawns }
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(ignored, player.Character) end end
	if extra then table.insert(ignored, extra) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	return params
end

function Service:_restoreLocker(record, moveOutside)
	local saved = record.locker
	if not saved then return end
	record.locker = nil
	if saved.locker.occupant == record then saved.locker.occupant = nil end
	for part, original in pairs(saved.parts) do
		if part.Parent then part.CanCollide = original end
	end
	for object, original in pairs(saved.visuals) do
		if object.Parent then object[original.property] = original.value end
	end
	if saved.root.Parent then
		saved.root.Anchored = saved.anchored
		saved.root.AssemblyLinearVelocity = Vector3.zero
		saved.root.AssemblyAngularVelocity = Vector3.zero
	end
	attribute(record.player, "HSHiding", false)
	attribute(record.player, "HSLockerName", "")
	if saved.character.Parent then attribute(saved.character, "HSHiding", false) end
	if record.character == saved.character and alive(record) then
		if moveOutside then self:_teleport(record, saved.locker.exit.CFrame) end
		pcall(function() if saved.owner then saved.root:SetNetworkOwner(saved.owner) else saved.root:SetNetworkOwnershipAuto() end end)
		self:_movement(record)
	end
end

function Service:_concealLocker(record, added)
	local saved = record.locker
	if not saved or saved.character ~= record.character then return end
	local objects = added and { added } or record.character:GetDescendants()
	for _, object in ipairs(objects) do
		local property, value
		if object:IsA("BasePart") or object:IsA("Decal") then property, value = "Transparency", 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("Highlight") then property, value = "Enabled", false end
		if property then
			if not saved.visuals[object] then saved.visuals[object] = { property = property, value = object[property] } end
			object[property] = value
		end
		if object:IsA("BasePart") then
			if saved.parts[object] == nil then saved.parts[object] = object.CanCollide end
			object.CanCollide = false
		end
	end
end

function Service:_enterLocker(record, locker)
	if locker.occupant or record.locker or not alive(record) or record.role ~= "Hider" then return false end
	local saved = { locker = locker, character = record.character, root = record.root, anchored = record.root.Anchored, parts = {}, visuals = {} }
	pcall(function() saved.owner = record.root:GetNetworkOwner() record.root:SetNetworkOwner(nil) end)
	record.locker, locker.occupant = saved, record
	record.sprintHeld, record.batSwing = false, nil
	self:_concealLabels(record)
	self:_concealLocker(record)
	self:_teleport(record, locker.hide.CFrame)
	record.root.Anchored = true
	attribute(record.player, "HSHiding", true)
	attribute(record.player, "HSLockerName", locker.model.Name)
	attribute(record.character, "HSHiding", true)
	self:_movement(record)
	return true
end

function Service:_exitClear(record, locker)
	local direction = locker.exit.Position - locker.hide.Position
	return direction.Magnitude <= 10 and not workspace:Raycast(locker.hide.Position, direction, self:_rayParameters(locker.model))
end

function Service:UseLocker(player, locker)
	local record = self.records[player]
	local now = workspace:GetServerTimeNow()
	if not self.active or (self.phase ~= "Hiding" and self.phase ~= "Seeking") or player.Parent ~= Players
		or not record or not record.participating or not alive(record) or record.frozen or record.ragdoll
		or not locker or self.lockers[locker.model] ~= locker or not locker.door.Parent or not self:_inBounds(record)
		or now - (record.lastLockerAt or -math.huge) < 0.4 then return false end
	record.lastLockerAt = now
	if record.locker then
		if record.locker.locker ~= locker or not self:_exitClear(record, locker) then return false end
		self:_restoreLocker(record, true)
		return true
	end
	local offset = locker.door.Position - record.root.Position
	if offset.Magnitude > 6 or not self:_exitClear(record, locker)
		or workspace:Raycast(record.root.Position, offset, self:_rayParameters(locker.model)) then return false end
	if record.role == "Hider" then return self:_enterLocker(record, locker) end
	if record.role ~= "Seeker" or self.phase ~= "Seeking" or now < (record.batSwingReadyAt or 0) then return false end
	record.batSwingReadyAt = now + 0.75
	attribute(player, "PCBatSwingAt", now)
	attribute(player, "PCBatSwingSerial", (player:GetAttribute("PCBatSwingSerial") or 0) + 1)
	local target = locker.occupant
	if not target then return true end
	if self.records[target.player] ~= target or not alive(target) or not target.participating or target.role ~= "Hider"
		or not target.locker or target.locker.locker ~= locker
		or (target.root.Position - locker.hide.Position).Magnitude > 2 then return false end
	self:_restoreLocker(target, true)
	return self:_convert(target, record, now)
end

function Service:ExitLocker(player)
	local record = self.records[player]
	if not record or not record.locker then return false end
	return self:UseLocker(player, record.locker.locker)
end

function Service:_bindLockers()
	for _, model in ipairs(self.gameplay:WaitForChild("LockerSpots"):GetChildren()) do
		local door, hide, exit = model:FindFirstChild("Door"), model:FindFirstChild("HidePoint"), model:FindFirstChild("ExitPoint")
		local prompt = door and door:FindFirstChild("LockerPrompt")
		if model:IsA("Model") and door and door:IsA("BasePart") and hide and hide:IsA("BasePart")
			and exit and exit:IsA("BasePart") and prompt and prompt:IsA("ProximityPrompt")
			and (hide.Position - door.Position).Magnitude <= 6 and (exit.Position - door.Position).Magnitude <= 8 then
			local locker = { model = model, door = door, hide = hide, exit = exit, prompt = prompt }
			self.lockers[model] = locker
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
			prompt.ActionText, prompt.ObjectText = "Hide / Search / Exit", model:GetAttribute("HSHidingSpotName") or "Locker"
			prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Enabled = 6, false, false
			table.insert(self.connections, prompt.Triggered:Connect(function(player) self:UseLocker(player, locker) end))
		end
	end
	assert(next(self.lockers), "Hide and Seek needs usable lockers")
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
	attribute(saved.character, "HSRagdolled", false)
	attribute(record.player, "HSRagdolled", false)
	attribute(saved.character, "PCPushed", false)
	attribute(record.player, "PCPushed", false)
	if record.character == saved.character and record.participating then self:_movement(record) end
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
	self:_releaseSeat(record)
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
		folder.Name = "HSRagdollConstraints"
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
						firstAttachment.Name = "HSRagdollA0"
						firstAttachment.CFrame = motor:IsA("Motor6D") and motor.C0 * motor.Transform or first.CFrame:ToObjectSpace(motor.Attachment0.WorldCFrame)
						firstAttachment.Parent = first
						table.insert(saved.created, firstAttachment)
						local secondAttachment = Instance.new("Attachment")
						secondAttachment.Name = "HSRagdollA1"
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
		attribute(record.player, "HSRagdolled", true)
		attribute(character, "HSRagdolled", true)
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
		warn("Hide and Seek ragdoll could not start: " .. tostring(failure))
	end
	return ok
end



function Service:TryBatSwing(player)
	local record, now = self.records[player], workspace:GetServerTimeNow()
	if player.Parent ~= Players or not self.active or self.phase ~= "Seeking" or now >= self.endsAt
		or not record or not record.participating or record.role ~= "Seeker" or not alive(record)
		or record.frozen or record.ragdoll or record.locker or not self:_inBounds(record)
		or now < (record.batSwingReadyAt or 0) then return false, "Cannot swing right now" end
	record.batSwingReadyAt = now + 0.75
	record.batSwing = { hitAt = now + 0.10, endsAt = now + 0.38, hit = false, character = record.character, token = self.currentRound }
	sampleBatSwing(record.batSwing, record, self:_batTargets(), now)
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

function Service:_convert(target, seeker, now)
	if not self.active or self.phase ~= "Seeking" or not target.participating or target.role ~= "Hider" then return false end
	self:_restoreLocker(target, true)
	target.sprintHeld, target.batSwing, target.stamina = false, nil, MAX_STAMINA
	target.batSwingReadyAt = now + BAT_RAGDOLL_SECONDS + 0.25
	attribute(target.player, "HSFoundAt", now)
	self:_role(target, "Seeker")
	if alive(target) then self:_ragdoll(target, seeker, now) end
	if seeker then
		seeker.tagsMade = (seeker.tagsMade or 0) + 1
		attribute(seeker.player, "PCBatHitSerial", (seeker.player:GetAttribute("PCBatHitSerial") or 0) + 1)
	end
	self:_publish()
	return true
end

function Service:SetSprint(player, enabled)
	local record, now = self.records[player], workspace:GetServerTimeNow()
	if typeof(enabled) ~= "boolean" or player.Parent ~= Players or not record then return false end
	if enabled and (not self.active or not record.participating or not alive(record) or record.frozen or record.ragdoll or record.locker
		or (self.phase ~= "Hiding" and self.phase ~= "Seeking") or now - (record.lastSprintAt or -math.huge) < 0.04) then return false end
	record.lastSprintAt, record.sprintHeld = now, enabled
	self:_movement(record)
	return true
end

function Service:_restoreCharacter(record)
	self:_clearAbilityEffects(record)
	self:_restoreLocker(record, false)
	self:_restoreRagdoll(record, true)
	self:_restorePropMorph(record)
	self:_restoreLabels(record)
	local saved = record.original
	if saved and record.humanoid and record.humanoid.Parent then
		record.humanoid.WalkSpeed, record.humanoid.JumpPower, record.humanoid.JumpHeight = saved.WalkSpeed, saved.JumpPower, saved.JumpHeight
		record.humanoid.AutoRotate, record.humanoid.PlatformStand = saved.AutoRotate, saved.PlatformStand
	end
	if saved and record.root and record.root.Parent then record.root.Anchored = saved.Anchored end
	record.sprintHeld, record.batSwing = false, nil
	attribute(record.player, "HSSprinting", false)
	attribute(record.player, "HSRagdolled", false)
end

function Service:_bindCharacter(record, character)
	self:_restoreCharacter(record)
	disconnect(record.characterConnections)
	record.character, record.ready = character, false
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if record.character ~= character or not character.Parent or self.records[record.player] ~= record
		or not humanoid or not root or not humanoid:IsA("Humanoid") or not root:IsA("BasePart") then return end
	record.humanoid, record.root, record.ready = humanoid, root, true
	record.original = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight,
		AutoRotate = humanoid.AutoRotate, PlatformStand = humanoid.PlatformStand, Anchored = root.Anchored }
	attribute(character, "HSRole", record.role or "")
	attribute(character, "HSHiding", false)
	attribute(character, "HSRagdolled", false)
	table.insert(record.characterConnections, character.DescendantAdded:Connect(function(object)
		if record.participating and (object:IsA("BillboardGui") or object:IsA("Highlight")) then self:_concealLabels(record) end
		if record.propMorph then self:_concealPropAvatar(record, object) end
		if record.locker then self:_concealLocker(record, object) end
	end))
	table.insert(record.characterConnections, humanoid.Died:Connect(function()
		self:_clearAbilityEffects(record)
		self:_restoreLocker(record, false)
		self:_restoreRagdoll(record, false)
		record.batSwing, record.sprintHeld = nil, false
		if record.participating and record.role == "Hider" then
			if self.phase == "Seeking" then self:_convert(record, nil, workspace:GetServerTimeNow())
			else self:_role(record, "Seeker") self:_publish() end
		end
	end))
	if record.participating and self.active then
		record.frozen = self.phase == "Countdown" or self.phase == "Results" or (self.phase == "Hiding" and record.role == "Seeker")
		record.stamina = MAX_STAMINA
		self:_teleport(record, self:_spawn(record.spawnIndex or 1, record.role == "Seeker"))
		self:_concealLabels(record)
		if record.role == "Hider" and not self:_applyPropMorph(record) then self:_finish(false, true) end
		self:_movement(record)
	end
end

function Service:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, ready = false, participating = false,
		role = "", stamina = MAX_STAMINA, sprintHeld = false }
	self.records[player] = record
	self:_resetAbilities(record)
	attribute(player, "HSLockerName", "")
	for name, value in pairs({ HSParticipating = false, HSRole = "", HSHiding = false, HSRagdolled = false,
		HSPropMorphed = false, HSPropId = "", HSPropName = "", HSSprinting = false, HSStamina = MAX_STAMINA, HSMaxStamina = MAX_STAMINA, HSResult = "" }) do attribute(player, name, value) end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) task.spawn(function() self:_bindCharacter(record, character) end) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if record.character ~= character then return end
		self:_restoreCharacter(record)
		record.ready = false
		if record.participating and record.role == "Hider" then self:_role(record, "Seeker") self:_publish() end
	end))
	if player.Character then task.spawn(function() self:_bindCharacter(record, player.Character) end) end
end

function Service:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	self:_restoreCharacter(record)
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self.records[player] = nil
	self:_publish()
end

function Service:_readyPlayers(selectedPlayers)
	local result, seen = {}, {}
	for _, player in ipairs(selectedPlayers or Players:GetPlayers()) do
		local record = self.records[player]
		if not seen[player] and player.Parent == Players and alive(record) and not record.participating
			and player:GetAttribute("PCDataReady") == true and not player:GetAttribute("PCAFK") and not player:GetAttribute("PCAFKRequested")
			and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating") and not player:GetAttribute("MDParticipating")
			and not player:GetAttribute("DGParticipating") and not player:GetAttribute("DGEliminated") then
			seen[player] = true
			table.insert(result, player)
		end
	end
	for index = #result, 2, -1 do
		local other = self.random:NextInteger(1, index)
		result[index], result[other] = result[other], result[index]
	end
	while #result > math.floor(self:_setting("MaxPlayers", 16, 2, 16)) do table.remove(result) end
	return result
end

function Service:_finish(seekersWon, cancelled)
	if not self.active or self.phase == "Results" then return end
	local winners, winnerIds, participantIds = {}, {}, {}
	for player, record in pairs(self.records) do
		if record.participating and player.Parent == Players then
			self:_restoreLocker(record, true)
			self:_restoreRagdoll(record, true)
			self:_restorePropMorph(record)
			self:_resetAbilities(record)
			record.frozen, record.sprintHeld, record.batSwing = true, false, nil
			local won = not cancelled and ((seekersWon and record.role == "Seeker") or (not seekersWon and record.role == "Hider"))
			attribute(player, "HSResult", cancelled and "Cancelled" or (won and "Won" or "Lost"))
			table.insert(participantIds, player.UserId)
			if won then table.insert(winnerIds, player.UserId) table.insert(winners, player.DisplayName) end
			self:_movement(record)
		end
	end
	table.sort(winnerIds) table.sort(participantIds) table.sort(winners)
	attribute(self.state, "WinnersText", cancelled and "Round cancelled" or (seekersWon and "Everybody found! Seekers win" or "Time's up! Hiders win"))
	attribute(self.state, "WinnerNames", table.concat(winners, ", "))
	attribute(self.state, "WinningRole", cancelled and "" or (seekersWon and "Seeker" or "Hider"))
	attribute(self.state, "LastResultWinnerIds", table.concat(winnerIds, ","))
	attribute(self.state, "LastResultParticipantIds", table.concat(participantIds, ","))
	attribute(self.state, "LastResultPractice", cancelled == true)
	attribute(self.state, "LastResultRound", self.roundNumber)
	self.resultsEndsAt = workspace:GetServerTimeNow() + self:_setting("ResultsSeconds", 7, 0, 15)
	attribute(self.state, "EndsAt", self.resultsEndsAt)
	self:_phase("Results")
	local event = self.state:FindFirstChild("RoundFinished")
	if event and event:IsA("BindableEvent") then event:Fire({ game = "HideAndSeek", roundNumber = self.roundNumber,
		winnerUserIds = winnerIds, participantUserIds = participantIds, practice = cancelled == true }) end
end

function Service:_ensureSeeker()
	local hiders, seekers = self:_publish()
	if seekers > 0 or hiders == 0 then return end
	local options = {}
	for _, record in pairs(self.records) do if record.participating and record.role == "Hider" then table.insert(options, record) end end
	local record = options[self.random:NextInteger(1, #options)]
	self:_restoreLocker(record, true)
	self:_role(record, "Seeker")
	record.frozen = self.phase == "Hiding" or self.phase == "Countdown"
	if alive(record) then self:_teleport(record, self:_spawn(record.spawnIndex or 1, true)) self:_movement(record) end
	self:_publish()
end

function Service:_tick(dt)
	if not self.active then return end
	local now = workspace:GetServerTimeNow()
	if self.phase == "Results" then
		if now >= self.resultsEndsAt then self:_cleanup(self.currentRound) end
		return
	end
	self:_ensureSeeker()
	local hiders, seekers = self:_publish()
	if hiders + seekers < 2 then self:_finish(false, true) return end
	if hiders == 0 and self.phase ~= "Seeking" then self:_finish(false, true) return end
	if self.phase == "Countdown" and now >= self.countdownEndsAt then
		self.hidingEndsAt = now + self:_setting("HideSeconds", 30, 5, 60)
		attribute(self.state, "HidingEndsAt", self.hidingEndsAt)
		attribute(self.state, "EndsAt", self.hidingEndsAt)
		attribute(self.state, "CountdownValue", 0)
		self:_phase("Hiding")
		for _, record in pairs(self.records) do if record.participating then record.frozen = record.role == "Seeker" self:_movement(record) end end
	elseif self.phase == "Countdown" then attribute(self.state, "CountdownValue", math.max(0, math.ceil(self.countdownEndsAt - now))) end
	if self.phase == "Hiding" and now >= self.hidingEndsAt then
		self.endsAt = now + self:_setting("RoundDuration", 300, 30, 600)
		attribute(self.state, "EndsAt", self.endsAt)
		self:_ringSchoolBell()
		self:_phase("Seeking")
		for _, record in pairs(self.records) do if record.participating then record.frozen = false self:_movement(record) end end
	end
	if self.phase ~= "Hiding" and self.phase ~= "Seeking" then return end
	for _, record in pairs(self.records) do
		if record.participating and record.humanoid and record.humanoid.Health <= 0 then
			self:_clearAbilityEffects(record)
			self:_restoreLocker(record, false)
			self:_restoreRagdoll(record, false)
			record.batSwing, record.sprintHeld = nil, false
			if record.role == "Hider" then self:_role(record, "Seeker") end
		elseif record.participating and alive(record) then
			if record.role == "Hider" and (not record.propMorph or record.propMorph.model.Parent ~= record.character) then
				self:_restoreLocker(record, true)
				if not self:_applyPropMorph(record) then self:_finish(false, true) return end
			end
			if record.ragdoll and now >= record.ragdoll.endsAt then self:_restoreRagdoll(record, true) end
			if record.locker and (record.locker.character ~= record.character
				or (record.root.Position - record.locker.locker.hide.Position).Magnitude > 2) then self:_restoreLocker(record, true) end
			if not self:_inBounds(record) and not record.ragdoll then self:_restoreLocker(record, false) self:_teleport(record, self:_spawn(record.spawnIndex or 1, record.role == "Seeker")) end
			local draining = not record.frozen and not record.locker and not record.ragdoll and record.sprintHeld and record.stamina > 0
			record.stamina = math.clamp(record.stamina + (draining and -1 or 1.5) * dt, 0, MAX_STAMINA)
			self:_movement(record)
		end
	end
	if self.phase ~= "Seeking" then return end
	if hiders == 0 then self:_finish(true) return end
	if now >= self.endsAt then self:_finish(false) return end
	local rayParameters = self:_rayParameters()
	for _, seeker in pairs(self.records) do
		local swing = seeker.batSwing
		if swing then
			if swing.hit or swing.character ~= seeker.character or swing.token ~= self.currentRound or now > swing.endsAt + BAT_SAMPLE_MAX_AGE
				or not alive(seeker) or not seeker.participating or seeker.role ~= "Seeker" or seeker.frozen or seeker.ragdoll or not self:_inBounds(seeker) then seeker.batSwing = nil
			else
				local nearest, best
				for _, target in pairs(self.records) do
					if target.participating and target.role == "Hider" and alive(target) and not target.locker and not target.ragdoll and self:_inBounds(target) then
						local hit, distance = batContact(swing, seeker, target, now, self:_setting("TagDistance", 10, 1, 10), rayParameters)
						if hit and (not best or distance < best) then nearest, best = target, distance end
					end
				end
				local nearestDecoy
				for _, decoy in pairs(self.decoys) do
					local owner = decoy.owner
					if decoy.character.Parent and decoy.root.Parent and decoy.token == self.currentRound
						and self.records[owner.player] == owner and owner.participating and owner.role == "Hider" and alive(owner) then
						local hit, distance = batContact(swing, seeker, decoy, now, self:_setting("TagDistance", 10, 1, 10), rayParameters)
						if hit and (not best or distance < best) then nearest, nearestDecoy, best = nil, decoy, distance end
					end
				end
				if nearestDecoy then swing.hit = self:_hitDecoy(nearestDecoy, seeker, now)
				elseif nearest then swing.hit = true self:_convert(nearest, seeker, now) end
				sampleBatSwing(swing, seeker, self:_batTargets(), now)
			end
		end
	end
	if self:_publish() == 0 then self:_finish(true) end
end

function Service:_begin(participants)
	self.active, self.mode, self.currentRound = true, "Round", {}
	self.roundNumber += 1
	self.endsAt, self.hidingEndsAt = 0, 0
	attribute(self.state, "Mode", "Round")
	attribute(self.state, "RoundNumber", self.roundNumber)
	attribute(self.state, "WinnersText", "")
	attribute(self.state, "WinningRole", "")
	attribute(self.state, "HidingEndsAt", 0)
	attribute(self.state, "RoundDuration", self:_setting("RoundDuration", 300, 30, 600))
	local firstSeeker = participants[self.random:NextInteger(1, #participants)]
	self.countdownEndsAt = workspace:GetServerTimeNow() + self:_setting("CountdownSeconds", 3, 1, 10)
	attribute(self.state, "EndsAt", self.countdownEndsAt)
	self:_phase("Countdown")
	for index, player in ipairs(participants) do
		local record = self.records[player]
		self:_resetAbilities(record)
		record.participating, record.spawnIndex, record.frozen = true, index, true
		record.stamina, record.sprintHeld, record.tagsMade = MAX_STAMINA, false, 0
		record.batSwingReadyAt, record.lastLockerAt, record.lastSprintAt = 0, -math.huge, -math.huge
		attribute(player, "HSResult", "")
		self:_role(record, player == firstSeeker and "Seeker" or "Hider")
		self:_teleport(record, self:_spawn(index, player == firstSeeker))
		if record.role == "Hider" then assert(self:_applyPropMorph(record), "No usable school prop morphs are available") end
	end
	self:_publish()
	return true
end

function Service:StartRound(selectedPlayers)
	if not self.running then return false, "Service is not running" end
	if self.active then return false, "A round is already running" end
	local participants = self:_readyPlayers(selectedPlayers)
	if #participants < self:_setting("MinimumPlayers", 2, 2, 16) then return false, "Not enough ready players" end
	local ok, result = xpcall(function() return self:_begin(participants) end, debug.traceback)
	if not ok then self:_cleanup() warn("Hide and Seek could not start: " .. tostring(result)) return false, "The school could not prepare the round" end
	return result
end

function Service:_cleanup(token)
	if token and token ~= self.currentRound then return end
	if self.schoolBell and self.schoolBell.Parent then self.schoolBell:Stop() end
	for _, record in pairs(self.records) do
		if record.participating then
			self:_resetAbilities(record)
			self:_restoreCharacter(record)
			record.participating, record.frozen, record.role = false, false, ""
			attribute(record.player, "HSParticipating", false)
			attribute(record.player, "HSRole", "")
			if record.character then attribute(record.character, "HSRole", "") end
			if self.lobbySpawn and self.lobbySpawn.Parent and alive(record) then self:_teleport(record, self.lobbySpawn.CFrame + Vector3.new(0, self.lobbySpawn.Size.Y * 0.5 + 3, 0)) end
		end
	end
	for _, decoy in pairs(self.decoys) do self:_removeDecoy(decoy) end
	if self.decoyFolder then self.decoyFolder:Destroy() self.decoyFolder = nil end
	for _, locker in pairs(self.lockers) do locker.occupant = nil end
	self.active, self.currentRound, self.mode, self.endsAt, self.hidingEndsAt = false, nil, "Waiting", 0, 0
	attribute(self.state, "Mode", "Waiting")
	attribute(self.state, "EndsAt", 0)
	attribute(self.state, "HidingEndsAt", 0)
	attribute(self.state, "CountdownValue", 0)
	self:_phase("Waiting")
	self:_publish()
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
	self:_bindLockers()
	for name, value in pairs({ Phase = "Waiting", Mode = "Waiting", EndsAt = 0, HidingEndsAt = 0, CountdownValue = 0,
		RoundNumber = 0, RoundDuration = self:_setting("RoundDuration", 300, 30, 600), HideSeconds = self:_setting("HideSeconds", 30, 5, 60),
		ParticipantCount = 0, SeekerCount = 0, HiderCount = 0, SeekerUserIds = "", WinnersText = "", WinningRole = "",
		LastResultWinnerIds = "", LastResultParticipantIds = "", LastResultPractice = true, LastResultRound = 0,
		MinimumPlayers = self:_setting("MinimumPlayers", 2, 2, 16), MaxPlayers = self:_setting("MaxPlayers", 16, 2, 16) }) do attribute(self.state, name, value) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.tickAccumulator += dt
		if self.tickAccumulator < 0.05 then return end
		local elapsed = math.min(self.tickAccumulator, 0.15)
		self.tickAccumulator = 0
		local ok, failure = xpcall(function() self:_tick(elapsed) end, debug.traceback)
		if not ok then warn("Hide and Seek round failed: " .. tostring(failure)) self:_cleanup() end
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	local remote = ReplicatedStorage:FindFirstChild("HideAndSeekSprintRequest")
	assert(remote and remote:IsA("RemoteEvent"), "Hide and Seek sprint remote is missing")
	table.insert(self.connections, remote.OnServerEvent:Connect(function(player, enabled) self:SetSprint(player, enabled) end))
	local lockerRemote = ReplicatedStorage:FindFirstChild("HideAndSeekActionRequest")
	assert(lockerRemote and lockerRemote:IsA("RemoteEvent"), "Hide and Seek locker remote is missing")
	table.insert(self.connections, lockerRemote.OnServerEvent:Connect(function(player, action)
		self:HandleAction(player, action)
	end))
	return self
end

function Service:Stop()
	self.running = false
	self:_cleanup()
	disconnect(self.connections)
	for _, record in pairs(self.records) do disconnect(record.connections) disconnect(record.characterConnections) end
	table.clear(self.records)
	table.clear(self.lockers)
	if runningService == self then runningService = nil end
end

function Service.GetRunningService() return runningService end
return Service
]======] .. "\nend"
module.Parent = realStorage
local bellCalls = { play = 0, stop = 0 }
local fakeBell = { Parent = true, TimePosition = 0 }
function fakeBell:Play() bellCalls.play += 1 end
function fakeBell:Stop() bellCalls.stop += 1 end
local service
local function character(owner)
	local model = Instance.new("Model") model.Name, model.Parent = owner.Name, container
	local root = part(model, "HumanoidRootPart", origin + Vector3.new(0, 3, 0), Vector3.new(2, 2, 1)) root.Anchored = false
	local torso = part(model, "Torso", root.Position, Vector3.new(2, 2, 1)) torso.Anchored = false
	local head = part(model, "Head", root.Position + Vector3.new(0, 1.5, 0), Vector3.new(2, 1, 1)) head.Anchored = false
	for index, limb in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local body = part(model, limb, root.Position + Vector3.new(index % 2 == 0 and 1.5 or -1.5, index > 2 and -2 or 0, 0), Vector3.new(1, 2, 1)) body.Anchored = false
		local joint = Instance.new("Motor6D") joint.Name, joint.Part0, joint.Part1, joint.Parent = limb, torso, body, torso
		joint.C0 = CFrame.new(body.Position - torso.Position)
	end
	local neck = Instance.new("Motor6D") neck.Name, neck.Part0, neck.Part1, neck.C0, neck.Parent = "Neck", torso, head, CFrame.new(0, 1.5, 0), torso
	local rootMotor = Instance.new("Motor6D") rootMotor.Name, rootMotor.Part0, rootMotor.Part1, rootMotor.Parent = "RootJoint", root, torso, root
	local humanoid = Instance.new("Humanoid") humanoid.RequiresNeck = false humanoid.Parent = model
	local accessory = Instance.new("Accessory") accessory.Name, accessory.Parent = "PermissionHat", model
	local handle = part(accessory, "Handle", root.Position, Vector3.one)
	local audio = Instance.new("AudioEmitter") audio.Parent = root
	local tag = Instance.new("BillboardGui") tag.Name, tag.Enabled, tag.Parent = "VIPNameplate", true, head
	local outline = Instance.new("Highlight") outline.DepthMode, outline.Enabled, outline.Parent = Enum.HighlightDepthMode.AlwaysOnTop, true, model
	model.PrimaryPart = root
	owner.Character = model
	return model, humanoid, root, tag, outline
end
local function add(index)
	local owner = player(index)
	table.insert(players, owner)
	local model, humanoid, root, tag, outline = character(owner)
	local record = { player = owner, connections = {}, characterConnections = {}, ready = false, participating = false,
		role = "", stamina = 10, sprintHeld = false }
	service.records[owner] = record
	service:_bindCharacter(record, model)
	return owner, record, tag, outline
end
local function seeking(list)
	service:StopRound()
	check("Round accepts eligible connected players", service:StartRound(list))
	check("Countdown starts", service.phase == "Countdown")
	now += 3 service:_tick(0.05)
	check("Countdown becomes hiding", service.phase == "Hiding")
	local seeker, hiders = nil, {}
	for _, owner in ipairs(list) do local record = service.records[owner] if record.role == "Seeker" then seeker = record else table.insert(hiders, record) end end
	check("One initial seeker", seeker ~= nil and state:GetAttribute("SeekerCount") == 1)
	check("Seeker frozen while hiders move", seeker.frozen == true and hiders[1].frozen == false)
	check("Seeker physically held during hiding", seeker.root.Anchored and not hiders[1].root.Anchored)
	check("No early swing during hiding", service:TryBatSwing(seeker.player) == false)
	local beforeRelease = bellCalls.play
	check("Hiding grace is exactly 30 seconds", math.abs(service.hidingEndsAt - now - 30) < 0.001)
	now += 29.9 service:_tick(0.05)
	check("Seekers remain held before thirty seconds", service.phase == "Hiding" and seeker.frozen and seeker.root.Anchored)
	check("Bell is silent before release", bellCalls.play == beforeRelease)
	now += 0.1 service:_tick(0.05)
	check("Bell rings once at seeker release", bellCalls.play == beforeRelease + 1 and fakeBell.TimePosition == 0)
	service:_tick(0.05)
	check("Heartbeat does not replay bell", bellCalls.play == beforeRelease + 1)
	check("Hiding becomes seeking", service.phase == "Seeking" and not seeker.frozen)
	check("Seeker releases for hunting", not seeker.root.Anchored)
	check("Search lasts exactly five minutes", math.abs(service.endsAt - now - 300) < 0.001)
	return seeker, hiders
end
local ok, failure = xpcall(function()
	local Service = require(module)(env)
	service = Service.new(arena, state)
	service.schoolBell = fakeBell
	service:Start()
	check("Only suitable tagged props are eligible", #service:_propTemplates() == 2)
	check("Storage displays correct kind", prompt.ObjectText == "Wardrobe")
	local a, ar, atag, aoutline = add(1)
	local b, br = add(2)
	local c, cr = add(3)
	local originals = {}
	for _, record in pairs(service.records) do
		record.character.Head.Transparency = 0.17
		local face = Instance.new("Decal") face.Transparency, face.Parent = 0.23, record.character.Head
		local effect = Instance.new("ParticleEmitter") effect.Enabled, effect.Parent = true, record.character.Head
		local original = {}
		for _, object in ipairs(record.character:GetDescendants()) do
			if object:IsA("BasePart") then original[object] = { Transparency = object.Transparency, CanCollide = object.CanCollide, Size = object.Size, Massless = object.Massless }
			elseif object:IsA("Decal") then original[object] = { Transparency = object.Transparency }
			elseif object:IsA("ParticleEmitter") or object:IsA("Highlight") or object:IsA("BillboardGui") then original[object] = { Enabled = object.Enabled } end
		end
		originals[record] = original
	end
	local function restored(record)
		for object, properties in pairs(originals[record] or {}) do
			if object.Parent then for key, value in pairs(properties) do if object[key] ~= value then return false, object.Name .. "." .. key end end end
		end
		return not record.propMorph and not record.player:GetAttribute("HSPropMorphed")
	end
	local function morphed(record)
		if not record.propMorph or not record.player:GetAttribute("HSPropMorphed") then return false end
		for object in pairs(originals[record] or {}) do
			if object:IsA("BasePart") or object:IsA("Decal") then if object.Transparency ~= 1 then return false end
			elseif object:IsA("ParticleEmitter") or object:IsA("Highlight") or object:IsA("BillboardGui") then if object.Enabled then return false end end
		end
		return true
	end
	local seeker, hiders = seeking({ a, b, c })
	local hider, other = hiders[1], hiders[2]
	check("School sprint capacity is twenty-five seconds", hider.player:GetAttribute("HSMaxStamina") == 25 and seeker.player:GetAttribute("HSMaxStamina") == 25)
	hider.stamina = 25
	check("Hider can begin sprinting", service:SetSprint(hider.player, true))
	now += 1
	service:_tick(1)
	check("One sprint second uses one of twenty-five seconds", math.abs(hider.stamina - 24) < 0.001 and hider.humanoid.WalkSpeed == 26)
	hider.stamina = 0.1
	service:_tick(0.05)
	check("School can sprint from a partially recharged bar", hider.stamina > 0 and hider.stamina < 0.1 and hider.humanoid.WalkSpeed == 26)
	hider.stamina = 0
	service:_movement(hider)
	check("School empty stamina stops sprinting", hider.humanoid.WalkSpeed == 16 and not hider.player:GetAttribute("HSSprinting"))
	service:_tick(0.05)
	check("First positive recharge immediately resumes school sprint", hider.stamina > 0 and hider.stamina < 0.1 and hider.humanoid.WalkSpeed == 26 and hider.player:GetAttribute("HSSprinting"))
	check("School sprint releases without a recharge gate", service:SetSprint(hider.player, false))
	service:_tick(30)
	check("School refill caps at twenty-five", hider.stamina == 25 and hider.humanoid.WalkSpeed == 16)
	check("Only hiders receive random prop morphs", morphed(hider) and morphed(other) and not seeker.propMorph)
	check("Prop identity is replicated on player and character", hider.player:GetAttribute("HSPropId") ~= "" and hider.character:GetAttribute("HSPropId") == hider.player:GetAttribute("HSPropId"))
	check("Bat reach remains ten studs", service:_setting("TagDistance", 10) == 10)

	check("Locker interaction uses F and controller X", prompt.KeyboardKeyCode == Enum.KeyCode.F and prompt.GamepadKeyCode == Enum.KeyCode.ButtonX)
	check("Wrong roles cannot use other side abilities", not service:Scan(hider.player) and not service:ChangeProp(seeker.player) and not service:DropDecoy(seeker.player))
	check("Unknown and malformed actions are rejected", not service:HandleAction(hider.player, {}) and not service:HandleAction(hider.player, "Admin"))
	local abilityStart = now
	local oldProp = hider.player:GetAttribute("HSPropId")
	check("Hider switches object", service:ChangeProp(hider.player))
	check("Switch chooses a different eligible object", hider.player:GetAttribute("HSPropId") ~= oldProp)
	check("Switch replicates its three second cooldown", hider.player:GetAttribute("HSSwitchReadyAt") == now + 3)
	check("Switch cannot spam", not service:ChangeProp(hider.player))
	now += 3
	check("Switch reusable after cooldown", service:ChangeProp(hider.player))
	service:_teleport(hider, CFrame.new(origin + Vector3.new(0, 3, -9.9)))
	service:_teleport(other, CFrame.new(origin + Vector3.new(50, 3, 0)))
	check("Hider places grounded decoy", service:DropDecoy(hider.player))
	local firstDecoy = hider.decoys[1]
	check("Decoy is exact current prop identity", firstDecoy.character:GetAttribute("HSPropId") == hider.player:GetAttribute("HSPropId"))
	check("Decoy preserves visible object size", firstDecoy.character.PropBody.Size == hider.propMorph.model.PropBody.Size)
	check("Decoy has cartoon outline", firstDecoy.character.SchoolPropOutline.Enabled and firstDecoy.character.SchoolPropOutline.Adornee == firstDecoy.character)
	for _, child in ipairs(firstDecoy.character:GetDescendants()) do
		if child:IsA("BasePart") then check("Decoy parts cannot obstruct map", child.Anchored and not child.CanCollide and not child.CanTouch and not child.CanQuery) end
		check("Decoy has no avatar weld", not child:IsA("WeldConstraint"))
	end
	check("Decoy cannot spam", not service:DropDecoy(hider.player))
	check("Decoy counter replicates", hider.player:GetAttribute("HSDecoyCount") == 1 and hider.player:GetAttribute("HSDecoyReadyAt") == now + 10)
	service:_teleport(hider, CFrame.new(origin + Vector3.new(40, 3, 0)))
	service:_teleport(seeker, CFrame.lookAt(origin + Vector3.new(0, 3, 0), origin + Vector3.new(0, 3, -10)))
	local tagsBefore = seeker.tagsMade or 0
	local wall = part(container, "DecoyWall", origin + Vector3.new(0, 3, -5), Vector3.new(12, 10, 0.5), true)
	now += 1
	check("Swing can target decoy", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Wall protects decoy against through-wall hits", firstDecoy.character.Parent ~= nil and hider.player:GetAttribute("HSRevealedUntil") == 0)
	wall:Destroy()
	now += 1
	check("Decoy swing after cooldown", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Ten-stud bat hits stationary decoy", firstDecoy.character.Parent == nil and hider.player:GetAttribute("HSDecoyCount") == 0)
	check("Decoy hit reveals owner for five seconds", hider.player:GetAttribute("HSRevealedUntil") == now + 5 and hider.player:GetAttribute("HSRevealReason") == "Decoy")
	check("Decoy never converts or rewards tag", hider.role == "Hider" and (seeker.tagsMade or 0) == tagsBefore)
	check("Decoy hit consumes bat swing", seeker.batSwing.hit)
	now += 10
	service:_teleport(hider, CFrame.new(origin + Vector3.new(0,3,7)))
	check("Behind decoy placed", service:DropDecoy(hider.player))
	local behind = hider.decoys[1]
	service:_teleport(hider, CFrame.new(origin + Vector3.new(40,3,0)))
	check("Behind-facing swing starts", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Swing does not hit behind player", behind.character.Parent ~= nil)
	for index = 1, 3 do
		now += 10
		service:_teleport(hider, CFrame.new(origin + Vector3.new(15 + index * 5,3,20)))
		check("Repeated decoy after cooldown " .. index, service:DropDecoy(hider.player))
	end
	check("Fourth placement replaces oldest; at most three active", #hider.decoys == 3 and hider.player:GetAttribute("HSDecoyCount") == 3 and behind.character.Parent == nil)
	service:_teleport(hider, CFrame.new(origin + Vector3.new(20,3,-6)))
	now += 1
	check("Decoy owner can hide in wardrobe", service:UseLocker(hider.player, service.lockers[lockerModel]))
	check("Locker name is replicated for scan visual", hider.player:GetAttribute("HSLockerName") == lockerModel.Name)
	check("No object switch or decoy while inside wardrobe", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player))
	check("Seeker scan starts", service:Scan(seeker.player))
	local scanAt = now
	check("Scan duration is ten seconds then sixty cooldown", seeker.player:GetAttribute("HSScanActiveUntil") == scanAt + 10 and seeker.player:GetAttribute("HSScanReadyAt") == scanAt + 70)
	check("Scan reveals both world and locker hiders", hider.player:GetAttribute("HSRevealedUntil") == scanAt + 10 and other.player:GetAttribute("HSRevealedUntil") == scanAt + 10)
	check("Scan reason and source replicate", hider.player:GetAttribute("HSRevealReason") == "Scan" and hider.player:GetAttribute("HSRevealSource") == seeker.player.UserId)
	check("Scan cannot spam", not service:Scan(seeker.player))
	service:_reveal(hider, now + 5, "Decoy", seeker)
	check("Shorter decoy reveal cannot truncate scan", hider.player:GetAttribute("HSRevealedUntil") == scanAt + 10)
	now += 1
	check("Leaving wardrobe clears scanner locker target", service:ExitLocker(hider.player) and hider.player:GetAttribute("HSLockerName") == "")
	check("Switching objects cannot evade reveal", service:ChangeProp(hider.player) and hider.player:GetAttribute("HSRevealedUntil") == scanAt + 10)
	now = scanAt + 10
	check("Active scan expires after ten", seeker.player:GetAttribute("HSScanActiveUntil") <= now)
	check("Cooldown begins after active phase", not service:Scan(seeker.player))
	now = scanAt + 69.99
	check("Cannot rescan before full minute cooldown", not service:Scan(seeker.player))
	now = scanAt + 70
	check("Scan reusable exactly after cooldown", service:Scan(seeker.player))
	local savedCooldown = seeker.scanReadyAt
	service:_restoreCharacter(seeker)
	check("Character cleanup preserves scan cooldown against respawn abuse", seeker.scanReadyAt == savedCooldown and seeker.player:GetAttribute("HSScanReadyAt") == savedCooldown)
	service:_clearAbilityEffects(hider)
	check("Owner cleanup removes all decoys and reveal", #hider.decoys == 0 and hider.player:GetAttribute("HSDecoyCount") == 0 and hider.player:GetAttribute("HSRevealedUntil") == 0)
	check("Owner cleanup leaves no decoy instances", next(service.decoys) == nil)
	for _, record in pairs(service.records) do service:_resetAbilities(record) end
	now += 4
	service:_teleport(hider, CFrame.new(origin + Vector3.new(0,3,0)))
	service:_teleport(other, CFrame.new(origin + Vector3.new(30,3,0)))
	service:_teleport(seeker, CFrame.new(origin + Vector3.new(-30,3,0)))
	local oldPhase = service.phase
	service.phase = "Countdown"
	check("Abilities forbidden during countdown", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player) and not service:Scan(seeker.player))
	service.phase = "Results"
	check("Abilities forbidden during results", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player) and not service:Scan(seeker.player))
	service.phase = oldPhase
	hider.frozen = true
	check("Frozen hider cannot use abilities", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player))
	hider.frozen = false
	hider.ragdoll = {}
	check("Ragdolled hider cannot use abilities", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player))
	hider.ragdoll = nil
	service:_teleport(hider, CFrame.new(origin + Vector3.new(0, 30, 0)))
	check("Airborne hider cannot leave floating decoy", not service:DropDecoy(hider.player))
	service:_teleport(hider, CFrame.new(origin + Vector3.new(1000,3,0)))
	check("Out of bounds hider cannot use abilities", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player))
	service:_teleport(hider, CFrame.new(origin + Vector3.new(0,3,0)))
	hider.participating = false
	check("Nonparticipants cannot use abilities", not service:ChangeProp(hider.player) and not service:DropDecoy(hider.player))
	hider.participating = true
	check("Hider keeps decoy until conversion", service:DropDecoy(hider.player))
	local conversionDecoy = hider.decoys[1]
	local model = hider.propMorph.model
	local box, size = model:GetBoundingBox()
	local floor = hider.root.Position.Y - hider.humanoid.HipHeight - hider.root.Size.Y * 0.5 - hider.character["Left Leg"].Size.Y
	check("Prop bottom rests at avatar feet", math.abs(box.Position.Y - size.Y * 0.5 - floor) < 0.001)
	check("Morph retains template scale", size == Vector3.new(3, 4, 3))
	local outline = model:FindFirstChild("SchoolPropOutline")
	check("Morph has black occluded outline", outline and outline.Enabled and outline.OutlineColor == Color3.new(0,0,0) and outline.DepthMode == Enum.HighlightDepthMode.Occluded and outline.FillTransparency == 1)
	for object, values in pairs(originals[hider]) do
		if object:IsA("BasePart") then check("Avatar collider and rig size remain unchanged: " .. object.Name, object.CanCollide == values.CanCollide and object.Size == values.Size and object.Massless == values.Massless) end
	end
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then check("Visible prop is massless welded decoration", not object.Anchored and object.Massless and not object.CanCollide and not object.CanTouch and not object.CanQuery and object.SchoolPropWeld.Part0 == hider.root) end
	end
	local late = Instance.new("Part")
	late.Name, late.Transparency, late.CanCollide = "LateHat", 0.34, false
	late.Parent = hider.character
	local lateSpark = Instance.new("Sparkles") lateSpark.Enabled, lateSpark.Parent = true, late
	task.wait()
	check("Late avatar accessories and sparkles stay concealed", late.Transparency == 1 and not lateSpark.Enabled)
	local locker = service.lockers[lockerModel]
	service:_teleport(hider, CFrame.new(origin + Vector3.new(20,3,-6)))
	now += 1
	check("Morphed hider can enter wardrobe", service:UseLocker(hider.player, locker))
	check("Wardrobe conceals prop and outline", model.PropBody.Transparency == 1 and not outline.Enabled and hider.root.Anchored)
	now += 1
	check("Hider can leave wardrobe", service:ExitLocker(hider.player))
	check("Leaving wardrobe reveals prop only", model.PropBody.Transparency == 0 and outline.Enabled and morphed(hider) and not hider.root.Anchored)
	now += 1
	check("Wardrobe can be occupied again", service:UseLocker(hider.player, locker))
	service:_teleport(seeker, CFrame.new(origin + Vector3.new(20,3,-6)))
	now += 1
	check("Seeker can find and convert wardrobe occupant", service:UseLocker(seeker.player, locker))
	check("Conversion clears decoy and reveal", conversionDecoy.character.Parent == nil and hider.player:GetAttribute("HSDecoyCount") == 0 and hider.player:GetAttribute("HSRevealedUntil") == 0)
	check("Conversion removes prop before ragdoll", hider.role == "Seeker" and not hider.propMorph and model.Parent == nil and not hider.player:GetAttribute("HSPropMorphed"))
	check("Conversion restores avatar face and late accessory", math.abs(hider.character.Head.Transparency - 0.17) < 0.0001 and math.abs(late.Transparency - 0.34) < 0.0001 and lateSpark.Enabled)
	now += 1.36 service:_tick(0.05)
	check("Converted seeker recovers normally", not hider.ragdoll and hider.humanoid.WalkSpeed == 18)
	service:_teleport(seeker, CFrame.lookAt(origin + Vector3.new(0,3,0), origin + Vector3.new(0,3,-10)))
	service:_teleport(other, CFrame.new(origin + Vector3.new(0,3,-9.9)))
	local wall = part(container, "PropBatWall", origin + Vector3.new(0,3,-5), Vector3.new(15,10,0.5), true)
	now += 1
	check("Seeker can swing at a prop", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Prop cannot be tagged through walls", other.role == "Hider" and other.propMorph ~= nil)
	wall:Destroy()
	now += 1
	check("Seeker can swing again after cooldown", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Prop tags at 9.9 studs convert and reveal avatar", other.role == "Seeker" and not other.propMorph and not other.player:GetAttribute("HSPropMorphed"))
	service:StopRound()
	check("Admin stop restores all originals", restored(ar) and restored(br) and restored(cr))
	check("Admin stop clears hiding flags", not a:GetAttribute("HSParticipating") and not b:GetAttribute("HSParticipating") and not c:GetAttribute("HSParticipating"))
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	local lost = hider.propMorph.model
	lost:Destroy()
	service:_tick(0.05)
	check("Missing morph is repaired instead of invisible hider", hider.propMorph and hider.propMorph.model.Parent == hider.character and morphed(hider))
	local originalCharacter = hider.character
	hider.player.CharacterRemoving:Fire(originalCharacter)
	service:_restoreCharacter(hider)
	hider.ready = false
	service:_role(hider, "Seeker")
	service:_bindCharacter(hider, character(hider.player))
	check("Respawn returns visible seeker with no stale morph", hider.ready and hider.role == "Seeker" and not hider.propMorph and hider.character.Head.Transparency == 0)
	service:StopRound()
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	check("Decoy may exist before owner death", service:DropDecoy(hider.player))
	local deathDecoy = hider.decoys[1]
	service:_reveal(hider, now + 10, "Scan", seeker)
	hider.humanoid.Health = 0
	task.wait()
	service:_tick(0.05)
	check("Death removes owner decoys and reveal", deathDecoy.character.Parent == nil and hider.player:GetAttribute("HSDecoyCount") == 0 and hider.player:GetAttribute("HSRevealedUntil") == 0)
	check("Death cleans prop and converts hider", not hider.propMorph and hider.role == "Seeker" and not hider.player:GetAttribute("HSPropMorphed"))
	service:StopRound()
	service:_bindCharacter(hider, character(hider.player))
	seeker, hiders = seeking({a,b,c})
	check("Decoy may exist at round end", service:DropDecoy(hiders[1].player))
	local endDecoy = hiders[1].decoys[1]
	now = service.endsAt
	service:_tick(0.05)
	check("Five minute timeout awards surviving hiders", service.phase == "Results" and state:GetAttribute("WinningRole") == "Hider")
	check("Results clear every decoy immediately", endDecoy.character.Parent == nil and next(service.decoys) == nil)
	check("Results reveal avatars and remove all props", not hiders[1].propMorph and not hiders[2].propMorph)
	service:StopRound()
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	check("Decoy may exist before owner leaves", service:DropDecoy(hider.player))
	local leaveDecoy = hider.decoys[1]
	service:_removePlayer(hider.player)
	check("Leaving removes decoys immediately", leaveDecoy.character.Parent == nil and next(service.decoys) == nil and service.records[hider.player] == nil)
	service:_addPlayer(hider.player)
	task.wait()
	service:StopRound()
	local entries = templates:GetChildren()
	for _, item in ipairs(entries) do item:SetAttribute("HSPropEligible", false) end
	check("Unavailable props cancel startup rather than invisible play", not service:StartRound({a,b,c}) and not service.active and service.phase == "Waiting")
	check("Failed start restores all participant flags", not a:GetAttribute("HSParticipating") and not b:GetAttribute("HSParticipating") and not c:GetAttribute("HSParticipating"))
	for _, item in ipairs(entries) do if item == usableTemplate then item:SetAttribute("HSPropEligible", true) end end
	usableTemplate.Archivable = false
	check("Clone failure cancels the prepared round safely", not service:StartRound({a,b,c}) and not service.active and service.phase == "Waiting")
	check("Clone failure leaves no hidden avatars", not a:GetAttribute("HSPropMorphed") and not b:GetAttribute("HSPropMorphed") and not c:GetAttribute("HSPropMorphed"))
	usableTemplate.Archivable = true
	seeker, hiders = seeking({a,b,c})
	hider = hiders[1]
	usableTemplate:SetAttribute("HSPropEligible", false)
	hider.propMorph.model:Destroy()
	service:_tick(0.05)
	check("Unrecoverable morph loss cancels rewards", service.phase == "Results" and state:GetAttribute("LastResultPractice") == true and state:GetAttribute("LastResultWinnerIds") == "")
	service:Stop()
	check("Shutdown clears service and no props remain", not service.running and next(service.records) == nil and not container:FindFirstChild("SchoolPropMorph", true))
end, debug.traceback)
if not ok then table.insert(report.errors, failure) end
pcall(function() if service then service:Stop() end end)
container:Destroy()
module:Destroy()
report.passed = ok
report.checkCount = #report.checks
return game:GetService("HttpService"):JSONEncode(report)


