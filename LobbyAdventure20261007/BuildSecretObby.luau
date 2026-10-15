local lobby = workspace:WaitForChild("Playground Lobby")
assert(not lobby:FindFirstChild("SecretCaveObby"), "Secret obby already exists")
local scene = Instance.new("Model")
scene.Name = "SecretCaveObby"
scene.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
scene:SetAttribute("DailyCoins", 1000)
scene:SetAttribute("Rows", 8)
scene:SetAttribute("RewardReset", "00:00 UTC")
local ink = Color3.fromRGB(20, 25, 39)
local cream = Color3.fromRGB(255, 243, 207)
local teal = Color3.fromRGB(68, 195, 168)
local gold = Color3.fromRGB(255, 204, 67)
local stone = Color3.fromRGB(126, 104, 139)

local function part(parent, name, size, position, color, collidable, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Anchored, p.Locked = true, true
	p.CanCollide, p.CanTouch, p.CanQuery = collidable ~= false, false, collidable ~= false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function plate(parent, name, position, size, color)
	part(parent, name .. "Ink", size + Vector3.new(0.22, 0.16, 0.22), position - Vector3.new(0, 0.1, 0), ink)
	local face = part(parent, name, size, position, color)
	face.MaterialVariant = "PlaygroundRetroStuds"
	return face
end

local function sign(parent, name, position, size, text, color, face)
	local board = part(parent, name, size, position, color, false)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.SizingMode = "Lettering", face or Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Label", UDim2.fromScale(1, 1), 1
	label.Text, label.Font, label.TextScaled = text, Enum.Font.FredokaOne, true
	label.TextColor3 = cream
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.09, 0), UDim.new(0.09, 0)
	padding.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color = 2.5, ink
	stroke.Parent = label
	return board
end

local function prompt(parent, name, action, object)
	local p = Instance.new("ProximityPrompt")
	p.Name, p.ActionText, p.ObjectText = name, action, object
	p.HoldDuration, p.MaxActivationDistance = 0.25, 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode, p.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

local function portal(parent, name, position, target, title)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	local frame = CFrame.lookAt(position, target)
	local function localPart(n, size, offset, color)
		local p = part(model, n, size, Vector3.zero, color, false)
		p.CFrame = frame * CFrame.new(offset)
		return p
	end
	localPart("DarkArch", Vector3.new(8.6, 10.4, 0.35), Vector3.zero, ink)
	localPart("StoneInset", Vector3.new(7.9, 9.7, 0.4), Vector3.new(0, 0, -0.1), stone)
	local opening = localPart("Opening", Vector3.new(6.4, 8.2, 0.45), Vector3.new(0, -0.1, -0.3), Color3.fromRGB(68, 42, 110))
	for _, x in {-3.55, 3.55} do
		for y = -3.7, 4, 1.6 do localPart("ArchBlock", Vector3.new(0.72, 1.38, 0.7), Vector3.new(x, y, -0.4), Color3.fromRGB(183, 160, 191)) end
	end
	localPart("Lintel", Vector3.new(7.7, 0.7, 0.7), Vector3.new(0, 4.45, -0.4), cream)
	for _, x in {-2.7, 2.7} do
		local glow = localPart("GlowStone", Vector3.new(0.36, 0.65, 0.3), Vector3.new(x, 1.6, -0.6), teal)
		glow.Material = Enum.Material.Neon
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = teal, 0.8, 12
	light.Parent = opening
	prompt(opening, "Travel", "Enter", title)
	return model
end

local start = plate(scene, "StartIsland", Vector3.new(-259, 19, 54), Vector3.new(22, 2, 38), Color3.fromRGB(130, 195, 142))
local finish = plate(scene, "FinishIsland", Vector3.new(-349, 19, 54), Vector3.new(24, 2, 38), Color3.fromRGB(130, 195, 142))
local spawn = part(scene, "StartPoint", Vector3.new(1, 1, 1), Vector3.new(-262, 23.5, 54), cream, false)
spawn.Transparency = 1
spawn.CFrame = CFrame.lookAt(spawn.Position, Vector3.new(-280, 23.5, 54))
local tiles = Instance.new("Folder")
tiles.Name, tiles.Parent = "Tiles", scene
for row = 1, 8 do
	for column = 1, 3 do
		local tile = Instance.new("Model")
		tile.Name = string.format("Tile%d_%d", row, column)
		tile:SetAttribute("Row", row)
		tile:SetAttribute("Column", column)
		tile.Parent = tiles
		local pos = Vector3.new(-267 - row * 8, 19.6, 54 + (column - 2) * 8)
		local top = plate(tile, "Top", pos, Vector3.new(7.2, 0.8, 7.2), Color3.fromRGB(128, 190, 223))
		tile.PrimaryPart = top
		for _, z in {-2.8, 2.8} do
			part(tile, "CornerStud", Vector3.new(0.35, 0.14, 0.35), pos + Vector3.new(2.8, 0.46, z), cream, false)
		end
	end
end
for _, z in {32, 76} do
	plate(scene, "GorgeRim", Vector3.new(-305, 17, z), Vector3.new(121, 5, 5), stone)
	for index = 0, 12 do
		local x = -247 - index * 9
		local h = 13 + (index * 7 % 13)
		local p = part(scene, "CavernRock", Vector3.new(10.5, h, 8), Vector3.new(x, 17 + h / 2, z + (z < 54 and -3 or 3)), Color3.fromRGB(118 + index % 3 * 12, 98 + index % 3 * 8, 128 + index % 3 * 10))
		p.CFrame *= CFrame.Angles(0, math.rad((index % 3 - 1) * 8), 0)
		plate(scene, "MossCap", p.Position + Vector3.new(0, h / 2 + 0.3, 0), Vector3.new(10.3, 0.6, 7.8), teal)
	end
end
part(scene, "FarRock", Vector3.new(8, 24, 53), Vector3.new(-366, 27, 54), stone)
part(scene, "EntryRock", Vector3.new(7, 24, 53), Vector3.new(-243, 27, 54), stone)
for _, x in {-366, -243} do plate(scene, "EndMossCap", Vector3.new(x, 39.25, 54), Vector3.new(8, 0.5, 53), teal) end
local mist = part(scene, "SoftMist", Vector3.new(100, 0.2, 40), Vector3.new(-306, 7.5, 54), Color3.fromRGB(155, 208, 219), false)
mist.Transparency = 0.55
for _, position in {Vector3.new(-260, 23, 39), Vector3.new(-260, 23, 69), Vector3.new(-350, 23, 39), Vector3.new(-350, 23, 69)} do
	part(scene, "LanternPost", Vector3.new(0.6, 5.8, 0.6), position, ink)
	local lamp = part(scene, "Lantern", Vector3.new(1.4, 1.6, 1.4), position + Vector3.new(0, 3.2, 0), gold, false)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = gold, 0.7, 18, lamp
	part(scene, "LanternCap", Vector3.new(1.8, 0.22, 1.8), position + Vector3.new(0, 4.12, 0), ink, false)
end
local instruction = sign(scene, "TrailInstructions", Vector3.new(-258, 25.2, 36), Vector3.new(18, 6.6, 0.55), "SECRET STEPS\nFind the safe tile in every row.\nWrong tiles disappear!", Color3.fromRGB(48, 116, 127))
instruction.CFrame = CFrame.new(instruction.Position) * CFrame.Angles(0, math.pi, 0)
sign(scene, "DailyPrizeSign", Vector3.new(-350, 28, 73), Vector3.new(18, 7, 0.55), "1,000 COINS\nONCE PER DAY\nResets at 00:00 UTC", Color3.fromRGB(137, 90, 42))
local chest = Instance.new("Model")
chest.Name, chest.Parent = "TreasureChest", scene
plate(chest, "Base", Vector3.new(-351, 21.6, 54), Vector3.new(7, 3, 5), Color3.fromRGB(175, 105, 49))
plate(chest, "Lid", Vector3.new(-351, 23.55, 54), Vector3.new(7.2, 1, 5.2), gold)
for _, x in {-353.4, -348.6} do part(chest, "GoldBand", Vector3.new(0.65, 4.05, 5.5), Vector3.new(x, 22.1, 54), gold, false) end
local latch = part(chest, "Latch", Vector3.new(1.2, 1.6, 0.35), Vector3.new(-351, 22.2, 51.35), ink, false)
prompt(latch, "ClaimReward", "Claim 1,000 coins", "Daily trail reward")
portal(scene, "ReturnPortal", Vector3.new(-251, 25, 66), Vector3.new(-251, 25, 54), "Back to the cave")
portal(scene, "FinishReturnPortal", Vector3.new(-357, 25, 66), Vector3.new(-357, 25, 54), "Back to the cave")
local caveEntry = portal(lobby.Improvements20261003.CaveAlcove, "SecretPassage", Vector3.new(-133, 9.4, 43.9), Vector3.new(-133, 9.4, 54), "A secret passage...")
scene.Parent = lobby
return game:GetService("HttpService"):JSONEncode({parts=#scene:GetDescendants(),entry=caveEntry:GetFullName(),obby=scene:GetFullName()})
