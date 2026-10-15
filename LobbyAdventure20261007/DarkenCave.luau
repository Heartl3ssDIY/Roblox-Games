local scene = workspace["Playground Lobby"].SecretCaveObby
assert(not scene:FindFirstChild("CaveShell"), "Cave shell already installed")
local backups = game:GetService("ServerStorage").LobbyAdventureBackup20261007
if not backups:FindFirstChild("SecretCaveBeforeRoof") then
	local recovery = scene:Clone()
	recovery.Name, recovery.Parent = "SecretCaveBeforeRoof", backups
end
local stone = Color3.fromRGB(57, 54, 69)
local moss = Color3.fromRGB(51, 77, 73)
for _, p in scene:GetDescendants() do
	if p:IsA("BasePart") then
		if p.Name == "CavernRock" then
			local shift = math.floor(math.abs(p.Position.X)) % 3 * 5
			p.Color = Color3.fromRGB(57 + shift, 54 + shift, 69 + shift)
		elseif p.Name == "FarRock" or p.Name == "EntryRock" or p.Name == "GorgeRim" then p.Color = stone
		elseif p.Name == "MossCap" or p.Name == "EndMossCap" then p.Color = moss
		elseif p.Name == "StartIsland" or p.Name == "FinishIsland" then p.Color = Color3.fromRGB(65, 94, 85)
		elseif p.Name == "Top" and p:IsDescendantOf(scene.Tiles) then p.Color = Color3.fromRGB(63, 117, 126)
		elseif p.Name == "SoftMist" then p.Color = Color3.fromRGB(35, 69, 78); p.Transparency = 0.28
		elseif p.Name == "Crystal" or p.Name == "CrystalTip" then p.Material = Enum.Material.Neon;p.Transparency=0.05
		elseif p.Name == "Lantern" then p.Material = Enum.Material.Neon end
	end
end
local shell = Instance.new("Model")
shell.Name, shell.Parent = "CaveShell", scene
local function rock(name, size, position, color, rotation)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, CFrame.new(position) * (rotation or CFrame.identity)
	p.Color, p.Material = color or stone, Enum.Material.SmoothPlastic
	p.Anchored, p.Locked, p.CanTouch = true, true, false
	p.Parent = shell
	return p
end
rock("Roof", Vector3.new(132, 5, 68), Vector3.new(-305, 46, 54), Color3.fromRGB(40, 38, 50))
rock("NorthBacking", Vector3.new(130, 36, 7), Vector3.new(-305, 27, 23), Color3.fromRGB(48, 45, 60))
rock("SouthBacking", Vector3.new(130, 36, 7), Vector3.new(-305, 27, 85), Color3.fromRGB(48, 45, 60))
rock("BackClosure", Vector3.new(7, 36, 60), Vector3.new(-366, 27, 54), stone)
rock("EntryClosure", Vector3.new(7, 36, 60), Vector3.new(-243, 27, 54), stone)
rock("PitBed", Vector3.new(102, 1, 42), Vector3.new(-305, 5, 54), Color3.fromRGB(24, 29, 40))
for i = 1, 9 do
	local x = -250 - i * 11
	rock("RoofFacet", Vector3.new(14, 4 + i % 3, 55), Vector3.new(x, 42.7, 54), Color3.fromRGB(48 + i % 3 * 4, 45 + i % 3 * 4, 61 + i % 3 * 3), CFrame.Angles(0, math.rad(i % 3 - 1), math.rad((i % 3 - 1) * 3)))
end
for i, x in {-273, -294, -315, -336} do
	for _, z in {35.7, 72.3} do
		local holder = rock("LanternBracket", Vector3.new(0.7, 1.6, 0.8), Vector3.new(x, 28, z), Color3.fromRGB(19, 24, 33))
		local lamp = rock("WarmLantern", Vector3.new(1.15, 1.8, 1.15), holder.Position + Vector3.new(0, 0.7, z < 54 and 0.8 or -0.8), Color3.fromRGB(255, 186, 82))
		lamp.Material, lamp.CanCollide = Enum.Material.Neon, false
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(255, 209, 140), 1.4, 23, false
		light.Parent = lamp
	end
end
for _, model in scene:GetChildren() do
	if model.Name:match("^CrystalPatch") then
		local first = model:FindFirstChild("Crystal")
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = first.Color, 0.6, 12, first
	end
end
scene:SetAttribute("CaveRoof", true)
return "Dark cave palette, enclosed roof, rock walls and warm path lighting installed."
