local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ShopUI = require(ReplicatedStorage:WaitForChild("ShopUI"))
local LevelPassUI = require(ReplicatedStorage:WaitForChild("LevelPassUI"))
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

local function formatBalance(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 10000 then return string.format("%.1fK", value / 1000) end
    return tostring(value)
end

local function refresh()
    currencies.Coins.Value.Text = formatBalance(PlayerData.coins())
    currencies.Gems.Value.Text = formatBalance(PlayerData.gems())
    currencies.Chips.Value.Text = formatBalance(PlayerData.masteryChips())
    local count = PlayerData.unclaimedLevelCount()
    badge.Visible = count > 0
    badge.Text = tostring(count)
end

ShopUI.build(panel.Content.ShopPage)
UnitsUI.build(playerGui)
LevelPassUI.build(playerGui)
shopGui.Enabled = false
refresh()
PlayerData.Changed:Connect(refresh)

screen.PvPBtn.Activated:Connect(function()
    local success, message = ArenaTravelClient.toDestination("PvP")
    if not success then warn(message) end
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
