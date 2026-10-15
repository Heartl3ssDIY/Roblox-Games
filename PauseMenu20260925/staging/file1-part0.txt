local RunService = game:GetService("RunService")
local MatchClock = {}
local paused = false
local started = 0
local stopped = 0

function MatchClock.now()
    return (paused and started or os.clock()) - stopped
end

function MatchClock.isPaused()
    return paused
end

function MatchClock.setPaused(value)
    if paused == value then return end
    if value then started = os.clock() else stopped += os.clock() - started end
    paused = value
    game.Players.LocalPlayer:SetAttribute("MatchPaused", paused)
end

function MatchClock.wait(duration, valid)
    local deadline = MatchClock.now() + duration
    while MatchClock.isPaused() or MatchClock.now() < deadline do
        if valid and not valid() then return false end
        RunService.Heartbeat:Wait()
    end
    return not valid or valid()
end

return MatchClock
