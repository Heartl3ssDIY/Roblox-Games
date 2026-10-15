return function(candidateSource)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local Players = game:GetService("Players")
	local fixture = Instance.new("Folder")
	fixture.Name = "_CoinPickupChecks"
	fixture.Parent = game.ServerStorage
	local source = game.ServerScriptService.PlaygroundEconomyService
	local module = source:Clone()
	module.Source = candidateSource or module.Source
	module.Parent = fixture
	local report = { checks = {}, playStarted = false, dataStoreWrites = 0, realPlayersMutated = 0 }
	local economies = {}
	local function check(name, value) assert(value, name) table.insert(report.checks, name) end
	local ok, problem = xpcall(function()
		local Economy = require(module)
		check("exact live permissions retained", module.Capabilities == source.Capabilities and module.Sandboxed == source.Sandboxed)
		report.capabilities = tostring(module.Capabilities)
		local lobby = Instance.new("Model")
		lobby.Parent = fixture
		local gameplay = Instance.new("Folder")
		gameplay.Name = "Gameplay"
		gameplay.Parent = lobby
		local origin = Vector3.new(100000, 500, 100000)
		local bounds = Instance.new("Part")
		bounds.Name = "LobbyBounds"
		bounds.Size = Vector3.new(200, 100, 200)
		bounds.Position = origin
		bounds.Parent = gameplay
		local spawns = Instance.new("Folder")
		spawns.Name = "CoinSpawns"
		spawns.Parent = gameplay
		for index, value in ipairs({ 1, 10 }) do
			local marker = Instance.new("Part")
			marker.Name = "Pickup" .. index
			marker.Position = origin + Vector3.new((index - 1) * 30, 0, 0)
			marker:SetAttribute("Value", value)
			marker:SetAttribute("RespawnSeconds", index == 1 and 45 or 75)
			marker.Parent = spawns
		end
		local fakeStore = {}
		function fakeStore:UpdateAsync() report.dataStoreWrites += 1 error("Unexpected data-store write") end
		local economy = Economy.new(lobby, fakeStore, true)
		table.insert(economies, economy)
		economy:_buildCoins()
		check("one imported visual per spawn", #economy.coins == 2 and economy.coins[1].visual:IsA("Model"))
		for _, entry in ipairs(economy.coins) do check(entry.id .. " always awards five regardless of legacy marker Value", entry.value == 5) end
		local coin
		for _, entry in ipairs(economy.coins) do if entry.marker.Name == "Pickup1" then coin = entry end end
		assert(coin)
		check("authored respawn delay retained", coin.cooldown == 45)
		local originalParts = {}
		for _, object in ipairs(coin.visual:GetDescendants()) do
			if object:IsA("BasePart") then originalParts[object] = object.Transparency end
		end
		check("actual imported coin has visible geometry", next(originalParts) ~= nil)
		local function profile(id)
			local character = Instance.new("Model")
			character.Parent = fixture
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = origin
			root.Parent = character
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			local player = { UserId = id, Character = character, Parent = Players, attributes = {}, writes = {} }
			function player:GetAttribute(key) return self.attributes[key] end
			function player:SetAttribute(key, value) self.attributes[key] = value table.insert(self.writes, key) end
			function player:FindFirstChild() return nil end
			local value = { player = player, data = Economy.CleanData({ Coins = 100 }), ready = true, version = 0, connections = {}, pickups = {} }
			economy.profiles[player] = value
			return value, player, root, humanoid
		end
		local first, player, root, humanoid = profile(90101)
		local second, other = profile(90102)
		player.attributes.PCRewardSerial = 10
		player.attributes.PCRewardAt = 123
		player.attributes.PCRewardText = "Existing round reward"
		local now = workspace:GetServerTimeNow()
		local pickupPosition = coin.visual:GetPivot().Position
		check("nearby live lobby player collects", economy:_collectCoin(first, coin, now))
		check("exactly five coins credited through profile sync", first.data.Coins == 105 and player.attributes.PCCoins == 105 and first.dirty and first.version == 1)
		check("entire imported visual disappears", coin.visual.Parent == economy.hiddenCoins and not coin.visual:IsDescendantOf(workspace))
		for object, transparency in pairs(originalParts) do
			check("hidden geometry remains intact " .. object.Name, object:IsDescendantOf(economy.hiddenCoins) and object.Transparency == transparency)
		end
		check("respawn time is server owned", coin.availableAt == now + 45)
		check("pickup event publishes amount and actual world position", player.attributes.PCCoinPickupAmount == 5 and player.attributes.PCCoinPickupPosition == pickupPosition and player.attributes.PCCoinPickupSerial == 1)
		local writes = player.writes
		check("pickup serial written after complete payload", writes[#writes - 2] == "PCCoinPickupAmount" and writes[#writes - 1] == "PCCoinPickupPosition" and writes[#writes] == "PCCoinPickupSerial")
		check("pickup leaves large reward toast channel unchanged", player.attributes.PCRewardSerial == 10 and player.attributes.PCRewardAt == 123 and player.attributes.PCRewardText == "Existing round reward")
		check("repeat contact cannot double award", not economy:_collectCoin(first, coin, now + 0.1) and first.data.Coins == 105)
		check("second player cannot claim unavailable coin", not economy:_collectCoin(second, coin, now + 0.1) and second.data.Coins == 100 and other.attributes.PCCoinPickupSerial == nil)
		local function tickWithoutPlayers()
			local profiles = economy.profiles
			economy.profiles = {}
			economy.lastSave = os.clock()
			economy:_tick(0.2)
			economy.profiles = profiles
		end
		tickWithoutPlayers()
		check("cooldown tick keeps coin hidden", coin.visual.Parent == economy.hiddenCoins)
		coin.availableAt = workspace:GetServerTimeNow() - 1
		tickWithoutPlayers()
		check("expired coin respawns at marker", coin.visual.Parent == economy.effects and (coin.visual:GetPivot().Position - coin.marker.Position).Magnitude <= 0.31)
		for object, transparency in pairs(originalParts) do check("respawn restores intact geometry " .. object.Name, object:IsDescendantOf(economy.effects) and object.Transparency == transparency) end
		check("respawn is available to another player", economy:_collectCoin(second, coin, workspace:GetServerTimeNow()) and second.data.Coins == 105)
		local function respawn()
			coin.availableAt = workspace:GetServerTimeNow() - 1
			tickWithoutPlayers()
		end
		respawn()
		for _, rule in ipairs({ { first, "ready", false }, { first, "closed", true }, { first, "released", true }, { player, "Parent", nil } }) do
			local object, key, value = rule[1], rule[2], rule[3]
			local previous = object[key]
			object[key] = value
			check("reject invalid profile " .. key, not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()))
			object[key] = previous
		end
		for _, flag in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
			player.attributes[flag] = true
			check("reject active game " .. flag, not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()))
			player.attributes[flag] = nil
		end
		root.Position = origin + Vector3.new(6, 0, 0)
		check("reject out of pickup range", not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()))
		root.Position = origin + Vector3.new(500, 0, 0)
		check("reject outside lobby", not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()))
		root.Position = origin
		humanoid.Health = 0
		check("reject dead character", not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()))
		humanoid.Health = 100
		first.data.Coins = 999999996
		check("full five must fit balance limit", not economy:_collectCoin(first, coin, workspace:GetServerTimeNow()) and coin.visual.Parent == economy.effects)
		first.data.Coins = 999999995
		check("exact cap awards full five", economy:_collectCoin(first, coin, workspace:GetServerTimeNow()) and first.data.Coins == 1000000000)
		check("pickup serial increases across respawn", player.attributes.PCCoinPickupSerial == 2)
		first.data.Coins = 100
		check("admin coin grant retains reward toast", economy:AdminGrantCoins(player, 7) and player.attributes.PCRewardCoins == 7 and player.attributes.PCRewardAt ~= 123)
		check("round award retains reward toast", economy:AwardRound("BB:CoinPickupCheck", { player.UserId }, false, { player.UserId }) == 1 and player.attributes.PCRewardCoins == 150 and player.attributes.PCRewardXP == 50 and player.attributes.PCRewardWon == true)
		check("other reward channels do not trigger pickup popup", player.attributes.PCCoinPickupSerial == 2)
		local oldUnlockSerial = first.unlockSerial or 0
		first.data.XP = 100000
		economy:_touch(first)
		check("level unlock publication preserved", (first.unlockSerial or 0) > oldUnlockSerial and player.attributes.PCUnlockSerial == first.unlockSerial)
		check("isolated checks never write data store", report.dataStoreWrites == 0)
		for _, value in ipairs(economies) do value:Stop() end
		check("cleanup destroys active and hidden coin containers", economy.effects.Parent == nil and economy.hiddenCoins.Parent == nil)
	end, debug.traceback)
	for _, economy in ipairs(economies) do
		if economy.effects.Parent then economy.effects:Destroy() end
		if economy.hiddenCoins.Parent then economy.hiddenCoins:Destroy() end
	end
	fixture:Destroy()
	report.passed = ok
	report.error = not ok and problem or nil
	report.fixtureDestroyed = fixture.Parent == nil
	return report
end
