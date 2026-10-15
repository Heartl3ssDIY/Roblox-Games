local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local Equipment = {}
Equipment.__index = Equipment

local sparkTexture = "rbxasset://textures/particles/sparkles_main.dds"
local smokeTexture = "rbxasset://textures/particles/smoke_main.dds"
local fireTexture = "rbxasset://textures/particles/fire_main.dds"
local starTexture = sparkTexture
local heartTexture = smokeTexture

local batEffects = {
	B01 = { name = "Sawdust Swirl", color = Color3.fromRGB(227, 169, 91), accent = Color3.fromRGB(255, 233, 185), texture = smokeTexture, rate = 5, speed = 0.55, size = 0.12, gravity = -0.8, spin = 75, glow = 0, squash = 0.6, trail = 0.12 },
	B02 = { name = "Alloy Glints", color = Color3.fromRGB(186, 231, 255), accent = Color3.new(1, 1, 1), texture = sparkTexture, rate = 3, speed = 0.12, size = 0.23, gravity = 0.1, spin = 15, glow = 0.55, lines = "alloy", trail = 0.14 },
	B03 = { name = "Varsity Confetti", color = Color3.fromRGB(255, 85, 105), accent = Color3.fromRGB(112, 195, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.16, gravity = -2.2, spin = 180, glow = 0, squash = 1.3, secondary = true, trail = 0.15 },
	B04 = { name = "Hazard Beacon", color = Color3.fromRGB(255, 153, 36), accent = Color3.fromRGB(255, 244, 172), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.2, gravity = 0.2, spin = 0, glow = 0.65, lines = "hazard", trail = 0.14 },
	B05 = { name = "Bubblegum Hearts", color = Color3.fromRGB(255, 136, 209), accent = Color3.fromRGB(255, 226, 250), texture = heartTexture, rate = 3, speed = 0.7, size = 0.26, gravity = 0.3, spin = 20, glow = 0.1, secondary = true, lines = "heart", trail = 0.19 },
	B06 = { name = "Muddy Droplets", color = Color3.fromRGB(139, 90, 45), accent = Color3.fromRGB(191, 156, 83), texture = smokeTexture, rate = 6, speed = 0.6, size = 0.22, gravity = -3, spin = 45, glow = 0, squash = 0.3, trail = 0.12 },
	B07 = { name = "Coil Embers", color = Color3.fromRGB(255, 97, 25), accent = Color3.fromRGB(255, 217, 70), texture = fireTexture, rate = 6, speed = 0.65, size = 0.29, gravity = 0.9, spin = 20, glow = 0.75, secondary = true, trail = 0.18 },
	B08 = { name = "Frost Crystals", color = Color3.fromRGB(124, 229, 255), accent = Color3.fromRGB(232, 255, 255), texture = sparkTexture, rate = 4, speed = 0.25, size = 0.24, gravity = -0.3, spin = 40, glow = 0.35, mist = true, trail = 0.22 },
	B09 = { name = "Circuit Arcs", color = Color3.fromRGB(77, 139, 255), accent = Color3.fromRGB(199, 253, 255), texture = sparkTexture, rate = 7, speed = 1, size = 0.12, gravity = 0, spin = 120, glow = 0.8, lines = "lightning", trail = 0.12 },
	B10 = { name = "Arcade Pixels", color = Color3.fromRGB(248, 89, 235), accent = Color3.fromRGB(87, 247, 219), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.35, spin = 0, glow = 0.5, squash = -0.4, lines = "pixels", trail = 0.1 },
	B11 = { name = "Orbit Stardust", color = Color3.fromRGB(176, 126, 255), accent = Color3.fromRGB(134, 222, 255), texture = starTexture, rate = 3, speed = 0.3, size = 0.19, gravity = 0.25, spin = 65, glow = 0.6, lines = "orbit", trail = 0.25 },
	B12 = { name = "Champion Stars", color = Color3.fromRGB(255, 213, 64), accent = Color3.fromRGB(255, 247, 180), texture = starTexture, rate = 4, speed = 0.55, size = 0.26, gravity = 0.45, spin = 30, glow = 0.45, lines = "crown", trail = 0.2 },
	B13 = { name = "Skatepark Ribbons", color = Color3.fromRGB(78, 228, 206), accent = Color3.fromRGB(255, 133, 140), texture = sparkTexture, rate = 3, speed = 0.35, size = 0.12, gravity = 0, spin = 80, glow = 0.25, ribbons = true, trail = 0.23 },
	B14 = { name = "Ocean Spray", color = Color3.fromRGB(62, 218, 214), accent = Color3.fromRGB(161, 247, 255), texture = smokeTexture, rate = 5, speed = 0.7, size = 0.19, gravity = 0.6, spin = 35, glow = 0.15, mist = true, lines = "wave", trail = 0.23 },
	B15 = { name = "Sunburst Rays", color = Color3.fromRGB(255, 175, 35), accent = Color3.fromRGB(255, 246, 112), texture = sparkTexture, rate = 5, speed = 0.6, size = 0.16, gravity = 0.45, spin = 60, glow = 0.65, lines = "sun", trail = 0.21 },
}

local function effectAttachment(anchor, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = anchor
	return attachment
end

local function effectEmitter(parent, name, effect, secondary)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = effect.texture
	emitter.Color = ColorSequence.new(secondary and effect.accent or effect.color, effect.accent)
	emitter.Rate = secondary and 2 or effect.rate
	emitter.Lifetime = NumberRange.new(0.45, 0.95)
	emitter.Speed = NumberRange.new(effect.speed * 0.5, effect.speed)
	emitter.Acceleration = Vector3.new(0, effect.gravity, 0)
	emitter.Drag = 1.5
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-effect.spin, effect.spin)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, effect.size * 0.3), NumberSequenceKeypoint.new(0.2, effect.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.15, 0.12), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = effect.glow
	emitter.LightInfluence = 0.2
	emitter.VelocityInheritance = 0.15
	emitter.Squash = NumberSequence.new(effect.squash or 0)
	emitter:SetAttribute("BatHitBurst", secondary and 4 or 8)
	emitter.Parent = parent
	return emitter
end

local function effectLine(anchor, folder, name, first, last, color, width)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = effectAttachment(anchor, name .. "A", first)
	beam.Attachment1 = effectAttachment(anchor, name .. "B", last)
	beam.Width0 = width or 0.035
	beam.Width1 = width or 0.035
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.22)
	beam.LightEmission = 0.65
	beam.LightInfluence = 0.1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = folder
	return beam
end

local function effectTrail(anchor, folder, name, first, last, color, lifetime)
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0 = effectAttachment(anchor, name .. "A", first)
	trail.Attachment1 = effectAttachment(anchor, name .. "B", last)
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = lifetime
	trail.MinLength = 0.06
	trail.FaceCamera = true
	trail.LightEmission = 0.35
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = folder
end

function Equipment:_attachBatEffects(carrier, anchor, item, sourceSize, gripHeight)
	local effect = batEffects[item.id]
	if not effect then return end
	carrier:SetAttribute("HeldEffect", effect.name)
	local folder = Instance.new("Folder")
	folder.Name = "HeldVFX"
	folder.Parent = carrier
	local top = sourceSize.Y - gripHeight
	local middle = top * 0.68
	local radius = math.clamp(math.max(sourceSize.X, sourceSize.Z) * 0.55, 0.18, 0.48)
	local tip = effectAttachment(anchor, "BatEffectTip", Vector3.new(0, top, 0))
	local barrel = effectAttachment(anchor, "BatEffectBarrel", Vector3.new(0, middle, 0))
	effectEmitter(tip, effect.name, effect, false)
	if effect.secondary then effectEmitter(barrel, effect.name .. "Accent", effect, true) end
	if effect.mist then
		local mist = effectEmitter(barrel, "SoftMist", effect, true)
		mist.Texture = smokeTexture
		mist.Size = NumberSequence.new(0.13, 0.4)
		mist.Transparency = NumberSequence.new(0.82, 1)
	end
	effectTrail(anchor, folder, "MotionRibbon", Vector3.new(-radius * 0.7, top, 0), Vector3.new(radius * 0.7, top, 0), effect.color, effect.trail)
	if effect.ribbons then
		for i = -1, 1, 2 do
			local point = Vector3.new(radius * i, middle, 0)
			effectTrail(anchor, folder, "SkateRibbon" .. i, point, point + Vector3.new(0, 0.14, 0), i == -1 and effect.accent or effect.color, 0.3)
		end
	end
	local style = effect.lines
	if style == "orbit" or style == "hazard" then
		local count = style == "orbit" and 16 or 8
		for i = 1, count do
			local a, b = (i - 1) / count * math.pi * 2, i / count * math.pi * 2
			local tilt = style == "orbit" and 0.22 or 0
			local p = Vector3.new(math.cos(a) * radius * 1.3, middle + math.sin(a) * tilt, math.sin(a) * radius * 1.3)
			local q = Vector3.new(math.cos(b) * radius * 1.3, middle + math.sin(b) * tilt, math.sin(b) * radius * 1.3)
			effectLine(anchor, folder, "Ring" .. i, p, q, i % 2 == 0 and effect.color or effect.accent)
		end
	elseif style == "heart" then
		local function point(angle)
			local x = 16 * math.sin(angle) ^ 3
			local y = 13 * math.cos(angle) - 5 * math.cos(2 * angle) - 2 * math.cos(3 * angle) - math.cos(4 * angle)
			return Vector3.new(x / 16 * radius, top * 0.8 + y / 16 * radius, -radius * 1.25)
		end
		for i = 1, 20 do
			effectLine(anchor, folder, "Heart" .. i, point((i - 1) / 20 * math.pi * 2), point(i / 20 * math.pi * 2), effect.accent, 0.028)
		end
	elseif style == "lightning" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 5 do
				local nextPoint = Vector3.new((radius + (i % 2) * 0.1) * side, middle * 0.55 + i * top * 0.09, (i % 2 - 0.5) * 0.2)
				effectLine(anchor, folder, "Arc" .. side .. "_" .. i, previous, nextPoint, effect.accent, 0.028)
				previous = nextPoint
			end
		end
	elseif style == "sun" then
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			effectLine(anchor, folder, "Ray" .. i, Vector3.new(0, top * 0.87, 0) + direction * radius, Vector3.new(0, top * 0.87, 0) + direction * radius * 1.5, effect.accent, 0.04)
		end
	elseif style == "pixels" then
		for i = 1, 4 do
			local center = Vector3.new((i % 2 == 0 and -1 or 1) * radius * 1.3, middle + (i - 2.5) * 0.2, 0)
			local color = i % 2 == 0 and effect.color or effect.accent
			effectLine(anchor, folder, "Pixel" .. i, center, center + Vector3.new(0.07, 0, 0), color, 0.07)
		end
	elseif style == "wave" then
		for side = -1, 1, 2 do
			local previous = Vector3.new(radius * side, middle * 0.55, 0)
			for i = 1, 8 do
				local point = Vector3.new((radius + math.sin(i * 0.8) * 0.1) * side, middle * 0.55 + top * i * 0.06, 0)
				effectLine(anchor, folder, "Wave" .. side .. "_" .. i, previous, point, effect.accent, 0.025)
				previous = point
			end
		end
	elseif style == "alloy" then
		for side = -1, 1, 2 do
			effectLine(anchor, folder, "ChromeEdge" .. side, Vector3.new(radius * side, middle, 0), Vector3.new(radius * side * 0.8, top * 0.91, 0), effect.accent, 0.02)
		end
	elseif style == "crown" then
		local previous = Vector3.new(-radius, top * 0.85, -radius)
		for i = 1, 4 do
			local point = Vector3.new(-radius + i * radius * 0.5, top * 0.85 + (i % 2) * 0.15, -radius)
			effectLine(anchor, folder, "Crown" .. i, previous, point, effect.accent, 0.035)
			previous = point
		end
	end
end

function Equipment:_batHitEffect(record)
	if not record.bat or not record.bat.Parent then return end
	for _, emitter in ipairs(record.bat:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then emitter:Emit(emitter:GetAttribute("BatHitBurst") or 6) end
	end
end


local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end

local function participating(player)
	return player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true
		or player:GetAttribute("MDParticipating") == true
end

local function visibleBounds(model)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part:GetAttribute("PCStudLayer") ~= true then
			for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
				local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
				low = low:Min(point)
				high = high:Max(point)
			end end end
		end
	end
	if low.X == math.huge then return nil end
	return low, high
end

local function anchorPart(name)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Transparency = 1
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function weldModel(model, anchor)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("LuaSourceContainer") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			local coatingWeld = child:GetAttribute("PCStudLayer") == true and child:FindFirstChild("StudFinishWeld")
			if not coatingWeld or not coatingWeld:IsA("WeldConstraint") or not coatingWeld.Part0 or not coatingWeld.Part1 then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticGripWeld"
				weld.Part0 = anchor
				weld.Part1 = child
				weld.Parent = child
			end
		elseif child:IsA("Highlight") then child.Adornee = model end
	end
end

function Equipment.new()
	return setmetatable({ running = false, records = {}, connections = {} }, Equipment)
end

function Equipment:_clearBat(record)
	local model = record.bat
	record.bat = nil
	record.batId = nil
	if model then model:Destroy() end
end

function Equipment:_clearGear(record)
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local gripAttachment = hand:FindFirstChild("RightGripAttachment")
	local handOffset = gripAttachment and gripAttachment:IsA("Attachment") and gripAttachment.Position or Vector3.new(0, -hand.Size.Y * 0.45, 0)
	local target = hand.CFrame * CFrame.new(handOffset) * CFrame.Angles(math.rad(-65), 0, math.rad(-8))
	local carrier = Instance.new("Model")
	carrier.Name = "PCCosmeticBat"
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("GripAnchor")
	anchor.CFrame = target
	anchor.Parent = carrier
	carrier.PrimaryPart = anchor
	visual.Name = "Visual"
	visual:PivotTo(target * CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	self:_attachBatEffects(carrier, anchor, item, size, math.min(size.Y * 0.14, 0.42))
	local handWeld = Instance.new("WeldConstraint")
	handWeld.Name = "RightHandGrip"
	handWeld.Part0 = hand
	handWeld.Part1 = anchor
	handWeld.Parent = anchor
	record.bat = carrier
	record.batId = item.id
	carrier.Parent = record.character
end

function Equipment:_makeGear(record, item, backpack, original)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local center = (low + high) * 0.5
	local size = high - low
	local grip = Vector3.new(center.X, low.Y + math.min(size.Y * 0.25, 0.45), center.Z + size.Z * 0.2)
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.name .. " · collectible toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = false
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("CosmeticOnly", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if participating(record.player) then self:_clearGear(record) self:_queue(record) end
	end))
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
end

function Equipment:_refresh(record)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = typeof(batId) == "string" and Catalog.ById[batId]
	local bulldog = player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog"
	local preview = player:GetAttribute("PCAdminBatPreview") == true and not participating(player)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if (not bulldog and not preview) or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		self:_clearBat(record)
	elseif record.batId ~= bat.id or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset)
	end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if participating(player) or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	record.humanoid = nil
	local function bindHumanoid(child)
		if child:IsA("Humanoid") and record.humanoid ~= child then
			record.humanoid = child
			table.insert(record.characterConnections, child.Died:Connect(function()
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() else bindHumanoid(child) end
	end
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		bindHumanoid(child)
		if child:IsA("BasePart") or child:IsA("Humanoid") then self:_queue(record) end
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.bat or child:IsA("BasePart") then self:_queue(record) end
	end))
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, closed = false }
	self.records[player] = record
	table.insert(record.connections, player:GetAttributeChangedSignal("BBBatHitSerial"):Connect(function() self:_batHitEffect(record) end))
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "PCAdminBatPreview", "BBRole", "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function() self:_queue(record) end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_queue(record) end
	end))
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then for _, child in ipairs(backpack:GetChildren()) do if child:GetAttribute("PCCosmeticEquipment") == true then child:Destroy() end end end
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	disconnect(record.connections)
	disconnect(record.characterConnections)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	for _, player in ipairs(Players:GetPlayers()) do self:_addPlayer(player) end
	return self
end

function Equipment:Stop()
	self.running = false
	disconnect(self.connections)
	local players = {}
	for player in pairs(self.records) do table.insert(players, player) end
	for _, player in ipairs(players) do self:_removePlayer(player) end
end

return Equipment
