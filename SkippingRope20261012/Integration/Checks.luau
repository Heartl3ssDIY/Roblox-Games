local count=0
local function check(value,message) assert(value,message) count+=1 end
local objects={}
local function folder()
 local x=Instance.new("Folder") table.insert(objects,x) return x
end
local playerList={}
local players={}
function players:GetPlayers() return playerList end
function players:GetPlayerByUserId(id) for _,p in ipairs(playerList) do if p.UserId==id then return p end end end
local function player(id)
 local root={Position=Vector3.zero}
 local p={UserId=id,Name="Fixture"..id,DisplayName="Fixture "..id,Parent=players,attributes={PCDataReady=true}}
 local humanoid={Health=100}
 p.Character={FindFirstChildOfClass=function()return humanoid end,FindFirstChild=function(_,name)return name=="HumanoidRootPart" and root or nil end}
 function p:GetAttribute(name)return self.attributes[name]end
 function p:SetAttribute(name,value)self.attributes[name]=value end
 return p
end
CoordinatorFixture.SetPlayers(players)
local Coordinator=CoordinatorFixture.Coordinator
local function fresh(n)
 playerList={} for id=1,n do table.insert(playerList,player(id)) end
 local service={arena=folder(),state=folder(),running=true,active=false,starts=0}
 service.arena:SetAttribute("MinimumPlayers",2)
 function service:StartRound(selected)
  self.starts+=1 self.selected=selected self.active=true self.phase="Countdown" self.state:SetAttribute("Phase","Countdown")
  for _,p in ipairs(selected)do p:SetAttribute("SKParticipating",true) p:SetAttribute("SKRole","Jumper")end
  return true
 end
 function service:StopRound()
  self.active=false self.state:SetAttribute("Phase","Waiting")
  for _,p in ipairs(self.selected or {})do p:SetAttribute("SKParticipating",false) p:SetAttribute("SKEliminated",false) end
 end
 local c=setmetatable({services={SkippingRope=service},lobby={Gameplay={FindFirstChild=function()return nil end}},state=folder(),votes={},lastVote={},spectators={},lastSessionRequest={},lastSpectateStamp={},lastSpectateRequest={},autoEnabled=true,votingEndsAt=0,startRetryAt=0,random=Random.new(1)},Coordinator)
 return c,service
end
local c,service=fresh(4)
playerList[3]:SetAttribute("PCAFKRequested",true)
playerList[4]:SetAttribute("PCDataReady",false)
c:_step(100)
check(c.state:GetAttribute("Phase")=="Voting","SK available to automatic voting")
check(c.state:GetAttribute("AvailableSkippingRope")==true,"SK availability published")
check(c.state:GetAttribute("VotingEndsAt")==135,"35-second intermission")
check(c.state:GetAttribute("ReadyPlayerCount")==2,"AFK and unloaded profiles excluded")
c:_step(134.99)
check(not service.active,"No early round")
c:_step(135)
check(service.active and service.starts==1 and #service.selected==2,"Automatic SK starts eligible roster once")
check(c.state:GetAttribute("ActiveGame")=="SkippingRope" and c.state:GetAttribute("GameTitle")=="Skipping Rope","SK session title")
c:_step(140)
check(service.starts==1,"Running SK not restarted")
local jumper=playerList[1]
check(c:_participating(jumper),"SK participant recognized")
jumper:SetAttribute("PCAFKRequested",true) c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFKQueued")==true and jumper:GetAttribute("PCAFK")==false,"AFK queues during SK")
jumper:SetAttribute("SKParticipating",false) jumper:SetAttribute("SKEliminated",true)
check(c:_participating(jumper),"SK eliminated remains in round")
c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFKQueued")==true,"Eliminated SK AFK stays queued")
jumper:SetAttribute("SKParticipating",true) jumper:SetAttribute("SKEliminated",false)
service.state:SetAttribute("Phase","Playing")
local target=c:_spectateTarget(playerList[3],jumper.UserId)
check(target==jumper,"Lobby spectator can follow SK jumper")
jumper:SetAttribute("SKEliminated",true)
check(c:_spectateTarget(playerList[3],jumper.UserId)==nil,"Out SK jumper not a spectate target")
check(c:_spectateTarget(playerList[2],jumper.UserId)==nil,"Active SK player cannot spectate to escape")
service:StopRound() c:_syncAFK(jumper)
check(jumper:GetAttribute("PCAFK")==true and jumper:GetAttribute("PCAFKQueued")==false,"AFK applies after cleanup")
jumper:SetAttribute("PCAFKRequested",false) c:_syncAFK(jumper)
c:_step(250)
check(c.state:GetAttribute("VotingEndsAt")==285,"Next 35-second intermission")
local reported={}
c.economy={AwardRound=function(_,...) table.insert(reported,table.pack(...))end}
service.state:SetAttribute("LastResultWinnerIds","1,2")
service.state:SetAttribute("LastResultParticipantIds","1,2,3")
service.state:SetAttribute("LastResultRound",7)
service.state:SetAttribute("LastResultPractice",false)
c:_rewardSkippingRope()
local reward=reported[1]
check(reward[1]=="SK:7" and reward[5].gameId=="SkippingRope","SK reward identity")
check(#reward[2]==2 and #reward[4]==3 and reward[3]==false,"Survivors and eliminated reward rosters distinct")
service.state:SetAttribute("LastResultPractice",true) c:_rewardSkippingRope()
check(reported[2][3]==true,"Cancelled round suppressed by reward gate")
c,service=fresh(2)
local config=folder() config:SetAttribute("AdminUserId",1)
local admin=Admin.new(c,config,true,players)
local rejected=admin:Handle(playerList[2],"SKStart")
check(not rejected.ok and not service.active,"Unauthorized SK start blocked")
local accepted=admin:Handle(playerList[1],"SKStart")
check(accepted.ok and service.active and accepted.game=="SkippingRope" and accepted.role=="Jumper","Authorized SK start dispatch and status")
admin.lastRequest[playerList[1]]=nil
local stopped=admin:Handle(playerList[1],"StopRound")
check(stopped.ok and not service.active and not c.autoEnabled,"Existing admin stop handles SK")
local Economy=EconomyFixture.Economy
local profiles={}
local economy=setmetatable({awarded={}},Economy)
for id=1,3 do profiles[id]={ready=true,data=EconomyFixture.CleanData({Coins=100,XP=0,Wins=0,GameWins={DuckDuckGoose=2}})} end
function economy:_profileByUserId(id)return profiles[id]end
function economy:_setting(_,fallback)return fallback end
function economy:_earnedCoins(_,amount)return amount end
function economy:_earnedXP(_,amount)return amount end
function economy:_touch()end
function economy:_publishReward(profile,coins,xp,won)profile.notice={coins,xp,won}end
check(profiles[1].data.GameWins.SkippingRope==0 and profiles[1].data.GameWins.DuckDuckGoose==2,"Existing saves gain SK zero wins without losing old wins")
local awarded=economy:AwardRound("SK:1",{1,2,999},false,{1,2,3},{gameId="SkippingRope"})
check(awarded==3,"Every connected participant rewarded exactly once")
check(profiles[1].data.Coins==250 and profiles[1].data.Wins==1 and profiles[1].data.GameWins.SkippingRope==1,"Survivor earns winner reward and SK win")
check(profiles[3].data.Coins==150 and profiles[3].data.Wins==0 and profiles[3].data.GameWins.SkippingRope==0,"Eliminated gets participation reward only")
check(economy:AwardRound("SK:1",{1,2},false,{1,2,3})==0,"Duplicate result cannot duplicate rewards")
check(economy:AwardRound("SK:2",{1,2},true,{1,2,3})==0,"Cancelled round gives no rewards")
check(economy:AwardRound("SK:3",{3},false,{3})==1 and profiles[3].data.GameWins.SkippingRope==1,"SK key prefix fallback works")
local candidates={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose","SkippingRope"}
c,service=fresh(2)
for _,id in ipairs(candidates)do
 local entry={arena=folder(),state=folder(),running=true,active=false}
 entry.arena:SetAttribute("MinimumPlayers",2)
 c.services[id]=entry
end
c.lastGame="TagYoureIt"
local seen={}
for index=1,5 do
 c.random={NextInteger=function(_,minimum,maximum)check(maximum==5,"Previous game excluded from unvoted pool")return index end}
 seen[c:_chooseGame()]=true
end
check(seen.SkippingRope and seen.DuckDuckGoose and seen.HideAndSeek and seen.StuckInTheMud and seen.BritishBulldog and not seen.TagYoureIt,"All other eligible games reachable without votes")
c.lastGame="SkippingRope" c.votes[playerList[1]]="SkippingRope"
c.random=Random.new(1)
check(c:_chooseGame()=="SkippingRope","Player votes can still choose previous game")

for _,x in ipairs(objects)do x:Destroy()end
return {passed=true,checks=count,scope="Native isolated coordinator/admin/economy execution; no live players or persistent rewards"}

