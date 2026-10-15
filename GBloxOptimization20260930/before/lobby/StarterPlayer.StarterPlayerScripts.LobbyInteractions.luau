local Players=game:GetService("Players")
local CS=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local MarketplaceService=game:GetService("MarketplaceService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Artwork=require(ReplicatedStorage:WaitForChild("GBloxUIArtwork"))
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
exitButton.Position=UDim2.new(.5,0,1,-128)
exitButton.Size=UDim2.fromOffset(220,44)
exitButton.BackgroundColor3=Color3.fromRGB(0,140,167)
exitButton.Text="EXIT TREADMILL"
exitButton.Font=Enum.Font.Arcade
exitButton.TextSize=16
exitButton.TextColor3=Color3.new(1,1,1)
exitButton.Visible=false
exitButton.Parent=overlay
local corner=Instance.new("UICorner")
corner.Parent=exitButton
Artwork.Button(exitButton)
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
statusText.Font=Enum.Font.Arcade
statusText.Parent=statusFrame
local textLimit=Instance.new("UITextSizeConstraint")
textLimit.MinTextSize=11
textLimit.MaxTextSize=18
textLimit.Parent=statusText
Artwork.Panel(statusFrame)
Artwork.Text(statusText)
local statusToken=0

local function standFor(theme)
 for _,stand in CS:GetTagged("GBloxEggStand") do
  if stand:IsA("BasePart") and stand:IsDescendantOf(workspace) and stand:GetAttribute("EggTheme")==theme then return stand end
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
 statusText.TextColor3=bad and Color3.fromRGB(255,160,160) or Color3.new(1,1,1)
 statusText.Text=text
 status.Enabled=true
 task.delay(duration or 2.7,function()
  if statusToken==token then status.Enabled=false end
 end)
end

-- Show all outcomes before the player requests paid Orbit checkout.
local orbitPanel=Instance.new("Frame")
orbitPanel.Name="OrbitConfirmation" orbitPanel.AnchorPoint=Vector2.new(.5,.5)
orbitPanel.Position=UDim2.fromScale(.5,.5) orbitPanel.Size=UDim2.new(.85,0,0,285)
orbitPanel.BackgroundColor3=Color3.fromRGB(3,39,57) orbitPanel.Visible=false orbitPanel.Parent=overlay
local maximum=Instance.new("UISizeConstraint") maximum.MaxSize=Vector2.new(450,285) maximum.Parent=orbitPanel
local rounding=Instance.new("UICorner") rounding.CornerRadius=UDim.new(0,18) rounding.Parent=orbitPanel
local border=Instance.new("UIStroke") border.Color=Color3.fromRGB(0,220,230) border.Thickness=3 border.Parent=orbitPanel
local odds=Instance.new("TextLabel") odds.Name="Odds" odds.BackgroundTransparency=1 odds.Position=UDim2.fromOffset(15,15)
odds.Size=UDim2.new(1,-30,0,190) odds.TextColor3=Color3.new(1,1,1) odds.Font=Enum.Font.Arcade
odds.TextSize=18 odds.TextWrapped=true odds.Text="ORBIT EGG — ONE PET\n\nOrca: 85%\nSwordfish: 10%\nShark: 4.5%\nAlien: 0.5%" odds.Parent=orbitPanel
local buy=Instance.new("ImageButton") buy.Name="BuyOrbit" buy.Image="rbxassetid://124666491673414"
buy.BackgroundTransparency=1 buy.Position=UDim2.new(.05,0,1,-65) buy.Size=UDim2.new(.58,0,0,45) buy.Parent=orbitPanel
local price=Instance.new("TextLabel") price.Size=UDim2.fromScale(1,1) price.BackgroundTransparency=1
price.Font=Enum.Font.Arcade price.TextColor3=Color3.new(1,1,1) price.TextSize=18 price.Text="CHECKING..." price.Parent=buy
local cancel=Instance.new("TextButton") cancel.Name="Cancel" cancel.Position=UDim2.new(.67,0,1,-65) cancel.Size=UDim2.new(.28,0,0,45)
cancel.Text="CANCEL" cancel.Font=Enum.Font.Arcade cancel.TextSize=16 cancel.TextColor3=Color3.new(1,1,1)
cancel.BackgroundColor3=Color3.fromRGB(30,74,85) cancel.Parent=orbitPanel
Artwork.Panel(orbitPanel)
Artwork.Button(cancel)
Artwork.Text(odds) Artwork.Text(price)
odds.TextScaled=true
local oddsLimit=Instance.new("UITextSizeConstraint") oddsLimit.MinTextSize=10 oddsLimit.MaxTextSize=18 oddsLimit.Parent=odds
price.TextScaled=true
cancel.Activated:Connect(function() orbitPanel.Visible=false end)
buy.Activated:Connect(function()
 if not buy.Active then return end
 orbitPanel.Visible=false eggRemote:FireServer("BuyOrbit","Orbit")
end)
local function confirmOrbit()
 orbitPanel.Visible=true buy.Active=false price.Text="CHECKING..."
 task.spawn(function()
  local ok,info=pcall(MarketplaceService.GetProductInfoAsync,MarketplaceService,3713207054,Enum.InfoType.Product)
  if ok and info.IsForSale~=false and type(info.PriceInRobux)=="number" then
   price.Text="BUY — "..info.PriceInRobux.." R$" buy.Active=true
  else price.Text="UNAVAILABLE" end
 end)
end

eggRemote.OnClientEvent:Connect(function(payload)
 if typeof(payload)~="table" then return end
 if payload.ConfirmOrbit then confirmOrbit() return end
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
  if rest and ring:IsDescendantOf(workspace) then
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
