assert(not game:GetService("RunService"):IsRunning(),"Edit only")
assert(game.PlaceId==95034648955135,"Wrong place")
assert(not game.StarterGui:FindFirstChild("PlaygroundIntermissionHUD"),"Timer already exists")
local gui
local ok, problem = pcall(function()
	gui = (function()
__BUILDER__
	end)()
	local controller = Instance.new("LocalScript")
	controller.Name = "Controller"
	controller.Sandboxed = true
	controller.Capabilities = SecurityCapabilities.new(Enum.SecurityCapability.RunClientScript,
		Enum.SecurityCapability.AccessOutsideWrite,Enum.SecurityCapability.Basic,
		Enum.SecurityCapability.UI,Enum.SecurityCapability.Physics,Enum.SecurityCapability.Players)
	controller.Source = [====[__CONTROLLER__]====]
	controller.Parent = gui
end)
if not ok then
	if gui then gui:Destroy() end
	error(problem)
end
return game:GetService("HttpService"):JSONEncode({installed=gui:GetFullName(),controller=gui.Controller:GetFullName(),capabilities=tostring(gui.Controller.Capabilities)})
