assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local library = assert(RS:FindFirstChild("PlaygroundCosmeticAssets"))
local knownNames, knownIds = {}, {}
for _, model in ipairs(library:GetChildren()) do
	if model:IsA("Model") then
		knownNames[model.Name] = true
		local originalName = model:GetAttribute("OriginalModelName")
		if originalName then knownNames[originalName] = true end
		knownIds[model.Name] = true
	end
end
local function isNew(model)
	local id = model:GetAttribute("CatalogId") or model.Name:match("^([BMPbmp]%d%d)")
	if not id then return false end
	id = id:upper()
	local n = tonumber(id:sub(2))
	return n and ((id:sub(1, 1) == "P" and n >= 21 and n <= 35) or ((id:sub(1, 1) == "B" or id:sub(1, 1) == "M") and n >= 16 and n <= 25))
end
local function record(model, outline)
	local archive = SS:FindFirstChild("PlaygroundStyledSourceAssets20261007")
	local black = isNew(model) and (model:IsDescendantOf(library) or model:IsDescendantOf(workspace) or (archive and model:IsDescendantOf(archive)))
	model:SetAttribute("PCOutlineStored", true)
	model:SetAttribute("PCOutlineEnabled", outline.Enabled)
	model:SetAttribute("PCOutlineColor", black and Color3.new(0, 0, 0) or outline.OutlineColor)
	model:SetAttribute("PCOutlineTransparency", outline.OutlineTransparency)
	model:SetAttribute("PCOutlineFillColor", outline.FillColor)
	model:SetAttribute("PCOutlineFillTransparency", outline.FillTransparency)
	model:SetAttribute("PCOutlineDepthMode", outline.DepthMode.Name)
end
local report = {stored = {}, updatedWorld = {}, countBefore = 0, countAfter = 0, libraryIds = {}}
for _, object in ipairs(game:GetDescendants()) do if object:IsA("Highlight") then report.countBefore += 1 end end
for _, service in ipairs({ RS, SS }) do
	for _, outline in ipairs(service:GetDescendants()) do
		if outline:IsA("Highlight") and outline.Name == "CartoonOutline" and outline.Parent:IsA("Model") then
			local model = outline.Parent
			table.insert(report.stored, {path = outline:GetFullName(), color = tostring(outline.OutlineColor), enabled = outline.Enabled})
			record(model, outline)
			outline:Destroy()
		end
	end
end
for _, model in ipairs(workspace:GetDescendants()) do
	if model:IsA("Model") then
		local id = model:GetAttribute("CatalogId") or model.Name:match("^([BMPbmp]%d%d)")
		local known = knownNames[model.Name] or (id and knownIds[id:upper()])
		local outline = model:FindFirstChild("CartoonOutline")
		if known and outline and outline:IsA("Highlight") then
			record(model, outline)
			outline.OutlineColor = model:GetAttribute("PCOutlineColor")
			outline:SetAttribute("PCCosmeticManaged", true)
			table.insert(report.updatedWorld, model:GetFullName())
		end
	end
end
for _, range in ipairs({ {"B", 16, 25}, {"M", 16, 25}, {"P", 21, 35} }) do
	for n = range[2], range[3] do
		local id = string.format("%s%02d", range[1], n)
		local model = assert(library:FindFirstChild(id))
		assert(model:GetAttribute("PCOutlineStored") == true)
		assert(model:GetAttribute("PCOutlineColor") == Color3.new(0, 0, 0))
		assert(not model:FindFirstChildOfClass("Highlight"))
		table.insert(report.libraryIds, id)
	end
end
for _, object in ipairs(game:GetDescendants()) do if object:IsA("Highlight") then report.countAfter += 1 end end
return game.HttpService:JSONEncode(report)
