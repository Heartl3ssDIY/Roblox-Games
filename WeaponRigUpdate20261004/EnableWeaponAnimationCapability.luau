assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local targets = {
	game.ServerScriptService.BritishBulldogService,
	game.ServerScriptService.TagService,
	game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes,
}
local backup = game.ServerStorage:FindFirstChild("WeaponRigUpdateBackup20261004")
if not backup then backup = Instance.new("Folder") backup.Name = "WeaponRigUpdateBackup20261004" backup.Parent = game.ServerStorage end
local result = {}
for _, target in ipairs(targets) do
	local before = tostring(target.Capabilities)
	local permissions = {}
	local hasAnimation = false
	for name in before:gmatch("[^|]+") do
		name = name:match("^%s*(.-)%s*$")
		table.insert(permissions, Enum.SecurityCapability[name])
		if name == "Animation" then hasAnimation = true end
	end
	if not hasAnimation then
		local record = Instance.new("ObjectValue")
		record.Name = "PermissionsBefore_" .. target.Name
		record.Value = target
		record:SetAttribute("Capabilities", before)
		record.Parent = backup
		table.insert(permissions, Enum.SecurityCapability.Animation)
		target.Capabilities = SecurityCapabilities.new(table.unpack(permissions))
	end
	table.insert(result, { path = target:GetFullName(), before = before, after = tostring(target.Capabilities) })
end
return result
