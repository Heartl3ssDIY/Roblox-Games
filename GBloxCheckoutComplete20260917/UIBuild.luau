local shop=game.StarterGui.GBloxShopMockups.Canvas.Shop
local abilities=game.StarterGui.GBloxShopMockups.Canvas.Abilities
local catalog=assert(loadstring(game.ReplicatedStorage.GBloxPurchaseCatalog.Source))()
local sections={
 {shop.Gamepasses,"GamePassId",{1981874715,1981928696,1982264711,1982600733,1981952807,1986410259}},
 {shop.Cash,"ProductId",{3713203989,3713204079,3713204982,3713205097,3713205149}},
 {shop.Trophies,"ProductId",{3713206457,3713206491,3713207026}},
}
local descriptions={
 [1981874715]="Double earned cash. Does not multiply purchased cash packs.",
 [1981928696]="5x earned cash. Replaces, rather than stacks with, 2x Cash.",
 [1982264711]="Equip two pets. Their bonuses above 1x add together.",
 [1982600733]="Double earned race trophies. Purchased packs remain exact.",
 [1981952807]="Open three trophy eggs at once. Trophy cost still applies.",
 [1986410259]="Automatically open trophy eggs while near their stand.",
}
local buttons=0
for _,section in sections do for i,id in section[3] do
 local card=section[1]:FindFirstChild("Card_"..i)
 local item=section[2]=="GamePassId" and catalog.Passes[id] or catalog.Products[id]
 card.Visible=true card.LayoutOrder=i card:SetAttribute(section[2],id) card:SetAttribute("BaseRobuxPrice",item.Price)
 card:SetAttribute("CashMultiplier",item.Cash)
 card:FindFirstChild("Name").Text=item.Name
 card.Description.Text=descriptions[id] or (item.Amount.." "..item.Kind.." added to your balance.")
 local art=card.PriceArtwork art.Price.Text=tostring(item.Price) art.ImageColor3=Color3.new(1,1,1)
 local b=art:FindFirstChild("PurchaseButton") or Instance.new("TextButton")
 b.Name="PurchaseButton" b.Size=UDim2.fromScale(1,1) b.Position=UDim2.fromScale(0,0)
 b.BackgroundTransparency=1 b.Text="" b.ZIndex=art.Price.ZIndex+2 b.Active=true b.Selectable=true b.Parent=art
 buttons+=1
end end
for _,name in {"Card_7","Card_8"} do local c=shop.Gamepasses:FindFirstChild(name) if c then c.Visible=false c:SetAttribute("GamePassId",nil) end end
shop.MockupNotice.Visible=true shop.MockupNotice.Text="Choose an item to open Roblox checkout."
abilities.MockupNotice.Visible=false
abilities.PreviewFooter.Text="Robux recharge: +2 game uses. Unlock the ability with cash first."
for _,card in abilities.AbilityCards:GetChildren() do
 local ability=card:GetAttribute("AbilityId")
 if ability then
  card.Refill.Visible=false card.PriceArtwork.Visible=false
  if ability=="Kong" then card.RobuxRefill.Visible=false card.CashPurchase.Active=false card.CashPurchase.Label.Text="UNAVAILABLE"
  else for id,item in catalog.Products do if item.Ability==ability then
   card:SetAttribute("RobuxPrice",item.Price)
   card.RobuxRefill:SetAttribute("ProductId",id)
   card.RobuxRefill.Label.Text=tostring(item.Price) card.RobuxRefill.Active=true card.RobuxRefill.Selectable=true
   buttons+=1
  end end end
 end
end
return {shopAndRechargeButtons=buttons,excludedCardsHidden=true}

