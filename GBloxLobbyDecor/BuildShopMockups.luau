local StarterGui=game:GetService("StarterGui")
assert(not StarterGui:FindFirstChild("GBloxShopMockups"),"Mockups already exist; refusing to overwrite")
local function make(class,name,parent,props)
 local o=Instance.new(class);o.Name=name
 for k,v in props or {} do o[k]=v end
 o.Parent=parent;return o
end
local teal=Color3.fromRGB(0,234,231)
local gui=make("ScreenGui","GBloxShopMockups",StarterGui,{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=35})
local root=make("Frame","Canvas",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1120,760),BackgroundTransparency=1})
make("UIScale","ResponsiveScale",root,{Scale=1})
local function label(name,parent,text,pos,size,fontSize,color)
 return make("TextLabel",name,parent,{Text=text,Position=pos,Size=size,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=fontSize,TextColor3=color or Color3.new(1,1,1),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
end
local function panel(name,title)
 local f=make("ImageLabel",name,root,{Size=UDim2.fromScale(1,1),Image="rbxassetid://122165574452062",ScaleType=Enum.ScaleType.Crop,BackgroundColor3=Color3.fromRGB(5,26,45),Visible=false})
 make("UICorner","RoundCorners",f,{CornerRadius=UDim.new(0,24)})
 make("UIStroke","Border",f,{Color=teal,Thickness=2})
 local shade=make("Frame","Tint",f,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(3,15,30),BackgroundTransparency=.16,BorderSizePixel=0})
 make("UICorner","RoundCorners",shade,{CornerRadius=UDim.new(0,24)})
 label("Title",f,title,UDim2.fromOffset(32,22),UDim2.fromOffset(960,60),40)
 label("MockupNotice",f,"DESIGN PREVIEW  /  purchases and abilities are inactive",UDim2.fromOffset(34,82),UDim2.fromOffset(1000,24),14,Color3.fromRGB(172,219,232))
 make("TextButton","Close",f,{Position=UDim2.new(1,-66,0,24),Size=UDim2.fromOffset(40,40),Text="X",Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(26,66,79)})
 return f
end
local shop=panel("Shop","G-BLOX  /  SHOP")
local abilities=panel("Abilities","G-BLOX  /  ABILITIES")
local function tab(name,parent,text,x)
 local b=make("TextButton",name,parent,{Position=UDim2.fromOffset(x,122),Size=UDim2.fromOffset(240,42),Text=text,Font=Enum.Font.GothamBold,TextSize=18,BackgroundColor3=Color3.fromRGB(14,78,96),TextColor3=Color3.new(1,1,1)})
 make("UICorner","Corners",b,{CornerRadius=UDim.new(0,10)})
 return b
end
tab("GamepassesTab",shop,"GAMEPASSES",32);tab("CashTab",shop,"CASH",284);tab("TrophiesTab",shop,"TROPHIES",536)
local function grid(name,parent,columns,height,top)
 local frame=make("ScrollingFrame",name,parent,{Position=UDim2.fromOffset(32,top),Size=UDim2.new(1,-64,1,-top-55),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=teal,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
 make("UIGridLayout","Cards",frame,{CellSize=UDim2.new(1/columns,-12,0,height),CellPadding=UDim2.fromOffset(14,14),SortOrder=Enum.SortOrder.LayoutOrder})
 make("UIPadding","Padding",frame,{PaddingBottom=UDim.new(0,8),PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,3)})
 return frame
end
local function card(parent,index,title,desc,price,height,extra)
 local c=make("Frame","Card_"..index,parent,{LayoutOrder=index,BackgroundColor3=Color3.fromRGB(8,35,52),BorderSizePixel=0})
 make("UICorner","Corners",c,{CornerRadius=UDim.new(0,14)})
 make("UIStroke","Outline",c,{Color=Color3.fromRGB(36,126,145),Thickness=1})
 label("Name",c,title,UDim2.fromOffset(16,12),UDim2.new(1,-32,0,30),22,teal)
 label("Description",c,desc,UDim2.fromOffset(16,48),UDim2.new(1,-32,0,height-112),15)
 if extra then label("Refill",c,extra,UDim2.fromOffset(16,height-104),UDim2.new(1,-32,0,48),14,Color3.fromRGB(182,220,229)) end
 local p=make("ImageLabel","PriceArtwork",c,{Position=UDim2.new(0,14,1,-48),Size=UDim2.new(1,-28,0,36),BackgroundTransparency=1,Image="rbxassetid://73899067954592",ScaleType=Enum.ScaleType.Stretch})
 local t=label("Price",p,price,UDim2.fromScale(0,0),UDim2.fromScale(1,1),17)
 t.TextXAlignment=Enum.TextXAlignment.Center;t.TextYAlignment=Enum.TextYAlignment.Center
 return c
end
local passes=grid("Gamepasses",shop,2,154,182)
local data={
 {"2x Cash","Double cash multiplier.","399 R$"},
 {"5x Cash","Five-times cash multiplier.","4,499 R$"},
 {"+1 Pet Equip","Equip one additional pet.","500 R$"},
 {"2x Trophies","Double trophies multiplier.","799 R$"},
 {"Refresh Ability","Ability refresh listing.","99 R$"},
 {"Dominus Pet","5x the multiplier of your equipped pet.","999 R$"},
 {"Permanent Abilities","No rebuying ability uses.","10,000 R$"},
 {"Skip Cooldowns","Cooldown-skip listing.","99 R$"},
}
for i,d in data do card(passes,i,d[1],d[2],d[3],154) end
local cash=grid("Cash",shop,2,154,182);cash.Visible=false
for i,d in {{"1,000","99"},{"5,000","500"},{"25,000","2,000"},{"100,000","8,999"},{"1,000,000","25,000"}} do card(cash,i,d[1].." Cash","Cash pack",d[2].." R$",154) end
local trophies=grid("Trophies",shop,2,154,182);trophies.Visible=false
for i,d in {{"50","299"},{"250","1,000"},{"1,000","3,999"}} do card(trophies,i,d[1].." Trophies","Trophy pack",d[2].." R$",154) end
label("PetsNote",shop,"PETS = CASH MULTIPLIERS",UDim2.new(0,34,1,-34),UDim2.fromOffset(1000,24),14,teal)
label("UsageRules",abilities,"Each purchase provides 2 games of use. Cash refill costs 10% of the original price. Robux refill restores 2 uses.",UDim2.fromOffset(34,120),UDim2.fromOffset(1050,48),17)
local ag=grid("AbilityCards",abilities,3,310,182)
local abilityData={
 {"Gravity Switch","Reverse every other player's gravity.\nCooldown: 20 seconds.","150,000 cash","Refill: 15,000 cash  |  149 R$"},
 {"Plat Be Gone","Remove a zone's top or bottom platform so players fall through.\nCooldown: 30 seconds.","50,000 cash","Refill: 5,000 cash  |  99 R$"},
 {"Kong","Release barrels that concuss and drop players hit for 3 seconds.\nCooldown: 25 seconds.","250,000 cash","Refill: 25,000 cash  |  299 R$"},
 {"Freeze","Freeze other players for 3 seconds.\nCooldown: to be decided.","100,000 cash","Refill: 10,000 cash  |  99 R$"},
 {"Antispike","Disable red spikes for yourself.\nCooldown: 25 seconds.","200,000 cash","Refill: 20,000 cash  |  149 R$"},
 {"Superspeed","Double the speed granted by a speed power-up.\nOnce per round; 5 rounds per game.","250,000 cash","Refill: 25,000 cash  |  299 R$"},
}
for i,d in abilityData do card(ag,i,d[1],d[2],d[3],310,d[4]) end
label("PreviewFooter",abilities,"PLACEHOLDER DESIGN  /  No ability effects or purchases are connected.",UDim2.new(0,34,1,-34),UDim2.fromOffset(1050,24),14,teal)
local launcher=make("Frame","PreviewButtons",gui,{Position=UDim2.new(1,-174,.5,100),Size=UDim2.fromOffset(160,104),BackgroundTransparency=1})
for i,name in {"Shop","Abilities"} do
 local b=make("ImageButton",name,launcher,{Position=UDim2.fromOffset(0,(i-1)*52),Size=UDim2.fromOffset(160,46),Image="rbxassetid://73899067954592",BackgroundTransparency=1})
 local t=label("Text",b,string.upper(name),UDim2.new(),UDim2.fromScale(1,1),18);t.TextXAlignment=Enum.TextXAlignment.Center;t.TextYAlignment=Enum.TextYAlignment.Center
end
gui:SetAttribute("MockupOnly",true)
return "Created GBloxShopMockups: 8 shop listings, 5 cash packs, 3 trophy packs, 6 ability cards. Purchase artwork is non-interactive."
