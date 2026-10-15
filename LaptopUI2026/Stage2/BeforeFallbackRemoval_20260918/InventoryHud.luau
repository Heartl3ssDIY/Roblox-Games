-- InventoryHud: a HUD bag button + panel for activating stored gift rewards (weather mutations, boosts).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer

local function make(c,p,ch) local i=Instance.new(c); for k,v in pairs(p)do i[k]=v end for _,x in ipairs(ch or{})do x.Parent=i end return i end
local TH={panel=Color3.fromRGB(26,40,92),card=Color3.fromRGB(40,60,128),btn=Color3.fromRGB(64,170,98),
	gold=Color3.fromRGB(248,200,86),text=Color3.fromRGB(236,242,255),sub=Color3.fromRGB(158,176,216),
	stroke=Color3.fromRGB(74,112,188),cardTop=Color3.fromRGB(50,74,150),cardBot=Color3.fromRGB(30,46,104)}

local rem=RS:WaitForChild("Remotes")
local invRF=rem:WaitForChild("Inventory")
local invEv=rem:WaitForChild("InventoryUpdate")

local gui=make("ScreenGui",{Name="InventoryHud",ResetOnSpawn=false,DisplayOrder=40,IgnoreGuiInset=true})
gui.Parent=plr:WaitForChild("PlayerGui")

-- Bag flows into the top-left HUD column (LeftBar), right under the Level chip.
local leftBar=plr:WaitForChild("PlayerGui"):WaitForChild("WarehouseUI"):WaitForChild("LeftBar")
local UIArt=(function()
-- Shared presentation only: existing controls retain their input and purchase handlers.
local UIArt={}
local assets=leftBar.Parent:WaitForChild("LaptopAssets")
function UIArt.image(name) return assets:WaitForChild(name).Value end
local function clearDecor(object)
 object.BackgroundTransparency=1;object.BorderSizePixel=0
 for _,c in object:GetChildren() do
  if c:IsA("UIStroke") then c.Enabled=false elseif c:IsA("UIGradient") then c.Enabled=false end
 end
end
function UIArt.panel(object,name,z)
 clearDecor(object)
 local a=object:FindFirstChild("SkinArt")
 if not a then a=Instance.new("ImageLabel");a.Name="SkinArt";a.BackgroundTransparency=1;a.BorderSizePixel=0;a.Active=false;a.Parent=object end
 a.Image=UIArt.image(name);a.ZIndex=math.max(1,(z or object.ZIndex)-1);a.ScaleType=Enum.ScaleType.Fit
 local p=object:FindFirstChildOfClass("UIPadding")
 local l,r,t,b=0,0,0,0
 if p then l=p.PaddingLeft.Offset;r=p.PaddingRight.Offset;t=p.PaddingTop.Offset;b=p.PaddingBottom.Offset end
 a.Position=UDim2.fromOffset(-l,-t);a.Size=UDim2.new(1,l+r,1,t+b)
 if object.BackgroundColor3==Color3.fromRGB(163,162,165) then object.BackgroundColor3=Color3.fromRGB(40,60,128) end
 local function loaded() object.BackgroundTransparency=a.IsLoaded and 1 or 0 end
 a:GetPropertyChangedSignal("IsLoaded"):Connect(loaded);loaded()
 return a
end
return UIArt

end)()
local bag=make("TextButton",{Name="Bag",Size=UDim2.fromOffset(204,71),LayoutOrder=6,BackgroundTransparency=1,Text="",AutoButtonColor=false,ZIndex=2})
local inventoryArt=UIArt.panel(bag,"InventoryButton",2)
local fallback=make("TextLabel",{Name="LoadingLabel",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,TextSize=20,TextColor3=Color3.new(1,1,1),TextStrokeTransparency=.2,Text="Inventory",ZIndex=3,Parent=bag})
local function imageReady() fallback.Visible=not inventoryArt.IsLoaded end
inventoryArt:GetPropertyChangedSignal("IsLoaded"):Connect(imageReady);imageReady()

bag.Parent=leftBar
local badge=make("TextLabel",{Name="Count",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,2,0,-6),Size=UDim2.fromOffset(22,22),
	BackgroundColor3=Color3.fromRGB(225,60,60),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),Text="0",Visible=false,ZIndex=3},{
	make("UICorner",{CornerRadius=UDim.new(1,0)})})
badge.Parent=bag

local panel=make("Frame",{Name="Panel",AnchorPoint=Vector2.new(0,0),Position=UDim2.new(0,230,0,80),Size=UDim2.fromOffset(286,340),
	BackgroundColor3=TH.panel,Visible=false,ZIndex=2},{
	make("UICorner",{CornerRadius=UDim.new(0,18)}), make("UIStroke",{Color=Color3.fromRGB(96,150,255),Thickness=2.5}), make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(40,60,128),Color3.fromRGB(16,24,60)),Rotation=90}),
	make("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)})})
panel:SetAttribute("FitW",286); panel:SetAttribute("FitH",340); panel.Parent=gui
make("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,24),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=TH.gold,Text="Inventory",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2}).Parent=panel
local list=make("ScrollingFrame",{Name="List",BackgroundTransparency=1,Position=UDim2.new(0,0,0,30),Size=UDim2.new(1,0,1,-30),
	AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(96,140,230),BorderSizePixel=0,ZIndex=2},{
	make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})})
list.Parent=panel

local WEATHER_ICON={Rain="77238968112926",Snow="109296391427207",Thunderstorm="105530651131697",Rainbow="134424720797150"}
local function iconFor(item)
	if item.kind=="weather" then return WEATHER_ICON[item.weather] or "77238968112926"
	elseif item.kind=="boost" then return (item.boost=="xp") and "91175965313196" or "136620269244747"
	elseif item.kind=="pkgmutation" then return (item.mutation=="rainbow") and "134424720797150" or "137921365992492" end
	return "123608924419962"
end
local function render(items)
	items=items or {}
	for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
	badge.Text=tostring(#items); badge.Visible = #items>0
	if #items==0 then
		make("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,60),Font=Enum.Font.Gotham,TextSize=13,TextColor3=TH.sub,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,Text="Empty. Win weather mutations & x2 boosts from gift trucks, then activate them here when you want.",LayoutOrder=1,ZIndex=2}).Parent=list
		return
	end
	for i,item in ipairs(items) do
		local card=make("Frame",{BackgroundColor3=TH.card,Size=UDim2.new(1,-4,0,54),LayoutOrder=i,ZIndex=2},{make("UICorner",{CornerRadius=UDim.new(0,10)}),make("UIStroke",{Color=TH.stroke,Thickness=1}),make("UIGradient",{Color=ColorSequence.new(TH.cardTop,TH.cardBot),Rotation=90}),make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,6)})})
		make("ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://"..iconFor(item),Size=UDim2.fromOffset(34,34),Position=UDim2.new(0,2,0.5,0),AnchorPoint=Vector2.new(0,0.5),ZIndex=3}).Parent=card
		make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,42,0,0),Size=UDim2.new(1,-104,1,0),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=TH.text,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Text=(item.label or item.kind),ZIndex=3}).Parent=card
		local use=make("TextButton",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(56,34),BackgroundColor3=TH.btn,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),Text="Use",AutoButtonColor=true,ZIndex=3},{make("UICorner",{CornerRadius=UDim.new(0,7)})})
		use.Activated:Connect(function()
			use.Active=false; use.Text="..."
			task.spawn(function() pcall(function() return invRF:InvokeServer({action="activate", index=i}) end) end)
		end)
		use.Parent=card
		card.Parent=list
	end
end

invEv.OnClientEvent:Connect(render)
bag.Activated:Connect(function() panel.Visible = not panel.Visible end)
task.spawn(function()
	local ok,res=pcall(function() return invRF:InvokeServer({action="get"}) end)
	if ok and res and res.items then render(res.items) end
end)
