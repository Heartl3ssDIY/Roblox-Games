assert(not game:GetService("RunService"):IsRunning(), "Stop Play before polishing school signs.")
local arena = workspace:FindFirstChild("Hide and Seek")
assert(arena, "Hide and Seek school is missing.")
local school = arena.Geometry.PlaygroundPrimarySchool
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("SchoolSurfaceGuiBackup20261010")
if not backup then
	backup = Instance.new("Folder")
	backup.Name, backup.Parent = "SchoolSurfaceGuiBackup20261010", storage
end
local normals = {
	[Enum.NormalId.Front] = Vector3.new(0,0,-1), [Enum.NormalId.Back] = Vector3.new(0,0,1),
	[Enum.NormalId.Left] = Vector3.new(-1,0,0), [Enum.NormalId.Right] = Vector3.new(1,0,0),
	[Enum.NormalId.Top] = Vector3.new(0,1,0), [Enum.NormalId.Bottom] = Vector3.new(0,-1,0),
}
local function faceSize(host,face)
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then return Vector2.new(host.Size.X,host.Size.Y) end
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then return Vector2.new(host.Size.Z,host.Size.Y) end
	return Vector2.new(host.Size.X,host.Size.Z)
end
local function mirrorFloor(host)
	local ancestor = host.Parent
	while ancestor and ancestor ~= arena do
		local floor = ancestor:GetAttribute("Floor")
		if typeof(floor) == "number" then return floor end
		ancestor = ancestor.Parent
	end
end
local report = { surfaceGuis = 0, labels = 0, mirrorsMoved = 0, alwaysOnTop = false, sourcesChanged = 0 }
for _, gui in arena:GetDescendants() do
	if gui:IsA("SurfaceGui") then
		local host = gui.Adornee or gui.Parent
		assert(host and host:IsA("BasePart"), "School sign has no valid host: " .. gui:GetFullName())
		if not gui:GetAttribute("PCSchoolSurfacePolished20261010") then
			local snapshot = gui:Clone()
			snapshot.Name = "Surface" .. tostring(report.surfaceGuis+1)
			snapshot:SetAttribute("OriginalPath",gui:GetFullName())
			snapshot:SetAttribute("OriginalHostCFrame",host.CFrame)
			snapshot.Parent = backup
		end
		if host.Name == "Mirror" then
			local floor = mirrorFloor(host)
			local wall = floor and school.Structure:FindFirstChild("BackWall"..tostring(floor-1).."Panel")
			if wall then
				local normal = host.CFrame:VectorToWorldSpace(normals[gui.Face])
				local face = host.CFrame:PointToWorldSpace(normals[gui.Face]*host.Size/2)
				local wallFace = wall.CFrame:PointToWorldSpace(Vector3.new(0,0,-wall.Size.Z/2))
				local distance = (wallFace-face):Dot(normal)+.12
				if distance > .01 then
					host.CFrame += normal*distance
					report.mirrorsMoved += 1
				end
			end
		end
		local physical = faceSize(host,gui.Face)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 64
		gui.CanvasSize = Vector2.new(math.max(1,math.round(physical.X*64)),math.max(1,math.round(physical.Y*64)))
		gui.AlwaysOnTop, gui.LightInfluence, gui.Brightness = false, 0, 1
		gui.ZOffset = .02
		gui.MaxDistance = host.Name == "SchoolName" and 220 or string.find(host.Name,"DrinkCarton",1,true) and 80 or 120
		gui.Enabled = true
		for _, label in gui:GetDescendants() do
			if label:IsA("TextLabel") then
				label.TextTruncate = Enum.TextTruncate.None
				label.TextWrapped = true
				label.TextScaled = true
				if gui.Name == "EditableLabel" and label.Name == "Caption" then
					label.Position, label.Size = UDim2.fromScale(.04,.12), UDim2.fromScale(.92,.76)
				end
				local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
				if not limit then limit = Instance.new("UITextSizeConstraint") limit.Name,limit.Parent = "SchoolTextSize",label end
				limit.MinTextSize = 10
				limit.MaxTextSize = host.Name == "SchoolName" and 108 or host.Name == "BoardFace" and
					(label.Name == "RoomNumber" and 60 or label.Name == "Lesson" and 52 or 36)
					or host.Name == "Mirror" and 30 or host.Name == "Nameplate" and 34
					or string.find(host.Name,"DrinkCarton",1,true) and 24 or 46
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then label.TextStrokeTransparency = 1 stroke.Thickness = 1.5 end
				report.labels += 1
			end
		end
		gui:SetAttribute("PCSchoolSurfacePolished20261010",true)
		report.surfaceGuis += 1
	end
end
assert(report.surfaceGuis == 35, "School label inventory changed; review the result.")
return report
