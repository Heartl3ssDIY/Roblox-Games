local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local small = workspace:FindFirstChild("VIP-Dragon-Rigged")
local display = workspace:FindFirstChild("VIP-Dragon-Rigged-display")
assert(small and display, "Both imported dragons must be present")
local assets = RS:WaitForChild("PlaygroundCosmeticAssets")
assert(not assets:FindFirstChild("P36"), "P36 already exists")
assert(not SS:FindFirstChild("VIPDragonBackup20261007"), "Backup already exists; inspect before reinstalling")
local originalDisplayPivot, originalDisplayScale = display:GetPivot(), display:GetScale()
local backup = Instance.new("Folder")
backup.Name = "VIPDragonBackup20261007"
backup.Parent = SS
for _, model in {small, display} do
	local copy = model:Clone()
	for _, child in copy:GetDescendants() do
		if child:IsA("Highlight") then child:Destroy() end
	end
	copy.Parent = backup
end
local material = game.MaterialService:FindFirstChild("PlaygroundItemStuds")
assert(material and material:IsA("MaterialVariant"), "Missing shared stud finish")
local largeMaterial = material:Clone()
largeMaterial.Name = "PlaygroundVIPDisplayStuds"
largeMaterial.StudsPerTile = material.StudsPerTile * originalDisplayScale
largeMaterial.Parent = game.MaterialService

local animationRoot = RS:FindFirstChild("PlaygroundPetAnimations")
if not animationRoot then
	animationRoot = Instance.new("Folder")
	animationRoot.Name = "PlaygroundPetAnimations"
	animationRoot.Parent = RS
end
assert(not animationRoot:FindFirstChild("VIPDragon"), "VIP clips already installed")
local clips = Instance.new("Folder")
clips.Name = "VIPDragon"
clips:SetAttribute("ReferenceScale", small:GetScale())
clips.Parent = animationRoot
local boneNames = {}
for _, bone in small.RootPart:GetDescendants() do
	if bone:IsA("Bone") then boneNames[bone.Name] = true end
end
local saved = {}
for _, sequence in SS:GetDescendants() do
	if not sequence:IsA("KeyframeSequence") then continue end
	local name = sequence.Name:find("VIP%-Dragon%-Hover") and "Idle"
		or sequence.Name:find("VIP%-Dragon%-Fly") and "Fly"
	if not name or saved[name] then continue end
	local clip = Instance.new("KeyframeSequence")
	clip.Name = name
	clip.Loop = true
	clip.Priority = Enum.AnimationPriority.Idle
	clip:SetAttribute("SourceSequence", sequence.Name)
	clip:SetAttribute("NormalizedBoneTransforms", true)
	local count = 0
	for _, keyframe in sequence:GetKeyframes() do
		local frame = Instance.new("Keyframe")
		frame.Time = keyframe.Time
		frame.Name = keyframe.Name
		frame.Parent = clip
		for _, pose in keyframe:GetDescendants() do
			if not pose:IsA("Pose") or not boneNames[pose.Name] then continue end
			local initial = small.InitialPoses:FindFirstChild(pose.Name .. "_Initial")
			assert(initial and initial:IsA("CFrameValue"), "Missing original pose for " .. pose.Name)
			local normalized = Instance.new("Pose")
			normalized.Name = pose.Name
			normalized.CFrame = initial.Value.Rotation:Inverse() * pose.CFrame
			normalized.Weight = pose.Weight
			normalized.EasingStyle = Enum.PoseEasingStyle.Linear
			normalized.Parent = frame
			count += 1
		end
	end
	assert(count > 300, "Incomplete imported animation")
	clip.Parent = clips
	saved[name] = true
end
assert(saved.Idle and saved.Fly, "Both authored flight clips are required")

local function style(model, isDisplay)
	local scale = model:GetScale()
	local originals = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Locked = true
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
			if object:IsA("MeshPart") and object.Transparency < 1 then table.insert(originals, object) end
		elseif object:IsA("Bone") then
			object.Transform = CFrame.identity
		end
	end
	assert(#originals == 8, "Unexpected imported mesh count")
	for _, part in originals do
		part.Material = Enum.Material.SmoothPlastic
		part.MaterialVariant = ""
		local coat = part:Clone()
		coat:ClearAllChildren()
		coat.Name = "PCStudFinish"
		coat:SetAttribute("PCStudLayer", true)
		coat.TextureID = ""
		coat.Color = Color3.fromRGB(166, 166, 166)
		coat.MaterialVariant = isDisplay and largeMaterial.Name or material.Name
		coat.Transparency = 0.68
		coat.Size = part.Size + Vector3.one * 0.006 * scale
		coat.CFrame = part.CFrame
		coat.CastShadow = false
		coat.Parent = part
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = part, coat
		weld.Parent = coat
	end
	model:SetAttribute("PCPetClipSet", "VIPDragon")
	model:SetAttribute("PCOutlineStored", true)
	model:SetAttribute("PCOutlineEnabled", true)
	model:SetAttribute("PCOutlineColor", Color3.new(0, 0, 0))
	model:SetAttribute("PCOutlineTransparency", 0)
	model:SetAttribute("PCOutlineFillTransparency", 1)
	model:SetAttribute("PCOutlineFillColor", Color3.new(0, 0, 0))
	model:SetAttribute("PCOutlineDepthMode", "Occluded")
	model:SetAttribute("PCDisplayPet", isDisplay)
	if isDisplay then
		local outline = model:FindFirstChild("CartoonOutline") or Instance.new("Highlight")
		outline.Name = "CartoonOutline"
		outline.Adornee = model
		outline.FillTransparency = 1
		outline.OutlineTransparency = 0
		outline.OutlineColor = Color3.new(0, 0, 0)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline:SetAttribute("PCCosmeticManaged", true)
		outline.Parent = model
	end
end
style(small, false)
style(display, true)
small.Name = "P36"
small:SetAttribute("CatalogId", "P36")
small:SetAttribute("DisplayName", "VIP Royal Dragon")
small:SetAttribute("PetFacingYaw", 0)
small:SetAttribute("PCPetHoverHeight", 1.15)
small:SetAttribute("PCVIPExclusive", true)
small:PivotTo(CFrame.identity)
small.Parent = assets
assert(display:GetPivot() == originalDisplayPivot, "Display position changed")
assert(display:GetScale() == originalDisplayScale, "Display size changed")
return {pet = small:GetFullName(), displayScale = display:GetScale(), meshes = 8, studLayers = 8, bones = 14, clips = {"Idle", "Fly"}}

