from pathlib import Path
import json
folder=Path(__file__).resolve().parents[1]
playback=(folder/'CatalogEmotePlayback.luau').read_text()
podium=(folder/'After/PlaygroundPodiumController.client.luau').read_text()
def literal(text):return '[====['+text+']====]'
body='''local Players={}
local clock=0
local os={clock=function()return clock end}
'''+playback+'''
return {SetPlayer=function(player)Players.LocalPlayer=player end,SetClock=function(value)clock=value end,
 Update=updateCatalogEmote,Stop=stopCatalogEmote,Retire=cleanRetiredEmotes,Request=function()return catalogEmote end,Asset=emoteAnimationId}
'''
podiumModule=podium[:podium.index('local gui = script.Parent')]
stop=podium[podium.index('local function stopTrack'):podium.index('local function clearAvatar')]
play=(folder/'PodiumAnimationPlayback.luau').read_text()
podiumModule+='''
local winner
local nativePlayers=Players
Players={GetPlayerByUserId=function()return winner end}
local gui={attrs={},GetAttribute=function(self,key)return self.attrs[key]end}
local alive=true
local packetState="ready"
'''+stop+play+'''
return {Prepare=prepareModel,Stop=stopTrack,Request=requestedAnimation,Update=updateAnimation,
 SetWinner=function(value)winner=value end,SetManual=function(value)gui.attrs.PodiumAnimationId=value end}
'''
assets=json.loads((folder/'Assets.json').read_text(encoding='utf-8-sig'))
asset='rbxassetid://'+next(a['animationId'] for a in assets if a['playable'])
harness='''local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder") fixture.Name="EmoteClientChecks20261005" fixture.Parent=workspace
local result={passed=false,checks=0}
local function check(value,message) assert(value,message) result.checks+=1 end
local ok,err=xpcall(function()
 local function module(name,source,live)
  local item=Instance.new("ModuleScript") item.Name=name item.Source=source item.Capabilities=live.Capabilities item.Sandboxed=live.Sandboxed item.Parent=fixture return require(item)
 end
 local api=module("Playback",__PLAYBACK__,game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes)
 local model=storage.WeaponRigFixtures.R15:Clone() model.Name="PlaybackRig" model.Parent=fixture model:PivotTo(CFrame.new(5000,1000,5000))
 local root=model.HumanoidRootPart root.Anchored=true root.AssemblyLinearVelocity=Vector3.zero
 local nativeHumanoid=model:FindFirstChildOfClass("Humanoid")
 local animator=nativeHumanoid:FindFirstChildOfClass("Animator") if not animator then animator=Instance.new("Animator") animator.Parent=nativeHumanoid end
 local state=Enum.HumanoidStateType.Running
 local delayedAnimator=false
 local humanoid={Health=100,PlatformStand=false,RigType=Enum.HumanoidRigType.R15,MoveDirection=Vector3.zero,Jump=false,
  GetState=function()return state end,FindFirstChildOfClass=function()if delayedAnimator then return nil end return animator end}
 local character={Parent=fixture,attrs={},GetAttribute=function(self,key)return self.attrs[key]end,
  FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
 local player={Character=character,attrs={PCDataReady=true},GetAttribute=function(self,key)return self.attrs[key]end,SetAttribute=function(self,key,value)self.attrs[key]=value if key=="PCEmotePlaybackStatus"then self.statusMessage=self.attrs.PCEmotePlaybackMessage end end}
 api.SetPlayer(player)
 local serial=0
 local function start()
  serial+=1 player.attrs.PCEmoteSerial=serial player.attrs.PCEmoteAction="E01" player.attrs.PCEmoteAnimationId=__ASSET__
  player.attrs.PCEmoteStartedAt=100 player.attrs.PCEmoteUntil=130 player.attrs.PCEmoteRigType="R15"
  api.SetClock(0) api.Update(100) task.wait(.15) api.Update(100.15)
 end
 check(api.Asset("rbxassetid://123")=="rbxassetid://123" and api.Asset("https://bad")==nil,"Strict animation URI")
 start()
 local request=api.Request()
 check(request and request.track,"Real Animator track created under exact capabilities")
 check(request.track.IsPlaying and request.track.Length>0,"Verified real animation loads and plays")
 check(request.track.Looped and request.track.Priority==Enum.AnimationPriority.Action,"Loop and priority configured")
 check(player.attrs.PCEmotePlaybackStatus=="playing","Ready status reflects loaded track")
 check(player.statusMessage=="Move or jump to stop dancing","Status publishes after its associated message")
 local track=request.track api.Update(100.2) check(api.Request().track==track,"Same serial creates no duplicate track")
 humanoid.MoveDirection=Vector3.xAxis api.Update(100.3) check(api.Request()==nil and not track.IsPlaying,"Movement stops real track")
 humanoid.MoveDirection=Vector3.zero api.Update(100.4) check(api.Request()==nil,"Stopping input cannot replay consumed serial")
 api.Retire(true)
 for _,reason in ipairs({"jump","death","round","ragdoll","toy","bat","toolAction","expiry","respawn"})do
  start() check(api.Request()~=nil,reason.." fresh serial starts")
  if reason=="jump"then humanoid.Jump=true
  elseif reason=="death"then humanoid.Health=0
  elseif reason=="round"then player.attrs.MDParticipating=true
  elseif reason=="ragdoll"then player.attrs.TGRagdolled=true
  elseif reason=="toy"then character.attrs.PCToyHeld="M01"
  elseif reason=="bat"then character.attrs.PCBatHeld=true
  elseif reason=="toolAction"then player.attrs.PCToyActionAt=101
  elseif reason=="expiry"then player.attrs.PCEmoteUntil=100
  elseif reason=="respawn"then player.Character=nil end
  api.Update(101) check(api.Request()==nil,reason.." cancels playback")
  humanoid.Jump=false humanoid.Health=100 player.attrs.MDParticipating=nil player.attrs.TGRagdolled=nil
  character.attrs.PCToyHeld=nil character.attrs.PCBatHeld=nil player.attrs.PCToyActionAt=nil player.Character=character
  api.Retire(true)
 end
 humanoid.RigType=Enum.HumanoidRigType.R6 start() check(api.Request()==nil,"R6 rejects R15-only animation")humanoid.RigType=Enum.HumanoidRigType.R15
 delayedAnimator=true start() check(api.Request()~=nil and not api.Request().track,"Late server Animator waits without local creation")
 delayedAnimator=false api.Update(100.3)task.wait(.15)api.Update(100.4)check(api.Request().track~=nil,"Late server Animator recovered")api.Stop("Stopped")api.Retire(true)
 delayedAnimator=true start()api.SetClock(9)api.Update(101)check(api.Request()==nil and player.attrs.PCEmotePlaybackStatus=="failed","Bounded Animator timeout with honest status")delayedAnimator=false
 api.Update(102)check(api.Request()==nil,"Timeout does not retry same serial")
 start()check(api.Request()~=nil,"New use request recovers after timeout")api.Stop("Stopped")api.Retire(true)
 local pod=module("Podium",__PODIUM__,game.StarterGui.PlaygroundPodium.Controller)
 local avatarModel=storage.WeaponRigFixtures.R15:Clone()avatarModel.Name="PodiumRig"avatarModel.Parent=fixture
 local avatar=pod.Prepare(avatarModel)
 avatar.model:PivotTo(CFrame.new(5020,1000,5000))
 local slot={userId=1,avatar=avatar,entry={emoteId="E01",emoteAnimationId=__ASSET__,emoteRigType="R15"},display={StatusLabel={Text=""}}}
 check(pod.Request(slot)==__ASSET__,"Offline equipped dance resolves from snapshot")
 pod.SetManual("rbxassetid://999")check(pod.Request(slot)==__ASSET__,"Equipped dance beats manual fallback")
 slot.entry.emoteAnimationId=""check(pod.Request(slot)==nil,"Unavailable equipped dance does not substitute manual animation")
 slot.entry=nil check(pod.Request(slot)=="rbxassetid://999","Manual fallback retained when no equipped emote")
 local winner={attrs={PCDataReady=true,PCEmote="E01",PCEquippedEmoteAnimationId=__ASSET__,PCEquippedEmoteRigType="R15"},GetAttribute=function(self,key)return self.attrs[key]end}
 pod.SetWinner(winner)check(pod.Request(slot)==__ASSET__,"Online winner immediately overrides stale snapshot")
 pod.Update(slot)task.wait(.15)pod.Update(slot)
 check(avatar.track and avatar.track.IsPlaying and avatar.track.Length>0,"Real equipped podium dance plays under exact capabilities")
 local old=avatar.track pod.Update(slot)check(avatar.track==old,"Podium avoids duplicate track loads")
 for cycle=1,5 do
  pod.Stop(avatar)pod.Update(slot)task.wait(.1)pod.Update(slot)
  check(avatar.track and avatar.track.IsPlaying,"Podium resumes after repeated intentional pause "..cycle)
 end
 old=avatar.track
 winner.attrs.PCEmote=nil winner.attrs.PCEquippedEmoteAnimationId=nil pod.SetManual(nil)pod.Update(slot)
 check(avatar.track==nil and not old.IsPlaying,"Unequip stops dance and restores podium pose")
 pod.Stop(avatar)
 result.passed=true result.playbackCapabilities=tostring(game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.Capabilities)
 result.podiumCapabilities=tostring(game.StarterGui.PlaygroundPodium.Controller.Capabilities)
end,debug.traceback)
fixture:Destroy()
result.cleaned=workspace:FindFirstChild("EmoteClientChecks20261005")==nil
if not ok then result.error=err end
return result
'''
harness=harness.replace('__PLAYBACK__',literal(body)).replace('__PODIUM__',literal(podiumModule)).replace('__ASSET__',json.dumps(asset))
(folder/'Tests/ClientNativeChecks.luau').write_text(harness,encoding='utf-8')
print('Native client playback and podium checks prepared')
