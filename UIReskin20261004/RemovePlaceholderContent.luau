return function()
	local RunService = game:GetService("RunService")
	assert(not RunService:IsRunning(), "Placeholder cleanup must run in Edit mode")
	local StarterGui = game:GetService("StarterGui")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local shell = assert(StarterGui:FindFirstChild("PlaygroundShell"), "PlaygroundShell is missing")
	local shop = assert(shell:FindFirstChild("ShopPanel"), "ShopPanel is missing")
	local cards = assert(shop:FindFirstChild("Cards"), "Shop card container is missing")
	local templates = assert(shell:FindFirstChild("Templates"), "Editable templates are missing")
	local template = assert(templates:FindFirstChild("ItemCard"), "ItemCard template is missing")
	local assets = assert(ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets"), "Cosmetic asset folder is missing")
	assert(assets:IsA("Folder"), "Cosmetic assets must remain a Folder")
	local retired = {
		BubbleBee = true, CloudPup = true, Wave = true, Cheer = true,
		Star = true, Heart = true, SunsetTrail = true, RainbowTrail = true,
		SkyOutline = true, RainbowOutline = true, SnowPotion = true, StarWand = true,
	}
	local targets = { template }
	for index = 1, 12 do
		local card = assert(cards:FindFirstChild(string.format("Slot%02d", index)), "An editable shop slot is missing")
		assert(card:IsA("Frame"), "Shop slots must remain editable Frames")
		local id = card:GetAttribute("CatalogId")
		assert(id == nil or retired[id], "A shop slot now contains a different item; preserve it before cleanup")
		table.insert(targets, card)
	end
	for _, card in ipairs(targets) do
		local preview = assert(card:FindFirstChild("Preview"), "A card preview is missing")
		assert(preview:IsA("ViewportFrame"), "Card previews must remain ViewportFrames")
		assert(preview:FindFirstChild("World") and preview.World:IsA("WorldModel"), "A card WorldModel is missing")
		local camera = preview:FindFirstChild("Camera")
		assert(camera == nil or camera:IsA("Camera"), "A card Camera has an unexpected type")
	end
	local report = { assetsRemoved = 0, previewModelsRemoved = 0, previewPedestalsRemoved = 0, effectsRemoved = 0, emptySlots = 12, templates = 1 }
	for _, object in ipairs(assets:GetChildren()) do
		if object:IsA("Model") and retired[object.Name] and object:GetAttribute("CatalogId") == object.Name then
			object:Destroy()
			report.assetsRemoved += 1
		end
	end
	for _, card in ipairs(targets) do
		card:SetAttribute("CatalogId", nil)
		card:SetAttribute("Category", nil)
		card:SetAttribute("EmptyShopSlot", true)
		for _, name in ipairs({ "Name", "Price", "Category", "Action", "Try" }) do
			local object = card:FindFirstChild(name)
			if object then
				if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then object.Text = "" end
				for _, label in ipairs(object:GetDescendants()) do
					if label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox") then label.Text = "" end
				end
			end
		end
		for _, name in ipairs({ "Action", "Try" }) do
			local button = card:FindFirstChild(name)
			if button and button:IsA("GuiButton") then
				button.Active = false
				button.Selectable = false
				button.AutoButtonColor = false
				button.Visible = false
			end
		end
		local preview = card.Preview
		for _, object in ipairs(preview.World:GetChildren()) do
			if object:IsA("Model") and object.Name == "ItemModel" and retired[object:GetAttribute("CatalogId")] then
				object:Destroy()
				report.previewModelsRemoved += 1
			elseif object:IsA("BasePart") and object.Name == "PreviewPedestal" then
				object:Destroy()
				report.previewPedestalsRemoved += 1
			end
		end
		local camera = preview:FindFirstChild("Camera") or preview.CurrentCamera
		if not camera then
			camera = Instance.new("Camera")
			camera.Name = "Camera"
			camera.FieldOfView = 32
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 1, 5), Vector3.zero)
			camera.Parent = preview
		end
		preview.CurrentCamera = camera
		card.Visible = card ~= template
	end
	local effects = workspace:FindFirstChild("PlaygroundCosmeticEffects")
	if effects then
		for _, object in ipairs(effects:GetChildren()) do
			if object:IsA("Model") and retired[object:GetAttribute("CatalogId")] then
				object:Destroy()
				report.effectsRemoved += 1
			end
		end
	end
	local status = shop:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then status.Text = "Items are being added." end
	return report
end
