from pathlib import Path

root = Path(__file__).resolve().parent

def replace_once(source, before, after):
    assert source.count(before) == 1, before
    return source.replace(before, after, 1)

economy = (root / 'Before/ServerScriptService.PlaygroundEconomyService.luau').read_text(encoding='utf-8-sig')
economy = replace_once(economy, 'function Economy:_claim(profile)', '''function Economy:_publishLeaderboard(userId, snapshot)
	if not self.leaderboards then return end
	local ok, err = pcall(function() self.leaderboards:PublishSaved(userId, snapshot) end)
	if not ok then warn("Leaderboard update delayed: " .. tostring(err)) end
end

function Economy:_claim(profile)''')
economy = replace_once(economy, '''		profile.data = cleanData(value)
		profile.ready = true
		return true''', '''		profile.data = cleanData(value)
		profile.ready = true
		self:_publishLeaderboard(profile.player.UserId, profile.data)
		return true''')
economy = replace_once(economy, '\tif saved and version == profile.version then profile.dirty = false end', '''	if saved and version == profile.version then profile.dirty = false end
	if saved then self:_publishLeaderboard(profile.player.UserId, snapshot) end''')
economy = replace_once(economy, '''		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
	end)''', '''		while pending > 0 and os.clock() < untilTime do task.wait(0.1) end
		if pending == 0 and self.leaderboards then
			pcall(function() self.leaderboards:Flush(2) end)
		end
	end)''')
(root / 'PlaygroundEconomyService.lua').write_text(economy, encoding='utf-8')

bootstrap = (root / 'Before/ServerScriptService.PlaygroundBootstrap.luau').read_text(encoding='utf-8-sig')
bootstrap = replace_once(bootstrap, '''local economy = Economy.new(lobby)
economy:Start()''', '''local economy = Economy.new(lobby)
local leaderboardModule = ServerScriptService:FindFirstChild("PlaygroundLeaderboardService")
if leaderboardModule and lobby:FindFirstChild("Leaderboards") then
	local ok, result = pcall(function()
		local Leaderboards = require(leaderboardModule)
		return Leaderboards.new(lobby):Start()
	end)
	if ok then
		economy.leaderboards = result
		script.Destroying:Connect(function() result:Stop() end)
	else
		warn("Lobby leaderboards could not start: " .. tostring(result))
	end
end
economy:Start()''')
(root / 'PlaygroundBootstrap.server.luau').write_text(bootstrap, encoding='utf-8')
print('Prepared economy and bootstrap integration from verified native snapshots.')
