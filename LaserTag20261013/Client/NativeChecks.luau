local HttpService = game:GetService("HttpService")
local fixture = Instance.new("Folder")
fixture.Name = "LaserTagClientChecks"
fixture.Parent = game.ServerStorage
local gui = game.StarterGui.MudHUD:Clone()
gui.Parent = fixture
local state = Instance.new("Folder")
state.Parent = fixture
local body = Instance.new("Model")
body.Parent = fixture
local humanoid = Instance.new("Humanoid")
humanoid.Parent = body
local backpack = Instance.new("Backpack")
backpack.Parent = fixture
local heat = Instance.new("Tool")
heat.Name,heat.RequiresHandle = "HeatGun",false
heat:SetAttribute("MDManaged",true)
heat:SetAttribute("MDOwnerUserId",123)
heat:SetAttribute("MDRound",7)
heat:SetAttribute("MDTeamId",1)
heat.Parent = body
local mud = heat:Clone()
mud.Name = "MudGun"
mud:SetAttribute("MDTeamId",2)
local playerGui = Instance.new("Folder")
playerGui.Parent = fixture
local session = Instance.new("ScreenGui")
session.Name,session.Parent = "PlaygroundSessionControls",playerGui
local admin = Instance.new("ScreenGui")
admin.Name,admin.Parent = "PlaygroundAdminPanel",playerGui
local adminHub = Instance.new("Frame")
adminHub.Name,adminHub.Visible,adminHub.Parent = "AdminHub",false,admin
local function signal()
 local handlers = {}
 return {Connect=function(_,fn)
  local connection = {Connected=true}
  function connection:Disconnect() self.Connected=false end
  table.insert(handlers,{connection,fn})
  return connection
 end,Fire=function(_,...) for _,h in ipairs(handlers)do if h[1].Connected then h[2](...)end end end}
end
local attrs = {MDParticipating=true,MDTeamId=1,MDLives=3,MDSprintRemaining=8,MDSprintMax=10}
local player = {Character=body,PlayerGui=playerGui,UserId=123,CharacterAdded=signal(),CharacterRemoving=signal()}
function player:GetAttribute(name) return attrs[name] end
function player:FindFirstChildOfClass(name) return name=="Backpack" and backpack or nil end
local now = 100
state:SetAttribute("Phase","Playing")
state:SetAttribute("RoundNumber",7)
state:SetAttribute("EndsAt",400)
state:SetAttribute("LaserCooldownSeconds",0.5)
state:SetAttribute("RedAlive",4)
state:SetAttribute("BlueAlive",5)
local requests = {}
local remote = {}
function remote:InvokeServer(action,value) table.insert(requests,{action=action,value=value}) return {ok=true} end
local services = {}
services.Players = {LocalPlayer=player}
services.ReplicatedStorage = {WaitForChild=function(_,name) return name=="MudState" and state or remote end}
local ui = {PreferredInput=Enum.PreferredInput.KeyboardAndMouse,MouseBehavior=Enum.MouseBehavior.Default,mouse=Vector2.new(150,140)}
for _,name in ipairs({"InputBegan","InputEnded","InputChanged","WindowFocusReleased","WindowFocused","TextBoxFocused"})do ui[name]=signal()end
ui.changed=signal()
function ui:GetPropertyChangedSignal() return self.changed end
function ui:GetFocusedTextBox() return self.focusedBox end
function ui:GetMouseLocation() return self.mouse end
services.UserInputService=ui
local insets = {MenuIsOpen=false,changed=signal(),origin=Vector2.new(59,0)}
function insets:GetInsetArea(kind)
 return kind==Enum.ScreenInsets.None and Rect.new(-self.origin.X,-58,1000,800) or Rect.new(0,-58,1000,800)
end
function insets:GetPropertyChangedSignal() return self.changed end
services.GuiService=insets
local cas = {bindings={}}
function cas:BindActionAtPriority(name,callback,_,priority,...) self.bindings[name]={callback=callback,priority=priority,keys={...}} end
function cas:UnbindAction(name) self.bindings[name]=nil end
services.ContextActionService=cas
local run={Heartbeat=signal(),renders={}}
function run:BindToRenderStep(name,priority,callback) self.renders[name]=callback end
function run:UnbindFromRenderStep(name) self.renders[name]=nil end
services.RunService=run
local camera={ViewportSize=Vector2.new(844,390)}
function camera:ViewportPointToRay(x,y) self.last=Vector2.new(x,y) return Ray.new(Vector3.new(0,4,0),Vector3.new(x/844-0.5,0.5-y/390,-1).Unit) end
local world={CurrentCamera=camera,GetServerTimeNow=function() return now end}
local destroy=signal()
local module=Instance.new("ModuleScript")
module.Name="ControllerUnderTest"
module.Source="return function(env) local game,workspace,script=env.game,env.workspace,env.script\n"..gui.Controller.Source.."\n return {refresh=refresh,viewportAim=viewportAim,aimPoint=aimPoint,aimRay=aimRay,selectedHeader=selectedHeader,beginFire=beginFire,sprintInput=sprintInput,release=release,fireWeapon=fireWeapon,inputAllowed=inputAllowed} end"
module.Parent=fixture
local assertions=0
local function check(value,label) assertions+=1 assert(value,label) end
local function near(a,b) return (a-b).Magnitude<0.01 end
local function count(action) local n=0 for _,r in ipairs(requests)do if r.action==action then n+=1 end end return n end
local function clear() table.clear(requests) end
local ok,result=xpcall(function()
 local api=require(module)({game={GetService=function(_,name)return services[name]end},workspace=world,script={Parent=gui,Destroying=destroy}})
 local main=gui.Main
 check(cas.bindings.LaserTagFire.keys[1]==Enum.KeyCode.ButtonR2,"R2 fire binding")
 check(cas.bindings.LaserTagSprint.keys[1]==Enum.KeyCode.LeftShift,"Shift sprint binding")
 check(cas.bindings.LaserTagSprint.keys[2]==Enum.KeyCode.ButtonL3,"L3 sprint binding")
 check(main.CompactTop.Visible and not main.Top.Visible,"phone compact header")
 check(main.CompactTop.Team.LiveCaption.Text=="RED\n4 ALIVE" and main.CompactTop.Other.Text=="BLUE\n5 ALIVE","both live team counts")
 check(main.CompactTop.Title.Text=="LASER TAG","game name")
 check(not gui:FindFirstChild("ColourPicker") and not main.Controls:FindFirstChild("Heat"),"legacy choice controls removed")
 check(near(api.aimPoint(camera),Vector2.new(91,140)),"physical pointer corrected for device inset")
 api.aimRay()
 check(near(camera.last,Vector2.new(91,140)),"ray matches visible pointer")
 run.renders.LaserTagAim()
 check(math.abs(main.Crosshair.Position.X.Scale-91/844)<0.001 and math.abs(main.Crosshair.Position.Y.Scale-140/390)<0.001,"crosshair and ray agree")
 ui.MouseBehavior=Enum.MouseBehavior.LockCenter
 check(near(api.aimPoint(camera),camera.ViewportSize*.5),"shift lock center aim")
 ui.MouseBehavior=Enum.MouseBehavior.Default
 ui.PreferredInput=Enum.PreferredInput.Touch
 check(near(api.aimPoint(camera),camera.ViewportSize*.5),"touch camera center aim")
 ui.PreferredInput=Enum.PreferredInput.Gamepad
 check(near(api.aimPoint(camera),camera.ViewportSize*.5),"controller camera center aim")
 check(near(api.viewportAim(Vector2.new(100,100),Vector2.new(-10,500),Vector2.zero,true),Vector2.new(0,100)),"pointer clamps to visible viewport")
 ui.PreferredInput=Enum.PreferredInput.Touch
 api.refresh()
 check(main.Controls.Visible and main.MobileSprint.Visible and not main.DesktopControls.Visible,"touch controls shown")
 local function rect(o,v)
  local size=Vector2.new(o.Size.X.Scale*v.X+o.Size.X.Offset,o.Size.Y.Scale*v.Y+o.Size.Y.Offset)
  local p=Vector2.new(o.Position.X.Scale*v.X+o.Position.X.Offset,o.Position.Y.Scale*v.Y+o.Position.Y.Offset)-size*o.AnchorPoint
  return p,size
 end
 local original={}
 for _,o in ipairs(main:GetDescendants())do if o:IsA("GuiObject")then original[o]={o.Position,o.Size}end end
 for _,v in ipairs({Vector2.new(320,568),Vector2.new(568,320),Vector2.new(667,375),Vector2.new(844,390),Vector2.new(896,414),Vector2.new(768,1024),Vector2.new(1024,768),Vector2.new(1280,720),Vector2.new(1920,1080)})do
  camera.ViewportSize=v api.refresh()
  local header=api.selectedHeader(v)
  local p,s=rect(header,v)
  check(p.X>=0 and p.Y>=0 and p.X+s.X<=v.X and p.Y+s.Y<=v.Y,"header fits "..tostring(v))
  local fp,fs=rect(main.Controls.Fire,v)
  local sp,ss=rect(main.MobileSprint,v)
  check(fp.X>v.X*.5 and sp.X>v.X*.5 and fp.Y>=0 and sp.Y>=0,"right touch controls fit "..tostring(v))
  check(fp.Y+fs.Y<sp.Y and sp.Y+ss.Y<=v.Y-140,"touch targets separated above jump "..tostring(v))
  check(fs.X>=44 and fs.Y>=44 and ss.X>=44 and ss.Y>=44,"touch target size "..tostring(v))
 end
 for o,props in pairs(original)do check(o.Position==props[1] and o.Size==props[2],"authored layout unchanged "..o.Name)end
 camera.ViewportSize=Vector2.new(844,390)
 for lives=3,0,-1 do attrs.MDLives=lives attrs.MDEliminated=lives==0 api.refresh()
  check(main.CompactTop.Out.Visible==(lives==0),"OUT toggles "..lives)
  for index=1,3 do check(main.CompactTop.Lives["Heart"..index].TextColor3==(index<=lives and Color3.fromRGB(255,82,105) or Color3.fromRGB(99,108,126)),"heart "..index.." life "..lives)end
 end
 check(not main.Controls.Visible and not main.MobileSprint.Visible and not main.Crosshair.Visible,"eliminated input hidden")
 clear() api.beginFire("out") check(count("Fire")==0,"out cannot shoot")
 attrs.MDLives,attrs.MDEliminated=3,false api.refresh()
 local touch={UserInputType=Enum.UserInputType.Touch,KeyCode=Enum.KeyCode.Unknown}
 local mouse={UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown}
 clear() ui.InputBegan:Fire(touch,false) check(count("Fire")==0,"camera pan cannot shoot")
 api.sprintInput(touch) check(count("Fire")==0 and count("Sprint")==1,"sprint touch does not fire")
 ui.InputEnded:Fire(touch)
 clear() ui.InputBegan:Fire(mouse,true) check(count("Fire")==0,"processed GUI click cannot fire")
 ui.PreferredInput=Enum.PreferredInput.KeyboardAndMouse
 ui.InputBegan:Fire(mouse,false) check(count("Fire")==1,"mouse first shot")
 run.renders.LaserTagAim() check(count("Fire")==1,"duplicate input respects cooldown")
 now+=0.6 run.renders.LaserTagAim() check(count("Fire")==2,"held mouse repeats after cooldown")
 ui.InputEnded:Fire(mouse) now+=1 run.renders.LaserTagAim() check(count("Fire")==2,"released mouse stops repeat")
 local ray=requests[#requests].value
 for _,r in ipairs(requests)do if r.action=="Fire"then check(typeof(r.value.cameraOrigin)=="Vector3" and typeof(r.value.cameraDirection)=="Vector3","camera aim payload")end end
 heat.Parent=nil mud.Parent=body attrs.MDTeamId=2 api.release() now+=1 clear()
 ui.PreferredInput=Enum.PreferredInput.Gamepad api.refresh()
 cas.bindings.LaserTagFire.callback("LaserTagFire",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.ButtonR2})
 check(count("Fire")==1 and count("Heat")==0,"blue gun uses same Fire action")
 cas.bindings.LaserTagFire.callback("LaserTagFire",Enum.UserInputState.End,{KeyCode=Enum.KeyCode.ButtonR2})
 now+=1 run.renders.LaserTagAim() check(count("Fire")==1,"R2 release stops repeat")
 api.release() mud.Parent=backpack now+=1 clear()
 api.beginFire("reequip")
 check(mud.Parent==body and count("Fire")==1 and count("Equip")==0,"owned current-round backpack gun locally re-equips and shoots")
 api.release()
 for _,invalid in ipairs({{"MDOwnerUserId",456},{"MDRound",6},{"MDTeamId",1},{"MDManaged",false}})do
  local attribute,incorrect=invalid[1],invalid[2]
  local original=mud:GetAttribute(attribute)
  mud.Parent=backpack mud:SetAttribute(attribute,incorrect) now+=1 clear()
  api.beginFire("invalid")
  check(mud.Parent==backpack and count("Fire")==0 and count("Equip")==1,"invalid backpack identity rejected "..attribute)
  mud:SetAttribute(attribute,original) api.release()
 end
 mud.Parent=backpack mud.Enabled=false now+=1 clear() api.beginFire("disabled")
 check(mud.Parent==backpack and count("Fire")==0,"disabled backpack gun rejected")
 mud.Enabled=true mud.Parent=body api.release()
 attrs.MDFireReadyAt=now+5 clear() api.beginFire("cooldown") check(count("Fire")==0,"server cooldown honored") api.release() attrs.MDFireReadyAt=nil
 for _,mode in ipairs({"Menu","Admin","Settings","TextBox","Focus"})do
  now+=10 clear()
  if mode=="Menu"then insets.MenuIsOpen=true elseif mode=="Admin"then adminHub.Visible=true elseif mode=="Settings"then session:SetAttribute("SessionMenuOpen",true) elseif mode=="TextBox"then ui.focusedBox={} else ui.WindowFocusReleased:Fire()end
  api.refresh() api.beginFire(mode) check(count("Fire")==0,"blocked fire "..mode)
  insets.MenuIsOpen=false adminHub.Visible=false session:SetAttribute("SessionMenuOpen",false) ui.focusedBox=nil ui.WindowFocused:Fire() api.refresh()
 end
 session:SetAttribute("UIHidden",true) ui.PreferredInput=Enum.PreferredInput.Touch api.refresh()
 check(not main.CompactTop.Visible and main.Controls.Visible and main.MobileSprint.Visible,"UIHidden preserves essential touch controls")
 session:SetAttribute("UIHidden",false)
 state:SetAttribute("Phase","Countdown") clear() api.refresh() api.beginFire("countdown")
 check(count("Fire")==0 and main.Countdown.Visible,"countdown cannot shoot")
 state:SetAttribute("Phase","Results") state:SetAttribute("ResultReason","TimeoutShared") api.refresh()
 check(main.Results.Visible and main.Results.Reason.Text=="TIME'S UP · TEAMS TIED","shared result copy")
 attrs.MDParticipating=false api.refresh()
 check(not main.Visible and not cas.bindings.LaserTagFire and not cas.bindings.LaserTagSprint,"round exit unbinds inputs")
 destroy:Fire()
 check(run.renders.LaserTagAim==nil,"destroy unbinds render")
 local native=workspace.CurrentCamera
 for _,fraction in ipairs({Vector2.new(.1,.1),Vector2.new(.5,.5),Vector2.new(.9,.9)})do
  local p=fraction*native.ViewportSize local r=native:ViewportPointToRay(p.X,p.Y) local projected=native:WorldToViewportPoint(r.Origin+r.Direction*100)
  check((Vector2.new(projected.X,projected.Y)-p).Magnitude<.05,"native viewport ray roundtrip")
 end
 return {passed=assertions,viewports=9,realCameraRoundtrips=3,scope="Fresh live source executed with native GuiObjects and mocked input/remote; no Play test"}
end,debug.traceback)
fixture:Destroy()
heat:Destroy()
mud:Destroy()
assert(ok,result)
return HttpService:JSONEncode(result)
