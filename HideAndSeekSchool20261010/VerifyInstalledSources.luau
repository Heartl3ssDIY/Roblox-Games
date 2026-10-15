assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local entries={
{path="ServerScriptService.PlaygroundCoordinator",fingerprint=662588760,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundEquipmentService",fingerprint=820718013,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundToyService",fingerprint=963687303,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundSecretObbyService",fingerprint=1063533538,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundLobbySwingService",fingerprint=315901621,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundLobbyBenchService",fingerprint=828896024,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundFishingService",fingerprint=903229343,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundAdminService",fingerprint=113600455,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundEconomyService",fingerprint=722271444,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ReplicatedStorage.PlaygroundCatalog",fingerprint=123409695,caps="RunClientScript | RunServerScript | Basic"},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundEmotes",fingerprint=1191040418,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundPets",fingerprint=1443904266,caps="RunClientScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.BritishBulldogCamera",fingerprint=702184026,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | Players | AvatarBehavior"},
{path="StarterPlayer.StarterPlayerScripts.PlaygroundLobbyAtmosphere",fingerprint=72206850,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.Controller",fingerprint=1987061700,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.PlayerLevelController",fingerprint=66057700,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundShell.CommerceController",fingerprint=1901192957,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase"},
{path="StarterGui.PlaygroundIntermissionHUD.Controller",fingerprint=1058767317,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Players"},
{path="StarterGui.PlaygroundFishingHUD.Controller",fingerprint=1508620414,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | Animation | AvatarAppearance | Environment | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundDonations.Controller",fingerprint=549581783,caps="RunClientScript | AccessOutsideWrite | Basic | UI | Input | RemoteEvent | Players | AssetRead | Monetization | PromptExternalPurchase"},
{path="StarterGui.PlaygroundBatControls.Controller",fingerprint=1931980630,caps="RunClientScript | AccessOutsideWrite | Basic | Physics | UI | Input | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundSessionControls.Controller",fingerprint=1535613685,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundEmoteWheel.Controller",fingerprint=672833248,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundToyHotbar.Controller",fingerprint=279969308,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="StarterGui.PlaygroundAdminPanel.Controller",fingerprint=1705551231,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | Physics | UI | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AvatarBehavior"},
{path="ServerScriptService.PlaygroundBootstrap",fingerprint=1285146170,caps="RunClientScript | RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Audio | DataStore | Physics | UI | Animation | AvatarAppearance | Input | Environment | RemoteEvent | LegacySound | Players | AssetRead | Monetization | PromptExternalPurchase | AvatarBehavior"},
}
local function fingerprint(source)
 source=source:gsub("\r\n","\n"):gsub("\n+$","")
 local n=0 for i=1,#source do n=(n*31+source:byte(i))%2147483647 end return n
end
for _,entry in entries do
 local object=game for name in entry.path:gmatch("[^.]+")do object=assert(object:FindFirstChild(name),"Missing "..entry.path) end
 assert(object:GetAttribute("HideAndSeekIntegrated20261010")==true,"Not installed: "..entry.path)
 assert(fingerprint(object.Source)==entry.fingerprint,"Source mismatch: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps,"Permissions changed: "..entry.path)
end
assert(#game.ServerStorage.HideAndSeekIntegrationBackup20261010:GetChildren()==#entries,"Incomplete backups")
for name,count in {["British Bulldog game"]=698,["Tag You\'re It"]=1109,["Stuck in the Mud"]=2793}do local n=0 for _,o in workspace[name]:GetDescendants()do if o:IsA("BasePart")then n+=1 end end assert(n==count,"Existing map changed: "..name) end
return{verifiedSources=#entries,capabilitiesPreserved=true,backupsComplete=true,originalMapsUnchanged=true,playStarted=false}
