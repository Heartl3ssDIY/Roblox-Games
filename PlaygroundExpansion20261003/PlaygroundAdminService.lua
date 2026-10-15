local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Admin = {}
Admin.__index = Admin
local controls = {
	BBStart = { game = "BritishBulldog" }, BBRunner = { game = "BritishBulldog", role = "Runner" }, BBBulldog = { game = "BritishBulldog", role = "Bulldog" },
	TagStart = { game = "TagYoureIt" }, TagRunner = { game = "TagYoureIt", role = "Runner" }, TagTagger = { game = "TagYoureIt", role = "Tagger" },
}
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }

function Admin.new(coordinator, config, isStudio)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	if self.isStudio then return true end
	local id = player.UserId
	if game.CreatorType == Enum.CreatorType.User and id == game.CreatorId then return true end
	if id == self.config:GetAttribute("AdminUserId") then return true end
	local extra = self.config:GetAttribute("ExtraAdminUserIds")
	if typeof(extra) == "string" then
		for value in string.gmatch(extra, "%d+") do if tonumber(value) == id then return true end end
	end
	return false
end

function Admin:Status(player, ok, message)
	local active = self.coordinator:ActiveGame()
	local service = active and self.coordinator.services[active]
	return { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
end

function Admin:Handle(player, action)
	if not self:IsAuthorized(player) then return { ok = false, message = "Admin access required." } end
	if typeof(action) ~= "string" then return self:Status(player, false, "Unknown control.") end
	action = aliases[action] or action
	if not controls[action] and action ~= "StopRound" and action ~= "GetStatus" and action ~= "ToggleAutomatic" then return self:Status(player, false, "Unknown control.") end
	local now = os.clock()
	local timestamps = action == "GetStatus" and self.lastStatus or self.lastRequest
	if now - (timestamps[player] or -math.huge) < (action == "GetStatus" and 0.1 or 0.5) then return self:Status(player, false, "Please wait a moment.") end
	timestamps[player] = now
	if action == "GetStatus" then return self:Status(player, true, "Ready to play.") end
	if self.busy then return self:Status(player, false, "Another control is finishing.") end
	self.busy = true
	local ok, success, message = pcall(function()
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
		return self:Status(player, false, "The game couldn't start. Try again.")
	end
	return self:Status(player, success == true, message)
end

function Admin.Start(coordinator)
	local config = ServerStorage:WaitForChild("PlaygroundAdminConfig")
	local remote = ReplicatedStorage:WaitForChild("PlaygroundAdminRequest")
	local self = Admin.new(coordinator, config, RunService:IsStudio())
	self.remote = remote
	remote.OnServerInvoke = function(player, action) return self:Handle(player, action) end
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
