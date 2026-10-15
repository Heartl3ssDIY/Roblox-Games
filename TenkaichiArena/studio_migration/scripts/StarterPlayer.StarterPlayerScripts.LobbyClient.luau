local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaTravelClient = require(ReplicatedStorage:WaitForChild("ArenaTravelClient"))

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local character  = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function(c)
    character = c
end)

local mmz       = workspace:WaitForChild("Lobby_MainModeZone")
local spawnPart = mmz:WaitForChild("MainModeSpawn")
local ringOuter = mmz:WaitForChild("RingOuter")

local RING_RADIUS = 11

local C = {
    bg      = Color3.fromRGB(18, 12, 36),
    panel   = Color3.fromRGB(32, 20, 62),
    border  = Color3.fromRGB(148, 88, 255),
    accent  = Color3.fromRGB(180, 120, 255),
    btnBg   = Color3.fromRGB(50, 28, 98),
    btnHov  = Color3.fromRGB(78, 48, 145),
    btnTxt  = Color3.fromRGB(230, 210, 255),
    title   = Color3.fromRGB(220, 190, 255),
    sub     = Color3.fromRGB(155, 130, 195),
    close   = Color3.fromRGB(200, 70, 95),
    play    = Color3.fromRGB(90, 215, 130),
    playTxt = Color3.fromRGB(15, 55, 28),
    gold    = Color3.fromRGB(255, 210, 80),
    lock    = Color3.fromRGB(90, 80, 120),
    lockTxt = Color3.fromRGB(140, 120, 170),
    arena   = Color3.fromRGB(22, 14, 48),
    arenaBorder = Color3.fromRGB(255, 180, 50),
}

local function corner(p, r)
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 14)
end
local function stroke(p, col, thick)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.border; s.Thickness = thick or 2
end

local playGui = Instance.new("ScreenGui")
playGui.Name = "PlayButtonGui"; playGui.ResetOnSpawn = false
playGui.IgnoreGuiInset = true; playGui.Parent = playerGui

local playBtn = Instance.new("TextButton")
playBtn.Name = "PlayBtn"
playBtn.Size = UDim2.new(0, 140, 0, 44)
playBtn.Position = UDim2.new(0.5, -70, 0, 14)
playBtn.BackgroundColor3 = C.play
playBtn.BorderSizePixel = 0
playBtn.Text = "▶  PLAY"
playBtn.TextColor3 = C.playTxt
playBtn.Font = Enum.Font.GothamBold
playBtn.TextSize = 18
playBtn.Parent = playGui
corner(playBtn, 22)
stroke(playBtn, Color3.fromRGB(55, 175, 75), 2)

TweenService:Create(playBtn,
    TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundColor3 = Color3.fromRGB(125, 255, 155) }):Play()

playBtn.MouseEnter:Connect(function()
    TweenService:Create(playBtn, TweenInfo.new(0.12),
        { Size = UDim2.new(0,152,0,48), Position = UDim2.new(0.5,-76,0,12) }):Play()
end)
playBtn.MouseLeave:Connect(function()
    TweenService:Create(playBtn, TweenInfo.new(0.12),
        { Size = UDim2.new(0,140,0,44), Position = UDim2.new(0.5,-70,0,14) }):Play()
end)
playBtn.Activated:Connect(function()
    local c = player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local success, message = ArenaTravelClient.toLobbyPortal()
    if not success then warn(message) return end
    TweenService:Create(playBtn, TweenInfo.new(0.08),
        { Size = UDim2.new(0,128,0,40), Position = UDim2.new(0.5,-64,0,16) }):Play()
    task.delay(0.12, function()
        TweenService:Create(playBtn, TweenInfo.new(0.15),
            { Size = UDim2.new(0,140,0,44), Position = UDim2.new(0.5,-70,0,14) }):Play()
    end)
end)

local modeGui = Instance.new("ScreenGui")
modeGui.Name = "ModePickerGui"; modeGui.ResetOnSpawn = false
modeGui.IgnoreGuiInset = true; modeGui.Enabled = false; modeGui.Parent = playerGui

local overlay = Instance.new("Frame", modeGui)
overlay.Size = UDim2.new(1,0,1,0)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.58
overlay.BorderSizePixel = 0

local modePanel = Instance.new("Frame", modeGui)
modePanel.Name = "Panel"
modePanel.Size = UDim2.new(0, 560, 0, 320)
modePanel.Position = UDim2.new(0.5,-280,0.5,-160)
modePanel.BackgroundColor3 = C.panel
modePanel.BorderSizePixel = 0
corner(modePanel, 24)
stroke(modePanel, C.border, 3)

local mTitle = Instance.new("TextLabel", modePanel)
mTitle.Size = UDim2.new(1,-50,0,40)
mTitle.Position = UDim2.new(0,20,0,16)
mTitle.BackgroundTransparency = 1
mTitle.Text = "⚔️  Choose Your Mode"
mTitle.TextColor3 = C.title
mTitle.Font = Enum.Font.GothamBold
mTitle.TextSize = 22

local mSub = Instance.new("TextLabel", modePanel)
mSub.Size = UDim2.new(1,-50,0,22)
mSub.Position = UDim2.new(0,20,0,56)
mSub.BackgroundTransparency = 1
mSub.Text = "Select a game mode to begin your journey"
mSub.TextColor3 = C.sub
mSub.Font = Enum.Font.Gotham
mSub.TextSize = 13

local mdiv = Instance.new("Frame", modePanel)
mdiv.Size = UDim2.new(1,-40,0,1)
mdiv.Position = UDim2.new(0,20,0,84)
mdiv.BackgroundColor3 = C.border
mdiv.BackgroundTransparency = 0.5
mdiv.BorderSizePixel = 0

local mClose = Instance.new("TextButton", modePanel)
mClose.Size = UDim2.new(0,34,0,34)
mClose.Position = UDim2.new(1,-44,0,10)
mClose.BackgroundColor3 = C.close
mClose.Text = "✕"; mClose.TextColor3 = Color3.fromRGB(255,255,255)
mClose.Font = Enum.Font.GothamBold; mClose.TextSize = 16
mClose.BorderSizePixel = 0
corner(mClose, 17)
mClose.Activated:Connect(function() modeGui.Enabled = false end)

local mFooter = Instance.new("TextLabel", modePanel)
mFooter.Size = UDim2.new(1,-40,0,20)
mFooter.Position = UDim2.new(0,20,1,-26)
mFooter.BackgroundTransparency = 1
mFooter.Text = "Step off the ring or press ✕ to cancel"
mFooter.TextColor3 = Color3.fromRGB(90,72,128)
mFooter.Font = Enum.Font.Gotham
mFooter.TextSize = 11

local MODES = {
    {
        tag   = "MAIN",
        icon  = "⚔️",
        name  = "Main",
        desc  = "Begin the main\ncampaign",
        color = Color3.fromRGB(100, 70, 200),
        lock  = false,
    },
    {
        tag   = "ENDLESS",
        icon  = "🔁",
        name  = "Endless",
        desc  = "Under\nConstruction",
        color = Color3.fromRGB(80, 80, 80),
        lock  = true,
    },
}

local mainBtn

for i, mode in ipairs(MODES) do
    local xOff = 20 + (i-1) * 272
    local btn = Instance.new("TextButton", modePanel)
    btn.Name = "ModeBtn_"..mode.tag
    btn.Size = UDim2.new(0, 248, 0, 160)
    btn.Position = UDim2.new(0, xOff, 0, 96)
    btn.BackgroundColor3 = mode.lock and C.lock or C.btnBg
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    corner(btn, 16)
    stroke(btn, mode.lock and Color3.fromRGB(80,70,110) or mode.color, 2)

    local iconL = Instance.new("TextLabel", btn)
    iconL.Size = UDim2.new(1,0,0,48)
    iconL.Position = UDim2.new(0,0,0,16)
    iconL.BackgroundTransparency = 1
    iconL.Text = mode.icon
    iconL.TextSize = 30
    iconL.Font = Enum.Font.GothamBold

    local nameL = Instance.new("TextLabel", btn)
    nameL.Size = UDim2.new(1,-16,0,26)
    nameL.Position = UDim2.new(0,8,0,66)
    nameL.BackgroundTransparency = 1
    nameL.Text = mode.name
    nameL.TextColor3 = mode.lock and C.lockTxt or C.btnTxt
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 18

    local descL = Instance.new("TextLabel", btn)
    descL.Size = UDim2.new(1,-16,0,36)
    descL.Position = UDim2.new(0,8,0,94)
    descL.BackgroundTransparency = 1
    descL.Text = mode.desc
    descL.TextColor3 = mode.lock and C.lockTxt or C.sub
    descL.Font = Enum.Font.Gotham
    descL.TextSize = 12
    descL.TextWrapped = true

    if mode.lock then

        local lockL = Instance.new("TextLabel", btn)
        lockL.Size = UDim2.new(1,0,1,0)
        lockL.BackgroundTransparency = 1
        lockL.Text = "🔒"
        lockL.TextSize = 28
        lockL.Font = Enum.Font.GothamBold
        lockL.TextColor3 = Color3.fromRGB(160,140,200)
        lockL.TextYAlignment = Enum.TextYAlignment.Top
        lockL.Position = UDim2.new(0,0,0,8)
    else

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12),
                { BackgroundColor3 = C.btnHov }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12),
                { BackgroundColor3 = C.btnBg }):Play()
        end)
    end

    if mode.tag == "MAIN" then mainBtn = btn end
end

local arenaGui = Instance.new("ScreenGui")
arenaGui.Name = "ArenaSelectGui"; arenaGui.ResetOnSpawn = false
arenaGui.IgnoreGuiInset = true; arenaGui.Enabled = false; arenaGui.Parent = playerGui

local aOverlay = Instance.new("Frame", arenaGui)
aOverlay.Size = UDim2.new(1,0,1,0)
aOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
aOverlay.BackgroundTransparency = 0.45
aOverlay.BorderSizePixel = 0

local aPanel = Instance.new("Frame", arenaGui)
aPanel.Name = "ArenaPanel"
aPanel.Size = UDim2.new(0, 700, 0, 520)
aPanel.Position = UDim2.new(0.5,-350,0.5,-260)
aPanel.BackgroundColor3 = C.arena
aPanel.BorderSizePixel = 0
corner(aPanel, 26)
stroke(aPanel, C.arenaBorder, 3)

local aHeader = Instance.new("Frame", aPanel)
aHeader.Size = UDim2.new(1,0,0,58)
aHeader.Position = UDim2.new(0,0,0,0)
aHeader.BackgroundColor3 = Color3.fromRGB(28, 18, 55)
aHeader.BorderSizePixel = 0
corner(aHeader, 26)

local aHeaderFill = Instance.new("Frame", aPanel)
aHeaderFill.Size = UDim2.new(1,0,0,28)
aHeaderFill.Position = UDim2.new(0,0,0,30)
aHeaderFill.BackgroundColor3 = Color3.fromRGB(28, 18, 55)
aHeaderFill.BorderSizePixel = 0

local aTitle = Instance.new("TextLabel", aHeader)
aTitle.Size = UDim2.new(1,-60,1,0)
aTitle.Position = UDim2.new(0,20,0,0)
aTitle.BackgroundTransparency = 1
aTitle.Text = "📍  Select Arena"
aTitle.TextColor3 = C.gold
aTitle.Font = Enum.Font.GothamBold
aTitle.TextSize = 22
aTitle.TextXAlignment = Enum.TextXAlignment.Left

local aClose = Instance.new("TextButton", aHeader)
aClose.Size = UDim2.new(0,34,0,34)
aClose.Position = UDim2.new(1,-44,0.5,-17)
aClose.BackgroundColor3 = C.close
aClose.Text = "✕"; aClose.TextColor3 = Color3.fromRGB(255,255,255)
aClose.Font = Enum.Font.GothamBold; aClose.TextSize = 16
aClose.BorderSizePixel = 0
corner(aClose, 17)
aClose.Activated:Connect(function()
    aPanel.Size = UDim2.new(0,700,0,520)
    aPanel.Position = UDim2.new(0.5,-350,0.5,-260)
    TweenService:Create(aPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Size=UDim2.new(0,700,0,10), Position=UDim2.new(0.5,-350,0.5,-5) }):Play()
    task.delay(0.2, function() arenaGui.Enabled = false end)
end)

local card = Instance.new("Frame", aPanel)
card.Name = "Arena1Card"
card.Size = UDim2.new(0, 640, 0, 390)
card.Position = UDim2.new(0.5,-320,0,72)
card.BackgroundColor3 = Color3.fromRGB(28, 16, 54)
card.BorderSizePixel = 0
corner(card, 18)
stroke(card, C.arenaBorder, 2)

local imgFrame = Instance.new("Frame", card)
imgFrame.Size = UDim2.new(0, 280, 1,-20)
imgFrame.Position = UDim2.new(0,10,0,10)
imgFrame.BackgroundColor3 = Color3.fromRGB(14, 8, 30)
imgFrame.BorderSizePixel = 0
corner(imgFrame, 14)
stroke(imgFrame, Color3.fromRGB(200,150,40), 2)

local gokuImg = Instance.new("ImageLabel", imgFrame)
gokuImg.Size = UDim2.new(1,-4,1,-4)
gokuImg.Position = UDim2.new(0,2,0,2)
gokuImg.BackgroundTransparency = 1
gokuImg.Image = "rbxassetid://7607741448"
gokuImg.ScaleType = Enum.ScaleType.Fit
gokuImg.ImageColor3 = Color3.fromRGB(255,255,255)
corner(gokuImg, 12)

local imgCaption = Instance.new("TextLabel", imgFrame)
imgCaption.Size = UDim2.new(1,0,0,20)
imgCaption.Position = UDim2.new(0,0,1,-22)
imgCaption.BackgroundColor3 = Color3.fromRGB(0,0,0)
imgCaption.BackgroundTransparency = 0.35
imgCaption.Text = "Dragon Ball inspired enemies await"
imgCaption.TextColor3 = Color3.fromRGB(220,200,255)
imgCaption.Font = Enum.Font.Gotham
imgCaption.TextSize = 10
corner(imgCaption, 0)

local infoX = 300

local arenaBadge = Instance.new("Frame", card)
arenaBadge.Size = UDim2.new(0, 100, 0, 28)
arenaBadge.Position = UDim2.new(0,infoX,0,18)
arenaBadge.BackgroundColor3 = C.arenaBorder
arenaBadge.BorderSizePixel = 0
corner(arenaBadge, 14)
local badgeTxt = Instance.new("TextLabel", arenaBadge)
badgeTxt.Size = UDim2.new(1,0,1,0)
badgeTxt.BackgroundTransparency = 1
badgeTxt.Text = "ARENA 1"
badgeTxt.TextColor3 = Color3.fromRGB(20,10,40)
badgeTxt.Font = Enum.Font.GothamBold
badgeTxt.TextSize = 13

local arenaName = Instance.new("TextLabel", card)
arenaName.Size = UDim2.new(0, 330, 0, 44)
arenaName.Position = UDim2.new(0,infoX,0,52)
arenaName.BackgroundTransparency = 1
arenaName.Text = "Tenkaichi"
arenaName.TextColor3 = Color3.fromRGB(255, 230, 120)
arenaName.Font = Enum.Font.GothamBold
arenaName.TextSize = 32
arenaName.TextXAlignment = Enum.TextXAlignment.Left

local nameDivider = Instance.new("Frame", card)
nameDivider.Size = UDim2.new(0,320,0,2)
nameDivider.Position = UDim2.new(0,infoX,0,100)
nameDivider.BackgroundColor3 = C.arenaBorder
nameDivider.BackgroundTransparency = 0.55
nameDivider.BorderSizePixel = 0

local flavour = Instance.new("TextLabel", card)
flavour.Size = UDim2.new(0,320,0,70)
flavour.Position = UDim2.new(0,infoX,0,110)
flavour.BackgroundTransparency = 1
flavour.Text = "Fight beneath tropical skies at the\nTenkaichi martial arts tournament.\nDraft your team and take the ring."
flavour.TextColor3 = C.sub
flavour.Font = Enum.Font.Gotham
flavour.TextSize = 13
flavour.TextWrapped = true
flavour.TextXAlignment = Enum.TextXAlignment.Left
flavour.TextYAlignment = Enum.TextYAlignment.Top

local stats = {{"⚔️ Enemies", "5"}, {"⭐ Difficulty", "Easy"}, {"🕐 Est. Time", "15 min"}}
for si, stat in ipairs(stats) do
    local pill = Instance.new("Frame", card)
    pill.Size = UDim2.new(0,96,0,28)
    pill.Position = UDim2.new(0, infoX + (si-1)*104, 0, 192)
    pill.BackgroundColor3 = Color3.fromRGB(40, 24, 78)
    pill.BorderSizePixel = 0
    corner(pill, 14)
    stroke(pill, Color3.fromRGB(100,70,180), 1)
    local pillTxt = Instance.new("TextLabel", pill)
    pillTxt.Size = UDim2.new(1,0,0,14)
    pillTxt.Position = UDim2.new(0,0,0,2)
    pillTxt.BackgroundTransparency = 1
    pillTxt.Text = stat[1]
    pillTxt.TextColor3 = C.sub
    pillTxt.Font = Enum.Font.Gotham
    pillTxt.TextSize = 9
    local pillVal = Instance.new("TextLabel", pill)
    pillVal.Size = UDim2.new(1,0,0,14)
    pillVal.Position = UDim2.new(0,0,0,13)
    pillVal.BackgroundTransparency = 1
    pillVal.Text = stat[2]
    pillVal.TextColor3 = C.btnTxt
    pillVal.Font = Enum.Font.GothamBold
    pillVal.TextSize = 11
end

local PlayerData = require(game:GetService("ReplicatedStorage"):WaitForChild("PlayerData"))
local PROG_MAX = 100

local progLabel = Instance.new("TextLabel", card)
progLabel.Name = "ProgLabel"
progLabel.Size = UDim2.new(0, 320, 0, 18)
progLabel.Position = UDim2.new(0, infoX, 0, 232)
progLabel.BackgroundTransparency = 1
progLabel.Text = "Arena Progress"
progLabel.TextColor3 = C.sub
progLabel.Font = Enum.Font.GothamBold
progLabel.TextSize = 12
progLabel.TextXAlignment = Enum.TextXAlignment.Left

local progPoints = Instance.new("TextLabel", card)
progPoints.Name = "ProgPoints"
progPoints.Size = UDim2.new(0, 320, 0, 18)
progPoints.Position = UDim2.new(0, infoX, 0, 232)
progPoints.BackgroundTransparency = 1
progPoints.Text = "0 pts"
progPoints.TextColor3 = C.gold
progPoints.Font = Enum.Font.GothamBold
progPoints.TextSize = 12
progPoints.TextXAlignment = Enum.TextXAlignment.Right

local barTrack = Instance.new("Frame", card)
barTrack.Name = "BarTrack"
barTrack.Size = UDim2.new(0, 320, 0, 14)
barTrack.Position = UDim2.new(0, infoX, 0, 254)
barTrack.BackgroundColor3 = Color3.fromRGB(20, 12, 42)
barTrack.BorderSizePixel = 0
corner(barTrack, 7)
stroke(barTrack, Color3.fromRGB(100,70,180), 1)

local barFill = Instance.new("Frame", barTrack)
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = C.gold
barFill.BorderSizePixel = 0
corner(barFill, 7)

local MILES = {
    { p = 25,  icon = "\xF0\x9F\xAA\x99", tip = "1000" },
    { p = 50,  icon = "\xE2\x9C\xA8", tip = "Unit" },
    { p = 75,  icon = "\xF0\x9F\x92\x8E", tip = "10" },
    { p = 100, icon = "\xE2\x9C\xA8", tip = "Unit" },
}
local markerDots = {}
for _, ms in ipairs(MILES) do
    local frac = ms.p / PROG_MAX
    local dot = Instance.new("Frame", barTrack)
    dot.Name = "Mark"..ms.p
    dot.Size = UDim2.new(0, 4, 1, 6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(frac, 0, 0.5, 0)
    dot.BackgroundColor3 = Color3.fromRGB(255,255,255)
    dot.BackgroundTransparency = 0.2
    dot.BorderSizePixel = 0

    local mi = Instance.new("TextLabel", card)
    mi.Size = UDim2.new(0, 40, 0, 14)
    mi.AnchorPoint = Vector2.new(0.5, 0)
    mi.Position = UDim2.new(0, infoX + frac*320, 0, 270)
    mi.BackgroundTransparency = 1
    mi.Text = ms.icon
    mi.TextSize = 12
    mi.Font = Enum.Font.GothamBold
    markerDots[ms.p] = dot
end

local winLossLbl = Instance.new("TextLabel", card)
winLossLbl.Name = "WinLoss"
winLossLbl.Size = UDim2.new(0, 320, 0, 16)
winLossLbl.Position = UDim2.new(0, infoX, 0, 292)
winLossLbl.BackgroundTransparency = 1
winLossLbl.Text = "Wins: 0   Losses: 0"
winLossLbl.TextColor3 = C.sub
winLossLbl.Font = Enum.Font.Gotham
winLossLbl.TextSize = 11
winLossLbl.TextXAlignment = Enum.TextXAlignment.Left

local function refreshArenaProgress()
    local prog = PlayerData.arenaProgress("Tenkaichi")
    local pts = prog.points
    progPoints.Text = pts .. " pts"
    winLossLbl.Text = "Wins: " .. prog.wins .. "   Losses: " .. prog.losses
    local frac = math.clamp(pts / PROG_MAX, 0, 1)
    TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.new(frac, 0, 1, 0) }):Play()

    for _, ms in ipairs(MILES) do
        local d = markerDots[ms.p]
        if d then d.BackgroundColor3 = (pts >= ms.p) and C.gold or Color3.fromRGB(255,255,255) end
    end
end
refreshArenaProgress()
PlayerData.Changed:Connect(refreshArenaProgress)

local enterBtn = Instance.new("TextButton", card)
enterBtn.Size = UDim2.new(0, 232, 0, 48)
enterBtn.Position = UDim2.new(0, infoX, 0, 330)
enterBtn.BackgroundColor3 = Color3.fromRGB(90, 215, 130)
enterBtn.BorderSizePixel = 0
enterBtn.Text = "▶  Enter Tenkaichi"
enterBtn.TextColor3 = Color3.fromRGB(15, 50, 25)
enterBtn.Font = Enum.Font.GothamBold
enterBtn.TextSize = 16
corner(enterBtn, 24)
stroke(enterBtn, Color3.fromRGB(55, 175, 75), 2)
enterBtn.MouseEnter:Connect(function()
    TweenService:Create(enterBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(120,240,155) }):Play()
end)
enterBtn.MouseLeave:Connect(function()
    TweenService:Create(enterBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(90,215,130) }):Play()
end)
enterBtn.Activated:Connect(function()
    print("[ArenaSelect] Entering Arena 1 — Tenkaichi")

    local Loadout = require(game:GetService("ReplicatedStorage"):WaitForChild("Loadout"))
    if Loadout.count() < 4 then

        local origText = enterBtn.Text
        enterBtn.Text = "Equip 4 units first!"
        enterBtn.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
        task.delay(1.6, function()
            enterBtn.Text = origText
            enterBtn.BackgroundColor3 = Color3.fromRGB(90, 215, 130)
        end)
        return
    end

    arenaGui.Enabled = false
    local ev = game:GetService("ReplicatedStorage"):FindFirstChild("ArenaEvents")
    ev = ev and ev:FindFirstChild("EnterArena")
    if ev then ev:Fire("Arena_Tenkaichi") end
end)

local PackOpening = require(game:GetService("ReplicatedStorage"):WaitForChild("PackOpening"))
local PackReveal = require(game:GetService("ReplicatedStorage"):WaitForChild("PackReveal"))

local dailyPacksBtn = Instance.new("TextButton", card)
dailyPacksBtn.Name = "DailyPacksBtn"
dailyPacksBtn.Size = UDim2.new(0, 80, 0, 48)
dailyPacksBtn.Position = UDim2.new(0, infoX + 240, 0, 330)
dailyPacksBtn.BackgroundColor3 = Color3.fromRGB(60, 38, 110)
dailyPacksBtn.BorderSizePixel = 0
dailyPacksBtn.AutoButtonColor = false
dailyPacksBtn.Text = "\xF0\x9F\x8E\x81"
dailyPacksBtn.TextColor3 = C.gold
dailyPacksBtn.Font = Enum.Font.GothamBold
dailyPacksBtn.TextSize = 24
corner(dailyPacksBtn, 24)
stroke(dailyPacksBtn, C.arenaBorder, 2)

local dpBadge = Instance.new("TextLabel", dailyPacksBtn)
dpBadge.Size = UDim2.new(0, 22, 0, 22)
dpBadge.Position = UDim2.new(1, -14, 0, -8)
dpBadge.BackgroundColor3 = Color3.fromRGB(220, 60, 70)
dpBadge.BorderSizePixel = 0
dpBadge.Text = "0"
dpBadge.TextColor3 = Color3.fromRGB(255,255,255)
dpBadge.Font = Enum.Font.GothamBold
dpBadge.TextSize = 12
dpBadge.Visible = false
corner(dpBadge, 11)

local dpPopup = Instance.new("Frame", aPanel)
dpPopup.Name = "DailyPacksPopup"
dpPopup.Size = UDim2.new(0, 300, 0, 260)
dpPopup.AnchorPoint = Vector2.new(0.5, 0.5)
dpPopup.Position = UDim2.new(0.5, 0, 0.5, 0)
dpPopup.BackgroundColor3 = C.panel
dpPopup.BorderSizePixel = 0
dpPopup.Visible = false
dpPopup.ZIndex = 20
corner(dpPopup, 16)
stroke(dpPopup, C.arenaBorder, 3)
local dpTitle = Instance.new("TextLabel", dpPopup)
dpTitle.Size = UDim2.new(1, -20, 0, 32)
dpTitle.Position = UDim2.new(0, 14, 0, 12)
dpTitle.BackgroundTransparency = 1
dpTitle.Text = "\xF0\x9F\x8E\x81  Daily Win Packs"
dpTitle.TextColor3 = C.gold
dpTitle.Font = Enum.Font.GothamBold
dpTitle.TextSize = 16
dpTitle.TextXAlignment = Enum.TextXAlignment.Left
dpTitle.ZIndex = 21
local dpClose = Instance.new("TextButton", dpPopup)
dpClose.Size = UDim2.new(0, 28, 0, 28)
dpClose.Position = UDim2.new(1, -36, 0, 12)
dpClose.BackgroundColor3 = C.close
dpClose.Text = "\xE2\x9C\x95"
dpClose.TextColor3 = Color3.fromRGB(255,255,255)
dpClose.Font = Enum.Font.GothamBold
dpClose.TextSize = 13
dpClose.BorderSizePixel = 0
dpClose.ZIndex = 21
corner(dpClose, 14)
dpClose.Activated:Connect(function() dpPopup.Visible = false end)
local dpList = Instance.new("ScrollingFrame", dpPopup)
dpList.Size = UDim2.new(1, -24, 1, -56)
dpList.Position = UDim2.new(0, 12, 0, 48)
dpList.BackgroundTransparency = 1
dpList.BorderSizePixel = 0
dpList.ScrollBarThickness = 5
dpList.CanvasSize = UDim2.new(0,0,0,0)
dpList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dpList.ZIndex = 21
local dpLayout = Instance.new("UIListLayout", dpList)
dpLayout.Padding = UDim.new(0, 8)
dpLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PACK_NAMES = { bronze = "Bronze Pack", silver = "Silver Pack", gold = "Gold Pack" }
local PACK_COLORS = { bronze = Color3.fromRGB(190,130,70), silver = Color3.fromRGB(190,200,215), gold = Color3.fromRGB(255,205,90) }

local rebuildDpList
rebuildDpList = function()
    for _, ch in ipairs(dpList:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
    local counts = PlayerData.allPackCounts()
    local order = { "bronze", "silver", "gold" }
    local any = false
    local li = 0
    for _, packId in ipairs(order) do
        local n = counts[packId] or 0
        for k = 1, n do
            any = true
            li += 1
            local rowF = Instance.new("Frame", dpList)
            rowF.Size = UDim2.new(1, 0, 0, 44)
            rowF.BackgroundColor3 = Color3.fromRGB(40, 24, 78)
            rowF.BorderSizePixel = 0
            rowF.LayoutOrder = li
            rowF.ZIndex = 22
            corner(rowF, 10)
            stroke(rowF, PACK_COLORS[packId] or C.border, 1)
            local nm = Instance.new("TextLabel", rowF)
            nm.Size = UDim2.new(1, -90, 1, 0)
            nm.Position = UDim2.new(0, 12, 0, 0)
            nm.BackgroundTransparency = 1
            nm.Text = "\xF0\x9F\x8E\x81  " .. (PACK_NAMES[packId] or packId)
            nm.TextColor3 = PACK_COLORS[packId] or C.btnTxt
            nm.Font = Enum.Font.GothamBold
            nm.TextSize = 14
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.ZIndex = 23
            local openB = Instance.new("TextButton", rowF)
            openB.Size = UDim2.new(0, 72, 0, 30)
            openB.AnchorPoint = Vector2.new(1, 0.5)
            openB.Position = UDim2.new(1, -8, 0.5, 0)
            openB.BackgroundColor3 = C.play
            openB.BorderSizePixel = 0
            openB.Text = "Open"
            openB.TextColor3 = C.playTxt
            openB.Font = Enum.Font.GothamBold
            openB.TextSize = 13
            openB.ZIndex = 23
            corner(openB, 8)
            openB.Activated:Connect(function()
                if PlayerData.consumePack(packId) then
                    local result = PackOpening.roll(packId)
                    PackOpening.apply(result)
                    dpPopup.Visible = false
                    arenaGui.Enabled = false
                    PackReveal.play(playerGui, result, function()
                        arenaGui.Enabled = true
                        rebuildDpList()
                        if PlayerData.totalBankedPacks() > 0 then dpPopup.Visible = true end
                    end)
                end
            end)
        end
    end
    if not any then
        local empty = Instance.new("TextLabel", dpList)
        empty.Size = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text = "No packs right now.\nWin matches to earn daily packs!"
        empty.TextColor3 = C.sub
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 13
        empty.ZIndex = 22
    end
end

local function refreshDpBadge()
    local n = PlayerData.totalBankedPacks()
    dpBadge.Visible = n > 0
    dpBadge.Text = tostring(n)
end
refreshDpBadge()
PlayerData.Changed:Connect(refreshDpBadge)

dailyPacksBtn.MouseEnter:Connect(function() dailyPacksBtn.BackgroundColor3 = Color3.fromRGB(80, 52, 145) end)
dailyPacksBtn.MouseLeave:Connect(function() dailyPacksBtn.BackgroundColor3 = Color3.fromRGB(60, 38, 110) end)
dailyPacksBtn.Activated:Connect(function()
    rebuildDpList()
    dpPopup.Visible = not dpPopup.Visible
end)

local function reopenModePanel()
    arenaGui.Enabled = false
    modePanel.Size     = UDim2.new(0,560,0,10)
    modePanel.Position = UDim2.new(0.5,-280,0.5,-5)
    modeGui.Enabled    = true
    TweenService:Create(modePanel,
        TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size=UDim2.new(0,560,0,320), Position=UDim2.new(0.5,-280,0.5,-160) }):Play()
end

local backBtn = Instance.new("TextButton", aPanel)
backBtn.Name = "BackBtn"
backBtn.Size = UDim2.new(0, 110, 0, 38)
backBtn.Position = UDim2.new(0, 20, 1, -50)
backBtn.BackgroundColor3 = Color3.fromRGB(48, 30, 88)
backBtn.BorderSizePixel = 0
backBtn.Text = "←  Back"
backBtn.TextColor3 = Color3.fromRGB(220, 205, 255)
backBtn.Font = Enum.Font.GothamBold
backBtn.TextSize = 15
corner(backBtn, 19)
stroke(backBtn, C.arenaBorder, 2)
backBtn.MouseEnter:Connect(function()
    TweenService:Create(backBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(66, 42, 120) }):Play()
end)
backBtn.MouseLeave:Connect(function()
    TweenService:Create(backBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(48, 30, 88) }):Play()
end)
backBtn.Activated:Connect(function()
    aPanel.Size = UDim2.new(0,700,0,520)
    aPanel.Position = UDim2.new(0.5,-350,0.5,-260)
    TweenService:Create(aPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Size=UDim2.new(0,700,0,10), Position=UDim2.new(0.5,-350,0.5,-5) }):Play()
    task.delay(0.2, reopenModePanel)
end)

local ARENAS = {
    { name = "Tenkaichi" },
}
local currentArena = 1

local nextBtn = Instance.new("TextButton", aPanel)
nextBtn.Name = "NextArenaBtn"
nextBtn.Size = UDim2.new(0, 48, 0, 48)
nextBtn.Position = UDim2.new(1, -64, 0.5, -24)
nextBtn.BackgroundColor3 = Color3.fromRGB(48, 30, 88)
nextBtn.BorderSizePixel = 0
nextBtn.Text = "›"
nextBtn.TextColor3 = Color3.fromRGB(230, 215, 255)
nextBtn.Font = Enum.Font.GothamBold
nextBtn.TextSize = 30
corner(nextBtn, 24)
stroke(nextBtn, C.arenaBorder, 2)

local function refreshArenaArrow()

    local hasNext = currentArena < #ARENAS
    nextBtn.AutoButtonColor = hasNext
    nextBtn.BackgroundTransparency = hasNext and 0 or 0.55
    nextBtn.TextTransparency = hasNext and 0 or 0.5
end
refreshArenaArrow()

nextBtn.MouseEnter:Connect(function()
    if currentArena < #ARENAS then
        TweenService:Create(nextBtn, TweenInfo.new(0.12),
            { BackgroundColor3 = Color3.fromRGB(66, 42, 120) }):Play()
    end
end)
nextBtn.MouseLeave:Connect(function()
    TweenService:Create(nextBtn, TweenInfo.new(0.12),
        { BackgroundColor3 = Color3.fromRGB(48, 30, 88) }):Play()
end)
nextBtn.Activated:Connect(function()
    if currentArena < #ARENAS then
        currentArena += 1

        refreshArenaArrow()
    end
end)

if mainBtn then
    mainBtn.Activated:Connect(function()
        modeGui.Enabled = false
        aPanel.Size = UDim2.new(0,700,0,10)
        aPanel.Position = UDim2.new(0.5,-350,0.5,-5)
        arenaGui.Enabled = true
        TweenService:Create(aPanel,
            TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size=UDim2.new(0,700,0,520), Position=UDim2.new(0.5,-350,0.5,-260) }):Play()
    end)
end

local onRing = false

RunService.Heartbeat:Connect(function()
    if player:GetAttribute("ActiveArena") then
        onRing = false
        modeGui.Enabled = false
        return
    end
    local c = player.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local pos = hrp.Position
    local dist = Vector2.new(pos.X - ringOuter.Position.X, pos.Z - ringOuter.Position.Z).Magnitude
    local inside = dist <= RING_RADIUS + 1

    if inside and not onRing then
        onRing = true
        modePanel.Size     = UDim2.new(0,560,0,10)
        modePanel.Position = UDim2.new(0.5,-280,0.5,-5)
        modeGui.Enabled    = true
        TweenService:Create(modePanel,
            TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size=UDim2.new(0,560,0,320), Position=UDim2.new(0.5,-280,0.5,-160) }):Play()
    elseif not inside and onRing then
        onRing = false
        if modeGui.Enabled then
            TweenService:Create(modePanel,
                TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Size=UDim2.new(0,560,0,10), Position=UDim2.new(0.5,-280,0.5,-5) }):Play()
            task.delay(0.18, function() modeGui.Enabled = false end)
        end
    end
end)

