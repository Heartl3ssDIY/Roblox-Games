assert(game.PlaceId == 106769122906103, "This installer belongs to Round 1 Muliplayer only")
assert(game.ServerStorage:FindFirstChild("BeforeHalloweenPolish20261004"), "Recovery backup is missing")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local assets = assert(ReplicatedStorage:FindFirstChild("GBloxHalloweenAssets"), "Halloween templates are missing")
local settings = assert(ReplicatedStorage:FindFirstChild("GBloxHalloweenSettings"), "Halloween settings are missing")
local buildVersion = "20261004-decor-1"
local plan = {
    {Index=2, Supports={
        {Position=Vector3.new(-70560.7578125,30.65250015258789,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-70927.625,-1.3827781677246094,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-71335.6015625,32.74800109863281,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-71672.2734375,52.132171630859375,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(-72080.9375,33.993526458740234,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-72458.484375,41.23331069946289,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(-72831.046875,31.244659423828125,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-73139.3984375,15.242847442626953,82031.1796875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
    }},
    {Index=3, Supports={
        {Position=Vector3.new(-25756.044921875,32.20673370361328,-11669.8193359375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-26141.58203125,2.1132354736328125,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-26510.9453125,-22.0157470703125,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-26969.41015625,-22.015743255615234,-11669.8193359375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-27380.8828125,-22.60379981994629,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(-27758.58203125,50.56940460205078,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(-28181.083984375,62.31126403808594,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(-28510.869140625,67.34124755859375,-11669.5302734375), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
    }},
    {Index=4, Supports={
        {Position=Vector3.new(196662.78125,34785.6171875,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(196272.78125,34785.6171875,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(195802.4375,34785.6171875,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(195361.078125,34849.203125,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(194926.265625,34785.6171875,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(194487.171875,34842.16015625,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(194050.859375,34813.65234375,-15307.82421875), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(193691.78125,34915.59765625,-15307.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
    }},
    {Index=5, Supports={
        {Position=Vector3.new(72470.7890625,45502.8828125,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(72103.6171875,45477.6171875,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(71709.1484375,45481.9140625,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(71330.7578125,45544.04296875,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(70966.1171875,45491.046875,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(70590.9453125,45534.4765625,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
        {Position=Vector3.new(70223.984375,45468.6171875,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=1},
        {Position=Vector3.new(69873.1953125,45544.04296875,-56524.8203125), Size=Vector3.new(34.82898712158203,1.451209306716919,11.695282936096191), Sign=-1},
    }},
}
local templates = {}
for _,name in {"Skull_Decoration", "Jack_O_Lantern", "Ectoplasm_Lantern", "Gravestone_Without_Hand", "Corner_Cobweb"} do
    templates[name] = assert(assets:FindFirstChild(name), "Missing Halloween template: " .. name)
    assert(templates[name]:IsA("Model"), name .. " must be a Model")
    for _,descendant in templates[name]:GetDescendants() do
        assert(not descendant:IsA("LuaSourceContainer"), "Template contains code; review it instead of deleting it: " .. name)
    end
end

local courses = {}
local existing = 0
for _,row in plan do
    local course = assert(workspace:FindFirstChild(" Course -  round " .. row.Index), "Course is missing")
    local root = course:FindFirstChild("HalloweenGameplay")
    if root then
        assert(root:GetAttribute("BuildVersion") == buildVersion, "An unrelated HalloweenGameplay folder already exists")
        existing += 1
    end
    courses[row.Index] = course
end
if existing == #plan then
    return {AlreadyInstalled=true, BuildVersion=buildVersion}
end
assert(existing == 0, "Partial installation exists; restore it before retrying")

local function findSupport(course, expected)
    local best, distance
    for _,part in course:GetDescendants() do
        if part:IsA("BasePart") and part.Name == "Flat_Platform_RunSurface" then
            local candidateDistance = (part.Position - expected.Position).Magnitude
            if not distance or candidateDistance < distance then
                best, distance = part, candidateDistance
            end
        end
    end
    assert(best and distance < 0.04, "Course support moved; review placements before installing")
    assert(best.CanCollide and (best.Size-expected.Size).Magnitude < 0.04, "Course support size or collision changed")
    assert(math.abs(best.CFrame.UpVector.Y) > 0.99, "Course support is no longer horizontal")
    return best
end
for _,row in plan do
    row.Resolved = {}
    for _,expected in row.Supports do
        table.insert(row.Resolved, findSupport(courses[row.Index], expected))
    end
end

local archive = ReplicatedStorage:FindFirstChild("GBloxHalloweenLooseImports")
assert(not archive or archive:IsA("Folder"), "Loose-import archive must be a Folder")
local looseNames = {
    "Floor_Web_Trap", "Last_Place_Chaser_Ghost", "Jack_O_Lantern", "Corner_Cobweb",
    "Gravestone_Without_Hand", "Ectoplasm_Lantern", "Throwable_Pumpkin", "Gravestone_Trap",
    "Halloween_Platform_Skull_Decoration.002", "Halloween_Platform_Skull_Decoration.003",
}
local loose = {}
for _,name in looseNames do
    local source = workspace:FindFirstChild(name)
    if source then
        assert(source:IsA("Model"), "Expected a loose imported Model: " .. name)
        assert(not archive or not archive:FindFirstChild(name), "An archived import already has this name")
        table.insert(loose, source)
    end
end

local function prepare(model)
    assert(model.Parent == nil, "Pass-through settings apply only to detached new clones")
    model:SetAttribute("HalloweenOnly", true)
    pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
    for _,item in model:GetDescendants() do
        if item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
            item.CanTouch = false
            item.CanQuery = false
            item.CastShadow = false
            item:SetAttribute("HalloweenVisibleTransparency", item.Transparency)
            item:SetAttribute("OriginalTransparency", item.Transparency)
        elseif item:IsA("Light") then
            item:SetAttribute("HalloweenVisibleEnabled", item.Enabled)
        end
    end
end
local function attachSupport(instance, support)
    local link = Instance.new("ObjectValue")
    link.Name = "Support"
    link.Value = support
    link.Parent = instance
end
local function floorFrame(support, x, sign, z)
    local y = support.Position.Y + sign * (support.Size.Y/2 + 0.04)
    return CFrame.new(x, y, z) * (sign == -1 and CFrame.Angles(0, 0, math.pi) or CFrame.identity)
end
local placements = {}
local created = {}
local propCycle = {"Jack_O_Lantern", "Ectoplasm_Lantern", "Gravestone_Without_Hand"}
local function decorate(parent, templateName, name, support, sign, x, scale)
    local model = templates[templateName]:Clone()
    model.Name = name
    prepare(model)
    model:ScaleTo(model:GetScale() * scale)
    local z = support.Position.Z - support.Size.Z/2 + 2.2
    model:PivotTo(floorFrame(support, x, sign, z))
    attachSupport(model, support)
    if templateName == "Ectoplasm_Lantern" then
        local core = model:FindFirstChild("Halloween_Lantern_Luminous_Core", true)
        if core and core:IsA("BasePart") then
            core.Material = Enum.Material.Neon
            core.Color = Color3.fromRGB(255, 173, 54)
            local light = Instance.new("PointLight")
            light.Name = "WarmLanternLight"
            light.Color = core.Color
            light.Range = 10
            light.Brightness = 0.8
            light.Shadows = false
            light:SetAttribute("HalloweenVisibleEnabled", true)
            light.Parent = core
        end
    end
    model.Parent = parent
    table.insert(placements, {CourseIndex=parent.Parent:GetAttribute("CourseIndex"), Name=name,
        Support=support:GetFullName(), Position={model:GetPivot().Position.X,model:GetPivot().Position.Y,model:GetPivot().Position.Z},
        SurfaceNormalY=sign, Kind="Decoration"})
end
local function cornerWeb(parent, name, support, sign, x)
    local trap = Instance.new("Model")
    trap.Name = name
    trap:SetAttribute("TrapType", "CornerWeb")
    trap:SetAttribute("SurfaceNormalY", sign)
    trap:SetAttribute("HoldSeconds", 7)
    trap:SetAttribute("HalloweenOnly", true)
    local floor = floorFrame(support, x, sign, support.Position.Z + 0.5)
    local visual = templates.Corner_Cobweb:Clone()
    visual.Name = "WebArtwork"
    prepare(visual)
    visual:ScaleTo(visual:GetScale() * 1.15)
    for _,part in visual:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = Color3.fromRGB(174, 255, 171)
            part.Material = Enum.Material.Neon
        end
    end
    visual:PivotTo(floor)
    visual.Parent = trap
    local sensor = Instance.new("Part")
    sensor.Name = "Sensor"
    sensor.Size = Vector3.new(5.5, 6, 5.5)
    sensor.CFrame = floor * CFrame.new(0, 3, 0)
    sensor.Transparency = 1
    sensor.Anchored = true
    sensor.CanCollide = false
    sensor.CanTouch = false
    sensor.CanQuery = false
    sensor.CastShadow = false
    sensor:SetAttribute("HalloweenVisibleTransparency", 1)
    sensor:SetAttribute("OriginalTransparency", 1)
    attachSupport(sensor, support)
    sensor.Parent = trap
    attachSupport(trap, support)
    trap.WorldPivot = floor
    pcall(function() trap.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
    trap.Parent = parent
    table.insert(placements, {CourseIndex=parent.Parent:GetAttribute("CourseIndex"), Name=name,
        Support=support:GetFullName(), Position={sensor.Position.X,sensor.Position.Y,sensor.Position.Z},
        SurfaceNormalY=sign, Kind="CornerWeb"})
end

for _,row in plan do
    local root = Instance.new("Folder")
    root.Name = "HalloweenGameplay"
    root:SetAttribute("BuildVersion", buildVersion)
    root:SetAttribute("CourseIndex", row.Index)
    root:SetAttribute("HalloweenOnly", true)
    local decorations = Instance.new("Folder")
    decorations.Name = "Decorations"
    decorations.Parent = root
    local traps = Instance.new("Folder")
    traps.Name = "Traps"
    traps.Parent = root
    local pairIndex = 0
    for index,support in row.Resolved do
        local sign = row.Supports[index].Sign
        if index == 2 then
            local x = support.Position.X + (row.Index == 3 and 6.5 or 0)
            cornerWeb(traps, "CornerWeb_Lower", support, 1, x)
        elseif index == 6 then
            local x = support.Position.X - (row.Index == 2 and 6.5 or 0)
            cornerWeb(traps, "CornerWeb_Upper", support, -1, x)
        else
            pairIndex += 1
            decorate(decorations, "Skull_Decoration", "Skull" .. pairIndex, support, sign, support.Position.X+7, 1)
            local prop = propCycle[(pairIndex-1)%#propCycle+1]
            decorate(decorations, prop, prop .. pairIndex, support, sign, support.Position.X-7, 0.75)
        end
    end
    table.insert(created, {Root=root, Course=courses[row.Index]})
end

local theme = ReplicatedStorage:FindFirstChild("GBloxCourseTheme")
local show = settings:GetAttribute("Enabled") == true and theme and theme:GetAttribute("ActiveTheme") == "Halloween"
for _,row in created do
    for _,item in row.Root:GetDescendants() do
        if item:IsA("BasePart") then
            item.Transparency = show and (item:GetAttribute("HalloweenVisibleTransparency") or 0) or 1
        elseif item:IsA("Light") then
            item.Enabled = show == true and item:GetAttribute("HalloweenVisibleEnabled") == true
        end
    end
end
for _,row in created do row.Root.Parent = row.Course end

local courseOne = workspace:FindFirstChild(" Course -  round 1")
local existingTraps = courseOne and courseOne:FindFirstChild("HalloweenGameplay") and courseOne.HalloweenGameplay:FindFirstChild("Traps")
if existingTraps then
    for _,trap in existingTraps:GetChildren() do
        if trap:GetAttribute("TrapType") == "CornerWeb" then trap:SetAttribute("HoldSeconds", 7) end
    end
end

local archived = {}
if #loose > 0 then
    if not archive then
        archive = Instance.new("Folder")
        archive.Name = "GBloxHalloweenLooseImports"
        archive.Parent = ReplicatedStorage
    end
    local manifest = Instance.new("StringValue")
    manifest.Name = "OriginalWorkspaceLocations_20261004"
    local records = {}
    for _,model in loose do
        local components = {model:GetPivot():GetComponents()}
        table.insert(records, {Name=model.Name, OriginalParent=model.Parent:GetFullName(), Pivot=components})
    end
    manifest.Value = HttpService:JSONEncode(records)
    manifest.Parent = archive
    for _,model in loose do
        model.Parent = archive
        table.insert(archived, model.Name)
    end
end
return {BuildVersion=buildVersion, AddedCourses={2,3,4,5}, Placements=placements, ArchivedLooseImports=archived,
    DecorationsPerCourse=12, CornerWebsPerCourse=2, OriginalPlatformsUntouched=true}

