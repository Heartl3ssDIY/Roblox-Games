local checks=0
local function check(value,message)assert(value,message)checks+=1 end
local function input(key,state)return fakeCAS.callback("test",state or Enum.UserInputState.Begin,{KeyCode=key})end
local function status()
 local inventory={}for i=1,20 do inventory["E"..string.format("%02d",i)]=true end
 inventory.E18=nil
 return{ok=true,ready=true,owned=inventory,equipped={Emote="E05"},message=""}
end
check(fakeSG.native==false and nativeSuppressed,"Native emote menu suppressed")
check(#pending==1 and pending[1].action=="GetStatus","Initial status refresh")
complete(pending[1],status())
check(ready and #dances==16 and pageCount==2,"Owned playable available Emotes only, eight per page")
check(slots[7].item.id=="E08" and slots[8].item.id=="E09","Sparse removed E07 omitted without shifting IDs")
check(slots[5].button.State.Text=="PODIUM EMOTE","Equipped podium label preserved")
fakeUIS.focus={}check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and not panel.Visible,"Typing does not open wheel")fakeUIS.focus=nil
fakeGS.MenuIsOpen=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass,"Escape menu has priority")fakeGS.MenuIsOpen=false
shell.ShopPanel.Visible=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and not panel.Visible,"Shop modal blocks opening")shell.ShopPanel.Visible=false
fakePlayer.attrs.BBParticipating=true check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass,"Round blocks input")fakePlayer.attrs.BBParticipating=nil
local external=object("PriorSelection",fakePlayer.PlayerGui)fakeGS.SelectedObject=external
fakeUIS.input=Enum.UserInputType.Gamepad1
check(input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Sink and panel.Visible,"DPadDown opens wheel")
check(fakeGS.SelectedObject==slots[1].button,"Gamepad starts on first owned slot")
check(input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Pass and panel.Visible,"DPadDown while open navigates rather than closing")
advance(.21)complete(pending[#pending],status())
input(Enum.KeyCode.ButtonR1)
check(page==2 and slots[1].item.id=="E10","Right bumper selects next page")
input(Enum.KeyCode.ButtonL1)check(page==1,"Left bumper selects previous page")
input(Enum.KeyCode.ButtonB)
check(not panel.Visible and fakeGS.SelectedObject==external,"Close restores previous gamepad selection")
fakeUIS.input=Enum.UserInputType.Keyboard
advance(.3)input(Enum.KeyCode.Period)complete(pending[#pending],status())
input(Enum.KeyCode.Three)
local play=pending[#pending]
check(play.action=="UseEmote" and play.id=="E03","Number key invokes UseEmote without Equip")
local reply=status()complete(play,reply)
check(not panel.Visible and equipped.Emote=="E05","Successful dance closes wheel preserving podium choice")
advance(.3)setOpen(true)complete(pending[#pending],status())
fakePlayer:SetAttribute("PCEmotePlaybackStatus","loading")fakePlayer:SetAttribute("PCEmoteUntil",clock+30)fakePlayer:SetAttribute("PCEmoteAction","E03")
check(panel.StopButton.Visible and panel.StopButton.Active,"Stop available while real playback is loading")
panel.StopButton.Activated:Fire()local stopping=pending[#pending]
check(stopping.action=="StopEmote" and stopping.id==nil,"Stop uses dedicated action")complete(stopping,status())
fakePlayer:SetAttribute("TGParticipating",true)
check(not panel.Visible,"Entering a round closes existing wheel")fakePlayer:SetAttribute("TGParticipating",false)
advance(.3)request("GetStatus")local stalled=pending[#pending]local thread=stalled.thread
advance(8.1)
check(not busy and coroutine.status(thread)=="dead","Hung InvokeServer worker cancelled after bounded timeout")
check(not complete(stalled,{ok=true,ready=true,owned={},equipped={}}),"Expired callback cannot overwrite ownership")
advance(.3)request("GetStatus")local retry=pending[#pending]complete(retry,status())
check(ready and #dances==16 and not busy,"Fresh request recovers after timeout")
local accepted=acceptStatus({ok=false,ready=true,owned=status().owned,equipped={Emote="E05"},message="Please wait"})
check(accepted and ready,"Throttled GetStatus still supplies valid ownership state")
setOpen(true)advance(.3)if busy then complete(pending[#pending],status())end
fakeGui.Enabled=false fakeGui:GetPropertyChangedSignal("Enabled"):Fire()
check(not panel.Visible,"Disabling GUI closes panel")
check(input(Enum.KeyCode.Period)==Enum.ContextActionResult.Pass and input(Enum.KeyCode.DPadDown)==Enum.ContextActionResult.Pass,"Disabled wheel relinquishes keyboard and gamepad controls")fakeGui.Enabled=true
local imageRecord=slots[1]imageRecord.button.Thumbnail.IsLoaded=false
imageRecord.imageStartedAt=nil imageState(imageRecord)
advance(9)
check(imageRecord.imageStartedAt==nil,"Hidden wheel does not expire thumbnail grace before display")
setOpen(true)if busy then complete(pending[#pending],status())end
check(imageRecord.imageStatus=="LOADING IMAGE","Visible unloaded thumbnail starts honest loading grace")
advance(8.1)
check(imageRecord.imageStatus=="IMAGE UNAVAILABLE","Visible thumbnail timeout is reported without preload service")
imageRecord.button.Thumbnail.IsLoaded=true imageRecord.button.Thumbnail:GetPropertyChangedSignal("IsLoaded"):Fire()
check(imageRecord.imageStatus=="","Late native ImageLabel success clears timeout status")
advance(.3)request("GetStatus")local destroyThread=pending[#pending].thread
fakeScript.Destroying:Fire()
check(not alive and coroutine.status(destroyThread)=="dead","Destroy cancels outstanding request")
check(fakeSG.native==true and fakeCAS.unbound==actionName,"Destroy restores original native menu and unbinds action")
check(not panel.Visible and not backdrop.Visible,"Destroy clears wheel and backdrop")
check(not complete(pending[#pending],status()),"Destroyed controller rejects later callback")
return {passed=true,checks=checks,nativeContentProviderAvailable=NativeContentProvider~=nil}
