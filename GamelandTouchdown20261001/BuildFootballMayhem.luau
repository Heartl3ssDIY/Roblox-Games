local parent = workspace:FindFirstChild("Oni's Work")
assert(parent, "Oni's Work is missing")
assert(not parent:FindFirstChild("FootballMayhem"), "FootballMayhem already exists")
local marker = parent:FindFirstChild("Part")
assert(marker and marker:IsA("BasePart"), "Expected the original marker part")
local origin = marker.CFrame * CFrame.new(0, marker.Size.Y / 2, 0)
local storage = game:GetService("ServerStorage")
local backup = Instance.new("Folder")
backup.Name = "BeforeFootballMayhem20261001"
backup.Parent = storage
marker:Clone().Parent = backup
workspace.GamelandLobby.LobbyRuntime:Clone().Parent = backup
local arena = Instance.new("Model")
arena.Name = "FootballMayhem"
arena.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
arena:SetAttribute("Rows", 10)
arena:SetAttribute("Lanes", 6)
arena:SetAttribute("InactivitySeconds", 45)
arena:SetAttribute("Rules", "Personal danger lane; one attempt; every finisher qualifies")
arena:SetAttribute("Footprint", Vector3.new(160, 56, 312))
arena.Parent = parent
local function folder(name, target)
    local f = Instance.new("Folder") f.Name = name f.Parent = target or arena return f
end
local architecture = folder("Stadium")
local decor = folder("Details")
local rows = folder("Rows")
local pads = folder("StartPads")
local palette = {
    navy = Color3.fromRGB(35, 126, 229), blue = Color3.fromRGB(74, 181, 250),
    cyan = Color3.fromRGB(63, 205, 230), gold = Color3.fromRGB(255, 201, 66),
    turf = Color3.fromRGB(105, 198, 58), white = Color3.fromRGB(236, 245, 247)
}
local function part(name, size, position, color, target, material)
    local p = Instance.new("Part")
    p.Name = name p.Size = size p.CFrame = origin * CFrame.new(position)
    p.Anchored = true p.Color = color p.Material = material or Enum.Material.Plastic
    p.TopSurface = Enum.SurfaceType.Studs p.BottomSurface = Enum.SurfaceType.Smooth
    p.FrontSurface = Enum.SurfaceType.Studs p.BackSurface = Enum.SurfaceType.Studs p.LeftSurface = Enum.SurfaceType.Studs p.RightSurface = Enum.SurfaceType.Studs p.CanTouch = false p.Parent = target or decor
    return p
end
local function text(p, words, face, color, textSize)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "Label" gui.Face = face gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 28 gui.LightInfluence = 0.1 gui.Parent = p
    local label = Instance.new("TextLabel") label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1) label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne label.TextColor3 = color or palette.white
    label.Text = words label.TextScaled = true label.TextWrapped = true label.Parent = gui
    local padding = Instance.new("UIPadding") padding.PaddingTop = UDim.new(0.1, 0)
    padding.PaddingBottom = UDim.new(0.1, 0) padding.PaddingLeft = UDim.new(0.04, 0)
    padding.PaddingRight = UDim.new(0.04, 0) padding.Parent = label
    local limit = Instance.new("UITextSizeConstraint") limit.MaxTextSize = textSize or 100 limit.MinTextSize = 8 limit.Parent = label
    return gui
end
marker.Name = "FieldBase"
marker.Size = Vector3.new(112, 4, 284)
marker.CFrame = origin * CFrame.new(0, -2, 0)
marker.Color = palette.turf marker.Material = Enum.Material.Plastic marker.Anchored = true marker.Parent = arena
arena.PrimaryPart = marker
local start = part("StartZone", Vector3.new(96, 0.16, 32), Vector3.new(0, 0.08, 126), palette.blue, arena)
text(start, "START  /  CARRY YOUR FOOTBALL", Enum.NormalId.Top)
local finish = part("EndZone", Vector3.new(96, 0.16, 32), Vector3.new(0, 0.08, -126), palette.gold, arena)
text(finish, "TOUCHDOWN", Enum.NormalId.Top, palette.navy)
for i, x in ipairs({-28, 0, 28}) do
    local pad = part("Start" .. i, Vector3.new(8, 0.25, 7), Vector3.new(x, -0.125, 132), palette.cyan, pads)
    pad.Transparency = 1 pad.CanCollide = false pad.CanTouch = false pad.CanQuery = false
end
for row = 1, 10 do
    local model = Instance.new("Model") model.Name = string.format("Row%02d", row) model.Parent = rows
    local z = 102 - (row - 1) * 22
    local strip = part("Row line " .. row, Vector3.new(96, 0.08, 0.28), Vector3.new(0, 0.09, z + 8), palette.white)
    strip.CanCollide = false
    for lane = 1, 6 do
        local x = -40 + (lane - 1) * 16
        local tile = part("Choice" .. lane, Vector3.new(15.5, 0.18, 15.5), Vector3.new(x, 0.1, z),
            row % 2 == 0 and Color3.fromRGB(86, 191, 66) or Color3.fromRGB(123, 213, 72), model)
        tile:SetAttribute("Row", row) tile:SetAttribute("Lane", lane)
        text(tile, tostring(lane), Enum.NormalId.Top, palette.white, 150)
    end
    for _, side in ipairs({-1, 1}) do
        local number = part("Row marker " .. row, Vector3.new(5, 0.12, 9), Vector3.new(side * 52, 0.12, z), palette.navy)
        text(number, string.format("%02d", row), Enum.NormalId.Top, palette.gold)
    end
end
for _, x in ipairs({-48, 48}) do
    local line = part("Sideline", Vector3.new(0.35, 0.14, 284), Vector3.new(x, 0.15, 0), palette.white)
    line.CanCollide = false
    local barrier = part("Field boundary", Vector3.new(1.2, 8, 284), Vector3.new(x + (x < 0 and -1 or 1), 4, 0), palette.blue, architecture)
    barrier.Material = Enum.Material.Glass barrier.Transparency = 0.55
end
part("Stadium foundation", Vector3.new(160, 5, 312), Vector3.new(0, -3, 0), palette.navy, architecture)
for _, side in ipairs({-1, 1}) do
    part("Enclosing side wall", Vector3.new(3, 56, 312), Vector3.new(side * 78.5, 25, 0), palette.navy, architecture)
    part("Upper cyan ribbon", Vector3.new(0.6, 1.2, 308), Vector3.new(side * 76.7, 46, 0), palette.cyan, architecture, Enum.Material.Neon)
    for tier = 1, 2 do
        local x = side * (53 + tier * 5)
        part("Stand tier", Vector3.new(5, tier * 3, 268), Vector3.new(x, tier * 1.5, 0), palette.blue, architecture)
        for seat = 1, 24 do
            part("Seat", Vector3.new(3.2, 1, 5.2), Vector3.new(x, tier * 3 + 0.5, -130 + seat * 10.4),
                (seat + tier) % 4 == 0 and palette.gold or (tier % 2 == 0 and palette.cyan or Color3.fromRGB(255, 139, 89)), decor)
        end
    end
    for z = -140, 140, 40 do
        part("Wall rib", Vector3.new(2.5, 53, 2), Vector3.new(side * 76.5, 24, z), palette.blue, architecture)
    end
end
part("Start enclosure", Vector3.new(160, 56, 3), Vector3.new(0, 25, 154.5), palette.navy, architecture)
part("Finish enclosure", Vector3.new(160, 56, 3), Vector3.new(0, 25, -154.5), palette.navy, architecture)
local scoreboard = part("Scoreboard", Vector3.new(88, 15, 1), Vector3.new(0, 35, -152.5), palette.blue, arena)
text(scoreboard, "FOOTBALL MAYHEM\n10 ROWS  /  6 CHOICES  /  DELIVER YOUR BALL", Enum.NormalId.Back, palette.white)
local instructions = part("Rules board", Vector3.new(91, 15, 1), Vector3.new(0, 34, 152.5), palette.blue)
text(instructions, "ONE WRONG LANE PER ROW\nCarry your football to the gold end zone. Your danger lanes are personal.\nWrong choice = tackled! No retries this round.", Enum.NormalId.Front)
for _, x in ipairs({-16, 16}) do
    part("Goal upright", Vector3.new(1, 18, 1), Vector3.new(x, 22, -140), palette.gold, decor, Enum.Material.Neon)
end
part("Goal crossbar", Vector3.new(33, 1, 1), Vector3.new(0, 13, -140), palette.gold, decor, Enum.Material.Neon)
part("Goal support", Vector3.new(1.8, 13, 1.8), Vector3.new(0, 6.5, -140), palette.gold)
for _, side in ipairs({-1, 1}) do
    for _, z in ipairs({-105, -35, 35, 105}) do
        part("Floodlight pole", Vector3.new(1, 39, 1), Vector3.new(side * 70, 19.5, z), palette.blue)
        local lamp = part("Floodlight", Vector3.new(10, 2, 3), Vector3.new(side * 62, 39, z), palette.white, decor, Enum.Material.Neon)
        local light = Instance.new("SurfaceLight") light.Face = Enum.NormalId.Bottom light.Angle = 150
        light.Range = 60 light.Brightness = 2 light.Color = Color3.fromRGB(225, 240, 255) light.Shadows = true light.Parent = lamp
    end
end
local rep = Instance.new("Folder") rep.Name = "FootballMayhem" rep:SetAttribute("Phase", "Idle") rep.Parent = game:GetService("ReplicatedStorage")
local cf = Instance.new("CFrameValue") cf.Name = "ArenaOrigin" cf.Value = origin cf.Parent = rep
for _, name in ipairs({"Action", "Feedback"}) do local event = Instance.new("RemoteEvent") event.Name = name event.Parent = rep end
local env = folder("Environment", rep)
local sky = Instance.new("Sky") sky.Name = "StadiumSky"
sky.SkyboxBk = "rbxassetid://150335574" sky.SkyboxDn = "rbxassetid://150335585" sky.SkyboxFt = "rbxassetid://150335628"
sky.SkyboxLf = "rbxassetid://150335620" sky.SkyboxRt = "rbxassetid://150335610" sky.SkyboxUp = "rbxassetid://150335642"
sky.StarCount = 0 sky.CelestialBodiesShown = true sky.Parent = env
local atmosphere = Instance.new("Atmosphere") atmosphere.Name = "StadiumAtmosphere"
atmosphere.Density = 0.1 atmosphere.Offset = 0.15 atmosphere.Color = Color3.fromRGB(196, 230, 255)
atmosphere.Decay = Color3.fromRGB(130, 175, 229) atmosphere.Haze = 0.5 atmosphere.Parent = env
local bloom = Instance.new("BloomEffect") bloom.Name = "StadiumBloom" bloom.Intensity = 0.16 bloom.Size = 20 bloom.Threshold = 1.5 bloom.Parent = env
marker.TopSurface = Enum.SurfaceType.Studs
arena:SetAttribute("AutoStartInStudio", false)
folder("RoundEffects")
local templates = folder("FootballMayhemAssets", storage)
for sourceName, templateName in pairs({["Quater back"] = "Quarterback", ["American football"] = "AmericanFootball"}) do
    local source = parent:FindFirstChild(sourceName)
    assert(source and source:IsA("Model"), "Imported model missing: " .. sourceName)
    source.Parent = backup
    local copy = source:Clone()
    copy.Name = templateName
    for _, descendant in ipairs(copy:GetDescendants()) do
        if descendant:IsA("LuaSourceContainer") then descendant:Destroy()
        elseif descendant:IsA("BasePart") then descendant.Anchored = true descendant.CanCollide = false descendant.CanTouch = false end
    end
    copy.PrimaryPart = copy:FindFirstChild("HumanoidRootPart") or copy:FindFirstChildWhichIsA("BasePart", true)
    copy.Parent = templates
end
do
local a=workspace["Oni's Work"].FootballMayhem
local history=game:GetService("ChangeHistoryService")
local recording=history:TryBeginRecording("FootballMayhemVisualPolish","Neon choices and dark-green borders")
local borders=a:FindFirstChild("ChoiceBorders") or Instance.new("Folder")
borders.Name="ChoiceBorders" borders.Parent=a
local changed,removed=0,0
for _,row in a.Rows:GetChildren() do
 for _,tile in row:GetChildren() do
  if tile:IsA("BasePart") then
   tile.Material=Enum.Material.Neon
   local label=tile:FindFirstChild("Label")
   if label then label:Destroy() removed+=1 end
   local name=row.Name.."_"..tile.Name
   local border=borders:FindFirstChild(name) or Instance.new("Folder")
   border.Name=name border.Parent=borders
   local thickness=.22
   for index,spec in ipairs({
    {Vector3.new(tile.Size.X+.12,.035,thickness),CFrame.new(0,tile.Size.Y/2+.025,-tile.Size.Z/2+.08)},
    {Vector3.new(tile.Size.X+.12,.035,thickness),CFrame.new(0,tile.Size.Y/2+.025,tile.Size.Z/2-.08)},
    {Vector3.new(thickness,.035,tile.Size.Z+.12),CFrame.new(-tile.Size.X/2+.08,tile.Size.Y/2+.025,0)},
    {Vector3.new(thickness,.035,tile.Size.Z+.12),CFrame.new(tile.Size.X/2-.08,tile.Size.Y/2+.025,0)}
   }) do
    local edge=border:FindFirstChild("Edge"..index) or Instance.new("Part")
    edge.Name="Edge"..index edge.Size=spec[1] edge.CFrame=tile.CFrame*spec[2]
    edge.Color=Color3.fromRGB(26,91,36) edge.Material=Enum.Material.SmoothPlastic
    edge.Anchored=true edge.CanCollide=false edge.CanTouch=false edge.CanQuery=false edge.CastShadow=false
    edge.Parent=border
   end
   changed+=1
  end
 end
end
for _,v in a.Details:GetChildren() do if string.match(v.Name,"^Row marker ") then v:Destroy() removed+=1 end end
for _,pad in a.StartPads:GetChildren() do pad.Transparency=1 pad.CanCollide=false pad.CanTouch=false pad.CanQuery=false end
if recording then history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end

end
do
local arena = workspace["Oni's Work"].FootballMayhem
local assets = game.ReplicatedStorage.FootballMayhem
local base = arena.FieldBase
assets.ArenaOrigin.Value = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
local top = base.Position.Y + base.Size.Y / 2
for _, part in ipairs(arena.Rows:GetDescendants()) do
    if part:IsA("BasePart") then
        top = math.max(top, part.Position.Y + part.Size.Y / 2)
        part.CanCollide = false
    end
end
local floor = arena:FindFirstChild("SupportFloor") or Instance.new("Part")
floor.Name = "SupportFloor"
floor.Size = Vector3.new(base.Size.X, 4, base.Size.Z)
floor.CFrame = CFrame.new(base.Position.X, top + 0.01 - 2, base.Position.Z) * base.CFrame.Rotation
floor.Anchored = true
floor.Transparency = 1
floor.CanCollide = true
floor.CanTouch = false
floor.CanQuery = true
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = arena
arena.StartZone.CanCollide = false
arena.EndZone.CanCollide = false
base.CanCollide = true
end
return {origin = tostring(origin.Position), descendants = #arena:GetDescendants(), backup = backup:GetFullName(), font = "FredokaOne", screenGuiCreated = false}
