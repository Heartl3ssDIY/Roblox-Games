assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local RS,SS=game.ReplicatedStorage,game.ServerStorage
local assets=assert(RS:FindFirstChild("PlaygroundCosmeticAssets"))
local saved=assert(SS:FindFirstChild("ExpansionFinishBackup20261007"))
local archive=SS:FindFirstChild("PlaygroundStyledSourceAssets20261007")
assert(not archive,"Archive already exists; review before rerunning")
local plans={}
for _,group in ipairs({{"Bats","B",16,25},{"Toys and misc items","M",16,25},{"Pets2","P",21,35}}) do
 local folder=assert(workspace:FindFirstChild(group[1]))
 for n=group[3],group[4] do
  local id=string.format("%s%02d",group[2],n)
  local library=assert(assets:FindFirstChild(id))
  assert(library:IsA("Model") and library:GetAttribute("CatalogId")==id and library:GetAttribute("PCExpansionVersion")==20261007)
  local originalName=assert(library:GetAttribute("OriginalModelName"))
  local source=assert(folder:FindFirstChild(originalName))
  local original=assert(saved:FindFirstChild(id))
  assert(source:IsA("Model") and source:GetAttribute("PCArtVersion")==1)
  assert(source:GetFullName()==original:GetAttribute("OriginalPath"))
  assert(source:GetPivot()==original:GetPivot(),"Source placement changed since backup: "..id)
  table.insert(plans,{id=id,source=source,pivot=source:GetPivot(),path=source:GetFullName(),parent=folder,library=library})
 end
end
assert(#plans==35)
archive=Instance.new("Folder")
archive.Name="PlaygroundStyledSourceAssets20261007"
archive:SetAttribute("Purpose","Styled expansion source archive; equippable models are in ReplicatedStorage.PlaygroundCosmeticAssets")
archive.Parent=SS
local moved={}
for _,plan in ipairs(plans) do
 plan.source:SetAttribute("ArchivedFrom",plan.path)
 plan.source:SetAttribute("CatalogId",plan.id)
 plan.source.Parent=archive
 assert(plan.source:GetPivot()==plan.pivot)
 assert(not plan.parent:FindFirstChild(plan.source.Name))
 assert(plan.library.Parent==assets)
 table.insert(moved,{id=plan.id,from=plan.path,to=plan.source:GetFullName()})
end
assert(#archive:GetChildren()==35)
local outside=0
for _,plan in ipairs(plans) do for _,d in ipairs(workspace:GetDescendants()) do if d:IsA("Model") and d.Name==plan.source.Name then outside+=1 end end end
assert(outside==0,"Unexpected duplicate source imports remain outside")
return game.HttpService:JSONEncode({moved=#moved,libraryCopies=35,outsideImports=outside,pivotsPreserved=true,archive=archive:GetFullName(),items=moved})
