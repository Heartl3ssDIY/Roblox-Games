local Rules = require("./GBloxRaceProgressRules")
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

local function packet(version, sequence)
	return {
		phase = "Running", courseVersion = version or 1, courseNumber = version or 1, sequence = sequence or 1,
		rows = {
			{userId = 30, progress = 0.8, place = 1, status = "Running"},
			{userId = 20, progress = 0.4, place = 2, status = "Out"},
			{userId = 10, progress = 0.2, place = 3, status = "Running"},
		},
	}
end

test("newer snapshots require both current course and increasing sequence", function()
	expect(Rules.Accept(packet(2, 21), 2, 20, 6), "fresh current course")
	expect(not Rules.Accept(packet(2, 20), 2, 20, 6), "duplicate sequence")
	expect(not Rules.Accept(packet(2, 19), 2, 20, 6), "old sequence")
	expect(not Rules.Accept(packet(1, 22), 2, 20, 6), "old course despite higher sequence")
	expect(Rules.Accept(packet(3, 22), 2, 20, 6), "new course uses global sequence")
	expect(not Rules.Accept(packet(3, 1), 2, 20, 6), "per-course sequence reset rejected")
end)

test("malformed packets and nonfinite identity fields cannot update the HUD", function()
	for _, value in {false, 1, "packet"} do
		expect(not Rules.Accept(value, 1, 0, 6), "wrong packet type")
	end
	expect(not Rules.Accept(nil, 1, 0, 6), "nil packet")
	for _, field in {"courseVersion", "sequence"} do
		for _, value in {0 / 0, math.huge, -math.huge, "2"} do
			local p = packet()
			p[field] = value
			expect(not Rules.Accept(p, 1, 0, 6), "invalid " .. field)
		end
	end
	local p = packet()
	p.courseVersion = 1.5
	expect(not Rules.Accept(p, 1, 0, 6), "fractional version")
	p = packet()
	p.phase = 1
	expect(not Rules.Accept(p, 1, 0, 6), "phase type")
	p = packet()
	p.rows = false
	expect(not Rules.Accept(p, 1, 0, 6), "rows type")
end)

test("capacity, duplicate identities and rank inconsistencies reject whole snapshot", function()
	local p = packet()
	for index = 4, 7 do
		p.rows[index] = {userId = index, progress = 0, place = index, status = "Running"}
	end
	expect(not Rules.Accept(p, 1, 0, 6), "capacity bound")
	p = packet()
	p.rows[2].userId = p.rows[1].userId
	expect(not Rules.Accept(p, 1, 0, 6), "duplicate identities")
	p = packet()
	p.rows[2].place = 1
	expect(not Rules.Accept(p, 1, 0, 6), "rank order")
	p = packet()
	p.rows[2].status = "Spectating"
	expect(not Rules.Accept(p, 1, 0, 6), "wire statuses must be normalized by server")
	p = packet()
	p.rows[2].userId = 2.5
	expect(not Rules.Accept(p, 1, 0, 6), "fractional userId")
	p = packet()
	p.rows[2].progress = 0 / 0
	expect(not Rules.Accept(p, 1, 0, 6), "NaN progress")
end)

test("accepted progress stays bounded and finished is pinned without mutating source", function()
	local p = packet()
	p.rows[1].status, p.rows[1].progress = "Finished", 0.7
	p.rows[2].progress = -1
	p.rows[3].progress = 2
	local accepted = Rules.Accept(p, 1, 0, 6)
	expect(accepted.rows[1].progress == 1, "accepted finish at end")
	expect(accepted.rows[2].progress == 0 and accepted.rows[2].status == "Out", "out lower bound")
	expect(accepted.rows[3].progress == 0.999, "unfinished upper bound")
	expect(p.rows[1].progress == 0.7 and p.rows[2].progress == -1 and p.rows[3].progress == 2, "source unchanged")
	accepted.rows[1].status = "Out"
	expect(p.rows[1].status == "Finished", "independent accepted rows")
end)

test("local identity always keeps cyan artwork and entire marker priority", function()
	for place = 1, 6 do
		for _, status in {"Running", "Out", "Finished"} do
			local own = Rules.Appearance(place, true, status)
			expect(own.ring == "you-ring" and own.badge == "you-badge", "local color survives rank changes")
			expect(own.zIndex == 100 and own.showNumber, "local stacking and rank label")
			for otherPlace = 1, 6 do
				expect(own.zIndex > Rules.Appearance(otherPlace, false, status).zIndex, "local always above rivals")
			end
		end
	end
end)

test("remote medals follow absolute rank through local overtakes", function()
	local expected = {"gold", "silver", "bronze", "other", "other", "other"}
	for place, color in expected do
		local rival = Rules.Appearance(place, false, "Running")
		expect(rival.ring == color .. "-ring" and rival.badge == color .. "-badge", "rank medal")
		expect(rival.showNumber == (place > 3), "numbered nonmedal places")
	end
	expect(Rules.Appearance(2, false, "Running").ring == "silver-ring", "rival second stays silver when local is first")
	expect(Rules.Appearance(1, false, "Running").ring == "gold-ring", "rival gets gold after overtaking local")
end)

test("out appearance and finish badge remain distinct", function()
	for _, localPlayer in {false, true} do
		local out = Rules.Appearance(2, localPlayer, "Out")
		local finish = Rules.Appearance(2, localPlayer, "Finished")
		expect(out.muted and not out.finished, "out visibly muted")
		expect(not finish.muted and finish.finished, "accepted finisher flag")
	end
end)

test("visibility respects course readiness, podium and race phase", function()
	expect(Rules.Visible("Running", true, false, false, true), "active race visible")
	expect(not Rules.Visible("Running", false, false, false, true), "loading hidden")
	expect(not Rules.Visible("Running", true, true, false, true), "podium hidden")
	expect(not Rules.Visible("Running", true, false, true, true), "podium camera hidden")
	expect(not Rules.Visible("Running", true, false, false, false), "no packet hidden")
	for _, phase in {"Waiting", "Countdown", "Intermission", "AwaitingCourse", "MatchComplete"} do
		expect(not Rules.Visible(phase, true, false, false, true), "hidden during " .. phase)
	end
end)

test("real server packets survive finish, spectating, recovery and course changes", function()
	local phase, version, course, latest = "Running", 1, 1, nil
	local first, second, observer = {UserId = 101, Parent = true}, {UserId = 102, Parent = true}, {UserId = 103, Parent = true}
	local runners = {
		[first] = {status = "Running", courseVersion = 1, progress = 0.8, maxProgress = 0.8},
		[second] = {status = "Running", courseVersion = 1, progress = 0.6, maxProgress = 0.6},
		[observer] = {status = "Spectating", courseVersion = 1, progress = 0},
	}
	local stream = RaceProgress.new({
		Runners = runners,
		Phase = function() return phase end,
		RoundKey = function() return version end,
		CourseNumber = function() return course end,
		Progress = function(data) return data.progress end,
		Broadcast = function(value) latest = value end,
	})
	stream:MarkStarted(first, 1)
	stream:MarkStarted(second, 1)
	stream:Publish()
	local accepted = Rules.Accept(latest, 1, 0, 6)
	expect(accepted and #accepted.rows == 2, "initial race excludes observer")
	local oldPacket, oldSequence = latest, latest.sequence
	runners[first].status, runners[first].roundStoppedProgress = "Spectating", 0.8
	runners[second].progress, runners[second].recovering = 0.3, true
	stream:Publish()
	accepted = Rules.Accept(latest, 1, oldSequence, 6)
	expect(accepted.rows[1].status == "Out" and accepted.rows[1].progress == 0.8, "spectating eliminated runner retains frozen marker")
	expect(accepted.rows[2].progress == 0.3 and accepted.rows[2].status == "Running", "recovery tracks backward")
	runners[second].status, runners[second].roundFinishPlace, runners[second].roundFinishTime = "Spectating", 1, 15
	stream:Publish()
	accepted = Rules.Accept(latest, 1, accepted.sequence, 6)
	expect(accepted.rows[1].userId == 102 and accepted.rows[1].status == "Finished" and accepted.rows[1].progress == 1, "finished character replacement")
	phase = "Intermission"
	stream:Publish()
	accepted = Rules.Accept(latest, 1, accepted.sequence, 6)
	expect(#accepted.rows == 0 and not Rules.Visible(accepted.phase, true, false, false, true), "immediate hide")
	version, course, phase = 2, 2, "Waiting"
	stream:Publish()
	accepted = Rules.Accept(latest, 2, accepted.sequence, 6)
	expect(accepted and #accepted.rows == 0, "new course empty snapshot")
	expect(not Rules.Accept(oldPacket, 2, accepted.sequence, 6), "old course cannot reappear")
end)

print(("%d client rules tests passed"):format(passed))
