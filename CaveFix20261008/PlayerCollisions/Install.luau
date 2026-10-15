assert(not game:GetService("RunService"):IsRunning(), "Keep Studio in Edit mode")
local edits = {{name=[====[BritishBulldogService]====],before=[====[provider:CollisionGroupSetCollidable(first, second, false)]====],after=[====[provider:CollisionGroupSetCollidable(first, second, true)]====],expectedLength=73749},
{name=[====[TagService]====],before=[====[provider:CollisionGroupSetCollidable("TGPlayer", "TGPlayer", false)]====],after=[====[provider:CollisionGroupSetCollidable("TGPlayer", "TGPlayer", true)]====],expectedLength=66391},
{name=[====[StuckInTheMudService]====],before=[====[provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)]====],after=[====[provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", true)]====],expectedLength=61049}}
local scripts = {}
for _,edit in edits do
 local script = game.ServerScriptService:FindFirstChild(edit.name)
 assert(script and script:IsA("ModuleScript"), edit.name .. " missing")
 assert(#script.Source == edit.expectedLength, edit.name .. " changed during preparation")
 local startAt,endAt = script.Source:find(edit.before, 1, true)
 assert(startAt and not script.Source:find(edit.before, endAt + 1, true), edit.name .. " collision setting changed")
 table.insert(scripts, {script=script, source=script.Source, after=script.Source:sub(1,startAt-1)..edit.after..script.Source:sub(endAt+1)})
end
local backup=game.ServerStorage:FindFirstChild("PlayerCollisionBackup20261008")
assert(not backup, "Backup already exists; inspect before reapplying")
backup=Instance.new("Folder")
backup.Name="PlayerCollisionBackup20261008"
backup.Parent=game.ServerStorage
local PhysicsService=game:GetService("PhysicsService")
local groups={"Default","BBRunner","BBBulldog","BBTagged","TGPlayer","MudPlayer","BBBarrier"}
local matrix={}
for _,a in groups do local row={} for _,b in groups do row[b]=PhysicsService:CollisionGroupsAreCollidable(a,b) end matrix[a]=row end
backup:SetAttribute("CollisionMatrixBefore",game.HttpService:JSONEncode(matrix))
for _,edit in scripts do
 local clone=edit.script:Clone();clone.Parent=backup
 edit.script.Source=edit.after
end
for _,a in {"BBRunner","BBBulldog","BBTagged"} do
 for _,b in {"BBRunner","BBBulldog","BBTagged"} do PhysicsService:CollisionGroupSetCollidable(a,b,true) end
end
PhysicsService:CollisionGroupSetCollidable("TGPlayer","TGPlayer",true)
PhysicsService:CollisionGroupSetCollidable("MudPlayer","MudPlayer",true)
return "Installed 3 guarded source edits and player collision matrix; backup ServerStorage.PlayerCollisionBackup20261008"
