return function(sources, dryRun)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local server = game:GetService("ServerScriptService")
	local replicated = game:GetService("ReplicatedStorage")
	local starter = game:GetService("StarterGui")
	local playerScripts = game:GetService("StarterPlayer").StarterPlayerScripts
	local targets = {
		PlaygroundEconomyService = server.PlaygroundEconomyService,
		PlaygroundEquipmentService = server.PlaygroundEquipmentService,
		PlaygroundBootstrap = server.PlaygroundBootstrap,
		PlaygroundCatalog = replicated.PlaygroundCatalog,
		PlaygroundEmotes = playerScripts.PlaygroundEmotes,
		ShellController = starter.PlaygroundShell.Controller,
	}
	for name in pairs(targets) do assert(typeof(sources[name]) == "string" and #sources[name] > 100, "Missing source " .. name) end
	assert(typeof(sources.PlaygroundToyService) == "string" and #sources.PlaygroundToyService > 100, "Missing toy service")
	local report = { dryRun = dryRun == true, existing = {}, new = { "PlaygroundToyService", "PlaygroundToyRequest" }, capabilityChanges = false }
	for name, target in pairs(targets) do report.existing[name] = { path = target:GetFullName(), capabilities = tostring(target.Capabilities), changed = target.Source ~= sources[name] } end
	if dryRun then return report end
	local storage = game:GetService("ServerStorage")
	local backup = storage:FindFirstChild("ToyGameplayScriptsBackup20261005")
	if not backup then backup = Instance.new("Folder") backup.Name = "ToyGameplayScriptsBackup20261005" backup.Parent = storage end
	for name, target in pairs(targets) do
		if not backup:FindFirstChild(name) then local clone = target:Clone() clone.Name = name clone.Parent = backup end
	end
	local toyModule = server:FindFirstChild("PlaygroundToyService")
	if toyModule and not backup:FindFirstChild("PlaygroundToyService") then toyModule:Clone().Parent = backup end
	if not toyModule then
		toyModule = server.PlaygroundEquipmentService:Clone()
		toyModule.Name = "PlaygroundToyService"
		toyModule.Parent = server
	end
	toyModule.Source = sources.PlaygroundToyService
	local remote = replicated:FindFirstChild("PlaygroundToyRequest")
	if not remote then
		remote = replicated:WaitForChild("BBMovementRequest"):Clone()
		remote.Name = "PlaygroundToyRequest"
		remote.Parent = replicated
	end
	assert(remote:IsA("RemoteFunction"), "Toy remote must be RemoteFunction")
	for name, target in pairs(targets) do target.Source = sources[name] end
	report.backup = backup:GetFullName()
	report.toyCapabilities = tostring(toyModule.Capabilities)
	report.remoteCapabilities = tostring(remote.Capabilities)
	return report
end
