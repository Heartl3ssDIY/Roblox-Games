local ServerScriptService = game:GetService("ServerScriptService")
local source = ServerScriptService:WaitForChild("TagService")
local module = source:Clone()
module.Name = "TagFixtureModule"
module.Parent = ServerScriptService
local fixture = Instance.new("Folder")
fixture.Name = "TagFixture"
fixture.Parent = workspace
local checks = {}
local function check(name, condition)
	assert(condition, name)
	table.insert(checks, name)
end

local ok, result = xpcall(function()
	local Service = require(module)
	local provider = game:GetService("PhysicsService")
	if pcall(function() workspace:IsCollisionGroupRegistered("TGPlayer") end) then provider = workspace end
	if not provider:IsCollisionGroupRegistered("TGPlayer") then provider:RegisterCollisionGroup("TGPlayer") end
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = fixture
	local gameplay = Instance.new("Folder")
	gameplay.Name = "Gameplay"
	gameplay.Parent = arena
	local function part(name, parent, position, size)
		local object = Instance.new("Part")
		object.Name = name
		object.Anchored = true
		object.CanCollide = false
		object.CanQuery = false
		object.Position = position
		object.Size = size or Vector3.new(2, 1, 2)
		object.Parent = parent
		return object
	end
	local center = Vector3.new(0, 1000, 0)
	part("ArenaBounds", gameplay, center, Vector3.new(416, 100, 416))
	part("TaggerSpawn", gameplay, center)
	local pads = Instance.new("Folder")
	pads.Name = "StartPads"
	pads.Parent = gameplay
	part("01", pads, center + Vector3.new(100, 0, 0))
	part("02", pads, center + Vector3.new(-100, 0, 0))
	local service = Service.new(arena)
	service.state = Instance.new("Folder")
	service.state.Parent = fixture
	service.running = true
	service.active = true
	service.phase = "Playing"
	service.endsAt = workspace:GetServerTimeNow() + 180
	service.tagCount = 0
	local now = workspace:GetServerTimeNow()
	local function participant(name, index, position)
		local attrs = {}
		local player = { DisplayName = name, UserId = index }
		function player:GetAttribute(key) return attrs[key] end
		function player:SetAttribute(key, value) attrs[key] = value end
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = fixture
		local root = part("HumanoidRootPart", model, position, Vector3.new(2, 2, 1))
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.Parent = model
		local record = service:_record(player, true)
		record.character, record.root, record.humanoid = model, root, humanoid
		record.ready, record.participating = true, true
		record.spawnIndex = index
		return record
	end
	local first = participant("First", 1, center)
	local second = participant("Second", 2, center + Vector3.new(3, 0, 0))
	service.tagger = first
	service:_role(first, "Tagger")
	service:_role(second, "Runner")
	check("Exactly one tagger and one runner", service:_counts() == 2 and first.role == "Tagger" and second.role == "Runner")
	check("Tagger speed18 runner16", first.humanoid.WalkSpeed == 18 and second.humanoid.WalkSpeed == 16)
	check("Cartoon outlines exist", first.character.TGOutline and second.character.TGOutline)
	check("Nearby unobstructed tag allowed", service:_canTag(first, second, now))
	second.root.Position = center + Vector3.new(8, 0, 0)
	check("Distant tag refused", not service:_canTag(first, second, now))
	second.root.Position = center + Vector3.new(3, 0, 0)
	local wall = part("Wall", fixture, center + Vector3.new(1.5, 0, 0), Vector3.new(0.5, 8, 8))
	wall.CanCollide, wall.CanQuery = true, true
	check("Tags through walls refused", not service:_canTag(first, second, now))
	wall:Destroy()
	second.protectedEndsAt = now + 2
	check("Protected runner cannot be tagged", not service:_canTag(first, second, now))
	second.protectedEndsAt = 0
	first.tagCooldownEndsAt = now + 1
	check("Incoming tagger cooldown prevents tag", not service:_canTag(first, second, now))
	first.tagCooldownEndsAt = 0
	service.lastAccountAt = now - 4
	service:_transfer(second, now)
	check("Tag changes hands without infection", first.role == "Runner" and second.role == "Tagger" and service.tagger == second)
	check("Outgoing tagger has2s protection", first.protectedEndsAt == now + 2)
	check("Incoming tagger has1.2s cooldown", math.abs(second.tagCooldownEndsAt - now - 1.2) < 0.001)
	check("Tagger time accounted at transfer", math.abs(first.taggerSeconds - 4) < 0.001)
	check("One successful tag counted", service.tagCount == 1 and first.tagsMade == 1)
	check("Immediate tag back refused", not service:_canTag(second, first, now + 0.5))
	check("Tag back possible after protection expires", service:_canTag(second, first, now + 2.1))
	service:_account(now + 5)
	check("New holder receives its own elapsed time", math.abs(second.taggerSeconds - 5) < 0.001)
	local losers = Service.SelectLosers(service.records, "MostTaggerTime", second)
	check("Highest tagger time loses", losers[second] == true and not losers[first])
	losers = Service.SelectLosers(service.records, "LastTagger", first)
	check("LastTagger rule independent of score", losers[first] == true and not losers[second])
	first.taggerSeconds = 5
	losers = Service.SelectLosers(service.records, "MostTaggerTime", second)
	check("Exact score ties treat tied players equally", losers[first] and losers[second])
	first.taggerSeconds, second.taggerSeconds = 0, 0
	losers = Service.SelectLosers(service.records, "MostTaggerTime", second)
	check("No scoring time loses current tagger only", losers[second] and not losers[first])
	first.taggerSeconds, second.taggerSeconds = 5, 5
	second.participating = false
	losers = Service.SelectLosers(service.records, "MostTaggerTime", second)
	check("Disconnected participants excluded from result", losers[first] and not losers[second])
	second.participating = true
	second.taggerSeconds = 0
	service.lastAccountAt = now
	service.initialGraceEndsAt = now + 8
	service:_account(now + 5)
	check("Initial grace excludes early holding time", second.taggerSeconds == 0)
	service:_account(now + 10)
	check("Initial grace only excludes its first8s", math.abs(second.taggerSeconds - 2) < 0.001)
	service:_transfer(first, now + 10)
	check("First transfer ends scoring grace", service.initialGraceEndsAt == 0)
	service.phase = "Countdown"
	check("Countdown tags refused", not service:_canTag(first, second, now + 14))
	service.phase = "Playing"
	check("Tags after end refused", not service:_canTag(first, second, service.endsAt + 1))
	check("Unknown move refused", service:Move(first.player, "Teleport") == false)
	check("Bots cannot use player movement remote", service:Move(first.player, "Dodge") == false)
	first.root.Position = center + Vector3.new(220, 0, 0)
	first.lastGoodCFrame = CFrame.new(center + Vector3.new(100, 0, 0))
	service:_keepLegal(first)
	check("Out-of-bounds participant restored inside", (first.root.Position - (center + Vector3.new(100, 0, 0))).Magnitude < 0.01)
	service:_restore(first)
	check("Original movement restored", first.humanoid.WalkSpeed == 16 and first.originalMovement == nil)
	check("Game outline removed on restoration", not first.character:FindFirstChild("TGOutline"))
	local oldToken, newToken = {}, {}
	service.currentRound = newToken
	service:_cleanup(oldToken)
	check("Stale cleanup cannot affect new round", service.currentRound == newToken and service.active)
	return { passed = #checks, checks = checks }
end, debug.traceback)
fixture:Destroy()
module:Destroy()
if not ok then error(result) end
return result
