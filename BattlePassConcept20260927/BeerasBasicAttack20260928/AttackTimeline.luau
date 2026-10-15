local AttackTimeline = {}

function AttackTimeline.get(unitName, unitType, hitSpeed)
	local speed = tonumber(hitSpeed) or 1
	if speed ~= speed or speed == math.huge or speed == -math.huge then speed = 1 end
	local profile = {
		kind = "Ranged", releaseAt = 0.46, duration = 0.89,
		cooldown = math.max(speed, 1.05), beamDuration = 0.16,
	}
	if unitName == "Master Roshu" or unitName == "Master Roshi" then
		profile.kind = "Roshi"
		profile.releaseAt, profile.duration = 1.35, 2.25
		profile.cooldown, profile.beamDuration = math.max(speed, 2.4), 0.38
	elseif unitName == "Beeras" then
		profile.kind = "Beeras"
		profile.releaseAt, profile.duration = 2.0, 2.65
		profile.cooldown, profile.beamDuration = math.max(speed, 3), 0.45
	elseif unitType == "Melee" then
		profile.kind = "Melee"
		profile.releaseAt, profile.duration = 0.22, 0.50
		profile.cooldown, profile.beamDuration = math.max(speed, 0.60), 0
	elseif unitName == "Pikkolo" then
		profile.kind = "Pikkolo"
		profile.releaseAt, profile.duration = 0.38, 0.73
		profile.cooldown = math.max(speed, 0.82)
	elseif unitName == "Tein" then
		profile.kind = "Tein"
		profile.releaseAt, profile.duration = 0.50, 0.93
		profile.cooldown, profile.beamDuration = math.max(speed, 1.05), 0.18
	elseif unitName == "Bluma" then
		profile.kind = "Bluma"
		profile.releaseAt, profile.duration = 0.30, 0.62
		profile.cooldown, profile.beamDuration = math.max(speed, 0.72), 0.12
	end
	return profile
end

return AttackTimeline
