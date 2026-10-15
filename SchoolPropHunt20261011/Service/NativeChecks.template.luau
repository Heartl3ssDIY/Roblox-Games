assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local realWorkspace = workspace
local realStorage = game:GetService("ServerStorage")
local container = Instance.new("Folder")
container.Name = "PropHuntServiceNativeChecks20261011"
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
module.Source = "return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\n" .. [======[__SERVICE_SOURCE__]======] .. "\nend"
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
	hider.humanoid.Health = 0
	task.wait()
	service:_tick(0.05)
	check("Death cleans prop and converts hider", not hider.propMorph and hider.role == "Seeker" and not hider.player:GetAttribute("HSPropMorphed"))
	service:StopRound()
	service:_bindCharacter(hider, character(hider.player))
	seeker, hiders = seeking({a,b,c})
	now = service.endsAt
	service:_tick(0.05)
	check("Five minute timeout awards surviving hiders", service.phase == "Results" and state:GetAttribute("WinningRole") == "Hider")
	check("Results reveal avatars and remove all props", not hiders[1].propMorph and not hiders[2].propMorph)
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
