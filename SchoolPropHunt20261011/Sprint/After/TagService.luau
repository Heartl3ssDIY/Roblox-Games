function Service:_botSprint(bot, now, wantsSprint)
	local dt = math.clamp(now - (bot.lastSprintAt or now), 0, 0.25)
	bot.lastSprintAt = now
	local capacity = math.clamp(self:_setting("SprintSeconds", 10, 1), 1, 30)
	bot.botSprintRemaining = math.clamp(bot.botSprintRemaining or capacity, 0, capacity)
	if wantsSprint and bot.botSprintRemaining > 0 then
		bot.botSprintRemaining = math.max(0, bot.botSprintRemaining - dt)
	else
		bot.botSprintRemaining = math.min(capacity, bot.botSprintRemaining + dt * capacity / self:_setting("SprintRefillSeconds", 15, 1))
	end
	bot.botSprintExhausted = bot.botSprintRemaining <= 0
	local sprinting = wantsSprint and not bot.botSprintExhausted
	local speed = bot.role == "Tagger" and self:_setting("TaggerWalkSpeed", 18, 1) or self:_setting("RunnerWalkSpeed", 16, 1)
	bot.humanoid.WalkSpeed = speed * (sprinting and math.clamp(self:_setting("SprintMultiplier", 2.5, 1), 1, 2.5) or 1)
end

