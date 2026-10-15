return function(assets, plan)
	assert(not game:GetService("RunService"):IsRunning(), "Screen skins must be authored in Edit mode")
	local StarterGui = game:GetService("StarterGui")
	local HttpService = game:GetService("HttpService")
	local report = { skins = 0, captions = 0, textOutlines = 0, icons = 0, libraryAssets = 0, removedArtwork = 0, hiddenShadows = 0, nativeColourFills = 0, missingIcons = {} }
	local roots = {}
	local styledText = {}
	local mappings = plan.mappings or {}
	local mappingByPath = {}
	for _, mapping in ipairs(mappings) do mappingByPath[mapping.path] = mapping end
	local textInk = Color3.fromRGB(24, 30, 51)
	local textFill = Color3.fromRGB(255, 249, 224)

	local function resolve(path)
		local current = game
		for segment in string.gmatch(path, "[^.]+") do
			if segment ~= "game" then
				current = current and current:FindFirstChild(segment)
			end
		end
		return current
	end

	local function imageId(key)
		local value = assets[key]
		if typeof(value) == "table" then value = value.imageId or value.assetId or value.id or value.image or value.contentUri end
		if typeof(value) == "number" then return "rbxassetid://" .. tostring(value) end
		assert(typeof(value) == "string" and value ~= "", "Missing uploaded image: " .. tostring(key))
		if string.match(value, "^%d+$") then return "rbxassetid://" .. value end
		return value
	end

	local function rememberRoot(target)
		local root = target:FindFirstAncestorOfClass("ScreenGui")
		if root then roots[root] = true end
	end

	for _, mapping in ipairs(mappings) do
		local target = assert(resolve(mapping.path), "Skin target is missing: " .. mapping.path)
		assert(target:IsA("GuiObject"), "Skin target is not a GuiObject: " .. mapping.path)
		imageId(mapping.asset)
		for _, key in pairs(mapping.variantAssets or {}) do imageId(key) end
		rememberRoot(target)
	end
	for _, mapping in ipairs(plan.meterFills or {}) do
		local target = assert(resolve(mapping.path), "Meter target is missing: " .. mapping.path)
		assert(target:IsA("GuiObject"), "Meter target is not a GuiObject: " .. mapping.path)
		imageId(mapping.asset)
		rememberRoot(target)
	end

	local function muteStrokes(target)
		for _, child in ipairs(target:GetChildren()) do
			if child:IsA("UIStroke") then child.Transparency = 1 end
		end
	end

	local function styleText(target)
		if not target:IsA("TextLabel") and not target:IsA("TextButton") then return end
		if target:GetAttribute("UISkinHiddenText") == true then
			target.TextTransparency = 1
			target.TextStrokeTransparency = 1
			muteStrokes(target)
			return
		end
		muteStrokes(target)
		target.Font = Enum.Font.FredokaOne
		target.TextColor3 = textFill
		target.TextTransparency = 0
		target.TextStrokeTransparency = 1
		local stroke = target:FindFirstChild("TextOutline")
		if stroke and not stroke:IsA("UIStroke") then stroke:Destroy() stroke = nil end
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "TextOutline"
			stroke.Parent = target
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Thickness = 0.085
		stroke.Color = textInk
		stroke.Transparency = 0
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Enabled = true
		if not styledText[target] then styledText[target] = true report.textOutlines += 1 end
	end

	for root in pairs(roots) do
		for _, object in ipairs(root:GetDescendants()) do
			if object.Parent then
				if object.Name == "UserArtwork" or object.Name == "TextlessSkin" or object.Name == "LiveCaption" or object.Name == "UserArtworkController" then
					object:Destroy()
					report.removedArtwork += 1
				elseif object:IsA("GuiObject") and object.Name == "Shadow" then
					object.Visible = false
					report.hiddenShadows += 1
				end
			end
		end
	end
	for _, path in ipairs(plan.clearShadows or {}) do
		local shadow = resolve(path)
		if shadow and shadow:IsA("GuiObject") then shadow.Visible = false end
	end
	for _, path in ipairs(plan.clearIconFallbacks or {}) do
		local fallback = resolve(path)
		if fallback and fallback:IsA("GuiObject") then fallback.Visible = false end
	end

	local function configureImage(image, mapping)
		image.Image = imageId(mapping.asset)
		image.ImageColor3 = Color3.new(1, 1, 1)
		image.ImageTransparency = 0
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Active = false
		image.Selectable = false
		image:SetAttribute("AssetKey", mapping.asset)
		image:SetAttribute("DefaultImage", image.Image)
		image:SetAttribute("UISkinTargetPath", mapping.path)
		image.ScaleType = mapping.mode == "Slice" and Enum.ScaleType.Slice or mapping.mode == "Stretch" and Enum.ScaleType.Stretch or Enum.ScaleType.Fit
		if mapping.sliceCenter then
			local rect = mapping.sliceCenter
			image.SliceCenter = Rect.new(rect[1], rect[2], rect[3], rect[4])
			image.SliceScale = mapping.sliceScale or 0.25
		end
		for colour, key in pairs(mapping.variantAssets or {}) do image:SetAttribute(colour .. "Image", imageId(key)) end
	end

	local function captionBounds(caption, target, mapping)
		local rect = mapping.textFaceRect or { 0.065, 0.078, 0.87, 0.78 }
		caption.AnchorPoint = Vector2.zero
		caption.Position = UDim2.fromScale(rect[1], rect[2])
		caption.Size = UDim2.fromScale(rect[3], rect[4])
		caption.BackgroundTransparency = 1
		caption.BorderSizePixel = 0
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.TextYAlignment = Enum.TextYAlignment.Center
		caption.TextScaled = true
		caption.TextWrapped = true
		caption.ZIndex = math.max(caption.ZIndex, target.ZIndex + 2)
		local constraint = caption:FindFirstChildOfClass("UITextSizeConstraint")
		if not constraint then constraint = Instance.new("UITextSizeConstraint") constraint.Parent = caption end
		local height = target.AbsoluteSize.Y > 0 and target.AbsoluteSize.Y or math.max(target.Size.Y.Offset, 48)
		local multiline = string.find(caption.Text, "\n", 1, true) ~= nil
		constraint.MinTextSize = 8
		constraint.MaxTextSize = math.clamp(math.floor(height * (multiline and 0.5 or 0.6)), 12, multiline and 24 or 26)
		styleText(caption)
	end

	local function applySkin(mapping)
		local target = resolve(mapping.path)
		if mapping.colourPolicy == "PreserveNativeFill" then
			local old = target:FindFirstChild("ReusableSkin")
			if old then old:Destroy() end
			target:SetAttribute("UISkinManaged", nil)
			target:SetAttribute("UISkinColourPolicy", "PreserveNativeFill")
			target.BackgroundTransparency = 0
			report.nativeColourFills += 1
			return
		end
		target.BackgroundTransparency = 1
		target.BorderSizePixel = 0
		muteStrokes(target)
		local previous = target:FindFirstChild("ReusableSkin")
		if previous then previous:Destroy() end
		local image = Instance.new("ImageLabel")
		image.Name = "ReusableSkin"
		configureImage(image, mapping)
		if target:IsA("ViewportFrame") then
			local name = target.Name .. "ReusableSkin"
			local oldBackground = target.Parent:FindFirstChild(name)
			if oldBackground and oldBackground:GetAttribute("UISkinTargetPath") == mapping.path then oldBackground:Destroy() end
			image.Name = name
			image.Position = target.Position
			image.Size = target.Size
			image.AnchorPoint = target.AnchorPoint
			image.Rotation = target.Rotation
			image.LayoutOrder = target.LayoutOrder
			image.ZIndex = math.max(1, target.ZIndex - 1)
			if target.ZIndex <= image.ZIndex then target.ZIndex = image.ZIndex + 1 end
			image.Visible = target.Visible
			image.Parent = target.Parent
			target:SetAttribute("UISkinManaged", nil)
		else
			for _, child in ipairs(target:GetChildren()) do
				if child:IsA("GuiObject") and child.ZIndex <= target.ZIndex then
					local shift = target.ZIndex + 1 - child.ZIndex
					child.ZIndex += shift
					for _, descendant in ipairs(child:GetDescendants()) do
						if descendant:IsA("GuiObject") then descendant.ZIndex += shift end
					end
				end
			end
			image.Size = UDim2.fromScale(1, 1)
			image.Position = UDim2.fromScale(0, 0)
			image.AnchorPoint = Vector2.zero
			image.ZIndex = target.ZIndex
			image.Parent = target
			target:SetAttribute("UISkinManaged", true)
			target:SetAttribute("UISkinDynamic", mapping.dynamic == true)
		end
		target:SetAttribute("UISkinAssetKey", mapping.asset)
		local progress = target:FindFirstChild("Progress")
		if progress and progress:IsA("UIGradient") then progress:Clone().Parent = image end
		local caption = target:FindFirstChild("Caption")
		if caption and caption:IsA("TextLabel") then
			caption.Visible = true
			captionBounds(caption, target, mapping)
			if target:IsA("TextButton") or target:IsA("TextLabel") then
				target:SetAttribute("UISkinHiddenText", true)
				target.TextTransparency = 1
				target.TextStrokeTransparency = 1
			end
		elseif target:IsA("TextButton") or target:IsA("TextLabel") then
			caption = Instance.new("TextLabel")
			caption.Name = "LiveCaption"
			caption.Text = target.Text
			caption.RichText = target.RichText
			caption.Visible = true
			caption.Parent = target
			captionBounds(caption, target, mapping)
			target.TextColor3 = textFill
			target:SetAttribute("UISkinHiddenText", true)
			target.TextTransparency = 1
			target.TextStrokeTransparency = 1
			report.captions += 1
		end
		target:SetAttribute("UISkinSelectionFromColour", mapping.selectionFromColour == true)
		target:SetAttribute("UISkinSelectionFromOutline", mapping.selectionFromOutline == true)
		if mapping.selectionFromColour or mapping.selectionFromOutline then
			local selection = target:FindFirstChild("SelectionMark")
			if selection and not selection:IsA("TextLabel") then selection:Destroy() selection = nil end
			if not selection then selection = Instance.new("TextLabel") selection.Name = "SelectionMark" selection.Parent = target end
			selection.AnchorPoint = Vector2.new(1, 0)
			selection.Position = UDim2.new(1, -5, 0, 4)
			selection.Size = UDim2.fromOffset(18, 18)
			selection.BackgroundTransparency = 1
			selection.Text = "✓"
			selection.TextScaled = true
			selection.ZIndex = target.ZIndex + 3
			selection.Visible = false
			styleText(selection)
		end
		report.skins += 1
	end

	for _, mapping in ipairs(mappings) do applySkin(mapping) end
	for _, mapping in ipairs(plan.meterFills or {}) do applySkin(mapping) end

	local function applyIcon(mapping)
		local target = resolve(mapping.path)
		if not target or not target:IsA("GuiObject") then
			table.insert(report.missingIcons, mapping.path)
			return
		end
		local image
		if not mapping.createChild and (target:IsA("ImageLabel") or target:IsA("ImageButton")) then
			image = target
		else
			local childName = mapping.childName or "ReusableIcon"
			local old = target:FindFirstChild(childName)
			if old then old:Destroy() end
			image = Instance.new("ImageLabel")
			image.Name = childName
			local rect = mapping.imageRect or (mapping.replaceBackground and { 0, 0, 1, 1 }) or { 0.14, 0.10, 0.72, 0.72 }
			image.AnchorPoint = Vector2.zero
			image.Position = UDim2.fromScale(rect[1], rect[2])
			image.Size = UDim2.fromScale(rect[3], rect[4])
			image.ZIndex = target.ZIndex + 2
			image.Parent = target
			if target:IsA("TextLabel") or target:IsA("TextButton") then
				target:SetAttribute("UISkinHiddenText", true)
				target.TextTransparency = 1
				target.TextStrokeTransparency = 1
				muteStrokes(target)
			end
			local caption = target:FindFirstChild("LiveCaption")
			if caption and caption:IsA("GuiObject") then caption.Visible = false end
		end
		configureImage(image, { asset = mapping.asset, mode = "Fit", path = mapping.path })
		image.Visible = true
		if mapping.replaceBackground then
			target.BackgroundTransparency = 1
			muteStrokes(target)
			local skin = target:FindFirstChild("ReusableSkin")
			if skin then skin:Destroy() end
		end
		for _, path in ipairs(mapping.clearText or {}) do
			local label = resolve(path)
			if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
				label:SetAttribute("UISkinHiddenText", true)
				label.TextTransparency = 1
				label.TextStrokeTransparency = 1
				label.Visible = false
				muteStrokes(label)
			end
		end
		local iconParent = target.Parent
		if target.Name == "Icon" and iconParent:IsA("GuiButton") then
			target.Visible = true
			local fallback = iconParent:FindFirstChild("IconFallback")
			if fallback and fallback:IsA("GuiObject") then fallback.Visible = false end
			local caption = iconParent:FindFirstChild("Caption") or iconParent:FindFirstChild("LiveCaption")
			if caption and caption:IsA("TextLabel") then
				local face = mappingByPath[iconParent:GetFullName()]
				local rect = face and face.textFaceRect or { 0.065, 0.078, 0.87, 0.78 }
				target.AnchorPoint = Vector2.new(0, 0.5)
				target.Position = UDim2.fromScale(rect[1], rect[2] + rect[4] * 0.5)
				target.Size = UDim2.fromScale(rect[3] * 0.17, rect[4] * 0.7)
				caption.Position = UDim2.fromScale(rect[1] + rect[3] * 0.22, rect[2])
				caption.Size = UDim2.fromScale(rect[3] * 0.78, rect[4])
			end
		end
		report.icons += 1
	end
	for _, mapping in ipairs(plan.icons or {}) do applyIcon(mapping) end

	for root in pairs(roots) do
		for _, object in ipairs(root:GetDescendants()) do styleText(object) end
	end

	local shell = assert(StarterGui:FindFirstChild("PlaygroundShell"), "PlaygroundShell is missing")
	local templates = assert(shell:FindFirstChild("Templates"), "Editable templates are missing")
	local oldLibrary = templates:FindFirstChild("AssetLibrary")
	if oldLibrary then
		assert(oldLibrary:GetAttribute("UISkinAssetLibrary") == true, "Preserve the existing unrecognised AssetLibrary")
		oldLibrary:Destroy()
	end
	local library = Instance.new("Folder")
	library.Name = "AssetLibrary"
	library:SetAttribute("UISkinAssetLibrary", true)
	library.Parent = templates
	local byImage = {}
	local allKeys = {}
	for key in pairs(assets) do table.insert(allKeys, key) end
	table.sort(allKeys)
	for _, key in ipairs(allKeys) do
		local id = imageId(key)
		if not byImage[id] then byImage[id] = {} end
		table.insert(byImage[id], key)
	end
	local metadata = plan.libraryAssets or {}
	local metadataByKey = {}
	for key, entry in pairs(metadata) do
		if typeof(key) == "string" then metadataByKey[key] = entry
		elseif typeof(entry) == "table" then
			local assetKey = entry.asset or entry.key or entry.png
			if assetKey then metadataByKey[assetKey] = entry end
		end
	end
	local groups = {}
	for id, aliases in pairs(byImage) do table.insert(groups, { id = id, aliases = aliases }) end
	table.sort(groups, function(a, b) return a.aliases[1] < b.aliases[1] end)
	for _, group in ipairs(groups) do
		local key = group.aliases[1]
		local data = metadataByKey[key] or {}
		local sample = Instance.new("ImageLabel")
		sample.Name = string.gsub(string.gsub(key, "%.png$", ""), "[/\\]", "__")
		configureImage(sample, { asset = key, mode = data.mode or "Fit", sliceCenter = data.sliceCenter, sliceScale = data.sliceScale })
		local size = data.logicalSize
		local width = size and size[1] or data.width and data.width / 4 or 128
		local height = size and size[2] or data.height and data.height / 4 or 80
		sample.Size = UDim2.fromOffset(width, height)
		sample.Visible = false
		sample:SetAttribute("Aliases", HttpService:JSONEncode(group.aliases))
		if data.width then sample:SetAttribute("SourceWidth", data.width) end
		if data.height then sample:SetAttribute("SourceHeight", data.height) end
		sample.Parent = library
		report.libraryAssets += 1
	end
	return report
end
