-- Install as a LocalScript in StarterPlayerScripts.
-- Gameplay LocalScripts must wait for ProfileClientReady before reading state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
player:SetAttribute("ProfileClientReady", false)
local bridge = require(ReplicatedStorage:WaitForChild("ProfileClientBridge"))
if not bridge.start() then
    player:SetAttribute("ProfileClientLoadError", true)
    warn("[Profile] Failed to load saved progress; gameplay writes are disabled")
    local gui = Instance.new("ScreenGui")
    gui.Name = "ProgressLoadError"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    local panel = Instance.new("Frame")
    panel.Name = "Message"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(420, 112)
    panel.BackgroundColor3 = Color3.fromRGB(28, 19, 48)
    panel.Parent = gui
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -24, 0, 36)
    title.Position = UDim2.fromOffset(12, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 21
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = "Progress could not load"
    title.Parent = panel
    local detail = title:Clone()
    detail.Name = "Detail"
    detail.Position = UDim2.fromOffset(12, 52)
    detail.Size = UDim2.new(1, -24, 0, 46)
    detail.Font = Enum.Font.Gotham
    detail.TextSize = 16
    detail.TextWrapped = true
    detail.Text = "Please rejoin. Progression is paused to protect your saved data."
    detail.Parent = panel
    gui.Parent = player:WaitForChild("PlayerGui")
    for _ = 1, 10 do
        local ok = pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Progress unavailable",
                Text = "Progress could not load. Please rejoin.",
                Duration = 10,
            })
        end)
        if ok then break end
        task.wait(0.5)
    end
end
