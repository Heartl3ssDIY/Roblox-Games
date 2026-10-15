local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = script.Parent
local panel = gui.Panel
local config = ReplicatedStorage:WaitForChild("PlaygroundDonationProducts")
local commerce = ReplicatedStorage:WaitForChild("PlaygroundCommerce")
local result = ReplicatedStorage:WaitForChild("PlaygroundDonationResult")
local offers, loading, pending, previousSelection = {}, false, nil, nil

local function inRound()
	return player:GetAttribute("BBParticipating") == true or player:GetAttribute("TGParticipating") == true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true )
end

local function close()
	panel.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
	end
end

local function fit()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	panel.Fit.Scale = math.min(1, math.max(0.25, (viewport.X - 32) / 460), math.max(0.25, (viewport.Y - 100) / 460))
end

local function buy(offer)
	if not panel.Visible or inRound() or pending then return end
	if commerce:GetAttribute("Ready") ~= true then panel.Status.Text = "Donations are not available right now." return end
	if not offer then panel.Status.Text = "That amount isn't available yet. Choose an available button." return end
	pending = offer.id
	panel.Status.Text = "Confirm your donation in the Roblox window."
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, offer.id) end)
	if not ok then pending = nil panel.Status.Text = "Roblox couldn't open the purchase. Please try again." end
end

local function loadOffers()
	if loading then return end
	loading = true
	table.clear(offers)
	panel.Status.Text = "Checking donation options..."
	for _, button in panel.Amounts:GetChildren() do
		if button:IsA("GuiButton") then button.Active = false button:SetAttribute("ProductId", nil) end
	end
	local count = 0
	for _, entry in config:GetChildren() do
		if not entry:IsA("IntValue") or entry.Value <= 0 then continue end
		local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(entry.Value, Enum.InfoType.Product) end)
		if not ok or typeof(info) ~= "table" or info.IsForSale == false or typeof(info.PriceInRobux) ~= "number" or info.PriceInRobux < 1 then continue end
		local offer = { id = entry.Value, price = info.PriceInRobux }
		table.insert(offers, offer)
		count += 1
		local button = panel.Amounts:FindFirstChild(entry.Name)
		if button then
			button.Label.Text = tostring(offer.price) .. " ROBUX"
			button:SetAttribute("ProductId", offer.id)
			button.Active = true
		end
	end
	loading = false
	panel.Status.Text = count > 0 and "Every donation helps. Thank you!" or "Donations are coming soon."
end

for _, button in panel.Amounts:GetChildren() do
	if button:IsA("GuiButton") then
		button.Activated:Connect(function()
			local id = button:GetAttribute("ProductId")
			for _, offer in offers do if offer.id == id then buy(offer) return end end
			panel.Status.Text = "This donation option is not available yet."
		end)
	end
end

panel.OtherDonate.Activated:Connect(function()
	local text = panel.OtherAmount.Text:match("^%s*(%d+)%s*$")
	local amount = text and tonumber(text)
	if not amount or amount < 1 or amount > 1000000000 then panel.Status.Text = "Enter a whole Robux amount." return end
	for _, offer in offers do if offer.price == amount then buy(offer) return end end
	buy(nil)
end)
panel.Close.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if not panel.Visible or processed then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player or inRound() or prompt:GetAttribute("PlaygroundDonationBoard") ~= true then return end
	previousSelection = GuiService.SelectedObject
	panel.Visible = true
	fit()
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = panel.Amounts.Donation50 end
	task.spawn(loadOffers)
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if userId ~= player.UserId or productId ~= pending then return end
	pending = nil
	panel.Status.Text = purchased and "Waiting for Roblox to confirm your donation..." or "Purchase cancelled. You haven't donated."
end)
result.OnClientEvent:Connect(function(message)
	if typeof(message) == "string" then pending = nil panel.Status.Text = message end
end)
for _, attribute in { "BBParticipating", "TGParticipating", "MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated" } do
	player:GetAttributeChangedSignal(attribute):Connect(function() if inRound() then close() end end)
end
local viewportConnection
local function bindCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
panel.Visible = false

