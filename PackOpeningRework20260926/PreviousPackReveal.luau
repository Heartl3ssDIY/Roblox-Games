local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local UnitViewport = require(ReplicatedStorage:WaitForChild("UnitViewport"))
local Assets = require(ReplicatedStorage:WaitForChild("PackUIAssets"))
local PackReveal = {}
local gui, board, callback, result, packBase
local version = 0
local phase = "Closed"
local rewards = {}
local active = {}
local idleTween
local foilTweens = {}
local packImages = {bronze = Assets.Common, silver = Assets.Silver, gold = Assets.Gold, diamond = Assets.Diamond}
local order = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5}
local function tween(object, duration, properties, style, direction)
    local t = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
    active[t] = true
    t.Completed:Once(function() active[t] = nil end)
    t:Play()
    return t
end
local function cancelTweens()
    for _, t in pairs(foilTweens) do t:Cancel() end
    table.clear(foilTweens)
    for t in pairs(active) do t:Cancel() end
    table.clear(active)
    if idleTween then idleTween:Cancel(); idleTween = nil end
end
local function setPhase(value)
    phase = value
    gui:SetAttribute("RevealPhase", value)
end
local function valid(token)
    return version == token and gui.Enabled
end
local function pause(seconds, token)
    task.wait(seconds)
    return valid(token)
end
local function destroyCard(card)
    for _, v in card:GetDescendants() do
        if v:IsA("ViewportFrame") then UnitViewport.clear(v) end
    end
    card:Destroy()
end
local function clearFocus()
    for _, child in board.Focus:GetChildren() do
        if child:GetAttribute("RewardCard") then destroyCard(child) end
    end
end
local function clearCards()
    clearFocus()
    for _, child in board.Results.Cards:GetChildren() do
        if child:IsA("GuiObject") then destroyCard(child) end
    end
    for _, child in board.Particles:GetChildren() do child:Destroy() end
end
local function fit()
    if gui:GetAttribute("AutoFit") == false then return end
    local margin = 28 + math.max(0, -gui.AbsolutePosition.Y)
    board.FitToScreen.Scale = math.max(.1, math.min(1, (gui.AbsoluteSize.X - 56) / board.Size.X.Offset, (gui.AbsoluteSize.Y - margin * 2) / board.Size.Y.Offset))
end
local function foil(target)
    local finish = target:FindFirstChild("Finish")
    if not finish then return end
    local gradient = finish.Streak.Sweep
    if foilTweens[target] then foilTweens[target]:Cancel() end
    gradient.Offset = Vector2.new(-1.1, 0)
    local t = TweenService:Create(gradient, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.1, 0)})
    foilTweens[target] = t
    t:Play()
    t.Completed:Once(function()
        if foilTweens[target] == t then foilTweens[target] = nil end
    end)
end
local function collectRewards()
    local combined = {}
    for id, count in pairs(result.cards or {}) do combined[id] = {id = id, count = count} end
    for _, id in ipairs(result.newUnits or {}) do
        combined[id] = combined[id] or {id = id, count = 0}
        combined[id].isNew = true
    end
    rewards = {}
    for id, item in pairs(combined) do
        local unit = UnitData.get(id)
        if unit then
            item.unit = unit
            local progress = result.progress and result.progress[id]
            local xp, needed = PlayerData.unitXpProgress(id, unit.rarity)
            item.before = progress and progress.before or math.max(0, xp - item.count)
            item.after = progress and progress.after or xp
            item.needed = progress and progress.needed or needed
            item.level = progress and progress.level or PlayerData.unitLevel(id)
            table.insert(rewards, item)
        end
    end
    table.sort(rewards, function(a, b)
        if a.isNew ~= b.isNew then return not a.isNew end
        local first, second = order[a.unit.rarity] or 99, order[b.unit.rarity] or 99
        if first ~= second then return first < second end
        return a.unit.name < b.unit.name
    end)
end
local function cardFor(item, parent, complete)
    local template = gui.Templates:FindFirstChild(item.unit.rarity) or gui.Templates.Common
    local card = template:Clone()
    card.Name = "Unit_" .. item.id
    card:SetAttribute("RewardCard", true)
    card:SetAttribute("XPBefore", item.before)
    card:SetAttribute("XPAfter", item.after)
    card:SetAttribute("CardsReceived", item.count)
    card.Visible = true
    card.Amount.Text = item.count > 0 and "+" .. item.count or "NEW"
    card.UnitName.Text = item.unit.name
    card.NewUnit.Visible = item.isNew == true
    card.LevelStar.Value.Text = tostring(item.level)
    local xp = complete and item.after or item.before
    card.XPTrack.Value.Text = item.needed and (xp .. "/" .. item.needed .. " XP") or "MAX LEVEL"
    card.XPTrack.Progress.Size = UDim2.fromScale(item.needed and math.clamp(xp / item.needed, 0, 1) or 1, 1)
    if parent == board.Focus then
        for _, child in card:GetDescendants() do
            if child:IsA("GuiObject") then child.ZIndex += 14 end
        end
    end
    card.Parent = parent
    UnitViewport.show(card.UnitModel, item.unit.model)
    return card
end
local function animateXP(card, item)
    local finish = item.needed and math.clamp(item.after / item.needed, 0, 1) or 1
    tween(card.XPTrack.Progress, .65, {Size = UDim2.fromScale(finish, 1)})
    local number = Instance.new("NumberValue")
    number.Value = item.before
    number.Parent = card
    number.Changed:Connect(function(value)
        card.XPTrack.Value.Text = item.needed and (math.floor(value + .5) .. "/" .. item.needed .. " XP") or "MAX LEVEL"
    end)
    tween(number, .65, {Value = item.after})
end
local function settle()
    cancelTweens()
    clearFocus()
    for _, piece in board.Particles:GetChildren() do piece:Destroy() end
    board.Opening.Visible = false
    board.Focus.Visible = false
    board.Results.Visible = true
    board.Results.Title.Visible = true
    board.Results.Continue.Visible = true
    board.Results.Empty.Visible = #rewards == 0
    board.Skip.Visible = false
    for _, item in ipairs(rewards) do
        if not item.card or not item.card.Parent then
            item.card = cardFor(item, item.slot, true)
        end
        item.card.Visible = true
        item.card.Motion.Scale = 1
        item.card.XPTrack.Progress.Size = UDim2.fromScale(item.needed and math.clamp(item.after / item.needed, 0, 1) or 1, 1)
        item.card.XPTrack.Value.Text = item.needed and (item.after .. "/" .. item.needed .. " XP") or "MAX LEVEL"
    end
    setPhase("Results")
end
function PackReveal.skip()
    if not gui or not gui.Enabled or phase == "Results" then return end
    version += 1
    settle()
end
function PackReveal.close()
    if not gui or not gui.Enabled then return end
    version += 1
    cancelTweens()
    gui.Enabled = false
    clearCards()
    rewards = {}
    result = nil
    setPhase("Closed")
    local done = callback
    callback = nil
    if done then done() end
end
local function showRewards(token)
    board.Opening.Visible = false
    board.Results.Visible = true
    board.Results.Title.Visible = false
    for index, item in ipairs(rewards) do
        if not valid(token) then return end
        setPhase(item.isNew and "Mystery" or "Reward")
        clearFocus()
        local focus = board.Focus
        focus.Visible = true
        focus.Shade.BackgroundTransparency = .55
        focus.Mystery.Visible = item.isNew == true
        focus.Title.Text = item.isNew and "A NEW UNIT!" or ("REWARD " .. index .. " / " .. #rewards)
        focus.Hint.Text = item.isNew and "WHO WILL JOIN YOUR TEAM?" or ""
        if item.isNew then
            local mystery = focus.Mystery
            mystery.Position = focus.CardAnchor.Position
            mystery.Motion.Scale = .85
            mystery.Rotation = 0
            mystery.Size = packBase.mysterySize
            tween(mystery.Motion, .6, {Scale = 1.08}, Enum.EasingStyle.Quint)
            if not pause(.8, token) then return end
            tween(mystery, .18, {Size = UDim2.new(0, 0, packBase.mysterySize.Y.Scale, packBase.mysterySize.Y.Offset)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
            if not pause(.19, token) then return end
            mystery.Visible = false
            focus.Title.Text = "NEW " .. string.upper(item.unit.rarity) .. " UNIT!"
            focus.Hint.Text = "UNLOCKED!"
        end
        local card = cardFor(item, focus, false)
        card.AnchorPoint = focus.CardAnchor.AnchorPoint
        card.Position = focus.CardAnchor.Position
        card.ZIndex = 14
        card.Motion.Scale = .96
        if item.isNew then
            local fullSize = card.Size
            card.Size = UDim2.new(0, 0, fullSize.Y.Scale, fullSize.Y.Offset)
            tween(card, .22, {Size = fullSize}, Enum.EasingStyle.Sine)
        end
        tween(card.Motion, .4, {Scale = 1.08}, Enum.EasingStyle.Quint)
        if not pause(.22, token) then return end
        animateXP(card, item)
        if not pause(item.isNew and (gui:GetAttribute("NewUnitHoldSeconds") or 1.25) or .85, token) then return end
        setPhase("Docking")
        tween(focus.Shade, .2, {BackgroundTransparency = 1})
        focus.Title.Text = ""
        focus.Hint.Text = ""
        RunService.Heartbeat:Wait()
        if not valid(token) then return end
        local scale = board.FitToScreen.Scale
        local target = (item.slot.AbsolutePosition + item.slot.AbsoluteSize / 2 - board.AbsolutePosition) / scale
        local from = Vector2.new(card.Position.X.Offset, card.Position.Y.Offset)
        local travel = Instance.new("NumberValue")
        travel.Parent = card
        travel.Changed:Connect(function(a)
            local point = from:Lerp(target, a) - Vector2.new(0, math.sin(a * math.pi) * 48)
            card.Position = UDim2.fromOffset(point.X, point.Y)
            card.Rotation = math.sin(a * math.pi) * (target.X < from.X and -4 or 4)
        end)
        tween(travel, .48, {Value = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        tween(card.Motion, .48, {Scale = 1})
        if not pause(.5, token) then return end
        item.card = cardFor(item, item.slot, true)
        clearFocus()
        focus.Visible = false
        if not pause(.12, token) then return end
    end
    if valid(token) then settle() end
end
function PackReveal.revealNow()
    if not gui or not gui.Enabled or phase ~= "Opening" then return end
    setPhase("Unsealing")
    if idleTween then idleTween:Cancel(); idleTween = nil end
    local token = version
    task.spawn(function()
        local pack = board.Opening.Pack
        foil(pack)
        tween(pack.Motion, .3, {Scale = .975}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        tween(pack, .3, {Rotation = packBase.rotation - 2}, Enum.EasingStyle.Sine)
        if not pause(.32, token) then return end
        tween(pack.Motion, .38, {Scale = 1.065}, Enum.EasingStyle.Quint)
        tween(pack, .38, {Rotation = packBase.rotation})
        tween(pack.Seam, .2, {BackgroundTransparency = .2})
        if not pause(.24, token) then return end
        pack.ImageTransparency = 1
        pack.Seal.Visible = true
        pack.Body.Visible = true
        pack.Finish.Visible = false
        foil(pack.Body)
        tween(pack.Seal, .68, {Position = UDim2.fromScale(.6, -.48), Rotation = 22, GroupTransparency = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        tween(pack.Seam, .5, {BackgroundTransparency = 1})
        board.Opening.Hint.Text = ""
        if not pause(.72, token) then return end
        showRewards(token)
    end)
end
local function build(playerGui)
    if gui then return end
    gui = playerGui:WaitForChild("PackRevealGui")
    board = gui:WaitForChild("Board")
    local pack = board.Opening.Pack
    packBase = {rotation = pack.Rotation, sealPosition = pack.Seal.Position, mysterySize = board.Focus.Mystery.Size}
    pack.Activated:Connect(PackReveal.revealNow)
    board.Skip.Activated:Connect(PackReveal.skip)
    board.Results.Continue.Activated:Connect(PackReveal.close)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
    local foilClock = 0
    RunService.RenderStepped:Connect(function(dt)
        if not gui.Enabled then return end
        foilClock += dt
        if foilClock >= 3.2 then
            foilClock = 0
            if phase == "Opening" then foil(pack) end
        end
    end)
    gui.Enabled = false
    fit()
end
function PackReveal.play(playerGui, received, onDone)
    build(playerGui)
    if gui.Enabled then PackReveal.close() end
    version += 1
    cancelTweens()
    clearCards()
    result = received or {cards = {}, newUnits = {}}
    callback = onDone
    collectRewards()
    gui.Enabled = true
    board.Opening.Visible = true
    board.Results.Visible = false
    board.Results.Continue.Visible = false
    board.Results.Empty.Visible = false
    board.Results.Cards.CanvasPosition = Vector2.zero
    board.Focus.Visible = false
    board.Skip.Visible = true
    local pack = board.Opening.Pack
    pack.Rotation = packBase.rotation
    pack.Motion.Scale = .92
    pack.Finish.Visible = true
    pack.Seam.BackgroundTransparency = 1
    board.Focus.Mystery.Size = packBase.mysterySize
    pack.ImageTransparency = 0
    pack.Seal.Position = packBase.sealPosition
    pack.Seal.Rotation = 0
    pack.Seal.GroupTransparency = 0
    pack.Seal.Visible = false
    pack.Body.Visible = false
    pack.Image = packImages[result.packId] or Assets.Common
    pack.Seal.Artwork.Image = pack.Image
    pack.Body.Artwork.Image = pack.Image
    board.Opening.Title.Text = string.upper(result.packName or "Common Pack")
    board.Opening.Hint.Text = "TAP TO OPEN"
    for index, item in ipairs(rewards) do
        local slot = gui.Templates.RewardSlot:Clone()
        slot.Name = "Slot_" .. item.id
        slot.LayoutOrder = index
        slot.Visible = true
        slot.Parent = board.Results.Cards
        item.slot = slot
    end
    fit()
    setPhase("Opening")
    tween(pack.Motion, .55, {Scale = 1}, Enum.EasingStyle.Quint)
    foil(pack)
    local token = version
    task.delay(.58, function()
        if not valid(token) or phase ~= "Opening" then return end
        idleTween = TweenService:Create(pack.Motion, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Scale = 1.012})
        idleTween:Play()
    end)
    task.delay(gui:GetAttribute("AutoOpenDelay") or 2.1, function()
        if valid(token) then PackReveal.revealNow() end
    end)
end
function PackReveal.isOpen()
    return gui ~= nil and gui.Enabled
end
return PackReveal
