return function(Economy, Catalog)
	local checks = 0
	local function check(value, message) assert(value, message) checks += 1 end
	local count, coins, levels, maximum = 0, 0, 0, 0
	for _, item in ipairs(Catalog.Items) do
		if item.slot == "Emote" then
			count += 1
			check(item.available and item.playable and Catalog.EmoteAnimations[item.id].R15AnimationId ~= item.catalogId, item.id .. " must use its resolved animation")
			if item.unlock.kind == "Coins" then coins += 1 maximum = math.max(maximum, item.price) else levels += 1 end
		else check(item.price <= 10000, "Equipment price changed") end
	end
	check(count == 31 and coins == 20 and levels == 11 and maximum == 15000, "Incorrect emote balance")
	check(Catalog.ById.E07 == nil, "Disabled Take The L must be omitted")
	local attrs, writes, characterAttrs = {}, {}, {}
	local humanoid = { Health = 100, RigType = Enum.HumanoidRigType.R15, MoveDirection = Vector3.zero, Sit = false, FloorMaterial = Enum.Material.Grass }
	local root = { Position = Vector3.zero }
	local character = {
		FindFirstChildOfClass = function(_, class) return class == "Humanoid" and humanoid end,
		FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root end,
		GetAttribute = function(_, key) return characterAttrs[key] end,
	}
	local player = {
		Character = character,
		GetAttribute = function(_, key) return attrs[key] end,
		SetAttribute = function(_, key, value) attrs[key] = value table.insert(writes, key) end,
	}
	local profile = { ready = true, data = Economy.CleanData(nil), lastMutation = -math.huge, lastStatus = -math.huge, lastExpression = -math.huge }
	local inside = true
	local service = setmetatable({ profiles = { [player] = profile }, podiumEmotes = {}, podiumEmoteReads = 0, isStudio = true }, { __index = Economy })
	function service:Status(_, ok, message) return { ok = ok, message = message } end
	function service:_inside(_) return inside end
	function service:_touch(_) end
	function service:_applyAppearance(_) end
	function service:LevelProgress(_) return 1 end
	local function request(action, id)
		profile.lastMutation, profile.lastExpression = -math.huge, -math.huge
		return service:Handle(player, action, id)
	end
	check(not request("UseEmote", "E01").ok, "Unowned emote accepted")
	profile.data.Coins = 14999
	check(not request("Buy", "E31").ok and profile.data.Coins == 14999, "Insufficient balance spent")
	profile.data.Coins = 15000
	check(request("Buy", "E31").ok and profile.data.Coins == 0 and profile.data.Owned.E31, "15000 coin purchase failed")
	check(not request("Buy", "E31").ok, "Duplicate charged")
	check(not request("Buy", "E04").ok and not profile.data.Owned.E04, "Level reward purchasable")
	check(not request("Buy", "E07").ok, "Disabled emote purchasable")
	profile.data.Owned.E01 = true
	check(request("UseEmote", "E01").ok, "Owned emote rejected")
	check(attrs.PCEmoteAction == "E01" and attrs.PCEmoteAnimationId == "rbxassetid://" .. string.format("%.0f", Catalog.EmoteAnimations.E01.R15AnimationId), "Wrong animation attribute")
	check(attrs.PCEmoteUntil - attrs.PCEmoteStartedAt == 30 and attrs.PCEmoteRigType == "R15", "Wrong duration/rig")
	check(writes[#writes] == "PCEmoteSerial" and attrs.PCEmoteSerial == 1, "Commit must be serial-last")
	for _, mode in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		attrs[mode] = true check(not request("UseEmote", "E01").ok, "Round emote accepted: " .. mode) attrs[mode] = false
	end
	humanoid.RigType = Enum.HumanoidRigType.R6 check(not request("UseEmote", "E01").ok, "R6 accepted") humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.Health = 0 check(not request("UseEmote", "E01").ok, "Dead character accepted") humanoid.Health = 100
	humanoid.MoveDirection = Vector3.xAxis check(not request("UseEmote", "E01").ok, "Moving character accepted") humanoid.MoveDirection = Vector3.zero
	humanoid.FloorMaterial = Enum.Material.Air check(not request("UseEmote", "E01").ok, "Airborne character accepted") humanoid.FloorMaterial = Enum.Material.Grass
	humanoid.Sit = true check(not request("UseEmote", "E01").ok, "Seated character accepted") humanoid.Sit = false
	inside = false check(not request("UseEmote", "E01").ok, "Outside lobby accepted") inside = true
	characterAttrs.PCToyHeld = "M01" check(not request("UseEmote", "E01").ok, "Held toy accepted") characterAttrs.PCToyHeld = nil
	characterAttrs.PCBatHeld = true check(not request("UseEmote", "E01").ok, "Held bat accepted") characterAttrs.PCBatHeld = nil
	profile.ready = false check(not request("UseEmote", "E01").ok, "Unloaded profile accepted") profile.ready = true
	request("UseEmote", "E01")
	profile.lastMutation = -math.huge
	check(not service:Handle(player, "UseEmote", "E01").ok, "Expression cooldown ignored")
	check(request("Unequip", "Emote").ok and attrs.PCEmoteUntil == 0 and attrs.PCEmoteAction == "", "Unequip did not stop")
	local levelData = Economy.CleanData(nil)
	check(not Economy.EvaluateUnlock(levelData, Catalog.ById.E04, 4).unlocked, "Level reward early")
	check(Economy.EvaluateUnlock(levelData, Catalog.ById.E04, 5).unlocked, "Level reward missing")
	function service:_profileByUserId(id) return id == 12 and profile end
	profile.data.Equipped.Emote = "E01"
	check(service:GetPodiumEmote(12).emoteId == "E01", "Online equipped emote missing")
	profile.data.Owned.E01 = nil
	check(service:GetPodiumEmote(12) == nil, "Unowned podium emote exposed")
	profile.data.Owned.E01 = true
	check(service:GetPodiumEmote(99) == nil, "Studio offline datastore requested")
	check(service:GetPodiumEmote(0/0) == nil, "Invalid user ID accepted")
	service.isStudio = false
	local reads = 0
	service.store = { GetAsync = function(_, key) reads += 1 check(key == "u:99", "Wrong saved profile key") return { Owned = { E01 = true }, Equipped = { Emote = "E01" } } end }
	service:GetPodiumEmote(99)
	task.wait()
	check(service:GetPodiumEmote(99).emoteId == "E01" and reads == 1, "Saved podium emote/caching failed")
	check(service.podiumEmoteReads == 0, "Read slot leaked")
	for _, bad in ipairs({ { Equipped = true, Owned = {} }, { Equipped = {}, Owned = true }, false, {} }) do
		service.podiumEmotes[99] = nil
		service.store.GetAsync = function() return bad end
		service:GetPodiumEmote(99)
		task.wait()
		check(service:GetPodiumEmote(99) == nil and service.podiumEmoteReads == 0, "Corrupt profile broke podium lookup")
	end
	return { passed = checks, emotes = count, coinPurchases = coins, levelRewards = levels, maxPrice = maximum }
end
