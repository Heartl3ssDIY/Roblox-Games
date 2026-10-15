local report = { checks = {}, playStarted = false, mockedSignals = true }
local function check(name, value)
	assert(value, name)
	table.insert(report.checks, name)
end
local function signal()
	local entries = {}
	return {
		Connect = function(_, fn)
			local entry = { Connected = true, fn = fn }
			function entry:Disconnect() self.Connected = false end
			table.insert(entries, entry)
			return entry
		end,
		Fire = function(_, ...)
			for _, entry in ipairs(table.clone(entries)) do
				if entry.Connected then entry.fn(...) end
			end
		end,
	}
end
local function node(className)
	local value = { attrs = {}, ClassName = className, children = {}, ChildAdded = signal(), ChildRemoved = signal() }
	function value:SetAttribute(key, v) self.attrs[key] = v end
	function value:GetAttribute(key) return self.attrs[key] end
	function value:IsA(kind) return kind == self.ClassName or (kind == "BasePart" and self.ClassName == "Part") end
	function value:FindFirstChild(name) return self.children[name] end
	function value:FindFirstChildOfClass(kind)
		for _, child in pairs(self.children) do if child.ClassName == kind then return child end end
	end
	function value:Destroy()
		self.destroyed = true
		if self.Destroying then self.Destroying:Fire() end
		self.Parent = nil
	end
	return value
end
local Instance = {}
function Instance.new(kind)
	local value = node(kind)
	if kind == "Tool" then
		value.Equipped = signal()
		value.Unequipped = signal()
		value.Activated = signal()
		value.Destroying = signal()
		value.Enabled = true
	end
	return value
end
local function model()
	local value = node("Model")
	function value:Clone() return model() end
	function value:GetPivot() return CFrame.identity end
	function value:PivotTo() end
	return value
end
local function visibleBounds() return Vector3.new(-1, 0, -1), Vector3.new(1, 3.5, 1) end
local function anchorPart() return node("Part") end
local function weldModel() end
local function disconnect(connections)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
local function participating(player)
	return player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating") or player:GetAttribute("MDParticipating")
end
local Catalog = { ById = { B01 = { id = "B01", name = "Basic Bat", slot = "Bat", available = true } } }
local ReplicatedStorage = node("Folder")
local assets = node("Folder")
assets.children.B01 = model()
ReplicatedStorage.children.PlaygroundCosmeticAssets = assets
local tagState = node("Folder")
tagState:SetAttribute("Phase", "Playing")
ReplicatedStorage.children.TagState = tagState
local workspace = { GetServerTimeNow = function() return 100 end }
local Equipment = {}
Equipment.__index = Equipment

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


function Equipment:_clearGear(record)
	disconnect(record.gearConnections)
	local tool = record.gear
	record.gear = nil
	record.gearId = nil
	if tool then tool:Destroy() end
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
	local gameId = self:_weaponGame(player)
	local ragdolled = player:GetAttribute("BBRagdolled") == true or player:GetAttribute("TGRagdolled") == true
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
	character:SetAttribute("PCBatHeld", false)
	character:SetAttribute("PCBatGame", nil)
	record.humanoid = nil
	local function bindHumanoid()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and record.humanoid ~= humanoid then
			record.humanoid = humanoid
			table.insert(record.characterConnections, humanoid.Died:Connect(function()
				self:_clearBat(record)
				self:_clearGear(record)
			end))
		end
	end
	bindHumanoid()
	table.insert(record.characterConnections, character.ChildAdded:Connect(function()
		bindHumanoid()
		self:_queue(record)
	end))
	table.insert(record.characterConnections, character.ChildRemoved:Connect(function()
		self:_queue(record)
	end))
	self:_queue(record)
end


local queued, cancelled = 0, 0
local service = setmetatable({}, Equipment)
function service:_attachBatEffects() end
function service:_queue() queued += 1 end
function service:_cancelBatHit() cancelled += 1 end
function service:_activateBat() end
function service:_weaponGame(player)
	if player:GetAttribute("BBParticipating") and player:GetAttribute("BBRole") == "Bulldog" then return "BritishBulldog" end
	if player:GetAttribute("TGParticipating") and player:GetAttribute("TGRole") == "Tagger" then return "TagYoureIt" end
	return nil
end
local function character()
	local value = node("Model")
	value.children.RightHand = node("Part")
	local humanoid = node("Humanoid")
	humanoid.Health = 100
	humanoid.Died = signal()
	function humanoid:EquipTool(tool)
		tool.Parent = value
		tool.Equipped:Fire()
	end
	value.children.Humanoid = humanoid
	return value
end
local rig = character()
local backpack = node("Backpack")
local player = node("Player")
player.children.Backpack = backpack
player.Character = rig
player:SetAttribute("PCDataReady", true)
player:SetAttribute("PCBat", "B01")
player:SetAttribute("BBParticipating", true)
player:SetAttribute("BBRole", "Bulldog")
local record = { player = player, character = rig, characterConnections = {}, gearConnections = {}, batConnections = {} }
service:_bindCharacter(record, rig)
check("Bind begins with false/nil mirrors", rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
service:_refresh(record)
local tool = assert(record.bat)
check("Equipped event mirrors true and current game", rig:GetAttribute("PCBatHeld") == true and rig:GetAttribute("PCBatGame") == "BritishBulldog")
local priorQueued, priorCancelled = queued, cancelled
tool.Parent = backpack
tool.Unequipped:Fire()
check("Unequipped event clears held/game mirrors", rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
check("Unequipped still cancels hit and queues refresh", queued > priorQueued and cancelled > priorCancelled)
rig.children.Humanoid:EquipTool(tool)
check("Re-equipped event restores mirrors", rig:GetAttribute("PCBatHeld") == true and rig:GetAttribute("PCBatGame") == "BritishBulldog")
rig:SetAttribute("PCBatHeld", false)
rig:SetAttribute("PCBatGame", nil)
service:_refresh(record)
check("Valid existing tool refresh repairs mirrors without replacement", record.bat == tool and rig:GetAttribute("PCBatHeld") == true and rig:GetAttribute("PCBatGame") == "BritishBulldog")
service:_clearBat(record)
check("Clear destroys tool and clears record and character state", tool.destroyed and record.bat == nil and record.batGame == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
tool.Equipped:Fire()
check("Disconnected stale Tool events cannot restore held state", rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
service:_refresh(record)
tool = record.bat
tool:Destroy()
check("External destruction clears both mirrors", rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
service:_clearBat(record)
service:_refresh(record)
tool = record.bat
rig.children.Humanoid.Died:Fire()
check("Humanoid death destroys held bat and clears mirrors", tool.destroyed and record.bat == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
service:_refresh(record)
local replacement = character()
service:_bindCharacter(record, replacement)
check("Respawn clears old character mirrors", rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
check("Respawn initializes new character mirrors", replacement:GetAttribute("PCBatHeld") == false and replacement:GetAttribute("PCBatGame") == nil and record.humanoid == replacement.children.Humanoid)
player.Character = replacement
rig = replacement
player:SetAttribute("BBParticipating", false)
player:SetAttribute("TGParticipating", true)
player:SetAttribute("TGRole", "Tagger")
service:_refresh(record)
tool = record.bat
check("Tag tool mirrors correct game", tool and rig:GetAttribute("PCBatGame") == "TagYoureIt" and rig:GetAttribute("PCBatHeld") == true)
tool:SetAttribute("BatSwingAt", 99.8)
player:SetAttribute("TGRole", "Runner")
priorCancelled = cancelled
service:_refresh(record)
check("Tag finishing swing retains original tool", record.bat == tool and not tool.destroyed)
check("Tag finishing swing preserves held/game mirrors", rig:GetAttribute("PCBatHeld") == true and rig:GetAttribute("PCBatGame") == "TagYoureIt")
check("Tag finishing swing disables another hit and cancels contact", tool.Enabled == false and cancelled > priorCancelled)
tool:SetAttribute("BatSwingAt", 99.51)
service:_refresh(record)
check("Expired finishing swing clears tool and mirrors", tool.destroyed and record.bat == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
player:SetAttribute("TGRole", "Tagger")
service:_refresh(record)
tool = record.bat
tool:SetAttribute("BatSwingAt", 99.8)
player:SetAttribute("TGRole", "Runner")
player:SetAttribute("TGRagdolled", true)
service:_refresh(record)
check("Ragdoll prevents finishing-swing retention", tool.destroyed and record.bat == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
player:SetAttribute("TGRagdolled", false)
player:SetAttribute("TGRole", "Tagger")
service:_refresh(record)
tool = record.bat
rig.children.Humanoid.Health = 0
service:_refresh(record)
check("Refresh on a dead humanoid clears mirrors", tool.destroyed and record.bat == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
rig.children.Humanoid.Health = 100
service:_refresh(record)
tool = record.bat
player:SetAttribute("PCDataReady", false)
service:_refresh(record)
check("Unavailable profile clears held mirrors", tool.destroyed and record.bat == nil and rig:GetAttribute("PCBatHeld") == false and rig:GetAttribute("PCBatGame") == nil)
report.passed = true
return report

