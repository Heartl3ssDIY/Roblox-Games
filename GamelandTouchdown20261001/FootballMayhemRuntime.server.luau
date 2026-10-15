local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local service = require(script.Parent.FootballMayhemService)
service.Init()
local arena = workspace:WaitForChild("Oni's Work"):WaitForChild("FootballMayhem")

if RunService:IsStudio() and arena:GetAttribute("AutoStartInStudio") then
    task.spawn(function()
        local ready = false
        while not ready do
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") then ready = true break end
            end
            if not ready then task.wait(0.25) end
        end
        task.wait(5)
        service.StartRound()
    end)
end