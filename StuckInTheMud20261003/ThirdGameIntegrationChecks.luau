local Players=game:GetService("Players")
local ServerScriptService=game:GetService("ServerScriptService")
local cleanup,checks={},{}
local function fresh(name)
 local module=ServerScriptService[name]:Clone()
 module.Name=name.."ThirdGameFixture"
 module.Parent=ServerScriptService
 table.insert(cleanup,module)
 return require(module)
end
local Economy=fresh("PlaygroundEconomyService")
local Coordinator=fresh("PlaygroundCoordinator")
local Admin=fresh("PlaygroundAdminService")
local lobby=workspace["Playground Lobby"]
local function expect(name,condition)
 assert(condition,name)
 table.insert(checks,name)
end
local function folder()
 local item=Instance.new("Folder")
 table.insert(cleanup,item)
 return item
end
local function player(id)
 local attrs={PCDataReady=true}
 local root=Instance.new("Part")
 root.Anchored=true root.Position=lobby.Gameplay.VoteZone.Position
 table.insert(cleanup,root)
 local human={Health=100}
 local board=folder()
 local p={UserId=id,Parent=Players,DisplayName="Test"..id,root=root,humanoid=human}
 function p:GetAttribute(name) return attrs[name] end
 function p:SetAttribute(name,value) attrs[name]=value end
 function p:FindFirstChild(name) return name=="leaderstats" and board or nil end
 p.Character={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root or nil end,
  FindFirstChildOfClass=function(_,name) return name=="Humanoid" and human or nil end}
 return p
end
local function gameService()
 local s={active=false,phase="Waiting",state=folder(),records={}}
 function s:StartRound(roster) self.active=true self.roster=roster return true end
 function s:StartPractice(p,role) self.active=true self.owner=p self.role=role return true end
 function s:StopRound() self.active=false end
 return s
end
local ok,failure=xpcall(function()
 local economy=Economy.new(lobby,{},true)
 table.insert(cleanup,economy.effects)
 expect("Native level one requires200XP",select(3,economy:LevelProgress(0))==200)
 local total=0
 for level=1,10 do
  local cost=200+(level-1)*50
  local current,progress,required=economy:LevelProgress(total)
  expect("Level"..level.." boundary",current==level and progress==0 and required==cost)
  current,progress,required=economy:LevelProgress(total+cost-1)
  expect("Level"..level.." before next boundary",current==level and progress==cost-1 and required==cost)
  total+=cost
 end
 local current,progress,required=economy:LevelProgress(total)
 expect("Ten level transitions sum correctly",current==11 and progress==0 and required==700)
 local winner,loser,outsider,fourth=player(820001),player(820002),player(820003),player(820004)
 local function profile(p)
  local record={player=p,data=Economy.CleanData({}),ready=true,version=0,dirty=false}
  economy.profiles[p]=record return record
 end
 local wp,lp,op=profile(winner),profile(loser),profile(outsider)
 expect("Whole final roster paid",economy:AwardRound("MUD:1",{winner.UserId,outsider.UserId},false,{winner.UserId,loser.UserId,winner.UserId},{winnerXP=50,loserXP=50})==2)
 expect("Winning teammate receives150coins50XP",wp.data.Coins==150 and wp.data.XP==50 and wp.data.Wins==1)
 expect("Losing teammate receives50coins50XP",lp.data.Coins==50 and lp.data.XP==50 and lp.data.Wins==0)
 expect("Unrelated lobby player receives nothing",op.data.Coins==0 and op.data.XP==0)
 expect("Winner toast publishes exact reward",winner:GetAttribute("PCRewardCoins")==150 and winner:GetAttribute("PCRewardXP")==50)
 expect("Loser toast publishes exact reward",loser:GetAttribute("PCRewardCoins")==50 and loser:GetAttribute("PCRewardXP")==50)
 expect("Duplicate result cannot pay twice",economy:AwardRound("MUD:1",{winner.UserId},false,{winner.UserId,loser.UserId})==0 and wp.data.XP==50)
 expect("Practice cannot add coins orXP",economy:AwardRound("MUD:Practice",{winner.UserId},true,{winner.UserId,loser.UserId})==0 and wp.data.Coins==150)
 for round=2,4 do economy:AwardRound("MUD:"..round,{winner.UserId},false,{winner.UserId,loser.UserId}) end
 expect("Four completed rounds reach level2for both outcomes",winner:GetAttribute("PCLevel")==2 and loser:GetAttribute("PCLevel")==2 and wp.data.XP==200 and lp.data.XP==200)
 expect("Level2requires250XP",winner:GetAttribute("PCLevelXP")==0 and winner:GetAttribute("PCLevelXPRequired")==250)
 expect("Normal Bulldog also grants50XP",economy:AwardRound("BB:NewRule",{winner.UserId},false,{winner.UserId,loser.UserId})==2 and wp.data.XP==250 and lp.data.XP==250)
 expect("Normal Tag also grants50XP",economy:AwardRound("TAG:NewRule",{winner.UserId},false,{winner.UserId,loser.UserId})==2 and wp.data.XP==300 and lp.data.XP==300)
 winner:SetAttribute("MDParticipating",true)
 wp.data.Owned.Wave=true wp.data.Equipped.Emote="Wave" wp.lastMutation=-math.huge wp.lastExpression=-math.huge
 expect("Mud participants cannot use lobby emotes",not economy:Handle(winner,"UseEmote","Wave").ok)
 winner:SetAttribute("MDParticipating",false)
 local services={BritishBulldog=gameService(),TagYoureIt=gameService(),StuckInTheMud=gameService()}
 services.StuckInTheMud.state:SetAttribute("GunAccessReady",true)
 local coordinator=Coordinator.new(services,lobby,economy)
 coordinator.state=folder()
 coordinator._readyPlayers=function() return {winner,loser,outsider,fourth} end
 coordinator.random={NextInteger=function(_,minimum) return minimum end}
 coordinator.state:SetAttribute("Phase","Voting")
 expect("Two ready players cannot choose a four-player round",not coordinator:GameAvailable("StuckInTheMud",2))
 expect("Four ready players can choose2v2",coordinator:GameAvailable("StuckInTheMud",4))
 services.StuckInTheMud.state:SetAttribute("GunAccessReady",false)
 expect("Unapproved game cannot enter automatic rotation",not coordinator:GameAvailable("StuckInTheMud",4) and coordinator:_chooseGame()~="StuckInTheMud")
 services.StuckInTheMud.state:SetAttribute("GunAccessReady",true)
 expect("Third game vote accepted in spatial vote zone",coordinator:Vote(winner,"StuckInTheMud").ok)
 expect("Third game tallied",coordinator.state:GetAttribute("VotesStuckInTheMud")==1 and coordinator:_chooseGame()=="StuckInTheMud")
 loser:SetAttribute("MDParticipating",true)
 expect("Mud participant cannot vote for another round",not coordinator:Vote(loser,"TagYoureIt").ok)
 loser:SetAttribute("MDParticipating",false)
 expect("Third normal round receives ready roster",coordinator:StartGame("StuckInTheMud",winner,nil,false) and #services.StuckInTheMud.roster==4)
 expect("Third round blocks concurrent game",not coordinator:StartGame("TagYoureIt",winner,"Runner",false))
 expect("Stopping third game returns lobby state",coordinator:StopGame() and not services.StuckInTheMud.active and coordinator.state:GetAttribute("ActiveGame")=="")
 local admin=Admin.new(coordinator,folder(),true)
 expect("MudShooter admin action starts correct practice",admin:Handle(winner,"MudShooter").ok and services.StuckInTheMud.role=="Shooter" and services.StuckInTheMud.owner==winner)
 admin.lastRequest[winner]=-math.huge
 expect("Admin stops third game",admin:Handle(winner,"StopRound").ok and not services.StuckInTheMud.active)
 admin.lastRequest[winner]=-math.huge
 expect("MudMedic admin action starts correct practice",admin:Handle(winner,"MudMedic").ok and services.StuckInTheMud.role=="Medic")
 services.StuckInTheMud.active=false
 local captured
 coordinator.economy={AwardRound=function(_,key,ids,practice,roster,options) captured={key=key,ids=ids,practice=practice,roster=roster,options=options} end}
 local state=services.StuckInTheMud.state
 state:SetAttribute("LastResultRound",19) state:SetAttribute("LastResultWinnerIds",tostring(winner.UserId))
 state:SetAttribute("LastResultParticipantIds",winner.UserId..","..loser.UserId) state:SetAttribute("LastResultPractice",false)
 coordinator:_rewardMud()
 expect("Mud result integration preserves exact winner and roster",captured.key=="MUD:19" and #captured.ids==1 and captured.ids[1]==winner.UserId and #captured.roster==2 and not captured.practice)
 expect("Mud result integration enforces50XPfor all",captured.options.winnerXP==50 and captured.options.loserXP==50)
 state:SetAttribute("LastResultPractice",true) coordinator:_rewardMud()
 expect("Practice result remains marked practice",captured.practice)
end,debug.traceback)
for _,item in ipairs(cleanup) do item:Destroy() end
assert(ok,failure)
return {passed=#checks,checks=checks,externalProfileWrites=0}
