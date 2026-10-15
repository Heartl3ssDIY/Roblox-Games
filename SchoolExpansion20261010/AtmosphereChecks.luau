local checks=0
local function check(value,message) checks+=1 assert(value,message) end
local attrs={}
local fakeRoot={Position=Vector3.new(0,0,0)}
local fakePlayer={Character={FindFirstChild=function()return fakeRoot end},GetAttribute=function(_,name)return attrs[name]end}
local old={Ambient=Color3.fromRGB(89,247,255),OutdoorAmbient=Color3.fromRGB(255,170,127),Brightness=2.4,ExposureCompensation=.08,ClockTime=13.5}
local Lighting=table.clone(old)
local playerBounds={CFrame=CFrame.new(),Size=Vector3.new(200,100,200),IsA=function()return true end}
local schoolBounds={CFrame=CFrame.new(11000,75,4573),Size=Vector3.new(208,84,282),IsA=function()return true end}
local function wrap(bounds) return {FindFirstChild=function()return {FindFirstChild=function()return bounds end}end}end
local workspace={CurrentCamera={CFrame=CFrame.new(0,10,0)},FindFirstChild=function(_,name)return wrap(name=="Hide and Seek" and schoolBounds or playerBounds)end}
local destroyCallback
local function connect(callback) return {Disconnect=function()end} end
local RunService={Heartbeat={Connect=function(_,cb)return connect(cb)end}}
local Players={LocalPlayer=fakePlayer}
local script={Destroying={Connect=function(_,cb)destroyCallback=cb return connect(cb)end}}
local controls=(function()
local player = Players.LocalPlayer
local baseline
local activeProfile
local elapsed = 0
local profiles = {
	Lobby = {
		Ambient = Color3.fromRGB(110, 122, 136),
		OutdoorAmbient = Color3.fromRGB(132, 145, 154),
		Brightness = 2.2, ExposureCompensation = 0, ClockTime = 13.5,
	},
	School = {
		Ambient = Color3.fromRGB(110, 108, 102),
		OutdoorAmbient = Color3.fromRGB(132, 129, 120),
		Brightness = 1.5, ExposureCompensation = -0.05, ClockTime = 13.5,
	},
}
local function restore()
	if baseline then
		for name, value in pairs(baseline) do Lighting[name] = value end
	end
	baseline, activeProfile = nil, nil
end
local function within(bounds, position)
	if not bounds or not bounds:IsA("BasePart") or not position then return false end
	local point = bounds.CFrame:PointToObjectSpace(position)
	local half = bounds.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end
local function boundsFor(name, partName)
	local model = workspace:FindFirstChild(name)
	local gameplay = model and model:FindFirstChild("Gameplay")
	return gameplay and gameplay:FindFirstChild(partName)
end
local function update()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local schoolBounds = boundsFor("Hide and Seek", "ArenaBounds")
	local inSchool = within(schoolBounds, camera and camera.CFrame.Position)
		or (player:GetAttribute("HSParticipating") and within(schoolBounds, root and root.Position))
	local profile
	if inSchool then
		profile = "School"
	elseif within(boundsFor("Playground Lobby", "LobbyBounds"), root and root.Position)
		and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
		and not player:GetAttribute("MDParticipating") and not player:GetAttribute("HSParticipating") then
		profile = "Lobby"
	end
	if not profile then restore() return end
	if profile == activeProfile then return end
	if not baseline then
		baseline = {
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness, ExposureCompensation = Lighting.ExposureCompensation, ClockTime = Lighting.ClockTime,
		}
	end
	for name, value in pairs(profiles[profile]) do Lighting[name] = value end
	activeProfile = profile
end
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.3 then elapsed = 0 update() end
end)
script.Destroying:Connect(function() heartbeat:Disconnect() restore() end)
update()


return {update=update}
end)()
local function profile(brightness,ambient,reason)check(math.abs(Lighting.Brightness-brightness)<.001,reason.." brightness")check(Lighting.Ambient==ambient,reason.." ambient")end
profile(2.2,Color3.fromRGB(110,122,136),"Lobby")
workspace.CurrentCamera.CFrame=CFrame.new(11000,45,4550)
controls.update()
profile(1.5,Color3.fromRGB(110,108,102),"Spectating school")
workspace.CurrentCamera.CFrame=CFrame.new(0,10,0)
controls.update()
profile(2.2,Color3.fromRGB(110,122,136),"Return lobby")
attrs.HSParticipating=true fakeRoot.Position=Vector3.new(11000,40,4550)
controls.update()
profile(1.5,Color3.fromRGB(110,108,102),"School player's camera outside")
attrs.HSParticipating=nil attrs.TGParticipating=true fakeRoot.Position=Vector3.new(5000,50,5000)
controls.update()
for property,value in pairs(old)do check(Lighting[property]==value,"Baseline restored "..property)end
attrs.TGParticipating=nil fakePlayer.Character=nil workspace.CurrentCamera=nil controls.update()
for property,value in pairs(old)do check(Lighting[property]==value,"No character/camera safe "..property)end
workspace.CurrentCamera={CFrame=CFrame.new(11000,45,4550)}controls.update()
profile(1.5,Color3.fromRGB(110,108,102),"School without character")
destroyCallback()
for property,value in pairs(old)do check(Lighting[property]==value,"Destroy restored "..property)end
return {passed=true,checks=checks,profiles={"Lobby","School","Spectating","Other maps","No character","Cleanup"},liveLightingChanged=false}
