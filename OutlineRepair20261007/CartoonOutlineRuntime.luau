local outlineCandidates = {}
local knownHighlights = {}
local outlineConnections = {}
local outlineClock = 1

local function outlineCandidate(object)
	if object:IsA("Model") and object:GetAttribute("PCOutlineStored") == true and object:IsDescendantOf(workspace) then
		outlineCandidates[object] = true
		local outline = object:FindFirstChild("CartoonOutline")
		if outline and outline:IsA("Highlight") then outline:SetAttribute("PCCosmeticManaged", true) end
	end
end

local function observeOutlineObject(object)
	if object:IsA("Highlight") then knownHighlights[object] = true end
	outlineCandidate(object)
end

for _, object in ipairs(game:GetDescendants()) do observeOutlineObject(object) end
table.insert(outlineConnections, game.DescendantAdded:Connect(observeOutlineObject))
table.insert(outlineConnections, game.DescendantRemoving:Connect(function(object)
	knownHighlights[object] = nil
end))

local function clearCosmeticOutline(model)
	local outline = model:FindFirstChild("CartoonOutline")
	if outline and outline:IsA("Highlight") and outline:GetAttribute("PCCosmeticManaged") == true then outline:Destroy() end
end

local function updateCartoonOutlines()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local external = 0
	for highlight in pairs(knownHighlights) do
		if not highlight.Parent then knownHighlights[highlight] = nil
		elseif highlight:GetAttribute("PCCosmeticManaged") ~= true then external += 1 end
	end
	local budget = math.clamp(239 - external, 0, 128)
	local candidates = {}
	for model in pairs(outlineCandidates) do
		if not model.Parent or not model:IsDescendantOf(workspace) then
			clearCosmeticOutline(model)
			outlineCandidates[model] = nil
		elseif model:GetAttribute("PCOutlineEnabled") ~= false then
			local position = model:GetPivot().Position
			local distance = (position - camera.CFrame.Position).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(position)
			local owner = model:GetAttribute("PetOwnerUserId")
			local tool = model:FindFirstAncestorOfClass("Tool")
			local localItem = owner == localPlayer.UserId or (tool and localPlayer.Character and tool:IsDescendantOf(localPlayer.Character))
			local score = localItem and -10000 or distance + (onScreen and 0 or 2000)
			if owner or tool then score -= 100 end
			table.insert(candidates, {model = model, score = score})
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	local wanted = {}
	for index = 1, math.min(budget, #candidates) do wanted[candidates[index].model] = true end
	for model in pairs(outlineCandidates) do
		if not wanted[model] then clearCosmeticOutline(model) end
	end
	for model in pairs(wanted) do
		local outline = model:FindFirstChild("CartoonOutline")
		if not outline then
			outline = Instance.new("Highlight")
			outline.Name = "CartoonOutline"
			outline:SetAttribute("PCCosmeticManaged", true)
			outline.Adornee = model
			outline.Parent = model
		end
		if outline:IsA("Highlight") then
			outline.Enabled = true
			outline.Adornee = model
			outline.FillTransparency = model:GetAttribute("PCOutlineFillTransparency") or 1
			outline.FillColor = model:GetAttribute("PCOutlineFillColor") or Color3.new(1, 1, 1)
			outline.OutlineTransparency = model:GetAttribute("PCOutlineTransparency") or 0
			outline.OutlineColor = model:GetAttribute("PCOutlineColor") or Color3.new(0, 0, 0)
			outline.DepthMode = model:GetAttribute("PCOutlineDepthMode") == "AlwaysOnTop" and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		end
	end
end

table.insert(outlineConnections, RunService.Heartbeat:Connect(function(delta)
	outlineClock += delta
	if outlineClock >= 0.25 then outlineClock = 0 updateCartoonOutlines() end
end))

local function releaseCartoonOutlines()
	for _, connection in ipairs(outlineConnections) do connection:Disconnect() end
	for model in pairs(outlineCandidates) do if model.Parent then clearCosmeticOutline(model) end end
	table.clear(outlineCandidates)
	table.clear(knownHighlights)
end
