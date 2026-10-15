assert(not game:GetService("RunService"):IsRunning(),"Play must remain stopped")
local server=game.ServerScriptService.PlaygroundAdminService
local gui=game.StarterGui.PlaygroundAdminPanel
local config=game.ServerStorage.PlaygroundAdminConfig
assert(server.Source==[====[local Players = game:GetService("Players")
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
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
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
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
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
]====],"Server source changed")
assert(gui.Controller.Source==[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and not equipped and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()
]====],"UI source changed")
assert(config:GetAttribute("AdminUserId")==1201803949,"Owner changed")
assert(not game.ServerStorage:FindFirstChild("OwnerAdminBackup20261007"),"Backup already exists")
local backup=Instance.new("Folder"); backup.Name="OwnerAdminBackup20261007"; backup.Parent=game.ServerStorage
server:Clone().Parent=backup
gui:Clone().Parent=backup
config:Clone().Parent=backup
server.Source=[====[local Players = game:GetService("Players")
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
local aliases = { StartRound = "BBStart", PracticeRunner = "BBRunner", PracticeBulldog = "BBBulldog" }
local grants = { GrantItem = true, GrantCoins = true, AddLevels = true }

function Admin.new(coordinator, config, isStudio, playerSource)
	return setmetatable({ coordinator = coordinator, config = config, isStudio = isStudio, players = playerSource or Players, lastRequest = {}, lastStatus = {}, busy = false, connections = {} }, Admin)
end

function Admin:IsAuthorized(player)
	local ownerId = self.config:GetAttribute("AdminUserId")
	return typeof(ownerId) == "number" and ownerId > 0 and ownerId % 1 == 0 and player.UserId == ownerId
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
	local reply = { ok = ok, message = message or "", game = active or "", phase = service and service.phase or "Waiting", mode = service and service.state:GetAttribute("Mode") or "Waiting", role = active == "StuckInTheMud" and (player:GetAttribute("MDMuddy") and "Stuck" or "Free") or active == "TagYoureIt" and player:GetAttribute("TGRole") or player:GetAttribute("BBRole"), automatic = self.coordinator.autoEnabled }
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
]====]
gui.Controller.Source=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
gui.Enabled = false
for _, name in ipairs({ "Toggle", "AdminHub", "Panel", "CompactPanel", "CompactToggle" }) do
	local object = gui:FindFirstChild(name)
	if object then object.Visible = false end
end
local hub = gui:WaitForChild("AdminHub")
local pages = hub.Pages
local itemsPage = pages.Items
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local connections = {}
local busy = false
local opened = false
local tab = "Items"
local category = "All"
local page = 1
local pageCount = 1
local selectedUserId = player.UserId
local targetData = nil
local roster = {}
local slots = {}
local states = {}
local gameControls = {}
local limits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 }
local gold = Color3.fromRGB(255, 211, 78)
local blue = Color3.fromRGB(89, 193, 244)
local muted = Color3.fromRGB(194, 201, 206)
local green = Color3.fromRGB(130, 225, 180)
local mudActions = { MudStart = true, MudShooter = true, MudMedic = true }
local phases = { Waiting = "Ready", Countdown = "Countdown", Crossing = "Playing", Playing = "Playing", Results = "Round finished", Intermission = "Next round" }
local gameNames = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }
local request

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function admin()
	return player.UserId == gui:GetAttribute("OwnerUserId") and player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end
local function sortedRoster(source)
	local result = {}
	for _, entry in ipairs(source) do
		if typeof(entry.userId) == "number" and typeof(entry.name) == "string" then table.insert(result, entry) end
	end
	table.sort(result, function(a, b)
		if a.userId == player.UserId then return b.userId ~= player.UserId end
		if b.userId == player.UserId then return false end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return result
end
local function refreshLocalRoster()
	local list = {}
	for _, current in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = current.UserId, name = current.Name, displayName = current.DisplayName, ready = current:GetAttribute("PCDataReady") == true })
	end
	roster = sortedRoster(list)
end
local function selectedEntry()
	for index, entry in ipairs(roster) do if entry.userId == selectedUserId then return entry, index end end
	return nil, nil
end
local function rewardReady()
	return admin() and not busy and targetData ~= nil and targetData.ready == true
end
local function syncTarget()
	local entry = selectedEntry()
	local own = selectedUserId == player.UserId
	local name = entry and ((entry.displayName or entry.name) .. " (@" .. entry.name .. ")") or "Player unavailable"
	hub.Target.PlayerName.Text = (own and "SELF · " or "") .. name
	hub.Target.PlayerStats.Text = targetData and targetData.ready and (tostring(targetData.coins or 0) .. " coins · Level " .. tostring(targetData.level or 1)) or "Profile loading..."
	enabled(hub.Target.Previous, admin() and not busy and #roster > 1)
	enabled(hub.Target.Next, admin() and not busy and #roster > 1)
	enabled(hub.Target.Self, admin() and not busy, own and gold or blue)
	enabled(pages.Rewards.Coins.GrantCoins, rewardReady())
	enabled(pages.Rewards.Levels.AddLevels, rewardReady())
end
local function unlockText(item)
	local unlock = item.unlock
	if not unlock or unlock.kind == "Starter" then return "Starter reward" end
	if unlock.kind == "Coins" then return tostring(item.price) .. " coins" end
	if unlock.kind == "Level" then return "Level " .. tostring(unlock.amount) end
	return tostring(unlock.amount) .. " " .. (gameNames[unlock.gameId] or "total") .. " wins"
end
local function syncItems()
	local query = string.lower(string.sub(itemsPage.Search.Value.Text, 1, 100))
	local matches = {}
	for _, item in ipairs(catalog.Items) do
		if (category == "All" or item.category == category) and (query == "" or string.find(string.lower(item.id .. " " .. item.name), query, 1, true)) then table.insert(matches, item) end
	end
	pageCount = math.max(1, math.ceil(#matches / #slots))
	page = math.clamp(page, 1, pageCount)
	itemsPage.Empty.Visible = #matches == 0
	itemsPage.Pager.PageLabel.Text = tostring(page) .. " / " .. tostring(pageCount)
	enabled(itemsPage.Pager.Previous, page > 1 and not busy)
	enabled(itemsPage.Pager.Next, page < pageCount and not busy)
	for index, record in ipairs(slots) do
		local item = matches[(page - 1) * #slots + index]
		record.item = item
		record.row.Visible = item ~= nil
		if item then
			record.row:SetAttribute("CatalogId", item.id)
			local owned = targetData and targetData.owned and targetData.owned[item.id] == true
			local equipped = targetData and targetData.equipped and targetData.equipped[item.slot] == item.id
			record.row.ItemName.Text = item.id .. " · " .. item.name
			record.row.Detail.Text = item.category .. " · " .. (equipped and "Equipped" or owned and "Owned" or unlockText(item))
			caption(record.row.Grant, busy and "WAIT..." or owned and "OWNED" or "GRANT")
			caption(record.row.GrantEquip, busy and "WAIT..." or equipped and "EQUIPPED" or owned and "EQUIP" or "GRANT + EQUIP")
			enabled(record.row.Grant, rewardReady() and not owned and item.available ~= false)
			enabled(record.row.GrantEquip, rewardReady() and not equipped and item.available ~= false, green)
		end
	end
	for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do enabled(itemsPage.Filters[id], admin(), id == category and gold or blue) end
end
local function syncRounds()
	local mud = states.MudState
	for action, button in pairs(gameControls) do
		local allowed = admin() and not busy and (not mudActions[action] or mud and mud:GetAttribute("GunAccessReady") == true)
		enabled(button, allowed)
	end
	for id, stateName in pairs({ BritishBulldog = "BritishBulldogState", TagYoureIt = "TagState", StuckInTheMud = "MudState" }) do
		local state = states[stateName]
		local phase = state and state:GetAttribute("Phase") or "Waiting"
		local mode = state and state:GetAttribute("Mode") or ""
		local text = (string.find(mode, "Practice", 1, true) and "Solo practice · " or "") .. (phases[phase] or phase)
		if id == "StuckInTheMud" and (not mud or mud:GetAttribute("GunAccessReady") ~= true) then text = "Gun access pending" end
		pages.Rounds[id].Status.Text = text
	end
	local state = states.PlaygroundState
	caption(gameControls.ToggleAutomatic, state and state:GetAttribute("AutomaticRounds") == true and "AUTO ROUNDS: ON" or "AUTO ROUNDS: OFF")
end
local function sync()
	syncVisibility()
	syncTarget()
	syncItems()
	syncRounds()
end
local function applyReply(reply, requestedTarget)
	if typeof(reply.players) == "table" then roster = sortedRoster(reply.players) end
	if typeof(reply.limits) == "table" then
		for key in pairs(limits) do if typeof(reply.limits[key]) == "number" then limits[key] = reply.limits[key] end end
	end
	if requestedTarget == selectedUserId and typeof(reply.target) == "table" and reply.target.userId == selectedUserId then targetData = reply.target end
end
request = function(action, payload, quiet)
	if not admin() or busy then return end
	if mudActions[action] and (not states.MudState or states.MudState:GetAttribute("GunAccessReady") ~= true) then return end
	local remote = ReplicatedStorage:FindFirstChild("PlaygroundAdminRequest")
	if not remote or not remote:IsA("RemoteFunction") then message("Admin controls are getting ready.") return end
	local requestedTarget = selectedUserId
	payload = payload or {}
	payload.targetUserId = requestedTarget
	busy = true
	sync()
	task.spawn(function()
		local ok, reply = pcall(function() return remote:InvokeServer(action, payload) end)
		busy = false
		if not gui.Parent then return end
		if ok and typeof(reply) == "table" then
			applyReply(reply, requestedTarget)
			if not quiet or not reply.ok then message(reply.message or (reply.ok and "Done." or "Request did not complete.")) end
		else message("Server unavailable. Try again.") end
		sync()
		if requestedTarget ~= selectedUserId and admin() then task.defer(function() request("GetStatus", nil, true) end) end
	end)
end
local function selectTarget(userId)
	if busy then return end
	selectedUserId = userId
	targetData = nil
	message("Rewards will go to the selected player.")
	sync()
	request("GetStatus", nil, true)
end
local function cycleTarget(direction)
	if busy or #roster == 0 then return end
	local _, index = selectedEntry()
	selectTarget(roster[((index or 1) - 1 + direction) % #roster + 1].userId)
end
for _, row in ipairs(itemsPage.Rows:GetChildren()) do
	if row:IsA("Frame") and row:FindFirstChild("Grant") then table.insert(slots, { row = row }) end
end
table.sort(slots, function(a, b) return a.row.Name < b.row.Name end)
for _, record in ipairs(slots) do
	connect(record.row.Grant.Activated, function()
		if record.item and record.row.Grant.Active then request("GrantItem", { itemId = record.item.id, equip = false }) end
	end)
	connect(record.row.GrantEquip.Activated, function()
		if record.item and record.row.GrantEquip.Active then request("GrantItem", { itemId = record.item.id, equip = true }) end
	end)
end
for _, id in ipairs({ "All", "Bats", "Pets", "Toys" }) do
	connect(itemsPage.Filters[id].Activated, function() category = id page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
end
connect(itemsPage.Search.Value:GetPropertyChangedSignal("Text"), function() page = 1 itemsPage.Rows.CanvasPosition = Vector2.zero syncItems() end)
for _, spec in ipairs({ { "Previous", -1 }, { "Next", 1 } }) do
	connect(itemsPage.Pager[spec[1]].Activated, function()
		if busy then return end
		page = math.clamp(page + spec[2], 1, pageCount)
		itemsPage.Rows.CanvasPosition = Vector2.zero
		syncItems()
	end)
end
local function grantAmount(action, box, maximum)
	if not rewardReady() then return end
	local amount = tonumber(box.Text)
	if not amount or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > maximum then
		message("Enter a whole number from 1 to " .. tostring(maximum) .. ".")
		return
	end
	request(action, { amount = amount })
end
connect(pages.Rewards.Coins.GrantCoins.Activated, function() grantAmount("GrantCoins", pages.Rewards.Coins.Amount.Value, limits.coinsPerGrant) end)
connect(pages.Rewards.Levels.AddLevels.Activated, function() grantAmount("AddLevels", pages.Rewards.Levels.Amount.Value, limits.levelsPerGrant) end)
connect(hub.Target.Previous.Activated, function() cycleTarget(-1) end)
connect(hub.Target.Next.Activated, function() cycleTarget(1) end)
connect(hub.Target.Self.Activated, function() selectTarget(player.UserId) end)
for _, button in ipairs(hub.Tabs:GetChildren()) do
	if button:IsA("TextButton") then connect(button.Activated, function() tab = button.Name syncVisibility() end) end
end
for _, name in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic" }) do
	local control = pages.Rounds:FindFirstChild(name, true)
	gameControls[name] = control
	connect(control.Activated, function() if control.Active then request(name) end end)
end
local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end
connect(gui.Toggle.Activated, toggle)
connect(hub.Close.Activated, function() opened = false syncVisibility() end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F6 then toggle() end
end)
connect(player:GetAttributeChangedSignal("PlaygroundAdmin"), sync)
connect(Players.PlayerAdded, function() refreshLocalRoster() syncTarget() end)
connect(Players.PlayerRemoving, function(leaving)
	for index = #roster, 1, -1 do if roster[index].userId == leaving.UserId then table.remove(roster, index) end end
	if leaving.UserId == selectedUserId then selectedUserId = player.UserId targetData = nil message("Player left. Rewards now target you.") end
	sync()
	if opened and not busy then request("GetStatus", nil, true) end
end)
local function bindState(object)
	if not ({ PlaygroundState = true, BritishBulldogState = true, TagState = true, MudState = true })[object.Name] or states[object.Name] == object then return end
	states[object.Name] = object
	connect(object.AttributeChanged, syncRounds)
	syncRounds()
end
for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState" }) do
	local object = ReplicatedStorage:FindFirstChild(name)
	if object then bindState(object) end
end
connect(ReplicatedStorage.ChildAdded, bindState)
connect(script.Destroying, function() for _, connection in ipairs(connections) do connection:Disconnect() end end)
refreshLocalRoster()
sync()
]====]
config:SetAttribute("ExtraAdminUserIds","")
gui:SetAttribute("OwnerUserId",1201803949)
gui.Enabled=false
for _,name in ipairs({"Toggle","AdminHub","Panel","CompactPanel","CompactToggle"}) do gui[name].Visible=false end
return {server=server:GetFullName(),owner=config:GetAttribute("AdminUserId"),enabled=gui.Enabled,backup=backup:GetFullName()}
