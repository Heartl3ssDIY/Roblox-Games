assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local realWorkspace, realStorage = workspace, game:GetService("ServerStorage")
local container = Instance.new("Folder") container.Name, container.Parent = "DuckGooseNativeFixture20261010", realWorkspace
local report = { checks = {}, errors = {} }
local function check(name, condition)
	table.insert(report.checks, { name = name, passed = condition == true })
	assert(condition, name)
end
local function signal()
	local entries = {}
	return { Connect = function(_, callback)
		local entry = { active = true, callback = callback } table.insert(entries, entry)
		return { Disconnect = function() entry.active = false end }
	end, Fire = function(_, ...) for _, entry in ipairs(entries) do if entry.active then entry.callback(...) end end end }
end
local now, players = 100, {}
local playersService = { PlayerAdded = signal(), PlayerRemoving = signal() }
function playersService:GetPlayers() return players end
function playersService:GetPlayerByUserId(id) for _, player in ipairs(players) do if player.UserId == id and player.Parent == self then return player end end end
local function player(index)
	local attrs = { PCDataReady = true }
	local object = { UserId = 890000 + index, Name = "GooseFixture" .. index, DisplayName = "GooseFixture" .. index,
		Parent = playersService, CharacterAdded = signal(), CharacterRemoving = signal() }
	function object:GetAttribute(name) return attrs[name] end
	function object:SetAttribute(name, value) attrs[name] = value end
	return object
end
local function part(parent, name, position, size, solid, class)
	local object = Instance.new(class or "Part")
	object.Name, object.Size, object.Position = name, size or Vector3.one, position
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, solid == true, solid == true, solid == true
	object.Parent = parent
	return object
end
local origin, TAU = Vector3.new(-32000, 1033, 4500), math.pi * 2
local arena = Instance.new("Folder") arena.Name, arena.Parent = "Duck Duck Goose", container
for name, value in pairs({ MinimumPlayers = 2, MaxPlayers = 16, RoundDuration = 180, CountdownSeconds = 3,
	ResultsSeconds = 7, SelectionSeconds = 15, BaseSpeed = 16, LapInnerRadius = 25, LapOuterRadius = 36 }) do arena:SetAttribute(name, value) end
local gameplay = Instance.new("Folder") gameplay.Name, gameplay.Parent = "Gameplay", arena
part(gameplay, "ArenaBounds", origin + Vector3.new(0, 40, 0), Vector3.new(144, 80, 144))
part(gameplay, "CircleCenter", origin, Vector3.one)
local seats = Instance.new("Folder") seats.Name, seats.Parent = "Seats", gameplay
for index = 1, 16 do
	local angle = (index - 1) / 16 * TAU
	local model = Instance.new("Model") model.Name, model.Parent = "Seat" .. index, seats model:SetAttribute("DGSeatIndex", index)
	local chair = part(model, "Seat", origin + Vector3.new(math.sin(angle) * 22, 1, -math.cos(angle) * 22), Vector3.new(3, 0.5, 3), true, "Seat")
	chair.CFrame = CFrame.lookAt(chair.Position, Vector3.new(origin.X, chair.Position.Y, origin.Z))
	local spot = part(model, "Spot", chair.Position + Vector3.new(0, 2.1, 0)) spot.CFrame = chair.CFrame + Vector3.new(0, 2.1, 0)
	local stand = part(model, "StandPoint", origin + Vector3.new(math.sin(angle) * 25.2, 3, -math.cos(angle) * 25.2))
	stand.CFrame = CFrame.lookAt(stand.Position, Vector3.new(origin.X, stand.Position.Y, origin.Z))
	local number = Instance.new("SurfaceGui") number.Name, number.Enabled, number.Parent = "SeatNumber", true, chair
end
for name, count in pairs({ EntrySpawns = 16, SpectatorSpawns = 16 }) do
	local folder = Instance.new("Folder") folder.Name, folder.Parent = name, gameplay
	for index = 1, count do part(folder, "Spawn" .. index, origin + Vector3.new(index * 4 - 32, 3, name == "EntrySpawns" and -48 or 49)) end
end
local lobbySpawn = part(container, "LobbyFixtureSpawn", origin + Vector3.new(0, 1, 150))
local state = Instance.new("Folder") state.Name, state.Parent = "DuckDuckGooseState", container
local remote = { OnServerEvent = signal(), IsA = function(_, kind) return kind == "RemoteEvent" end }
local services = {
	Players = playersService, RunService = { Heartbeat = signal() },
	ReplicatedStorage = { FindFirstChild = function(_, name) if name == "DuckDuckGooseState" then return state elseif name == "DuckDuckGooseActionRequest" or name == "DuckDuckGooseSprintRequest" then return remote end end },
}
local env = {
	game = { GetService = function(_, name) return assert(services[name], name) end },
	workspace = { GetServerTimeNow = function() return now end, Raycast = function(_, ...) return realWorkspace:Raycast(...) end },
}
local module = Instance.new("ModuleScript")
module.Name, module.Sandboxed = "DuckGooseExactCapabilityFixture", true
module.Capabilities = game.ServerScriptService.HideAndSeekService.Capabilities
module.Source = "return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\n" .. [======[__SERVICE_SOURCE__]======] .. "\nend"
module.Parent = realStorage
local service
local function character(owner)
	local model = Instance.new("Model") model.Name, model.Parent = owner.Name, container
	local root = part(model, "HumanoidRootPart", origin + Vector3.new(0, 3, -48), Vector3.new(2, 2, 1)) root.Anchored = false
	local torso = part(model, "Torso", root.Position, Vector3.new(2, 2, 1)) torso.Anchored = false
	local head = part(model, "Head", root.Position + Vector3.new(0, 1.5, 0), Vector3.new(2, 1, 1)) head.Anchored = false
	for index, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local limb = part(model, name, root.Position + Vector3.new(index % 2 == 0 and 1.5 or -1.5, index > 2 and -2 or 0, 0), Vector3.new(1, 2, 1)) limb.Anchored = false
		local joint = Instance.new("Motor6D") joint.Name, joint.Part0, joint.Part1, joint.C0, joint.Parent = name, torso, limb, CFrame.new(limb.Position - torso.Position), torso
	end
	local neck = Instance.new("Motor6D") neck.Name, neck.Part0, neck.Part1, neck.C0, neck.Parent = "Neck", torso, head, CFrame.new(0, 1.5, 0), torso
	local rootJoint = Instance.new("Motor6D") rootJoint.Name, rootJoint.Part0, rootJoint.Part1, rootJoint.Parent = "RootJoint", root, torso, root
	local humanoid = Instance.new("Humanoid") humanoid.RequiresNeck, humanoid.Parent = false, model
	model.PrimaryPart, owner.Character = root, model
	return model
end
local function add(index)
	local owner = player(index) table.insert(players, owner)
	local record = { player = owner, ready = false, inRound = false, participating = false, role = "", stamina = 5,
		connections = {}, characterConnections = {} }
	service.records[owner] = record
	service:_bindCharacter(record, character(owner))
	return owner, record
end
local function playing(list)
	service:StopRound()
	check("Round starts with eligible connected players", service:StartRound(list))
	check("Countdown freezes seated players", service.phase == "Countdown" and service.records[list[1]].root.Anchored)
	now += 3 service:_tick(0.05)
	check("Countdown becomes picking", service.phase == "Playing" and service.turnPhase == "Choosing" and service.picker ~= nil)
	check("Round clock is exactly three minutes", math.abs(service.endsAt - now - 180) < 0.001)
	local ducks = {} for _, owner in ipairs(list) do local record = service.records[owner] if record ~= service.picker then table.insert(ducks, record) end end
	return service.picker, ducks
end
local function choose(picker, duck)
	service:_teleport(picker, service:_outsideSeat(duck.seat, 29))
	now += 0.5
	check("Nearby picker chooses valid seated duck", service:ChooseGoose(picker.player, duck.player.UserId))
	check("Picker becomes runner and chosen duck becomes goose", picker.role == "Runner" and duck.role == "Goose")
	check("Chosen seat disabled until lap is valid", service.turn.seat.record == nil and service.turn.seat.seat.Disabled)
	check("Empty chosen spot marked gold", service.turn.seat.claimMarker.Enabled and service.turn.seat.model:GetAttribute("DGClaimSeat"))
	return service.turn
end
local function lap(turn, segments)
	local initial = turn.lastAngle
	for step = 1, segments do
		local angle = initial + TAU * step / 180
		service:_teleport(turn.runner, CFrame.lookAt(service:_trackPosition(angle, 30), service:_trackPosition(angle + 0.05, 30)))
		now += 0.05 service:_tick(0.05)
		if service.turn ~= turn then return end
	end
end
local ok, failure = xpcall(function()
	local Service = require(module)(env)
	service = Service.new(arena)
	service.lobbySpawn = lobbySpawn
	service:Start()
	local a, ar = add(1) local b, br = add(2) local c, cr = add(3)
	check("One-player round rejected", service:StartRound({ a }) == false)
	b:SetAttribute("PCAFK", true) check("AFK players excluded", #service:_readyPlayers({ a, b }) == 1) b:SetAttribute("PCAFK", false)
	b:SetAttribute("PCDataReady", false) check("Unloaded profile excluded", #service:_readyPlayers({ a, b }) == 1) b:SetAttribute("PCDataReady", true)
	b:SetAttribute("HSParticipating", true) check("Other game player excluded", #service:_readyPlayers({ a, b }) == 1) b:SetAttribute("HSParticipating", false)
	check("Duplicate entries excluded", #service:_readyPlayers({ a, a, b }) == 2)
	local picker, ducks = playing({ a, b, c })
	check("Seated ducks held in sitting pose", ducks[1].humanoid.Sit and ducks[1].root.Anchored and ducks[1].humanoid.WalkSpeed == 0)
	check("Picker is marked red without through-wall visibility", picker.roleMarker ~= nil and picker.roleMarker.DepthMode == Enum.HighlightDepthMode.Occluded and picker.roleMarker.FillColor == Color3.fromRGB(255, 100, 115))
	check("Seated ducks have no active role marker", ducks[1].roleMarker == nil)
	check("Prompt data available on seat model", ducks[1].seat.model:GetAttribute("DGSeatedUserId") == ducks[1].player.UserId and ducks[1].seat.prompt:GetAttribute("DGGoosePrompt"))
	check("Only picker can select goose", not service:ChooseGoose(ducks[1].player, ducks[2].player.UserId))
	check("Invalid target IDs rejected", not service:ChooseGoose(picker.player, "bad"))
	service:_teleport(picker, CFrame.new(origin + Vector3.new(0, 3, -65)))
	check("Distant choice rejected", not service:ChooseGoose(picker.player, ducks[1].player.UserId))
	local turn = choose(picker, ducks[1])
	check("Runner keeps red marker and goose uses amber", picker.roleMarker.FillColor == Color3.fromRGB(255, 100, 115) and ducks[1].roleMarker.FillColor == Color3.fromRGB(255, 202, 65))
	check("No early seat claim", not service:ClaimSeat(picker.player))
	check("No duck or runner bat swings", not service:TryBatSwing(ducks[2].player) and not service:TryBatSwing(picker.player))
	check("Goose grace blocks immediate hit", not service:TryBatSwing(ducks[1].player))
	check("Runner sprint starts", service:SetSprint(picker.player, true) and picker.humanoid.WalkSpeed == 26)
	now += 0.05 service:_tick(0.05) check("Sprint drains from five seconds", picker.stamina < 5 and picker.player:GetAttribute("DGMaxStamina") == 5)
	picker.stamina = 0 now += 0.05 service:_tick(0.05)
	check("Any regenerated stamina resumes held sprint", picker.stamina > 0 and picker.player:GetAttribute("DGSprinting"))
	service:SetSprint(picker.player, false)
	service:_teleport(picker, CFrame.new(origin + Vector3.new(0, 3, 0))) now += 0.05 service:_tick(0.05)
	check("Centre shortcut resets progress", turn.progress == 0 and (picker.root.Position - origin).Magnitude > 25)
	local jumpingAngle = turn.lastAngle
	service:_teleport(picker, CFrame.new(service:_trackPosition(jumpingAngle + 0.02, 30) + Vector3.new(0, 2.5, 0)))
	now += 0.05 service:_tick(0.05)
	check("Normal jump retains clockwise progress", turn.progress > 0 and turn.lastPosition.Y > origin.Y + 5)
	service:_resetLap(turn)
	local oldGoose = ducks[1].root.Position
	service:_teleport(ducks[1], CFrame.new(origin + Vector3.new(0, 3, 0)))
	check("Goose cannot swing from centre", not service:TryBatSwing(ducks[1].player))
	now += 0.05 service:_tick(0.05)
	check("Goose centre shortcut rewound", (ducks[1].root.Position - oldGoose).Magnitude < 0.01)
	service:_teleport(picker, service:_outsideSeat(turn.seat, 30) * CFrame.new(0, 0, -1))
	now += 0.05 service:_tick(0.05)
	check("Short movement cannot mark full lap", not turn.ready)
	service:_resetLap(turn)
	local startAngle = turn.lastAngle
	service:_teleport(picker, CFrame.new(service:_trackPosition(startAngle - 0.2, 30))) now += 0.05 service:_tick(0.05)
	check("Counterclockwise runner cannot gain progress", turn.progress == 0)
	local gooseAngle = turn.gooseAngle
	service:_teleport(ducks[1], CFrame.new(service:_trackPosition(gooseAngle - 0.2, 25.5))) now += 0.05 service:_tick(0.05)
	check("Counterclockwise goose rewound", math.abs(select(2, service:_polar(ducks[1].root.Position)) - gooseAngle) < 0.01)
	service:_teleport(picker, CFrame.new(service:_trackPosition(startAngle + 2, 30))) now += 0.05 service:_tick(0.05)
	check("Teleport cannot complete lap", turn.progress == 0 and not turn.ready)
	local lagAngle, beforeProgress = turn.lastAngle, turn.progress
	service:_teleport(picker, CFrame.new(service:_trackPosition(lagAngle + 0.2, 30)))
	now += 0.4 service:_tick(0.15)
	check("Plausible delayed frame keeps lap progress", turn.progress > beforeProgress and not turn.ready)
	local oldGoosePosition = turn.goosePosition
	local radius, lagGooseAngle = service:_polar(oldGoosePosition)
	service:_teleport(ducks[1], CFrame.new(service:_trackPosition(lagGooseAngle + 0.2, radius)))
	now += 0.4 service:_tick(0.15)
	check("Plausible delayed goose frame is not rewound", (ducks[1].root.Position - oldGoosePosition).Magnitude > 1)
	local distanceBefore = turn.gooseDistance
	service:_resetLap(turn)
	now += 0.05 service:_tick(0.05)
	check("Runner reset does not punish legal goose distance", turn.gooseDistance == distanceBefore and service:_guardGoose(turn, now))
	local rewound = false
	for step = 1, 50 do
		local lastRadius, currentAngle = service:_polar(turn.goose.root.Position)
		local desired = service:_trackPosition(currentAngle + 45 * 0.05 / lastRadius, lastRadius)
		service:_teleport(turn.goose, CFrame.new(desired))
		now += 0.05
		if not service:_guardGoose(turn, now) then rewound = true break end
	end
	check("Sustained forty-five stud speed is rejected", rewound)
	service:_resetLap(turn)
	lap(turn, 90)
	check("Half lap remains incomplete", service.turn == turn and turn.progress > 2.5 and not turn.ready)
	check("Half lap cannot claim seat", not service:ClaimSeat(picker.player))
	local halfAngle = turn.lastAngle
	for step = 1, 90 do
		local angle = halfAngle + TAU * step / 180
		service:_teleport(picker, CFrame.lookAt(service:_trackPosition(angle, 30), service:_trackPosition(angle + 0.05, 30)))
		now += 0.05 service:_tick(0.05)
	end
	check("Outside clockwise full lap validates", turn.ready and picker.player:GetAttribute("DGLapProgress") == 1)
	service:_teleport(picker, turn.seat.spot.CFrame)
	check("Ready runner cannot instantly teleport-claim", not service:ClaimSeat(picker.player) and not turn.ready)
	lap(turn, 180)
	check("Runner revalidates lap after teleport rejection", turn.ready)
	local originalEndsAt = service.endsAt
	service.endsAt = now
	service:_teleport(picker, turn.seat.spot.CFrame)
	check("Post-deadline claim is rejected before heartbeat", not service:ClaimSeat(picker.player))
	service.endsAt = originalEndsAt
	service:_teleport(picker, CFrame.new(turn.lastPosition))
	local wrongSlot = service.seats[(turn.seat.index % 16) + 1]
	service:_teleport(picker, wrongSlot.spot.CFrame)
	check("Wrong empty spot cannot claim", not service:ClaimSeat(picker.player))
	service:_teleport(picker, turn.seat.spot.CFrame)
	now += 0.4
	check("Valid runner claims chosen empty spot", service:ClaimSeat(picker.player))
	check("Runner seats and goose becomes next picker", picker.role == "Duck" and picker.humanoid.Sit and service.picker == ducks[1] and ducks[1].role == "Picker")
	check("Seating removes runner marker", picker.roleMarker == nil and ducks[1].roleMarker.FillColor == Color3.fromRGB(255, 100, 115))
	check("Role loop keeps original round clock", service.endsAt > now and service.endsAt - now < 180)
	picker, ducks = playing({ a, b, c })
	turn = choose(picker, ducks[1])
	now += 1
	local angle = turn.lastAngle
	local goosePosition = service:_trackPosition(angle, 30)
	local function arrange(distance, facingAway)
		local delta = 2 * math.asin(distance / 60)
		local runnerPosition = service:_trackPosition(angle + delta, 30)
		service:_teleport(turn.goose, CFrame.lookAt(goosePosition, facingAway and service:_trackPosition(angle - 0.1, 30) or runnerPosition))
		service:_teleport(turn.runner, CFrame.new(runnerPosition))
		turn.lastPosition, turn.lastAngle, turn.lastAt = runnerPosition, angle + delta, now
		turn.goosePosition, turn.gooseAngle, turn.gooseAt = goosePosition, angle, now
		return runnerPosition
	end
	arrange(10.1, false)
	check("Range test swing accepted", service:TryBatSwing(turn.goose.player))
	now += 0.15 service:_tick(0.05)
	check("Bat cannot hit beyond ten studs", picker.participating and picker.role == "Runner")
	now += 1 arrange(9.9, true)
	check("Facing test swing accepted", service:TryBatSwing(turn.goose.player))
	now += 0.15 service:_tick(0.05)
	check("Bat cannot hit behind goose", picker.participating and picker.role == "Runner")
	now += 1 local runnerPosition = arrange(9.9, false)
	local wall = part(container, "BatObstruction", (goosePosition + runnerPosition) * 0.5, Vector3.new(1, 9, 12), true)
	check("Obstruction test swing accepted", service:TryBatSwing(turn.goose.player))
	now += 0.15 service:_tick(0.05)
	check("Bat cannot hit through a wall", picker.participating and picker.role == "Runner")
	wall:Destroy()
	now += 1 arrange(9.9, false)
	check("Contact test swing accepted", service:TryBatSwing(turn.goose.player))
	now += 0.15 service:_tick(0.05)
	check("Bat hits facing runner at 9.9 studs", not picker.participating and picker.player:GetAttribute("DGEliminated"))
	picker, ducks = playing({ a, b, c })
	turn = choose(picker, ducks[1])
	now += 1
	local angle = turn.lastAngle
	local goosePosition = service:_trackPosition(angle, 30)
	local runnerPosition = service:_trackPosition(angle + 0.25, 30)
	service:_teleport(turn.goose, CFrame.lookAt(goosePosition, runnerPosition))
	service:_teleport(turn.runner, CFrame.new(runnerPosition))
	turn.lastPosition, turn.lastAngle, turn.lastAt = runnerPosition, angle + 0.25, now
	turn.goosePosition, turn.gooseAngle, turn.gooseAt = goosePosition, angle, now
	check("Goose can swing after grace", service:TryBatSwing(turn.goose.player))
	check("Swing cooldown enforced", not service:TryBatSwing(turn.goose.player))
	now += 0.15 service:_tick(0.05)
	check("Bat catch eliminates runner", not picker.participating and picker.player:GetAttribute("DGEliminated") and picker.role == "Spectator")
	check("Elimination removes active role marker", picker.roleMarker == nil)
	check("Catch ragdoll lasts 1.35 seconds", picker.ragdoll ~= nil and picker.player:GetAttribute("DGRagdolled") and math.abs(picker.ragdoll.endsAt - now - 1.35) < 0.001)
	check("Goose becomes next picker after catch", service.picker == ducks[1] and service.turnPhase == "Choosing")
	check("Only active players counted alive", state:GetAttribute("AliveCount") == 2 and state:GetAttribute("ParticipantCount") == 3)
	now += 1.36 service:_tick(0.05)
	check("Eliminated runner recovers at spectator spawn", not picker.ragdoll and not picker.humanoid.PlatformStand and (picker.root.Position - service.spectatorSpawns[(picker.spawnIndex - 1) % #service.spectatorSpawns + 1].Position).Magnitude < 0.01)
	now = service.endsAt service:_tick(0.05)
	check("Timeout picker loses and duck wins", service.phase == "Results" and ducks[1].player:GetAttribute("DGResult") == "Lost" and ducks[2].player:GetAttribute("DGResult") == "Won")
	check("Eliminated runner remains reward participant", state:GetAttribute("LastResultParticipantIds"):find(tostring(picker.player.UserId), 1, true) ~= nil and picker.player:GetAttribute("DGResult") == "Lost")
	now += 7 service:_tick(0.05)
	check("All players including eliminated return to lobby", not picker.inRound and not picker.player:GetAttribute("DGEliminated") and (picker.root.Position - lobbySpawn.Position).Magnitude < 5)
	check("Cleanup removes all owned role markers", ar.roleMarker == nil and br.roleMarker == nil and cr.roleMarker == nil)
	check("Original movement and standing restore", picker.humanoid.WalkSpeed == picker.original.WalkSpeed and not picker.humanoid.Sit and not picker.root.Anchored)
	picker, ducks = playing({ a, b })
	turn = choose(picker, ducks[1])
	service:_catch(turn, now)
	check("Last survivor remains seated until round ends", service.phase == "Playing" and service.turnPhase == "FinalDuck" and ducks[1].role == "Duck" and ducks[1].humanoid.Sit)
	check("Last survivor timer preserved", service.endsAt > now and state:GetAttribute("FinalDuckUserId") == ducks[1].player.UserId)
	now = service.endsAt service:_tick(0.05)
	check("Sole legitimate survivor wins at timeout", ducks[1].player:GetAttribute("DGResult") == "Won" and state:GetAttribute("LastResultPractice") == false)
	picker, ducks = playing({ a, b, c })
	now = service.turnDeadline service:_tick(0.05)
	check("Fifteen-second selection timeout chooses a goose", service.turnPhase == "Chasing" and service.turn ~= nil)
	check("Auto choice remains server-owned", service.turn.runner == picker and service.turn.goose.role == "Goose")
	picker, ducks = playing({ a, b })
	service:_lost(ducks[1])
	check("Death or departure below minimum cancels rewards", service.phase == "Results" and state:GetAttribute("LastResultPractice") == true and state:GetAttribute("LastResultWinnerIds") == "")
	service:StopRound()
	local many = {}
	for index = 10, 27 do local owner = add(index) table.insert(many, owner) end
	check("Capacity limits to sixteen", #service:_readyPlayers(many) == 16)
	check("Sixteen-player round starts", service:StartRound(many))
	check("Sixteen assigned seats available", state:GetAttribute("AliveCount") == 16)
	service:StopRound()
	service.config.MaxPlayers = 8
	check("Capacity easily changes to eight", #service:_readyPlayers(many) == 8)
	check("Eight-player round starts", service:StartRound(many))
	local count, indexes = 0, {}
	for _, record in pairs(service.records) do if record.inRound then count += 1 indexes[record.seatIndex] = true end end
	check("Eight seats distributed evenly", count == 8 and indexes[1] and indexes[3] and indexes[5] and indexes[7] and indexes[9] and indexes[11] and indexes[13] and indexes[15])
	check("Unused seats hidden and disabled", service.seats[2].seat.Transparency == 1 and service.seats[2].seat.Disabled and not service.seats[2].seat.CanTouch)
	check("Unused SurfaceGui seat number hidden", service.seats[2].seat.SeatNumber.Enabled == false)
	service:StopRound()
	check("Seat visibility restored after round", service.seats[2].seat.Transparency == service.seats[2].original.visuals[service.seats[2].seat].Transparency)
	check("Seat number restores original visibility", service.seats[2].seat.SeatNumber.Enabled == true)
	service:Stop()
	check("Service disconnects and clears", not service.running and next(service.records) == nil)
	check("Owned prompts and claim markers removed", service.seats[1].seat:FindFirstChild("SelectGoosePrompt") == nil and service.seats[1].model:FindFirstChild("EmptyGooseSpot") == nil)
end, debug.traceback)
if not ok then table.insert(report.errors, failure) end
pcall(function() if service then service:Stop() end end)
container:Destroy() module:Destroy()
report.passed, report.checkCount = ok, #report.checks
return game:GetService("HttpService"):JSONEncode(report)
