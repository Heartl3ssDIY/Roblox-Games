local actualTypeof = typeof
local function typeof(value)
 return type(value) == "table" and value.isInstance and "Instance" or actualTypeof(value)
end
local activeConnections, createdObjects, jobs, calls = 0, {}, {}, {}
local function signal()
 local listeners = {}
 local result = {}
 function result:Connect(callback)
  local connection = { active = true }
  activeConnections += 1
  function connection:Disconnect()
   if self.active then self.active = false activeConnections -= 1 end
  end
  listeners[connection] = callback
  return connection
 end
 function result:Fire(...)
  local copy = table.clone(listeners)
  for connection, callback in copy do if connection.active then callback(...) end end
 end
 return result
end
local function object(class, name)
 local value = { isInstance = true, ClassName = class, Name = name, children = {}, signals = {}, Destroying = signal(), AncestryChanged = signal(), DescendantAdded = signal(), DescendantRemoving = signal() }
 function value:IsA(wanted) return self.ClassName == wanted end
 function value:FindFirstChild(name) return self.children[name] end
 function value:FindFirstAncestorOfClass() return nil end
 function value:GetChildren()
  local list = {} for _, child in self.children do table.insert(list, child) end return list
 end
 function value:GetDescendants() return self:GetChildren() end
 function value:IsDescendantOf(parent) return self.Parent == parent end
 function value:GetAttribute(name) return self[name .. "Attribute"] end
 function value:GetPropertyChangedSignal(name)
  self.signals[name] = self.signals[name] or signal()
  return self.signals[name]
 end
 function value:Destroy()
  if self.destroyed then return end
  self.Destroying:Fire()
  self.destroyed = true self.Parent = nil
 end
 return value
end
local Instance = {}
function Instance.new(class)
 local result = object(class, class)
 table.insert(createdObjects, result)
 return result
end
local task = {}
function task.spawn(callback) table.insert(jobs, callback) end
function task.delay(_, callback) table.insert(jobs, callback) end
function task.wait() end
local function drain()
 local guard = 0
 while #jobs > 0 do
  guard += 1 assert(guard < 100, "unbounded queued work")
  table.remove(jobs, 1)()
 end
end
local Players = { PlayerRemoving = signal() }
local duringFetch
function Players:GetUserThumbnailAsync(userId)
 calls[userId] = (calls[userId] or 0) + 1
 if duringFetch then local callback = duringFetch duringFetch = nil callback() end
 return "thumb:" .. userId, true
end
local game = {}
function game:GetService(name) assert(name == "Players") return Players end
local Enum = { ThumbnailType = { HeadShot = "head" }, ThumbnailSize = { Size180x180 = "180" } }
local function marker()
 local result = object("Frame", "Marker")
 for name, class in { Portrait = "ViewportFrame", Thumbnail = "ImageLabel" } do
  local child = object(class, name)
  child.Parent = result child.Position = "authored-position" child.Size = "authored-size"
  child.AbsoluteSize = { X = 42, Y = 42 } child.Visible = false child.Image = ""
  result.children[name] = child
 end
 return result
end
local function player(id, character)
 local result = object("Player", "Player")
 result.UserId = id result.Character = character
 result.CharacterAdded = signal() result.CharacterRemoving = signal() result.CharacterAppearanceLoaded = signal()
 return result
end
local function checkLayout(marker)
 for _, child in marker:GetChildren() do
  assert(child.Position == "authored-position" and child.Size == "authored-size", "authored layout changed")
 end
end
local Portraits = (function()
local Players = game:GetService("Players")

local Portraits = {}
local bindings = setmetatable({}, { __mode = "k" })
local thumbnails = {}
local headTypes = {
	Hat = true, Hair = true, Face = true, Eyebrow = true, Eyelash = true,
}
local function appearanceProperties(object)
	if object:IsA("MeshPart") then
		return { "Color", "Material", "Transparency", "Size", "MeshId", "TextureID" }
	elseif object:IsA("BasePart") then
		return { "Color", "Material", "Transparency", "Size" }
	elseif object:IsA("SpecialMesh") then
		return { "MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor" }
	elseif object:IsA("DataModelMesh") then
		return { "Scale", "Offset", "VertexColor" }
	elseif object:IsA("Decal") then
		return { "Texture", "Color3", "Transparency" }
	elseif object:IsA("SurfaceAppearance") then
		return { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap", "AlphaMode" }
	elseif object:IsA("Accessory") then
		return { "AccessoryType", "AttachmentPoint" }
	elseif object:IsA("Attachment") and not object:IsA("Bone") then
		return { "CFrame" }
	end
	return {}
end

local function thumbnailFor(userId, callback)
	local entry = thumbnails[userId]
	if not entry then
		entry = { callbacks = {} }
		thumbnails[userId] = entry
	end
	entry.callbacks[callback] = true
	if entry.image then
		callback(entry.image)
	elseif not entry.loading then
		entry.loading = true
		task.spawn(function()
			for attempt = 1, 3 do
				if thumbnails[userId] ~= entry or not next(entry.callbacks) then break end
				local ok, content, ready = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
				end)
				if thumbnails[userId] ~= entry then break end
				if ok and ready and type(content) == "string" and content ~= "" then
					entry.image = content
					for receive in entry.callbacks do pcall(receive, content) end
					break
				end
				if attempt < 3 then task.wait(attempt) end
			end
			entry.loading = false
		end)
	end
	return function()
		entry.callbacks[callback] = nil
		if entry.removed and not next(entry.callbacks) and thumbnails[userId] == entry then
			thumbnails[userId] = nil
		end
	end
end

local function disconnect(connections)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function clonePart(source)
	local ok, part = pcall(function() return source:Clone() end)
	if not ok or not part then return nil end
	for _, child in part:GetDescendants() do
		if not (child:IsA("DataModelMesh") or child:IsA("Decal")
			or child:IsA("SurfaceAppearance") or child:IsA("Attachment")
			or child:IsA("FaceControls") or child:IsA("WrapTarget")) then
			child:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.LocalTransparencyModifier = 0
	return part
end

local function headOffset(accessory, head)
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end
	for _, attachment in handle:GetChildren() do
		if attachment:IsA("Attachment") then
			local target = head:FindFirstChild(attachment.Name)
			if target and target:IsA("Attachment") then
				return handle, target.CFrame * attachment.CFrame:Inverse()
			end
		end
	end
	for _, joint in handle:GetChildren() do
		if joint:IsA("JointInstance") then
			if joint.Part0 == head and joint.Part1 == handle then
				return handle, joint.C0 * joint.C1:Inverse()
			elseif joint.Part1 == head and joint.Part0 == handle then
				return handle, joint.C1 * joint.C0:Inverse()
			end
		end
	end
	if headTypes[accessory.AccessoryType.Name] then
		return handle, head.CFrame:ToObjectSpace(handle.CFrame)
	end
	return nil
end

local function buildHead(character)
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return nil end
	local model = Instance.new("Model")
	model.Name = "RacePortraitHead"
	local ok = pcall(function()
		local copy = clonePart(head)
		assert(copy, "Head is not cloneable")
		copy.CFrame = CFrame.identity
		copy.Parent = model
		model.PrimaryPart = copy
		for _, accessory in character:GetChildren() do
			if accessory:IsA("Accessory") then
				local handle, offset = headOffset(accessory, head)
				if handle then
					local item = clonePart(handle)
					if item then
						item.Name = accessory.Name
						item.CFrame = offset
						item.Parent = model
					end
				end
			end
		end
	end)
	if not ok then model:Destroy() return nil end
	return model
end

function Portraits.Bind(marker, player, userId)
	assert(typeof(marker) == "Instance", "Race portrait requires a marker")
	local viewport = marker:FindFirstChild("Portrait")
	local thumbnail = marker:FindFirstChild("Thumbnail")
	assert(viewport and viewport:IsA("ViewportFrame"), "Marker.Portrait must be a ViewportFrame")
	assert(thumbnail and thumbnail:IsA("ImageLabel"), "Marker.Thumbnail must be an ImageLabel")
	if player then
		assert(player:IsA("Player"), "Race portrait player must be a Player or nil")
		userId = userId or player.UserId
		assert(player.UserId == userId, "Race portrait userId does not match player")
	end
	assert(type(userId) == "number" and userId == userId and userId % 1 == 0, "Race portrait requires a userId")
	if bindings[marker] then bindings[marker]:Destroy() end

	local handle = {}
	local alive, generation, queued = true, 0, false
	local connections, characterConnections, appearanceConnections = {}, {}, {}
	local character, model, stopThumbnail
	local thumbnailRequested = false
	local world = Instance.new("WorldModel")
	world.Name = "RacePortraitWorld"
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.Name = "RacePortraitCamera"
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Visible = false
	local placeholder = thumbnail:GetAttribute("FallbackImage")
	thumbnail.Image = type(placeholder) == "string" and placeholder or ""
	thumbnail.Visible = true
	bindings[marker] = handle

	local function current()
		return alive and bindings[marker] == handle and viewport.Parent == marker and thumbnail.Parent == marker
	end
	local function clearModel()
		if model then model:Destroy() model = nil end
	end
	local function fallback()
		if not current() then return end
		viewport.Visible = false
		thumbnail.Visible = true
		if thumbnailRequested or userId <= 0 then return end
		thumbnailRequested = true
		stopThumbnail = thumbnailFor(userId, function(image)
			if current() then thumbnail.Image = image end
		end)
	end
	local function frameHead()
		if not current() or not model then return end
		local cf, size = model:GetBoundingBox()
		local aspect = viewport.AbsoluteSize.Y > 0 and viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y or 1
		aspect = math.max(aspect, 0.1)
		local halfExtent = math.max(size.Y * 0.5, size.X * 0.5 / aspect)
		local distance = halfExtent * 1.13 / math.tan(math.rad(camera.FieldOfView * 0.5)) + size.Z * 0.5
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, -distance), cf.Position)
		camera.Focus = CFrame.new(cf.Position)
	end
	local schedule
	local function appearanceObject(object)
		if not character then return false end
		local head = character:FindFirstChild("Head")
		return object == head or (head and object:IsDescendantOf(head))
			or object:IsA("Accessory") or object:FindFirstAncestorOfClass("Accessory") ~= nil
	end
	local function watchAppearance()
		disconnect(appearanceConnections)
		if not character then return end
		for _, object in character:GetDescendants() do
			if appearanceObject(object) then
				for _, property in appearanceProperties(object) do
					local ok, signal = pcall(object.GetPropertyChangedSignal, object, property)
					if ok then table.insert(appearanceConnections, signal:Connect(schedule)) end
				end
			end
		end
	end
	local function rebuild()
		if not current() then return end
		local nextModel = character and character.Parent and buildHead(character) or nil
		clearModel()
		model = nextModel
		watchAppearance()
		if model then
			model.Parent = world
			frameHead()
			viewport.Visible = true
			thumbnail.Visible = false
		else
			fallback()
		end
	end
	schedule = function()
		if not current() or queued then return end
		queued = true
		local version = generation
		task.delay(0.15, function()
			if not current() or version ~= generation then return end
			queued = false
			rebuild()
		end)
	end
	local function bindCharacter(nextCharacter)
		if not current() then return end
		generation += 1
		queued = false
		disconnect(characterConnections)
		disconnect(appearanceConnections)
		character = nextCharacter
		clearModel()
		if character then
			table.insert(characterConnections, character.AncestryChanged:Connect(schedule))
			table.insert(characterConnections, character.DescendantAdded:Connect(function(object)
				if appearanceObject(object) then schedule() end
			end))
			table.insert(characterConnections, character.DescendantRemoving:Connect(function(object)
				if appearanceObject(object) then schedule() end
			end))
		end
		rebuild()
	end
	function handle:Destroy()
		if not alive then return end
		alive = false
		generation += 1
		disconnect(connections)
		disconnect(characterConnections)
		disconnect(appearanceConnections)
		if stopThumbnail then stopThumbnail() stopThumbnail = nil end
		clearModel()
		if viewport.CurrentCamera == camera then viewport.CurrentCamera = nil end
		world:Destroy()
		camera:Destroy()
		if bindings[marker] == handle then
			bindings[marker] = nil
			viewport.Visible = false
			thumbnail.Visible = false
		end
	end
	table.insert(connections, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameHead))
	table.insert(connections, marker.Destroying:Connect(function() handle:Destroy() end))
	table.insert(connections, viewport.Destroying:Connect(function() handle:Destroy() end))
	table.insert(connections, thumbnail.Destroying:Connect(function() handle:Destroy() end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(leaving)
		if leaving == player or leaving.UserId == userId then
			local entry = thumbnails[userId]
			if entry then entry.removed = true end
			handle:Destroy()
			if entry and not next(entry.callbacks) and thumbnails[userId] == entry then thumbnails[userId] = nil end
		end
	end))
	if player then
		table.insert(connections, player.CharacterAdded:Connect(bindCharacter))
		table.insert(connections, player.CharacterRemoving:Connect(function(removing)
			if removing == character then bindCharacter(nil) end
		end))
		table.insert(connections, player.CharacterAppearanceLoaded:Connect(function(loaded)
			if loaded == character then schedule() end
		end))
	end
	bindCharacter(player and player.Character or nil)
	return handle
end

return Portraits


end)()
local passed = 0
local function test(name, callback)
 callback()
 assert(activeConnections == 0, "leaked listener after " .. name .. ": " .. activeConnections)
 passed += 1 print("PASS " .. name)
end
test("nil player destruction cancels queued request", function()
 local m = marker()
 local h = Portraits.Bind(m, nil, 101)
 assert(m.children.Thumbnail.Visible and not m.children.Portrait.Visible)
 h:Destroy() h:Destroy() drain()
 assert(calls[101] == nil and not m.children.Thumbnail.Visible)
 checkLayout(m)
end)
test("thumbnail requests deduplicate and cache across bindings", function()
 local m1, m2 = marker(), marker()
 local h1, h2 = Portraits.Bind(m1, nil, 102), Portraits.Bind(m2, nil, 102)
 drain()
 assert(calls[102] == 1 and m1.children.Thumbnail.Image == "thumb:102" and m2.children.Thumbnail.Image == "thumb:102")
 h1:Destroy() h2:Destroy()
 local m3 = marker() local h3 = Portraits.Bind(m3, nil, 102)
 assert(calls[102] == 1 and m3.children.Thumbnail.Image == "thumb:102")
 h3:Destroy() drain() checkLayout(m1) checkLayout(m2) checkLayout(m3)
end)
test("rebinding rejects old work and old handle destruction", function()
 local m = marker()
 local old = Portraits.Bind(m, nil, 103)
 local fresh = Portraits.Bind(m, nil, 104)
 old:Destroy() drain()
 assert(calls[103] == nil and m.children.Thumbnail.Image == "thumb:104" and m.children.Thumbnail.Visible)
 fresh:Destroy() checkLayout(m)
end)
test("destroy during a yielding thumbnail request cannot update marker", function()
 local m = marker() local h = Portraits.Bind(m, nil, 105)
 duringFetch = function() h:Destroy() end
 drain()
 assert(m.children.Thumbnail.Image == "" and not m.children.Thumbnail.Visible)
 checkLayout(m)
end)
test("character transitions debounce and keep one camera", function()
 local character = object("Model", "Character") character.Parent = {}
 local p = player(106, character) local m = marker()
 local before = #createdObjects
 local h = Portraits.Bind(m, p)
 local accessory = object("Accessory", "Hat")
 for _ = 1, 8 do character.DescendantAdded:Fire(accessory) end
 assert(#jobs == 2, "appearance work did not coalesce with thumbnail task")
 local nextCharacter = object("Model", "NextCharacter") nextCharacter.Parent = {}
 p.Character = nextCharacter p.CharacterAdded:Fire(nextCharacter)
 drain()
 assert(#createdObjects == before + 2, "camera or world recreated")
 assert(calls[106] == 1 and m.children.Thumbnail.Image == "thumb:106")
 p.CharacterRemoving:Fire(nextCharacter)
 Players.PlayerRemoving:Fire(p)
 drain() checkLayout(m)
 assert(not m.children.Thumbnail.Visible)
 local m2 = marker() local h2 = Portraits.Bind(m2, nil, 106) drain()
 assert(calls[106] == 2, "removed player's cached thumbnail not evicted")
 h2:Destroy()
end)
test("authored child destruction cleans binding", function()
 local m = marker() local h = Portraits.Bind(m, nil, 107)
 m.children.Portrait:Destroy() drain()
 assert(calls[107] == nil)
 h:Destroy()
end)
for _, item in createdObjects do assert(item.destroyed, "owned instance leaked: " .. item.ClassName) end
print("PASS " .. passed .. " portrait lifecycle checks")

