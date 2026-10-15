from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'After/PlaygroundEconomyService.luau').read_text()
assert source.count('StopEmote = true')==1
assert source.index('if action == "StopEmote" then')<source.index('if now - profile[key]')
body='''assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("ModuleScript") fixture.Name="EmoteWheelStopChecks20261005"
local live=game.ServerScriptService.PlaygroundEconomyService
fixture.Capabilities=live.Capabilities fixture.Sandboxed=live.Sandboxed
fixture.Source=__SOURCE__ fixture.Parent=game.ServerStorage
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local ok,result=xpcall(function()
 local Economy=require(fixture)
 local player={attrs={PCEmoteAction="E01",PCEmoteUntil=workspace:GetServerTimeNow()+30,PCEmoteAnimationId="rbxassetid://123",PCEmote="E05",PCEquippedEmoteAnimationId="rbxassetid://456",PCEmoteSerial=9},GetAttribute=function(self,k)return self.attrs[k]end,SetAttribute=function(self,k,v)self.attrs[k]=v end}
 local profile={ready=true,closed=false,released=false,lastMutation=os.clock(),lastStatus=os.clock(),lastExpression=os.clock(),data={Equipped={Emote="E05"},Owned={E01=true,E05=true},Coins=333,XP=124}}
 local economy=setmetatable({profiles={[player]=profile}},Economy)
 function economy:Status(p,ok,message)return {ok=ok,message=message,equipped=table.clone(profile.data.Equipped),ready=profile.ready}end
 function economy:_touch()error("Stop must not mutate saved profile")end
 function economy:_applyAppearance()error("Stop must not change equipment")end
 local mutation,expression=profile.lastMutation,profile.lastExpression
 local reply=economy:Handle(player,"StopEmote")
 check(reply.ok==true,"Stop immediately after Use bypasses shared mutation throttle")
 check(player.attrs.PCEmoteUntil==0 and player.attrs.PCEmoteAction=="" and player.attrs.PCEmoteAnimationId=="","Stop clears playback fields")
 check(profile.data.Equipped.Emote=="E05" and reply.equipped.Emote=="E05","Stop keeps equipped podium emote")
 check(player.attrs.PCEmote=="E05" and player.attrs.PCEquippedEmoteAnimationId=="rbxassetid://456","Equipped attributes remain unchanged")
 check(player.attrs.PCEmoteSerial==9,"Stop does not create new playback serial")
 check(profile.lastMutation==mutation and profile.lastExpression==expression,"Stop cannot reset purchase or expression cooldowns")
 check(profile.data.Coins==333 and profile.data.XP==124 and profile.data.Owned.E01==true,"Stop preserves inventory and balances")
 check(economy:Handle(player,"StopEmote").ok==true,"Repeated Stop is idempotent")
 player.attrs.PCEmoteUntil=500 player.attrs.PCEmoteAction="E01" player.attrs.PCEmoteAnimationId="rbxassetid://123"
 check(economy:Handle(player,"StopEmote","E99").ok==true and profile.data.Equipped.Emote=="E05","Extraneous item ID cannot alter equipment")
 profile.ready=false
 check(economy:Handle(player,"StopEmote").ok==false,"Existing profile readiness gate preserved")
 profile.ready=true profile.closed=true
 check(economy:Handle(player,"StopEmote").ok==false,"Closed session gate preserved")
 profile.closed=false profile.released=true
 check(economy:Handle(player,"StopEmote").ok==false,"Released session gate preserved")
 profile.released=false
 check(economy:Handle(player,"UnknownAction").ok==false,"Unknown action rejection preserved")
 return {passed=true,checks=checks}
end,debug.traceback)
fixture:Destroy()
return {passed=ok,result=result,fixtureCleaned=game.ServerStorage:FindFirstChild("EmoteWheelStopChecks20261005")==nil}
'''.replace('__SOURCE__','[====['+source+']====]')
(root/'Tests/StopNativeChecks.generated.luau').write_text(body)
print('Stop harness generated')
