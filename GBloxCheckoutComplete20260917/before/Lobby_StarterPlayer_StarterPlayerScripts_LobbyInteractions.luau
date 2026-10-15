local Players=game:GetService("Players")
local CS=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local MarketplaceService=game:GetService("MarketplaceService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local shop=pg:WaitForChild("GBloxShopMockups")
local event=shop:WaitForChild("OpenPanel")
local exit=ReplicatedStorage:WaitForChild("TreadmillExit")
local eggRemote=ReplicatedStorage:WaitForChild("GBloxEggRequest")

local overlay=Instance.new("ScreenGui")
overlay.Name="GBloxInteractionUI"
overlay.ResetOnSpawn=false
overlay.DisplayOrder=60
overlay.Parent=pg

local exitButton=Instance.new("TextButton")
exitButton.Name="ExitTreadmill"
exitButton.AnchorPoint=Vector2.new(.5,1)
exitButton.Position=UDim2.new(.5,0,1,-106)
exitButton.Size=UDim2.fromOffset(180,40)
exitButton.BackgroundColor3=Color3.fromRGB(0,140,167)
exitButton.Text="EXIT TREADMILL"
exitButton.Font=Enum.Font.GothamBold
exitButton.TextSize=16
exitButton.TextColor3=Color3.new(1,1,1)
exitButton.Visible=false
exitButton.Parent=overlay
local corner=Instance.new("UICorner")
corner.Parent=exitButton
exitButton.Activated:Connect(function() exit:FireServer() end)

local status=Instance.new("BillboardGui")
status.Name="GBloxEggStatus"
status.Size=UDim2.fromOffset(400,76)
status.StudsOffsetWorldSpace=Vector3.new(0,13,0)
status.AlwaysOnTop=true
status.LightInfluence=0
status.MaxDistance=18
status.Enabled=false
status.Parent=pg
local statusFrame=Instance.new("Frame")
statusFrame.Size=UDim2.fromScale(1,1)
statusFrame.BackgroundColor3=Color3.fromRGB(10,13,18)
statusFrame.BackgroundTransparency=.08
statusFrame.Parent=status
local statusCorner=Instance.new("UICorner")
statusCorner.CornerRadius=UDim.new(.22,0)
statusCorner.Parent=statusFrame
local statusStroke=Instance.new("UIStroke")
statusStroke.Color=Color3.fromRGB(24,241,255)
statusStroke.Thickness=2
statusStroke.Parent=statusFrame
local statusText=Instance.new("TextLabel")
statusText.Size=UDim2.new(1,-24,1,-12)
statusText.Position=UDim2.fromOffset(12,6)
statusText.BackgroundTransparency=1
statusText.TextColor3=Color3.new(1,1,1)
statusText.TextStrokeTransparency=.6
statusText.TextWrapped=true
statusText.TextScaled=true
statusText.Font=Enum.Font.GothamMedium
statusText.Parent=statusFrame
local textLimit=Instance.new("UITextSizeConstraint")
textLimit.MinTextSize=11
textLimit.MaxTextSize=18
textLimit.Parent=statusText
local statusToken=0

local function standFor(theme)
 for _,stand in CS:GetTagged("GBloxEggStand") do
  if stand:GetAttribute("EggTheme")==theme then return stand end
 end
end

local function showStatus(theme,text,bad,duration)
 local stand=standFor(theme)
 if not stand then return end
 statusToken+=1
 local token=statusToken
 status.Adornee=stand
 status.StudsOffsetWorldSpace=Vector3.new(0,13,0)
 statusFrame.BackgroundColor3=bad and Color3.fromRGB(91,24,34) or Color3.fromRGB(10,13,18)
 statusStroke.Color=bad and Color3.fromRGB(255,91,112) or Color3.fromRGB(24,241,255)
 statusText.Text=text
 status.Enabled=true
 task.delay(duration or 2.7,function()
  if statusToken==token then status.Enabled=false end
 end)
end

eggRemote.OnClientEvent:Connect(function(payload)
 if typeof(payload)~="table" then return end
 if payload.PromptPass and payload.PromptPass>0 then
  MarketplaceService:PromptGamePassPurchase(player,payload.PromptPass)
 end
 local theme=payload.Theme
 if not theme then return end
 if payload.Results and #payload.Results>0 then
  return -- Successful hatches are shown by the full-screen opening sequence.
 elseif payload.Message then
  showStatus(theme,payload.Message,payload.Ok==false,payload.AutoActive and 1.8 or 2.7)
 end
end)

local function treadmill()
 local on=player:GetAttribute("OnTreadmill")==true
 exitButton.Visible=on
 if on then
  CAS:BindActionAtPriority("ExitTreadmill",function(_,state)
   if state==Enum.UserInputState.Begin then exit:FireServer() end
   return Enum.ContextActionResult.Sink
  end,false,5000,Enum.KeyCode.Space,Enum.KeyCode.ButtonA)
 else
  CAS:UnbindAction("ExitTreadmill")
 end
end
player:GetAttributeChangedSignal("OnTreadmill"):Connect(treadmill)
treadmill()

local elapsed=0
local lastAbilityZone=nil
Run.RenderStepped:Connect(function(dt)
 local now=workspace:GetServerTimeNow()
 for _,ring in CS:GetTagged("GBloxEggRing") do
  local rest=ring:GetAttribute("RingRestCFrame")
  if rest then
   ring.CFrame=CFrame.new(rest.Position)*CFrame.Angles(0,math.rad(ring:GetAttribute("RingSpeed") or 18)*now,0)*rest.Rotation
  end
 end

 elapsed+=dt
 if elapsed<.15 then return end
 elapsed=0
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local zone,best=nil,math.huge
 if root and not player:GetAttribute("OnTreadmill") then
  for _,part in CS:GetTagged("GBloxAbilityCounter") do
   local delta=root.Position-part.Position
   local dist=Vector2.new(delta.X,delta.Z).Magnitude
   if dist<10 and math.abs(delta.Y)<10 and dist<best then best=dist zone=part end
  end
 end
 if zone~=lastAbilityZone then
  lastAbilityZone=zone
  event:Fire(zone and "Abilities" or nil)
 end
end)
