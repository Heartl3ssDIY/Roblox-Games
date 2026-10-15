local RaceProgress = {}
local INTERVAL = 0.15

local function finite(value, fallback)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return value
end

function RaceProgress.new(context)
	local roster = {}
	local elapsed = 0
	local sequence = 0
	local lastPhase, lastVersion, lastCourse
	local isPresent = context.IsPresent or function(player)
		return player.Parent ~= nil
	end
	local self = {}

	local function synchronize()
		local phase = context.Phase()
		local version = context.RoundKey()
		local course = context.CourseNumber()
		local changed = phase ~= lastPhase or version ~= lastVersion or course ~= lastCourse
		if version ~= lastVersion or phase ~= "Running" then
			table.clear(roster)
		end
		if changed then elapsed = 0 end
		lastPhase, lastVersion, lastCourse = phase, version, course
		return changed, phase, version, course
	end

	function self:MarkStarted(player, version)
		local _, phase, currentVersion = synchronize()
		local data = context.Runners[player]
		if phase ~= "Running" or version ~= currentVersion or not data
			or data.status ~= "Running" or data.courseVersion ~= currentVersion
			or not isPresent(player) then
			return false
		end
		roster[player] = data
		return true
	end

	function self:Publish()
		local _, phase, version, course = synchronize()
		local rows = {}
		if phase == "Running" then
			for player, data in roster do
				if not isPresent(player) or context.Runners[player] ~= data then
					roster[player] = nil
				else
					local finished = data.roundFinishTime ~= nil
					local status = finished and "Finished" or data.status == "Running" and "Running" or "Out"
					local progress
					if finished then
						progress = 1
					elseif status == "Running" then
						progress = context.Progress(data)
					else
						progress = data.roundStoppedProgress or data.maxProgress or 0
					end
					table.insert(rows, {
						userId = player.UserId,
						progress = math.clamp(finite(progress, 0), 0, finished and 1 or 0.999),
						status = status,
						finished = finished,
						finishPlace = finished and finite(data.roundFinishPlace, nil) or nil,
						finishTime = finished and finite(data.roundFinishTime, nil) or nil,
					})
				end
			end
			table.sort(rows, function(a, b)
				if a.finished ~= b.finished then return a.finished end
				if a.finished then
					if a.finishPlace ~= b.finishPlace then
						return (a.finishPlace or 99) < (b.finishPlace or 99)
					end
					if a.finishTime ~= b.finishTime then
						return (a.finishTime or math.huge) < (b.finishTime or math.huge)
					end
				elseif a.progress ~= b.progress then
					return a.progress > b.progress
				end
				return a.userId < b.userId
			end)
			for place, row in rows do
				row.place = place
				row.finishTime = nil
			end
		end
		sequence += 1
		elapsed = 0
		local packet = {
			phase = phase,
			courseVersion = version,
			courseNumber = course,
			sequence = sequence,
			rows = rows,
		}
		context.Broadcast(packet)
		return packet
	end

	function self:Step(deltaTime)
		local changed, phase = synchronize()
		if changed then
			self:Publish()
			return
		end
		if phase ~= "Running" then return end
		elapsed += math.max(0, finite(deltaTime, 0))
		if elapsed >= INTERVAL then self:Publish() end
	end

	return self
end

return RaceProgress
