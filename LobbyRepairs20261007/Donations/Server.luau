local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("PlaygroundDonationProducts")
local result = ReplicatedStorage:WaitForChild("PlaygroundDonationResult")
local receipts = DataStoreService:GetDataStore("PlaygroundDonationReceipts_v1")

local function configured(productId)
	if typeof(productId) ~= "number" or productId <= 0 or productId % 1 ~= 0 then return false end
	for _, entry in config:GetChildren() do
		if entry:IsA("IntValue") and entry.Value == productId then return true end
	end
	return false
end

MarketplaceService.ProcessReceipt = function(receipt)
	if not configured(receipt.ProductId) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if typeof(receipt.PurchaseId) ~= "string" or receipt.PurchaseId == "" or #receipt.PurchaseId > 128 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local ok, saved = pcall(function()
		return receipts:UpdateAsync(receipt.PurchaseId, function(previous)
			if previous then return previous end
			return {
				playerId = receipt.PlayerId,
				productId = receipt.ProductId,
				robux = receipt.CurrencySpent,
				at = os.time(),
			}
		end)
	end)
	if not ok or typeof(saved) ~= "table" or saved.playerId ~= receipt.PlayerId or saved.productId ~= receipt.ProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	result:FireClient(player, "Thank you for supporting Playground Classics!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
