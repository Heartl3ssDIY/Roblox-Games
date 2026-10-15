
assert(game.PlaceId==106769122906103,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local editor=game:GetService("ScriptEditorService")
local server=game.ServerScriptService.RunnerServer
local client=game.StarterPlayer.StarterPlayerScripts.RunnerClient
local function normalized(s) return (s:gsub("\r\n","\n")) end
local function hash(s) local h=5381 for i=1,#s do h=(h*33+s:byte(i))%4294967296 end return h end
local serverBefore=editor:GetEditorSource(server)
local clientBefore=editor:GetEditorSource(client)
assert(hash(normalized(serverBefore))==2579172160,"RunnerServer changed since backup; stopped")
assert(hash(normalized(clientBefore))==2629689237,"RunnerClient changed since backup; stopped")
local edits={{old_string=[====[local roundPhase = "Waiting"
local spectating=]====],new_string=[====[local roundPhase = "Waiting"
local raceProgress
local spectating=]====]},{old_string=[====[	event:FireAllClients("State", packet)
end

local function resetRound()]====],new_string=[====[	event:FireAllClients("State", packet)
 if raceProgress then raceProgress:Publish() end
end

local function resetRound()]====]},{old_string=[====[ return math.clamp((data.roundStartX-data.root.Position.X)/span,0,1)
end

local function sendRoundRankings()]====],new_string=[====[ return math.clamp((data.roundStartX-data.root.Position.X)/span,0,1)
end

raceProgress=require(game.ServerScriptService:WaitForChild("GBloxRaceProgressServer")).new({
 Runners=players,Phase=function() return roundPhase end,RoundKey=function() return courseVersion end,
 CourseNumber=function() return courseNumber end,Progress=currentRoundProgress,
 IsPresent=function(player) return player.Parent==Players end,
 Broadcast=function(packet) event:FireAllClients("RaceProgress",packet) end,
})

local function sendRoundRankings()]====]},{old_string=[====[            data.roundStoppedProgress=nil data.roundFinishTime=nil data.roundFinishPlace=nil data.firstFinishTime=nil data.maxProgress=0 data.roundStartX=data.root.Position.X
            data.root.Anchored = false]====],new_string=[====[            data.roundStoppedProgress=nil data.roundFinishTime=nil data.roundFinishPlace=nil data.firstFinishTime=nil data.maxProgress=0 data.roundStartX=data.root.Position.X
            raceProgress:MarkStarted(player,courseVersion)
            data.root.Anchored = false]====]},{old_string=[====[RunService.Heartbeat:Connect(function(deltaTime)
 spectatorClock+=deltaTime]====],new_string=[====[RunService.Heartbeat:Connect(function(deltaTime)
 raceProgress:Step(deltaTime)
 spectatorClock+=deltaTime]====]}}
local function patched(source,changes)
 source=normalized(source)
 for _,p in changes do
  local a,z=source:find(p.old_string,1,true)
  assert(a and not source:find(p.old_string,z+1,true),"Patch not unique")
  source=source:sub(1,a-1)..p.new_string..source:sub(z+1)
 end
 return source
end
local nextServer=patched(serverBefore,edits)
local nextClient=patched(clientBefore,{{old_string=[====[local lifeStatus = create("TextLabel", "SecondLifeStatus", gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 70),]====],new_string=[====[local lifeStatus = create("TextLabel", "SecondLifeStatus", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -48),]====]}})
local targets={{game.ServerScriptService,"GBloxRaceProgressServer"},{game.ReplicatedStorage,"GBloxRaceProgressRules"},{game.ReplicatedStorage,"GBloxRacePortraits"},{game.StarterGui,"GBloxRaceProgress"}}
for _,t in targets do assert(not t[1]:FindFirstChild(t[2]),"Existing target: "..t[2]) end
local announcement=game.StarterGui.GBloxAbilityHUD.Announcement
local oldPosition,oldSize=announcement.Position,announcement.Size
local history=game:GetService("ChangeHistoryService")
local record=history:TryBeginRecording("GBloxRaceProgressInstall","Add G-Blox race progress HUD")
if not record then history:SetWaypoint("Before G-Blox race progress HUD") end
local created={}
local serverChanged,clientChanged=false,false
local ok,result=xpcall(function()
 local function module(parent,name,source)
  local m=Instance.new("ModuleScript") table.insert(created,m)
  m.Name=name m.Source=source m.Parent=parent
  return m
 end
 module(game.ServerScriptService,"GBloxRaceProgressServer",[====[local RaceProgress = {}
local INTERVAL = 0.15

local function finite(value, fallback)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return value
end

function RaceProgress.new(context)
	local roster = {}
	local elapsed = 0
	local sequence = 0
	local lastPhase, lastVersion, lastCourse
	local isPresent = context.IsPresent or function(player)
		return player.Parent ~= nil
	end
	local self = {}

	local function synchronize()
		local phase = context.Phase()
		local version = context.RoundKey()
		local course = context.CourseNumber()
		local changed = phase ~= lastPhase or version ~= lastVersion or course ~= lastCourse
		if version ~= lastVersion or phase ~= "Running" then
			table.clear(roster)
		end
		if changed then elapsed = 0 end
		lastPhase, lastVersion, lastCourse = phase, version, course
		return changed, phase, version, course
	end

	function self:MarkStarted(player, version)
		local _, phase, currentVersion = synchronize()
		local data = context.Runners[player]
		if phase ~= "Running" or version ~= currentVersion or not data
			or data.status ~= "Running" or data.courseVersion ~= currentVersion
			or not isPresent(player) then
			return false
		end
		roster[player] = data
		return true
	end

	function self:Publish()
		local _, phase, version, course = synchronize()
		local rows = {}
		if phase == "Running" then
			for player, data in roster do
				if not isPresent(player) or context.Runners[player] ~= data then
					roster[player] = nil
				else
					local finished = data.roundFinishTime ~= nil
					local status = finished and "Finished" or data.status == "Running" and "Running" or "Out"
					local progress
					if finished then
						progress = 1
					elseif status == "Running" then
						progress = context.Progress(data)
					else
						progress = data.roundStoppedProgress or data.maxProgress or 0
					end
					table.insert(rows, {
						userId = player.UserId,
						progress = math.clamp(finite(progress, 0), 0, finished and 1 or 0.999),
						status = status,
						finished = finished,
						finishPlace = finished and finite(data.roundFinishPlace, nil) or nil,
						finishTime = finished and finite(data.roundFinishTime, nil) or nil,
					})
				end
			end
			table.sort(rows, function(a, b)
				if a.finished ~= b.finished then return a.finished end
				if a.finished then
					if a.finishPlace ~= b.finishPlace then
						return (a.finishPlace or 99) < (b.finishPlace or 99)
					end
					if a.finishTime ~= b.finishTime then
						return (a.finishTime or math.huge) < (b.finishTime or math.huge)
					end
				elseif a.progress ~= b.progress then
					return a.progress > b.progress
				end
				return a.userId < b.userId
			end)
			for place, row in rows do
				row.place = place
				row.finishTime = nil
			end
		end
		sequence += 1
		elapsed = 0
		local packet = {
			phase = phase,
			courseVersion = version,
			courseNumber = course,
			sequence = sequence,
			rows = rows,
		}
		context.Broadcast(packet)
		return packet
	end

	function self:Step(deltaTime)
		local changed, phase = synchronize()
		if changed then
			self:Publish()
			return
		end
		if phase ~= "Running" then return end
		elapsed += math.max(0, finite(deltaTime, 0))
		if elapsed >= INTERVAL then self:Publish() end
	end

	return self
end

return RaceProgress
]====])
 module(game.ReplicatedStorage,"GBloxRaceProgressRules",[====[local Rules = {}

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function Rules.Accept(packet, minimumVersion, lastSequence, maxPlayers)
	if type(packet) ~= "table" or not finite(packet.courseVersion)
		or packet.courseVersion < minimumVersion or packet.courseVersion % 1 ~= 0
		or not finite(packet.sequence) or packet.sequence <= lastSequence
		or type(packet.phase) ~= "string" or type(packet.rows) ~= "table"
		or #packet.rows > maxPlayers then return nil end
	local rows, seen = {}, {}
	for index, row in ipairs(packet.rows) do
		if type(row) ~= "table" or not finite(row.userId) or row.userId % 1 ~= 0
			or seen[row.userId] or not finite(row.progress) or row.place ~= index
			or (row.status ~= "Running" and row.status ~= "Finished" and row.status ~= "Out") then return nil end
		seen[row.userId] = true
		table.insert(rows, {
			userId = row.userId,
			progress = row.status == "Finished" and 1 or math.clamp(row.progress, 0, 0.999),
			place = row.place,
			status = row.status,
		})
	end
	return { courseVersion = packet.courseVersion, sequence = packet.sequence, phase = packet.phase, rows = rows }
end

function Rules.Appearance(place, isLocal, status)
	local medal = place == 1 and "gold" or place == 2 and "silver" or place == 3 and "bronze" or "other"
	local style = isLocal and "you" or medal
	return {
		ring = style .. "-ring",
		badge = style .. "-badge",
		showNumber = isLocal or place > 3,
		zIndex = isLocal and 100 or 30 - place,
		muted = status == "Out",
		finished = status == "Finished",
	}
end

function Rules.Visible(phase, ready, podium, podiumCamera, hasPacket)
	return phase == "Running" and ready == true and not podium and not podiumCamera and hasPacket == true
end

return Rules
]====])
 module(game.ReplicatedStorage,"GBloxRacePortraits",[====[local Players = game:GetService("Players")

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
]====])
 local build=(function()
local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in properties or {} do object[key] = value end
	object.Parent = parent
	return object
end

return function(assets)
	local gui = create("ScreenGui", "GBloxRaceProgress", nil, {
		DisplayOrder = 30, ResetOnSpawn = false, Enabled = true,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui:SetAttribute("RaceProgressVersion", 1)
	local artwork = create("Folder", "Artwork", gui)
	for key, asset in assets do create("StringValue", key, artwork, {Value = asset}) end
	local function frame(name, parent, props)
		local object = create("Frame", name, parent, {BackgroundTransparency = 1, BorderSizePixel = 0})
		for key, value in props or {} do object[key] = value end
		return object
	end
	local function image(name, parent, asset, position, size, anchor, z)
		return create("ImageLabel", name, parent, {
			BackgroundTransparency = 1, BorderSizePixel = 0, Image = assets[asset] or "",
			Position = position, Size = size, AnchorPoint = anchor or Vector2.zero,
			ZIndex = z or 1, ScaleType = Enum.ScaleType.Stretch,
		})
	end
	local hud = frame("HUD", gui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.76, 0, 0, 82), Visible = false,
	})
	create("UISizeConstraint", "ResponsiveWidth", hud, {MinSize = Vector2.new(260, 82), MaxSize = Vector2.new(900, 82)})
	local track = frame("Track", hud, {Position = UDim2.new(0, 36, 0, 38), Size = UDim2.new(1, -72, 0, 16)})
	image("TrackArtwork", track, "track", UDim2.fromScale(0,0), UDim2.fromScale(1,1))
	local interior = frame("ProgressInterior", track, {Position = UDim2.fromOffset(4,3), Size = UDim2.new(1,-8,1,-6), ZIndex = 2})
	image("Fill", interior, "fill", UDim2.fromScale(0,0), UDim2.fromScale(0,1))
	image("StartLabel", track, "start", UDim2.new(0,0,1,8), UDim2.fromOffset(55,12), Vector2.new(0.5,0),3)
	image("FinishLabel", track, "finish", UDim2.new(1,0,1,8), UDim2.fromOffset(65,12), Vector2.new(0.5,0),3)
	image("FinishFlag", track, "flag", UDim2.new(1,8,0.5,0), UDim2.fromOffset(18,22), Vector2.new(0,0.5),3)
	frame("Markers", track, {Size = UDim2.fromScale(1,1), ZIndex = 10})
	local templates = create("Folder", "Templates", gui)
	local marker = frame("PlayerMarker", templates, {
		AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0,0.5),
		Size = UDim2.fromOffset(46,46), Visible = false, ZIndex = 20,
	})
	image("Ring", marker, "other-ring", UDim2.fromScale(0,0), UDim2.fromScale(1,1),nil,1)
	create("ViewportFrame", "Portrait", marker, {
		Position = UDim2.fromScale(0.5,0.48), AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.fromScale(0.68,0.68),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Visible = false,
		Ambient = Color3.fromRGB(200,220,235), LightColor = Color3.fromRGB(245,250,255), LightDirection = Vector3.new(-1,-1,-2),
	})
	local thumb = image("Thumbnail", marker, "", UDim2.fromScale(0.5,0.48), UDim2.fromScale(0.68,0.68), Vector2.new(0.5,0.5),2)
	create("UICorner", "Circle", thumb, {CornerRadius = UDim.new(1,0)})
	local badge = image("Badge", marker, "other-badge", UDim2.fromScale(0.85,0.85), UDim2.fromOffset(18,18), Vector2.new(0.5,0.5),4)
	create("TextLabel", "Number", badge, {
		Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "", TextSize = 18,
		TextColor3 = Color3.fromRGB(6,24,34), Font = Enum.Font.Arcade, ZIndex = 5,
	})
	local you = image("YouLabel", marker, "you-label", UDim2.new(0.5,0,0,-17), UDim2.fromOffset(42,16), Vector2.new(0.5,0),4)
	you.Visible = false
	local finished = image("Finished", marker, "flag", UDim2.new(1,-2,0,-5), UDim2.fromOffset(13,16), nil,4)
	finished.Visible = false
	create("TextLabel", "OutLabel", marker, {
		Position = UDim2.new(0.5,0,1,3), AnchorPoint = Vector2.new(0.5,0), Size = UDim2.fromOffset(36,14),
		BackgroundColor3 = Color3.fromRGB(6,24,34), BackgroundTransparency = 0.12, BorderSizePixel = 0,
		Text = "OUT", TextColor3 = Color3.fromRGB(185,207,216), Font = Enum.Font.Arcade,
		TextSize = 10, Visible = false, ZIndex = 4,
	})
	return gui
end

end)()
 local gui=build({["bronze-badge"]="rbxassetid://94168005493584",["track"]="rbxassetid://75503937294462",["start"]="rbxassetid://135544039418291",["you-ring"]="rbxassetid://126615691544771",["finish"]="rbxassetid://90743517207431",["other-badge"]="rbxassetid://70387575602485",["flag"]="rbxassetid://88205366205241",["other-ring"]="rbxassetid://129601475644689",["you-label"]="rbxassetid://81403660935236",["silver-badge"]="rbxassetid://87561710303958",["gold-ring"]="rbxassetid://121675672980409",["bronze-ring"]="rbxassetid://118880995296193",["silver-ring"]="rbxassetid://110616119068168",["you-badge"]="rbxassetid://86355349566414",["fill"]="rbxassetid://84519143176739",["gold-badge"]="rbxassetid://86948793458498"})
 table.insert(created,gui)
 local controller=Instance.new("LocalScript")
 controller.Name="Controller" controller.Source=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
local gui = script.Parent
if game.PlaceId ~= config.PlaceId or config.TutorialRecovery == true then gui.Enabled = false return end

local Rules = require(ReplicatedStorage:WaitForChild("GBloxRaceProgressRules"))
local Portraits = require(ReplicatedStorage:WaitForChild("GBloxRacePortraits"))
local event = ReplicatedStorage:WaitForChild("RunnerEvent")
local root = gui:WaitForChild("HUD")
local track = root:WaitForChild("Track")
local markers = track:WaitForChild("Markers")
local fill = track:WaitForChild("ProgressInterior"):WaitForChild("Fill")
local template = gui:WaitForChild("Templates"):WaitForChild("PlayerMarker")
local artwork = gui:WaitForChild("Artwork")
local entries, connections = {}, {}
local version = player:GetAttribute("RunnerCourseVersion") or 0
local sequence = 0
local phase = workspace:GetAttribute("RunnerRoundPhase") or "Waiting"
local packet, fillTween, destroyed
local smooth = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
root.Visible = false

local function clearDisplay()
	packet = nil
	for _, entry in entries do
		if entry.tween then entry.tween:Cancel() end
		entry.frame.Visible = false
		entry.fresh = true
	end
	if fillTween then fillTween:Cancel() end
	fill.Size = UDim2.fromScale(0, 1)
	root.Visible = false
end

local function visibility()
	root.Visible = Rules.Visible(phase, player:GetAttribute("GBloxCourseReady"),
		player:GetAttribute("GBloxPodiumActive"), player:GetAttribute("GBloxPodiumCameraActive"), packet ~= nil)
end

local function imageFor(key)
	local value = artwork:FindFirstChild(key)
	return value and value.Value or ""
end

local function removeEntry(id)
	local entry = entries[id]
	if not entry then return end
	if entry.tween then entry.tween:Cancel() end
	entry.portrait:Destroy()
	entry.frame:Destroy()
	entries[id] = nil
end

local function getEntry(id)
	if entries[id] then return entries[id] end
	local marker = template:Clone()
	marker.Name = "Player_" .. tostring(id)
	marker.Parent = markers
	local entry = {frame = marker, fresh = true}
	entry.portrait = Portraits.Bind(marker, Players:GetPlayerByUserId(id), id)
	entries[id] = entry
	return entry
end

local function applyPacket(nextPacket)
	local minimum = math.max(version, player:GetAttribute("RunnerCourseVersion") or 0)
	local accepted = Rules.Accept(nextPacket, minimum, sequence, config.MaxPlayers)
	if not accepted then return end
	sequence = accepted.sequence
	if accepted.courseVersion ~= version then clearDisplay() end
	version, phase = accepted.courseVersion, accepted.phase
	if phase ~= "Running" then clearDisplay() return end
	packet = accepted
	local present, ownProgress = {}, 0
	for _, row in accepted.rows do
		present[row.userId] = true
		local entry = getEntry(row.userId)
		local marker = entry.frame
		local isLocal = row.userId == player.UserId
		local style = Rules.Appearance(row.place, isLocal, row.status)
		marker.ZIndex = style.zIndex
		marker.Ring.Image = imageFor(style.ring)
		marker.Badge.Image = imageFor(style.badge)
		marker.Badge.Number.Text = tostring(row.place)
		marker.Badge.Number.Visible = style.showNumber
		marker.YouLabel.Visible = isLocal
		marker.Finished.Visible = style.finished
		marker.OutLabel.Visible = style.muted
		marker.Ring.ImageTransparency = style.muted and 0.35 or 0
		marker.Portrait.ImageTransparency = style.muted and 0.5 or 0
		marker.Thumbnail.ImageTransparency = style.muted and 0.5 or 0
		marker.Visible = true
		local position = UDim2.new(row.progress, 0, template.Position.Y.Scale, template.Position.Y.Offset)
		if entry.tween then entry.tween:Cancel() end
		if entry.fresh or not root.Visible then
			marker.Position = position
		else
			entry.tween = TweenService:Create(marker, smooth, {Position = position})
			entry.tween:Play()
		end
		entry.fresh = false
		if isLocal then ownProgress = row.progress end
	end
	for id, entry in entries do
		if not present[id] then
			if entry.tween then entry.tween:Cancel() end
			entry.frame.Visible = false
			entry.fresh = true
		end
	end
	if fillTween then fillTween:Cancel() end
	local fillSize = UDim2.fromScale(ownProgress, 1)
	if not root.Visible then fill.Size = fillSize else
		fillTween = TweenService:Create(fill, smooth, {Size = fillSize})
		fillTween:Play()
	end
	visibility()
end

table.insert(connections, event.OnClientEvent:Connect(function(action, data)
	if action == "RaceProgress" then applyPacket(data)
	elseif action == "State" and type(data) == "table" then
		if type(data.courseVersion) ~= "number" or data.courseVersion < version then return end
		if data.courseVersion ~= version then clearDisplay() end
		version, phase = data.courseVersion, data.phase
		if phase ~= "Running" then clearDisplay() else visibility() end
	end
end))
for _, attribute in {"GBloxCourseReady", "GBloxPodiumActive", "GBloxPodiumCameraActive"} do
	table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(visibility))
end
table.insert(connections, player:GetAttributeChangedSignal("RunnerCourseVersion"):Connect(function()
	local current = player:GetAttribute("RunnerCourseVersion") or 0
	if current > version then version = current clearDisplay() end
end))
table.insert(connections, workspace:GetAttributeChangedSignal("RunnerRoundPhase"):Connect(function()
	local current = workspace:GetAttribute("RunnerRoundPhase")
	if current ~= "Running" then phase = current clearDisplay() end
end))
table.insert(connections, Players.PlayerRemoving:Connect(function(leaving) removeEntry(leaving.UserId) end))
local function cleanup()
	if destroyed then return end
	destroyed = true
	for _, connection in connections do connection:Disconnect() end
	for id in entries do removeEntry(id) end
	if fillTween then fillTween:Cancel() end
end
script.Destroying:Connect(cleanup)
gui.Destroying:Connect(cleanup)
]====] controller.Parent=gui
 gui.Parent=game.StarterGui
 editor:UpdateSourceAsync(server,function(old) assert(normalized(old)==normalized(serverBefore),"Server changed during edit") return nextServer end) serverChanged=true
 editor:UpdateSourceAsync(client,function(old) assert(normalized(old)==normalized(clientBefore),"Client changed during edit") return nextClient end) clientChanged=true
 announcement.Position=UDim2.new(.5,0,0,94)
 announcement.Size=UDim2.new(.86,0,0,72)
 return {gui=gui:GetFullName(),serverHook=true,clientHook=true,artworkCount=#gui.Artwork:GetChildren(),rootPosition=tostring(gui.HUD.Position),rootSize=tostring(gui.HUD.Size)}
end,debug.traceback)
if not ok then
 if serverChanged then editor:UpdateSourceAsync(server,function() return serverBefore end) end
 if clientChanged then editor:UpdateSourceAsync(client,function() return clientBefore end) end
 announcement.Position,announcement.Size=oldPosition,oldSize
 for _,item in created do item:Destroy() end
if record then history:FinishRecording(record,Enum.FinishRecordingOperation.Cancel) end
 error(result)
end
if record then history:FinishRecording(record,Enum.FinishRecordingOperation.Commit) else history:SetWaypoint("Added G-Blox race progress HUD") end
return result

