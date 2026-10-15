local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local gui=script.Parent
local main=gui:WaitForChild("Main")
main.Visible=false
local controls=UserInputService.TouchEnabled and main.Controls or (main:FindFirstChild("DesktopControls") or main.Controls)
local mobileSprint=main:WaitForChild("MobileSprint")
local state=ReplicatedStorage:WaitForChild("MudState")
local remote=ReplicatedStorage:WaitForChild("MudActionRequest")
local focused=true
local sprintKeys={}
local sprintTouch
local fireTouch
local fireHeld=false
local sprintHeld=false
local binding=false
local lastSprint=0
local lastHeat=0
local lastShot=0
local elapsed=0
local message=""
local messageUntil=0
local palette=gui.ColourPicker
local connections={}
local toolConnections={}
local character
local sending={}
local pending={}

local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end
local function playing()
 return player:GetAttribute("MDParticipating")==true and state:GetAttribute("Phase")=="Playing" and player:GetAttribute("MDMuddy")~=true and player:GetAttribute("MDEliminated")~=true
end
local function call(action,value,aim,quiet)
 pending[action]={value=value,aim=aim,quiet=quiet}
 if sending[action] then return end
 sending[action]=true
 task.spawn(function()
  while pending[action] do
   local request=pending[action] pending[action]=nil
   local ok,result=pcall(function() return remote:InvokeServer(action,request.value,request.aim) end)
   if not request.quiet and (not ok or typeof(result)=="table" and result.ok==false) then
    message=ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil=workspace:GetServerTimeNow()+1.4
   end
   if action=="ChooseColor" then palette.Message.Text=ok and result and result.message or "Try again." end
  end
  sending[action]=nil
 end)
end
local function release()
 table.clear(sprintKeys) sprintTouch=nil fireTouch=nil fireHeld=false
 sprintHeld=false
 call("Sprint",false,nil,true)
 call("Heat",false,nil,true)
end
local function sprintChange()
 local held=focused and playing() and not palette.Visible and (next(sprintKeys)~=nil or sprintTouch~=nil)
 if held~=sprintHeld then sprintHeld=held lastSprint=os.clock() call("Sprint",held,nil,true) end
end
local function equip(name)
 if palette.Visible or not player:GetAttribute("MDParticipating") or player:GetAttribute("MDMuddy") or player:GetAttribute("MDEliminated") then return end
 call("Heat",false,nil,true)
 fireHeld=false
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local backpack=player:FindFirstChildOfClass("Backpack")
 local tool=character and character:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
 if humanoid and tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end
local function keys(_,phase,input)
 if not player:GetAttribute("MDParticipating") then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode]=nil sprintChange()
 elseif phase==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  sprintKeys[input.KeyCode]=true sprintChange()
 end
 return Enum.ContextActionResult.Sink
end
local function aimViewportPoint(camera)
 local deviceArea=GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local point=camera.ViewportSize*0.5
 if UserInputService.PreferredInput==Enum.PreferredInput.KeyboardAndMouse and UserInputService.MouseBehavior~=Enum.MouseBehavior.LockCenter then
  local fullArea=GuiService:GetInsetArea(Enum.ScreenInsets.None)
  point=UserInputService:GetMouseLocation()-(deviceArea.Min-fullArea.Min)
 end
 point=Vector2.new(math.clamp(point.X,0,camera.ViewportSize.X),math.clamp(point.Y,0,camera.ViewportSize.Y))
 return point,point+deviceArea.Min
end
local function updateCrosshair()
 local camera=workspace.CurrentCamera
 if not camera or not main.Crosshair.Visible then return end
 local _,screenPoint=aimViewportPoint(camera)
 local offset=screenPoint-main.AbsolutePosition
 local size=main.AbsoluteSize
 if size.X>0 and size.Y>0 then main.Crosshair.Position=UDim2.fromScale(offset.X/size.X,offset.Y/size.Y) end
end
local function aimRay()
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local point=aimViewportPoint(camera)
 local ray=camera:ViewportPointToRay(point.X,point.Y)
 return {cameraOrigin=ray.Origin,cameraDirection=ray.Direction}
end
local function progress(track,fraction)
 fraction=math.clamp(fraction,0,1)
 local gradient=track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local p=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(p-0.0001,0),NumberSequenceKeypoint.new(p+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function bindTools(newCharacter)
 if newCharacter==character then return end
 release()
 character=newCharacter
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
 table.clear(toolConnections)
 local hooked={}
 local function bind(tool)
  if not tool:IsA("Tool") or hooked[tool] or (tool.Name~="MudGun" and tool.Name~="HeatGun") then return end
  hooked[tool]=true
  table.insert(toolConnections,tool.Activated:Connect(function()
   if focused and playing() and not palette.Visible then fireHeld=true lastShot=0 end
  end))
  table.insert(toolConnections,tool.Deactivated:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
  table.insert(toolConnections,tool.Unequipped:Connect(function() fireHeld=false call("Heat",false,nil,true) end))
 end
 if character then
  for _,tool in ipairs(character:GetChildren()) do bind(tool) end
  table.insert(toolConnections,character.ChildAdded:Connect(bind))
 end
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then
  for _,tool in ipairs(backpack:GetChildren()) do bind(tool) end
  table.insert(toolConnections,backpack.ChildAdded:Connect(bind))
 end
end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 mobileSprint.Visible=false
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Sprint.Visible=not UserInputService.TouchEnabled
 mobileSprint.Visible=showControls and UserInputService.TouchEnabled
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=focused and playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 caption(mobileSprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").."\nHOLD")
 mobileSprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end
connect(controls.Mud.Activated,function() equip("MudGun") end)
connect(controls.Heat.Activated,function() equip("HeatGun") end)
local function sprintInput(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end
connect(controls.Sprint.InputBegan,sprintInput)
connect(mobileSprint.InputBegan,sprintInput)
connect(controls.Fire.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then fireTouch=input fireHeld=true lastShot=0 end
end)
connect(UserInputService.InputEnded,function(input)
 if input==sprintTouch then sprintTouch=nil end
 if input==fireTouch then fireTouch=nil fireHeld=false call("Heat",false,nil,true) end
 if input.KeyCode==Enum.KeyCode.LeftShift then sprintKeys[input.KeyCode]=nil end
 sprintChange()
end)
connect(UserInputService.InputChanged,function(input)
 if input.UserInputState==Enum.UserInputState.Cancel and (input==sprintTouch or input==fireTouch) then release() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(gui.ColourToggle.Activated,function() palette.Visible=not palette.Visible release() end)
connect(main.Top.Team.Activated,function() palette.Visible=not palette.Visible release() end)
connect(palette.Close.Activated,function() palette.Visible=false release() end)
connect(palette:GetPropertyChangedSignal("Visible"),function() if palette.Visible then release() end end)
for _,name in ipairs({"Red","Blue","Green","Black"}) do connect(palette[name].Activated,function() call("ChooseColor",name) end) end
connect(player.CharacterAdded,bindTools)
connect(player.CharacterRemoving,function() bindTools(nil) end)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if player.Character~=character then bindTools(player.Character) end
 if elapsed>=0.05 then elapsed=0 refresh() end
 if sprintHeld and os.clock()-lastSprint>=0.3 then lastSprint=os.clock() call("Sprint",true,nil,true) end
 if fireHeld and playing() and not palette.Visible then
  local direction=aimRay()
  if direction then
   if player:GetAttribute("MDTool")=="HeatGun" then
    if os.clock()-lastHeat>=0.25 then lastHeat=os.clock() call("Heat",true,direction,true) end
   elseif os.clock()-lastShot>=0.7 then lastShot=os.clock() call("Fire",direction,nil,true) end
  end
 end
end)
RunService:BindToRenderStep("MudAimReticle",Enum.RenderPriority.Camera.Value+1,updateCrosshair)
connect(script.Destroying,function()
 release()
 RunService:UnbindFromRenderStep("MudAimReticle")
 if binding then ContextActionService:UnbindAction("MudControls") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(toolConnections) do connection:Disconnect() end
end)
bindTools(player.Character)
refresh()
