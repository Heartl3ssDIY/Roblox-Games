assert(game.PlaceId == 106769122906103, "This installer belongs to Round 1 Muliplayer only")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local course = assert(workspace:FindFirstChild(" Course -  round 1"), "Course one is missing")
local installed = course:FindFirstChild("HalloweenGameplay")
if installed and installed:GetAttribute("BuildVersion") == "20261003-1" then
    return {AlreadyInstalled = true, Root = installed:GetFullName()}
end
assert(not installed, "An unrelated HalloweenGameplay folder already exists")
assert(not ReplicatedStorage:FindFirstChild("GBloxHalloweenAssets"), "Halloween asset root already exists")

local imports = {
    "Floor_Web_Trap", "Last_Place_Chaser_Ghost", "Jack_O_Lantern", "Corner_Cobweb",
    "Gravestone_Without_Hand", "Ectoplasm_Lantern", "Throwable_Pumpkin", "Gravestone_Trap",
    "Halloween_Bone_Saw_Platform",
}
local sources = {}
for _,name in imports do
    local source = assert(workspace:FindFirstChild(name), "Missing imported model: " .. name)
    assert(source:IsA("Model"), name .. " must be a Model")
    sources[name] = source
end

local function surface(x, y)
    local best, distance
    for _,part in course:GetDescendants() do
        if part:IsA("BasePart") and part.Name == "Flat_Platform_RunSurface" and part.CanCollide then
            local score = math.abs(part.Position.X - x) + math.abs(part.Position.Y - y) * 3
            if not distance or score < distance then best, distance = part, score end
        end
    end
    assert(best and distance < 2, "Course support moved; review placement before installing")
    return best
end

local supports = {
    StartLower = surface(3471.028, 0.0669), FirstUpper = surface(3327.028, 44.0669),
    WebLower = surface(3279.028, 4.0669), GraveLower = surface(3116.028, -8.9331),
    SkullLower = surface(3067.028, -1.9331), SkullUpper = surface(2962.308, 54.0669),
    GraveUpper = surface(2770.308, 54.0669), MidLower = surface(2670.028, 6.0666),
    WebUpper = surface(2422.028, 40.0669), LateLower = surface(1781.928, 4.067),
    LastUpper = surface(952.708, 40.0669),
}

local function bottomPivot(model)
    model.PrimaryPart = nil
    local cf,size = model:GetBoundingBox()
    local low = math.huge
    for _,part in model:GetDescendants() do
        if part:IsA("BasePart") then
            for _,x in {-1, 1} do
                for _,y in {-1, 1} do
                    for _,z in {-1, 1} do
                        low = math.min(low, (part.CFrame * Vector3.new(part.Size.X*x/2, part.Size.Y*y/2, part.Size.Z*z/2)).Y)
                    end
                end
            end
        end
    end
    assert(low < math.huge, "Model contains no parts")
    model.WorldPivot = CFrame.new(cf.Position.X, low, cf.Position.Z)
end

local function prepare(model)
    model:SetAttribute("HalloweenOnly", true)
    pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
    for _,item in model:GetDescendants() do
        if item:IsA("LuaSourceContainer") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
            item.CanTouch = false
            item.CanQuery = false
            item:SetAttribute("OriginalTransparency", item.Transparency)
            item:SetAttribute("HalloweenVisibleTransparency", item.Transparency)
            item.CastShadow = false
        elseif item:IsA("Light") then
            item:SetAttribute("HalloweenVisibleEnabled", item.Enabled)
        end
    end
end

local assets = Instance.new("Folder")
assets.Name = "GBloxHalloweenAssets"
assets:SetAttribute("BuildVersion", "20261003-1")
local templates = {}
for _,name in imports do
    local model = sources[name]:Clone()
    model.Name = name
    prepare(model)
    bottomPivot(model)
    model:PivotTo(CFrame.new())
    model.Parent = assets
    templates[name] = model
end

local function alias(original, name)
    local model = templates[original]:Clone()
    model.Name = name
    model.Parent = assets
    return model
end
alias("Last_Place_Chaser_Ghost", "Ghost")
alias("Floor_Web_Trap", "Trap_Web")

local graveTemplate = templates.Gravestone_Trap
local hand = Instance.new("Model")
hand.Name = "Zombie_Hand"
local handParts = {}
for _,part in graveTemplate:GetDescendants() do
    if part:IsA("BasePart") and (part.Name:find("Finger", 1, true) or part.Name:find("Palm", 1, true)
        or part.Name:find("Forearm", 1, true) or part.Name:find("Thumb", 1, true) or part.Name:find("Cuff", 1, true)) then
        handParts[part.Name] = part
    end
end
for _,part in handParts do part.Parent = hand end
local palm = assert(handParts.Halloween_Palm, "Imported zombie palm is missing")
for index=1,4 do
    local suffix = index == 1 and "" or string.format(".%03d", index-1)
    local finger = Instance.new("Model")
    finger.Name = "Finger" .. index
    for _,name in {"Halloween_Finger_" .. index, "Halloween_Finger_Knuckle" .. suffix, "Halloween_Finger_Nail" .. suffix} do
        assert(handParts[name], "Imported zombie finger component is missing: " .. name).Parent = finger
    end
    local knuckle = handParts["Halloween_Finger_Knuckle" .. suffix]
    finger.WorldPivot = CFrame.new(knuckle.Position.X, palm.Position.Y + palm.Size.Y/2, palm.Position.Z)
    finger:SetAttribute("CurlDegrees", -55)
    finger.Parent = hand
end
local thumb = Instance.new("Model")
thumb.Name = "Thumb"
handParts.Halloween_Hooked_Thumb.Parent = thumb
thumb.WorldPivot = CFrame.new(palm.Position.X + palm.Size.X/2, palm.Position.Y, palm.Position.Z)
thumb:SetAttribute("CurlDegrees", -30)
thumb.Parent = hand
prepare(hand)
bottomPivot(hand)
hand:PivotTo(CFrame.new())
hand:SetAttribute("ForwardAxis", "-Z")
hand:SetAttribute("CurlAxis", "X")
hand:SetAttribute("RiseSeconds", 0.6)
hand:SetAttribute("HoldSeconds", 5)
hand.Parent = assets

local skull = Instance.new("Model")
skull.Name = "Skull_Decoration"
local bone = templates.Halloween_Bone_Saw_Platform
local face = assert(bone:FindFirstChild("Halloween_Skull.004", true), "Imported skull decoration is missing")
for _,part in bone:GetDescendants() do
    if part:IsA("BasePart") and part.Name:find("Skull", 1, true) and math.abs(part.Position.X - face.Position.X) < 0.75 then
        part:Clone().Parent = skull
    end
end
prepare(skull)
bottomPivot(skull)
skull:PivotTo(CFrame.new())
skull:ScaleTo(skull:GetScale() * 3.2)
skull.Parent = assets

local root = Instance.new("Folder")
root.Name = "HalloweenGameplay"
root:SetAttribute("BuildVersion", "20261003-1")
root:SetAttribute("CourseIndex", 1)
root:SetAttribute("HalloweenOnly", true)
local decorations = Instance.new("Folder")
decorations.Name = "Decorations"
decorations.Parent = root
local traps = Instance.new("Folder")
traps.Name = "Traps"
traps.Parent = root

local placements = {}
local function attachSupport(model, support)
    local link = Instance.new("ObjectValue")
    link.Name = "Support"
    link.Value = support
    link.Parent = model
end
local function floorFrame(support, x, sign, z)
    local y = support.Position.Y + sign * support.Size.Y/2
    return CFrame.new(x, y + sign*0.08, z or support.Position.Z) * (sign == -1 and CFrame.Angles(0, 0, math.pi) or CFrame.identity)
end
local function decorate(template, name, support, x, sign, scale)
    local model = template:Clone()
    model.Name = name
    if scale then model:ScaleTo(model:GetScale()*scale) end
    local z = support.Position.Z - support.Size.Z/2 + 1.0
    model:PivotTo(floorFrame(support, x, sign, z))
    attachSupport(model, support)
    model.Parent = decorations
    table.insert(placements, {Name=name, Position=model:GetPivot().Position})
    return model
end

local skulls = {
    {"StartLower", 3460, 1}, {"FirstUpper", 3337, -1}, {"SkullLower", 3075, 1}, {"SkullUpper", 2954, -1},
    {"MidLower", 2685, 1}, {"WebUpper", 2429, -1}, {"LateLower", 1790, 1}, {"LastUpper", 960, -1},
}
for index,row in skulls do decorate(skull, "Skull" .. index, supports[row[1]], row[2], row[3]) end
local props = {
    {"Jack_O_Lantern", "StartLower", 3481, 1, 0.9},
    {"Ectoplasm_Lantern", "FirstUpper", 3316, -1, 0.8},
    {"Gravestone_Without_Hand", "WebLower", 3294, 1, 0.85},
    {"Jack_O_Lantern", "SkullUpper", 2969, -1, 0.85},
    {"Ectoplasm_Lantern", "MidLower", 2660, 1, 0.85},
    {"Gravestone_Without_Hand", "WebUpper", 2435, -1, 0.75},
    {"Jack_O_Lantern", "LateLower", 1770, 1, 0.9},
    {"Ectoplasm_Lantern", "LastUpper", 944, -1, 0.85},
}
for index,row in props do
    local model = decorate(templates[row[1]], row[1] .. index, supports[row[2]], row[3], row[4], row[5])
    if row[1] == "Ectoplasm_Lantern" then
        local core = model:FindFirstChild("Halloween_Lantern_Luminous_Core", true)
        core.Material = Enum.Material.Neon
        core.Color = Color3.fromRGB(255, 173, 54)
        local light = Instance.new("PointLight")
        light.Name = "WarmLanternLight"
        light.Color = core.Color
        light.Range = 12
        light.Brightness = 1.1
        light.Shadows = false
        light:SetAttribute("HalloweenVisibleEnabled", true)
        light.Parent = core
    end
end

local function sensor(model, support, cf, size)
    local part = Instance.new("Part")
    part.Name = "Sensor"
    part.Size = size
    part.CFrame = cf
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part:SetAttribute("HalloweenVisibleTransparency", 1)
    part:SetAttribute("OriginalTransparency", 1)
    attachSupport(part, support)
    part.Parent = model
    attachSupport(model, support)
    return part
end
local function cornerWeb(name, support, x, sign)
    local trap = Instance.new("Model")
    trap.Name = name
    trap:SetAttribute("TrapType", "CornerWeb")
    trap:SetAttribute("SurfaceNormalY", sign)
    trap:SetAttribute("HoldSeconds", 5)
    trap:SetAttribute("HalloweenOnly", true)
    local visual = templates.Corner_Cobweb:Clone()
    visual.Name = "WebArtwork"
    visual:ScaleTo(visual:GetScale() * 1.15)
    for _,part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = Color3.fromRGB(174, 255, 171)
            part.Material = Enum.Material.Neon
        end
    end
    local floor = floorFrame(support, x, sign, 8330)
    visual:PivotTo(floor)
    visual.Parent = trap
    local zone = sensor(trap, support, floor * CFrame.new(0, 3, 0), Vector3.new(5.5, 6, 5.5))
    trap.WorldPivot = floor
    pcall(function() trap.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
    trap.Parent = traps
    table.insert(placements, {Name=name, Position=zone.Position, Type="CornerWeb"})
end
local function graveTrap(name, support, x, sign)
    local trap = Instance.new("Model")
    trap.Name = name
    trap:SetAttribute("TrapType", "Grave")
    trap:SetAttribute("SurfaceNormalY", sign)
    trap:SetAttribute("StationarySeconds", 1)
    trap:SetAttribute("HoldSeconds", 5)
    trap:SetAttribute("HalloweenOnly", true)
    local floor = floorFrame(support, x, sign, 8330)
    local artwork = graveTemplate:Clone()
    artwork.Name = "GraveArtwork"
    bottomPivot(artwork)
    artwork:PivotTo(floor * CFrame.new(0, 0, 1.4))
    artwork.Parent = trap
    local restHand = hand:Clone()
    restHand.Name = "ZombieHand"
    restHand:SetAttribute("HalloweenRestHidden", true)
    restHand:PivotTo(floor * CFrame.new(0, -4.5, 0))
    for _,part in restHand:GetDescendants() do
        if part:IsA("BasePart") then
            part:SetAttribute("HalloweenRestHidden", true)
            part.Transparency = 1
        end
    end
    restHand.Parent = trap
    local zone = sensor(trap, support, floor * CFrame.new(0, 3, 0), Vector3.new(7, 6, 5.5))
    trap.WorldPivot = floor
    pcall(function() trap.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
    trap.Parent = traps
    table.insert(placements, {Name=name, Position=zone.Position, Type="Grave"})
end
cornerWeb("CornerWeb_Lower", supports.WebLower, 3268, 1)
cornerWeb("CornerWeb_Upper", supports.WebUpper, 2425, -1)
graveTrap("Grave_LowerRidge", supports.GraveLower, 3096, 1)
graveTrap("Grave_UpperRidge", supports.GraveUpper, 2749, -1)

local theme = ReplicatedStorage:FindFirstChild("GBloxCourseTheme")
local show = theme and theme:GetAttribute("ActiveTheme") == "Halloween"
for _,item in root:GetDescendants() do
    if item:IsA("BasePart") then
        local visible = item:GetAttribute("HalloweenVisibleTransparency") or 0
        item.Transparency = (show and not item:GetAttribute("HalloweenRestHidden")) and visible or 1
    elseif item:IsA("Light") then
        item.Enabled = show == true and item:GetAttribute("HalloweenVisibleEnabled") == true
    end
end
assets.Parent = ReplicatedStorage
root.Parent = course
return {Root = root:GetFullName(), Assets = assets:GetFullName(), Placements = placements, ImportedSourcesUntouched = true}
