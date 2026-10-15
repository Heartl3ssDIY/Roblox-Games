local result={}
local function check(name,fn)
 local ok,err=xpcall(fn,debug.traceback)
 table.insert(result,{name=name,passed=ok,error=not ok and tostring(err) or nil})
end
local sourceGui=game.StarterGui.DuckDuckGooseHUD
local gui=sourceGui:Clone() gui.Parent=script.Parent
local arena=script.Parent.FixtureArena
local track=arena.Grounds.CircularRunningTrack
local directions=track.TrackDirections
local attributes={DGRouteStatus="Clockwise",DGSeatReady=false}
local stateAttributes={EmptySeatIndex=1}
local env={now=0,callbacks={},arena=arena}
local Guidance=require(script.Parent.GuidanceCandidate)(env)
local player={GetAttribute=function(_,name) return attributes[name] end}
local state={GetAttribute=function(_,name) return stateAttributes[name] end}
local handle=Guidance.Start(gui,state,player)
local context={shown=true,phase="Countdown",turn="Choosing",role="Duck",eliminated=false,compact=true,portrait=false,touch=true}
local original={}
for _,a in directions:GetChildren() do for _,p in a:GetChildren() do if p:IsA("BasePart") then original[p]={color=p.Color,material=p.Material,transparency=p.Transparency} end end end
check("Countdown presents only the current compact rules card",function()
 handle.Update(context)
 assert(gui.CompactRules.Visible and not gui.DesktopRules.Visible and not gui.PortraitRules.Visible)
 assert(gui.TouchRulesButton.Visible and not gui.DesktopRulesButton.Visible)
end)
check("Portrait and desktop rules switch without changing authored layout",function()
 local old=gui.PortraitRules.Position context.portrait=true handle.Update(context)
 assert(gui.PortraitRules.Visible and not gui.CompactRules.Visible and gui.PortraitRules.Position==old)
 context.portrait=false context.compact=false context.touch=false handle.Update(context)
 assert(gui.DesktopRules.Visible and not gui.CompactRules.Visible and gui.DesktopRulesButton.Visible)
 context.compact=true context.touch=true
end)
check("Rules close at chase start and runner sees one goal marker",function()
 context.phase="Playing" context.turn="Chasing" context.role="Runner" handle.Update(context)
 assert(not gui.CompactRules.Visible and gui.CompactNotice.Visible)
 assert(gui.DGGoalNotice.Enabled and gui.DGGoalNotice.Adornee==arena.Gameplay.Seats.Seat1.Seat)
 handle.Update(context)
 local count=0 for _,v in gui:GetChildren() do if v.Name=="DGGoalNotice" then count+=1 end end assert(count==1)
end)
check("All arrows glow and animation advances clockwise",function()
 for part in original do assert(part.Material==Enum.Material.Neon) end
 env.now=0 handle.Update(context)
 local first=directions.Chevron01.InnerArm.Color
 env.now=(math.pi*2/24)/2.8 handle.Update(context)
 local second=directions.Chevron02.InnerArm.Color
 assert((Vector3.new(first.R,first.G,first.B)-Vector3.new(second.R,second.G,second.B)).Magnitude<0.001)
 assert(directions.Chevron01.InnerArm.Color~=directions.Chevron02.InnerArm.Color)
end)
check("Every chevron geometrically points along clockwise travel",function()
 local center=arena.Gameplay.CircleCenter.CFrame
 for _,arrow in directions:GetChildren() do
  local angle=arrow:GetAttribute("ClockwiseAngle")
  local forward=Vector3.new(math.cos(angle),0,math.sin(angle))
  for _,part in arrow:GetChildren() do if part:IsA("BasePart") then
   local tip=center:PointToObjectSpace(part.Position+part.CFrame.RightVector*part.Size.X*0.5)
   local tail=center:PointToObjectSpace(part.Position-part.CFrame.RightVector*part.Size.X*0.5)
   assert((tip-tail):Dot(forward)>2,"chevron points the wrong way")
   assert(not part.CanCollide and not part.CanQuery and not part.CanTouch)
  end end
 end
end)
check("Recovery takes precedence over an already completed lap",function()
 attributes.DGSeatReady=true attributes.DGRouteStatus="OffTrack" attributes.DGReturnPoint=Vector3.new(1,2,3)
 env.now=10 handle.Update(context)
 assert(Guidance.Describe("Runner","OffTrack",true,false)=="RETURN TO THE TRACK")
 assert(gui.DGReturnNotice.Enabled and gui.DGReturnNotice.Adornee.Position==attributes.DGReturnPoint)
 assert(not gui:FindFirstChild("DGGoalNotice"))
 assert(gui.CompactNotice.Caption.Text=="RETURN TO THE TRACK")
end)
check("Moving recovery point reuses its marker and stays nonphysical",function()
 local part=gui.DGReturnNotice.Adornee
 attributes.DGReturnPoint=Vector3.new(4,5,6) handle.Update(context)
 assert(gui.DGReturnNotice.Adornee==part and part.Position==attributes.DGReturnPoint)
 assert(part.Transparency==1 and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
end)
check("Recovery completion removes return marker and restores goal",function()
 attributes.DGRouteStatus="Ready" attributes.DGReturnPoint=nil handle.Update(context)
 assert(not gui:FindFirstChild("DGReturnNotice") and not script.Parent.FixtureWorld:FindFirstChild("DGLocalReturnPoint"))
 assert(gui.DGGoalNotice.Caption.Text=="LAP DONE - SIT HERE!")
end)
check("Chaser never gets the runner's chair marker",function()
 context.role="Goose" attributes.DGSeatReady=false attributes.DGRouteStatus="Clockwise" handle.Update(context)
 assert(not gui:FindFirstChild("DGGoalNotice"))
 assert(gui.CompactNotice.Caption.Text=="YOU'RE THE GOOSE! CHASE AND TAG")
end)
check("Tagged players get elimination notice and markers are cleared",function()
 context.role="Spectator" context.eliminated=true handle.Update(context)
 assert(gui.CompactNotice.Caption.Text=="TAGGED! YOU'RE OUT")
 assert(not gui:FindFirstChild("DGGoalNotice") and not gui:FindFirstChild("DGReturnNotice"))
end)
check("Hidden session UI hides guidance and restores arrow artwork",function()
 context.shown=false handle.Update(context)
 assert(not gui.CompactNotice.Visible and not gui.TouchRulesButton.Visible)
 for part,old in original do assert(part.Color==old.color and part.Material==old.material and part.Transparency==old.transparency) end
end)
check("Late streamed chevrons join glow or directions stream atomically",function()
 if directions.ModelStreamingMode==Enum.ModelStreamingMode.Atomic then return end
 context.shown=true context.role="Runner" context.eliminated=false
 local late=directions.Chevron01:Clone() late.Name="LateStreamedArrow"
 for _,part in late:GetChildren() do if part:IsA("BasePart") then part.Material=Enum.Material.SmoothPlastic end end
 late.Parent=directions handle.Update(context)
 assert(late.InnerArm.Material==Enum.Material.Neon,"newly streamed arrow never registered")
 late:Destroy()
end)
check("Destroy removes local markers and restores the original arrows",function()
 context.role="Runner" context.shown=true attributes.DGRouteStatus="OffTrack" attributes.DGReturnPoint=Vector3.new(1,2,3)
 handle.Update(context) handle.Destroy() handle.Destroy()
 assert(not gui:FindFirstChild("DGGoalNotice") and not gui:FindFirstChild("DGReturnNotice"))
 assert(not script.Parent.FixtureWorld:FindFirstChild("DGLocalReturnPoint"))
 for part,old in original do assert(part.Color==old.color and part.Material==old.material and part.Transparency==old.transparency) end
 handle.Update(context) assert(not gui:FindFirstChild("DGReturnNotice"))
end)
local ts=game:GetService("TextService")
for _,prefix in ipairs({"Desktop","Compact","Portrait"}) do
 check(prefix.." rules text fits the authored cards",function()
  local card=gui[prefix.."Rules"]
  for _,label in card:GetDescendants() do if label:IsA("TextLabel") then
   local parent=label.Parent local pw=parent.Size.X.Offset local ph=parent.Size.Y.Offset
   local width=pw*label.Size.X.Scale+label.Size.X.Offset local height=ph*label.Size.Y.Scale+label.Size.Y.Offset
   local min=label:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize
   local bounds=ts:GetTextSize(label.Text,min,label.Font,Vector2.new(width,1000))
   assert(bounds.X<=width+0.1 and bounds.Y<=height+0.1,label:GetFullName().." overflows")
  end end
 end)
end
for _,view in ipairs({{568,320},{667,375},{812,375},{844,390},{1024,768},{1180,820},{320,568},{390,844},{1920,1080}}) do
 check("Guidance fits "..view[1].."x"..view[2].." viewport safe area",function()
  local w,h=view[1],view[2]-58
  local compact=view[1]<=900 or math.min(table.unpack(view))<=600 or (math.min(table.unpack(view))<=1024 and math.max(table.unpack(view))<=1400)
  local prefix=not compact and "Desktop" or view[2]>view[1] and "Portrait" or "Compact"
  for _,name in ipairs({prefix.."Rules",prefix.."Notice",prefix=="Desktop" and "DesktopRulesButton" or "TouchRulesButton"}) do
   local v=gui[name] local sw=w*v.Size.X.Scale+v.Size.X.Offset local sh=h*v.Size.Y.Scale+v.Size.Y.Offset
   local x=w*v.Position.X.Scale+v.Position.X.Offset-sw*v.AnchorPoint.X
   local y=h*v.Position.Y.Scale+v.Position.Y.Offset-sh*v.AnchorPoint.Y
   assert(x>=0 and y>=0 and x+sw<=w+0.01 and y+sh<=h+0.01,name.." offscreen")
  end
 end)
end
gui:Destroy()
local passed=0 for _,v in result do if v.passed then passed+=1 end end
return {passed=passed,total=#result,checks=result}
