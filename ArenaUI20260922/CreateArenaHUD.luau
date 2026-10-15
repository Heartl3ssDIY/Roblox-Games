local playerGui = game.StarterGui
assert(not playerGui:FindFirstChild("ArenaHUD"), "ArenaHUD already exists")
local C = {
    bg      = Color3.fromRGB(18, 12, 36),
    panel   = Color3.fromRGB(32, 20, 62),
    btnHov = Color3.fromRGB(60, 38, 112),
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

local hud = mk("ScreenGui", {
    Name = "ArenaHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
    Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local banner = mk("TextLabel", {
    Name = "RoundBanner", Size = UDim2.new(0, 600, 0, 90),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.42, 0),
    BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 230, 130),
    Font = Enum.Font.PermanentMarker, TextSize = 56, TextStrokeTransparency = 0.2,
    TextStrokeColor3 = Color3.fromRGB(20, 10, 40), Visible = false, ZIndex = 20,
}, hud)

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
    Font = Enum.Font.PermanentMarker, TextSize = 38, ZIndex = 32,
}, rewardPanel)

local rewardBody = mk("ScrollingFrame", {
    Name = "Body", Size = UDim2.new(1,-36,1,-150), Position = UDim2.new(0,18,0,74),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
    ScrollBarImageColor3 = C.border, CanvasSize = UDim2.new(0,0,0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 32,
}, rewardPanel)
mk("UIListLayout", { Padding = UDim.new(0,12), SortOrder = Enum.SortOrder.LayoutOrder }, rewardBody)
mk("UIPadding", { PaddingRight = UDim.new(0,8) }, rewardBody)

local backLobbyBtn = mk("TextButton", {
    Name = "BackLobby", Size = UDim2.new(0, 250, 0, 46), AnchorPoint = Vector2.new(0,1),
    Position = UDim2.new(0,18,1,-18), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "\xE2\x86\x90  Back to Lobby", TextColor3 = C.btnTxt,
    Font = Enum.Font.PermanentMarker, TextSize = 16, ZIndex = 32,
}, rewardPanel)
corner(backLobbyBtn, 23); stroke(backLobbyBtn, C.border, 2)
local nextMatchBtn = mk("TextButton", {
    Name = "NextMatch", Size = UDim2.new(0, 250, 0, 46), AnchorPoint = Vector2.new(1,1),
    Position = UDim2.new(1,-18,1,-18), BackgroundColor3 = Color3.fromRGB(90,215,130),
    BorderSizePixel = 0, AutoButtonColor = false, Text = "Next Match  \xE2\x96\xB6",
    TextColor3 = Color3.fromRGB(15,50,25), Font = Enum.Font.PermanentMarker, TextSize = 16, ZIndex = 32,
}, rewardPanel)
corner(nextMatchBtn, 23)

banner.Text = "Round 1"
rewardTitle.Text = "VICTORY!"
local function label(parent, name, text, position, size, textSize)
    local object = mk("TextLabel", {
        Name=name, Text=text, Position=position, Size=size,
        BackgroundTransparency=1, Font=Enum.Font.PermanentMarker,
        TextColor3=Color3.new(1,1,1), TextSize=textSize, TextStrokeTransparency=0.15,
        TextStrokeColor3=Color3.new(), BorderSizePixel=0,
    }, parent)
    return object
end
local function artwork(parent, name, asset, position, size, button)
    return mk(button and "ImageButton" or "ImageLabel", {
        Name=name, Image=asset, Position=position, Size=size,
        BackgroundTransparency=1, BorderSizePixel=0, ScaleType=Enum.ScaleType.Fit,
    }, parent)
end
local function viewport(parent, position, size)
    return mk("ViewportFrame", {
        Name="UnitModel", Position=position, Size=size, BackgroundTransparency=1, BorderSizePixel=0,
        Ambient=Color3.fromRGB(190,190,190), LightColor=Color3.new(1,1,1), LightDirection=Vector3.new(-1,-1,-2),
    }, parent)
end
for _, side in ipairs({"Player", "Opponent"}) do
    local isPlayer = side == "Player"
    local cluster = mk("Frame", {
        Name=side.."Cluster", BackgroundTransparency=1, BorderSizePixel=0,
        Size=UDim2.fromOffset(240,76),
        AnchorPoint=isPlayer and Vector2.new(0,1) or Vector2.new(1,0),
        Position=isPlayer and UDim2.new(0,18,1,-18) or UDim2.new(1,-18,0,18),
    }, hud)
    local name = label(cluster,"NameLbl",side,UDim2.fromOffset(0,0),UDim2.new(1,0,0,26),20)
    name.TextXAlignment=isPlayer and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    local hearts=mk("Frame",{Name="Hearts",BackgroundTransparency=1,Size=UDim2.new(1,0,0,42),Position=UDim2.fromOffset(0,30)},cluster)
    for index=1,4 do
        local x = isPlayer and (index-1)*46 or 240-4*46+(index-1)*46
        artwork(hearts,"Heart"..index,"rbxassetid://89314684232894",UDim2.fromOffset(x,0),UDim2.fromOffset(42,42))
    end
end
local bar=artwork(hud,"EquippedBar","rbxassetid://116303266653759",UDim2.new(1,-18,1,-16),UDim2.fromOffset(410,116))
bar.AnchorPoint=Vector2.new(1,1)
for index=1,4 do
    local slot=artwork(bar,"Slot"..index,"rbxassetid://116604373220052",UDim2.fromOffset(14+(index-1)*98,14),UDim2.fromOffset(88,88))
    viewport(slot,UDim2.fromOffset(9,9),UDim2.fromOffset(70,61))
    local name=label(slot,"UnitName","Slot "..index,UDim2.fromOffset(6,67),UDim2.fromOffset(76,17),12)
    name.TextScaled=true
    mk("UITextSizeConstraint",{MinTextSize=9,MaxTextSize=14},name)
end
local region=mk("Frame",{
    Name="OptionRegion",Size=UDim2.fromOffset(580,266),Position=UDim2.fromScale(0.5,0.6),
    AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Visible=false,
},hud)
label(region,"Timer","Choose your unit  ·  15",UDim2.fromOffset(0,0),UDim2.new(1,0,0,32),23)
local cards=mk("Frame",{Name="Cards",Size=UDim2.new(1,0,1,-38),Position=UDim2.fromOffset(0,38),BackgroundTransparency=1},region)
mk("UIListLayout",{
    FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,
    VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder,
},cards)
local templates=mk("Folder",{Name="Templates"},hud)
local rarityAssets={
    Common="rbxassetid://81336478666792",Rare="rbxassetid://74968163212885",
    Epic="rbxassetid://118531938737279",Legendary="rbxassetid://110235904395766",
    Mythic="rbxassetid://109222511271107",
}
local draft=mk("Folder",{Name="DraftCards"},templates)
for rarity, asset in pairs(rarityAssets) do
    local card=artwork(draft,rarity,asset,UDim2.new(),UDim2.fromOffset(180,220),true)
    card.Visible=false
    card.AutoButtonColor=false
    viewport(card,UDim2.fromOffset(17,25),UDim2.fromOffset(146,157))
    local name=label(card,"UnitName","Unit Name",UDim2.fromOffset(12,181),UDim2.fromOffset(156,28),20)
    name.TextScaled=true
    mk("UITextSizeConstraint",{MinTextSize=12,MaxTextSize=23},name)
    label(card,"Rarity",rarity,UDim2.fromOffset(12,9),UDim2.fromOffset(156,19),14)
    local selection=stroke(card,Color3.fromRGB(255,220,90),3)
    selection.Name="Selection"
    selection.Enabled=false
    corner(card,12)
end
local exit=mk("TextButton",{
    Name="LeaveArena",Text="Back to Lobby",Size=UDim2.fromOffset(150,34),
    Position=UDim2.fromOffset(16,60),BackgroundColor3=C.panel,TextColor3=C.btnTxt,
    Font=Enum.Font.PermanentMarker,TextSize=16,BorderSizePixel=0,ZIndex=25,
},hud)
corner(exit,10)
mk("UIScale",{Name="FitToScreen"},region)
hud:SetAttribute("AutoFitDraft",true)
return {name=hud:GetFullName(),descendants=#hud:GetDescendants()}
