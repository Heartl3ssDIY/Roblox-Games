-- GuardService: spawns each owner's hired guards (1-2) AT NIGHT. They patrol a fixed loop around the
-- outside of the warehouse, stop when a player comes near, and only open fire if provoked (the intruder
-- is carrying stolen parcels, or the guard has been shot). 150 HP (300 with vest); a killed guard
-- stays down until the NEXT night. Upgrades (rapid fire / vest / better gun) apply to both guards.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local PlotService=require(script.Parent.PlotService)
local SecurityService=require(script.Parent.SecurityService)
local SecurityCombatService=require(script.Parent.SecurityCombatService)
local ManualLoadService=require(script.Parent.ManualLoadService)
local AccessService=require(script.Parent.AccessService)
local Cfg=require(RS.Configs.SecurityConfig)

local GuardService={}
local rigs={}              -- [ownerUserId] = { guards={ {model=,hum=,slot=,wp=1,nextShot=0,aggroUntil=0}, ...}, killedThisNight=0 }
local function models() return ServerStorage:FindFirstChild("SecurityModels") end
local function notify(plr,text,kind) local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify"); if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end end

-- footprint of a plot (axis-aligned bbox of its warehouse folder) -> center + half extents
local function footprint(plot)
	local folder=plot.LoadBays and plot.LoadBays.Parent; if not folder then return nil end
	local minv=Vector3.new(1e9,1e9,1e9); local maxv=Vector3.new(-1e9,-1e9,-1e9)
	for _,d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.Y>=4 then   -- only WALLS/pillars define the building outline (incl. office)
			local nmSelf=d.Name
			local skip = (nmSelf=="DriveLine" or nmSelf=="LaneL" or nmSelf=="LaneR" or nmSelf=="Lane" or nmSelf=="Hz")
			if not skip then local a=d.Parent
				while a and a~=folder do local nm=a.Name; if nm=="Trucks" or nm=="Workers" then skip=true break end a=a.Parent end
			end
			if not skip then
				local p=d.Position; local s=d.Size/2
				minv=Vector3.new(math.min(minv.X,p.X-s.X),math.min(minv.Y,p.Y-s.Y),math.min(minv.Z,p.Z-s.Z))
				maxv=Vector3.new(math.max(maxv.X,p.X+s.X),math.max(maxv.Y,p.Y+s.Y),math.max(maxv.Z,p.Z+s.Z))
			end
		end
	end
	if minv.X>maxv.X then return nil end
	local center=(minv+maxv)/2
	return center, (maxv-minv)/2, minv.Y
end
-- a loop AROUND the OUTSIDE of the whole building (hall + office wing), offset clear of every wall
local function waypoints(plot)
	local c,ext,baseY=footprint(plot); if not c then return {} end
	local pad=8
	local y=(baseY or 0)+3
	local hx=ext.X+pad; local hz=ext.Z+pad
	return {
		Vector3.new(c.X+hx, y, c.Z+hz), Vector3.new(c.X-hx, y, c.Z+hz),
		Vector3.new(c.X-hx, y, c.Z-hz), Vector3.new(c.X+hx, y, c.Z-hz),
	}
end

local function attachGun(model, better)
	local m=models(); if not m then return end
	local src=better and m:FindFirstChild("GuardGunBetter") or m:FindFirstChild("GuardGun")
	if not src then return end
	local hand=model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm"); if not hand then return end
	local gun=src:Clone()
	local base=gun:IsA("Model") and (gun.PrimaryPart or gun:FindFirstChild("Main") or gun:FindFirstChildWhichIsA("BasePart")) or gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
	if gun:IsA("Tool") then
		-- flatten the tool into a held model
		local holder=Instance.new("Model"); holder.Name="GuardWeapon"
		for _,c in ipairs(gun:GetChildren()) do if c:IsA("BasePart") then c.Parent=holder end end
		gun:Destroy(); gun=holder; base=holder:FindFirstChild("Handle") or holder:FindFirstChildWhichIsA("BasePart")
	end
	if not base then gun:Destroy(); return end
	for _,d in ipairs(gun:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false; d.CanCollide=false; d.Massless=true end end
	base.CFrame=hand.CFrame*CFrame.new(0,-0.2,-0.6)*CFrame.Angles(math.rad(-90),0,0)
	for _,d in ipairs(gun:GetDescendants()) do if d:IsA("BasePart") and d~=base then local w=Instance.new("WeldConstraint"); w.Part0=base; w.Part1=d; w.Parent=base end end
	-- Motor6D the gun to the hand so it tracks the (anchored, CFrame-driven) rig with no physics lag
	base.Massless=true
	local mw=Instance.new("Motor6D"); mw.Name="GunMotor"; mw.Part0=hand; mw.Part1=base
	mw.C0=CFrame.new(0,-0.25,-0.9)*CFrame.Angles(math.rad(-90),0,0); mw.Parent=hand
	gun.Name="GuardWeapon"; gun.Parent=model
	return base
end

local function muzzleTracer(fromPos, toPos)
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(255,220,120)
	local d=(toPos-fromPos).Magnitude; p.Size=Vector3.new(0.12,0.12,math.max(d,0.1))
	p.CFrame=CFrame.lookAt((fromPos+toPos)/2,toPos); p.Parent=workspace
	Debris:AddItem(p,0.08)
end

local function spawnGuard(owner, slot)
	local plot=PlotService.forPlayer(owner); if not plot then return end
	local wps=waypoints(plot); if #wps==0 then return end
	local m=models(); local src=m and m:FindFirstChild(slot==1 and "Guard1" or "Guard2"); if not src then return end
	local model=src:Clone()
	local hum=model:FindFirstChildOfClass("Humanoid"); if not hum then model:Destroy(); return end
	local stats=SecurityService.guardStats(owner)
	local hp=Cfg.Guards.baseHealth*((stats.resist>0) and (1/(1-stats.resist)) or 1)
	hum.MaxHealth=hp; hum.Health=hp; hum.WalkSpeed=10
	hum.EvaluateStateMachine=false; hum.AutoRotate=false
	model:SetAttribute("LabelOwner", owner.UserId)
	model:SetAttribute("SecGuard", true)
	-- anchored-HRP, CFrame-driven rig (limbs ride along via their Motor6Ds; never shoves the player)
	local grHrp=model:FindFirstChild("HumanoidRootPart")
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide=false; d.Massless=true; pcall(function() d.CollisionGroup="NPCs" end); d.Anchored=(d==grHrp) end
	end
	local startWp=(slot==1) and 1 or 3
	local start=wps[startWp] or wps[1]
	model:PivotTo(CFrame.new(start))
	model.Parent=workspace
	local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local walkTrack
	pcall(function() local a=Instance.new("Animation"); a.AnimationId="rbxassetid://913402848"; walkTrack=animator:LoadAnimation(a); walkTrack.Looped=true; walkTrack.Priority=Enum.AnimationPriority.Movement end)
	local g_wps=wps
	attachGun(model, SecurityService.get(owner).guardUp.bettergun==true)
	if stats.resist>0 then  -- vest visual
		local vest=m:FindFirstChild("Vest")
		if vest and vest:IsA("Accessory") then pcall(function() hum:AddAccessory(vest:Clone()) end) end
	end
	local g={model=model, hum=hum, slot=slot, wp=startWp, nextShot=0, owner=owner, wps=g_wps, dir=((slot==1) and 1 or -1), walkTrack=walkTrack}
	hum.Died:Connect(function()
		local rig=rigs[owner.UserId]; if rig then rig.downed=(rig.downed or 0)+1 end
		notify(owner,"A guard was taken down -- back next night.","error")
		task.delay(3,function() if model and model.Parent then model:Destroy() end end)
	end)
	return g
end

local function despawnRig(uid)
	local rig=rigs[uid]; if not rig then return end
	for _,g in ipairs(rig.guards) do if g.model and g.model.Parent then g.model:Destroy() end end
	rigs[uid]=nil
end

-- nearest non-owner player to a position
local function nearestIntruder(owner, pos, maxd)
	local best,bd
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=owner and p.Character and not SecurityCombatService.isOut(p) then
			local hrp=p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then local d=(hrp.Position-pos).Magnitude; if d<=maxd and (not best or d<bd) then best=p; bd=d end end
		end
	end
	return best,bd
end

local function stepGuard(g, dt)
	local model=g.model; local hum=g.hum
	if not (model and model.Parent and hum and hum.Health>0) then return end
	local hrp=model:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local owner=g.owner
	if owner and SecurityCombatService.isOut(owner) then return end   -- owner WASTED: stand down
	local stats=SecurityService.guardStats(owner)
	local target,td=nearestIntruder(owner, hrp.Position, Cfg.Guards.engageRange)
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
		if g.walkTrack and g.walkTrack.IsPlaying then g.walkTrack:Stop() end
		local thrp=target.Character.HumanoidRootPart
		local look=Vector3.new(thrp.Position.X-hrp.Position.X,0,thrp.Position.Z-hrp.Position.Z)
		if look.Magnitude>0.1 then hrp.CFrame=CFrame.new(hrp.Position, hrp.Position+look.Unit) end
		local provoked=(ManualLoadService.carryCount(target)>0) or (hum.Health<hum.MaxHealth)
		if provoked and td<=Cfg.Guards.shootRange and os.clock()>=g.nextShot then
			g.nextShot=os.clock()+stats.fireDelay
			local gun=model:FindFirstChild("GuardWeapon")
			local muzzle=gun and (gun:FindFirstChild("Muzzle") or gun:FindFirstChildWhichIsA("BasePart")) or hrp
			muzzleTracer(muzzle.Position, thrp.Position)
			if math.random()<=Cfg.Guards.hitChance then SecurityCombatService.applyDamage(target, stats.damage, owner) end
		end
	else
		-- the owner's CCTV may have flagged a thief -> head straight to that position; else patrol
		local markPos
		for _,p in ipairs(Players:GetPlayers()) do
			if p~=owner and p.Character and p:GetAttribute("SeenByCCTVOwner")==owner.UserId and (os.time()-(p:GetAttribute("SeenByCCTV") or 0))<=4 then
				local php=p.Character:FindFirstChild("HumanoidRootPart")
				if php and (php.Position-hrp.Position).Magnitude<=90 then markPos=php.Position; break end
			end
		end
		local dest, patrolling
		if markPos then dest=Vector3.new(markPos.X, hrp.Position.Y, markPos.Z)
		else local wps=g.wps; if not wps or #wps==0 then return end; dest=wps[g.wp]; patrolling=true end
		local cur=hrp.Position
		local fx,fz=dest.X-cur.X, dest.Z-cur.Z
		local dist=math.sqrt(fx*fx+fz*fz)
		local stepd=(markPos and 13 or 10)*dt
		if dist<=stepd or dist<0.1 then
			if patrolling then g.wp=((g.wp-1+(g.dir or 1)) % #g.wps)+1 end
		else
			if g.walkTrack and not g.walkTrack.IsPlaying then g.walkTrack:Play() end
			local inv=stepd/dist
			local nx,nz=cur.X+fx*inv, cur.Z+fz*inv
			hrp.CFrame=CFrame.new(Vector3.new(nx,dest.Y,nz), Vector3.new(nx+fx,dest.Y,nz+fz))
		end
	end
end

function GuardService.Start()
	local lastNight=false
	RunService.Heartbeat:Connect(function(dt)
		for _,rig in pairs(rigs) do for _,g in ipairs(rig.guards) do pcall(stepGuard,g,dt) end end
	end)
	task.spawn(function()
		while true do
			local night=AccessService.isNight()
			-- guards are a NIGHT defense: they spawn + patrol only at night, and stand down by day.
			if night then
				for _,plr in ipairs(Players:GetPlayers()) do
					local n=SecurityService.guardCount(plr)
					if n>0 then
						local rig=rigs[plr.UserId]
						if not rig then rig={guards={}, downed=0}; rigs[plr.UserId]=rig end
						if not lastNight then rig.downed=0 end   -- fresh night: downed guards return
						local alive={}
						for _,g in ipairs(rig.guards) do if g.model and g.model.Parent and g.hum and g.hum.Health>0 then alive[#alive+1]=g end end
						rig.guards=alive
						local want=math.max(0, n-(rig.downed or 0))
						while #rig.guards < want do
							local g=spawnGuard(plr, #rig.guards+1)
							if g then rig.guards[#rig.guards+1]=g else break end
						end
					elseif rigs[plr.UserId] then despawnRig(plr.UserId) end
				end
			elseif lastNight then
				for uid in pairs(rigs) do despawnRig(uid) end   -- day: stand down
			end
			lastNight=night
			-- offline-while-owner-out: hide/show
			for uid,rig in pairs(rigs) do
				local owner=Players:GetPlayerByUserId(uid)
				local out= owner and SecurityCombatService.isOut(owner)
				for _,g in ipairs(rig.guards) do if g.model and g.model.Parent then for _,d in ipairs(g.model:GetDescendants()) do if d:IsA("BasePart") then d.LocalTransparencyModifier=0 end end; local h=g.model:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed= out and 0 or 10 end end end
			end
			task.wait(2)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr) despawnRig(plr.UserId) end)
	print("[GuardService] started")
end
return GuardService

