from pathlib import Path
folder=Path(__file__).resolve().parents[1]
source=(folder/'After/PlaygroundEmotes.client.luau').read_text(encoding='utf-8')
prefix=source[:source.index('local beforeAnimation =')]
before=(folder/'Before/PlaygroundEmotes.client.luau').read_text(encoding='utf-8')
assert prefix[:prefix.index('local function animateDodge')].rstrip() == before[:before.index('local beforeAnimation =')].rstrip()
support='''local nativeGame, nativeWorkspace = game, workspace
local testState, testFolder
local game = {GetService=function(_,name)
 if name=="ReplicatedStorage" then return {FindFirstChild=function()return testState end} end
 return nativeGame:GetService(name)
end}
local workspace = {FindFirstChild=function(_,name) if name=="TagPracticeBots" then return testFolder end return nativeWorkspace:FindFirstChild(name) end}
'''
expose='''return {Dodge=animateDodge,Bots=animatePracticeBots,Restore=restore,Collect=collectJoints,BotRecords=botRecords,
 Configure=function(state,folder)testState,testFolder=state,folder end}
'''
module=support+prefix+expose
test='''local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder") fixture.Name="MovementPoseChecks20261005" fixture.Parent=storage
local result={passed=false,checks=0}
local function check(value,message) assert(value,message) result.checks+=1 end
local ok,err=xpcall(function()
 local live=game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
 local module=Instance.new("ModuleScript") module.Name="Candidate" module.Capabilities=live.Capabilities module.Sandboxed=live.Sandboxed
 module.Source=__MODULE__ module.Parent=fixture
 local api=require(module)
 local phase="Playing"
 local state={GetAttribute=function(_,key)if key=="Phase"then return phase end end}
 local bots=Instance.new("Folder") bots.Name="Bots" bots.Parent=fixture
 api.Configure(state,bots)
 for _,kind in ipairs({"R6","R15"})do
  local character=storage.WeaponRigFixtures[kind]:Clone() character.Name=kind character.Parent=bots
  local humanoid=character:FindFirstChildOfClass("Humanoid") local root=character.HumanoidRootPart
  humanoid.Health=100 humanoid.PlatformStand=false
  local attrs={TGParticipating=true,TGDodgeStartedAt=100,TGDodgeDuration=.32,TGDodgeDirection=Vector3.xAxis}
  local player={GetAttribute=function(_,key)return attrs[key]end}
  local record={joints={}}
  local joints=api.Collect(character)
  local original={}
  for _,joint in pairs(joints)do original[joint]=joint.Transform end
  check(api.Dodge(record,player,character,humanoid,100.12),kind.." accepted pose")
  local changed=0 for joint,frame in pairs(original)do if joint.Transform~=frame then changed+=1 end end
  check(changed>=3,kind.." torso and shoulders animate")
  api.Restore(record)
  for joint,frame in pairs(original)do check(joint.Transform==frame,kind.." exact joint restore")end
  check(next(record.joints)==nil,kind.." cleanup clears state")
  check(not api.Dodge(record,player,character,humanoid,100.6),kind.." expired pose stays clear")
  attrs.TGRagdolled=true check(not api.Dodge(record,player,character,humanoid,100.12),kind.." ragdoll excludes pose") attrs.TGRagdolled=nil
  phase="Results" check(not api.Dodge(record,player,character,humanoid,100.12),kind.." results excludes pose") phase="Playing"
  attrs.TGParticipating=false check(not api.Dodge(record,player,character,humanoid,100.12),kind.." nonparticipant excludes pose") attrs.TGParticipating=true
  root.AssemblyLinearVelocity=Vector3.new(16,0,0)
  api.Bots(100.12)
  check(api.BotRecords[character]~=nil,kind.." bot walk recorded")
  changed=0 for joint,frame in pairs(original)do if joint.Transform~=frame then changed+=1 end end
  check(changed>=4,kind.." native arms and legs walk")
  humanoid.PlatformStand=true api.Bots(100.15)
  for joint,frame in pairs(original)do check(joint.Transform==frame,kind.." ragdoll restores walk")end
  humanoid.PlatformStand=false root.AssemblyLinearVelocity=Vector3.zero api.Bots(100.2)
  check(next(api.BotRecords[character].joints)==nil,kind.." stopped bot no stale pose")
  root.AssemblyLinearVelocity=Vector3.new(16,0,0) api.Bots(100.22)
  character.Parent=fixture api.Bots(100.25)
  check(api.BotRecords[character]==nil,kind.." removal releases cache")
  for joint,frame in pairs(original)do check(joint.Transform==frame,kind.." removal restores joint")end
 end
 result.capabilities=tostring(live.Capabilities)
 result.passed=true
end,debug.traceback)
fixture:Destroy()
result.cleaned=storage:FindFirstChild("MovementPoseChecks20261005")==nil
if not ok then result.error=err end
return result
'''
(folder/'Tests/MovementPoseNativeChecks.luau').write_text(test.replace('__MODULE__','[====['+module+']====]'),encoding='utf-8')
print('Native pose harness generated; original bat and toy source preserved exactly')
