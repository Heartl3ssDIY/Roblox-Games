local Players = game:GetService("Players")
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
controls.DGStart = { game = "DuckDuckGoose" }
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
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "DuckDuckGoose" and player:GetAttribute("DGRole") or active == "HideAndSeek" and player:GetAttribute("HSRole") or active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
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
