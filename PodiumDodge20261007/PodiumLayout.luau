assert(not game.RunService:IsRunning(), "Edit mode required")
local podium = workspace["Playground Lobby"].WinnerPodium
assert(podium.Stage.Position == Vector3.new(22,4.599999904632568,-82), "Podium moved since inspection")
assert(not game.ServerStorage:FindFirstChild("PodiumLayoutBackup20261007"), "Podium layout already updated")
local backup = podium:Clone()
backup.Name = "PodiumLayoutBackup20261007"
backup.Parent = game.ServerStorage
local shift = Vector3.new(20,0,-32)
for _,part in ipairs(podium:GetDescendants()) do if part:IsA("BasePart") then part.CFrame += shift end end
podium.StageInk.Size = Vector3.new(74,podium.StageInk.Size.Y,12)
podium.Stage.Size = Vector3.new(73.4,podium.Stage.Size.Y,11.4)
podium.FrontStepInk.Size = Vector3.new(66,podium.FrontStepInk.Size.Y,2.3)
podium.FrontStep.Size = Vector3.new(65.6,podium.FrontStep.Size.Y,2)
local targets = {42,18,66}
for index,x in ipairs(targets) do
	local rank = podium["Rank"..index]
	local center = rank.Top.Position
	local widthScale = 1.5
	for _,part in ipairs(rank:GetDescendants()) do if part:IsA("BasePart") then
		local offset = part.Position-center
		part.CFrame = CFrame.new(x+offset.X*widthScale,part.Position.Y,part.Position.Z)*part.CFrame.Rotation
		part.Size = Vector3.new(part.Size.X*widthScale,part.Size.Y,part.Size.Z)
	end end
end
local rise = 12
for _,part in ipairs(podium:GetChildren()) do if part:IsA("BasePart") and part.Name:sub(1,6)=="Header" then
	if part.Name:find("Post",1,true) then
		part.Size += Vector3.new(0,rise,0)
		part.CFrame += Vector3.new(0,rise/2,0)
	else part.CFrame += Vector3.new(0,rise,0) end
end end
podium:SetAttribute("StatueScale",4)
podium:SetAttribute("LayoutVersion",20261007)
local report={}
for i=1,3 do table.insert(report,{rank=i,position=tostring(podium["Rank"..i].Top.StandingPoint.WorldPosition)}) end
return game.HttpService:JSONEncode({points=report,backup=backup:GetFullName()})
