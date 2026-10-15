local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage:WaitForChild("UnitsUIAssets"))
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
local Loadout = require(ReplicatedStorage:WaitForChild("Loadout"))
local Models = ReplicatedStorage:WaitForChild("UnitModels")

local UnitsUI = {}
local white = Color3.new(1, 1, 1)
local purple = Color3.fromRGB(166, 83, 255)
local selectedId
local tab = "collection"
local filter = "All"
local cards = {}
local gui, overlay, board, panel, gridBackground, grid, detail, empty
local titleText, secondaryName, portrait, tags, series, levelButton, xpText, xpClip
local equipButton, lockButton, search, filterMenu, popup, notice, status
local statValues = {}
local refresh, selectUnit, rebuild

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function bounds(object, x, y, width, height)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(width, height)
	return object
end

local function image(parent, name, asset, x, y, width, height, button)
	return bounds(make(button and "ImageButton" or "ImageLabel", name, parent, {
		BackgroundTransparency = 1, BorderSizePixel = 0, Image = Assets[asset],
		ScaleType = Enum.ScaleType.Stretch,
	}), x, y, width, height)
end

local function label(parent, name, text, x, y, width, height, size, align, button)
	local object = bounds(make(button and "TextButton" or "TextLabel", name, parent, {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
		Font = Enum.Font.PermanentMarker, TextSize = (size or 20) * 1.35,
		TextColor3 = white, TextStrokeColor3 = Color3.new(), TextStrokeTransparency = 1,
		TextXAlignment = align or Enum.TextXAlignment.Center,
	}), x, y, width, height)
	make("UIStroke", "TextOutline", object, {Color = Color3.new(), Thickness = math.max(1.5, (size or 20) / 15)})
	return object
end

local function outline(object, color, thickness)
	return make("UIStroke", "Outline", object, {
		Color = color, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function rounded(object, radius)
	make("UICorner", "Corners", object, {CornerRadius = UDim.new(0, radius)})
end

local function feedback(button)
	button.AutoButtonColor = false
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {ImageColor3 = Color3.fromRGB(225, 215, 255)}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {ImageColor3 = white}):Play()
	end)
end

local function preview(parent, unit, x, y, width, height)
	local viewport = bounds(make("ViewportFrame", "UnitModel", parent, {
		BackgroundTransparency = 1, BorderSizePixel = 0, Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = white, LightDirection = Vector3.new(-1, -1, -2),
	}), x, y, width, height)
	local template = Models:FindFirstChild(unit.model)
	if not template then
		label(viewport, "MissingModel", "Preview unavailable", 0, height / 2 - 14, width, 28, 15)
		return viewport
	end
	local world = make("WorldModel", "World", viewport)
	local model = template:Clone()
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
		elseif object:IsA("Script") or object:IsA("LocalScript") then
			object:Destroy()
		end
	end
	model.Parent = world
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local direction = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local forward = Vector3.new(direction.X, 0, direction.Z)
	if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
	forward = forward.Unit
	local cf, size = model:GetBoundingBox()
	local camera = make("Camera", "Camera", viewport, {FieldOfView = 34})
	local focus = cf.Position
	local aspect = width / height
	local halfHeight = math.max(size.Y / 2, math.max(size.X, size.Z) / (2 * aspect))
	local distance = halfHeight / math.tan(math.rad(camera.FieldOfView / 2)) + math.min(size.X, size.Z) / 2
	camera.CFrame = CFrame.lookAt(focus + forward * distance, focus)
	viewport.CurrentCamera = camera
	return viewport
end

local noticeVersion = 0
local function tell(message)
	noticeVersion += 1
	local version = noticeVersion
	notice.Text = message
	notice.Visible = true
	task.delay(3.5, function()
		if noticeVersion == version then notice.Visible = false end
	end)
end

local function clearPopup()
	for _, child in ipairs(popup:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	popup.Visible = false
end

local function popupButton(text, x, width, callback)
	local button = label(popup, text, text, x, 245, width, 42, 21, nil, true)
	button.BackgroundTransparency = 0
	button.BackgroundColor3 = Color3.fromRGB(72, 39, 110)
	rounded(button, 9)
	outline(button, purple, 1)
	button.Activated:Connect(callback)
	return button
end

local function chooseReplacement()
	clearPopup()
	popup.Visible = true
	label(popup, "Heading", "Choose a unit to replace", 15, 15, 590, 40, 28)
	label(popup, "Hint", "Your team is full (" .. Loadout.MAX .. "/" .. Loadout.MAX .. ")", 15, 55, 590, 28, 18)
	local incoming = selectedId
	for index, id in ipairs(Loadout.getAll()) do
		local unit = UnitData.get(id)
		if unit then
			local card = image(popup, "Replace_" .. id, "CardEquipped", 18 + (index - 1) * 146, 90, 140, 140, true)
			preview(card, unit, 15, 26, 110, 100)
			label(card, "Name", unit.name, 10, 9, 120, 25, 15)
			card.Activated:Connect(function()
				if incoming and PlayerData.unitUnlockState(incoming) == "owned" then Loadout.swap(id, incoming) end
				clearPopup()
			end)
		end
	end
	popupButton("Cancel", 220, 180, clearPopup)
end

local function tryLevel()
	if not selectedId then return end
	local unit = UnitData.get(selectedId)
	if not unit then return end
	if not PlayerData.unitReadyToLevel(selectedId, unit.rarity) then
		tell("Earn unit XP in battles to level up.")
		return
	end
	clearPopup()
	popup.Visible = true
	local id = selectedId
	local cost = PlayerData.unitLevelCost(PlayerData.unitLevel(id))
	label(popup, "Heading", "Level up " .. unit.name .. "?", 15, 30, 590, 45, 28)
	label(popup, "Cost", tostring(cost) .. " coins", 20, 105, 580, 38, 27)
	label(popup, "Increase", "Health and damage increase by 10%", 20, 153, 580, 35, 21)
	popupButton("Cancel", 85, 200, clearPopup)
	popupButton("Level up", 335, 200, function()
		local success = PlayerData.tryLevelUnit(id, unit.rarity)
		clearPopup()
		tell(success and "Unit leveled up!" or "Not enough coins or XP.")
	end)
end

local function updateLayout()
	local showing = selectedId ~= nil and tab == "collection"
	gridBackground.Image = Assets[showing and "InnerSelected" or "Inner"]
	gridBackground.Size = UDim2.fromOffset(showing and 466 or 1060, 486)
	detail.Visible = showing
	grid.Size = UDim2.new(1, -28, 1, -28)
	empty.Size = UDim2.new(1, -30, 1, -30)
end

local function matches(unit)
	local query = string.lower(search.Text):match("^%s*(.-)%s*$")
	local haystack = string.lower(table.concat({unit.name, unit.rarity, unit.type, table.concat(unit.lines, " "), unit.ability or ""}, " "))
	if query ~= "" and not string.find(haystack, query, 1, true) then return false end
	if filter == "All" then return true end
	if filter == "Equipped" then return Loadout.isEquipped(unit.id) end
	if filter == "Locked" then return PlayerData.isUnitLocked(unit.id) end
	return string.lower(unit.type) == string.lower(filter) or table.find(unit.lines, string.lower(filter)) ~= nil
end

refresh = function()
	status.Text = string.format("%d/%d equipped", Loadout.count(), Loadout.MAX)
	for id, card in pairs(cards) do
		card.Image = Assets[Loadout.isEquipped(id) and "CardEquipped" or "Card"]
		card.Selection.Enabled = id == selectedId
		card.Level.Text = "Level " .. PlayerData.unitLevel(id)
		card.Locked.Visible = PlayerData.isUnitLocked(id)
	end
	if not selectedId then return end
	local unit = UnitData.get(selectedId)
	if not unit then return end
	titleText.Text = unit.name
	secondaryName.Text = unit.name
	tags.Text = string.format("%s   %s   %s", unit.rarity, unit.type, table.concat(unit.lines, "/"))
	series.Text = unit.series or "Dragon Ball"
	local hp, damage = PlayerData.unitStats(selectedId, unit.health, unit.damage)
	local values = {tostring(hp), tostring(damage), string.format("%s [%d]", unit.range.category, unit.range.value),
		string.format("%gs", unit.hitSpeed), unit.damagePattern, unit.ability or "None"}
	for index, value in ipairs(values) do statValues[index].Text = value end
	local level = PlayerData.unitLevel(selectedId)
	local ready = PlayerData.unitReadyToLevel(selectedId, unit.rarity)
	levelButton.Text = ready and ("Level " .. level .. "  ↑") or ("Level " .. level)
	levelButton.TextColor3 = ready and Color3.fromRGB(255, 222, 80) or white
	local xp, needed = PlayerData.unitXpProgress(selectedId, unit.rarity)
	xpText.Text = needed and string.format("%d/%d XP", xp, needed) or "MAX LEVEL"
	xpClip.Size = UDim2.fromOffset(265 * (needed and math.clamp(xp / needed, 0, 1) or 1), 20)
	equipButton.Image = Assets[Loadout.isEquipped(selectedId) and "Equipped" or "Equip"]
	equipButton:SetAttribute("Equipped", Loadout.isEquipped(selectedId))
	lockButton.Image = Assets[PlayerData.isUnitLocked(selectedId) and "Locked" or "Unlocked"]
	lockButton:SetAttribute("Locked", PlayerData.isUnitLocked(selectedId))
	lockButton.ImageColor3 = PlayerData.isUnitLocked(selectedId) and Color3.fromRGB(255, 222, 100) or white
end

selectUnit = function(id)
	selectedId = id
	clearPopup()
	if portrait:FindFirstChild("UnitModel") then portrait.UnitModel:Destroy() end
	if id then
		local unit = UnitData.get(id)
		if unit then preview(portrait, unit, 14, 49, 202, 223) end
	end
	updateLayout()
	refresh()
end

rebuild = function()
	for _, card in pairs(cards) do card:Destroy() end
	table.clear(cards)
	if tab == "abilities" then
		empty.Text = "No abilities collected yet."
		empty.Visible = true
		updateLayout()
		return
	end
	local roster = {}
	local priority = {Yumcha = 1, Goku = 2, Krillen = 3, Tein = 4, MasterRoshu = 5}
	for id, unit in pairs(UnitData.all()) do
		if PlayerData.unitUnlockState(id) == "owned" and matches(unit) then table.insert(roster, unit) end
	end
	table.sort(roster, function(a, b)
		local pa, pb = priority[a.id] or 100, priority[b.id] or 100
		return pa == pb and a.name < b.name or pa < pb
	end)
	for index, unit in ipairs(roster) do
		local card = image(grid, "Unit_" .. unit.id, "Card", 0, 0, 138, 138, true)
		card.LayoutOrder = index
		card:SetAttribute("UnitId", unit.id)
		local selection = outline(card, white, 2)
		selection.Name = "Selection"
		selection.Enabled = false
		rounded(card, 16)
		preview(card, unit, 17, 26, 104, 98)
		local name = label(card, "Name", unit.name, 11, 10, 116, 22, 16)
		name.TextScaled = true
		make("UITextSizeConstraint", "TextLimit", name, {MaxTextSize = 22, MinTextSize = 10})
		label(card, "Level", "Level 1", 9, 113, 120, 19, 15)
		image(card, "Locked", "Locked", 91, 94, 34, 16).Visible = false
		card.Activated:Connect(function() selectUnit(unit.id) end)
		feedback(card)
		cards[unit.id] = card
	end
	empty.Text = "No units match your search or filter."
	empty.Visible = #roster == 0
	updateLayout()
	refresh()
end

function UnitsUI.close()
	if overlay then
		overlay.Visible = false
		filterMenu.Visible = false
		clearPopup()
		search:ReleaseFocus()
	end
end

function UnitsUI.open(playerGui)
	UnitsUI.build(playerGui)
	gui.Enabled = true
	overlay.Visible = true
	tab = "collection"
	filter = "All"
	search.Text = ""
	selectedId = nil
	filterMenu.Visible = false
	clearPopup()
	rebuild()
end

function UnitsUI.build(playerGui)
	if gui then return gui end
	gui = make("ScreenGui", "UnitsGui", playerGui, {
		ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	overlay = make("Frame", "Overlay", gui, {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, Active = true,
	})
	board = make("Frame", "Board", overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1280, 770), BackgroundTransparency = 1,
	})
	local scale = make("UIScale", "FitToScreen", board)
	local function resize()
		local size = overlay.AbsoluteSize
		scale.Scale = math.min(1.5, (size.X - 28) / 1280, (size.Y - 84) / 770)
	end
	overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	panel = image(board, "Panel", "Background", 140, 70, 1132, 689)
	local banner = image(board, "TitleBanner", "Title", 0, 0, 965, 159)
	banner.ZIndex = 3
	local heading = label(banner, "Heading", "Units", 195, 28, 360, 90, 76, Enum.TextXAlignment.Left)
	heading.Rotation = -3
	local close = image(panel, "Close", "Close", 1057, 27, 50, 51, true)
	close.Activated:Connect(UnitsUI.close)
	feedback(close)
	local collection = image(panel, "Collection", "Collection", 36, 94, 224, 62, true)
	local abilities = image(panel, "Abilities", "Abilities", 274, 94, 224, 62, true)
	local filterButton = image(panel, "Filter", "Filter", 512, 94, 148, 62, true)
	local searchBackground = image(panel, "Search", "Search", 674, 94, 422, 62)
	search = make("TextBox", "Input", searchBackground, {
		Position = UDim2.fromOffset(17, 4), Size = UDim2.new(1, -34, 1, -8),
		BackgroundTransparency = 1, Font = Enum.Font.PermanentMarker, TextSize = 48,
		TextColor3 = white, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(),
		PlaceholderText = "Search...", PlaceholderColor3 = white, Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	})
	gridBackground = image(panel, "CollectionBackground", "Inner", 36, 176, 1060, 486)
	grid = make("ScrollingFrame", "Grid", gridBackground, {
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = purple,
	})
	make("UIGridLayout", "Layout", grid, {
		CellSize = UDim2.fromOffset(138, 138), CellPadding = UDim2.fromOffset(9, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	empty = label(gridBackground, "EmptyState", "", 15, 15, 1030, 456, 24)
	empty.TextWrapped = true
	empty.Visible = false
	detail = bounds(make("Frame", "Detail", panel, {
		BackgroundColor3 = Color3.fromRGB(12, 9, 22), BorderSizePixel = 0, Visible = false,
	}), 520, 176, 576, 486)
	rounded(detail, 15)
	outline(detail, Color3.fromRGB(159, 170, 193), 2)
	local header = image(detail, "UnitTitle", "UnitTitle", 8, 8, 560, 82)
	titleText = label(header, "Name", "", 20, 6, 520, 65, 46)
	local back = image(panel, "Back", "Back", 1075, 164, 35, 36, true)
	back.ZIndex = 5
	back.Activated:Connect(function()
		if selectedId then selectUnit(nil) else UnitsUI.close() end
	end)
	feedback(back)
	portrait = image(detail, "Portrait", "Portrait", 8, 96, 230, 284)
	series = label(portrait, "Series", "", 9, 5, 212, 20, 16)
	series.TextColor3 = Color3.fromRGB(255, 213, 39)
	tags = label(portrait, "Tags", "", 9, 26, 212, 22, 14)
	tags.TextScaled = true
	make("UITextSizeConstraint", "TextLimit", tags, {MaxTextSize = 19, MinTextSize = 10})
	local brush = image(detail, "NameBrush", "Name", 245, 103, 315, 51)
	secondaryName = label(brush, "Name", "", 4, 4, 307, 40, 32)
	local rows = {{"Health", "Health"}, {"Damage", "Damage"}, {"Range", "Range"},
		{"Hit Speed", "Speed"}, {"Attack Pattern", "Pattern"}, {"Ability", "Ability"}}
	for index, row in ipairs(rows) do
		local background = image(detail, row[2] .. "Row", row[2], 245, 152 + (index - 1) * 38, 315, 36)
		label(background, "Label", row[1], 0, 0, 180, 34, index == 5 and 17 or 19, Enum.TextXAlignment.Left)
		local value = label(background, "Value", "", 168, 0, 139, 34, 20, Enum.TextXAlignment.Right)
		value.TextScaled = true
		make("UITextSizeConstraint", "TextLimit", value, {MaxTextSize = 27, MinTextSize = 11})
		statValues[index] = value
	end
	lockButton = image(detail, "Lock", "Unlocked", 10, 386, 52, 24, true)
	lockButton.Activated:Connect(function()
		if selectedId then
			local locked = not PlayerData.isUnitLocked(selectedId)
			PlayerData.setUnitLocked(selectedId, locked)
			tell(locked and "Unit locked." or "Unit unlocked.")
		end
	end)
	levelButton = label(detail, "Level", "Level 1", 65, 383, 171, 30, 22, nil, true)
	levelButton.Activated:Connect(tryLevel)
	local xpTrack = image(detail, "XPTrack", "XP", 295, 388, 265, 20)
	xpTrack.ImageColor3 = Color3.fromRGB(110, 85, 140)
	xpClip = bounds(make("Frame", "Progress", xpTrack, {
		BackgroundTransparency = 1, ClipsDescendants = true,
	}), 0, 0, 0, 20)
	local xpFill = image(xpClip, "Fill", "XP", 0, 0, 265, 20)
	xpFill.ImageColor3 = white
	xpFill.Image = Assets.XP
	xpText = label(xpTrack, "Value", "", 0, -5, 265, 28, 20)
	local mastery = image(detail, "Mastery", "Mastery", 8, 414, 265, 62, true)
	mastery.AutoButtonColor = false
	equipButton = image(detail, "Equip", "Equip", 295, 414, 265, 62, true)
	feedback(equipButton)
	equipButton.Activated:Connect(function()
		if not selectedId or PlayerData.unitUnlockState(selectedId) ~= "owned" then return end
		if Loadout.isEquipped(selectedId) then
			Loadout.unequip(selectedId)
		elseif Loadout.isFull() then
			chooseReplacement()
		else
			Loadout.equip(selectedId)
		end
	end)
	status = label(panel, "TeamCount", "", 778, 663, 309, 22, 16, Enum.TextXAlignment.Right)
	filterMenu = bounds(make("Frame", "Filters", panel, {
		BackgroundColor3 = Color3.fromRGB(35, 20, 59), BorderSizePixel = 0, Visible = false, ZIndex = 10,
	}), 512, 161, 246, 372)
	rounded(filterMenu, 12)
	outline(filterMenu, purple, 2)
	for index, option in ipairs({"All", "Equipped", "Locked", "Front", "Mid", "Back", "Melee", "Ranged", "Energy", "Tank", "Artillery"}) do
		local item = label(filterMenu, "Filter_" .. option, option, 12, 7 + (index - 1) * 32, 222, 31, 21, Enum.TextXAlignment.Left, true)
		item.Activated:Connect(function()
			filter = option
			filterMenu.Visible = false
			filterButton.ImageColor3 = option == "All" and white or Color3.fromRGB(196, 141, 255)
			rebuild()
		end)
	end
	filterButton.Activated:Connect(function() filterMenu.Visible = not filterMenu.Visible end)
	collection.Activated:Connect(function()
		tab = "collection"
		selectUnit(nil)
		rebuild()
	end)
	abilities.Activated:Connect(function()
		tab = "abilities"
		selectedId = nil
		filterMenu.Visible = false
		clearPopup()
		rebuild()
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if overlay.Visible then rebuild() end
	end)
	popup = bounds(make("Frame", "Popup", board, {
		BackgroundColor3 = Color3.fromRGB(24, 14, 40), BorderSizePixel = 0, Visible = false, ZIndex = 20,
	}), 360, 250, 620, 310)
	rounded(popup, 16)
	outline(popup, purple, 3)
	notice = label(board, "Notice", "", 250, 191, 950, 38, 24)
	notice.BackgroundColor3 = Color3.fromRGB(22, 12, 37)
	notice.BackgroundTransparency = 0.08
	notice.ZIndex = 30
	notice.Visible = false
	rounded(notice, 10)
	Loadout.Changed:Connect(function()
		if filter == "Equipped" then rebuild() else refresh() end
	end)
	PlayerData.Changed:Connect(function()
		if overlay.Visible then rebuild() end
	end)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then UnitsUI.close() end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not overlay.Visible then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if popup.Visible then clearPopup()
			elseif filterMenu.Visible then filterMenu.Visible = false
			elseif selectedId then selectUnit(nil)
			else UnitsUI.close() end
		end
	end)
	task.spawn(function()
		local images = {}
		for _, asset in pairs(Assets) do table.insert(images, asset) end
		pcall(function() ContentProvider:PreloadAsync(images) end)
	end)
	refresh()
	return gui
end

return UnitsUI
