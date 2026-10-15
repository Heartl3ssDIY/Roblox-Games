local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Commerce = {}
Commerce.__index = Commerce

function Commerce.new(economy)
	return setmetatable({ economy = economy, connections = {}, players = {}, running = false }, Commerce)
end

local function validId(value)
	return typeof(value) == "number" and value > 0 and value % 1 == 0 and value < 9007199254740991
end

function Commerce:_tag(player, vip)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local current = head:FindFirstChild("PlaygroundVIPTag")
	if not vip then if current then current:Destroy() end return end
	if current then return end
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "PlaygroundVIPTag", head, UDim2.fromOffset(100, 30)
	gui.StudsOffsetWorldSpace, gui.MaxDistance, gui.AlwaysOnTop = Vector3.new(0, 3.4, 0), 90, false
	local label = Instance.new("TextLabel")
	label.Name, label.Text, label.Size = "Title", "VIP", UDim2.fromScale(1, 1)
	label.BackgroundTransparency, label.Font, label.TextSize = 1, Enum.Font.FredokaOne, 24
	label.TextColor3 = Color3.fromRGB(255, 212, 70)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = Color3.fromRGB(24, 35, 62), 2
	stroke.Parent, label.Parent, gui.Parent = label, gui, head
end

function Commerce:_passes(player)
	local state = self.players[player]
	if not self.running or not state then return end
	if state.loading then state.refreshPending = true return end
	state.loading = true
	local failed = false
	for _, key in { "VIP", "DoubleCoins", "DoubleXP" } do
		local entry = self.config:FindFirstChild(key)
		if entry and validId(entry.Value) then
			local ok, owned = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.Value) end)
			if ok then state[key] = owned == true else failed = true end
		else
			state[key] = false
		end
	end
	state.loading = false
	if not self.running or self.players[player] ~= state or player.Parent ~= Players then return end
	self.economy:SetPassBenefits(player, state.VIP == true, state.DoubleCoins == true, state.DoubleXP == true)
	self:_tag(player, state.VIP == true)
	local purchased = state.purchaseKey
	if purchased and state[purchased] then
		state.purchaseKey = nil
		pcall(function() self.result:FireClient(player, "Your " .. (purchased == "VIP" and "VIP" or purchased == "DoubleXP" and "2x XP" or "2x coins") .. " pass is active!") end)
	end
	if state.refreshPending then
		state.refreshPending = nil
		task.defer(function() if self.players[player] == state then self:_passes(player) end end)
	elseif failed and (state.retries or 0) < 3 then
		state.retries = (state.retries or 0) + 1
		task.delay(5 * state.retries, function() if self.players[player] == state then self:_passes(player) end end)
	elseif not failed then
		state.retries = 0
	end
end

function Commerce:_player(player)
	if self.players[player] then return end
	local state = {}
	self.players[player] = state
	local function bindCharacter(character)
		task.spawn(function()
			local head = character:WaitForChild("Head", 10)
			if head and self.players[player] == state and player.Character == character then self:_tag(player, state.VIP == true) end
		end)
	end
	state.character = player.CharacterAdded:Connect(bindCharacter)
	if player.Character then bindCharacter(player.Character) end
	task.spawn(function() self:_passes(player) end)
end

function Commerce:_remove(player)
	local state = self.players[player]
	if state and state.character then state.character:Disconnect() end
	self.players[player] = nil
end

function Commerce:_receipt(receipt)
	local retry = Enum.ProductPurchaseDecision.NotProcessedYet
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted
	if not self.running or not validId(receipt.ProductId) or not validId(receipt.PlayerId) then return retry end
	if typeof(receipt.PurchaseId) ~= "string" or receipt.PurchaseId == "" or #receipt.PurchaseId > 50 then return retry end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return retry end
	for _, entry in self.config:GetChildren() do
		if entry:IsA("IntValue") and entry:GetAttribute("Kind") == "Product" and entry.Value == receipt.ProductId then
			local coins = entry:GetAttribute("Coins")
			if not validId(coins) or coins > 100000 then return retry end
			local ok, saved = pcall(function() return self.economy:GrantCoinPurchase(player, receipt, coins) end)
			if not ok or saved ~= true then return retry end
			pcall(function() self.result:FireClient(player, "Purchase confirmed! +" .. coins .. " coins.") end)
			return granted
		end
	end
	for _, entry in self.donations:GetChildren() do
		if not entry:IsA("IntValue") or entry.Value ~= receipt.ProductId then continue end
		local ok, saved = pcall(function()
			return self.receipts:UpdateAsync(receipt.PurchaseId, function(previous)
				if previous then return previous end
				return { playerId = receipt.PlayerId, productId = receipt.ProductId, robux = receipt.CurrencySpent, at = os.time() }
			end)
		end)
		if not ok or typeof(saved) ~= "table" or saved.playerId ~= receipt.PlayerId or saved.productId ~= receipt.ProductId then return retry end
		pcall(function() self.donationResult:FireClient(player, "Thank you for supporting Playground Classics!") end)
		return granted
	end
	return retry
end

function Commerce:Start()
	if self.running then return self end
	self.config = ReplicatedStorage:WaitForChild("PlaygroundCommerce")
	self.result = ReplicatedStorage:WaitForChild("PlaygroundCommerceResult")
	self.donations = ReplicatedStorage:WaitForChild("PlaygroundDonationProducts")
	self.donationResult = ReplicatedStorage:WaitForChild("PlaygroundDonationResult")
	self.receipts = DataStoreService:GetDataStore("PlaygroundDonationReceipts_v1")
	self.config:SetAttribute("Ready", false)
	self.running = true
	MarketplaceService.ProcessReceipt = function(receipt) return self:_receipt(receipt) end
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_player(player) end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self:_remove(player) end))
	table.insert(self.connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		for _, key in { "VIP", "DoubleCoins", "DoubleXP" } do
			local entry = self.config:FindFirstChild(key)
			if entry and validId(entry.Value) and entry.Value == passId then
				task.spawn(function()
					local state = self.players[player]
					if state then state.purchaseKey, state.retries = key, 0 self:_passes(player) end
				end)
				break
			end
		end
	end))
	for _, player in Players:GetPlayers() do self:_player(player) end
	self.config:SetAttribute("Ready", true)
	return self
end

function Commerce:Stop()
	self.running = false
	if self.config then self.config:SetAttribute("Ready", false) end
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for player in self.players do self:_remove(player) end
end

return Commerce
