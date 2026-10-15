from pathlib import Path

root = Path(__file__).parent
source = (root / 'Before/PlaygroundEconomyService.luau').read_text(encoding='utf-8-sig')
anchor = '\tfor gameId in pairs(games) do\n\t\tresult.GameWins'
assert source.count(anchor) == 1
source = source.replace(anchor, '\tresult.SecretObbyClaimDay = integer(value.SecretObbyClaimDay, 0)\n' + anchor)
source = source.replace('player:SetAttribute("PCCoins", profile.data.Coins)', 'player:SetAttribute("PCCoins", profile.data.Coins)\n\tplayer:SetAttribute("PCSecretObbyClaimDay", profile.data.SecretObbyClaimDay)')
method = '''function Economy:ClaimSecretObbyReward(player)
	local profile = self.profiles[player]
	if player.Parent ~= Players or not profile or not profile.ready or profile.closed or profile.released then
		return false, "Your coins are still loading. Try again in a moment."
	end
	if inGame(player) then return false, "Finish your round first." end
	local day = math.floor(os.time() / 86400)
	if integer(profile.data.SecretObbyClaimDay, 0) >= day then
		return false, "Trail complete! Today's prize is already collected. Come back tomorrow."
	end
	if profile.data.Coins > adminLimits.maxCoins - 1000 then return false, "Your coin balance is full." end
	profile.data.SecretObbyClaimDay = day
	profile.data.Coins += 1000
	self:_touch(profile)
	self:_publishReward(profile, 1000, 0, false, false)
	task.spawn(function() self:_save(profile, false) end)
	return true, "Secret Steps complete! +1,000 coins."
end

'''
anchor = 'function Economy:AdminGrantCoins(player, amount)'
assert source.count(anchor) == 1
source = source.replace(anchor, method + anchor)
(root / 'After').mkdir(exist_ok=True)
(root / 'After/PlaygroundEconomyService.luau').write_text(source, encoding='utf-8')
source = (root / 'Before/PlaygroundBootstrap.luau').read_text(encoding='utf-8-sig')
anchor = 'economy:Start()\n'
assert source.count(anchor) == 1
source = source.replace(anchor, anchor + '''local lobbyActivities = {}
local function startLobbyActivity(name, create)
	local ok, activity = pcall(function() return create(require(ServerScriptService:FindFirstChild(name))) end)
	if ok then table.insert(lobbyActivities, activity) else warn("Lobby activity unavailable: " .. name .. " - " .. tostring(activity)) end
end
startLobbyActivity("PlaygroundSecretObbyService", function(module)
	return module.new(lobby.SecretCaveObby, lobby.Improvements20261003.CaveAlcove.SecretPassage, economy):Start()
end)
startLobbyActivity("PlaygroundLobbySwingService", function(module) return module.Start() end)
startLobbyActivity("PlaygroundLobbyBenchService", function(module) return module.Start() end)
script.Destroying:Connect(function()
	for _, activity in lobbyActivities do activity:Stop() end
end)
''')
(root / 'After/PlaygroundBootstrap.luau').write_text(source, encoding='utf-8')
print('Prepared daily reward and adventure startup patches.')
