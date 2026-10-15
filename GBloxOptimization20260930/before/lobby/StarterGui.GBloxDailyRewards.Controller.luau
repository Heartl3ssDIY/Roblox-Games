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
local remote=RS:WaitForChild("GBloxDailyRewards")
local state,pending,autoOpened=nil,false,false
local lastRefresh=-math.huge
local popTween
local assetsReady=false
task.spawn(function()
 local ok,err=pcall(function()
  -- Preload the image instances (including hidden claim stamps and Day 7's button).
  game:GetService("ContentProvider"):PreloadAsync({panel,gui.Calendar})
 end)
 if not ok then warn("[DailyRewards] Image preload:",err) end
 assetsReady=true
end)
-- A slow asset service must not permanently prevent the player opening rewards.
task.delay(15,function() assetsReady=true end)
local function localOffset()
 local timestamp=math.floor(workspace:GetServerTimeNow())
 local localTime=DateTime.fromUnixTimestamp(timestamp):ToLocalTime()
 local localAsUTC=DateTime.fromUniversalTime(localTime.Year,localTime.Month,localTime.Day,localTime.Hour,localTime.Minute,localTime.Second).UnixTimestamp
 return math.round((localAsUTC-timestamp)/60)
end
local function otherPanelOpen()
 if player:GetAttribute("GBloxCommunityRewardsOpen") or player:GetAttribute("GBloxPlaytimeRewardsOpen") then return true end
 local shop=pg:FindFirstChild("GBloxShopMockups")
 local canvas=shop and shop:FindFirstChild("Canvas")
 if shop and shop.Enabled and canvas and canvas.Visible then
  for _,name in {"Shop","Abilities","Inventory","Pets"} do
   local p=canvas:FindFirstChild(name)
   if p and p.Visible then return true end
  end
 end
 local settings=pg:FindFirstChild("GBloxSettings")
 return settings and settings.Enabled and settings.Panel.Visible or false
end
local function canShow()
 return player:GetAttribute("GBloxLobbyReady")==true
  and not player:GetAttribute("GBloxInParty") and not player:GetAttribute("OnTreadmill")
end
local function render()
 content.Count.Text=state and tostring(state.Claimed).."/7 Claimed" or "Loading rewards..."
 for day=1,7 do
  local card=content["Day"..day]
  card.Claimed.Visible=state~=nil and day<=state.Claimed
  card.Claim.Visible=state~=nil and state.CanClaim and state.NextDay==day
  card.Claim.Active=card.Claim.Visible and not pending
  card.Claim.Selectable=card.Claim.Active
  card.Claim.ImageColor3=pending and Color3.fromRGB(150,175,180) or Color3.new(1,1,1)
 end
 gui.Calendar.Available.Visible=state~=nil and state.CanClaim
 gui.Calendar.Visible=assetsReady and canShow() and not panel.Visible and not otherPanelOpen()
end
local function fitScale()
 local size=gui.AbsoluteSize
 return math.max(.1,math.min(1,(size.X-40)/1100,(size.Y-42)/706))
end
local function resize()
 if popTween then popTween:Cancel() popTween=nil end
 panel.ResponsiveScale.Scale=fitScale()
 local small=gui.AbsoluteSize.X<650
 gui.Calendar.Size=UDim2.fromOffset(small and 44 or 52,small and 44 or 52)
 gui.Calendar.Position=UDim2.new(0,small and 68 or 80,1,-12)
end
local function close()
 panel.Visible=false gui.Shade.Visible=false
 player:SetAttribute("GBloxDailyRewardsOpen",false)
 render()
end
local function request(action)
 if pending or player:GetAttribute("PlayerDataReady")~=true then return end
 pending=true render()
 if action=="Claim" then content.Status.Text="Claiming..." end
 local ok,result=pcall(function() return remote:InvokeServer(action,localOffset()) end)
 pending=false lastRefresh=os.clock()
 if ok and typeof(result)=="table" then
  if result.State then state=result.State end
  content.Status.Text=result.Message or (state and state.CanClaim and "Your next reward is ready to claim!" or "Today's reward is claimed. Come back after local midnight.")
 else
  content.Status.Text="Couldn't connect. Reopen the calendar to try again."
 end
 render()
end
local function open()
 if not assetsReady or not canShow() or otherPanelOpen() then return end
 autoOpened=true panel.Visible=true gui.Shade.Visible=true
 player:SetAttribute("GBloxDailyRewardsOpen",true)
 if popTween then popTween:Cancel() end
 local target=fitScale()
 panel.ResponsiveScale.Scale=target*.94
 popTween=Tween:Create(panel.ResponsiveScale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=target})
 popTween:Play()
 render()
 task.spawn(request,"Status")
end
panel.Close.Activated:Connect(close)
gui.Shade.Activated:Connect(close)
gui.Calendar.Activated:Connect(open)
for day=1,7 do
 content["Day"..day].Claim.Activated:Connect(function()
  if not panel.Visible or pending or not state or not state.CanClaim or state.NextDay~=day then return end
  request("Claim")
 end)
end
UIS.InputBegan:Connect(function(input,processed)
 if panel.Visible and not processed and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close() end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.5 then return end elapsed=0
 if panel.Visible and (not canShow() or otherPanelOpen()) then close() end
 render()
 if player:GetAttribute("PlayerDataReady")==true and not pending then
  local reset=state and workspace:GetServerTimeNow()>=state.NextReset
  if os.clock()-lastRefresh>30 or (reset and os.clock()-lastRefresh>1) then task.spawn(request,"Status") end
 end
 local menu=pg:FindFirstChild("GBloxMenu")
 local menuFinished=not menu or not menu.Enabled or menu:GetAttribute("State")=="Lobby"
 if not autoOpened and canShow() and menuFinished and not otherPanelOpen() then open() end
end)
resize() close()

