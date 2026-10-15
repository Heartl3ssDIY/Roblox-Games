-- PackageService: parcel spawning, value and damage.
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local PackageConfig = require(RS.Configs.PackageConfig)
local CompanyConfig = require(RS.Configs.CompanyConfig)

local PackageService = {}
local SIZE_DIMS = {Small = 1.3, Medium = 1.9, Large = 2.6}
-- Paste a crack/break SoundId here to give breakages audio (leave "" for silent).
local BREAK_SOUND_ID = ""

local ServerStorage = game:GetService("ServerStorage")
local PARCEL_DIMS = {
 Small = Vector3.new(1.53, 0.78, 1.15),
 Medium = Vector3.new(1.94, 1.51, 1.61),
 Large = Vector3.new(2.28, 2.65, 1.96),
}

local function damageVisual(part)
 local visual = part:FindFirstChild("ParcelVisual")
 if not visual then return end
 for _,p in visual:GetChildren() do
  if p:IsA("BasePart") then
   p.Color = Color3.new(p.Color.R * 0.55, p.Color.G * 0.55, p.Color.B * 0.55)
   p.Material = Enum.Material.Cardboard
   p.Reflectance = 0
  end
 end
end

local function dressPackage(part)
 local templates = ServerStorage:FindFirstChild("ParcelModels")
 local rarity = part:GetAttribute("Rarity")
 local name = rarity ~= "Regular" and rarity or (part:GetAttribute("Fragile") and "Fragile" or part:GetAttribute("Size"))
 local template = templates and templates:FindFirstChild(name)
 if not template then return end
 local old = part:FindFirstChild("ParcelVisual")
 if old then old:Destroy() end
 local visual = Instance.new("Folder")
 visual.Name = "ParcelVisual"
 local centre, size = template:GetBoundingBox()
 local scale = part.Size / size
 for _,source in template:GetDescendants() do
  if source:IsA("BasePart") then
   local p = source:Clone()
   local relative = centre:ToObjectSpace(source.CFrame)
   local offset = CFrame.new(relative.Position * scale) * relative.Rotation
   p.Size = source.Size * scale
   p.CFrame = part.CFrame * offset
   p.Anchored = false
   p.Massless = true
   p.CanCollide = false
   p.CanTouch = false
   p.CanQuery = false
   local joint = Instance.new("Motor6D")
   joint.Name = "ParcelJoint"
   joint.Part0 = part
   joint.Part1 = p
   joint.C0 = offset
   joint.Parent = p
   p.Parent = visual
  end
 end
 visual.Parent = part
 part.Transparency = 1
 part:SetAttribute("RigMarker", true)
 part.CustomPhysicalProperties = PhysicalProperties.new(0.55, 0.65, 0.12, 100, 100)
 if part:GetAttribute("Damaged") then damageVisual(part) end
end

function PackageService.create(company, luckMult)
	local roll = PackageConfig.roll(luckMult)
	local dim = SIZE_DIMS[roll.size] or 1.6
	local rdef = PackageConfig.Rarities[roll.rarity]

	local p = Instance.new("Part")
	p.Name = "Package"
	p.Anchored = true
	p.CanCollide = false  -- decorative/grabbable; never push or launch the player or workers
	p.Size = PARCEL_DIMS[roll.size] or Vector3.new(dim, dim, dim)
	p.Color = rdef.color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if roll.rarity == "Gold" then
		p.Material = Enum.Material.Metal
	elseif roll.rarity == "Rainbow" then
		p.Material = Enum.Material.Neon
	else
		p.Material = Enum.Material.Cardboard
	end

	-- gameplay attributes
	p:SetAttribute("Company", company)
	p:SetAttribute("Size", roll.size)
	p:SetAttribute("Rarity", roll.rarity)
	p:SetAttribute("Fragile", roll.fragile)
	p:SetAttribute("Damaged", false)
	local comp = CompanyConfig.get(company)
	local base = comp and comp.base[roll.size] or nil
	p:SetAttribute("CompanyTier", comp and comp.tier or "Small")
	p:SetAttribute("Value", PackageConfig.computeValue(roll, base))

	-- glow for Gold / Rainbow
	if roll.rarity ~= "Regular" then
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.55
		h.FillColor = rdef.color
		h.OutlineColor = rdef.color
		h.Parent = p
	end

	-- fragile marker: subtle red outline (the stuck-on FRAGILE sticker is added by dressPackage below)
	if roll.fragile then
		local sb = Instance.new("SelectionBox")
		sb.Adornee = p; sb.Color3 = Color3.fromRGB(235,60,60); sb.LineThickness = 0.04; sb.Transparency = 0.2; sb.Parent = p
	end

	-- The collision part stays separate from the imported parcel surfaces.
	dressPackage(p)

	-- Floating "Pick Up" prompt (like the office terminal) so a player can target & grab a SPECIFIC
	-- parcel even though staged parcels are solid now. Enabled while staged; toggled off when the
	-- parcel leaves staging (carried/loaded) and back on when restaged (handled in TruckService).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabParcel"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = tostring(company)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = p

	return p
end

-- Mark a package damaged (employee break logic): recomputes its Value and gives it an
-- unmistakable "damaged" look so the loss is readable at a glance.
function PackageService.markDamaged(part)
	if not part or part:GetAttribute("Damaged") then return end
	part:SetAttribute("Damaged", true)
	local pkg = {
		size = part:GetAttribute("Size"), rarity = part:GetAttribute("Rarity"),
		fragile = part:GetAttribute("Fragile"), damaged = true,
	}
	local comp = CompanyConfig.get(part:GetAttribute("Company"))
	local base = comp and comp.base[pkg.size] or nil
	part:SetAttribute("Value", PackageConfig.computeValue(pkg, base))
	-- damaged look: darken, dull the surface, recolor the fragile tag to a grey "DAMAGED"
	part.Transparency = part:FindFirstChild("ParcelVisual") and 1 or 0.2
	damageVisual(part)
	part.Color = Color3.new(part.Color.R*0.55, part.Color.G*0.55, part.Color.B*0.55)
	part.Material = Enum.Material.Cardboard
	local sb = part:FindFirstChildOfClass("SelectionBox")
	if sb then sb.Color3 = Color3.fromRGB(120,120,125) end
	local bb = part:FindFirstChildOfClass("BillboardGui")
	local lbl = bb and bb:FindFirstChildOfClass("TextLabel")
	if lbl then lbl.Text = "DAMAGED"; lbl.TextColor3 = Color3.fromRGB(185,185,190) end
end

-- One-shot break feedback: a debris puff, a quick squash, and an optional crack sound.
-- Purely cosmetic -- markDamaged already handled the value drop and damaged look.
function PackageService.breakEffect(part)
	if not part or not part.Parent then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Color = ColorSequence.new(part.Color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, part.Size.X*0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	emitter:Emit(14)
	Debris:AddItem(emitter, 1)

	local visual = part:FindFirstChild("ParcelVisual")
 local squash = Vector3.new(1.15, 0.7, 1.15)
 local targets = {}
 if visual then
  for _,p in visual:GetChildren() do
   if p:IsA("BasePart") then
    local joint = p:FindFirstChild("ParcelJoint")
    table.insert(targets, {part=p, size=p.Size, joint=joint, offset=joint and joint.C0})
   end
  end
 else
  table.insert(targets, {part=part, size=part.Size})
 end
 for _,item in targets do
  TweenService:Create(item.part, TweenInfo.new(0.08), {Size=item.size*squash}):Play()
  if item.joint then
   TweenService:Create(item.joint, TweenInfo.new(0.08), {C0=CFrame.new(item.offset.Position*squash)*item.offset.Rotation}):Play()
  end
 end
 task.delay(0.09, function()
  for _,item in targets do
   if item.part.Parent then
    TweenService:Create(item.part, TweenInfo.new(0.12), {Size=item.size}):Play()
    if item.joint and item.joint.Parent then
     TweenService:Create(item.joint, TweenInfo.new(0.12), {C0=item.offset}):Play()
    end
   end
  end
 end)

	if BREAK_SOUND_ID ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = BREAK_SOUND_ID; s.Volume = 0.6; s.RollOffMaxDistance = 60; s.Parent = part
		s:Play(); Debris:AddItem(s, 2)
	end
end

-- Re-route a staged package to a different company (used to balance bay supply) + recompute value.
function PackageService.reassignCompany(part, company)
	if not part or part:GetAttribute("Company") == company then return end
	part:SetAttribute("Company", company)
	local comp = CompanyConfig.get(company)
	part:SetAttribute("CompanyTier", comp and comp.tier or "Small")
	local base = comp and comp.base[part:GetAttribute("Size")] or nil
	part:SetAttribute("Value", PackageConfig.computeValue({
		size = part:GetAttribute("Size"), rarity = part:GetAttribute("Rarity"),
		fragile = part:GetAttribute("Fragile"), damaged = part:GetAttribute("Damaged"),
	}, base))
end

-- Upgrade a package's rarity (Golden/Rainbow worker conversion) and recompute its value + look.
function PackageService.setRarity(part, newRarity)
	local def = PackageConfig.Rarities[newRarity]; if not def then return end
	part:SetAttribute("Rarity", newRarity)
	part.Color = def.color
	dressPackage(part)
	part.Material = (newRarity=="Gold" and Enum.Material.Metal) or (newRarity=="Rainbow" and Enum.Material.Neon) or part.Material
	local h = part:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
	h.FillTransparency=0.5; h.FillColor=def.color; h.OutlineColor=def.color; h.Parent=part
	local comp=CompanyConfig.get(part:GetAttribute("Company"))
	local base=comp and comp.base[part:GetAttribute("Size")] or nil
	part:SetAttribute("Value", PackageConfig.computeValue({
		size=part:GetAttribute("Size"), rarity=newRarity,
		fragile=part:GetAttribute("Fragile"), damaged=part:GetAttribute("Damaged"),
	}, base))
end

return PackageService
