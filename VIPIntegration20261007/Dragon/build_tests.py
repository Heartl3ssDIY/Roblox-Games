from pathlib import Path
p=Path(__file__).parent
s=(p/"After/Emotes.luau").read_text(encoding="utf-8")
motion=s[s.index("local petClipCache = {}"):s.index("local beforeAnimation = ")]
pre='''return function()
local report = {}
task.spawn(function()
local fixture
report.ok, report.result = xpcall(function()
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local Players = {LocalPlayer={GetAttribute=function() return false end}}
'''
post='''
local template=game.ReplicatedStorage.PlaygroundCosmeticAssets.P36
local display=workspace["VIP-Dragon-Rigged-display"]
local backup=game.ServerStorage.VIPDragonBackup20261007["VIP-Dragon-Rigged-display"]
check(display:GetPivot()==backup:GetPivot() and display:GetScale()==backup:GetScale(),"Large display moved or resized")
local clips=loadPetClips("VIPDragon")
check(clips.Idle and clips.Fly and #clips.Idle.frames==41 and #clips.Fly.frames==27,"Authored animation frames missing")
check(clips.Idle.duration>clips.Fly.duration,"Flight clip cadence incorrect")
for _,clip in {clips.Idle,clips.Fly} do
 for name,first in clip.frames[1].poses do
  local last=clip.frames[#clip.frames].poses[name]
  local delta=first:ToObjectSpace(last)
  local _,angle=delta:ToAxisAngle()
  check(delta.Position.Magnitude<0.002 and angle<0.002,"Clip loop seam on "..name)
 end
end
fixture=template:Clone()
fixture.Name="VIPAnimationCheck"
fixture:PivotTo(CFrame.new(0,4000,0))
fixture.Parent=workspace
local state={model=fixture,id="P36",tracks={},movement=0,phase=0}
prepareRigMotion(state)
check(state.authored and #state.authored.bones==14,"Rig did not bind all 14 bones")
local wing=fixture.RootPart:FindFirstChild("Wing.L",true)
state.authored.phase=0 updateRigMotion(state,false) local down=wing.Transform
state.authored.phase=0.5 updateRigMotion(state,false) local up=wing.Transform
local _,wingRange=down:ToObjectSpace(up):ToAxisAngle()
check(math.deg(wingRange)>50,"Authored wing flap missing")
state.authored.phase=0.3 state.movement=0 updateRigMotion(state,false) local hover=wing.Transform
state.movement=1 updateRigMotion(state,false) local flying=wing.Transform
check(not hover:FuzzyEq(flying,0.0001),"Moving pet does not switch to flight")
updateRigMotion(state,true) local reduced=wing.Transform
state.authored.phase=0.9 updateRigMotion(state,true)
check(reduced:FuzzyEq(wing.Transform),"Reduced motion does not hold steady")
local body=fixture.RootPart:FindFirstChild("Body",true)
state.movement=0 state.authored.phase=0.25 updateRigMotion(state,false)
local smallOffset=body.Transform.Position
state.authored.scale=25 updateRigMotion(state,false)
check((body.Transform.Position-smallOffset*25).Magnitude<0.0001,"Large rig translations are not scaled")
local originals,coats=0,0
for _,part in template:GetDescendants() do
 if part:IsA("BasePart") then
  check(not part.CanCollide and not part.CanTouch and not part.CanQuery,"Cosmetic collision enabled")
  if part:IsA("MeshPart") then
   if part:GetAttribute("PCStudLayer") then
    coats+=1 check(part.HasSkinnedMesh and part.MaterialVariant=="PlaygroundItemStuds","Stud coat lost skinned binding")
   else originals+=1 end
  end
 end
end
check(originals==8 and coats==8,"Incorrect VIP mesh layers")
check(template:GetAttribute("PCOutlineStored")==true and template:GetAttribute("PCOutlineColor")==Color3.new(0,0,0),"Black outline metadata missing")
check(template:FindFirstChildOfClass("Highlight")==nil,"Stored template wastes an outline slot")
check(display.CartoonOutline.Adornee==display and display.CartoonOutline.OutlineTransparency==0,"Display outline missing")
check(template:GetAttribute("PCPetHoverHeight")==1.15,"VIP flight height missing")
return {checks=checks,passed=true,wingRange=math.deg(wingRange)}
end,debug.traceback)
if fixture then fixture:Destroy() end
report.done=true
end)
while not report.done do task.wait() end
return report
end
'''
(p/"VerifyAnimation.luau").write_text(pre+motion+post,encoding="utf-8")
s=(p/"After/Pets.luau").read_text(encoding="utf-8")
body=s[s.index("local states = {}"):s.index("local reconcileClock = 1")]
head='''return function()
local report={}
task.spawn(function()
local fixturePlayers={list={}}
function fixturePlayers:GetPlayers() return self.list end
local Players=fixturePlayers
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local assets=ReplicatedStorage.PlaygroundCosmeticAssets
local localPlayer
local visuals=Instance.new("Folder")
visuals.Name="VIPFollowerFixture"
visuals.Parent=workspace
'''
old=(p.parents[1]/"PetAdminFix20261007/Pets/VerifyPetVisibility.luau").read_text(encoding="utf-8")
tests=old[old.index("local checks={}"):old.index("end,debug.traceback)\nreport.done=true")]
start=tests.index(' local tool=workspace:FindFirstChild("PetOutlineInputRegression")')
end=tests.index(" for n=1,35 do")
tests=tests[:start]+tests[end:]
tests=tests.replace("for n=1,35 do","for n=1,36 do")
tests=tests.replace('lower.Y<17.7','lower.Y<(id=="P36" and 18.0 or 17.7)')
tests=tests.replace('petTemplates=35','petTemplates=36')
tests=tests.replace("releaseCartoonOutlines()","")
tail='''report.ok,report.result=xpcall(function()
'''+tests+'''
end,debug.traceback)
report.done=true
end)
while not report.done do task.wait() end
return report
end
'''
(p/"VerifyFollower.luau").write_text(head+body+tail,encoding="utf-8")
print("Prepared isolated animation and 36-pet follower fixtures.")

