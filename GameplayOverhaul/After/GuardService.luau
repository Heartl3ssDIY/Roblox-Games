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

local Motion=require(script.Parent.PackageService).Motion
local GuardService={}
local rigs={}              -- [ownerUserId] = { guards={ {model=,hum=,slot=,wp=1,nextShot=0,aggroUntil=0}, ...}, killedThisNight=0 }
local function models() return ServerStorage:FindFirstChild("SecurityModels") end
local function notify(plr,text,kind) local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify"); if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end end

-- footprint of a plot (axis-aligned bbox of its warehouse folder) -> center + half extents
local function waypoints(plot)
 local visuals=plot.wh:FindFirstChild("WarehouseVisuals")
 if not visuals then return {} end
 local low=Vector3.new(math.huge,0,math.huge);local high=-low
 for _,p in visuals:GetDescendants() do
  if p:IsA("BasePart") and p.CanCollide and p.Name:find("Wall") then
   for _,x in {-1,1} do for _,z in {-1,1} do
    local q=plot.frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(p.Size.X*x/2,0,p.Size.Z*z/2)))
    low=Vector3.new(math.min(low.X,q.X),0,math.min(low.Z,q.Z));high=Vector3.new(math.max(high.X,q.X),0,math.max(high.Z,q.Z))
   end end
  end
 end
 if low.X==math.huge then return {} end
 local result={}
 for _,q in {Vector3.new(high.X+8,0,high.Z+8),Vector3.new(low.X-8,0,high.Z+8),Vector3.new(low.X-8,0,low.Z-8),Vector3.new(high.X+8,0,low.Z-8)} do
  local p=plot.frame:PointToWorldSpace(q);table.insert(result,Vector3.new(p.X,PlotService.floorY(plot)+3,p.Z))
 end
 return result
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
	local target=hand.CFrame*CFrame.new(0,-0.25,-0.9)*CFrame.Angles(math.rad(-90),0,0)
 local delta=target*base.CFrame:Inverse()
 for _,p in gun:GetDescendants() do if p:IsA("BasePart") then p.CFrame=delta*p.CFrame end end
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
	Motion.prepare(model)
 local walkTrack
	local g_wps=wps
	attachGun(model, SecurityService.get(owner).guardUp.bettergun==true)
	if stats.resist>0 then  -- vest visual
		local vest=m:FindFirstChild("Vest")
		if vest and vest:IsA("Accessory") then pcall(function() hum:AddAccessory(vest:Clone()) end) end
	end
	local g={plot=plot,hrp=grHrp,model=model, hum=hum, slot=slot, wp=startWp, nextShot=0, owner=owner, wps=g_wps, dir=((slot==1) and 1 or -1), walkTrack=walkTrack}
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
local function stepGuard(g,dt)
 local model,hum,root=g.model,g.hum,g.hrp
 if not model.Parent or hum.Health<=0 or not root then return end
 model:SetAttribute("GuardAiming",false)
 if SecurityCombatService.isOut(g.owner) then return end
 local target,nearest
 for _,p in Players:GetPlayers() do
  local char=p.Character;local h=char and char:FindFirstChildOfClass("Humanoid");local r=char and char:FindFirstChild("HumanoidRootPart")
  local hostile=ManualLoadService.stolenCount(p,g.owner.UserId)>0 or (model:GetAttribute("AggroUserId")==p.UserId and (model:GetAttribute("AggroUntil") or 0)>os.clock())
  if p~=g.owner and hostile and h and h.Health>0 and r and not SecurityCombatService.isOut(p) then
   local d=(r.Position-root.Position).Magnitude
   if d<=Cfg.Guards.engageRange and (not nearest or d<nearest) and Motion.visible(root.Position,r.Position,{model},char) then target=p;nearest=d end
  end
 end
 if target then
  local r=target.Character.HumanoidRootPart
  local look=Vector3.new(r.Position.X-root.Position.X,0,r.Position.Z-root.Position.Z)
  if look.Magnitude>.01 then root.CFrame=CFrame.lookAt(root.Position,root.Position+look) end
  model:SetAttribute("GuardAiming",true)
  local stats=SecurityService.guardStats(g.owner)
  if nearest<=Cfg.Guards.shootRange and os.clock()>=g.nextShot then
   g.nextShot=os.clock()+stats.fireDelay
   local start=root.Position+Vector3.new(0,.5,0)+root.CFrame.LookVector*1.8
   if Motion.visible(start,r.Position,{model},target.Character) then
    muzzleTracer(start,r.Position)
    if math.random()<=Cfg.Guards.hitChance then SecurityCombatService.applyDamage(target,stats.damage,g.owner) end
   end
  end
 elseif Motion.move(g,g.wps[g.wp],10,dt) then g.wp=((g.wp-1+g.dir)%#g.wps)+1 end
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

