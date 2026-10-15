assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local count=0
local function check(v,name)assert(v,name)count+=1 end
local function hash(source)local v=0 for i=1,#source do v=(v*31+source:byte(i))%2147483647 end return v end
local backup=assert(game.ServerStorage:FindFirstChild("SkippingRopeIntegrationBackup20261012"))
for _,e in {{path="ServerScriptService.PlaygroundEconomyService",hash=1393665713,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundEquipmentService",hash=1549151859,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | AvatarAppearance | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundToyService",hash=740547870,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundLobbySwingService",hash=1801779865,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundSecretObbyService",hash=155311894,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundLobbyBenchService",hash=988410324,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundFishingService",hash=2035572153,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundPushService",hash=990221292,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundLobbyAtmosphere",hash=948396902,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundEmotes",hash=172958710,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.Controller",hash=588620915,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.PlayerLevelController",hash=962124834,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.CommerceController",hash=28431319,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase"},
{path="StarterGui.PlaygroundToyHotbar.Controller",hash=608398963,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundEmoteWheel.Controller",hash=1939439794,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundDonations.Controller",hash=954980157,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase"},
{path="StarterGui.PlaygroundFishingHUD.Controller",hash=1284752741,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundPushControls.Controller",hash=815215349,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | RemoteEvent | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundIntermissionHUD.Controller",hash=948338216,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Players"},
{path="ServerScriptService.PlaygroundBootstrap",hash=1473166155,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | Animation | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AssetRead | Monetization | PromptExternalPurchase | AvatarBehavior"},
{path="ServerScriptService.PlaygroundCoordinator",hash=1977880787,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundAdminService",hash=922448998,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundAdminPanel.Controller",hash=1050888514,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ReplicatedStorage.PlaygroundCatalog",hash=60276395,caps="RunClientScript | RunServerScript | Basic"},
{path="StarterGui.PlaygroundSessionControls.Controller",hash=1003719507,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.BritishBulldogCamera",hash=2040219094,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | Players | AvatarBehavior"}} do
 local o=game for name in e.path:gmatch("[^.]+")do o=assert(o:FindFirstChild(name),e.path)end
 local old=backup:FindFirstChild(e.path:gsub("%.","_"))
 check(old~=nil,"Backup exists: "..e.path)
 check(hash(o.Source)==e.hash,"Installed source: "..e.path)
 check(tostring(o.Capabilities)==e.caps and o.Sandboxed==old.Sandboxed,"Permissions preserved: "..e.path)
end
local ids={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose","SkippingRope"}
for _,name in {"VotePanel","CompactVotePanel"}do
 local p=game.StarterGui.PlaygroundShell[name]
 check(p.Choices:IsA("ScrollingFrame"),"Scrollable voting")
 check(p.Choices.SkippingRope.Button.LiveCaption.Text=="SKIPPING\nROPE","Sixth caption")
 check(p.Choices.CanvasSize.X.Offset>=p.Choices.SkippingRope.Position.X.Offset+p.Choices.SkippingRope.Size.X.Offset,"Sixth card reachable")
 for _,id in ids do check(p.Choices[id].Button.Size.Y.Offset>=44,"Touch target: "..id)end
 check(p.ScrollHint.Text=="SWIPE OR SCROLL FOR ALL 6 GAMES","Sixth choice discoverability")
end
local rounds=game.StarterGui.PlaygroundAdminPanel.AdminHub.Pages.Rounds
check(rounds.AutomaticCanvasSize==Enum.AutomaticSize.Y and rounds.SkippingRope.LayoutOrder==6 and rounds.RoundSettings.LayoutOrder==7,"Admin scroll accommodates sixth game")
check(rounds.SkippingRope.SKStart.LiveCaption.Text=="START SKIPPING ROUND","Authored admin action")
local lobby=workspace["Playground Lobby"]
local zone=lobby.Gameplay.VoteZone
local boxes={}
for _,id in ids do
 local stand=lobby.VotingAlcove[id.."Stand"]
 local cf,size=stand:GetBoundingBox()
 local p=zone.CFrame:PointToObjectSpace(cf.Position)
 check(math.abs(p.X)+size.X/2<=zone.Size.X/2 and math.abs(p.Z)+size.Z/2<=zone.Size.Z/2,"Stand inside alcove: "..id)
 local trigger=lobby.Gameplay.VoteChoices[id]
 check(trigger:GetAttribute("GameId")==id and math.abs(trigger.Position.X-cf.Position.X)<0.01 and math.abs(trigger.Position.Z-cf.Position.Z)<0.01,"Voting trigger aligned: "..id)
 for _,other in boxes do check(math.abs(cf.Position.X-other.cf.Position.X)>(size.X+other.size.X)/2 or math.abs(cf.Position.Z-other.cf.Position.Z)>(size.Z+other.size.Z)/2,"No voting stand overlap")end
 table.insert(boxes,{cf=cf,size=size})
end
check(game.ServerScriptService:FindFirstChild("SkippingRopeService")~=nil and game.ReplicatedStorage:FindFirstChild("SkippingRopeMath")~=nil,"Service and math installed")
check(game.ReplicatedStorage.SkippingRopeState:GetAttribute("Phase")=="Waiting","Edit state remains idle")
check(game.StarterGui:FindFirstChild("SkippingRopeHUD")~=nil,"Sixth game HUD installed")
check(not game.ServerStorage:FindFirstChild("SkippingRopeFullCycleModules") and not workspace:FindFirstChild("SkippingRopeFullCycleFixture"),"Fixture removed")
return {passed=true,checks=count,permissionsPreserved=true,playStarted=false}
