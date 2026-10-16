local ServerScriptService = game:GetService("ServerScriptService")
local BritishBulldogService = require(ServerScriptService:WaitForChild("BritishBulldogService"))
local arena = workspace:WaitForChild("British Bulldog game")
local service = BritishBulldogService.new(arena)
local startRound = ServerScriptService:FindFirstChild("BritishBulldogStartRound")
if startRound then
	assert(startRound:IsA("BindableFunction"), "BritishBulldogStartRound must be a BindableFunction")
else
	startRound = Instance.new("BindableFunction")
	startRound.Name = "BritishBulldogStartRound"
	startRound.Parent = ServerScriptService
end
startRound:SetAttribute("Ready", false)
startRound.OnInvoke = function(selectedPlayers)
	if not startRound:GetAttribute("Ready") then
		return false, "British Bulldog service is not ready"
	end
	if selectedPlayers ~= nil and typeof(selectedPlayers) ~= "table" then
		return false, "Expected an array of players"
	end
	return service:StartRound(selectedPlayers)
end
service:Start()
local admin=require(ServerScriptService:WaitForChild("PlaygroundAdminService")).Start(service)
startRound:SetAttribute("Ready", true)
script:SetAttribute("Ready", true)
