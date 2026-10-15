local Players=game:GetService("Players")
local tag=require(game.ServerScriptService.TagService).GetRunningService()
local sprint=require(game.ServerScriptService.TagSprintService).GetRunningService()
assert(tag and tag.running and not tag.active,"Use a fresh stopped Play session")
assert(sprint and sprint.running,"TagSprintService must be running")
local p=Players:GetPlayers()[1]
assert(p,"One connected Play player is required")
local checks={}
local function expect(name,condition) assert(condition,name) table.insert(checks,name) end
local ai={}
local ok,failure=xpcall(function()
 local started,reason=tag:StartPractice(p,"Runner")
 expect("Live Tag practice starts",started)
 local untilTime=os.clock()+7
 while tag.phase~="Playing" and os.clock()<untilTime do task.wait(.05) end
 expect("Live Tag countdown releases",tag.phase=="Playing")
 for _,record in pairs(tag.records) do
  if record.isBot then
   ai[record]={record.nextBotMoveAt,record.nextBotPathAt}
   record.nextBotMoveAt=math.huge record.nextBotPathAt=math.huge
   record.root.Anchored=true
   record.character:PivotTo(CFrame.new(6500,60,4534))
  end
 end
 local human=tag.records[p]
 tag:_teleport(human,CFrame.new(6440,37.4,4344))
 human.root:SetNetworkOwner(nil)
 task.wait(.1)
 local start=human.root.Position
 expect("Live sprint accepts real player hold",sprint:Request(p,true).ok)
 human.humanoid:MoveTo(start+Vector3.new(70,0,0))
 local began=os.clock()
 while os.clock()-began<1.2 do sprint:Request(p,true) task.wait(.3) end
 expect("Live sprint applies40speed",human.humanoid.WalkSpeed==40)
 expect("Live movement drains stamina",p:GetAttribute("TGSprintRemaining")<9.5 and p:GetAttribute("TGSprinting"))
 expect("Live character crosses distance",(human.root.Position-start).Magnitude>15)
 sprint:Request(p,false)
 task.wait(.15)
 expect("Live release restores16speed",human.humanoid.WalkSpeed==16 and not p:GetAttribute("TGSprinting"))
 human.humanoid:MoveTo(human.root.Position+Vector3.new(50,0,0))
 sprint:Request(p,true)
 task.wait(1.15)
 expect("Live lease expiry restores baseline",human.humanoid.WalkSpeed==16 and not p:GetAttribute("TGSprinting"))
end,debug.traceback)
for record,old in pairs(ai) do record.nextBotMoveAt=old[1] record.nextBotPathAt=old[2] end
if tag.active then tag:StopRound() end
if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart:SetNetworkOwnershipAuto() end
assert(ok,failure)
expect("Live stop clears Tag participation",not p:GetAttribute("TGParticipating"))
return {passed=#checks,checks=checks}
