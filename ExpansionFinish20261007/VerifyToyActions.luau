assert(not game:GetService("RunService"):IsRunning())
local folder=Instance.new("Folder") folder.Name="ExpansionToyVerification" folder.Parent=game.ServerStorage
local module=game.ServerScriptService.PlaygroundToyService:Clone() module.Name="ToyFixture" module.Parent=folder
local function test()
local Toys=require(module)
local toys=Toys.new()
toys.folder=folder
toys._inside=function() return true end
toys._ray=function() return nil end
toys._ground=function() return Vector3.new(0,0,-4) end
local root=Instance.new("Part") root.Anchored=true root.CFrame=CFrame.new(0,3,0) root.Parent=folder
toys._character=function() return {},{},root end
local record={player={Character=nil}}
local report={}
for n=16,25 do
 local id=string.format("M%02d",n)
 local before=#folder:GetDescendants()
 local objectsBefore=#toys.objects
 toys:_cosmeticExpansion(record,id,root,Vector3.new(0,0,-1))
 local count=#folder:GetDescendants()-before
 assert(count>0,"No cosmetic effect for "..id)
 local now=workspace:GetServerTimeNow()
 for i=objectsBefore+1,#toys.objects do
  local entry=toys.objects[i]
  assert(toys:_tickObject(entry,now+.1,.1),"Premature expiration "..id)
  if entry.kind=="Snowball" or entry.kind=="Honey" then
   toys._ray=function() return {Position=Vector3.new(0,0,-4),Normal=Vector3.yAxis} end
   assert(toys:_tickObject(entry,now+.2,.1)==false,"Impact did not end projectile "..id)
   toys._ray=function() return nil end
  end
 end
 table.insert(report,{id=id,createdInstances=count})
end
return report
end
local ok,result=xpcall(test,debug.traceback)
folder:Destroy()
if not ok then error(result) end
return game.HttpService:JSONEncode(result)
