assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local module = game.ServerScriptService.PlaygroundSecretObbyService
local fixture = Instance.new("Folder")
fixture.Name = "CaveCheck20261008"
fixture.Parent = workspace
local report = {checks = {}}
local function check(name, passed)
	table.insert(report.checks, {name = name, passed = passed == true})
	assert(passed, name)
end
local ok, failure = xpcall(function()
	local api = require(module)
	local scene = workspace["Playground Lobby"].SecretCaveObby:Clone()
	scene.Parent = fixture
	scene:PivotTo(CFrame.new(2000, 100, 2000) * CFrame.Angles(0, math.rad(90), 0) * scene:GetPivot())
	local entry = workspace["Playground Lobby"].Improvements20261003.CaveAlcove.SecretPassage:Clone()
	entry.Parent = fixture
	local character = Instance.new("Model")
	character.Parent = fixture
	local root = Instance.new("Part")
	root.Name, root.Size, root.Anchored, root.CanCollide = "HumanoidRootPart", Vector3.new(2, 2, 1), true, false
	root.Parent = character
	local leg = Instance.new("Part")
	leg.Name, leg.Size, leg.Anchored, leg.CanCollide = "Left Leg", Vector3.new(1, 2, 1), true, false
	leg.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	local attrs = {PCDataReady = true}
	local player = {Parent = game.Players, Character = character}
	function player:GetAttribute(key) return attrs[key] end
	function player:SetAttribute(key, value) attrs[key] = value end
	local awards, claims = 0, 0
	local economy = {}
	function economy:ClaimSecretObbyReward()
		claims += 1
		if awards > 0 then return false, "Already claimed today" end
		awards += 1000
		return true, "1,000 coins!"
	end
	local obby = api.new(scene, entry, economy)
	local function place(position, height, name)
		leg.Name = name or "Left Leg"
		root.CFrame = CFrame.new(position + Vector3.new(0, height, 0))
		leg.CFrame = CFrame.new(position + Vector3.new(0, leg.Size.Y * 0.5, 0))
	end
	local function standing(tile, height, name)
		place(tile.top.Position + Vector3.new(0, tile.top.Size.Y * 0.5, 0), height or 3, name)
	end
	local function newRun()
		local run = {character=character, row=0, started=os.clock()-10, lastStep=-math.huge, lastPosition=root.Position}
		obby.runs[player] = run
		return run
	end
	for row = 1, 8 do obby.path[row] = 2 end
	for _, data in {{"R6 feet",3,"Left Leg"},{"R15 feet",3,"LeftFoot"},{"small avatar",0.7,"LeftFoot"},{"tall avatar",8,"LeftFoot"}} do
		standing(obby.tiles[1][2], data[2], data[3])
		local run = newRun()
		obby:_tick(0.1)
		check(data[1] .. " registers a safe tile", run.row == 1)
	end
	standing(obby.tiles[1][2], 3)
	local run = newRun()
	root.CFrame += Vector3.new(0,8,0)
	leg.CFrame += Vector3.new(0,8,0)
	run.lastPosition = root.Position
	obby:_tick(0.1)
	check("Jumping above a tile does not complete it", run.row == 0)
	standing(obby.tiles[2][2], 3)
	run = newRun()
	obby:_tick(0.1)
	check("Skipped row resets to the start", run.row == 0 and (root.Position-scene.StartPoint.Position).Magnitude < 0.1)
	standing(obby.tiles[1][1], 3)
	run = newRun()
	local wrong = obby.tiles[1][1]
	obby:_tick(0.1)
	check("Wrong tile flashes and starts collapse", wrong.failedAt ~= nil and wrong.top.Color == Color3.fromRGB(255,110,117))
	wrong.failedAt = os.clock() - 0.3
	obby:_tick(0.1)
	local absent = true
	for _, piece in wrong.pieces do absent = absent and not piece.part.CanCollide and not piece.part.CanQuery and piece.part.Transparency == 1 end
	check("All wrong-tile pieces disappear and stop colliding", absent)
	root.CFrame = CFrame.new(root.Position.X, obby.floorY-7, root.Position.Z)
	obby:_tick(0.1)
	check("Falling resets the run", run.row == 0 and (root.Position-scene.StartPoint.Position).Magnitude < 0.1)
	wrong.failedAt = os.clock() - 4
	obby:_tick(0.1)
	check("Collapsed platform returns with solid collision", wrong.failedAt == nil and wrong.top.CanCollide and wrong.top.CanQuery and wrong.top.Transparency == 0)
	for row = 1, 8 do
		standing(obby.tiles[row][2],3)
		run.lastPosition, run.lastStep = root.Position, -math.huge
		obby:_tick(0.1)
		check("Correct row " .. row .. " progresses", run.row == row and attrs.PCSecretObbyRow == row)
	end
	root.CFrame = scene.TreasureChest.Latch.CFrame + Vector3.new(20,0,0)
	obby:_claim(player)
	check("Remote chest claim rejected", claims == 0)
	root.CFrame = scene.TreasureChest.Latch.CFrame
	run.started = os.clock()-10
	obby:_claim(player)
	check("Completed path reaches daily reward service", awards == 1000 and claims == 1)
	obby:_claim(player)
	check("Daily denial is reported without extra award", awards == 1000 and attrs.PCRewardText == "Already claimed today")
	run.row = 0
	obby:_claim(player)
	check("Chest cannot award an incomplete run", claims == 2)
	root.CFrame = entry.Opening.CFrame
	attrs.PCDataReady = false
	obby:_enter(player)
	check("Loading data gets useful entrance feedback", string.find(attrs.PCRewardText,"loading",1,true) ~= nil)
	attrs.PCDataReady = true
	obby.promptTimes[player] = nil
	obby:_enter(player)
	check("Entrance teleports to start with fresh progress", obby.runs[player].row == 0 and (root.Position-scene.StartPoint.Position).Magnitude < 0.1)
	root.CFrame = scene.ReturnPortal.Opening.CFrame
	obby:_exit(player)
	check("Return portal clears active run", obby.runs[player] == nil and attrs.PCSecretObbyRow == 0)
	obby:Start()
	check("Prompt and heartbeat connections start", #obby.connections == 6)
	obby:Stop()
	check("Stopping disconnects the controller", not obby.running and #obby.connections == 0)
end, debug.traceback)
fixture:Destroy()
report.ok, report.error = ok, not ok and failure or nil
return game:GetService("HttpService"):JSONEncode(report)
