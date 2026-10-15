local result={};local entries=assert(loadstring(game.ReplicatedStorage.ArenaCatalog.Source))().ordered
for _,entry in ipairs(entries) do
 local r=workspace[entry.modelName];local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={r.Collision};params.RespectCanCollide=true
 local holes=0;local high=0;local min=math.huge;local max=-math.huge
 for x=-28,28,7 do for z=-28,28,7 do
 local pos=r.BattleOrigin.Position+Vector3.new(x,10,z);local hit=workspace:Raycast(pos,Vector3.new(0,-30,0),params)
 if not hit then holes+=1 else local y=hit.Position.Y-r.BattleOrigin.Position.Y;min=math.min(min,y);max=math.max(max,y);if y>2 then high+=1 end end
 end end
 table.insert(result,{name=r.Name,samples=81,holes=holes,obstructions=high,min=min,max=max})
end
return game.HttpService:JSONEncode(result)