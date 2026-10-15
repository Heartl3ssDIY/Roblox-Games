local school = workspace["Hide and Seek"].Geometry.PlaygroundPrimarySchool
local props = school.SchoolAssetProps
local rooms, count = {}, 0
for _, room in school:GetChildren() do
	local number = room:GetAttribute("ClassroomNumber")
	if number then rooms[number] = room end
end
local chairs, boards, minimumDot = 0, 0, 1
for _, prop in props:GetChildren() do
	if prop:IsA("Model") and prop:GetAttribute("SchoolFacingVersion") == "20261011-facing-v2" then
		local room = assert(rooms[prop:GetAttribute("ClassroomNumber")])
		local furniture
		for _, item in room:GetChildren() do if item:IsA("Model") and item:FindFirstChild("Table11") then furniture = item break end end
		local at = prop:GetPivot()
		local target
		if prop.Name:match("_Chair%d") then
			local row, column = prop.Name:match("_Chair(%d)(%d)%d")
			target = furniture["Table" .. row .. column].DeskTop.Position
			chairs += 1
		elseif prop.Name:match("_TeacherChair$") then
			target = furniture.TeacherTable.DeskTop.Position
			chairs += 1
		elseif prop.Name:match("_TeachingBoard$") then
			target = (furniture.Table11.DeskTop.Position + furniture.Table22.DeskTop.Position) / 2
			local face = assert(prop:FindFirstChild(prop:GetAttribute("HSPropId") .. "_B01_M02", true))
			assert(at:PointToObjectSpace(face.Position).Z < -.2, "Board face away from classroom: " .. prop.Name)
			boards += 1
		end
		assert(target, "Unexpected repaired object: " .. prop.Name)
		local direction = Vector3.new(target.X - at.X, 0, target.Z - at.Z).Unit
		local dot = at.LookVector:Dot(direction)
		assert(dot > .8, "Asset facing away from intended use: " .. prop.Name)
		minimumDot = math.min(minimumDot, dot)
		count += 1
	end
end
assert(chairs == 288 and boards == 32 and count == 320, "Missing room repairs")
for _, template in game.ReplicatedStorage.SchoolPropTemplates:GetChildren() do
	if template:GetAttribute("SchoolFacingVersion") then
		assert(template:GetAttribute("SchoolFrontAxis") == "-Z")
		assert(template:GetPivot().Position.Magnitude < .001)
	end
end
return {checks = count, chairs = chairs, boards = boards, minimumFacingDot = minimumDot, rooms = #rooms}
