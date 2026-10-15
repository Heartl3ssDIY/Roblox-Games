-- SecurityService: backend for warehouse defense + armoury, bought from the laptop 'Security' tab
-- (level 15+). Holds each player's security loadout (per-player, applies to their warehouse),
-- validates progressive purchases, spends currency, persists via SaveService, and exposes getters
-- the CCTV/Guard runtime + armoury combat read from.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CurrencyService=require(script.Parent.CurrencyService)
local Cfg=require(RS.Configs.SecurityConfig)

local SecurityService={}
local state={}            -- [uid] = loadout table
local CUR={cash="Cash", crypto="Crypto"}   -- config currency -> CurrencyService kind

local function notify(plr,text,kind)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end
local function levelOf(plr)
	local cur=plr:FindFirstChild("Currency"); local L=cur and cur:FindFirstChild("Level")
	return (L and L.Value) or 0
end

local function blank()
	return {
		cctv=false, cctvUp={}, cameras=0, -- cctvUp[key]=true ; cameras = how many cameras owned (2..5)
		guards=0,   guardUp={},
		guns={},    gun1Name="Gun 1",
	}
end
local function ensure(plr)
	local uid=plr.UserId
	if not state[uid] then state[uid]=blank() end
	return state[uid]
end
function SecurityService.get(plr) return ensure(plr) end

-- ---- progressive helpers ------------------------------------------------
local function prevOwned(ownedSet, order, key)
	local idx=table.find(order, key); if not idx then return false end
	if idx==1 then return true end
	return ownedSet[order[idx-1]]==true
end

local function spend(plr, currency, cost)
	return CurrencyService.Spend(plr, CUR[currency] or currency, cost)
end

-- ---- purchase -----------------------------------------------------------
-- cat: "cctv_unlock" | "cctv" | "guard" | "guard_up" | "gun"
function SecurityService.buy(plr, cat, key)
	if levelOf(plr) < Cfg.UnlockLevel then return {ok=false,msg="Security unlocks at Level "..Cfg.UnlockLevel} end
	local s=ensure(plr)

	if cat=="cctv_unlock" then
		if s.cctv then return {ok=false,msg="CCTV already installed"} end
		if not spend(plr, Cfg.CCTV.unlockCurrency, Cfg.CCTV.unlockPrice) then return {ok=false,msg="Not enough cash"} end
		s.cctv=true; s.cameras=2

	elseif cat=="cctv" then
		if not s.cctv then return {ok=false,msg="Install CCTV first"} end
		local u=Cfg.CctvUpByKey[key]; if not u then return {ok=false,msg="Unknown upgrade"} end
		if s.cctvUp[key] then return {ok=false,msg="Already owned"} end
		if not prevOwned(s.cctvUp, Cfg.CctvOrder, key) then return {ok=false,msg="Buy the previous upgrade first"} end
		if not spend(plr, u.currency, u.price) then return {ok=false,msg="Not enough "..u.currency} end
		s.cctvUp[key]=true

	elseif cat=="camera" then
		if not s.cctv then return {ok=false,msg="Install CCTV first"} end
		local cur=s.cameras or 2
		if cur>=Cfg.CCTV.maxCameras then return {ok=false,msg="Max "..Cfg.CCTV.maxCameras.." cameras"} end
		if not spend(plr, Cfg.CCTV.extraCameraCurrency, Cfg.CCTV.extraCameraPrice) then return {ok=false,msg="Not enough cash"} end
		s.cameras=cur+1

	elseif cat=="guard" then
		if s.guards >= Cfg.Guards.max then return {ok=false,msg="Max "..Cfg.Guards.max.." guards"} end
		if not spend(plr, Cfg.Guards.currency, Cfg.Guards.unitPrice) then return {ok=false,msg="Not enough cash"} end
		s.guards += 1

	elseif cat=="guard_up" then
		if s.guards < 1 then return {ok=false,msg="Hire a guard first"} end
		local u=Cfg.GuardUpByKey[key]; if not u then return {ok=false,msg="Unknown upgrade"} end
		if s.guardUp[key] then return {ok=false,msg="Already owned"} end
		if not prevOwned(s.guardUp, Cfg.GuardOrder, key) then return {ok=false,msg="Buy the previous upgrade first"} end
		if not spend(plr, u.currency, u.price) then return {ok=false,msg="Not enough "..u.currency} end
		s.guardUp[key]=true

	elseif cat=="gun" then
		local g=Cfg.GunByKey[key]; if not g then return {ok=false,msg="Unknown gun"} end
		if s.guns[key] then return {ok=false,msg="Already owned"} end
		if not prevOwned(s.guns, Cfg.GunOrder, key) then return {ok=false,msg="Buy the previous gun first"} end
		if not spend(plr, g.currency, g.price) then return {ok=false,msg="Not enough cash"} end
		s.guns[key]=true
	else
		return {ok=false,msg="Unknown purchase"}
	end

	pcall(function() CurrencyService.SaveNow(plr) end)
	SecurityService.push(plr)
	return {ok=true}
end

function SecurityService.renameGun1(plr, name)
	local s=ensure(plr); if not s.guns.gun1 then return {ok=false,msg="You don't own Gun 1"} end
	name=tostring(name or ""):gsub("%s+$",""):sub(1,18)
	if #name<1 then return {ok=false,msg="Name too short"} end
	s.gun1Name=name
	pcall(function() CurrencyService.SaveNow(plr) end)
	SecurityService.push(plr)
	return {ok=true, name=name}
end

-- ---- computed loadout (read by runtime systems) -------------------------
function SecurityService.cctvRange(plr)
	local s=ensure(plr); if not s.cctv then return 0 end
	local r=Cfg.CCTV.baseRange
	for _,u in ipairs(Cfg.CCTV.upgrades) do if u.addRange and s.cctvUp[u.key] then r+=u.addRange end end
	return r
end
function SecurityService.hasCCTV(plr) return ensure(plr).cctv==true end
function SecurityService.cameraCount(plr) local s=ensure(plr); return s.cctv and (s.cameras or 2) or 0 end
function SecurityService.hasFreeze(plr) return ensure(plr).cctvUp.freeze==true end
function SecurityService.guardCount(plr) return ensure(plr).guards or 0 end
function SecurityService.guardStats(plr)
	local s=ensure(plr); local G=Cfg.Guards
	local health=G.baseHealth; local damage=G.baseDamage; local fireDelay=G.baseFireDelay; local resist=0
	if s.guardUp.firerate then fireDelay=Cfg.GuardUpByKey.firerate.fireDelay end
	if s.guardUp.vest    then resist=Cfg.GuardUpByKey.vest.damageResist end
	if s.guardUp.bettergun then damage=Cfg.GuardUpByKey.bettergun.damage end
	return {health=health, damage=damage, fireDelay=fireDelay, resist=resist}
end
function SecurityService.ownsGun(plr, key) return ensure(plr).guns[key]==true end
function SecurityService.gunName(plr, key)
	if key=="gun1" then return ensure(plr).gun1Name or "Gun 1" end
	local g=Cfg.GunByKey[key]; return g and g.name or key
end

-- ---- client sync + persistence -----------------------------------------
function SecurityService.push(plr)
	local rem=RS:FindFirstChild("Remotes"); local ev=rem and rem:FindFirstChild("SecurityUpdate")
	if ev then ev:FireClient(plr, ensure(plr)) end
end
function SecurityService.getSaved(plr) return state[plr.UserId] end
function SecurityService.loadSaved(plr, data)
	if type(data)=="table" then
		local s=blank()
		s.cctv=data.cctv==true; s.cctvUp=data.cctvUp or {}
		s.guards=tonumber(data.guards) or 0; s.guardUp=data.guardUp or {}
		s.guns=data.guns or {}; s.gun1Name=data.gun1Name or "Gun 1"
		s.cameras=tonumber(data.cameras) or (s.cctv and 2 or 0)
		state[plr.UserId]=s
	end
end
function SecurityService.clear(plr) state[plr.UserId]=nil end

function SecurityService.Start()
	local rem=RS:WaitForChild("Remotes")
	local rf=rem:FindFirstChild("Security") or Instance.new("RemoteFunction")
	rf.Name="Security"; rf.Parent=rem
	if not rem:FindFirstChild("SecurityUpdate") then
		local ev=Instance.new("RemoteEvent"); ev.Name="SecurityUpdate"; ev.Parent=rem
	end
	rf.OnServerInvoke=function(plr, req)
		req=req or {}
		if req.action=="get" then return {ok=true, state=ensure(plr), level=levelOf(plr)} end
		if req.action=="buy" then return SecurityService.buy(plr, req.cat, req.key) end
		if req.action=="rename" then return SecurityService.renameGun1(plr, req.name) end
		return {ok=false,msg="Unknown action"}
	end
	Players.PlayerRemoving:Connect(function(plr) state[plr.UserId]=nil end)
	print("[SecurityService] started")
end
return SecurityService

