assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local fixture=Instance.new("Folder")
fixture.Name="RightSprintGeometryFixture20261008"
fixture.Parent=game:GetService("ServerStorage")
local report={checks={},layouts={}}
local function check(name,passed)
 table.insert(report.checks,{name=name,passed=passed==true})
 assert(passed,name)
end
local rendered
local ok,failure=xpcall(function()
 local sourceBefore={}
 for _,name in ipairs({"BritishBulldogHUD","TagHUD","MudHUD","PlaygroundBatControls","PlaygroundPushControls"})do
  local clone=game.StarterGui[name]:Clone()
  clone.Parent=fixture
  for _,d in ipairs(clone:GetDescendants())do if d:IsA("LuaSourceContainer")then sourceBefore[d]=d.Source end end
 end
 local desktop={}
 for _,button in ipairs({
  fixture.TagHUD.SprintPanel.Sprint,
  fixture.TagHUD.SprintPanel.Push,
  fixture.BritishBulldogHUD.MovementControls.Sprint,
  fixture.BritishBulldogHUD.MovementControls.Push,
  fixture.MudHUD.Main.DesktopControls,
 })do desktop[button]={button.Position,button.AnchorPoint,button.Size}end
 local module=Instance.new("ModuleScript")
 module.Source=[======[__LAYOUT__]======]
 module.Parent=fixture
 local targets=require(module)(fixture,true)
 for button,old in pairs(desktop)do check(button:GetFullName().." desktop layout stays unchanged",button.Position==old[1]and button.AnchorPoint==old[2]and button.Size==old[3])end
 for source,text in pairs(sourceBefore)do assert(source.Source==text,"Input source changed")end
 check("All input sources and bindings stay unchanged",true)
 rendered=Instance.new("ScreenGui")
 rendered.Name="RightSprintGeometryRender20261008"
 rendered.Enabled=false
 rendered.Parent=game:GetService("CoreGui")
 local viewport=Instance.new("Frame")
 viewport.Parent=rendered
 local buttons={
  BulldogSprint=fixture.BritishBulldogHUD.MobileSprint,
  TagSprint=fixture.TagHUD.MobileSprint,
  MudSprint=fixture.MudHUD.Main.MobileSprint,
  Swing=fixture.PlaygroundBatControls.Swing,
  Push=fixture.PlaygroundPushControls.MobilePush,
  Mud=fixture.MudHUD.Main.Controls.Mud,
  Heat=fixture.MudHUD.Main.Controls.Heat,
  Fire=fixture.MudHUD.Main.Controls.Fire,
 }
 for _,button in pairs(buttons)do button.Parent=viewport end
 local topCards={fixture.BritishBulldogHUD.TopCard,fixture.TagHUD.Top,fixture.MudHUD.Main.Top}
 for _,card in ipairs(topCards)do card.Parent=viewport end
 local departure=fixture.BritishBulldogHUD.CompactDeparture departure.Parent=viewport
 local jump=Instance.new("Frame")
 jump.AnchorPoint=Vector2.new(1,1) jump.Position=UDim2.new(1,-18,1,-24)
 jump.Size=UDim2.fromOffset(88,88) jump.Parent=viewport
 local joystick=Instance.new("Frame")
 joystick.AnchorPoint=Vector2.new(0,1) joystick.Position=UDim2.new(0,0,1,0)
 joystick.Size=UDim2.fromOffset(160,160) joystick.Parent=viewport
 local function overlap(a,b)
  local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
  return p.X<q.X+t.X and p.X+s.X>q.X and p.Y<q.Y+t.Y and p.Y+s.Y>q.Y
 end
 local combat={buttons.BulldogSprint,buttons.Swing,buttons.Push}
 local mud={buttons.MudSprint,buttons.Mud,buttons.Heat,buttons.Fire}
 for _,v in ipairs({
  Vector2.new(320,524),Vector2.new(375,623),Vector2.new(568,276),
  Vector2.new(667,331),Vector2.new(844,248),
  Vector2.new(768,980),Vector2.new(1024,724),Vector2.new(1194,790),
 })do
  viewport.Size=UDim2.fromOffset(v.X,v.Y)
  for _,card in ipairs(topCards)do
   local scale=card:FindFirstChild("ResponsiveHudScale")
   if scale then scale.Scale=scale:GetAttribute((v.X<=900 or v.Y<=600)and"PhoneScale"or"TabletScale")or 1 end
  end
  task.wait()
  local prefix=string.format("%dx%d safe area ",v.X,v.Y)
  local onScreen,clearStock,readable=true,true,true
  for _,button in pairs(buttons)do
   local p=button.AbsolutePosition-viewport.AbsolutePosition local s=button.AbsoluteSize
   onScreen=onScreen and p.X>=0 and p.Y>=0 and p.X+s.X<=v.X+0.1 and p.Y+s.Y<=v.Y+0.1
   clearStock=clearStock and not overlap(button,jump)and not overlap(button,joystick)
   readable=readable and s.X>=44 and s.Y>=44
   for _,label in ipairs(button:GetDescendants())do
    if label:IsA("TextLabel")and label.Visible then readable=readable and label.TextScaled and label.AbsoluteSize.Y>=10 end
   end
  end
  check(prefix.."all touch buttons stay on screen",onScreen)
  check(prefix.."all touch buttons clear jump and joystick",clearStock)
  check(prefix.."tap targets and captions remain readable",readable)
  local right=buttons.BulldogSprint.AbsolutePosition.X-viewport.AbsolutePosition.X>=v.X/2
   and buttons.TagSprint.AbsolutePosition.X-viewport.AbsolutePosition.X>=v.X/2
   and buttons.MudSprint.AbsolutePosition.X-viewport.AbsolutePosition.X>=v.X/2
  check(prefix.."all three sprint buttons are on the right",right)
  local combatClear,mudClear=true,true
  for i=1,#combat do for j=i+1,#combat do combatClear=combatClear and not overlap(combat[i],combat[j])end end
  for i=1,#mud do for j=i+1,#mud do mudClear=mudClear and not overlap(mud[i],mud[j])end end
  check(prefix.."Sprint Swing and Push do not overlap",combatClear)
  check(prefix.."Mud Sprint Fire and selectors do not overlap",mudClear)
  check(prefix.."Bulldog controls clear top HUD and safe warning",not overlap(buttons.BulldogSprint,topCards[1])and not overlap(buttons.Swing,topCards[1])and not overlap(buttons.Push,topCards[1])and not overlap(buttons.BulldogSprint,departure))
  check(prefix.."Tag controls clear top HUD",not overlap(buttons.TagSprint,topCards[2])and not overlap(buttons.Swing,topCards[2])and not overlap(buttons.Push,topCards[2]))
  check(prefix.."Mud controls clear top HUD",not overlap(buttons.MudSprint,topCards[3])and not overlap(buttons.Fire,topCards[3])and not overlap(buttons.Mud,topCards[3])and not overlap(buttons.Heat,topCards[3]))
  table.insert(report.layouts,{width=v.X,height=v.Y,sprint=tostring(buttons.MudSprint.AbsolutePosition-viewport.AbsolutePosition),fire=tostring(buttons.Fire.AbsolutePosition-viewport.AbsolutePosition),swing=tostring(buttons.Swing.AbsolutePosition-viewport.AbsolutePosition)})
 end
end,debug.traceback)
if rendered then rendered:Destroy()end
fixture:Destroy()
report.ok=ok report.error=not ok and tostring(failure)or nil
return game:GetService("HttpService"):JSONEncode(report)
