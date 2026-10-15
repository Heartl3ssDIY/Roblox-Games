local Selection = game:GetService("Selection")
local changed = 0
local function configure(part)
	if not part:IsA("BasePart") then
		return
	end
	if part.Name:match("^TC_") then
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if part.Name:match("^TC_22_Glass") then
			part.Transparency = 0.75
			part.Color = Color3.fromRGB(170, 234, 211)
			part.Reflectance = 0.05
		end
		changed += 1
	elseif part.Name:match("^COL_") then
		part.Anchored = true
		part.Transparency = 1
		part.CanCollide = true
		part.CanTouch = true
		part.CanQuery = true
		if part:IsA("MeshPart") then
			part.CollisionFidelity = Enum.CollisionFidelity.Hull
		end
		changed += 1
	end
end
for _, root in Selection:Get() do
	configure(root)
	for _, item in root:GetDescendants() do
		configure(item)
	end
end
print("Configured Hyperbolic Time Chamber parts:", changed)
