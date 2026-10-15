assert(not game.RunService:IsRunning(), "Edit mode required")
local serverFolders = {"PlaygroundBeforeMud20261003", "WeaponRigBackup20261004", "WeaponRigFixtures", "PodiumEmotesBackup20261004", "ShopViewportRefreshBackup20261004", "ToyGameplayUIBackup20261005", "EmoteShopUIBackup20261005", "EmoteWheelBackup20261005", "MobileFinishBackup20261007", "PlaygroundStyledSourceAssets20261007"}
local targets = {}
local function take(outline)
	assert(outline:IsA("Highlight") and outline.Name == "CartoonOutline" and outline.Parent:IsA("Model"))
	assert(outline.Adornee == outline.Parent, "Unexpected external adornee: " .. outline:GetFullName())
	table.insert(targets, outline)
end
for _, name in ipairs(serverFolders) do
	local folder = assert(game.ServerStorage:FindFirstChild(name), name)
	for _, object in ipairs(folder:GetDescendants()) do if object:IsA("Highlight") then take(object) end end
end
for _, range in ipairs({{"B",16,25},{"M",16,25},{"P",21,35}}) do
	for n=range[2],range[3] do
		local id=string.format("%s%02d",range[1],n)
		local model=assert(game.ReplicatedStorage.PlaygroundCosmeticAssets:FindFirstChild(id))
		take(assert(model:FindFirstChild("CartoonOutline")))
	end
end
assert(#targets == 149, "Highlight plan count changed")
local rows = {}
for _, h in ipairs(targets) do
	table.insert(rows, {path=h:GetFullName(), owner=h.Parent:GetFullName(), name=h.Name, enabled=h.Enabled,
		fillColor={h.FillColor.R,h.FillColor.G,h.FillColor.B}, fillTransparency=h.FillTransparency,
		outlineColor={h.OutlineColor.R,h.OutlineColor.G,h.OutlineColor.B}, outlineTransparency=h.OutlineTransparency,
		depthMode=h.DepthMode.Name, attributes=h:GetAttributes()})
end
return game.HttpService:JSONEncode(rows)
