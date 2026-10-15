function Service:_propTemplates()
	local folder = ReplicatedStorage:FindFirstChild("SchoolPropTemplates")
	local result = {}
	if not folder then return result end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("HSPropEligible") == true
			and type(model:GetAttribute("HSPropId")) == "string" then
			local _, size = model:GetBoundingBox()
			local label = string.lower(model.Name .. " " .. tostring(model:GetAttribute("DisplayName") or ""))
			local forbidden = label:find("pencil", 1, true) or label:find("wardrobe", 1, true)
				or label:find("drawer", 1, true) or label:find("cupboard", 1, true) or label:find("tray", 1, true)
			if not forbidden and size.Y >= 1.4 and math.max(size.X, size.Z) >= 1.8
				and size.X * size.Y * size.Z >= 4 and math.max(size.X, size.Y, size.Z) <= 8
				and model:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(result, model)
			end
		end
	end
	table.sort(result, function(first, second) return first.Name < second.Name end)
	return result
end

function Service:_concealPropAvatar(record, added)
	local saved = record.propMorph
	if not saved or saved.character ~= record.character then return end
	local objects = added and { added } or record.character:GetDescendants()
	for _, object in ipairs(objects) do
		if object ~= saved.model and not object:IsDescendantOf(saved.model) then
			local property, value
			if object:IsA("BasePart") or object:IsA("Decal") then property, value = "Transparency", 1
			elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
				or object:IsA("Highlight") or object:IsA("BillboardGui") or object:IsA("SurfaceGui")
				or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles") then
				property, value = "Enabled", false
			end
			if property then
				if not saved.visuals[object] then saved.visuals[object] = { property = property, value = object[property] } end
				object[property] = value
			end
		end
	end
end

function Service:_restorePropMorph(record)
	local saved = record.propMorph
	record.propMorph = nil
	if saved then
		for object, original in pairs(saved.visuals) do
			if object.Parent then object[original.property] = original.value end
		end
		if saved.model then saved.model:Destroy() end
		if saved.character.Parent then
			attribute(saved.character, "HSPropMorphed", false)
			attribute(saved.character, "HSPropId", "")
		end
	end
	attribute(record.player, "HSPropMorphed", false)
	attribute(record.player, "HSPropId", "")
	attribute(record.player, "HSPropName", "")
end

function Service:_applyPropMorph(record)
	if not alive(record) or record.role ~= "Hider" then return false end
	self:_restorePropMorph(record)
	local options = self:_propTemplates()
	if #options == 0 then return false end
	local template = options[self.random:NextInteger(1, #options)]
	local model
	local ok, failure = xpcall(function()
		model = template:Clone()
		assert(model, "School prop could not be cloned")
		model.Name = "SchoolPropMorph"
		model.PrimaryPart = nil
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("LuaSourceContainer") or object:IsA("Humanoid") or object:IsA("AnimationController")
				or object:IsA("ProximityPrompt") or object:IsA("ClickDetector") or object:IsA("JointInstance")
				or object:IsA("Constraint") then object:Destroy() end
		end
		model:PivotTo(CFrame.identity)
		local box, size = model:GetBoundingBox()
		local leg = record.character:FindFirstChild("Left Leg") or record.character:FindFirstChild("Right Leg")
		local legHeight = record.humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") and leg.Size.Y or 0
		local floorOffset = record.humanoid.HipHeight + legHeight + record.root.Size.Y * 0.5
		local bottom = CFrame.new(box.Position.X, box.Position.Y - size.Y * 0.5, box.Position.Z)
		model:PivotTo(record.root.CFrame * CFrame.new(0, -floorOffset, 0) * bottom:Inverse() * model:GetPivot())
		local count = 0
		for _, object in ipairs(model:GetDescendants()) do
			if object:IsA("BasePart") then
				object.Anchored, object.Massless = false, true
				object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
				if object:IsA("Seat") or object:IsA("VehicleSeat") then object.Disabled = true end
				local weld = Instance.new("WeldConstraint")
				weld.Name, weld.Part0, weld.Part1, weld.Parent = "SchoolPropWeld", record.root, object, object
				count += 1
			end
		end
		assert(count > 0, "School prop has no visible parts")
		local outline = Instance.new("Highlight")
		outline.Name, outline.Adornee = "SchoolPropOutline", model
		outline.FillTransparency, outline.OutlineTransparency = 1, 0
		outline.OutlineColor = Color3.new(0, 0, 0)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
		record.propMorph = { model = model, character = record.character, visuals = {} }
		model.Parent = record.character
		self:_concealPropAvatar(record)
		attribute(record.player, "HSPropMorphed", true)
		attribute(record.player, "HSPropId", template:GetAttribute("HSPropId"))
		attribute(record.player, "HSPropName", template:GetAttribute("DisplayName") or template.Name)
		attribute(record.character, "HSPropMorphed", true)
		attribute(record.character, "HSPropId", template:GetAttribute("HSPropId"))
	end, debug.traceback)
	if not ok then
		self:_restorePropMorph(record)
		if model then model:Destroy() end
		warn("School prop could not prepare a hider: " .. tostring(failure))
	end
	return ok
end

