local p=game.Players.LocalPlayer
local g=script.Parent
local b=g.UseAbility
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local remote=game.ReplicatedStorage:WaitForChild("GBloxAbilityEvent")
local pendingUntil,localCooldown,messageUntil=0,0,0
local statusMessage=""
local notices={}
local definitions=require(game.ReplicatedStorage:WaitForChild("GBloxAbilityRules")).Definitions
local function allowed()
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 local settings=p.PlayerGui:FindFirstChild("GBloxSettings")
 local id=p:GetAttribute("GBloxEquippedAbility")
 local seasonal=id=="Pumpkin" or id=="Web"
 return definitions[id]~=nil
  and (not seasonal or p:GetAttribute("AbilityOwned_"..id)==true)
  and p:GetAttribute("RunnerStatus")=="Running" and root and not root.Anchored
  and (p:GetAttribute("GBloxCornerWebHeldUntil") or 0)<=workspace:GetServerTimeNow()
  and not (settings and settings.Panel.Visible)
  and (p:GetAttribute("AbilityUnlimited_"..tostring(id))==true
   or (p:GetAttribute("AbilityUses_"..tostring(id)) or 0)>0
   or p:GetAttribute("GBloxAbilityActiveThisGame")==true)
end
local function usedThisRound()
 return p:GetAttribute("GBloxEquippedAbility")=="Superspeed"
  and p:GetAttribute("GBloxAbilityUsedRound")~=nil
  and p:GetAttribute("GBloxAbilityUsedRound")==p:GetAttribute("GBloxAbilityRoundKey")
end
local function activate()
 local now=workspace:GetServerTimeNow()
 if not allowed() or usedThisRound() or UIS:GetFocusedTextBox() or now<pendingUntil
  or now<math.max(localCooldown,p:GetAttribute("GBloxAbilityCooldownUntil") or 0) then return end
 pendingUntil=now+1.5
 remote:FireServer("Activate")
end
b.Activated:Connect(activate)
CAS:BindActionAtPriority("GBloxUseAbility",function(_,state)
 if not allowed() or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then activate() end
 return Enum.ContextActionResult.Sink
end,false,4100,Enum.KeyCode.E,Enum.KeyCode.ButtonX)
remote.OnClientEvent:Connect(function(action,data)
 local now=workspace:GetServerTimeNow()
 if action=="Result" and typeof(data)=="table" then
  pendingUntil=0
  if typeof(data.cooldownUntil)=="number" then localCooldown=data.cooldownUntil end
  if data.message then statusMessage=data.message messageUntil=now+3 end
 elseif action=="Announcement" and typeof(data)=="string" then
  table.insert(notices,{text=data,expires=now+4})
  if #notices>3 then table.remove(notices,1) end
 end
end)
local function clearActivationState()
 pendingUntil,localCooldown,messageUntil=0,0,0
 statusMessage=""
end
p:GetAttributeChangedSignal("GBloxEquippedAbility"):Connect(clearActivationState)
p:GetAttributeChangedSignal("GBloxAbilityRoundKey"):Connect(clearActivationState)
p.CharacterRemoving:Connect(clearActivationState)
local function layout()
 local small=g.AbsoluteSize.X<700
 b.Size=UDim2.fromOffset(small and 116 or 155,small and 79 or 105)
 b.Hint.TextSize=small and 11 or 14
 g.Announcement.TextSize=small and 14 or 22
end
g:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({b}) end) end)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.1 then return end elapsed=0
 local now=workspace:GetServerTimeNow()
 b.Visible=allowed()==true
 local left=math.max(0,math.max(localCooldown,p:GetAttribute("GBloxAbilityCooldownUntil") or 0)-now)
 b.Active=b.Visible and not usedThisRound() and left<=0 and now>=pendingUntil
 b.Cooldown.Visible=usedThisRound() or left>0 or now<pendingUntil
 b.Cooldown.Seconds.Text=usedThisRound() and "USED" or left>0 and tostring(math.ceil(left)) or "..."
 local gamepad=UIS:GetLastInputType().Name:find("Gamepad")~=nil
 b.GamepadKey.Visible=gamepad and now>=messageUntil
 if gamepad then b.GamepadKey.Image=UIS:GetImageForKeyCode(Enum.KeyCode.ButtonX) end
 b.Hint.Text=now<messageUntil and statusMessage or (string.upper((definitions[p:GetAttribute("GBloxEquippedAbility")] or {Name="Ability"}).Name)..(p:GetAttribute("GBloxAbilityPractice") and " (PRACTICE)" or "")..(gamepad and "" or UIS:GetLastInputType()==Enum.UserInputType.Touch and "\nTAP TO USE" or "\nE"))
 local text={}
 for i=#notices,1,-1 do if notices[i].expires<=now then table.remove(notices,i) end end
 for _,notice in notices do table.insert(text,notice.text) end
 g.Announcement.Text=table.concat(text,"\n")
end)

