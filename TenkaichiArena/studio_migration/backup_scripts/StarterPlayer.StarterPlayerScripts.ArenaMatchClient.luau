-- ArenaMatchClient
-- Handles entering an arena from the lobby: moves the character to the arena
-- sideline, locks the overhead camera, hides lobby UI, and shows the match HUD.
-- Triggered by ReplicatedStorage.ArenaEvents.EnterArena:Fire(arenaName).
-- Unit option-cards and unit logic are intentionally NOT built here (design later).

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")
local Loadout = require(ReplicatedStorage:WaitForChild("Loadout"))
local DraftController = require(ReplicatedStorage:WaitForChild("DraftController"))
local Deployment = require(ReplicatedStorage:WaitForChild("Deployment"))
local CombatController = require(ReplicatedStorage:WaitForChild("CombatController"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette (matches lobby) ───────────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(18, 12, 36),
    panel   = Color3.fromRGB(32, 20, 62),
    border  = Color3.fromRGB(148, 88, 255),
    accent  = Color3.fromRGB(180, 120, 255),
    btnTxt  = Color3.fromRGB(230, 210, 255),
    sub     = Color3.fromRGB(155, 130, 195),
    gold    = Color3.fromRGB(255, 210, 80),
    cellBg  = Color3.fromRGB(40, 24, 78),
    heart   = Color3.fromRGB(235, 70, 90),
    heartOff= Color3.fromRGB(70, 50, 90),
    red     = Color3.fromRGB(200, 70, 90),
    blue    = Color3.fromRGB(80, 110, 220),
}
local function corner(p, r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 12) end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke", p); s.Color = col; s.Thickness = th or 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s
end
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent = parent; return o
end

local MAX_LIVES = 4
local EQUIPPED_SLOTS = 4

-- ══════════════════════════════════════════════════════════════════════════════
-- MATCH HUD (hidden until a match starts)
-- ══════════════════════════════════════════════════════════════════════════════
local hud = mk("ScreenGui", {
    Name = "ArenaHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
    Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- ── Round banner (center-screen "Round 1" / "Battle Start!") ─────────────────
local banner = mk("TextLabel", {
    Name = "RoundBanner", Size = UDim2.new(0, 600, 0, 90),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0),
    BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 230, 130),
    Font = Enum.Font.GothamBlack, TextSize = 56, TextStrokeTransparency = 0.2,
    TextStrokeColor3 = Color3.fromRGB(20, 10, 40), Visible = false, ZIndex = 20,
}, hud)

-- ── End-of-match rewards page (expanded) ─────────────────────────────────────
-- Shows: outcome, currency gains, player XP progress, and per-unit progress
-- (level + mastery, with a spend-chip button). Offers Back to Lobby / Next Match.
local rewardOverlay = mk("Frame", {
    Name = "RewardOverlay", Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.fromRGB(0,0,0),
    BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, ZIndex = 30,
}, hud)
local rewardPanel = mk("Frame", {
    Name = "RewardPanel", Size = UDim2.new(0, 560, 0, 520),
    AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0.5,0),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 31,
}, rewardOverlay)
corner(rewardPanel, 22); stroke(rewardPanel, C.border, 3)

local rewardTitle = mk("TextLabel", {
    Name = "Title", Size = UDim2.new(1,0,0,48), Position = UDim2.new(0,0,0,18),
    BackgroundTransparency = 1, Text = "VICTORY!", TextColor3 = C.gold,
    Font = Enum.Font.GothamBlack, TextSize = 38, ZIndex = 32,
}, rewardPanel)

-- scrolling body for reward sections
local rewardBody = mk("ScrollingFrame", {
    Name = "Body", Size = UDim2.new(1,-36,1,-150), Position = UDim2.new(0,18,0,74),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
    ScrollBarImageColor3 = C.border, CanvasSize = UDim2.new(0,0,0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 32,
}, rewardPanel)
mk("UIListLayout", { Padding = UDim.new(0,12), SortOrder = Enum.SortOrder.LayoutOrder }, rewardBody)
mk("UIPadding", { PaddingRight = UDim.new(0,8) }, rewardBody)

-- a titled section frame inside the body
local function rewardSection(titleText, order)
    local sec = mk("Frame", {
        Name = "Sec_"..titleText, Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 32,
    }, rewardBody)
    corner(sec, 12); stroke(sec, C.border, 1)
    mk("UIPadding", { PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,10),
        PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12) }, sec)
    mk("UIListLayout", { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, sec)
    mk("TextLabel", { Name="SecTitle", Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
        Text=titleText, TextColor3=C.gold, Font=Enum.Font.GothamBold, TextSize=16,
        TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0, ZIndex=33 }, sec)
    return sec
end

-- simple icon+label reward row
local function rewardRow(parent, order, icon, label, color)
    local row = mk("Frame", { Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=order, ZIndex=33 }, parent)
    mk("TextLabel", { Size=UDim2.new(0,32,1,0), BackgroundTransparency=1, Text=icon,
        TextColor3=color, Font=Enum.Font.GothamBold, TextSize=18, ZIndex=34 }, row)
    mk("TextLabel", { Size=UDim2.new(1,-40,1,0), Position=UDim2.new(0,38,0,0), BackgroundTransparency=1,
        Text=label, TextColor3=C.btnTxt, Font=Enum.Font.GothamMedium, TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=34 }, row)
    return row
end

-- bottom buttons
local backLobbyBtn = mk("TextButton", {
    Name = "BackLobby", Size = UDim2.new(0, 250, 0, 46), AnchorPoint = Vector2.new(0,1),
    Position = UDim2.new(0,18,1,-18), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "\xE2\x86\x90  Back to Lobby", TextColor3 = C.btnTxt,
    Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 32,
}, rewardPanel)
corner(backLobbyBtn, 23); stroke(backLobbyBtn, C.border, 2)
local nextMatchBtn = mk("TextButton", {
    Name = "NextMatch", Size = UDim2.new(0, 250, 0, 46), AnchorPoint = Vector2.new(1,1),
    Position = UDim2.new(1,-18,1,-18), BackgroundColor3 = Color3.fromRGB(90,215,130),
    BorderSizePixel = 0, AutoButtonColor = false, Text = "Next Match  \xE2\x96\xB6",
    TextColor3 = Color3.fromRGB(15,50,25), Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 32,
}, rewardPanel)
corner(nextMatchBtn, 23)
for _, b in ipairs({backLobbyBtn, nextMatchBtn}) do
    b.MouseEnter:Connect(function() b.BackgroundColor3 = (b==nextMatchBtn) and Color3.fromRGB(120,240,155) or C.btnHov end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = (b==nextMatchBtn) and Color3.fromRGB(90,215,130) or C.panel end)
end

-- Show the expanded rewards page.
-- data = { playerWon, coins, accountXp, leveledTo, arenaDelta, arenaPoints,
--          milestoneCoins, milestoneGems, unlockedUnits (list),
--          masteryChips, unitMastery (list of {id, name, rarity, gained}) }
-- onLobby() and onNextMatch() are the two button callbacks.
local function showRewards(data, onLobby, onNextMatch)
    for _, ch in ipairs(rewardBody:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    rewardTitle.Text = data.playerWon and "VICTORY!" or "DEFEAT"
    rewardTitle.TextColor3 = data.playerWon and C.gold or Color3.fromRGB(220,90,110)

    -- Currencies section
    local curSec = rewardSection("Currencies", 1)
    local cord = 1
    if data.coins and data.coins > 0 then cord+=1; rewardRow(curSec, cord, "\xF0\x9F\xAA\x99", "+"..data.coins.." Coins", Color3.fromRGB(255,205,70)) end
    if data.milestoneCoins and data.milestoneCoins > 0 then cord+=1; rewardRow(curSec, cord, "\xF0\x9F\x8E\x81", "Milestone: +"..data.milestoneCoins.." Coins", Color3.fromRGB(255,205,70)) end
    if data.milestoneGems and data.milestoneGems > 0 then cord+=1; rewardRow(curSec, cord, "\xF0\x9F\x92\x8E", "Milestone: +"..data.milestoneGems.." Gems", Color3.fromRGB(110,220,255)) end
    if data.masteryChips and data.masteryChips > 0 then cord+=1; rewardRow(curSec, cord, "\xE2\x97\x88", "+"..data.masteryChips.." Mastery Chips", Color3.fromRGB(190,130,255)) end
    if data.dailyPack then
        local pn = (data.dailyPack == "silver") and "Silver" or (data.dailyPack == "gold") and "Gold" or "Bronze"
        cord+=1; rewardRow(curSec, cord, "\xF0\x9F\x8E\x81", "Daily Pack Earned: "..pn.."!  (open it in the lobby)", Color3.fromRGB(255,180,120))
    end

    -- Player XP section (with a bar)
    local xpSec = rewardSection("Player Progress", 2)
    rewardRow(xpSec, 1, "\xE2\xAD\x90", "+"..(data.accountXp or 0).." Account XP", Color3.fromRGB(130,200,255))
    if data.leveledTo then
        rewardRow(xpSec, 2, "\xF0\x9F\x86\x99", "Reached Level "..data.leveledTo.."!", C.gold)
    end
    -- live xp bar
    local xpTrack = mk("Frame", { Size=UDim2.new(1,0,0,12), BackgroundColor3=Color3.fromRGB(20,12,42),
        BorderSizePixel=0, LayoutOrder=3, ZIndex=33 }, xpSec)
    corner(xpTrack, 6)
    local lvl = PlayerData.level()
    local frac = math.clamp(PlayerData.xp() / PlayerData.xpNeeded(), 0, 1)
    local xpFill = mk("Frame", { Size=UDim2.new(frac,0,1,0), BackgroundColor3=Color3.fromRGB(130,200,255),
        BorderSizePixel=0, ZIndex=34 }, xpTrack)
    corner(xpFill, 6)
    mk("TextLabel", { Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, LayoutOrder=4,
        Text="Lv "..lvl.."  \xC2\xB7  "..PlayerData.xp().." / "..PlayerData.xpNeeded().." XP",
        TextColor3=C.sub, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=33 }, xpSec)

    -- Arena points section
    local apSec = rewardSection("Arena Progress", 3)
    local dStr = (data.arenaDelta >= 0 and "+" or "")..data.arenaDelta
    rewardRow(apSec, 1, "\xF0\x9F\x93\x88", dStr.." Arena Points  ("..data.arenaPoints.." total)", Color3.fromRGB(140,220,160))
    if data.unlockedUnits and #data.unlockedUnits > 0 then
        rewardRow(apSec, 2, "\xE2\x9C\xA8", "New Unit Unlockable in Packs!", Color3.fromRGB(255,180,120))
    end

    -- Units section: per-unit mastery gained + a spend-chip button.
    -- You may spend ONE mastery chip on this page (grants +10 to that one unit).
    local uSec = rewardSection("Unit Mastery", 4)
    mk("TextLabel", { Name="SpendHint", Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, LayoutOrder=1,
        Text="Spend \xE2\x97\x88 chips to boost units (+10 each, once per unit):", TextColor3=C.sub,
        Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=33 }, uSec)

    -- Each unit can have ONE chip spent on it (player's discretion). Spending on
    -- one unit does NOT lock the others — you can boost as many units as you have
    -- chips for, but only once per unit per page.
    if data.unitMastery then
        for ui, um in ipairs(data.unitMastery) do
            local row = mk("Frame", { Size=UDim2.new(1,0,0,32), BackgroundTransparency=1, LayoutOrder=ui+1, ZIndex=33 }, uSec)
            mk("TextLabel", { Size=UDim2.new(0,150,1,0), Position=UDim2.new(0,0,0,0), BackgroundTransparency=1,
                Text=um.name, TextColor3=C.btnTxt, Font=Enum.Font.GothamBold, TextSize=13,
                TextXAlignment=Enum.TextXAlignment.Left, ZIndex=34 }, row)
            local progLbl = mk("TextLabel", { Size=UDim2.new(0,120,1,0), Position=UDim2.new(0,150,0,0), BackgroundTransparency=1,
                Text="("..PlayerData.masteryFor(um.id).."/"..PlayerData.masteryThreshold(um.rarity)..")",
                TextColor3=Color3.fromRGB(170,140,230), Font=Enum.Font.GothamMedium, TextSize=13,
                TextXAlignment=Enum.TextXAlignment.Left, ZIndex=34 }, row)

            local spendBtn = mk("TextButton", {
                Size=UDim2.new(0,72,0,26), AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0),
                BackgroundColor3=C.cellBg, BorderSizePixel=0, AutoButtonColor=false,
                Text="\xE2\x97\x88 +10", TextColor3=Color3.fromRGB(190,130,255),
                Font=Enum.Font.GothamBold, TextSize=13, ZIndex=34,
            }, row)
            corner(spendBtn, 8); stroke(spendBtn, Color3.fromRGB(150,100,210), 1)

            local spentOnThisUnit = false
            spendBtn.Activated:Connect(function()
                if spentOnThisUnit then return end
                if PlayerData.masteryChips() < 1 then
                    -- no chips left: flash red
                    local orig = spendBtn.BackgroundColor3
                    spendBtn.BackgroundColor3 = Color3.fromRGB(170,50,50)
                    task.delay(0.4, function()
                        if not spentOnThisUnit then spendBtn.BackgroundColor3 = orig end
                    end)
                    return
                end
                -- spend 1 chip, grant +10 mastery to THIS unit only
                PlayerData.addMasteryChips(-1)
                PlayerData.addMasteryPoints(um.id, 10)
                spentOnThisUnit = true
                -- update this row's progress + mark only THIS button spent
                progLbl.Text = "("..PlayerData.masteryFor(um.id).."/"..PlayerData.masteryThreshold(um.rarity)..")"
                spendBtn.Active = false
                spendBtn.BackgroundColor3 = C.cellBg
                spendBtn.TextColor3 = C.sub
                spendBtn.Text = "Spent"
                local st = spendBtn:FindFirstChildOfClass("UIStroke")
                if st then st.Color = Color3.fromRGB(70,55,100) end
            end)
            spendBtn.MouseEnter:Connect(function()
                if not spentOnThisUnit then spendBtn.BackgroundColor3 = C.panel end
            end)
            spendBtn.MouseLeave:Connect(function()
                if not spentOnThisUnit then spendBtn.BackgroundColor3 = C.cellBg end
            end)
        end
    end

    rewardOverlay.Visible = true
    rewardPanel.Size = UDim2.new(0, 520, 0, 40)
    TweenService:Create(rewardPanel,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 560, 0, 520) }):Play()

    local c1, c2
    c1 = backLobbyBtn.Activated:Connect(function()
        if c1 then c1:Disconnect() end; if c2 then c2:Disconnect() end
        rewardOverlay.Visible = false
        if onLobby then onLobby() end
    end)
    c2 = nextMatchBtn.Activated:Connect(function()
        if c1 then c1:Disconnect() end; if c2 then c2:Disconnect() end
        rewardOverlay.Visible = false
        if onNextMatch then onNextMatch() end
    end)
end

-- Helper: a name + hearts cluster
local function makeLifeCluster(name, anchorCorner)
    -- anchorCorner: "bottomLeft" or "topRight"
    local holder = mk("Frame", {
        Name = (anchorCorner == "bottomLeft") and "PlayerCluster" or "OpponentCluster",
        Size = UDim2.new(0, 240, 0, 64), BackgroundTransparency = 1,
    }, hud)
    if anchorCorner == "bottomLeft" then
        holder.AnchorPoint = Vector2.new(0,1)
        holder.Position = UDim2.new(0, 18, 1, -18)
    else
        holder.AnchorPoint = Vector2.new(1,0)
        holder.Position = UDim2.new(1, -18, 0, 18)
    end

    local nameAlign = (anchorCorner == "bottomLeft") and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    local nameLbl = mk("TextLabel", {
        Name = "NameLbl", Size = UDim2.new(1,0,0,26),
        Position = (anchorCorner == "bottomLeft") and UDim2.new(0,0,0,0) or UDim2.new(0,0,0,0),
        BackgroundTransparency = 1, Text = name, TextColor3 = C.btnTxt,
        Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = nameAlign,
    }, holder)

    local heartsRow = mk("Frame", {
        Name = "Hearts", Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,30),
        BackgroundTransparency = 1,
    }, holder)
    local layout = mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,6),
        HorizontalAlignment = (anchorCorner == "bottomLeft")
            and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, heartsRow)

    local hearts = {}
    for i = 1, MAX_LIVES do
        local h = mk("TextLabel", {
            Name = "Heart"..i, Size = UDim2.new(0,28,0,28),
            BackgroundTransparency = 1, Text = "♥", TextColor3 = C.heart,
            Font = Enum.Font.GothamBold, TextSize = 26, LayoutOrder = i,
        }, heartsRow)
        hearts[i] = h
    end
    return { name = nameLbl, hearts = hearts }
end

local playerCluster   = makeLifeCluster(player.DisplayName, "bottomLeft")
local opponentCluster = makeLifeCluster("Opponent", "topRight")

-- Set lives (greys out lost hearts)
local function setLives(cluster, lives)
    for i, h in ipairs(cluster.hearts) do
        h.Text = (i <= lives) and "♥" or "♡"
        h.TextColor3 = (i <= lives) and C.heart or C.heartOff
    end
end
setLives(playerCluster, MAX_LIVES)
setLives(opponentCluster, MAX_LIVES)

-- ── Equipped units bar (bottom right) ────────────────────────────────────────
local unitBar = mk("Frame", {
    Name = "EquippedBar", Size = UDim2.new(0, EQUIPPED_SLOTS*52 + (EQUIPPED_SLOTS-1)*8 + 16, 0, 64),
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16),
    BackgroundColor3 = C.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0,
}, hud)
corner(unitBar, 16); stroke(unitBar, C.border, 2)
mk("UIPadding", {
    PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8),
    PaddingTop = UDim.new(0,7), PaddingBottom = UDim.new(0,7),
}, unitBar)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,8),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, unitBar)

local function slotIcon(parent, modelName)
    local vp = mk("ViewportFrame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
    local tmpl = UnitModels:FindFirstChild(modelName)
    if not tmpl then return end
    local m = tmpl:Clone()
    for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
    m.Parent = vp
    local cf, size = m:GetBoundingBox()
    local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam
    local focus = cf.Position + Vector3.new(0, size.Y*0.12, 0)
    cam.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -size.Y*0.95), focus)
end

-- (Re)build the equipped bar from the shared Loadout. Called on entering the
-- arena so it always reflects the latest equip/unequip choices.
local function refreshEquippedBar()
    -- clear existing slots
    for _, ch in ipairs(unitBar:GetChildren()) do
        if ch:IsA("Frame") and ch.Name:match("^Slot") then ch:Destroy() end
    end
    local equipped = Loadout.getAll()
    for i = 1, EQUIPPED_SLOTS do
        local slot = mk("Frame", {
            Name = "Slot"..i, Size = UDim2.new(0, 50, 0, 50),
            BackgroundColor3 = C.cellBg, BorderSizePixel = 0, LayoutOrder = i,
        }, unitBar)
        corner(slot, 10); stroke(slot, C.border, 1)
        local unitId = equipped[i]
        if unitId then
            local unit = UnitData.get(unitId)
            if unit then slotIcon(slot, unit.model) end
        else
            mk("TextLabel", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
                Text = tostring(i), TextColor3 = C.sub, Font = Enum.Font.GothamBold, TextSize = 15,
            }, slot)
        end
    end
end
refreshEquippedBar()

-- ── Option-card region (placeholder; cards designed later) ───────────────────
-- This is the empty stage where the 3 randomised choice cards will appear.
-- Intentionally left empty and hidden this pass.
local optionRegion = mk("Frame", {
    Name = "OptionRegion", Size = UDim2.new(0, 520, 0, 220),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0),
    BackgroundTransparency = 1, Visible = false,
}, hud)


-- ══════════════════════════════════════════════════════════════════════════════
-- ENTER / LEAVE LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local lobbyGuiNames = { "PlayButtonGui", "LobbyMenuGui" }  -- Play, PvP, Units, Shop dock
local hiddenGuis = {}
local savedReturn = nil   -- CFrame to return the character to the lobby
local inMatch = false

local function setLobbyUiVisible(visible)
    for _, name in ipairs(lobbyGuiNames) do
        local g = playerGui:FindFirstChild(name)
        if g then g.Enabled = visible end
    end
end

local function getSidelineCFrame(arena)
    local sp = arena:FindFirstChild("Sidelines")
    sp = sp and sp:FindFirstChild("Spawn_Player")
    if sp then
        -- stand on the pad, facing the field (toward +X-> field centre is at lower X)
        return CFrame.new(sp.Position + Vector3.new(0, 3, 0))
    end
    return arena:GetPivot()
end

-- Plays the round-start banner sequence: "Round 1" -> "Battle Start!".
-- No countdown, no units; this is the structural start of a round.
local leaveArena   -- forward declaration; defined further below
local startMatch   -- forward declaration; (re)starts a match in the current arena
local roundNumber = 0
local function showBannerText(text, holdTime)
    banner.Text = text
    banner.Visible = true
    banner.TextTransparency = 1
    banner.TextStrokeTransparency = 1
    -- pop in
    banner.Size = UDim2.new(0, 540, 0, 90)
    TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { TextTransparency = 0, TextStrokeTransparency = 0.2, Size = UDim2.new(0, 600, 0, 90) }):Play()
    task.wait(holdTime)
    -- fade out
    TweenService:Create(banner, TweenInfo.new(0.3),
        { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.wait(0.3)
end

-- Round/match state
local playerLives = MAX_LIVES
local opponentLives = MAX_LIVES
local pityFor = nil   -- "player" | "opponent" | nil: who gets the bonus first pick this round
-- Accumulated army history across rounds. Units persist: each round respawns
-- everything picked so far (at full HP) and the new picks are added on top.
local playerArmy = {}    -- list of unit ids deployed by the player across all rounds
local opponentArmy = {}  -- same for the opponent
-- The AI opponent's pool for the whole match: 4 DISTINCT units drawn randomly
-- from the FULL roster (including units the player hasn't unlocked). Fixed for
-- the match; re-rolled fresh each new match. The AI drafts from these 4 each
-- round and may deploy multiples of the same unit.
local opponentMatchPool = {}

local function rollOpponentPool()
    -- gather all unit ids from the registry
    local allIds = {}
    for id in pairs(UnitData.all()) do table.insert(allIds, id) end
    -- shuffle and take 4 distinct
    for i = #allIds, 2, -1 do
        local j = math.random(1, i)
        allIds[i], allIds[j] = allIds[j], allIds[i]
    end
    local pool = {}
    for i = 1, math.min(4, #allIds) do pool[i] = allIds[i] end
    return pool
end

local function buildCtx()
    local playerPool = Loadout.getAll()
    -- opponent uses its fixed match pool (rolled once in enterArena)
    local opponentPool = {}
    for _, id in ipairs(opponentMatchPool) do table.insert(opponentPool, id) end
    return {
        optionRegion = optionRegion, playerPool = playerPool, opponentPool = opponentPool,
        -- record each draft pick into the running army history
        onDeploy = function(side, unitId)
            if side == "player" then table.insert(playerArmy, unitId)
            else table.insert(opponentArmy, unitId) end
        end,
    }
end

-- Respawn the entire accumulated army from history, at full HP, in formation.
local function respawnArmies()
    Deployment.reset()
    for _, id in ipairs(playerArmy) do Deployment.deploy(id, "player") end
    for _, id in ipairs(opponentArmy) do Deployment.deploy(id, "opponent") end
end

local function startRound()
    roundNumber += 1
    task.spawn(function()
        -- Respawn the accumulated army from previous rounds (all at full HP).
        respawnArmies()
        showBannerText("Round " .. roundNumber, 1.1)
        showBannerText("Battle Start!", 1.0)
        banner.Visible = false
        print("[ArenaMatch] Round " .. roundNumber .. " begun")

        local ctx = buildCtx()

        -- Pity pick: the loser of the previous round gets one bonus pick first.
        if pityFor then
            DraftController.runPityPick(ctx, pityFor)
            task.wait(0.5)
        end

        -- Normal 3-selection draft for both sides.
        DraftController.runRound(ctx)
        task.wait(0.5)

        -- Combat: deployed units fight until one side is wiped (or stalemate).
        showBannerText("Fight!", 0.7)
        CombatController.run(function(winner)
            -- winner is "player" or "opponent"; the loser drops a heart + gets pity next round.
            local loser = (winner == "player") and "opponent" or "player"
            if loser == "player" then
                playerLives = math.max(0, playerLives - 1)
                setLives(playerCluster, playerLives)
            else
                opponentLives = math.max(0, opponentLives - 1)
                setLives(opponentCluster, opponentLives)
            end
            pityFor = loser
            print("[ArenaMatch] Round "..roundNumber.." winner="..tostring(winner).." | loser="..loser.." lives p="..playerLives.." o="..opponentLives)

            -- show outcome banner, then start next round (if both still alive)
            task.spawn(function()
                showBannerText(winner == "player" and "Round Won!" or "Round Lost!", 1.3)
                banner.Visible = false
                if playerLives > 0 and opponentLives > 0 then
                    task.wait(0.8)
                    startRound()
                else
                    -- Match over. Record result in the point system (it grants
                    -- milestone rewards itself), then build the rewards-page data.
                    local playerWon = playerLives > 0
                    local r = PlayerData.recordResult("West City", playerWon)

                    -- Reward amounts: losses pay 35%% of a win's coins & XP (rounded),
                    -- mastery chips are a flat 10 (win) / 4 (loss), and per-unit
                    -- mastery points are +10 either way.
                    local coinReward = playerWon and 100 or math.floor(100 * 0.35 + 0.5)   -- 100 / 35
                    local xpReward   = playerWon and 50  or math.floor(50  * 0.35 + 0.5)   -- 50 / 18
                    local chipReward = playerWon and 10  or 4

                    local data = {
                        playerWon = playerWon,
                        coins = coinReward, accountXp = xpReward, leveledTo = nil,
                        arenaDelta = r.delta, arenaPoints = r.points,
                        milestoneCoins = r.coinsAwarded, milestoneGems = r.gemsAwarded,
                        unlockedUnits = r.unlockedUnits,
                        masteryChips = chipReward, unitMastery = {},
                    }

                    PlayerData.addCoins(coinReward)
                    local gained = PlayerData.addXp(xpReward)
                    if gained > 0 then data.leveledTo = PlayerData.level() end

                    -- Daily free win-pack: first 4 wins / 24h grant a pack.
                    if playerWon then
                        data.dailyPack = PlayerData.grantDailyWinPack()  -- packId or nil
                    end

                    -- Mastery chips + per-unit mastery for everyone who fought.
                    PlayerData.addMasteryChips(chipReward)
                    for _, id in ipairs(Loadout.getAll()) do
                        PlayerData.addMasteryPoints(id, PlayerData.MASTERY_PER_MATCH)
                        local u = UnitData.get(id)
                        if u then
                            table.insert(data.unitMastery, {
                                id = id, name = u.name, rarity = u.rarity,
                                gained = PlayerData.MASTERY_PER_MATCH,
                            })
                        end
                    end

                    banner.Visible = false
                    showRewards(data,
                        function() leaveArena() end,          -- Back to Lobby
                        function() startMatch() end           -- Next Match (same arena)
                    )
                end
            end)
        end)
    end)
end

local function enterArena(arenaName)
    if inMatch then return end
    local arena = workspace:FindFirstChild(arenaName)
    if not arena then warn("[ArenaMatch] arena not found: "..tostring(arenaName)); return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    inMatch = true
    savedReturn = hrp.CFrame

    -- Move character to the sideline and anchor in the same frame so physics
    -- can't nudge them off the pad before they're locked in place.
    hrp.Anchored = true
    hrp.CFrame = getSidelineCFrame(arena)

    -- Lock the overhead portrait camera (ArenaCameraController reads this attribute).
    player:SetAttribute("ActiveArena", arenaName)

    -- Hide lobby UI, show HUD.
    setLobbyUiVisible(false)
    hud.Enabled = true

    print("[ArenaMatch] Entered "..arenaName)
    startMatch()   -- per-match setup + first round
end

-- (Re)start a match in the current arena. Used for the first match (from
-- enterArena) and for "Next Match" on the rewards page. Does NOT teleport or
-- touch the camera/lobby UI — the player is already at the arena.
startMatch = function()
    Deployment.reset()
    table.clear(playerArmy)
    table.clear(opponentArmy)
    opponentMatchPool = rollOpponentPool()   -- fresh AI pool each match
    roundNumber = 0
    pityFor = nil
    playerLives = MAX_LIVES
    opponentLives = MAX_LIVES
    setLives(playerCluster, MAX_LIVES)
    setLives(opponentCluster, MAX_LIVES)
    opponentCluster.name.Text = "Opponent"
    playerCluster.name.Text = player.DisplayName
    refreshEquippedBar()
    startRound()
end

leaveArena = function()
    if not inMatch then return end
    inMatch = false
    player:SetAttribute("ActiveArena", nil)  -- releases camera
    hud.Enabled = false

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = false
        if savedReturn then hrp.CFrame = savedReturn end
    end
    setLobbyUiVisible(true)
    print("[ArenaMatch] Left arena")
end


-- Listen for the lobby's Enter button.
local evFolder = ReplicatedStorage:WaitForChild("ArenaEvents")
local enterEvent = evFolder:WaitForChild("EnterArena")
enterEvent.Event:Connect(function(arenaName)
    enterArena(arenaName or "Arena_WestCity")
end)

