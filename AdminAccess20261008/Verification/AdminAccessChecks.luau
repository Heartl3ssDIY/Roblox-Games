local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
assert(not game:GetService("RunService"):IsRunning(), "Checks must run in edit mode")
local template = ServerScriptService:FindFirstChild("PlaygroundAdminService")
local gui = StarterGui:FindFirstChild("PlaygroundAdminPanel")
local controller = gui and gui:FindFirstChild("Controller")
local liveConfig = ServerStorage:FindFirstChild("PlaygroundAdminConfig")
assert(template and controller and liveConfig, "Installed admin instances are missing")
local beforeOwner = liveConfig:GetAttribute("AdminUserId")
local beforeExtra = liveConfig:GetAttribute("ExtraAdminUserIds")
local clones = {}
local function temporary(name, source)
	assert(not ServerStorage:FindFirstChild(name), "Fixture name is already occupied")
	local clone = template:Clone()
	table.insert(clones, clone)
	clone.Name = name
	if source then clone.Source = source end
	clone.Parent = ServerStorage
	return clone
end
local ok, result = xpcall(function()
	local Admin = require(temporary("_AdminAccessAuthChecks20261008"))
	local checks = {}
	local function check(name, condition)
		assert(condition, name)
		table.insert(checks, name)
	end
	local function actor(id, name)
		local current = { UserId = id, Name = name, DisplayName = name, attributes = { PCDataReady = true, BBRole = "Runner", PlaygroundAdmin = false } }
		function current:GetAttribute(key) return self.attributes[key] end
		return current
	end
	local owner = actor(1201803949, "SandboxxYY")
	local newAdmin = actor(157349477, "AntoineGold3")
	local unrelated = actor(987654321, "Unrelated")
	local target = actor(765432109, "Target")
	local roster = { owner, newAdmin, unrelated, target }
	local playerSource = {}
	function playerSource:GetPlayers() return roster end
	function playerSource:GetPlayerByUserId(id)
		for _, current in ipairs(roster) do if current.UserId == id then return current end end
	end
	local values = { AdminUserId = 1201803949, ExtraAdminUserIds = "157349477" }
	local config = {}
	function config:GetAttribute(key) return values[key] end
	local calls = {}
	local function called(kind, fields)
		fields = fields or {}
		fields.kind = kind
		table.insert(calls, fields)
		return true, "Mock action accepted"
	end
	local economy = { AdminLimits = { coinsPerGrant = 1000000, levelsPerGrant = 100, maxLevel = 1000 } }
	function economy:Status(current) return { ready = true, coins = 0, level = 1, entitlements = {}, owned = {}, equipped = {} } end
	function economy:AdminGrantItem(current, itemId, equip) return called("GrantItem", { target = current, itemId = itemId, equip = equip }) end
	function economy:AdminGrantCoins(current, amount) return called("GrantCoins", { target = current, amount = amount }) end
	function economy:AdminAddLevels(current, amount) return called("AddLevels", { target = current, amount = amount }) end
	function economy:AdminGrantEntitlement(current, kind) return called(kind == "VIP" and "GrantVIP" or "GrantBetaTester", { target = current, entitlement = kind }) end
	local coordinator = { services = {}, economy = economy, autoEnabled = false }
	function coordinator:ActiveGame() return nil end
	function coordinator:StartGame(gameId, current, role, automatic) return called("StartGame", { gameId = gameId, actor = current, role = role, automatic = automatic }) end
	function coordinator:StopGame() return called("StopRound") end
	function coordinator:SetAutoEnabled(value) self.autoEnabled = value called("ToggleAutomatic", { automatic = value }) end
	local admin = Admin.new(coordinator, config, false, playerSource)
	check("owner_authorized", admin:IsAuthorized(owner))
	check("antoine_authorized", admin:IsAuthorized(newAdmin))
	check("unrelated_denied", not admin:IsAuthorized(unrelated))
	check("no_blanket_studio_authorization", not Admin.new(coordinator, config, true, playerSource):IsAuthorized(unrelated))
	check("nil_actor_denied", not admin:IsAuthorized(nil))
	for _, invalid in ipairs({ { label = "nil", actor = {} }, { label = "string", actor = { UserId = "157349477" } }, { label = "zero", actor = { UserId = 0 } }, { label = "negative", actor = { UserId = -157349477 } }, { label = "fractional", actor = { UserId = 157349477.5 } }, { label = "nan", actor = { UserId = 0 / 0 } }, { label = "infinite", actor = { UserId = math.huge } } }) do
		check("invalid_actor_id_" .. invalid.label .. "_denied", not admin:IsAuthorized(invalid.actor))
	end
	values.ExtraAdminUserIds = nil
	check("nil_extra_ids_denied", not admin:IsAuthorized(newAdmin))
	for _, invalid in ipairs({ 157349477, {}, "", "AntoineGold3", "157349477suffix", "prefix157349477", "0", "-157349477", "157349477.5", "1.57349477e8", "nan", "inf" }) do
		values.ExtraAdminUserIds = invalid
		check("malformed_extra_ids_denied_" .. tostring(#checks + 1), not admin:IsAuthorized(newAdmin))
	end
	values.ExtraAdminUserIds = " 157349477 , 555555555 "
	check("whitespace_csv_admin_allowed", admin:IsAuthorized(newAdmin))
	values.ExtraAdminUserIds = "157349477, malformed"
	check("valid_entry_survives_unrelated_malformed_csv_token", admin:IsAuthorized(newAdmin))
	values.ExtraAdminUserIds = "157349477"
	unrelated.attributes.PlaygroundAdmin = true
	unrelated.attributes.OwnerUserId = owner.UserId
	check("forged_client_admin_attributes_do_not_authorize", not admin:IsAuthorized(unrelated))
	check("authorized_user_does_not_depend_on_client_attribute", admin:IsAuthorized(newAdmin))
	local grantPayload = { targetUserId = target.UserId, amount = 25, itemId = "FixtureItem", equip = true }
	local actions = { "GrantItem", "GrantCoins", "AddLevels", "GrantVIP", "GrantBetaTester", "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic", "StartRound", "PracticeRunner", "PracticeBulldog" }
	for _, action in ipairs(actions) do
		local count = #calls
		local payload = table.clone(grantPayload)
		payload.AdminUserId = owner.UserId
		payload.actor = owner
		local reply = admin:Handle(unrelated, action, payload)
		check("unrelated_" .. action .. "_denied_before_dispatch", reply.ok == false and #calls == count)
	end
	for _, action in ipairs(actions) do
		admin.lastRequest[newAdmin] = nil
		local count = #calls
		local reply = admin:Handle(newAdmin, action, table.clone(grantPayload))
		check("antoine_" .. action .. "_dispatched", reply.ok == true and #calls == count + 1)
		local call = calls[#calls]
		if action == "GrantItem" or action == "GrantCoins" or action == "AddLevels" or action == "GrantVIP" or action == "GrantBetaTester" then
			check("antoine_" .. action .. "_uses_explicit_target", call.kind == action and call.target == target)
		elseif call.kind == "StartGame" then
			check("antoine_" .. action .. "_uses_authenticated_actor", call.actor == newAdmin and call.automatic == false)
		end
	end
	local gate = controller.Source:match("(local function admin%(%).-\nend)")
	assert(gate, "Current client admin gate was not found")
	check("client_gate_has_no_owner_id_restriction", not string.find(gate, "OwnerUserId", 1, true))
	local gateSource = "return function(player, gui)\n" .. gate .. "\nreturn admin()\nend"
	local clientAllowed = require(temporary("_AdminAccessClientGateChecks20261008", gateSource))
	local mockGui = { GetAttribute = function(_, key) return key == "OwnerUserId" and owner.UserId or nil end }
	owner.attributes.PlaygroundAdmin = true
	newAdmin.attributes.PlaygroundAdmin = true
	check("owner_client_gate_allowed", clientAllowed(owner, mockGui))
	check("antoine_client_gate_allowed_despite_different_owner_id", clientAllowed(newAdmin, mockGui))
	newAdmin.attributes.PlaygroundAdmin = false
	check("false_attribute_hides_client_ui", not clientAllowed(newAdmin, mockGui))
	newAdmin.attributes.PlaygroundAdmin = nil
	check("missing_attribute_hides_client_ui", not clientAllowed(newAdmin, mockGui))
	admin:Destroy()
	check("live_owner_config_preserved", liveConfig:GetAttribute("AdminUserId") == beforeOwner and beforeOwner == 1201803949)
	check("live_extra_config_preserved", liveConfig:GetAttribute("ExtraAdminUserIds") == beforeExtra and beforeExtra == "157349477")
	return { passed = #checks, checks = checks, authorizedIds = { owner.UserId, newAdmin.UserId }, mockDispatches = #calls, realProfilesChanged = false, playStarted = false }
end, debug.traceback)
for _, clone in ipairs(clones) do clone:Destroy() end
assert(ok, result)
assert(not ServerStorage:FindFirstChild("_AdminAccessAuthChecks20261008") and not ServerStorage:FindFirstChild("_AdminAccessClientGateChecks20261008"), "Temporary fixture cleanup failed")
result.temporaryFixturesCleaned = true
return result

