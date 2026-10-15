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

local ArenaCatalog = require(ReplicatedStorage:WaitForChild("ArenaCatalog"))
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local ArenaSelectionUI = {}
local visiting = false
local teleporting = false
local hiddenVisitGuis = {}

local function restoreVisitGuis()
    for screen, enabled in pairs(hiddenVisitGuis) do
        if screen.Parent then screen.Enabled = enabled end
    end
    table.clear(hiddenVisitGuis)
end
local gui, board, playerGui
local selected = 1
local freePlayMode = false
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
    local arena = ArenaCatalog.get(selected)
    local progress = PlayerData.arenaProgress(arena.key)
    local first = arena.matchReady and not freePlayMode
    local completed = PlayerData.isArenaCompleted(arena.key)
    local showProgress = first or freePlayMode
    local value = showProgress and progress.progressWins or 0
    board.ArenaNumber.Label.Text = "Arena " .. arena.number
    board.Title.Text = arena.displayName
    board.Description.Text = arena.description
    board.Illustration.Visible = selected == 1 and (not freePlayMode or completed)
    board.Locked.Visible = selected ~= 1 or (freePlayMode and not completed)
    if freePlayMode then
        board.Locked.Text = completed and ("ARENA " .. arena.number .. "\nFREE PLAY UNLOCKED")
            or ("ARENA " .. arena.number .. "\nCOMPLETE THIS ARENA'S STORY\n100 POINTS TO UNLOCK FREE PLAY")
    else
        board.Locked.Text = "ARENA " .. arena.number .. "\nSTORY MODE COMING SOON"
    end
    board.ProgressBorder.Visible = showProgress
    board.ProgressTrack.Visible = showProgress
    board.Progress.Visible = showProgress
    board.ProgressText.Visible = showProgress
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
    board.Action.Visible = pending or first
    board.Teleport.Visible = not pending and freePlayMode
    board.Teleport.Interactable = not teleporting and arena.teleportReady and completed
    board.Action.Interactable = not claiming and (pending or first)
    board.Action.ImageTransparency = (pending or first) and 0 or .5
    board.Back.Interactable = not claiming
    board.Next.Interactable = not claiming and not teleporting
    gui:SetAttribute("SelectedArena", selected)
    gui:SetAttribute("Action", pending and "Claim" or (freePlayMode and (completed and "FreePlay" or "Locked") or (first and "Battle" or "Unavailable")))
    gui:SetAttribute("FreePlay", freePlayMode)
    gui:SetAttribute("ArenaCompleted", completed)
end

function ArenaSelectionUI.close()
    if gui then gui.Enabled = false end
end

function ArenaSelectionUI.back()
    if claiming or teleporting or visiting then return end
    ArenaSelectionUI.close()
    if not freePlayMode then ModePickerUI.open() end
end

function ArenaSelectionUI.nextArena()
    if claiming or teleporting or visiting then return end
    selected = selected % ArenaCatalog.count() + 1
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
            ArenaSelectionUI.open(playerGui, selected, freePlayMode)
        end)
        return true
    end
    if freePlayMode then return ArenaSelectionUI.teleport() end
    local arena = ArenaCatalog.get(selected)
    if not arena or not arena.matchReady then return false end
    if Loadout.count() < 4 then
        Feedback.play("Unavailable")
        notify("Equip 4 units before battling.")
        return false
    end
    gui.Enabled = false
    ReplicatedStorage:WaitForChild("ArenaEvents"):WaitForChild("EnterArena"):Fire(arena.modelName)
    return true
end

function ArenaSelectionUI.teleport()
    if claiming or teleporting or visiting or not gui or not gui.Enabled then return false end
    local arena = ArenaCatalog.get(selected)
    if not arena or not arena.teleportReady then return false end
    if not freePlayMode then return false end
    if not PlayerData.isArenaCompleted(arena.key) then
        Feedback.play("Unavailable")
        notify("Complete " .. arena.displayName .. " in Story Mode by reaching 100 points to unlock Free Play.")
        refresh(true)
        return false
    end
    teleporting = true
    board.Teleport.Interactable = false
    local success, message = ArenaTravelClient.visit(arena.modelName)
    teleporting = false
    if not success then refresh(true); notify(message or "Teleport is unavailable."); return false end
    visiting = true
    for _, screen in ipairs(playerGui:GetChildren()) do
        if screen:IsA("ScreenGui") and screen ~= gui and screen.Name ~= "TouchGui" then
            hiddenVisitGuis[screen] = screen.Enabled
            screen.Enabled = false
        end
    end
    board.Visible = false
    gui.ReturnToLobby.Visible = true
    return true
end

function ArenaSelectionUI.returnFromVisit()
    if not visiting or teleporting then return end
    teleporting = true
    local success, message = ArenaTravelClient.leave()
    teleporting = false
    if not success then warn(message); return end
    visiting = false
    restoreVisitGuis()
    gui.ReturnToLobby.Visible = false
    board.Visible = true
    ArenaSelectionUI.open(playerGui, selected, freePlayMode)
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
    board.Teleport.Activated:Connect(ArenaSelectionUI.teleport)
    gui.ReturnToLobby.Activated:Connect(ArenaSelectionUI.returnFromVisit)
    Players.LocalPlayer.CharacterRemoving:Connect(function()
        if not visiting then return end
        visiting = false
        teleporting = false
        restoreVisitGuis()
        ArenaTravelClient.restore()
        gui.ReturnToLobby.Visible = false
        board.Visible = true
        gui.Enabled = false
    end)
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

function ArenaSelectionUI.isBusy()
    return claiming or visiting or teleporting
end

function ArenaSelectionUI.open(pg, arenaIndex, freePlay)
    if ArenaSelectionUI.isBusy() then return false, "Finish the current pack or arena visit first." end
    local nextSelected = selected
    if arenaIndex ~= nil then
        local arena
        if type(arenaIndex) == "number" then
            if arenaIndex == arenaIndex and arenaIndex % 1 == 0 and arenaIndex >= 1 and arenaIndex <= ArenaCatalog.count() then
                arena = ArenaCatalog.get(arenaIndex)
            end
        elseif type(arenaIndex) == "string" then
            arena = ArenaCatalog.find(arenaIndex)
        end
        if not arena then return false, "That arena is unavailable." end
        nextSelected = nil
        for index = 1, ArenaCatalog.count() do
            if ArenaCatalog.get(index).key == arena.key then nextSelected = index; break end
        end
        if not nextSelected then return false, "That arena is unavailable." end
    end
    ArenaSelectionUI.build(pg or Players.LocalPlayer.PlayerGui)
    if ArenaSelectionUI.isBusy() then return false, "Finish the current pack or arena visit first." end
    selected = nextSelected
    freePlayMode = freePlay == true
    ModePickerUI.close()
    board.Notice.Visible = false
    refresh(true)
    fit()
    gui.Enabled = true
    return true
end

return ArenaSelectionUI
