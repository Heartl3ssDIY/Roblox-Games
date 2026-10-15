assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing mobile controls.")
assert(game.PlaceId==95034648955135,"This installer is for Playground Classics.")
local StarterGui=game:GetService("StarterGui")
local ServerStorage=game:GetService("ServerStorage")
local changes={
 {gui="TagHUD",name="SprintController",before=[======[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("SprintPanel")
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
 progress(remaining/math.max(maximum,0.1))
 updateHold()
end
connect(panel.Sprint.InputBegan,function(input)
 if focused and active() and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then touch=input updateHold() end
end)
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
]======],after=[======[local Players=game:GetService("Players")
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
 mobileSprint.Text=caption.."\nHOLD"
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
]======]},
 {gui="BritishBulldogHUD",name="MovementController",before=[======[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local gui=script.Parent
local controls=gui:WaitForChild("MovementControls")
local meter=controls:WaitForChild("Meter")
local sprint=controls:WaitForChild("Sprint")
local dodge=controls:WaitForChild("Dodge")
local boost=controls:WaitForChild("EscapeBoost")
local gradient=meter.Track.Fill.Progress
local blue=Color3.fromRGB(42,160,255)
local red=Color3.fromRGB(255,81,92)
local yellow=Color3.fromRGB(255,204,54)
local actionName="BritishBulldogSprintHold"
local connections={}
local shiftKeys={}
local touchHold=nil
local focused=true
local alive=true
local bound=false
local lastKeepalive=0
local requestPending=nil
local requestRunning=false
local sprintSerial=0
local requestedHeld=false
local dodgeBusy=false
local dodgeSerial=0
local dodgeNoticeUntil=0
local dodgeNotice=""
local lastDodgeDirection=1
local jumpHumanoid=nil
local jumpWasEnabled=nil
local jumpBound=false
local jumpActionName="BritishBulldogNoJump"
local lastConfirmed=player:GetAttribute("BBDodgeConfirmedAt") or 0

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(object,name,fallback)
 local value=object and object:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function phase()
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 return state and state:GetAttribute("Phase") or "Waiting"
end

local function inputContext()
 local current=phase()
 return player:GetAttribute("BBParticipating")==true and (current=="Countdown" or current=="Crossing")
end

local function releaseJumpLock()
 if jumpHumanoid and jumpHumanoid.Parent and jumpWasEnabled~=nil then
  jumpHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,jumpWasEnabled)
 end
 jumpHumanoid=nil
 jumpWasEnabled=nil
 if jumpBound then ContextActionService:UnbindAction(jumpActionName) jumpBound=false end
end

local function syncJumpLock()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not alive or player:GetAttribute("BBParticipating")~=true or not humanoid then releaseJumpLock() return end
 if jumpHumanoid~=humanoid then
  releaseJumpLock()
  jumpHumanoid=humanoid
  jumpWasEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
 end
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 humanoid.Jump=false
 if not jumpBound then
  ContextActionService:BindActionAtPriority(jumpActionName,function()
   if alive and player:GetAttribute("BBParticipating")==true then return Enum.ContextActionResult.Sink end
   return Enum.ContextActionResult.Pass
  end,false,3000,Enum.PlayerActions.CharacterJump)
  jumpBound=true
 end
end

local function canSprint()
 local role=player:GetAttribute("BBRole")
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return inputContext() and phase()=="Crossing" and (role=="Runner" or role=="Bulldog")
  and player:GetAttribute("BBStatus")~="Safe" and player:GetAttribute("BBRagdolled")~=true and humanoid and humanoid.Health>0
end

local function requestSprint(value)
 requestPending=value==true
 if requestRunning or not alive then return end
 requestRunning=true sprintSerial+=1
 local serial=sprintSerial
 local worker=task.spawn(function()
  while requestPending~=nil and alive and serial==sprintSerial do
   local held=requestPending
   requestPending=nil
   local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
   if remote and remote:IsA("RemoteFunction") then
    pcall(function() remote:InvokeServer("Sprint",held) end)
   end
  end
  if serial==sprintSerial then requestRunning=false end
 end)
 task.delay(2,function()
  if serial==sprintSerial and requestRunning then sprintSerial+=1 requestRunning=false requestPending=nil pcall(task.cancel,worker) end
 end)
end

local function releaseHold()
 table.clear(shiftKeys)
 touchHold=nil
 requestedHeld=false
 requestSprint(false)
end

local function holdChanged()
 local held=focused and (next(shiftKeys)~=nil or touchHold~=nil) and canSprint()==true
 if held~=requestedHeld then
  requestedHeld=held
  requestSprint(held)
  lastKeepalive=os.clock()
 end
end

local function sprintAction(_,inputState,input)
 if not alive or not inputContext() then return Enum.ContextActionResult.Pass end
 if inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then
  shiftKeys[input.KeyCode]=nil
  holdChanged()
 elseif inputState==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  shiftKeys[input.KeyCode]=true
  holdChanged()
 end
 return Enum.ContextActionResult.Sink
end

local function syncBinding()
 local active=alive and inputContext()
 if active and not bound then
  ContextActionService:BindActionAtPriority(actionName,sprintAction,false,3000,Enum.KeyCode.LeftShift)
  bound=true
 elseif not active and bound then
  ContextActionService:UnbindAction(actionName)
  bound=false
  releaseHold()
 end
end

local function progress(fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,0),
   NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),
   NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),
   NumberSequenceKeypoint.new(1,1),
  })
 end
end

local function arenaRight()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 return bounds and bounds:IsA("BasePart") and bounds.CFrame.RightVector or Vector3.xAxis
end

local function dodgeDirection()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local right=arenaRight()
 if humanoid then
  local lateral=humanoid.MoveDirection:Dot(right)
  if math.abs(lateral)>0.12 then return lateral<0 and -1 or 1 end
 end
 if not root then return 1 end
 local nearest=nil
 local distance=math.huge
 local function consider(candidate)
  local target=candidate and candidate:FindFirstChild("HumanoidRootPart")
  if target then
   local delta=target.Position-root.Position
   local squared=delta:Dot(delta)
   if squared<distance then distance=squared nearest=target end
  end
 end
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=player and other:GetAttribute("BBParticipating")==true and other:GetAttribute("BBRole")=="Bulldog" then consider(other.Character) end
 end
 local bots=workspace:FindFirstChild("BritishBulldogPracticeBots")
 if bots then
  for _,bot in ipairs(bots:GetChildren()) do
   local outline=bot:FindFirstChild("BBOutline")
   if outline and outline:IsA("Highlight") and outline.OutlineColor.R>outline.OutlineColor.B then consider(bot) end
  end
 end
 if nearest then
  local away=(root.Position-nearest.Position):Dot(right)
  if math.abs(away)>0.1 then return away<0 and -1 or 1 end
 end
 return 1
end

local function dodgeEnabled()
 local arena=workspace:FindFirstChild("British Bulldog game")
 return arena~=nil and arena:GetAttribute("DodgeEnabled")==true
end
local function requestDodge()
 if not dodgeEnabled() then return end
 if dodgeBusy or not canSprint() or player:GetAttribute("BBRole")~="Runner" then return end
 if player:GetAttribute("BBStatus")~="Crossing" then return end
 if workspace:GetServerTimeNow()<numberAttribute(player,"BBDodgeReadyAt",0) then return end
 local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 dodgeBusy=true
 dodgeSerial+=1
 local serial=dodgeSerial
 lastDodgeDirection=dodgeDirection()
 local worker=task.spawn(function()
  local success,response=pcall(function() return remote:InvokeServer("Dodge",lastDodgeDirection) end)
  if not alive or serial~=dodgeSerial then return end
  dodgeBusy=false
  if not success or typeof(response)~="table" or not response.ok then
   dodgeNotice=success and typeof(response)=="table" and tostring(response.message or "TRY AGAIN") or "TRY AGAIN"
   dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
 task.delay(2,function()
  if serial==dodgeSerial and dodgeBusy then
   dodgeSerial+=1 dodgeBusy=false
   pcall(task.cancel,worker)
   dodgeNotice="TRY AGAIN" dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
end

local function refresh()
 syncJumpLock()
 syncBinding()
 local role=player:GetAttribute("BBRole") or "Spectator"
 local visible=inputContext() and role~="Tagged"
 controls.Visible=visible
 if not visible then if requestedHeld then releaseHold() end return end
 local maximum=math.max(0.1,numberAttribute(player,"BBSprintMax",role=="Bulldog" and 15 or 10))
 local remaining=math.clamp(numberAttribute(player,"BBSprintRemaining",maximum),0,maximum)
 local exhausted=player:GetAttribute("BBSprintExhausted")==true
 local color=role=="Bulldog" and red or role=="Tagged" and yellow or blue
 meter.Role.Text=role=="Bulldog" and "BULLDOG" or role=="Tagged" and "TAGGED" or "RUNNER"
 meter.Charge.Text=string.format("%.1fs / %ds",remaining,math.floor(maximum+0.5))
 meter.Track.Fill.BackgroundColor3=color
 progress(remaining/maximum)
 sprint.BackgroundColor3=color
 local holdHint=UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"
 sprint.Caption.Text=(exhausted and "RECHARGING" or player:GetAttribute("BBSprinting")==true and "SPRINTING" or "SPRINT").."\n"..holdHint
 sprint.AutoButtonColor=canSprint()==true
 dodge.Visible=role=="Runner" and dodgeEnabled()
 boost.Visible=role=="Runner" and numberAttribute(player,"BBBoostEndsAt",0)>workspace:GetServerTimeNow()
 local cooldown=math.max(0,numberAttribute(player,"BBDodgeReadyAt",0)-workspace:GetServerTimeNow())
 dodge.Caption.Text=workspace:GetServerTimeNow()<dodgeNoticeUntil and ("DODGE\n"..dodgeNotice) or cooldown>0 and string.format("DODGE\n%.1fs",cooldown) or UserInputService.TouchEnabled and "DODGE\nTAP" or "DODGE\n[E]"
 dodge.AutoButtonColor=canSprint()==true and player:GetAttribute("BBStatus")=="Crossing" and cooldown<=0
 if not canSprint() and requestedHeld then releaseHold() end
 holdChanged()
 local confirmed=numberAttribute(player,"BBDodgeConfirmedAt",0)
 if confirmed>lastConfirmed then lastConfirmed=confirmed end
end

connect(sprint.InputBegan,function(input)
 if not focused or not canSprint() then return end
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  touchHold=input
  holdChanged()
 end
end)
connect(sprint.InputEnded,function(input)
 if input==touchHold then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputEnded,function(input)
 if input==touchHold then touchHold=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift then shiftKeys[input.KeyCode]=nil end
 holdChanged()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touchHold and (input.UserInputState==Enum.UserInputState.Cancel or input.UserInputState==Enum.UserInputState.End) then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputBegan,function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.E and focused and not UserInputService:GetFocusedTextBox() then requestDodge() end
end)
connect(dodge.Activated,requestDodge)
connect(UserInputService.WindowFocusReleased,function() focused=false releaseHold() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,releaseHold)
connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() end)
connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() syncJumpLock() end)
connect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)
connect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)
connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then
  elapsed=0
  refresh()
 end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 releaseHold()
 alive=false
 dodgeSerial+=1 sprintSerial+=1
 releaseJumpLock()
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]======],after=[======[local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local gui=script.Parent
local controls=gui:WaitForChild("MovementControls")
local meter=controls:WaitForChild("Meter")
local sprint=controls:WaitForChild("Sprint")
local mobileSprint=gui:WaitForChild("MobileSprint")
local dodge=controls:WaitForChild("Dodge")
local boost=controls:WaitForChild("EscapeBoost")
local gradient=meter.Track.Fill.Progress
local blue=Color3.fromRGB(42,160,255)
local red=Color3.fromRGB(255,81,92)
local yellow=Color3.fromRGB(255,204,54)
local actionName="BritishBulldogSprintHold"
local connections={}
local shiftKeys={}
local touchHold=nil
local focused=true
local alive=true
local bound=false
local lastKeepalive=0
local requestPending=nil
local requestRunning=false
local sprintSerial=0
local requestedHeld=false
local dodgeBusy=false
local dodgeSerial=0
local dodgeNoticeUntil=0
local dodgeNotice=""
local lastDodgeDirection=1
local jumpHumanoid=nil
local jumpWasEnabled=nil
local jumpBound=false
local jumpActionName="BritishBulldogNoJump"
local lastConfirmed=player:GetAttribute("BBDodgeConfirmedAt") or 0

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(object,name,fallback)
 local value=object and object:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function phase()
 local state=ReplicatedStorage:FindFirstChild("BritishBulldogState")
 return state and state:GetAttribute("Phase") or "Waiting"
end

local function inputContext()
 local current=phase()
 return player:GetAttribute("BBParticipating")==true and (current=="Countdown" or current=="Crossing")
end

local function releaseJumpLock()
 if jumpHumanoid and jumpHumanoid.Parent and jumpWasEnabled~=nil then
  jumpHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,jumpWasEnabled)
 end
 jumpHumanoid=nil
 jumpWasEnabled=nil
 if jumpBound then ContextActionService:UnbindAction(jumpActionName) jumpBound=false end
end

local function syncJumpLock()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not alive or player:GetAttribute("BBParticipating")~=true or not humanoid then releaseJumpLock() return end
 if jumpHumanoid~=humanoid then
  releaseJumpLock()
  jumpHumanoid=humanoid
  jumpWasEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
 end
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 humanoid.Jump=false
 if not jumpBound then
  ContextActionService:BindActionAtPriority(jumpActionName,function()
   if alive and player:GetAttribute("BBParticipating")==true then return Enum.ContextActionResult.Sink end
   return Enum.ContextActionResult.Pass
  end,false,3000,Enum.PlayerActions.CharacterJump)
  jumpBound=true
 end
end

local function canSprint()
 local role=player:GetAttribute("BBRole")
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return inputContext() and phase()=="Crossing" and (role=="Runner" or role=="Bulldog")
  and player:GetAttribute("BBStatus")~="Safe" and player:GetAttribute("BBRagdolled")~=true and humanoid and humanoid.Health>0
end

local function requestSprint(value)
 requestPending=value==true
 if requestRunning or not alive then return end
 requestRunning=true sprintSerial+=1
 local serial=sprintSerial
 local worker=task.spawn(function()
  while requestPending~=nil and alive and serial==sprintSerial do
   local held=requestPending
   requestPending=nil
   local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
   if remote and remote:IsA("RemoteFunction") then
    pcall(function() remote:InvokeServer("Sprint",held) end)
   end
  end
  if serial==sprintSerial then requestRunning=false end
 end)
 task.delay(2,function()
  if serial==sprintSerial and requestRunning then sprintSerial+=1 requestRunning=false requestPending=nil pcall(task.cancel,worker) end
 end)
end

local function releaseHold()
 table.clear(shiftKeys)
 touchHold=nil
 requestedHeld=false
 requestSprint(false)
end

local function holdChanged()
 local held=focused and (next(shiftKeys)~=nil or touchHold~=nil) and canSprint()==true
 if held~=requestedHeld then
  requestedHeld=held
  requestSprint(held)
  lastKeepalive=os.clock()
 end
end

local function sprintAction(_,inputState,input)
 if not alive or not inputContext() then return Enum.ContextActionResult.Pass end
 if inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then
  shiftKeys[input.KeyCode]=nil
  holdChanged()
 elseif inputState==Enum.UserInputState.Begin then
  if not focused or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
  shiftKeys[input.KeyCode]=true
  holdChanged()
 end
 return Enum.ContextActionResult.Sink
end

local function syncBinding()
 local active=alive and inputContext()
 if active and not bound then
  ContextActionService:BindActionAtPriority(actionName,sprintAction,false,3000,Enum.KeyCode.LeftShift)
  bound=true
 elseif not active and bound then
  ContextActionService:UnbindAction(actionName)
  bound=false
  releaseHold()
 end
end

local function progress(fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,0),
   NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),
   NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),
   NumberSequenceKeypoint.new(1,1),
  })
 end
end

local function arenaRight()
 local arena=workspace:FindFirstChild("British Bulldog game")
 local gameplay=arena and arena:FindFirstChild("Gameplay")
 local bounds=gameplay and gameplay:FindFirstChild("ArenaBounds")
 return bounds and bounds:IsA("BasePart") and bounds.CFrame.RightVector or Vector3.xAxis
end

local function dodgeDirection()
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local right=arenaRight()
 if humanoid then
  local lateral=humanoid.MoveDirection:Dot(right)
  if math.abs(lateral)>0.12 then return lateral<0 and -1 or 1 end
 end
 if not root then return 1 end
 local nearest=nil
 local distance=math.huge
 local function consider(candidate)
  local target=candidate and candidate:FindFirstChild("HumanoidRootPart")
  if target then
   local delta=target.Position-root.Position
   local squared=delta:Dot(delta)
   if squared<distance then distance=squared nearest=target end
  end
 end
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=player and other:GetAttribute("BBParticipating")==true and other:GetAttribute("BBRole")=="Bulldog" then consider(other.Character) end
 end
 local bots=workspace:FindFirstChild("BritishBulldogPracticeBots")
 if bots then
  for _,bot in ipairs(bots:GetChildren()) do
   local outline=bot:FindFirstChild("BBOutline")
   if outline and outline:IsA("Highlight") and outline.OutlineColor.R>outline.OutlineColor.B then consider(bot) end
  end
 end
 if nearest then
  local away=(root.Position-nearest.Position):Dot(right)
  if math.abs(away)>0.1 then return away<0 and -1 or 1 end
 end
 return 1
end

local function dodgeEnabled()
 local arena=workspace:FindFirstChild("British Bulldog game")
 return arena~=nil and arena:GetAttribute("DodgeEnabled")==true
end
local function requestDodge()
 if not dodgeEnabled() then return end
 if dodgeBusy or not canSprint() or player:GetAttribute("BBRole")~="Runner" then return end
 if player:GetAttribute("BBStatus")~="Crossing" then return end
 if workspace:GetServerTimeNow()<numberAttribute(player,"BBDodgeReadyAt",0) then return end
 local remote=ReplicatedStorage:FindFirstChild("BBMovementRequest")
 if not remote or not remote:IsA("RemoteFunction") then return end
 dodgeBusy=true
 dodgeSerial+=1
 local serial=dodgeSerial
 lastDodgeDirection=dodgeDirection()
 local worker=task.spawn(function()
  local success,response=pcall(function() return remote:InvokeServer("Dodge",lastDodgeDirection) end)
  if not alive or serial~=dodgeSerial then return end
  dodgeBusy=false
  if not success or typeof(response)~="table" or not response.ok then
   dodgeNotice=success and typeof(response)=="table" and tostring(response.message or "TRY AGAIN") or "TRY AGAIN"
   dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
 task.delay(2,function()
  if serial==dodgeSerial and dodgeBusy then
   dodgeSerial+=1 dodgeBusy=false
   pcall(task.cancel,worker)
   dodgeNotice="TRY AGAIN" dodgeNoticeUntil=workspace:GetServerTimeNow()+1.4
  end
 end)
end

local function refresh()
 syncJumpLock()
 syncBinding()
 local role=player:GetAttribute("BBRole") or "Spectator"
 local visible=inputContext() and role~="Tagged"
 controls.Visible=visible
 local touchMode=UserInputService.TouchEnabled
 sprint.Visible=not touchMode
 mobileSprint.Visible=visible and touchMode
 if not visible then if requestedHeld then releaseHold() end return end
 local maximum=math.max(0.1,numberAttribute(player,"BBSprintMax",role=="Bulldog" and 15 or 10))
 local remaining=math.clamp(numberAttribute(player,"BBSprintRemaining",maximum),0,maximum)
 local exhausted=player:GetAttribute("BBSprintExhausted")==true
 local color=role=="Bulldog" and red or role=="Tagged" and yellow or blue
 meter.Role.Text=role=="Bulldog" and "BULLDOG" or role=="Tagged" and "TAGGED" or "RUNNER"
 meter.Charge.Text=string.format("%.1fs / %ds",remaining,math.floor(maximum+0.5))
 meter.Track.Fill.BackgroundColor3=color
 progress(remaining/maximum)
 sprint.BackgroundColor3=color
 local holdHint=UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"
 sprint.Caption.Text=(exhausted and "RECHARGING" or player:GetAttribute("BBSprinting")==true and "SPRINTING" or "SPRINT").."\n"..holdHint
 sprint.AutoButtonColor=canSprint()==true
 mobileSprint.Text=(exhausted and "RECHARGING" or player:GetAttribute("BBSprinting")==true and "SPRINTING" or "SPRINT").."\nHOLD"
 mobileSprint.BackgroundColor3=color
 mobileSprint.AutoButtonColor=canSprint()==true
 dodge.Visible=role=="Runner" and dodgeEnabled()
 boost.Visible=role=="Runner" and numberAttribute(player,"BBBoostEndsAt",0)>workspace:GetServerTimeNow()
 local cooldown=math.max(0,numberAttribute(player,"BBDodgeReadyAt",0)-workspace:GetServerTimeNow())
 dodge.Caption.Text=workspace:GetServerTimeNow()<dodgeNoticeUntil and ("DODGE\n"..dodgeNotice) or cooldown>0 and string.format("DODGE\n%.1fs",cooldown) or UserInputService.TouchEnabled and "DODGE\nTAP" or "DODGE\n[E]"
 dodge.AutoButtonColor=canSprint()==true and player:GetAttribute("BBStatus")=="Crossing" and cooldown<=0
 if not canSprint() and requestedHeld then releaseHold() end
 holdChanged()
 local confirmed=numberAttribute(player,"BBDodgeConfirmedAt",0)
 if confirmed>lastConfirmed then lastConfirmed=confirmed end
end

local function beginSprint(input)
 if not focused or not canSprint() then return end
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  touchHold=input
  holdChanged()
 end
end
connect(sprint.InputBegan,beginSprint)
connect(mobileSprint.InputBegan,beginSprint)
connect(sprint.InputEnded,function(input)
 if input==touchHold then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputEnded,function(input)
 if input==touchHold then touchHold=nil end
 if input.KeyCode==Enum.KeyCode.LeftShift then shiftKeys[input.KeyCode]=nil end
 holdChanged()
end)
connect(UserInputService.InputChanged,function(input)
 if input==touchHold and (input.UserInputState==Enum.UserInputState.Cancel or input.UserInputState==Enum.UserInputState.End) then touchHold=nil holdChanged() end
end)
connect(UserInputService.InputBegan,function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.E and focused and not UserInputService:GetFocusedTextBox() then requestDodge() end
end)
connect(dodge.Activated,requestDodge)
connect(UserInputService.WindowFocusReleased,function() focused=false releaseHold() end)
connect(UserInputService.WindowFocused,function() focused=true end)
connect(UserInputService.TextBoxFocused,releaseHold)
connect(player.CharacterRemoving,function() releaseHold() releaseJumpLock() end)
connect(player.CharacterAdded,function() releaseHold() releaseJumpLock() syncJumpLock() end)
connect(player:GetAttributeChangedSignal("BBParticipating"),syncJumpLock)
connect(UserInputService.JumpRequest,function() if jumpHumanoid then jumpHumanoid.Jump=false end end)
connect(RunService.PreSimulation,function()
 if jumpHumanoid then jumpHumanoid.Jump=false end
end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.05 then
  elapsed=0
  refresh()
 end
 if requestedHeld and os.clock()-lastKeepalive>=0.3 then lastKeepalive=os.clock() requestSprint(true) end
end)
connect(script.Destroying,function()
 releaseHold()
 alive=false
 dodgeSerial+=1 sprintSerial+=1
 releaseJumpLock()
 if bound then ContextActionService:UnbindAction(actionName) bound=false end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh()

]======]},
 {gui="MudHUD",name="Controller",before=[======[local Players=game:GetService("Players")
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
connect(controls.Sprint.InputBegan,function(input)
 if playing() and focused and not palette.Visible and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then sprintTouch=input sprintChange() end
end)
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

]======],after=[======[local Players=game:GetService("Players")
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
refresh()]======]},
}
for _,change in ipairs(changes)do
 local target=StarterGui[change.gui][change.name]
 assert(target.Source==change.before,"Source changed: "..target:GetFullName())
end
for _,parent in ipairs({StarterGui.TagHUD,StarterGui.BritishBulldogHUD,StarterGui.MudHUD.Main})do
 assert(not parent:FindFirstChild("MobileSprint"),"MobileSprint is already installed.")
end
assert(not ServerStorage:FindFirstChild("MudMobileUiBackup20261008"),"Mobile backup already exists.")
local backup=Instance.new("Folder")
backup.Name="MudMobileUiBackup20261008"
backup.Parent=ServerStorage
for _,name in ipairs({"TagHUD","BritishBulldogHUD","MudHUD"})do
 local clone=StarterGui[name]:Clone()
 clone.Parent=backup
end
local function build()
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
assert(not RunService:IsRunning(),"Stop Play before installing mobile sprint buttons.")
assert(game.PlaceId==95034648955135,"This installer is for Playground Classics.")
local template=StarterGui.TagHUD.SprintPanel.Sprint
local parents={
 StarterGui.BritishBulldogHUD,
 StarterGui.TagHUD,
 StarterGui.MudHUD.Main,
}
for _,parent in ipairs(parents) do
 assert(not parent:FindFirstChild("MobileSprint"),parent:GetFullName().." already has MobileSprint.")
end
local out={}
for _,parent in ipairs(parents) do
 local button=template:Clone()
 button.Name="MobileSprint"
 button.AnchorPoint=Vector2.new(0,1)
 button.Position=UDim2.new(0,18,1,-202)
 button.Size=UDim2.fromOffset(120,54)
 button.Visible=false
 button.Active=true
 button.Selectable=false
 button.AutoButtonColor=false
 button.ZIndex=20
 button.Text="SPRINT\nHOLD"
 button.TextTransparency=1
 button.TextStrokeTransparency=1
 button:SetAttribute("UserArtworkManaged",nil)
 button:SetAttribute("ArtworkAsset",nil)
 button:SetAttribute("ArtworkText",nil)
 button:SetAttribute("MobileSprintPlacement","LeftAboveJoystick")
 button:SetAttribute("TouchHold",true)
 local skin=button:FindFirstChild("ReusableSkin")
 if skin then skin.ZIndex=20 end
 local label=button:FindFirstChild("LiveCaption")
 if label then
  label.Position=UDim2.fromScale(0.075,0.08)
  label.Size=UDim2.fromScale(0.85,0.78)
  label.Text="SPRINT\nHOLD"
  label.TextScaled=true
  label.TextWrapped=false
  label.ZIndex=21
  local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
  if not limit then limit=Instance.new("UITextSizeConstraint") limit.Parent=label end
  limit.MinTextSize=10
  limit.MaxTextSize=18
 end
 button.Parent=parent
 table.insert(out,button:GetFullName())
end
local controls=StarterGui.MudHUD.Main.Controls
controls.AnchorPoint=Vector2.zero
controls.Position=UDim2.fromScale(0,0)
controls.Size=UDim2.fromScale(1,1)
controls.Active=false
local scale=controls:FindFirstChild("ResponsiveHudScale")
if scale then
 scale.Scale=1
 scale:SetAttribute("PhoneScale",1)
 scale:SetAttribute("TabletScale",1)
 scale:SetAttribute("DesktopScale",1)
end
controls.Meter.AnchorPoint=Vector2.new(0.5,1)
controls.Meter.Position=UDim2.new(0.5,0,1,-18)
controls.Meter.Size=UDim2.fromOffset(200,36)
controls.Mud.AnchorPoint=Vector2.new(1,1)
controls.Mud.Position=UDim2.new(1,-88,1,-238)
controls.Mud.Size=UDim2.fromOffset(62,44)
controls.Heat.AnchorPoint=Vector2.new(1,1)
controls.Heat.Position=UDim2.new(1,-18,1,-238)
controls.Heat.Size=UDim2.fromOffset(62,44)
controls.Fire.AnchorPoint=Vector2.new(1,1)
controls.Fire.Position=UDim2.new(1,-18,1,-180)
controls.Fire.Size=UDim2.fromOffset(132,54)
controls.Sprint.Visible=false
for _,button in ipairs({controls.Mud,controls.Heat,controls.Fire}) do
 button.ZIndex=20
 for _,child in ipairs(button:GetChildren()) do
  if child:IsA("GuiObject") then child.ZIndex=child:IsA("TextLabel") and 21 or 20 end
 end
end
return out
end
local buttons=build()
for _,change in ipairs(changes)do StarterGui[change.gui][change.name].Source=change.after end
return {buttons=buttons,backup=backup:GetFullName()}

