from pathlib import Path

root = Path(__file__).resolve().parent
out = root / 'After'
out.mkdir(exist_ok=True)

def replace(source, old, new):
    assert source.count(old) == 1, (old[:90], source.count(old))
    return source.replace(old, new, 1)

s = (root / 'Before/PlaygroundEconomyService.luau').read_text(encoding='utf-8-sig')
s = replace(s, 'local function cleanToyLoadout', '''local function emoteDetails(data)
	if typeof(data) ~= "table" or typeof(data.Equipped) ~= "table" or typeof(data.Owned) ~= "table" then return nil end
	local id = data.Equipped.Emote
	local item = id and Catalog.ById[id]
	local animation = item and Catalog.EmoteAnimations[id]
	local animationId = animation and animation.R15AnimationId
	if not item or item.slot ~= "Emote" or item.available == false or item.playable ~= true
		or not data.Owned or data.Owned[id] ~= true or not boundedInteger(animationId, 1, 9007199254740991) then return nil end
	return { emoteId = id, emoteAnimationId = "rbxassetid://" .. string.format("%.0f", animationId), emoteRigType = "R15" }
end

local function stopEmote(player)
	player:SetAttribute("PCEmoteUntil", 0)
	player:SetAttribute("PCEmoteAction", "")
	player:SetAttribute("PCEmoteAnimationId", "")
end

local function cleanToyLoadout''')
s = replace(s, '\tself.awarded = {}', '\tself.awarded = {}\n\tself.podiumEmotes = {}\n\tself.podiumEmoteReads = 0')
s = replace(s, '\tfor index = 1, maxToySlots do player:SetAttribute', '''	local emote = profile.ready and emoteDetails(profile.data)
	player:SetAttribute("PCEquippedEmoteAnimationId", emote and emote.emoteAnimationId or "")
	player:SetAttribute("PCEquippedEmoteRigType", emote and emote.emoteRigType or "")
	for index = 1, maxToySlots do player:SetAttribute''')
s = replace(s, '\t\ttask.spawn(function()\n\t\t\tcharacter:WaitForChild("HumanoidRootPart", 10)', '\t\tstopEmote(player)\n\t\ttask.spawn(function()\n\t\t\tcharacter:WaitForChild("HumanoidRootPart", 10)')
s = replace(s, '\tself:_sync(profile)\n\ttable.insert(profile.connections, player.CharacterAdded', '''	self:_sync(profile)
	for _, attribute in ipairs({ "BBParticipating", "TGParticipating", "MDParticipating" }) do
		table.insert(profile.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if inGame(player) then stopEmote(player) end
		end))
	end
	table.insert(profile.connections, player.CharacterAdded''')
s = replace(s, '\t\tprofile.data.Equipped[id] = nil', '\t\tif id == "Emote" then stopEmote(player) end\n\t\tprofile.data.Equipped[id] = nil')
s = replace(s, '\tif action == "Buy" then', '\tif item.slot == "Emote" and (item.playable ~= true or not Catalog.EmoteAnimations[id]) then return self:Status(player, false, "This emote is not available to play.") end\n\tif action == "Buy" then')
s = replace(s, '\tif action == "Equip" then', '\tif action == "Equip" then\n\t\tif item.slot == "Emote" then stopEmote(player) end')
s = replace(s, '''		profile.lastExpression = now
		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteUntil", workspace:GetServerTimeNow() + 2.4)
			local response = self:Status(player, true)
			return response
		end''', '''		if action == "UseEmote" then
			if item.slot ~= "Emote" then return self:Status(player, false, "Choose an emote.") end
			local character = player.Character
			if character and ((character:GetAttribute("PCToyHeld") or "") ~= "" or character:GetAttribute("PCBatHeld") == true) then
				return self:Status(player, false, "Put your toy away to dance.")
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then return self:Status(player, false, "Your character is not ready.") end
			if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return self:Status(player, false, "These dances need an R15 avatar.") end
			if not self:_inside(rootPart.Position) then return self:Status(player, false, "Dance in the lobby between rounds.") end
			if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit or humanoid.FloorMaterial == Enum.Material.Air then
				return self:Status(player, false, "Stand still on the ground to dance.")
			end
			local animation = Catalog.EmoteAnimations[id]
			if not animation or not boundedInteger(animation.R15AnimationId, 1, 9007199254740991) then return self:Status(player, false, "This emote is unavailable.") end
			local startedAt = workspace:GetServerTimeNow()
			profile.lastExpression = now
			player:SetAttribute("PCEmoteAction", id)
			player:SetAttribute("PCEmoteAnimationId", "rbxassetid://" .. string.format("%.0f", animation.R15AnimationId))
			player:SetAttribute("PCEmoteRigType", "R15")
			player:SetAttribute("PCEmoteStartedAt", startedAt)
			player:SetAttribute("PCEmoteUntil", startedAt + 30)
			player:SetAttribute("PCEmoteSerial", integer(player:GetAttribute("PCEmoteSerial"), 0) + 1)
			return self:Status(player, true, "Move or jump to stop dancing.")
		end
		profile.lastExpression = now''')
s = replace(s, 'function Economy:_profileByUserId(id)', '''function Economy:GetPodiumEmote(userId)
	if not boundedInteger(userId, 1, 1000000000000) then return nil end
	local profile = self:_profileByUserId(userId)
	if profile then
		return profile.ready and not profile.closed and not profile.released and emoteDetails(profile.data) or nil
	end
	local cached = self.podiumEmotes[userId]
	local now = os.clock()
	if cached and (cached.busy or cached.expires > now) then return cached.value end
	if self.isStudio or not self.store or self.podiumEmoteReads >= 2 then return cached and cached.value end
	local record = cached or {}
	record.busy = true
	self.podiumEmotes[userId] = record
	self.podiumEmoteReads += 1
	task.spawn(function()
		local ok, data = pcall(function() return self.store:GetAsync("u:" .. userId) end)
		self.podiumEmoteReads -= 1
		record.busy = false
		record.expires = os.clock() + (ok and 120 or 30)
		if ok then record.value = emoteDetails(data) end
	end)
	return record.value
end

function Economy:_profileByUserId(id)''')
(out / 'PlaygroundEconomyService.luau').write_text(s, encoding='utf-8')

s = (root / 'Before/PlaygroundLeaderboardService.luau').read_text(encoding='utf-8-sig')
s = replace(s, 'resolveRegion = dependencies.resolveRegion }', 'resolveRegion = dependencies.resolveRegion, resolveEmote = dependencies.resolveEmote }')
s = replace(s, '''	for _, entry in ipairs(entries) do
		local cached = self.identities[entry.userId]
		table.insert(result, { userId = entry.userId, name = entry.name or (cached and cached.name) or "Player " .. entry.userId, image = cached and cached.image or entry.image or "", value = stat == "XP" and "LV " .. self:_level(entry.value) or tostring(entry.value) })
	end''', '''	for index, entry in ipairs(entries) do
		local cached = self.identities[entry.userId]
		local display = { userId = entry.userId, name = entry.name or (cached and cached.name) or "Player " .. entry.userId, image = cached and cached.image or entry.image or "", value = stat == "XP" and "LV " .. self:_level(entry.value) or tostring(entry.value) }
		if index <= 3 and typeof(self.resolveEmote) == "function" then
			local ok, emote = pcall(self.resolveEmote, entry.userId)
			if ok and typeof(emote) == "table" then
				display.emoteId, display.emoteAnimationId, display.emoteRigType = emote.emoteId, emote.emoteAnimationId, emote.emoteRigType
			end
		end
		table.insert(result, display)
	end''')
(out / 'PlaygroundLeaderboardService.luau').write_text(s, encoding='utf-8')

s = (root / 'Before/PlaygroundBootstrap.luau').read_text(encoding='utf-8-sig')
s = replace(s, 'return Leaderboards.new(lobby, {', 'return Leaderboards.new(lobby, {\n\t\t\tresolveEmote = function(userId) return economy:GetPodiumEmote(userId) end,')
(out / 'PlaygroundBootstrap.luau').write_text(s, encoding='utf-8')
print('Created economy, leaderboard and bootstrap candidates.')
