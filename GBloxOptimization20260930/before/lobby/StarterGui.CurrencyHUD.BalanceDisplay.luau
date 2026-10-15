local Players = game:GetService("Players")
local player = Players.LocalPlayer
local holder = script.Parent.Counters

local function formatAmount(value)
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return "—" end
	local digits = string.format("%.0f", math.max(0, math.floor(value)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return grouped:gsub("^,", "")
end
local function refresh(name)
	holder[name].Amount.Text = formatAmount(player:GetAttribute(name))
end
for _, name in {"Cash", "Trophies"} do
	player:GetAttributeChangedSignal(name):Connect(function() refresh(name) end)
	refresh(name)
end
local cameraConnection
local function resize()
	local camera = workspace.CurrentCamera
	if camera then
 local v=camera.ViewportSize
 holder.ResponsiveScale.Scale=math.min(v.X,v.Y)<600 and .52 or math.clamp(math.min(v.X/1000,v.Y/800),.7,1)
end
end
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

