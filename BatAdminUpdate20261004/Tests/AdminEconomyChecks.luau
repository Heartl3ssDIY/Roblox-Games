return function(sources)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode checks only")
	sources = sources or {}
	local folder = Instance.new("Folder")
	folder.Name = "AdminEconomyChecks_" .. game:GetService("HttpService"):GenerateGUID(false)
	folder.Parent = game:GetService("ServerStorage")
	for _, entry in ipairs({
		{ "Catalog", sources.Catalog or ReplicatedStorage.PlaygroundCatalog.Source },
		{ "Economy", sources.Economy or ServerScriptService.PlaygroundEconomyService.Source },
		{ "Admin", sources.Admin or ServerScriptService.PlaygroundAdminService.Source },
	}) do
		local module = Instance.new("ModuleScript")
		module.Name = entry[1]
		module.Source = entry[2]:gsub('require%(ReplicatedStorage:WaitForChild%("PlaygroundCatalog"%)%)', 'require(script.Parent.Catalog)')
		module.Parent = folder
	end
	local passed = {}
	local ok, result = xpcall(function()
		local Catalog = require(folder.Catalog)
		local Economy = require(folder.Economy)
		local Admin = require(folder.Admin)
		local function check(name, condition)
			assert(condition, name)
			table.insert(passed, name)
		end
		local function fakePlayer(id, name)
			local player = { UserId = id, Name = name, DisplayName = name, Parent = Players, Attributes = {} }
			function player:GetAttribute(key) return self.Attributes[key] end
			function player:SetAttribute(key, value) self.Attributes[key] = value end
			function player:FindFirstChild() return nil end
			return player
		end
		local actor = fakePlayer(18237460001, "Admin")
		local target = fakePlayer(18237460002, "Target")
		local ordinary = fakePlayer(18237460003, "Ordinary")
		local fakePlayers = { list = { actor, target, ordinary } }
		function fakePlayers:GetPlayers() return table.clone(self.list) end
		function fakePlayers:GetPlayerByUserId(id)
			for _, player in ipairs(self.list) do if player.UserId == id then return player end end
		end
		local config = { AdminUserId = actor.UserId, ExtraAdminUserIds = "" }
		function config:GetAttribute(name) return self[name] end
		local lobby = { BaseLevelXP = 200, LevelXPStep = 50 }
		function lobby:GetAttribute(name) return self[name] end
		local economy = setmetatable({ lobby = lobby, profiles = {}, isStudio = true }, Economy)
		local appearances, storeWrites = 0, 0
		function economy:_applyAppearance() appearances += 1 end
		economy.store = { UpdateAsync = function() storeWrites += 1 error("Unexpected datastore write") end }
		for _, player in ipairs(fakePlayers.list) do
			economy.profiles[player] = { player = player, data = Economy.CleanData(nil), ready = true, version = 0, lastMutation = -math.huge, lastStatus = -math.huge }
			economy:_sync(economy.profiles[player])
		end
		local coordinator = { economy = economy, services = {}, autoEnabled = true, starts = 0, stops = 0 }
		function coordinator:ActiveGame() return nil end
		function coordinator:StartGame(id, player, role)
			self.starts += 1 self.lastStart = { id, player, role } return true
		end
		function coordinator:StopGame() self.stops += 1 return true, "Stopped." end
		function coordinator:SetAutoEnabled(value) self.autoEnabled = value end
		local admin = Admin.new(coordinator, config, false, fakePlayers)
		local function request(player, action, payload)
			admin.lastStatus[player] = -math.huge
			admin.lastRequest[player] = -math.huge
			return admin:Handle(player, action, payload)
		end
		local targetProfile = economy.profiles[target]
		local ordinaryProfile = economy.profiles[ordinary]
		local function targetPayload(fields)
			fields = fields or {}
			fields.targetUserId = target.UserId
			return fields
		end

		ordinary:SetAttribute("PlaygroundAdmin", true)
		local reply = request(ordinary, "GrantCoins", { targetUserId = ordinary.UserId, amount = 1000, actorUserId = actor.UserId })
		check("client admin attribute and spoofed actor ID do not authorize grants", not reply.ok and ordinaryProfile.data.Coins == 0)
		check("unauthorized responses expose no player inventory", reply.target == nil and reply.players == nil)
		check("ordinary shop endpoint rejects admin actions", not economy:Handle(ordinary, "GrantItem", "B06").ok and not ordinaryProfile.data.Owned.B06)
		check("authorized actor uses server config", admin:IsAuthorized(actor))
		config.AdminUserId = 18237460999
		check("revoked admin is denied immediately", not request(actor, "GrantCoins", targetPayload({ amount = 1 })).ok)
		config.AdminUserId = actor.UserId
		config.ExtraAdminUserIds = tostring(ordinary.UserId)
		check("existing extra-admin allowlist remains supported", admin:IsAuthorized(ordinary))
		config.ExtraAdminUserIds = ""
		check("Studio authorization is unchanged", Admin.new(coordinator, config, true, fakePlayers):IsAuthorized(ordinary))

		local before = targetProfile.data.Coins
		for _, value in ipairs({ "18237460002", false, 0, -2, 1.5, math.huge, 0 / 0, 18237469999 }) do
			reply = request(actor, "GrantCoins", { targetUserId = value, amount = 10 })
			check("reject malformed or offline target " .. tostring(value), not reply.ok and targetProfile.data.Coins == before)
		end
		check("grant requires explicit selected target", not request(actor, "GrantCoins", { amount = 10 }).ok)
		check("non-table grant payload rejected", not request(actor, "GrantCoins", 100).ok)
		reply = request(actor, "GetStatus", targetPayload())
		check("admin status includes selected target and online roster", reply.ok and reply.target.userId == target.UserId and #reply.players == 3 and reply.target.ready)
		check("status contains safe limits and copied inventory", reply.limits.coinsPerGrant == 1000000 and reply.limits.levelsPerGrant == 100 and reply.target.owned ~= targetProfile.data.Owned)
		check("default status target is the requesting admin", request(actor, "GetStatus").target.userId == actor.UserId)
		local invalidTarget = request(actor, "GetStatus", { targetUserId = false })
		check("false target does not silently fall back to self", not invalidTarget.ok and invalidTarget.target == nil and invalidTarget.targetUserId == nil)

		reply = request(actor, "GrantItem", targetPayload({ itemId = "B06", equip = true }))
		check("admin can grant locked bat without spending target coins", reply.ok and targetProfile.data.Owned.B06 and targetProfile.data.Coins == 0 and targetProfile.data.GameWins.StuckInTheMud == 0)
		check("grant and equip publishes bat and lobby preview", target:GetAttribute("PCBat") == "B06" and target:GetAttribute("PCAdminBatPreview") == true)
		reply = request(actor, "ClearPreview", targetPayload())
		check("hide bat clears preview without losing ownership or selection", reply.ok and not target:GetAttribute("PCAdminBatPreview") and targetProfile.data.Owned.B06 and targetProfile.data.Equipped.Bat == "B06")
		check("invalid catalog ID is rejected", not request(actor, "GrantItem", targetPayload({ itemId = "ServerStorage.Secret", equip = true })).ok)
		check("malformed equip toggle is rejected", not request(actor, "GrantItem", targetPayload({ itemId = "P01", equip = "yes" })).ok and not targetProfile.data.Owned.P01)
		for _, item in ipairs(Catalog.Items) do
			local granted = economy:AdminGrantItem(target, item.id, true)
			check("admin grants catalog item " .. item.id, granted and targetProfile.data.Owned[item.id] and targetProfile.data.Equipped[item.slot] == item.id)
		end
		check("catalog grants preserve total and per-game wins", targetProfile.data.Wins == 0 and targetProfile.data.GameWins.StuckInTheMud == 0 and targetProfile.data.Coins == 0)
		check("grant existing item without equip is a safe no-op", not economy:AdminGrantItem(target, "B01", false))
		check("grant and equip refreshes equipped appearance", appearances > 0)

		for _, value in ipairs({ "100", false, 0, -1, 1.2, math.huge, 0 / 0, 1000001 }) do
			reply = request(actor, "GrantCoins", targetPayload({ amount = value }))
			check("reject invalid coin amount " .. tostring(value), not reply.ok and targetProfile.data.Coins == 0)
		end
		reply = request(actor, "GrantCoins", targetPayload({ amount = 1000000 }))
		check("coin grant adds exact bounded amount", reply.ok and targetProfile.data.Coins == 1000000 and reply.target.coins == 1000000)
		local duplicate = admin:Handle(actor, "GrantCoins", targetPayload({ amount = 10 }))
		check("rate limit prevents immediate duplicate grants", not duplicate.ok and targetProfile.data.Coins == 1000000)
		targetProfile.data.Coins = 999999999
		check("balance cap rejects overflow atomically", not request(actor, "GrantCoins", targetPayload({ amount = 2 })).ok and targetProfile.data.Coins == 999999999)
		check("exact coin cap accepted", request(actor, "GrantCoins", targetPayload({ amount = 1 })).ok and targetProfile.data.Coins == 1000000000)
		targetProfile.data.Coins = 0

		for _, value in ipairs({ "4", false, 0, -1, 1.2, math.huge, 0 / 0, 101 }) do
			check("reject invalid level amount " .. tostring(value), not request(actor, "AddLevels", targetPayload({ amount = value })).ok and targetProfile.data.XP == 0)
		end
		ordinaryProfile.data.XP = 50
		reply = request(actor, "AddLevels", { targetUserId = ordinary.UserId, amount = 4 })
		local level, progress = economy:LevelProgress(ordinaryProfile.data.XP)
		check("adding levels preserves current level XP progress", reply.ok and level == 5 and progress == 50 and ordinaryProfile.data.XP == 1150)
		check("level grant earns automatic level rewards", ordinaryProfile.data.Owned.B03 and ordinaryProfile.data.Owned.P02)
		check("level grant does not fabricate game wins", ordinaryProfile.data.Wins == 0 and ordinaryProfile.data.GameWins.StuckInTheMud == 0 and not ordinaryProfile.data.Owned.B06)
		local completed = 998
		targetProfile.data.XP = completed * 200 + 50 * completed * (completed - 1) / 2
		local capXP = targetProfile.data.XP
		check("admin level cap rejects overflow atomically", not request(actor, "AddLevels", targetPayload({ amount = 2 })).ok and targetProfile.data.XP == capXP)
		check("exact level cap accepted", request(actor, "AddLevels", targetPayload({ amount = 1 })).ok and economy:LevelProgress(targetProfile.data.XP) == 1000)

		targetProfile.ready = false
		check("unloaded target cannot receive coins", not request(actor, "GrantCoins", targetPayload({ amount = 1 })).ok and targetProfile.data.Coins == 0)
		check("unloaded target cannot receive items", not request(actor, "GrantItem", targetPayload({ itemId = "B01", equip = true })).ok)
		targetProfile.ready = true
		targetProfile.closed = true
		check("closed profile cannot receive levels", not request(actor, "AddLevels", targetPayload({ amount = 1 })).ok)
		targetProfile.closed = false
		targetProfile.released = true
		check("released profile cannot receive coins", not request(actor, "GrantCoins", targetPayload({ amount = 1 })).ok)
		targetProfile.released = false
		target.Parent = nil
		check("departed player cannot receive a grant", not economy:AdminGrantCoins(target, 1))
		target.Parent = Players
		check("normal game controls still route through coordinator", request(actor, "BBBulldog").ok and coordinator.starts == 1 and coordinator.lastStart[1] == "BritishBulldog" and coordinator.lastStart[3] == "Bulldog")
		check("stop control preserved", request(actor, "StopRound").ok and coordinator.stops == 1)
		check("automatic voting toggle preserved", request(actor, "ToggleAutomatic").ok and coordinator.autoEnabled == false)
		check("grants use existing dirty profile save lifecycle", targetProfile.dirty == true and targetProfile.version > 0 and storeWrites == 0)
		return { passed = #passed, checks = passed, catalogItems = #Catalog.Items, playStarted = false, dataStoreWrites = storeWrites, realPlayersMutated = 0 }
	end, debug.traceback)
	folder:Destroy()
	assert(ok, result)
	return result
end
