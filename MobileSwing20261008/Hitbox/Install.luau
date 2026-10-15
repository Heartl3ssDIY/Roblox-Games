assert(not game:GetService("RunService"):IsRunning(),"Edit mode only")
local function checksum(s)
 local a,b=1,0
 for i=1,#s do a=(a+string.byte(s,i))%65521 b=(b+a)%65521 end
 return b*65536+a
end
local function replaceAll(s, old, new, expected)
 local result,n=s:gsub(old:gsub("(%W)","%%%1"),function() return new end)
 assert(n==expected,"Changed occurrence count: "..old)
 return result
end
local specs={{name="BritishBulldogService",before=1453243384,after=1014287895},
{name="TagService",before=1293169644,after=2773960306}}
for _,entry in specs do
 local target=game.ServerScriptService:FindFirstChild(entry.name)
 assert(target and checksum(target.Source)==entry.before,"Live source changed: "..entry.name)
 entry.target=target
 local source=target.Source
 source=replaceAll(source,"local BAT_SAMPLE_MAX_AGE = 0.15","local BAT_SAMPLE_MAX_AGE = 0.15\nlocal BAT_FACING_DOT = 0.15",1)
 source=replaceAll(source,"0.0625 * facingLength[i] * horizontalLength[j]","BAT_FACING_DOT * BAT_FACING_DOT * facingLength[i] * horizontalLength[j]",1)
 source=replaceAll(source,">= 0.25 - 1e-7",">= BAT_FACING_DOT - 1e-7",1)
 if entry.name=="BritishBulldogService" then
  source=replaceAll(source,"local TAG_DISTANCE = 4.5","local TAG_DISTANCE = 6",1)
 else
  source=replaceAll(source,'math.clamp(self:_setting("TagDistance", 4.5, 1), 1, 5)','math.clamp(self:_setting("TagDistance", 6, 1), 1, 6.5)',2)
 end
 assert(checksum(source)==entry.after,"Unexpected patch result: "..entry.name)
 entry.source=source
end
local storage=game.ServerStorage
assert(not storage:FindFirstChild("MobileSwingHitboxBackup20261008"),"Backup exists; inspect before rerunning")
local backup=Instance.new("Folder")
backup.Name="MobileSwingHitboxBackup20261008"
backup.Parent=storage
local results={}
for _,entry in specs do
 local before=Instance.new("StringValue")
 before.Name=entry.name
 before.Value=entry.target.Source
 before:SetAttribute("TargetPath",entry.target:GetFullName())
 before.Parent=backup
 entry.target.Source=entry.source
 assert(checksum(entry.target.Source)==entry.after,"Readback mismatch")
 table.insert(results,{name=entry.name,checksum=entry.after})
end
return game:GetService("HttpService"):JSONEncode({installed=results,backup=backup:GetFullName(),running=game:GetService("RunService"):IsRunning()})

