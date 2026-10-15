-- SecurityCombatService: the real-damage layer for the night security system.
--  * At NIGHT every player's max health becomes SecurityConfig.NightHealth (500); by day it is normal.
--  * applyDamage()/tagHit() are called by guards + (indirectly) the armoury guns.
--  * On a security-context death the player is WASTED: a full-screen death overlay + countdown shows,
--    they're locked out for SecurityConfig.DeathTimeout (60s), and while out their CCTV + guards go
--    offline (other systems read SecurityCombatService.isOut(owner)).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local AccessService=require(script.Parent.AccessService)
local Cfg=require(RS.Configs.SecurityConfig)

local SecurityCombatService={}
local NORMAL_HP=100
local NORMAL_RESPAWN=3   -- seconds for an ordinary (non-security) death to respawn

local function remotes() return RS:FindFirstChild("Remotes") end
local function fire(name, plr, payload)
	local r=remotes(); local e=r and r:FindFirstChild(name)
	if e then e:FireClient(plr, payload) end
end
local function notify(plr,text,kind) fire("Notify", plr, {text=text,kind=kind or "info"}) end

local function isImmune(plr) return (plr:GetAttribute("ImmuneUntil") or 0) > os.time() end
function SecurityCombatService.isOut(plr)
	return plr and (plr:GetAttribute("SecDeadUntil") or 0) > os.time()
end

-- ---- night health scaling ----------------------------------------------
local function applyHealthFor(plr, night)
	local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local want = night and Cfg.NightHealth or NORMAL_HP
	if hum.MaxHealth~=want then
		local frac = hum.MaxHealth>0 and (hum.Health/hum.MaxHealth) or 1
		hum.MaxHealth = want
		-- going INTO night: top them up; coming OUT: keep proportional but never above new max
		hum.Health = night and want or math.min(hum.Health, want)
		if night then hum.Health=want end
	end
end

-- ---- damage + death ----------------------------------------------------
-- Record that an attacker hit a victim recently (for kill credit + to confirm a security death).
function SecurityCombatService.tagHit(victim, attacker)
	if not victim then return end
	victim:SetAttribute("SecHitUntil", os.time()+8)
	if attacker then victim:SetAttribute("SecLastAttacker", attacker.UserId) end
end

-- Apply server-authoritative damage (used by guards; the gun kits damage Humanoids directly).
function SecurityCombatService.applyDamage(victim, amount, attacker)
	if not victim or SecurityCombatService.isOut(victim) then return end
	if not AccessService.isNight() then return end          -- security combat is night-only
	if isImmune(victim) then return end
	local char=victim.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health<=0 then return end
	SecurityCombatService.tagHit(victim, attacker)
	hum:TakeDamage(amount)
end

local function killCreditName(plr)
	local uid=plr:GetAttribute("SecLastAttacker")
	if not uid then return nil end
	local a=Players:GetPlayerByUserId(uid); return a and (a.DisplayName or a.Name) or nil
end

-- Put a player into the WASTED state. Respawn is BLOCKED until the timer ends -- we own respawn
-- (Players.CharacterAutoLoads is off), so the downed player must wait out the full DeathTimeout.
function SecurityCombatService.wast(plr)
	if SecurityCombatService.isOut(plr) then return end
	local secs=Cfg.DeathTimeout
	plr:SetAttribute("SecDeadUntil", os.time()+secs)
	fire("SecurityDeath", plr, {secs=secs, by=killCreditName(plr)})
	pcall(function() require(script.Parent.ManualLoadService).dropCarried(plr) end)
end

-- respawn a player now: clear the WASTED flag, tell the client to lift the overlay, load a fresh body
local function respawn(plr)
	if not plr.Parent then return end
	plr:SetAttribute("SecDeadUntil", nil)
	fire("SecurityRevive", plr, {})
	pcall(function() plr:LoadCharacter() end)
end

local function hookCharacter(plr, char)
	local hum=char:WaitForChild("Humanoid",5); if not hum then return end
	applyHealthFor(plr, AccessService.isNight())
	hum.Died:Connect(function()
		-- a death AT NIGHT is a security death -> WASTED, blocked from respawning for the full timer.
		local secDeath = AccessService.isNight()
		if secDeath then SecurityCombatService.wast(plr) end
		local wait = secDeath and Cfg.DeathTimeout or NORMAL_RESPAWN
		task.delay(wait, function() respawn(plr) end)
	end)
end

function SecurityCombatService.Start()
	-- ensure the death/revive remotes exist
	local r=RS:WaitForChild("Remotes")
	for _,n in ipairs({"SecurityDeath","SecurityRevive"}) do
		if not r:FindFirstChild(n) then local e=Instance.new("RemoteEvent"); e.Name=n; e.Parent=r end
	end
	-- We OWN respawn so a WASTED player cannot respawn before the timer ends.
	Players.CharacterAutoLoads=false
	local function hook(plr)
		plr.CharacterAdded:Connect(function(char) task.spawn(function() hookCharacter(plr, char) end) end)
		if plr.Character then task.spawn(function() hookCharacter(plr, plr.Character) end)
		elseif not SecurityCombatService.isOut(plr) then pcall(function() plr:LoadCharacter() end) end
	end
	Players.PlayerAdded:Connect(hook)
	for _,plr in ipairs(Players:GetPlayers()) do hook(plr) end
	-- safety watchdog: any player with no body who isn't serving a WASTED timer gets respawned
	task.spawn(function()
		while true do
			task.wait(4)
			for _,plr in ipairs(Players:GetPlayers()) do
				if not SecurityCombatService.isOut(plr) then
					local need = (plr.Character==nil)
					local h=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if h and h.Health<=0 then need=true end   -- dead body lingering past the timer
					if need then pcall(function() plr:LoadCharacter() end) end
				end
			end
		end
	end)
	-- watch the day/night flip to rescale everyone's health
	local lastNight=AccessService.isNight()
	task.spawn(function()
		while true do
			task.wait(2)
			local night=AccessService.isNight()
			if night~=lastNight then
				lastNight=night
				for _,plr in ipairs(Players:GetPlayers()) do applyHealthFor(plr, night) end
			end
		end
	end)
	print("[SecurityCombatService] started")
end
return SecurityCombatService

