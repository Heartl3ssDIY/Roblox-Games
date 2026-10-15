local service = require(game.ServerScriptService.FootballMayhem.FootballMayhemService)
local rules = require(game.ServerScriptService.FootballMayhem.FootballMayhemRules)
local original = rules.NewPlayerState
local remote = Instance.new("RemoteFunction")
remote.Name = "FootballMovementTest"
remote.Parent = game.ReplicatedStorage
remote.OnServerInvoke = function(player, command)
    if command == "Begin" then
        rules.NewPlayerState = function(rng, rows, lanes)
            local state = original(rng, rows, lanes)
            for row = 1, rows do state.wrong[row] = 6 end
            return state
        end
        local ok, message = service.StartRound({player})
        rules.NewPlayerState = original
        return ok, message
    elseif command == "Stop" then
        return service.StopRound()
    elseif command == "Return" then
        service.ReturnPlayer(player)
        return true
    end
end
