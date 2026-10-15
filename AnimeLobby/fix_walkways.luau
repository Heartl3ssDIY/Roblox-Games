local lobby = workspace:WaitForChild("Lobby_MainModeZone")
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("BeforeLobbyWalkwayFix_20260917")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "BeforeLobbyWalkwayFix_20260917"
	backup.Parent = storage
	lobby:Clone().Parent = backup
end
if lobby:GetAttribute("WalkwayFixVersion") == 1 then return "Already applied" end

local courtyard = lobby.Courtyard
local sample = courtyard:FindFirstChild("RadialTimber")
local function disk(name, radius, height, y, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(0, y, 4) * CFrame.Angles(0, 0, math.pi / 2)
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = courtyard
	return p
end

if sample then
	disk("TimberPromenade", 33.65, 0.1, 1.12, sample.Color, sample.Material)
	disk("InnerStoneCourt", 21.65, 0.08, 1.18, courtyard.CourtyardStone.Color, Enum.Material.Slate)
	for _, p in ipairs(courtyard:GetChildren()) do
		if p.Name == "RadialTimber" then p:Destroy()
		elseif p.Name == "CourtyardPaver" then p.Position = Vector3.new(p.Position.X, 1.25, p.Position.Z) end
	end
end

for _, name in ipairs({ "TimberPromenade", "InnerStoneCourt", "CourtyardStone" }) do
	local floor = courtyard:FindFirstChild(name)
	if floor then floor.CanCollide = true floor.CanQuery = true end
end

local posts = {}
for _, p in ipairs(lobby.GardenDetails:GetChildren()) do
	if p.Name == "LanternPost" then table.insert(posts, p.Position) end
end
local center = Vector3.new(0, 0, 4)
local turn = CFrame.new(center) * CFrame.Angles(0, math.rad(15), 0) * CFrame.new(-center)
local lampNames = { LanternBase = true, LanternPost = true, PaperLantern = true, LanternCap = true }
local gardenNames = { BambooStem = true, BambooNode = true, BambooLeaf = true, Shrub = true, GardenRock = true }
local moved = 0
for _, p in ipairs(lobby.GardenDetails:GetChildren()) do
	if p:IsA("BasePart") then
		if lampNames[p.Name] then
			for _, position in ipairs(posts) do
				if Vector2.new(p.Position.X - position.X, p.Position.Z - position.Z).Magnitude < 1 then
					p.CFrame = turn * p.CFrame
					moved += 1
					break
				end
			end
			p.CanCollide = false
			p.CanQuery = false
		elseif gardenNames[p.Name] then
			local side = p.Position.X < 0 and -1 or 1
			local cluster = Vector3.new(side * 31, p.Position.Y, 7)
			if (p.Position - cluster).Magnitude < 8 then
				p.CFrame += Vector3.new(side * 37, 0, 32)
				moved += 1
			end
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

for _, p in ipairs(lobby.GardenPaths:GetChildren()) do
	if p.Name == "WalkBorder" then
		p.CanCollide = false
		p.CanQuery = false
	elseif p.Name == "WalkJoint" then
		p.Position = Vector3.new(p.Position.X, 1.225, p.Position.Z)
	end
end

local portalNames = { PortalBase = true, PortalInlay = true, PortalLight = true }
local centers = {}
for _, p in ipairs(lobby:GetDescendants()) do
	if p:IsA("BasePart") and p.Name == "PortalBase" then table.insert(centers, p.Position) end
end
for _, p in ipairs(lobby:GetDescendants()) do
	if p:IsA("BasePart") and portalNames[p.Name] then
		local closest, distance
		for _, position in ipairs(centers) do
			local d = Vector2.new(p.Position.X - position.X, p.Position.Z - position.Z).Magnitude
			if not distance or d < distance then closest, distance = position, d end
		end
		if closest then
			local scale = 0.66
			if p.Name == "PortalLight" then
				local offset = p.Position - closest
				p.Position = closest + Vector3.new(offset.X * scale, offset.Y, offset.Z * scale)
				p.Size = Vector3.new(p.Size.X * scale, p.Size.Y, p.Size.Z)
			else
				p.Size = Vector3.new(p.Size.X, p.Size.Y * scale, p.Size.Z * scale)
			end
		end
	end
end

lobby:SetAttribute("WalkwayFixVersion", 1)
return { movedDecor = moved, backup = backup:GetFullName() }
