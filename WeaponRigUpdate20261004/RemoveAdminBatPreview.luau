assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local gui = game.StarterGui:WaitForChild("PlaygroundAdminPanel")
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("WeaponRigUpdateBackup20261004")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "WeaponRigUpdateBackup20261004"
	backup.Parent = storage
end
if not backup:FindFirstChild("PlaygroundAdminPanel") then
	local copy = gui:Clone()
	copy.Parent = backup
end
local filters = gui.AdminHub.Pages.Items.Filters
local button = filters:FindFirstChild("ClearPreview")
if button then button:Destroy() end
local changed = 0
for _, object in ipairs(gui:GetDescendants()) do
	if object:IsA("TextButton") or object:IsA("TextLabel") then
		if object.Text == "SHOW BAT" then
			object.Text = "EQUIPPED"
			changed += 1
		end
	end
end
gui:SetAttribute("BatPreviewRemoved", true)
return { backup = backup:GetFullName(), removedButton = button ~= nil, correctedCaptions = changed, playStarted = false }
