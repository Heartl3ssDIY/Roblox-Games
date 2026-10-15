assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local RS = game:GetService("ReplicatedStorage")
local assets = RS.PlaygroundCosmeticAssets
local catalogClone = RS.PlaygroundCatalog:Clone()
catalogClone.Name = "IntegrationCatalogCheck"
catalogClone.Parent = game.ServerStorage
local ok, result = pcall(function()
	local catalog = require(catalogClone)
	local report = { catalogItems = #catalog.Items, assets = 0, outlines = 0, studCoatings = 0, lobbyLocked = 0, gunMeshParts = {}, rigsPreserved = 0, playStarted = false }
	assert(#catalog.Items == 50)
	for _,item in catalog.Items do
		local model = assets:FindFirstChild(item.id)
		assert(model and model:IsA("Model"), "Missing asset " .. item.id)
		assert(item.price >= 0 and item.price <= 10000)
		assert(model:FindFirstChild("CartoonOutline"), "Missing outline " .. item.id)
		report.assets += 1
		report.outlines += 1
		for _,part in model:GetDescendants() do
			if part:IsA("MeshPart") and part:GetAttribute("PCStudLayer") ~= true then
				assert(part.TextureID ~= "", "Missing colour texture " .. item.id)
				assert(part:FindFirstChild("PCStudFinish"), "Missing studs " .. item.id)
				report.studCoatings += 1
			end
		end
		if item.slot == "Pet" then
			local backup = game.ServerStorage.AssetIntegrationBackup20261004.ImportedModels:FindFirstChild(model:GetAttribute("OriginalModelName"))
			assert(backup)
			local function count(root, class)
				local n = 0
				for _,o in root:GetDescendants() do if o:IsA(class) then n += 1 end end
				return n
			end
			for _,class in {"Motor6D", "Bone", "AnimationController", "Animation"} do assert(count(model,class) == count(backup,class), "Rig changed " .. item.id .. " " .. class) end
			report.rigsPreserved += 1
		end
	end
	assert(assets:FindFirstChild("C01"), "Coin model missing")
	for _,name in {"MudGun", "HeatGun"} do
		local tool = RS.MudAssets[name]
		assert(tool:IsA("Tool") and tool.RequiresHandle and not tool.CanBeDropped)
		assert(tool.Handle.MuzzleAttachment.Position.Z < -2)
		assert(tool:GetAttribute("GunKind") == (name == "MudGun" and "Mud" or "Heat"))
		local count = 0
		for _,part in tool:GetDescendants() do if part:IsA("BasePart") then
			assert(not part.Anchored and not part.CanCollide and part.Massless, "Unsafe gun part " .. part.Name)
			if part:IsA("MeshPart") then assert(part.MaterialVariant == "PlaygroundItemStuds"); count += 1 end
		end end
		report.gunMeshParts[name] = count
	end
	for _,part in workspace["Playground Lobby"]:GetDescendants() do if part:IsA("BasePart") then assert(part.Anchored and part.Locked); report.lobbyLocked += 1 end end
	local shop = game.StarterGui.PlaygroundShell.ShopPanel
	assert(shop.Pager.Previous and shop.Pager.Next and shop.Pager.PageLabel)
	local cards = 0
	for _,card in shop.Cards:GetChildren() do if card:IsA("Frame") and card:FindFirstChild("Preview") then
		assert(card.Preview.CurrentCamera and card.Preview.World:FindFirstChildOfClass("Model"))
		cards += 1
	end end
	assert(cards == 12)
	report.shopCards = cards
	return report
end)
catalogClone:Destroy()
assert(ok, result)
return result
