local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {
    Gold = "rbxassetid://107366517958284",
    XPCommon = "rbxassetid://120964141847007",
    XPEpic = "rbxassetid://117478940416668",
}
local assetModule = ReplicatedStorage:FindFirstChild("PackUIAssets")
if assetModule and assetModule:IsA("ModuleScript") then
    local ok, supplied = pcall(require, assetModule)
    if ok and type(supplied) == "table" then
        for name, asset in pairs(supplied) do
            Assets[name] = asset
        end
    end
end

local C = {
    Plum = Color3.fromRGB(47, 20, 59),
    DeepPlum = Color3.fromRGB(35, 17, 48),
    Gold = Color3.fromRGB(255, 201, 77),
    PaleGold = Color3.fromRGB(255, 242, 190),
    Cream = Color3.fromRGB(255, 250, 233),
    White = Color3.fromRGB(255, 255, 255),
    Green = Color3.fromRGB(73, 187, 75),
    GreenDark = Color3.fromRGB(32, 96, 42),
}
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function make(className, name, parent, properties)
    local item = Instance.new(className)
    item.Name = name
    for key, value in pairs(properties or {}) do
        item[key] = value
    end
    item.Parent = parent
    return item
end

local function frame(parent, name, position, size, zIndex, color, transparency)
    return make("Frame", name, parent, {
        Position = position,
        Size = size,
        BackgroundColor3 = color or C.White,
        BackgroundTransparency = transparency == nil and 1 or transparency,
        BorderSizePixel = 0,
        Active = false,
        Selectable = false,
        ZIndex = zIndex or 10,
    })
end

local function corner(parent, radius)
    return make("UICorner", "Corners", parent, { CornerRadius = UDim.new(0, radius) })
end

local function outline(parent, color, thickness, transparency, name)
    return make("UIStroke", name or "Outline", parent, {
        Color = color or C.DeepPlum,
        Thickness = thickness or 2,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function label(parent, name, value, position, size, textSize, zIndex, color)
    return make("TextLabel", name, parent, {
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = value,
        Font = Enum.Font.PermanentMarker,
        TextSize = textSize,
        TextColor3 = color or C.Cream,
        TextStrokeColor3 = C.DeepPlum,
        TextStrokeTransparency = 0.14,
        TextWrapped = true,
        Active = false,
        Selectable = false,
        ZIndex = zIndex or 15,
    })
end

local function fitText(item, minSize, maxSize)
    item.TextScaled = true
    make("UITextSizeConstraint", "TextLimit", item, {
        MinTextSize = minSize,
        MaxTextSize = maxSize,
    })
    return item
end

local function image(parent, name, asset, position, size, zIndex)
    return make("ImageLabel", name, parent, {
        Position = position,
        Size = size,
        Image = asset,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Fit,
        Active = false,
        Selectable = false,
        ZIndex = zIndex or 11,
    })
end

local function motion(parent)
    return make("UIScale", "Motion", parent, { Scale = 1 })
end

local function button(parent, name, text, position, size, zIndex, selectionOrder)
    local result = make("TextButton", name, parent, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position,
        Size = size,
        Text = "",
        BackgroundColor3 = C.White,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Active = true,
        Selectable = true,
        SelectionOrder = selectionOrder,
        ZIndex = zIndex,
    })
    corner(result, 14)
    outline(result, C.GreenDark, 3, 0)
    make("UIGradient", "Finish", result, {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(169, 243, 120)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(89, 203, 86)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 156, 65)),
        }),
        Rotation = 90,
    })
    local shine = frame(result, "Lip", UDim2.new(0, 13, 0, 3), UDim2.new(1, -26, 0, 2), zIndex + 1, C.White, 0.56)
    corner(shine, 1)
    local caption = label(result, "Label", text, UDim2.fromScale(0.04, 0), UDim2.fromScale(0.92, 1), 29, zIndex + 2)
    caption.TextStrokeColor3 = C.GreenDark
    fitText(caption, 16, 29)
    motion(result)
    return result
end

local gui = make("ScreenGui", "PackRevealGui", nil, {
    Enabled = false,
    ResetOnSpawn = false,
    DisplayOrder = 220,
    IgnoreGuiInset = false,
    ClipToDeviceSafeArea = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui:SetAttribute("Revision", "Cinematic20260926")
gui:SetAttribute("AutoOpenDelay", 1.1)
gui:SetAttribute("ReducedMotion", false)
gui:SetAttribute("SoundEnabled", true)
gui:SetAttribute("XPBeatSeconds", 0.38)
gui:SetAttribute("NewUnitHoldSeconds", 1.15)

local background = frame(gui, "Background", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 1, C.White, 0)
make("UIGradient", "ThemeGradient", background, {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(82, 40, 82)),
        ColorSequenceKeypoint.new(0.22, Color3.fromRGB(190, 112, 45)),
        ColorSequenceKeypoint.new(0.49, Color3.fromRGB(255, 217, 133)),
        ColorSequenceKeypoint.new(0.71, Color3.fromRGB(216, 151, 58)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(73, 32, 73)),
    }),
    Rotation = 20,
})

local atmosphere = frame(gui, "Atmosphere", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
atmosphere.ClipsDescendants = true
local aura = image(atmosphere, "Aura", SMOKE, UDim2.fromScale(0.5, 0.48), UDim2.fromScale(1.12, 1.52), 2)
aura.AnchorPoint = Vector2.new(0.5, 0.5)
aura.ImageColor3 = C.PaleGold
aura.ImageTransparency = 0.27
make("UIAspectRatioConstraint", "RoundAura", aura, { AspectRatio = 1 })
local rays = frame(atmosphere, "Rays", UDim2.fromScale(0.5, 0.48), UDim2.fromScale(1.7, 1.7), 3)
rays.AnchorPoint = Vector2.new(0.5, 0.5)
make("UIAspectRatioConstraint", "RoundRays", rays, { AspectRatio = 1 })
for index = 1, 14 do
    local ray = frame(rays, string.format("Ray%02d", index), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.006 + (index % 3) * 0.003, 0.96), 3, C.Cream, 0.72)
    ray.AnchorPoint = Vector2.new(0.5, 0.5)
    ray.Rotation = (index - 1) * 360 / 14 + 9
    make("UIGradient", "Falloff", ray, {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.22, 0.9),
            NumberSequenceKeypoint.new(0.4, 0.14),
            NumberSequenceKeypoint.new(0.5, 0.65),
            NumberSequenceKeypoint.new(0.6, 0.14),
            NumberSequenceKeypoint.new(0.78, 0.9),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
end
local motes = frame(atmosphere, "Motes", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 4)
local motePositions = {
    {0.11, 0.27, 16}, {0.18, 0.68, 10}, {0.28, 0.18, 9}, {0.33, 0.73, 12},
    {0.73, 0.2, 13}, {0.82, 0.67, 11}, {0.9, 0.36, 17}, {0.65, 0.83, 8},
}
for index, position in ipairs(motePositions) do
    local mote = image(motes, "Mote" .. index, SPARK, UDim2.fromScale(position[1], position[2]), UDim2.fromOffset(position[3], position[3]), 4)
    mote.AnchorPoint = Vector2.new(0.5, 0.5)
    mote.ImageColor3 = C.PaleGold
    mote.ImageTransparency = 0.35 + (index % 3) * 0.1
end
frame(gui, "Flash", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 90, C.White, 1)
frame(gui, "Particles", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 80)

local function viewport(parent, name, position, size, zIndex)
    return make("ViewportFrame", name, parent, {
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(187, 173, 204),
        LightColor = Color3.fromRGB(255, 242, 211),
        LightDirection = Vector3.new(-0.8, -1, -1.8),
        Active = false,
        Selectable = false,
        ZIndex = zIndex,
    })
end

local function createLayout(name, portrait)
    local width, height = portrait and 460 or 1280, portrait and 820 or 800
    local board = frame(gui, name, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(width, height), 10)
    board.AnchorPoint = Vector2.new(0.5, 0.5)
    board.Visible = not portrait
    board:SetAttribute("AuthoringWidth", width)
    board:SetAttribute("AuthoringHeight", height)
    make("UIScale", "Fit", board, { Scale = 1 })

    local subheading = label(board, "Subheading", "ANIME COMBAT UNITS", UDim2.fromOffset(24, portrait and 22 or 20), UDim2.fromOffset(width - 48, 26), portrait and 17 or 19, 16, C.PaleGold)
    subheading.TextStrokeTransparency = 0.28
    local header = label(board, "Header", "GOLD PACK", UDim2.fromOffset(24, portrait and 52 or 49), UDim2.fromOffset(width - 48, portrait and 52 or 59), portrait and 37 or 48, 16)
    fitText(header, 25, portrait and 37 or 48)

    local opening = frame(board, "Opening", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10)
    local packWidth, packHeight = portrait and 228 or 280, portrait and 374 or 460
    local pack = make("ImageButton", "Pack", opening, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(width / 2, portrait and 386 or 385),
        Size = UDim2.fromOffset(packWidth, packHeight),
        Image = Assets.Gold,
        ScaleType = Enum.ScaleType.Stretch,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Active = true,
        Selectable = true,
        SelectionOrder = 10,
        ZIndex = 12,
    })
    motion(pack)
    local seal = make("CanvasGroup", "Seal", pack, {
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 0.14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = false,
        Visible = false,
        ZIndex = 13,
    })
    local sealArt = image(seal, "Artwork", Assets.Gold, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1 / 0.14), 13)
    sealArt.ScaleType = Enum.ScaleType.Stretch
    local body = make("CanvasGroup", "Body", pack, {
        Position = UDim2.fromScale(0, 0.14),
        Size = UDim2.fromScale(1, 0.86),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = false,
        Visible = false,
        ZIndex = 13,
    })
    local bodyArt = image(body, "Artwork", Assets.Gold, UDim2.fromScale(0, -0.14 / 0.86), UDim2.fromScale(1, 1 / 0.86), 13)
    bodyArt.ScaleType = Enum.ScaleType.Stretch

    local foil = frame(pack, "Foil", UDim2.fromScale(0.052, 0.105), UDim2.fromScale(0.896, 0.79), 14)
    foil.ClipsDescendants = true
    local shine = frame(foil, "Shine", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, C.White, 0)
    make("UIGradient", "Sweep", shine, {
        Rotation = 23,
        Offset = Vector2.new(-1.3, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.33, 1),
            NumberSequenceKeypoint.new(0.43, 0.96),
            NumberSequenceKeypoint.new(0.51, 0.67),
            NumberSequenceKeypoint.new(0.59, 0.95),
            NumberSequenceKeypoint.new(0.71, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
    frame(pack, "Seam", UDim2.fromScale(0.03, 0.14), UDim2.fromScale(0.94, 0.008), 17, C.PaleGold, 1)
    frame(pack, "SeamProgress", UDim2.fromScale(0.03, 0.14), UDim2.fromScale(0, 0.01), 18, C.White, 0)
    label(opening, "Hint", "TAP TO OPEN", UDim2.fromOffset(24, portrait and 620 or 652), UDim2.fromOffset(width - 48, 43), portrait and 27 or 29, 16)
    local subhint = label(opening, "Subhint", "A NEW CHAMPION COULD BE INSIDE", UDim2.fromOffset(24, portrait and 668 or 699), UDim2.fromOffset(width - 48, 26), portrait and 13 or 17, 16, C.PaleGold)
    subhint.TextStrokeTransparency = 0.3

    local rewards = frame(board, "Rewards", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20)
    rewards.Visible = false
    label(rewards, "Title", "YOUR REWARDS", UDim2.fromOffset(20, portrait and 125 or 122), UDim2.fromOffset(width - 40, 44), portrait and 27 or 35, 22)
    local cards = make("ScrollingFrame", "Cards", rewards, {
        Position = UDim2.fromOffset(portrait and 11 or 86, portrait and 181 or 185),
        Size = UDim2.fromOffset(portrait and 438 or 1108, portrait and 436 or 425),
        CanvasSize = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = portrait and 3 or 5,
        ScrollBarImageColor3 = C.PaleGold,
        ScrollBarImageTransparency = 0.23,
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Selectable = false,
        ZIndex = 21,
    })
    make("UIGridLayout", "Grid", cards, {
        CellSize = UDim2.fromOffset(portrait and 126 or 186, portrait and 188 or 264),
        CellPadding = UDim2.fromOffset(portrait and 14 or 18, portrait and 16 or 22),
        FillDirection = Enum.FillDirection.Horizontal,
        FillDirectionMaxCells = portrait and 3 or 5,
        StartCorner = Enum.StartCorner.TopLeft,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    make("UIPadding", "Padding", cards, {
        PaddingLeft = UDim.new(0, portrait and 10 or 24),
        PaddingRight = UDim.new(0, portrait and 10 or 24),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 14),
    })
    local empty = label(rewards, "Empty", "NO UNIT REWARDS IN THIS PACK", UDim2.fromOffset(32, portrait and 326 or 335), UDim2.fromOffset(width - 64, 100), portrait and 24 or 30, 24)
    empty.Visible = false
    local totals = label(rewards, "Totals", "", UDim2.fromOffset(24, portrait and 633 or 626), UDim2.fromOffset(width - 48, 37), portrait and 18 or 22, 24, C.PaleGold)
    fitText(totals, 12, portrait and 18 or 22)
    local resultsContinue = button(rewards, "Continue", "CONTINUE", UDim2.fromOffset(width / 2, portrait and 710 or 710), UDim2.fromOffset(portrait and 274 or 302, portrait and 55 or 61), 26, 20)

    local showcase = frame(board, "Showcase", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 30)
    showcase.Visible = false
    local kicker = label(showcase, "Kicker", "NEW UNIT DISCOVERED", UDim2.fromOffset(22, portrait and 128 or 121), UDim2.fromOffset(width - 44, 36), portrait and 22 or 28, 34, C.PaleGold)
    fitText(kicker, 16, portrait and 22 or 28)
    label(showcase, "Rarity", "EPIC", UDim2.fromOffset(22, portrait and 169 or 163), UDim2.fromOffset(width - 44, 32), portrait and 22 or 24, 34, Color3.fromRGB(235, 193, 255))
    local hero = frame(showcase, "Hero", UDim2.fromOffset(width / 2, portrait and 409 or 402), UDim2.fromOffset(portrait and 400 or 620, 400), 31)
    hero.AnchorPoint = Vector2.new(0.5, 0.5)
    motion(hero)
    viewport(hero, "UnitModel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 32)
    local heroFallback = label(hero, "Fallback", "?", UDim2.fromScale(0.08, 0.18), UDim2.fromScale(0.84, 0.62), 150, 33)
    heroFallback.Visible = false
    fitText(heroFallback, 28, 150)
    local mystery = image(showcase, "Mystery", Assets.XPEpic, UDim2.fromOffset(width / 2, portrait and 393 or 401), UDim2.fromOffset(portrait and 217 or 249, portrait and 318 or 359), 36)
    mystery.AnchorPoint = Vector2.new(0.5, 0.5)
    mystery.ScaleType = Enum.ScaleType.Stretch
    mystery.Visible = false
    motion(mystery)
    label(mystery, "Question", "?", UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.9), portrait and 146 or 172, 37)
    local unitName = label(showcase, "UnitName", "UNIT NAME", UDim2.fromOffset(26, portrait and 617 or 609), UDim2.fromOffset(width - 52, portrait and 50 or 56), portrait and 37 or 48, 35)
    fitText(unitName, 20, portrait and 37 or 48)
    local subtitle = label(showcase, "Subtitle", "ADDED TO YOUR COLLECTION", UDim2.fromOffset(22, portrait and 671 or 669), UDim2.fromOffset(width - 44, 26), portrait and 14 or 17, 35, C.PaleGold)
    fitText(subtitle, 11, portrait and 14 or 17)
    local heroContinue = button(showcase, "Continue", "CONTINUE", UDim2.fromOffset(width / 2, portrait and 735 or 733), UDim2.fromOffset(portrait and 248 or 286, portrait and 51 or 55), 38, 20)
    heroContinue.Visible = false

    local skip = make("TextButton", "Skip", board, {
        AnchorPoint = Vector2.new(portrait and 0.5 or 1, 0.5),
        Position = UDim2.fromOffset(portrait and width / 2 or width - 33, portrait and 791 or 764),
        Size = UDim2.fromOffset(portrait and 220 or 214, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "SKIP ANIMATION",
        Font = Enum.Font.PermanentMarker,
        TextSize = portrait and 15 or 16,
        TextColor3 = C.PaleGold,
        TextStrokeColor3 = C.DeepPlum,
        TextStrokeTransparency = 0.22,
        AutoButtonColor = false,
        Active = true,
        Selectable = true,
        SelectionOrder = 30,
        ZIndex = 60,
    })
    motion(skip)
    pack.NextSelectionDown = skip
    resultsContinue.NextSelectionDown = skip
    heroContinue.NextSelectionDown = skip
    return board
end

createLayout("Landscape", false)
createLayout("Portrait", true)

local compact = createLayout("CompactLandscape", false)
compact.Visible = false
compact.Size = UDim2.fromOffset(960, 400)
compact:SetAttribute("AuthoringWidth", 960)
compact:SetAttribute("AuthoringHeight", 400)

local function place(object, x, y, width, height, anchorX, anchorY)
    object.AnchorPoint = Vector2.new(anchorX or 0, anchorY or 0)
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(width, height)
end

place(compact.Header, 200, 0, 560, 32)
compact.Header.TextLimit.MinTextSize = 20
compact.Header.TextLimit.MaxTextSize = 29
place(compact.Subheading, 220, 35, 520, 14)
compact.Subheading.TextSize = 13
place(compact.Opening.Pack, 480, 187, 154, 250, 0.5, 0.5)
place(compact.Opening.Hint, 250, 321, 460, 31)
compact.Opening.Hint.TextSize = 25
place(compact.Opening.Subhint, 235, 355, 490, 24)
compact.Opening.Subhint.TextSize = 15

place(compact.Rewards.Title, 20, 0, 920, 44)
compact.Rewards.Title.TextSize = 32
place(compact.Rewards.Cards, 10, 58, 940, 230)
compact.Rewards.Cards.Grid.CellSize = UDim2.fromOffset(154, 218)
compact.Rewards.Cards.Grid.CellPadding = UDim2.fromOffset(16, 16)
compact.Rewards.Cards.Grid.FillDirectionMaxCells = 5
compact.Rewards.Cards.Padding.PaddingLeft = UDim.new(0, 10)
compact.Rewards.Cards.Padding.PaddingRight = UDim.new(0, 10)
compact.Rewards.Cards.Padding.PaddingTop = UDim.new(0, 8)
compact.Rewards.Cards.Padding.PaddingBottom = UDim.new(0, 4)
place(compact.Rewards.Empty, 110, 125, 740, 85)
compact.Rewards.Empty.TextSize = 26
place(compact.Rewards.Totals, 100, 300, 760, 22)
compact.Rewards.Totals.TextLimit.MaxTextSize = 19
place(compact.Rewards.Continue, 480, 358, 300, 64, 0.5, 0.5)

place(compact.Showcase.Hero, 270, 216, 460, 300, 0.5, 0.5)
place(compact.Showcase.Mystery, 270, 210, 187, 270, 0.5, 0.5)
compact.Showcase.Mystery.Question.TextSize = 124
place(compact.Showcase.Kicker, 530, 35, 400, 42)
compact.Showcase.Kicker.TextLimit.MaxTextSize = 23
place(compact.Showcase.Rarity, 540, 90, 380, 28)
compact.Showcase.Rarity.TextSize = 23
place(compact.Showcase.UnitName, 530, 134, 400, 64)
compact.Showcase.UnitName.TextLimit.MinTextSize = 18
compact.Showcase.UnitName.TextLimit.MaxTextSize = 38
place(compact.Showcase.Subtitle, 530, 211, 400, 44)
compact.Showcase.Subtitle.TextLimit.MaxTextSize = 17
place(compact.Showcase.Continue, 730, 335, 300, 64, 0.5, 0.5)

place(compact.Skip, 951, 360, 64, 64, 1, 0.5)
compact.Skip.Text = "SKIP"
compact.Skip.TextSize = 17

local templates = make("Folder", "Templates", gui)
local card = frame(templates, "Card", UDim2.fromScale(0, 0), UDim2.fromOffset(186, 264), 22)
card.Visible = false
motion(card)
outline(card, Color3.fromRGB(213, 213, 225), 1.5, 0.12, "Edge")
make("UICorner", "Corners", card, { CornerRadius = UDim.new(0.072, 0) })
local back = image(card, "Back", Assets.XPCommon, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 22)
back.ScaleType = Enum.ScaleType.Stretch
viewport(card, "UnitModel", UDim2.fromScale(0.06, 0.17), UDim2.fromScale(0.88, 0.44), 24)
local fallback = label(card, "Fallback", "?", UDim2.fromScale(0.09, 0.18), UDim2.fromScale(0.82, 0.4), 64, 25)
fitText(fallback, 18, 64)
fallback.Visible = false
local amount = label(card, "Amount", "+0 XP", UDim2.fromScale(0.07, 0.035), UDim2.fromScale(0.62, 0.12), 26, 26)
amount.TextXAlignment = Enum.TextXAlignment.Left
fitText(amount, 12, 26)
local level = label(card, "Level", "LV. 1", UDim2.fromScale(0.71, 0.048), UDim2.fromScale(0.24, 0.089), 14, 26, C.Cream)
level.BackgroundColor3 = C.DeepPlum
level.BackgroundTransparency = 0.18
fitText(level, 8, 14)
make("UICorner", "Corners", level, { CornerRadius = UDim.new(0.23, 0) })
local fresh = label(card, "NewUnit", "NEW UNIT", UDim2.fromScale(0.205, 0.612), UDim2.fromScale(0.59, 0.085), 18, 27, C.PaleGold)
fresh.BackgroundColor3 = C.DeepPlum
fresh.BackgroundTransparency = 0.12
fresh.Visible = false
fitText(fresh, 10, 18)
make("UICorner", "Corners", fresh, { CornerRadius = UDim.new(0.22, 0) })
local unitName = label(card, "UnitName", "UNIT NAME", UDim2.fromScale(0.06, 0.713), UDim2.fromScale(0.88, 0.114), 22, 26)
fitText(unitName, 10, 22)
local xpTrack = frame(card, "XPTrack", UDim2.fromScale(0.08, 0.866), UDim2.fromScale(0.84, 0.077), 25, C.DeepPlum, 0.06)
xpTrack.ClipsDescendants = true
make("UICorner", "Corners", xpTrack, { CornerRadius = UDim.new(0.25, 0) })
local fill = frame(xpTrack, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), 26, Color3.fromRGB(102, 224, 107), 0)
make("UICorner", "Corners", fill, { CornerRadius = UDim.new(0.25, 0) })
make("UIGradient", "Finish", fill, {
    Color = ColorSequence.new(Color3.fromRGB(162, 244, 111), Color3.fromRGB(44, 185, 90)),
    Rotation = 90,
})
fitText(label(xpTrack, "Value", "0 / 5 XP", UDim2.fromScale(0.035, 0), UDim2.fromScale(0.93, 1), 13, 27), 8, 13)

local spark = image(templates, "Spark", SPARK, UDim2.fromScale(0, 0), UDim2.fromOffset(26, 26), 81)
spark.AnchorPoint = Vector2.new(0.5, 0.5)
spark.ImageColor3 = C.White
spark.Visible = false
local confetti = frame(templates, "Confetti", UDim2.fromScale(0, 0), UDim2.fromOffset(6, 11), 81, C.PaleGold, 0)
confetti.AnchorPoint = Vector2.new(0.5, 0.5)
confetti.Visible = false
local shard = frame(templates, "TearShard", UDim2.fromScale(0, 0), UDim2.fromOffset(9, 17), 81, C.Gold, 0)
shard.AnchorPoint = Vector2.new(0.5, 0.5)
shard.Rotation = 28
shard.Visible = false
make("UIGradient", "Foil", shard, {
    Color = ColorSequence.new(C.PaleGold, Color3.fromRGB(200, 111, 31)),
    Rotation = 34,
})

local sounds = make("Folder", "Sounds", gui)
local cues = {
    { "Windup", "rbxassetid://139719503904449", 0.13, 0.72 },
    { "Tear", "rbxassetid://88442833509532", 0.24, 0.84 },
    { "Tick", "rbxassetid://88442833509532", 0.13, 1.48 },
    { "Reveal", "rbxassetid://116995696565929", 0.32, 0.83 },
    { "Land", "rbxassetid://139719503904449", 0.18, 1.12 },
    { "Continue", "rbxassetid://116995696565929", 0.24, 1.16 },
}
for _, cue in ipairs(cues) do
    make("Sound", cue[1], sounds, {
        SoundId = cue[2],
        Volume = cue[3],
        PlaybackSpeed = cue[4],
        Looped = false,
    })
end

return gui





