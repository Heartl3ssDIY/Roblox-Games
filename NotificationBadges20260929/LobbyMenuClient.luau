local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
while player:GetAttribute("ProfileClientReady") ~= true do
    if player:GetAttribute("ProfileClientLoadError") then return end
    task.wait(0.1)
end
local playerGui = player:WaitForChild("PlayerGui")
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ShopUI = require(ReplicatedStorage:WaitForChild("ShopUI"))
local LevelPassUI = require(ReplicatedStorage:WaitForChild("LevelPassUI"))
local SeasonPassData = require(ReplicatedStorage:WaitForChild("SeasonPassData"))
local UnitsUI = require(ReplicatedStorage:WaitForChild("UnitsUI"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local screen = playerGui:WaitForChild("LobbyMenuGui")
local shopGui = playerGui:WaitForChild("ShopGui")
local overlay = shopGui:WaitForChild("MenuOverlay")
local panel = overlay:WaitForChild("MenuPanel")
local sidebar = screen:WaitForChild("Sidebar")
local currencies = sidebar:WaitForChild("CurrencyBar")
local dock = sidebar:WaitForChild("SideDock")
local passButton = sidebar:WaitForChild("BattlePass")
local badge = passButton:WaitForChild("Badge")
local passXP = passButton:WaitForChild("XPTrack")
local passLevel = passButton:WaitForChild("LevelValue")

local function formatBalance(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 10000 then return string.format("%.1fK", value / 1000) end
    return tostring(value)
end

local function refresh()
    currencies.Coins.Value.Text = formatBalance(PlayerData.coins())
    currencies.Gems.Value.Text = formatBalance(PlayerData.gems())
    currencies.Chips.Value.Text = formatBalance(PlayerData.masteryChips())
end

local function refreshPassBadge()
    badge.Visible = false
    for level = 1, SeasonPassData.LEVEL_COUNT do
        if SeasonPassData.rewardState("free", level) == "claimable"
            or SeasonPassData.rewardState("paid", level) == "claimable" then
            badge.Visible = true
            break
        end
    end
end

local function refreshPassProgress()
    local ratio = math.clamp(SeasonPassData.xp() / SeasonPassData.XP_PER_LEVEL, 0, 1)
    passLevel.Text = "LV " .. SeasonPassData.level()
    passXP.Fill.Size = UDim2.fromScale(ratio, 1)
    passXP.Orb.Position = UDim2.fromScale(ratio, .5)
    refreshPassBadge()
end

ShopUI.build(panel.Content.ShopPage)
UnitsUI.build(playerGui)
LevelPassUI.build(playerGui)
shopGui.Enabled = false
refresh()
PlayerData.Changed:Connect(refresh)
refreshPassProgress()
SeasonPassData.Changed:Connect(refreshPassProgress)

screen.PvPBtn.Activated:Connect(function()
    local success, message = ArenaTravelClient.toDestination("PvP")
    if success then
        require(ReplicatedStorage:WaitForChild("ModePickerUI")).close()
        require(ReplicatedStorage:WaitForChild("PackShopUI")).close()
        UnitsUI.close()
        LevelPassUI.close()
        shopGui.Enabled = false
    end
    if success then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title="PvP Court", Text="Ranked and Unranked modes are being configured.", Duration=4})
        end)
    else
        warn(message)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title="Travel unavailable", Text=tostring(message or "Try again."), Duration=4})
        end)
    end
end)

dock.UnitsOpen.Activated:Connect(function()
    shopGui.Enabled = false
    LevelPassUI.close()
    UnitsUI.open(playerGui)
end)

dock.ShopOpen.Activated:Connect(function()
    UnitsUI.close()
    LevelPassUI.close()
    shopGui.Enabled = true
end)

passButton.Activated:Connect(function()
    UnitsUI.close()
    shopGui.Enabled = false
    LevelPassUI.open(playerGui)
end)

panel.Header.Close.Activated:Connect(function()
    shopGui.Enabled = false
end)

