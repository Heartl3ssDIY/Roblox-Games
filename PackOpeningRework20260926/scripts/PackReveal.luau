local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local UnitViewport = require(ReplicatedStorage:WaitForChild("UnitViewport"))
local Assets = require(ReplicatedStorage:WaitForChild("PackUIAssets"))

local PackReveal = {}
local cachedGui, authored
local current
local requestVersion = 0
local actionName = "ACU_PackRevealAdvance"
local layoutNames = {"Landscape", "Portrait", "CompactLandscape"}

local function layouts(gui)
    local found = {}
    for _, name in ipairs(layoutNames) do
        local layout = gui:FindFirstChild(name)
        if layout and layout:IsA("Frame") then table.insert(found, layout) end
    end
    return found
end
local rarityOrder = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5}
local rarityColors = {
    Common = Color3.fromRGB(216, 224, 235), Rare = Color3.fromRGB(84, 188, 255),
    Epic = Color3.fromRGB(181, 99, 255), Legendary = Color3.fromRGB(255, 194, 69),
    Mythic = Color3.fromRGB(255, 105, 184),
}
local packImages = {bronze = Assets.Common, silver = Assets.Silver, gold = Assets.Gold, diamond = Assets.Diamond}
local packColors = {
    bronze = Color3.fromRGB(255, 173, 92), silver = Color3.fromRGB(186, 222, 255),
    gold = rarityColors.Legendary, diamond = Color3.fromRGB(106, 237, 255),
}
local packNames = {bronze = "Common Pack", silver = "Silver Pack", gold = "Gold Pack", diamond = "Diamond Pack"}

local function number(value, fallback)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
    return value
end

local function safeCall(callback)
    if type(callback) ~= "function" then return end
    local ok, message = pcall(callback)
    if not ok then warn("Pack reveal completion: " .. tostring(message)) end
end

local function live(s)
    return current == s and not s.closed and s.gui.Parent ~= nil and s.gui.Enabled
end

local function valid(s, token)
    return live(s) and s.token == token
end

local function connect(s, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(s.connections, connection)
    return connection
end

local function phase(s, value)
    if not live(s) then return end
    s.phase = value
    s.gui:SetAttribute("RevealPhase", value)
end

local function duration(s, name, fallback, minimum, maximum)
    return math.clamp(number(s.gui:GetAttribute(name), fallback), minimum or .05, maximum or 5)
end

local function reduced(s)
    return s.gui:GetAttribute("ReducedMotion") == true or GuiService.ReducedMotionEnabled
end

local function snapshot(gui)
    local poses = {}
    for _, object in ipairs(gui:GetDescendants()) do
        local values = {}
        if object:IsA("GuiObject") then
            values.Position = object.Position
            values.Size = object.Size
            values.Rotation = object.Rotation
            values.Visible = object.Visible
            values.BackgroundTransparency = object.BackgroundTransparency
            values.BackgroundColor3 = object.BackgroundColor3
        end
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            values.ImageTransparency = object.ImageTransparency
            values.ImageColor3 = object.ImageColor3
        elseif object:IsA("TextLabel") or object:IsA("TextButton") then
            values.TextTransparency = object.TextTransparency
            values.TextColor3 = object.TextColor3
        elseif object:IsA("UIScale") then
            values.Scale = object.Scale
        elseif object:IsA("UIGradient") then
            values.Offset = object.Offset
        end
        if object:IsA("CanvasGroup") then values.GroupTransparency = object.GroupTransparency end
        if next(values) then poses[object] = values end
    end
    return poses
end

local function restore(s)
    for object, values in pairs(s.authored) do
        if object.Parent then
            for property, value in pairs(values) do object[property] = value end
        end
    end
end

local function tween(s, object, seconds, properties, style, direction)
    if not live(s) or not object.Parent then return end
    if reduced(s) then seconds = math.min(seconds, .12) end
    local animation = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out), properties)
    s.tweens[animation] = true
    animation.Completed:Once(function() s.tweens[animation] = nil end)
    animation:Play()
    return animation
end

local function pause(s, token, seconds)
    local elapsed = 0
    repeat
        if not valid(s, token) then return false end
        elapsed += RunService.Heartbeat:Wait()
    until elapsed >= seconds
    return valid(s, token)
end

local function clearViewport(viewport)
    if viewport and viewport.Parent then
        local ok, message = pcall(UnitViewport.clear, viewport)
        if not ok then warn("Pack reveal viewport cleanup: " .. tostring(message)) end
    end
end

local function stopVisuals(s)
    s.token += 1
    for animation in pairs(s.tweens) do animation:Cancel() end
    table.clear(s.tweens)
    table.clear(s.counters)
    for sound in pairs(s.sounds) do sound:Destroy() end
    table.clear(s.sounds)
    for particle in pairs(s.particles) do particle:Destroy() end
    table.clear(s.particles)
    s.gui.Flash.BackgroundTransparency = 1
    for _, layout in ipairs(layouts(s.gui)) do
        clearViewport(layout.Showcase.Hero.UnitModel)
    end
end

local function clearCards(s)
    for _, card in ipairs(s.cards) do
        if card.Parent then
            clearViewport(card.UnitModel)
            card:Destroy()
        end
    end
    table.clear(s.cards)
    table.clear(s.cardItems)
    table.clear(s.mounted)
end

local function finish(s)
    if s.closed then return end
    s.closed = true
    if current == s then current = nil end
    s.token += 1
    for _, connection in ipairs(s.connections) do connection:Disconnect() end
    table.clear(s.connections)
    if s.actionsBound then ContextActionService:UnbindAction(actionName) end
    for animation in pairs(s.tweens) do animation:Cancel() end
    table.clear(s.tweens)
    for sound in pairs(s.sounds) do sound:Destroy() end
    for particle in pairs(s.particles) do particle:Destroy() end
    table.clear(s.sounds)
    table.clear(s.particles)
    table.clear(s.counters)
    clearCards(s)
    for _, layoutName in ipairs(layoutNames) do
        local layout = s.gui:FindFirstChild(layoutName)
        local showcase = layout and layout:FindFirstChild("Showcase")
        local hero = showcase and showcase:FindFirstChild("Hero")
        if hero then clearViewport(hero:FindFirstChild("UnitModel")) end
    end
    if s.gui.Parent then
        s.gui.Enabled = false
        s.gui:SetAttribute("RevealPhase", "Closed")
    end
    local selected = GuiService.SelectedObject
    if not current and (selected == nil or selected:IsDescendantOf(s.gui)) then
        local previous = s.previousSelection
        GuiService.SelectedObject = previous and previous.Parent and previous or nil
    end
    local callback = s.callback
    s.callback = nil
    safeCall(callback)
end

local function playSound(s, name)
    if not live(s) or s.gui:GetAttribute("SoundEnabled") == false then return end
    local template = s.gui.Sounds:FindFirstChild(name)
    if not template or not template:IsA("Sound") or template.SoundId == "" then return end
    local sound = template:Clone()
    sound.Name = "Playing_" .. name
    sound.Looped = false
    sound.Volume = math.min(sound.Volume, .35)
    sound.Parent = s.gui.Sounds
    s.sounds[sound] = true
    sound.Ended:Once(function()
        s.sounds[sound] = nil
        sound:Destroy()
    end)
    sound:Play()
    task.delay(8, function()
        if s.sounds[sound] then s.sounds[sound] = nil; sound:Destroy() end
    end)
end

local function theme(s, color)
    s.color = color
    local edge = color:Lerp(Color3.fromRGB(55, 27, 57), .36)
    local light = color:Lerp(Color3.fromRGB(255, 246, 217), .46)
    s.gui.Background.ThemeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, edge), ColorSequenceKeypoint.new(.14, color),
        ColorSequenceKeypoint.new(.48, light), ColorSequenceKeypoint.new(.79, color),
        ColorSequenceKeypoint.new(1, edge),
    })
    s.gui.Atmosphere.Aura.ImageColor3 = light
    for _, ray in ipairs(s.gui.Atmosphere.Rays:GetChildren()) do
        if ray:IsA("Frame") then ray.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), .5) end
    end
end

local function flash(s, color)
    if reduced(s) then return end
    local panel = s.gui.Flash
    panel.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), .6)
    panel.BackgroundTransparency = .84
    tween(s, panel, .22, {BackgroundTransparency = 1})
end

local function burst(s, origin, count, shard)
    if reduced(s) then return end
    local templates = s.gui.Templates
    local space = s.gui.Particles
    local originPoint = origin - space.AbsolutePosition
    for index = 1, count do
        local piece = (shard and templates.TearShard or templates.Spark):Clone()
        piece.Name = "RevealParticle"
        piece.Visible = true
        piece.Position = UDim2.fromOffset(originPoint.X, originPoint.Y)
        piece.Rotation = index * 37
        if piece:IsA("ImageLabel") then piece.ImageColor3 = s.color else piece.BackgroundColor3 = s.color end
        piece.Parent = space
        s.particles[piece] = true
        local angle = index * 2.399963
        local radius = (shard and 95 or 145) + (index % 4) * 24
        local target = originPoint + Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius * .75 + 28)
        local properties = {Position = UDim2.fromOffset(target.X, target.Y), Rotation = piece.Rotation + 100}
        if piece:IsA("ImageLabel") then properties.ImageTransparency = 1 else properties.BackgroundTransparency = 1 end
        tween(s, piece, .6 + index % 3 * .08, properties, Enum.EasingStyle.Quart)
        task.delay(1, function()
            if s.particles[piece] then s.particles[piece] = nil; piece:Destroy() end
        end)
    end
end

local function celebrate(s, origin)
    if not live(s) or reduced(s) then return end
    local token = s.token
    local space = s.gui.Particles
    local center = origin - space.AbsolutePosition
    local spread = math.clamp(math.min(space.AbsoluteSize.X, space.AbsoluteSize.Y) * .28, 72, 180)
    local colors = {Color3.fromRGB(255, 247, 218), Color3.fromRGB(255, 202, 83), s.color}
    for index = 1, 24 do
        local side = index % 2 == 0 and 1 or -1
        local offset = Vector2.new(side * (12 + index % 5 * 4), index % 4 * 5)
        local apex = center + Vector2.new(side * spread * (.35 + index % 7 * .095), -spread * (.36 + index % 5 * .08))
        local landing = apex + Vector2.new(side * spread * .34, spread * (1.12 + index % 4 * .13))
        local piece = s.gui.Templates.Confetti:Clone()
        piece.Name = "NewUnitConfetti"
        piece.Position = UDim2.fromOffset(center.X + offset.X, center.Y + offset.Y)
        piece.Rotation = index * 29
        piece.BackgroundColor3 = colors[index % #colors + 1]
        piece.BackgroundTransparency = 0
        piece.Visible = true
        piece.Parent = space
        s.particles[piece] = true
        local rise = .30 + index % 3 * .025
        local lift = tween(s, piece, rise, {
            Position = UDim2.fromOffset(apex.X, apex.Y), Rotation = piece.Rotation + side * 115,
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if lift then
            lift.Completed:Once(function(state)
                if state ~= Enum.PlaybackState.Completed or not s.particles[piece] then return end
                if not valid(s, token) or reduced(s) then
                    s.particles[piece] = nil
                    piece:Destroy()
                    return
                end
                local fall = tween(s, piece, 1.2 - rise, {
                    Position = UDim2.fromOffset(landing.X, landing.Y),
                    Rotation = piece.Rotation + side * 210, BackgroundTransparency = 1,
                }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                if fall then
                    fall.Completed:Once(function()
                        if s.particles[piece] then s.particles[piece] = nil; piece:Destroy() end
                    end)
                end
            end)
        end
    end
end

local function collect(received)
    local data = type(received) == "table" and received or {}
    local combined = {}
    if type(data.cards) == "table" then
        for id, count in pairs(data.cards) do
            if type(id) == "string" and number(count, 0) > 0 then
                combined[id] = {id = id, count = math.floor(count)}
            end
        end
    end
    if type(data.newUnits) == "table" then
        for _, id in ipairs(data.newUnits) do
            if type(id) == "string" then
                combined[id] = combined[id] or {id = id, count = 0}
                combined[id].isNew = true
            end
        end
    end
    local items = {}
    for id, item in pairs(combined) do
        local ok, unit = pcall(UnitData.get, id)
        unit = ok and type(unit) == "table" and unit or {}
        item.name = type(unit.name) == "string" and unit.name or id
        item.model = type(unit.model) == "string" and unit.model or nil
        item.rarity = rarityOrder[unit.rarity] and unit.rarity or "Common"
        item.color = rarityColors[item.rarity]
        local progress = type(data.progress) == "table" and data.progress[id]
        progress = type(progress) == "table" and progress or nil
        local xp, needed, level = 0, nil, 1
        local xpOK, savedXP, savedNeeded = pcall(PlayerData.unitXpProgress, id, item.rarity)
        if xpOK then xp, needed = number(savedXP, 0), number(savedNeeded, nil) end
        local levelOK, savedLevel = pcall(PlayerData.unitLevel, id)
        if levelOK then level = number(savedLevel, 1) end
        item.before = math.max(0, number(progress and progress.before, math.max(0, xp - item.count)))
        item.after = math.max(0, number(progress and progress.after, xp))
        if progress then item.needed = number(progress.needed, nil) else item.needed = needed end
        if item.needed and item.needed <= 0 then item.needed = nil end
        item.level = math.max(1, math.floor(number(progress and progress.level, level)))
        table.insert(items, item)
    end
    table.sort(items, function(a, b)
        if (a.isNew == true) ~= (b.isNew == true) then return not a.isNew end
        if a.rarity ~= b.rarity then return rarityOrder[a.rarity] < rarityOrder[b.rarity] end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return data, items
end

local function setXP(card, item, alpha)
    local xp = math.floor(item.before + (item.after - item.before) * alpha + .5)
    card.XPTrack.Fill.Size = UDim2.fromScale(item.needed and math.clamp(xp / item.needed, 0, 1) or 1, 1)
    card.XPTrack.Value.Text = item.needed and (xp .. "/" .. item.needed .. " XP") or "MAX LEVEL"
    card.Amount.Text = item.count > 0 and ("+" .. math.floor(item.count * alpha + .5) .. " XP") or "NEW UNIT"
end

local function prepareCards(s)
    if #s.cards > 0 then return end
    local holder = s.layout.Rewards.Cards
    holder.CanvasPosition = Vector2.zero
    local totalXP, totalNew = 0, 0
    for index, item in ipairs(s.items) do
        local card = s.gui.Templates.Card:Clone()
        card.Name = "Reward_" .. index
        card.LayoutOrder = index
        card.Visible = false
        card:SetAttribute("RewardCard", true)
        card:SetAttribute("UnitId", item.id)
        card:SetAttribute("CardsReceived", item.count)
        card:SetAttribute("XPBefore", item.before)
        card:SetAttribute("XPAfter", item.after)
        card.Back.Image = Assets["XP" .. item.rarity] or Assets.XPCommon
        card.Edge.Color = item.color
        card.UnitName.Text = item.name
        card.NewUnit.Visible = item.isNew == true
        card.Level.Text = "LV. " .. item.level
        card.Fallback.Text = "?"
        card.Fallback.Visible = true
        card.UnitModel.Visible = false
        card.Motion.Scale = 1
        setXP(card, item, 1)
        card.Parent = holder
        table.insert(s.cards, card)
        s.cardItems[card] = item
        item.card = card
        totalXP += item.count
        if item.isNew then totalNew += 1 end
    end
    s.layout.Rewards.Totals.Text = totalXP .. " XP" .. (totalNew > 0 and ("  /  " .. totalNew .. " NEW " .. (totalNew == 1 and "UNIT" or "UNITS")) or "  /  ADDED TO YOUR COLLECTION")
end

local function mountModel(viewport, fallback, item)
    viewport.Visible = false
    fallback.Visible = true
    if not item.model then return false end
    local ok, shown = pcall(UnitViewport.show, viewport, item.model)
    if not ok or not shown then clearViewport(viewport); return false end
    viewport.Visible = true
    fallback.Visible = false
    return true
end

local function updateViewports(s)
    local holder = s.layout.Rewards.Cards
    local showing = s.layout.Rewards.Visible
    local position, size = holder.AbsolutePosition, holder.AbsoluteSize
    local count = 0
    for _, card in ipairs(s.cards) do
        local p, z = card.AbsolutePosition, card.AbsoluteSize
        local visible = showing and card.Visible and z.X > 0 and z.Y > 0
            and p.Y + z.Y > position.Y and p.Y < position.Y + size.Y
            and p.X + z.X > position.X and p.X < position.X + size.X
        if visible then count += 1 end
        if visible and count <= 18 then
            if not s.mounted[card] then
                s.mounted[card] = true
                mountModel(card.UnitModel, card.Fallback, s.cardItems[card])
            end
        elseif s.mounted[card] then
            clearViewport(card.UnitModel)
            s.mounted[card] = nil
            card.UnitModel.Visible = false
            card.Fallback.Visible = true
        end
    end
end

local function select(s, button)
    local kind = UserInputService:GetLastInputType()
    if kind.Name:match("Gamepad") and live(s) then GuiService.SelectedObject = button end
end

local function fit(s)
    local insetOK, fullRect = pcall(function() return GuiService:GetInsetArea(Enum.ScreenInsets.None) end)
    for _, decoration in ipairs({s.gui.Background, s.gui.Flash}) do
        if insetOK and typeof(fullRect) == "Rect" then
            decoration.Position = UDim2.fromOffset(fullRect.Min.X, fullRect.Min.Y)
            decoration.Size = UDim2.fromOffset(fullRect.Width, fullRect.Height)
        else
            decoration.Position = UDim2.fromScale(0, 0)
            decoration.Size = UDim2.fromScale(1, 1)
        end
    end
    local size = s.gui.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return nil end
    local ratio = size.X / size.Y
    local name = ratio < .85 and "Portrait" or "Landscape"
    if ratio >= 1.4 and size.Y < 520 and s.gui:FindFirstChild("CompactLandscape") then
        name = "CompactLandscape"
    end
    local layout = s.gui[name]
    local authorSize = s.authored[layout].Size
    layout.Fit.Scale = math.max(.1, math.min((size.X - 16) / authorSize.X.Offset, (size.Y - 16) / authorSize.Y.Offset))
    return layout
end

local function settle(s)
    if not live(s) then return end
    stopVisuals(s)
    s.layout.Opening.Visible = false
    s.layout.Showcase.Visible = false
    s.layout.Rewards.Visible = true
    s.layout.Skip.Visible = false
    s.layout.Header.Visible = false
    s.layout.Subheading.Visible = false
    theme(s, s.packColor)
    prepareCards(s)
    for _, card in ipairs(s.cards) do
        card.Visible = true
        card.Motion.Scale = 1
        setXP(card, s.cardItems[card], 1)
    end
    s.layout.Rewards.Empty.Visible = #s.items == 0
    s.layout.Rewards.Continue.Visible = true
    phase(s, "Results")
    updateViewports(s)
    select(s, s.layout.Rewards.Continue)
end

local function foil(s)
    local gradient = s.layout.Opening.Pack.Foil.Shine.Sweep
    gradient.Offset = Vector2.new(-1.2, 0)
    tween(s, gradient, .85, {Offset = Vector2.new(1.2, 0)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function showHero(s, item, token)
    local show = s.layout.Showcase
    phase(s, "Mystery")
    s.layout.Rewards.Visible = false
    updateViewports(s)
    s.layout.Showcase.Visible = true
    show.Continue.Visible = false
    show.Hero.Visible = false
    show.Mystery.Visible = true
    show.Mystery.Image = Assets["XP" .. item.rarity] or Assets.XPCommon
    local mysteryPose = s.authored[show.Mystery]
    show.Mystery.Size = mysteryPose.Size
    show.Mystery.Rotation = 0
    show.Mystery.Motion.Scale = reduced(s) and 1 or .88
    show.Kicker.Text = "NEW UNIT DISCOVERED"
    show.Rarity.Text = string.upper(item.rarity)
    show.Rarity.TextColor3 = item.color
    show.UnitName.Text = "?"
    show.Subtitle.Text = "WHO WILL JOIN YOUR TEAM?"
    theme(s, item.color)
    playSound(s, "Windup")
    tween(s, show.Mystery.Motion, .55, {Scale = 1.04}, Enum.EasingStyle.Quint)
    if not pause(s, token, reduced(s) and .2 or .58) then return false end
    if not reduced(s) then
        tween(s, show.Mystery, .14, {Size = UDim2.new(0, 0, mysteryPose.Size.Y.Scale, mysteryPose.Size.Y.Offset)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        if not pause(s, token, .15) then return false end
    end
    show.Mystery.Visible = false
    show.Hero.Visible = true
    show.Hero.Motion.Scale = reduced(s) and 1 or .88
    show.UnitName.Text = item.name
    show.Subtitle.Text = item.count > 0 and ("UNLOCKED  /  +" .. item.count .. " XP") or "ADDED TO YOUR COLLECTION"
    show.Hero.Fallback.Text = item.name
    mountModel(show.Hero.UnitModel, show.Hero.Fallback, item)
    phase(s, "Showcase")
    playSound(s, "Reveal")
    flash(s, item.color)
    burst(s, show.Hero.AbsolutePosition + show.Hero.AbsoluteSize / 2, 12, false)
    celebrate(s, show.Hero.AbsolutePosition + show.Hero.AbsoluteSize / 2)
    tween(s, show.Hero.Motion, .4, {Scale = 1}, Enum.EasingStyle.Back)
    if not pause(s, token, duration(s, "NewUnitHoldSeconds", 1.15, .3, 5)) then return false end
    show.Continue.Visible = true
    show.Continue.Label.Text = "CONTINUE"
    s.advanceHero = false
    phase(s, "ShowcaseReady")
    select(s, show.Continue)
    repeat
        if not pause(s, token, .05) then return false end
    until s.advanceHero
    playSound(s, "Continue")
    clearViewport(show.Hero.UnitModel)
    return valid(s, token)
end

local function showRewards(s, token)
    s.layout.Opening.Visible = false
    s.layout.Header.Visible = false
    s.layout.Subheading.Visible = false
    s.layout.Rewards.Visible = true
    s.layout.Rewards.Continue.Visible = false
    prepareCards(s)
    phase(s, "Rewards")
    local duplicates = 0
    for _, item in ipairs(s.items) do if not item.isNew then duplicates += 1 end end
    local beat = math.min(duration(s, "XPBeatSeconds", .38, .08, .8), duplicates > 0 and 3.2 / duplicates or .38)
    beat = math.max(.035, beat)
    for _, item in ipairs(s.items) do
        if not valid(s, token) then return end
        if not item.isNew then
            local card = item.card
            card.Visible = true
            card.Motion.Scale = reduced(s) and 1 or .84
            setXP(card, item, 0)
            s.counters[card] = {item = item, started = os.clock(), duration = reduced(s) and .12 or .34}
            tween(s, card.Motion, .3, {Scale = 1}, Enum.EasingStyle.Back)
            if os.clock() - s.lastTick > .09 then playSound(s, "Tick"); s.lastTick = os.clock() end
            updateViewports(s)
            if not pause(s, token, reduced(s) and math.min(beat, .08) or beat) then return end
        end
    end
    if duplicates > 0 and not pause(s, token, .28) then return end
    for _, item in ipairs(s.items) do
        if item.isNew and not showHero(s, item, token) then return end
    end
    if valid(s, token) then settle(s); playSound(s, "Land") end
end

local function sequence(s, token)
    local pack = s.layout.Opening.Pack
    local pose = s.authored[pack]
    foil(s)
    playSound(s, "Windup")
    s.layout.Opening.Hint.Text = ""
    s.layout.Opening.Subhint.Text = ""
    if not reduced(s) then
        tween(s, pack.Motion, .16, {Scale = .94}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
        tween(s, pack, .16, {Rotation = pose.Rotation - 4})
        if not pause(s, token, .17) then return end
        tween(s, pack, .16, {Rotation = pose.Rotation + 3})
        tween(s, pack.Motion, .26, {Scale = 1.045}, Enum.EasingStyle.Quint)
        if not pause(s, token, .15) then return end
    end
    phase(s, "Tearing")
    tween(s, pack, .2, {Rotation = pose.Rotation})
    pack.Seam.BackgroundTransparency = .38
    pack.SeamProgress.BackgroundTransparency = .05
    local seamSize = s.authored[pack.Seam].Size
    pack.SeamProgress.Size = UDim2.new(0, 0, seamSize.Y.Scale, seamSize.Y.Offset)
    tween(s, pack.SeamProgress, .34, {Size = seamSize}, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    if not pause(s, token, reduced(s) and .12 or .35) then return end
    playSound(s, "Tear")
    pack.ImageTransparency = 1
    pack.Seal.Visible = true
    pack.Body.Visible = true
    pack.Foil.Visible = false
    pack.Seam.BackgroundTransparency = 1
    pack.SeamProgress.BackgroundTransparency = 1
    flash(s, s.packColor)
    local center = pack.AbsolutePosition + Vector2.new(pack.AbsoluteSize.X / 2, pack.AbsoluteSize.Y * .14)
    burst(s, center, 9, true)
    local sealPosition = s.authored[pack.Seal].Position
    local bodyPosition = s.authored[pack.Body].Position
    if reduced(s) then
        tween(s, pack.Seal, .1, {GroupTransparency = 1})
        tween(s, pack.Body, .1, {GroupTransparency = 1})
    else
        tween(s, pack.Seal, .52, {Position = sealPosition + UDim2.fromScale(.38, -.56), Rotation = -26, GroupTransparency = 1}, Enum.EasingStyle.Quart)
        tween(s, pack.Body, .42, {Position = bodyPosition + UDim2.fromScale(-.06, .24), Rotation = 5, GroupTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    end
    if not pause(s, token, reduced(s) and .14 or .45) then return end
    showRewards(s, token)
end

function PackReveal.revealNow()
    local s = current
    if not s or not live(s) or s.phase ~= "Opening" then return end
    phase(s, "Unsealing")
    local token = s.token
    task.spawn(function()
        local ok, message = xpcall(function() sequence(s, token) end, debug.traceback)
        if not ok then
            warn("Pack reveal sequence: " .. tostring(message))
            if valid(s, token) then
                local settled = pcall(settle, s)
                if not settled then finish(s) end
            end
        end
    end)
end

function PackReveal.skip()
    local s = current
    if not s or not live(s) or s.phase == "Results" then return end
    settle(s)
end

function PackReveal.close()
    requestVersion += 1
    if current then finish(current) end
end

function PackReveal.isOpen()
    return current ~= nil and live(current)
end

local function advance(s)
    if not live(s) then return end
    if s.phase == "Opening" then PackReveal.revealNow()
    elseif s.phase == "ShowcaseReady" then s.advanceHero = true
    elseif s.phase == "Results" then
        local cue = s.gui.Sounds:FindFirstChild("Continue")
        if s.gui:GetAttribute("SoundEnabled") ~= false and cue and cue:IsA("Sound") then
            SoundService:PlayLocalSound(cue)
        end
        finish(s)
    end
end

local function bind(s)
    for _, layout in ipairs(layouts(s.gui)) do
        connect(s, layout.Opening.Pack.Activated, function() if s.layout == layout then PackReveal.revealNow() end end)
        connect(s, layout.Skip.Activated, function() if s.layout == layout then PackReveal.skip() end end)
        connect(s, layout.Showcase.Continue.Activated, function() if s.layout == layout then advance(s) end end)
        connect(s, layout.Rewards.Continue.Activated, function() if s.layout == layout then advance(s) end end)
    end
    connect(s, s.gui:GetAttributeChangedSignal("SoundEnabled"), function()
        if s.gui:GetAttribute("SoundEnabled") == false then
            for sound in pairs(s.sounds) do sound:Destroy() end
            table.clear(s.sounds)
        end
    end)
    connect(s, s.gui:GetPropertyChangedSignal("Enabled"), function()
        if current == s and not s.gui.Enabled then finish(s) end
    end)
    connect(s, s.gui.Destroying, function() finish(s) end)
    connect(s, s.gui.AncestryChanged, function()
        if not s.gui:IsDescendantOf(s.playerGui) then finish(s) end
    end)
    local function resize()
        if not live(s) then return end
        local layout = fit(s)
        if layout and layout ~= s.layout then
            stopVisuals(s)
            clearCards(s)
            s.layout = layout
            for _, available in ipairs(layouts(s.gui)) do available.Visible = available == layout end
            settle(s)
        end
    end
    connect(s, s.gui:GetPropertyChangedSignal("AbsoluteSize"), resize)
    connect(s, s.gui:GetPropertyChangedSignal("AbsolutePosition"), resize)
    local function action(_, state, input)
        if not live(s) then return Enum.ContextActionResult.Pass end
        if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
        if state == Enum.UserInputState.Begin then
            if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
                if s.phase == "Results" then finish(s) else PackReveal.skip() end
            elseif GuiService.SelectedObject == s.layout.Skip and s.layout.Skip.Visible then
                PackReveal.skip()
            else advance(s) end
        end
        return Enum.ContextActionResult.Sink
    end
    ContextActionService:BindActionAtPriority(actionName, action, false, Enum.ContextActionPriority.High.Value + 10,
        Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
    s.actionsBound = true
    local clock, viewportClock, foilClock = 0, 0, 0
    connect(s, RunService.RenderStepped, function(dt)
        if not live(s) then return end
        clock += dt
        viewportClock += dt
        foilClock += dt
        if s.phase == "Opening" and not reduced(s) then
            s.layout.Opening.Pack.Motion.Scale = 1 + math.sin(clock * 2.1) * .012
        end
        if not reduced(s) then
            s.gui.Atmosphere.Rays.Rotation = clock * 2
            s.gui.Atmosphere.Aura.Rotation = math.sin(clock * .2) * 5
        end
        if foilClock > 3.1 then
            foilClock = 0
            if s.phase == "Opening" then foil(s) end
        end
        for card, counter in pairs(s.counters) do
            if card.Parent then
                local alpha = math.clamp((os.clock() - counter.started) / counter.duration, 0, 1)
                setXP(card, counter.item, 1 - (1 - alpha) ^ 3)
                if alpha >= 1 then s.counters[card] = nil end
            else s.counters[card] = nil end
        end
        if viewportClock > .12 then viewportClock = 0; updateViewports(s) end
    end)
end

function PackReveal.play(playerGui, received, onDone)
    requestVersion += 1
    local requested = requestVersion
    if current then finish(current) end
    if requested ~= requestVersion then safeCall(onDone); return false end
    local gui = playerGui:FindFirstChild("PackRevealGui") or playerGui:WaitForChild("PackRevealGui", 10)
    if requested ~= requestVersion then safeCall(onDone); return false end
    if not gui or not gui:FindFirstChild("Landscape") or not gui:FindFirstChild("Portrait") then
        warn("Pack opening v2 needs its editable PackRevealGui installed in StarterGui.")
        safeCall(onDone)
        return false
    end
    if cachedGui ~= gui then cachedGui = gui; authored = snapshot(gui) end
    local data, items = collect(received)
    local s = {
        gui = gui, playerGui = playerGui, authored = authored, data = data, items = items,
        callback = onDone, token = 1, closed = false, phase = "Opening", connections = {},
        tweens = {}, sounds = {}, particles = {}, cards = {}, cardItems = {}, mounted = {}, counters = {},
        previousSelection = GuiService.SelectedObject, lastTick = -math.huge,
        packColor = packColors[data.packId] or packColors.gold,
    }
    current = s
    local ok, message = xpcall(function()
        restore(s)
        gui.Enabled = true
        s.layout = fit(s) or gui.Landscape
        for _, layout in ipairs(layouts(gui)) do layout.Visible = layout == s.layout end
        local layout = s.layout
        layout.Opening.Visible = true
        layout.Rewards.Visible = false
        layout.Showcase.Visible = false
        layout.Header.Visible = true
        layout.Subheading.Visible = true
        layout.Skip.Visible = true
        layout.Header.Text = string.upper(type(data.packName) == "string" and data.packName or packNames[data.packId] or "UNIT PACK")
        layout.Opening.Hint.Text = "TAP TO OPEN"
        layout.Opening.Subhint.Text = "YOUR NEXT TEAMMATE IS WAITING"
        local pack = layout.Opening.Pack
        pack.Image = packImages[data.packId] or Assets.Common
        pack.ImageTransparency = 0
        pack.Seal.Artwork.Image = pack.Image
        pack.Body.Artwork.Image = pack.Image
        pack.Seal.Visible = false
        pack.Body.Visible = false
        pack.Foil.Visible = true
        pack.Motion.Scale = 1
        pack.Seam.BackgroundTransparency = 1
        pack.SeamProgress.BackgroundTransparency = 1
        theme(s, s.packColor)
        phase(s, "Opening")
        bind(s)
        select(s, pack)
        foil(s)
        local token = s.token
        task.spawn(function()
            pcall(function()
                local assets = {pack, gui.Atmosphere.Aura, gui.Templates.Spark}
                for rarity in pairs(rarityOrder) do
                    local image = Assets["XP" .. rarity]
                    if type(image) == "string" and image ~= "" then table.insert(assets, image) end
                end
                local models = ReplicatedStorage:FindFirstChild("UnitModels")
                local queuedModels = {}
                if models then
                    for _, item in ipairs(s.items) do
                        if item.model and not queuedModels[item.model] then
                            queuedModels[item.model] = true
                            local model = models:FindFirstChild(item.model)
                            if model and model:IsA("Model") then table.insert(assets, model) end
                        end
                    end
                end
                for _, sound in ipairs(gui.Sounds:GetChildren()) do
                    if sound:IsA("Sound") then table.insert(assets, sound) end
                end
                ContentProvider:PreloadAsync(assets)
            end)
        end)
        task.delay(duration(s, "AutoOpenDelay", 1.1, .25, 20), function()
            if valid(s, token) and s.phase == "Opening" then PackReveal.revealNow() end
        end)
    end, debug.traceback)
    if not ok then warn("Pack reveal setup: " .. tostring(message)); finish(s); return false end
    return true
end

return PackReveal







