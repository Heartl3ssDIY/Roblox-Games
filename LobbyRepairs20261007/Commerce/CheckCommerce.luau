local checked = 0
local function check(condition, label) assert(condition, label); checked += 1 end
local queue = {}
local task = {
 defer = function(fn) table.insert(queue, fn) end,
 delay = function(_, fn) table.insert(queue, fn) end,
 spawn = function(fn) fn() end,
}
local Enum = {ProductPurchaseDecision={NotProcessedYet="retry", PurchaseGranted="granted"}}
local market = {}
local player = {UserId=7}
local online = true
local players = {}
player.Parent=players
function players:GetPlayerByUserId(id) return online and id==7 and player or nil end
local recorded, storeFails = {}, false
local saves = 0
local receipts = {}
function receipts:UpdateAsync(id, transform)
 if storeFails then error("storage unavailable") end
 recorded[id]=transform(recorded[id]); saves+=1; return recorded[id]
end
local replicated = {}
local dataStore = {GetDataStore=function() return receipts end}
local services = {MarketplaceService=market, DataStoreService=dataStore, Players=players, ReplicatedStorage=replicated}
local game = {GetService=function(_, name) return services[name] end}
local function moduleFactory()
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
	state.character = player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			local head = character:WaitForChild("Head", 10)
			if head and self.players[player] == state and player.Character == character then self:_tag(player, state.VIP == true) end
		end)
	end)
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


end
local Commerce=moduleFactory()
local function entry(name, value, kind, amount)
 return {Name=name,Value=value,IsA=function(_,class) return class=="IntValue" end,GetAttribute=function(_,key) if key=="Kind" then return kind elseif key=="Coins" then return amount end end}
end
local coin=entry("Coin5000",101,"Product",5000)
local vip=entry("VIP",201,"GamePass")
local double=entry("DoubleCoins",202,"GamePass")
local xp=entry("DoubleXP",203,"GamePass")
local entries={coin,vip,double,xp}
local config={GetChildren=function() return entries end,FindFirstChild=function(_,name) for _,v in entries do if v.Name==name then return v end end end}
local donation=entry("Donation50",301)
local donated={GetChildren=function() return {donation} end}
local failGrant, notifyFails = false,false
local grants,benefits={},{}
local economy={}
function economy:GrantCoinPurchase(_,receipt,coins) if failGrant then return false end grants[receipt.PurchaseId]=coins;return true end
function economy:SetPassBenefits(_,a,b,c) table.insert(benefits,{a,b,c}) end
local event={FireClient=function() if notifyFails then error("player left") end end}
local service=Commerce.new(economy)
service.running=true;service.config=config;service.donations=donated;service.receipts=receipts;service.result=event;service.donationResult=event
local function receipt(product,id) return {PlayerId=7,ProductId=product,PurchaseId=id or "receipt-1",CurrencySpent=50} end
check(service:_receipt(receipt(999))=="retry","unknown product")
check(service:_receipt(receipt(0))=="retry","zero product")
online=false;check(service:_receipt(receipt(101))=="retry","offline");online=true
failGrant=true;check(service:_receipt(receipt(101))=="retry","coin save pending");failGrant=false
check(service:_receipt(receipt(101))=="granted" and grants["receipt-1"]==5000,"exact pack amount")
notifyFails=true;check(service:_receipt(receipt(101,"receipt-left"))=="granted","notification cannot block saved coins")
check(service:_receipt(receipt(301,"donation-1"))=="granted","donation persists despite notification error")
check(recorded["donation-1"].productId==301 and recorded["donation-1"].robux==50,"actual receipt logged")
local original=recorded["donation-1"]
check(service:_receipt(receipt(301,"donation-1"))=="granted" and recorded["donation-1"]==original,"donation replay unchanged")
storeFails=true;check(service:_receipt(receipt(301,"donation-2"))=="retry","failed donation save");storeFails=false
notifyFails=false
local state={};service.players[player]=state
local raced=false
function market:UserOwnsGamePassAsync(_,id)
 if not raced then raced=true;service:_passes(player);return false end
 return id==201
end
service:_passes(player)
check(#queue==1,"pass refresh queued during lookup")
table.remove(queue,1)()
check(benefits[#benefits][1]==true,"queued refresh sees VIP")
check(not state.loading and not state.refreshPending,"refresh lock released")
local attempt=0
function market:UserOwnsGamePassAsync() attempt+=1;error("temporary outage") end
service:_passes(player)
while #queue>0 do table.remove(queue,1)() end
check(attempt==12,"ownership retries bounded to initial plus three")
check(state.VIP==true,"temporary failure preserves known ownership")
service.running=false
check(service:_receipt(receipt(101))=="retry","stopped service denies receipt")
print("Commerce checks passed: "..checked)

