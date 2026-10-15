return function(Rules)
	local checks = 0
	local function expect(actual, expected, label)
		assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
		checks = checks + 1
	end

	expect(Rules.DepartureExpired(true, 15, 14.99), false, "Departure grace remains before deadline")
	expect(Rules.DepartureExpired(true, 15, 15), true, "Departure grace expires at deadline")
	expect(Rules.DepartureExpired(false, 15, 100), false, "A departed runner does not forfeit later")
	expect(Rules.DepartureExpired(true, 0, 100), false, "Countdown has no departure deadline")
	expect(Rules.CanTag("Countdown", "Runner", true, false, true, false), false, "No countdown tags")
	expect(Rules.CanTag("Crossing", "Runner", false, false, false, false), false, "Source safe zone")
	expect(Rules.CanTag("Crossing", "Runner", true, true, false, false), false, "Arrival remains safe")
	expect(Rules.CanTag("Crossing", "Runner", true, false, true, true), false, "Frozen forfeiter cannot tag")
	expect(Rules.CanTag("Crossing", "Runner", true, false, true, false), true, "Active runner in court")
	expect(Rules.CanTag("Crossing", "Tagged", true, false, true, false), false, "No repeated tags")
	expect(Rules.CrossingResolved(1), false, "Crossing waits for last runner")
	expect(Rules.CrossingResolved(0), true, "All arrived or caught resolves crossing")
	expect(Rules.Outcome(1, 23, 0, 24, true), "Runners", "One timeout survivor wins")
	expect(Rules.Outcome(5, 19, 0, 24, true), "Runners", "All timeout survivors win")
	expect(Rules.Outcome(0, 20, 4, 24, false), "Bulldogs", "All caught wins immediately")
	expect(Rules.Outcome(0, 0, 0, 0, true), "None", "Empty match abandons")
	expect(Rules.Outcome(3, 0, 1, 4, false), nil, "Pending tagged replacement keeps match alive")
	expect(Rules.Outcome(3, 0, 0, 3, false), "Runners", "Bulldog disconnect survivor result")
	expect(Rules.IsInside(10, 5, -20, 10, 5, 20), true, "Safe volume includes edge")
	expect(Rules.IsInside(10.01, 5, -20, 10, 5, 20), false, "Sidewall bypass is outside safe volume")
	return { passed = checks }
end
