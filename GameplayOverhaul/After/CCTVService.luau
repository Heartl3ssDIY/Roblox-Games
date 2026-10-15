-- CCTVService: mounts 2 scanning cameras on each CCTV-owner's front (bay-facing) wall. Each camera
-- sweeps a red light cone; an intruder caught in-cone pings the owner + alerts their guards, and (if
-- the Freeze Ray upgrade is owned) freezes a thief who's carrying packages (15s freeze, 15s cooldown).
-- Cameras go dark while the owner is WASTED (out).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")
local PlotService=require(script.Parent.PlotService)
local SecurityService=require(script.Parent.SecurityService)
local SecurityCombatService=require(script.Parent.SecurityCombatService)
local ManualLoadService=require(script.Parent.ManualLoadService)
local AccessService=require(script.Parent.AccessService)
local Cfg=require(RS.Configs.SecurityConfig)
local CurrencyService=require(script.Parent.CurrencyService)

local Motion=require(script.Parent.PackageService).Motion
local CCTVService={}
local rigs={}            -- [ownerUserId] = { cams={camModel,...}, owner=Player }
local lastAlert={}       -- [ownerUserId]=clock (throttle owner pings)
local freezeReady={}     -- [ownerUserId]=clock when the freeze ray is ready again
local camState=setmetatable({},{__mode="k"})   -- [camModel]={lock=uid,lastAlert=clock}
local camMeta=setmetatable({},{__mode="k"})  -- [camModel]={head=headModel, headCF0=baseCFrame, pivot=neckPos} -- base bolted, only head pans
local RING_R=9           -- ground detection-ring radius (studs)
local FLOOR_Y=0.35
local SWEEP_DEG=48        -- how far the camera pans either side of centre
local CAM_HP=100000          -- huge so the camera never "dies"; we break it on cumulative damage instead
local CAM_BREAK_DAMAGE=100   -- bullet damage needed to shoot a camera out
local REPAIR_COST=5000
local breakCamera, repairCamera, finishRepair   -- forward declarations
local function gameHours()
	local gt=RS:FindFirstChild("GameTime")
	return ((gt and gt:GetAttribute("Day") or 1)-1)*24 + (gt and gt:GetAttribute("Hour") or 0)
end
local function isMorning() local gt=RS:FindFirstChild("GameTime"); return gt~=nil and gt:GetAttribute("Shift")=="Morning" end

local function notify(plr,text,kind)
	local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end
local function template() local f=ServerStorage:FindFirstChild("SecurityModels"); return f and f:FindFirstChild("Camera") end

-- front (bay-facing) wall frame of a plot: returns center, outward normal, right axis
local function frontFrame(plot)
	local bays=plot.loadBays or {}
	if #bays==0 then return nil end
	local sum=Vector3.zero; local look=Vector3.zero
	for _,b in ipairs(bays) do sum+=b.pad.Position; look+=b.pad.CFrame.LookVector end
	local center=sum/#bays
	local outward=(look*-1)
	outward=(outward.Magnitude>0.05) and outward.Unit or Vector3.new(0,0,1)
	local right=outward:Cross(Vector3.new(0,1,0))
	right=(right.Magnitude>0.05) and right.Unit or Vector3.new(1,0,0)
	return center, outward, right
end

-- build the two cameras for an owner
local function spawnRig(owner)
	local plot=PlotService.forPlayer(owner); if not plot then return end
	local center,outward,right=frontFrame(plot); if not center then return end
	local tmpl=template()
	local cams={}
	-- 5 preset wall slots on the front-wall pillars: outer-left, outer-right, middle, inner-left,
	-- inner-right. The owner gets the first cameraCount() of them.
	local bays=plot.loadBays or {}
	local baseY=(bays[1] and bays[1].pad.Position.Y) or 0
	local mountList={}
	local n=SecurityService.cameraCount(owner) or 2
	-- Prefer hand-placed CamSlot markers (Warehouse > CameraSlots folder): the owner can drag
	-- each slot exactly where they want a camera. Slot position = wall mount; LookVector = facing.
	local whFolder = plot.LoadBays and plot.LoadBays.Parent
	local slotsFolder = whFolder and whFolder:FindFirstChild("CameraSlots")
	if slotsFolder then
		local slots={}
		for _,s in ipairs(slotsFolder:GetChildren()) do if s:IsA("BasePart") then slots[#slots+1]=s end end
		table.sort(slots, function(a,b) return a.Name<b.Name end)
		n=math.clamp(n,0,#slots)
		for i=1,n do local s=slots[i]; mountList[#mountList+1]={mount=s.Position, fwd=s.CFrame.LookVector} end
	else
		local minL,maxL=1e9,-1e9
		for _,b in ipairs(bays) do local l=(b.pad.Position-center):Dot(right); minL=math.min(minL,l); maxL=math.max(maxL,l) end
		local outerL=math.max(math.abs(minL),math.abs(maxL))+11
		local midL=outerL*0.52
		local laterals={-outerL, outerL, 0, -midL, midL}
		n=math.clamp(n,0,#laterals)
		for i=1,n do
			local m=center+outward*16+right*laterals[i]
			mountList[#mountList+1]={mount=Vector3.new(m.X, baseY+10.5, m.Z), fwd=(outward-Vector3.new(0,0.5,0)).Unit}
		end
	end
	for _,mEntry in ipairs(mountList) do
		local mount=mEntry.mount
		local faceForward=mEntry.fwd
		local cam
		if tmpl then cam=tmpl:Clone() else
			cam=Instance.new("Model")
			local b=Instance.new("Part"); b.Size=Vector3.new(1.6,1,2.4); b.Color=Color3.fromRGB(35,35,40); b.Anchored=true; b.CanCollide=false; b.Parent=cam; cam.PrimaryPart=b
		end
		cam.Name="SecCam"
		-- ensure a PrimaryPart
		if not cam.PrimaryPart then cam.PrimaryPart=cam:FindFirstChildWhichIsA("BasePart") end
		for _,d in ipairs(cam:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=true end end   -- CanQuery so bullets can hit it
		if cam.PrimaryPart then cam:PivotTo(CFrame.lookAt(mount, mount+faceForward)); pcall(function() cam:ScaleTo(1.8) end) end   -- bigger = easier to spot
		-- base (Wall) stays bolted to the wall; only the head ("Camera" submodel) pivots about the neck
		do
			local head=cam:FindFirstChild("Camera")
			local neck=cam:FindFirstChild("Neck")
			local pivotPos
			if neck then pivotPos=neck:GetBoundingBox().Position
			elseif head then pivotPos=head:GetPivot().Position else pivotPos=mount end
			if head then
				-- the model's pivot axis doesn't match the lens axis, so re-aim ONLY the head about the
				-- neck so its lens (neck->head direction) points along faceForward (outward + downward).
				local hp=head:GetBoundingBox().Position
				local lensDir=(hp-pivotPos)
				if lensDir.Magnitude>1e-3 then
					lensDir=lensDir.Unit
					local desired=faceForward.Unit
					local d=math.clamp(lensDir:Dot(desired),-1,1)
					local axis=lensDir:Cross(desired)
					local rotCF
					if axis.Magnitude<1e-4 then rotCF=(d>0) and CFrame.new() or CFrame.Angles(0,math.pi,0)
					else rotCF=CFrame.fromAxisAngle(axis.Unit, math.acos(d)) end
					pcall(function() head:PivotTo(CFrame.new(pivotPos)*rotCF*CFrame.new(-pivotPos)*head:GetPivot()) end)
				end
			end
			camMeta[cam]={head=head, headCF0=(head and head:GetPivot() or nil), pivot=pivotPos}
		end
		-- red scan emitter (a child part carrying the SpotLight; we sweep this part)
		local emit=Instance.new("Part"); emit.Name="ScanEmitter"; emit.Size=Vector3.new(0.4,0.4,0.4)
		emit.Transparency=1; emit.Anchored=true; emit.CanCollide=false; emit.CanQuery=false; emit.CFrame=CFrame.new(mount)
		local light=Instance.new("SpotLight"); light.Color=Color3.fromRGB(255,40,40); light.Angle=math.deg(0)+math.clamp(Cfg.CCTV.coneAngle,20,80)
		light.Range=SecurityService.cctvRange(owner); light.Brightness=3; light.Face=Enum.NormalId.Front; light.Parent=emit
		local blip=Instance.new("PointLight"); blip.Color=Color3.fromRGB(255,0,0); blip.Range=4; blip.Brightness=2; blip.Parent=emit
		emit.Parent=cam
		-- bright red hazard light on the camera body (blinks) so players notice it
		local hazard=Instance.new("Part"); hazard.Name="HazardLight"; hazard.Shape=Enum.PartType.Ball; hazard.Size=Vector3.new(0.8,0.8,0.8)
		hazard.Material=Enum.Material.Neon; hazard.Color=Color3.fromRGB(255,25,25); hazard.Anchored=true; hazard.CanCollide=false; hazard.CanQuery=false
		hazard.CFrame=CFrame.new(mount); hazard.Parent=cam
		local hpl=Instance.new("PointLight"); hpl.Color=Color3.fromRGB(255,25,25); hpl.Range=12; hpl.Brightness=3; hpl.Parent=hazard
		-- ground detection ring (red disc) the camera projects + sweeps
		local ring=Instance.new("Part"); ring.Name="ScanRing"; ring.Shape=Enum.PartType.Cylinder
		ring.Size=Vector3.new(0.3, RING_R*2, RING_R*2); ring.Material=Enum.Material.Neon; ring.Color=Color3.fromRGB(255,40,40)
		ring.Transparency=0.55; ring.Anchored=true; ring.CanCollide=false; ring.CanQuery=false; ring.Parent=cam
		cam:SetAttribute("BaseCFrame", true)
		cam:SetAttribute("MountX",mount.X); cam:SetAttribute("MountY",mount.Y); cam:SetAttribute("MountZ",mount.Z)
		cam:SetAttribute("FwdX",faceForward.X); cam:SetAttribute("FwdY",faceForward.Y); cam:SetAttribute("FwdZ",faceForward.Z)
		cam:SetAttribute("LabelOwner", owner.UserId)
		cam:SetAttribute("Broken", false)
		-- make the camera shootable: an invisible Humanoid soaks bullet damage; we break it on enough hits
		do
			local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Size=Vector3.new(1,1,1)
			root.Transparency=1; root.CanCollide=false; root.CanQuery=false; root.Anchored=true
			root.CFrame=(cam.PrimaryPart and cam.PrimaryPart.CFrame) or CFrame.new(mount); root.Parent=cam
			local chum=Instance.new("Humanoid"); chum.MaxHealth=CAM_HP; chum.Health=CAM_HP
			chum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
			chum.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff; chum.BreakJointsOnDeath=false
			chum.Parent=cam
			chum.HealthChanged:Connect(function(h)
				if (not cam:GetAttribute("Broken")) and (CAM_HP-h)>=CAM_BREAK_DAMAGE then breakCamera(cam, owner) end
			end)
			local prompt=Instance.new("ProximityPrompt"); prompt.Name="RepairPrompt"; prompt.ActionText="Repair Camera"
			prompt.ObjectText="$"..REPAIR_COST; prompt.HoldDuration=0.6; prompt.MaxActivationDistance=12
			prompt.RequiresLineOfSight=false; prompt.Enabled=false; prompt.Parent=cam.PrimaryPart
			prompt.Triggered:Connect(function(plr) repairCamera(cam, owner, plr) end)
		end
		cam.Parent=workspace
		cams[#cams+1]=cam
	end
	rigs[owner.UserId]={cams=cams, owner=owner, count=n}
end

local function despawn(uid)
	local rig=rigs[uid]; if not rig then return end
	for _,c in ipairs(rig.cams) do if c and c.Parent then c:Destroy() end end
	rigs[uid]=nil
end

-- freeze a thief (mirrors the freeze-ray gun: 15s, icy highlight + anchored)
local function freeze(plr, secs)
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not hrp then return end
	if hum then hum.WalkSpeed=0; hum.JumpPower=0 end
	hrp.Anchored=true
	if not char:FindFirstChild("FrostFX") then
		local frost=Instance.new("Highlight"); frost.Name="FrostFX"; frost.FillColor=Color3.fromRGB(150,225,255); frost.FillTransparency=0.45; frost.OutlineColor=Color3.fromRGB(225,245,255); frost.Parent=char
	end
	plr:SetAttribute("FrozenUntil", os.time()+secs)
	task.delay(secs,function()
		if (plr:GetAttribute("FrozenUntil") or 0)>os.time() then return end
		local c=plr.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local rp=c and c:FindFirstChild("HumanoidRootPart")
		if rp then rp.Anchored=false end
		local fr=c and c:FindFirstChild("FrostFX"); if fr then fr:Destroy() end
		if h then h.WalkSpeed=16; h.JumpPower=50 end
	end)
end

-- shoot-out + morning repair --------------------------------------------
breakCamera=function(cam, owner)
	if cam:GetAttribute("Broken") then return end
	cam:SetAttribute("Broken", true); cam:SetAttribute("Repairing", false)
	local emit=cam:FindFirstChild("ScanEmitter")
	if emit then local sl=emit:FindFirstChildOfClass("SpotLight"); if sl then sl.Enabled=false end; local pl=emit:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=false end end
	if cam.PrimaryPart then pcall(function() cam:PivotTo(cam:GetPivot()*CFrame.Angles(math.rad(-40),0,0)) end) end   -- sag
	local pp=cam.PrimaryPart
	if pp then local s=Instance.new("Sparkles"); s.SparkleColor=Color3.fromRGB(255,170,60); s.Parent=pp; local sm=Instance.new("Smoke"); sm.Size=2; sm.Opacity=0.35; sm.RiseVelocity=2.5; sm.Color=Color3.fromRGB(40,40,40); sm.Parent=pp end
	if owner then notify(owner,"\u{1F4F9} A CCTV camera was shot out! Repair it in the morning for $"..REPAIR_COST..".","error") end
end
repairCamera=function(cam, owner, plr)
 local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
 if not root or not cam.PrimaryPart or (root.Position-cam.PrimaryPart.Position).Magnitude>14 then return end
	if plr~=owner then notify(plr,"Only the owner can repair this camera.","error"); return end
	if (not cam:GetAttribute("Broken")) or cam:GetAttribute("Repairing") then return end
	if not isMorning() then notify(plr,"Cameras can only be repaired in the morning.","error"); return end
	if not CurrencyService.Spend(plr,"Cash",REPAIR_COST) then notify(plr,"You need $"..REPAIR_COST.." to repair.","error"); return end
	cam:SetAttribute("Repairing", true); cam:SetAttribute("RepairDoneHours", gameHours()+1)
	local pr=cam.PrimaryPart and cam.PrimaryPart:FindFirstChild("RepairPrompt"); if pr then pr.Enabled=false end
	notify(plr,"Repairing camera... fully operational in 1 hour.","success")
end
finishRepair=function(cam)
	cam:SetAttribute("Broken", false); cam:SetAttribute("Repairing", false)
	local hum=cam:FindFirstChildOfClass("Humanoid"); if hum then hum.Health=hum.MaxHealth end
	local pp=cam.PrimaryPart
	if pp then for _,cl in ipairs({"Sparkles","Smoke"}) do local f=pp:FindFirstChildOfClass(cl); if f then f:Destroy() end end end
	local mount=Vector3.new(cam:GetAttribute("MountX"),cam:GetAttribute("MountY"),cam:GetAttribute("MountZ"))
	local fwd=Vector3.new(cam:GetAttribute("FwdX"),cam:GetAttribute("FwdY"),cam:GetAttribute("FwdZ"))
	pcall(function() cam:PivotTo(CFrame.lookAt(mount, mount+fwd)) end)
end

-- per-frame sweep + per-tick detection
local acc=0
local function step(dt)
	for uid,rig in pairs(rigs) do
		local owner=rig.owner
		local ownerOut=SecurityCombatService.isOut(owner)
		local range=SecurityService.cctvRange(owner)
		local half=math.rad(math.clamp(Cfg.CCTV.coneAngle,20,80)/2)
		for _,cam in ipairs(rig.cams) do
			-- shoot-out state: broken/repairing cameras don't scan; the repair prompt shows in the morning
			local broken=cam:GetAttribute("Broken"); local repairing=cam:GetAttribute("Repairing")
			local rpr=cam.PrimaryPart and cam.PrimaryPart:FindFirstChild("RepairPrompt")
			if rpr then rpr.Enabled = (broken==true and repairing~=true and isMorning()) end
			if repairing and gameHours()>=(cam:GetAttribute("RepairDoneHours") or 0) then finishRepair(cam); broken=false; repairing=false end
			if broken or repairing then
				local e=cam:FindFirstChild("ScanEmitter")
				if e then local sl=e:FindFirstChildOfClass("SpotLight"); if sl then sl.Enabled=false end; local pl=e:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=false end end
				continue
			end
			-- cameras are only ACTIVE at night (the stealing window). By day they sit dormant: no ring, no scan.
			if (not AccessService.isNight()) or ownerOut then
				local e=cam:FindFirstChild("ScanEmitter"); if e then local sl=e:FindFirstChildOfClass("SpotLight"); if sl then sl.Enabled=false end; local pl=e:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=false end end
				local rg=cam:FindFirstChild("ScanRing"); if rg then rg.Transparency=1 end
				local hz=cam:FindFirstChild("HazardLight"); if hz then hz.Transparency=1; local pl=hz:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=false end end
				local stx=camState[cam]; if stx then stx.lock=nil end
				continue
			end
			local mount=Vector3.new(cam:GetAttribute("MountX"),cam:GetAttribute("MountY"),cam:GetAttribute("MountZ"))
			local fwd=Vector3.new(cam:GetAttribute("FwdX"),cam:GetAttribute("FwdY"),cam:GetAttribute("FwdZ"))
			local st=camState[cam]; if not st then st={lock=nil,lastAlert=0}; camState[cam]=st end
			-- hazard blink
			local hazard=cam:FindFirstChild("HazardLight")
			if hazard then local on=(math.floor(os.clock()*2)%2==0) and not ownerOut; hazard.Transparency=on and 0 or 0.75; local pl=hazard:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=on end end
			-- aim: stay locked on a target, otherwise pan left/right
			local aimDir
			if st.lock then
				local lp=Players:GetPlayerByUserId(st.lock)
				local php=lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				if php and (not ownerOut) and (php.Position-mount).Magnitude<=range+6 and Motion.visible(mount,php.Position,{cam},lp.Character) then aimDir=(php.Position-mount).Unit
				else st.lock=nil end
			end
			if not st.lock then
				local phase=(os.clock()%Cfg.CCTV.sweepPeriod)/Cfg.CCTV.sweepPeriod
				local yaw=math.sin(phase*math.pi*2)*math.rad(SWEEP_DEG)
				aimDir=(CFrame.Angles(0,yaw,0)*CFrame.new(Vector3.zero,fwd)).LookVector
			end
			-- project the aim ray to the ground for the ring
			local tt=(aimDir.Y<-0.05) and ((mount.Y-FLOOR_Y)/(-aimDir.Y)) or range
			tt=math.clamp(tt,6,range)
			local ringPos=mount+aimDir*tt
 local groundParams=RaycastParams.new();groundParams.FilterType=Enum.RaycastFilterType.Exclude;groundParams.FilterDescendantsInstances={cam};groundParams.RespectCanCollide=true
 local ground=workspace:Raycast(Vector3.new(ringPos.X,mount.Y,ringPos.Z),Vector3.new(0,-100,0),groundParams)
 ringPos=Vector3.new(ringPos.X,ground and ground.Position.Y+.06 or FLOOR_Y,ringPos.Z)
			-- pan ONLY the head about its neck (base stays bolted to the wall, no clipping/sliding)
			local meta=camMeta[cam]
			if meta and meta.head and meta.headCF0 then
				local f2=Vector3.new(fwd.X,0,fwd.Z); local a2=Vector3.new(aimDir.X,0,aimDir.Z)
				local yaw2=0
				if f2.Magnitude>1e-3 and a2.Magnitude>1e-3 then f2=f2.Unit; a2=a2.Unit; yaw2=math.atan2(f2:Cross(a2).Y, f2:Dot(a2)) end
				local piv=meta.pivot
				local rot=CFrame.new(piv)*CFrame.Angles(0,yaw2,0)*CFrame.new(-piv)
				pcall(function() meta.head:PivotTo(rot*meta.headCF0) end)
			elseif cam.PrimaryPart then
				pcall(function() cam:PivotTo(CFrame.lookAt(mount, mount+aimDir)) end)
			end
			local emit=cam:FindFirstChild("ScanEmitter")
			if emit then emit.CFrame=CFrame.lookAt(mount, mount+aimDir); local sl=emit:FindFirstChildOfClass("SpotLight"); if sl then sl.Range=range; sl.Enabled=not ownerOut end; local pl=emit:FindFirstChildOfClass("PointLight"); if pl then pl.Enabled=not ownerOut end end
			local ring=cam:FindFirstChild("ScanRing")
			if ring then ring.CFrame=CFrame.new(ringPos)*CFrame.Angles(0,0,math.rad(90)); ring.Transparency= ownerOut and 1 or (st.lock and 0.25 or 0.55); ring.Color= st.lock and Color3.fromRGB(255,90,20) or Color3.fromRGB(255,40,40) end
			-- DETECTION: a non-owner inside the ground ring -> lock on + alert
			if not ownerOut then
				for _,p in ipairs(Players:GetPlayers()) do
					if p~=owner and p.Character then
						local php=p.Character:FindFirstChild("HumanoidRootPart")
						if php and (php.Position-mount).Magnitude<=range then
							local horiz=(Vector3.new(php.Position.X,0,php.Position.Z)-Vector3.new(ringPos.X,0,ringPos.Z)).Magnitude
							if horiz<=RING_R and Motion.visible(mount,php.Position,{cam},p.Character) then
								st.lock=p.UserId
								p:SetAttribute("SeenByCCTV", os.time()); p:SetAttribute("SeenByCCTVOwner", owner.UserId)
								if (os.clock()-(st.lastAlert or 0))>4 then st.lastAlert=os.clock(); notify(owner,"\u{1F6A8} CCTV locked onto "..(p.DisplayName or "an intruder").."!","error") end
								if SecurityService.hasFreeze(owner) and ManualLoadService.stolenCount(p,owner.UserId)>0 and (os.clock()>=(freezeReady[uid] or 0)) then
									local fcfg=Cfg.CctvUpByKey.freeze
									freeze(p, fcfg.freezeSecs); freezeReady[uid]=os.clock()+fcfg.freezeSecs+fcfg.freezeCooldown
									notify(p,"A CCTV freeze ray caught you!","error"); notify(owner,"Your CCTV froze a thief!","success")
								end
								break
							end
						end
					end
				end
			end
		end
	end
	-- red "marked" highlight on intruders the CCTV has seen in the last 3s
	for _,p in ipairs(Players:GetPlayers()) do
		local seen=(p:GetAttribute("SeenByCCTV") or 0)
		local mark=p.Character and p.Character:FindFirstChild("CCTVMark")
		if os.time()-seen>3 then if mark then mark:Destroy() end
		elseif p.Character and not mark then
			local h=Instance.new("Highlight"); h.Name="CCTVMark"; h.FillColor=Color3.fromRGB(255,40,40); h.FillTransparency=0.7; h.OutlineColor=Color3.fromRGB(255,60,60); h.Parent=p.Character
		end
	end
end

function CCTVService.Start()
	-- maintain rigs: spawn for owners who have CCTV, despawn for those who don't / left
	task.spawn(function()
		while true do
			for _,plr in ipairs(Players:GetPlayers()) do
				local owns=SecurityService.hasCCTV(plr)
				local rig=rigs[plr.UserId]
				if owns then
					local cnt=SecurityService.cameraCount(plr)
					if not rig then pcall(function() spawnRig(plr) end)
					elseif rig.count~=cnt then despawn(plr.UserId); pcall(function() spawnRig(plr) end) end
				elseif rig then despawn(plr.UserId) end
			end
			for uid in pairs(rigs) do if not Players:GetPlayerByUserId(uid) then despawn(uid) end end
			task.wait(3)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) despawn(plr.UserId) end)
	RunService.Heartbeat:Connect(step)
	print("[CCTVService] started")
end
return CCTVService

