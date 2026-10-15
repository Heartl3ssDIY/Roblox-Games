local service = require(game:GetService("ServerScriptService"):WaitForChild("FootballMayhem").FootballMayhemService)
service.Init()
local arena = workspace:WaitForChild("Oni's Work"):WaitForChild("FootballMayhem")

return {
    DisplayName = "Football Mayhem",
    Description = "Carry your football through 10 rows. Six choices per row, one personal danger lane. Reach the end to qualify.",
    Badge = "FM",
    Start = service.StartRound,
    Stop = service.StopRound,
    ReleasePlayer = service.ReturnPlayer,
    Summary = service.GetRoundSummary,
    InspectionCFrame = function()
        return arena.StartPads.Start2.CFrame + Vector3.new(0, 4, 0)
    end,
}
