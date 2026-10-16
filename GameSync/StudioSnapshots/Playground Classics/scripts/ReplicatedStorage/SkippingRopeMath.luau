local RopeMath = {}
local TAU = math.pi * 2

local function options(settings, stepSeconds, factor)
	if type(settings) == "table" then return settings.period or 3.6, settings.stepSeconds or 10, settings.speedFactor or 1.05 end
	return type(settings) == "number" and settings or 3.6, stepSeconds or 10, factor or 1.05
end

function RopeMath.GetSpeedMultiplier(elapsed, settings, stepSeconds, factor)
	local _, step, growth = options(settings, stepSeconds, factor)
	return growth ^ math.floor(math.max(0, elapsed) / step)
end

function RopeMath.GetAngle(elapsed, settings, stepSeconds, factor)
	local period, step, growth = options(settings, stepSeconds, factor)
	elapsed = math.max(0, elapsed)
	local sections = math.floor(elapsed / step)
	local speed = growth ^ sections
	local integrated = growth == 1 and sections * step or step * (speed - 1) / (growth - 1)
	return math.pi + TAU / period * (integrated + (elapsed - sections * step) * speed)
end

function RopeMath.GetCycle(angle)
	return math.floor((angle + math.pi) / TAU)
end

function RopeMath.RadiusAtX(x, settings)
	settings = settings or {}
	local halfSpan, flat = settings.halfSpan or 26, settings.flatHalfSpan or 16
	local radius = settings.radius or 8
	local distance = math.abs(x)
	if distance >= halfSpan then return 0 end
	if distance <= flat then return radius end
	local u = (distance - flat) / (halfSpan - flat)
	return radius * math.sqrt(math.max(0, 1 - u * u))
end

function RopeMath.Point(angle, x, settings)
	settings = settings or {}
	local radius = RopeMath.RadiusAtX(x, settings)
	return Vector3.new(x, (settings.pivotHeight or 8.8) - radius * math.cos(angle), radius * math.sin(angle))
end

function RopeMath.SweepAvatar(firstTime, lastTime, firstPosition, lastPosition, lower, upper, halfWidth, halfDepth, settings)
	if lastTime < firstTime then return {} end
	local firstAngle, lastAngle = RopeMath.GetAngle(firstTime, settings), RopeMath.GetAngle(lastTime, settings)
	local count = math.clamp(math.max(math.ceil((lastAngle - firstAngle) / 0.06), math.ceil((lastTime - firstTime) / 0.016)), 1, 64)
	local hits, found = {}, {}
	for index = 0, count do
		local alpha = index / count
		local elapsed = firstTime + (lastTime - firstTime) * alpha
		local angle = RopeMath.GetAngle(elapsed, settings)
		local position = firstPosition:Lerp(lastPosition, alpha)
		if math.abs(position.X) <= (settings.halfSpan or 26) + halfWidth then
			local point = RopeMath.Point(angle, math.clamp(position.X, -(settings.halfSpan or 26), settings.halfSpan or 26), settings)
			if math.abs(point.Z - position.Z) <= halfDepth + 0.3
				and point.Y >= position.Y + lower - 0.25 and point.Y <= position.Y + upper + 0.25 then
				local cycle = RopeMath.GetCycle(angle)
				if not found[cycle] then found[cycle] = true table.insert(hits, cycle) end
			end
		end
	end
	return hits
end

return RopeMath
