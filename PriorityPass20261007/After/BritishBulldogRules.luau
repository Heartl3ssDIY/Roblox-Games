local Rules = {}

function Rules.IsInside(x, y, z, halfX, halfY, halfZ)
	return math.abs(x) <= halfX and math.abs(y) <= halfY and math.abs(z) <= halfZ
end

function Rules.DepartureExpired(mustLeave, deadline, now)
	return mustLeave and deadline > 0 and now >= deadline
end

function Rules.CrossingResolved(unresolvedRunners)
	return unresolvedRunners == 0
end

function Rules.Outcome(runners, bulldogs, tagged, participants, timedOut, lastRunnerWins)
	if participants == 0 then
		return "None"
	end
	if runners == 0 then
		return "Bulldogs"
	end
	if lastRunnerWins or timedOut or bulldogs + tagged == 0 then
		return "Runners"
	end
	return nil
end

function Rules.CanTag(phase, runnerRole, runnerDeparted, runnerArrived, inField, bulldogFrozen)
	return phase == "Crossing"
		and runnerRole == "Runner"
		and runnerDeparted
		and not runnerArrived
		and inField
		and not bulldogFrozen
end

return Rules

