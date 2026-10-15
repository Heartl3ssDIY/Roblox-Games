local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CS=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Groups=game:GetService("GroupService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local gui=script.Parent
local panel=gui.Panel
local Rules=require(RS:WaitForChild("GBloxCommunityRewardRules"))
local remote=RS:WaitForChild("GBloxCommunityRewards")
local state,busy,dismissed=nil,false,false
local gift,model
local pop
local ready=false
task.spawn(function()
 pcall(function() game:GetService("ContentProvider"):PreloadAsync({panel}) end)
 ready=true
end)
task.delay(12,function() ready=true end)
local function findGift()
 if gift and gift:IsDescendantOf(workspace) then return gift end
 for _,part in CS:GetTagged("GBloxCommunityGift") do if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
  gift=part model=part:FindFirstAncestorOfClass("Model") return part
 end end
 gift=nil model=nil
end
local function near(radius)
 local part=findGift()
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 return root and part and Rules.Near(root.Position,part:GetAttribute("GiftCenter") or part.Position,radius) or false
end
local function available()
 return player:GetAttribute("GBloxLobbyReady")==true and player:GetAttribute("PlayerDataReady")==true
  and not player:GetAttribute("GBloxInParty") and not player:GetAttribute("OnTreadmill")
end
local function otherPanel()
 if player:GetAttribute("GBloxDailyRewardsOpen") or player:GetAttribute("GBloxPlaytimeRewardsOpen") then return true end
 local settings=pg:FindFirstChild("GBloxSettings")
 if settings and settings.Enabled and settings.Panel.Visible then return true end
 local shop=pg:FindFirstChild("GBloxShopMockups")
 if shop and shop.Enabled and shop.Canvas.Visible then
  for _,name in {"Shop","Abilities","Inventory","Pets"} do local p=shop.Canvas:FindFirstChild(name) if p and p.Visible then return true end end
 end
 return false
end
local function fit()
 local size=gui.AbsoluteSize
 return math.max(.1,math.min(.68,(size.X-40)/984,(size.Y-68)/716))
end
local function resize()
 if pop then pop:Cancel() pop=nil end
 panel.ResponsiveScale.Scale=fit()
end
local function render()
 panel.CommunityClaimed.Visible=state~=nil and state.Community
 panel.LikeClaimed.Visible=state~=nil and state.Like
 for _,b in {panel.Community,panel.Heart} do
  b.Active=not busy
  b.Selectable=not busy
  b.ImageColor3=busy and Color3.fromRGB(165,180,185) or Color3.new(1,1,1)
 end
end
local function close()
 panel.Visible=false gui.Shade.Visible=false
 player:SetAttribute("GBloxCommunityRewardsOpen",false)
 dismissed=true
end
local function request(action)
 if busy then return end
 busy=true render()
 local ok,result=pcall(function() return remote:InvokeServer(action) end)
 busy=false
 if ok and typeof(result)=="table" then
  if result.State then state=result.State end
  panel.Status.Text=result.Message or "Each reward can only be claimed once."
 else panel.Status.Text="Connection error. Try a reward button again." end
 render()
 return ok and result or nil
end
local function open()
 if not ready or not available() or otherPanel() or not near(Rules.VisitRadius) then return end
 panel.Visible=true gui.Shade.Visible=true panel.PageLink.Visible=false
 player:SetAttribute("GBloxCommunityRewardsOpen",true)
 panel.Status.Text="Checking your rewards..."
 if pop then pop:Cancel() end
 local scale=fit() panel.ResponsiveScale.Scale=scale*.94
 pop=Tween:Create(panel.ResponsiveScale,TweenInfo.new(.23,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=scale})
 pop:Play()
 task.spawn(request,"Visit")
end
panel.Close.Activated:Connect(close)
gui.Shade.Activated:Connect(close)
panel.Heart.Activated:Connect(function()
 if busy or not panel.Visible then return end
 panel.PageLink.Visible=true
 local result=request("ThankYou")
 if result and result.State and result.State.Like then
  panel.Status.Text="Thank-you gift claimed! Open the G-Blox page below and tap thumbs-up. Select the link to copy it."
 end
end)
panel.PageLink.Focused:Connect(function()
 panel.PageLink.CursorPosition=#panel.PageLink.Text+1
 panel.PageLink.SelectionStart=1
end)
panel.Community.Activated:Connect(function()
 if busy or not panel.Visible then return end
 if state and state.Community then panel.Status.Text="Your community reward is already claimed. Thank you!" return end
 busy=true render()
 panel.Status.Text="Opening the community join prompt..."
 local ok,result=pcall(function() return Groups:PromptJoinAsync(Rules.GroupId) end)
 busy=false render()
 if not ok then panel.Status.Text="The join prompt couldn't open. Join Deus Invictus Studios on Roblox, then return here." return end
 if result==Enum.GroupMembershipStatus.JoinRequestPending then
  panel.Status.Text="Join request pending. Your reward is available once membership is approved."
 elseif result==Enum.GroupMembershipStatus.Joined or result==Enum.GroupMembershipStatus.AlreadyMember then
  for attempt=1,3 do
   if not panel.Visible or not near(Rules.CloseRadius) then break end
   if attempt>1 then task.wait(2) end
   local response=request("CheckCommunity")
   if response and response.State and response.State.Community then break end
  end
 else panel.Status.Text="Join the community whenever you're ready to claim its reward." end
end)
UIS.InputBegan:Connect(function(input,processed)
 if panel.Visible and not processed and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close() end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
local elapsed=0
Run.RenderStepped:Connect(function(dt)
 if model and model:IsDescendantOf(workspace) then
  local rest=model:GetAttribute("GiftRestPivot")
  if rest then
   local t=workspace:GetServerTimeNow()
   model:PivotTo(rest+Vector3.new(0,math.sin(t*math.pi/2)*.3,0))
  end
 end
 elapsed+=dt if elapsed<.2 then return end elapsed=0
 findGift()
 if not near(Rules.CloseRadius) then
  if panel.Visible then close() end
  dismissed=false
 elseif panel.Visible and (not available() or otherPanel()) then close()
 elseif not panel.Visible and not dismissed and near(Rules.VisitRadius) then open() end
end)
resize() close() dismissed=false render()

