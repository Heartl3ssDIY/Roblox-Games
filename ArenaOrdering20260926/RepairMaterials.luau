local changed={}
for _,name in ipairs({"Arena_Tenkaichi","Arena_ChuninExamHall","Arena_Loguetown","Arena_JujutsuHigh","Arena_Fujikasane","Arena_HeavensArena","Arena_HyperbolicTimeChamber","Arena_Wano","Arena_Marineford"}) do
 local root=workspace[name];local env=root.Environment
 for _,p in env:GetDescendants() do
 if p:IsA("MeshPart") then
 p.DoubleSided=true
 local reference
 for _,s in p:GetChildren() do if s:IsA("SurfaceAppearance") and s.ColorMap~="" then reference=s;break end end
 if reference then
 for _,s in p:GetChildren() do
 if s:IsA("SurfaceAppearance") and s.ColorMap=="" then
 s.ColorMap=reference.ColorMap;s.NormalMap=reference.NormalMap;s.RoughnessMap=reference.RoughnessMap;s.MetalnessMap=reference.MetalnessMap;s.Color=Color3.new(1,1,1)
 table.insert(changed,p:GetFullName())
 end end
 end
 end
 end
end
return game.HttpService:JSONEncode(changed)