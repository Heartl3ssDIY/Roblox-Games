function Toys:_cosmeticExpansion(record, id, root, direction)
	local origin = root.Position + Vector3.new(0, 1.2, 0) + direction * 2
	if not self:_inside(origin) then return end
	if id == "M16" then
		self:_burst(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(208, 246, 255), "snow", 24)
	elseif id == "M17" then
		local snowball = part("ToySnowball", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(238, 252, 255), self.folder)
		snowball.Shape, snowball.Position = Enum.PartType.Ball, origin
		self:_object(record.player, snowball, 3, {kind = "Snowball", position = origin, velocity = direction * 42 + Vector3.new(0, 7, 0), gravity = 32})
	elseif id == "M18" then
		for i = 1, 7 do
			local diameter = self.random:NextNumber(0.3, 0.7)
			local bubble = part("ToyBubble", Vector3.one * diameter, palette[(i % #palette) + 1], self.folder)
			bubble.Shape, bubble.Transparency, bubble.Position = Enum.PartType.Ball, 0.45, origin
			self:_object(record.player, bubble, 2.4, {position = origin, velocity = direction * self.random:NextNumber(4, 9) + Vector3.new(self.random:NextNumber(-2, 2), 2 + i * 0.2, self.random:NextNumber(-2, 2)), gravity = -0.3, cosmetic = true, fade = true})
		end
	elseif id == "M19" then
		local ground = self:_ground(root, 4)
		if ground then
			local banana = self:_visual(id, ground + Vector3.new(0, 0.6, 0), 2)
			if banana then self:_object(record.player, banana, 5) end
		end
	elseif id == "M20" then
		local hit = self:_ray(origin, direction * 4, record.player)
		local contact = hit and hit.Position or origin + direction * 2
		self:_burst(contact, Color3.fromRGB(255, 210, 92), "stars", 12)
		if hit and self.playBonk then self.playBonk(contact) end
	elseif id == "M21" then
		local honey = self:_visual(id, origin, 1.4)
		if honey then self:_object(record.player, honey, 4, {kind = "Honey", position = origin, velocity = direction * 28 + Vector3.new(0, 12, 0), gravity = 40, spin = Vector3.new(1, 2, 0)}) end
	elseif id == "M22" then
		self:_burst(origin, Color3.fromRGB(255, 223, 203), "puff", 16)
	elseif id == "M23" then
		local range = self:_boundedRange(origin, direction, 7)
		local hit = self:_ray(origin, direction * range, record.player)
		local finish = hit and hit.Position or origin + direction * range
		self:_beam(origin, finish, Color3.fromRGB(111, 232, 255))
		self:_burst(finish, Color3.fromRGB(255, 109, 110), "stars", 9)
	elseif id == "M24" then
		local flyer = self:_visual(id, origin, 2)
		if flyer then self:_object(record.player, flyer, 2.4, {flyer = true, position = origin, flightOrigin = origin, flightDirection = direction}) end
	elseif id == "M25" then
		self:_confetti(origin, record.player)
	end
end
