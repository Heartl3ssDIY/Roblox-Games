return function(plan)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
	assert(game.PlaceId == 95034648955135, "Unexpected place")
	local storage = game:GetService("ServerStorage")
	assert(not storage:FindFirstChild("ToyRoundRepairBackup20261008"), "Backup already exists; inspect before reinstalling")
	local function normalize(source)
		return source:gsub("\r\n", "\n"):gsub("%s+$", "")
	end
	local entries = {}
	for _, item in ipairs(plan) do
		local target = game
		for name in string.gmatch(item.path, "[^.]+") do target = assert(target:FindFirstChild(name), item.path) end
		assert(target:IsA("LuaSourceContainer"), item.path)
		assert(normalize(target.Source) == normalize(item.before), "Source changed since audit: " .. item.path)
		table.insert(entries, { target = target, path = item.path, source = target.Source, replacement = item.after,
			capabilities = target.Capabilities, sandboxed = target.Sandboxed })
	end
	assert(#entries == 3, "Expected the equipment, toy and hotbar scripts only")
	local backup = Instance.new("Folder")
	backup.Name, backup.Parent = "ToyRoundRepairBackup20261008", storage
	for _, entry in ipairs(entries) do
		local clone = entry.target:Clone()
		clone.Name = entry.target.Name == "Controller" and "ToyHotbarController" or entry.target.Name
		clone:SetAttribute("OriginalPath", entry.path)
		clone.Parent = backup
	end
	local ok, failure = pcall(function()
		for _, entry in ipairs(entries) do
			entry.target.Source = entry.replacement
			assert(entry.target.Capabilities == entry.capabilities and entry.target.Sandboxed == entry.sandboxed, "Permissions changed")
		end
	end)
	if not ok then
		for _, entry in ipairs(entries) do entry.target.Source = entry.source end
		error(failure)
	end
	local report = { backup = backup:GetFullName(), installed = {}, playStarted = false, published = false }
	for _, entry in ipairs(entries) do
		table.insert(report.installed, { path = entry.path, characters = #entry.target.Source, capabilities = tostring(entry.target.Capabilities) })
	end
	return report
end
