assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local original = game.ServerScriptService.PlaygroundEconomyService
local fixture = Instance.new("Folder")
fixture.Name = "_NativeLeaderstatsAudit"
fixture.Parent = game.ServerStorage
local player = Instance.new("Folder")
player.Name = "NativeLeaderstatsFixture"
player.Parent = fixture
local checks = {}
local function check(name, condition) assert(condition, name) table.insert(checks, name) end
local economy
local ok, problem = xpcall(function()
	local module = original:Clone()
	module.Name = "EconomyAudit"
	module.Parent = fixture
	check("exact live economy capabilities and sandbox", module.Capabilities == original.Capabilities and module.Sandboxed == original.Sandboxed)
	local Economy = require(module)
	local bindSource = assert(original.Source:match("function Economy:_bindPlayer%(player%)(.-)\nfunction Economy:Status"), "Native player binding missing")
	local statSource = assert(bindSource:match('(\tlocal board = player:FindFirstChild%("leaderstats"%).-)\n\tself:_sync%(profile%)'), "Native stat construction missing")
	local binding = module:Clone()
	binding.Name = "NativeStatConstruction"
	binding.Source = "return function(player)\n" .. statSource .. "\nend"
	binding.Parent = fixture
	local bindStats = require(binding)
	local lobby = Instance.new("Folder")
	lobby:SetAttribute("BaseLevelXP", 200)
	lobby:SetAttribute("LevelXPStep", 50)
	lobby.Parent = fixture
	economy = setmetatable({ lobby = lobby, profiles = {}, running = false, isStudio = true }, Economy)
	function economy:_claim() error("Test must not claim a profile") end
	function economy:_save() error("Test must not save a profile") end
	bindStats(player)
	local profile = { player = player, ready = false, version = 0, connections = {}, data = { Wins = 0, Coins = 0, XP = 0, Owned = { B01 = true }, Equipped = {}, GameWins = { BritishBulldog = 0, TagYoureIt = 0, StuckInTheMud = 0 } } }
	economy.profiles[player] = profile
	economy:_sync(profile)
	local board = player:FindFirstChild("leaderstats")
	check("native lowercase leaderstats folder created", board and board:IsA("Folder"))
	local children = board:GetChildren()
	check("only Wins Level Coins in requested creation order", #children == 3 and children[1].Name == "Wins" and children[2].Name == "Level" and children[3].Name == "Coins")
	for _, name in ipairs({ "Wins", "Level", "Coins" }) do check(name .. " is a native integer column", board[name]:IsA("IntValue")) end
	check("default displayed values are consistent", board.Wins.Value == 0 and board.Level.Value == 1 and board.Coins.Value == 0)
	profile.ready = true
	profile.data.Wins, profile.data.Coins, profile.data.XP = 37, 155, 950
	economy:_sync(profile)
	local expectedLevel = economy:LevelProgress(950)
	check("profile wins update native Wins", board.Wins.Value == 37 and player:GetAttribute("PCWins") == 37)
	check("profile balance updates native Coins", board.Coins.Value == 155 and player:GetAttribute("PCCoins") == 155)
	check("earned XP updates native Level", board.Level.Value == expectedLevel and player:GetAttribute("PCLevel") == expectedLevel)
	profile.data.Coins -= 50
	economy:_touch(profile)
	check("store spend updates same native Coins instance", board.Coins == children[3] and board.Coins.Value == 105)
	profile.data.Coins += 5
	economy:_touch(profile)
	check("five coin increment reaches native list", board.Coins.Value == 110 and player:GetAttribute("PCCoins") == 110)
	bindStats(player)
	check("rebinding does not duplicate native stat columns", #board:GetChildren() == 3 and economy.profiles[player] == profile)
	check("fixture is a folder outside live Players service", player:IsA("Folder") and not player:IsDescendantOf(game.Players))
end, debug.traceback)
if economy then
	for _, profile in pairs(economy.profiles) do for _, connection in ipairs(profile.connections) do connection:Disconnect() end end
end
player:Destroy()
fixture:Destroy()
return game:GetService("HttpService"):JSONEncode({ passed = ok, error = not ok and problem or nil, checks = checks, fixtureDestroyed = fixture.Parent == nil, playerDestroyed = player.Parent == nil, noPlayStartedOrStopped = true, dataStoreCalls = 0, sourceChanges = 0 })
