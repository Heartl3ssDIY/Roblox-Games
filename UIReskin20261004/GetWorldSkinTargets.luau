return function()
	local targets = {}
	local function add(instance, kind, palette)
		if instance then table.insert(targets, {instance = instance, kind = kind, palette = palette}) end
	end
	for _,mapName in {"British Bulldog game", "Tag You're It"} do
		local map = workspace:FindFirstChild(mapName)
		local scenery = map and map:FindFirstChild("SchoolScenery")
		if scenery then
			for _,gui in scenery:GetDescendants() do
				if gui:IsA("SurfaceGui") and gui.Name == "ClassDetail" and gui.Parent:IsA("BasePart") then
					local host = gui.Parent.Name
					if host == "HopscotchSquare" then add(gui, "hopscotch")
					elseif host == "RoomPlaque" or host == "PinnedClassPaper" then add(gui, "school", "cream") end
				end
			end
		end
		local walls = map and map:FindFirstChild("ArenaWalls")
		if mapName == "British Bulldog game" and walls then
			for _,gui in walls:GetDescendants() do
				if gui:IsA("SurfaceGui") and gui.Name == "TitleArtwork" and gui.Parent.Name == "TitleCreamPanel" then add(gui, "title", "gold") end
			end
		end
	end
	local lobby = workspace:FindFirstChild("Playground Lobby")
	local voting = lobby and lobby:FindFirstChild("VotingAlcove")
	if voting then
		for standName, palette in {BritishBulldogStand = "blue", TagYoureItStand = "red", StuckInTheMudStand = "green"} do
			local stand = voting:FindFirstChild(standName)
			local face = stand and stand:FindFirstChild("ChoiceCardFace")
			local gui = face and face:FindFirstChild("GameName")
			if gui and gui:IsA("SurfaceGui") then add(gui, "vote", palette) end
		end
	end
	for _,spec in {{"BritishBulldogAssets", "TaggedTemplate", "gold"}, {"TagAssets", "TaggerTemplate", "red"}, {"MudAssets", "MuddyTemplate", "mud"}} do
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild(spec[1])
		local gui = assets and assets:FindFirstChild(spec[2])
		if gui and gui:IsA("BillboardGui") then add(gui, "overhead", spec[3]) end
	end
	return targets
end
