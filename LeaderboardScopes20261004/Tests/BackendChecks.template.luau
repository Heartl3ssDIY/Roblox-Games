local clock = 1000
local jobs = {}
local inJob = false
local task = {}
local os = { clock = function() return clock end }
local function advance(seconds)
	local deadline = clock + seconds
	local steps = 0
	while true do
		local index, nextJob
		for i, job in ipairs(jobs) do if job.at <= deadline and (not nextJob or job.at < nextJob.at) then index, nextJob = i, job end end
		if not nextJob then break end
		table.remove(jobs, index)
		clock = math.max(clock, nextJob.at)
		inJob = true
		local ok, wait = coroutine.resume(nextJob.thread)
		inJob = false
		assert(ok, wait)
		if coroutine.status(nextJob.thread) ~= "dead" then nextJob.at = clock + math.max(0.001, wait or 0.03) table.insert(jobs, nextJob) end
		steps += 1 assert(steps < 10000, "Scheduler did not settle")
	end
	clock = deadline
end
function task.spawn(callback) table.insert(jobs, { thread = coroutine.create(callback), at = clock }) end
function task.wait(seconds)
	seconds = seconds or 0.03
	if inJob then return coroutine.yield(seconds) end
	advance(math.max(0.001, seconds))
	return seconds
end
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		local entry = { callback = callback, connected = true }
		table.insert(listeners, entry)
		return { Disconnect = function() entry.connected = false end }
	end, Fire = function(_, ...) for _, entry in ipairs(listeners) do if entry.connected then entry.callback(...) end end end }
end
local players = {}
local identityCalls, reads, writes, connects = 0, 0, 0, 0
local studio = false
local Players = { PlayerAdded = signal() }
function Players:GetPlayers() return table.clone(players) end
function Players:GetPlayerByUserId(id) for _, player in ipairs(players) do if player.UserId == id then return player end end end
function Players:GetNameFromUserIdAsync(id) identityCalls += 1 return "Remote" .. id end
function Players:GetUserThumbnailAsync(id) identityCalls += 1 return "avatar:" .. id, true end
local stores = {}
local DataStoreService = {}
function DataStoreService:GetOrderedDataStore(name)
	connects += 1
	if not stores[name] then
		local store = { name = name, values = {} }
		function store:UpdateAsync(key, transform)
			writes += 1
			if self.failWrites then error("offline write") end
			if self.onWrite then local callback = self.onWrite self.onWrite = nil callback() end
			self.values[key] = transform(self.values[key])
			return self.values[key]
		end
		function store:GetSortedAsync(descending, count, minimum)
			reads += 1
			assert(descending == false and count == 10 and minimum == 1)
			if self.failReads then error("offline read") end
			local page = self.pageOverride and table.clone(self.pageOverride) or {}
			if not self.pageOverride then
				for key, value in pairs(self.values) do if value >= minimum then table.insert(page, { key = key, value = value }) end end
				table.sort(page, function(a, b) return a.value > b.value or a.value == b.value and tonumber(a.key) < tonumber(b.key) end)
				while #page > count do table.remove(page) end
			end
			return { GetCurrentPage = function() return page end }
		end
		stores[name] = store
	end
	return stores[name]
end
local RunService = { IsStudio = function() return studio end }
local services = { Players = Players, DataStoreService = DataStoreService, RunService = RunService }
local game = { GetService = function(_, name) return assert(services[name], name) end }
local Enum = { ThumbnailType = { HeadShot = 1 }, ThumbnailSize = { Size100x100 = 1 } }
local function loadService()
-- SERVICE_SOURCE
end
local Service = loadService()
local passed = {}
local function check(name, value) assert(value, name) table.insert(passed, name) end
local function object(name, class)
	local value = { Name = name, class = class, attributes = {}, children = {} }
	function value:FindFirstChild(childName) return self.children[childName] end
	function value:GetFullName() return self.Name end
	function value:IsA(wanted) return self.class == wanted end
	function value:SetAttribute(key, v) self.attributes[key] = v end
	function value:GetAttribute(key) return self.attributes[key] end
	return value
end
local function child(parent, name, class)
	local value = object(name, class)
	parent.children[name], parent[name] = value, value
	return value
end
local function lobby()
	local value = object("Lobby", "Model")
	local root = child(value, "Leaderboards", "Model")
	for _, name in ipairs({ "HighestLevel", "MostWins" }) do
		local gui = child(child(child(root, name, "Model"), "Face", "BasePart"), "Display", "SurfaceGui")
		child(gui, "Empty", "TextLabel") child(gui, "Status", "TextLabel")
		local body = child(gui, "Body", "Frame")
		for index = 1, 10 do
			local row = child(body, string.format("Row%02d", index), "Frame")
			child(row, "Rank", "TextLabel") child(row, "PlayerName", "TextLabel") child(row, "Value", "TextLabel")
			child(child(row, "Avatar", "ImageLabel"), "Placeholder", "TextLabel")
		end
	end
	return value
end
local function player(id, xp, wins, ready)
	local value = object("User" .. id, "Player")
	value.UserId, value.Parent = id, Players
	value.attributes = { PCXP = xp, PCWins = wins, PCDataReady = ready ~= false }
	return value
end
local function fresh(resolve)
	local value = Service.new(lobby(), { resolveRegion = resolve })
	value.running, value.generation = true, 1
	return value
end
local function reset()
	players, stores, jobs = {}, {}, {}
	reads, writes, connects, identityCalls = 0, 0, 0, 0
	studio = false
	clock += 1000
end
local function drain(service)
	for _ = 1, 20 do
		service:_connectStores()
		service:_writeOne(service.generation)
		advance(3)
		local pending = false
		for _, scope in ipairs(service:_scopes()) do if next(scope.queue) then pending = true end end
		if not pending then return end
	end
	error("Write queue did not drain")
end
reset()
local first, second, loading = player(101, 450, 5), player(102, 200, 9), player(103, 99999, 999, false)
players = { first, second, loading }
local service = fresh(function(p) return p == first and { id = "Europe", name = "Europe" } or nil end)
local snap = service:GetSnapshot(first, "server")
check("server sorts wins and formats values as strings", snap.boards.MostWins.entries[1].userId == 102 and snap.boards.MostWins.entries[1].value == "9")
check("server sorts XP and formats display levels", snap.boards.HighestLevel.entries[1].userId == 101 and snap.boards.HighestLevel.entries[1].value == "LV 3")
check("unready players excluded from server rankings", #snap.boards.MostWins.entries == 2)
check("all snapshots avoid datastore and identity requests", reads == 0 and writes == 0 and connects == 0 and identityCalls == 0)
players = { first, loading }
check("departed player disappears immediately", #service:GetSnapshot(first, "server").boards.MostWins.entries == 1)
first.attributes.PCWins = 15
check("server reflects current score without saved-profile publication", service:GetSnapshot(first, "server").boards.MostWins.entries[1].value == "15")
check("invalid scope safely defaults global", service:GetSnapshot(first, "unsupported").scope == "global")
check("global begins honestly loading", service:GetSnapshot(first, "global").state == "loading")
check("unresolved region begins honestly loading", service:GetSnapshot(first, "region").state == "loading")
check("only valid saved profiles accepted", not service:PublishSaved(0, { XP = 2, Wins = 1 }) and not service:PublishSaved(101, { XP = 0 / 0, Wins = 1 }))
check("saved profile queues global publication", service:PublishSaved(101, { XP = 450, Wins = 5 }) and service.queue[101].XP == 450)
check("saved profile retained before resolution", service.saved[101].Wins == 5 and next(service.regions) == nil)
service:PublishSaved(101, { XP = 900, Wins = 7 })
advance(0)
check("resolution queues latest saved snapshot for region", service.regions.Europe.queue[101].XP == 900 and service.regions.Europe.queue[101].Wins == 7)
check("regional creation alone never writes or reads datastore", writes == 0 and reads == 0)
local regionReply = service:GetSnapshot(first, "region")
check("region metadata uses validated canonical display name", regionReply.region == "Europe" and regionReply.regionId == "Europe" and regionReply.scope == "region")
service:_connectStores()
check("original global datastore names preserved", stores.PlaygroundClassics_TopXP_v1 ~= nil and stores.PlaygroundClassics_TopWins_v1 ~= nil)
check("regional stores have deterministic isolated names", stores.PlaygroundClassics_TopXP_v1_Region_Europe ~= nil and stores.PlaygroundClassics_TopWins_v1_Region_Europe ~= nil)
drain(service)
check("both global and regional scores persist", stores.PlaygroundClassics_TopXP_v1.values["101"] == 900 and stores.PlaygroundClassics_TopWins_v1_Region_Europe.values["101"] == 7)
check("successful queues drain independently", next(service.queue) == nil and next(service.regions.Europe.queue) == nil)
local writeCount = writes
service:PublishSaved(101, { XP = 1, Wins = 1 })
drain(service)
check("lower saved values never lower high scores", writes == writeCount and service.saved[101].XP == 900)
for _, board in ipairs(service.boards) do service:_refresh(board, service.generation) end
for _, board in ipairs(service.regions.Europe.boards) do service:_refresh(board, service.generation, service.regions.Europe) end
snap = service:GetSnapshot(first, "global")
check("persistent global cache displays saved score rather than live attributes", snap.boards.MostWins.entries[1].value == "7")
check("live world board renders same cached global values", service.boards[2].rows[1].Value.Text == "7" and service.boards[1].rows[1].Value.Text == "LV 4")
check("offline name/avatar identity is cached", snap.boards.MostWins.entries[1].name == "User101" and snap.boards.MostWins.entries[1].image == "avatar:101")
local readCount, identityCount = reads, identityCalls
for _ = 1, 100 do service:GetSnapshot(first, "global") service:GetSnapshot(first, "region") service:GetSnapshot(first, "server") end
check("300 cached requests cause zero new service reads", reads == readCount and identityCalls == identityCount)
snap.boards.MostWins.entries[1].name = "tampered"
check("snapshot tables cannot mutate cached entries", service:GetSnapshot(first, "global").boards.MostWins.entries[1].name == "User101")
stores.PlaygroundClassics_TopWins_v1.failReads = true
service:_refresh(service.boards[2], service.generation)
snap = service:GetSnapshot(first, "global")
check("failed read keeps cached scores with stale status", snap.state == "stale" and snap.boards.MostWins.entries[1].value == "7" and snap.boards.MostWins.status:find("RECONNECTING") ~= nil)
stores.PlaygroundClassics_TopWins_v1.failReads = nil
service:_refresh(service.boards[2], service.generation)
check("successful retry clears stale status", service:GetSnapshot(first, "global").state == "ready")
service:_resolvePlayer(second, service.generation)
advance(0)
check("unknown location is honestly unavailable", service:GetSnapshot(second, "region").state == "unavailable" and service:GetSnapshot(second, "region").region == nil)
service:PublishSaved(second.UserId, { XP = 300, Wins = 2 })
check("unknown region saves global only", service.queue[102] ~= nil and service.regions.Europe.queue[102] == nil)
local invalid = player(104, 200, 1)
players = { invalid }
service.resolveRegion = function() return { id = "arbitrary/store", name = "Fake" } end
service:_resolvePlayer(invalid, service.generation) advance(0)
check("invalid resolver region never creates arbitrary datastore", service:GetSnapshot(invalid, "region").state == "unavailable" and service.regions["arbitrary/store"] == nil)
reset()
first = player(201, 250, 3)
players = { first }
local attempts = 0
service = fresh(function() attempts += 1 error("localization temporarily offline") end)
service:_resolvePlayer(first, 1) advance(0)
service:_resolvePlayer(first, 1) advance(0)
check("transient location lookup is bounded by retry delay", attempts == 1)
advance(15) service:_resolvePlayer(first, 1) advance(0)
advance(30) service:_resolvePlayer(first, 1) advance(0)
advance(200) service:_resolvePlayer(first, 1) advance(0)
check("lookup stops after three transient failures", attempts == 3 and service:GetSnapshot(first, "region").state == "unavailable")
reset()
first = player(301, 250, 3)
players = { first }
service = fresh(function() return { id = "Europe" } end)
service:_resolvePlayer(first, 1) advance(0)
service:PublishSaved(301, { XP = 250, Wins = 3 })
service:_connectStores()
stores.PlaygroundClassics_TopXP_v1_Region_Europe.failWrites = true
service:_writeOne(1)
advance(3) service:_writeOne(1)
check("regional failure does not erase successful global publication", service.published[301].XP == 250 and next(service.queue) == nil and service.regions.Europe.queue[301] ~= nil)
check("partial regional success retained", service.regions.Europe.published[301].Wins == 3 and service.regions.Europe.published[301].XP == 0)
check("regional failure gets bounded backoff", service.regions.Europe.queue[301].due > clock and service.regions.Europe.queue[301].attempts == 1)
service:PublishSaved(302, { XP = 500, Wins = 8 })
advance(3) service:_writeOne(1)
check("ready global writes proceed while region is retrying", service.published[302].XP == 500)
stores.PlaygroundClassics_TopXP_v1_Region_Europe.failWrites = nil
advance(10) drain(service)
check("regional retry eventually persists missing stat", stores.PlaygroundClassics_TopXP_v1_Region_Europe.values["301"] == 250 and next(service.regions.Europe.queue) == nil)
service:PublishSaved(301, { XP = 600, Wins = 4 })
stores.PlaygroundClassics_TopXP_v1.onWrite = function() service:PublishSaved(301, { XP = 900, Wins = 6 }) end
drain(service)
check("newer saved scores during write are not lost", stores.PlaygroundClassics_TopXP_v1.values["301"] == 900 and stores.PlaygroundClassics_TopXP_v1_Region_Europe.values["301"] == 900)
service:PublishSaved(303, { XP = 300, Wins = 3 })
local beforeThrottle = writes
service.nextWriteAt = clock + 3 service:_writeOne(1)
check("shared write throttle is enforced", writes == beforeThrottle)
advance(3) service:_writeOne(1, clock)
check("expired flush deadline leaves pending scores intact", writes == beforeThrottle and service.queue[303] ~= nil and not service.writeBusy)
service.nextWriteAt = clock
drain(service)
check("empty flush succeeds", service:Flush(0))
service:PublishSaved(304, { XP = 300, Wins = 1 })
check("zero deadline flush honestly reports pending work", not service:Flush(0))
service.nextWriteAt = clock
check("bounded flush drains global pending writes", service:Flush(5) and next(service.queue) == nil)
reset()
first = player(401, 600, 4)
players = { first }
service = fresh(function() return { id = "Europe" } end)
service:_resolvePlayer(first, 1) advance(0)
for _, id in ipairs({ "Asia", "Africa", "Oceania", "NorthAmerica", "SouthAmerica" }) do service:_region(id) end
service:_connectStores()
for _ = 1, 4 do service:_refreshNext(1) advance(2) end
check("refresh only reads global plus current active region", reads == 4)
for _, scope in pairs(service.regions) do if scope.id ~= "Europe" then check("inactive " .. scope.id .. " cache is not fetched", scope.boards[1].state == "loading" and scope.boards[2].state == "loading") end end
players = {}
for _, board in ipairs(service.boards) do board.refreshAt = clock + 100 end
for _, board in ipairs(service.regions.Europe.boards) do board.refreshAt = 0 end
local beforeDeparted = reads
service:_refreshNext(1)
check("departed region stops refreshing immediately", reads == beforeDeparted)
reset()
studio = true
first, second = player(501, 450, 2), player(502, 200, 7)
players = { first, second }
service = fresh(function(p) return p == first and { id = "Europe" } or { id = "Asia" } end)
service:_resolvePlayer(first, 1) service:_resolvePlayer(second, 1) advance(0)
service:_connectStores()
for _, board in ipairs(service.boards) do service:_refresh(board, 1) end
for _, scope in pairs(service.regions) do for _, board in ipairs(scope.boards) do service:_refresh(board, 1, scope) end end
check("Studio never connects reads or writes external datastores", connects == 0 and reads == 0 and writes == 0 and not service:PublishSaved(501, { XP = 1, Wins = 1 }))
check("Studio global explicitly labels local preview", service:GetSnapshot(first, "global").status:find("STUDIO PREVIEW") ~= nil)
snap = service:GetSnapshot(first, "region")
check("Studio region preview filters by actual resolved region", #snap.boards.MostWins.entries == 1 and snap.boards.MostWins.entries[1].userId == 501 and snap.status:find("STUDIO PREVIEW") ~= nil)
reset()
first = player(601, 300, 2)
players = { first }
service = Service.new(lobby(), { resolveRegion = function() return { id = "Europe" } end })
service:Start()
check("Start keeps uncached global boards in loading state", service:GetSnapshot(first, "global").state == "loading")
advance(0)
check("Start resolves current players in background", service.regionLookups[601].id == "Europe")
local extra = player(602, 600, 3)
table.insert(players, extra) Players.PlayerAdded:Fire(extra) advance(0)
check("new arrivals resolve without snapshot side effects", service.regionLookups[602].id == "Europe")
service:Stop()
local readsAtStop, writesAtStop = reads, writes
advance(65)
check("Stop halts background reads and writes", reads == readsAtStop and writes == writesAtStop)
local departed = player(603, 0, 0)
table.insert(players, departed) Players.PlayerAdded:Fire(departed) advance(0)
check("Stop disconnects player lifecycle subscription", service.regionLookups[603] == nil)
reset()
first = player(701, 400, 5)
players = { first }
service = fresh(function() task.wait(2) return { id = "Europe" } end)
service:PublishSaved(701, { XP = 400, Wins = 5 })
advance(0)
check("Flush tracks unresolved saved regional work", service:_pending())
service:Stop()
advance(3)
check("stale resolver completion cannot queue after Stop", service.regions.Europe == nil)
print("PASS " .. #passed .. " backend checks; mocked services only, zero live datastore calls, no Studio mutations")
for _, name in ipairs(passed) do print("PASS " .. name) end
