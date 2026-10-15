local ss=game:GetService("ServerScriptService")
local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder") fixture.Name="_LeaderboardScopesCapabilityCheck" fixture.Parent=storage
local result
local ok,err=xpcall(function()
 local service=ss.PlaygroundLeaderboardService:Clone() service.Parent=fixture
 local regions=ss.PlaygroundRegions:Clone() regions.Parent=fixture
 local caller=ss.PlaygroundBootstrap:Clone() caller.Disabled=true caller.Parent=fixture
 local remote=Instance.new("RemoteFunction") remote.Name="Probe" remote.Parent=fixture
 local check=Instance.new("ModuleScript") check.Name="Check" check.Parent=caller
 check.Source=[==[
 local root=script.Parent.Parent
 local Service=require(root.PlaygroundLeaderboardService)
 local Regions=require(root.PlaygroundRegions)
 assert(Regions.Resolve("GB").id=="Europe")
 assert(Regions.Resolve("US").id=="NorthAmerica")
 assert(Regions.Resolve("XX")==nil)
 local service=Service.new(workspace["Playground Lobby"],{resolveRegion=function()return Regions.Resolve("GB")end})
 local player=game:GetService("Players"):GetPlayers()[1]
 local global=service:GetSnapshot(player,"global")
 local server=service:GetSnapshot(player,"server")
 local region=service:GetSnapshot(player,"region")
 assert(global.scope=="global" and global.state=="loading")
 assert(server.scope=="server" and server.boards.MostWins)
 assert(region.scope=="region" and region.state=="unavailable")
 local remoteOk,remoteError=pcall(function()
  root.Probe.OnServerInvoke=function(_,scope)return service:GetSnapshot(player,scope)end
  root.Probe.OnServerInvoke=nil
 end)
 assert(remoteOk or tostring(remoteError):find("only be implemented on the server",1,true),tostring(remoteError))
 local lookupOk,lookup=pcall(function()return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(player)end)
 if not lookupOk then assert(not tostring(lookup):find("lacking capability",1,true),tostring(lookup))end
 return {passed=true,global=global.state,server=server.state,unknownRegion=region.state,regionAPI=lookupOk and "available" or "lookup unavailable",lookedUpRegion=lookupOk and Regions.Resolve(lookup) and Regions.Resolve(lookup).name or nil}
 ]==]
 result=require(check)
end,debug.traceback)
fixture:Destroy()
assert(ok,err)
return result
