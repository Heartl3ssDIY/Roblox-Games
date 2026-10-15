from pathlib import Path

root=Path(__file__).parent
src=(root/'Before/PlaygroundEconomyService.luau').read_text(encoding='utf-8')
def replace(old,new):
    global src
    assert src.count(old)==1, (old[:120],src.count(old))
    src=src.replace(old,new)

replace('local actions = { GetStatus = true,', 'local actions = { RedeemCode = true, GetStatus = true,')
replace('CoinPurchases = {}, Version = 5','CoinPurchases = {}, Entitlements = {}, RedeemedCodes = {}, Version = 6')
replace('\tresult.SecretObbyClaimDay =', '''	local entitlements = typeof(value.Entitlements) == "table" and value.Entitlements or {}
	result.Entitlements.VIP = entitlements.VIP == true
	result.Entitlements.BetaTester = entitlements.BetaTester == true
	if typeof(value.RedeemedCodes) == "table" then
		for code, redeemedAt in pairs(value.RedeemedCodes) do
			if typeof(code) == "string" and #code > 0 and #code <= 32 and code:match("^[A-Z0-9_%-]+$") and timestamp(redeemedAt) > 0 then
				result.RedeemedCodes[code] = timestamp(redeemedAt)
			end
		end
	end
	result.SecretObbyClaimDay =''')
replace('local function unlockStatus(data, item, level)', 'local function unlockStatus(data, item, level, entitlements)')
replace('\telseif kind == "Level" then','''	elseif kind == "VIP" or kind == "BetaTester" then
		local granted = entitlements or data.Entitlements or {}
		unlocked, label = granted[kind] == true, kind == "VIP" and "VIP reward" or "Beta Tester reward"
	elseif kind == "Level" then''')
replace('unlockStatus(profile.data, item, level).unlocked','unlockStatus(profile.data, item, level, self:_entitlements(profile.player)).unlocked')
replace('\tself.passBenefits = {}','\tself.passBenefits = {}\n\tself.redemptionCodes = require(script.Parent:WaitForChild("PlaygroundRedemptionCodes"))')
replace('\t\tprofile.savedPurchases = table.clone(profile.data.CoinPurchases)','\t\tprofile.savedPurchases = table.clone(profile.data.CoinPurchases)\n\t\tprofile.savedEntitlements = table.clone(profile.data.Entitlements)\n\t\tprofile.savedCodes = table.clone(profile.data.RedeemedCodes)')
replace('\t\tprofile.savedPurchases = snapshot.CoinPurchases','\t\tprofile.savedPurchases = snapshot.CoinPurchases\n\t\tprofile.savedEntitlements = snapshot.Entitlements\n\t\tprofile.savedCodes = snapshot.RedeemedCodes')
replace('local status = unlockStatus(data, item, level)','local status = unlockStatus(data, item, level, self:_entitlements(player))')
replace('\t\towned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,','\t\towned = table.clone(data.Owned), equipped = equipped, toyLoadout = loadout, ready = ready,\n\t\tentitlements = self:_entitlements(player),')
replace('\tif action == "StopEmote" then','''	if action == "RedeemCode" then
		local redeemed, message = self:RedeemCode(player, id)
		return self:Status(player, redeemed, message)
	end
	if action == "StopEmote" then''')
replace('unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP))','unlockStatus(profile.data, item, self:LevelProgress(profile.data.XP), self:_entitlements(player))')
replace('function Economy:_syncPassBenefits(player)', '''function Economy:_entitlements(player)
	local profile = self.profiles[player]
	local manual = profile and profile.ready and not profile.closed and not profile.released and profile.data.Entitlements or {}
	local passes = self.passBenefits[player] or {}
	return { VIP = passes.vip == true or manual.VIP == true, BetaTester = manual.BetaTester == true }
end

function Economy:_syncPassBenefits(player)''')
replace('\tplayer:SetAttribute("PCVIP", benefits.vip == true)','\tlocal entitlements = self:_entitlements(player)\n\tplayer:SetAttribute("PCVIP", entitlements.VIP)\n\tplayer:SetAttribute("PCBetaTester", entitlements.BetaTester)')
replace('(benefits.vip and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", now)', '(entitlements.VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", now)')
replace('((benefits.vip or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", now)', '((entitlements.VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", now)')
replace('\tself:_syncPassBenefits(player)\n\treturn true\nend','''	local profile = self.profiles[player]
	if profile and profile.ready and not profile.closed and not profile.released then self:_touch(profile)
	else self:_syncPassBenefits(player) end
	return true
end''')
replace('(benefits.vip and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", os.time())','(self:_entitlements(profile.player).VIP and 3 or benefits.doubleCoins and 2 or 1) * fishingMultiplier(profile, "FishingCoinsExpires", os.time())')
replace('((benefits.vip or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", os.time())','((self:_entitlements(profile.player).VIP or benefits.doubleXP) and 2 or 1) * fishingMultiplier(profile, "FishingXPExpires", os.time())')
replace('function Economy:AdminGrantCoins(player, amount)', '''function Economy:AdminGrantEntitlement(player, entitlement)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	if entitlement ~= "VIP" and entitlement ~= "BetaTester" then return false, "Choose VIP or Beta Tester." end
	if self.sessionOnly and not self.isStudio then return false, "Grants are unavailable while player data is offline." end
	if profile.entitlementSaving then return false, "That player's previous grant is still saving." end
	local label = entitlement == "VIP" and "VIP" or "Beta Tester"
	if profile.savedEntitlements and profile.savedEntitlements[entitlement] then return true, label .. " is already granted." end
	if not profile.data.Entitlements[entitlement] then
		profile.data.Entitlements[entitlement] = true
		self:_touch(profile)
	end
	profile.entitlementSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.entitlementSaving = false
	local confirmed = self.isStudio or (profile.savedEntitlements and profile.savedEntitlements[entitlement] == true)
	if not ok or not saved or not confirmed then return false, label .. " is pending a save. Retry the grant to confirm it." end
	return true, "Granted " .. label .. "." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:RedeemCode(player, payload)
	local profile, reason = self:_adminProfile(player)
	if not profile then return false, reason end
	local now = os.clock()
	if now - (profile.lastRedeem or -math.huge) < 2 then return false, "Wait two seconds before trying another code." end
	profile.lastRedeem = now
	if profile.codeSaving then return false, "Your previous code is still saving." end
	if self.sessionOnly and not self.isStudio then return false, "Codes are unavailable while player data is offline." end
	local text = typeof(payload) == "table" and payload.code
	if typeof(text) ~= "string" or #text > 64 then return false, "Enter a valid code of up to 32 characters." end
	local code = string.upper(text:match("^%s*(.-)%s*$"))
	if #code == 0 or #code > 32 or not code:match("^[A-Z0-9_%-]+$") then return false, "Enter a valid code of up to 32 characters." end
	if profile.savedCodes and profile.savedCodes[code] then return false, "You have already redeemed this code." end
	if not profile.data.RedeemedCodes[code] then
		local reward = typeof(self.redemptionCodes) == "table" and self.redemptionCodes[code]
		if typeof(reward) ~= "table" or reward.Enabled ~= true then return false, "This code is invalid or unavailable." end
		if reward.ExpiresAt ~= nil and (not boundedInteger(reward.ExpiresAt, 0, 1000000000000) or (reward.ExpiresAt > 0 and os.time() >= reward.ExpiresAt)) then
			return false, "This code has expired."
		end
		if reward.Kind == "Coins" then
			if not boundedInteger(reward.Amount, 1, adminLimits.coinsPerGrant) then return false, "This code is unavailable." end
			if profile.data.Coins > adminLimits.maxCoins - reward.Amount then return false, "Your coin balance is full. Use some coins before redeeming this code." end
			profile.data.Coins += reward.Amount
		elseif reward.Kind == "VIP" or reward.Kind == "BetaTester" then
			profile.data.Entitlements[reward.Kind] = true
		else return false, "This code is unavailable." end
		profile.data.RedeemedCodes[code] = os.time()
		self:_touch(profile)
	end
	profile.codeSaving = true
	local ok, saved = pcall(self._save, self, profile, false)
	profile.codeSaving = false
	local confirmed = self.isStudio or (profile.savedCodes and profile.savedCodes[code] ~= nil)
	if not ok or not saved or not confirmed then return false, "Your reward is waiting to save. Try this code again; it will not grant twice." end
	if self.isStudio then
		profile.savedCodes = profile.savedCodes or {}
		profile.savedCodes[code] = profile.data.RedeemedCodes[code]
	end
	return true, "Code redeemed! Your reward is active." .. (self.isStudio and " This Studio test does not save player data." or "")
end

function Economy:AdminGrantCoins(player, amount)''')
(root/'After').mkdir(exist_ok=True)
(root/'After/PlaygroundEconomyService.luau').write_text(src,encoding='utf-8')

src=(root/'Before/PlaygroundCommerceService.luau').read_text(encoding='utf-8')
start=src.index('function Commerce:_tag(')
end=src.index('\nfunction Commerce:_passes(',start)
src=src[:start]+'''function Commerce:_tag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local vip = player:GetAttribute("PCVIP") == true
	local beta = player:GetAttribute("PCBetaTester") == true
	local current = head:FindFirstChild("PlaygroundVIPTag")
	if not vip and not beta then if current then current:Destroy() end return end
	local gui = current or Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "PlaygroundVIPTag", head, UDim2.fromOffset(vip and beta and 210 or 170, 30)
	gui.StudsOffsetWorldSpace, gui.MaxDistance, gui.AlwaysOnTop = Vector3.new(0, 3.4, 0), 90, false
	local label = gui:FindFirstChild("Title") or Instance.new("TextLabel")
	label.Name, label.Text, label.Size = "Title", vip and beta and "VIP • BETA TESTER" or vip and "VIP" or "BETA TESTER", UDim2.fromScale(1, 1)
	label.BackgroundTransparency, label.Font, label.TextSize = 1, Enum.Font.FredokaOne, 24
	label.TextColor3 = vip and Color3.fromRGB(255, 212, 70) or Color3.fromRGB(126, 226, 255)
	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Color3.fromRGB(24, 35, 62), 2
	stroke.Parent, label.Parent, gui.Parent = label, gui, head
end
''' +src[end:]
src=src.replace('self:_tag(player, state.VIP == true)', 'self:_tag(player)')
replace('\tstate.character = player.CharacterAdded:Connect(bindCharacter)', '''	state.character = player.CharacterAdded:Connect(bindCharacter)
	state.vip = player:GetAttributeChangedSignal("PCVIP"):Connect(function() self:_tag(player) end)
	state.beta = player:GetAttributeChangedSignal("PCBetaTester"):Connect(function() self:_tag(player) end)''')
replace('\tif state and state.character then state.character:Disconnect() end','''	if state then
		for _, name in { "character", "vip", "beta" } do if state[name] then state[name]:Disconnect() end end
	end''')
(root/'After/PlaygroundCommerceService.luau').write_text(src,encoding='utf-8')
(root/'After/PlaygroundRedemptionCodes.luau').write_text('return {}\n',encoding='utf-8')
print('Prepared Economy, Commerce, private code definitions.')
