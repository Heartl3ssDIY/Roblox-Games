assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing Push.")
local services = game.ServerScriptService
local staging = game.ServerStorage:FindFirstChild("_PushActionChecks20261008")
assert(staging, "Validated Push staging is missing.")
local function checksum(source)
	local a, b = 1, 0
	for index = 1, #source do
		a = (a + source:byte(index)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end
local changes = {
	{ name = "BritishBulldogService", beforeLength = 73748, beforeHash = 3313159628, afterLength = 76037, afterHash = 19778957 },
	{ name = "TagService", beforeLength = 66390, beforeHash = 3191424551, afterLength = 68115, afterHash = 3205596709 },
	{ name = "PlaygroundBootstrap", beforeLength = 6465, beforeHash = 1575799886, afterLength = 6650, afterHash = 1776619234 },
}
assert(not services:FindFirstChild("PlaygroundPushService"), "Push service already exists.")
local remote = game.ReplicatedStorage:FindFirstChild("PlaygroundPushRequest")
assert(not remote or remote:IsA("RemoteEvent"), "Push remote name is occupied.")
for _, change in ipairs(changes) do
	local current, nextVersion = services:FindFirstChild(change.name), staging:FindFirstChild(change.name)
	assert(current and #current.Source == change.beforeLength and checksum(current.Source) == change.beforeHash, "Live source changed: " .. change.name)
	assert(nextVersion and #nextVersion.Source == change.afterLength and checksum(nextVersion.Source) == change.afterHash, "Staged source changed: " .. change.name)
end
local preparedPush = staging.PlaygroundPushService
assert(#preparedPush.Source == 6215 and checksum(preparedPush.Source) == 1661696138, "Staged Push source changed.")
local backup = game.ServerStorage:FindFirstChild("PushActionBackup20261008")
if not backup then backup = Instance.new("Folder") backup.Name = "PushActionBackup20261008" backup.Parent = game.ServerStorage end
for _, change in ipairs(changes) do assert(not backup:FindFirstChild(change.name), "Backup already exists: " .. change.name) end
for _, change in ipairs(changes) do
	local copy = services[change.name]:Clone()
	if copy:IsA("Script") then copy.Disabled = true end
	copy.Parent = backup
end
local newPush = preparedPush:Clone()
local madeRemote
newPush:SetAttribute("CooldownSeconds", 6)
newPush:SetAttribute("Reach", 6)
newPush:SetAttribute("RagdollSeconds", 3)
local ok, failure = xpcall(function()
	if not remote then
		madeRemote = Instance.new("RemoteEvent")
		madeRemote.Name = "PlaygroundPushRequest"
		madeRemote.Parent = game.ReplicatedStorage
	end
	newPush.Parent = services
	for _, change in ipairs(changes) do services[change.name].Source = staging[change.name].Source end
end, debug.traceback)
if not ok then
	newPush:Destroy()
	if madeRemote then madeRemote:Destroy() end
	for _, change in ipairs(changes) do services[change.name].Source = backup[change.name].Source end
	error(failure)
end
return { installed = true, files = #changes + 1, playStarted = false, cooldown = 6, reach = 6, ragdollSeconds = 3, backup = backup:GetFullName() }

