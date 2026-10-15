local ServerScriptService = game:GetService("ServerScriptService")
local module = ServerScriptService.StuckInTheMudService:Clone()
module.Name = "MudPureFixtureModule"
module.Parent = ServerScriptService
local folder = Instance.new("Folder") folder.Name = "MudPureFixtures" folder.Parent = workspace
local checks = {}
local function expect(condition, name)
	assert(condition, name)
	table.insert(checks, name)
end
local function equalList(a, b)
	if #a ~= #b then return false end
	for index, value in ipairs(a) do if value ~= b[index] then return false end end
	return true
end
local ok, failure = xpcall(function()
	local Service = require(module)
	for count = 2, 24 do
		local assignments, teamCount = Service.TeamAssignments(count, 2, 12)
		local totals = {}
		for _, team in ipairs(assignments) do totals[team] = (totals[team] or 0) + 1 end
		expect(#assignments == count and teamCount == 2 and math.abs((totals[1] or 0) - (totals[2] or 0)) <= 1 and totals[1] <= 12 and totals[2] <= 12, "Balanced roster invariant for" .. count .. " players")
	end
	local assignments, teamCount = Service.TeamAssignments(24, 12, 2)
	local totals = {} for _, id in ipairs(assignments) do totals[id] = (totals[id] or 0) + 1 end
	local validPairs = #assignments == 24 and teamCount == 12
	for team = 1, 12 do validPairs = validPairs and totals[team] == 2 end
	expect(validPairs, "24-player pair mode has exactly twelve teams of two")
	assignments, teamCount = Service.TeamAssignments(4, 2, 2)
	expect(teamCount == 2 and equalList(assignments, { 1, 2, 1, 2 }), "Exact 2v2 assignments")
	assignments, teamCount = Service.TeamAssignments(24, 4, 6)
	totals = {} for _, id in ipairs(assignments) do totals[id] = (totals[id] or 0) + 1 end
	expect(teamCount == 4 and totals[1] == 6 and totals[4] == 6, "Four-team configuration is balanced")
	assignments, teamCount = Service.TeamAssignments(7, 2, 2)
	totals = {} for _, id in ipairs(assignments) do totals[id] = (totals[id] or 0) + 1 end
	expect(teamCount == 4 and totals[1] == 2 and totals[4] == 1, "Pair mode keeps an odd roster within capacity")
	assignments, teamCount = Service.TeamAssignments(1, 2, 12)
	expect(#assignments == 0 and teamCount == 0, "Single-player roster does not create a normal match")
	assignments, teamCount = Service.TeamAssignments(0, 2, 12)
	expect(#assignments == 0 and teamCount == 0, "Empty roster does not create teams")
	assignments, teamCount = Service.TeamAssignments(3, 99, 2)
	expect(teamCount == 3 and #assignments == 3, "Team count never exceeds participating roster")
	assignments, teamCount = Service.TeamAssignments(24, 99, 2)
	expect(teamCount == 12, "Team count stays within twelve unique colors")

	local active, free, original = { 2, 1 }, { 1, 1 }, { 3, 2 }
	local winners = Service.ChooseTimeoutTeams(active, free, original)
	expect(equalList(winners, { 2 }), "Timeout uses proportion rather than raw free count")
	expect(equalList(active, { 2, 1 }) and free[1] == 1 and original[1] == 3, "Timeout selection does not mutate inputs")
	winners = Service.ChooseTimeoutTeams({ 1, 2 }, { 2, 1 }, { 4, 2 })
	expect(equalList(winners, { 1, 2 }), "Different roster sizes share equal-proportion win")
	winners = Service.ChooseTimeoutTeams({ 3, 2, 1 }, { 2, 4, 3 }, { 4, 8, 6 })
	expect(equalList(winners, { 1, 2, 3 }), "Shared winners are returned in stable team order")
	winners = Service.ChooseTimeoutTeams({ 1, 2 }, { 4, 2 }, { 12, 3 })
	expect(equalList(winners, { 2 }), "Larger absolute free team may lose on proportion")
	local assigned = { 4, 2 }
	local beforeLeaving = Service.ChooseTimeoutTeams({ 1, 2 }, { 2, 1 }, assigned)
	winners = Service.ChooseTimeoutTeams({ 1, 2 }, { 1, 1 }, assigned)
	expect(equalList(beforeLeaving, { 1, 2 }) and equalList(winners, { 2 }) and assigned[1] == 4, "Disconnecting never shrinks the supplied original denominator")
	winners = Service.ChooseTimeoutTeams({ 2 }, { 10, 1 }, { 12, 2 })
	expect(equalList(winners, { 2 }), "Eliminated team excluded even if a stale free count exists")
	expect(#Service.ChooseTimeoutTeams({}, {}, {}) == 0, "No active teams produce no winners")
	expect(#Service.ChooseTimeoutTeams({ 1, 2 }, { 0, 0 }, { 3, 2 }) == 0, "Zero-free teams cannot win timeout")
	winners = Service.ChooseTimeoutTeams({ 1 }, { 1 }, {})
	expect(equalList(winners, { 1 }), "Missing original count never divides by zero")
	winners = Service.ChooseTimeoutTeams({ 1, 2 }, { 12, 11 }, { 12, 11 })
	expect(equalList(winners, { 1, 2 }), "Odd balanced teams both staying completely free share win")
	winners = Service.ChooseTimeoutTeams({ 1, 2 }, { 6, 6 }, { 12, 11 })
	expect(equalList(winners, { 2 }), "Odd-team proportion is precise and fair")

	local arena = Instance.new("Folder") arena.Name = "SettingsFixture" arena.Parent = folder
	local controller = setmetatable({ arena = arena }, Service)
	expect(controller:_weaponsReady() == false, "Pending Input module fails actual weapon access gate without Tool mutation")
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 10, "Absent authored setting uses fallback")
	arena:SetAttribute("SprintSeconds", 15)
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 15, "Numeric authored setting is used")
	arena:SetAttribute("SprintSeconds", "15")
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 10, "String authored setting uses fallback")
	arena:SetAttribute("SprintSeconds", -3)
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 0.1, "Negative authored setting is clamped")
	controller.arena = { GetAttribute = function() return math.huge end }
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 10, "Infinite authored setting uses fallback")
	controller.arena = { GetAttribute = function() return 0 / 0 end }
	expect(controller:_setting("SprintSeconds", 10, 0.1) == 10, "NaN authored setting uses fallback")
	controller.arena = arena
	arena:SetAttribute("FloorY", -40)
	expect(controller:_setting("FloorY", 32.9, -10000) == -40, "Valid negative floor height is preserved")
	arena:SetAttribute("ResultsSeconds", 0)
	expect(controller:_setting("ResultsSeconds", 7, 0) == 0, "Zero results duration is permitted")
	arena:SetAttribute("SprintMultiplier", 0)
	expect(controller:_setting("SprintMultiplier", 2.5, 1) == 1, "Sprint multiplier cannot reduce base speed")
	local readinessState = Instance.new("Folder") readinessState.Name = "ReadinessFixture" readinessState.Parent = folder
	local rejected = setmetatable({ arena = arena, running = true, active = false, currentRound = nil, records = {}, state = readinessState }, Service)
	rejected._weaponsReady = function() return false end
	rejected._readyPlayers = function() error("Guard must run before gathering or mutating gameplay") end
	rejected._newBot = function() error("Guard must run before spawning a bot") end
	rejected._begin = function() error("Guard must run before starting gameplay") end
	local accepted, why = rejected:StartRound()
	expect(not accepted and why == "Mud gun access is awaiting approval." and not rejected.active and rejected.currentRound == nil and readinessState:GetAttribute("GunAccessReady") == false, "Unavailable weapons reject normal round and publish limited readiness before gameplay change")
	accepted, why = rejected:StartPractice(nil, "Shooter")
	expect(not accepted and why == "Mud gun access is awaiting approval." and not rejected.active and next(rejected.records) == nil, "Unavailable weapons reject practice without spawning or participation")
	local selection = setmetatable({ arena = arena, running = true, active = false, records = {}, state = readinessState }, Service)
	selection._weaponsReady = function() return true end
	local selected, picked = {}, nil
	selection._readyPlayers = function() return table.clone(selected) end
	selection._begin = function(_, roster) picked = roster return true end
	selection.random = Random.new(71)
	selected = { 1, 2, 3 }
	accepted, why = selection:StartRound()
	expect(not accepted and why == "At least 4 ready players are needed." and picked == nil and not selection.active, "Default normal match requires four ready players")
	selected = { 1, 2, 3, 4, 5, 6 }
	accepted = selection:StartRound()
	expect(accepted and #picked == 4 and readinessState:GetAttribute("GunAccessReady") == true, "Default normal match selects four and publishes accessible readiness")
	arena:SetAttribute("MaxPlayers", 24) arena:SetAttribute("MinimumPlayers", 2) arena:SetAttribute("MaxTeamSize", 12)
	selected = {} for index = 1, 24 do selected[index] = index end
	accepted = selection:StartRound()
	expect(accepted and #picked == 24, "Optional24-player configuration remains supported")
	local heatValues = { MDHeatProgress = 2.5, MDHeatActive = true, MDHeatTargetUserId = 123 }
	local heatPlayer = {}
	function heatPlayer:GetAttribute(name) return heatValues[name] end
	function heatPlayer:SetAttribute(name, value) heatValues[name] = value end
	local released = { player = heatPlayer, heatProgress = 2.5, heatHeld = true, heatDirection = Vector3.xAxis, heatLeaseEndsAt = 99 }
	controller:_clearHeat(released, true)
	expect(released.heatProgress == 0 and heatValues.MDHeatProgress == 0 and heatValues.MDHeatActive == false and heatValues.MDHeatTargetUserId == 0 and not released.heatHeld and released.heatLeaseEndsAt == 0, "Heat release clears rescuer seconds target and held lease without Tool access")
	local unrelatedPlayer = {}
	function unrelatedPlayer:FindFirstChild() error("Mud must never scan unrelated Backpack gear") end
	local noKit = { player = unrelatedPlayer, isBot = false, managedTools = {} }
	controller:_destroyTools(noKit)
	expect(#noKit.managedTools == 0, "Disabled or inactive Mud cleanup does not inspect unrelated character or Backpack gear")

	local function body(model, name, size, position)
		local part = Instance.new("Part") part.Name = name part.Size = size part.Position = position part.Anchored = true part.Parent = model return part
	end
	local r6 = Instance.new("Model") r6.Name = "SyntheticR6" r6.Parent = folder
	local root = body(r6, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 200, 0))
	body(r6, "Head", Vector3.new(2, 1, 1), root.Position + Vector3.new(0, 1.5, 0))
	body(r6, "Torso", Vector3.new(2, 2, 1), root.Position)
	for index, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do body(r6, name, Vector3.new(1, 2, 1), root.Position + Vector3.new(index * 2, 0, 0)) end
	local record = { character = r6, root = root, muddy = true, isBot = true, originalGroups = {} }
	controller:_mudVisual(record)
	local coating = r6:FindFirstChild("MDMudCoating")
	expect(coating and #coating:GetChildren() == 6, "R6 receives six visible mud patches including face")
	local face = coating:FindFirstChild("MudFaceMask")
	expect(face and face.MudWeld.Part0 == r6.Head and face.MudWeld.Part1 == face, "Face mask is welded to actual synthetic Head")
	local nonphysical = true
	for _, patch in ipairs(coating:GetChildren()) do nonphysical = nonphysical and patch.Massless and not patch.CanCollide and not patch.CanTouch and not patch.CanQuery and not patch.Anchored end
	expect(nonphysical, "Every mud patch is massless noncolliding nontouching nonquery and welded")
	controller:_mudVisual(record)
	expect(#coating:GetChildren() == 6, "Repeated mud update does not duplicate geometry")
	record.muddy = false controller:_mudVisual(record)
	expect(r6:FindFirstChild("MDMudCoating") == nil and r6.Head.Parent == r6, "Rescue removes coating while preserving body parts")
	record.muddy = true controller:_mudVisual(record)
	local outline = Instance.new("Highlight") outline.Name = "MDOutline" outline.Parent = r6
	local label = Instance.new("BillboardGui") label.Name = "MDMuddyLabel" label.Parent = r6
	controller:_restore(record)
	expect(r6:FindFirstChild("MDMudCoating") == nil and r6:FindFirstChild("MDOutline") == nil and r6:FindFirstChild("MDMuddyLabel") == nil, "Synthetic cleanup removes coating outline and label")
	expect(r6.Head.Parent == r6 and r6.Torso.Parent == r6 and root.Parent == r6, "Synthetic cleanup preserves the entire original rig")
	local r15 = Instance.new("Model") r15.Name = "SyntheticR15" r15.Parent = folder
	for index, name in ipairs({ "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do body(r15, name, Vector3.new(1.4, 1.2, 0.8), Vector3.new(index * 3, 200, 0)) end
	local r15Record = { character = r15, muddy = true }
	controller:_mudVisual(r15Record)
	expect(#r15.MDMudCoating:GetChildren() == 7, "R15 receives torso arm leg patches and face mask")
	r15Record.muddy = false controller:_mudVisual(r15Record)
	expect(r15:FindFirstChild("MDMudCoating") == nil, "R15 rescue cleans all synthetic mud geometry")
end, debug.traceback)
folder:Destroy() module:Destroy()
assert(ok, failure)
return { passed = #checks, checks = checks, readsToolForReadiness = true, mutatesTool = false, startsGameplay = false, changesCapabilities = false }
