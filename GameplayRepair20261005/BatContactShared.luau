local BAT_SAMPLE_MAX_AGE = 0.15

local function sampleBatSwing(swing, attacker, records, now)
	local targets = {}
	for _, target in pairs(records) do
		if target ~= attacker and target.root and target.root.Parent and target.character then
			targets[target] = { position = target.root.Position, character = target.character, root = target.root }
		end
	end
	swing.sample = { at = now, origin = attacker.root.Position, root = attacker.root,
		forward = attacker.root.CFrame.LookVector, targets = targets }
end

local function polynomialValue(coefficients, alpha)
	local value = 0
	for index = #coefficients, 1, -1 do value = value * alpha + coefficients[index] end
	return value
end

local function polynomialRoots(coefficients, first, last)
	local scale = 0
	for _, value in ipairs(coefficients) do scale = math.max(scale, math.abs(value)) end
	if scale < 1e-12 then return {} end
	local normalized = {}
	for index, value in ipairs(coefficients) do normalized[index] = value / scale end
	while #normalized > 1 and math.abs(normalized[#normalized]) < 1e-12 do table.remove(normalized) end
	local degree = #normalized - 1
	if degree < 1 then return {} end
	if degree == 1 then
		local root = -normalized[1] / normalized[2]
		return root >= first and root <= last and { root } or {}
	end
	local derivative = {}
	for index = 2, #normalized do derivative[index - 1] = normalized[index] * (index - 1) end
	local boundaries = { first }
	for _, root in ipairs(polynomialRoots(derivative, first, last)) do table.insert(boundaries, root) end
	table.insert(boundaries, last)
	table.sort(boundaries)
	local roots = {}
	for index, boundary in ipairs(boundaries) do
		local value = polynomialValue(normalized, boundary)
		if math.abs(value) < 1e-10 then table.insert(roots, boundary) end
		local nextBoundary = boundaries[index + 1]
		if nextBoundary then
			local nextValue = polynomialValue(normalized, nextBoundary)
			if value * nextValue < 0 then
				local left, right, leftValue = boundary, nextBoundary, value
				for _ = 1, 32 do
					local middle = (left + right) * 0.5
					local middleValue = polynomialValue(normalized, middle)
					if leftValue * middleValue <= 0 then right = middle
					else left, leftValue = middle, middleValue end
				end
				table.insert(roots, (left + right) * 0.5)
			end
		end
	end
	return roots
end

local function contactIntervals(relative, change, facing, turn, first, last, reach)
	local a, b, c = change:Dot(change), 2 * relative:Dot(change), relative:Dot(relative) - reach * reach
	if a < 1e-10 then
		if c > 0 then return {} end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant < 0 then return {} end
		local root = math.sqrt(discriminant)
		first, last = math.max(first, (-b - root) / (2 * a)), math.min(last, (-b + root) / (2 * a))
		if first > last then return {} end
	end
	local horizontal, travel = Vector3.new(relative.X, 0, relative.Z), Vector3.new(change.X, 0, change.Z)
	facing, turn = Vector3.new(facing.X, 0, facing.Z), Vector3.new(turn.X, 0, turn.Z)
	local dot = { facing:Dot(horizontal), facing:Dot(travel) + turn:Dot(horizontal), turn:Dot(travel) }
	local facingLength = { facing:Dot(facing), 2 * facing:Dot(turn), turn:Dot(turn) }
	local horizontalLength = { horizontal:Dot(horizontal), 2 * horizontal:Dot(travel), travel:Dot(travel) }
	local cone = { 0, 0, 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do cone[i + j - 1] += dot[i] * dot[j] - 0.0625 * facingLength[i] * horizontalLength[j] end
	end
	local boundaries = { first, last }
	facingLength[1] -= 0.0001
	horizontalLength[1] -= 0.0001
	for _, polynomial in ipairs({ cone, dot, facingLength, horizontalLength }) do
		for _, root in ipairs(polynomialRoots(polynomial, first, last)) do table.insert(boundaries, root) end
	end
	table.sort(boundaries)
	local candidates = {}
	for index, boundary in ipairs(boundaries) do
		table.insert(candidates, boundary)
		if boundaries[index + 1] then table.insert(candidates, (boundary + boundaries[index + 1]) * 0.5) end
	end
	return candidates
end

local function batContact(swing, attacker, target, now, reach, parameters)
	if now < swing.hitAt or now > swing.endsAt + BAT_SAMPLE_MAX_AGE then return false end
	local origin, position = attacker.root.Position, target.root.Position
	local forward = attacker.root.CFrame.LookVector
	local previous, oldTarget = swing.sample, swing.sample and swing.sample.targets[target]
	local elapsed = previous and now - previous.at or 0
	local hasHistory = previous and oldTarget and previous.root == attacker.root
		and oldTarget.character == target.character and oldTarget.root == target.root
		and elapsed > 0 and elapsed <= BAT_SAMPLE_MAX_AGE
		and (origin - previous.origin).Magnitude <= 12 and (position - oldTarget.position).Magnitude <= 12
	local first, last = 1, 1
	if hasHistory then
		first = math.clamp((math.max(swing.hitAt, target.protectedEndsAt or 0) - previous.at) / elapsed, 0, 1)
		last = math.clamp((swing.endsAt - previous.at) / elapsed, 0, 1)
		if previous.at > swing.endsAt or first > last then return false end
	elseif now > swing.endsAt then
		return false
	end
	local oldOrigin = hasHistory and previous.origin or origin
	local oldPosition = hasHistory and oldTarget.position or position
	local relative = oldPosition - oldOrigin
	local change = (position - origin) - relative
	local oldForward = hasHistory and previous.forward or forward
	if workspace:Raycast(origin, position - origin, parameters) then return false end
	local best
	for _, alpha in ipairs(contactIntervals(relative, change, oldForward, forward - oldForward, first, last, reach)) do
		local contactOrigin = oldOrigin:Lerp(origin, alpha)
		local offset = oldPosition:Lerp(position, alpha) - contactOrigin
		local distance = offset.Magnitude
		local direction = hasHistory and previous.forward:Lerp(forward, alpha) or forward
		local horizontal, facing = Vector3.new(offset.X, 0, offset.Z), Vector3.new(direction.X, 0, direction.Z)
		local inFront = horizontal.Magnitude < 0.01 or (facing.Magnitude > 0.01 and facing.Unit:Dot(horizontal.Unit) >= 0.25 - 1e-7)
		if distance <= reach + 1e-5 and inFront and (not best or distance < best)
			and not workspace:Raycast(contactOrigin, offset, parameters) then
			best = distance
		end
	end
	return best ~= nil, best
end

local function chaseGoal(bot, target)
	local delta = target.root.Position - bot.root.Position
	local velocity = target.root.AssemblyLinearVelocity
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * math.clamp(delta.Magnitude / 100, 0.08, 0.25)
	if lead.Magnitude > 4 then lead = lead.Unit * 4 end
	return target.root.Position + lead
end
