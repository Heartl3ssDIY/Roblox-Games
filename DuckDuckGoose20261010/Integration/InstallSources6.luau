assert(not game:GetService("RunService"):IsRunning(), "Stop Play before integrating Duck Duck Goose.")
assert(game.PlaceId == 95034648955135, "Wrong experience.")
local entries = { {path="ServerScriptService.PlaygroundEquipmentService",expected=1467775725,after=2136719028,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
	B16 = { name = "Fossil Dust", color = Color3.fromRGB(218, 190, 134), accent = Color3.fromRGB(255, 240, 196), texture = smokeTexture, rate = 4, speed = 0.4, size = 0.14, gravity = -0.7, spin = 35, glow = 0, trail = 0.18, lines = "alloy" },
	B17 = { name = "Dragon Scales", color = Color3.fromRGB(65, 199, 116), accent = Color3.fromRGB(251, 213, 105), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.18, gravity = 0.3, spin = 45, glow = 0.3, trail = 0.18, lines = "wave" },
	B18 = { name = "Breakfast Crumbs", color = Color3.fromRGB(229, 165, 75), accent = Color3.fromRGB(255, 233, 158), texture = smokeTexture, rate = 4, speed = 0.6, size = 0.11, gravity = -1.2, spin = 95, glow = 0, trail = 0.18 },
	B19 = { name = "Cloud Wisps", color = Color3.fromRGB(197, 209, 253), accent = Color3.fromRGB(255, 249, 233), texture = smokeTexture, rate = 3, speed = 0.4, size = 0.25, gravity = 0.65, spin = 20, glow = 0.1, trail = 0.18, lines = "orbit" },
	B20 = { name = "Bamboo Leaves", color = Color3.fromRGB(130, 203, 103), accent = Color3.fromRGB(230, 236, 148), texture = sparkTexture, rate = 5, speed = 0.45, size = 0.14, gravity = -0.25, spin = 110, glow = 0.1, trail = 0.18, lines = "wave" },
	B21 = { name = "Combo Pixels", color = Color3.fromRGB(96, 202, 245), accent = Color3.fromRGB(254, 115, 174), texture = sparkTexture, rate = 6, speed = 0.55, size = 0.16, gravity = 0.2, spin = 0, glow = 0.45, trail = 0.18, lines = "pixels" },
	B22 = { name = "Honey Sparks", color = Color3.fromRGB(249, 191, 63), accent = Color3.fromRGB(255, 232, 142), texture = sparkTexture, rate = 4, speed = 0.4, size = 0.15, gravity = -0.15, spin = 35, glow = 0.35, trail = 0.18, lines = "hazard" },
	B23 = { name = "Clockwork Glints", color = Color3.fromRGB(202, 159, 90), accent = Color3.fromRGB(255, 230, 176), texture = sparkTexture, rate = 3, speed = 0.2, size = 0.19, gravity = 0.05, spin = 65, glow = 0.3, trail = 0.18, lines = "orbit" },
	B24 = { name = "Patchwork Confetti", color = Color3.fromRGB(225, 133, 212), accent = Color3.fromRGB(108, 223, 226), texture = sparkTexture, rate = 6, speed = 0.7, size = 0.15, gravity = -0.5, spin = 180, glow = 0.2, trail = 0.18, lines = "pixels" },
	B25 = { name = "Prism Gleam", color = Color3.fromRGB(121, 199, 255), accent = Color3.fromRGB(252, 178, 250), texture = sparkTexture, rate = 5, speed = 0.5, size = 0.19, gravity = 0.35, spin = 50, glow = 0.6, trail = 0.18, lines = "sun" },
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
		or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true
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

function Equipment.new(batServices, toys)
	return setmetatable({ running = false, records = {}, connections = {}, batServices = batServices or {}, toys = toys }, Equipment)
end

function Equipment:_weaponGame(player)
	if player:GetAttribute("MDParticipating") == true then return nil end
	if player:GetAttribute("BBParticipating") == true and player:GetAttribute("BBRole") == "Bulldog" then
		local state = ReplicatedStorage:FindFirstChild("BritishBulldogState")
		if state and state:GetAttribute("Phase") == "Crossing" then return "BritishBulldog" end
	elseif player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Tagger" then
		local state = ReplicatedStorage:FindFirstChild("TagState")
		if state and state:GetAttribute("Phase") == "Playing" then return "TagYoureIt" end
	elseif player:GetAttribute("HSParticipating") == true and player:GetAttribute("HSRole") == "Seeker" then
		local state = ReplicatedStorage:FindFirstChild("HideAndSeekState")
		if state and state:GetAttribute("Phase") == "Seeking" then return "HideAndSeek" end
	elseif player:GetAttribute("DGParticipating") == true and player:GetAttribute("DGRole") == "Goose" then
		local state = ReplicatedStorage:FindFirstChild("DuckDuckGooseState")
		if state and state:GetAttribute("Phase") == "Playing" and state:GetAttribute("TurnPhase") == "Chasing" then return "DuckDuckGoose" end
	end
	return nil
end

function Equipment:_batService(gameId)
	return self.batServices[gameId]
end

function Equipment:_cancelBatHit(record)
	if not record.batGame then return end
	local service = self:_batService(record.batGame)
	if service and service.CancelBatSwing then service:CancelBatSwing(record.player) end
end

function Equipment:_activateBat(record)
	local tool = record.bat
	local gameId = self:_weaponGame(record.player)
	if not tool or not tool.Enabled or tool.Parent ~= record.character or record.player.Character ~= record.character
		or not gameId or record.batGame ~= gameId or record.player:GetAttribute("PCDataReady") ~= true
		or record.player:GetAttribute("BBRagdolled") == true or record.player:GetAttribute("TGRagdolled") == true or record.player:GetAttribute("HSRagdolled") == true or record.player:GetAttribute("DGRagdolled") == true then return false end
	local service = self:_batService(gameId)
	if not service or not service.TryBatSwing then return false end
	local accepted = service:TryBatSwing(record.player)
	if accepted then
		tool:SetAttribute("BatSwingAt", workspace:GetServerTimeNow())
		task.delay(0.5, function() if not record.closed then self:_queue(record) end end)
	end
	return accepted == true
end

function Equipment:_clearBat(record)
	if record.character then
		record.character:SetAttribute("PCBatHeld", false)
		record.character:SetAttribute("PCBatGame", nil)
	end
	self:_cancelBatHit(record)
	if record.batConnections then disconnect(record.batConnections) end
	local model = record.bat
	record.bat = nil
	record.batId = nil
	record.batGame = nil
	if model then model:Destroy() end
end

function Equipment:_reconcileToys(record, keep)
	local containers = { record.character, record.player.Character, record.player:FindFirstChildOfClass("Backpack"), record.player:FindFirstChild("StarterGear") }
	local seen = {}
	for _, container in pairs(containers) do
		if container and not seen[container] then
			seen[container] = true
			for _, child in ipairs(container:GetChildren()) do
				local item = Catalog.ById[child:GetAttribute("CatalogId")]
				local toy = child:IsA("Tool") and (child:GetAttribute("PCToy") == true
					or child:GetAttribute("PCCosmeticEquipment") == true and item and item.slot == "Gear")
				if toy and child ~= keep then child:Destroy() end
			end
		end
	end
end

function Equipment:_toyAllowed(record)
	return not record.roundPreparing and not participating(record.player) and self.toys and self.toys:CanHold(record.player) == true
end

function Equipment:_clearGear(record)
	if self.toys then self.toys:CancelAction(record.player) end
	if record.character then record.character:SetAttribute("PCToyHeld", nil) end
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
	self:_reconcileToys(record, nil)
end

function Equipment:_queue(record)
	if not self.running or record.closed or record.queued then return end
	record.queued = true
	task.defer(function()
		record.queued = false
		if self.running and not record.closed then self:_refresh(record) end
	end)
end

function Equipment:_makeBat(record, item, hand, original, gameId)
	local visual = original:Clone()
	local low, high = visibleBounds(visual)
	if not low then visual:Destroy() return end
	local size = high - low
	local grip = Vector3.new((low.X + high.X) * 0.5, low.Y + math.min(size.Y * 0.14, 0.42), (low.Z + high.Z) * 0.5)
	local carrier = Instance.new("Tool")
	carrier.Name = item.name
	carrier.ToolTip = "Click / tap to swing"
	carrier.RequiresHandle = true
	carrier.CanBeDropped = false
	carrier.ManualActivationOnly = false
	carrier.Grip = CFrame.identity
	carrier:SetAttribute("PCCosmeticEquipment", true)
	carrier:SetAttribute("PCBatWeapon", true)
	carrier:SetAttribute("WeaponGame", gameId)
	carrier:SetAttribute("BatSwingAt", 0)
	carrier:SetAttribute("CatalogId", item.id)
	local anchor = anchorPart("Handle")
	anchor.Parent = carrier
	local palm = Instance.new("Attachment")
	palm.Name = "RightGripAttachment"
	palm.CFrame = carrier.Grip
	palm.Parent = anchor
	visual.Name = "Visual"
	visual:PivotTo(CFrame.new(-grip) * visual:GetPivot())
	visual.Parent = carrier
	weldModel(visual, anchor)
	self:_attachBatEffects(carrier, anchor, item, size, math.min(size.Y * 0.14, 0.42))
	record.bat = carrier
	record.batId = item.id
	record.batGame = gameId
	record.batConnections = record.batConnections or {}
	local function mirrorHeld(held)
		if record.bat ~= carrier or not record.character then return end
		record.character:SetAttribute("PCBatHeld", held)
		record.character:SetAttribute("PCBatGame", held and gameId or nil)
	end
	table.insert(record.batConnections, carrier.Equipped:Connect(function() mirrorHeld(true) end))
	table.insert(record.batConnections, carrier.Activated:Connect(function() self:_activateBat(record) end))
	table.insert(record.batConnections, carrier.Unequipped:Connect(function()
		mirrorHeld(false)
		self:_cancelBatHit(record)
		self:_queue(record)
	end))
	table.insert(record.batConnections, carrier.Destroying:Connect(function() mirrorHeld(false) self:_cancelBatHit(record) end))
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	carrier.Parent = record.player:FindFirstChildOfClass("Backpack") or record.character
	if humanoid then humanoid:EquipTool(carrier) end
	mirrorHeld(carrier.Parent == record.character)
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
	tool.ToolTip = item.name .. " · lobby toy"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Enabled = true
	tool.ManualActivationOnly = true
	tool.Grip = CFrame.new(0, -0.15, 0)
	tool:SetAttribute("PCCosmeticEquipment", true)
	tool:SetAttribute("CatalogId", item.id)
	tool:SetAttribute("PCToy", true)
	local handle = anchorPart("Handle")
	handle.Parent = tool
	visual.Name = "Visual"
	visual.Parent = tool
	weldModel(visual, handle)
	record.gear = tool
	record.gearId = item.id
	local function mirrorHeld(held)
		if record.gear ~= tool or not record.character then return end
		record.character:SetAttribute("PCToyHeld", held and item.id or nil)
		if self.toys then
			if held then self.toys:Hold(record.player) else self.toys:CancelAction(record.player) end
		end
	end
	table.insert(record.gearConnections, tool.Equipped:Connect(function()
		if not self:_toyAllowed(record) then self:_clearGear(record) self:_queue(record) else mirrorHeld(true) end
	end))
	table.insert(record.gearConnections, tool.Unequipped:Connect(function() mirrorHeld(false) end))
	if item.id == "M14" then
		local flame = anchorPart("TorchFlame")
		flame.CFrame = CFrame.new(0, size.Y - math.min(size.Y * 0.25, 0.45), -size.Z * 0.2)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, flame, flame
		local fire = Instance.new("Fire")
		fire.Name, fire.Size, fire.Heat, fire.Parent = "CampFlame", 2.4, 3, flame
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 170, 70), 0.6, 9, flame
	end
	table.insert(record.gearConnections, tool.AncestryChanged:Connect(function() self:_queue(record) end))
	tool.Parent = backpack
	local humanoid = record.character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	mirrorHeld(tool.Parent == record.character)
end

function Equipment:_refresh(record)
	if participating(record.player) then
		record.roundPreparing = false
		record.player:SetAttribute("PCToyRoundPreparing", false)
	end
	self:_reconcileToys(record, record.gear)
	local player = record.player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local ready = player:GetAttribute("PCDataReady") == true
	if character ~= record.character or not ready or not humanoid or humanoid.Health <= 0 then
		if self.toys then self.toys:ClearPlayer(player) end
		self:_clearBat(record)
		self:_clearGear(record)
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	local batId = player:GetAttribute("PCBat")
	local bat = (typeof(batId) == "string" and Catalog.ById[batId]) or Catalog.ById.B01
	local gameId = self:_weaponGame(player)
	local ragdolled = player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true or player:GetAttribute("HSRagdolled") == true or player:GetAttribute("DGRagdolled") == true
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local batAsset = bat and assets and assets:FindFirstChild(bat.id)
	if not gameId or ragdolled or not bat or bat.slot ~= "Bat" or bat.available == false or not hand or not hand:IsA("BasePart") or not batAsset or not batAsset:IsA("Model") then
		local at = record.bat and record.bat:GetAttribute("BatSwingAt")
		local tagState = ReplicatedStorage:FindFirstChild("TagState")
		local finishing = record.batGame == "TagYoureIt" and player:GetAttribute("TGParticipating") == true and player:GetAttribute("TGRole") == "Runner"
			and not ragdolled and tagState and tagState:GetAttribute("Phase") == "Playing" and typeof(at) == "number" and workspace:GetServerTimeNow() - at < 0.48
		if finishing then record.bat.Enabled = false self:_cancelBatHit(record) else self:_clearBat(record) end
	elseif record.batId ~= bat.id or record.batGame ~= gameId or not record.bat or record.bat.Parent ~= character then
		self:_clearBat(record)
		self:_makeBat(record, bat, hand, batAsset, gameId)
	else
		record.bat.Enabled = true
		character:SetAttribute("PCBatHeld", true)
		character:SetAttribute("PCBatGame", gameId)
	end
	local toyAllowed = self:_toyAllowed(record)
	if not toyAllowed and self.toys then self.toys:ClearPlayer(player) end
	local gearId = player:GetAttribute("PCGear")
	local gear = typeof(gearId) == "string" and Catalog.ById[gearId]
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gearAsset = gear and assets and assets:FindFirstChild(gear.id)
	if not toyAllowed or not gear or gear.slot ~= "Gear" or gear.available == false or not backpack or not gearAsset or not gearAsset:IsA("Model") then
		self:_clearGear(record)
	elseif record.gearId ~= gear.id or not record.gear or (record.gear.Parent ~= backpack and record.gear.Parent ~= character) then
		self:_clearGear(record)
		self:_makeGear(record, gear, backpack, gearAsset)
	elseif record.gear.Parent ~= character then
		humanoid:EquipTool(record.gear)
		character:SetAttribute("PCToyHeld", gear.id)
		if self.toys then self.toys:Hold(player) end
	end
end

function Equipment:_bindCharacter(record, character)
	disconnect(record.characterConnections)
	if self.toys then self.toys:ClearPlayer(record.player) end
	self:_clearBat(record)
	self:_clearGear(record)
	record.character = character
	character:SetAttribute("PCBatHeld", false)
	character:SetAttribute("PCBatGame", nil)
	record.humanoid = nil
	local function bindHumanoid()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and record.humanoid ~= humanoid then
			record.humanoid = humanoid
			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				if self.toys then self.toys:ClearPlayer(record.player) end
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	bindHumanoid()
	table.insert(record.characterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("PCToy") == true and not self:_toyAllowed(record) then self:_clearGear(record) end
		bindHumanoid()
		self:_queue(record)
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function()
		self:_queue(record)
	end))
	self:_queue(record)
end

function Equipment:_bindBackpack(record, backpack)
	disconnect(record.backpackConnections)
	record.backpack = backpack
	if not backpack then return end
	table.insert(record.backpackConnections, backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("PCToy") == true and not self:_toyAllowed(record) then self:_clearGear(record) end
		self:_queue(record)
	end))
	table.insert(record.backpackConnections, backpack.ChildRemoved:Connect(function() self:_queue(record) end))
	self:_reconcileToys(record, record.gear)
	self:_queue(record)
end

function Equipment:_addPlayer(player)
	if self.records[player] then return end
	local record = { player = player, connections = {}, characterConnections = {}, gearConnections = {}, batConnections = {}, backpackConnections = {}, closed = false }
	self.records[player] = record
	table.insert(record.connections, player:GetAttributeChangedSignal("PCBatHitSerial"):Connect(function() self:_batHitEffect(record) end))
	for _, attribute in ipairs({ "PCBat", "PCGear", "PCDataReady", "BBRole", "BBParticipating", "TGRole", "TGParticipating", "MDParticipating", "BBRagdolled", "TGRagdolled", "HSParticipating", "DGParticipating", "DGEliminated", "HSRole", "HSRagdolled", "DGRole", "DGRagdolled" }) do
		table.insert(record.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if participating(player) then
				record.roundPreparing = false
				player:SetAttribute("PCToyRoundPreparing", false)
				if self.toys then self.toys:ClearPlayer(player) end
				self:_clearGear(record)
			end
			self:_queue(record)
		end))
	end
	table.insert(record.connections, player.CharacterAdded:Connect(function(character) self:_bindCharacter(record, character) end))
	table.insert(record.connections, player.CharacterRemoving:Connect(function(character)
		if character == record.character then
			if self.toys then self.toys:ClearPlayer(record.player) end
			disconnect(record.characterConnections)
			self:_clearBat(record)
			self:_clearGear(record)
			record.character = nil
		end
	end))
	table.insert(record.connections, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then self:_bindBackpack(record, child) end
	end))
	self:_bindBackpack(record, player:FindFirstChildOfClass("Backpack"))
	if player.Character then self:_bindCharacter(record, player.Character) end
end

function Equipment:_removePlayer(player)
	local record = self.records[player]
	if not record then return end
	record.closed = true
	if self.toys then self.toys:ClearPlayer(player) end
	disconnect(record.connections)
	disconnect(record.characterConnections)
	disconnect(record.backpackConnections)
	player:SetAttribute("PCToyRoundPreparing", false)
	self:_clearBat(record)
	self:_clearGear(record)
	self.records[player] = nil
end

function Equipment:UseToy(player, aim)
	local record = self.records[player]
	if not self.running or not record or record.closed or not self.toys then return { ok = false, message = "Toys are loading." } end
	if not self:_toyAllowed(record) then
		self.toys:ClearPlayer(player)
		self:_clearGear(record)
		return { ok = false, message = "Toys are for the lobby." }
	end
	return self.toys:Use(player, record.gear, aim)
end

function Equipment:PrepareRound(selected)
	local players = typeof(selected) == "Instance" and { selected } or selected or Players:GetPlayers()
	for _, player in ipairs(players) do
		if player.Parent == Players then
			local record = self.records[player]
			if record then
				record.roundPreparing = true
				record.prepareSerial = (record.prepareSerial or 0) + 1
				local serial = record.prepareSerial
				player:SetAttribute("PCToyRoundPreparing", true)
				self:_clearGear(record)
				task.delay(3, function()
					if self.running and not record.closed and record.prepareSerial == serial and not participating(player) then
						record.roundPreparing = false
						player:SetAttribute("PCToyRoundPreparing", false)
						self:_queue(record)
					end
				end)
			end
			if self.toys then self.toys:ClearPlayer(player) end
		end
	end
end

function Equipment:Start()
	if self.running then return self end
	self.running = true
	for _, name in ipairs({ "BritishBulldogState", "TagState", "HideAndSeekState", "DuckDuckGooseState" }) do
		local state = ReplicatedStorage:FindFirstChild(name)
		if state then
			for _, attribute in { "Phase", "TurnPhase" } do
				table.insert(self.connections, state:GetAttributeChangedSignal(attribute):Connect(function()
					for _, record in pairs(self.records) do self:_queue(record) end
				end))
			end
		end
	end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_addPlayer(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_removePlayer(player) end))
	local assets = ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")
	if assets then
		table.insert(self.connections, assets.ChildAdded:Connect(function()
			for _, record in pairs(self.records) do self:_queue(record) end
		end))
	end
	local elapsed = 0
	table.insert(self.connections, game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		for _, record in pairs(self.records) do
			local allowed = self:_toyAllowed(record) == true
			if record.toyAllowed ~= allowed then
				record.toyAllowed = allowed
				if not allowed then
					if self.toys then self.toys:ClearPlayer(record.player) end
					self:_clearGear(record)
				end
				self:_queue(record)
			end
		end
	end))
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






]==]},
 {path="ServerScriptService.PlaygroundToyService",expected=1666751846,after=1745467822,caps="RunServerScript | AccessOutsideWrite | CreateInstances | Basic | Physics | UI | Input | Players | AvatarBehavior",sandboxed=true,source=[==[local Players = game:GetService("Players")
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
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
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



]==]}}
local function fingerprint(source)
 source = string.gsub(source,"\r\n","\n")
 local value=0
 for index=1,#source do value=(value*31+string.byte(source,index))%2147483647 end
 return value
end
local objects={}
for _,entry in entries do
 local object=game
 for name in string.gmatch(entry.path,"[^.]+") do object=object:FindFirstChild(name) assert(object,"Missing "..entry.path) end
 local hash=fingerprint(object.Source)
 assert(hash==entry.expected or hash==entry.after,"Source changed: "..entry.path)
 assert(tostring(object.Capabilities)==entry.caps and object.Sandboxed==entry.sandboxed,"Permissions changed: "..entry.path)
 objects[entry.path]=object
end
local storage=game:GetService("ServerStorage")
local backup=storage:FindFirstChild("DuckDuckGooseIntegrationBackup20261010")
if not backup then backup=Instance.new("Folder") backup.Name,backup.Parent="DuckDuckGooseIntegrationBackup20261010",storage end
local changed=0
for _,entry in entries do
 local object=objects[entry.path]
 if fingerprint(object.Source)~=entry.after then
  local snapshot=object:Clone()
  snapshot.Name=entry.path
  if snapshot:IsA("BaseScript") then snapshot.Enabled=false end
  snapshot.Parent=backup
  object.Source=entry.source
  object:SetAttribute("DuckDuckGooseIntegrated20261010",true)
  changed+=1
 end
end
return {patched=changed,capabilitiesPreserved=true,backup=backup:GetFullName()}
