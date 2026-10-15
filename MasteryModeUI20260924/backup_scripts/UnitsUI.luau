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
local PreviewAnimator = require(ReplicatedStorage:WaitForChild("UnitPreviewAnimator"))

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
local collectionSize, xpFullSize
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

local function preview(parent, unit, x, y, width, height, combo)
	local viewport = parent:FindFirstChild("UnitModel") or bounds(make("ViewportFrame", "UnitModel", parent, {
		BackgroundTransparency = 1, BorderSizePixel = 0, Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = white, LightDirection = Vector3.new(-1, -1, -2),
	}), x, y, width, height)
	for _, child in ipairs(viewport:GetChildren()) do
        if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
    end
    viewport.Visible = true
    local template = Models:FindFirstChild(unit.model)
	if not template then
		label(viewport, "MissingModel", "Preview unavailable", 0, height / 2 - 14, width, 28, 15)
		return viewport
	end
	local world = make("WorldModel", "World", viewport)
	local model = template:Clone()
	local anchor = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Anchored = object == anchor
			object.CanCollide = false
			object.Massless = true
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
	local aspect = viewport.Size.X.Offset / math.max(1, viewport.Size.Y.Offset)
	local halfHeight = math.max(size.Y / 2, math.max(size.X, size.Z) / (2 * aspect))
	local distance = halfHeight / math.tan(math.rad(camera.FieldOfView / 2)) + math.min(size.X, size.Z) / 2
	local right = forward:Cross(Vector3.yAxis)
	camera.CFrame = CFrame.lookAt(focus + (forward + right * 0.28 + Vector3.yAxis * 0.035).Unit * distance * 1.1, focus)
	viewport.CurrentCamera = camera
	PreviewAnimator.attach(viewport, model)
	if combo then PreviewAnimator.playCombo(viewport) end
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
	gridBackground.Size = showing and UDim2.new(collectionSize.X.Scale, gridBackground:GetAttribute("SelectedWidth") or 466, collectionSize.Y.Scale, collectionSize.Y.Offset) or collectionSize
	detail.Visible = showing
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
	local progress = needed and math.clamp(xp / needed, 0, 1) or 1
    xpClip.Size = UDim2.new(xpFullSize.X.Scale * progress, xpFullSize.X.Offset * progress, xpFullSize.Y.Scale, xpFullSize.Y.Offset)
	equipButton.Image = Assets[Loadout.isEquipped(selectedId) and "Equipped" or "Equip"]
	equipButton:SetAttribute("Equipped", Loadout.isEquipped(selectedId))
	lockButton.Image = Assets[PlayerData.isUnitLocked(selectedId) and "Locked" or "Unlocked"]
	lockButton:SetAttribute("Locked", PlayerData.isUnitLocked(selectedId))
	lockButton.ImageColor3 = PlayerData.isUnitLocked(selectedId) and Color3.fromRGB(255, 222, 100) or white
end

selectUnit = function(id)
	selectedId = id
	clearPopup()
	local existing = portrait:FindFirstChild("UnitModel")
    if existing then
        for _, child in ipairs(existing:GetChildren()) do
            if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
        end
        existing.Visible = id ~= nil
    end
	if id then
		local unit = UnitData.get(id)
		if unit then preview(portrait, unit, 14, 49, 202, 223, true) end
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
		local card = gui.Templates.UnitCard:Clone()
        card.Name = "Unit_" .. unit.id
        card.LayoutOrder = index
        card.Visible = true
        card:SetAttribute("UnitId", unit.id)
        card.Parent = grid
        card.Selection.Enabled = false
        preview(card, unit, 17, 26, 104, 98)
        card:WaitForChild("Name").Text = unit.name
        card.Level.Text = "Level " .. PlayerData.unitLevel(unit.id)
        card.Locked.Visible = PlayerData.isUnitLocked(unit.id)
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
		gui.Enabled = false
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
    gui = playerGui:WaitForChild("UnitsGui")
    overlay = gui.Overlay
    board = overlay.Board
    panel = board.Panel
    gridBackground = panel.CollectionBackground
    grid = gridBackground.Grid
    empty = gridBackground.EmptyState
    detail = panel.Detail
    titleText = detail.UnitTitle:WaitForChild("Name")
    secondaryName = detail.NameBrush:WaitForChild("Name")
    portrait = detail.Portrait
    series = portrait.Series
    tags = portrait.Tags
    levelButton = detail.Level
    xpText = detail.XPTrack.Value
    xpClip = detail.XPTrack.Progress
    equipButton = detail.Equip
    lockButton = detail.Lock
    search = panel.Search.Input
    filterMenu = panel.Filters
    popup = board.Popup
    notice = board.Notice
    status = panel.TeamCount
    local collection = panel.Collection
    local abilities = panel.Abilities
    local filterButton = panel.Filter
    collectionSize = gridBackground.Size
    xpFullSize = xpClip.Size
    for index, name in ipairs({"Health", "Damage", "Range", "Speed", "Pattern", "Ability"}) do
        statValues[index] = detail[name .. "Row"].Value
    end
    local scale = board.FitToScreen
    local baseScale = scale.Scale
    local function resize()
        if gui:GetAttribute("AutoFit") == false then return end
        local size = overlay.AbsoluteSize
        local width = math.max(1, board.Size.X.Offset)
        local height = math.max(1, board.Size.Y.Offset)
        scale.Scale = math.min(baseScale, (size.X - 28) / width, (size.Y - 28) / height)
    end
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    panel.Close.Activated:Connect(UnitsUI.close)
    panel.Back.Activated:Connect(function()
        if selectedId then selectUnit(nil) else UnitsUI.close() end
    end)
    portrait.ReplayCombo.Activated:Connect(function()
        local viewport = portrait:FindFirstChild("UnitModel")
        if viewport then PreviewAnimator.playCombo(viewport) end
    end)
    lockButton.Activated:Connect(function()
        if selectedId then
            local locked = not PlayerData.isUnitLocked(selectedId)
            PlayerData.setUnitLocked(selectedId, locked)
            tell(locked and "Unit locked." or "Unit unlocked.")
        end
    end)
    levelButton.Activated:Connect(tryLevel)
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
    for _, item in ipairs(filterMenu:GetChildren()) do
        if item:IsA("TextButton") then
            local option = item.Name:sub(8)
            item.Activated:Connect(function()
                filter = option
                filterMenu.Visible = false
                filterButton.ImageColor3 = option == "All" and white or Color3.fromRGB(196, 141, 255)
                rebuild()
            end)
        end
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
    overlay.Visible = true
    gui.Enabled = false
    filterMenu.Visible = false
    popup.Visible = false
    notice.Visible = false
    refresh()
    return gui
end

return UnitsUI
