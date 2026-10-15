local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local Assets = require(ReplicatedStorage:WaitForChild("ArenaUIAssets"))
local PackOpening = require(ReplicatedStorage:WaitForChild("PackOpening"))
local PackReveal = require(ReplicatedStorage:WaitForChild("PackReveal"))
local ModePickerUI = require(ReplicatedStorage:WaitForChild("ModePickerUI"))
local Feedback = require(ReplicatedStorage:WaitForChild("PackShopEffects"))
local Loadout = require(ReplicatedStorage:WaitForChild("Loadout"))

local ArenaSelectionUI = {}
local gui, board, playerGui
local selected = 1
local claiming = false
local fillTween, lossTween
local noticeToken = 0
local milestones = {
    {points = 20, description = "2 wins: 1,000 cash"},
    {points = 40, description = "4 wins: Bluma becomes unlockable in packs"},
    {points = 80, description = "8 wins: 10 diamonds"},
    {points = 100, description = "10 wins: Pikkolo becomes unlockable in packs"},
}

local function notify(message)
    noticeToken += 1
    local token = noticeToken
    board.Notice.Text = message
    board.Notice.Visible = true
    task.delay(3, function()
        if noticeToken == token then board.Notice.Visible = false end
    end)
end

local function fit()
    if gui:GetAttribute("AutoFit") == false then return end
    local margin = gui:GetAttribute("FitMargin") or 24
    board.FitToScreen.Scale = math.max(.1, math.min(1,
        (gui.AbsoluteSize.X - margin * 2) / board.Size.X.Offset,
        (gui.AbsoluteSize.Y - margin * 2) / board.Size.Y.Offset))
end

local function refresh(instant)
    if not gui then return end
    local progress = PlayerData.arenaProgress("Tenkaichi")
    local first = selected == 1
    local value = first and progress.progressWins or 0
    board.ArenaNumber.Label.Text = "Arena " .. selected
    board.Title.Text = first and "Tenkaichi" or "Next Story"
    board.Description.Text = first
        and "Fight beneath tropical skies at the Tenkaichi martial arts tournament. Draft your team and take the ring."
        or (progress.completed and "Arena unlocked. The next story is coming soon." or "Complete Tenkaichi with 10 wins to unlock this arena.")
    board.Illustration.Visible = first
    board.Locked.Visible = not first
    board.Locked.Text = progress.completed and "ARENA 2\nCOMING SOON" or "ARENA 2\nLOCKED"
    board.ProgressText.Text = string.format("%g/10", value)
    local fraction = math.clamp(value / 10, 0, 1)
    local fill = board.Progress.FillClip
    local loss = board.Progress.LossClip
    local previous = fill.Size.X.Scale
    if fillTween then fillTween:Cancel() end
    if lossTween then lossTween:Cancel() end
    if instant or not gui.Enabled then
        fill.Size = UDim2.fromScale(fraction, 1)
        loss.Size = fill.Size
    else
        loss.Size = UDim2.fromScale(math.max(previous, fraction), 1)
        fillTween = TweenService:Create(fill, TweenInfo.new(.3, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(fraction, 1)})
        lossTween = TweenService:Create(loss, TweenInfo.new(.65, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(fraction, 1)})
        fillTween:Play()
        lossTween:Play()
    end
    for index, milestone in ipairs(milestones) do
        local icon = board.Milestones["Reward" .. index]
        icon.Visible = first
        icon.Check.Visible = progress.claimed[milestone.points] == true
    end
    for index, reward in ipairs(PlayerData.dailyWinRewards()) do
        local icon = board.DailyRewards["Reward" .. index]
        icon.Check.Visible = reward.earned and not reward.claimed
        icon.Pack.ImageTransparency = reward.claimed and .6 or 0
        icon.ImageTransparency = reward.claimed and .35 or 0
    end
    local pending = PlayerData.pendingDailyPack() ~= nil
    board.Action.Image = pending and Assets.Claim or Assets.Battle
    board.Action.Interactable = not claiming and (pending or first)
    board.Action.ImageTransparency = (pending or first) and 0 or .5
    board.Back.Interactable = not claiming
    board.Next.Interactable = not claiming
    gui:SetAttribute("SelectedArena", selected)
    gui:SetAttribute("Action", pending and "Claim" or "Battle")
end

function ArenaSelectionUI.close()
    if gui then gui.Enabled = false end
end

function ArenaSelectionUI.back()
    if claiming then return end
    ArenaSelectionUI.close()
    ModePickerUI.open()
end

function ArenaSelectionUI.nextArena()
    if claiming then return end
    selected = selected == 1 and 2 or 1
    board.Notice.Visible = false
    refresh(true)
end

function ArenaSelectionUI.activate()
    if claiming or not gui or not gui.Enabled then return false end
    local pending = PlayerData.pendingDailyPack()
    if pending then
        claiming = true
        local result = PackOpening.roll(pending.packId)
        if not result then
            claiming = false
            Feedback.play("Unavailable")
            notify("This pack cannot be opened yet.")
            return false
        end
        if not PlayerData.consumeDailyPack() then claiming = false; refresh(true); return false end
        PackOpening.apply(result)
        Feedback.play("Confirm")
        gui.Enabled = false
        PackReveal.play(playerGui, result, function()
            claiming = false
            ArenaSelectionUI.open(playerGui)
        end)
        return true
    end
    if selected ~= 1 then return false end
    if Loadout.count() < 4 then
        Feedback.play("Unavailable")
        notify("Equip 4 units before battling.")
        return false
    end
    gui.Enabled = false
    ReplicatedStorage:WaitForChild("ArenaEvents"):WaitForChild("EnterArena"):Fire("Arena_Tenkaichi")
    return true
end

function ArenaSelectionUI.build(pg)
    if gui then return gui end
    playerGui = pg
    gui = pg:WaitForChild("ArenaSelectGui")
    board = gui.Board
    local outline = board:FindFirstChild("TitleWhiteOutline")
    if outline then
        local function syncTitle()
            outline.Text = board.Title.Text
            outline.Visible = board.Title.Visible
        end
        board.Title:GetPropertyChangedSignal("Text"):Connect(syncTitle)
        board.Title:GetPropertyChangedSignal("Visible"):Connect(syncTitle)
        syncTitle()
    end
    Feedback.bind(gui)
    board.Back.Activated:Connect(ArenaSelectionUI.back)
    board.Next.Activated:Connect(ArenaSelectionUI.nextArena)
    board.Action.Activated:Connect(ArenaSelectionUI.activate)
    for index, milestone in ipairs(milestones) do
        local icon = board.Milestones["Reward" .. index]
        icon.Activated:Connect(function() notify(milestone.description) end)
    end
    for index = 1, 4 do
        local icon = board.DailyRewards["Reward" .. index]
        icon.Activated:Connect(function()
            local reward = PlayerData.dailyWinRewards()[index]
            notify(reward.claimed and "Pack claimed."
                or (reward.earned and "Pack earned. Press Claim to open it."
                or ("Daily win " .. index .. ": " .. (index == 4 and "Silver" or "Common") .. " Unit Pack")))
        end)
    end
    PlayerData.Changed:Connect(function() refresh(false) end)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
    task.spawn(function()
        local previousRemaining = PlayerData.dailyWinPacksRemaining()
        while gui.Parent do
            task.wait(1)
            local remaining = PlayerData.dailyWinPacksRemaining()
            if remaining ~= previousRemaining then refresh(true); previousRemaining = remaining end
        end
    end)
    refresh(true)
    fit()
    return gui
end

function ArenaSelectionUI.open(pg)
    ArenaSelectionUI.build(pg or Players.LocalPlayer.PlayerGui)
    if claiming then return end
    ModePickerUI.close()
    board.Notice.Visible = false
    refresh(true)
    fit()
    gui.Enabled = true
end

return ArenaSelectionUI
