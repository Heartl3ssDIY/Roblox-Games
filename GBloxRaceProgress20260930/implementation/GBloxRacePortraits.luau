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
