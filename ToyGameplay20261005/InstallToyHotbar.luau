return function(controllerSource, dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	assert(typeof(controllerSource) == "string" and #controllerSource > 100, "Toy hotbar controller source is required")
	local starter = game:GetService("StarterGui")
	local shell = starter:WaitForChild("PlaygroundShell")
	local sourceController = starter.BritishBulldogHUD:WaitForChild("MovementController")
	local cardSkin = shell.ShopPanel.Cards.Slot01:WaitForChild("ReusableSkin")
	local report = { dryRun = dryRun == true, slots = 4, sourceCapabilities = tostring(sourceController.Capabilities), newCapabilities = false }
	if dryRun then return report end
	local storage = game:GetService("ServerStorage")
	local backup = storage:FindFirstChild("ToyGameplayUIBackup20261005")
	if not backup then backup = Instance.new("Folder") backup.Name = "ToyGameplayUIBackup20261005" backup.Parent = storage end
	local old = starter:FindFirstChild("PlaygroundToyHotbar")
	if old then
		if not backup:FindFirstChild("PlaygroundToyHotbar") then old:Clone().Parent = backup end
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaygroundToyHotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 24
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("ToyHotbarVersion", 1)
	local function frame(parent, name, size, position)
		local object = Instance.new("Frame")
		object.Name = name
		object.Size = size
		object.Position = position
		object.BackgroundTransparency = 1
		object.BorderSizePixel = 0
		object.Parent = parent
		return object
	end
	local function label(parent, name, text, size, position, maximum)
		local object = shell.Dock.Shop.LiveCaption:Clone()
		object.Name = name
		object.Text = text
		object.Size = size
		object.Position = position
		object.AnchorPoint = Vector2.zero
		object.TextScaled = true
		object.TextWrapped = true
		object.BorderSizePixel = 0
		object.ZIndex = 4
		object:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = maximum or 16
		object.Parent = parent
		return object
	end
	local bar = frame(gui, "Bar", UDim2.fromOffset(310, 130), UDim2.new(1, -18, 1, -18))
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.Visible = false
	label(bar, "Title", "LOBBY TOYS", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 0), 17)
	local holder = frame(bar, "Slots", UDim2.new(1, 0, 0, 78), UDim2.fromOffset(0, 22))
	for index = 1, 4 do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. tostring(index)
		slot.Size = UDim2.fromOffset(70, 76)
		slot.Position = UDim2.fromOffset((index - 1) * 80, 0)
		slot.Text = ""
		slot.BackgroundTransparency = 1
		slot.BorderSizePixel = 0
		slot.AutoButtonColor = false
		slot.Active = false
		slot.Selectable = false
		slot.Parent = holder
		slot:SetAttribute("ToySlot", index)
		local skin = cardSkin:Clone()
		skin.Name = "ReusableSkin"
		skin.Position = UDim2.fromScale(0, 0)
		skin.Size = UDim2.fromScale(1, 1)
		skin.AnchorPoint = Vector2.zero
		skin.ZIndex = 1
		skin.ImageTransparency = 0
		skin:SetAttribute("UISkinTargetPath", "StarterGui.PlaygroundToyHotbar.Bar.Slots." .. slot.Name)
		skin.Parent = slot
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Preview"
		viewport.BackgroundTransparency = 1
		viewport.BorderSizePixel = 0
		viewport.Size = UDim2.new(1, -14, 0, 43)
		viewport.Position = UDim2.fromOffset(7, 12)
		viewport.Ambient = Color3.fromRGB(210, 210, 210)
		viewport.LightColor = Color3.new(1, 1, 1)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.ZIndex = 2
		viewport.Visible = false
		viewport.Parent = slot
		local world = Instance.new("WorldModel")
		world.Name = "World"
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		label(slot, "Key", tostring(index), UDim2.fromOffset(16, 17), UDim2.fromOffset(3, 2), 15)
		local selected = label(slot, "Selected", "HELD", UDim2.fromOffset(39, 13), UDim2.fromOffset(26, 4), 10)
		selected.TextColor3 = Color3.fromRGB(255, 215, 74)
		selected.Visible = false
		label(slot, "ItemName", "EMPTY", UDim2.new(1, -8, 0, 19), UDim2.fromOffset(4, 54), 11)
		local note = label(slot, "PreviewNote", "NO PREVIEW", UDim2.new(1, -8, 0, 24), UDim2.fromOffset(4, 25), 9)
		note.Visible = false
	end
	local use = shell.Dock.Shop:Clone()
	use.Name = "Use"
	use.Size = UDim2.fromOffset(94, 28)
	use.Position = UDim2.new(1, -94, 1, -28)
	use.Text = "USE"
	use.LiveCaption.Text = "USE"
	use.LiveCaption:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 18
	use.Parent = bar
	use.ReusableSkin:SetAttribute("UISkinTargetPath", "StarterGui.PlaygroundToyHotbar.Bar.Use")
	label(bar, "Status", "Choose toys in the shop", UDim2.new(1, -102, 0, 28), UDim2.new(0, 0, 1, -28), 12)
	local crosshair = label(gui, "Crosshair", "+", UDim2.fromOffset(22, 22), UDim2.fromScale(0.5, 0.5), 20)
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Visible = false
	local controller = sourceController:Clone()
	controller.Name = "Controller"
	controller.Source = controllerSource
	controller.Enabled = true
	controller.Parent = gui
	assert(controller.Capabilities == sourceController.Capabilities and controller.Sandboxed == sourceController.Sandboxed, "Capability settings changed")
	gui.Parent = starter
	report.path = gui:GetFullName()
	report.backup = backup:GetFullName()
	return report
end

