-- SecurityConfig: warehouse defense + armoury. Bought from the laptop 'Security' tab (level 15+,
-- separate from the Black Market). Three tracks -- CCTV, Guards, Armoury -- each PROGRESSIVE
-- (can't buy an upgrade without the one before it). Upgrades apply fleet-wide (both cameras / both
-- guards at once). Player max health becomes NightHealth during the night only.
local SecurityConfig = {}

SecurityConfig.UnlockLevel = 15            -- level required to open the Security tab
SecurityConfig.NightHealth = 500           -- player max HP at night (normal otherwise)
SecurityConfig.DeathTimeout = 60           -- seconds a killed player is timed-out (WASTED)

-- ===== CCTV ============================================================
-- One purchase unlocks BOTH cameras. They mount on the outside warehouse wall facing the
-- town-centre / incoming-bays side and sweep a red vision cone. A detected intruder pings the
-- owner and (if owned) the guards. The freeze upgrade freezes a detected thief WHO IS CARRYING
-- stolen packages.
SecurityConfig.CCTV = {
	unlockPrice = 500000, unlockCurrency = "cash",   -- installs the first 2 cameras
	extraCameraPrice = 100000, extraCameraCurrency = "cash",   -- each camera after the first 2
	maxCameras = 5,
	baseRange   = 42,      -- stud reach of the cone
	coneAngle   = 55,      -- full cone angle (degrees)
	sweepPeriod = 4.0,     -- seconds for one left-right sweep
	scanHz      = 4,       -- detection checks per second
	-- progressive, in order:
	upgrades = {
		{ key="range1", name="Extended Range I",  price=150000, currency="cash",   addRange=24 },
		{ key="range2", name="Extended Range II", price=450000, currency="cash",   addRange=34 },
		{ key="freeze", name="Freeze Ray",        price=75,     currency="crypto", freezeSecs=15, freezeCooldown=15 },   -- same freeze as the gun; 15s cd after target thaws
	},
}

-- ===== GUARDS ==========================================================
-- Up to 2, bought one at a time. They patrol a fixed outdoor loop around the warehouse, stop when
-- a player comes near, and only open fire if attacked first OR the intruder grabs a package.
-- 150 HP; a killed guard returns next night. Upgrades apply to both guards.
SecurityConfig.Guards = {
	unitPrice = 200000, currency = "cash", max = 2,
	baseHealth = 150, baseDamage = 10, baseFireDelay = 1.0,   -- 1 shot / second
	engageRange = 26,   -- stop patrolling + face a player this close
	shootRange  = 55,
	hitChance   = 0.7,  -- shots can miss (players can dodge); a hitbox confirms real hits
	respawn     = "nextNight",
	upgrades = {
		{ key="firerate",  name="Rapid Fire",       price=350000, currency="cash",   fireDelay=0.5 },   -- 2 / second
		{ key="vest",      name="Bulletproof Vest", price=500000, currency="cash",   damageResist=0.5 },
		{ key="bettergun", name="Better Gun",       price=125,    currency="crypto", damage=20 },
	},
}

-- ===== ARMOURY =========================================================
-- Three guns, taken from the armoury fixture in the office. Usable on other players ONLY at night.
-- Progressive: Gun 1 -> Gun 2 -> Shotgun. Gun 1 is renameable.
SecurityConfig.Guns = {
	{ key="gun1",    name="Gun 1",   renameable=true, price=350000,  currency="cash", damage=25, fireDelay=0.45 },
	{ key="gun2",    name="Gun 2",                    price=500000,  currency="cash", damage=40, fireDelay=0.55 },
	{ key="shotgun", name="Shotgun",                  price=1500000, currency="cash", damage=70, fireDelay=5.0 },
}

-- lookup helpers
SecurityConfig.GunByKey = {}
for _,g in ipairs(SecurityConfig.Guns) do SecurityConfig.GunByKey[g.key]=g end
SecurityConfig.CctvUpByKey = {}
for _,u in ipairs(SecurityConfig.CCTV.upgrades) do SecurityConfig.CctvUpByKey[u.key]=u end
SecurityConfig.GuardUpByKey = {}
for _,u in ipairs(SecurityConfig.Guards.upgrades) do SecurityConfig.GuardUpByKey[u.key]=u end

-- ordered progressive keys (index = required predecessor)
SecurityConfig.CctvOrder  = {"range1","range2","freeze"}
SecurityConfig.GuardOrder = {"firerate","vest","bettergun"}
SecurityConfig.GunOrder   = {"gun1","gun2","shotgun"}

return SecurityConfig

