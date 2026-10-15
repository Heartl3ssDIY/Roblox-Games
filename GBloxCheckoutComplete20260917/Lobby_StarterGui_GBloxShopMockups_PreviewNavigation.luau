local g=script.Parent
local p=game.Players.LocalPlayer
local canvas=g.Canvas local shop=canvas.Shop local abilities=canvas.Abilities
local Tween=game:GetService("TweenService")
local Marketplace=game:GetService("MarketplaceService")
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS:WaitForChild("GBloxPurchaseCatalog"))
local entries={}
local function status(message)
 shop.MockupNotice.Visible=true shop.MockupNotice.Text=message
 abilities.PreviewFooter.Text=message
end
local function formatPrice(amount)
 return tostring(math.floor(amount)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local promptBusy=false local activePrompt
local function finish(kind,id,purchased)
 if not activePrompt or activePrompt.kind~=kind or activePrompt.id~=id then return end
 activePrompt=nil promptBusy=false
 status(purchased and "Confirming with Roblox..." or "Purchase cancelled.")
end
Marketplace.PromptProductPurchaseFinished:Connect(function(uid,id,bought) if uid==p.UserId then finish("Product",id,bought) end end)
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,bought) if player==p then finish("GamePass",id,bought) end end)
task.spawn(function() RS:WaitForChild("GBloxShopFeedback").OnClientEvent:Connect(status) end)

local refresh
local function owned(entry)
 if entry.kind~="GamePass" then return false end
 local item=Catalog.Passes[entry.id]
 return p:GetAttribute("GBloxOwnsPass_"..entry.id)==true or item.Cash and (p:GetAttribute("GBloxCashMultiplier") or 1)>=item.Cash
end
local function draw(entry)
 local isOwned=owned(entry)
 entry.label.Text=isOwned and "OWNED" or entry.offSale and "OFF SALE" or entry.price and formatPrice(entry.price) or "CHECK PRICE"
 entry.button.Active=not isOwned and not entry.offSale
 entry.button.Selectable=entry.button.Active
 entry.art.ImageColor3=isOwned and Color3.fromRGB(165,235,190) or Color3.new(1,1,1)
end
refresh=function(entry,force)
 if entry.loading or (not force and entry.checked and os.clock()-entry.checked<60) then draw(entry) return end
 entry.loading=true
 task.spawn(function()
  local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,entry.id,entry.kind=="GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
  entry.loading=false
  if ok and type(info)=="table" and type(info.PriceInRobux)=="number" then
   entry.price=info.PriceInRobux entry.offSale=info.IsForSale==false entry.checked=os.clock()
  else entry.price=nil entry.checked=nil end
  draw(entry)
 end)
end
local function bind(button,art,label,kind,id)
 local entry={button=button,art=art,label=label,kind=kind,id=id}
 table.insert(entries,entry)
 button.Active=true button.Selectable=true button.AutoButtonColor=true
 button.Activated:Connect(function()
  if promptBusy or owned(entry) then return end
  if not entry.price or entry.offSale then refresh(entry,true) status("Checking availability. Please try again shortly.") return end
  promptBusy=true status("Opening Roblox checkout...")
  local ok,allowed,message=pcall(function() return RS:WaitForChild("GBloxShopRequest",10):InvokeServer(kind,id) end)
  if not ok or not allowed then promptBusy=false status(ok and (message or "Purchase unavailable.") or "Connection error. Please try again.") return end
  local token={kind=kind,id=id} activePrompt=token
  local prompted=pcall(function()
   if kind=="GamePass" then Marketplace:PromptGamePassPurchase(p,id) else Marketplace:PromptProductPurchase(p,id) end
  end)
  if not prompted then activePrompt=nil promptBusy=false status("Could not open Roblox checkout. Please try again.") end
  task.delay(90,function() if activePrompt==token then activePrompt=nil promptBusy=false end end)
 end)
 p:GetAttributeChangedSignal("GBloxOwnsPass_"..id):Connect(function() draw(entry) end)
 p:GetAttributeChangedSignal("GBloxCashMultiplier"):Connect(function() draw(entry) end)
 refresh(entry,true)
end
local sections={
 {shop.Gamepasses,"GamePass",{1981874715,1981928696,1982264711,1982600733,1981952807,1986410259}},
 {shop.Cash,"Product",{3713203989,3713204079,3713204982,3713205097,3713205149}},
 {shop.Trophies,"Product",{3713206457,3713206491,3713207026}},
}
for _,section in sections do
 for index,id in section[3] do
  local card=section[1]:FindFirstChild("Card_"..index)
  if card then
   local item=section[2]=="GamePass" and Catalog.Passes[id] or Catalog.Products[id]
   card.Visible=true card:SetAttribute(section[2]=="GamePass" and "GamePassId" or "ProductId",id)
   card:FindFirstChild("Name").Text=item.Name
   local art=card.PriceArtwork
   local button=art:FindFirstChild("PurchaseButton") or Instance.new("TextButton")
   button.Name="PurchaseButton" button.Text="" button.BackgroundTransparency=1
   button.Position=UDim2.fromScale(0,0) button.Size=UDim2.fromScale(1,1) button.ZIndex=art.Price.ZIndex+2 button.Parent=art
   bind(button,art,art.Price,section[2],id)
  end
 end
end
for _,name in {"Card_7","Card_8"} do local c=shop.Gamepasses:FindFirstChild(name) if c then c.Visible=false end end
for _,card in abilities.AbilityCards:GetChildren() do
 local id=card:GetAttribute("AbilityId")
 for product,item in Catalog.Products do if id and item.Ability==id then
  card.RobuxRefill:SetAttribute("ProductId",product)
  card.Refill.Visible=false
  card.PriceArtwork.Visible=false
  bind(card.RobuxRefill,card.RobuxRefill,card.RobuxRefill.Label,"Product",product)
 end end
end
shop:GetPropertyChangedSignal("Visible"):Connect(function() if shop.Visible then for _,entry in entries do refresh(entry) end end end)
status("Choose an item to open Roblox checkout.")
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
