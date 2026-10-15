local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("SprintPanel")
local mobileSprint=gui:WaitForChild("MobileSprint")
local state=ReplicatedStorage:WaitForChild("TagState")
local remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
local keys={}
local touch
local held=false
local focused=true
local bound=false
local pending
local sending=false
local requestSerial=0
local alive=true
local elapsed=0
local lease=0
local connections={}
local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local function active()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("TGParticipating")==true and player:GetAttribute("TGRagdolled")~=true and state:GetAttribute("Phase")=="Playing" and humanoid and humanoid.Health>0
end
local function inputContext()
 local phase=state:GetAttribute("Phase")
 return player:GetAttribute("TGParticipating")==true and (phase=="Playing" or phase=="Countdown")
end
local function request(value)
 pending=value
 if sending or not alive then return end
 sending=true requestSerial+=1
 local serial=requestSerial
 local worker=task.spawn(function()
  while pending~=nil and alive and serial==requestSerial do
   local value=pending pending=nil
   pcall(function() remote:InvokeServer(value) end)
  end
  if serial==requestSerial then sending=false end
 end)
 task.delay(2,function()
  if serial==requestSerial and sending then requestSerial+=1 sending=false pending=nil pcall(task.cancel,worker) end
 end)
end
local function updateHold()
 local value=focused and active() and (next(keys)~=nil or touch~=nil)
 if value~=held then held=value request(value) lease=os.clock() end
end
local function release()
 table.clear(keys) touch=nil
 if held then held=false request(false) end
end
local function action(_,phase,input)
 if not inputContext() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if phase==Enum.UserInputState.End or phase==Enum.UserInputState.Cancel then keys[input.KeyCode]=nil
 elseif phase==Enum.UserInputState.Begin and focused and not UserInputService:GetFocusedTextBox() then keys[input.KeyCode]=true end
 updateHold()
 return Enum.ContextActionResult.Sink
end
local function progress(fraction)
 local gradient=panel.Meter.Track.Fill.Progress
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  local point=math.clamp(fraction,0.001,0.999)
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(point-0.0001,0),NumberSequenceKeypoint.new(point+0.0001,1),NumberSequenceKeypoint.new(1,1)})
 end
end
local function refresh()
 local participating=player:GetAttribute("TGParticipating")==true
 local phase=state:GetAttribute("Phase")
 panel.Visible=participating and (phase=="Playing" or phase=="Countdown")
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local short=math.min(viewport.X,viewport.Y)
 local compactHud=viewport.X<=900 or short<=600 or (short<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 panel.Meter.Visible=not compactHud
 local touchMode=UserInputService.TouchEnabled
 panel.Sprint.Visible=not touchMode
 mobileSprint.Visible=panel.Visible and touchMode
 if inputContext() and not bound then ContextActionService:BindActionAtPriority("TagSprint",action,false,3000,Enum.KeyCode.LeftShift) bound=true
 elseif not inputContext() and bound then ContextActionService:UnbindAction("TagSprint") bound=false release() end
 if not panel.Visible then release() return end
 local maximum=player:GetAttribute("TGSprintMax") or 10
 local remaining=math.clamp(player:GetAttribute("TGSprintRemaining") or maximum,0,maximum)
 local tagger=player:GetAttribute("TGRole")=="Tagger"
 local color=tagger and Color3.fromRGB(255,81,92) or Color3.fromRGB(42,160,255)
 panel.Meter.Role.Text=tagger and "YOU'RE IT!" or "RUNNER"
 panel.Meter.Time.Text=string.format("IT: %.1fs",player:GetAttribute("TGTaggerSeconds") or 0)
 panel.Meter.Charge.Text=string.format("%.1fs / %ds",remaining,maximum)
 panel.Meter.Track.Fill.BackgroundColor3=color
 panel.Sprint.BackgroundColor3=color
 local caption=player:GetAttribute("TGSprintExhausted") and "RECHARGING" or player:GetAttribute("TGSprinting") and "SPRINTING" or "SPRINT"
 panel.Sprint.Text=caption.."\n"..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT")
 panel.Sprint.AutoButtonColor=active()
 mobileSprint.Text=caption..string.format("\n%.1f/%gs",remaining,maximum)
 mobileSprint.BackgroundColor3=color
 mobileSprint.AutoButtonColor=active()
 progress(remaining/math.max(maximum,0.1))
 updateHold()
end
local function beginSprint(input)
 if focused and active() and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then touch=input updateHold() end
end
connect(panel.Sprint.InputBegan,beginSprint)
connect(mobileSprint.InputBegan,beginSprint)
connect(UserInputService.InputEnded,function(input)
 if input==touch then touch=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift then keys[input.KeyCode]=nil end
 updateHold()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touch and input.UserInputState==Enum.UserInputState.Cancel then touch=nil updateHold() end
end)
connect(UserInputService.WindowFocusReleased,function() focused=false release() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,release)
connect(player.CharacterRemoving,release)
connect(player.CharacterAdded,release)
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then elapsed=0 refresh() end
 if held and os.clock()-lease>=0.3 then lease=os.clock() request(true) end
end)
connect(script.Destroying,function()
 release()
 alive=false requestSerial+=1
 if bound then ContextActionService:UnbindAction("TagSprint") end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

