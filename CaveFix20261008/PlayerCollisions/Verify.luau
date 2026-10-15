assert(not game:GetService("RunService"):IsRunning(), "Keep Studio in Edit mode")
local PhysicsService=game:GetService("PhysicsService")
local roles={"Default","BBRunner","BBBulldog","BBTagged","TGPlayer","MudPlayer"}
local checks=0
local function check(condition, message)
 assert(condition, message)
 checks+=1
end
local fixture=Instance.new("Folder")
fixture.Name="PlayerCollisionVerification20261008"
fixture.Parent=workspace
local ok,result=pcall(function()
 local bodies={}
 for i,group in roles do
  local model=Instance.new("Model")
  model.Name=group
  model.Parent=fixture
  local torso=Instance.new("Part")
  torso.Name="Torso"
  torso.Size=Vector3.new(2,2,1)
  torso.CFrame=CFrame.new(-10000,1000+i*5,0)
  torso.Anchored=true
  torso.CanCollide=true
  torso.CollisionGroup=group
  torso.Parent=model
  bodies[group]=torso
 end
 for _,a in roles do for _,b in roles do
  check(PhysicsService:CollisionGroupsAreCollidable(a,b), a.." / "..b.." matrix should collide")
  if a~=b then check(bodies[a]:CanCollideWith(bodies[b]), a.." / "..b.." bodies should collide") end
 end end
 local second=Instance.new("Part")
 second.Name="SecondPlayerTorso"
 second.Anchored=true
 second.CanCollide=true
 second.CFrame=CFrame.new(-10000,1040,0)
 second.Parent=fixture
 for _,group in roles do
  second.CollisionGroup=group
  check(bodies[group]:CanCollideWith(second), group.." two players should collide")
 end
 local barrier=Instance.new("Part")
 barrier.Name="Barrier"
 barrier.CollisionGroup="BBBarrier"
 barrier.Anchored=true
 barrier.CanCollide=true
 barrier.CFrame=CFrame.new(-10000,1050,0)
 barrier.Parent=fixture
 for group,shouldBlock in {Default=false, BBRunner=false, BBBulldog=true, BBTagged=false} do
  check(bodies[group]:CanCollideWith(barrier)==shouldBlock, group.." barrier rule changed")
 end
 local cosmetic=Instance.new("Part")
 cosmetic.Name="PetOrTool"
 cosmetic.Anchored=true
 cosmetic.CanCollide=false
 cosmetic.CFrame=CFrame.new(-10000,1060,0)
 cosmetic.Parent=fixture
 for _,group in roles do
  cosmetic.CollisionGroup=group
  check(not bodies[group]:CanCollideWith(cosmetic), group.." cosmetic must remain noncolliding")
 end
 local before=game.ServerStorage.PlayerCollisionBackup20261008
 local edits={
  {"BritishBulldogService","provider:CollisionGroupSetCollidable(first, second, false)","provider:CollisionGroupSetCollidable(first, second, true)"},
  {"TagService",'provider:CollisionGroupSetCollidable("TGPlayer", "TGPlayer", false)','provider:CollisionGroupSetCollidable("TGPlayer", "TGPlayer", true)'},
  {"StuckInTheMudService",'provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", false)','provider:CollisionGroupSetCollidable("MudPlayer", "MudPlayer", true)'}
 }
 for _,edit in edits do
  local original=before[edit[1]].Source
  local first,last=original:find(edit[2],1,true)
  local expected=original:sub(1,first-1)..edit[3]..original:sub(last+1)
  local current=game.ServerScriptService[edit[1]]
  check(current.Source==expected, edit[1].." unexpected source changes")
  check(current.Capabilities==before[edit[1]].Capabilities and current.Sandboxed==before[edit[1]].Sandboxed, edit[1].." security settings changed")
 end
 local nativeRig=game.ServerStorage.WeaponRigFixtures.R15
 check(nativeRig.UpperTorso.CanCollide and nativeRig.LowerTorso.CanCollide,"R15 torso is not collidable")
 return {checks=checks,playerGroups=roles,pushCollisions=true,barrierRulesPreserved=true,cosmeticsNoncolliding=true,editOnly=true}
end)
fixture:Destroy()
assert(ok,result)
return game.HttpService:JSONEncode(result)
