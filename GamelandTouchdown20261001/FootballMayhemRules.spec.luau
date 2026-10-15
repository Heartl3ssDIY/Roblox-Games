local Rules = require(game.ServerScriptService.FootballMayhem.FootballMayhemRules)
local checks = 0
local function expect(condition, message)
    assert(condition, message)
    checks += 1
end
local rng = Random.new(4102026)
local state = Rules.NewPlayerState(rng, 10, 6)
expect(#state.wrong == 10, "Exactly ten private danger lanes")
for row = 1, 10 do expect(state.wrong[row] >= 1 and state.wrong[row] <= 6, "Danger lane within bounds") end
local accepted = Rules.ResolveChoice(state, 2, 1)
expect(not accepted and state.progress == 0, "Cannot skip a row")
expect(not Rules.Qualify(state), "Cannot qualify early")
accepted = Rules.ResolveChoice(state, 1, 7)
expect(not accepted and state.progress == 0, "Cannot use an invalid lane")
for row = 1, 10 do
    local safe = state.wrong[row] % 6 + 1
    local ok, outcome = Rules.ResolveChoice(state, row, safe)
    expect(ok and outcome == "Safe" and state.progress == row, "Safe choice advances one row")
    expect(not Rules.ResolveChoice(state, row, safe), "Re-entering a completed row does not advance")
end
expect(Rules.Qualify(state) and state.status == "Qualified", "Ten safe choices allow qualification")
expect(not Rules.Qualify(state), "Cannot qualify twice")
local failed = Rules.NewPlayerState(rng, 10, 6)
local ok, outcome = Rules.ResolveChoice(failed, 1, failed.wrong[1])
expect(ok and outcome == "Eliminated" and failed.progress == 0, "Wrong choice ends attempt")
expect(not Rules.ResolveChoice(failed, 1, failed.wrong[1] % 6 + 1), "No retry after failure")
for lane = 1, 6 do expect(Rules.GetLane(-40 + (lane - 1) * 16, 16, 6) == lane, "Lane center resolves correctly") end
expect(Rules.GetLane(-49, 16, 6) == nil and Rules.GetLane(49, 16, 6) == nil, "No route around sides")
expect(Rules.GetLane(-48, 16, 6) == 1 and Rules.GetLane(48, 16, 6) == 6, "Edge lanes remain valid")
local first = Rules.NewPlayerState(rng, 10, 6)
local second = Rules.NewPlayerState(rng, 10, 6)
local differing = 0
for row = 1, 10 do if first.wrong[row] ~= second.wrong[row] then differing += 1 end end
expect(differing > 0 and first.wrong ~= second.wrong, "Players receive independent danger lanes")
local survivors = 0
local trials = 12000
for _ = 1, trials do
    local trial = Rules.NewPlayerState(rng, 10, 6)
    for row = 1, 10 do
        if trial.status ~= "Active" then break end
        Rules.ResolveChoice(trial, row, 1)
    end
    if Rules.Qualify(trial) then survivors += 1 end
end
expect(survivors / trials > 0.145 and survivors / trials < 0.18, "Qualification rate matches five-sixths survival over ten rows")
return game:GetService("HttpService"):JSONEncode({checks = checks, trials = trials, qualified = survivors, qualificationRate = survivors / trials})
