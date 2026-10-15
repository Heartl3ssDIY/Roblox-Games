local module=game.ServerScriptService.HideAndSeekService:Clone()
module.Name="SchoolPropInstalledAssetCheck20261011" module.Parent=game.ServerStorage
local fixture=Instance.new("Folder") fixture.Name="SchoolPropInstalledAssetCheck20261011" fixture.Parent=game.ServerStorage
local count=0
local ok,err=xpcall(function()
 local Service=require(module)
 local state=Instance.new("Folder") state.Parent=fixture
 local service=Service.new(workspace["Hide and Seek"],state)
 local templates=service:_propTemplates()
 assert(#templates==13,"Actual eligible template count")
 for index,template in templates do
  local player=Instance.new("Folder") player.Parent=fixture
  local character=Instance.new("Model") character.Parent=fixture
  local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Size=Vector3.new(2,2,1) root.CFrame=CFrame.new(0,3,0) root.Anchored=true root.Transparency=.2 root.Parent=character
  local originalTransparency=root.Transparency
  local head=Instance.new("Part") head.Name="Head" head.Size=Vector3.new(2,1,1) head.CFrame=CFrame.new(0,4.5,0) head.Parent=character
  local leg=Instance.new("Part") leg.Name="Left Leg" leg.Size=Vector3.new(1,2,1) leg.CFrame=CFrame.new(-.5,1,0) leg.Parent=character
  local humanoid=Instance.new("Humanoid") humanoid.Parent=character
  local record={player=player,character=character,root=root,humanoid=humanoid,role="Hider",participating=true,ready=true}
  service.random={NextInteger=function()return index end}
  assert(service:_applyPropMorph(record),"Morph failed "..template.Name)
  local morph=record.propMorph.model
  assert(player:GetAttribute("HSPropId")==template.Name and root.Transparency==1 and head.Transparency==1,"Conceal failed")
  local cf,size=morph:GetBoundingBox()
  assert(math.abs(cf.Position.Y-size.Y/2)<.03,"Floor alignment "..template.Name.." "..tostring(cf.Position.Y-size.Y/2))
  for _,p in morph:GetDescendants() do if p:IsA("BasePart") then assert(not p.Anchored and not p.CanCollide and p.Massless and p:FindFirstChild("SchoolPropWeld"),"Unsafe morph part") end end
  service:_restorePropMorph(record)
  assert(root.Transparency==originalTransparency and head.Transparency==0 and not character:FindFirstChild("SchoolPropMorph"),"Avatar restore failed")
  count+=1
  character:Destroy() player:Destroy()
 end
end,debug.traceback)
fixture:Destroy() module:Destroy()
assert(ok,err)
return {passed=true,actualTemplatesTested=count}
