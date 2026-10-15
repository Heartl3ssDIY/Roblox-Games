assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local realWorkspace = workspace
local realStorage = game:GetService("ServerStorage")
local container = Instance.new("Folder")
container.Name = "HideSeekServiceNativeChecks20261010"
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
for name, value in pairs({ FloorY = origin.Y, MinimumPlayers = 2, MaxPlayers = 16, RoundDuration = 180,
	HideSeconds = 20, CountdownSeconds = 3, ResultsSeconds = 7, BaseSpeed = 16, SeekerSpeed = 18, TagDistance = 10 }) do arena:SetAttribute(name, value) end
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
local remote = { OnServerEvent = signal(), IsA = function(_, class) return class == "RemoteEvent" end }
services.Players = playersService
services.RunService = { Heartbeat = signal() }
services.ReplicatedStorage = { FindFirstChild = function(_, name) if name == "HideAndSeekState" then return state elseif name == "HideAndSeekSprintRequest" or name == "HideAndSeekActionRequest" then return remote end end }
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
module.Capabilities = game.ServerScriptService.TagService.Capabilities:Add(SecurityCapabilities.new(Enum.SecurityCapability.Input))
module.Source = "return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\n" .. [======[__SERVICE_SOURCE__]======] .. "\nend"
module.Parent = realStorage
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
	now += 20 service:_tick(0.05)
	check("Hiding becomes seeking", service.phase == "Seeking" and not seeker.frozen)
	check("Seeker releases for hunting", not seeker.root.Anchored)
	check("Search lasts exactly three minutes", math.abs(service.endsAt - now - 180) < 0.001)
	return seeker, hiders
end
local ok, failure = xpcall(function()
	local Service = require(module)(env)
	service = Service.new(arena, state)
	service:Start()
	local a, ar, atag, aoutline = add(1)
	local b, br = add(2)
	local c, cr = add(3)
	check("No round with only one player", service:StartRound({ a }) == false)
	b:SetAttribute("PCAFK", true)
	check("AFK players excluded", #service:_readyPlayers({ a, b }) == 1)
	b:SetAttribute("PCAFK", false) b:SetAttribute("PCDataReady", false)
	check("Unloaded profiles excluded", #service:_readyPlayers({ a, b }) == 1)
	b:SetAttribute("PCDataReady", true) b:SetAttribute("MDParticipating", true)
	check("Other game participants excluded", #service:_readyPlayers({ a, b }) == 1)
	b:SetAttribute("MDParticipating", false)
	check("Duplicate selected players excluded", #service:_readyPlayers({ a, a, b }) == 2)
	local seeker, hiders = seeking({ a, b, c })
	check("All participants marked", a:GetAttribute("HSParticipating") and b:GetAttribute("HSParticipating") and c:GetAttribute("HSParticipating"))
	check("Humanoid name and health concealed", ar.humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None and ar.humanoid.HealthDisplayType == Enum.HumanoidHealthDisplayType.AlwaysOff)
	check("VIP tags concealed", not atag.Enabled)
	check("No hider through-wall outline", ar.role == "Seeker" or not aoutline.Enabled)
	local extraTag = Instance.new("BillboardGui") extraTag.Enabled = true extraTag.Parent = ar.character
	task.wait()
	check("New nameplates concealed mid-round", extraTag.Enabled == false)
	check("Seeker outlines occluded", aoutline.DepthMode == Enum.HighlightDepthMode.Occluded)
	check("Sprint begins", service:SetSprint(hiders[1].player, true) and hiders[1].humanoid.WalkSpeed == 26)
	service:_tick(1)
	check("Sprint consumes stamina", hiders[1].stamina == 9)
	hiders[1].stamina = 0 service:_tick(0.05)
	check("Any regenerated stamina resumes held sprint", hiders[1].stamina > 0 and hiders[1].player:GetAttribute("HSSprinting"))
	check("Sprint release always accepted", service:SetSprint(hiders[1].player, false))
	check("Invalid sprint payload rejected", not service:SetSprint(hiders[1].player, "yes"))
	local locker = service.lockers[lockerModel]
	service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(20, 3, -6)))
	now += 1
	local arm = hiders[1].character:FindFirstChild("Right Arm")
	arm.Transparency = 0.15
	local bulkyHat = part(hiders[1].character, "OversizedHatFixture", hiders[1].root.Position, Vector3.new(8, 3, 4), true)
	bulkyHat.Transparency, bulkyHat.Anchored = 0.25, false
	local face = Instance.new("Decal") face.Transparency, face.Parent = 0.2, hiders[1].character.Head
	local pattern = Instance.new("Texture") pattern.Transparency, pattern.Parent = 0.3, bulkyHat
	local sparkle = Instance.new("ParticleEmitter") sparkle.Enabled, sparkle.Parent = true, bulkyHat
	local ribbon = Instance.new("Trail") ribbon.Enabled, ribbon.Parent = true, bulkyHat
	local beam = Instance.new("Beam") beam.Enabled, beam.Parent = false, bulkyHat
	local originalVisuals = {arm.Transparency, bulkyHat.Transparency, face.Transparency, pattern.Transparency}
	hiders[1].humanoid.Sit = true
	check("Hider enters locker", service:UseLocker(hiders[1].player, locker))
	check("Entering locker releases seated avatar", not hiders[1].humanoid.Sit)
	check("Locker owns and anchors occupant", locker.occupant == hiders[1] and hiders[1].root.Anchored and hiders[1].player:GetAttribute("HSHiding"))
	check("Standard arms and bulky hats concealed", arm.Transparency == 1 and bulkyHat.Transparency == 1)
	check("Face and texture concealed", face.Transparency == 1 and pattern.Transparency == 1)
	check("Avatar effects concealed", not sparkle.Enabled and not ribbon.Enabled and not beam.Enabled)
	local lateAccessory = part(hiders[1].character, "LateAccessoryFixture", hiders[1].root.Position, Vector3.new(7, 2, 5), true)
	lateAccessory.Transparency = 0.4
	local lateTransparency = lateAccessory.Transparency
	local lateSparkle = Instance.new("ParticleEmitter") lateSparkle.Enabled, lateSparkle.Parent = true, lateAccessory
	local lateOutline = Instance.new("Highlight") lateOutline.Enabled, lateOutline.Parent = true, hiders[1].character
	task.wait()
	check("Late accessories concealed while occupied", lateAccessory.Transparency == 1 and not lateSparkle.Enabled and not lateOutline.Enabled)
	check("Concealment does not change avatar size", bulkyHat.Size == Vector3.new(8, 3, 4) and lateAccessory.Size == Vector3.new(7, 2, 5))
	check("Cannot sprint in locker", not service:SetSprint(hiders[1].player, true))
	service:_teleport(hiders[2], CFrame.new(origin + Vector3.new(20, 3, -6)))
	now += 1 check("One occupant per locker", not service:UseLocker(hiders[2].player, locker))
	check("Immediate exit is rate limited", not service:UseLocker(hiders[2].player, locker))
	now += 1 check("Occupant can exit using UI action", service:ExitLocker(hiders[1].player))
	check("Exit restores movement and physics", not hiders[1].root.Anchored and locker.occupant == nil and not hiders[1].player:GetAttribute("HSHiding"))
	check("Exit restores exact transparency", arm.Transparency == originalVisuals[1] and bulkyHat.Transparency == originalVisuals[2] and face.Transparency == originalVisuals[3] and pattern.Transparency == originalVisuals[4] and lateAccessory.Transparency == lateTransparency)
	check("Exit restores exact effect settings", sparkle.Enabled and ribbon.Enabled and not beam.Enabled and lateSparkle.Enabled)
	check("Round label rules survive locker exit", not lateOutline.Enabled)
	local wall = part(container, "LockerApproachWall", origin + Vector3.new(20, 3, -9), Vector3.new(8, 8, 0.5), true)
	now += 1 check("Locker cannot enter through wall", not service:UseLocker(hiders[2].player, locker))
	wall:Destroy()
	now += 1 check("Hider can re-enter locker", service:UseLocker(hiders[1].player, locker))
	check("Non-occupant cannot exit another locker", not service:ExitLocker(hiders[2].player))
	local exitWall = part(container, "LockerExitWall", origin + Vector3.new(20, 3, -9), Vector3.new(8, 8, 0.5), true)
	now += 1 check("Exit cannot teleport through a wall", not service:ExitLocker(hiders[1].player))
	exitWall:Destroy()
	service:_teleport(seeker, CFrame.new(origin + Vector3.new(20, 3, 5)))
	now += 1 check("Distant seeker cannot search", not service:UseLocker(seeker.player, locker))
	service:_teleport(seeker, CFrame.new(origin + Vector3.new(20, 3, -6)))
	now += 1 check("Seeker finds locker occupant", service:UseLocker(seeker.player, locker))
	check("Found hider joins seekers", hiders[1].role == "Seeker" and state:GetAttribute("SeekerCount") == 2)
	check("Found locker occupant exits before ragdoll", not hiders[1].root.Anchored and not hiders[1].player:GetAttribute("HSHiding"))
	check("Found hider ragdolls", hiders[1].ragdoll ~= nil and hiders[1].player:GetAttribute("HSRagdolled") and hiders[1].humanoid.PlatformStand)
	check("Ragdoll lasts 1.35 seconds", math.abs(hiders[1].ragdoll.endsAt - now - 1.35) < 0.001)
	now += 1.36 service:_tick(0.05)
	check("Ragdoll joints and movement restore", not hiders[1].ragdoll and not hiders[1].humanoid.PlatformStand)
	seeker, hiders = seeking({ a, b, c })
	service:_teleport(seeker, CFrame.lookAt(origin + Vector3.new(0, 3, 0), origin + Vector3.new(0, 3, -10)))
	service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(0, 3, 10)))
	service:_teleport(hiders[2], CFrame.new(origin + Vector3.new(30, 3, 10)))
	now += 1 check("Seeker can swing", service:TryBatSwing(seeker.player))
	check("Swing cooldown enforced", not service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Cannot hit behind the seeker", hiders[1].role == "Hider")
	now += 1 service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(0, 3, -10.1)))
	check("Swing begins for distance test", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Cannot hit beyond 10 studs", hiders[1].role == "Hider")
	now += 1 service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(0, 3, -9.9)))
	local batWall = part(container, "BatWall", origin + Vector3.new(0, 3, -5), Vector3.new(15, 10, 0.5), true)
	check("Swing begins for obstruction test", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Cannot hit through wall", hiders[1].role == "Hider")
	batWall:Destroy()
	now += 1 check("Swing begins for contact test", service:TryBatSwing(seeker.player))
	now += 0.15 service:_tick(0.05)
	check("Front target hit at 9.9 studs", hiders[1].role == "Seeker")
	check("Tag converts exactly one hider", state:GetAttribute("HiderCount") == 1 and state:GetAttribute("SeekerCount") == 2)
	check("Hider cannot swing", not service:TryBatSwing(hiders[2].player))
	check("Hit triggers bat VFX serial", (seeker.player:GetAttribute("PCBatHitSerial") or 0) > 0)
	now = service.endsAt service:_tick(0.05)
	check("Timeout gives surviving hiders win", service.phase == "Results" and state:GetAttribute("WinningRole") == "Hider" and hiders[2].player:GetAttribute("HSResult") == "Won")
	check("Standard rewards include participants", state:GetAttribute("LastResultParticipantIds") ~= "" and state:GetAttribute("LastResultPractice") == false)
	check("Winner IDs contain remaining hider", state:GetAttribute("LastResultWinnerIds") == tostring(hiders[2].player.UserId))
	now += 7 service:_tick(0.05)
	check("Results clean back to waiting", not service.active and service.phase == "Waiting")
	check("Participant flags clear", not a:GetAttribute("HSParticipating") and not b:GetAttribute("HSParticipating") and not c:GetAttribute("HSParticipating"))
	check("Authored tags restore exactly", atag.Enabled and extraTag.Enabled and aoutline.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop and aoutline.Enabled)
	check("Movement settings restore", ar.humanoid.WalkSpeed == ar.original.WalkSpeed and ar.humanoid.JumpPower == ar.original.JumpPower)
	seeker, hiders = seeking({ a, b, c })
	service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(20, 3, -6)))
	now += 1 check("Locker occupied for stale-position check", service:UseLocker(hiders[1].player, locker))
	service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(40, 3, -20)))
	service:_tick(0.05)
	check("Stale locker teleports release ownership", not hiders[1].locker and locker.occupant == nil and not hiders[1].root.Anchored)
	service:_teleport(hiders[1], CFrame.new(origin + Vector3.new(20, 3, -6)))
	now += 1 check("Locker occupied for death check", service:UseLocker(hiders[1].player, locker))
	hiders[1].humanoid.Health = 0
	task.wait()
	service:_tick(0.05)
	check("Death clears locker ownership", locker.occupant == nil and not hiders[1].locker)
	check("Death restores hidden character transparency", arm.Transparency == originalVisuals[1] and bulkyHat.Transparency == originalVisuals[2])
	check("Dead hider cannot hide indefinitely", hiders[1].role == "Seeker")
	service:StopRound()
	local replacement = character(hiders[1].player)
	service:_bindCharacter(hiders[1], replacement)
	check("Respawn character recovers readiness", hiders[1].ready and hiders[1].humanoid.Health > 0)
	seeker, hiders = seeking({ a, b, c })
	check("First conversion valid", service:_convert(hiders[1], seeker, now))
	check("Last conversion valid", service:_convert(hiders[2], seeker, now))
	service:_tick(0.05)
	check("All found ends round early", service.phase == "Results" and state:GetAttribute("WinningRole") == "Seeker")
	check("All seekers receive win", a:GetAttribute("HSResult") == "Won" and b:GetAttribute("HSResult") == "Won" and c:GetAttribute("HSResult") == "Won")
	service:StopRound()
	seeker, hiders = seeking({ a, b, c })
	seeker.player.Parent = nil service:_removePlayer(seeker.player)
	service:_tick(0.05)
	check("Departing seeker replaced", state:GetAttribute("SeekerCount") == 1 and state:GetAttribute("HiderCount") == 1)
	for _, record in pairs(service.records) do if record.role == "Seeker" then seeker = record else hiders = { record } end end
	service:_removePlayer(hiders[1].player) hiders[1].player.Parent = nil service:_tick(0.05)
	check("Insufficient players cancels reward", service.phase == "Results" and state:GetAttribute("LastResultPractice") == true and state:GetAttribute("LastResultWinnerIds") == "")
	service:StopRound()
	local many = {}
	for index = 10, 27 do local owner = add(index) table.insert(many, owner) end
	check("Round caps at 16 ready players", #service:_readyPlayers(many) == 16)
	check("Sixteen player round starts", service:StartRound(many))
	check("Exactly 16 participate", state:GetAttribute("ParticipantCount") == 16 and state:GetAttribute("SeekerCount") == 1)
	check("Fifteen hiders fit", state:GetAttribute("HiderCount") == 15)
	service:StopRound()
	check("Admin stop gives no new result reward", service.phase == "Waiting")
	service:Stop()
	check("Service stops and disconnects", not service.running and next(service.records) == nil)
end, debug.traceback)
if not ok then table.insert(report.errors, failure) end
pcall(function() if service then service:Stop() end end)
container:Destroy()
module:Destroy()
report.passed = ok
report.checkCount = #report.checks
return game:GetService("HttpService"):JSONEncode(report)
