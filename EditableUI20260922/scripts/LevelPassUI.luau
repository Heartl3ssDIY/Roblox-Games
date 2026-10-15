local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local LevelPassUI = {}
local gui
local refs
local rows = {}

local function rewardText(reward)
    local parts = {}
    if reward.coins then table.insert(parts, "🪙 " .. reward.coins) end
    if reward.gems then table.insert(parts, "💎 " .. reward.gems) end
    if reward.masteryChips then table.insert(parts, "◈ " .. reward.masteryChips) end
    return table.concat(parts, "   ")
end

local function refresh()
    if not refs then return end
    local level = PlayerData.level()
    refs.Level.Text = "Level " .. level
    refs.XP.Fill.Size = UDim2.fromScale(math.clamp(PlayerData.xp() / PlayerData.xpNeeded(), 0, 1), 1)
    refs.XP.Value.Text = PlayerData.xp() .. " / " .. PlayerData.xpNeeded() .. " XP"
    for number = 2, math.max(level + 8, 10) do
        local row = rows[number]
        if not row then
            row = refs.RowTemplate:Clone()
            row.Name = "Level_" .. number
            row.Visible = true
            row.LayoutOrder = number
            row.Parent = refs.Track
            rows[number] = row
            row.Claim.Activated:Connect(function()
                if PlayerData.levelRewardState(number) == "claimable" then
                    PlayerData.claimLevelReward(number)
                end
            end)
        end
        local state = PlayerData.levelRewardState(number)
        row.LevelBadge.Value.Text = tostring(number)
        row.Reward.Text = rewardText(PlayerData.levelReward(number))
        row.Claim.Text = state == "claimable" and "Claim" or state == "claimed" and "✓ Claimed" or "Locked"
        row.Claim.Active = state == "claimable"
        row.Claim.AutoButtonColor = state == "claimable"
    end
end

function LevelPassUI.build(playerGui)
    if gui then return gui end
    gui = playerGui:WaitForChild("BattlePassGui")
    local panel = gui:WaitForChild("Panel")
    refs = {
        Level = panel.Level,
        XP = panel.XP,
        Track = panel.Track,
        RowTemplate = gui.Templates.RewardRow,
    }
    panel.Close.Activated:Connect(LevelPassUI.close)
    gui.Dim.Activated:Connect(LevelPassUI.close)
    gui.Enabled = false
    PlayerData.Changed:Connect(refresh)
    refresh()
    return gui
end

function LevelPassUI.open(playerGui)
    LevelPassUI.build(playerGui)
    refresh()
    gui.Enabled = true
end

function LevelPassUI.close()
    if gui then gui.Enabled = false end
end

function LevelPassUI.isOpen()
    return gui ~= nil and gui.Enabled
end

return LevelPassUI
