assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Hide and Seek.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = {
 { path = "ServerScriptService.PlaygroundToyService", expected = 510040784, source = [==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Toys = {}
Toys.__index = Toys

local actions = {
	M01 = { pose = "Kick", contact = 0.60, duration = 1.10, cooldown = 5 },
	M02 = { pose = "Lob", contact = 0.34, duration = 0.85, cooldown = 5 },
	M03 = { pose = "Bonk", contact = 0.23, duration = 0.58, cooldown = 0.8 },
	M04 = { pose = "BarrelThrow", contact = 0.52, duration = 1.10, cooldown = 5 },
	M05 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 25.82 },
	M06 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 10.82 },
	M07 = { pose = "Drink", contact = 0.82, duration = 1.30, cooldown = 15.82 },
	M08 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3 },
	M10 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 5 },
	M11 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 2 },
	M12 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M13 = { pose = "Throw", contact = 0.30, duration = 0.78, cooldown = 3 },
	M14 = { pose = "Aim", contact = 0.35, duration = 0.80, cooldown = 1 },
	M15 = { pose = "Place", contact = 0.46, duration = 1, cooldown = 15.46 },
	M16 = { pose = "Drink", contact = 0.82, duration = 1.3, cooldown = 3, cosmetic = true },
	M17 = { pose = "Aim", contact = 0.35, duration = 0.8, cooldown = 1.6, cosmetic = true },
	M18 = { pose = "Aim", contact = 0.35, duration = 0.8, cooldown = 3, cosmetic = true },
	M19 = { pose = "Place", contact = 0.46, duration = 1, cooldown = 5, cosmetic = true },
	M20 = { pose = "Bonk", contact = 0.23, duration = 0.58, cooldown = 1, cosmetic = true },
	M21 = { pose = "Throw", contact = 0.3, duration = 0.78, cooldown = 3, cosmetic = true },
	M22 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3, cosmetic = true },
	M23 = { pose = "Aim", contact = 0.35, duration = 0.8, cooldown = 2, cosmetic = true },
	M24 = { pose = "Throw", contact = 0.3, duration = 0.78, cooldown = 3, cosmetic = true },
	M25 = { pose = "Shake", contact = 0.65, duration = 1.05, cooldown = 3, cosmetic = true },
}
local palette = { Color3.fromRGB(255, 93, 131), Color3.fromRGB(70, 201, 255), Color3.fromRGB(255, 212, 72), Color3.fromRGB(117, 228, 137), Color3.fromRGB(195, 122, 255) }

local function now() return workspace:GetServerTimeNow() end
local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
end
local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 1000000 and math.abs(value.Y) < 1000000 and math.abs(value.Z) < 1000000
end
local function setAttribute(object, key, value)
	if object:GetAttribute(key) ~= value then object:SetAttribute(key, value) end
end
local function part(name, size, color, parent)
	local object = Instance.new("Part")
	object.Name, object.Size, object.Color = name, size, color
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Material, object.TopSurface, object.BottomSurface = Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function Toys.new(options)
	options = options or {}
	return setmetatable({ records = {}, objects = {}, running = false, playBonk = options.playBonk, random = Random.new() }, Toys)
end

function Toys:_inside(position)
	local bounds = self.bounds
	if not bounds or not bounds.Parent or not finiteVector(position) then return false end
	local point, half = bounds.CFrame:PointToObjectSpace(position), bounds.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z and math.abs(point.Y) <= half.Y + 20
end

function Toys:_character(player)
	if not player or player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true or participating(player) or player:GetAttribute("PCToyRoundPreparing") == true then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or not self:_inside(root.Position) then return nil end
	return character, humanoid, root
end

function Toys:_record(player)
	local character, humanoid = self:_character(player)
	if not character then return nil end
	local record = self.records[player]
	if record and record.character ~= character then self:ClearPlayer(player) record = nil end
	if not record then
		record = { player = player, character = character, humanoid = humanoid, cooldowns = {}, serial = 0, speedUntil = 0, jumpUntil = 0, emberUntil = 0, freezeUntil = 0, burnUntil = 0, busyUntil = 0, nextFire = 0 }
		self.records[player] = record
	end
	return record
end

function Toys:CanHold(player)
	return self.running and self:_character(player) ~= nil
end

function Toys:Hold(player)
	return self:CanHold(player) and self:_record(player) ~= nil
end

function Toys:_restoreVisual(record)
	if not record.hidden then return end
	for object, transparency in pairs(record.hidden) do if object.Parent then object.Transparency = transparency end end
	record.hidden = nil
end

function Toys:_hideVisual(record, tool)
	self:_restoreVisual(record)
	local visual = tool:FindFirstChild("Visual")
	if not visual then return end
	record.hidden = {}
	for _, object in ipairs(visual:GetDescendants()) do
		if object:IsA("BasePart") then record.hidden[object] = object.Transparency object.Transparency = 1 end
	end
end

function Toys:_ray(origin, direction, owner, ignoreCharacters)
	local excludes = { self.folder }
	if owner and owner.Character then table.insert(excludes, owner.Character) end
	if ignoreCharacters then for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(excludes, player.Character) end end end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, excludes
	params.IgnoreWater = true
	return workspace:Raycast(origin, direction, params)
end

function Toys:_direction(root, aim)
	local direction = finiteVector(aim) and aim - root.Position or root.CFrame.LookVector
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	return direction.Unit
end

function Toys:_burst(position, color, kind, count, owner)
	local anchor = part("ToyBurst", Vector3.new(0.1, 0.1, 0.1), color, self.folder)
	anchor.Transparency, anchor.Position = 1, position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = kind == "fire" and "rbxasset://textures/particles/fire_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color, kind == "fire" and Color3.fromRGB(255, 211, 80) or Color3.new(1, 1, 1))
	emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.35, 0.8), NumberRange.new(3, 8), Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(kind == "fire" and 0.65 or 0.22, 0)
	emitter.LightEmission, emitter.Parent = 0.3, anchor
	emitter:Emit(count or 16)
	if owner then self:_object(owner, anchor, 1) else Debris:AddItem(anchor, 1) end
end

function Toys:_confetti(position, owner)
	for i = 1, 16 do
		local confetti = part("Confetti", Vector3.new(0.12, 0.05, 0.23), palette[(i - 1) % #palette + 1], self.folder)
		confetti.Position = position
		self:_object(owner, confetti, 2, { position = position, velocity = Vector3.new(self.random:NextNumber(-8, 8), self.random:NextNumber(7, 14), self.random:NextNumber(-8, 8)), gravity = 18, spin = Vector3.new(5, 3, 2), cosmetic = true })
	end
end

function Toys:_object(owner, object, lifetime, data)
	data = data or {}
	data.owner, data.object, data.expiresAt = owner, object, now() + lifetime
	data.bornAt, data.originalPivot = now(), object:GetPivot()
	data.visualOffset = object:GetAttribute("ToyVisualOffset") or CFrame.identity
	table.insert(self.objects, data)
	return data
end

function Toys:_visual(id, position, length)
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local source = assets and assets:FindFirstChild(id)
	if not source or not source:IsA("Model") then return nil end
	local clone = source:Clone()
	clone.Name = "Toy_" .. id
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.CanTouch, child.CanQuery = true, false, false, false
		elseif child:IsA("Highlight") then child.Adornee = clone end
	end
	local box, size = clone:GetBoundingBox()
	clone:ScaleTo(clone:GetScale() * length / math.max(size.X, size.Y, size.Z, 0.1))
	box = clone:GetBoundingBox()
	local offset = box:Inverse() * clone:GetPivot()
	clone:SetAttribute("ToyVisualOffset", offset)
	clone:PivotTo(CFrame.new(position) * offset)
	clone.Parent = self.folder
	return clone
end

function Toys:_ground(root, distance)
	local horizontal = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) else horizontal = horizontal.Unit end
	local origin = root.Position + horizontal * distance + Vector3.new(0, 2, 0)
	local hit = self:_ray(origin, Vector3.new(0, -12, 0), nil, true)
	if hit and hit.Normal.Y > 0.75 and self:_inside(hit.Position) then return hit.Position end
	return nil
end

function Toys:_padGround(root)
	local position = self:_ground(root, 5)
	if not position then return nil end
	for x = -1, 1, 2 do for z = -1, 1, 2 do
		local corner = position + Vector3.new(x * 2.7, 0, z * 2.7)
		if not self:_inside(corner) then return nil end
		local ground = self:_ray(corner + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), nil, true)
		if not ground or ground.Normal.Y < 0.75 or math.abs(ground.Position.Y - position.Y) > 0.5 then return nil end
	end end
	return position
end

function Toys:_boundedRange(origin, direction, distance)
	local target = origin + direction * distance
	if self:_inside(target) then return distance end
	local low, high = 0, distance
	for _ = 1, 14 do
		local middle = (low + high) / 2
		if self:_inside(origin + direction * middle) then low = middle else high = middle end
	end
	return low
end

function Toys:_movement(record, time)
	local humanoid = record.humanoid
	local active = record.speedUntil > time or record.jumpUntil > time or record.freezeUntil > time
	if active and not record.base then
		record.base = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate }
		record.written = {}
	end
	if not record.base then return end
	local frozen = record.freezeUntil > time
	local values = {
		WalkSpeed = frozen and 0 or record.base.WalkSpeed * (record.speedUntil > time and 3 or 1),
		JumpPower = frozen and 0 or record.base.JumpPower * (record.jumpUntil > time and math.sqrt(5) or 1),
		JumpHeight = frozen and 0 or record.base.JumpHeight * (record.jumpUntil > time and 5 or 1),
		AutoRotate = not frozen and record.base.AutoRotate,
	}
	for key, value in pairs(values) do humanoid[key] = value record.written[key] = humanoid[key] end
	if frozen then humanoid.Jump = false end
	if not active then record.base, record.written = nil, nil end
end

function Toys:_burn(owner, target)
	if owner == target or not self:_character(owner) then return end
	local record = self:_record(target)
	if not record or now() < (record.burnImmuneUntil or 0) then return end
	record.burnUntil, record.nextBurn, record.burnImmuneUntil, record.burnOwner = now() + 10, now() + 1, now() + 12, owner
	setAttribute(target, "PCToyBurnUntil", record.burnUntil)
	local root = record.character:FindFirstChild("HumanoidRootPart")
	local fire = Instance.new("Fire")
	fire.Name, fire.Size, fire.Heat = "ToyCampfire", 3, 2
	fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 142, 45), Color3.fromRGB(255, 224, 102)
	fire.Parent, record.fire = root, fire
end

function Toys:_freeze(target, owner)
	local record = self:_record(target)
	if not record or now() < (record.freezeImmuneUntil or 0) then return end
	record.freezeUntil, record.freezeImmuneUntil, record.freezeOwner = now() + 2.5, now() + 6, owner
	self:CancelAction(target)
	setAttribute(target, "PCToyFrozenUntil", record.freezeUntil)
	local outline = Instance.new("Highlight")
	outline.Name, outline.Adornee = "ToyFrost", record.character
	outline.FillColor, outline.FillTransparency = Color3.fromRGB(142, 233, 255), 0.35
	outline.OutlineColor, outline.DepthMode = Color3.fromRGB(214, 252, 255), Enum.HighlightDepthMode.Occluded
	outline.Parent, record.frost = record.character, outline
	self:_movement(record, now())
end

function Toys:_target(hit)
	if not hit then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = self:_character(player)
		if character and hit.Instance:IsDescendantOf(character) then return player end
	end
	return nil
end

function Toys:_beam(origin, destination, color, owner)
	local delta = destination - origin
	if delta.Magnitude < 0.01 then return end
	local beam = part("ToyRay", Vector3.new(0.14, 0.14, delta.Magnitude), color, self.folder)
	beam.Material, beam.CFrame = Enum.Material.Neon, CFrame.lookAt((origin + destination) / 2, destination)
	if owner then self:_object(owner, beam, 0.16) else Debris:AddItem(beam, 0.16) end
end

function Toys:_splat(position, normal, owner, cake)
	local color = cake and Color3.fromRGB(255, 238, 209) or palette[self.random:NextInteger(1, #palette)]
	local frame = CFrame.lookAt(position + normal * 0.04, position + normal)
	for i = 0, 6 do
		local size = i == 0 and 1.55 or self.random:NextNumber(0.25, 0.7)
		local blob = part(cake and "Frosting" or "PaintSplat", Vector3.new(size, size, 0.045), color, self.folder)
		blob.Shape = Enum.PartType.Ball
		local angle = i * math.pi / 3
		blob.CFrame = frame * CFrame.new(i == 0 and 0 or math.cos(angle) * 0.9, i == 0 and 0 or math.sin(angle) * 0.9, 0)
		self:_object(owner, blob, cake and 5 or 10)
	end
end

function Toys:_launch(record, id, root, direction)
	local position = root.Position + Vector3.new(0, 1.3, 0) + direction * 2
	local length, velocity = 1.6, direction * 48 + Vector3.new(0, 15, 0)
	if id == "M02" then velocity = direction * 20 + Vector3.new(0, 48, 0) length = 1.8 end
	if id == "M04" then position = root.Position + Vector3.new(0, 4, 0) velocity = direction * 38 + Vector3.new(0, 18, 0) length = 2.7 end
	if id == "M01" then
		local ground = self:_ground(root, 3)
		if not ground then return end
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		direction = forward.Magnitude > 0.1 and forward.Unit or Vector3.new(0, 0, -1)
		position, velocity = ground + Vector3.new(0, 0.9, 0), direction * 54 + Vector3.new(0, 5, 0)
		if record.stagedBall then
			local staged = record.stagedBall
			record.stagedBall = nil
			staged.kind, staged.position, staged.velocity, staged.gravity, staged.spin, staged.bounces = id, position, velocity, 60, Vector3.new(2, 1, 0), 0
			staged.expiresAt = now() + 5
			return
		end
	end
	local object
	if id == "M11" then
		object = part("FlyingPaint", Vector3.new(0.7, 0.7, 0.7), palette[self.random:NextInteger(1, #palette)], self.folder)
		object.Shape, object.Position = Enum.PartType.Ball, position
	else object = self:_visual(id, position, length) end
	if not object then return end
	self:_object(record.player, object, 5, { kind = id, position = position, velocity = velocity, gravity = 60, spin = Vector3.new(2, 1, 0), bounces = 0 })
end

function Toys:_placePad(record, root)
	local position = self:_padGround(root)
	if not position then return false end
	local model = self:_visual("M15", position + Vector3.new(0, 0.45, 0), 6)
	if not model then return false end
	local surface = part("BounceSurface", Vector3.new(5.2, 0.45, 5.2), Color3.fromRGB(73, 196, 228), model)
	surface.Transparency, surface.CanCollide, surface.CanQuery = 1, true, true
	surface.Position = position + Vector3.new(0, 0.45, 0)
	local entry = self:_object(record.player, model, 15, { kind = "Pad", surface = surface, nextBounce = {} })
	entry.padPosition = position
	setAttribute(record.player, "PCToyPadUntil", entry.expiresAt)
	return true
end

function Toys:_cosmeticExpansion(record, id, root, direction)
	local origin = root.Position + Vector3.new(0, 1.2, 0) + direction * 2
	if not self:_inside(origin) then return end
	if id == "M16" then
		self:_burst(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(208, 246, 255), "snow", 24, record.player)
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
		self:_burst(contact, Color3.fromRGB(255, 210, 92), "stars", 12, record.player)
		if hit and self.playBonk then self.playBonk(contact) end
	elseif id == "M21" then
		local honey = self:_visual(id, origin, 1.4)
		if honey then self:_object(record.player, honey, 4, {kind = "Honey", position = origin, velocity = direction * 28 + Vector3.new(0, 12, 0), gravity = 40, spin = Vector3.new(1, 2, 0)}) end
	elseif id == "M22" then
		self:_burst(origin, Color3.fromRGB(255, 223, 203), "puff", 16, record.player)
	elseif id == "M23" then
		local range = self:_boundedRange(origin, direction, 7)
		local hit = self:_ray(origin, direction * range, record.player)
		local finish = hit and hit.Position or origin + direction * range
		self:_beam(origin, finish, Color3.fromRGB(111, 232, 255), record.player)
		self:_burst(finish, Color3.fromRGB(255, 109, 110), "stars", 9, record.player)
	elseif id == "M24" then
		local flyer = self:_visual(id, origin, 2)
		if flyer then self:_object(record.player, flyer, 2.4, {flyer = true, position = origin, flightOrigin = origin, flightDirection = direction}) end
	elseif id == "M25" then
		self:_confetti(origin, record.player)
	end
end

function Toys:_effect(record, id, aim, fireShot)
	local _, _, root = self:_character(record.player)
	if not root then return end
	local direction = self:_direction(root, aim)
	if actions[id] and actions[id].cosmetic then self:_cosmeticExpansion(record, id, root, direction) return end
	if id == "M05" then record.speedUntil = now() + 25 self:_movement(record, now()) setAttribute(record.player, "PCToySpeedUntil", record.speedUntil)
	elseif id == "M06" then record.jumpUntil = now() + 10 self:_movement(record, now()) setAttribute(record.player, "PCToyJumpUntil", record.jumpUntil)
	elseif id == "M07" and not fireShot then record.emberUntil = now() + 10 setAttribute(record.player, "PCToyEmberUntil", record.emberUntil)
	elseif id == "M07" or id == "M10" then
		local origin = root.Position + Vector3.new(0, 1.4, 0)
		local range = self:_boundedRange(origin, direction, id == "M10" and 55 or 32)
		local hit = self:_ray(origin, direction * range, record.player)
		local destination = hit and hit.Position or origin + direction * range
		self:_beam(origin, destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55), record.player)
		self:_burst(destination, id == "M10" and Color3.fromRGB(140, 233, 255) or Color3.fromRGB(255, 160, 55), id == "M10" and "frost" or "fire", 12, record.player)
		local target = self:_target(hit)
		if target then if id == "M10" then self:_freeze(target, record.player) else self:_burn(record.player, target) end end
	elseif id == "M03" then
		local hit = self:_ray(root.Position + Vector3.new(0, 0.6, 0), direction * 6, record.player)
		if hit then self:_burst(hit.Position, Color3.fromRGB(255, 227, 96), "stars", 12, record.player) if self.playBonk then self.playBonk(hit.Position) end end
	elseif id == "M08" then
		self:_confetti(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), record.player)
	elseif id == "M14" then self:_burst(root.Position + direction * 2, Color3.fromRGB(255, 174, 65), "fire", 6, record.player)
	elseif id == "M15" then
		if not self:_placePad(record, root) then
			record.cooldowns.M15 = 0
			setAttribute(record.player, "PCToyCooldown_M15", 0)
			self:_restoreVisual(record)
		end
	else self:_launch(record, id, root, direction) end
end

function Toys:Use(player, tool, aim)
	local record = self:_record(player)
	if not self.running or not record then return { ok = false, message = "Toys are for the lobby." } end
	local id = player:GetAttribute("PCGear")
	if not tool or tool.Parent ~= record.character or tool:GetAttribute("CatalogId") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return { ok = false, message = "Choose a toy first." } end
	local config = actions[id]
	if not config then return { ok = false, message = id == "M09" and "Plunger Popper is waiting for its plunger model." or "This toy action is not available." } end
	local time = now()
	if time < record.freezeUntil then return { ok = false, message = "Frozen for a moment!" } end
	if time < record.busyUntil then return { ok = false, message = "Finish this action first." } end
	local fireShot = id == "M07" and time < record.emberUntil
	local readyAt = fireShot and record.nextFire or (record.cooldowns[id] or 0)
	if time < readyAt then return { ok = false, message = "Recharging", cooldownEndsAt = readyAt } end
	if aim ~= nil and not finiteVector(aim) then return { ok = false, message = "Invalid aim." } end
	if id == "M15" then local _, _, root = self:_character(player) if not self:_padGround(root) then return { ok = false, message = "Place the pad on open ground." } end end
	local duration, contact, pose = config.duration, config.contact, config.pose
	if fireShot then
		duration, contact, pose = 0.8, 0.35, "Aim"
		record.nextFire = time + 0.8
		setAttribute(player, "PCToyEmberShotUntil", record.nextFire)
	else record.cooldowns[id] = time + config.cooldown end
	record.busyUntil, record.serial = time + duration, record.serial + 1
	local serial = record.serial
	player:SetAttribute("PCToyActionItem", id)
	player:SetAttribute("PCToyAction", pose)
	player:SetAttribute("PCToyActionAt", time)
	player:SetAttribute("PCToyCooldown_" .. id, record.cooldowns[id] or 0)
	local thrown = id == "M01" or id == "M02" or id == "M04" or id == "M12" or id == "M13" or id == "M15" or id == "M19" or id == "M21" or id == "M24"
	if id == "M01" then
		task.delay(0.24, function()
			if not self.running or self.records[player] ~= record or record.serial ~= serial or not self:_character(player) or tool.Parent ~= record.character then return end
			local _, _, root = self:_character(player)
			local ground = root and self:_ground(root, 3)
			if ground then
				self:_hideVisual(record, tool)
				local object = self:_visual(id, ground + Vector3.new(0, 0.9, 0), 1.6)
				if object then record.stagedBall = self:_object(player, object, 5.4) end
			end
		end)
	end
	task.delay(contact, function()
		if not self.running or self.records[player] ~= record or record.serial ~= serial or not self:_character(player)
			or tool.Parent ~= record.character or player:GetAttribute("PCGear") ~= id or record.character:GetAttribute("PCToyHeld") ~= id then return end
		if now() < record.freezeUntil then return end
		if fireShot and now() >= record.emberUntil then return end
		if thrown then self:_hideVisual(record, tool) end
		self:_effect(record, id, aim, fireShot)
	end)
	if thrown then
		task.delay(id == "M15" and config.cooldown or duration, function()
			if self.records[player] == record and record.serial == serial then self:_restoreVisual(record) end
		end)
	end
	return { ok = true, cooldownEndsAt = fireShot and record.nextFire or record.cooldowns[id], message = id == "M07" and not fireShot and "Drink, then tap to breathe fire!" or "" }
end

function Toys:CancelAction(player)
	local record = self.records[player]
	if record then
		record.serial += 1 record.busyUntil = 0
		self:_restoreVisual(record)
		if record.stagedBall then record.stagedBall.object:Destroy() record.stagedBall = nil end
	end
	for _, key in ipairs({ "PCToyAction", "PCToyActionAt", "PCToyActionItem" }) do player:SetAttribute(key, nil) end
end

function Toys:ClearPlayer(player)
	self:CancelAction(player)
	local record = self.records[player]
	if record then
		if record.base and record.humanoid and record.humanoid.Parent then
			for key, value in pairs(record.base) do if record.humanoid[key] == record.written[key] then record.humanoid[key] = value end end
		end
		if record.fire then record.fire:Destroy() end
		if record.frost then record.frost:Destroy() end
		self.records[player] = nil
	end
	for i = #self.objects, 1, -1 do local entry = self.objects[i] if entry.owner == player then entry.object:Destroy() table.remove(self.objects, i) end end
	for _, target in pairs(self.records) do
		if target.burnOwner == player then
			target.burnUntil, target.burnOwner = 0, nil
			if target.fire then target.fire:Destroy() target.fire = nil end
			setAttribute(target.player, "PCToyBurnUntil", 0)
		end
		if target.freezeOwner == player then
			target.freezeUntil, target.freezeOwner = 0, nil
			if target.frost then target.frost:Destroy() target.frost = nil end
			if participating(target.player) or target.player:GetAttribute("PCToyRoundPreparing") == true then
				self:ClearPlayer(target.player)
			else
				self:_movement(target, now())
			end
			setAttribute(target.player, "PCToyFrozenUntil", 0)
		end
	end
	for _, key in ipairs({ "PCToySpeedUntil", "PCToyJumpUntil", "PCToyEmberUntil", "PCToyEmberShotUntil", "PCToyFrozenUntil", "PCToyBurnUntil", "PCToyPadUntil" }) do setAttribute(player, key, 0) end
	for id in pairs(actions) do setAttribute(player, "PCToyCooldown_" .. id, 0) end
end

function Toys:_tickPlayer(record, time)
	local player = record.player
	local _, _, root = self:_character(player)
	if not root or player.Character ~= record.character then self:ClearPlayer(player) return end
	self:_movement(record, time)
	if time >= record.freezeUntil and record.frost then record.frost:Destroy() record.frost = nil end
	if record.burnOwner and not self:_character(record.burnOwner) then record.burnUntil = 0 end
	if record.burnUntil > 0 and time >= record.nextBurn and record.nextBurn <= record.burnUntil then
		record.nextBurn += 1
		record.humanoid:TakeDamage(1)
	end
	if time >= record.burnUntil and record.fire then record.fire:Destroy() record.fire = nil setAttribute(player, "PCToyBurnUntil", 0) end
	if record.character:GetAttribute("PCToyHeld") == "M14" and time >= (record.nextTorch or 0) then
		record.nextTorch = time + 0.3
		local hand = record.character:FindFirstChild("RightHand") or record.character:FindFirstChild("Right Arm")
		local origin = hand and hand.Position or root.Position
		for _, target in ipairs(Players:GetPlayers()) do
			local _, _, targetRoot = self:_character(target)
			if target ~= player and targetRoot and (targetRoot.Position - origin).Magnitude <= 4 then
				local hit = self:_ray(origin, targetRoot.Position - origin, player)
				if hit and hit.Instance:IsDescendantOf(target.Character) then self:_burn(player, target) end
			end
		end
	end
end

function Toys:_tickObject(entry, time, dt)
	local object = entry.object
	if not object.Parent or time >= entry.expiresAt or not self:_character(entry.owner) then
		if entry.kind == "Pad" and object.Parent then self:_burst(entry.padPosition, Color3.fromRGB(100, 217, 240), "stars", 18, entry.owner) end
		return false
	end
	if entry.kind == "Pad" then
		for _, player in ipairs(Players:GetPlayers()) do
			local _, humanoid, root = self:_character(player)
			if root then
				local delta = root.Position - entry.surface.Position
				local footHeight = humanoid.HipHeight + root.Size.Y * 0.5
				local leg = player.Character:FindFirstChild("Left Leg")
				if leg then footHeight += leg.Size.Y end
				if math.abs(delta.X) < 2.8 and math.abs(delta.Z) < 2.8 and math.abs(delta.Y - footHeight) < 1.3 and root.AssemblyLinearVelocity.Y <= 2 and time >= (entry.nextBounce[player] or 0) then
					entry.nextBounce[player] = time + 0.9
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 75, velocity.Z)
					self:_burst(entry.surface.Position, Color3.fromRGB(105, 236, 242), "stars", 10, entry.owner)
				end
			end
		end
		return true
	end
	if entry.flyer then
		local progress = math.clamp((time - entry.bornAt) / 2.4, 0, 1)
		local travel = math.sin(progress * math.pi)
		local position = entry.flightOrigin + entry.flightDirection * (travel * 14) + Vector3.new(0, travel * 3, 0)
		if not self:_inside(position) then return false end
		local obstruction = self:_ray(entry.position, position - entry.position, entry.owner)
		if obstruction then self:_burst(obstruction.Position, Color3.fromRGB(104, 227, 255), "stars", 8, entry.owner) return false end
		entry.position = position
		object:PivotTo(CFrame.new(position) * CFrame.Angles(0, progress * math.pi * 12, 0) * entry.visualOffset)
		return progress < 1
	end
	if entry.fade and object:IsA("BasePart") then
		object.Transparency = math.clamp(0.45 + (time - entry.bornAt) / (entry.expiresAt - entry.bornAt) * 0.55, 0, 1)
	end
	if entry.shakeUntil then
		if time >= entry.shakeUntil then self:_confetti(entry.position, entry.owner) return false end
		object:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, 0, math.sin(time * 38) * 0.13) * entry.visualOffset)
		return true
	end
	if not entry.velocity then return true end
	entry.velocity += Vector3.new(0, -(entry.gravity or 60) * dt, 0)
	local nextPosition = entry.position + entry.velocity * dt
	if not self:_inside(nextPosition) then return false end
	local hit = not entry.cosmetic and self:_ray(entry.position, nextPosition - entry.position, entry.owner)
	if hit then
		if entry.kind == "Snowball" then self:_burst(hit.Position, Color3.fromRGB(219, 247, 255), "snow", 16, entry.owner) return false end
		if entry.kind == "Honey" then
			self:_burst(hit.Position, Color3.fromRGB(255, 206, 75), "honey", 12, entry.owner)
			local splat = part("HoneySplat", Vector3.new(1.6, 1.6, 0.05), Color3.fromRGB(247, 185, 53), self.folder)
			splat.Shape = Enum.PartType.Ball
			splat.CFrame = CFrame.lookAt(hit.Position + hit.Normal * 0.04, hit.Position + hit.Normal)
			self:_object(entry.owner, splat, 4)
			return false
		end
		if entry.kind == "M11" or entry.kind == "M13" then self:_splat(hit.Position, hit.Normal, entry.owner, entry.kind == "M13") return false
		elseif entry.kind == "M12" then
			entry.position = hit.Position + hit.Normal * 0.35
			entry.originalPivot = CFrame.new(entry.position) * entry.visualOffset
			entry.velocity, entry.shakeUntil = nil, time + 0.65
			object:PivotTo(entry.originalPivot)
			return true
		else
			entry.bounces = (entry.bounces or 0) + 1
			if entry.bounces > 8 or entry.velocity.Magnitude < 3 then entry.velocity = nil return true end
			entry.velocity = (entry.velocity - 2 * entry.velocity:Dot(hit.Normal) * hit.Normal) * 0.6
			nextPosition = hit.Position + hit.Normal * (entry.kind == "M04" and 1.1 or 0.75)
		end
	end
	entry.position = nextPosition
	local angle = entry.spin and entry.spin * (time - entry.bornAt) or Vector3.zero
	object:PivotTo(CFrame.new(nextPosition) * CFrame.Angles(angle.X, angle.Y, angle.Z) * entry.visualOffset)
	return true
end

function Toys:Start()
	if self.running then return self end
	local lobby = workspace:WaitForChild("Playground Lobby")
	self.bounds = lobby:WaitForChild("Gameplay"):WaitForChild("LobbyBounds")
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PlaygroundToyEffects", workspace
	self.running = true
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		local time = now()
		for _, record in pairs(self.records) do self:_tickPlayer(record, time) end
		for i = #self.objects, 1, -1 do local entry = self.objects[i] if not self:_tickObject(entry, time, math.min(dt, 0.1)) then entry.object:Destroy() table.remove(self.objects, i) end end
	end)
	self.leaving = Players.PlayerRemoving:Connect(function(player) self:ClearPlayer(player) end)
	return self
end

function Toys:Stop()
	self.running = false
	if self.heartbeat then self.heartbeat:Disconnect() end
	if self.leaving then self.leaving:Disconnect() end
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:ClearPlayer(player) end
	if self.folder then self.folder:Destroy() end
	table.clear(self.objects)
end

return Toys



]==] },
 { path = "ServerScriptService.PlaygroundSecretObbyService", expected = 1048583363, source = [==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Obby = {}
Obby.__index = Obby

local function participating(player)
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true )
end

local function characterOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player.Parent ~= Players or not humanoid or humanoid.Health <= 0 or not root or participating(player) then return nil end
	return character, root, humanoid
end

local function near(player, part, distance)
	local character, root = characterOf(player)
	return character and (root.Position - part.Position).Magnitude <= distance
end

local function footRayLength(character, root)
	local lowest
	for _, name in {"LeftFoot", "RightFoot", "Left Leg", "Right Leg"} do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local frame, size = foot.CFrame, foot.Size
			local extent = (math.abs(frame.RightVector.Y) * size.X + math.abs(frame.UpVector.Y) * size.Y + math.abs(frame.LookVector.Y) * size.Z) * 0.5
			lowest = math.min(lowest or math.huge, foot.Position.Y - extent)
		end
	end
	return math.max(0.5, root.Position.Y - (lowest or (root.Position.Y - root.Size.Y * 1.5))) + 0.6
end

function Obby.new(scene, entry, economy)
	local self = setmetatable({}, Obby)
	self.scene, self.entry, self.economy = scene, entry, economy
	self.runs, self.connections, self.promptTimes = {}, {}, {}
	self.tiles, self.path = {}, {}
	self.tileParts = {}
	self.boundsFrame, self.boundsSize = scene:GetBoundingBox()
	self.floorY = math.huge
	self.random = Random.new()
	self.floorQuery = RaycastParams.new()
	self.floorQuery.FilterType = Enum.RaycastFilterType.Include
	self.floorQuery.FilterDescendantsInstances = {scene.Tiles}
	self.running = false
	self.lastOccupied = os.clock()
	for _, model in scene.Tiles:GetChildren() do
		local row, column = model:GetAttribute("Row"), model:GetAttribute("Column")
		local tile = { model = model, top = model.Top, row = row, column = column, pieces = {} }
		self.floorY = math.min(self.floorY, tile.top.Position.Y + tile.top.Size.Y * 0.5)
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then
			self.tileParts[p] = tile
			table.insert(tile.pieces, {part=p, transparency=p.Transparency, collide=p.CanCollide, query=p.CanQuery, color=p.Color})
		end end
		self.tiles[row] = self.tiles[row] or {}
		self.tiles[row][column] = tile
	end
	self:_newPath()
	return self
end

function Obby:_restoreTile(tile)
	tile.failedAt = nil
	for _, record in tile.pieces do
		record.part.Transparency, record.part.CanCollide, record.part.CanQuery = record.transparency, record.collide, record.query
		record.part.Color = record.color
	end
end

function Obby:_newPath()
	local column = self.random:NextInteger(1, 3)
	for row = 1, 8 do
		column = math.clamp(column + self.random:NextInteger(-1, 1), 1, 3)
		self.path[row] = column
		for _, tile in self.tiles[row] do self:_restoreTile(tile) end
	end
	self.lastOccupied = os.clock()
end

function Obby:_tell(player, text)
	player:SetAttribute("PCRewardText", text)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Obby:_move(player, frame)
	local character, root, humanoid = characterOf(player)
	if not character then return false end
	local seat = humanoid.SeatPart
	local weld = seat and seat:FindFirstChild("SeatWeld")
	humanoid.Sit = false
	if weld and ((weld.Part0 and weld.Part0:IsDescendantOf(character)) or (weld.Part1 and weld.Part1:IsDescendantOf(character))) then weld:Destroy() end
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	character:PivotTo(frame)
	return true
end

function Obby:_reset(player, message)
	local run = self.runs[player]
	if not run then return end
	if self:_move(player, self.scene.StartPoint.CFrame) then
		run.row, run.started, run.lastStep, run.lastPosition = 0, os.clock(), -math.huge, self.scene.StartPoint.Position
		player:SetAttribute("PCSecretObbyRow", 0)
		if message and os.clock() - (run.lastNotice or -math.huge) >= 4 then self:_tell(player, message); run.lastNotice = os.clock() end
	else self.runs[player] = nil end
end

function Obby:_enter(player)
	local opening = self.entry.Opening
	if not near(player, opening, 12) then return end
	local now = os.clock()
	if now - (self.promptTimes[player] or -math.huge) < 1 then return end
	self.promptTimes[player] = now
	if player:GetAttribute("PCDataReady") ~= true then
		self:_tell(player, "Your data is still loading. Try the cave again in a moment.")
		return
	end
	if self:_move(player, self.scene.StartPoint.CFrame) then
		self.runs[player] = { character=player.Character, row=0, started=now, lastStep=-math.huge, lastPosition=self.scene.StartPoint.Position }
		player:SetAttribute("PCSecretObbyRow", 0)
		self:_tell(player, "Secret Steps: find all 8 safe tiles. Daily prize: 1,000 coins!")
	end
end

function Obby:_exit(player)
	if not near(player, self.scene.ReturnPortal.Opening, 12) and not near(player, self.scene.FinishReturnPortal.Opening, 12) then return end
	self.runs[player] = nil
	player:SetAttribute("PCSecretObbyRow", 0)
	self:_move(player, CFrame.lookAt(Vector3.new(-132, 7.6, 54), Vector3.new(-120, 7.6, 54)))
end

function Obby:_claim(player)
	local run = self.runs[player]
	if not run or run.claiming or run.character ~= player.Character or run.row ~= 8
		or os.clock() - run.started < 1.2 or not near(player, self.scene.TreasureChest.Latch, 12) then return end
	run.claiming = true
	local ok, message = self.economy:ClaimSecretObbyReward(player)
	run.claiming = false
	self:_tell(player, message)
end

function Obby:_visit(player, run, tile, now)
	if tile.failedAt then return end
	if self.path[tile.row] ~= tile.column then
		tile.failedAt = now
		tile.top.Color = Color3.fromRGB(255, 110, 117)
		return
	end
	if tile.row <= run.row then return end
	if tile.row ~= run.row + 1 or now - run.lastStep < 0.09 then
		self:_reset(player, "Follow each row of the secret path.")
		return
	end
	run.row, run.lastStep = tile.row, now
	tile.top.Color = Color3.fromRGB(96, 219, 152)
	player:SetAttribute("PCSecretObbyRow", run.row)
end

function Obby:_tick(dt)
	local now = os.clock()
	for _, row in self.tiles do for _, tile in row do
		if tile.failedAt then
			local age = now - tile.failedAt
			if age >= 3.5 then self:_restoreTile(tile)
			elseif age >= 0.18 then for _, record in tile.pieces do record.part.Transparency=1;record.part.CanCollide=false;record.part.CanQuery=false end end
		end
	end end
	local occupied = false
	for player, run in self.runs do
		local character, root, humanoid = characterOf(player)
		if not character or character ~= run.character then
			self.runs[player] = nil
			if player.Parent == Players then player:SetAttribute("PCSecretObbyRow", 0) end
		else
			occupied = true
			local p = root.Position
			local localPosition = self.boundsFrame:PointToObjectSpace(p)
			if p.Y < self.floorY - 6 or p.Y > self.floorY + 65
				or math.abs(localPosition.X) > self.boundsSize.X * 0.5 + 2
				or math.abs(localPosition.Z) > self.boundsSize.Z * 0.5 + 2 then
				self:_reset(player, "Wrong turn! Try the next tile.")
			elseif run.lastPosition and (p - run.lastPosition).Magnitude > math.max(18, humanoid.WalkSpeed * dt * 4 + 8) then
				self:_reset(player, "Follow each row of the secret path.")
			else
				local floor = workspace:Raycast(p, Vector3.new(0, -footRayLength(character, root), 0), self.floorQuery)
				local tile = floor and self.tileParts[floor.Instance]
				if tile and floor.Normal.Y > 0.5 then self:_visit(player, run, tile, now) end
			end
			run.lastPosition = root.Position
		end
	end
	if occupied then self.lastOccupied = now elseif now - self.lastOccupied > 120 then self:_newPath() end
end

function Obby:Start()
	if self.running then return self end
	self.running = true
	table.insert(self.connections, self.entry.Opening.Travel.Triggered:Connect(function(player) self:_enter(player) end))
	table.insert(self.connections, self.scene.ReturnPortal.Opening.Travel.Triggered:Connect(function(player) self:_exit(player) end))
	table.insert(self.connections, self.scene.FinishReturnPortal.Opening.Travel.Triggered:Connect(function(player) self:_exit(player) end))
	table.insert(self.connections, self.scene.TreasureChest.Latch.ClaimReward.Triggered:Connect(function(player) self:_claim(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.runs[player]=nil;self.promptTimes[player]=nil end))
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.08 then local delta=elapsed;elapsed=0;self:_tick(delta) end
	end))
	return self
end

function Obby:Stop()
	self.running = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player in self.runs do if player.Parent == Players then self:_move(player, CFrame.new(-132, 7.6, 54));player:SetAttribute("PCSecretObbyRow", 0) end end
	table.clear(self.runs)
	for _, row in self.tiles do for _, tile in row do self:_restoreTile(tile) end end
end

return Obby]==] },
 { path = "ServerScriptService.PlaygroundLobbySwingService", expected = 1736078440, source = [==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Swing = {}
local active
local roundAttributes = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }

local function inRound(player)
	for _, attribute in ipairs(roundAttributes) do
		if player:GetAttribute(attribute) == true then return true end
	end
	return false
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function release(entry)
	local humanoid = entry.seat.Occupant
	local weld = entry.seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	if humanoid and humanoid.Parent then humanoid.Sit = false end
end

function Swing.Start()
	if active then return active end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local model = lobby and lobby:FindFirstChild("PlaygroundLobbySwing")
	if not model then return nil end
	local self = { connections = {}, entries = {}, running = true, model = model }
	active = self
	for _, assembly in ipairs(model.Seats:GetChildren()) do
		local seat = assembly:FindFirstChild("Seat")
		local hinge = assembly:FindFirstChild("SwingHinge")
		local prompt = seat and seat:FindFirstChild("SitPrompt")
		if not seat or not hinge or not prompt then continue end
		for _, part in ipairs(assembly:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
		local entry = { seat = seat, hinge = hinge, prompt = prompt, ramp = 0, phase = 0, occupantConnections = {}, lastRequest = {} }
		table.insert(self.entries, entry)
		local function occupantChanged()
			disconnect(entry.occupantConnections)
			local previousPlayer = entry.player
			local previousRoot = entry.root
			local humanoid = seat.Occupant
			local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			prompt.Enabled = humanoid == nil and self.running
			entry.player = player
			entry.root = humanoid and humanoid.Parent:FindFirstChild("HumanoidRootPart")
			if previousPlayer ~= player and previousRoot and previousRoot.Parent then
				pcall(previousRoot.SetNetworkOwnershipAuto, previousRoot)
			end
			if humanoid and (not player or inRound(player) or humanoid.Health <= 0) then release(entry) return end
			if not humanoid then return end
			entry.phase = 0
			entry.ramp = 0
			pcall(seat.SetNetworkOwner, seat, nil)
			for _, attribute in ipairs(roundAttributes) do
				table.insert(entry.occupantConnections, player:GetAttributeChangedSignal(attribute):Connect(function()
					if inRound(player) then release(entry) end
				end))
			end
			table.insert(entry.occupantConnections, humanoid.Died:Connect(function() release(entry) end))
		end
		table.insert(self.connections, seat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged))
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			if not self.running or player.Parent ~= Players or seat.Occupant or inRound(player) then return end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart or root.Anchored then return end
			if (root.Position - seat.Position).Magnitude > prompt.MaxActivationDistance + 2 then return end
			local now = os.clock()
			if now - (entry.lastRequest[player] or -math.huge) < 1 then return end
			entry.lastRequest[player] = now
			humanoid:UnequipTools()
			seat:Sit(humanoid)
		end))
		pcall(seat.SetNetworkOwner, seat, nil)
		occupantChanged()
	end
	local accumulator = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then return end
		local elapsed = math.min(accumulator, 0.1)
		accumulator = 0
		if not model.Parent then Swing.Stop() return end
		for _, entry in ipairs(self.entries) do
			local occupied = entry.seat.Occupant ~= nil and entry.player and not inRound(entry.player)
			local amplitude = math.clamp(model:GetAttribute("SwingAngle") or 26, 8, 30)
			local period = math.clamp(model:GetAttribute("SwingPeriod") or 4.5, 3.5, 8)
			entry.ramp += ((occupied and 1 or 0) - entry.ramp) * math.min(elapsed * 1.6, 1)
			entry.phase += elapsed * math.pi * 2 / period
			entry.hinge.TargetAngle = math.sin(entry.phase) * amplitude * entry.ramp
			if not occupied and entry.ramp < 0.003 then entry.hinge.TargetAngle = 0 end
		end
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		for _, entry in ipairs(self.entries) do
			entry.lastRequest[player] = nil
			if entry.player == player then release(entry) end
		end
	end))
	function self:Stop() Swing.Stop() end
	return self
end

function Swing.Stop()
	local self = active
	if not self then return end
	self.running = false
	active = nil
	disconnect(self.connections)
	for _, entry in ipairs(self.entries) do
		disconnect(entry.occupantConnections)
		entry.prompt.Enabled = false
		entry.hinge.TargetAngle = 0
		release(entry)
		if entry.root and entry.root.Parent then pcall(entry.root.SetNetworkOwnershipAuto, entry.root) end
	end
end

return Swing

]==] },
 { path = "ServerScriptService.PlaygroundLobbyBenchService", expected = 1350272645, source = [==[local Players = game:GetService("Players")

local Benches = {}
local active
local roundAttributes = { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating" }

local function inRound(player)
	for _, attribute in ipairs(roundAttributes) do
		if player:GetAttribute(attribute) == true then return true end
	end
	return false
end

local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function release(entry)
	local humanoid = entry.seat.Occupant
	local weld = entry.seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	if humanoid and humanoid.Parent then humanoid.Sit = false end
end

function Benches.Start()
	if active then return active end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	if not lobby then return nil end
	local self = { connections = {}, entries = {}, running = true }
	active = self
	for _, seat in ipairs(lobby:GetDescendants()) do
		if not seat:IsA("Seat") or seat:GetAttribute("PCBenchSeat") ~= true then continue end
		local prompt = seat:FindFirstChild("SitPrompt", true)
		if not prompt then continue end
		local entry = { seat = seat, prompt = prompt, occupantConnections = {}, lastRequest = {} }
		table.insert(self.entries, entry)
		local function occupantChanged()
			disconnect(entry.occupantConnections)
			local humanoid = seat.Occupant
			local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
			entry.player = player
			prompt.Enabled = humanoid == nil and self.running
			if humanoid and (not player or inRound(player) or humanoid.Health <= 0) then release(entry) return end
			if not humanoid then return end
			for _, attribute in ipairs(roundAttributes) do
				table.insert(entry.occupantConnections, player:GetAttributeChangedSignal(attribute):Connect(function()
					if inRound(player) then release(entry) end
				end))
			end
			table.insert(entry.occupantConnections, humanoid.Died:Connect(function() release(entry) end))
		end
		table.insert(self.connections, seat:GetPropertyChangedSignal("Occupant"):Connect(occupantChanged))
		table.insert(self.connections, prompt.Triggered:Connect(function(player)
			if not self.running or player.Parent ~= Players or seat.Occupant or inRound(player) then return end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart or root.Anchored then return end
			if (root.Position - seat.Position).Magnitude > prompt.MaxActivationDistance + 1 then return end
			local now = os.clock()
			if now - (entry.lastRequest[player] or -math.huge) < 0.75 then return end
			entry.lastRequest[player] = now
			humanoid:UnequipTools()
			seat:Sit(humanoid)
		end))
		occupantChanged()
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		for _, entry in ipairs(self.entries) do
			entry.lastRequest[player] = nil
			if entry.player == player then release(entry) end
		end
	end))
	function self:Stop() Benches.Stop() end
	return self
end

function Benches.Stop()
	local self = active
	if not self then return end
	active, self.running = nil, false
	disconnect(self.connections)
	for _, entry in ipairs(self.entries) do
		disconnect(entry.occupantConnections)
		entry.prompt.Enabled = false
		release(entry)
	end
end

return Benches

]==] },
 { path = "ServerScriptService.PlaygroundFishingService", expected = 1692913973, source = [==[local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Fishing = {}
Fishing.__index = Fishing

local function characterOf(player)
	if player.Parent ~= Players or player:GetAttribute("PCDataReady") ~= true
		or player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true
		or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true ) then return nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return character, root
end

function Fishing.new(scene, economy)
	local self = setmetatable({ scene = scene, economy = economy, stations = {}, runs = {}, requests = {}, connections = {}, running = false }, Fishing)
	for index = 1, 4 do
		local model = assert(scene:FindFirstChild("Rod" .. index), "Fishing rod is missing")
		local interaction = assert(model:FindFirstChild("Interaction"), "Fishing interaction is missing")
		local prompt = assert(interaction:FindFirstChild("Fish"), "Fishing prompt is missing")
		local bobber = assert(model:FindFirstChild("Bobber"), "Fishing bobber is missing")
		table.insert(self.stations, { model = model, interaction = interaction, prompt = prompt, bobber = bobber, rest = bobber.CFrame })
	end
	return self
end

function Fishing:_tell(player, message)
	if player.Parent ~= Players then return end
	player:SetAttribute("PCRewardText", message)
	player:SetAttribute("PCRewardAt", workspace:GetServerTimeNow())
end

function Fishing:_valid(player, station, character)
	local current, root = characterOf(player)
	return current ~= nil and (character == nil or current == character)
		and station.model:IsDescendantOf(self.scene) and station.interaction.Parent ~= nil
		and (root.Position - station.interaction.Position).Magnitude <= 10
end

function Fishing:_finish(player, run, message)
	if self.runs[player] ~= run then return end
	self.runs[player] = nil
	local station = run.station
	if station.run == run then
		station.run = nil
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
		if station.prompt.Parent then station.prompt.Enabled = self.running end
		if station.model.Parent then station.model:SetAttribute("FishingUserId", nil) end
	end
	if player.Parent == Players then
		player:SetAttribute("PCFishingCasting", false)
		player:SetAttribute("PCFishingCastEnds", 0)
		if message then self:_tell(player, message) end
	end
end

function Fishing:_begin(player, station)
	if not self.running or station.run or self.runs[player] or not self:_valid(player, station) then return end
	local now = os.clock()
	if now - (self.requests[player] or -math.huge) < 0.75 then return end
	self.requests[player] = now
	local ok, reason = self.economy:CanFish(player)
	if not ok then self:_tell(player, reason or "Fishing isn't available right now.") return end
	if station.run or self.runs[player] or not self.running or not self:_valid(player, station) then return end
	local run = { station = station, character = player.Character, started = os.clock(), claiming = false }
	self.runs[player], station.run = run, run
	station.prompt.Enabled = false
	station.model:SetAttribute("FishingUserId", player.UserId)
	player:SetAttribute("PCFishingCasting", true)
	player:SetAttribute("PCFishingCastEnds", workspace:GetServerTimeNow() + 6)
	self:_tell(player, "Fishing... stay by the rod until you get a bite!")
end

function Fishing:_claim(player, run)
	if run.claiming or self.runs[player] ~= run or not self.running then return end
	if not self:_valid(player, run.station, run.character) then self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.") return end
	run.claiming = true
	local called, ok, message = pcall(function() return self.economy:ClaimFishingReward(player) end)
	if not called then
		warn("Fishing reward could not finish: " .. tostring(ok))
		message = "Your catch couldn't be confirmed. Please try the rod again."
	elseif typeof(message) ~= "string" then
		message = ok and "Caught a five-minute boost!" or "Your catch couldn't be confirmed. Try again."
	end
	self:_finish(player, run, message)
end

function Fishing:_step(now)
	for player, run in self.runs do
		if run.claiming then continue end
		if not self:_valid(player, run.station, run.character) then
			self:_finish(player, run, "Fishing cancelled. Your catch wasn't used.")
		else
			local elapsed = now - run.started
			local dip = elapsed > 4.8 and -0.22 or 0
			run.station.bobber.CFrame = run.station.rest * CFrame.new(0, math.sin(elapsed * 5) * 0.055 + dip, 0)
			if elapsed >= 6 then
				run.claiming = true
				task.spawn(function()
					run.claiming = false
					self:_claim(player, run)
				end)
			end
		end
	end
end

function Fishing:Start()
	if self.running then return self end
	self.running = true
	for _, station in self.stations do
		station.prompt.Enabled = true
		station.model:SetAttribute("FishingUserId", nil)
		table.insert(self.connections, station.prompt.Triggered:Connect(function(player) self:_begin(player, station) end))
	end
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		local run = self.runs[player]
		if run then self:_finish(player, run) end
		self.requests[player] = nil
	end))
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.08 then elapsed = 0 self:_step(os.clock()) end
	end))
	return self
end

function Fishing:Stop()
	self.running = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player, run in self.runs do self:_finish(player, run) end
	table.clear(self.requests)
	for _, station in self.stations do
		if station.prompt.Parent then station.prompt.Enabled = false end
		if station.bobber.Parent then station.bobber.CFrame = station.rest end
	end
end

return Fishing

]==] },
 { path = "ServerScriptService.PlaygroundAdminService", expected = 1853255660, source = [==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
	MudStart = { game = "StuckInTheMud" }, MudShooter = { game = "StuckInTheMud", role = "Shooter" }, MudMedic = { game = "StuckInTheMud", role = "Medic" },
}
controls.HSStart = { game = "HideAndSeek" }
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true, GrantVIP = true, GrantBetaTester = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	local userId = player and player.UserId
	if typeof(userId) ~= "number" or userId <= 0 or userId % 1 ~= 0 or userId >= 9007199254740991 then return false end
	if userId == self.config:GetAttribute("AdminUserId") then return true end
	local extraIds = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extraIds) ~= "string" then return false end
	for token in extraIds:gmatch("[^,]+") do
		local digits = token:match("^%s*(%d+)%s*$")
		if digits and tonumber(digits) == userId then return true end
	end
	return false
end

function Admin:_target(player, payload)
	if payload ~= nil and typeof(payload) ~= "table" then return nil, "Choose a player in this server." end
	local id = player.UserId
	if payload and payload.targetUserId ~= nil then id = payload.targetUserId end
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id == 0 or math.abs(id) > 1000000000000 or (id < 0 and not self.isStudio) then
		return nil, "Choose a player in this server."
	end
	local target = self.players:GetPlayerByUserId(id)
	if not target then return nil, "That player is no longer in this server." end
	return target
end

function Admin:Status(player, ok, message, target)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "HideAndSeek" and player:GetAttribute("HSRole") or active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
	reply.players = {}
	for _, online in ipairs(self.players:GetPlayers()) do
		table.insert(reply.players, { userId = online.UserId, name = online.Name, displayName = online.DisplayName, ready = online:GetAttribute("PCDataReady") == true })
	end
	table.sort(reply.players, function(a, b)
		if a.name == b.name then return a.userId < b.userId end
		return a.name:lower() < b.name:lower()
	end)
	local economy = self.coordinator.economy
	if economy then
		reply.limits = table.clone(economy.AdminLimits)
		if target == false then target = nil
		else target = target or self.players:GetPlayerByUserId(player.UserId) end
		if target then
			reply.targetUserId = target.UserId
			reply.target = economy:Status(target, true)
			reply.target.userId = target.UserId
			reply.target.name = target.Name
			reply.target.displayName = target.DisplayName
		end
	end
	return reply
end

function Admin:Handle(player, action, payload)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and not grants[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local target, targetError
	if grants[action] or action == "GetStatus" then
		if grants[action] and (typeof(payload) ~= "table" or payload.targetUserId == nil) then return self:Status(player, false, "Choose a target player for this action.") end
		target, targetError = self:_target(player, payload)
		if not target then return self:Status(player, false, targetError, false) end
	end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.", target) end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.", target) end
	if self.busy then return self:Status(player, false, "Another control is finishing.", target) end
	self.busy = true
	local ok, success, message = pcall(function()
		if grants[action] then
			local economy = self.coordinator.economy
			if not economy then return false, "The player economy is not ready." end
			if typeof(payload) ~= "table" then return false, "Choose an item or grant amount." end
			if action == "GrantItem" then
				return economy:AdminGrantItem(target, payload.itemId, payload.equip)
			end
			if action == "GrantCoins" then return economy:AdminGrantCoins(target, payload.amount) end
			if action == "AddLevels" then return economy:AdminAddLevels(target, payload.amount) end
			if action == "GrantVIP" then return economy:AdminGrantEntitlement(target, "VIP") end
			if action == "GrantBetaTester" then return economy:AdminGrantEntitlement(target, "BetaTester") end
		end
		if action == "StopRound" then return self.coordinator:StopGame() end
		if action == "ToggleAutomatic" then
			self.coordinator:SetAutoEnabled(not self.coordinator.autoEnabled)
			return true, self.coordinator.autoEnabled and "Automatic voting rounds are on." or "Automatic rounds paused."
		end
		local control = controls[action]
		local started, reason = self.coordinator:StartGame(control.game, player, control.role, false)
		if not started and reason == "Not enough ready players" then reason = "Use a solo button to test alone. Normal rounds need two players." end
		return started, started and "Starting your game." or reason
	end)
	self.busy = false
	if not ok then
		warn("Playground admin command failed: " .. tostring(success))
		return self:Status(player, false, "That admin action could not finish. Try again.", target)
	end
	if success and grants[action] then print("Playground admin " .. player.UserId .. " used " .. action .. " for " .. target.UserId) end
	return self:Status(player, success == true, message, target)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action, payload) return self:Handle(player, action, payload) end
	local function bind(player) player:SetAttribute("PlaygroundAdmin", self:IsAuthorized(player)) end
	table.insert(self.connections, Players.PlayerAdded:Connect(bind))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastRequest[player] = nil self.lastStatus[player] = nil end))
	for _, player in ipairs(Players:GetPlayers()) do bind(player) end
	table.insert(self.connections, config.AttributeChanged:Connect(function() for _, player in ipairs(Players:GetPlayers()) do bind(player) end end))
	return self
end

function Admin:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	if self.remote then self.remote.OnServerInvoke = nil end
end

return Admin
]==] },
}
local function fingerprint(source)
 source = string.gsub(source, "\r\n", "\n")
 local value = 0
 for index = 1, #source do value = (value * 31 + string.byte(source,index)) % 2147483647 end
 return value
end
local objects = {}
for _, entry in entries do
 local object = game
 for name in string.gmatch(entry.path, "[^.]+") do object = object:FindFirstChild(name) assert(object, "Missing " .. entry.path) end
 assert(object:IsA("LuaSourceContainer"), "Invalid script " .. entry.path)
 assert(fingerprint(object.Source) == entry.expected, "Source changed: " .. entry.path)
 objects[entry.path] = object
end
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("HideAndSeekIntegrationBackup20261010")
if not backup then backup = Instance.new("Folder") backup.Name, backup.Parent = "HideAndSeekIntegrationBackup20261010",storage end
for _, entry in entries do
 local object = objects[entry.path]
 local snapshot = object:Clone()
 snapshot.Name = entry.path
 if snapshot:IsA("BaseScript") then snapshot.Enabled = false end
 snapshot.Parent = backup
 object.Source = entry.source
 object:SetAttribute("HideAndSeekIntegrated20261010",true)
end
return { patched = #entries, capabilitiesPreserved = true, backup = backup:GetFullName() }

