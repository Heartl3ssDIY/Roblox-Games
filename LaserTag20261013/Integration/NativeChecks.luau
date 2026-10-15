assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local checks={}
local function check(name,condition) assert(condition,name) table.insert(checks,name) end
local fixture=Instance.new("Folder") fixture.Name="LaserTagIntegrationFixture" fixture.Parent=game.ServerStorage
local ok,result=xpcall(function()
 local players={roster={}}
 function players:GetPlayers() return self.roster end
 function players:GetPlayerByUserId(id) for _,p in self.roster do if p.UserId==id then return p end end end
 local function module(name,inject)
  local m=game.ServerScriptService[name]:Clone()
  if inject then
   m.Source="return function(fakePlayers)\n"..m.Source:gsub('local Players = game:GetService%("Players"%)',"local Players = fakePlayers",1).."\nend"
  end
  m.Parent=fixture
  return inject and require(m)(players) or require(m)
 end
 local Coordinator=module("PlaygroundCoordinator",true)
 local Admin=module("PlaygroundAdminService",false)
 local Economy=module("PlaygroundEconomyService",false)
 local state=Instance.new("Folder") state.Parent=fixture state:SetAttribute("Phase","Playing")
 local arena=Instance.new("Folder") arena.Parent=fixture arena:SetAttribute("MinimumPlayers",2)
 local service={active=true,running=true,state=state,arena=arena,phase="Playing"}
 local c=setmetatable({services={StuckInTheMud=service},spectators={},lastSpectateStamp={},lastSpectateRequest={},votes={},state=Instance.new("Folder"),autoEnabled=true},Coordinator)
 c.state.Parent=fixture
 local function player(id,participating,eliminated)
  local p={UserId=id,Name="Fixture"..id,DisplayName="Fixture"..id,Parent=players,attrs={MDParticipating=participating,MDEliminated=eliminated,MDLives=eliminated and 0 or 3,PCDataReady=true}}
  function p:GetAttribute(name) return self.attrs[name] end
  function p:SetAttribute(name,value) self.attrs[name]=value end
  function p:AddReplicationFocus(root) self.focus=root end
  function p:RemoveReplicationFocus() self.focus=nil end
  local model=Instance.new("Model") model.Parent=fixture
  local hum=Instance.new("Humanoid") hum.RequiresNeck=false hum.Parent=model
  local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Anchored=true root.Parent=model
  p.Character=model table.insert(players.roster,p) return p
 end
 local red=player(991401,true,false)
 local blue=player(991402,true,false)
 local out=player(991403,true,true)
 local lobby=player(991404,false,false)
 check("Alive players cannot use spectator camera",c:_spectateTarget(red,blue.UserId)==nil)
 check("Eliminated players can watch a live opponent",c:_spectateTarget(out,blue.UserId)==blue)
 check("Eliminated players cannot be watched",c:_spectateTarget(lobby,out.UserId)==nil)
 check("Lobby players can still spectate",c:_spectateTarget(lobby,red.UserId)==red)
 check("Eliminated players remain round participants",c:_participating(out))
 check("Cannot spectate yourself",c:_spectateTarget(out,out.UserId)==nil)
 state:SetAttribute("Phase","Results")
 check("Results ends spectating eligibility",c:_spectateTarget(out,blue.UserId)==nil)
 state:SetAttribute("Phase","Playing")
 service.active=false
 local otherState=Instance.new("Folder") otherState.Parent=fixture otherState:SetAttribute("Phase","Playing")
 c.services.TagYoureIt={active=true,state=otherState}
 check("An old eliminated flag cannot bypass another game",c:_spectateTarget(out,blue.UserId)==nil)
 c.services.TagYoureIt=nil service.active=true
 out:SetAttribute("PCAFKRequested",true)
 c.spectators[out]={root=blue.Character.HumanoidRootPart}
 c:_syncAFK(out)
 check("AFK remains queued during elimination",out:GetAttribute("PCAFKQueued")==true and out:GetAttribute("PCAFK")==false)
 check("Queued AFK does not kick eliminated spectator",c.spectators[out]~=nil)
 check("Normal minimum is two",c:MinimumPlayers("StuckInTheMud")==2)
 arena:SetAttribute("MinimumPlayers",nil)
 check("Default minimum remains two",c:MinimumPlayers("StuckInTheMud")==2)
 local called
 c.StartGame=function(_,id,p,role) called={id=id,player=p,role=role} return true end
 c.StopGame=function() return true end
 local config=Instance.new("Folder") config:SetAttribute("AdminUserId",red.UserId) config.Parent=fixture
 local admin=Admin.new(c,config,false,players)
 admin.Status=function(_,_,success,message) return {ok=success,message=message} end
 check("Admin laser start uses existing game id",admin:Handle(red,"MudStart").ok and called.id=="StuckInTheMud" and called.role==nil)
 admin.lastRequest[red]=nil
 check("Red practice remains reachable",admin:Handle(red,"MudShooter").ok and called.role=="Shooter")
 admin.lastRequest[red]=nil
 check("Blue practice remains reachable",admin:Handle(red,"MudMedic").ok and called.role=="Medic")
 check("Non-admin cannot start laser practice",not admin:Handle(blue,"MudShooter").ok)
 local profiles={}
 for _,p in players.roster do profiles[p.UserId]={ready=true,data={Coins=0,XP=0,Wins=0,GameWins={StuckInTheMud=7}}} end
 local economy=setmetatable({awarded={}},Economy)
 function economy:_profileByUserId(id) return profiles[id] end
 function economy:_setting(_,fallback) return fallback end
 function economy:_earnedCoins(_,amount) return amount end
 function economy:_earnedXP(_,amount) return amount end
 function economy:_touch() end
 function economy:_publishReward() end
 c.economy=economy
 state:SetAttribute("LastResultRound",301)
 state:SetAttribute("LastResultWinnerIds",tostring(red.UserId))
 state:SetAttribute("LastResultParticipantIds",red.UserId..","..blue.UserId)
 state:SetAttribute("LastResultPractice",false)
 c:_rewardMud()
 check("Laser win preserves existing unlock progress",profiles[red.UserId].data.GameWins.StuckInTheMud==8)
 check("Winners receive existing rewards",profiles[red.UserId].data.Coins==150 and profiles[red.UserId].data.XP==50 and profiles[red.UserId].data.Wins==1)
 check("Other team receives participation rewards",profiles[blue.UserId].data.Coins==50 and profiles[blue.UserId].data.XP==50 and profiles[blue.UserId].data.Wins==0)
 c:_rewardMud()
 check("Repeated result cannot duplicate rewards",profiles[red.UserId].data.Coins==150)
 state:SetAttribute("LastResultRound",302) state:SetAttribute("LastResultPractice",true) c:_rewardMud()
 check("Laser practice awards no coins, XP or wins",profiles[red.UserId].data.Coins==150 and profiles[red.UserId].data.XP==50 and profiles[red.UserId].data.Wins==1)
 local src=game.StarterGui.PlaygroundSessionControls.Controller.Source
 local first=assert(src:find("local function inRound()",1,true))
 local last=assert(src:find("local function compactLayout()",first,true))
 local m=Instance.new("ModuleScript")
 m.Source="return function(player,state,participatingNames)\n"..src:sub(first,last-1).."\nreturn inRound,canSpectate\nend"
 m.Parent=fixture
 local clientState=Instance.new("Folder") clientState.Parent=fixture clientState:SetAttribute("ActiveGame","StuckInTheMud")
 local flags={"BBParticipating","TGParticipating","MDParticipating","HSParticipating","DGParticipating","SKParticipating","SKEliminated"}
 local stillIn,canWatch=require(m)(out,clientState,flags)
 check("Client keeps eliminated membership but exposes spectate",stillIn() and canWatch())
 out:SetAttribute("MDEliminated",false) check("Client hides watch for live laser players",not canWatch())
 out:SetAttribute("MDEliminated",true) clientState:SetAttribute("ActiveGame","TagYoureIt")
 check("Client spectator exception is laser only",not canWatch())
 out:SetAttribute("MDParticipating",false) check("Lobby spectating remains enabled",canWatch())
 return {passed=true,count=#checks,checks=checks}
end,debug.traceback)
fixture:Destroy()
assert(ok,result)
return result
