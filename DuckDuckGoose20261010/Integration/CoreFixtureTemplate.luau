assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local fixture=Instance.new("Folder")
fixture.Name,fixture.Parent="DuckDuckGooseIntegrationFixture",game:GetService("ServerStorage")
local checks=0
local function check(value,message) checks+=1 assert(value,message) end
local function event() local e=Instance.new("BindableEvent")e.Parent=fixture return e end
local function moduleFrom(source,original)
 local m=Instance.new("ModuleScript")
 m.Name,m.Source,m.Capabilities,m.Sandboxed,m.Parent="FixtureModule",source,original.Capabilities,original.Sandboxed,fixture
 return require(m)
end
local players,roster={},{}
players.PlayerAdded,players.PlayerRemoving=event().Event,event().Event
function players:GetPlayers()return roster end
function players:GetPlayerByUserId(id)for _,p in roster do if p.UserId==id then return p end end end
local function makePlayer(id,ready)
 local attrs=Instance.new("Folder")attrs.Parent=fixture
 local char=Instance.new("Model")char.Name,char.Parent="FixtureRig"..id,fixture
 local h=Instance.new("Humanoid")h.Parent=char
 for _,name in {"HumanoidRootPart","Head","RightHand","UpperTorso"}do
  local p=Instance.new("Part")p.Name,p.Size,p.Anchored,p.CanCollide,p.Parent=name,Vector3.new(1,1,1),true,false,char
 end
 local backpack=Instance.new("Backpack")backpack.Parent=attrs
 local p={UserId=id,Name="Fixture"..id,Parent=players,Character=char}
 p.CharacterAdded,p.CharacterRemoving=event().Event,event().Event
 p.ChildAdded=attrs.ChildAdded
 function p:GetAttribute(name)return attrs:GetAttribute(name)end
 function p:SetAttribute(name,value)attrs:SetAttribute(name,value)end
 function p:GetAttributeChangedSignal(name)return attrs:GetAttributeChangedSignal(name)end
 function p:FindFirstChildOfClass(name)if name=="Backpack"then return backpack end end
 function p:FindFirstChild(name)return attrs:FindFirstChild(name)end
 function p:AddReplicationFocus()end
 function p:RemoveReplicationFocus()end
 p:SetAttribute("PCDataReady",ready)
 p:SetAttribute("PCBat","B01")
 table.insert(roster,p)
 return p
end
local a,b,observer=makePlayer(1,true),makePlayer(2,true),makePlayer(3,false)
local replicated,states={},{}
for _,name in {"PlaygroundState","BritishBulldogState","TagState","MudState","HideAndSeekState","DuckDuckGooseState"}do
 local state=Instance.new("Folder")state.Name,state.Parent=name,fixture states[name]=state
end
local assets=game:GetService("ReplicatedStorage"):FindFirstChild("PlaygroundCosmeticAssets")
function replicated:WaitForChild(name)
 if name=="PlaygroundCatalog"then return game:GetService("ReplicatedStorage").PlaygroundCatalog end
 return assert(states[name],name)
end
function replicated:FindFirstChild(name)if name=="PlaygroundCosmeticAssets"then return assets end return states[name]end
local heartbeat=event()
local mockGame={}
function mockGame:GetService(name)return ({Players=players,ReplicatedStorage=replicated,RunService={Heartbeat=heartbeat.Event}})[name]end
local clock=100
local mockWorld={}
function mockWorld:GetServerTimeNow()return clock end
local Coordinator=moduleFrom([==[return function(game,workspace)
COORDINATOR_SOURCE
end]==],game:GetService("ServerScriptService").PlaygroundCoordinator)(mockGame,mockWorld)
local services={}
local stateNames={BritishBulldog="BritishBulldogState",TagYoureIt="TagState",StuckInTheMud="MudState",HideAndSeek="HideAndSeekState",DuckDuckGoose="DuckDuckGooseState"}
for id,name in stateNames do
 local s={active=false,running=true,state=states[name],arena=Instance.new("Folder")}
 s.arena.Parent=fixture s.arena:SetAttribute("MinimumPlayers",2)
 function s:StartRound(selected)
  self.active,self.selected=true,selected
  self.state:SetAttribute("Phase",id=="HideAndSeek" and "Seeking" or "Playing")
  if id=="DuckDuckGoose"then
   self.state:SetAttribute("TurnPhase","Choosing")
   for _,p in selected do p:SetAttribute("DGParticipating",true)p:SetAttribute("DGRole","Duck")end
  end
  return true
 end
 function s:StopRound()
  self.active=false self.state:SetAttribute("Phase","Waiting")
  if id=="DuckDuckGoose"then for _,p in roster do p:SetAttribute("DGParticipating",false)p:SetAttribute("DGEliminated",false)p:SetAttribute("DGRole","")end end
 end
 services[id]=s
end
local rewards={}
local economy={}function economy:AwardRound(...)table.insert(rewards,{...})end
local lobby={Gameplay={VoteZone={CFrame=CFrame.new(),Size=Vector3.new(100,100,100)}}}
function lobby.Gameplay:FindFirstChild()return nil end
local coordinator=Coordinator.new(services,lobby,economy)
check(#coordinator:_readyPlayers()==2,"Only data-ready candidates start rounds")
check(coordinator:MinimumPlayers("DuckDuckGoose")==2,"Goose minimum is two")
check(coordinator:GameAvailable("DuckDuckGoose",2),"Two players can vote for Goose")
check(not coordinator:GameAvailable("DuckDuckGoose",1),"Solo Goose is unavailable")
coordinator:_step(100)
check(states.PlaygroundState:GetAttribute("Phase")=="Voting","Voting starts normally")
check(states.PlaygroundState:GetAttribute("VotingEndsAt")==135,"35 second intermission preserved")
check(states.PlaygroundState:GetAttribute("AvailableDuckDuckGoose")==true,"Fifth-game availability published")
check(coordinator:Vote(a,"DuckDuckGoose").ok and coordinator:Vote(b,"DuckDuckGoose").ok,"Both players can vote Goose")
check(states.PlaygroundState:GetAttribute("VotesDuckDuckGoose")==2,"Fifth-game votes counted")
check(coordinator:_chooseGame()=="DuckDuckGoose","Fifth game can win vote")
clock=134 coordinator:_step(clock)
check(not services.DuckDuckGoose.active,"Game cannot start before timer ends")
clock=135 coordinator:_step(clock)
check(services.DuckDuckGoose.active,"Goose starts when intermission ends")
check(coordinator:ActiveGame()=="DuckDuckGoose","Fifth game recognized as active")
check(states.PlaygroundState:GetAttribute("GameTitle")=="Duck Duck Goose","Fifth title is correct")
check(#services.DuckDuckGoose.selected==2,"Ready roster reaches service")
check(coordinator:_participating(a) and #coordinator:_readyPlayers()==0,"Goose players excluded from other rounds")
a:SetAttribute("PCAFKRequested",true)coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFKQueued")==true and a:GetAttribute("PCAFK")==false,"AFK queues while playing")
local target=coordinator:_spectateTarget(observer,a.UserId)
check(target==a,"Lobby spectator sees active Goose players")
check(coordinator:_spectateTarget(a,b.UserId)==nil,"Active Goose cannot spectate")
local Equipment=moduleFrom([==[return function(game,workspace)
EQUIPMENT_SOURCE
end]==],game:GetService("ServerScriptService").PlaygroundEquipmentService)(mockGame,mockWorld)
local toys={clears=0,cancels=0}
function toys:CanHold()return true end
function toys:ClearPlayer()self.clears+=1 end
function toys:CancelAction()self.cancels+=1 end
local dg=services.DuckDuckGoose
dg.swings=0
function dg:TryBatSwing()self.swings+=1 return true end
function dg:CancelBatSwing()end
local equipment=Equipment.new({DuckDuckGoose=dg},toys):Start()
local function settle()task.wait()task.wait()end
settle()
local record=equipment.records[a]
check(record~=nil,"Equipment watches Goose player")
check(record.bat==nil,"Seated Duck receives no bat")
a:SetAttribute("DGRole","Picker")settle()
check(record.bat==nil,"Picker receives no bat")
a:SetAttribute("DGRole","Runner")settle()
check(record.bat==nil,"Runner receives no bat")
a:SetAttribute("DGRole","Goose")settle()
check(record.bat==nil,"Goose receives no bat during Choosing")
dg.state:SetAttribute("TurnPhase","Chasing")settle()
check(record.bat~=nil and record.bat:IsA("Tool"),"TurnPhase watcher equips chasing Goose")
check(record.bat:GetAttribute("WeaponGame")=="DuckDuckGoose","Equipped Tool routes to fifth game")
check(record.bat.Parent==a.Character and a.Character:GetAttribute("PCBatHeld")==true,"Bat is held by character")
check(equipment:_activateBat(record) and dg.swings==1,"Equipped bat activates DG service once")
check(not equipment:_toyAllowed(record),"Active Goose cannot hold lobby toys")
a:SetAttribute("DGRagdolled",true)settle()
check(record.bat==nil,"Ragdoll temporarily removes Goose bat")
a:SetAttribute("DGRagdolled",false)settle()
check(record.bat~=nil,"Bat returns after ragdoll")
dg.state:SetAttribute("TurnPhase","Choosing")settle()
check(record.bat==nil,"Bat disappears immediately after chasing")
dg.state:SetAttribute("TurnPhase","Chasing")settle()
check(record.bat~=nil,"Next chasing phase restores bat")
a:SetAttribute("DGRole","Duck")settle()
check(record.bat==nil,"Successful Runner back in seat has no bat")
a:SetAttribute("DGParticipating",false)a:SetAttribute("DGEliminated",true)a:SetAttribute("DGRole","Spectator")settle()
check(not equipment:_toyAllowed(record),"Eliminated arena spectator cannot use lobby toys")
check(not coordinator:_participating(a),"Eliminated player may spectate")
coordinator:_syncAFK(a)
check(a:GetAttribute("PCAFK")==true and a:GetAttribute("PCAFKQueued")==false,"Eliminated AFK request no longer queues")
check(coordinator:_spectateTarget(a,b.UserId)==b,"Eliminated player can spectate alive Goose participant")
check(coordinator:_spectateTarget(observer,a.UserId)==nil,"Eliminated players are not spectator targets")
dg.state:SetAttribute("LastResultWinnerIds","2")
dg.state:SetAttribute("LastResultParticipantIds","1,2")
dg.state:SetAttribute("LastResultRound",8)
coordinator:_rewardDuckDuckGoose()
check(#rewards==1 and rewards[1][1]=="DG:8","Goose receipt key is unique")
check(rewards[1][2][1]==2 and rewards[1][4][1]==1,"Winner and eliminated participant reach economy")
check(rewards[1][5].gameId=="DuckDuckGoose","Wins assigned to fifth game")
equipment:Stop()
coordinator:StopGame()
check(not dg.active and states.PlaygroundState:GetAttribute("Phase")=="Paused","Admin stop handles fifth game")
check(a:GetAttribute("DGEliminated")==false,"Round cleanup restores lobby presence")
fixture:Destroy()
return {passed=true,checks=checks,actualBatToolTested=true,permissionsPreserved=true,playStarted=false}
