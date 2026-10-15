local nativeTask=task
local gui=game.StarterGui.PlaygroundShell:Clone()
local config=game.ReplicatedStorage.PlaygroundCommerce:Clone()
gui.ShopPanel.Visible=true gui.ShopPanel.BuyCoinsPanel.Visible=true
local function signal()
 local callbacks={}
 return {Connect=function(_,fn) local item={fn=fn,live=true} table.insert(callbacks,item) return {Disconnect=function()item.live=false end} end,
 Fire=function(_,...)for _,item in callbacks do if item.live then item.fn(...) end end end}
end
local attributes={PCDataReady=true}
local attributeSignals={}
local player={UserId=123}
function player:GetAttribute(name)return attributes[name] end
function player:GetAttributeChangedSignal(name) if not attributeSignals[name] then attributeSignals[name]=signal() end return attributeSignals[name] end
function player:SetAttribute(name,value)attributes[name]=value self:GetAttributeChangedSignal(name):Fire() end
local result={OnClientEvent=signal()}
local replicated={}
function replicated:WaitForChild(name) if name=="PlaygroundCommerce" then return config elseif name=="PlaygroundCommerceResult" then return result end error(name) end
local calls={}
local marketplace={PromptProductPurchaseFinished=signal(),PromptGamePassPurchaseFinished=signal()}
function marketplace:GetProductInfoAsync(id,kind) if id==9999 then error("unavailable") end return {PriceInRobux=id==101 and 499 or 57,IsForSale=true} end
function marketplace:PromptProductPurchase(who,id)table.insert(calls,{"Product",who,id}) end
function marketplace:PromptGamePassPurchase(who,id)table.insert(calls,{"Pass",who,id}) end
local services={Players={LocalPlayer=player},ReplicatedStorage=replicated,MarketplaceService=marketplace}
local game={GetService=function(_,name)return assert(services[name],name) end}
local script={Parent=gui,Destroying=signal()}
local task={spawn=function(fn,...)fn(...) end,defer=function(fn,...)fn(...) end}
local run=function()
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = script.Parent
local shop = gui:WaitForChild("ShopPanel")
local panel = shop:WaitForChild("BuyCoinsPanel")
local config = ReplicatedStorage:WaitForChild("PlaygroundCommerce")
local result = ReplicatedStorage:WaitForChild("PlaygroundCommerceResult")
local offers = {}
local connections = {}
local alive = true
local pending
local loading = false
local reloadQueued = false
local ownership = { VIP = "PCVIP", DoubleCoins = "PCDoubleCoins", DoubleXP = "PCDoubleXP" }

local function connect(signal, callback)
 local connection = signal:Connect(callback)
 table.insert(connections, connection)
 return connection
end

local function inRound()
 return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
end

local function caption(button, text)
 button.Text = text
 button.LiveCaption.Text = text
end

local function owned(name)
 local attribute = ownership[name]
 return attribute and player:GetAttribute(attribute) == true
end

local function included(name)
 return name ~= "VIP" and ownership[name] ~= nil and player:GetAttribute("PCVIP") == true
end

local function refresh()
 for name, offer in pairs(offers) do
  local card = offer.card
  local entry = config:FindFirstChild(name)
  local configured = entry and entry:IsA("IntValue") and entry.Value > 0
  local ready = config:GetAttribute("Ready") == true and player:GetAttribute("PCDataReady") == true
  local valid = configured and offer.id == entry.Value and offer.price ~= nil
  local isOwned, isIncluded = owned(name), included(name)
  local canBuy = ready and valid and not isOwned and not isIncluded and pending == nil and not inRound()
  card.Buy.Active = canBuy
  card.Buy.Selectable = canBuy
  card.Buy.AutoButtonColor = canBuy
  caption(card.Buy, isOwned and "OWNED" or isIncluded and "IN VIP" or tostring(offer.price or entry and entry:GetAttribute("Robux") or offer.plannedPrice) .. " ROBUX")
  card.Availability.Text = isOwned and "OWNED" or isIncluded and "INCLUDED WITH VIP" or not configured and "COMING SOON" or not valid and "UNAVAILABLE" or not ready and "GETTING READY" or "AVAILABLE"
  card.Buy.ReusableSkin.ImageColor3 = canBuy and Color3.new(1, 1, 1) or Color3.fromRGB(190, 196, 208)
 end
end

local function loadOffers()
 if loading then reloadQueued = true return end
 loading = true
 local available = 0
 for name, offer in pairs(offers) do
  local entry = config:FindFirstChild(name)
  local id = entry and entry:IsA("IntValue") and entry.Value or 0
  offer.id, offer.price = id, nil
  offer.kind = entry and entry:GetAttribute("Kind")
  if id > 0 then
   local infoType = offer.kind == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
   local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(id, infoType) end)
   if not alive then return end
   if entry.Value == id and ok and typeof(info) == "table" and info.IsForSale ~= false and typeof(info.PriceInRobux) == "number" and info.PriceInRobux >= 1 then
    offer.price = info.PriceInRobux
    available += 1
   end
  end
 end
 loading = false
 refresh()
 if not pending then
  panel.Status.Text = available > 0 and "Roblox confirms the price before you buy." or "Purchases are coming soon."
 end
 if reloadQueued then reloadQueued = false task.defer(loadOffers) end
end

local function buy(name)
 local offer = offers[name]
 local entry = config:FindFirstChild(name)
 if not alive or not shop.Visible or not panel.Visible or pending or inRound() or not offer or not offer.card.Buy.Active then return end
 if not entry or entry.Value ~= offer.id or offer.id <= 0 or not offer.price or config:GetAttribute("Ready") ~= true or player:GetAttribute("PCDataReady") ~= true or owned(name) or included(name) then refresh() return end
 pending = { id = offer.id, kind = offer.kind }
 panel.Status.Text = "Confirm your purchase in the Roblox window."
 refresh()
 local ok = pcall(function()
  if offer.kind == "GamePass" then MarketplaceService:PromptGamePassPurchase(player, offer.id)
  else MarketplaceService:PromptProductPurchase(player, offer.id) end
 end)
 if not ok and alive then
  pending = nil
  panel.Status.Text = "Roblox couldn't open the purchase. Please try again."
  refresh()
 end
end

for _, card in panel.Offers:GetChildren() do
 if card:IsA("Frame") and card:FindFirstChild("Buy") then
  local entry = config:FindFirstChild(card.Name)
  offers[card.Name] = { card = card, plannedPrice = entry and entry:GetAttribute("Robux") or 0 }
  connect(card.Buy.Activated, function() buy(card.Name) end)
 end
end

local function bindEntry(entry)
 if not entry:IsA("IntValue") or not offers[entry.Name] then return end
 connect(entry.Changed, function() task.spawn(loadOffers) end)
 connect(entry.AttributeChanged, function() task.spawn(loadOffers) end)
 task.spawn(loadOffers)
end
for _, entry in config:GetChildren() do bindEntry(entry) end
connect(config.ChildAdded, bindEntry)
connect(config.ChildRemoved, function() task.spawn(loadOffers) end)
connect(config:GetAttributeChangedSignal("Ready"), refresh)
for _, attribute in { "PCDataReady", "PCVIP", "PCDoubleCoins", "PCDoubleXP", "BBParticipating", "TGParticipating", "MDParticipating" } do
 connect(player:GetAttributeChangedSignal(attribute), refresh)
end
connect(panel:GetPropertyChangedSignal("Visible"), function()
 if panel.Visible then task.spawn(loadOffers) end
end)
connect(shop:GetPropertyChangedSignal("Visible"), function()
 if shop.Visible and panel.Visible then task.spawn(loadOffers) end
end)
connect(MarketplaceService.PromptProductPurchaseFinished, function(userId, productId, purchased)
 if userId ~= player.UserId or not pending or pending.kind == "GamePass" or productId ~= pending.id then return end
 pending = nil
 panel.Status.Text = purchased and "Waiting for Roblox to confirm your coins..." or "Purchase cancelled."
 refresh()
end)
connect(MarketplaceService.PromptGamePassPurchaseFinished, function(who, passId, purchased)
 if who ~= player or not pending or pending.kind ~= "GamePass" or passId ~= pending.id then return end
 pending = nil
 panel.Status.Text = purchased and "Waiting for Roblox to confirm your pass..." or "Purchase cancelled."
 refresh()
end)
connect(result.OnClientEvent, function(message)
 if typeof(message) == "string" then
  pending = nil
  panel.Status.Text = message
 end
 refresh()
end)
script.Destroying:Connect(function()
 alive = false
 for _, connection in connections do connection:Disconnect() end
 table.clear(connections)
end)
refresh()
task.spawn(loadOffers)

return {buy=buy,refresh=refresh,load=loadOffers}
end
local runtime=run()
local checks=0
local function check(v,m)checks+=1 assert(v,m) end
local panel=gui.ShopPanel.BuyCoinsPanel
local coin=panel.Offers.Coin5000 local vip=panel.Offers.VIP
local ok,failure=pcall(function()
 check(not coin.Buy.Active and coin.Availability.Text=="COMING SOON","unconfigured product disabled")
 runtime.buy("Coin5000") check(#calls==0,"missing ID never prompts")
 config.Coin5000.Value=100
 config.VIP.Value=101
 config.DoubleCoins.Value=102
 config.DoubleXP.Value=103
 runtime.load()
 check(not coin.Buy.Active,"server readiness gate")
 config:SetAttribute("Ready",true) runtime.refresh()
 check(coin.Buy.Active,"verified product enabled")
 check(coin.Buy.LiveCaption.Text=="57 ROBUX","live metadata price overrides planned price")
 runtime.buy("Coin5000")
 check(#calls==1 and calls[1][1]=="Product" and calls[1][3]==100,"product purchase routes to Roblox")
 check(not coin.Buy.Active,"pending purchase blocks repeats")
 runtime.buy("Coin5000") check(#calls==1,"duplicate input ignored")
 result.OnClientEvent:Fire("5,000 coins added.")
 marketplace.PromptProductPurchaseFinished:Fire(123,100,true)
 check(panel.Status.Text=="5,000 coins added.","late prompt event preserves receipt confirmation")
 runtime.buy("VIP")
 check(#calls==2 and calls[2][1]=="Pass" and calls[2][3]==101,"pass purchase uses pass prompt")
 marketplace.PromptGamePassPurchaseFinished:Fire(player,101,true)
 check(panel.Status.Text:find("Waiting")~=nil,"UI waits for server-confirmed pass")
 player:SetAttribute("PCVIP",true)
 result.OnClientEvent:Fire("VIP activated.")
 check(not vip.Buy.Active and vip.Buy.LiveCaption.Text=="OWNED","owned VIP no repurchase")
 check(not panel.Offers.DoubleCoins.Buy.Active and panel.Offers.DoubleCoins.Availability.Text=="INCLUDED WITH VIP","coins bonus included")
 check(not panel.Offers.DoubleXP.Buy.Active and panel.Offers.DoubleXP.Availability.Text=="INCLUDED WITH VIP","XP bonus included")
 runtime.buy("DoubleCoins") check(#calls==2,"VIP does not prompt redundant bonus")
 player:SetAttribute("PCVIP",false)
 player:SetAttribute("PCDoubleCoins",true)
 check(panel.Offers.DoubleCoins.Buy.LiveCaption.Text=="OWNED","individual pass owned")
 player:SetAttribute("TGParticipating",true)
 runtime.buy("Coin5000") check(#calls==2,"round purchases blocked")
 player:SetAttribute("TGParticipating",false)
 player:SetAttribute("PCDataReady",false)
 runtime.buy("Coin5000") check(#calls==2,"unloaded data blocked")
 player:SetAttribute("PCDataReady",true)
 gui.ShopPanel.Visible=false runtime.buy("Coin5000") check(#calls==2,"hidden shop blocked")
 gui.ShopPanel.Visible=true
 config.Coin5000.Value=9999 runtime.load()
 check(not coin.Buy.Active and coin.Availability.Text=="UNAVAILABLE","failed metadata disabled")
end)
script.Destroying:Fire()
gui:Destroy() config:Destroy()
assert(ok,failure)
return tostring(checks).." client commerce checks passed; no actual purchases"

