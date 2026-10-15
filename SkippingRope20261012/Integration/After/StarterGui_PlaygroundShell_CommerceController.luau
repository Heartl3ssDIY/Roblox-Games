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
 return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true )
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
for _, attribute in { "PCDataReady", "PCVIP", "PCDoubleCoins", "PCDoubleXP", "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated", "SKParticipating", "SKEliminated" } do
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

