local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local ProfileClientBridge = require(ReplicatedStorage:WaitForChild("ProfileClientBridge"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local player = Players.LocalPlayer

local StatsUI = {}
local gui
local panel
local nameText
local avatar
local leagueFrame
local values = {}

local function whole(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.max(0, math.floor(value))
end

local function formatCount(value)
    local digits = tostring(whole(value))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

local function formatRate(value)
    if type(value) ~= "number" or value ~= value then value = 0 end
    value = math.clamp(value, 0, 100)
    if math.abs(value - math.round(value)) < 0.05 then
        return string.format("%.0f%%", value)
    end
    return string.format("%.1f%%", value)
end

local function fit()
    if not gui or not panel then return end
    local available = gui.AbsoluteSize
    local base = panel.Size
    if base.X.Offset <= 0 or base.Y.Offset <= 0 then return end
    local width = math.max(1, available.X - 48)
    local height = math.max(1, available.Y - 48)
    panel.FitToScreen.Scale = math.clamp(
        math.min(width / base.X.Offset, height / base.Y.Offset),
        0.25,
        1
    )
end

local function fitName()
    local maxWidth = nameText.Size.X.Offset - 16
    local maxHeight = nameText.Size.Y.Offset - 10
    local size = 68
    while size > 22 do
        local bounds = TextService:GetTextSize(nameText.Text, size, Enum.Font.PermanentMarker, Vector2.new(10000, 10000))
        if bounds.X <= maxWidth and bounds.Y <= maxHeight then break end
        size -= 2
    end
    nameText.TextSize = size
end

local function refresh()
    if not gui then return end
    local snapshot = ProfileClientBridge.statsSnapshot() or {}
    nameText.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
    fitName()
    values.Kills.Text = formatCount(snapshot.kills)
    values.Units.Text = formatCount(snapshot.unitsCollected)
    values.HighestTrophies.Text = formatCount(snapshot.highestTrophies)
    values.WinRate.Text = formatRate(snapshot.winRate)
    values.Losses.Text = formatCount(snapshot.losses)
    values.Wins.Text = formatCount(snapshot.wins)

    local league = ProfileClientBridge.league()
    if type(league) ~= "string" or league == "" then league = "Bronze" end
    local image = gui:GetAttribute(league .. "FrameImage")
    if type(image) == "number" then image = "rbxassetid://" .. tostring(image) end
    if type(image) == "string" and image ~= "" then
        leagueFrame.Image = image
    end
end

function StatsUI.close()
    if gui then gui.Enabled = false end
end

function StatsUI.build(playerGui)
    if gui then return gui end
    gui = playerGui:WaitForChild("StatsGui")
    panel = gui:WaitForChild("Panel")
    local stats = panel:WaitForChild("Stats")
    nameText = panel:WaitForChild("NameBanner"):WaitForChild("NameText")
    avatar = panel:WaitForChild("Portrait"):WaitForChild("Avatar")
    leagueFrame = panel.Portrait:WaitForChild("Frame")
    for _, key in ipairs({"Kills", "Units", "HighestTrophies", "WinRate", "Losses", "Wins"}) do
        values[key] = stats:WaitForChild(key):WaitForChild("Value")
    end

    nameText.Font = Enum.Font.PermanentMarker
    nameText.TextScaled = false
    nameText.TextSize = 68
    nameText.TextWrapped = false
    local stroke = nameText:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Name = "NameOutline"
        stroke.Parent = nameText
    end
    stroke.Color = Color3.fromRGB(54, 24, 53)
    stroke.Thickness = 3

    gui:WaitForChild("Dim").Activated:Connect(StatsUI.close)
    panel:WaitForChild("Close").Activated:Connect(StatsUI.close)
    ProfileClientBridge.StatsChanged:Connect(function()
        if gui.Enabled then refresh() end
    end)
    PlayerData.Changed:Connect(function()
        if gui.Enabled then refresh() end
    end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui.Enabled = false
    fit()
    refresh()

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and image and avatar and avatar.Parent then avatar.Image = image end
    end)
    return gui
end

function StatsUI.open(playerGui)
    StatsUI.build(playerGui)
    refresh()
    fit()
    gui.Enabled = true
end

function StatsUI.isOpen()
    return gui ~= nil and gui.Enabled
end

return StatsUI

