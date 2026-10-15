local Rules = {}

function Rules.NewPlayerState(random, rows, lanes)
    local wrong = table.create(rows)
    for row = 1, rows do
        wrong[row] = random:NextInteger(1, lanes)
    end
    return {wrong = wrong, progress = 0, status = "Active", lanes = lanes, rows = rows}
end

function Rules.ResolveChoice(state, row, lane)
    if state.status ~= "Active" or row ~= state.progress + 1 then
        return false, "OutOfOrder"
    end
    if lane % 1 ~= 0 or lane < 1 or lane > state.lanes or row > state.rows then
        return false, "InvalidChoice"
    end
    state.lastRow = row
    state.lastLane = lane
    if state.wrong[row] == lane then
        state.status = "Eliminated"
        return true, "Eliminated"
    end
    state.progress = row
    return true, "Safe"
end

function Rules.Qualify(state)
    if state.status ~= "Active" or state.progress ~= state.rows then
        return false
    end
    state.status = "Qualified"
    return true
end

function Rules.GetLane(x, laneWidth, lanes)
    local half = laneWidth * lanes / 2
    if x < -half or x > half then return nil end
    return math.clamp(math.floor((x + half) / laneWidth) + 1, 1, lanes)
end

return Rules
