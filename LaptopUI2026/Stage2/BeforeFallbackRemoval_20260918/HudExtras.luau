local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunService=game:GetService("RunService"); local TweenService=game:GetService("TweenService")
local plr=Players.LocalPlayer; local gui=script.Parent
local UIArt=(function()
-- Shared presentation only: existing controls retain their input and purchase handlers.
local UIArt={}
local assets=gui:WaitForChild("LaptopAssets")
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
local Progression=require(RS.Configs.ProgressionConfig)
local THEME={panel=Color3.fromRGB(30,34,60),stroke=Color3.fromRGB(70,80,130),text=Color3.fromRGB(235,238,250),
	sub=Color3.fromRGB(150,158,190),accent=Color3.fromRGB(70,130,240),gold=Color3.fromRGB(245,195,70)}
local function make(c,p,ch) local i=Instance.new(c); for k,v in pairs(p)do i[k]=v end for _,x in ipairs(ch or{})do x.Parent=i end return i end
local function fmt2(n) local s=tostring(math.floor(n)); local o="" while #s>3 do o=","..s:sub(#s-2)..o; s=s:sub(1,#s-3) end return s..o end

-- clock pill (top center): date line (weekday + week) over time line (clock + shift)
local clock=make("Frame",{Name="ClockPill",BackgroundColor3=Color3.fromRGB(26,40,92),AnchorPoint=Vector2.new(0.5,0),
	Position=UDim2.new(0.5,0,0,14),Size=UDim2.fromOffset(288,56)},{
	make("UICorner",{CornerRadius=UDim.new(0,14)}),
	make("UIStroke",{Color=Color3.fromRGB(96,150,255),Thickness=2}),
	make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(40,60,128),Color3.fromRGB(16,24,60)),Rotation=90}),
	make("TextLabel",{Name="D",BackgroundTransparency=1,Position=UDim2.new(0,0,0,6),Size=UDim2.new(1,0,0,20),Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(248,200,86),Text="Monday  \u{00B7}  Week 1"})})
local timeRow=make("Frame",{Name="TimeRow",BackgroundTransparency=1,Position=UDim2.new(0,0,0,28),Size=UDim2.new(1,0,0,24),ZIndex=2},{
	make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder}),
	make("ImageLabel",{Name="ClockIcon",LayoutOrder=1,BackgroundTransparency=1,Image="rbxassetid://72922695241969",Size=UDim2.fromOffset(18,18)}),
	make("TextLabel",{Name="TimeLbl",LayoutOrder=2,BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,20),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(236,242,255),Text="06:00"}),
	make("TextLabel",{Name="Sep",LayoutOrder=3,BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,20),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(120,140,190),Text="\u{00B7}"}),
	make("ImageLabel",{Name="ShiftIcon",LayoutOrder=4,BackgroundTransparency=1,Image="rbxassetid://103969815839775",Size=UDim2.fromOffset(18,18)}),
	make("TextLabel",{Name="ShiftLbl",LayoutOrder=5,BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,20),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(236,242,255),Text="Morning"})})
timeRow.Parent=clock
clock.Parent=gui

-- level chip (LeftBar)
local leftBar=gui:WaitForChild("LeftBar")
local lvl=make("TextButton",{Name="LevelChip",AutoButtonColor=false,Text="",BackgroundTransparency=1,Size=UDim2.fromOffset(204,72),LayoutOrder=5},{
 make("TextLabel",{Name="L",BackgroundTransparency=1,Position=UDim2.fromOffset(46,7),Size=UDim2.new(1,-58,0,26),Font=Enum.Font.FredokaOne,TextSize=20,TextColor3=Color3.new(1,1,1),TextStrokeColor3=Color3.fromRGB(10,15,35),TextStrokeTransparency=.2,Text="1",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3}),
 make("ImageLabel",{Name="Bar",BackgroundTransparency=1,Image=UIArt.image("LevelTrack"),Position=UDim2.fromOffset(12,43),Size=UDim2.new(1,-24,0,18),ZIndex=3},{
  make("ImageLabel",{Name="Fill",BackgroundTransparency=1,Image=UIArt.image("LevelFill"),Size=UDim2.new(0,0,1,0),ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(10,10,149,12),ZIndex=4})})})
UIArt.panel(lvl,"LevelHud",1)

lvl.Parent=leftBar

local gt=RS:WaitForChild("GameTime"); local cur=plr:WaitForChild("Currency")
local SHIFT_ICON={Morning="103969815839775",Afternoon="119706145426345",Night="114095502206294"}
local acc=0
RunService.RenderStepped:Connect(function(dt)
	acc=acc+dt; if acc<0.2 then return end; acc=0
	do local h=gt:GetAttribute("Hour") or 6; local hh=math.floor(h); local mm=math.floor((h-hh)*60)
		timeRow.TimeLbl.Text=string.format("%02d:%02d",hh,mm)
		local shift=gt:GetAttribute("Shift") or "Morning"
		timeRow.ShiftLbl.Text=shift
		timeRow.ShiftIcon.Image="rbxassetid://"..(SHIFT_ICON[shift] or "103969815839775") end
	local wd=gt:GetAttribute("Weekday") or "Monday"
	clock.D.Text=string.format("%s  \u{00B7}  Week %d%s", wd, gt:GetAttribute("Week") or 1, wd=="Friday" and "  \u{1F4BC}" or "")
	local level,into,need=Progression.levelForXp(cur.Xp.Value)
	lvl.L.Text=(lvl.SkinArt.IsLoaded and "" or "Lvl ")..level
	lvl.Bar.Fill.Size=UDim2.new(math.clamp(need>0 and into/need or 0,0,1),0,1,0)
end)

local Remotes=RS:WaitForChild("Remotes")
-- toasts
local toastHolder=make("Frame",{Name="Toasts",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,1),
	Position=UDim2.new(0.5,0,1,-90),Size=UDim2.fromOffset(380,220)},{
	make("UIListLayout",{VerticalAlignment=Enum.VerticalAlignment.Bottom,HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})})
toastHolder.Parent=gui
local function colorFor(kind)
	if kind=="success" then return Color3.fromRGB(60,170,90)
	elseif kind=="error" or kind=="expense" then return Color3.fromRGB(200,70,70)
	else return Color3.fromRGB(50,90,170) end
end
Remotes.Notify.OnClientEvent:Connect(function(data)
	data=data or {}
	local t=make("Frame",{BackgroundColor3=colorFor(data.kind),Size=UDim2.fromOffset(360,38),BackgroundTransparency=0.05},{
		make("UICorner",{CornerRadius=UDim.new(0,10)}),
		make("TextLabel",{Name="Msg",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.new(1,1,1),Text=tostring(data.text or "")})})
	t.Parent=toastHolder
	task.delay(3,function() for i=1,12 do t.BackgroundTransparency=0.05+i*0.08; pcall(function() t.Msg.TextTransparency=i*0.085 end); task.wait(0.03) end t:Destroy() end)
end)

-- investor offer popup (generic; reads title/rate)
Remotes.InvestorOffer.OnClientEvent:Connect(function(data)
	data=data or {}
	if gui:FindFirstChild("InvestorPopup") then gui.InvestorPopup:Destroy() end
	local ov=make("Frame",{Name="InvestorPopup",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.45,Size=UDim2.fromScale(1,1),ZIndex=30})
	local card=make("Frame",{BackgroundColor3=Color3.fromRGB(28,32,56),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(450,250),ZIndex=31,Parent=ov},{
		make("UICorner",{CornerRadius=UDim.new(0,16)}), make("UIStroke",{Color=THEME.gold,Thickness=2}),
		make("UIPadding",{PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,18),PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16)})})
	make("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,28),Font=Enum.Font.GothamBold,TextSize=22,TextColor3=THEME.gold,Text=data.title or "\u{1F4BC} Investor",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=card})
	make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,42),Size=UDim2.new(1,0,0,70),Font=Enum.Font.Gotham,TextSize=15,TextColor3=Color3.fromRGB(220,224,235),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextXAlignment=Enum.TextXAlignment.Left,Text="Hand over 25% of your Cash ($"..fmt2(data.cash25 or 0)..") for Crypto at "..fmt2(data.rate or 1000).." : 1.",ZIndex=31,Parent=card})
	make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,118),Size=UDim2.new(1,0,0,34),Font=Enum.Font.GothamBold,TextSize=24,TextColor3=Color3.fromRGB(64,200,224),Text="+ "..fmt2(data.crypto or 0).." \u{25C6} Crypto",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=card})
	local row=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,0),Size=UDim2.new(1,0,0,44),ZIndex=31,Parent=card},{
		make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})})
	local function btn(txt,color,accept,order)
		local b=make("TextButton",{Text=txt,BackgroundColor3=color,Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.new(1,1,1),Size=UDim2.fromOffset(185,42),LayoutOrder=order,ZIndex=31,Parent=row},{make("UICorner",{CornerRadius=UDim.new(0,10)})})
		b.Activated:Connect(function() Remotes.InvestorRespond:FireServer(accept); ov:Destroy() end)
	end
	btn("Accept Deal",Color3.fromRGB(60,180,90),true,1)
	btn("Decline",Color3.fromRGB(90,96,110),false,2)
	ov.Parent=gui
end)

-- ===== XP-gain float + Level-up celebration =====
-- Floating "+N XP" appears by the level chip whenever XP is awarded (e.g. a truck is filled);
-- a celebratory banner pops when the player's level increases.
local lastXp = cur.Xp.Value
local lastLevel = Progression.levelForXp(cur.Xp.Value)
local startT = os.clock()

local function floatXp(amount)
	local f=make("TextLabel",{Name="XpFloat",BackgroundTransparency=1,AnchorPoint=Vector2.new(0,0.5),
		Position=UDim2.new(1,10,0.5,0),Size=UDim2.fromOffset(130,26),Font=Enum.Font.GothamBlack,TextSize=18,
		TextColor3=THEME.gold,TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=0.35,
		TextXAlignment=Enum.TextXAlignment.Left,Text="+"..fmt2(amount).." XP",ZIndex=25})
	f.Parent=lvl
	TweenService:Create(f,TweenInfo.new(1.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
		{Position=UDim2.new(1,10,0.5,-30),TextTransparency=1,TextStrokeTransparency=1}):Play()
	task.delay(1.2,function() f:Destroy() end)
end

local function levelUpPopup(newLevel)
	if gui:FindFirstChild("LevelUpPopup") then gui.LevelUpPopup:Destroy() end
	local ov=make("Frame",{Name="LevelUpPopup",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0),
		Position=UDim2.new(0.5,0,0,96),Size=UDim2.fromOffset(360,96),ZIndex=40,Parent=gui})
	local card=make("Frame",{BackgroundColor3=THEME.panel,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
		Size=UDim2.fromOffset(40,40),ZIndex=41,Parent=ov},{
		make("UICorner",{CornerRadius=UDim.new(0,16)}), make("UIStroke",{Color=THEME.gold,Thickness=2.5}),
		make("TextLabel",{Name="Big",BackgroundTransparency=1,Position=UDim2.new(0,0,0,14),Size=UDim2.new(1,0,0,34),
			Font=Enum.Font.GothamBlack,TextSize=26,TextColor3=THEME.gold,Text="\u{2B50} LEVEL UP!"}),
		make("TextLabel",{Name="Sub",BackgroundTransparency=1,Position=UDim2.new(0,0,0,50),Size=UDim2.new(1,0,0,28),
			Font=Enum.Font.GothamBold,TextSize=20,TextColor3=THEME.text,Text="You reached Level "..newLevel})})
	TweenService:Create(card,TweenInfo.new(0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(320,84)}):Play()
	task.delay(2.2,function()
		if not ov.Parent then return end
		TweenService:Create(ov,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,0,46)}):Play()
		TweenService:Create(card,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
		local st=card:FindFirstChildOfClass("UIStroke"); if st then TweenService:Create(st,TweenInfo.new(0.4),{Transparency=1}):Play() end
		for _,d in ipairs(card:GetChildren()) do if d:IsA("TextLabel") then TweenService:Create(d,TweenInfo.new(0.4),{TextTransparency=1}):Play() end end
		task.delay(0.45,function() ov:Destroy() end)
	end)
end

cur.Xp.Changed:Connect(function(newXp)
	local delta = newXp - lastXp
	lastXp = newXp
	local newLevel = Progression.levelForXp(newXp)
	local leveled = newLevel > lastLevel
	lastLevel = newLevel
	if os.clock()-startT < 4 then return end   -- ignore the load-time replication burst on join
	if delta > 0 then floatXp(delta) end
	if leveled then levelUpPopup(newLevel) end
end)
