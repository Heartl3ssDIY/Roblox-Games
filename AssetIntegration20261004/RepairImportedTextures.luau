assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local fixes = {
	["rbxassetid://138756639549153"] = "rbxassetid://77066929906664",
	["rbxassetid://122033544638433"] = "rbxassetid://78142008898295",
}
local repaired = 0
for _,root in {workspace, game.ReplicatedStorage.PlaygroundCosmeticAssets} do
	for _,part in root:GetDescendants() do
		if part:IsA("MeshPart") and fixes[part.TextureID] then
			part:SetAttribute("PCOriginalTexture", part.TextureID)
			part.TextureID = fixes[part.TextureID]
			repaired += 1
		end
	end
end
return repaired
