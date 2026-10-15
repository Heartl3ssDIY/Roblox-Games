local config=assert(loadstring(game.ReplicatedStorage.ArenaConfig.Source))()
local originalGame=game;local originalRequire=require
local travel={}
local events={FindFirstChild=function() return travel end}
local replicated={WaitForChild=function(_,name) if name=="ArenaEvents" then return events end return originalGame.ReplicatedStorage[name] end}
local added=Instance.new("BindableEvent");local removed=Instance.new("BindableEvent")
local fakePlayers={PlayerAdded=added.Event,PlayerRemoving=removed.Event,GetPlayers=function() return {} end}
local fakeGame={GetService=function(_,name) if name=="Players" then return fakePlayers elseif name=="ReplicatedStorage" then return replicated end error(name) end}
local clockTime=10
local env=setmetatable({game=fakeGame,require=function(m) if m.Name=="ArenaConfig" then return config end return originalRequire(m) end,os={clock=function() return clockTime end}},{__index=getfenv()})
local f=assert(loadstring(game.ServerScriptService.ArenaTravelService.Source));setfenv(f,env);f()
local character=Instance.new("Model");local humanoid=Instance.new("Humanoid");humanoid.Parent=character
local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Parent=character
local attrs={};local fakePlayer={Character=character,SetAttribute=function(_,k,v) attrs[k]=v end}
local start=CFrame.new(2,30,4);local out={}
local catalog=assert(loadstring(originalGame.ReplicatedStorage.ArenaCatalog.Source))()
for _,entry in ipairs(catalog.ordered) do
 root.CFrame=start;root.Anchored=false;clockTime+=1
 local ok,reason=travel.OnServerInvoke(fakePlayer,"Visit",entry.modelName);assert(ok,reason)
 assert(attrs.ActiveArena==entry.modelName and attrs.ArenaVisitOnly==true)
 assert(root.Anchored and (root.Position-(workspace[entry.modelName].Sidelines.Spawn_Player.Position+Vector3.new(0,3,0))).Magnitude<.001)
 assert(travel.OnServerInvoke(fakePlayer,"Leave"));assert((root.Position-start.Position).Magnitude<.001 and not root.Anchored and attrs.ActiveArena==nil)
 table.insert(out,entry.displayName)
end
clockTime+=1;assert(travel.OnServerInvoke(fakePlayer,"Enter"));assert(attrs.ActiveArena=="Arena_Tenkaichi" and attrs.ArenaVisitOnly==false);travel.OnServerInvoke(fakePlayer,"Leave")
clockTime+=1;assert(travel.OnServerInvoke(fakePlayer,"Enter","Arena_Wano")==false)
clockTime+=1;assert(travel.OnServerInvoke(fakePlayer,"Visit","Tournament_of_Power_Roblox")==false)
character:Destroy();added:Destroy();removed:Destroy()
return originalGame.HttpService:JSONEncode({roundTrips=out,tenkaichiDefault=true,nonMatchRejected=true,excludedArenaRejected=true})