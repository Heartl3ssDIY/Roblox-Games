assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local storage = game:GetService("ServerStorage")
local replicated = game:GetService("ReplicatedStorage")
local fixture = Instance.new("Folder")
fixture.Name = "_BatEffectsChecks"
fixture.Parent = storage
local report = { playStarted = false, effects = {}, checks = {}, assetErrors = {} }
local success, problem = xpcall(function()
	local source = game.ServerScriptService.PlaygroundEquipmentService:Clone()
	source.Parent = fixture
	local Equipment = require(source)
	local Catalog = require(replicated.PlaygroundCatalog)
	local service = Equipment.new()
	local character = Instance.new("Model")
	character.Parent = fixture
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local attributes = { PCDataReady = true, PCBat = "B01", PCAdminBatPreview = true }
	local player = { Character = character }
	function player:GetAttribute(name) return attributes[name] end
	function player:FindFirstChildOfClass() return nil end
	local record = { player = player, character = character, gearConnections = {}, characterConnections = {}, connections = {} }
	local names, textures = {}, {}
	for index = 1, 15 do
		local id = string.format("B%02d", index)
		attributes.PCBat = id
		local previous = record.bat
		service:_refresh(record)
		assert(record.bat and record.batId == id, "Missing lobby preview " .. id)
		if previous then assert(previous.Parent == nil, "Old effect leaked") end
		local name = record.bat:GetAttribute("HeldEffect")
		assert(name and not names[name], "Effect name must be distinct")
		names[name] = true
		local emitters, beams, trails, rate = 0, 0, 0, 0
		for _, instance in ipairs(record.bat:GetDescendants()) do
			if instance:IsA("ParticleEmitter") then
				emitters += 1
				rate += instance.Rate
				assert(instance.Enabled and instance.Lifetime.Max <= 1, "Effect budget exceeded")
				textures[instance.Texture] = true
			elseif instance:IsA("Beam") then
				beams += 1
				assert(instance.Attachment0 and instance.Attachment1 and instance.Enabled)
			elseif instance:IsA("Trail") then
				trails += 1
				assert(instance.Attachment0 and instance.Attachment1 and instance.Lifetime <= 0.301)
			end
		end
		assert(emitters > 0 and trails > 0 and rate <= 10, "Incomplete or excessive VFX " .. id)
		service:_batHitEffect(record)
		table.insert(report.effects, { id = id, name = name, particlesPerSecond = rate, emitters = emitters, beams = beams, trails = trails })
	end
	table.insert(report.checks, "All15 distinct held effects build and burst within budget")
	attributes.TGParticipating = true
	service:_refresh(record)
	assert(record.bat == nil, "Admin preview leaked into Tag")
	attributes.TGParticipating = nil
	attributes.BBParticipating = true
	attributes.BBRole = "Runner"
	service:_refresh(record)
	assert(record.bat == nil, "Admin preview leaked onto runner")
	attributes.BBRole = "Bulldog"
	service:_refresh(record)
	assert(record.bat, "Bulldog missing bat")
	table.insert(report.checks, "Admin preview never overrides active game roles")
	attributes.BBParticipating = nil
	attributes.BBRole = nil
	attributes.PCAdminBatPreview = false
	service:_refresh(record)
	assert(record.bat == nil)
	table.insert(report.checks, "Hiding admin preview removes effect and bat")
	local assets = {}
	for texture in pairs(textures) do table.insert(assets, texture) end
	game:GetService("ContentProvider"):PreloadAsync(assets, function(assetId, status)
		if status ~= Enum.AssetFetchStatus.Success then table.insert(report.assetErrors, { id = assetId, status = status.Name }) end
	end)
	assert(#report.assetErrors == 0, "A VFX texture failed to load")
	table.insert(report.checks, "Every VFX texture preloads successfully")
	service:_clearBat(record)
	assert(not service.running, "Service must not start during checks")
end, debug.traceback)
fixture:Destroy()
report.fixtureDestroyed = fixture.Parent == nil
report.passed = success
report.error = not success and problem or nil
return report
