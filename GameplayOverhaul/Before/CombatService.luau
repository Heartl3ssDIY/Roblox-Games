-- CombatService: the black-market weapon layer. Gives owned weapon tools (event-gated), and on
-- Tool.Activated finds the target the attacker is facing and applies a server-authoritative effect.
-- Immunity + speed potions are honoured here. The Magic Carpet is a self-contained tool (its own
-- scripts handle flight) cloned from ServerStorage.MagicCarpet.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local BlackMarketConfig=require(RS.Configs.BlackMarketConfig)
local BlackMarketService=require(script.Parent.BlackMarketService)
local SpecialTruckService=require(script.Parent.SpecialTruckService)
local PlotService=require(script.Parent.PlotService)
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
-- Player-supplied tool models live in ServerStorage; cloned on equip. Carpet self-handles flight
-- (Pilot script); slap/freeze keep our server-authoritative effect on Activated.
local TEMPLATES={carpet="MagicCarpet", slap="SlapTool", freeze="FreezeRay", gun="GunTool", bat="BatTool", speed="SpeedPotion", immunity="ImmunityPotion"}
local function templateFor(key) local n=TEMPLATES[key]; return n and ServerStorage:FindFirstChild(n) or nil end

local CombatService={}
local lastUse={}   -- [uid][key]=os.clock() for cooldowns

local function notify(plr,text,kind)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end
local function isImmune(plr)
	return (plr:GetAttribute("ImmuneUntil") or 0) > os.time()   -- set by drinking the Immunity Potion
end

-- effects (server-authoritative) --------------------------------------------------
local function ragdoll(plr, secs)
	local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	hum.PlatformStand=true
	local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,28,0) end
	plr:SetAttribute("RagdollUntil", os.time()+secs)
	task.delay(secs, function()
		if (plr:GetAttribute("RagdollUntil") or 0) > os.time() then return end   -- a newer ragdoll extended it
		local c=plr.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Parent then h.PlatformStand=false; pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
	end)
end
local function freeze(plr, secs)
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not hrp then return end
	local ex=char:FindFirstChild("FrostFX"); if ex then ex:Destroy() end
	if hum then hum.WalkSpeed=0; hum.JumpPower=0 end
	hrp.Anchored=true
	local frost=Instance.new("Highlight"); frost.Name="FrostFX"; frost.FillColor=Color3.fromRGB(150,225,255)
	frost.FillTransparency=0.45; frost.OutlineColor=Color3.fromRGB(225,245,255); frost.Parent=char
	plr:SetAttribute("FrozenUntil", os.time()+secs)
	task.delay(secs, function()
		if (plr:GetAttribute("FrozenUntil") or 0) > os.time() then return end   -- a newer freeze extended it
		if hrp and hrp.Parent then hrp.Anchored=false end
		local c=plr.Character
		local fr=c and c:FindFirstChild("FrostFX"); if fr then fr:Destroy() end
		local h=c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Parent then
			h.JumpPower=50; h.PlatformStand=false
			h.WalkSpeed = ((plr:GetAttribute("SpeedBoostUntil") or 0) > os.time()) and 32 or 16   -- restore directly (refreshTools' guard skips a WalkSpeed of 0)
			pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
	end)
end
local function sendHome(plr)
	local plot=PlotService.forPlayer(plr); if plot then pcall(function() PlotService.teleportToPlot(plr, plot) end) end
end
-- (slap swing is client-side -- see the SwingFX LocalScript inside the Slap Tool -- because the
-- player's character joints are network-owned by the client and the server can't write their C0.)
-- freeze-ray VFX: a cyan neon beam from shooter to target (the icy highlight is added in freeze())
local function freezeBeam(attacker, target)
	local ahrp=attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	local thrp=target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not (ahrp and thrp) then return end
	local p=Instance.new("Part")
	p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(130,225,255); p.Transparency=0.1
	local d=(thrp.Position-ahrp.Position).Magnitude
	p.Size=Vector3.new(0.35,0.35,math.max(d,0.1))
	p.CFrame=CFrame.lookAt((ahrp.Position+thrp.Position)/2, thrp.Position)
	p.Parent=workspace
	TweenService:Create(p,TweenInfo.new(0.35),{Transparency=1, Size=Vector3.new(0.05,0.05,math.max(d,0.1))}):Play()
	Debris:AddItem(p,0.4)
end

-- find the other player the attacker is facing, within range
local function findTarget(attacker)
	local char=attacker.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
	local best,bestd
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=attacker and p.Character then
			local thrp=p.Character:FindFirstChild("HumanoidRootPart")
			if thrp then
				local to=thrp.Position-hrp.Position; local dist=to.Magnitude
				if dist<=16 and hrp.CFrame.LookVector:Dot(to.Unit)>0.25 and (not best or dist<bestd) then best=p; bestd=dist end
			end
		end
	end
	return best
end

local function handleUse(attacker, key)
	local it=BlackMarketConfig.ByKey[key]; if not it then return end
	if it.eventOnly and not SpecialTruckService.isActive() then notify(attacker,"Only usable during a gift-truck event.","error"); return end
	-- can't act while ragdolled or frozen (slapped players can't slap back until they recover)
	local achar=attacker.Character
	local ahum=achar and achar:FindFirstChildOfClass("Humanoid")
	if ahum and ahum.PlatformStand then return end
	local ahrp0=achar and achar:FindFirstChild("HumanoidRootPart")
	if ahrp0 and ahrp0.Anchored then return end
	local cd=lastUse[attacker.UserId] or {}; lastUse[attacker.UserId]=cd
	if key=="gun" and cd.gun and (os.clock()-cd.gun)<15 then
		notify(attacker,"Gun on cooldown ("..math.ceil(15-(os.clock()-cd.gun)).."s)","error"); return
	end
	local target=findTarget(attacker); if not target then notify(attacker,"No one in range/aim.","error"); return end
	if isImmune(target) then notify(attacker, (target.DisplayName or target.Name).." is immune!","error"); return end
	if key=="slap" then ragdoll(target,5)
	elseif key=="freeze" then freeze(target,15); freezeBeam(attacker,target)
	elseif key=="bat" then SpecialTruckService.dropCarried(target); ragdoll(target,5)
	elseif key=="gun" then sendHome(target); cd.gun=os.clock()
	else return end
end

-- tool creation + (re)equip --------------------------------------------------------
local function makeTool(key, name)
	local tool=Instance.new("Tool"); tool.Name=name; tool:SetAttribute("WeaponKey", key)
	tool.RequiresHandle=true; tool.CanBeDropped=false
	local handle=Instance.new("Part"); handle.Name="Handle"; handle.Size=Vector3.new(1,1,3); handle.Color=Color3.fromRGB(40,40,48); handle.Parent=tool
	return tool
end

-- Drink a consumable potion: 30s timed buff, then the charge is used up (must rebuy). Event-gated.
local POTION_SECS=30
local function drinkPotion(plr, key)
	if not SpecialTruckService.isActive() then notify(plr,"Only usable during a gift-truck event.","error"); return end
	if BlackMarketService.owned(plr)[key]~=true then return end
	local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
	if key=="speed" then
		plr:SetAttribute("SpeedBoostUntil", os.time()+POTION_SECS)
		if hum and not hum.PlatformStand and hum.WalkSpeed~=0 then hum.WalkSpeed=32 end
		notify(plr,"Speed Potion: x2 speed for "..POTION_SECS.."s!","success")
	elseif key=="immunity" then
		plr:SetAttribute("ImmuneUntil", os.time()+POTION_SECS)
		notify(plr,"Immunity Potion: immune to attacks for "..POTION_SECS.."s!","success")
	else return end
	BlackMarketService.consume(plr, key)   -- one charge -- must rebuy
	local cfg=BlackMarketConfig.ByKey[key]
	for _,where in ipairs({char, plr:FindFirstChildOfClass("Backpack")}) do
		local t=where and cfg and where:FindFirstChild(cfg.name); if t then t:Destroy() end
	end
end

function CombatService.refreshTools(plr)
	local char=plr.Character; if not char then return end
	local backpack=plr:FindFirstChildOfClass("Backpack"); if not backpack then return end
	local owned=BlackMarketService.owned(plr)
	local eventActive=SpecialTruckService.isActive()
	for _,it in ipairs(BlackMarketConfig.Items) do
		if it.kind=="tool" then
			local shouldHave = owned[it.key]==true and ((not it.eventOnly) or eventActive)
			local existing = char:FindFirstChild(it.name) or backpack:FindFirstChild(it.name)
			if shouldHave and not existing then
				local tmpl=templateFor(it.key)
				local tool
				if tmpl then tool=tmpl:Clone(); tool.Name=it.name   -- player's own model (carpet / slap / freeze)
				else tool=makeTool(it.key, it.name) end
				if it.key~="carpet" then tool.Activated:Connect(function() handleUse(plr, it.key) end) end
				tool.Parent=backpack
			elseif (not shouldHave) and existing then existing:Destroy() end
		elseif it.kind=="potion" then
			local pHave = owned[it.key]==true and eventActive
			local pExist = char:FindFirstChild(it.name) or backpack:FindFirstChild(it.name)
			if pHave and not pExist then
				local tmpl=templateFor(it.key)
				local tool = tmpl and tmpl:Clone() or makeTool(it.key, it.name)
				if tmpl then tool.Name=it.name end
				tool.Activated:Connect(function() drinkPotion(plr, it.key) end)
				tool.Parent=backpack
			elseif (not pHave) and pExist then pExist:Destroy() end
		end
	end
	local hum=char:FindFirstChildOfClass("Humanoid")
	-- carpet is event-only: if still riding when the carpet tool is gone (event ended), drop them off
	if hum and hum.SeatPart and hum.SeatPart.Name=="Saddle" then
		local hasCarpet = char:FindFirstChild("Magic Carpet") or backpack:FindFirstChild("Magic Carpet")
		if not hasCarpet then
			local rig=hum.SeatPart.Parent
			hum.Sit=false; hum.Jump=true
			if rig and rig.Name=="CarpetRig" then rig:Destroy() end
		end
	end
	if hum and not hum.PlatformStand and hum.WalkSpeed~=0 then
		hum.WalkSpeed = ((plr:GetAttribute("SpeedBoostUntil") or 0) > os.time()) and 32 or 16
	end
end

function CombatService.Start()
	local function hook(plr)
		plr.CharacterAdded:Connect(function(char)
			plr:SetAttribute("FrozenUntil", nil); plr:SetAttribute("RagdollUntil", nil)   -- respawn clears stuck state
			local hrp=char:WaitForChild("HumanoidRootPart",5); if hrp then hrp.Anchored=false end
			task.wait(0.6); CombatService.refreshTools(plr)
		end)
		if plr.Character then task.spawn(function() CombatService.refreshTools(plr) end) end
	end
	Players.PlayerAdded:Connect(hook)
	for _,plr in ipairs(Players:GetPlayers()) do hook(plr) end
	Players.PlayerRemoving:Connect(function(plr) lastUse[plr.UserId]=nil end)
	-- re-equip event tools + apply speed when the event turns on/off
	task.spawn(function() while true do task.wait(3); for _,plr in ipairs(Players:GetPlayers()) do CombatService.refreshTools(plr) end end end)
	print("[CombatService] started")
end
return CombatService

