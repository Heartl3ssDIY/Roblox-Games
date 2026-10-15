local Players=game:GetService("Players")
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


