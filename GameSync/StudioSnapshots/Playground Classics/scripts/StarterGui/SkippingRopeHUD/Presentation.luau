local Presentation = {}

function Presentation.Get(values)
	local hits = math.clamp(values.hits or 0, 0, 2)
	local out = { title = "SKIPPING ROPE", role = "ROPE " .. tostring(values.lane or 1),
		counts = string.format("%d %s left  |  %d still in", 2 - hits, hits == 1 and "hit" or "hits", values.alive or 0),
		hint = "Jump over the rope. Two hits and you're out!", warning = false }
	if values.phase == "Countdown" then
		out.hint = "Get ready! Jump with Space, A or the jump button"
	elseif values.phase == "Results" then
		out.title, out.role = "ROUND FINISHED", values.result == "Won" and "SURVIVED!" or values.result == "Cancelled" and "CANCELLED" or "ROUND OVER"
		out.hint = values.result == "Won" and "You survived two minutes!" or values.result == "Cancelled" and "Round cancelled" or "Try again next round"
	elseif values.eliminated then
		out.role, out.hint, out.warning = "OUT", "Two hits! Watch from the benches until next round", true
	elseif hits == 1 then
		out.hint, out.warning = "One hit left! Watch the rope and jump", true
	end
	if values.watching then out.role, out.hint = "WATCHING", "Jumpers survive two minutes to win" end
	return out
end

return Presentation