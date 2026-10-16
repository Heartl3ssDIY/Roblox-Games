-- Import the two approved Blender samples into Studio, without publishing.
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local names = {"HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}
local parentNames = {Torso = "HumanoidRootPart", Head = "Torso", ["Right Arm"] = "Torso", ["Left Arm"] = "Torso", ["Right Leg"] = "Torso", ["Left Leg"] = "Torso"}
local specs = {
    {name = "RockLiiTriplePunch", file = "rock_lii_triple_punch.keyframes.json", duration = 1.5, count = 46, priority = Enum.AnimationPriority.Action},
    {name = "RockLiiDrunkenFist", file = "rock_lii_drunken_fist.keyframes.json", duration = 7, count = 211, priority = Enum.AnimationPriority.Action2},
}
local staged = {}
for _, spec in ipairs(specs) do
    local data = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8874/exports/" .. spec.file))
    assert(type(data.kfs) == "table" and #data.kfs == spec.count, "Unexpected keyframe count")
    assert(math.abs(data.kfs[#data.kfs].t - spec.duration) < 0.00001, "Unexpected animation duration")
    local sequence = Instance.new("KeyframeSequence")
    sequence.Name = spec.name
    sequence.Loop = false
    sequence.Priority = spec.priority
    sequence:SetAttribute("Source", "Reviewed Blender animation")
    sequence:SetAttribute("SourceFile", spec.file)
    sequence:SetAttribute("Duration", spec.duration)
    sequence:SetAttribute("SampleRate", 30)
    sequence:SetAttribute("RootMotionInTorso", true)
    local previousTime = -1
    for index, sample in ipairs(data.kfs) do
        assert(type(sample.t) == "number" and sample.t > previousTime, "Keyframes must be ordered")
        previousTime = sample.t
        local keyframe = Instance.new("Keyframe")
        keyframe.Name = index == 1 and "Start" or index == #data.kfs and "End" or string.format("Frame%03d", index)
        keyframe.Time = sample.t
        local poses = {}
        for _, name in ipairs(names) do
            local entry = assert(sample.kf[name], "Missing R6 pose " .. name)
            local components = entry[1]
            assert(#components == 12, "Invalid CFrame component count")
            for _, value in ipairs(components) do
                assert(type(value) == "number" and value == value and math.abs(value) < 100, "Invalid pose component")
            end
            local pose = Instance.new("Pose")
            pose.Name = name
            pose.CFrame = CFrame.new(table.unpack(components))
            pose.Weight = name == "HumanoidRootPart" and 0 or 1
            pose.EasingStyle = Enum.PoseEasingStyle.Linear
            pose.EasingDirection = Enum.PoseEasingDirection.Out
            pose.Parent = parentNames[name] and poses[parentNames[name]] or keyframe
            poses[name] = pose
        end
        if spec.name == "RockLiiTriplePunch" then
            for hit, time in ipairs({8 / 30, 19 / 30, 32 / 30}) do
                if math.abs(sample.t - time) < 0.00001 then
                    local marker = Instance.new("KeyframeMarker")
                    marker.Name = "Hit"
                    marker.Value = tostring(hit)
                    marker.Parent = keyframe
                end
            end
        end
        keyframe.Parent = sequence
    end
    table.insert(staged, sequence)
end
local folder = ServerStorage:FindFirstChild("RockLiiAnimationExports")
if folder then
    assert(folder:GetAttribute("ExportOwner") == "RockLiiReviewed20260929", "Existing animation export folder belongs to other work")
else
    folder = Instance.new("Folder")
    folder.Name = "RockLiiAnimationExports"
    folder:SetAttribute("ExportOwner", "RockLiiReviewed20260929")
    folder.Parent = ServerStorage
end
local imported = {}
for _, sequence in ipairs(staged) do
    local old = folder:FindFirstChild(sequence.Name)
    if old and old:GetAttribute("PublishedAssetId") then
        sequence:Destroy()
        table.insert(imported, {name = old.Name, skippedPublished = true, assetId = old:GetAttribute("PublishedAssetId")})
    else
        if old then
            local archive = folder:FindFirstChild("EarlierStaged") or Instance.new("Folder")
            archive.Name = "EarlierStaged"
            archive.Parent = folder
            old.Parent = archive
        end
        sequence.Parent = folder
        table.insert(imported, {name = sequence.Name, frames = #sequence:GetKeyframes(), duration = sequence:GetAttribute("Duration")})
    end
end
return imported
