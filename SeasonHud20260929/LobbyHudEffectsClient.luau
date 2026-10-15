local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local lobby = playerGui:WaitForChild("LobbyMenuGui")
local packs = playerGui:WaitForChild("PacksButtonGui")
local play = playerGui:WaitForChild("PlayButtonGui")
local Effects = require(ReplicatedStorage:WaitForChild("PackShopEffects"))
local MatchSettings = require(ReplicatedStorage:WaitForChild("MatchSettings"))

local function available(button, gui)
    if not gui.Enabled or not button.Interactable then return false end
    local current = button
    while current and current ~= gui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return current == gui
end

local function bind(button, gui)
    local scale = button:WaitForChild("FeedbackScale")
    local baseTint = button.ImageColor3
    local hovered = false
    local scaleTween
    local colorTween

    local function tweenScale(value, duration, easing)
        if scaleTween then scaleTween:Cancel() end
        scaleTween = TweenService:Create(
            scale,
            TweenInfo.new(duration, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Scale = value}
        )
        scaleTween:Play()
        return scaleTween
    end

    local function tweenTint(color)
        if colorTween then colorTween:Cancel() end
        colorTween = TweenService:Create(button, TweenInfo.new(0.18), {ImageColor3 = color})
        colorTween:Play()
    end

    local function enter()
        if hovered or not available(button, gui) then return end
        hovered = true
        Effects.play("HudHover")
        if MatchSettings.effectsEnabled() then
            tweenTint(Color3.fromRGB(215, 215, 235))
            Effects.sweep(button, gui)
            tweenScale(1.035, 0.18, Enum.EasingStyle.Back)
        end
    end

    local function leave()
        hovered = false
        tweenTint(baseTint)
        tweenScale(1, 0.18)
    end

    button.MouseEnter:Connect(enter)
    button.SelectionGained:Connect(enter)
    button.MouseLeave:Connect(leave)
    button.SelectionLost:Connect(leave)
    button.Activated:Connect(function()
        if not available(button, gui) then return end
        Effects.play("HudClick")
        if not MatchSettings.effectsEnabled() then return end
        Effects.sweep(button, gui)
        local press = tweenScale(0.965, 0.08)
        press.Completed:Once(function(state)
            if state == Enum.PlaybackState.Completed and scaleTween == press then
                tweenScale(hovered and 1.035 or 1, 0.25, Enum.EasingStyle.Back)
            end
        end)
    end)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not gui.Enabled then leave() end
    end)
end

local sidebar = lobby:WaitForChild("Sidebar")
local dock = sidebar:WaitForChild("SideDock")
for _, entry in ipairs({
    {sidebar:WaitForChild("BattlePass"), lobby},
    {sidebar:WaitForChild("SeasonRank"), lobby},
    {sidebar:WaitForChild("PlayerStats"), lobby},
    {dock:WaitForChild("ShopOpen"), lobby},
    {dock:WaitForChild("UnitsOpen"), lobby},
    {lobby:WaitForChild("PvPBtn"), lobby},
    {packs:WaitForChild("PacksBtn"), packs},
    {play:WaitForChild("PlayBtn"), play},
}) do
    bind(entry[1], entry[2])
end
