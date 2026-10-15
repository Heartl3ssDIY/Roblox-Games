local Players=game:GetService("Players")
local p=Players:GetPlayers()[1]
assert(p,"Use a Play client for the sprint fixture")
local original=game.ServerScriptService.TagSprintService
local module=original:Clone() module.Name="TagSprintFixtureModule" module.Parent=game.ServerScriptService
local Sprint=require(module)
local saved={}
for _,key in ipairs({"BBParticipating","MDParticipating","TGParticipating","TGSprintMax","TGSprintRemaining","TGSprinting","TGSprintExhausted"}) do
 saved[key]={p:GetAttribute(key)}
end
local checks={}
local function expect(name,condition) assert(condition,name) table.insert(checks,name) end
local ok,failure=xpcall(function()
 p:SetAttribute("BBParticipating",false) p:SetAttribute("MDParticipating",false) p:SetAttribute("TGParticipating",true)
 local character={}
 local record={participating=true,frozen=false,role="Runner",character=character,root={AssemblyLinearVelocity=Vector3.zero,Parent=true},humanoid={Health=100,WalkSpeed=16}}
 local tag={active=true,phase="Playing",records={[p]=record},arena=workspace["Tag You're It"],roundNumber=1,currentRound={}}
 local restores=0
 function tag:_movement(item) restores+=1 item.humanoid.WalkSpeed=16 end
 local sprint=Sprint.new(tag)
 sprint:_tick(0)
 local entry=sprint.entries[p]
 expect("Sprint starts with10seconds",entry.remaining==10)
 expect("Nonboolean sprint rejected",not sprint:Request(p,"yes").ok)
 expect("Playing runner can hold sprint",sprint:Request(p,true).ok)
 sprint:_tick(1)
 expect("Stationary hold does not drain",entry.remaining==10 and not p:GetAttribute("TGSprinting"))
 record.root.AssemblyLinearVelocity=Vector3.new(10,0,0)
 sprint:_tick(1)
 expect("Moving runner sprints at40",record.humanoid.WalkSpeed==40 and p:GetAttribute("TGSprinting"))
 expect("Moving sprint consumes one second",entry.remaining==9)
 expect("Repeated hold is rate limited",not sprint:Request(p,true).ok)
 expect("Release bypasses rate limit",sprint:Request(p,false).ok and not entry.held)
 sprint:_tick(1.5)
 expect("Released sprint refills15second curve",entry.remaining==10 and record.humanoid.WalkSpeed==16)
 entry.held=true entry.lease=workspace:GetServerTimeNow()+20
 sprint:_tick(10)
 expect("Ten continuous seconds exhausts sprint",entry.remaining==0 and entry.locked and record.humanoid.WalkSpeed==16)
 sprint:_tick(7.5)
 expect("Half refill remains locked",entry.remaining==5 and entry.locked)
 sprint:_tick(7.5)
 expect("Full15second refill unlocks without release",entry.remaining==10 and not entry.locked and entry.held)
 sprint:_tick(.1)
 expect("Held sprint resumes after full refill",record.humanoid.WalkSpeed==40 and entry.remaining<10)
 entry.lease=0 sprint:_tick(.1)
 expect("Expired hold lease stops sprint",not entry.held and record.humanoid.WalkSpeed==16)
 entry.held=true entry.lease=workspace:GetServerTimeNow()+20 record.role="Tagger" sprint:_tick(.1)
 expect("Tagger sprint uses2point5times18base",record.humanoid.WalkSpeed==45)
 record.frozen=true sprint:_tick(.1)
 expect("Frozen player cannot move or sprint",record.humanoid.WalkSpeed==0 and not p:GetAttribute("TGSprinting"))
 record.frozen=false tag.phase="Countdown" sprint:_tick(.1)
 expect("Countdown does not consume stamina",record.humanoid.WalkSpeed==18 and not p:GetAttribute("TGSprinting"))
 expect("Countdown hold rejected",not sprint:Request(p,true).ok)
 tag.phase="Playing" record.humanoid.Health=0
 expect("Dead player hold rejected",not sprint:Request(p,true).ok)
 record.humanoid.Health=100 p:SetAttribute("MDParticipating",true)
 expect("Mud participants cannot trigger Tag sprint",not sprint:Request(p,true).ok)
 record.humanoid.WalkSpeed=31 sprint:_tick(.1)
 expect("Tag tick preserves movement during Mud",record.humanoid.WalkSpeed==31 and sprint.entries[p]==nil)
 p:SetAttribute("MDParticipating",false) p:SetAttribute("BBParticipating",true)
 expect("Bulldog participants cannot trigger Tag sprint",not sprint:Request(p,true).ok)
 record.humanoid.WalkSpeed=33 sprint:_tick(.1)
 expect("Tag tick preserves movement during Bulldog",record.humanoid.WalkSpeed==33)
 p:SetAttribute("BBParticipating",false)
 sprint:_tick(0)
 entry=sprint.entries[p] entry.remaining=3 entry.locked=true entry.held=true entry.lease=workspace:GetServerTimeNow()+20
 record.character={} sprint:_tick(0)
 expect("Respawn clears held input without granting stamina",sprint.entries[p].character==record.character and not sprint.entries[p].held and sprint.entries[p].remaining==3 and sprint.entries[p].locked)
 tag.roundNumber=2 tag.currentRound={} sprint:_tick(0)
 expect("New round grants fresh stamina even with same character",sprint.entries[p].remaining==10 and not sprint.entries[p].locked and not sprint.entries[p].held)
 p:SetAttribute("MDParticipating",true) record.humanoid.WalkSpeed=31 sprint:Stop()
 expect("Stopping sprint preserves another game movement",record.humanoid.WalkSpeed==31 and restores==0)
 p:SetAttribute("MDParticipating",false) sprint:_tick(0) sprint:Stop()
 expect("Stopping owned Tag sprint restores baseline",record.humanoid.WalkSpeed==16 and restores==1)
 sprint:_tick(0)
 record.participating=false sprint:_tick(.1)
 expect("Leaving Tag clears sprint state",sprint.entries[p]==nil and not p:GetAttribute("TGSprinting") and not p:GetAttribute("TGSprintExhausted"))
end,debug.traceback)
for key,value in pairs(saved) do p:SetAttribute(key,value[1]) end
module:Destroy()
assert(ok,failure)
return {passed=#checks,checks=checks,usesMockMovementOnly=true}
