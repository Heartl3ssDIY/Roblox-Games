from pathlib import Path
root=Path(__file__).resolve().parents[1]
controller=(root/'After/EmoteWheel.Controller.client.luau').read_text()
installer=(root/'CreateEmoteWheelUI.luau').read_text().replace('local StarterGui = game:GetService("StarterGui")','local StarterGui = folder')
button=controller[controller.index('local function buttonState'):controller.index('local function restoreSelection')]
images=controller[controller.index('local function imageState'):controller.index('render = function()')]
render=controller[controller.index('render = function()'):controller.index('local function acceptStatus')]
body='''local passed,result=xpcall(function()
local gui=script.Parent:WaitForChild("PlaygroundEmoteWheel")
local panel=gui.Panel
local toggle=gui.Toggle
local clock=100
local os={clock=function()return clock end}
local player={attrs={PCEmoteAction="E03"},GetAttribute=function(self,key)return self.attrs[key]end}
local UserInputService={TouchEnabled=false}
local function gamepadActive()return false end
local playing=false
local function isPlaying()return playing end
local alive,ready,busy=true,true,false
local page,pageCount=1,1
local notice,noticeUntil="",0
local dances,slots={},{}
local catalog={Items={}}
local owned,equipped={},{Emote="E05"}
for i=1,10 do
 local id="E"..string.format("%02d",i)
 table.insert(catalog.Items,{id=id,name="Dance "..i,slot="Emote",playable=true,available=true,thumbnail="rbxassetid://1"})owned[id]=true
end
for i=1,8 do local button=panel.Wheel:FindFirstChild("Slot"..i)table.insert(slots,{button=button,selected=button:WaitForChild("Selected"),generation=0,imageStatus=""})end
local authored={}
for _,obj in ipairs(gui:GetDescendants())do if obj:IsA("GuiObject")then authored[obj]={obj.Position,obj.Size}end end
local render
__BUTTON__
__IMAGES__
__RENDER__
local checks=0
local function check(value,message)assert(value,message)checks+=1 end
render()
check(typeof(slots[1].button.Selected)=="boolean" and slots[1].selected:IsA("ImageLabel"),"Native Selected collision bypassed by cached child")
check(panel.PageLabel.Text=="1 / 2" and slots[8].button.ItemName.Text=="Dance 8","Actual native UI binds eight card labels")
check(slots[5].button.State.Text=="LOADING IMAGE" or slots[5].button.State.Text=="PODIUM EMOTE","Native thumbnail state renders without service dependency")
check(panel.Next.Active and not panel.Previous.Active,"Native pagination interactability")
playing=true render()
check(slots[3].selected.Visible and slots[3].button.State.Text=="PLAYING","Active emote selection uses authored native child")
check(panel.StopButton.Visible and panel.StopButton.Active,"Native Stop UI state")
page=2 render()
check(slots[1].button.Visible and slots[2].button.Visible and not slots[3].button.Visible,"Last page hides empty slots")
check(slots[1].button.ItemName.Text=="Dance 9" and panel.PageLabel.Text=="2 / 2","Native second page maps correct items")
busy=true render()check(not slots[1].button.Active and not panel.StopButton.Active,"Busy state disables conflicting controls")
busy=false ready=false render()check(not slots[1].button.Active,"Profile loading disables playback")
for obj,state in pairs(authored)do check(obj.Position==state[1] and obj.Size==state[2],"Authored layout unchanged: "..obj.Name)end
return{passed=true,checks=checks}
end,debug.traceback)
return{passed=passed,result=result}
'''.replace('__BUTTON__',button).replace('__IMAGES__',images).replace('__RENDER__',render)
harness='''assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local folder=Instance.new("Folder")folder.Name="EmoteWheelBindings20261005"folder.Parent=game.ServerStorage
local function install()
__INSTALLER__
end
install()
local item=Instance.new("ModuleScript")item.Name="Checks"
item.Capabilities=game.StarterGui.PlaygroundToyHotbar.Controller.Capabilities item.Sandboxed=game.StarterGui.PlaygroundToyHotbar.Controller.Sandboxed
item.Source=__SOURCE__ item.Parent=folder
local ok,result=xpcall(function()return require(item)end,debug.traceback)
folder:Destroy()
return {passed=ok,result=result,fixtureCleaned=game.ServerStorage:FindFirstChild("EmoteWheelBindings20261005")==nil}
'''.replace('__SOURCE__','[====['+body+']====]').replace('__INSTALLER__',installer)
(root/'Tests/WheelNativeBindings.generated.luau').write_text(harness)
print('Native UI binding harness generated')
