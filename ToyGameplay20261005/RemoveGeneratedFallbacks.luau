return function(dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local starter = game:GetService("StarterGui")
	local targets, borders, affected = {}, {}, {}
	for _, gui in ipairs(starter:GetChildren()) do
		if gui:IsA("ScreenGui") then
			for _, object in ipairs(gui:GetDescendants()) do
				if object:IsA("Frame") and object:GetAttribute("BackgroundFallbackVersion") == 1 then
					local imageName = object:GetAttribute("BackgroundFallbackFor")
					if typeof(imageName) == "string" and imageName ~= "ReusableIcon" then
						table.insert(targets, object)
						affected[gui] = true
					end
				elseif object:IsA("ImageLabel") then
					local parent = object.Parent
					if (object.Name == "ReusableSkin" or object.Name:find("Artwork")) and parent:IsA("GuiObject") and parent.BorderSizePixel > 0 then
						borders[parent] = true
						affected[gui] = true
					end
				end
			end
		end
	end
	local report = { removed = {}, bordersCleared = {}, dryRun = dryRun == true, textOutlinesChanged = false, nativeProgressChanged = false }
	if not dryRun then
		local storage = game:GetService("ServerStorage")
		local backup = storage:FindFirstChild("ToyGameplayUIBackup20261005")
		if not backup then backup = Instance.new("Folder") backup.Name = "ToyGameplayUIBackup20261005" backup.Parent = storage end
		local originals = backup:FindFirstChild("BeforeGlobalFallbackCleanup")
		if not originals then originals = Instance.new("Folder") originals.Name = "BeforeGlobalFallbackCleanup" originals.Parent = backup end
		for gui in pairs(affected) do if not originals:FindFirstChild(gui.Name) then gui:Clone().Parent = originals end end
		report.backup = originals:GetFullName()
	end
	for _, target in ipairs(targets) do
		table.insert(report.removed, target:GetFullName())
		if not dryRun then target:Destroy() end
	end
	for target in pairs(borders) do
		table.insert(report.bordersCleared, target:GetFullName())
		if not dryRun then target.BorderSizePixel = 0 end
	end
	return report
end

