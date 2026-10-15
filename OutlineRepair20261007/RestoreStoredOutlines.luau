assert(not game.RunService:IsRunning(), "Edit mode required")
local backup = assert(game.ServerStorage:FindFirstChild("OutlinePropertyBackup20261007"))
local count = 0
for _, record in ipairs(backup:GetChildren()) do
	local model = record.Owner.Value
	assert(model and model:IsA("Model"), "Original model missing")
	local name = record:GetAttribute("OriginalName")
	if not model:FindFirstChild(name) then
		local h = Instance.new("Highlight")
		h.Name, h.Adornee = name, model
		h.DepthMode = Enum.HighlightDepthMode[record:GetAttribute("DepthMode")]
		for _, field in ipairs({"Enabled", "FillColor", "FillTransparency", "OutlineColor", "OutlineTransparency"}) do h[field] = record:GetAttribute(field) end
		for key, value in pairs(record.OriginalAttributes:GetAttributes()) do h:SetAttribute(key, value) end
		h.Parent = model
		count += 1
	end
end
return "Restored " .. count .. " original stored outlines"
