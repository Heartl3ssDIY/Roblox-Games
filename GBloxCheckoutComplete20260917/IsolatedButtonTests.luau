local catalog=assert(loadstring("local C={}\nC.Passes={\n [1981874715]={Name=\"2x Cash\",Price=399,Cash=2},\n [1981928696]={Name=\"5x Cash\",Price=1999,Cash=5},\n [1982264711]={Name=\"+1 Pet Equip\",Price=500,PetSlots=2},\n [1982600733]={Name=\"2x Trophies\",Price=799,Trophies=2},\n [1981952807]={Name=\"Triple Egg Open\",Price=299,Egg=\"Triple\"},\n [1986410259]={Name=\"Auto Egg Open\",Price=149,Egg=\"Auto\"},\n}\nC.Products={\n [3713203989]={Name=\"1,000 Cash\",Kind=\"Cash\",Amount=1000,Price=99},\n [3713204079]={Name=\"5,000 Cash\",Kind=\"Cash\",Amount=5000,Price=499},\n [3713204982]={Name=\"25,000 Cash\",Kind=\"Cash\",Amount=25000,Price=2000},\n [3713205097]={Name=\"100,000 Cash\",Kind=\"Cash\",Amount=100000,Price=4499},\n [3713205149]={Name=\"1,000,000 Cash\",Kind=\"Cash\",Amount=1000000,Price=9499},\n [3713206457]={Name=\"50 Trophies\",Kind=\"Trophies\",Amount=50,Price=299},\n [3713206491]={Name=\"250 Trophies\",Kind=\"Trophies\",Amount=250,Price=1000},\n [3713207026]={Name=\"1,000 Trophies\",Kind=\"Trophies\",Amount=1000,Price=3999},\n [3713207054]={Name=\"Orbit Egg\",Kind=\"Egg\",Egg=\"Orbit\",Price=249},\n [3713207574]={Name=\"Gravity Switch recharge\",Kind=\"Ability\",Ability=\"GravitySwitch\",Amount=2,Price=299},\n [3713207627]={Name=\"Plat Be Gone recharge\",Kind=\"Ability\",Ability=\"PlatBeGone\",Amount=2,Price=198},\n [3713207658]={Name=\"Freeze recharge\",Kind=\"Ability\",Ability=\"Freeze\",Amount=2,Price=199},\n [3713208203]={Name=\"Antispike recharge\",Kind=\"Ability\",Ability=\"Antispike\",Amount=2,Price=298},\n [3713207914]={Name=\"Superspeed recharge\",Kind=\"Ability\",Ability=\"Superspeed\",Amount=2,Price=598},\n}\nreturn C\n"))()
local function signal()
 local callbacks={} return {Connect=function(_,fn) table.insert(callbacks,fn) end,Fire=function(_,...) for _,fn in callbacks do fn(...) end end}
end
local function object(name)
 local o={Name=name,children={},attrs={},Activated=signal(),Visible=true,ImageColor3=Color3.new(1,1,1)}
 function o:GetChildren() return self.children end
 function o:GetAttribute(k) return self.attrs[k] end
 function o:SetAttribute(k,v) self.attrs[k]=v end
 function o:GetAttributeChangedSignal() return signal() end
 function o:GetPropertyChangedSignal() return signal() end
 function o:FindFirstChild(k) if k=="Name" then return self.title end return self[k] end
 function o:WaitForChild(k) return self[k] end
 return o
end
local shop=object("Shop") shop.Gamepasses=object("Gamepasses") shop.Cash=object("Cash") shop.Trophies=object("Trophies") shop.MockupNotice=object("Notice")
local abilities=object("Abilities") abilities.AbilityCards=object("AbilityCards") abilities.PreviewFooter=object("Footer")
for _,pair in {{shop.Gamepasses,8},{shop.Cash,5},{shop.Trophies,3}} do
 for i=1,pair[2] do local card=object("Card_"..i) card.title={Text=""} card.PriceArtwork=object("PriceArtwork")
 card.PriceArtwork.Price={Text="",ZIndex=3} card.PriceArtwork.PurchaseButton=object("PurchaseButton")
 pair[1][card.Name]=card table.insert(pair[1].children,card) end
end
for _,id in {"GravitySwitch","PlatBeGone","Kong","Freeze","Antispike","Superspeed"} do
 local card=object(id) card.attrs.AbilityId=id card.RobuxRefill=object("RobuxRefill") card.RobuxRefill.Label={Text=""}
 card.Refill=object("Refill") card.PriceArtwork=object("PriceArtwork") table.insert(abilities.AbilityCards.children,card)
end
table.insert(abilities.AbilityCards.children,object("Cards")) -- UIGridLayout, no AbilityId
local player=object("Player") player.UserId=42
local sent={} local allowed=true local failPrompt=false
local marketplace={PromptProductPurchaseFinished=signal(),PromptGamePassPurchaseFinished=signal()}
function marketplace:GetProductInfoAsync(id) return {PriceInRobux=123,IsForSale=true} end
function marketplace:PromptProductPurchase(p,id) if failPrompt then error("test failure") end table.insert(sent,{"Product",id}) end
function marketplace:PromptGamePassPurchase(p,id) table.insert(sent,{"GamePass",id}) end
local RS=object("RS") RS.GBloxPurchaseCatalog={} RS.GBloxShopFeedback={OnClientEvent=signal()}
RS.GBloxShopRequest={InvokeServer=function() return allowed,"Denied for test" end}
local fakeGame={Players={LocalPlayer=player},GetService=function(_,name) if name=="MarketplaceService" then return marketplace elseif name=="ReplicatedStorage" then return RS else return {} end end}
local env={game=fakeGame,script={Parent={Canvas={Shop=shop,Abilities=abilities}}},require=function() return catalog end,
 task={spawn=function(fn) fn() end,delay=function() end},warn=function() end}
local fn=assert(loadstring("local g=script.Parent\nlocal p=game.Players.LocalPlayer\nlocal canvas=g.Canvas local shop=canvas.Shop local abilities=canvas.Abilities\nlocal Tween=game:GetService(\"TweenService\")\nlocal Marketplace=game:GetService(\"MarketplaceService\")\nlocal RS=game:GetService(\"ReplicatedStorage\")\nlocal Catalog=require(RS:WaitForChild(\"GBloxPurchaseCatalog\"))\nlocal entries={}\nlocal function status(message)\n shop.MockupNotice.Visible=true shop.MockupNotice.Text=message\n abilities.PreviewFooter.Text=message\nend\nlocal function formatPrice(amount)\n return tostring(math.floor(amount)):reverse():gsub(\"(%d%d%d)\",\"%1,\"):reverse():gsub(\"^,\",\"\")\nend\nlocal promptBusy=false local activePrompt\nlocal function finish(kind,id,purchased)\n if not activePrompt or activePrompt.kind~=kind or activePrompt.id~=id then return end\n activePrompt=nil promptBusy=false\n status(purchased and \"Confirming with Roblox...\" or \"Purchase cancelled.\")\nend\nMarketplace.PromptProductPurchaseFinished:Connect(function(uid,id,bought) if uid==p.UserId then finish(\"Product\",id,bought) end end)\nMarketplace.PromptGamePassPurchaseFinished:Connect(function(player,id,bought) if player==p then finish(\"GamePass\",id,bought) end end)\ntask.spawn(function() RS:WaitForChild(\"GBloxShopFeedback\").OnClientEvent:Connect(status) end)\n\nlocal refresh\nlocal function owned(entry)\n if entry.kind~=\"GamePass\" then return false end\n local item=Catalog.Passes[entry.id]\n return p:GetAttribute(\"GBloxOwnsPass_\"..entry.id)==true or item.Cash and (p:GetAttribute(\"GBloxCashMultiplier\") or 1)>=item.Cash\nend\nlocal function draw(entry)\n local isOwned=owned(entry)\n entry.label.Text=isOwned and \"OWNED\" or entry.offSale and \"OFF SALE\" or entry.price and formatPrice(entry.price) or \"CHECK PRICE\"\n entry.button.Active=not isOwned and not entry.offSale\n entry.button.Selectable=entry.button.Active\n entry.art.ImageColor3=isOwned and Color3.fromRGB(165,235,190) or Color3.new(1,1,1)\nend\nrefresh=function(entry,force)\n if entry.loading or (not force and entry.checked and os.clock()-entry.checked<60) then draw(entry) return end\n entry.loading=true\n task.spawn(function()\n  local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,entry.id,entry.kind==\"GamePass\" and Enum.InfoType.GamePass or Enum.InfoType.Product)\n  entry.loading=false\n  if ok and type(info)==\"table\" and type(info.PriceInRobux)==\"number\" then\n   entry.price=info.PriceInRobux entry.offSale=info.IsForSale==false entry.checked=os.clock()\n  else entry.price=nil entry.checked=nil end\n  draw(entry)\n end)\nend\nlocal function bind(button,art,label,kind,id)\n local entry={button=button,art=art,label=label,kind=kind,id=id}\n table.insert(entries,entry)\n button.Active=true button.Selectable=true button.AutoButtonColor=true\n button.Activated:Connect(function()\n  if promptBusy or owned(entry) then return end\n  if not entry.price or entry.offSale then refresh(entry,true) status(\"Checking availability. Please try again shortly.\") return end\n  promptBusy=true status(\"Opening Roblox checkout...\")\n  local ok,allowed,message=pcall(function() return RS:WaitForChild(\"GBloxShopRequest\",10):InvokeServer(kind,id) end)\n  if not ok or not allowed then promptBusy=false status(ok and (message or \"Purchase unavailable.\") or \"Connection error. Please try again.\") return end\n  local token={kind=kind,id=id} activePrompt=token\n  local prompted=pcall(function()\n   if kind==\"GamePass\" then Marketplace:PromptGamePassPurchase(p,id) else Marketplace:PromptProductPurchase(p,id) end\n  end)\n  if not prompted then activePrompt=nil promptBusy=false status(\"Could not open Roblox checkout. Please try again.\") end\n  task.delay(90,function() if activePrompt==token then activePrompt=nil promptBusy=false end end)\n end)\n p:GetAttributeChangedSignal(\"GBloxOwnsPass_\"..id):Connect(function() draw(entry) end)\n p:GetAttributeChangedSignal(\"GBloxCashMultiplier\"):Connect(function() draw(entry) end)\n refresh(entry,true)\nend\nlocal sections={\n {shop.Gamepasses,\"GamePass\",{1981874715,1981928696,1982264711,1982600733,1981952807,1986410259}},\n {shop.Cash,\"Product\",{3713203989,3713204079,3713204982,3713205097,3713205149}},\n {shop.Trophies,\"Product\",{3713206457,3713206491,3713207026}},\n}\nfor _,section in sections do\n for index,id in section[3] do\n  local card=section[1]:FindFirstChild(\"Card_\"..index)\n  if card then\n   local item=section[2]==\"GamePass\" and Catalog.Passes[id] or Catalog.Products[id]\n   card.Visible=true card:SetAttribute(section[2]==\"GamePass\" and \"GamePassId\" or \"ProductId\",id)\n   card:FindFirstChild(\"Name\").Text=item.Name\n   local art=card.PriceArtwork\n   local button=art:FindFirstChild(\"PurchaseButton\") or Instance.new(\"TextButton\")\n   button.Name=\"PurchaseButton\" button.Text=\"\" button.BackgroundTransparency=1\n   button.Position=UDim2.fromScale(0,0) button.Size=UDim2.fromScale(1,1) button.ZIndex=art.Price.ZIndex+2 button.Parent=art\n   bind(button,art,art.Price,section[2],id)\n  end\n end\nend\nfor _,name in {\"Card_7\",\"Card_8\"} do local c=shop.Gamepasses:FindFirstChild(name) if c then c.Visible=false end end\nfor _,card in abilities.AbilityCards:GetChildren() do\n local id=card:GetAttribute(\"AbilityId\")\n for product,item in Catalog.Products do if id and item.Ability==id then\n  card.RobuxRefill:SetAttribute(\"ProductId\",product)\n  card.Refill.Visible=false\n  card.PriceArtwork.Visible=false\n  bind(card.RobuxRefill,card.RobuxRefill,card.RobuxRefill.Label,\"Product\",product)\n end end\nend\nshop:GetPropertyChangedSignal(\"Visible\"):Connect(function() if shop.Visible then for _,entry in entries do refresh(entry) end end end)\nstatus(\"Choose an item to open Roblox checkout.\")\n")) setfenv(fn,setmetatable(env,{__index=getfenv()})) fn()
local checks=0 local function check(v,label) checks+=1 assert(v,label) end
local targets={}
for _,section in {shop.Gamepasses,shop.Cash,shop.Trophies} do for _,card in section:GetChildren() do
 if card.Visible then table.insert(targets,{button=card.PriceArtwork.PurchaseButton,kind=section==shop.Gamepasses and "GamePass" or "Product",id=card.attrs.GamePassId or card.attrs.ProductId}) end
end end
for _,card in abilities.AbilityCards.children do if card.RobuxRefill and card.RobuxRefill.attrs.ProductId then table.insert(targets,{button=card.RobuxRefill,kind="Product",id=card.RobuxRefill.attrs.ProductId}) end end
check(#targets==19,"nineteen purchase targets")
for _,entry in targets do
 local before=#sent entry.button.Activated:Fire()
 check(#sent==before+1 and sent[#sent][1]==entry.kind and sent[#sent][2]==entry.id,"correct checkout ID")
 entry.button.Activated:Fire() check(#sent==before+1,"double-click guarded")
 if entry.kind=="GamePass" then marketplace.PromptGamePassPurchaseFinished:Fire(player,entry.id,false)
 else marketplace.PromptProductPurchaseFinished:Fire(42,entry.id,false) end
end
local cash=shop.Cash.Card_1.PriceArtwork.PurchaseButton
allowed=false local before=#sent cash.Activated:Fire() check(#sent==before,"server refusal no checkout")
allowed=true failPrompt=true cash.Activated:Fire() check(#sent==before,"failed prompt safe")
failPrompt=false cash.Activated:Fire() check(#sent==before+1,"retry after prompt error")
marketplace.PromptProductPurchaseFinished:Fire(42,3713203989,false)
player.attrs.GBloxCashMultiplier=5 before=#sent
shop.Gamepasses.Card_1.PriceArtwork.PurchaseButton.Activated:Fire()
check(#sent==before,"owned/superseded pass not prompted")
check(not shop.Gamepasses.Card_7.Visible and not shop.Gamepasses.Card_8.Visible,"excluded passes hidden")
return {callbackChecksPassed=checks,actualPurchases=0}

