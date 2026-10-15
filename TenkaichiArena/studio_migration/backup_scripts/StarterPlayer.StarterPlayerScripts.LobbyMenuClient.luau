-- LobbyMenuClient
-- Persistent lobby UI: top bar (Play + PvP) and a Units / Shop menu.
-- Additive only: does not touch the ring-based mode flow in LobbyClient.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")
local Loadout = require(ReplicatedStorage:WaitForChild("Loadout"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local ShopUI = require(ReplicatedStorage:WaitForChild("ShopUI"))
local LevelPassUI = require(ReplicatedStorage:WaitForChild("LevelPassUI"))

-- Owned collection (placeholder until save data). Equipped state lives in the
-- shared Loadout module so the in-arena bar and this menu stay in sync.
local OWNED = { "Yumcha", "Goku", "Krillen", "Tein", "MasterRoshu" }

-- ── Palette (vibrant & punchy) ────────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(24, 16, 48),
    bg2     = Color3.fromRGB(34, 22, 66),
    panel   = Color3.fromRGB(44, 28, 84),
    panel2  = Color3.fromRGB(56, 36, 104),
    border  = Color3.fromRGB(170, 110, 255),
    accent  = Color3.fromRGB(190, 130, 255),
    btnBg   = Color3.fromRGB(64, 38, 120),
    btnHov  = Color3.fromRGB(96, 60, 175),
    btnTxt  = Color3.fromRGB(238, 224, 255),
    title   = Color3.fromRGB(225, 200, 255),
    sub     = Color3.fromRGB(168, 142, 210),
    close   = Color3.fromRGB(235, 70, 100),
    play    = Color3.fromRGB(80, 225, 130),
    playTxt = Color3.fromRGB(10, 50, 24),
    playDk  = Color3.fromRGB(40, 180, 90),
    gold    = Color3.fromRGB(255, 215, 75),
    goldDk  = Color3.fromRGB(225, 165, 30),
    cellBg  = Color3.fromRGB(52, 32, 98),
    cellHov = Color3.fromRGB(76, 48, 140),
    pvp     = Color3.fromRGB(255, 130, 70),
    shadow  = Color3.fromRGB(8, 4, 20),
}
-- Rarity colors (used to tint units/cards everywhere).
local RARITY = {
    Common    = { main = Color3.fromRGB(150, 165, 185), dark = Color3.fromRGB(95, 108, 128) },
    Rare      = { main = Color3.fromRGB(70, 165, 255),  dark = Color3.fromRGB(35, 105, 200) },
    Epic      = { main = Color3.fromRGB(200, 110, 255), dark = Color3.fromRGB(140, 55, 210) },
    Legendary = { main = Color3.fromRGB(255, 185, 60),  dark = Color3.fromRGB(220, 130, 20) },
}
local function rarityColor(r) return (RARITY[r] or RARITY.Common).main end
local function rarityDark(r) return (RARITY[r] or RARITY.Common).dark end

local function corner(p, r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 14) end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke", p)
    s.Color = col; s.Thickness = th or 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
-- Vertical gradient fill for depth.
local function gradient(p, topCol, botCol, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(topCol, botCol)
    g.Rotation = rot or 90
    g.Parent = p
    return g
end
-- Soft drop shadow behind a frame (a dark, slightly larger rounded image).
local function dropShadow(p, size, transparency)
    local sh = Instance.new("ImageLabel")
    sh.Name = "DropShadow"
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://5554236805"   -- soft rounded shadow
    sh.ImageColor3 = C.shadow
    sh.ImageTransparency = transparency or 0.35
    sh.ScaleType = Enum.ScaleType.Slice
    sh.SliceCenter = Rect.new(23, 23, 277, 277)
    sh.Size = UDim2.new(1, (size or 30)*2, 1, (size or 30)*2)
    sh.Position = UDim2.new(0, -(size or 30), 0, -(size or 30) + 6)
    sh.ZIndex = (p.ZIndex or 1) - 1
    sh.Parent = p
    return sh
end
-- Add juicy hover (scale up) + press (squish) to a button.
local function juicy(btn, baseSize, hoverCol, baseCol)
    local grow = UDim2.new(baseSize.X.Scale, baseSize.X.Offset + 6, baseSize.Y.Scale, baseSize.Y.Offset + 6)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size = grow }):Play()
        if hoverCol then TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol }):Play() end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = baseSize }):Play()
        if baseCol then TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = baseCol }):Play() end
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.06), { Size = baseSize }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = grow }):Play()
    end)
end

local screen = mk("ScreenGui", {
    Name = "LobbyMenuGui", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- ══════════════════════════════════════════════════════════════════════════════
-- PvP BUTTON (sits to the right of the existing PLAY button from LobbyClient)
-- The existing Play button (PlayButtonGui) is 140x44 centred at top, spanning
-- screen-centre -70..+70 px. We place PvP just to its right, vertically aligned.
-- ══════════════════════════════════════════════════════════════════════════════
local pvpBtn = mk("TextButton", {
    Name = "PvPBtn", Size = UDim2.new(0, 130, 0, 44),
    Position = UDim2.new(0.5, 80, 0, 14),
    BackgroundColor3 = C.pvp, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "\xE2\x9A\x94  PvP", TextColor3 = Color3.fromRGB(50, 22, 10),
    Font = Enum.Font.GothamBold, TextSize = 18,
}, screen)
corner(pvpBtn, 22); stroke(pvpBtn, Color3.fromRGB(190, 90, 50), 2)

pvpBtn.MouseEnter:Connect(function()
    TweenService:Create(pvpBtn, TweenInfo.new(0.12),
        { Size = UDim2.new(0,142,0,48), Position = UDim2.new(0.5,74,0,12),
          BackgroundColor3 = Color3.fromRGB(245,150,100) }):Play()
end)
pvpBtn.MouseLeave:Connect(function()
    TweenService:Create(pvpBtn, TweenInfo.new(0.12),
        { Size = UDim2.new(0,130,0,44), Position = UDim2.new(0.5,80,0,14),
          BackgroundColor3 = C.pvp }):Play()
end)

pvpBtn.Activated:Connect(function()
    print("[LobbyMenu] PvP pressed (not wired yet)")
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- SIDE DOCK (Units / Shop openers)
-- ══════════════════════════════════════════════════════════════════════════════
local dock = mk("Frame", {
    Name = "SideDock", Size = UDim2.new(0, 84, 0, 184),
    Position = UDim2.new(0, 16, 0.5, -92), BackgroundTransparency = 1,
}, screen)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Padding = UDim.new(0, 12),
}, dock)

local function dockButton(name, icon, label, order)
    local b = mk("TextButton", {
        Name = name, Size = UDim2.new(0, 84, 0, 84),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", LayoutOrder = order,
    }, dock)
    corner(b, 18); stroke(b, C.border, 3); gradient(b, C.panel2, C.panel, 90); dropShadow(b, 16, 0.4)
    mk("TextLabel", {
        Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,0,10),
        BackgroundTransparency = 1, Text = icon, TextSize = 30,
        Font = Enum.Font.GothamBold, TextColor3 = C.accent,
    }, b)
    mk("TextLabel", {
        Size = UDim2.new(1,0,0,22), Position = UDim2.new(0,0,1,-26),
        BackgroundTransparency = 1, Text = label, TextSize = 13,
        Font = Enum.Font.GothamBold, TextColor3 = C.btnTxt,
    }, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.14), {BackgroundColor3 = C.btnHov}):Play()
        local s = b:FindFirstChildOfClass("UIStroke")
        if s then TweenService:Create(s, TweenInfo.new(0.14), {Thickness = 4}):Play() end
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.14), {BackgroundColor3 = C.panel}):Play()
        local s = b:FindFirstChildOfClass("UIStroke")
        if s then TweenService:Create(s, TweenInfo.new(0.14), {Thickness = 3}):Play() end
    end)
    return b
end

local unitsOpen = dockButton("UnitsOpen", "🥋", "Units", 1)
local shopOpen  = dockButton("ShopOpen", "🛒", "Shop", 2)

-- ══════════════════════════════════════════════════════════════════════════════
-- CURRENCY BAR (left side, above the Units/Shop dock, clear of the chat corner)
-- ══════════════════════════════════════════════════════════════════════════════
local currencyBar = mk("Frame", {
    Name = "CurrencyBar", Size = UDim2.new(0, 132, 0, 120),
    -- dock top edge is at Y = 0.5, -92; place this bar just above it.
    Position = UDim2.new(0, 16, 0.5, -224), BackgroundTransparency = 1,
}, screen)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
}, currencyBar)

local function currencyPill(name, icon, iconColor, order)
    local pill = mk("Frame", {
        Name = name, Size = UDim2.new(0, 132, 0, 34),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order,
    }, currencyBar)
    corner(pill, 17); stroke(pill, C.border, 2); gradient(pill, C.panel2, C.panel, 90)
    mk("TextLabel", {
        Name = "Icon", Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1, Text = icon, TextColor3 = iconColor,
        Font = Enum.Font.GothamBold, TextSize = 18,
    }, pill)
    local val = mk("TextLabel", {
        Name = "Value", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 36, 0, 0),
        BackgroundTransparency = 1, Text = "0", TextColor3 = C.btnTxt,
        Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
    }, pill)
    return val
end

local coinVal  = currencyPill("Coins", "\xF0\x9F\xAA\x99", Color3.fromRGB(255, 205, 70), 1)
local gemVal   = currencyPill("Gems", "\xF0\x9F\x92\x8E", Color3.fromRGB(110, 220, 255), 2)
local chipVal  = currencyPill("Chips", "\xE2\x97\x88", Color3.fromRGB(190, 130, 255), 3)

local function fmtNum(n)
    -- compact thousands display
    if n >= 1000000 then return string.format("%.1fM", n/1000000) end
    if n >= 10000 then return string.format("%.1fK", n/1000) end
    return tostring(n)
end

local function refreshCurrencies()
    coinVal.Text = fmtNum(PlayerData.coins())
    gemVal.Text  = fmtNum(PlayerData.gems())
    chipVal.Text = fmtNum(PlayerData.masteryChips())
end
refreshCurrencies()
PlayerData.Changed:Connect(refreshCurrencies)

-- ── Level / Pass button (above the currency bar; opens the level-pass screen) ──
local levelBtn = mk("TextButton", {
    Name = "LevelBtn", Size = UDim2.new(0, 132, 0, 38),
    Position = UDim2.new(0, 16, 0.5, -270), BackgroundColor3 = C.panel,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "",
}, screen)
corner(levelBtn, 19); stroke(levelBtn, C.gold, 2)
local levelIcon = mk("TextLabel", {
    Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1,
    Text = "\xF0\x9F\x8E\x96\xEF\xB8\x8F", TextColor3 = C.gold, Font = Enum.Font.GothamBold, TextSize = 16,
}, levelBtn)
local levelText = mk("TextLabel", {
    Name = "LevelText", Size = UDim2.new(1, -42, 1, 0), Position = UDim2.new(0, 38, 0, 0),
    BackgroundTransparency = 1, Text = "Level 1", TextColor3 = C.btnTxt,
    Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, levelBtn)
-- unclaimed-rewards badge (red dot with count, top-right of the button)
local levelBadge = mk("TextLabel", {
    Name = "Badge", Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -22, 0, -6),
    BackgroundColor3 = Color3.fromRGB(220, 60, 70), BorderSizePixel = 0, Visible = false,
    Text = "0", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 5,
}, levelBtn)
corner(levelBadge, 10)

local function refreshLevelBtn()
    levelText.Text = "Level " .. PlayerData.level()
    local unclaimed = PlayerData.unclaimedLevelCount()
    levelBadge.Visible = unclaimed > 0
    levelBadge.Text = tostring(unclaimed)
end
refreshLevelBtn()
PlayerData.Changed:Connect(refreshLevelBtn)

levelBtn.MouseEnter:Connect(function() TweenService:Create(levelBtn, TweenInfo.new(0.12), {BackgroundColor3=C.btnHov}):Play() end)
levelBtn.MouseLeave:Connect(function() TweenService:Create(levelBtn, TweenInfo.new(0.12), {BackgroundColor3=C.panel}):Play() end)
levelBtn.Activated:Connect(function() LevelPassUI.open(playerGui) end)

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN MENU PANEL (hosts Units / Shop pages)
-- ══════════════════════════════════════════════════════════════════════════════
local overlay = mk("Frame", {
    Name = "MenuOverlay", Size = UDim2.new(1,0,1,0),
    BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.5,
    BorderSizePixel = 0, Visible = false,
}, screen)

local panel = mk("Frame", {
    Name = "MenuPanel", Size = UDim2.new(0, 880, 0, 560),
    Position = UDim2.new(0.5, -440, 0.5, -280),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 2,
}, overlay)
corner(panel, 26); stroke(panel, C.border, 4); gradient(panel, C.bg2, C.bg, 90)
dropShadow(panel, 40, 0.3)

-- Header
local header = mk("Frame", {
    Size = UDim2.new(1,0,0,60), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, panel)
corner(header, 24); gradient(header, C.panel2, C.panel, 90)
mk("Frame", { -- hide bottom corners of header
    Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,30),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, header)

local headerTitle = mk("TextLabel", {
    Name = "HeaderTitle", Size = UDim2.new(1,-120,1,0), Position = UDim2.new(0,24,0,0),
    BackgroundTransparency = 1, Text = "🥋  UNITS", TextColor3 = C.gold,
    Font = Enum.Font.FredokaOne, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-48,0.5,-18),
    BackgroundColor3 = C.close, BorderSizePixel = 0, Text = "✕",
    TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 16,
}, header)
corner(closeBtn, 18); juicy(closeBtn, UDim2.new(0,36,0,36))

-- Content region (below header)
local content = mk("Frame", {
    Name = "Content", Size = UDim2.new(1,-32,1,-76), Position = UDim2.new(0,16,0,68),
    BackgroundTransparency = 1,
}, panel)

local function openMenu(page)
    overlay.Visible = true
    panel.Size = UDim2.new(0,200,0,140)
    panel.Position = UDim2.new(0.5,-100,0.5,-70)
    panel.Rotation = -4
    TweenService:Create(panel, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0,880,0,560), Position = UDim2.new(0.5,-440,0.5,-280), Rotation = 0 }):Play()
end
local function closeMenu()
    TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        { Size = UDim2.new(0,200,0,140), Position = UDim2.new(0.5,-100,0.5,-70), Rotation = 4 }):Play()
    task.delay(0.2, function() overlay.Visible = false; panel.Rotation = 0 end)
end
closeBtn.Activated:Connect(closeMenu)

-- ══════════════════════════════════════════════════════════════════════════════
-- UNITS PAGE
-- ══════════════════════════════════════════════════════════════════════════════
local unitsPage = mk("Frame", {
    Name = "UnitsPage", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Visible = true,
}, content)

-- Sub-tabs: Collection / Spells
local subTabs = mk("Frame", {
    Size = UDim2.new(0, 320, 0, 38), Position = UDim2.new(0,0,0,0),
    BackgroundTransparency = 1,
}, unitsPage)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8),
}, subTabs)

local function subTab(name, label, order)
    local b = mk("TextButton", {
        Name = name, Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, AutoButtonColor = false,
        Text = label, TextColor3 = C.btnTxt, Font = Enum.Font.GothamBold,
        TextSize = 15, LayoutOrder = order,
    }, subTabs)
    corner(b, 12); stroke(b, C.border, 2)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = C.btnHov}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = (b.BackgroundColor3 == C.btnHov) and C.btnHov or C.panel}):Play()
    end)
    return b
end
local tabCollection = subTab("TabCollection", "Collection", 1)
local tabSpells     = subTab("TabSpells", "Spells", 2)

-- Shared body area below sub-tabs
local body = mk("Frame", {
    Name = "Body", Size = UDim2.new(1,0,1,-50), Position = UDim2.new(0,0,0,50),
    BackgroundTransparency = 1,
}, unitsPage)

-- Grid container (shrinks to side when a cell is selected)
local gridWrap = mk("Frame", {
    Name = "GridWrap", Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, body)
corner(gridWrap, 16); stroke(gridWrap, C.border, 1)
mk("UIPadding", {
    PaddingTop = UDim.new(0,12), PaddingBottom = UDim.new(0,12),
    PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12),
}, gridWrap)

local grid = mk("ScrollingFrame", {
    Name = "Grid", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(0,0,0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarImageColor3 = C.border,
}, gridWrap)
local gridLayout = mk("UIGridLayout", {
    CellSize = UDim2.new(0, 92, 0, 92), CellPadding = UDim2.new(0, 12, 0, 12),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

-- Detail panel (hidden until a cell is selected; fills right side)
local detail = mk("Frame", {
    Name = "Detail", Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
}, body)
corner(detail, 18); local detailStroke = stroke(detail, C.border, 3)
gradient(detail, C.panel2, C.bg2, 90)
mk("UIPadding", {
    PaddingTop = UDim.new(0,16), PaddingBottom = UDim.new(0,14),
    PaddingLeft = UDim.new(0,16), PaddingRight = UDim.new(0,16),
}, detail)

-- Rarity banner behind the name (tinted per unit in showUnitDetail)
local dRarityBanner = mk("Frame", {
    Name = "RarityBanner", Size = UDim2.new(1,0,0,60), Position = UDim2.new(0,0,0,-2),
    BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 1,
}, detail)
corner(dRarityBanner, 14)
local dRarityBannerGrad = gradient(dRarityBanner, Color3.fromRGB(255,255,255), Color3.fromRGB(200,200,200), 90)

-- Detail: name + rarity + close
local dName = mk("TextLabel", {
    Name = "DName", Size = UDim2.new(1,-44,0,34), Position = UDim2.new(0,4,0,4),
    BackgroundTransparency = 1, Text = "Unit Name", TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.FredokaOne, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, detail)
local dClose = mk("TextButton", {
    Name = "DClose", Size = UDim2.new(0,32,0,32), Position = UDim2.new(1,-32,0,4),
    BackgroundColor3 = C.close, BorderSizePixel = 0, Text = "\xE2\x86\x90",
    TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 3,
}, detail)
corner(dClose, 16); juicy(dClose, UDim2.new(0,32,0,32))

local dRarity = mk("TextLabel", {
    Name = "DRarity", Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,4,0,38),
    BackgroundTransparency = 1, Text = "Rarity \xE2\x80\xA2 Type \xE2\x80\xA2 Positioning",
    TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, detail)

-- Stats list
local statList = mk("Frame", {
    Name = "Stats", Size = UDim2.new(1,0,0,186), Position = UDim2.new(0,0,0,62),
    BackgroundTransparency = 1, ZIndex = 3,
}, detail)
mk("UIListLayout", { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, statList)

local STAT_FIELDS = {
    {"Health", "\xE2\x80\x94"}, {"Damage", "\xE2\x80\x94"}, {"Range", "\xE2\x80\x94"},
    {"Hit Speed", "\xE2\x80\x94"}, {"Pattern", "\xE2\x80\x94"}, {"Ability", "\xE2\x80\x94"},
}
local STAT_ICON = { Health="\xE2\x9D\xA4\xEF\xB8\x8F", Damage="\xE2\x9A\x94\xEF\xB8\x8F", Range="\xF0\x9F\x8E\xAF",
    ["Hit Speed"]="\xE2\x9A\xA1", Pattern="\xF0\x9F\x92\xA5", Ability="\xE2\x9C\xA8" }
local statValueLabels = {}
for i, sf in ipairs(STAT_FIELDS) do
    local row = mk("Frame", {
        Size = UDim2.new(1,0,0,25), BackgroundColor3 = C.cellBg,
        BorderSizePixel = 0, LayoutOrder = i, ZIndex = 3,
    }, statList)
    corner(row, 9); stroke(row, C.panel2, 1)
    mk("TextLabel", {
        Size = UDim2.new(0,24,1,0), Position = UDim2.new(0,8,0,0), BackgroundTransparency = 1,
        Text = STAT_ICON[sf[1]] or "", TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 4,
    }, row)
    mk("TextLabel", {
        Size = UDim2.new(0.5,-10,1,0), Position = UDim2.new(0,34,0,0),
        BackgroundTransparency = 1, Text = sf[1], TextColor3 = C.sub,
        Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, row)
    local val = mk("TextLabel", {
        Size = UDim2.new(0.5,-12,1,0), Position = UDim2.new(0.5,0,0,0),
        BackgroundTransparency = 1, Text = sf[2], TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    }, row)
    statValueLabels[sf[1]] = val
end

-- Level + XP meter + Level Up (below stats)
local levelRow = mk("Frame", {
    Name = "LevelRow", Size = UDim2.new(1,0,0,34), Position = UDim2.new(0,0,0,256),
    BackgroundColor3 = C.btnBg, BorderSizePixel = 0, ZIndex = 3,
}, detail)
corner(levelRow, 10); stroke(levelRow, C.gold, 2); gradient(levelRow, C.panel2, C.btnBg, 90)
mk("TextLabel", {
    Size = UDim2.new(0.5,-12,1,0), Position = UDim2.new(0,12,0,0),
    BackgroundTransparency = 1, Text = "\xF0\x9F\x8E\x96\xEF\xB8\x8F LEVEL", TextColor3 = C.gold,
    Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, levelRow)
local dLevel = mk("TextLabel", {
    Name = "DLevel", Size = UDim2.new(0.5,-12,1,0), Position = UDim2.new(0.5,0,0,0),
    BackgroundTransparency = 1, Text = "1", TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.FredokaOne, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
}, levelRow)

-- XP meter (under the level row)
local xpMeterTrack = mk("Frame", {
    Name = "XpMeterTrack", Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,0,296),
    BackgroundColor3 = Color3.fromRGB(22,14,46), BorderSizePixel = 0, ZIndex = 3,
}, detail)
corner(xpMeterTrack, 7); stroke(xpMeterTrack, C.panel2, 1)
local xpMeterFill = mk("Frame", {
    Name = "XpMeterFill", Size = UDim2.new(0,0,1,0),
    BackgroundColor3 = Color3.fromRGB(120,200,255), BorderSizePixel = 0, ZIndex = 4,
}, xpMeterTrack)
corner(xpMeterFill, 7); gradient(xpMeterFill, Color3.fromRGB(150,225,255), Color3.fromRGB(80,160,255), 90)
local xpMeterText = mk("TextLabel", {
    Name = "XpMeterText", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
    Text = "", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 5,
}, xpMeterTrack)

-- Level Up button (active only when the meter is full; spends coins)
local levelUpBtn = mk("TextButton", {
    Name = "LevelUpBtn", Size = UDim2.new(1,0,0,38), Position = UDim2.new(0,0,0,318),
    BackgroundColor3 = C.cellBg, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "Level Up", TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 3,
}, detail)
corner(levelUpBtn, 11); local levelUpStroke = stroke(levelUpBtn, C.border, 2)

local masteryBtn = mk("TextButton", {
    Name = "MasteryBtn", Size = UDim2.new(0.5,-5,0,40), Position = UDim2.new(0,0,0,360),
    BackgroundColor3 = C.cellBg, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "⭐  Mastery", TextColor3 = C.btnTxt, Font = Enum.Font.GothamBold, TextSize = 15,
}, detail)
corner(masteryBtn, 11); stroke(masteryBtn, C.accent, 2)

-- Equip / Unequip button (right half of the row). Text + colour set per-unit
-- in showUnitDetail based on current equipped state.
local equipBtn = mk("TextButton", {
    Name = "EquipBtn", Size = UDim2.new(0.5,-5,0,40), Position = UDim2.new(0.5,5,0,360),
    BackgroundColor3 = C.play, BorderSizePixel = 0, AutoButtonColor = false,
    Text = "Equip", TextColor3 = C.playTxt, Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 3,
}, detail)
corner(equipBtn, 11); stroke(equipBtn, C.playDk, 2)
juicy(masteryBtn, UDim2.new(0.5,-5,0,40), C.cellHov, C.cellBg)
juicy(equipBtn, UDim2.new(0.5,-5,0,40), nil, nil)
juicy(levelUpBtn, UDim2.new(1,0,0,38), nil, nil)

-- ── Equip / Unequip state ─────────────────────────────────────────────────────
local currentUnitId = nil   -- unit currently shown in the detail panel
local rebuildCollection      -- forward declaration; assigned after fillGrid/setSubTab
local showUnitDetail         -- forward declaration; defined further below

local function isEquipped(id)
    return Loadout.isEquipped(id)
end

-- Refresh the equip button's look for the currently shown unit.
local function refreshEquipButton()
    if not currentUnitId then equipBtn.Visible = false; return end
    equipBtn.Visible = true
    if Loadout.isEquipped(currentUnitId) then
        -- Equipped units can't be unequipped directly (only swapped out via another unit).
        equipBtn.Text = "Equipped"
        equipBtn.BackgroundColor3 = C.cellBg
        equipBtn.TextColor3 = C.sub
        equipBtn.Active = false
    else
        -- Not equipped: offer to equip (which opens the replace-chooser since team is full).
        equipBtn.Text = "Equip"
        equipBtn.BackgroundColor3 = C.play
        equipBtn.TextColor3 = C.playTxt
        equipBtn.Active = true
    end
end

-- Swap mode: clicking Equip on an unequipped unit makes the 4 equipped cells
-- in the grid glow/pulse. Tapping one unequips it and the new unit takes its slot.
local swapMode = { active = false, newUnitId = nil, conns = {}, tweens = {} }

local function exitSwapMode()
    swapMode.active = false
    swapMode.newUnitId = nil
    for _, t in ipairs(swapMode.tweens) do pcall(function() t:Cancel() end) end
    swapMode.tweens = {}
    for _, c in ipairs(swapMode.conns) do pcall(function() c:Disconnect() end) end
    swapMode.conns = {}
    -- reset any glowing cell strokes
    for _, cell in ipairs(grid:GetChildren()) do
        if cell:IsA("TextButton") then
            local s = cell:FindFirstChildOfClass("UIStroke")
            if s then
                s.Transparency = 0
                local cid = cell:GetAttribute("UnitId")
                if cid then
                    local u = UnitData.get(cid)
                    s.Color = u and rarityColor(u.rarity) or C.border; s.Thickness = 3
                else
                    s.Color = C.border; s.Thickness = 2
                end
            end
        end
    end
end

local function enterSwapMode(newUnitId)
    if swapMode.active then exitSwapMode() end
    swapMode.active = true
    swapMode.newUnitId = newUnitId
    -- glow + bind tap on every equipped cell
    for _, cell in ipairs(grid:GetChildren()) do
        if cell:IsA("TextButton") then
            local cid = cell:GetAttribute("UnitId")
            if cid and Loadout.isEquipped(cid) then
                local s = cell:FindFirstChildOfClass("UIStroke")
                if s then
                    s.Color = C.gold; s.Thickness = 3
                    -- pulse the stroke transparency
                    local tw = TweenService:Create(s,
                        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                        { Transparency = 0.6 })
                    tw:Play()
                    table.insert(swapMode.tweens, tw)
                end
                local conn = cell.Activated:Connect(function()
                    if not swapMode.active then return end
                    local replaced = cid
                    local newId = swapMode.newUnitId
                    exitSwapMode()
                    Loadout.swap(replaced, newId)
                    if rebuildCollection then rebuildCollection() end
                    local u = UnitData.get(newId)
                    if u then showUnitDetail(u) end
                end)
                table.insert(swapMode.conns, conn)
            end
        end
    end
end

equipBtn.Activated:Connect(function()
    if not currentUnitId then return end
    if Loadout.isEquipped(currentUnitId) then return end  -- equipped: no direct action
    -- not equipped: enter swap mode — equipped grid cells glow; tap one to replace it
    enterSwapMode(currentUnitId)
end)
masteryBtn.MouseEnter:Connect(function()
    TweenService:Create(masteryBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.cellHov}):Play()
end)
masteryBtn.MouseLeave:Connect(function()
    TweenService:Create(masteryBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.cellBg}):Play()
end)
masteryBtn.Activated:Connect(function()
    print("[LobbyMenu] Mastery pressed (not wired yet)")
end)

-- ── Level Up: XP meter + coin-gated upgrade ───────────────────────────────────
-- Refreshes the meter, level number, and the Level Up button state for the
-- currently shown unit. Active only when the meter is full (ready to level).
local function refreshLevelUp()
    if not currentUnitId then return end
    local unit = UnitData.get(currentUnitId)
    if not unit then return end
    local lvl = PlayerData.unitLevel(currentUnitId)
    dLevel.Text = tostring(lvl)

    local cur, needed = PlayerData.unitXpProgress(currentUnitId, unit.rarity)
    if needed == nil then
        -- maxed
        xpMeterFill.Size = UDim2.new(1,0,1,0)
        xpMeterText.Text = "MAX LEVEL"
        levelUpBtn.Text = "Maxed"
        levelUpBtn.BackgroundColor3 = C.cellBg
        levelUpBtn.TextColor3 = C.sub
        levelUpBtn.Active = false
        return
    end
    local frac = math.clamp(cur / needed, 0, 1)
    xpMeterFill.Size = UDim2.new(frac, 0, 1, 0)
    xpMeterText.Text = cur .. " / " .. needed .. " XP"

    local ready = PlayerData.unitReadyToLevel(currentUnitId, unit.rarity)
    local cost = PlayerData.unitLevelCost(lvl)
    if ready then
        local canAfford = PlayerData.coins() >= cost
        levelUpBtn.Text = "Level Up  (\xF0\x9F\xAA\x99 " .. cost .. ")"
        levelUpBtn.BackgroundColor3 = canAfford and C.play or Color3.fromRGB(120,70,70)
        levelUpBtn.TextColor3 = canAfford and C.playTxt or Color3.fromRGB(255,200,200)
        levelUpBtn.Active = true
    else
        levelUpBtn.Text = "Need more XP cards"
        levelUpBtn.BackgroundColor3 = C.cellBg
        levelUpBtn.TextColor3 = C.sub
        levelUpBtn.Active = false
    end
end

levelUpBtn.Activated:Connect(function()
    if not currentUnitId then return end
    local unit = UnitData.get(currentUnitId)
    if not unit then return end
    if not PlayerData.unitReadyToLevel(currentUnitId, unit.rarity) then return end
    local cost = PlayerData.unitLevelCost(PlayerData.unitLevel(currentUnitId))
    if PlayerData.coins() < cost then
        -- can't afford: flash red
        local orig = levelUpBtn.BackgroundColor3
        levelUpBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
        task.delay(0.4, function() refreshLevelUp() end)
        return
    end
    if PlayerData.tryLevelUnit(currentUnitId, unit.rarity) then
        -- refresh the detail (stats now reflect the new level) + meter
        local u = UnitData.get(currentUnitId)
        if u then showUnitDetail(u) end
    end
end)
levelUpBtn.MouseEnter:Connect(function()
    if levelUpBtn.Active then levelUpBtn.BackgroundColor3 = Color3.fromRGB(120,240,155) end
end)
levelUpBtn.MouseLeave:Connect(function() refreshLevelUp() end)
-- keep the meter live if coins/xp change while viewing
PlayerData.Changed:Connect(function()
    if detail.Visible and currentUnitId then refreshLevelUp() end
end)

-- ── Spells page (placeholder grid, same structure, shown via sub-tab) ─────────
-- Reuses the same grid/detail; we just swap what populates the grid.

-- ══════════════════════════════════════════════════════════════════════════════
-- SHOP PAGE (placeholder)
-- ══════════════════════════════════════════════════════════════════════════════
local shopPage = mk("Frame", {
    Name = "ShopPage", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Visible = false,
}, content)
ShopUI.build(shopPage)

-- ══════════════════════════════════════════════════════════════════════════════
-- GRID FILL + SELECTION LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local GRID_EXPANDED   = UDim2.new(1, 0, 1, 0)
local GRID_SHRUNK     = UDim2.new(0.46, -8, 1, 0)
local DETAIL_WIDTH    = UDim2.new(0.54, -8, 1, 0)

local function clearGrid()
    for _, ch in ipairs(grid:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
end

local function showDetail()
    detail.Visible = true
    TweenService:Create(gridWrap, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Size = GRID_SHRUNK}):Play()
    TweenService:Create(detail, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Size = DETAIL_WIDTH}):Play()
end
local function hideDetail()
    TweenService:Create(gridWrap, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Size = GRID_EXPANDED}):Play()
    local t = TweenService:Create(detail, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {Size = UDim2.new(0,0,1,0)})
    t:Play()
    t.Completed:Connect(function() detail.Visible = false end)
end
dClose.Activated:Connect(hideDetail)

-- Populate an empty clickable grid of N cells.
-- Build a ViewportFrame icon showing the unit's actual model.
local function makeUnitIcon(parent, modelName)
    local vp = mk("ViewportFrame", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0,
    }, parent)
    local tmpl = UnitModels:FindFirstChild(modelName)
    if not tmpl then return vp end
    local m = tmpl:Clone()
    for _,p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = true end
    end
    m.Parent = vp
    -- frame the face: camera in front of the model looking at the head/torso.
    -- The rig's actual forward is its HumanoidRootPart/PrimaryPart LookVector
    -- (these models face -X, not -Z), so place the camera along that direction
    -- to capture the FRONT (face) rather than a side profile.
    local cf, size = m:GetBoundingBox()
    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
    local forward = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
    -- focus a touch above center (head/torso); pull the camera out front
    local focus = cf.Position + Vector3.new(0, size.Y*0.12, 0)
    local dist = math.max(size.X, size.Y, size.Z) * 0.95
    cam.CFrame = CFrame.lookAt(focus + forward * dist, focus)
    return vp
end

function showUnitDetail(unit)
    if swapMode.active then exitSwapMode() end
    currentUnitId = unit.id
    dName.Text = unit.name
    -- rarity-tinted banner behind the name
    local rc, rd = rarityColor(unit.rarity), rarityDark(unit.rarity)
    dRarityBanner.BackgroundColor3 = rc
    dRarityBannerGrad.Color = ColorSequence.new(rc, rd)
    detailStroke.Color = rc
    dRarity.Text = string.format("%s  \xE2\x80\xA2  %s  \xE2\x80\xA2  %s",
        string.upper(unit.rarity), unit.type, table.concat(unit.lines, "/"))
    -- stats reflect the unit's CURRENT level (compounded +10%/level)
    local curHp, curDmg = PlayerData.unitStats(unit.id, unit.health, unit.damage)
    local lvl = PlayerData.unitLevel(unit.id)
    if lvl > 1 then
        statValueLabels["Health"].Text = tostring(curHp) .. "  (L" .. lvl .. ")"
        statValueLabels["Damage"].Text = tostring(curDmg) .. "  (L" .. lvl .. ")"
    else
        statValueLabels["Health"].Text = tostring(unit.health)
        statValueLabels["Damage"].Text = tostring(unit.damage)
    end
    statValueLabels["Range"].Text = string.format("%s (%d)", unit.range.category, unit.range.value)
    statValueLabels["Hit Speed"].Text = string.format("%.2fs", unit.hitSpeed)
    statValueLabels["Pattern"].Text = unit.damagePattern
    statValueLabels["Ability"].Text = unit.ability or "None"
    dLevel.Text = tostring(lvl)
    refreshLevelUp()
    refreshEquipButton()
    showDetail()
end

-- Populate the grid: owned units first (real cells), then empty slots.
local function fillGrid(count, dataList)
    clearGrid()
    hideDetail()
    dataList = dataList or {}
    for i = 1, count do
        local unitId = dataList[i]
        local cell = mk("TextButton", {
            Name = "Cell"..i, BackgroundColor3 = C.cellBg, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", LayoutOrder = i,
        }, grid)
        corner(cell, 14)
        local cellStroke = stroke(cell, C.border, 2)

        if unitId then
            local unit = UnitData.get(unitId)
            if unit then
                -- rarity-tinted cell
                local rc = rarityColor(unit.rarity)
                cellStroke.Color = rc; cellStroke.Thickness = 3
                gradient(cell, rarityDark(unit.rarity), C.cellBg, 90)
                cell:SetAttribute("UnitId", unitId)
                makeUnitIcon(cell, unit.model)
                -- equipped badge (top-right corner) if this unit is in the loadout
                if isEquipped(unit.id) then
                    local badge = mk("TextLabel", {
                        Name = "EquippedBadge",
                        Size = UDim2.new(0,20,0,20), Position = UDim2.new(1,-22,0,2),
                        BackgroundColor3 = C.play, BorderSizePixel = 0,
                        Text = "\xE2\x9C\x93", TextColor3 = C.playTxt,
                        Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 5,
                    }, cell)
                    corner(badge, 10)
                end
                -- name strip at bottom of the cell
                local strip = mk("TextLabel", {
                    Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,1,-18),
                    BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.4,
                    BorderSizePixel = 0, Text = unit.name, TextColor3 = C.btnTxt,
                    Font = Enum.Font.GothamBold, TextSize = 11,
                }, cell)
                cell.Activated:Connect(function()
                    if swapMode.active then return end  -- swap-mode tap handled separately
                    showUnitDetail(unit)
                end)
            end
        else
            -- empty slot marker
            mk("TextLabel", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
                Text = "+", TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 30,
            }, cell)
            cell.Activated:Connect(function()
                dName.Text = "Empty Slot"
                dRarity.Text = "Rarity \xE2\x80\xA2 Type \xE2\x80\xA2 Positioning"
                statValueLabels["Health"].Text = "\xE2\x80\x94"
                statValueLabels["Damage"].Text = "\xE2\x80\x94"
                statValueLabels["Range"].Text = "\xE2\x80\x94"
                statValueLabels["Hit Speed"].Text = "\xE2\x80\x94"
                statValueLabels["Ability"].Text = "\xE2\x80\x94"
                dLevel.Text = "\xE2\x80\x94"
                xpMeterFill.Size = UDim2.new(0,0,1,0)
                xpMeterText.Text = ""
                levelUpBtn.Text = "\xE2\x80\x94"
                levelUpBtn.Active = false
                levelUpBtn.BackgroundColor3 = C.cellBg
                levelUpBtn.TextColor3 = C.sub
                showDetail()
            end)
        end

        cell.MouseEnter:Connect(function()
            TweenService:Create(cell, TweenInfo.new(0.1), {BackgroundColor3 = C.cellHov}):Play()
            local s = cell:FindFirstChildOfClass("UIStroke")
            if s then TweenService:Create(s, TweenInfo.new(0.1), {Thickness = 4}):Play() end
        end)
        cell.MouseLeave:Connect(function()
            TweenService:Create(cell, TweenInfo.new(0.1), {BackgroundColor3 = C.cellBg}):Play()
            local s = cell:FindFirstChildOfClass("UIStroke")
            if s and not (swapMode.active and s.Color == C.gold) then
                TweenService:Create(s, TweenInfo.new(0.1), {Thickness = unitId and 3 or 2}):Play()
            end
        end)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB / PAGE SWITCHING
-- ══════════════════════════════════════════════════════════════════════════════
local function setSubTab(which)
    local activeCol = C.btnHov
    local idleCol   = C.panel
    tabCollection.BackgroundColor3 = (which == "collection") and activeCol or idleCol
    tabSpells.BackgroundColor3     = (which == "spells") and activeCol or idleCol
    if which == "collection" then
        fillGrid(24, OWNED)   -- owned units fill first, rest empty
    else
        fillGrid(12, {})      -- spells: empty for now
    end
end
-- Rebuild the collection grid in place (used after equip/unequip changes).
rebuildCollection = function()
    if unitsPage.Visible then setSubTab("collection") end
end

tabCollection.Activated:Connect(function() setSubTab("collection") end)
tabSpells.Activated:Connect(function() setSubTab("spells") end)

local function showPage(page)
    unitsPage.Visible = (page == "units")
    shopPage.Visible  = (page == "shop")
    if page == "units" then
        headerTitle.Text = "🥋  UNITS"
        setSubTab("collection")
    else
        headerTitle.Text = "🛒  SHOP"
    end
end

unitsOpen.Activated:Connect(function() openMenu(); showPage("units") end)
shopOpen.Activated:Connect(function() openMenu(); showPage("shop") end)

-- Initialise
showPage("units")
overlay.Visible = false

