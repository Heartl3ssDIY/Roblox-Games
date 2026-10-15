return function(source)
	assert(not game:GetService("RunService"):IsRunning(), "Edit checks only")
	local catalog = require(game.ReplicatedStorage.PlaygroundCatalog)
	local folder = Instance.new("Folder")
	folder.Name = "AdminUIBindingChecks"
	folder.Parent = game.ServerStorage
	local gui = game.StarterGui.PlaygroundAdminPanel:Clone()
	gui.Parent = folder
	local module = Instance.new("ModuleScript")
	module.Name = "InstrumentedController"
	source = source or game.StarterGui.PlaygroundAdminPanel.Controller.Source
	source = source:gsub("local connection = signal:Connect%(callback%)", "local connection = test.connect(signal, callback)")
	source = source:gsub("connect%(([^%s%(%)%,]+)%.Activated,", "connect(%1,")
	source = source:gsub('connect%(itemsPage.Search.Value:GetPropertyChangedSignal%("Text"%),', 'connect(itemsPage.Search.Value,')
	module.Source = "return function(test)\nlocal game=test.game\nlocal script=test.script\nlocal task=test.task\n" .. source .. "\nend"
	module.Parent = folder
	local links, callbacks, queue, calls, passed = {}, {}, {}, {}, {}
	local function signal()
		local event = Instance.new("BindableEvent")
		event.Parent = folder
		return event.Event
	end
	local function fakePlayer(id, name)
		local value = { UserId = id, Name = name, DisplayName = name, attrs = { PlaygroundAdmin = id == 101, PCDataReady = true }, signals = {} }
		function value:GetAttribute(key) return self.attrs[key] end
		function value:GetAttributeChangedSignal(key) self.signals[key] = self.signals[key] or signal() return self.signals[key] end
		return value
	end
	local actor, other = fakePlayer(101, "TestAdmin"), fakePlayer(202, "TestRecipient")
	local players = { LocalPlayer = actor, PlayerAdded = signal(), PlayerRemoving = signal(), list = { actor, other } }
	function players:GetPlayers() return self.list end
	local profiles = {}
	for _, player in ipairs(players.list) do profiles[player.UserId] = { userId = player.UserId, name = player.Name, displayName = player.DisplayName, ready = true, coins = 100, level = 1, owned = {}, equipped = {}, batPreview = false } end
	local remote = {}
	function remote:IsA(class) return class == "RemoteFunction" end
	function remote:InvokeServer(action, payload)
		table.insert(calls, { action = action, payload = table.clone(payload) })
		local profile = profiles[payload.targetUserId]
		if action == "GrantItem" then
			profile.owned[payload.itemId] = true
			if payload.equip then local item = catalog.ById[payload.itemId] profile.equipped[item.slot] = item.id if item.slot == "Bat" then profile.batPreview = true end end
		elseif action == "GrantCoins" then profile.coins += payload.amount
		elseif action == "AddLevels" then profile.level += payload.amount
		elseif action == "ClearPreview" then profile.batPreview = false end
		return { ok = true, message = "Test reply", players = { { userId = 101, name = actor.Name }, { userId = 202, name = other.Name } }, targetUserId = payload.targetUserId, target = profile }
	end
	local states = {}
	for _, name in ipairs({ "PlaygroundState", "BritishBulldogState", "TagState", "MudState" }) do
		local state = { Name = name, AttributeChanged = signal() }
		function state:GetAttribute(key) return ({ GunAccessReady = true, Phase = "Waiting", Mode = "", AutomaticRounds = true })[key] end
		states[name] = state
	end
	local storage = { ChildAdded = signal() }
	function storage:WaitForChild(name) return name == "PlaygroundCatalog" and game.ReplicatedStorage.PlaygroundCatalog or self:FindFirstChild(name) end
	function storage:FindFirstChild(name) return name == "PlaygroundAdminRequest" and remote or states[name] end
	local input = { InputBegan = signal() }
	function input:GetFocusedTextBox() return nil end
	local fakeGame = {}
	function fakeGame:GetService(name) return ({ Players = players, ReplicatedStorage = storage, UserInputService = input })[name] end
	local fakeTask = {}
	function fakeTask.spawn(callback, ...) table.insert(queue, { callback, table.pack(...) }) end
	fakeTask.defer = fakeTask.spawn
	local function flush()
		local iterations = 0
		while #queue > 0 do
			iterations += 1 assert(iterations < 30, "unexpected request loop")
			local job = table.remove(queue, 1)
			job[1](table.unpack(job[2], 1, job[2].n))
		end
	end
	local function check(name, value) assert(value, name) table.insert(passed, name) end
	local function activate(button)
		assert(callbacks[button], "Unbound button " .. button:GetFullName())
		callbacks[button]()
	end
	local ok, result = xpcall(function()
		require(module)({ game = fakeGame, task = fakeTask, script = { Parent = gui, Destroying = signal() }, connect = function(event, callback)
			callbacks[event] = callback
			local nativeSignal = typeof(event) == "Instance" and (event:IsA("GuiButton") and event.Activated or event:GetPropertyChangedSignal("Text")) or event
			local connection = nativeSignal:Connect(callback)
			table.insert(links, connection)
			return connection
		end })
		local hub, itemPage = gui.AdminHub, gui.AdminHub.Pages.Items
		activate(gui.Toggle) flush()
		check("opening defaults explicitly to self", calls[#calls].payload.targetUserId == actor.UserId and hub.Target.PlayerName.Text:find("SELF", 1, true) ~= nil)
		activate(hub.Target.Next) flush()
		check("recipient can select another player", calls[#calls].payload.targetUserId == other.UserId and hub.Target.PlayerName.Text:find(other.Name, 1, true) ~= nil)
		itemPage.Search.Value.Text = "mudslinger"
		callbacks[itemPage.Search.Value]()
		check("search binds actual catalog id", itemPage.Rows.Slot01:GetAttribute("CatalogId") == "B06" and not itemPage.Rows.Slot02.Visible)
		activate(itemPage.Rows.Slot01.GrantEquip)
		local before = #calls
		activate(itemPage.Rows.Slot01.GrantEquip)
		flush()
		check("overlapping item requests are blocked", #calls == before + 1)
		check("grant equip sends explicit recipient and item", calls[#calls].action == "GrantItem" and calls[#calls].payload.targetUserId == 202 and calls[#calls].payload.itemId == "B06" and calls[#calls].payload.equip == true)
		check("equipped item and preview update UI", profiles[202].equipped.Bat == "B06" and itemPage.Rows.Slot01.GrantEquip.Text == "EQUIPPED" and itemPage.Filters.ClearPreview.Active)
		activate(itemPage.Filters.ClearPreview) flush()
		check("hide preview routes correctly", calls[#calls].action == "ClearPreview" and not profiles[202].batPreview and itemPage.Rows.Slot01.GrantEquip.Text == "SHOW BAT")
		itemPage.Search.Value.Text = ""
		callbacks[itemPage.Search.Value]()
		activate(itemPage.Filters.Pets)
		check("pet filter binds first pet", itemPage.Rows.Slot01:GetAttribute("CatalogId") == "P01")
		activate(itemPage.Pager.Next)
		check("pet pagination binds next eight", itemPage.Rows.Slot01:GetAttribute("CatalogId") == "P09")
		activate(itemPage.Filters.All)
		local seen = {}
		for _ = 1, 7 do
			for _, row in ipairs(itemPage.Rows:GetChildren()) do if row:IsA("Frame") and row.Visible then seen[row:GetAttribute("CatalogId")] = true end end
			activate(itemPage.Pager.Next)
		end
		local count = 0 for _ in pairs(seen) do count += 1 end
		check("every catalog item reachable through pagination", count == 50)
		activate(hub.Target.Self) flush()
		hub.Pages.Rewards.Coins.Amount.Value.Text = "250"
		activate(hub.Pages.Rewards.Coins.GrantCoins) flush()
		check("coin grant routes entered amount to self", calls[#calls].action == "GrantCoins" and calls[#calls].payload.targetUserId == 101 and calls[#calls].payload.amount == 250 and profiles[101].coins == 350)
		activate(hub.Target.Next) flush()
		hub.Pages.Rewards.Levels.Amount.Value.Text = "5"
		activate(hub.Pages.Rewards.Levels.AddLevels) flush()
		check("level increment routes to selected other player", calls[#calls].action == "AddLevels" and calls[#calls].payload.targetUserId == 202 and calls[#calls].payload.amount == 5 and profiles[202].level == 6)
		before = #calls
		hub.Pages.Rewards.Levels.Amount.Value.Text = "-2"
		activate(hub.Pages.Rewards.Levels.AddLevels) flush()
		check("invalid amount never reaches server", #calls == before)
		for _, action in ipairs({ "BBStart", "BBRunner", "BBBulldog", "TagStart", "TagRunner", "TagTagger", "MudStart", "MudShooter", "MudMedic", "StopRound", "ToggleAutomatic" }) do
			activate(hub.Pages.Rounds:FindFirstChild(action, true)) flush()
			check("round control preserved: " .. action, calls[#calls].action == action)
		end
		actor.attrs.PlaygroundAdmin = false
		callbacks[actor:GetAttributeChangedSignal("PlaygroundAdmin")]()
		before = #calls
		activate(gui.Toggle) flush()
		check("removed admin permission hides controls and blocks requests", not gui.Enabled and #calls == before)
		return { passed = #passed, checks = passed, catalogItems = count, realGrants = 0, playStarted = false, networkCalls = 0 }
	end, debug.traceback)
	for _, connection in ipairs(links) do connection:Disconnect() end
	folder:Destroy()
	assert(ok, result)
	return result
end
