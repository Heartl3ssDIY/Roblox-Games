return function()
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local shell = game.StarterGui.PlaygroundShell
	local dock = shell.Dock
	local controller = shell.Controller
	local replacements = { Emote = "Pets", Emoji = "Toys" }
	local source = controller.Source
	for oldName, newName in pairs(replacements) do
		local old = dock:FindFirstChild(oldName)
		local existing = dock:FindFirstChild(newName)
		assert(not old or not existing, "Duplicate shortcut names")
		assert(old or existing, "Missing shortcut " .. newName)
		source = source:gsub("dock%." .. oldName .. "%.", "dock." .. newName .. ".")
	end
	local backup = game.ServerStorage:FindFirstChild("ToyGameplayUIBackup20261005")
	assert(backup, "UI backup required")
	if not backup:FindFirstChild("ControllerBeforeShortcutNames") then
		local copy = controller:Clone()
		copy.Name = "ControllerBeforeShortcutNames"
		copy.Parent = backup
	end
	for oldName, newName in pairs(replacements) do
		local button = dock:FindFirstChild(oldName) or dock:FindFirstChild(newName)
		button.Name = newName
		for _, child in ipairs(button:GetDescendants()) do
			local path = child:GetAttribute("UISkinTargetPath")
			if typeof(path) == "string" then
				child:SetAttribute("UISkinTargetPath", path:gsub("Dock%." .. oldName, "Dock." .. newName))
			end
		end
	end
	controller.Source = source
	return { renamed = { "Dock.Pets", "Dock.Toys" }, sourceChanges = "Only two shortcut references", positionsChanged = false }
end

