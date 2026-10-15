-- SecurityGunService: server-authoritative firing for the armoury guns. The client sends an aim ray
-- (camera origin + direction = the crosshair). We validate (night, owns the gun, it's equipped, off
-- cooldown), raycast, draw a tracer, and apply REAL damage -- to players (via the HP-500/WASTED
-- layer), and to guards / CCTV cameras (their soak Humanoid).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local TweenService=game:GetService("TweenService")
local SecurityService=require(script.Parent.SecurityService)
local SecurityCombatService=require(script.Parent.SecurityCombatService)
local AccessService=require(script.Parent.AccessService)
local Cfg=require(RS.Configs.SecurityConfig)

local SecurityGunService={}
local lastShot={}   -- [uid][gunKey]=os.clock()

local function notify(plr,text,kind) local r=RS:FindFirstChild("Remotes"); local n=r and r:FindFirstChild("Notify"); if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end end

local function tracer(fromPos, toPos)
	local p=Instance.new("Part"); p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(255,225,140)
	local d=(toPos-fromPos).Magnitude; p.Size=Vector3.new(0.15,0.15,math.max(d,0.1))
	p.CFrame=CFrame.lookAt((fromPos+toPos)/2, toPos); p.Parent=workspace
	TweenService:Create(p,TweenInfo.new(0.12),{Transparency=1}):Play(); Debris:AddItem(p,0.13)
end
local function muzzleFlash(pos)
	local f=Instance.new("Part"); f.Anchored=true; f.CanCollide=false; f.CanQuery=false; f.Material=Enum.Material.Neon; f.Color=Color3.fromRGB(255,200,90)
	f.Shape=Enum.PartType.Ball; f.Size=Vector3.new(1.2,1.2,1.2); f.Position=pos; f.Parent=workspace
	TweenService:Create(f,TweenInfo.new(0.08),{Size=Vector3.new(0.1,0.1,0.1),Transparency=1}):Play(); Debris:AddItem(f,0.1)
end

local function equippedGun(plr, gunKey)
	local char=plr.Character; if not char then return nil end
	for _,t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("SecGun")==gunKey then return t end
	end
	return nil
end

local function fire(plr, origin, dir, gunKey)
	local g=Cfg.GunByKey[tostring(gunKey)]; if not g then return end
	if not AccessService.isNight() then return end
	if SecurityCombatService.isOut(plr) then return end
	if not SecurityService.ownsGun(plr, gunKey) then return end
	local tool=equippedGun(plr, gunKey); if not tool then return end
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	-- cooldown
	local cd=g.fireDelay or 0.4
	local lu=lastShot[plr.UserId]; if not lu then lu={}; lastShot[plr.UserId]=lu end
	if lu[gunKey] and (os.clock()-lu[gunKey])<cd then return end
	lu[gunKey]=os.clock()
	-- sanitise aim
	if typeof(dir)~="Vector3" or dir.X~=dir.X or dir.Y~=dir.Y or dir.Z~=dir.Z or dir.Magnitude==math.huge or dir.Magnitude<.01 then return end
 local hum=char:FindFirstChildOfClass("Humanoid");if not hum or hum.Health<=0 then return end
	dir=dir.Unit
	local handle=tool:FindFirstChild("Handle")
	local muzzlePos=(handle and handle.Position) or hrp.Position
	origin=muzzlePos
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={char, tool}
	local res=workspace:Raycast(origin, dir*350, params)
	local hitPos=res and res.Position or (origin+dir*350)
	muzzleFlash(muzzlePos); tracer(muzzlePos, hitPos)
	if res and res.Instance then
		local model=res.Instance:FindFirstAncestorOfClass("Model")
		local hum=model and model:FindFirstChildOfClass("Humanoid")
  while model and not hum do model=model.Parent;if model and model:IsA("Model") then hum=model:FindFirstChildOfClass("Humanoid") end end
		if hum and hum.Health>0 then
			local victim=Players:GetPlayerFromCharacter(model)
			if victim and victim~=plr then
				SecurityCombatService.applyDamage(victim, g.damage, plr)
			elseif not victim then
				if model:GetAttribute("SecGuard") then model:SetAttribute("AggroUserId",plr.UserId);model:SetAttribute("AggroUntil",os.clock()+20) end
                hum:TakeDamage(g.damage)   -- guard NPC or CCTV soak
			end
		end
	end
end

function SecurityGunService.Start()
	local r=RS:WaitForChild("Remotes")
	local ev=r:FindFirstChild("FireGun") or Instance.new("RemoteEvent")
	ev.Name="FireGun"; ev.Parent=r
	ev.OnServerEvent:Connect(function(plr, origin, dir, gunKey) pcall(fire, plr, origin, dir, gunKey) end)
	Players.PlayerRemoving:Connect(function(plr) lastShot[plr.UserId]=nil end)
	print("[SecurityGunService] started")
end
return SecurityGunService

