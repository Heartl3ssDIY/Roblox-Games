-- WorkerService: per-shift R6 worker NPCs (free starters + hired roster) that walk -> grab -> sort -> load,
-- with real walk animation, pickup gesture, stats-driven speed, breakage, Golden/Rainbow conversion, leveling; plus hiring.
local TweenService=game:GetService("TweenService"); local WS=game:GetService("Workspace"); local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local PhysicsService=game:GetService("PhysicsService")
-- NPCs live in their own collision group so the Humanoid can't make them shove the player.
pcall(function() PhysicsService:RegisterCollisionGroup("NPCs") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("NPCs","Default",false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("NPCs","NPCs",false) end)
local PackageService=require(script.Parent.PackageService)
local TruckService=require(script.Parent.TruckService)
local PlotService=require(script.Parent.PlotService)
local TimeService=require(script.Parent.TimeService)
local CurrencyService=require(script.Parent.CurrencyService)
local EmployeeConfig=require(RS.Configs.EmployeeConfig)
local AgencyConfig=require(RS.Configs.AgencyConfig)
local Progression=require(RS.Configs.ProgressionConfig)
local Remotes=RS:WaitForChild("Remotes")

local WorkerService={}
WorkerService.active={}   -- every active worker across all plots (each w carries w.plot)
WorkerService.roster={}
local autoDismiss={}   -- [userId][tier]=true : freshly rolled workers of that rarity are auto-dismissed
-- extra equipped-worker slots per shift, granted by the "+slots" game passes (StoreService sets the attribute)
local function extraSlots(plr) return (plr and plr:GetAttribute("ExtraEquipSlots")) or 0 end
-- Premium "Exceptional" workers bought with Robux are built on the fly so a player's CUSTOM name
-- survives rejoins (they aren't in EmployeeConfig.ByName). Max speed, never break fragiles (brk=0),
-- Rainbow finish (same rainbow-conversion as a Rainbow worker). They spawn EXTRA, beyond the cap.
local EXCEPTIONAL_CYCLE=6
local function makeExceptional(name)
	return {name=name, rarity="Exceptional", baseCycle=EXCEPTIONAL_CYCLE, baseBreak=0}
end

local WALK_ID="rbxassetid://180426354"
local FACE_OFFSET=0  -- yaw offset so the rig faces its travel direction (flip to math.pi if backwards)
local HOMES={Vector3.new(-12,3,-22),Vector3.new(-4,3,-24),Vector3.new(4,3,-24),Vector3.new(12,3,-22),
	Vector3.new(-8,3,-26),Vector3.new(8,3,-26),Vector3.new(0,3,-22)}
-- HOMES are authored in world space for the original warehouse. Convert each to an offset from
-- that warehouse's origin so a worker on ANY plot stands at the matching spot on ITS warehouse.
-- For the primary plot (origin == the authoring origin) this returns the original HOMES exactly.
local homeBase=Vector3.new(20.5,8.375,0)
local function homeFor(plot, i)
	local h=HOMES[i] or HOMES[1]
	local p=plot.frame:PointToWorldSpace(h-homeBase)
	return Vector3.new(p.X,PlotService.floorY(plot)+3,p.Z)
end

-- One Heartbeat advances every active worker toward its current goal (set via moveTo).
-- This replaces the old per-leg CFrameValue+Tween+Changed pattern, which allocated a
-- throwaway value/tween/connection for every leg of every walk and fired a Lua callback
-- per worker per frame -- the main source of the NPC lag.
local moveConn
local function stepWorkers(dt)
	local list=WorkerService.active
	for i=1,#list do
		local w=list[i]
		local goal=w.moveGoal
		if goal and w.active and w.hrp and w.hrp.Parent then
			local cur=w.hrp.Position
			local fx,fz=goal.X-cur.X, goal.Z-cur.Z
			local dist=math.sqrt(fx*fx+fz*fz)
			local step=(w.moveSpeed or 12)*dt
			if dist<=step or dist<0.05 then
				local rot = (dist>1e-3) and CFrame.lookAt(Vector3.zero, Vector3.new(fx,0,fz).Unit).Rotation or w.hrp.CFrame.Rotation
				w.hrp.CFrame=CFrame.new(goal)*rot*CFrame.Angles(0,FACE_OFFSET,0)
				w.moveGoal=nil
			else
				local inv=step/dist
				local rot=CFrame.lookAt(Vector3.zero, Vector3.new(fx,0,fz).Unit).Rotation
				w.hrp.CFrame=CFrame.new(cur.X+fx*inv,goal.Y,cur.Z+fz*inv)*rot*CFrame.Angles(0,FACE_OFFSET,0)
			end
		end
	end
end

local function makeWorker(emp,finish)
	local tpl=RS.CharModels:FindFirstChild("WorkerTemplate")
	local m=tpl:Clone(); m.Name=emp.name
	local rcol=EmployeeConfig.Rarities[emp.rarity].color
	for _,n in ipairs({"HardHat","Brim"}) do local p=m:FindFirstChild(n); if p then p.Color=rcol end end
	if finish then local h=Instance.new("Highlight"); local fc=EmployeeConfig.Finishes[finish].color
		h.FillTransparency=0.65; h.FillColor=fc; h.OutlineColor=fc; h.Parent=m end
	local head=m:FindFirstChild("Head")
	local bb=Instance.new("BillboardGui"); bb.Name="NameTag"; bb.Size=UDim2.fromOffset(140,30); bb.StudsOffset=Vector3.new(0,2.2,0); bb.AlwaysOnTop=true; bb.MaxDistance=60; bb.Adornee=head; bb.Parent=head
	local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold
	lbl.TextScaled=true; lbl.TextColor3=Color3.new(1,1,1); lbl.TextStrokeTransparency=0.3; lbl.Text=emp.name; lbl.Parent=bb
	local hum=m:FindFirstChildOfClass("Humanoid"); if hum then hum.AutoRotate=false; hum.EvaluateStateMachine=false end
	-- NPCs move by anchored HRP tween; make every body part non-collidable so they never
	-- shove or launch the player when they cluster/teleport around the staging area.
	for _,bp in ipairs(m:GetDescendants()) do
		if bp:IsA("BasePart") then bp.CanCollide=false; bp.Massless=true; bp.CollisionGroup="NPCs" end
	end
	local hrpRef=m:FindFirstChild("HumanoidRootPart"); if hrpRef then hrpRef.Anchored=true end
	-- Accessories (HardHat/Brim/VestBand) were attached with WeldConstraints, which are physics-
	-- resolved and lag a frame behind when the anchored HRP is CFrame-teleported each step (like
	-- the R6 limbs) so they ride the rig rigidly with zero lag. Convert each weld to a Motor6D.
	local ACCESSORY={HardHat=true,Brim=true,VestBand=true}
	for _,wc in ipairs(m:GetDescendants()) do
		if wc:IsA("WeldConstraint") and wc.Part0 and wc.Part1 then
			local body,acc=wc.Part0,wc.Part1
			if ACCESSORY[body.Name] and not ACCESSORY[acc.Name] then body,acc=acc,body end
			local m6=Instance.new("Motor6D"); m6.Name="AccessoryMotor"
			m6.Part0=body; m6.Part1=acc; m6.C0=body.CFrame:ToObjectSpace(acc.CFrame); m6.Parent=body
			wc:Destroy()
		end
	end
	local animator=hum and hum:FindFirstChildOfClass("Animator")
	local walkTrack
	if animator then local a=Instance.new("Animation"); a.AnimationId=WALK_ID; walkTrack=animator:LoadAnimation(a); walkTrack.Looped=true; walkTrack.Priority=Enum.AnimationPriority.Movement end
	return m,lbl,walkTrack,m:FindFirstChild("HumanoidRootPart")
end

-- speed (studs/sec) from the worker's cycle stat: better workers walk faster, but
-- everyone moves at a natural pace (no crawling), independent of the raw cycle seconds.
local function speedFor(cycle) return math.clamp(160/math.max(1,cycle), 8, 26) end
-- per-tier move-speed multipliers (user-tuned)
local TIER_SPEED={Exceptional=2.5, Super=2.0, Hard=1.5}
-- Set a goal and yield cheaply until the central stepper arrives the worker there.
-- No per-leg instances or connections -- just a flag the Heartbeat loop drains.
local function moveTo(w, pos, speed)
	if not (w.active and w.hrp and w.hrp.Parent) then return end
	w.moveSpeed=speed or 12
	w.moveGoal=Vector3.new(pos.X,PlotService.floorY(w.plot)+3,pos.Z)
	-- while carrying, DON'T play the walk anim -- its arm-swing fights the carry pose and makes the
	-- hands flail off the parcel. Legs glide instead, but the parcel stays held steady in both hands.
	if w.walkTrack and not w.carry then w.walkTrack:Play(0.15) end
	while w.moveGoal and w.active and w.hrp and w.hrp.Parent do task.wait() end
	w.moveGoal=nil
	if w.walkTrack then w.walkTrack:Stop(0.15) end
end

-- brief forward bow to "pick up" -- tweens the anchored HRP directly (no proxy value/connection)
local function pickupGesture(w)
	if not (w.active and w.hrp and w.hrp.Parent) then return end
	local base=w.hrp.CFrame
	local down=base*CFrame.Angles(math.rad(-28),0,0)
	local t1=TweenService:Create(w.hrp,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{CFrame=down}); t1:Play(); t1.Completed:Wait()
	task.wait(0.1)
	if not (w.hrp and w.hrp.Parent) then return end
	local t2=TweenService:Create(w.hrp,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{CFrame=base}); t2:Play(); t2.Completed:Wait()
end

-- raise both arms forward (R6 shoulders) so the worker holds the parcel in their hands
local function setCarryPose(w, on)
	local torso=w.model and w.model:FindFirstChild("Torso")
	if not torso then return end
	w._shBase=w._shBase or {}
	for _,side in ipairs({"Right","Left"}) do
		local sh=torso:FindFirstChild(side.." Shoulder")
		if sh and sh:IsA("Motor6D") then
			w._shBase[side]=w._shBase[side] or sh.C0
			sh.C0 = on and (w._shBase[side]*CFrame.Angles(math.rad(-72),0,0)) or w._shBase[side]
		end
	end
end
-- carry slots: primary in the hands, extras cradled up the arms (gamepass +carry)
local CARRY_OFF={ CFrame.new(0,-0.2,-1.5), CFrame.new(0,0.6,-1.7), CFrame.new(0,1.35,-1.9), CFrame.new(0,2.05,-2.1) }
local function carry(w, pkg)
	w.carryList = w.carryList or {}
	local slot=#w.carryList+1
	local off=CARRY_OFF[math.min(slot,#CARRY_OFF)]
	pkg.Anchored=false; pkg.CanCollide=false; pkg.Massless=true
	pkg.CFrame=w.hrp.CFrame*off
	-- Motor6D (not WeldConstraint) so the parcel tracks the CFrame-teleported HRP with zero lag.
	local m6=Instance.new("Motor6D"); m6.Name="CarryMotor"..slot; m6.Part0=w.hrp; m6.Part1=pkg
	m6.C0=off; m6.Parent=w.hrp
	pkg.Parent=w.model
	table.insert(w.carryList, {pkg=pkg, motor=m6})
	w.carry=pkg   -- primary (doBreak's gesture reads this)
	setCarryPose(w, true)
end
local function releaseCarry(w)
	if w.carryList then
		for _,c in ipairs(w.carryList) do if c.motor then c.motor:Destroy() end; if c.pkg and c.pkg.Parent then c.pkg.Anchored=true end end
		w.carryList=nil
	end
	w.carry=nil
	setCarryPose(w, false)
end

-- quick stumble when a worker botches a fragile parcel (jerkier than the smooth pickup bow)
local function fumbleGesture(w)
	if not (w.active and w.hrp and w.hrp.Parent) then return end
	local base=w.hrp.CFrame
	local jolt=base*CFrame.Angles(math.rad(16),math.rad(10),0)
	local t1=TweenService:Create(w.hrp,TweenInfo.new(0.08,Enum.EasingStyle.Quad),{CFrame=jolt}); t1:Play(); t1.Completed:Wait()
	if not (w.hrp and w.hrp.Parent) then return end
	local t2=TweenService:Create(w.hrp,TweenInfo.new(0.18,Enum.EasingStyle.Elastic),{CFrame=base}); t2:Play(); t2.Completed:Wait()
end

-- A worker botches a fragile parcel: drop its value, play the break feedback, stumble, warn the owner.
local function doBreak(w, pkg)
	local cleanVal = pkg:GetAttribute("Value") or 0
	PackageService.markDamaged(pkg)
	local lost = cleanVal - (pkg:GetAttribute("Value") or 0)
	PackageService.breakEffect(pkg)
	fumbleGesture(w)
	local plr=(w.plot and w.plot.owner) or Players:GetPlayers()[1]
	if plr and lost>0 then
		Remotes.Notify:FireClient(plr, {text=w.emp.name.." fumbled a fragile parcel  (-$"..lost..")", kind="error"})
	end
end

local function tryLevel(w)
	local need=EmployeeConfig.parcelsToLevel(w.emp.rarity,w.level)
	while w.delivered>=need and w.level<EmployeeConfig.MaxLevel do
		w.delivered-=need; w.level+=1; need=EmployeeConfig.parcelsToLevel(w.emp.rarity,w.level)
		if w.entry then w.entry.level=w.level end
		if w.label then w.label.Text=w.emp.name.."  Lv "..w.level end
	end
end

local function routine(w)
	while w.active do
		local pkg=TruckService.takeForBalancedBay(w.plot)
		if not pkg then task.wait(0.4)
		else
			local company=pkg:GetAttribute("Company")
			local bay=TruckService.getLoadBay(company, w.plot)
			if not bay then TruckService.restage(pkg, w.plot); task.wait(0.3)
			else
				local cycle,brk=EmployeeConfig.statsAtLevel(w.emp,w.level)
				local spd=speedFor(cycle)*(TIER_SPEED[w.emp.rarity] or 1)
				local gp=pkg.Position
				moveTo(w, gp+w.plot.frame:VectorToWorldSpace(Vector3.new(0,0,2)), spd)
				if not w.active then TruckService.restage(pkg, w.plot); break end
				pickupGesture(w); carry(w, pkg)
				local batch={pkg}
				-- GAMEPASS: workers carry extra parcels of the SAME company in one trip (0 unless the owner owns the pass)
				local extra=(w.plot.owner and w.plot.owner:GetAttribute("WorkerCarryPlus")) or 0
				for _=1,extra do
					local p2=TruckService.takeCompanyStaged(company, w.plot)
					if not p2 then break end
					carry(w, p2); batch[#batch+1]=p2
				end
				moveTo(w, bay.pad.CFrame:PointToWorldSpace(Vector3.new(0,3,4)), spd)
				if not w.active then releaseCarry(w); for _,p in ipairs(batch) do TruckService.restage(p, w.plot) end; break end
				for _,p in ipairs(batch) do
					if w.finish=="Golden" and math.random()<EmployeeConfig.Finishes.Golden.convertChance then PackageService.setRarity(p,"Gold")
					elseif w.finish=="Rainbow" and math.random()<EmployeeConfig.Finishes.Rainbow.convertChance then PackageService.setRarity(p,"Rainbow") end
					if p:GetAttribute("Fragile") and math.random()<brk then doBreak(w, p) end
				end
				pickupGesture(w); releaseCarry(w)
				-- load each carried parcel; restage any the bay can't take (truck left/full)
				for _,p in ipairs(batch) do
					if (not bay.leaving) and bay:load(p) then
						w.delivered+=1; tryLevel(w)
						if w.entry then w.entry.delivered=w.delivered end
					else
						TruckService.restage(p, w.plot)
					end
				end
				moveTo(w, w.home, spd)
			end
		end
	end
end

local function spawnWorker(plot,emp,finish,level,home,entry)
	local model,lbl,walkTrack,hrp=makeWorker(emp,finish)
	hrp.CFrame=CFrame.new(home)*plot.frame.Rotation
	model.Parent=plot.workersFolder
	model:SetAttribute("LabelOwner", (plot.owner and plot.owner.UserId) or 0)   -- only the owner sees this NPC's name label
	lbl.Text=emp.name.."  Lv "..(level or 1)
	local w={plot=plot,emp=emp,level=level or 1,finish=finish,delivered=(entry and entry.delivered) or 0,model=model,label=lbl,home=home,active=true,entry=entry,walkTrack=walkTrack,hrp=hrp}
	task.spawn(function() routine(w) end); return w
end
local function despawnPlot(plot)
	local keep={}
	for _,w in ipairs(WorkerService.active) do
		if w.plot==plot then
			w.active=false
			if w.carry and w.carry.Parent==w.model then releaseCarry(w); TruckService.restage(w.carry, w.plot) end
			if w.model then w.model:Destroy() end
		else
			keep[#keep+1]=w
		end
	end
	WorkerService.active=keep
end
WorkerService.despawnPlot=despawnPlot

local function getRoster(plr)
	local r=WorkerService.roster[plr.UserId]
	if not r then r={Morning={},Afternoon={},Night={}}; WorkerService.roster[plr.UserId]=r end
	if not r.freeOff then r.freeOff={Morning={},Afternoon={},Night={}} end
	return r
end
WorkerService.getRoster=getRoster

function WorkerService.hire(plr, agencyId)
	local ag=AgencyConfig.get(agencyId)
	if not ag then return {ok=false,msg="Unknown agency"} end
	local lvl=plr:FindFirstChild("Currency") and plr.Currency.Level.Value or 1
	if lvl<ag.unlockLevel then return {ok=false,msg="Unlocks at Level "..ag.unlockLevel} end
	if not CurrencyService.Spend(plr,"Cash",ag.rollCost) then return {ok=false,msg="Not enough Cash"} end
	local roster=getRoster(plr)
	local owned={}
	for i=1,Progression.StartingWorkersPerShift do owned[EmployeeConfig.Names.Lazy[i]]=true end
	for _,sh in pairs(roster) do for _,w in ipairs(sh) do owned[w.empName]=true end end
	local ad=autoDismiss[plr.UserId]
	local results={}
	for _,shift in ipairs(Progression.ShiftOrder) do
		local rarity=AgencyConfig.rollRarity(agencyId)
		local names=EmployeeConfig.Names[rarity]
		local name=names[math.random(#names)]
		local finish=EmployeeConfig.rollFinish()
		local dupe=owned[name]==true
		local dismissed=(not dupe) and ad~=nil and ad[rarity]==true
		if (not dupe) and (not dismissed) then
			local maxHired=Progression.WorkersPerShift + extraSlots(plr)
			local eqHired=0; for _,w in ipairs(roster[shift]) do if w.equipped~=false and w.special~="exceptional" then eqHired+=1 end end
			table.insert(roster[shift],{empName=name,rarity=rarity,finish=finish,level=1,delivered=0,agencyId=agencyId,equipped=(eqHired<maxHired)}); owned[name]=true
		end
		table.insert(results,{shift=shift,name=name,rarity=rarity,finish=finish,dupe=dupe,dismissed=dismissed})
	end
	-- new hires deploy when their shift next begins (the on-duty shift's lineup stays locked)
	pcall(function() require(script.Parent.BillingService).recompute(plr) end)
	return {ok=true,results=results}
end

-- Auto-dismiss settings: rolled workers of an enabled tier are discarded instead of joining the roster.
function WorkerService.setAutoDismiss(plr, tier, enabled)
	if not EmployeeConfig.Rarities[tier] then return {ok=false,msg="Unknown tier"} end
	autoDismiss[plr.UserId]=autoDismiss[plr.UserId] or {}
	autoDismiss[plr.UserId][tier]= enabled and true or nil
	return {ok=true, tier=tier, enabled=enabled and true or false}
end
function WorkerService.getAutoDismiss(plr) return autoDismiss[plr.UserId] or {} end
function WorkerService.loadAutoDismiss(plr, data) if type(data)=="table" then autoDismiss[plr.UserId]=data end end
function WorkerService.clearAutoDismiss(plr) autoDismiss[plr.UserId]=nil end

function WorkerService.spawnShiftForPlot(plot, shift)
	if not plot.owner or plot.active==false then despawnPlot(plot);return end
	if not plot.workersFolder then
		local f=Instance.new("Folder"); f.Name="Workers"; f.Parent=plot.wh; plot.workersFolder=f
	end
	despawnPlot(plot)
	local cap=Progression.WorkersPerShift + extraSlots(plot.owner or Players:GetPlayers()[1])
	local idx,spawned=0,0
	-- 1) the owner's EQUIPPED hired employees fill slots first, up to the cap (fall back to the
	--    lone player while the primary plot is still unowned)
	local owner=plot.owner or Players:GetPlayers()[1]
	if owner then
		for _,w in ipairs(getRoster(owner)[shift] or {}) do
			if spawned>=cap then break end
			if w.equipped~=false and w.special~="exceptional" then
				local emp=EmployeeConfig.ByName[w.empName]
				if emp then idx+=1; spawned+=1; table.insert(WorkerService.active, spawnWorker(plot, emp,w.finish,w.level or 1, homeFor(plot,idx), w)) end
			end
		end
	end
	-- 2) free Lazy starters fill any remaining empty slots, up to the free baseline,
	--    skipping any the owner has dismissed ("fired") for this shift
	local freeOff=(owner and getRoster(owner).freeOff[shift]) or {}
	for i=1,Progression.StartingWorkersPerShift do
		if spawned>=cap then break end
		local nm=EmployeeConfig.Names.Lazy[i]
		if not freeOff[nm] then
			local emp=EmployeeConfig.ByName[nm]
			if emp then idx+=1; spawned+=1; table.insert(WorkerService.active, spawnWorker(plot, emp,nil,1, homeFor(plot,idx))) end
		end
	end
	-- 3) premium Exceptional workers (bought with Robux) spawn EXTRA -- beyond the cap -- on their shift
	if owner then
		for _,w in ipairs(getRoster(owner)[shift] or {}) do
			if w.special=="exceptional" and w.equipped~=false then
				idx+=1
				table.insert(WorkerService.active, spawnWorker(plot, makeExceptional(w.empName), "Rainbow", w.level or 1, homeFor(plot,idx), w))
			end
		end
	end
end

function WorkerService.spawnShift(shift)
	for _,plot in ipairs(PlotService.all()) do
		WorkerService.spawnShiftForPlot(plot, shift)
	end
end

function WorkerService.toggleEquip(plr, shift, empName, equipped)
	if shift==TimeService.getShift() then
		return {ok=false,msg="The "..shift.." crew is on duty \u{2013} change it once the shift ends"}
	end
	local r=getRoster(plr)
	-- free Lazy starters aren't roster entries; dismissing one just flags it off for this shift
	local isFree=false
	for i=1,Progression.StartingWorkersPerShift do if EmployeeConfig.Names.Lazy[i]==empName then isFree=true break end end
	if isFree then
		r.freeOff[shift]=r.freeOff[shift] or {}
		if equipped then r.freeOff[shift][empName]=nil else r.freeOff[shift][empName]=true end
		return {ok=true,equipped=equipped and true or false}
	end
	local roster=r[shift]; if not roster then return {ok=false,msg="bad shift"} end
	local maxHired=Progression.WorkersPerShift + extraSlots(plr)
	local target; for _,w in ipairs(roster) do if w.empName==empName then target=w end end
	if not target then return {ok=false,msg="not found"} end
	if equipped then
		if target.equipped~=false then return {ok=true,equipped=true} end
		if target.special~="exceptional" then
			local n=0; for _,w in ipairs(roster) do if w.equipped~=false and w.special~="exceptional" then n+=1 end end
			if n>=maxHired then return {ok=false,msg="Shift full ("..maxHired.." slots)"} end
		end
		target.equipped=true
	else target.equipped=false end
	-- off-duty shift: the change deploys when that shift next starts (no live respawn needed)
	return {ok=true,equipped=target.equipped~=false}
end

-- Fire (permanently remove) a hired worker from a shift's roster so it stops cluttering the list.
-- Only off-duty shifts, and never the free Lazy starters (those are the baseline -- Unequip those).
function WorkerService.fire(plr, shift, empName)
	if shift==TimeService.getShift() then
		return {ok=false,msg="The "..shift.." crew is on duty \u{2013} fire once the shift ends"}
	end
	local roster=getRoster(plr)[shift]; if not roster then return {ok=false,msg="bad shift"} end
	for i=1,Progression.StartingWorkersPerShift do
		if EmployeeConfig.Names.Lazy[i]==empName then return {ok=false,msg="Starter workers can't be fired"} end
	end
	local idx; for i,w in ipairs(roster) do if w.empName==empName then idx=i break end end
	if not idx then return {ok=false,msg="Worker not found"} end
	local removed=table.remove(roster, idx)
	if removed and removed.special=="exceptional" then WorkerService.refreshExceptional(plr) end
	pcall(function() require(script.Parent.BillingService).recompute(plr) end)
	return {ok=true, name=empName}
end

function WorkerService.getRosterData(plr)
	local roster=getRoster(plr)
	local cap=Progression.WorkersPerShift + extraSlots(plr)
	local out={cap=cap, free=Progression.StartingWorkersPerShift, activeShift=TimeService.getShift(), shifts={}}
	for _,shift in ipairs(Progression.ShiftOrder) do
		local hired={}; local equipped=0
		for _,w in ipairs(roster[shift] or {}) do
			local isEq=(w.equipped~=false)
			if isEq and w.special~="exceptional" then equipped+=1 end
			hired[#hired+1]={name=w.empName,rarity=w.rarity,finish=w.finish,level=w.level or 1,equipped=isEq,free=false,special=w.special}
		end
		-- free Lazy starters: shown for the slots equipped hired didn't take (up to the free
		-- baseline). A dismissed starter still shows so the player can re-add it, but unequipped.
		local freeOff=roster.freeOff[shift] or {}
		local freeSlots=math.min(Progression.StartingWorkersPerShift, math.max(0, cap-equipped))
		local list={}
		for i=1,freeSlots do
			local nm=EmployeeConfig.Names.Lazy[i]
			local emp=EmployeeConfig.ByName[nm]
			if emp then list[#list+1]={name=emp.name,rarity=emp.rarity,level=1,equipped=(freeOff[nm]~=true),free=true} end
		end
		for _,h in ipairs(hired) do list[#list+1]=h end
		out.shifts[shift]=list
	end
	return out
end

-- Count a player's Exceptional (Robux) workers and mirror it to the ExceptionalOwned attribute
-- so the store UI can show "X/max" and disable the buy button at the cap.
function WorkerService.refreshExceptional(plr)
	local roster=getRoster(plr); local n=0
	for _,sh in ipairs(Progression.ShiftOrder) do
		for _,w in ipairs(roster[sh] or {}) do if w.special=="exceptional" then n+=1 end end
	end
	plr:SetAttribute("ExceptionalOwned", n)
	return n
end

-- Add a Robux-bought Exceptional worker to a shift (capped at maxOwned across all shifts).
-- Returns the new count, or nil + reason ("max"/"bad shift") if it couldn't be added.
function WorkerService.addExceptional(plr, name, shift, maxOwned)
	local roster=getRoster(plr)
	if not roster[shift] then return nil,"bad shift" end
	local count=WorkerService.refreshExceptional(plr)
	if maxOwned and count>=maxOwned then return nil,"max" end
	name=(name and name~="" and name) or "Ace"
	table.insert(roster[shift], {empName=name, rarity="Exceptional", finish="Rainbow", level=1, delivered=0, equipped=true, special="exceptional"})
	if shift==TimeService.getShift() then
		local plot=PlotService.forPlayer(plr)
		if plot then WorkerService.spawnShiftForPlot(plot, shift) end
	end
	return WorkerService.refreshExceptional(plr)
end

function WorkerService.Start()
	if not moveConn then moveConn=RunService.Heartbeat:Connect(stepWorkers) end
	WorkerService.spawnShift(TimeService.getShift())
	TimeService.ShiftChanged.Event:Connect(function(newShift) WorkerService.spawnShift(newShift) end)
	print("[WorkerService] started ("..#WorkerService.active.." workers on "..TimeService.getShift().." shift, "..#PlotService.all().." plot(s))")
end
return WorkerService

