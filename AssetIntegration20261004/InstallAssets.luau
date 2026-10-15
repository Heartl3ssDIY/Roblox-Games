local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local backup = SS:FindFirstChild("AssetIntegrationBackup20261004")
if not backup then backup = Instance.new("Folder"); backup.Name = "AssetIntegrationBackup20261004"; backup.Parent = SS end
local importedBackup = backup:FindFirstChild("ImportedModels")
if not importedBackup then importedBackup = Instance.new("Folder"); importedBackup.Name = "ImportedModels"; importedBackup.Parent = backup end
local assets = RS:WaitForChild("PlaygroundCosmeticAssets")
local variant = game.MaterialService:FindFirstChild("PlaygroundItemStuds")
if not variant then variant = game.MaterialService.PlaygroundRetroStuds:Clone(); variant.Name = "PlaygroundItemStuds"; variant.Parent = game.MaterialService end
variant.StudsPerTile = 0.26
local ink = Color3.fromRGB(24, 35, 62)
local sources = {}
for _,model in workspace:GetDescendants() do
	if model:IsA("Model") and (model.Name:match("^[bpmc]%d%d%-") or model.Name == "MudGun" or model.Name == "HeatGun") then table.insert(sources, model) end
end
local function save(model)
	if not importedBackup:FindFirstChild(model.Name) then local copy = model:Clone(); copy.Parent = importedBackup end
end
local function gunColour(part, heat)
	local n = part.Name
	local dark = n:find("Grip") or n:find("Bumper") or n:find("Frame") or n:find("Vent") or n:find("Mouth") or n:find("Foot") or n:find("Hose")
	if dark then return ink end
	if n:find("Badge") or n:find("Ray") or n:find("Bolt") or n:find("Knob") or n:find("Detail") or n:find("Rib") or n:find("Accent") then
		return heat and Color3.fromRGB(255,218,91) or Color3.fromRGB(119,201,103)
	end
	if n:find("Plaque") or n:find("CoilCap") or n:find("Neck") or n:find("Nozzle_Rim") then return Color3.fromRGB(255,238,199) end
	if n:find("WarmCore") then return Color3.fromRGB(255,207,74) end
	if n:find("WarmCoil") then return Color3.fromRGB(244,116,36) end
	if n:find("MudDrip") or n:find("Tank") then return Color3.fromRGB(114,74,40) end
	if n:find("PressButton") then return heat and Color3.fromRGB(245,81,55) or Color3.fromRGB(126,204,91) end
	return heat and Color3.fromRGB(243,136,45) or Color3.fromRGB(168,110,57)
end
local function style(model, gun)
	for _,part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("PCStudLayer") ~= true then
			part.Anchored = true
			part.Locked = true
			if part.Transparency < 1 then
				part.Material = Enum.Material.SmoothPlastic
				if gun then part.Color = gunColour(part, model.Name == "HeatGun"); part.MaterialVariant = "PlaygroundItemStuds" end
				if part:IsA("MeshPart") and part.TextureID ~= "" and not part:FindFirstChild("PCStudFinish") then
					local coat = part:Clone()
					coat:ClearAllChildren()
					coat.Name = "PCStudFinish"
					coat:SetAttribute("PCStudLayer", true)
					coat.TextureID = ""
					coat.Color = Color3.new(0.65, 0.65, 0.65)
					coat.MaterialVariant = "PlaygroundItemStuds"
					coat.Transparency = 0.68
					coat.Size = part.Size + Vector3.new(0.012, 0.012, 0.012)
					coat.CFrame = part.CFrame
					coat.CanCollide = false
					coat.CanTouch = false
					coat.CanQuery = false
					coat.Massless = true
					coat.CastShadow = false
					coat.Parent = part
					local weld = Instance.new("WeldConstraint")
					weld.Name = "StudFinishWeld"
					weld.Part0 = part
					weld.Part1 = coat
					weld.Parent = coat
				elseif not part:IsA("MeshPart") then part.MaterialVariant = "PlaygroundItemStuds" end
			end
		end
	end
	local outline = model:FindFirstChild("CartoonOutline")
	if not outline then outline = Instance.new("Highlight"); outline.Name = "CartoonOutline"; outline.Parent = model end
	outline.Adornee = model
	outline.FillTransparency = 1
	outline.OutlineTransparency = 0
	outline.OutlineColor = ink
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	model:SetAttribute("PCArtVersion", 1)
end
local count = 0
for _,model in sources do
	save(model)
	local gun = model.Name == "MudGun" or model.Name == "HeatGun"
	style(model, gun)
	local id = model.Name:match("^([bpmc]%d%d)%-")
	if id then
		id = id:upper()
		local previous = assets:FindFirstChild(id)
		if previous then assert(previous:GetAttribute("PCImported") == true, "Asset name conflict " .. id); previous:Destroy() end
		local clone = model:Clone()
		clone.Name = id
		clone:SetAttribute("PCImported", true)
		clone:SetAttribute("OriginalModelName", model.Name)
		clone:SetAttribute("CatalogId", id)
		for _,part in clone:GetDescendants() do if part:IsA("BasePart") then part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true end end
		clone.Parent = assets
		count += 1
	end
end
for _,name in {"MudGun", "HeatGun"} do
	local old = RS.MudAssets:FindFirstChild(name)
	if not backup:FindFirstChild("Original" .. name) then local copy = old:Clone(); copy.Name = "Original" .. name; copy.Parent = backup end
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = name == "MudGun" and "Splat opponents with mud" or "Warm and free your teammate"
	tool.Grip = old.Grip
	for key, value in old:GetAttributes() do tool:SetAttribute(key, value) end
	tool:SetAttribute("TemplateVersion", 2)
	local handle = old.Handle:Clone()
	for _,child in handle:GetChildren() do if not child:IsA("Attachment") then child:Destroy() end end
	handle.Transparency = 1
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.identity
	handle.Parent = tool
	local art = workspace[name]:Clone()
	art.Name = "ImportedArtwork"
	art:PivotTo(CFrame.Angles(0, math.pi, 0))
	for _,object in art:GetDescendants() do
		if object:IsA("JointInstance") or object:IsA("WeldConstraint") then object:Destroy() end
	end
	for _,part in art:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
			local weld = Instance.new("WeldConstraint"); weld.Part0 = handle; weld.Part1 = part; weld.Parent = part
		end
	end
	art.Parent = tool
	old:Destroy()
	tool.Parent = RS.MudAssets
end
local locked = 0
for _,part in workspace["Playground Lobby"]:GetDescendants() do if part:IsA("BasePart") then
	if part:GetAttribute("PCBeforeLocked") == nil then part:SetAttribute("PCBeforeLocked", part.Locked); part:SetAttribute("PCBeforeAnchored", part.Anchored) end
	part.Anchored = true; part.Locked = true; locked += 1
end end
local loose = workspace:FindFirstChild("Part")
if loose and loose:IsA("BasePart") then loose:SetAttribute("PCBeforeAnchored", loose.Anchored); loose:SetAttribute("PCBeforeLocked", loose.Locked); loose.Anchored = true; loose.Locked = true end
return {assets = count, importedModels = #sources, lobbyPartsLocked = locked, guns = 2}
