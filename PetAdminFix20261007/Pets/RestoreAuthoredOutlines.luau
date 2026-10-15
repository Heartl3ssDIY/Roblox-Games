assert(not game.RunService:IsRunning())
local restored=0
for _,model in workspace:GetDescendants() do
 if model.ClassName=="Model" and model:GetAttribute("PCOutlineStored")==true and not model:FindFirstChild("CartoonOutline") then
  local outline=Instance.new("Highlight")
  outline.Name="CartoonOutline"
  outline:SetAttribute("PCCosmeticManaged",true)
  outline.Adornee=model
  outline.Enabled=model:GetAttribute("PCOutlineEnabled")~=false
  outline.FillColor=assert(model:GetAttribute("PCOutlineFillColor"))
  outline.FillTransparency=assert(model:GetAttribute("PCOutlineFillTransparency"))
  outline.OutlineColor=assert(model:GetAttribute("PCOutlineColor"))
  outline.OutlineTransparency=assert(model:GetAttribute("PCOutlineTransparency"))
  outline.DepthMode=Enum.HighlightDepthMode[assert(model:GetAttribute("PCOutlineDepthMode"))]
  outline.Parent=model
  restored+=1
 end
end
local verified,highlights=0,0
for _,model in workspace:GetDescendants() do
 if model:IsA("Highlight") then highlights+=1 end
 if model.ClassName=="Model" and model:GetAttribute("PCOutlineStored")==true then
  local outline=assert(model:FindFirstChild("CartoonOutline"))
  assert(outline.Adornee==model)
  assert(outline.Enabled==(model:GetAttribute("PCOutlineEnabled")~=false))
  assert(outline.FillColor==model:GetAttribute("PCOutlineFillColor"))
  assert(outline.FillTransparency==model:GetAttribute("PCOutlineFillTransparency"))
  assert(outline.OutlineColor==model:GetAttribute("PCOutlineColor"))
  assert(outline.OutlineTransparency==model:GetAttribute("PCOutlineTransparency"))
  assert(outline.DepthMode.Name==model:GetAttribute("PCOutlineDepthMode"))
  verified+=1
 end
end
return game.HttpService:JSONEncode({restored=restored,verified=verified,workspaceHighlights=highlights,Play=game.RunService:IsRunning()})
