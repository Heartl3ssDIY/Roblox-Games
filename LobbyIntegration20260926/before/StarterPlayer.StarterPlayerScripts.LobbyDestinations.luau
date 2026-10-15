local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
local destinations = workspace:WaitForChild("Lobby_MainModeZone"):WaitForChild("Destinations")
local messages = {
	Ranked = "The Season Hall is ready. Ranked battles are coming soon.",
	PvP = "The Duel Court is ready. Player challenges are coming soon.",
	Clans = "The Guild House is ready. Clan features are coming soon.",
}
local lastNotice = 0

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if player:GetAttribute("ActiveArena") or not prompt:IsDescendantOf(destinations) then return end
	local name = prompt.Parent.Name
	local message = messages[name]
	if not message or os.clock() - lastNotice < 2 then return end
	lastNotice = os.clock()
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = name, Text = message, Duration = 5 })
	end)
end)

