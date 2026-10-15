local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local gui=script.Parent
local panel=gui.Panel
local content=panel.Content
local remote=RS:WaitForChild("GBloxPlaytimeRewards")
local Rules=require(RS:WaitForChild("GBloxPlaytimeRules"))
local state,pending=nil,false
local lastRefresh=-math.huge
local receivedAt=0
local popTween
local function otherPanelOpen()
 if player:GetAttribute("GBloxDailyRewardsOpen") or player:GetAttribute("GBloxCommunityRewardsOpen") then return true end
 local shop=pg:FindFirstChild("GBloxShopMockups")
 local canvas=shop and shop:FindFirstChild("Canvas")
 if shop and shop.Enabled and canvas and canvas.Visible then
  for _,name in {"Shop","Abilities","Inventory","Pets"} do
   local p=canvas:FindFirstChild(name) if p and p.Visible then return true end
  end
 end
 local settings=pg:FindFirstChild("GBloxSettings")
 return settings and settings.Enabled and settings.Panel.Visible or false
end
local function canShow()
 return player:GetAttribute("GBloxLobbyReady")==true and not player:GetAttribute("GBloxInParty")
  and not player:GetAttribute("OnTreadmill") and not player:GetAttribute("GBloxPlaytimeTransferring")
end
local function formatTime(seconds)
 seconds=math.max(0,math.ceil(seconds))
 if seconds>=3600 then return string.format("%d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60) end
 return string.format("%02d:%02d",math.floor(seconds/60),seconds%60)
end
local function render()
 local elapsed=state and state.Elapsed+(os.clock()-receivedAt) or 0
 local available=false
 for i,reward in Rules.Rewards do
  local card=content["Reward"..i]
  local claimed=state and state.Claimed[tostring(i)]==true or false
  local ready=state~=nil and elapsed>=reward.Seconds and not claimed
  card.Timer.Text=claimed and "CLAIMED" or ready and "READY!" or formatTime(reward.Seconds-elapsed)
  card.Timer.TextColor3=ready and Color3.fromRGB(0,255,235) or Color3.new(1,1,1)
  card.Claimed.Visible=claimed
  card.Claim.Visible=ready
  card.Claim.Active=ready and not pending and not state.Transferring
  card.Claim.Selectable=card.Claim.Active
  card.Claim.ImageColor3=card.Claim.Active and Color3.new(1,1,1) or Color3.fromRGB(145,170,180)
  available=available or ready
 end
 gui.Clock.Available.Visible=available
 gui.Clock.Visible=canShow() and not panel.Visible and not otherPanelOpen()
end
local function fitScale()
 local size=gui.AbsoluteSize
 return math.max(.1,math.min(1,(size.X-32)/1128,(size.Y-32)/730))
end
local function resize()
 if popTween then popTween:Cancel() popTween=nil end
 panel.ResponsiveScale.Scale=fitScale()
 local small=gui.AbsoluteSize.X<650
 gui.Clock.Size=UDim2.fromOffset(small and 44 or 52,small and 44 or 52)
 gui.Clock.Position=UDim2.new(0,small and 122 or 144,1,-12)
end
local function close()
 panel.Visible=false gui.Shade.Visible=false
 player:SetAttribute("GBloxPlaytimeRewardsOpen",false)
 render()
end
local function request(action,index)
 if pending or player:GetAttribute("PlayerDataReady")~=true then return end
 pending=true render()
 if action=="Claim" then content.Status.Text="Claiming..." end
 local ok,result=pcall(function() return remote:InvokeServer(action,index) end)
 pending=false lastRefresh=os.clock()
 if ok and typeof(result)=="table" then
  if result.State then state=result.State receivedAt=os.clock() end
  if result.Message then content.Status.Text=result.Message
  elseif action=="Status" then content.Status.Text="Time carries through multiplayer. Leaving the experience resets this track." end
 else content.Status.Text="Couldn't connect. Reopen Playtime Rewards to retry." end
 render()
end
local function open()
 if not canShow() or otherPanelOpen() then return end
 panel.Visible=true gui.Shade.Visible=true player:SetAttribute("GBloxPlaytimeRewardsOpen",true)
 if popTween then popTween:Cancel() end
 local target=fitScale() panel.ResponsiveScale.Scale=target*.94
 popTween=Tween:Create(panel.ResponsiveScale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=target}) popTween:Play()
 render() task.spawn(request,"Status")
end
panel.Close.Activated:Connect(close)
gui.Shade.Activated:Connect(close)
gui.Clock.Activated:Connect(open)
gui.Clock.MouseEnter:Connect(function() gui.Clock.Tooltip.Visible=true end)
gui.Clock.MouseLeave:Connect(function() gui.Clock.Tooltip.Visible=false end)
for i=1,#Rules.Rewards do
 local button=content["Reward"..i].Claim
 button.Activated:Connect(function() if panel.Visible and not pending then request("Claim",i) end end)
 button.MouseEnter:Connect(function() Tween:Create(button.PopScale,TweenInfo.new(.15),{Scale=1.04}):Play() end)
 button.MouseLeave:Connect(function() Tween:Create(button.PopScale,TweenInfo.new(.15),{Scale=1}):Play() end)
 button.MouseButton1Down:Connect(function() Tween:Create(button.PopScale,TweenInfo.new(.08),{Scale=.96}):Play() end)
 button.MouseButton1Up:Connect(function() Tween:Create(button.PopScale,TweenInfo.new(.15),{Scale=1}):Play() end)
end
UIS.InputBegan:Connect(function(input,processed)
 if panel.Visible and not processed and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close() end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.25 then return end elapsed=0
 if panel.Visible and (not canShow() or otherPanelOpen()) then close() end
 render()
 if player:GetAttribute("PlayerDataReady")==true and not pending and os.clock()-lastRefresh>15 then task.spawn(request,"Status") end
end)
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({panel,gui.Clock}) end) end)
resize() close()
