local RaceProgress = require("./GBloxRaceProgressServer")
local passed = 0

local function expect(value, message)
	assert(value, message)
end

local function test(name, callback)
	callback()
	passed += 1
	print("PASS " .. name)
end

local function fixture()
	local state = { phase = "Running", version = 1, course = 1, runners = {}, packets = {} }
	state.stream = RaceProgress.new({
		Runners = state.runners,
		Phase = function() return state.phase end,
		RoundKey = function() return state.version end,
		CourseNumber = function() return state.course end,
		Progress = function(data) return data.liveProgress end,
		IsPresent = function(player) return player.present end,
		Broadcast = function(packet) table.insert(state.packets, packet) end,
	})
	function state:add(id, progress, status, mark)
		local player = { UserId = id, present = true }
		local data = {
			status = status or "Running", courseVersion = self.version,
			liveProgress = progress, maxProgress = progress,
		}
		self.runners[player] = data
		if mark ~= false then self.stream:MarkStarted(player, self.version) end
		return player, data
	end
	return state
end

test("six runners share deterministic live positions and overtake order", function()
	local s = fixture()
	local players = {}
	for id = 6, 1, -1 do players[id] = s:add(id, 0.1 * id) end
	local packet = s.stream:Publish()
	expect(#packet.rows == 6 and packet.rows[1].userId == 6, "six-member order")
	for rank, row in packet.rows do expect(row.place == rank, "server places") end
	s.runners[players[1]].liveProgress = 0.8
	s.runners[players[6]].liveProgress = 0.8
	packet = s.stream:Publish()
	expect(packet.rows[1].userId == 1 and packet.rows[2].userId == 6, "UserId tie break")
	expect(packet.sequence == 2 and packet.courseVersion == 1 and packet.courseNumber == 1, "packet identity")
end)

test("finish order stays fixed ahead of unfinished progress", function()
	local s = fixture()
	local _, first = s:add(40, 0.2)
	local _, second = s:add(10, 0.9)
	s:add(1, 1)
	first.roundFinishTime, first.roundFinishPlace, first.status = 12, 1, "Spectating"
	second.roundFinishTime, second.roundFinishPlace, second.status = 12.1, 2, "Finished"
	local rows = s.stream:Publish().rows
	expect(rows[1].userId == 40 and rows[2].userId == 10, "accepted finish order")
	expect(rows[1].status == "Finished" and rows[1].progress == 1 and rows[1].finishPlace == 1, "finished survives character replacement")
	expect(rows[3].progress == 0.999 and not rows[3].finished, "unfinished cannot imply accepted finish")
	expect(rows[1].finishTime == nil, "no unnecessary time field in wire packet")
end)

test("out runner freezes at stopped progress and remains after spectating", function()
	local s = fixture()
	local _, data = s:add(1, 0.8)
	s:add(2, 0.5)
	data.status, data.roundStoppedProgress, data.liveProgress = "Out", 0.4, 0.9
	local rows = s.stream:Publish().rows
	expect(rows[1].userId == 2 and rows[2].progress == 0.4 and rows[2].status == "Out", "stopped progress")
	data.status, data.liveProgress = "Spectating", 0
	rows = s.stream:Publish().rows
	expect(#rows == 2 and rows[2].status == "Out" and rows[2].progress == 0.4, "out participant retained")
	data.roundStoppedProgress = nil
	expect(s.stream:Publish().rows[1].progress == 0.8, "maxProgress fallback")
end)

test("recovery moves progress backward without losing participation", function()
	local s = fixture()
	local _, data = s:add(1, 0.7)
	data.recovering, data.liveProgress = true, 0.35
	local row = s.stream:Publish().rows[1]
	expect(row.progress == 0.35 and row.status == "Running", "current recovery progress")
	expect(data.maxProgress == 0.7 and data.liveProgress == 0.35, "gameplay state untouched")
end)

test("roster excludes unstarted players and drops departed or replaced entries", function()
	local s = fixture()
	local first = s:add(1, 0.5)
	local second = s:add(2, 0.3)
	local spectator = s:add(3, 0.9, "Spectating", false)
	local unstarted = s:add(4, 0.9, "Running", false)
	expect(not s.stream:MarkStarted(spectator, 1), "spectator cannot join")
	expect(not s.stream:MarkStarted(unstarted, 2), "wrong version cannot join")
	expect(#s.stream:Publish().rows == 2, "only explicit race starters")
	first.present = false
	s.runners[second] = { status = "Running", liveProgress = 0.9, courseVersion = 1 }
	expect(#s.stream:Publish().rows == 0, "departure and state replacement removed")
	first.present = true
	expect(#s.stream:Publish().rows == 0, "departed entry stays removed")
end)

test("phase and course changes publish empty packets and require fresh marking", function()
	local s = fixture()
	local player, data = s:add(1, 0.7)
	data.roundFinishTime, data.roundFinishPlace = 10, 1
	s.stream:Publish()
	s.phase = "Intermission"
	s.stream:Step(0)
	local packet = s.packets[#s.packets]
	expect(packet.phase == "Intermission" and #packet.rows == 0, "immediate hide")
	s.version, s.course, s.phase = 2, 2, "Waiting"
	s.stream:Publish()
	packet = s.packets[#s.packets]
	expect(packet.courseVersion == 2 and #packet.rows == 0, "new course ignores old result fields")
	s.phase = "Running"
	s.stream:Step(0)
	expect(#s.packets[#s.packets].rows == 0, "no inferred participants")
	data.courseVersion, data.roundFinishTime, data.roundFinishPlace, data.liveProgress = 2, nil, nil, 0
	expect(s.stream:MarkStarted(player, 2), "fresh participant")
	packet = s.stream:Publish()
	expect(#packet.rows == 1 and packet.rows[1].progress == 0 and packet.sequence > 3, "fresh zero progress")
end)

test("version change clears roster even if phase remains Running", function()
	local s = fixture()
	s:add(1, 0.7)
	s.stream:Publish()
	s.version, s.course = 2, 2
	s.stream:Step(0)
	expect(#s.packets[#s.packets].rows == 0 and s.packets[#s.packets].courseVersion == 2, "version isolation")
end)

test("steady running stream is throttled and catches no backlog", function()
	local s = fixture()
	s:add(1, 0)
	s.stream:Publish()
	s.stream:Step(0.1)
	s.stream:Step(0.049)
	expect(#s.packets == 1, "no early send")
	s.stream:Step(0.002)
	expect(#s.packets == 2, "send at 0.15 seconds")
	s.stream:Step(2)
	expect(#s.packets == 3, "one latest packet after hitch")
	s.stream:Step(0)
	expect(#s.packets == 3, "no backlog packets")
	s.phase = "Waiting"
	s.stream:Publish()
	local count = #s.packets
	for _ = 1, 10 do s.stream:Step(1) end
	expect(#s.packets == count, "idle phases generate no periodic traffic")
end)

test("invalid progress and delta cannot poison future packets", function()
	local s = fixture()
	local _, data = s:add(1, 0)
	data.liveProgress = 0 / 0
	expect(s.stream:Publish().rows[1].progress == 0, "NaN progress")
	data.liveProgress = math.huge
	expect(s.stream:Publish().rows[1].progress == 0, "infinite progress")
	data.liveProgress = -5
	expect(s.stream:Publish().rows[1].progress == 0, "lower clamp")
	s.stream:Step(0 / 0)
	s.stream:Step(math.huge)
	s.stream:Step(-1)
	local count = #s.packets
	s.stream:Step(0.15)
	expect(#s.packets == count + 1, "cadence recovers")
end)

print(("%d server snapshot tests passed"):format(passed))
