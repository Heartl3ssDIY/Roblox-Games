assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
assert(game.PlaceId == 95034648955135, "Wrong place")
local function checksum(source)
 local a,b=1,0
 for index=1,#source do a=(a+string.byte(source,index))%65521 b=(b+a)%65521 end
 return b*65536+a
end
local function replace(source,before,after,count)
 local patched,found=source:gsub(before:gsub("(%W)","%%%1"),function() return after end)
 assert(found==count,"Unexpected source match count")
 return patched
end
local specs={
 {name="BritishBulldogService",before=19778957,after=1133563320,
  old="local TAG_DISTANCE = 6\n",new="local TAG_DISTANCE = 10\n",count=1},
 {name="TagService",before=3205596709,after=4065494539,
  old='math.clamp(self:_setting("TagDistance", 6, 1), 1, 6.5)',new='math.clamp(self:_setting("TagDistance", 10, 1), 1, 10)',count=2},
}
local tagArena=workspace:FindFirstChild("Tag You're It")
assert(tagArena and tagArena:GetAttribute("TagDistance")==nil,"Tag distance changed; inspect first")
for _,entry in ipairs(specs) do
 entry.target=game:GetService("ServerScriptService"):FindFirstChild(entry.name)
 assert(entry.target and checksum(entry.target.Source)==entry.before,"Live source changed: "..entry.name)
 entry.source=replace(entry.target.Source,entry.old,entry.new,entry.count)
 assert(checksum(entry.source)==entry.after,"Unexpected patch result")
end
local storage=game:GetService("ServerStorage")
assert(not storage:FindFirstChild("BatReachBackup20261008"),"Backup already exists")
local backup=Instance.new("Folder")
backup.Name="BatReachBackup20261008"
backup:SetAttribute("PreviousTagDistancePresent",false)
backup.Parent=storage
local installed={}
for _,entry in ipairs(specs) do
 local saved=Instance.new("StringValue")
 saved.Name=entry.name
 saved.Value=entry.target.Source
 saved:SetAttribute("TargetPath",entry.target:GetFullName())
 saved.Parent=backup
 entry.target.Source=entry.source
 assert(checksum(entry.target.Source)==entry.after,"Readback mismatch: "..entry.name)
 table.insert(installed,entry.name)
end
tagArena:SetAttribute("TagDistance",10)
assert(tagArena:GetAttribute("TagDistance")==10,"Tag distance readback mismatch")
return game:GetService("HttpService"):JSONEncode({installed=installed,reach=10,backup=backup:GetFullName(),playStarted=false})

