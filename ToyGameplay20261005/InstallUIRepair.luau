return function(dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local shell = game:GetService("StarterGui"):WaitForChild("PlaygroundShell")
	local roots = { shell.Dock, shell.Wallet, shell.LevelPanel, shell.CompactLevelPanel }
	local report = { removed = {}, cleanParents = {}, bordersCleared = {}, textOutlines = 0, dryRun = dryRun == true, scriptSourcesChanged = false }
	local backup
	if not dryRun then
		backup = game:GetService("ServerStorage"):FindFirstChild("ToyGameplayUIBackup20261005")
		if not backup then
			backup = Instance.new("Folder")
			backup.Name = "ToyGameplayUIBackup20261005"
			backup.Parent = game:GetService("ServerStorage")
		end
		for _, root in ipairs(roots) do
			if not backup:FindFirstChild(root.Name) then root:Clone().Parent = backup end
		end
		report.backup = backup:GetFullName()
	end
	local remove = {}
	for _, root in ipairs(roots) do
		local objects = { root }
		for _, object in ipairs(root:GetDescendants()) do table.insert(objects, object) end
		for _, object in ipairs(objects) do
			if object:IsA("GuiObject") then
				if object.BorderSizePixel ~= 0 then
					table.insert(report.bordersCleared, object:GetFullName())
					if not dryRun then object.BorderSizePixel = 0 end
				end
				local skin = object:FindFirstChild("ReusableSkin") or object:FindFirstChild("ReusableIcon")
				if skin and skin:IsA("ImageLabel") then
					table.insert(report.cleanParents, object:GetFullName())
					if not dryRun then object.BackgroundTransparency = 1 end
					for _, child in ipairs(object:GetChildren()) do
						if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
							table.insert(remove, child)
						end
					end
				end
				if object:GetAttribute("BackgroundFallbackFor") ~= nil then table.insert(remove, object) end
			elseif object:IsA("UIStroke") and object.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
				report.textOutlines += 1
			end
		end
	end
	local layout = shell.Dock:FindFirstChild("DockLayout")
	if layout then table.insert(remove, layout) end
	for _, object in ipairs(remove) do
		table.insert(report.removed, object:GetFullName())
		if not dryRun then object:Destroy() end
	end
	if not dryRun then
		shell.Dock:SetAttribute("IndependentButtonPositions", true)
		shell.Dock:SetAttribute("DockPolishVersion", 2)
		for _, root in ipairs(roots) do root:SetAttribute("PNGOnlyBackground", true) end
	end
	return report
end

