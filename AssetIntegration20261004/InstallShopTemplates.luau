assert(not game:GetService("RunService"):IsRunning(), "Install the shop in Edit mode only")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = game.StarterGui:WaitForChild("PlaygroundShell")
local shop = gui:WaitForChild("ShopPanel")
local catalog = require(ReplicatedStorage:WaitForChild("PlaygroundCatalog"))
local assets = ReplicatedStorage:WaitForChild("PlaygroundCosmeticAssets")
local categories = shop.Categories

local function caption(label, value)
	label.Text = value
	local live = label:FindFirstChild("LiveCaption")
	if live then live.Text = value end
end

local function textStyle(label)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeTransparency = 1
	local stroke = label:FindFirstChild("TextOutline")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "TextOutline"
		stroke.Parent = label
	end
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.085
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = Color3.fromRGB(24, 30, 51)
	stroke.Transparency = 0
	stroke.Enabled = true
end

local bats = categories:FindFirstChild("Bats") or categories:FindFirstChild("Emotes")
assert(bats, "Missing authored category button for bats")
bats.Name = "Bats"
local toys = categories:FindFirstChild("Toys") or categories:FindFirstChild("Gear")
assert(toys, "Missing authored category button for toys")
toys.Name = "Toys"
for _, button in ipairs(categories:GetChildren()) do
	if button:IsA("TextButton") then
		local order = ({ All = 1, Bats = 2, Pets = 3, Toys = 4 })[button.Name]
		button.Visible = order ~= nil
		button.Active = order ~= nil
		button.Selectable = order ~= nil
		if order then
			button.LayoutOrder = order
			caption(button, string.upper(button.Name))
			button.ReusableSkin:SetAttribute("UISkinTargetPath", button:GetFullName())
		end
	end
end

local pager = shop:FindFirstChild("Pager")
if not pager then
	pager = Instance.new("Frame")
	pager.Name = "Pager"
	pager.BackgroundTransparency = 1
	pager.BorderSizePixel = 0
	pager.AnchorPoint = Vector2.new(0.5, 0)
	pager.Position = UDim2.new(0.5, 0, 1, -54)
	pager.Size = UDim2.fromOffset(236, 28)
	pager.ZIndex = 24
	pager.Parent = shop
	for _, spec in ipairs({ { "Previous", "PREV", 0 }, { "Next", "NEXT", 164 } }) do
		local button = categories.All:Clone()
		button.Name = spec[1]
		button.Position = UDim2.fromOffset(spec[3], 0)
		button.Size = UDim2.fromOffset(72, 28)
		button.LayoutOrder = 0
		button.Visible = true
		button.ZIndex = 25
		button:SetAttribute("UISkinSelectionFromColour", false)
		button:SetAttribute("UISkinSelectionFromOutline", false)
		button.BackgroundColor3 = Color3.fromRGB(89, 193, 244)
		button.Parent = pager
		button.ReusableSkin.ZIndex = 26
		button.ReusableSkin:SetAttribute("UISkinTargetPath", button:GetFullName())
		button.LiveCaption.ZIndex = 27
		local mark = button:FindFirstChild("SelectionMark")
		if mark then mark.Visible = false end
		caption(button, spec[2])
		textStyle(button.LiveCaption)
	end
	local label = shop.Status:Clone()
	label.Name = "PageLabel"
	label.Position = UDim2.fromOffset(76, 0)
	label.Size = UDim2.fromOffset(84, 28)
	label.ZIndex = 25
	label.Parent = pager
	textStyle(label)
end
caption(pager.PageLabel, "1 / " .. tostring(math.max(1, math.ceil(#catalog.Items / 12))))
shop.Status.Position = UDim2.new(0, 20, 1, -25)
shop.Status.Size = UDim2.new(1, -40, 0, 20)
caption(shop.Status, "Earn rewards, or spend your coins.")
textStyle(shop.Status)
caption(gui.Dock.Emote, "PETS")
caption(gui.Dock.Emoji, "TOYS")
local petCaption = gui.Dock.Emote:FindFirstChild("LiveCaption")
local toyCaption = gui.Dock.Emoji:FindFirstChild("LiveCaption")
if petCaption and toyCaption then
	toyCaption.Visible = true
	toyCaption.AnchorPoint = petCaption.AnchorPoint
	toyCaption.Position = petCaption.Position
	toyCaption.Size = petCaption.Size
	textStyle(toyCaption)
end
local icon = gui.Dock.Emoji:FindFirstChild("ArtworkIcon")
if icon then icon.Visible = false end
local gameLabels = { BritishBulldog = "Bulldog", TagYoureIt = "Tag", StuckInTheMud = "Mud", All = "total" }
local slotList = {}
for _, card in ipairs(shop.Cards:GetChildren()) do
	if card:IsA("Frame") and card:FindFirstChild("Preview") and card:FindFirstChild("Action") then table.insert(slotList, card) end
end
table.sort(slotList, function(a, b) return a.Name < b.Name end)
assert(#slotList == 12, "Expected twelve authored shop card slots")
local previewCount = 0
for index, card in ipairs(slotList) do
	local item = catalog.Items[index]
	card.Visible = item ~= nil
	card:SetAttribute("EmptyShopSlot", false)
	card:SetAttribute("CatalogId", item and item.id or nil)
	local preview = card.Preview
	local camera = preview:FindFirstChild("PreviewCamera")
	if not camera then camera = Instance.new("Camera") camera.Name = "PreviewCamera" camera.Parent = preview end
	camera.FieldOfView = 35
	preview.CurrentCamera = camera
	preview.Ambient = Color3.fromRGB(195, 195, 195)
	preview.LightColor = Color3.fromRGB(255, 249, 232)
	preview.LightDirection = Vector3.new(-1, -1, -1)
	local world = preview:FindFirstChild("World")
	assert(world and world:IsA("WorldModel"), "Missing authored WorldModel in " .. card.Name)
	for _, child in ipairs(world:GetChildren()) do child:Destroy() end
	if item then
		caption(card:FindFirstChild("Name"), item.name)
		local rule = item.unlock
		local price = rule.kind == "Coins" and tostring(item.price) .. " coins"
			or rule.kind == "Level" and "Level " .. tostring(rule.amount)
			or rule.kind == "Wins" and tostring(rule.amount) .. " " .. (gameLabels[rule.gameId] or "total") .. " wins"
			or "Starter reward"
		caption(card.Price, price)
		caption(card.Category, item.category)
		caption(card.Action, rule.kind == "Starter" and "EQUIPPED" or rule.kind == "Coins" and "BUY" or "LOCKED")
		card.Action.Visible = true
		card.Action.Active = true
		card.Action.Selectable = true
		caption(card.Try, "INFO")
		card.Try.Visible = true
		card.Try.Active = true
		card.Try.Selectable = true
		for _, label in ipairs({ card:FindFirstChild("Name"), card.Price, card.Category, card.Action.LiveCaption, card.Try.LiveCaption }) do textStyle(label) end
		local original = assets:FindFirstChild(item.id)
		if original and original:IsA("Model") then
			local model = original:Clone()
			model.Name = "ItemModel"
			local low = Vector3.new(math.huge, math.huge, math.huge)
			local high = Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("LuaSourceContainer") then child:Destroy()
				elseif child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide = false
					child.CanTouch = false
					child.CanQuery = false
					if child.Transparency < 1 then
						for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
							local point = child.CFrame:PointToWorldSpace(child.Size * Vector3.new(x, y, z) * 0.5)
							low = low:Min(point)
							high = high:Max(point)
						end end end
					end
				elseif child:IsA("ParticleEmitter") or child:IsA("Trail") then child.Enabled = false end
			end
			if low.X ~= math.huge then
				local center = (low + high) * 0.5
				local radius = math.max(0.01, (high - low).Magnitude * 0.5)
				model:PivotTo(CFrame.new(-center) * model:GetPivot())
				model.Parent = world
				local aspect = 218 / 122
				local angle = math.rad(camera.FieldOfView * 0.5)
				local distance = radius / math.sin(math.min(angle, math.atan(math.tan(angle) * aspect))) * 1.12
				camera.CFrame = CFrame.lookAt(Vector3.new(0.5, 0.2, -1).Unit * distance, Vector3.zero)
				previewCount += 1
			else model:Destroy() end
		end
	end
end
gui:SetAttribute("CosmeticShopRevision", "20261004")
pcall(function() game:GetService("ContentProvider"):PreloadAsync({ shop, gui.Dock }) end)
for _, card in ipairs(slotList) do
	local model = card.Preview.World:FindFirstChild("ItemModel")
	if model then model.Parent = nil model.Parent = card.Preview.World end
end
return { slots = #slotList, firstPagePreviews = previewCount, categories = { "All", "Bats", "Pets", "Toys" }, pageCount = math.ceil(#catalog.Items / 12) }
