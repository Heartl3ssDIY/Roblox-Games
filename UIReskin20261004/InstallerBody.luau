assert(not game:GetService("RunService"):IsRunning(), "Use Edit mode")
assert(game.PlaceId == 95034648955135, "Select the Playground Classics place")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")
local function resolve(path)
	local current = game
	for segment in string.gmatch(path, "[^.]+") do current = current and current:FindFirstChild(segment) end
	return current
end
local function normalized(source)
	local unix = string.gsub(source, "\r\n", "\n")
	return string.gsub(unix, "\n+$", "")
end
local function compile(source, name)
	local chunk, issue = loadstring(source, name)
	assert(chunk, tostring(issue))
	return chunk
end
for path, sources in pairs(data.replacements) do
	local target = assert(resolve(path), "Missing source: " .. path)
	assert(normalized(target.Source) == normalized(sources.before), "Source changed since snapshot: " .. path)
	compile(sources.after, path)
end
compile(data.controller, "ReusableSkinController")
local builders = {}
for name, source in pairs(data.builders) do builders[name] = compile(source, name)() end
local backupName = "PlaygroundUIReskinBackup20261004"
assert(not ServerStorage:FindFirstChild(backupName), "A reskin backup already exists; inspect before reapplying")
local backup = Instance.new("Folder")
backup.Name = backupName
backup:SetAttribute("Purpose", "Recovery snapshot before the supplied blank PNG reskin")
backup.Parent = ServerStorage
local saved = {}
local included = {}
local function save(object)
	if not object or included[object] then return end
	included[object] = true
	local entry = Instance.new("Folder")
	entry.Name = string.format("Item%03d", #saved + 1)
	entry:SetAttribute("OriginalPath", object:GetFullName())
	entry:SetAttribute("OriginalName", object.Name)
	entry.Parent = backup
	local parent = Instance.new("ObjectValue")
	parent.Name = "OriginalParent"
	parent.Value = object.Parent
	parent.Parent = entry
	local clone = object:Clone()
	assert(clone, "Cannot back up " .. object:GetFullName())
	for _, descendant in ipairs({ clone, table.unpack(clone:GetDescendants()) }) do
		if descendant:IsA("BaseScript") or descendant:IsA("ScreenGui") then
			descendant:SetAttribute("ReskinBackupEnabled", descendant.Enabled)
			descendant.Enabled = false
		end
	end
	clone.Parent = entry
	table.insert(saved, { original = object, parent = object.Parent, clone = clone, name = object.Name })
end
for _, name in ipairs({ "BritishBulldogHUD", "TagHUD", "MudHUD", "PlaygroundShell", "PlaygroundAdminPanel" }) do save(assert(StarterGui:FindFirstChild(name), name)) end
save(resolve("ReplicatedStorage.PlaygroundCatalog"))
save(resolve("ServerScriptService.PlaygroundEconomyService"))
save(resolve("ReplicatedStorage.PlaygroundCosmeticAssets"))
save(workspace:FindFirstChild("PlaygroundCosmeticEffects"))
for _, path in ipairs({ "ReplicatedStorage.BritishBulldogAssets.TaggedTemplate", "ReplicatedStorage.TagAssets.TaggerTemplate", "ReplicatedStorage.MudAssets.MuddyTemplate" }) do save(resolve(path)) end
for _, object in ipairs(workspace:GetDescendants()) do
	if object:IsA("SurfaceGui") or object:IsA("BillboardGui") then save(object) end
end
backup:SetAttribute("Objects", #saved)
local function rollback()
	for _, entry in ipairs(saved) do
		if entry.original.Parent then entry.original:Destroy() end
		local restored = entry.clone:Clone()
		for _, descendant in ipairs({ restored, table.unpack(restored:GetDescendants()) }) do
			local enabled = descendant:GetAttribute("ReskinBackupEnabled")
			if enabled ~= nil then descendant.Enabled = enabled descendant:SetAttribute("ReskinBackupEnabled", nil) end
		end
		restored.Name = entry.name
		restored.Parent = entry.parent
	end
end
local report = { backup = backup:GetFullName(), backedUpObjects = #saved }
local ok, issue = xpcall(function()
	report.cleanup = builders.RemovePlaceholderContent()
	report.screens = builders.ApplyScreenSkins(data.assets, data.plan)
	report.leaderboards = builders.ApplyLeaderboardSkins(data.assets)
	report.world = builders.ApplyWorldSkins(data.assets)
	report.spacing = builders.ApplySkinRefinement(data.assets, { mappings = {} })
	for path, sources in pairs(data.replacements) do
		ScriptEditorService:UpdateSourceAsync(resolve(path), function(old)
			assert(normalized(old) == normalized(sources.before), "Source changed during installation: " .. path)
			return sources.after
		end)
	end
	for _, gui in ipairs(StarterGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			assert(not gui:FindFirstChild("ReusableSkinController"), "Unexpected existing skin controller")
			local controller = Instance.new("LocalScript")
			controller.Name = "ReusableSkinController"
			controller.Source = data.controller
			controller.Sandboxed = true
			controller.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.RunClientScript, Enum.SecurityCapability.AccessOutsideWrite, Enum.SecurityCapability.Basic, Enum.SecurityCapability.UI)
			controller.Parent = gui
			gui:SetAttribute("ReusableArtworkVersion", "20261004")
		end
	end
	for path, sources in pairs(data.replacements) do assert(normalized(resolve(path).Source) == normalized(sources.after), "Source verification failed: " .. path) end
end, debug.traceback)
if not ok then
	local restored, restoreIssue = pcall(rollback)
	backup:SetAttribute("InstallationFailed", true)
	error(tostring(issue) .. "\nRestored original objects: " .. tostring(restored) .. (restoreIssue and "\n" .. tostring(restoreIssue) or ""))
end
backup:SetAttribute("InstallationComplete", true)
report.playTestingStarted = false
return HttpService:JSONEncode(report)
