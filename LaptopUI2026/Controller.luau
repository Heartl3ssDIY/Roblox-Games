local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer
local gui = script.Parent
local assets=gui:WaitForChild("LaptopAssets")
local function art(name) return assets[name].Value end
 task.spawn(function()
 local images={};for _,value in assets:GetChildren() do if value:IsA("StringValue") then table.insert(images,value.Value) end end
 pcall(function() game:GetService("ContentProvider"):PreloadAsync(images) end)
end)

-- Resolve THIS player's own warehouse plot (set by the server's PlotService as an ObjectValue).
-- Falls back to the primary Workspace.Warehouse so the host/solo case is unchanged.
local function myWarehouse()
	local ov=plr:FindFirstChild("PlotModel") or plr:WaitForChild("PlotModel",10)
	if ov then
		if not ov.Value then ov:GetPropertyChangedSignal("Value"):Wait() end
		if ov.Value then return ov.Value end
	end
	return game:GetService("Workspace"):WaitForChild("Warehouse")
end

local function make(class, props, children)
	local inst = Instance.new(class)
	for k,v in pairs(props or {}) do inst[k]=v end
	for _,c in ipairs(children or {}) do c.Parent=inst end
	return inst
end
local function corner(r) return make("UICorner",{CornerRadius=UDim.new(0,r or 10)}) end
local function stroke(c,t) return make("UIStroke",{Color=c,Thickness=t or 1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
-- subtle top-lit gradient (multiplies the parent fill) for depth on cards/buttons
local function grad(rot)
	local g=Instance.new("UIGradient")
	g.Rotation=rot or 90
	g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(202,202,214))})
	return g
end
-- a small flat "gem" icon used for the Crypto currency (replaces the diamond glyph)
local function gemIcon(sz)
	return make("ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://104741920562923",Size=UDim2.fromOffset(sz,sz),ZIndex=11})
end
local function fmt(n)
	local s = tostring(math.floor(n)); local out=""
	while #s>3 do out=","..s:sub(#s-2)..out; s=s:sub(1,#s-3) end
	return s..out
end

local THEME = {
bgDeep=Color3.fromRGB(16,24,60), panel=Color3.fromRGB(40,60,128), panel2=Color3.fromRGB(52,78,156),
slot=Color3.fromRGB(26,40,90), stroke=Color3.fromRGB(74,112,188), text=Color3.fromRGB(236,242,255),
subtext=Color3.fromRGB(158,176,216), accent=Color3.fromRGB(72,134,248), gold=Color3.fromRGB(248,200,86),
green=Color3.fromRGB(86,200,120), red=Color3.fromRGB(236,84,98),
}
local RARITY = {
	{name="Common",   color=Color3.fromRGB(150,160,180)},
	{name="Uncommon", color=Color3.fromRGB(90,205,120)},
	{name="Rare",     color=Color3.fromRGB(70,140,240)},
	{name="Epic",     color=Color3.fromRGB(170,90,235)},
	{name="Legendary",color=Color3.fromRGB(245,180,55)},
	{name="Mythic",   color=Color3.fromRGB(235,75,95)},
}

-- bind to server-authoritative currency (Player.Currency folder)
local cur = plr:WaitForChild("Currency")
local cashV, cryptoV = cur:WaitForChild("Cash"), cur:WaitForChild("Crypto")
local function refreshCurrency()
	gui.LeftBar.Cash.Amount.Text   = "$"..fmt(cashV.Value)
	gui.LeftBar.Crypto.Amount.Text = fmt(cryptoV.Value)
end
cashV.Changed:Connect(refreshCurrency)
cryptoV.Changed:Connect(refreshCurrency)
refreshCurrency()
local coins, cash = cashV.Value, cryptoV.Value  -- snapshots for laptop content below

local NAMES = {"Forklift Frank","Box Betty","Pallet Pete","Loader Luis","Crane Carla",
	"Scanner Sam","Dolly Dana","Picker Paul","Sorter Sara","Hauler Hank","Packer Priya","Driver Dex"}
local workers = {}
for i=1,22 do
	local r = RARITY[math.random(1,#RARITY)]
	table.insert(workers,{name=NAMES[((i-1)%#NAMES)+1],rarity=r,level=math.random(1,9),
		speed=math.random(2,10),cap=math.random(1,6)*5,wage=math.random(1,8)*5})
end

-- ===== Worker inventory =====
local wov = gui.WorkerOverlay
local panel = wov.Panel
-- (worker overlay contents are built by the WorkerInv LocalScript; Controller only opens/closes it)

local function selectWorker(w)
	prev.Portrait.BackgroundColor3 = w.rarity.color:Lerp(THEME.slot,0.7)
	prev.Portrait.Rarity.Text = w.rarity.name
	prev.Portrait.Rarity.TextColor3 = w.rarity.color
	local us = prev.Portrait:FindFirstChild("UIStroke"); if us then us.Color = w.rarity.color end
	prev.WName.Text = w.name.."  (Lv "..w.level..")"
	prev.WStats.Text = ("Speed %d  •  Capacity %d  •  Wage $%d/min"):format(w.speed,w.cap,w.wage)
end
local function slot(w,i)
	local b = make("TextButton",{Name="Slot"..i,BackgroundColor3=THEME.slot,AutoButtonColor=true,Text="",
		LayoutOrder=i,ZIndex=6},{corner(10),stroke(w.rarity.color,2.5),
		make("TextLabel",{Name="N",BackgroundColor3=w.rarity.color,Size=UDim2.new(1,0,0,18),Text=w.name:sub(1,10),
			Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(20,20,30),ZIndex=6},{corner(6)}),
		make("TextLabel",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-4),
			Size=UDim2.new(1,0,0,16),Text="Lv "..w.level,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=THEME.text,ZIndex=6})})
	b.Activated:Connect(function() selectWorker(w) end)
	return b
end

-- ===== Laptop content =====
local lov = gui.LaptopOverlay
local root = lov.Root
root.AnchorPoint = Vector2.new(0.5,0.5)   -- centre the laptop so it scales to fit every device (was bottom-right)
local screen = root.Screen
local content = screen.Main.Content

local function card(parent,h,order)
	return make("Frame",{BackgroundColor3=THEME.panel,Size=UDim2.new(1,0,0,h),LayoutOrder=order,ZIndex=8},
		{corner(12),stroke(THEME.stroke,1.25),make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),
			PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10)}),grad(90),parent})
end
local function lbl(text,size,color,xa,pos,sz)
	return make("TextLabel",{BackgroundTransparency=1,Text=text,Font=Enum.Font.GothamBold,TextSize=size,
		TextColor3=color,TextXAlignment=xa or Enum.TextXAlignment.Left,Position=pos or UDim2.new(),
		Size=sz or UDim2.new(1,0,1,0),ZIndex=9,TextWrapped=true})
end
local function pill(text,color,parent)
	local b=make("TextButton",{Text=text,BackgroundColor3=color,Font=Enum.Font.GothamBold,TextSize=14,
		AutoButtonColor=false,TextColor3=Color3.fromRGB(255,255,255),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),
		Size=UDim2.fromOffset(112,34),ZIndex=9,Parent=parent},{corner(9),stroke(color:Lerp(Color3.new(0,0,0),0.4),1.5),grad(95)})
	b.MouseEnter:Connect(function() b:SetAttribute("rest",b.BackgroundColor3); TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=b.BackgroundColor3:Lerp(Color3.new(1,1,1),0.18)}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=b:GetAttribute("rest") or color}):Play() end)
	return b
end

-- All laptop-page content building below is wrapped in a pcall so that a failure while
-- building any page can never stop the open/close + tab handlers at the END of this script
-- from connecting. (Those handlers being skipped on an error was why BOTH overlays could
-- fail to open.)
local _contentOk, _contentErr = pcall(function()
local cP = content.Contracts
for i,c in ipairs({
	{client="MegaMart Distribution",cargo="Electronics ×40",reward=2200,days=2},
	{client="FreshFoods Co.",cargo="Perishables ×25",reward=1500,days=1},
	{client="BuildIt Hardware",cargo="Lumber ×60",reward=3100,days=3},
	{client="Apex Auto Parts",cargo="Engine Kits ×18",reward=2750,days=2}}) do
	local h = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl(c.client,17,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
	lbl(c.cargo.."   •   ⏱ "..c.days.." day(s)",13,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=h
	lbl("Reward: $"..fmt(c.reward),14,THEME.green,nil,UDim2.new(0,0,0,46),UDim2.new(1,-120,0,18)).Parent=h
	local b = pill("Accept",THEME.green,h)
	b.Activated:Connect(function() b.Text="Accepted ✓"; b.BackgroundColor3=THEME.subtext end)
	card(h,74,i).Parent = cP
end

local pP = content.Payments
do
	local bal = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Account Balance",14,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=bal
	lbl("$"..fmt(coins),32,THEME.gold,nil,UDim2.new(0,0,0,22),UDim2.new(1,0,0,40)).Parent=bal
	card(bal,80,1).Parent=pP
	for i,r in ipairs({{"Pending contract income","+$5,750",THEME.green},{"Worker wages (per min)","-$210",THEME.red},
		{"Truck fuel & upkeep","-$95",THEME.red},{"Warehouse rent (daily)","-$400",THEME.red}}) do
		local h = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(r[1],15,THEME.text,nil,UDim2.new(),UDim2.new(1,-120,1,0)).Parent=h
		lbl(r[2],16,r[3],Enum.TextXAlignment.Right,UDim2.new(0,0,0,0),UDim2.new(1,0,1,0)).Parent=h
		card(h,46,i+1).Parent=pP
	end
	local ch = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Collect available income",15,THEME.text,nil,UDim2.new(),UDim2.new(1,-120,1,0)).Parent=ch
	local cb = pill("Collect",THEME.accent,ch)
	cb.Activated:Connect(function() cb.Text="Collected ✓"; cb.BackgroundColor3=THEME.subtext end)
	card(ch,46,99).Parent=pP
end

local tP = content.Trucks
for i,t in ipairs({
	{id="Truck #1 — Box Van",status="In Warehouse",eta=nil},
	{id="Truck #2 — Flatbed",status="Out on delivery",eta="3:20"},
	{id="Truck #3 — Reefer",status="Out on delivery",eta="1:05"},
	{id="Truck #4 — Semi",status="In Warehouse",eta=nil}}) do
	local h = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	local out = t.eta ~= nil
	lbl(t.id,16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
	lbl((out and ("🚚 "..t.status.."  •  ETA "..t.eta) or "🏭 "..t.status),13,out and THEME.gold or THEME.green,
		nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=h
	local b = pill(out and "Recall" or "Dispatch", out and THEME.red or THEME.accent, h)
	b.Activated:Connect(function() b.Text="Sent ✓"; b.BackgroundColor3=THEME.subtext end)
	card(h,58,i).Parent=tP
end

local sP = content.Stats
local sLbFolder = myWarehouse():WaitForChild("LoadBays")
local GetRosterR = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("GetRoster")
local deliveriesV = cur:WaitForChild("Deliveries", 10)
local sg = make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,230),LayoutOrder=1,ZIndex=8},{
	make("UIGridLayout",{CellSize=UDim2.new(0.5,-6,0,70),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder})})
local statVals={}
for i,name in ipairs({"Total Deliveries","Net Worth","Workers Owned","Trucks","Reputation","Warehouse Level"}) do
	local c = make("Frame",{BackgroundColor3=THEME.panel,LayoutOrder=i,ZIndex=8},{corner(10),stroke(THEME.stroke,1),
		make("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingTop=UDim.new(0,8)})})
	lbl(name,13,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,16)).Parent=c
	local v=lbl("\u{2014}",24,THEME.text,nil,UDim2.new(0,0,0,22),UDim2.new(1,0,0,32)); v.Parent=c
	statVals[name]=v
	c.Parent=sg
end
sg.Parent = sP
local lastWorkers=0
local function countTrucks()
	local n=0
	for _,pad in ipairs(sLbFolder:GetChildren()) do
		if pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load" and pad:GetAttribute("Company") then n+=1 end
	end
	return n
end
local function refreshStats()
	local cashN=cur.Cash.Value; local cryptoN=cur.Crypto.Value; local level=cur.Level.Value
	local deliv=deliveriesV and deliveriesV.Value or 0
	local netWorth=cashN + cryptoN*3000
	local rating=math.clamp(3 + level*0.015 + deliv*0.002, 0, 5)
	statVals["Total Deliveries"].Text=fmt(deliv)
	statVals["Net Worth"].Text="$"..fmt(netWorth)
	statVals["Trucks"].Text=tostring(countTrucks())
	statVals["Warehouse Level"].Text=tostring(level)
	statVals["Reputation"].Text=("%.1f / 5"):format(rating)
	statVals["Workers Owned"].Text=lastWorkers.."/100"
end
cur.Cash.Changed:Connect(refreshStats); cur.Crypto.Changed:Connect(refreshStats); cur.Level.Changed:Connect(refreshStats)
if deliveriesV then deliveriesV.Changed:Connect(refreshStats) end
refreshStats()
-- worker count needs a server round-trip; poll lightly, only while the Stats page is visible
task.spawn(function()
	while true do
		if sP.Visible then
			local ok,data=pcall(function() return GetRosterR:InvokeServer() end)
			if ok and data and data.shifts then
				local seen={}; local n=0
				for _,list in pairs(data.shifts) do
					for _,w in ipairs(list) do if (not w.free) and not seen[w.name] then seen[w.name]=true; n+=1 end end
				end
				lastWorkers=n; refreshStats()
			end
		end
		task.wait(4)
	end
end)

-- ===== Agency hiring populate =====
local AgencyConfig = require(game:GetService("ReplicatedStorage").Configs.AgencyConfig)
local HireRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("HireEmployee")
local aP = content.Agency
local function plvl() local L=cur:FindFirstChild("Level"); return (L and L.Value) or 1 end
local function oddsStr(ag)
	local order={"Lazy","Good","Hard","Super","Exceptional"}; local parts={}
	for _,r in ipairs(order) do if ag.odds[r] then parts[#parts+1]=r.." "..ag.odds[r] end end
	return table.concat(parts," \u{00B7} ")
end
-- (re)build the agency list. Re-runs on level-up so a newly-unlocked agency becomes rollable live
-- (previously the lock state was baked in once at laptop load and never refreshed).
local function renderAgency()
	for _,c in ipairs(aP:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local resHolder = make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	local resLbl = lbl("Roll an agency to hire 3 workers (Morning / Afternoon / Night).",13,THEME.subtext,nil,UDim2.new(),UDim2.new(1,0,1,0))
	resLbl.TextWrapped=true; resLbl.Parent=resHolder
	card(resHolder,70,1).Parent=aP
	-- auto-dismiss rolled workers by tier
	local adH=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8})
	lbl("Auto-dismiss rolled workers of tier:",13,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=adH
	local adRow=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,24),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8},{
		make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Wraps=true,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})})
	local TIERCOL={Lazy=Color3.fromRGB(150,156,166),Good=Color3.fromRGB(90,200,110),Hard=Color3.fromRGB(70,140,240),Super=Color3.fromRGB(168,90,232),Exceptional=Color3.fromRGB(240,160,40)}
	local adBtns={}; local adState={}
	local WorkerSettings=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("WorkerSettings")
	local function adRefresh() for t,b in pairs(adBtns) do b.BackgroundColor3=adState[t] and TIERCOL[t] or THEME.panel2 end end
	for i,tier in ipairs({"Lazy","Good","Hard","Super","Exceptional"}) do
		local b=make("TextButton",{Name=tier,BackgroundColor3=THEME.panel2,AutoButtonColor=true,Text=tier,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=THEME.text,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,28),LayoutOrder=i,ZIndex=9},{corner(7),make("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)}),make("UISizeConstraint",{MinSize=Vector2.new(58,28),MaxSize=Vector2.new(150,28)})})
		b.Activated:Connect(function()
			local newv=not adState[tier]
			local r=WorkerSettings:InvokeServer({action="setAutoDismiss", tier=tier, enabled=newv})
			if r and r.ok then adState[tier]=r.enabled; adRefresh() end
		end)
		b.Parent=adRow; adBtns[tier]=b
	end
	adRow.Parent=adH
	do local _c=card(adH,60,2); _c.AutomaticSize=Enum.AutomaticSize.Y; _c.Size=UDim2.new(1,0,0,0); _c.Parent=aP end
	task.spawn(function()
		local r=WorkerSettings:InvokeServer({action="getAutoDismiss"})
		if r and r.ok and r.set then for t in pairs(r.set) do adState[t]=true end; adRefresh() end
	end)
	for i,ag in ipairs(AgencyConfig.Agencies) do
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(ag.name,16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
		lbl("Roll $"..fmt(ag.rollCost).."   \u{00B7}   Wkly $"..fmt(ag.weeklyFee).."/worker",13,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=h
		lbl(oddsStr(ag),12,THEME.subtext,nil,UDim2.new(0,0,0,46),UDim2.new(1,-120,0,18)).Parent=h
		local locked = plvl() < ag.unlockLevel
		local btn=pill(locked and ("Lv "..ag.unlockLevel) or "Roll", locked and THEME.subtext or THEME.green, h)
		if not locked then
			btn.Activated:Connect(function()
				local res=HireRemote:InvokeServer(ag.id)
				if res and res.ok and res.results then
					local lines={}
					for _,r in ipairs(res.results) do
						lines[#lines+1]=r.shift..": "..r.name.." ("..r.rarity..")"..(r.finish and (" \u{2605}"..r.finish) or "")..(r.dismissed and " \u{2014} auto-dismissed" or (r.dupe and " \u{2014} trial" or ""))
					end
					resLbl.Text=table.concat(lines,"\n"); resLbl.TextColor3=Color3.fromRGB(120,235,150)
				else
					resLbl.Text=(res and res.msg) or "Roll failed"; resLbl.TextColor3=Color3.fromRGB(235,120,120)
				end
			end)
		end
		card(h,74,i+2).Parent=aP
	end
end
renderAgency()
cur:WaitForChild("Level"):GetPropertyChangedSignal("Value"):Connect(renderAgency)
-- Hiring Agency populate

-- Payments live rebuild =====
do
	local Players=game:GetService("Players"); local plr=Players.LocalPlayer
	local pP=content.Payments
	for _,ch in ipairs(pP:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
	local function row(title,color,order)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(title,15,THEME.text,nil,UDim2.new(),UDim2.new(1,-150,1,0)).Parent=h
		local v=lbl("",16,color,Enum.TextXAlignment.Right,UDim2.new(),UDim2.new(1,0,1,0)); v.Parent=h
		card(h,46,order).Parent=pP
		return v
	end
	local bal=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Cash Balance",14,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=bal
	local balV=lbl("$0",30,THEME.gold,nil,UDim2.new(0,0,0,22),UDim2.new(1,0,0,38)); balV.Parent=bal
	card(bal,76,1).Parent=pP
	local cryptoV2=row("Crypto",THEME.accent,2)
	local wagesV=row("Worker wages (weekly)",THEME.red,3)
	local function refresh()
		balV.Text="$"..fmt(cur.Cash.Value)
		cryptoV2.Text=fmt(cur.Crypto.Value).." \u{25C6}"
		wagesV.Text="-$"..fmt(plr:GetAttribute("WeeklyWages") or 0)
	end
	cur.Cash.Changed:Connect(refresh); cur.Crypto.Changed:Connect(refresh)
	plr:GetAttributeChangedSignal("WeeklyWages"):Connect(refresh)
	plr:GetAttributeChangedSignal("MonthlyUpkeep"):Connect(refresh)
	refresh()
end

-- Trucks live rebuild =====
do
	local RScfg=game:GetService("ReplicatedStorage").Configs
	local TruckConfig=require(RScfg.TruckConfig)
	local Remotes=game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
	local UpgradeRemote=Remotes:WaitForChild("UpgradeTruck")
	local lbFolder=myWarehouse():WaitForChild("LoadBays")
	local tP=content.Trucks
	for _,ch in ipairs(tP:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
	local selectedBay=nil
	local statusH=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	local statusV=lbl("Pick a bay below, then buy its truck \u{2014} put fast trucks on your best contracts.",13,THEME.gold,nil,UDim2.new(),UDim2.new(1,0,1,0)); statusV.TextWrapped=true; statusV.Parent=statusH
	card(statusH,50,1).Parent=tP
	local baySelH=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8},{
		make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Wraps=true,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
	local bayBtns={}
	local function refreshStatus()
		if not selectedBay then return end
		local pad=lbFolder:FindFirstChild(selectedBay)
		local co=pad and pad:GetAttribute("Company") or "?"
		local tr=(pad and pad:GetAttribute("TruckId")) or "Starter"
		local td=TruckConfig.getTruck(tr)
		statusV.Text=co.."   \u{2192}   "..(td and td.display or tr).."  ("..(td and td.capacity or 15).." cap)"
		statusV.TextColor3=THEME.gold
		for name,btn in pairs(bayBtns) do btn.BackgroundColor3=(name==selectedBay) and THEME.accent or THEME.panel end
	end
	-- (re)build the bay picker from the currently-contracted bays. Called on open and again
	-- whenever a bay gains a company (a new contract is signed) so its truck becomes buyable live.
	local function rebuildBays()
		for _,c in ipairs(baySelH:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		bayBtns={}
		local firstActive=nil
		for _,pad in ipairs(lbFolder:GetChildren()) do
			if pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load" and pad:GetAttribute("Company") then
				local nm=pad.Name; firstActive=firstActive or nm
				local b=make("TextButton",{Name=nm,BackgroundColor3=THEME.panel,AutoButtonColor=true,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,36),Text=pad:GetAttribute("Company"),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=THEME.text,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=8},{make("UICorner",{CornerRadius=UDim.new(0,8)}),make("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)}),make("UISizeConstraint",{MinSize=Vector2.new(78,36),MaxSize=Vector2.new(180,36)})})
				b.Activated:Connect(function() selectedBay=nm; refreshStatus() end)
				b.Parent=baySelH; bayBtns[nm]=b
			end
		end
		if not selectedBay or not bayBtns[selectedBay] then selectedBay=firstActive end
		refreshStatus()
	end
	do local bayCard=card(baySelH,52,2); bayCard.AutomaticSize=Enum.AutomaticSize.Y; bayCard.Size=UDim2.new(1,0,0,0); bayCard.Parent=tP end
	rebuildBays()
	-- signing a contract sets a bay pad's Company attribute -> refresh the picker so the new bay
	-- appears and its truck can be bought without reopening the laptop.
	local function watchPad(pad)
		if pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load" then
			pad:GetAttributeChangedSignal("Company"):Connect(rebuildBays)
		end
	end
	for _,pad in ipairs(lbFolder:GetChildren()) do watchPad(pad) end
	lbFolder.ChildAdded:Connect(function(c) watchPad(c); task.defer(rebuildBays) end)
	for i,t in ipairs(TruckConfig.All) do
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(t.display,16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
		lbl("Cap "..t.capacity.."   \u{00B7}   turn "..t.turnaround.."h   \u{00B7}   "..t.tier,13,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=h
		local btn=pill("$"..fmt(t.cost),THEME.green,h)
		btn.Activated:Connect(function()
			if not selectedBay then statusV.Text="Select a bay first."; statusV.TextColor3=THEME.red; return end
			local r=UpgradeRemote:InvokeServer(selectedBay,t.id)
			if r and r.ok then refreshStatus()
			else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
		end)
		card(h,64,i+2).Parent=tP
	end

	-- Golden Hauler (Game Pass truck): assignable free to pass owners; x5 package value
	do
		local gh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Golden Hauler",16,THEME.gold,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=gh
		lbl("Cap 150   \u{00B7}   x5 package value   \u{00B7}   Mythic (Game Pass)",13,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=gh
		local gbtn=pill("",THEME.gold,gh)
		local function updateGold()
			if plr:GetAttribute("OwnsGoldTruck") then gbtn.Text="Assign"; gbtn.BackgroundColor3=THEME.gold
			else gbtn.Text="Get Pass"; gbtn.BackgroundColor3=THEME.subtext end
		end
		updateGold()
		plr:GetAttributeChangedSignal("OwnsGoldTruck"):Connect(updateGold)
		gbtn.Activated:Connect(function()
			if not plr:GetAttribute("OwnsGoldTruck") then statusV.Text="Buy the Golden Hauler in the Store tab first."; statusV.TextColor3=THEME.gold; return end
			if not selectedBay then statusV.Text="Select a bay first."; statusV.TextColor3=THEME.red; return end
			local r=UpgradeRemote:InvokeServer(selectedBay,"GoldenHauler")
			if r and r.ok then refreshStatus()
			else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
		end)
		card(gh,64,#TruckConfig.All+3).Parent=tP
	end
end

-- Contracts live rebuild (roll -> choose company -> choose bay; plus reassign/swap) =====
do
	local ReplicatedStorage=game:GetService("ReplicatedStorage")
	local Workspace=game:GetService("Workspace")
	local RScfg=ReplicatedStorage.Configs
	local ContractRollConfig=require(RScfg.ContractRollConfig)
	local CompanyConfig=require(RScfg.CompanyConfig)
	local BuyRemote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyContract")
	local lbFolder=myWarehouse():WaitForChild("LoadBays")
	local cP=content.Contracts
 local requestBusy=false
 local function request(data)
  if requestBusy then return {ok=false,msg="Please wait for your current request."} end
  requestBusy=true
  local ok,result=pcall(function() return BuyRemote:InvokeServer(data) end)
  requestBusy=false
  return ok and result or {ok=false,msg="Could not connect. Please try again."}
 end
 local baseLabel=lbl
 local function lbl(...)
  local label=baseLabel(...);label.Font=Enum.Font.FredokaOne
  label.TextColor3=Color3.new(1,1,1);label.TextStrokeColor3=Color3.fromRGB(10,15,35);label.TextStrokeTransparency=.15
  return label
 end
 local function card(inner,height,order)
  height=math.max(height,77)
  local frame=make("Frame",{Name="ContractRow"..order,BackgroundTransparency=1,Size=UDim2.new(1,0,0,height),LayoutOrder=order,ZIndex=8})
  make("ImageLabel",{Name="Art",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Fit,Image=art("Hud"),ZIndex=8,Parent=frame})
  inner.Position=UDim2.fromOffset(12,8);inner.Size=UDim2.new(1,-24,1,-16);inner.Parent=frame
  return frame
 end
 local function imageButton(name,asset,text,parent)
  local button=make("ImageButton",{Name=name,Image=art(asset),BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(128,45),ZIndex=10,AutoButtonColor=false,Parent=parent})
  local amount=lbl(text,20,THEME.text,Enum.TextXAlignment.Center,UDim2.fromScale(.31,0),UDim2.fromScale(.67,1));amount.Name="Amount";amount.ZIndex=11;amount.Parent=button
  return button
 end

	local pendingOffer=nil
	local selCompany=nil
	local selTarget=nil
	local selSwap={}
	local message="Spend Crypto on a tender, reveal companies, then place one on the bay you want."
	local messageColor=THEME.subtext

	local function tierColor(t) local d=CompanyConfig.Tiers[t]; return d and d.color or THEME.subtext end
	-- tint a card's border with the contract tier colour (tier accent)
	local function accent(cd, color)
		local st=cd:FindFirstChildOfClass("UIStroke"); if st then st.Color=color; st.Thickness=2 end
	end
	local function bayLabel(n) return (n or ""):gsub("LoadBay","Bay ") end
	local function readBays()
		local list={}
		for _,pad in ipairs(lbFolder:GetChildren()) do
			if pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load" then
				list[#list+1]={name=pad.Name, company=pad:GetAttribute("Company"), tier=pad:GetAttribute("Tier")}
			end
		end
		table.sort(list,function(a,b) return a.name<b.name end)
		return list
	end

	local render
	local function setMsg(t,c) message=t; messageColor=c or THEME.subtext; render() end

	function render()
		for _,ch in ipairs(cP:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
		local order=0
		local function ord() order+=1; return order end

		local resH=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		local rl=lbl(message,13,messageColor,nil,UDim2.new(),UDim2.new(1,0,1,0)); rl.TextWrapped=true; rl.Parent=resH
		card(resH,56,ord()).Parent=cP

		local bays=readBays()

		if pendingOffer then
			local locked={}
			for _,b in ipairs(bays) do if not b.company then locked[#locked+1]=b.name end end
			if not selTarget or not table.find(locked,selTarget) then selTarget=locked[1] end

			local hdr=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl("Tender ["..pendingOffer.tier.."] \u{2014} choose a company:",13,THEME.text,nil,UDim2.new(),UDim2.new(1,0,1,0)).Parent=hdr
			card(hdr,28,ord()).Parent=cP

			for _,c in ipairs(pendingOffer.candidates) do
				local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
				local sel=(selCompany==c.name)
				lbl(c.name,16,sel and THEME.green or THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
				lbl(c.tier.."   \u{00B7}   base $"..c.base.Small.." / $"..c.base.Medium.." / $"..c.base.Large.." (S/M/L)",12,tierColor(c.tier),nil,UDim2.new(0,0,0,24),UDim2.new(1,-120,0,18)).Parent=h
				local b=pill(sel and "Selected \u{2713}" or "Select", sel and THEME.green or THEME.accent, h)
				b.Activated:Connect(function() selCompany=c.name; render() end)
				local cd=card(h,60,ord()); cd.Parent=cP; accent(cd, tierColor(c.tier))
			end

			local th=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8})
			lbl("Open which bay?",13,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=th
			local grid=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,22),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8},{make("UIGridLayout",{CellSize=UDim2.fromOffset(96,34),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder})})
			for _,nm in ipairs(locked) do
				local b=make("TextButton",{Name=nm,BackgroundColor3=(selTarget==nm) and THEME.accent or THEME.panel2,AutoButtonColor=true,Text=bayLabel(nm),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=THEME.text,ZIndex=9},{corner(8)})
				b.Activated:Connect(function() selTarget=nm; render() end)
				b.Parent=grid
			end
			grid.Parent=th
			do th.AutomaticSize=Enum.AutomaticSize.None;local _c=card(th,38+math.ceil(#locked/6)*42,ord());_c.Parent=cP end

			local ch=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl((selCompany and selTarget) and ("Sign "..selCompany.." \u{2192} "..bayLabel(selTarget)) or "Pick a company and a bay",14,THEME.text,nil,UDim2.new(),UDim2.new(1,-130,1,0)).Parent=ch
			local cb=pill("Sign",(selCompany and selTarget) and THEME.green or THEME.subtext,ch)
			cb.Activated:Connect(function()
				if not(selCompany and selTarget) then setMsg("Pick a company and a bay first.",THEME.red); return end
				local r=request({action="confirm",company=selCompany,bay=selTarget})
				if r and r.ok then
					pendingOffer=nil; selCompany=nil; selTarget=nil
					task.wait(0.15); setMsg("Signed "..r.company.." \u{2192} "..bayLabel(r.bay).."!",THEME.green)
				else setMsg((r and r.msg) or "Failed",THEME.red) end
			end)
			card(ch,48,ord()).Parent=cP
		else

   local tenderArt={"Standard","Premium","Elite"}
   for _,roll in ContractRollConfig.Rolls do
    local row=make("Frame",{Name=tenderArt[roll.id].."Tender",BackgroundTransparency=1,Size=UDim2.new(1,0,0,77),LayoutOrder=ord(),ZIndex=8,Parent=cP})
    make("ImageLabel",{Name="Art",BackgroundTransparency=1,Image=art(tenderArt[roll.id]),Size=UDim2.fromScale(1,1),ZIndex=8,Parent=row})
    local btn=imageButton("BuyTender"..roll.id,"Purchase",fmt(roll.cryptoCost),row)
    btn.Position=UDim2.new(1,-72,.5,0)
    btn.Activated:Connect(function()
     local r=request({action="roll",rollId=roll.id})
     if r and r.ok then
      pendingOffer={tier=r.tier,candidates=r.candidates};selCompany=nil;selTarget=nil
      cP.CanvasPosition=Vector2.zero
      setMsg("Tender opened ("..r.tier..") — choose a company and a bay.",THEME.green)
     else setMsg((r and r.msg) or "Roll failed",THEME.red) end
    end)
   end

		end

		local active={}
		for _,b in ipairs(bays) do if b.company then active[#active+1]=b end end

		-- Your contracts: drop one to free its bay for a new tender (works with a single contract too)
		if #active>=1 then
			local dh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl("Your contracts \u{2014} drop one to free its bay for a new tender:",12,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=dh
			card(dh,28,ord()).Parent=cP
			for _,b in ipairs(active) do
				local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
				lbl(b.company,15,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
				lbl((b.tier or "").."   \u{00B7}   "..bayLabel(b.name),12,tierColor(b.tier or ""),nil,UDim2.new(0,0,0,22),UDim2.new(1,-120,0,16)).Parent=h
				local db=imageButton("DropContract","Trash","Drop",h)
				db.Activated:Connect(function()
					local r=request({action="clear",bay=b.name})
					if r and r.ok then task.wait(0.1)
						local extra=(r.cleared and r.cleared>0) and (" Cleared "..r.cleared.." parcel"..(r.cleared==1 and "" or "s")..".") or ""
						setMsg("Dropped "..r.company.." \u{2014} "..bayLabel(r.bay).." is open for a new tender."..extra,THEME.green)
					else setMsg((r and r.msg) or "Couldn't drop contract",THEME.red) end
				end)
				local cd=card(h,52,ord()); cd.Parent=cP; accent(cd, tierColor(b.tier or ""))
			end
		end

		if #active>=2 then
			local sh=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8})
			lbl("Reassign \u{2014} swap two bays' companies (trucks stay, so you can re-pair a company with a better truck):",12,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,34)).Parent=sh
			local grid=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,38),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=8},{make("UIGridLayout",{CellSize=UDim2.fromOffset(150,38),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder})})
			for _,b in ipairs(active) do
				local selected=(selSwap[1]==b.name or selSwap[2]==b.name)
				local btn=make("TextButton",{Name=b.name,BackgroundColor3=selected and THEME.accent or THEME.panel2,AutoButtonColor=true,Text=(b.company or "?").."\n("..bayLabel(b.name)..")",Font=Enum.Font.GothamBold,TextSize=11,TextScaled=true,TextWrapped=true,TextColor3=THEME.text,ZIndex=9},{corner(8),make("UITextSizeConstraint",{MaxTextSize=11,MinTextSize=7}),make("UIPadding",{PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4)})})
				btn.Activated:Connect(function()
					if selSwap[1]==b.name then selSwap[1]=selSwap[2]; selSwap[2]=nil
					elseif selSwap[2]==b.name then selSwap[2]=nil
					elseif not selSwap[1] then selSwap[1]=b.name
					elseif not selSwap[2] then selSwap[2]=b.name
					else selSwap[1]=selSwap[2]; selSwap[2]=b.name end
					render()
				end)
				btn.Parent=grid
			end
			grid.Parent=sh
			do sh.AutomaticSize=Enum.AutomaticSize.None;local _c=card(sh,54+math.ceil(#active/4)*46,ord());_c.Parent=cP end

			local ch=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl((selSwap[1] and selSwap[2]) and ("Swap "..bayLabel(selSwap[1]).." \u{2194} "..bayLabel(selSwap[2])) or "Select two bays above",14,THEME.text,nil,UDim2.new(),UDim2.new(1,-130,1,0)).Parent=ch
			local sb=pill("Swap",(selSwap[1] and selSwap[2]) and THEME.gold or THEME.subtext,ch)
			sb.Activated:Connect(function()
				if not(selSwap[1] and selSwap[2]) then setMsg("Select two bays to swap.",THEME.red); return end
				local r=request({action="swap",bayA=selSwap[1],bayB=selSwap[2]})
				if r and r.ok then selSwap={}; task.wait(0.15); setMsg(r.msg or "Swapped.",THEME.green)
				else setMsg((r and r.msg) or "Swap failed",THEME.red) end
			end)
			card(ch,48,ord()).Parent=cP
		end
	end

	task.spawn(function()
		local r=request({action="pending"})
		if r and r.ok and r.pending then pendingOffer={tier=r.pending.tier,candidates=r.pending.candidates} end
		render()
	end)
end

-- Exchange options =====
do
	local Remotes=game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
	local SelfEx=Remotes:WaitForChild("SelfExchange"); local FindInv=Remotes:WaitForChild("FindInvestor")
	local pP=content.Payments
	local exH=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Get Crypto",16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,20)).Parent=exH
	local exInfo=lbl("Self-exchange at 3,000:1, or find a street investor (1/day).",12,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,0,0,18)); exInfo.TextWrapped=true; exInfo.Parent=exH
	card(exH,54,5).Parent=pP
	local function exRow(amt,order)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Buy "..amt.." \u{25C6}   ($"..fmt(amt*3000)..")",15,THEME.text,nil,UDim2.new(),UDim2.new(1,-130,1,0)).Parent=h
		local b=pill("Exchange",THEME.accent,h)
		b.Activated:Connect(function()
			local r=SelfEx:InvokeServer(amt)
			if r and r.ok then exInfo.Text="Exchanged "..amt.." \u{25C6} for $"..fmt(r.cost); exInfo.TextColor3=Color3.fromRGB(120,235,150)
			else exInfo.Text=(r and r.msg) or "Failed"; exInfo.TextColor3=Color3.fromRGB(235,120,120) end
		end)
		card(h,46,order).Parent=pP
	end
	exRow(1,6); exRow(10,7)
	local fh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Find a street investor  (1 / day)",15,THEME.text,nil,UDim2.new(),UDim2.new(1,-130,1,0)).Parent=fh
	local fb=pill("Search",THEME.gold,fh)
	fb.Activated:Connect(function()
		local r=FindInv:InvokeServer()
		if r and not r.ok then exInfo.Text=r.msg; exInfo.TextColor3=Color3.fromRGB(235,120,120) end
	end)
	card(fh,46,8).Parent=pP
	-- Summon Investor (Robux dev product): 25% Cash -> Crypto at 600:1, once per in-game day
	local MS=game:GetService("MarketplaceService")
	local PConfig=require(game:GetService("ReplicatedStorage").Configs.ProductConfig)
	local invP=PConfig.byKey("force_investor")
	if invP then
		local ih=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Summon Investor",15,THEME.gold,nil,UDim2.new(0,0,0,0),UDim2.new(1,-130,0,18)).Parent=ih
		lbl("25% Cash \u{2192} Crypto at 600:1 \u{00B7} once per in-game day",12,THEME.subtext,nil,UDim2.new(0,0,0,22),UDim2.new(1,-130,0,16)).Parent=ih
		local b=pill("",THEME.gold,ih)
		local GameTime=game:GetService("ReplicatedStorage"):FindFirstChild("GameTime")
		local function usedToday()
			local d=GameTime and GameTime:GetAttribute("Day")
			return d~=nil and plr:GetAttribute("InvestorSummonDay")==d
		end
		local function updInv()
			local hasId=(invP.productId or 0)>0
			if not hasId then b.Text="Soon"; b.BackgroundColor3=THEME.subtext
			elseif usedToday() then b.Text="Used today"; b.BackgroundColor3=THEME.subtext
			else b.Text="R$ "..invP.robux; b.BackgroundColor3=THEME.gold end
		end
		b.Activated:Connect(function()
			if (invP.productId or 0)>0 and not usedToday() then MS:PromptProductPurchase(plr, invP.productId) end
		end)
		updInv()
		plr:GetAttributeChangedSignal("InvestorSummonDay"):Connect(updInv)
		task.spawn(function()
			local gt=game:GetService("ReplicatedStorage"):WaitForChild("GameTime", 15)
			if gt then GameTime=gt; gt:GetAttributeChangedSignal("Day"):Connect(updInv); updInv() end
		end)
		card(ih,58,9).Parent=pP
	end
end

-- ===== Robux Store =====
do
	local MarketplaceService=game:GetService("MarketplaceService")
	local ProductConfig=require(game:GetService("ReplicatedStorage").Configs.ProductConfig)
	local StoreRemote=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Store")
	local sPage=content.Store
	local empName, empShift = "", "Morning"
	local order=0
	local function ord() order+=1; return order end

	local function header(text)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,26),LayoutOrder=ord(),ZIndex=8})
		lbl(text,15,THEME.gold,nil,UDim2.new(0,2,0,4),UDim2.new(1,0,0,20)).Parent=h
		h.Parent=sPage
	end
	local function priced(name,blurb,priceText,color,onClick,enabled,iconId)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		local off=0
		if iconId then make("ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://"..iconId,Size=UDim2.fromOffset(46,46),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),ZIndex=9}).Parent=h; off=56 end
		lbl(name,16,THEME.text,nil,UDim2.new(0,off,0,0),UDim2.new(1,-120-off,0,20)).Parent=h
		lbl(blurb,12,THEME.subtext,nil,UDim2.new(0,off,0,24),UDim2.new(1,-120-off,0,28)).Parent=h
		local b=pill(priceText, enabled and color or THEME.subtext, h)
		if enabled and onClick then b.Activated:Connect(onClick) end
		card(h,66,ord()).Parent=sPage
		return b
	end

	local function render()
		for _,ch in ipairs(sPage:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
		order=0
		local ih=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Power up your warehouse \u{2014} these purchases use Robux.",13,THEME.subtext,nil,UDim2.new(),UDim2.new(1,0,1,0)).Parent=ih
		card(ih,38,ord()).Parent=sPage

		header("Cash")
		for _,p in ipairs(ProductConfig.Products) do if p.kind=="cash" then
			local en=(p.productId or 0)>0
			priced(p.name,p.blurb, en and ("R$ "..p.robux) or "Soon", THEME.green,
				function() MarketplaceService:PromptProductPurchase(plr, p.productId) end, en)
		end end

		header("Crypto")
		for _,p in ipairs(ProductConfig.Products) do if p.kind=="crypto" then
			local en=(p.productId or 0)>0
			priced(p.name,p.blurb, en and ("R$ "..p.robux) or "Soon", THEME.accent,
				function() MarketplaceService:PromptProductPurchase(plr, p.productId) end, en)
		end end

		header("Boosts & Events")
		local wcfg=game:GetService("ReplicatedStorage"):FindFirstChild("Weather")
		local weatherActive=(wcfg and wcfg:GetAttribute("Active")==true)
		local truckActive=game:GetService("Workspace"):FindFirstChild("SpecialGifts")~=nil
		for _,p in ipairs(ProductConfig.Products) do
			if p.kind=="xpboost" or p.kind=="cashboost" or p.kind=="forceweather" or p.kind=="forcetruck" or p.kind=="instantload" then
				local hasId=(p.productId or 0)>0
				local blocked=(p.kind=="forceweather" and weatherActive) or (p.kind=="forcetruck" and truckActive)
				local txt=(not hasId and "Soon") or (blocked and "Active") or ("R$ "..p.robux)
				priced(p.name,p.blurb, txt, THEME.gold,
					function() MarketplaceService:PromptProductPurchase(plr, p.productId) end, hasId and not blocked, (p.kind=="forcetruck" and "134959391708949") or (p.kind=="instantload" and "101695502300261") or nil)
			end
		end

		header("Game Passes")
		for _,p in ipairs(ProductConfig.Passes) do
			local id=p.gamePassId or 0
			local owned=false
			if p.kind=="luck" then owned=(plr:GetAttribute("LuckMult") or 1)>=(p.mult or 1)
			elseif p.kind=="cashmult" then owned=(plr:GetAttribute("CashMult") or 1)>=(p.mult or 1)
			elseif p.kind=="truck" then owned=plr:GetAttribute("OwnsGoldTruck")==true
			elseif p.kind=="slots" then owned=plr:GetAttribute("Owns_"..p.key)==true end
			local txt=(id<=0 and "Soon") or (owned and "Owned") or ("R$ "..p.robux)
			local en=(id>0) and (not owned)
			priced(p.name,p.blurb, txt, p.kind=="truck" and THEME.gold or THEME.accent,
				function() MarketplaceService:PromptGamePassPurchase(plr, id) end, en)
		end

		header("Exceptional Worker")
		local emp; for _,p in ipairs(ProductConfig.Products) do if p.kind=="employee" then emp=p end end
		if emp then
			local owned=plr:GetAttribute("ExceptionalOwned") or 0
			local maxOwned=emp.maxOwned or 6
			local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl(emp.name.."   ("..owned.."/"..maxOwned..")",16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,20)).Parent=h
			lbl(emp.blurb,12,THEME.subtext,nil,UDim2.new(0,0,0,22),UDim2.new(1,0,0,30)).Parent=h
			local box=make("TextBox",{PlaceholderText="Name your worker...",Text=empName,ClearTextOnFocus=false,BackgroundColor3=THEME.slot,Size=UDim2.new(1,-12,0,30),Position=UDim2.new(0,0,0,56),Font=Enum.Font.GothamBold,TextSize=14,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=9},{corner(8),stroke(THEME.stroke,1),make("UIPadding",{PaddingLeft=UDim.new(0,10)})})
			box:GetPropertyChangedSignal("Text"):Connect(function() empName=box.Text:sub(1,18) end)
			box.Parent=h
			local shiftRow=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,92),Size=UDim2.new(1,0,0,34),ZIndex=9},{make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8)})})
			local shiftBtns={}
			for _,sh in ipairs({"Morning","Afternoon","Night"}) do
				local sbn=make("TextButton",{Name=sh,BackgroundColor3=(empShift==sh) and THEME.accent or THEME.panel2,AutoButtonColor=true,Text=sh,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=THEME.text,Size=UDim2.fromOffset(98,32),ZIndex=9},{corner(8)})
				sbn.Activated:Connect(function() empShift=sh; for n2,b2 in pairs(shiftBtns) do b2.BackgroundColor3=(n2==sh) and THEME.accent or THEME.panel2 end end)
				sbn.Parent=shiftRow; shiftBtns[sh]=sbn
			end
			shiftRow.Parent=h
			local atCap=owned>=maxOwned
			local en=((emp.productId or 0)>0) and not atCap
			local bb=pill(atCap and ("Max "..maxOwned) or (((emp.productId or 0)>0) and ("R$ "..emp.robux) or "Soon"), en and THEME.gold or THEME.subtext, h)
			bb.AnchorPoint=Vector2.new(1,1); bb.Position=UDim2.new(1,0,1,0)
			if en then
				bb.Activated:Connect(function()
					StoreRemote:InvokeServer({action="setEmployee", name=empName, shift=empShift})
					MarketplaceService:PromptProductPurchase(plr, emp.productId)
				end)
			end
			card(h,150,ord()).Parent=sPage
		end
	end

	render()
	for _,attr in ipairs({"LuckMult","CashMult","OwnsGoldTruck","ExceptionalOwned","Owns_slots_1","Owns_slots_3"}) do
		plr:GetAttributeChangedSignal(attr):Connect(render)
	end
	-- re-render the Boosts & Events gating when a weather event / gift-truck starts or ends
	task.spawn(function()
		local w=game:GetService("ReplicatedStorage"):WaitForChild("Weather", 20)
		if w then w:GetAttributeChangedSignal("Active"):Connect(render) end
	end)
	game:GetService("Workspace").ChildAdded:Connect(function(c) if c.Name=="SpecialGifts" then render() end end)
	game:GetService("Workspace").ChildRemoved:Connect(function(c) if c.Name=="SpecialGifts" then render() end end)
end

-- ===== Warehouse Customisation (wall/roof/office colours) =====
do
	local CustomiseRemote=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Customise")
	local cuPage=content.Customise
	local COST=5000
	local PALETTE={
		Color3.fromRGB(228,236,231), Color3.fromRGB(235,90,90), Color3.fromRGB(245,180,70),
		Color3.fromRGB(90,205,120), Color3.fromRGB(70,130,240), Color3.fromRGB(170,90,235),
		Color3.fromRGB(60,64,76), Color3.fromRGB(120,82,48),
		Color3.fromRGB(255,105,180), Color3.fromRGB(255,190,215), Color3.fromRGB(255,215,190),
		Color3.fromRGB(255,245,180), Color3.fromRGB(190,240,200), Color3.fromRGB(185,225,255),
		Color3.fromRGB(210,190,255), Color3.fromRGB(255,255,255),
	}
	local SURFACES={{group="Wall",name="Warehouse Walls"},{group="Roof",name="Roof"},{group="OfficeWall",name="Office Walls"},
		{group="Pillar",name="Pillars"},{group="Trim",name="Trims & Frames"},{group="Neon",name="Neon Lighting"}}
	local order=0; local function ord() order+=1; return order end
	local ih=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Recolour your warehouse \u{2014} $"..fmt(COST).." Cash per change. Upgrade your desk laptop & office chair below.",13,THEME.subtext,nil,UDim2.new(),UDim2.new(1,0,1,0)).Parent=ih
	card(ih,42,ord()).Parent=cuPage
	local statusH=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	local statusV=lbl("Pick a colour to apply.",13,THEME.gold,nil,UDim2.new(),UDim2.new(1,0,1,0)); statusV.Parent=statusH
	card(statusH,36,ord()).Parent=cuPage
	-- warehouse name (free)
	local nh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Warehouse Name",14,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=nh
	local nameBox=make("TextBox",{PlaceholderText="Name your warehouse...",Text="",ClearTextOnFocus=false,BackgroundColor3=THEME.slot,Size=UDim2.new(1,-112,0,32),Position=UDim2.new(0,0,0,24),Font=Enum.Font.GothamBold,TextSize=14,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=9},{corner(8),stroke(THEME.stroke,1),make("UIPadding",{PaddingLeft=UDim.new(0,10)})})
	nameBox.Parent=nh
	local setBtn=make("TextButton",{Text="Set Name",BackgroundColor3=THEME.green,AutoButtonColor=true,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,24),Size=UDim2.fromOffset(102,32),ZIndex=9},{corner(8)})
	setBtn.Activated:Connect(function()
		local r=CustomiseRemote:InvokeServer({action="setName", name=nameBox.Text})
		if r and r.ok then statusV.Text="Warehouse named: "..r.name; statusV.TextColor3=THEME.green; nameBox.Text=""
		else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
	end)
	setBtn.Parent=nh
	card(nh,66,ord()).Parent=cuPage
	-- access permissions: who can visit your warehouse
	local ah=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Who can visit your warehouse?",14,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=ah
	local accRow=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,26),Size=UDim2.new(1,0,0,34),ZIndex=8},{
		make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
	local accBtns={}
	local function setAccessHL(mode) for m,b in pairs(accBtns) do b.BackgroundColor3=(m==mode) and THEME.accent or THEME.panel2 end end
	for i,mode in ipairs({"Open","Friends","Closed"}) do
		local b=make("TextButton",{Name=mode,BackgroundColor3=THEME.panel2,AutoButtonColor=true,Text=mode,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=THEME.text,Size=UDim2.fromOffset(110,32),LayoutOrder=i,ZIndex=9},{corner(8)})
		b.Activated:Connect(function()
			local r=CustomiseRemote:InvokeServer({action="setAccess", mode=mode})
			if r and r.ok then setAccessHL(r.mode); statusV.Text="Access set to "..r.mode; statusV.TextColor3=THEME.green
			else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
		end)
		b.Parent=accRow; accBtns[mode]=b
	end
	accRow.Parent=ah
	card(ah,72,ord()).Parent=cuPage
	task.spawn(function() local r=CustomiseRemote:InvokeServer({action="getAccess"}); if r and r.ok then setAccessHL(r.mode) end end)
	-- black market: carry more special gifts (used during the gift-truck event)
	local ch2=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
	lbl("Black Market \u{2014} carry more special gifts",14,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,-120,0,18)).Parent=ch2
	local carryLbl=lbl("Carry: 1 / 5",12,THEME.subtext,nil,UDim2.new(0,0,0,22),UDim2.new(1,-120,0,16)); carryLbl.Parent=ch2
	local carryBtn=pill("Upgrade",THEME.accent,ch2)
	local function refreshCarry()
		local r=CustomiseRemote:InvokeServer({action="getCarry"})
		if r and r.ok then carryLbl.Text="Carry: "..r.carry.." / 5"; if r.carry>=5 then carryBtn.Text="Maxed" end end
	end
	carryBtn.Activated:Connect(function()
		local r=CustomiseRemote:InvokeServer({action="buyCarry"})
		if r and r.ok then statusV.Text="Carry upgraded to "..r.carry.." (-"..r.cost.." Crypto)"; statusV.TextColor3=THEME.green; refreshCarry()
		else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
	end)
	card(ch2,60,ord()).Parent=cuPage
	task.spawn(refreshCarry)
	-- ===== Office furniture: desk laptop + office chair (upgrade in order, then swap freely) =====
	local FurnitureRemote=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Furniture")
	local PRICE_TXT={[2]="$50k",[3]="$100k"}
	local function furnitureCard(kind, title)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(title,16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,20)).Parent=h
		lbl("Tier 1 free. Buy 2/3 in order, then click an owned tier to display it.",12,THEME.subtext,nil,UDim2.new(0,0,0,22),UDim2.new(1,0,0,16)).Parent=h
		local row=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,44),Size=UDim2.new(1,0,0,40),ZIndex=8},{make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
		local btns={}
		for tier=1,3 do
			local b=make("TextButton",{Name="T"..tier,BackgroundColor3=THEME.panel2,AutoButtonColor=true,Text="Tier "..tier,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=THEME.text,Size=UDim2.fromOffset(132,38),LayoutOrder=tier,ZIndex=9},{corner(8)})
			b.Parent=row; btns[tier]=b
		end
		row.Parent=h
		local function refresh()
			local r=FurnitureRemote:InvokeServer({action="get"})
			if not (r and r.owned and r.sel) then return end
			local ownedT=r.owned[kind] or 1; local selT=r.sel[kind] or 1
			for tier=1,3 do
				local b=btns[tier]
				if tier<=ownedT then
					if tier==selT then b.BackgroundColor3=THEME.accent; b.Text="Tier "..tier.."  \u{2713}"; b.TextColor3=Color3.new(1,1,1)
					else b.BackgroundColor3=THEME.panel2; b.Text="Tier "..tier; b.TextColor3=THEME.text end
				elseif tier==ownedT+1 then b.BackgroundColor3=THEME.gold; b.Text="Tier "..tier.."  "..(PRICE_TXT[tier] or ""); b.TextColor3=Color3.new(0.1,0.1,0.1)
				else b.BackgroundColor3=THEME.slot; b.Text="Tier "..tier.."  \u{1F512}"; b.TextColor3=THEME.subtext end
			end
		end
		for tier=1,3 do
			btns[tier].Activated:Connect(function()
				local r=FurnitureRemote:InvokeServer({action="get"}); if not r then return end
				local ownedT=r.owned[kind] or 1
				if tier<=ownedT then
					local rr=FurnitureRemote:InvokeServer({action="select", kind=kind, tier=tier})
					if rr and rr.ok then statusV.Text=title.." set to Tier "..tier; statusV.TextColor3=THEME.green; refresh()
					else statusV.Text=(rr and rr.msg) or "Failed"; statusV.TextColor3=THEME.red end
				elseif tier==ownedT+1 then
					local rr=FurnitureRemote:InvokeServer({action="buy", kind=kind})
					if rr and rr.ok then statusV.Text=title.." Tier "..tier.." unlocked!"; statusV.TextColor3=THEME.green; refresh()
					else statusV.Text=(rr and rr.msg) or "Failed"; statusV.TextColor3=THEME.red end
				else statusV.Text="Buy Tier "..(ownedT+1).." first."; statusV.TextColor3=THEME.red end
			end)
		end
		card(h,96,ord()).Parent=cuPage
		task.spawn(refresh)
	end
	furnitureCard("laptop","Desk Laptop")
	furnitureCard("chair","Office Chair")
	for _,surf in ipairs(SURFACES) do
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(surf.name,16,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,20)).Parent=h
		local sw=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,26),Size=UDim2.new(1,0,0,80),ZIndex=8},{
			make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Wraps=true,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
		for i,col in ipairs(PALETTE) do
			local b=make("TextButton",{Name="Sw"..i,BackgroundColor3=col,AutoButtonColor=true,Text="",Size=UDim2.fromOffset(34,34),LayoutOrder=i,ZIndex=9},{corner(8),stroke(THEME.stroke,1)})
			b.Activated:Connect(function()
				local c=b.BackgroundColor3
				local r=CustomiseRemote:InvokeServer({action="setColor",group=surf.group,r=math.floor(c.R*255),g=math.floor(c.G*255),b=math.floor(c.B*255)})
				if r and r.ok then statusV.Text="Recoloured "..surf.name.."  (-$"..fmt(r.cost)..")"; statusV.TextColor3=THEME.green
				else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
			end)
			b.Parent=sw
		end
		sw.Parent=h
		card(h,120,ord()).Parent=cuPage
	end
end
end)
-- ===== Black Market =====
local _bmOk,_bmErr=pcall(function()
	local BlackMarket=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BlackMarket")
	local BMConfig=require(game:GetService("ReplicatedStorage").Configs.BlackMarketConfig)
	local mPage=content.Market
	local order=0; local function ord() order+=1; return order end
	local statusV; local selectedTarget=nil; local selectedSub="resetTrucks"
	local refresh
	local MARKET_UNLOCK_LEVEL=10
	local function render(ownedSet, targets)
		for _,ch in ipairs(mPage:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
		order=0
		local lvl=(cur:FindFirstChild("Level") and cur.Level.Value) or 0
		if lvl < MARKET_UNLOCK_LEVEL then   -- gated: show a lock card instead of the shop
			local lh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl("\u{1F512}  Black Market locked",18,THEME.gold,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,24)).Parent=lh
			lbl(("Reach Level %d to unlock weapons, potions & sabotages.  You are Level %d."):format(MARKET_UNLOCK_LEVEL, lvl),13,THEME.subtext,nil,UDim2.new(0,0,0,30),UDim2.new(1,0,0,40)).Parent=lh
			card(lh,82,ord()).Parent=mPage
			return
		end
		local ih=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Buy weapons & potions, or sabotage rivals. Most weapons only work during a gift-truck event.",12,THEME.subtext,nil,UDim2.new(),UDim2.new(1,0,1,0)).Parent=ih
		card(ih,40,ord()).Parent=mPage
		local sh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		statusV=lbl("",13,THEME.gold,nil,UDim2.new(),UDim2.new(1,0,1,0)); statusV.Parent=sh
		card(sh,30,ord()).Parent=mPage
		local SUBLABEL={resetTrucks="Reset Trucks", breakPackages="Break Fragiles", unequipShift="Unequip Shift"}
		for _,it in ipairs(BMConfig.Items) do
			local isSab2=(it.key=="sabotage2")
			local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl(it.name,16,THEME.text,nil,UDim2.new(0,0,0,2),UDim2.new(1,-165,0,22)).Parent=h
			local bl=lbl(it.blurb,12,THEME.subtext,nil,UDim2.new(0,0,0,26),UDim2.new(1,-165,0,isSab2 and 50 or 34))
			bl.TextYAlignment=Enum.TextYAlignment.Top; bl.Parent=h
			local tag=(it.currency=="Crypto") and " C" or " $"
			if it.kind=="sabotage" then
				local btn=pill("Use ("..fmt(it.cost)..tag..")",THEME.red,h); btn.Size=UDim2.fromOffset(150,34)
				btn.Activated:Connect(function()
					if not selectedTarget then statusV.Text="Pick a target player below first."; statusV.TextColor3=THEME.red; return end
					local r=BlackMarket:InvokeServer({action="sabotage",key=it.key,target=selectedTarget.id,sub=(isSab2 and selectedSub or nil)})
					statusV.Text=(r and r.ok and ("Done: "..(r.msg or ""))) or (r and r.msg) or "Failed"; statusV.TextColor3=(r and r.ok) and THEME.green or THEME.red
				end)
				if isSab2 then
					local subRow=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,84),Size=UDim2.new(1,0,0,28),ZIndex=8},{make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})})
					local oi=0
					for _,sub in ipairs(it.subs) do
						oi+=1
						local sb=make("TextButton",{Name=sub,LayoutOrder=oi,BackgroundColor3=(selectedSub==sub) and THEME.accent or THEME.panel2,AutoButtonColor=true,Text=SUBLABEL[sub] or sub,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=THEME.text,Size=UDim2.new(1/3,-6,0,26),ZIndex=9},{corner(6)})
						sb.Activated:Connect(function() selectedSub=sub; refresh() end); sb.Parent=subRow
					end
					subRow.Parent=h
				end
				card(h, isSab2 and 132 or 74, ord()).Parent=mPage
			else
				local isOwned=ownedSet and ownedSet[it.key]
				local btn=pill(isOwned and "Owned" or (fmt(it.cost)..tag), isOwned and THEME.subtext or ((it.currency=="Crypto") and THEME.accent or THEME.green), h)
				if not isOwned then btn.Activated:Connect(function()
					local r=BlackMarket:InvokeServer({action="buy",key=it.key})
					if r and r.ok then statusV.Text="Bought "..it.name.."!"; statusV.TextColor3=THEME.green; refresh()
					else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
				end) end
				card(h,74,ord()).Parent=mPage
			end
		end
		local th=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Sabotage target:",13,THEME.text,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,18)).Parent=th
		local grid=make("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,0,0,22),Size=UDim2.new(1,0,0,60),ZIndex=8},{make("UIGridLayout",{CellSize=UDim2.fromOffset(124,30),CellPadding=UDim2.fromOffset(6,6)})})
		if targets and #targets>0 then
			for _,t in ipairs(targets) do
				local tb=make("TextButton",{Name=tostring(t.id),BackgroundColor3=(selectedTarget and selectedTarget.id==t.id) and THEME.accent or THEME.panel2,AutoButtonColor=true,Text=t.name,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=THEME.text,ZIndex=9},{corner(7)})
				tb.Activated:Connect(function() selectedTarget=t; refresh() end); tb.Parent=grid
			end
		else lbl("(no other players online)",12,THEME.subtext,nil,UDim2.new(0,0,0,24),UDim2.new(1,0,0,18)).Parent=th end
		grid.Parent=th
		card(th,90,ord()).Parent=mPage
	end
	function refresh()
		local o=BlackMarket:InvokeServer({action="owned"})
		local t=BlackMarket:InvokeServer({action="targets"})
		render(o and o.owned or {}, t and t.targets or {})
	end
	refresh()
	local lvN=cur:FindFirstChild("Level"); if lvN then lvN.Changed:Connect(function() refresh() end) end  -- re-render when they hit Lv10
	-- re-fetch ownership when a gift-truck event starts/ends (the Magic Carpet is consumed at event end)
	local ws=game:GetService("Workspace")
	ws.ChildAdded:Connect(function(c) if c.Name=="SpecialGifts" then refresh() end end)
	ws.ChildRemoved:Connect(function(c) if c.Name=="SpecialGifts" then task.wait(0.15); refresh() end end)
end)
if not _bmOk then warn("[WarehouseUI] black market build error: "..tostring(_bmErr)) end

-- ===== Security =====  (CCTV / guards / armoury -- level 15, separate from the Black Market)
local _secOk,_secErr=pcall(function()
	local RSx=game:GetService("ReplicatedStorage")
	local Security=RSx:WaitForChild("Remotes"):WaitForChild("Security")
	local SecUpdate=RSx.Remotes:FindFirstChild("SecurityUpdate")
	local SecCfg=require(RSx.Configs.SecurityConfig)
	local sideRef=screen.Main.Sidebar
	-- clone the Market tab button + page so styling matches exactly; swap the icon to a shield
	local secTab=sideRef:FindFirstChild("SecurityTab")
	if not secTab then
		secTab=sideRef.MarketTab:Clone(); secTab.Name="SecurityTab"; secTab.LayoutOrder=9
		local lab=secTab:FindFirstChild("Label"); if lab then lab.Text="Security" end
		local ic=secTab:FindFirstChild("Icon")
		if ic and ic:IsA("ImageLabel") then ic.Image="rbxassetid://123791735820898" end
		secTab.Parent=sideRef
	end
	local secPage=content:FindFirstChild("Security")
	if not secPage then
		secPage=content.Market:Clone(); secPage.Name="Security"
		for _,ch in ipairs(secPage:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
		secPage.Visible=false; secPage.Parent=content
	end

	local order=0; local function ord() order+=1; return order end
	local statusV; local refresh
	local function tagc(c) return (c=="crypto") and " C" or " $" end
	local function buyState(owned, locked, price, currency)
		if owned then return "Owned", THEME.subtext, false end
		if locked then return "Locked", THEME.slot, false end
		return fmt(price)..tagc(currency), (currency=="crypto") and THEME.accent or THEME.green, true
	end
	local function shopCard(title, blurb, pillText, pillColor, buyable, onBuy, height)
		local h=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl(title,16,THEME.text,nil,UDim2.new(0,0,0,2),UDim2.new(1,-150,0,22)).Parent=h
		if blurb then local bl=lbl(blurb,12,THEME.subtext,nil,UDim2.new(0,0,0,26),UDim2.new(1,-150,0,(height or 74)-34)); bl.TextYAlignment=Enum.TextYAlignment.Top; bl.Parent=h end
		local btn=pill(pillText, pillColor, h)
		if buyable and onBuy then btn.Activated:Connect(onBuy) end
		card(h, height or 74, ord()).Parent=secPage
		return h
	end
	local function header(t, iconId)
		local hh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		local off=0
		if iconId then make("ImageLabel",{BackgroundTransparency=1,Image="rbxassetid://"..iconId,Size=UDim2.fromOffset(24,24),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),ZIndex=9}).Parent=hh; off=32 end
		lbl(t,15,THEME.gold,nil,UDim2.new(0,off,0,0),UDim2.new(1,-off,1,0)).Parent=hh
		card(hh,30,ord()).Parent=secPage
	end
	local DESC={
		range1="Widens both cameras' vision range.",
		range2="Widens vision range even further.",
		freeze="Freezes a thief carrying packages for 15s (15s cooldown).",
		firerate="Both guards fire twice per second.",
		vest="Both guards take 50% less damage.",
		bettergun="Both guards' shots deal 20 damage.",
	}

	local function render(s, level)
		for _,ch in ipairs(secPage:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
		order=0
		s=s or {}; s.cctvUp=s.cctvUp or {}; s.guardUp=s.guardUp or {}; s.guns=s.guns or {}
		if level < SecCfg.UnlockLevel then
			local lh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
			lbl("\u{1F512}  Security locked",18,THEME.gold,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,24)).Parent=lh
			lbl(("Reach Level %d to defend your warehouse with CCTV, guards & an armoury.  You are Level %d."):format(SecCfg.UnlockLevel, level),13,THEME.subtext,nil,UDim2.new(0,0,0,30),UDim2.new(1,0,0,40)).Parent=lh
			card(lh,82,ord()).Parent=secPage
			return
		end
		local ih=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		lbl("Defend your warehouse at night. Upgrades apply to all your units. Armoury weapons work at night only.",12,THEME.subtext,nil,UDim2.new(),UDim2.new(1,0,1,0)).Parent=ih
		card(ih,46,ord()).Parent=secPage
		local sh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
		statusV=lbl("",13,THEME.gold,nil,UDim2.new(),UDim2.new(1,0,1,0)); statusV.Parent=sh
		card(sh,26,ord()).Parent=secPage
		local function doBuy(cat,key)
			local r=Security:InvokeServer({action="buy",cat=cat,key=key})
			if r and r.ok then statusV.Text="Purchased!"; statusV.TextColor3=THEME.green; refresh()
			else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
		end

		header("CCTV", "118149015962925")
		if not s.cctv then
			local pt,pc,buy=buyState(false,false,SecCfg.CCTV.unlockPrice,SecCfg.CCTV.unlockCurrency)
			shopCard("CCTV System  (2 cameras)","Mounts 2 scanning cameras on your warehouse wall facing the bays. Detects intruders & alerts you.",pt,pc,buy,function() doBuy("cctv_unlock") end, 80)
		else
			shopCard("CCTV System","Installed and scanning.","Owned",THEME.subtext,false,nil)
			local ncam=s.cameras or 2
			if ncam<SecCfg.CCTV.maxCameras then
				shopCard(("Extra Camera  (%d/%d)"):format(ncam,SecCfg.CCTV.maxCameras),"Adds a camera at the next preset wall slot.",fmt(SecCfg.CCTV.extraCameraPrice)..tagc("cash"),THEME.green,true,function() doBuy("camera") end)
			else
				shopCard(("Cameras  (%d/%d)"):format(ncam,SecCfg.CCTV.maxCameras),"All 5 camera slots filled.","Max",THEME.subtext,false,nil)
			end
			local prev=true
			for _,u in ipairs(SecCfg.CCTV.upgrades) do
				local owned=s.cctvUp[u.key]==true
				local locked=(not owned) and (not prev)
				local pt,pc,buy=buyState(owned,locked,u.price,u.currency)
				shopCard(u.name, DESC[u.key], pt,pc,buy, function() doBuy("cctv",u.key) end)
				prev=owned
			end
		end

		header("\u{1F46E} Guards")
		local gc=s.guards or 0
		local full=gc>=SecCfg.Guards.max
		local gpt = full and ("Max "..SecCfg.Guards.max) or (fmt(SecCfg.Guards.unitPrice).." $")
		shopCard(("Security Guard  (%d/%d)"):format(gc,SecCfg.Guards.max),"Patrols outside at night. Fires back only if attacked or robbed. 150 HP; returns next night if downed.",gpt, full and THEME.subtext or THEME.green, not full, function() doBuy("guard") end, 80)
		if gc>=1 then
			local prev=true
			for _,u in ipairs(SecCfg.Guards.upgrades) do
				local owned=s.guardUp[u.key]==true
				local locked=(not owned) and (not prev)
				local pt,pc,buy=buyState(owned,locked,u.price,u.currency)
				shopCard(u.name, DESC[u.key], pt,pc,buy, function() doBuy("guard_up",u.key) end)
				prev=owned
			end
		end

		header("Armoury  (night only)", "103392291705188")
		local prevG=true
		for _,g in ipairs(SecCfg.Guns) do
			local owned=s.guns[g.key]==true
			local locked=(not owned) and (not prevG)
			local nm=(g.key=="gun1") and (s.gun1Name or g.name) or g.name
			local blurb=(g.fireDelay>=1) and (("%d damage \u{00B7} %ss cooldown"):format(g.damage,g.fireDelay)) or (("%d damage per shot"):format(g.damage))
			local pt,pc,buy=buyState(owned,locked,g.price,g.currency)
			shopCard(nm, blurb, pt,pc,buy, function() doBuy("gun",g.key) end)
			if g.key=="gun1" and owned then
				local rh=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8})
				lbl("Rename Gun 1",12,THEME.subtext,nil,UDim2.new(0,0,0,0),UDim2.new(1,0,0,16)).Parent=rh
				local box=make("TextBox",{Text=nm,PlaceholderText="New name",ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=THEME.text,BackgroundColor3=THEME.slot,Size=UDim2.new(1,-120,0,30),Position=UDim2.new(0,0,0,20),ZIndex=9},{corner(7),make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)})})
				box.Parent=rh
				local sv=make("TextButton",{Text="Save",BackgroundColor3=THEME.accent,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,20),Size=UDim2.fromOffset(108,30),ZIndex=9},{corner(7)})
				sv.Activated:Connect(function()
					local r=Security:InvokeServer({action="rename",name=box.Text})
					if r and r.ok then statusV.Text="Renamed to "..r.name; statusV.TextColor3=THEME.green; refresh()
					else statusV.Text=(r and r.msg) or "Failed"; statusV.TextColor3=THEME.red end
				end)
				sv.Parent=rh
				card(rh,58,ord()).Parent=secPage
			end
			prevG=owned
		end
	end

	function refresh()
		local res=Security:InvokeServer({action="get"})
		local s=res and res.state or {}
		local level=(res and res.level) or ((cur:FindFirstChild("Level") and cur.Level.Value) or 0)
		render(s, level)
	end
	refresh()
	local lvN=cur:FindFirstChild("Level"); if lvN then lvN.Changed:Connect(function() refresh() end) end
	if SecUpdate then SecUpdate.OnClientEvent:Connect(function(s) render(s, (cur:FindFirstChild("Level") and cur.Level.Value) or 0) end) end
end)
if not _secOk then warn("[WarehouseUI] security build error: "..tostring(_secErr)) end

if not _contentOk then warn("[WarehouseUI] laptop content build error (overlays still open): "..tostring(_contentErr)) end


local sidebar=screen.Main.Sidebar
local business=root.BusinessSelection
local tabs={}
for _,name in {"Contracts","Payments","Trucks","Stats","Agency","Store","Customise","Market","Security","Achievements"} do
 tabs[name]=sidebar:WaitForChild(name.."Tab")
end
local function showPage(name)
 screen.Visible=true;business.Visible=false
 content.ContractsSkin.Visible=name=="Contracts"
 for _,page in content:GetChildren() do if page:IsA("ScrollingFrame") then page.Visible=page.Name==name end end
 for key,button in tabs do
  button.Selection.Visible=key==name
  button:SetAttribute("active",key==name)
 end
 gui:SetAttribute("LaptopPage",name)
end
local function showBusinesses()
 screen.Visible=false;business.Visible=true
 gui:SetAttribute("LaptopPage","Businesses")
end
for name,button in tabs do
 button.Activated:Connect(function() showPage(name) end)
 button.MouseEnter:Connect(function() button.Art.ImageColor3=Color3.fromRGB(225,240,255) end)
 button.MouseLeave:Connect(function() button.Art.ImageColor3=Color3.new(1,1,1) end)
end
business.Businesses.Warehouse.Activated:Connect(function() sidebar.CanvasPosition=Vector2.zero;showPage("Contracts") end)
for _,name in {"Car","Jet"} do
 local button=business.Businesses[name]
 button.Activated:Connect(function()
  button.LockedText.Text="COMING SOON"
  local scale=button.Lock:FindFirstChildOfClass("UIScale") or Instance.new("UIScale",button.Lock)
  scale.Scale=1.08;TweenService:Create(scale,TweenInfo.new(.18),{Scale=1}):Play()
 end)
end
screen.Header.Back.Activated:Connect(showBusinesses)
showBusinesses()

lov.ZIndex=20
local scrim=make("TextButton",{Name="Scrim",Text="",AutoButtonColor=false,Modal=true,Active=true,BackgroundColor3=Color3.new(),BackgroundTransparency=.45,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=6,Parent=lov})
local OPEN=UDim2.fromScale(.5,.5)
local CLOSED=UDim2.fromScale(.5,1.6)
local laptopOpen=false
local transition
lov.Visible=false
local function openLaptop()
 if transition then transition:Cancel() end
 showBusinesses()
 laptopOpen=true;root.Position=CLOSED;lov.Visible=true
 transition=TweenService:Create(root,TweenInfo.new(.3,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=OPEN});transition:Play()
end
local function closeLaptop()
 if transition then transition:Cancel() end
 laptopOpen=false
 transition=TweenService:Create(root,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=CLOSED})
 transition.Completed:Once(function(state) if state==Enum.PlaybackState.Completed and not laptopOpen then lov.Visible=false end end)
 transition:Play()
end
gui.LeftBar.WorkersBtn.Activated:Connect(function() wov.Visible=true end)
panel.TitleBar.Close.Activated:Connect(function() wov.Visible=false end)
gui.LaptopBtn.Activated:Connect(function() if laptopOpen then closeLaptop() else openLaptop() end end)
screen.Header.Close.Activated:Connect(closeLaptop)
business.Close.Activated:Connect(closeLaptop)
local function openStore() if not laptopOpen then openLaptop() end;showPage("Store") end
for _,name in {"Cash","Crypto"} do local button=gui.LeftBar[name]:FindFirstChild("Plus");if button then button.Activated:Connect(openStore) end end
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
 if prompt.Name=="OfficeTerminal" and not laptopOpen then openLaptop() end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input,processed)
 if not processed and laptopOpen and input.KeyCode==Enum.KeyCode.Escape then closeLaptop() end
end)

local UIS=game:GetService("UserInputService")
local drag
local function customScroll(scroll,parent,horizontal)
 scroll.ScrollBarThickness=0
 local track=make("Frame",{Name=scroll.Name.."Scroll",BackgroundColor3=Color3.fromRGB(18,29,59),BorderSizePixel=0,ZIndex=24,Parent=parent},{corner(5)})
 if horizontal then track.Position=UDim2.new(0,9,1,-12);track.Size=UDim2.new(1,-18,0,7)
 elseif scroll==sidebar then track.Position=UDim2.fromOffset(192,6);track.Size=UDim2.new(0,6,1,-12)
 else local top=scroll.Name=="Contracts" and 44 or 6;track.Position=UDim2.new(1,-9,0,top);track.Size=UDim2.new(0,7,1,-top-6) end
 local thumb=make("ImageButton",{Name="Thumb",Image="",BackgroundTransparency=1,BackgroundColor3=Color3.fromRGB(102,177,255),BorderSizePixel=0,AutoButtonColor=false,ZIndex=25,Parent=track},{corner(5)})
 local artwork=make("ImageLabel",{Name="Art",Image=art("Scroll"),BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),ZIndex=25,Parent=thumb})
 local function fitArtwork()
  if horizontal then artwork.Size=UDim2.fromScale(1,1);artwork.Rotation=0
  else local scale=root:FindFirstChild("FitScale");local factor=scale and scale.Scale or 1
   artwork.Size=UDim2.fromOffset(thumb.AbsoluteSize.Y/factor,thumb.AbsoluteSize.X/factor);artwork.Rotation=90 end
 end
 thumb:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitArtwork)
 local function geometry()
  local view=horizontal and scroll.AbsoluteWindowSize.X or scroll.AbsoluteWindowSize.Y
  local canvas=horizontal and scroll.AbsoluteCanvasSize.X or scroll.AbsoluteCanvasSize.Y
  local length=horizontal and track.AbsoluteSize.X or track.AbsoluteSize.Y
  local fraction=math.clamp(view/math.max(canvas,1),.08,1)
  return math.max(0,canvas-view),length,fraction
 end
 local function sync()
  local maximum,_,fraction=geometry()
  track.Visible=scroll.Visible and maximum>1
  fitArtwork()
  local progress=maximum>0 and (horizontal and scroll.CanvasPosition.X or scroll.CanvasPosition.Y)/maximum or 0
  if horizontal then thumb.Size=UDim2.fromScale(fraction,1);thumb.Position=UDim2.fromScale(progress*(1-fraction),0)
  else thumb.Size=UDim2.fromScale(1,fraction);thumb.Position=UDim2.fromScale(0,progress*(1-fraction)) end
 end
 local function update(pointer,offset)
  local maximum,length,fraction=geometry();local origin=horizontal and track.AbsolutePosition.X or track.AbsolutePosition.Y
  local value=horizontal and pointer.X or pointer.Y
  local progress=math.clamp((value-origin-offset)/math.max(1,length*(1-fraction)),0,1)
  scroll.CanvasPosition=horizontal and Vector2.new(progress*maximum,0) or Vector2.new(0,progress*maximum)
 end
 thumb.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   local offset=horizontal and input.Position.X-thumb.AbsolutePosition.X or input.Position.Y-thumb.AbsolutePosition.Y
   drag={input=input,update=update,offset=offset}
  end
 end)
 track.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then local _,length,fraction=geometry();update(input.Position,length*fraction/2) end
 end)
 for _,property in {"CanvasPosition","AbsoluteCanvasSize","AbsoluteWindowSize","Visible"} do scroll:GetPropertyChangedSignal(property):Connect(sync) end
 track:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
 sync()
end
UIS.InputChanged:Connect(function(input)
 if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseMovement) then drag.update(input.Position,drag.offset) end
end)
UIS.InputEnded:Connect(function(input) if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil end end)
customScroll(sidebar,screen.Main,false)
customScroll(business.Businesses,business,true)
for _,page in content:GetChildren() do if page:IsA("ScrollingFrame") then customScroll(page,content,false) end end

-- Local laptop feedback: short, quiet cues and a gloss sweep on focus.
local feedback=Instance.new("Folder");feedback.Name="LaptopFeedback";feedback.Parent=gui
local cueSpecs={
 Hover={"rbxasset://sounds/button.wav",.07,1.7},
 Click={"rbxasset://sounds/button.wav",.16,1.15},
 Tab={"rbxasset://sounds/electronicpingshort.wav",.10,1.6},
 Open={"rbxasset://sounds/electronicpingshort.wav",.12,1.15},
 Close={"rbxasset://sounds/button.wav",.20,.75},
 Back={"rbxasset://sounds/button.wav",.13,.95},
}
local cues={}
for name,spec in cueSpecs do
 local sound=Instance.new("Sound");sound.Name=name;sound.SoundId=spec[1];sound.Volume=spec[2];sound.PlaybackSpeed=spec[3];sound.Parent=feedback;cues[name]=sound
end
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync(feedback:GetChildren()) end) end)
local lastHover=0
local function cue(name)
 if name=="Hover" then if os.clock()-lastHover<.09 then return end;lastHover=os.clock() end
 local sound=cues[name];if sound then sound.TimePosition=0;sound:Play() end
end
local function decorate(button)
 if not button:IsA("GuiButton") or button:GetAttribute("LaptopPolished") then return end
 if button~=gui.LaptopBtn and not button:IsDescendantOf(root) then return end
 if button.Name=="Thumb" then return end
 button:SetAttribute("LaptopPolished",true)
 local scale=Instance.new("UIScale");scale.Name="PressScale";scale.Scale=1;scale.Parent=button
 local pressed=false
 local pressTween
 local function resize(value)
  if pressTween then pressTween:Cancel() end
  pressTween=TweenService:Create(scale,TweenInfo.new(.12,Enum.EasingStyle.Quad),{Scale=value});pressTween:Play()
 end
 local gloss=make("Frame",{Name="Gloss",BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.78,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=math.max(button.ZIndex+3,15),Visible=false,Parent=button},{corner(9)})
 local gradient=Instance.new("UIGradient");gradient.Rotation=20
 gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.40,1),NumberSequenceKeypoint.new(.5,.15),NumberSequenceKeypoint.new(.60,1),NumberSequenceKeypoint.new(1,1)})
 gradient.Offset=Vector2.new(-1,0);gradient.Parent=gloss
 local sweep
 local function shine()
  if sweep then sweep:Cancel() end
  gloss.Visible=true;gradient.Offset=Vector2.new(-1,0)
  sweep=TweenService:Create(gradient,TweenInfo.new(.48,Enum.EasingStyle.Sine),{Offset=Vector2.new(1,0)})
  sweep:Play()
 end
 button.MouseEnter:Connect(function() cue("Hover");shine() end)
 button.SelectionGained:Connect(function() cue("Hover");shine() end)
 button.MouseLeave:Connect(function() pressed=false;resize(1) end)
 button.SelectionLost:Connect(function() pressed=false;resize(1) end)
 button.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then pressed=true;resize(.965) end
 end)
 button.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then pressed=false;resize(1) end
 end)
 button.Activated:Connect(function()
  resize(1);shine()
  local name=button.Name
  if name=="Close" then cue("Close")
  elseif name=="Back" then cue("Back")
  elseif name=="LaptopBtn" then cue(laptopOpen and "Open" or "Close")
  elseif name:sub(-3)=="Tab" or name=="Warehouse" then cue("Tab")
  else cue("Click") end
 end)
end
for _,object in gui:GetDescendants() do decorate(object) end
gui.DescendantAdded:Connect(function(object) if object:IsA("GuiButton") then task.defer(decorate,object) end end)

