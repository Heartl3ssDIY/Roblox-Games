local Players = game:GetService("Players")
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

