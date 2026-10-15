-- TruckService: offload bays (back) run inbound loops; loading bays (front) fill->leave.
-- Packages from inbound are routed to companies the player holds contracts with.
local TweenService=game:GetService("TweenService"); local Players=game:GetService("Players")
local WS=game:GetService("Workspace"); local RS=game:GetService("ReplicatedStorage"); local Lighting=game:GetService("Lighting")
local Debris=game:GetService("Debris")
local PackageService=require(script.Parent.PackageService)
local CurrencyService=require(script.Parent.CurrencyService)
local PlotService=require(script.Parent.PlotService)
local TruckConfig=require(RS.Configs.TruckConfig)
local ProgressionConfig=require(RS.Configs.ProgressionConfig)
local CompanyConfig=require(RS.Configs.CompanyConfig)
local ContractRollConfig=require(RS.Configs.ContractRollConfig)
local WeatherService=require(script.Parent.WeatherService)

local TruckService={}
TruckService.activeTruck=TruckConfig.Default
TruckService.owned={[TruckConfig.Default]=true}
TruckService.pendingOffers={}

local PRODUCTION_HOUR_SECONDS=12
local INBOUND_EVERY_HOURS=3
local PACKAGES_PER_INBOUND=100
local STAGING_CAP=170   -- warehouse holds up to this many staged parcels; inbound pauses at the cap (existing parcels are never removed -- delivery just resumes once the floor drops back under this)
local STARTER=TruckConfig.getTruck(TruckConfig.Default)
local DEFAULT_CAPACITY=STARTER.capacity
local DEFAULT_TURNAROUND=STARTER.turnaround

local function primary() return PlotService.primary() end
local function plotFor(plr) return PlotService.forPlayer(plr) end
local function plotOf(inst) return PlotService.plotOfInstance(inst) or primary() end

local function tweenModel(model,goalCF,t,style)
	local cfv=Instance.new("CFrameValue"); cfv.Value=model:GetPivot()
	local c=cfv.Changed:Connect(function(v) model:PivotTo(v) end)
	local tw=TweenService:Create(cfv,TweenInfo.new(t,style or Enum.EasingStyle.Quad),{Value=goalCF})
	tw:Play(); tw.Completed:Connect(function() c:Disconnect(); cfv:Destroy() end); return tw
end
local function makeTruck(color, name, tier)
	local tm=RS:FindFirstChild("TruckModels")
	local tpl=tm and ((tier and tm:FindFirstChild(tier)) or tm:FindFirstChild("TruckTemplate"))
	if not tpl then
		local m=Instance.new("Model"); local b=Instance.new("Part"); b.Name="Body"; b.Anchored=true
		b.Size=Vector3.new(7,5,13); b.Color=color; b.Parent=m; m.PrimaryPart=b; return m
	end
	local m=tpl:Clone(); m.Name="Truck"
	local custom = m:GetAttribute("CustomLivery")==true   -- generated trucks keep their own livery; don't flat-tint
	local body
	for _,d in ipairs(m:GetDescendants()) do if d:GetAttribute("IsBody") then if not custom then d.Color=color end; body=d end end
	-- (truck name plates removed -- players don't need a "Starter Truck" label on every truck)
	if m.PrimaryPart then
		local bb=Instance.new("BillboardGui"); bb.Name="FillGui"; bb.Size=UDim2.fromOffset(150,30); bb.StudsOffset=Vector3.new(0,4.5,0); bb.AlwaysOnTop=true; bb.Adornee=m.PrimaryPart; bb.Parent=m.PrimaryPart
		local fl=Instance.new("TextLabel"); fl.Name="Fill"; fl.Size=UDim2.fromScale(1,1); fl.BackgroundTransparency=1; fl.Font=Enum.Font.GothamBold; fl.TextScaled=true; fl.TextColor3=Color3.new(1,1,1); fl.TextStrokeTransparency=0.4; fl.Text=""; fl.Parent=bb
	end
	return m
end
local function floatText(parent,pos,text,color)
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.Transparency=1; p.Size=Vector3.one; p.Position=pos; p.Parent=parent
	local bb=Instance.new("BillboardGui"); bb.Size=UDim2.fromOffset(180,60); bb.StudsOffset=Vector3.new(0,2,0); bb.AlwaysOnTop=true; bb.Parent=p
	local tl=Instance.new("TextLabel"); tl.Size=UDim2.fromScale(1,1); tl.BackgroundTransparency=1; tl.Font=Enum.Font.GothamBold
	tl.TextScaled=true; tl.TextColor3=color or Color3.fromRGB(90,235,120); tl.TextStrokeTransparency=0.3; tl.Text=text; tl.Parent=bb
	TweenService:Create(p,TweenInfo.new(1.2),{Position=pos+Vector3.new(0,8,0)}):Play()
	TweenService:Create(tl,TweenInfo.new(1.2),{TextTransparency=1,TextStrokeTransparency=1}):Play()
	Debris:AddItem(p,1.3)
end
local function awardPlot(plot, amount, xp)
	local owner = plot and plot.owner
	if owner ~= nil then
		if owner.Parent then
			CurrencyService.Add(owner, "Cash", amount)
			if xp then CurrencyService.AddXp(owner, xp) end
		end
	else
		for _,plr in ipairs(Players:GetPlayers()) do
			CurrencyService.Add(plr, "Cash", amount)
			if xp then CurrencyService.AddXp(plr, xp) end
		end
	end
end
local function activeCompanies(plot)
	local list={}
	for _,pad in ipairs(plot.LoadBays:GetChildren()) do
		local co=pad:GetAttribute("Company"); if co then table.insert(list,co) end
	end
	return list
end

-- A parcel leaving staging (taken by a worker or player): stop colliding and hide its "Pick Up"
-- prompt so it can't be re-grabbed while carried/loaded.
local function leaveStaging(pkg)
	pkg.CanCollide=false
	local pr=pkg:FindFirstChild("GrabParcel"); if pr then pr.Enabled=false end
end

function TruckService.takeStaged(company, plot)
	local sp=(plot or primary()).stagedPackages
	for i,pkg in ipairs(sp) do
		if pkg.Parent and pkg:GetAttribute("Company")==company then table.remove(sp,i); leaveStaging(pkg); return pkg end
	end
	return nil
end

-- Golden Hauler premium finish: metallic gold body + warm glow + sparkles + crisp gold outline.
-- Applied per-spawn (trucks rebuild each departure) ONLY when the bay runs the Game Pass truck.
local GOLD=Color3.fromRGB(245,193,66)
local function applyGoldenFinish(model)
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("IsBody") then
			d.Material=Enum.Material.Metal; d.Reflectance=0.3; d.Color=GOLD
		end
	end
	local pp=model.PrimaryPart
	if not pp then return end
	local light=Instance.new("PointLight"); light.Name="GoldGlow"; light.Color=GOLD; light.Brightness=1.6; light.Range=20; light.Parent=pp
	local sp=Instance.new("Sparkles"); sp.Name="GoldSparkle"; sp.SparkleColor=GOLD; sp.Parent=pp
	local hl=Instance.new("Highlight"); hl.Name="GoldEdge"; hl.FillTransparency=1
	hl.OutlineColor=Color3.fromRGB(255,224,130); hl.OutlineTransparency=0.15
	hl.DepthMode=Enum.HighlightDepthMode.Occluded; hl.Adornee=model; hl.Parent=model
end

local LoadBay={}; LoadBay.__index=LoadBay
function LoadBay.new(plot,pad)
	local self=setmetatable({},LoadBay)
	self.plot=plot
	self.pad=pad; self.company=pad:GetAttribute("Company")
	self.color=Color3.new(pad:GetAttribute("ColR") or 1, pad:GetAttribute("ColG") or 1, pad:GetAttribute("ColB") or 1)
	self.truckId=pad:GetAttribute("TruckId") or TruckConfig.Default
	self.owned={Starter=true,[self.truckId]=true}
	self.capacity=(TruckConfig.getTruck(self.truckId) or {capacity=DEFAULT_CAPACITY}).capacity
	self.valueMult=(TruckConfig.getTruck(self.truckId) or {}).valueMult or 1
	self.parkCF=CFrame.new(pad.Position+Vector3.new(0,3,6))
	self.leaveCF=self.parkCF+Vector3.new(0,0,110)
	self:spawnTruck(); return self
end
function LoadBay:spawnTruck()
	if self.removed then return end
	self.loaded={}; self.count=0; self.loadedValue=0; self.leaving=false
	self.truckDisplay=(TruckConfig.getTruck(self.truckId) or {}).display
	local nm=self.truckDisplay
	local col=(self.truckId=="GoldenHauler") and Color3.fromRGB(245,193,66) or self.color
	local t=makeTruck(col, nm, (TruckConfig.getTruck(self.truckId) or {}).tier); t.Name="Outbound_"..self.company
	if self.truckId=="GoldenHauler" then applyGoldenFinish(t) end
	t:SetAttribute("LabelOwner", (self.plot.owner and self.plot.owner.UserId) or 0)   -- so other players' truck name labels can be hidden client-side
	t.Parent=self.plot.trucksFolder; self.truck=t
	-- ===== park OUTSIDE the bay: rear (cargo door) to the dock, cab pointing out =====
	-- 'outward' = away from the warehouse interior. Bays look INWARD, so -LookVector points out.
	-- Derived from the pad's own frame so it's correct on every (rotated) plot clone.
	local pad=self.pad
	local lk=pad.CFrame.LookVector
	local outward=Vector3.new(-lk.X,0,-lk.Z); outward=(outward.Magnitude>0.05) and outward.Unit or Vector3.new(0,0,1)
	t:PivotTo(CFrame.new(pad.Position+Vector3.new(0,6,0)))
	-- read the truck's REAR direction from its RearDoor (robust to mixed template orientations)
	local rdoor=t:FindFirstChild("RearDoor", true)
	local c0=t:GetBoundingBox()
	local rearDir = rdoor and (rdoor.Position-c0.Position) or (t:GetPivot().LookVector*-1)
	rearDir=Vector3.new(rearDir.X,0,rearDir.Z); rearDir=(rearDir.Magnitude>0.05) and rearDir.Unit or Vector3.new(0,0,1)
	local camDir=-rearDir
	local yaw=math.atan2(outward.X,outward.Z)-math.atan2(camDir.X,camDir.Z)
	local cen=c0.Position
	t:PivotTo(CFrame.new(cen)*CFrame.Angles(0,yaw,0)*CFrame.new(-cen)*t:GetPivot())   -- aim cab outward, rear to dock
	local c1,sz=t:GetBoundingBox()
	local lenOut=math.abs(sz.X*outward.X)+math.abs(sz.Z*outward.Z)
	local DOCK_OUT=15   -- rear sits this far outward from the bay pad (just past the dock wall)
	local rearPt=pad.Position+outward*DOCK_OUT
	local desired=rearPt+outward*(lenOut/2)
	desired=Vector3.new(desired.X, pad.Position.Y+sz.Y/2+0.1, desired.Z)
	t:PivotTo(t:GetPivot()+(desired-c1.Position))
	self.parkCF=t:GetPivot()
	self.leaveCF=self.parkCF+outward*120
	-- rear roll-up door: opens for loading, closes when full (set in depart())
	local door=t:FindFirstChild("RearDoor", true)
	if door then
		self.door=door; self.doorClosed=door.CFrame
		door.CFrame=door.CFrame*CFrame.new(0, (door:GetAttribute("OpenSlide") or door.Size.Y*0.86), 0)
	else self.door=nil end
	self:updateFill()
end
function LoadBay:updateFill()
	local pp=self.truck and self.truck.PrimaryPart
	local g=pp and pp:FindFirstChild("FillGui")
	if g then g.Fill.Text=self.count.."/"..self.capacity end
end
function LoadBay:slotCF(i)
	local col=i%3; local row=math.floor(i/3)%6; local layer=math.floor(i/18)
	return self.truck:GetPivot()*CFrame.new((col-1)*2.2, 3+layer*1.6, (row-2.5)*1.9 - 1)
end
function LoadBay:load(pkg)
	if self.removed or not self.truck or self.leaving or self.count>=self.capacity then return false end
	pkg.Parent=self.truck; pkg.Transparency=1
	for _,d in ipairs(pkg:GetDescendants()) do
		if d:IsA("Highlight") or d:IsA("SelectionBox") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then d:Destroy()
		elseif d:IsA("BasePart") then d.Transparency=1 end   -- hide the shipping dressing inside the truck too
	end
	self.count+=1; self.loadedValue=(self.loadedValue or 0)+(pkg:GetAttribute("Value") or 0); table.insert(self.loaded,pkg); self:updateFill()
	if self.count>=self.capacity then self:depart() end
	return true
end
function LoadBay:depart()
	self.leaving=true; local truck=self.truck
	local total=self.loadedValue or 0   -- running sum (so a restored partial fill keeps its value)
	total = math.floor(total * (self.valueMult or 1))            -- per-truck value (Golden Hauler = x5)
	local owner = self.plot.owner
	local cashMult = (owner and owner:GetAttribute("CashMult")) or 1   -- x2 Cash game pass
	if owner and (owner:GetAttribute("CashBoostUntil") or 0) > os.time() then cashMult=cashMult*2 end  -- special-gift x2 parcel cash
	local weatherMult = WeatherService.getMultiplier()                 -- daily weather event (x1..x50)
	local payout = math.floor(total * cashMult * weatherMult)
	if owner and owner:GetAttribute("SpikesArmed") then payout=math.floor(payout*0.5); owner:SetAttribute("SpikesArmed", nil) end  -- road-spikes sabotage
	local tier=(TruckConfig.getTruck(self.truckId) or {}).tier
	awardPlot(self.plot, payout, ProgressionConfig.xpForTruck(tier))   -- XP doubles per truck tier
	if owner then CurrencyService.AddDelivery(owner, 1) end   -- lifetime delivery-run counter (Stats UI)
	floatText(self.plot.trucksFolder, truck:GetPivot().Position+Vector3.new(0,6,0),"+$"..payout,Color3.fromRGB(90,235,120))
	-- close the rear door before the truck pulls away
	if self.door and self.doorClosed and self.door.Parent then
		local dt=TweenService:Create(self.door, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {CFrame=self.doorClosed})
		dt:Play(); dt.Completed:Wait()
	end
	local travel=1.5
	tweenModel(truck,self.leaveCF,travel).Completed:Connect(function()
		truck:Destroy()
		task.wait(math.max(0.3, ((TruckConfig.getTruck(self.truckId) or {turnaround=DEFAULT_TURNAROUND}).turnaround)*PRODUCTION_HOUR_SECONDS - travel))
		self:spawnTruck()
	end)
end
-- Drop a bay: stop it respawning a truck and remove its current one (unless mid-departure).
function LoadBay:destroy()
	self.removed=true
	if self.truck and not self.leaving then self.truck:Destroy(); self.truck=nil end
end

local STAGE_COLS=12; local STAGE_ROWS=8; local STAGE_SP=3.0
local function stageSlotCF(plot, slot, pkg)
	local col=slot%STAGE_COLS
	local row=math.floor(slot/STAGE_COLS)%STAGE_ROWS
	local layer=math.floor(slot/(STAGE_COLS*STAGE_ROWS))
	local cf=plot.staging.CFrame*CFrame.new((col-(STAGE_COLS-1)/2)*STAGE_SP, 0, (row-(STAGE_ROWS-1)/2)*STAGE_SP)
	local y=PlotService.floorY(plot)+pkg.Size.Y/2+0.02+layer*2.7
	return cf+Vector3.new(0,y-cf.Position.Y,0)
end
local function isCompanyServed(plot, company)
	for _,pad in ipairs(plot.LoadBays:GetChildren()) do
		if pad:GetAttribute("Company")==company then return true end
	end
	return false
end
local function placeStaged(plot, pkg)
	if not isCompanyServed(plot, pkg:GetAttribute("Company")) then pkg:Destroy(); return false end
	local used={}
	for _,p in ipairs(plot.stagedPackages) do local sl=p:GetAttribute("StageSlot"); if sl then used[sl]=true end end
	local slot=0; while used[slot] do slot+=1 end
	pkg:SetAttribute("StageSlot", slot)
	pkg.Anchored=true; pkg.CanCollide=true
	pkg.CFrame=stageSlotCF(plot, slot, pkg)
	local pr=pkg:FindFirstChild("GrabParcel")
	if pr then pr.ObjectText=tostring(pkg:GetAttribute("Company")); pr.Enabled=true end
	return true
end
local function runOffload(plot, pad)
	local dockCF=CFrame.new(pad.Position+Vector3.new(0,3,-4))
	local startCF=dockCF-Vector3.new(0,0,110)
	while plot.active~=false do
		local comps=activeCompanies(plot)
		local sp=plot.stagedPackages
		if #comps==0 or #sp>=STAGING_CAP then task.wait(2) else
			local truck=makeTruck(Color3.fromRGB(150,155,165)); truck.Name="Inbound"
			truck:PivotTo(startCF); truck.Parent=plot.trucksFolder
			tweenModel(truck,dockCF,2.0).Completed:Wait()
			local nMake=math.min(PACKAGES_PER_INBOUND, math.max(0, STAGING_CAP-#sp))
			local luck=(plot.owner and plot.owner:GetAttribute("LuckMult")) or 1
			for i=1,nMake do
				local company=comps[(plot.inboundCursor % #comps)+1]
				plot.inboundCursor+=1
				local pkg=PackageService.create(company, luck)
				pkg.Parent=plot.trucksFolder
				if placeStaged(plot, pkg) then table.insert(sp,pkg) end
				task.wait(0.05)
			end
			task.wait(0.4)
			tweenModel(truck,startCF,2.0).Completed:Wait(); truck:Destroy()
			task.wait(INBOUND_EVERY_HOURS*PRODUCTION_HOUR_SECONDS)
		end
	end
end
function TruckService.takeNearestStaged(pos, range, plot)
	local sp=(plot or primary()).stagedPackages
	local best,bestd,bi
	for i,pkg in ipairs(sp) do
		if pkg.Parent then local d=(pkg.Position-pos).Magnitude
			if d<=range and (not best or d<bestd) then best=pkg; bestd=d; bi=i end end
	end
	if best then table.remove(sp,bi); leaveStaging(best); return best end
	return nil
end
function TruckService.takeAnyStaged(plot)
	local sp=(plot or primary()).stagedPackages
	for i,pkg in ipairs(sp) do
		if pkg.Parent then table.remove(sp,i); leaveStaging(pkg); return pkg end
	end
	return nil
end
function TruckService.takeSpecificStaged(pkg, plot)
	plot = plot or primary()
	local sp = plot.stagedPackages
	for i,p in ipairs(sp) do
		if p==pkg and p.Parent then table.remove(sp,i); leaveStaging(p); return p end
	end
	return nil
end
-- take a staged parcel of a SPECIFIC company (used by the +carry gamepass so a worker grabs extras for the same bay)
function TruckService.takeCompanyStaged(company, plot)
	plot = plot or primary()
	local sp = plot.stagedPackages
	for i,p in ipairs(sp) do
		if p.Parent and p:GetAttribute("Company")==company then table.remove(sp,i); leaveStaging(p); return p end
	end
	return nil
end
-- Rush Load (dev product / admin): instantly load every staged parcel onto the player's trucks,
-- filling them (and departing any that hit capacity) and clearing that much of the floor.
function TruckService.instantLoadAll(plot)
	plot = plot or primary()
	local loaded=0
	local list={}; for _,p in ipairs(plot.stagedPackages or {}) do list[#list+1]=p end
	for _,pkg in ipairs(list) do
		if pkg and pkg.Parent then
			local bay=TruckService.getLoadBay(pkg:GetAttribute("Company"), plot)
			if bay and not bay.leaving and (bay.count or 0)<(bay.capacity or 0) then
				local taken=TruckService.takeSpecificStaged(pkg, plot)
				if taken and bay:load(taken) then loaded+=1 end
			end
		end
	end
	return loaded
end
function TruckService.takeForBalancedBay(plot)
	plot = plot or primary()
	local order={}
	for _,b in ipairs(plot.loadBays or {}) do
		if b.company and not b.leaving and (b.count or 0) < (b.capacity or 0) then order[#order+1]=b end
	end
	if #order==0 then return nil end
	local function frac(b) return (b.count or 0)/math.max(1,(b.capacity or 1)) end
	table.sort(order, function(a,b) return frac(a) < frac(b) end)
	local target=order[1]
	local pkg=TruckService.takeStaged(target.company, plot)
	if pkg then return pkg end
	pkg=TruckService.takeAnyStaged(plot)
	if pkg then PackageService.reassignCompany(pkg, target.company); return pkg end
	return nil
end
function TruckService.getLoadBay(company, plot)
	for _,bay in ipairs((plot or primary()).loadBays or {}) do
		if bay.company==company then return bay end
	end
	return nil
end
function TruckService.stagedCount() return #primary().stagedPackages end
function TruckService.restage(pkg, plot)
	if not pkg or not pkg.Parent then return end
	plot = plot or primary()
	pkg.Parent = plot.trucksFolder
	if placeStaged(plot, pkg) then table.insert(plot.stagedPackages, pkg) end
end

function TruckService.initPlot(plot)
	plot.trucksFolder=Instance.new("Folder"); plot.trucksFolder.Name="Trucks"; plot.trucksFolder.Parent=plot.wh
	plot.loadBays={}; plot.stagedPackages={}; plot.active=true; plot.inboundCursor=0
	Lighting.ClockTime=14
	for _,pad in ipairs(plot.LoadBays:GetChildren()) do
		if pad:IsA("Part") and pad:GetAttribute("Company") then
			table.insert(plot.loadBays, LoadBay.new(plot, pad))
		end
	end
	local nOff=0
	for _,pad in ipairs(plot.OffloadBays:GetChildren()) do
		if pad:IsA("Part") and pad:GetAttribute("Active") then
			nOff+=1; task.spawn(function() runOffload(plot, pad) end)
		end
	end
	if plot==primary() then TruckService.loadBays=plot.loadBays end
	print(("[TruckService] plot %d: %d loading bay(s), %d offload bay(s) active"):format(plot.id or 0, #plot.loadBays, nOff))
	return plot
end

function TruckService.Start()
	TruckService.initPlot(primary())
end

-- Restore a saved truck fill (count + accumulated value) onto a bay after load.
function TruckService.restoreFill(bay, count, value)
	if not bay then return end
	local cap=bay.capacity or 0
	count=math.clamp(math.floor(count or 0), 0, cap)
	if count<=0 then return end
	bay.count=count; bay.loadedValue=value or 0
	if bay.updateFill then pcall(function() bay:updateFill() end) end
	-- If a bay is restored ALREADY full (e.g. a truck downgraded to a smaller capacity, like the
	-- Golden Hauler's 150), load() can never push it over the line, so it'd sit full forever. Depart it
	-- now so it pays out and cycles a fresh empty truck.
	if cap>0 and bay.count>=cap and bay.truck and not bay.leaving and bay.depart then
		task.defer(function() pcall(function() bay:depart() end) end)
	end
end

function TruckService.buyTruck(plr, bayName, truckId)
	local plot=plotFor(plr)
	local t=TruckConfig.getTruck(truckId); if not t then return {ok=false,msg="Unknown truck"} end
	if truckId=="GoldenHauler" and not plr:GetAttribute("OwnsGoldTruck") then return {ok=false,msg="Requires the Golden Hauler game pass"} end
	local bay; for _,b in ipairs(plot.loadBays or {}) do if b.pad.Name==bayName then bay=b break end end
	if not bay then return {ok=false,msg="Bay not active"} end
	bay.owned=bay.owned or {Starter=true}
	if not bay.owned[truckId] then
		if not CurrencyService.Spend(plr,"Cash",t.cost) then return {ok=false,msg="Not enough Cash"} end
		bay.owned[truckId]=true
	end
	bay.truckId=truckId; bay.pad:SetAttribute("TruckId",truckId); bay.capacity=t.capacity; bay.valueMult=t.valueMult or 1
	if bay.truck and not bay.leaving then bay.truck:Destroy(); bay:spawnTruck() end
	return {ok=true, bay=bayName, truck=t.display, capacity=t.capacity}
end

local function activeCompanySet(plot)
	local set={}
	for _,pad in ipairs(plot.LoadBays:GetChildren()) do local c=pad:GetAttribute("Company"); if c then set[c]=true end end
	return set
end
local function nextLockedBay(plot)
	for _,pad in ipairs(plot.LoadBays:GetChildren()) do
		if pad:IsA("Part") and not pad:GetAttribute("Company") then return pad end
	end
	return nil
end
local function updateBaySign(pad, company)
	local F=plotOf(pad).wh:FindFirstChild("BaySigns"); if not F then return end
	local sign=F:FindFirstChild("BaySign_"..pad.Name); if not sign then return end
	local g=sign:FindFirstChildOfClass("SurfaceGui"); if not g then return end
	local frame=g:FindFirstChildOfClass("Frame"); if not frame then return end
	local color=company and company.color or Color3.fromRGB(120,128,142)
	if frame:FindFirstChild("NameLbl") then frame.NameLbl.Text=company and company.name or "AVAILABLE"; frame.NameLbl.TextColor3=color end
	if frame:FindFirstChild("TierLbl") then frame.TierLbl.Text=company and (company.tier.." Co.") or "Buy a Contract" end
	if frame:FindFirstChild("Stripe") then frame.Stripe.BackgroundColor3=color end
end
function TruckService.activateBay(pad, company)
	local plot=plotOf(pad)
	pad:SetAttribute("Company", company.name); pad:SetAttribute("Tier", company.tier)
	pad:SetAttribute("ColR",company.color.R); pad:SetAttribute("ColG",company.color.G); pad:SetAttribute("ColB",company.color.B)
	pad.Color=company.color; pad.Transparency=0.15
	updateBaySign(pad, company)
	local bay=LoadBay.new(plot, pad)
	table.insert(plot.loadBays, bay)
	return bay
end
local function pickCandidates(plot, tier, count)
	local active=activeCompanySet(plot)
	local pool={}
	for _,c in ipairs(CompanyConfig.ByTier[tier]) do if not active[c.name] then pool[#pool+1]=c end end
	if #pool==0 then for _,c in ipairs(CompanyConfig.ByTier[tier]) do pool[#pool+1]=c end end
	for i=#pool,2,-1 do local j=math.random(i); pool[i],pool[j]=pool[j],pool[i] end
	local out={}
	for i=1,math.min(count,#pool) do out[#out+1]=pool[i] end
	return out
end

local function bayByName(plot, name) for _,b in ipairs(plot.loadBays or {}) do if b.pad.Name==name then return b end end end
local function applyCompany(pad, bay, company)
	pad:SetAttribute("Company", company.name); pad:SetAttribute("Tier", company.tier)
	pad:SetAttribute("ColR",company.color.R); pad:SetAttribute("ColG",company.color.G); pad:SetAttribute("ColB",company.color.B)
	pad.Color=company.color
	updateBaySign(pad, company)
	if bay then
		bay.company=company.name; bay.color=company.color
		if bay.truck then
			bay.truck.Name="Outbound_"..company.name
			for _,d in ipairs(bay.truck:GetDescendants()) do if d:GetAttribute("IsBody") then d.Color=company.color end end
		end
	end
end

function TruckService.getPending(plr) return TruckService.pendingOffers[plr.UserId] end

function TruckService.rollContract(plr, rollId)
	local plot=plotFor(plr)
	local roll=ContractRollConfig.get(rollId); if not roll then return {ok=false,msg="Unknown tender"} end
	if TruckService.pendingOffers[plr.UserId] then return {ok=false,msg="Place your current tender first"} end
	if not nextLockedBay(plot) then return {ok=false,msg="All loading bays in use"} end
	if not CurrencyService.Spend(plr,"Crypto",roll.cryptoCost) then return {ok=false,msg="Not enough Crypto"} end
	local tier=ContractRollConfig.rollTier(rollId)
	local cands=pickCandidates(plot, tier, 3)
	local payload={tier=tier, candidates={}}
	for _,c in ipairs(cands) do
		payload.candidates[#payload.candidates+1]={name=c.name, tier=c.tier, base={Small=c.base.Small, Medium=c.base.Medium, Large=c.base.Large}}
	end
	TruckService.pendingOffers[plr.UserId]=payload
	return {ok=true, tier=tier, candidates=payload.candidates}
end

function TruckService.confirmContract(plr, companyName, bayName)
	local plot=plotFor(plr)
	local pending=TruckService.pendingOffers[plr.UserId]; if not pending then return {ok=false,msg="No tender to place"} end
	local match=false; for _,c in ipairs(pending.candidates) do if c.name==companyName then match=true break end end
	if not match then return {ok=false,msg="That company isn't in your tender"} end
	local pad=plot.LoadBays:FindFirstChild(bayName)
	if not (pad and pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load") then return {ok=false,msg="Bay not found"} end
	if pad:GetAttribute("Company") then return {ok=false,msg="That bay is already in use"} end
	local company=CompanyConfig.get(companyName); if not company then return {ok=false,msg="Unknown company"} end
	pad:SetAttribute("Locked", nil)
	TruckService.activateBay(pad, company)
	TruckService.pendingOffers[plr.UserId]=nil
	return {ok=true, company=company.name, tier=company.tier, bay=bayName}
end

function TruckService.swapBays(plr, aName, bName)
	local plot=plotFor(plr)
	if aName==bName then return {ok=false,msg="Pick two different bays"} end
	local padA=plot.LoadBays:FindFirstChild(aName); local padB=plot.LoadBays:FindFirstChild(bName)
	if not (padA and padB) then return {ok=false,msg="Bay not found"} end
	local coA=padA:GetAttribute("Company"); local coB=padB:GetAttribute("Company")
	if not (coA and coB) then return {ok=false,msg="Both bays must be active"} end
	local companyA=CompanyConfig.get(coA); local companyB=CompanyConfig.get(coB)
	if not (companyA and companyB) then return {ok=false,msg="Unknown company"} end
	applyCompany(padA, bayByName(plot,aName), companyB)
	applyCompany(padB, bayByName(plot,bName), companyA)
	return {ok=true, msg="Swapped "..coA.." \u{2194} "..coB}
end

-- Drop a contract: free its bay so the player can roll & place a new one. Keeps any upgraded truck.
function TruckService.clearBay(plr, bayName)
	local plot=plotFor(plr)
	local pad=plot.LoadBays:FindFirstChild(bayName)
	if not (pad and pad:IsA("BasePart") and pad:GetAttribute("Kind")=="Load") then return {ok=false,msg="Bay not found"} end
	local company=pad:GetAttribute("Company")
	if not company then return {ok=false,msg="That bay has no contract"} end
	local removedBay, kept = nil, {}
	for _,b in ipairs(plot.loadBays or {}) do
		if b.pad==pad then removedBay=b else kept[#kept+1]=b end
	end
	plot.loadBays=kept
	if plot==primary() then TruckService.loadBays=plot.loadBays end
	if removedBay then removedBay:destroy() end
	for _,a in ipairs({"Company","Tier","ColR","ColG","ColB"}) do pad:SetAttribute(a, nil) end
	pad.Color=Color3.fromRGB(78,82,92); pad.Transparency=0.5
	updateBaySign(pad, nil)
	local stillServed=false
	for _,p in ipairs(plot.LoadBays:GetChildren()) do
		if p:GetAttribute("Company")==company then stillServed=true break end
	end
	local cleared=0
	if not stillServed then
		local sp=plot.stagedPackages
		for i=#sp,1,-1 do
			local pkg=sp[i]
			if pkg and pkg:GetAttribute("Company")==company then
				table.remove(sp,i)
				if pkg.Parent then pkg:Destroy() end
				cleared+=1
			end
		end
	end
	return {ok=true, bay=bayName, company=company, cleared=cleared}
end

return TruckService

