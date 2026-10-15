local Rules = {}

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Rules.Accept(packet, minimumVersion, lastSequence, maxPlayers)
	if type(packet) ~= "table" or not finite(packet.courseVersion)
		or packet.courseVersion < minimumVersion or packet.courseVersion % 1 ~= 0
		or not finite(packet.sequence) or packet.sequence <= lastSequence
		or type(packet.phase) ~= "string" or type(packet.rows) ~= "table"
		or #packet.rows > maxPlayers then return nil end
	local rows, seen = {}, {}
	for index, row in ipairs(packet.rows) do
		if type(row) ~= "table" or not finite(row.userId) or row.userId % 1 ~= 0
			or seen[row.userId] or not finite(row.progress) or row.place ~= index
			or (row.status ~= "Running" and row.status ~= "Finished" and row.status ~= "Out") then return nil end
		seen[row.userId] = true
		table.insert(rows, {
			userId = row.userId,
			progress = row.status == "Finished" and 1 or math.clamp(row.progress, 0, 0.999),
			place = row.place,
			status = row.status,
		})
	end
	return { courseVersion = packet.courseVersion, sequence = packet.sequence, phase = packet.phase, rows = rows }
end

function Rules.Appearance(place, isLocal, status)
	local medal = place == 1 and "gold" or place == 2 and "silver" or place == 3 and "bronze" or "other"
	local style = isLocal and "you" or medal
	return {
		ring = style .. "-ring",
		badge = style .. "-badge",
		showNumber = isLocal or place > 3,
		zIndex = isLocal and 100 or 30 - place,
		muted = status == "Out",
		finished = status == "Finished",
	}
end

function Rules.Visible(phase, ready, podium, podiumCamera, hasPacket)
	return phase == "Running" and ready == true and not podium and not podiumCamera and hasPacket == true
end

return Rules
