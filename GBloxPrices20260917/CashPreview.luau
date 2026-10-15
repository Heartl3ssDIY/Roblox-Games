local g=script.Parent
local p=game.Players.LocalPlayer
local canvas=g.Canvas local shop=canvas.Shop local abilities=canvas.Abilities
local Tween=game:GetService("TweenService")

-- Resolve linked shop prices for this player (including regional prices/discounts).
local Marketplace=game:GetService("MarketplaceService")
local priceRequests={}
local function formatRobux(amount)
 local digits=tostring(math.floor(amount))
 return (digits:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
end
local function refreshShopPrices()
 for _,section in {shop.Gamepasses,shop.Cash,shop.Trophies} do
 for _,card in section:GetChildren() do
  local attribute=section==shop.Gamepasses and "GamePassId" or "ProductId"
  local infoType=section==shop.Gamepasses and Enum.InfoType.GamePass or Enum.InfoType.Product
  local id=card:GetAttribute(attribute)
  local artwork=card:FindFirstChild("PriceArtwork")
  local label=artwork and artwork:FindFirstChild("Price")
  if type(id)=="number" and id>0 and label then
   local state=priceRequests[card]
   if not state then state={};priceRequests[card]=state end
   if not state.busy and (not state.updated or os.clock()-state.updated>=60) then
    state.busy=true
    if not state.updated then label.Text="..." end
    task.spawn(function()
     local ok,info=pcall(function() return Marketplace:GetProductInfoAsync(id,infoType) end)
     state.busy=false
     if not card.Parent or card:GetAttribute(attribute)~=id then return end
     if ok and type(info)=="table" then
      if info.IsForSale==false then
       label.Text="Off sale";card:SetAttribute("PriceStatus","OffSale");state.updated=os.clock()
      elseif type(info.PriceInRobux)=="number" then
       label.Text=formatRobux(info.PriceInRobux)
       card:SetAttribute("CurrentRobuxPrice",info.PriceInRobux)
       card:SetAttribute("PriceStatus","Live");state.updated=os.clock()
      else label.Text="—";card:SetAttribute("PriceStatus","Unavailable") end
     else
      label.Text="—";card:SetAttribute("PriceStatus","Unavailable")
     end
    end)
   end
  end
 end
 end
end
shop:GetPropertyChangedSignal("Visible"):Connect(function()
 if shop.Visible then refreshShopPrices() end
end)
refreshShopPrices()

local function open(panel)
 for _,name in {"Shop","Abilities","Inventory","Pets"} do canvas[name].Visible=panel==canvas[name] end
 g.PreviewButtons.Visible=panel==nil
 if panel then
  local s=panel:FindFirstChild("OpenScale") or Instance.new("UIScale") s.Name="OpenScale" s.Parent=panel s.Scale=.97
  Tween:Create(s,TweenInfo.new(.16,Enum.EasingStyle.Quad),{Scale=1}):Play()
 end
end
g:WaitForChild("OpenPanel").Event:Connect(function(name)
 open(typeof(name)=="string" and canvas:FindFirstChild(name) or nil)
end)
g.PreviewButtons.Shop.Activated:Connect(function() open(shop) end)
g.PreviewButtons.Abilities.Activated:Connect(function() open(abilities) end)
for _,name in {"Inventory","Pets"} do
 g.PreviewButtons[name].Activated:Connect(function() open(canvas[name]) end)
 canvas[name].Close.Activated:Connect(function() open(nil) end)
end
shop.Close.Activated:Connect(function() open(nil) end)
abilities.Close.Activated:Connect(function() open(nil) end)
for _,n in {"Gamepasses","Cash","Trophies"} do shop[n.."Tab"].Activated:Connect(function()
 for _,s in {"Gamepasses","Cash","Trophies"} do shop[s].Visible=s==n end
end) end
local remote=game.ReplicatedStorage:WaitForChild("AbilityPurchase")
for _,card in abilities.AbilityCards:GetChildren() do
 local id=card:GetAttribute("AbilityId")
 if id then
  local b=card.CashPurchase local busy=false
  local function refresh()
   if id=="Kong" then
    b.Label.Text="UNAVAILABLE" b.Active=false b.ImageColor3=Color3.fromRGB(155,155,155)
    card.RobuxRefill.Visible=false
    return
   end
   local owned=p:GetAttribute("AbilityOwned_"..id)==true
   local uses=p:GetAttribute("AbilityUses_"..id) or 0
   local cost=card:GetAttribute("CashPrice")*(owned and .1 or 1)
   b.Label.Text=owned and uses>0 and (uses.." games left") or (tostring(cost/1000) .. "k Cash")
   b.Position=UDim2.new(owned and .74 or .5,0,1,-16)
   b.Size=UDim2.fromOffset(owned and 190 or 214,owned and 43 or 49)
   b.Active=not busy and p:GetAttribute("PlayerDataReady")==true and (not owned or uses==0)
   b.ImageColor3=b.Active and Color3.new(1,1,1) or Color3.fromRGB(155,155,155)
   card.RobuxRefill.Visible=owned
  end
  p:GetAttributeChangedSignal("AbilityOwned_"..id):Connect(refresh)
  p:GetAttributeChangedSignal("AbilityUses_"..id):Connect(refresh)
  p:GetAttributeChangedSignal("PlayerDataReady"):Connect(refresh)
  b.Activated:Connect(function()
   if busy or not b.Active then return end
   busy=true refresh()
   local ok,success,message=pcall(function() return remote:InvokeServer(id) end)
   abilities.PreviewFooter.Text=ok and message or "Connection error; check your balance before retrying."
   busy=false refresh()
  end)
  refresh()
 end
end
local function resize()
 local camera=workspace.CurrentCamera if not camera then return end
 local v=camera.ViewportSize local mobile=v.X<650
 local scale=mobile and math.min(v.X/600,1) or math.min(v.X/1180,v.Y/810,1)
 canvas.ResponsiveScale.Scale=scale
 canvas.Size=mobile and UDim2.fromOffset(560,math.max(719,(v.Y-70)/scale)) or UDim2.fromOffset(1120,719)
 for _,panel in {shop,abilities} do
  for _,list in panel:GetChildren() do if list:IsA("ScrollingFrame") then
   list.Cards.CellSize=UDim2.new(mobile and 1 or .5,-10,0,panel==abilities and 270 or 216)
  end end
 end
 for i,n in {"GamepassesTab","CashTab","TrophiesTab"} do
  local b=shop[n] b.Position=mobile and UDim2.fromOffset(28+(i-1)*172,105) or UDim2.fromOffset(62+(i-1)*239,105)
  b.Size=UDim2.fromOffset(mobile and 160 or 220,mobile and 37 or 50)
 end
 require(g.InventoryLayout).Apply(g,v)
end
local connection
local function cameraChanged()
 if connection then connection:Disconnect() end
 if workspace.CurrentCamera then connection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged() open(nil)
