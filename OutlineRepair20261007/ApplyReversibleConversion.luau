assert(not game.RunService:IsRunning(), "Edit mode required")
local SS, RS = game.ServerStorage, game.ReplicatedStorage
local backup = assert(SS:FindFirstChild("OutlinePropertyBackup20261007"))
assert(backup:GetAttribute("RoundTripVerified") == true and #backup:GetChildren() == 149)
local library = assert(RS:FindFirstChild("PlaygroundCosmeticAssets"))
local archive = assert(SS:FindFirstChild("PlaygroundStyledSourceAssets20261007"))
local function newItem(model)
	local id = model:GetAttribute("CatalogId") or model.Name:match("^([BMPbmp]%d%d)")
	if not id then return false end
	id=id:upper()
	local n=tonumber(id:sub(2))
	return n and ((id:sub(1,1)=="P" and n>=21 and n<=35) or ((id:sub(1,1)=="B" or id:sub(1,1)=="M") and n>=16 and n<=25))
end
local function describe(model, h)
	local black=newItem(model) and (model:IsDescendantOf(library) or model:IsDescendantOf(workspace) or model:IsDescendantOf(archive))
	model:SetAttribute("PCOutlineStored",true)
	model:SetAttribute("PCOutlineEnabled",h.Enabled)
	model:SetAttribute("PCOutlineColor",black and Color3.new(0,0,0) or h.OutlineColor)
	model:SetAttribute("PCOutlineTransparency",h.OutlineTransparency)
	model:SetAttribute("PCOutlineFillColor",h.FillColor)
	model:SetAttribute("PCOutlineFillTransparency",h.FillTransparency)
	model:SetAttribute("PCOutlineDepthMode",h.DepthMode.Name)
end
local targets={}
for _,record in ipairs(backup:GetChildren()) do
	local owner=assert(record.Owner.Value)
	local h=assert(owner:FindFirstChild(record:GetAttribute("OriginalName")))
	assert(h:IsA("Highlight") and h:GetFullName()==record:GetAttribute("OriginalPath") and h.Adornee==owner)
	assert(owner:IsDescendantOf(SS) or (owner.Parent==library and newItem(owner)),"Outside approved conversion scope")
	for _,key in ipairs({"Enabled","FillColor","FillTransparency","OutlineColor","OutlineTransparency"}) do assert(h[key]==record:GetAttribute(key),"Outline changed since backup") end
	table.insert(targets,{owner=owner,highlight=h})
end
local known={}
for _,model in ipairs(library:GetChildren()) do
	if model:IsA("Model") then
		known[model.Name]=true
		local h=model:FindFirstChild("CartoonOutline")
		if h and h:IsA("Highlight") then describe(model,h) end
	end
end
local world=0
for _,model in ipairs(workspace:GetDescendants()) do
	if model:IsA("Model") then
		local id=model:GetAttribute("CatalogId") or model.Name:match("^([BMPbmp]%d%d)")
		if id and known[id:upper()] then
			local h=model:FindFirstChild("CartoonOutline")
			if h and h:IsA("Highlight") then
				describe(model,h)
				h.OutlineColor=model:GetAttribute("PCOutlineColor")
				h:SetAttribute("PCCosmeticManaged",true)
				world+=1
			end
		end
	end
end
for _,target in ipairs(targets) do
	describe(target.owner,target.highlight)
	target.highlight:Destroy()
end
local total,workspaceCount,oldTemplates=0,0,0
for _,h in ipairs(game:GetDescendants()) do if h:IsA("Highlight") then total+=1 if h:IsDescendantOf(workspace) then workspaceCount+=1 end end end
for _,h in ipairs(library:GetDescendants()) do if h:IsA("Highlight") then oldTemplates+=1 end end
assert(oldTemplates==51,"Old library template outlines must remain intact")
assert(total<255,"Highlight budget still exhausted")
backup:SetAttribute("ConvertedCount",#targets)
return game.HttpService:JSONEncode({converted=#targets,originalPropertiesBackedUp=true,oldTemplatesIntact=oldTemplates,worldCosmetics=world,workspaceHighlights=workspaceCount,totalHighlights=total})
