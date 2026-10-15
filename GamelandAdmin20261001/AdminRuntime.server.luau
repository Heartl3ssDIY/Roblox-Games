local Players = game:GetService("Players")
local service = require(script.Parent.AdminService)
local remote = game:GetService("ReplicatedStorage"):WaitForChild("GamelandAdmin"):WaitForChild("Request")

local function setup(player)
    player:SetAttribute("GamelandAdmin", service.IsAdmin(player))
    player.CharacterAdded:Connect(function()
        player:SetAttribute("AdminInspecting", nil)
    end)
end
Players.PlayerAdded:Connect(setup)
for _, player in ipairs(Players:GetPlayers()) do setup(player) end

remote.OnServerInvoke = function(player, request)
    local ok, result = pcall(service.Handle, player, request)
    if ok then return result end
    warn("Gameland admin action failed:", result)
    return {ok = false, message = "The action could not finish. Check Studio Output for details."}
end
