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

local ArenaTravelClient = require(game:GetService("ReplicatedStorage"):WaitForChild("ArenaTravelClient"))
pvpBtn.Activated:Connect(function()
    local success, message = ArenaTravelClient.toDestination("PvP")
    if not success then warn(message) end
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

local unitsOpen = mk("ImageButton", {
    Name = "UnitsOpen", Size = UDim2.fromOffset(110, 82), LayoutOrder = 1,
    BackgroundTransparency = 1, Image = require(ReplicatedStorage:WaitForChild("UnitsUIAssets")).Open,
    ScaleType = Enum.ScaleType.Fit,
}, dock)
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
local shopPage = mk("Frame", {
    Name = "ShopPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
}, content)
ShopUI.build(shopPage)

local UnitsUI = require(ReplicatedStorage:WaitForChild("UnitsUI"))
UnitsUI.build(playerGui)
unitsOpen.Activated:Connect(function()
    overlay.Visible = false
    UnitsUI.open(playerGui)
end)
shopOpen.Activated:Connect(function()
    UnitsUI.close()
    headerTitle.Text = "SHOP"
    openMenu()
end)
overlay.Visible = false
