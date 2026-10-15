local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local UnitViewport = require(ReplicatedStorage:WaitForChild("UnitViewport"))
local Assets = require(ReplicatedStorage:WaitForChild("PackUIAssets"))
local PackReveal = {}
local gui, board, callback, result
local version = 0
local opened = false
local packImages = {bronze = Assets.Common, silver = Assets.Silver, gold = Assets.Gold, diamond = Assets.Diamond}
local order = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5}

local function clearCards()
    for _, child in ipairs(board.Results.Cards:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function fit()
    if gui:GetAttribute("AutoFit") == false then return end
    board.FitToScreen.Scale = math.min(1, (gui.AbsoluteSize.X - 28) / board.Size.X.Offset, (gui.AbsoluteSize.Y - 40) / board.Size.Y.Offset)
end

function PackReveal.close()
    if not gui then return end
    version += 1
    gui.Enabled = false
    clearCards()
    local done = callback
    callback = nil
    result = nil
    if done then done() end
end

local function showCards(token)
    if token ~= version or not result then return end
    board.Opening.Visible = false
    board.Results.Visible = true
    local rewards = {}
    for id, count in pairs(result.cards or {}) do rewards[id] = {id = id, count = count} end
    for _, id in ipairs(result.newUnits or {}) do
        rewards[id] = rewards[id] or {id = id, count = 0}
        rewards[id].isNew = true
    end
    local sorted = {}
    for id, reward in pairs(rewards) do
        local unit = UnitData.get(id)
        if unit then reward.unit = unit; table.insert(sorted, reward) end
    end
    table.sort(sorted, function(a, b)
        local first, second = order[a.unit.rarity] or 99, order[b.unit.rarity] or 99
        if first ~= second then return first < second end
        return a.unit.name < b.unit.name
    end)
    board.Results.Empty.Visible = #sorted == 0
    for index, reward in ipairs(sorted) do
        local unit = reward.unit
        local template = gui.Templates:FindFirstChild(unit.rarity) or gui.Templates.Common
        local card = template:Clone()
        card.Name = "Unit_" .. reward.id
        card.LayoutOrder = index
        card.Visible = true
        card.Amount.Text = reward.count > 0 and "+" .. reward.count or "NEW"
        card.UnitName.Text = unit.name
        card.NewUnit.Visible = reward.isNew == true
        local progress = result.progress and result.progress[reward.id]
        local xp, needed = PlayerData.unitXpProgress(reward.id, unit.rarity)
        local level = PlayerData.unitLevel(reward.id)
        local before = progress and progress.before or math.max(0, xp - reward.count)
        local after = progress and progress.after or xp
        if progress then needed = progress.needed; level = progress.level end
        card.LevelStar.Value.Text = tostring(level)
        card.XPTrack.Value.Text = needed and (after .. "/" .. needed .. " XP") or "MAX LEVEL"
        local start = needed and math.clamp(before / needed, 0, 1) or 1
        local finish = needed and math.clamp(after / needed, 0, 1) or 1
        card.XPTrack.Progress.Size = UDim2.fromScale(start, 1)
        card:SetAttribute("XPBefore", before)
        card:SetAttribute("XPAfter", after)
        card:SetAttribute("CardsReceived", reward.count)
        card.Parent = board.Results.Cards
        UnitViewport.show(card.UnitModel, unit.model)
        TweenService:Create(card.XPTrack.Progress, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(finish, 1),
        }):Play()
    end
end

function PackReveal.revealNow()
    if not gui or not gui.Enabled or opened then return end
    opened = true
    local token = version
    local art = board.Opening.Pack
    local rotation = art.Rotation
    local shake = TweenService:Create(art, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {Rotation = rotation + 8})
    shake:Play()
    task.delay(0.42, function()
        if token ~= version then return end
        art.Rotation = rotation
        showCards(token)
    end)
end

local function build(playerGui)
    if gui then return end
    gui = playerGui:WaitForChild("PackRevealGui")
    board = gui:WaitForChild("Board")
    board.Opening.Pack.Activated:Connect(PackReveal.revealNow)
    board.Results.Continue.Activated:Connect(PackReveal.close)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui.Enabled = false
    fit()
end

function PackReveal.play(playerGui, rewards, onDone)
    build(playerGui)
    version += 1
    local token = version
    clearCards()
    result = rewards or {cards = {}, newUnits = {}}
    callback = onDone
    opened = false
    gui.Enabled = true
    board.Opening.Visible = true
    board.Results.Visible = false
    board.Opening.Pack.Image = packImages[result.packId] or Assets.Common
    board.Opening.Title.Text = result.packName or "Common Pack"
    fit()
    task.delay(1.4, function()
        if token == version then PackReveal.revealNow() end
    end)
end

function PackReveal.isOpen()
    return gui ~= nil and gui.Enabled
end

return PackReveal
