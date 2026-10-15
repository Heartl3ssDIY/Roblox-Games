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
 build.Source="return function(game)\n"..[======[local RunService=game:GetService("RunService")
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
return out]======].."\nend"
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
  local source=name=="TagHUD"and[======[local Players=game:GetService("Players")
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
]======]or[======[local Players=game:GetService("Players")
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

]======]
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
