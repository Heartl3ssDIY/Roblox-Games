assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("Folder")
fixture.Name="MobileSprintFixture20261008"
fixture.Parent=game:GetService("ServerStorage")
local report={checks={},geometry={}}
local function check(name,passed)
 table.insert(report.checks,{name=name,passed=passed==true})
 assert(passed,name)
end
local function signal()
 local handlers={}
 local s={}
 function s:Connect(fn)
  local h={fn=fn,active=true} table.insert(handlers,h)
  return {Disconnect=function()h.active=false end}
 end
 function s:Fire(...)
  for _,h in ipairs(handlers)do if h.active then h.fn(...)end end
 end
 return s
end
local rendered
local ok,failure=xpcall(function()
 for _,name in ipairs({"TagHUD","BritishBulldogHUD","MudHUD"})do
  local clone=game.StarterGui[name]:Clone()
  for _,d in ipairs(clone:GetDescendants())do if d:IsA("BaseScript")then d:Destroy()end end
  clone.Parent=fixture
 end
 local build=Instance.new("ModuleScript")
 build.Source="return function(game)\n"..[======[__BUILDER__]======].."\nend"
 build.Parent=fixture
 require(build)({PlaceId=game.PlaceId,GetService=function(_,name)
  if name=="StarterGui"then return fixture end
  return game:GetService(name)
 end})
 for _,name in ipairs({"TagHUD","BritishBulldogHUD"})do
  local gui=fixture[name]
  local nativeHumanoid=Instance.new("Humanoid")
  local character=Instance.new("Model")
  character.Parent=fixture nativeHumanoid.Parent=character
  local attrs={BBParticipating=name=="BritishBulldogHUD",TGParticipating=name=="TagHUD",BBRole="Runner",TGRole="Runner",BBStatus="Crossing"}
  local player={Character=character,CharacterAdded=signal(),CharacterRemoving=signal()}
  function player:GetAttribute(key)return attrs[key]end
  function player:GetAttributeChangedSignal()return signal()end
  local state=Instance.new("Folder") state.Parent=fixture
  state:SetAttribute("Phase",name=="TagHUD"and"Playing"or"Crossing")
  local calls={}
  local remote={}
  function remote:IsA(kind)return kind=="RemoteFunction"end
  function remote:InvokeServer(...)
   table.insert(calls,{...}) return {ok=true}
  end
  local replication={}
  function replication:WaitForChild(key)return key:find("State")and state or remote end
  function replication:FindFirstChild(key)return key:find("State")and state or remote end
  local input={TouchEnabled=true}
  for _,event in ipairs({"InputEnded","InputChanged","InputBegan","WindowFocusReleased","WindowFocused","TextBoxFocused","JumpRequest"})do input[event]=signal()end
  function input:GetFocusedTextBox()return nil end
  local action
  local context={}
  function context:BindActionAtPriority(_,fn)action=fn end
  function context:UnbindAction()action=nil end
  local heartbeat=signal()
  local services={Players={LocalPlayer=player,GetPlayers=function()return{}end},ReplicatedStorage=replication,UserInputService=input,ContextActionService=context,RunService={Heartbeat=heartbeat,PreSimulation=signal()}}
  local mobileBegin,desktopBegin,desktopEnd,destroying=signal(),signal(),signal(),signal()
  local fakeTask={spawn=function(fn)fn()return{}end,delay=function()end,cancel=function()end}
  local env={
   game={GetService=function(_,key)return assert(services[key],key)end},
   script={Parent=gui,Destroying=destroying},task=fakeTask,
   workspace={FindFirstChild=function()return nil end,GetServerTimeNow=function()return 100 end},
   mobileBegin=mobileBegin,desktopBegin=desktopBegin,desktopEnd=desktopEnd
  }
  local source=name=="TagHUD"and[======[__TAG__]======]or[======[__BULLDOG__]======]
  local replacements
  source,replacements=source:gsub("connect%(mobileSprint%.InputBegan,beginSprint%)","connect(env.mobileBegin,beginSprint)")
  check(name.." substitutes only native mobile input signal",replacements==1)
  if name=="TagHUD"then
   source,replacements=source:gsub("connect%(panel%.Sprint%.InputBegan,beginSprint%)","connect(env.desktopBegin,beginSprint)")
  else
   source,replacements=source:gsub("connect%(sprint%.InputBegan,beginSprint%)","connect(env.desktopBegin,beginSprint)")
   source=source:gsub("connect%(sprint%.InputEnded,","connect(env.desktopEnd,")
  end
  check(name.." substitutes only native desktop input signal",replacements==1)
  local module=Instance.new("ModuleScript")
  module.Name=name.."ControllerFixture"
  module.Sandboxed=true
  module.Capabilities=game.StarterGui[name][name=="TagHUD"and"SprintController"or"MovementController"].Capabilities
  module.Source="return function(env)\nlocal game=env.game\nlocal workspace=env.workspace\nlocal script=env.script\nlocal task=env.task\n"..source.."\nreturn {refresh=refresh}\nend"
  module.Parent=fixture
  local controller=require(module)(env)
  local desktop=name=="TagHUD"and gui.SprintPanel.Sprint or gui.MovementControls.Sprint
  local mobile=gui.MobileSprint
  local position,size,anchor=mobile.Position,mobile.Size,mobile.AnchorPoint
  local function held(value)
   local c=calls[#calls]
   return c and c[name=="TagHUD"and 1 or 2]==value
  end
  check(name.." shows only the left button on touch",mobile.Visible and not desktop.Visible)
  local touch={UserInputType=Enum.UserInputType.Touch,KeyCode=Enum.KeyCode.Unknown}
  mobileBegin:Fire(touch)
  check(name.." phone press requests sprint",held(true))
  input.InputEnded:Fire(touch)
  check(name.." phone release stops sprint",held(false))
  mobileBegin:Fire(touch)
  touch.UserInputState=Enum.UserInputState.Cancel
  input.InputChanged:Fire(touch)
  check(name.." cancelled touch stops sprint",held(false))
  mobileBegin:Fire(touch)
  input.WindowFocusReleased:Fire()
  check(name.." losing focus stops sprint",held(false))
  input.WindowFocused:Fire()
  mobileBegin:Fire(touch)
  input.TextBoxFocused:Fire()
  check(name.." text entry releases sprint",held(false))
  state:SetAttribute("Phase","Results") controller.refresh()
  check(name.." results hide mobile sprint",not mobile.Visible)
  local before=#calls mobileBegin:Fire(touch)
  check(name.." results cannot send sprint",#calls==before)
  state:SetAttribute("Phase",name=="TagHUD"and"Playing"or"Crossing")
  input.TouchEnabled=false controller.refresh()
  check(name.." desktop button remains in original slot",desktop.Visible and not mobile.Visible)
  if action then action("Sprint",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.LeftShift})end
  check(name.." desktop shift still requests sprint",held(true))
  if action then action("Sprint",Enum.UserInputState.End,{KeyCode=Enum.KeyCode.LeftShift})end
  check(name.." shift release still stops sprint",held(false))
  check(name.." runtime preserves authored mobile geometry",mobile.Position==position and mobile.Size==size and mobile.AnchorPoint==anchor)
  destroying:Fire()
 end
 rendered=Instance.new("ScreenGui")
 rendered.Name="MobileSprintGeometryFixture20261008" rendered.Enabled=false
 rendered.Parent=game:GetService("CoreGui")
 local viewport=Instance.new("Frame") viewport.Parent=rendered
 local root=fixture.MudHUD.Main root.Parent=viewport
 local bbSprint=fixture.BritishBulldogHUD.MobileSprint bbSprint.Parent=viewport
 local tagSprint=fixture.TagHUD.MobileSprint tagSprint.Parent=viewport
 local departure=fixture.BritishBulldogHUD.CompactDeparture departure.Parent=viewport
 local function overlap(a,b)
  local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
  return p.X<q.X+t.X and p.X+s.X>q.X and p.Y<q.Y+t.Y and p.Y+s.Y>q.Y
 end
 local jump=Instance.new("Frame")
 jump.Size=UDim2.fromOffset(88,88) jump.AnchorPoint=Vector2.new(1,1)
 jump.Position=UDim2.new(1,-18,1,-24) jump.Parent=viewport
 local joystick=Instance.new("Frame")
 joystick.Size=UDim2.fromOffset(160,160) joystick.AnchorPoint=Vector2.new(0,1)
 joystick.Position=UDim2.new(0,0,1,0) joystick.Parent=viewport
 for _,v in ipairs({Vector2.new(320,568),Vector2.new(375,667),Vector2.new(667,375),Vector2.new(844,292),Vector2.new(768,1024),Vector2.new(1024,768)})do
  viewport.Size=UDim2.fromOffset(v.X,v.Y)
  root.Controls.ResponsiveHudScale.Scale=root.Controls.ResponsiveHudScale:GetAttribute("PhoneScale")
  task.wait()
  local prefix=string.format("%dx%d ",v.X,v.Y)
  for _,button in ipairs({root.MobileSprint,bbSprint,tagSprint,root.Controls.Mud,root.Controls.Heat,root.Controls.Fire})do
   local p=button.AbsolutePosition-viewport.AbsolutePosition local s=button.AbsoluteSize
   check(prefix..button:GetFullName().." remains on screen",p.X>=0 and p.Y>=0 and p.X+s.X<=v.X+0.1 and p.Y+s.Y<=v.Y+0.1)
   check(prefix..button.Name.." clears mobile jump",not overlap(button,jump))
   check(prefix..button.Name.." clears mobile joystick",not overlap(button,joystick))
   if button.Name~="MobileSprint"then check(prefix..button.Name.." clears left sprint",not overlap(button,root.MobileSprint))end
  end
  check(prefix.." safe-zone warning clears sprint",not overlap(departure,bbSprint))
  check(prefix.." Fire clears top Mud HUD",not overlap(root.Controls.Fire,root.Top))
  check(prefix.." weapon selectors clear top Mud HUD",not overlap(root.Controls.Mud,root.Top)and not overlap(root.Controls.Heat,root.Top))
  check(prefix.." touch meter does not block inputs",not root.Controls.Meter.Active and not root.Controls.Active)
  table.insert(report.geometry,{width=v.X,height=v.Y,sprint=tostring(root.MobileSprint.AbsolutePosition-viewport.AbsolutePosition),fire=tostring(root.Controls.Fire.AbsolutePosition-viewport.AbsolutePosition)})
 end
end,debug.traceback)
if rendered then rendered:Destroy()end
fixture:Destroy()
report.ok=ok report.error=not ok and tostring(failure)or nil
return game:GetService("HttpService"):JSONEncode(report)
