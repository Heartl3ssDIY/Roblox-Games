local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

while true do
 PlayerData.RefreshSeasonalAvailability()
 task.wait(30)
end

