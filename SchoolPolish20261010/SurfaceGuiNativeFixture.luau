assert(not game:GetService("RunService"):IsRunning(),"Edit fixtures only")
local live = workspace["Hide and Seek"]
local storage = game:GetService("ServerStorage")
for _,name in {"SchoolSurfaceGuiFixture20261010","SchoolSurfaceGuiFixtureBackup20261010"} do local old=storage:FindFirstChild(name) if old then old:Destroy() end end
local fixture = Instance.new("Folder")
fixture.Name,fixture.Parent = "SchoolSurfaceGuiFixture20261010",storage
local geometry = Instance.new("Folder") geometry.Name,geometry.Parent = "Geometry",fixture
local school = Instance.new("Folder") school.Name,school.Parent = "PlaygroundPrimarySchool",geometry
local structure = Instance.new("Folder") structure.Name,structure.Parent = "Structure",school
for _,name in {"BackWall0Panel","BackWall1Panel"}do local wall=live.Geometry.PlaygroundPrimarySchool.Structure[name]:Clone()wall.Parent=structure end
local originals = {}
for _,gui in live:GetDescendants()do if gui:IsA("SurfaceGui")then
 local host=gui.Adornee or gui.Parent
 local clone=host:Clone()
 if host.Name=="Mirror"then
  local ancestors=host.Parent local floor
  while ancestors and ancestors~=live do if ancestors:GetAttribute("Floor")then floor=ancestors:GetAttribute("Floor")break end ancestors=ancestors.Parent end
  local toilet=Instance.new("Model")toilet.Name,toilet.Parent="ToiletFloor"..floor,school toilet:SetAttribute("Floor",floor)
  clone.Parent=toilet
  clone.CFrame += clone.CFrame.LookVector*(-.19)
 else clone.Parent=school end
 for _,g in clone:GetDescendants()do if g:IsA("SurfaceGui")then g:SetAttribute("PCSchoolSurfacePolished20261010",false)end end
 table.insert(originals,{live=host,cframe=host.CFrame,clone=clone})
end end
local patch = function(arena)
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before polishing school signs.")

assert(arena, "Hide and Seek school is missing.")
local school = arena.Geometry.PlaygroundPrimarySchool
local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("SchoolSurfaceGuiFixtureBackup20261010")
if not backup then
	backup = Instance.new("Folder")
	backup.Name, backup.Parent = "SchoolSurfaceGuiFixtureBackup20261010", storage
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


end
local first=patch(fixture)
local second=patch(fixture)
local count=0
local function check(value,message)assert(value,message)count+=1 end
check(first.surfaceGuis==35 and first.labels==51,"All35surfaces/51labels covered")
check(first.mirrorsMoved==2,"Two buried mirrors lifted")
check(second.mirrorsMoved==0,"Rerunning does not keep moving mirrors")
check(#storage.SchoolSurfaceGuiFixtureBackup20261010:GetChildren()==35,"Backups are not duplicated on rerun")
for _,entry in originals do
 check(entry.live.CFrame==entry.cframe,"Live school was not changed by fixture")
end
for _,gui in fixture:GetDescendants()do if gui:IsA("SurfaceGui")then
 local host=gui.Adornee or gui.Parent
 check(not gui.AlwaysOnTop,"Labels remain occluded by walls")
 check(gui.Face==Enum.NormalId.Front,"Correct authored directions retained")
 check(gui.PixelsPerStud==64 and gui.SizingMode==Enum.SurfaceGuiSizingMode.PixelsPerStud,"Model scaling maintains label aspect")
 check(math.abs(gui.CanvasSize.X/gui.CanvasSize.Y-host.Size.X/host.Size.Y)<.02,"Canvas aspect agrees with its actual face")
 for _,label in gui:GetDescendants()do if label:IsA("TextLabel")then
  check(label.Position.X.Scale>=0 and label.Position.Y.Scale>=0 and label.Position.X.Scale+label.Size.X.Scale<=1.001 and label.Position.Y.Scale+label.Size.Y.Scale<=1.001,"Padded label stays within face")
  local limit=label:FindFirstChildOfClass("UITextSizeConstraint")
  check(limit and limit.MaxTextSize>=limit.MinTextSize and label.TextScaled and label.TextWrapped,"Actual scaled text remains enabled with bounded font sizes")
 end end
 if host.Name=="Mirror"then
  local floor=host.Parent:GetAttribute("Floor")local wall=structure["BackWall"..(floor-1).."Panel"]
  local face=host.CFrame:PointToWorldSpace(Vector3.new(0,0,-host.Size.Z/2))
  local wallFront=wall.CFrame:PointToWorldSpace(Vector3.new(0,0,-wall.Size.Z/2))
  check(face.Z<=wallFront.Z-.11,"Mirror label is in front of opaque wall")
 end
end end
local probe = RaycastParams.new() probe.FilterType=Enum.RaycastFilterType.Include probe.FilterDescendantsInstances={live}
for _,gui in live:GetDescendants()do if gui:IsA("SurfaceGui")then
 local host=gui.Adornee or gui.Parent
 local front=host.CFrame:PointToWorldSpace(Vector3.new(0,0,-host.Size.Z/2))
 local direction=host.CFrame.LookVector
 local hit=workspace:Raycast(front+direction,-direction*1.05,probe)
 check(not hit or hit.Instance==host or hit.Distance>=.985,"No opaque obstruction directly in front of a school label")
 if host.Name=="Mirror"then
  local desired={TopOutline=Vector3.new(0,host.Size.Y/2-.07,-.105),BottomOutline=Vector3.new(0,-host.Size.Y/2+.07,-.105),LeftOutline=Vector3.new(-host.Size.X/2+.07,0,-.105),RightOutline=Vector3.new(host.Size.X/2-.07,0,-.105)}
  for name,offset in pairs(desired)do
   local trim=host.Parent:FindFirstChild(name)
   check(trim and (trim.Position-(host.CFrame*CFrame.new(offset)).Position).Magnitude<.001,"Mirror cartoon outline remains aligned")
  end
 end
end end
storage.SchoolSurfaceGuiFixtureBackup20261010:Destroy()
fixture:Destroy()
return {passed=true,checks=count,surfaceGuis=35,labels=51,mirrors=2,liveChanges=false}

