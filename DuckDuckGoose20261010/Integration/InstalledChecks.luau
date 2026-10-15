assert(not game:GetService("RunService"):IsRunning(),"Readiness check expects Edit mode")
local count=0
local function check(value,message)count+=1 assert(value,message)end
local function hash(source)
 source=source:gsub("\r\n","\n")
 local value=0 for i=1,#source do value=(value*31+string.byte(source,i))%2147483647 end return value
end
for _,entry in {{path="StarterPlayer.StarterPlayerScripts.BritishBulldogCamera",expected=233641297,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | Players | AvatarBehavior",sandboxed=true},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundLobbyAtmosphere",expected=947370447,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundEmotes",expected=1485311896,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundShell.Controller",expected=297437938,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundShell.PlayerLevelController",expected=1924872173,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundShell.CommerceController",expected=1938774835,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase",sandboxed=true},
{path="StarterGui.PlaygroundAdminPanel.Controller",expected=288410300,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundToyHotbar.Controller",expected=674598432,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundEmoteWheel.Controller",expected=487787175,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundSessionControls.Controller",expected=1835871687,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundDonations.Controller",expected=369871353,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase",sandboxed=true},
{path="StarterGui.PlaygroundFishingHUD.Controller",expected=991157405,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundBatControls.Controller",expected=1263330899,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundIntermissionHUD.Controller",expected=94519385,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Players",sandboxed=true},
{path="ReplicatedStorage.PlaygroundCatalog",expected=989140918,caps="RunClientScript | RunServerScript | Basic",sandboxed=true},
{path="ServerScriptService.PlaygroundAdminService",expected=1190708090,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundCoordinator",expected=1489884087,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundBootstrap",expected=208534973,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | Animation | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AssetRead | Monetization | PromptExternalPurchase | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundEconomyService",expected=1077265464,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundEquipmentService",expected=2136719028,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundToyService",expected=1745467822,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundLobbySwingService",expected=1430572022,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundSecretObbyService",expected=1723726874,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundLobbyBenchService",expected=2053443118,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundFishingService",expected=1009253996,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true},
{path="ServerScriptService.PlaygroundPushService",expected=496784774,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior",sandboxed=true},
{path="StarterGui.PlaygroundPushControls.Controller",expected=1882537479,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | RemoteEvent | Players | AvatarBehavior",sandboxed=true}}do
 local object=game for part in string.gmatch(entry.path,"[^.]+")do object=object:FindFirstChild(part)check(object~=nil,"Missing "..entry.path)end
 check(hash(object.Source)==entry.expected,"Unexpected source: "..entry.path)
 check(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
end
local replicated=game:GetService("ReplicatedStorage")
for _,pair in {{"DuckDuckGooseState","Folder"},{"DuckDuckGooseSprintRequest","RemoteEvent"},{"DuckDuckGooseActionRequest","RemoteEvent"}}do
 check(replicated:FindFirstChild(pair[1])~=nil and replicated[pair[1]]:IsA(pair[2]),"Missing channel: "..pair[1])
end
check(game:GetService("ServerScriptService"):FindFirstChild("DuckDuckGooseService")~=nil,"New service missing")
check(workspace:FindFirstChild("Duck Duck Goose")~=nil,"Fifth island missing")
local sg=game:GetService("StarterGui")
check(sg:FindFirstChild("DuckDuckGooseHUD")~=nil,"New editable HUD missing")
local ids={"BritishBulldog","TagYoureIt","StuckInTheMud","HideAndSeek","DuckDuckGoose"}
for _,name in {"VotePanel","CompactVotePanel"}do
 local panel=sg.PlaygroundShell[name]
 check(panel.Choices:IsA("ScrollingFrame") and panel.Size.Y.Offset==166,"Voting panel layout differs")
 check(panel.Message.Position.Y.Offset==-29 and panel.Choices.DuckDuckGoose.Button:GetAttribute("UISkinAssetKey")=="PNG/07-Resizable-Skins/gold-normal.png","Final authored properties differ")
 check(panel.Choices.ZIndex>panel.ReusableSkin.ZIndex,"Voting cards hidden by background")
 check(panel.ScrollHint.ZIndex>panel.ReusableSkin.ZIndex and panel.ScrollHint.TextStrokeTransparency==1 and panel.ScrollHint.TextScaled==false and panel.ScrollHint.TextSize==13 and not panel.ScrollHint:FindFirstChildWhichIsA("UIStroke",true),"Scroll hint unreadable")
 for _,id in ids do local card=panel.Choices[id]
  check(card.Button.Size.Y.Offset>=44 and card.VoteCount:IsA("TextLabel") and card.Button:FindFirstChild("ArtFallback")~=nil,"Card missing: "..id)
  check(card.Button.LiveCaption.TextScaled and card.Button.LiveCaption.TextWrapped and card.Button.Text=="","Card text regressed: "..id)
 end
end
check(sg.PlaygroundAdminPanel.AdminHub.Pages.Rounds.DuckDuckGoose.DGStart~=nil,"Fifth admin action missing")
local lobby=workspace["Playground Lobby"]
local zone=lobby.Gameplay.VoteZone
for _,id in ids do
 local stand=lobby.VotingAlcove[id.."Stand"]
 local _,size=stand:GetBoundingBox()
 check(math.abs(size.X-11.9)<.02,"Voting stand width changed")
 local trigger=lobby.Gameplay.VoteChoices[id]
 local point=zone.CFrame:PointToObjectSpace(trigger.Position)
 check(math.abs(point.X)+trigger.Size.X/2<=zone.Size.X/2+.01 and math.abs(point.Z)+trigger.Size.Z/2<=zone.Size.Z/2+.01,"Voting pad exceeds alcove")
end
check(not game:GetService("ServerStorage"):FindFirstChild("DuckDuckGooseIntegrationFixture") and not game:GetService("ServerStorage"):FindFirstChild("DuckDuckGooseVotingFixture"),"Temporary fixture remains")
return {passed=true,checks=count,permissionsPreserved=true,playStarted=false}
