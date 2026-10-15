-- SessionLockService: shared advisory session lock so only ONE live server treats a player's
-- DataStore profile as save-authoritative. Prevents cash/item dupes and rollbacks when a player
-- hops servers fast or ends up loaded on two servers at once.
--
-- How it's used: CurrencyService (Player_<id>) and SaveService (Econ_<id>) call wait(plr) during
-- load and fold the result into their existing loadedOK gate. If we DON'T hold the lock, that player
-- runs READ-ONLY this session (loads fine, never saves) so the authoritative server isn't clobbered.
-- Because saving is gated by the (local) loadedOK flag, release ordering on leave can't corrupt data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SessionLockService = {}
local studioStores={}
function SessionLockService.studioStore(name)
 if not game:GetService("RunService"):IsStudio() or game.ServerScriptService:GetAttribute("UseLiveDataInStudio")==true then return nil end
 if studioStores[name] then return studioStores[name] end
 local values={}
 local function copy(v) if v==nil then return nil end return HttpService:JSONDecode(HttpService:JSONEncode(v)) end
 local memory={}
 function memory:GetAsync(key) return copy(values[key]) end
 function memory:SetAsync(key,value) values[key]=copy(value) end
 function memory:UpdateAsync(key,fn) local value=fn(copy(values[key]));if value~=nil then values[key]=copy(value) end;return copy(values[key]) end
 studioStores[name]=memory
 return memory
end
local store=SessionLockService.studioStore("WarehouseSim_v1") or DataStoreService:GetDataStore("WarehouseSim_v1")

-- Identity for THIS running server. Published servers have a real game.JobId; Studio gives "",
-- so we mint a GUID to keep two test sessions distinguishable.
local SERVER_ID = game.JobId
if SERVER_ID == nil or SERVER_ID == "" then SERVER_ID = "studio-"..HttpService:GenerateGUID(false) end

local STALE_SECONDS = 150     -- a lock older than this is treated as abandoned (server crashed)
local REFRESH_SECONDS = 60    -- how often we bump our held locks so long sessions never look stale
local ACQUIRE_TRIES = 6       -- retries while another LIVE server still holds the lock
local ACQUIRE_WAIT = 3        -- seconds between acquire retries
local WAIT_TIMEOUT = 30       -- max seconds wait() yields before defaulting to read-only

local function lockKey(userId) return "Lock_"..userId end

-- status[userId] = "pending" | "held" | "denied" ; nil = not tracked / released
local status = {}

-- One UpdateAsync attempt to take the lock. Returns true if we own it afterwards.
local function tryAcquire(userId)
	local got = false
	local ok = pcall(function()
		store:UpdateAsync(lockKey(userId), function(cur)
			local now = os.time()
			if cur == nil
				or cur.jobId == SERVER_ID
				or (type(cur.t) == "number" and (now - cur.t) > STALE_SECONDS) then
				got = true
				return {jobId = SERVER_ID, t = now}
			end
			return nil  -- held by another live server: abort, leave their lock untouched
		end)
	end)
	return ok and got
end

-- Acquire (with retries). Sets status; returns true if we hold the lock.
local function acquire(plr)
	local uid = plr.UserId
	status[uid] = "pending"
	for attempt = 1, ACQUIRE_TRIES do
		if status[uid] == nil then return false end  -- player left mid-acquire
		if tryAcquire(uid) then status[uid] = "held"; return true end
		warn("[SessionLock] "..plr.Name.." lock held by another server (try "..attempt.."/"..ACQUIRE_TRIES..")")
		task.wait(ACQUIRE_WAIT)
	end
	status[uid] = "denied"
	warn("[SessionLock] could NOT acquire lock for "..plr.Name.." -- running READ-ONLY (saving disabled) to protect their data")
	return false
end

-- Public: yield until acquisition resolves, then report whether we hold the lock.
function SessionLockService.wait(plr)
	local uid = plr.UserId
	local t = 0
	while (status[uid] == nil or status[uid] == "pending") and t < WAIT_TIMEOUT do
		task.wait(0.1); t += 0.1
	end
	return status[uid] == "held"
end

-- Public: do we currently hold this player's lock?
function SessionLockService.held(plr)
	return status[plr.UserId] == "held"
end

-- Public: release the lock. Idempotent + shutdown-safe: decides from the STORED jobId, not transient
-- local state, so a duplicate call (PlayerRemoving + BindToClose) can't defeat it and it never frees
-- another server's lock. NOTE: returning nil from UpdateAsync only CANCELS the write (it does NOT delete
-- the key), so to free the lock we write a sentinel with t=0 -- the stale check then makes it instantly
-- reclaimable by any server (including us on a fast rejoin).
local FREED = {jobId = "__free__", t = 0}
function SessionLockService.release(plr)
	status[plr.UserId] = nil
	pcall(function()
		store:UpdateAsync(lockKey(plr.UserId), function(cur)
			if cur == nil then return nil end             -- nothing there: nothing to do
			if cur.jobId == SERVER_ID then return FREED end -- still ours: mark free
			return cur                                     -- someone else's: leave it as-is
		end)
	end)
end

function SessionLockService.Start()
	Players.PlayerAdded:Connect(function(plr) acquire(plr) end)
	for _,plr in ipairs(Players:GetPlayers()) do task.spawn(acquire, plr) end
	Players.PlayerRemoving:Connect(function(plr) SessionLockService.release(plr) end)
	game:BindToClose(function()
		local pending=0
		for _,plr in ipairs(Players:GetPlayers()) do
			pending+=1
			task.spawn(function() SessionLockService.release(plr); pending-=1 end)
		end
		local t=0; while pending>0 and t<10 do task.wait(0.2); t+=0.2 end
	end)
	-- Heartbeat: keep our held locks fresh so long sessions never look abandoned.
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _,plr in ipairs(Players:GetPlayers()) do
				if status[plr.UserId] == "held" then
					pcall(function()
						store:UpdateAsync(lockKey(plr.UserId), function(cur)
							if cur and cur.jobId == SERVER_ID then cur.t = os.time(); return cur end
							return cur
						end)
					end)
				end
			end
		end
	end)
	print("[SessionLockService] started (server id "..SERVER_ID..")")
end

return SessionLockService

