from pathlib import Path
import re

folder=Path(__file__).resolve().parent
before=folder/"Before"
after=folder/"After"

path="StarterGui.BritishBulldogHUD.MovementController.luau"
s=(before/path).read_text(encoding="utf-8")
s=s.replace('local animations={}\nlocal observers={}\n','')
s=s[:s.index('local function restorePose(animation)')]+s[s.index('local function requestDodge()'):]
s=s.replace('   syncDodgePose(player)','   lastDodgeDirection=lastDodgeDirection')
s=s.replace(' releaseJumpLock() stopPose(player)',' releaseJumpLock()')
s=s.replace('connect(Players.PlayerAdded,observePlayer)\nconnect(Players.PlayerRemoving,unobservePlayer)\nfor _,target in ipairs(Players:GetPlayers()) do observePlayer(target) end\n','')
a=s.index('connect(RunService.PreAnimation,function()')
b=s.index('local elapsed=0',a)
s=s[:a]+'connect(RunService.PreSimulation,function()\n if jumpHumanoid then jumpHumanoid.Jump=false end\nend)\n'+s[b:]
s=s.replace('  for target in pairs(observers) do syncDodgePose(target) end\n','')
s=s.replace(' for target in pairs(observers) do unobservePlayer(target) end\n','')
s=s.replace('  and player:GetAttribute("BBStatus")~="Safe" and humanoid and humanoid.Health>0', '  and player:GetAttribute("BBStatus")~="Safe" and player:GetAttribute("BBRagdolled")~=true and humanoid and humanoid.Health>0')
s=s.replace('local dodgeBusy=false','local dodgeBusy=false\nlocal dodgeSerial=0\nlocal dodgeNoticeUntil=0\nlocal dodgeNotice=""')
s=s.replace('local requestRunning=false', 'local requestRunning=false\nlocal sprintSerial=0')
s=s.replace(' if requestRunning then return end\n requestRunning=true\n task.spawn(function()', ' if requestRunning or not alive then return end\n requestRunning=true sprintSerial+=1\n local serial=sprintSerial\n local worker=task.spawn(function()')
s=s.replace('  while requestPending~=nil do', '  while requestPending~=nil and alive and serial==sprintSerial do')
s=s.replace('  requestRunning=false\n end)\nend', '  if serial==sprintSerial then requestRunning=false end\n end)\n task.delay(2,function()\n  if serial==sprintSerial and requestRunning then sprintSerial+=1 requestRunning=false requestPending=nil pcall(task.cancel,worker) end\n end)\nend',1)
a=s.index('local function requestDodge()')
b=s.index('\nlocal function refresh()',a)
s=s[:a]+'''local function requestDodge()
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
'''+s[b:]
s=s.replace(' dodge.Caption.Text=cooldown>0 and', ' dodge.Caption.Text=workspace:GetServerTimeNow()<dodgeNoticeUntil and ("DODGE\\n"..dodgeNotice) or cooldown>0 and')
s=s.replace(' alive=false\n releaseHold()', ' alive=false\n dodgeSerial+=1\n releaseHold()')
s=s.replace(' alive=false\n dodgeSerial+=1\n releaseHold()', ' releaseHold()\n alive=false\n dodgeSerial+=1 sprintSerial+=1')
(after/path).write_text(s,encoding="utf-8")

path="StarterGui.TagHUD.Controller.luau"
s=(before/path).read_text(encoding="utf-8")
s=s.replace('local gui = script.Parent','local gui = script.Parent\ngui.Enabled = false')
s=s.replace('local previousCamera\n','').replace('local movePose\n','local alive = true\nlocal moveSerial = 0\n')
a=s.index('local function camera(active)')
b=s.index('local function secondsRemaining',a)
s=s[:a]+s[b:]
s=s.replace('gui.Enabled = participating\n\tcamera(participating)\n\tif not participating then return end\n\tlocal phase = state:GetAttribute("Phase") or "Waiting"', 'local phase = state:GetAttribute("Phase") or "Waiting"\n\tgui.Enabled = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")\n\tif not gui.Enabled then return end')
a=s.index('\tfor _, action in ipairs({ "Vault", "Dodge" }) do')
b=s.index('\n\tgui.MoveMessage.Visible',a)
s=s[:a]+'''\tlocal button = controls.Dodge
\tlocal cooldown = secondsRemaining(player:GetAttribute("TGDodgeReadyAt"), now)
\tbutton.Text = "DODGE\\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or UserInputService.TouchEnabled and "TAP" or "[E]")
\tbutton.Active = cooldown == 0 and not busy and player:GetAttribute("TGRagdolled") ~= true
'''+s[b:]
s=s.replace('results.Title.TextColor3 = won and blue or red','results.Title.TextColor3 = Color3.fromRGB(255,248,221)')
s=s.replace('if not gui.Enabled then return end', 'if not gui.Enabled then return end\n\ttop.Visible = phase ~= "Results"')
a=s.index('local function move(action)')
b=s.index('player.AttributeChanged:Connect(update)',a)
s=s[:a]+'''local function dodgeDirection()
\tlocal character = player.Character
\tlocal root = character and character:FindFirstChild("HumanoidRootPart")
\tlocal humanoid = character and character:FindFirstChildOfClass("Humanoid")
\tlocal camera = workspace.CurrentCamera
\tlocal axis = camera and camera.CFrame.RightVector or Vector3.xAxis
\tlocal right = Vector3.new(axis.X, 0, axis.Z)
\tif right.Magnitude < 0.01 then right = Vector3.xAxis else right = right.Unit end
\tif not root then return right end
\tlocal lateral = humanoid and humanoid.MoveDirection:Dot(right) or 0
\tif math.abs(lateral)>0.12 then return right * (lateral<0 and -1 or 1) end
\tlocal nearest, distance
\tfor _, other in ipairs(Players:GetPlayers()) do
\t\tlocal candidate=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
\t\tif other~=player and candidate and other:GetAttribute("TGParticipating")==true and other:GetAttribute("TGRole")=="Tagger" then
\t\t\tlocal delta=candidate.Position-root.Position
\t\t\tif not distance or delta.Magnitude<distance then nearest,distance=candidate,delta.Magnitude end
\t\tend
\tend
\tif nearest then local away=(root.Position-nearest.Position):Dot(right) if math.abs(away)>.1 then return right * (away<0 and -1 or 1) end end
\treturn right
end

local function move()
\tif not alive or busy or player:GetAttribute("TGParticipating")~=true or player:GetAttribute("TGRagdolled")==true or state:GetAttribute("Phase")~="Playing" then return end
\tif secondsRemaining(player:GetAttribute("TGDodgeReadyAt"),workspace:GetServerTimeNow())>0 then return end
\tbusy=true moveSerial+=1
\tlocal serial=moveSerial
\tlocal direction=dodgeDirection()
\tlocal worker=task.spawn(function()
\t\tlocal ok,accepted,message=pcall(function() return movement:InvokeServer("Dodge",direction) end)
\t\tif not alive or serial~=moveSerial then return end
\t\tbusy=false
\t\tif not ok or not accepted then
\t\t\tgui.MoveMessage.Text=ok and tostring(message or "Move is not ready") or "Move couldn't be sent. Try again."
\t\t\tmessageEndsAt=workspace:GetServerTimeNow()+1.8
\t\tend
\t\tupdate()
\tend)
\ttask.delay(2,function()
\t\tif alive and serial==moveSerial and busy then
\t\t\tmoveSerial+=1 busy=false pcall(task.cancel,worker)
\t\t\tgui.MoveMessage.Text="Move couldn't be sent. Try again." messageEndsAt=workspace:GetServerTimeNow()+1.8
\t\tend
\tend)
end

controls.Dodge.Activated:Connect(move)
UserInputService.InputBegan:Connect(function(input, processed)
\tif processed or UserInputService:GetFocusedTextBox() then return end
\tif input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.X then move() end
end)
'''+s[b:]
a=s.index('RunService.PreSimulation:Connect(function()')
b=s.index('script.Destroying:Connect',a)
s=s[:a]+s[b:]
s=s.replace('script.Destroying:Connect(function() camera(false) end)','script.Destroying:Connect(function() alive=false moveSerial+=1 end)')
(after/path).write_text(s,encoding="utf-8")

path="StarterGui.TagHUD.SprintController.luau"
s=(before/path).read_text(encoding="utf-8")
s=s.replace('local function active() return player:GetAttribute("TGParticipating")==true and state:GetAttribute("Phase")=="Playing" end', '''local function active()
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("TGParticipating")==true and player:GetAttribute("TGRagdolled")~=true and state:GetAttribute("Phase")=="Playing" and humanoid and humanoid.Health>0
end''')
s=s.replace('local sending=false','local sending=false\nlocal requestSerial=0\nlocal alive=true')
s=s.replace(' if sending then return end\n sending=true\n task.spawn(function()', ' if sending or not alive then return end\n sending=true requestSerial+=1\n local serial=requestSerial\n local worker=task.spawn(function()')
s=s.replace('  while pending~=nil do','  while pending~=nil and alive and serial==requestSerial do')
s=s.replace('  sending=false\n end)\nend','  if serial==requestSerial then sending=false end\n end)\n task.delay(2,function()\n  if serial==requestSerial and sending then requestSerial+=1 sending=false pending=nil pcall(task.cancel,worker) end\n end)\nend',1)
s=s.replace(' if not panel.Visible then return end',' if not panel.Visible then release() return end')
s=s.replace('connect(script.Destroying,function()\n release()', 'connect(script.Destroying,function()\n release()\n alive=false requestSerial+=1')
(after/path).write_text(s,encoding="utf-8")
print("Prepared three movement clients")
