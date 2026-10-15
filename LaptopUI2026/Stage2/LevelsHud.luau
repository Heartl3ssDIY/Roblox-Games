local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")
local Progression=require(RS.Configs.ProgressionConfig)
local function make(c,p,ch) local i=Instance.new(c); for k,v in pairs(p)do i[k]=v end for _,x in ipairs(ch or{})do x.Parent=i end return i end
local function fmt(n) local s=tostring(math.floor(n)); local o="" while #s>3 do o=","..s:sub(#s-2)..o; s=s:sub(1,#s-3) end return s..o end

local LOCK="rbxassetid://135331072081593"
local CHECK="rbxassetid://104966124695479"
local MILES={
 {lvl=1,  title="QuickHands Staffing",   desc="Roll your first hiring agency"},
 {lvl=10, title="Black Market",          desc="Weapons, potions & sabotage"},
 {lvl=15, title="Security + BoxBuddies",  desc="CCTV, guards, armoury & a new agency"},
 {lvl=30, title="PrimeLift Personnel",    desc="Higher-tier hiring agency"},
 {lvl=45, title="Apex Workforce",         desc="Higher-tier hiring agency"},
 {lvl=60, title="Elite Logistics Guild",  desc="Top-tier hiring agency"},
 {lvl=100,title="Prestige",               desc="Sell your company & restart for prestige"},
}

local BASE_W,BASE_H=430,548
local gui=make("ScreenGui",{Name="LevelsGui",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=46})
gui.Parent=pg

local dim=make("TextButton",{Name="Dim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.5,Text="",Visible=false,ZIndex=10,AutoButtonColor=false})
dim.Parent=gui

local panel=make("Frame",{Name="Panel",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(BASE_W,BASE_H),
	BackgroundColor3=Color3.fromRGB(26,40,92),Visible=false,ZIndex=11},{
	make("UICorner",{CornerRadius=UDim.new(0,20)}),
	make("UIStroke",{Color=Color3.fromRGB(96,150,255),Thickness=2.5}),
	make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(40,60,128),Color3.fromRGB(16,24,60)),Rotation=90}),
	make("UIPadding",{PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,18),PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16)})})
panel.Parent=gui
local fit=make("UIScale",{Name="Fit"}); fit.Parent=panel

-- header
make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,-40,0,28),Font=Enum.Font.GothamBold,TextSize=22,TextColor3=Color3.fromRGB(248,200,86),TextXAlignment=Enum.TextXAlignment.Left,Text="Levels",ZIndex=12}).Parent=panel
local closeX=make("TextButton",{Name="Close",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,-2),Size=UDim2.fromOffset(32,32),BackgroundColor3=Color3.fromRGB(228,84,98),Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.new(1,1,1),Text="X",ZIndex=12},{make("UICorner",{CornerRadius=UDim.new(0,9)})})
closeX.Parent=panel

-- current-level card
local card=make("Frame",{Name="Cur",Position=UDim2.new(0,0,0,40),Size=UDim2.new(1,0,0,118),BackgroundColor3=Color3.fromRGB(40,60,128),ZIndex=12},{
	make("UICorner",{CornerRadius=UDim.new(0,14)}),
	make("UIStroke",{Color=Color3.fromRGB(74,112,188),Thickness=1.2}),
	make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(50,74,150),Color3.fromRGB(30,46,104)),Rotation=90}),
	make("UIPadding",{PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)})})
card.Parent=panel
local bigLvl=make("TextLabel",{Name="Big",BackgroundTransparency=1,Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,0,30),Font=Enum.Font.GothamBlack,TextSize=26,TextColor3=Color3.fromRGB(255,212,120),TextXAlignment=Enum.TextXAlignment.Left,Text="Level 1",ZIndex=13})
bigLvl.Parent=card
local totalLbl=make("TextLabel",{Name="Total",BackgroundTransparency=1,Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,0,30),Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.fromRGB(158,176,216),TextXAlignment=Enum.TextXAlignment.Right,Text="0 total XP",ZIndex=13})
totalLbl.Parent=card
local track=make("Frame",{Name="Track",Position=UDim2.new(0,0,0,52),Size=UDim2.new(1,0,0,18),BackgroundColor3=Color3.fromRGB(16,24,60),ZIndex=13},{make("UICorner",{CornerRadius=UDim.new(1,0)}),make("UIStroke",{Color=Color3.fromRGB(52,64,108),Thickness=1})})
track.Parent=card
local fill=make("Frame",{Name="Fill",Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(255,196,80),ZIndex=14},{make("UICorner",{CornerRadius=UDim.new(1,0)}),make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(255,216,116),Color3.fromRGB(244,166,40)),Rotation=90})})
fill.Parent=track
local prog=make("TextLabel",{Name="Prog",BackgroundTransparency=1,Position=UDim2.new(0,0,0,78),Size=UDim2.new(1,0,0,18),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=Color3.fromRGB(210,222,250),TextXAlignment=Enum.TextXAlignment.Center,Text="",ZIndex=13})
prog.Parent=card

make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,2,0,166),Size=UDim2.new(1,0,0,20),Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(248,200,86),TextXAlignment=Enum.TextXAlignment.Left,Text="Unlocks",ZIndex=12}).Parent=panel

local list=make("ScrollingFrame",{Name="List",Active=true,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,0,0,190),Size=UDim2.new(1,0,1,-190),
	CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(96,140,230),ZIndex=12},{
	make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder}),make("UIPadding",{PaddingRight=UDim.new(0,6)})})
list.Parent=panel

local milesByLvl={}
for _,m in ipairs(MILES) do milesByLvl[m.lvl]=m end
local rowY={}
local function buildRows(level)
	for _,c in ipairs(list:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
	rowY={}; local y=0
	for l=1,Progression.PrestigeLevel do
		local m=milesByLvl[l]; local done=level>=l; rowY[l]=y
		if m then
			local row=make("Frame",{LayoutOrder=l,Size=UDim2.new(1,0,0,62),BackgroundColor3=Color3.fromRGB(36,54,118),ZIndex=12},{make("UICorner",{CornerRadius=UDim.new(0,12)}),make("UIStroke",{Color=done and Color3.fromRGB(86,200,120) or Color3.fromRGB(64,98,170),Thickness=1.2}),make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(46,68,140),Color3.fromRGB(28,42,100)),Rotation=90})})
			make("TextLabel",{BackgroundColor3=Color3.fromRGB(20,30,72),Position=UDim2.new(0,10,0.5,0),AnchorPoint=Vector2.new(0,0.5),Size=UDim2.fromOffset(50,42),Font=Enum.Font.GothamBlack,TextSize=15,TextColor3=Color3.fromRGB(255,212,120),Text="Lv\n"..l,ZIndex=13},{make("UICorner",{CornerRadius=UDim.new(0,9)}),make("UIStroke",{Color=Color3.fromRGB(74,112,188),Thickness=1})}).Parent=row
			make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,72,0,9),Size=UDim2.new(1,-150,0,20),Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(236,242,255),TextXAlignment=Enum.TextXAlignment.Left,Text=m.title,ZIndex=13}).Parent=row
			make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,72,0,31),Size=UDim2.new(1,-150,0,18),Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(158,176,216),TextXAlignment=Enum.TextXAlignment.Left,Text=m.desc,ZIndex=13}).Parent=row
			make("ImageLabel",{BackgroundTransparency=1,Image=done and CHECK or LOCK,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(26,26),ImageColor3=done and Color3.fromRGB(120,235,150) or Color3.fromRGB(150,168,205),ZIndex=13}).Parent=row
			row.Parent=list; y=y+70
		else
			local row=make("Frame",{LayoutOrder=l,Size=UDim2.new(1,0,0,34),BackgroundColor3=Color3.fromRGB(28,42,100),BackgroundTransparency=0.3,ZIndex=12},{make("UICorner",{CornerRadius=UDim.new(0,8)})})
			make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0,60,1,0),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(200,212,245),TextXAlignment=Enum.TextXAlignment.Left,Text="Lv "..l,ZIndex=13}).Parent=row
			make("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,80,0,0),Size=UDim2.new(1,-150,1,0),Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(120,138,180),TextXAlignment=Enum.TextXAlignment.Left,Text="No reward",ZIndex=13}).Parent=row
			make("ImageLabel",{BackgroundTransparency=1,Image=done and CHECK or LOCK,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(20,20),ImageColor3=done and Color3.fromRGB(110,200,135) or Color3.fromRGB(120,138,180),ImageTransparency=0.15,ZIndex=13}).Parent=row
			row.Parent=list; y=y+42
		end
	end
end

local cur=plr:WaitForChild("Currency")
local xpV=cur:WaitForChild("Xp")
local lastLevel=-1
local function refresh()
	local level,into,need=Progression.levelForXp(xpV.Value)
	bigLvl.Text=(level>=Progression.PrestigeLevel) and ("Level "..level.."  (MAX)") or ("Level "..level)
	totalLbl.Text=fmt(xpV.Value).." total XP"
	fill.Size=UDim2.new(math.clamp(need>0 and into/need or 1,0,1),0,1,0)
	prog.Text=(need>0) and (fmt(into).." / "..fmt(need).." XP to Lv "..(level+1)) or "Max level reached"
	if level~=lastLevel then lastLevel=level; buildRows(level) end
end
xpV.Changed:Connect(refresh)
refresh()

-- responsive fit
local cam=workspace.CurrentCamera
local function applyFit()
	local vp=cam.ViewportSize
	fit.Scale=math.clamp(math.min(vp.X*0.92/BASE_W, vp.Y*0.9/BASE_H),0.4,1)
end
applyFit(); cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyFit)

-- wire the Level chip
local chip=pg:WaitForChild("WarehouseUI"):WaitForChild("LeftBar"):WaitForChild("LevelChip")
local function openP() refresh(); panel.Visible=true; dim.Visible=true; local _lv=Progression.levelForXp(xpV.Value); list.CanvasPosition=Vector2.new(0, math.max(0,(rowY[_lv] or 0)-90)) end
local function closeP() panel.Visible=false; dim.Visible=false end
if chip:IsA("TextButton") or chip:IsA("ImageButton") then
	chip.Activated:Connect(function() if panel.Visible then closeP() else openP() end end)
end
closeX.Activated:Connect(closeP)
dim.Activated:Connect(closeP)
