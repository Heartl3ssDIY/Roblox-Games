local Selection = game:GetService("Selection")
local changed = 0
local function configure(part)
	if not part:IsA("BasePart") then
		return
	end
	if part.Name:match("^WA_") then
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
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
print("Configured Wano arena parts:", changed)
