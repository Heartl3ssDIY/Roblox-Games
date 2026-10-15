return function(serviceSource)
	local owner = Instance.new("Folder")
	owner.Name = "IsolatedLobbyTravelRegression"
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, fn)
				table.insert(callbacks, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_, ...)
				for _, fn in ipairs(callbacks) do fn(...) end
			end,
		}
	end
	local function part(parent, name, position, size)
		local value = Instance.new("Part")
		value.Name = name
		value.Size = size or Vector3.new(1, 0.1, 1)
		value.CFrame = CFrame.new(position or Vector3.zero)
		value.Anchored = true
		value.Parent = parent
		return value
	end
	local function model(parent, name)
		local value = Instance.new("Model")
		value.Name = name
		value.Parent = parent
		return value
	end
	local function character(r15, legHeight)
		local value = model(owner, r15 and "R15Test" or "R6Test")
		local root = part(value, "HumanoidRootPart", Vector3.new(15, 10, 12), Vector3.new(2, 2, 1))
		root.Anchored = false
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = r15 and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
		humanoid.HipHeight = r15 and 2.4 or 0
		humanoid.Health = 100
		humanoid.Parent = value
		if not r15 then part(value, "Right Leg", Vector3.zero, Vector3.new(1, legHeight or 2, 1)) end
		return value, root, humanoid
	end
	local player = { CharacterRemoving = signal(), attributes = {} }
	function player:SetAttribute(key, value) self.attributes[key] = value end
	function player:GetAttribute(key) return self.attributes[key] end
	local char, root, humanoid = character(false)
	player.Character = char
	local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	function players:GetPlayers() return { player } end
	local fakeWorkspace = Instance.new("Folder")
	fakeWorkspace.Parent = owner
	local lobby = model(fakeWorkspace, "Lobby_MainModeZone")
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = lobby
	local story = part(markers, "PORTAL_Story", Vector3.new(-40, 12, 100))
	story.CFrame *= CFrame.Angles(0, math.rad(60), 0)
	local summon = part(markers, "INTERACT_Summon", Vector3.new(60, 2, -8))
	local summonLook = part(markers, "SummonDestination", Vector3.new(61, 2, -5))
	local ranked = part(markers, "RankedFloor", Vector3.new(90, 16, 40))
	local tenkaichi = model(fakeWorkspace, "Arena_Tenkaichi")
	tenkaichi:SetAttribute("TeleportReady", true)
	tenkaichi:SetAttribute("MatchReady", true)
	local side = Instance.new("Folder")
	side.Name = "Sidelines"
	side.Parent = tenkaichi
	local arenaSpawn = part(side, "Spawn_Player", Vector3.new(400, 8, -500))
	local visitOnly = model(fakeWorkspace, "Arena_JujutsuHigh")
	visitOnly:SetAttribute("TeleportReady", true)
	visitOnly:SetAttribute("MatchReady", false)
	local side2 = side:Clone()
	side2.Parent = visitOnly
	local catalog = {
		{ key = "Tenkaichi", modelName = "Arena_Tenkaichi" },
		{ key = "JujutsuHigh", modelName = "Arena_JujutsuHigh" },
	}
	local clock, arenaCalls = 0, 0
	local config = {
		RootName = lobby.Name, RequestCooldown = 0.4, RootClearance = 3.5, SafeLandingOffset = 0.12,
		Destinations = {
			MainMode = { marker = story.Name }, Packs = { marker = summon.Name, lookAt = summonLook.Name },
			Ranked = { marker = ranked.Name }, Broken = { marker = "Missing" },
			BadLook = { marker = summon.Name, lookAt = "Missing" },
		},
	}
	local modules = {
		LobbyConfig = config,
		ArenaCatalog = {
			find = function(value)
				if type(value) == "number" then return catalog[value] end
				for _, entry in ipairs(catalog) do
					if value == entry.key or value == entry.modelName then return entry end
				end
			end,
		},
		ArenaConfig = {
			arenaName = "Arena_Tenkaichi",
			getArena = function(name)
				arenaCalls += 1
				return fakeWorkspace:FindFirstChild(name) or tenkaichi
			end,
		},
	}
	local travel = { IsA = function(_, class) return class == "RemoteFunction" end }
	local events = { WaitForChild = function(_, name) assert(name == "TravelRequest"); return travel end }
	local replicated = {
		WaitForChild = function(_, name)
			if name == "ArenaEvents" then return events end
			assert(modules[name], name)
			return { Name = name }
		end,
	}
	local fakeGame = { GetService = function(_, name)
		if name == "Players" then return players end
		if name == "ReplicatedStorage" then return replicated end
		error("Unexpected service " .. name)
	end }
	local run = assert(loadstring(serviceSource))
	setfenv(run, setmetatable({
		game = fakeGame, workspace = fakeWorkspace,
		require = function(token) return modules[token.Name] end,
		os = { clock = function() return clock end },
	}, { __index = getfenv() }))
	local checks = {}
	local function check(condition, name)
		assert(condition, name)
		table.insert(checks, name)
	end
	local function near(a, b)
		return (a.Position - b.Position).Magnitude < 0.0001
			and a.LookVector:Dot(b.LookVector) > 0.99999
	end
	local function request(action, destination, advance)
		if advance ~= false then clock += 1 end
		return travel.OnServerInvoke(player, action, destination)
	end
	local ok, result = pcall(function()
		run()
		local original = root.CFrame
		check(not request({}, nil), "Reject non-string action")
		check(not request("Destination", {}), "Reject non-string lobby destination")
		check(not request("Destination", "Unknown"), "Reject unlisted lobby destination")
		check(not request("Enter", "UnknownArena"), "Reject unknown arena without fallback")
		check(not request("Enter", false), "Reject false arena without default")
		check(arenaCalls == 0 and near(root.CFrame, original) and not root.Anchored,
			"Rejected requests do not resolve arena, move or anchor avatar")
		check(not request("Destination", "Broken"), "Reject missing marker before mutation")
		check(not request("Destination", "BadLook"), "Reject missing lookAt before mutation")
		check(near(root.CFrame, original) and player:GetAttribute("ActiveArena") == nil,
			"Unavailable destinations leave avatar and visit state unchanged")
		root.AssemblyLinearVelocity = Vector3.new(12, -50, 3)
		root.AssemblyAngularVelocity = Vector3.new(2, 3, 4)
		check(request("LobbyPortal"), "Legacy lobby request maps MainMode")
		check(math.abs(root.Position.Y - (story.Position.Y + 3.12)) < 0.0001,
			"R6 landing uses half root plus leg height and safe offset")
		check(root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0,
			"Teleport clears linear and angular velocities")
		check(math.abs(root.CFrame.LookVector.Y) < 0.0001, "Arrival facing stays horizontal")
		local landed = root.CFrame
		check(not request("PackPortal", nil, false) and near(root.CFrame, landed), "Cooldown prevents rapid second teleport")
		check(request("PackPortal"), "Legacy pack request maps Packs")
		local direction = summonLook.Position - summon.Position
		direction = Vector3.new(direction.X, 0, direction.Z).Unit
		check(root.CFrame.LookVector:Dot(direction) > 0.99999, "Pack arrival faces its configured lookAt marker")
		lobby:ScaleTo(1.5)
		lobby:PivotTo(CFrame.new(700, 100, -400) * lobby:GetPivot())
		check(request("Destination", "Ranked"), "Travel succeeds after lobby move and scale")
		check((root.Position - ranked.Position - Vector3.new(0, 3.12, 0)).Magnitude < 0.0001,
			"Travel uses transformed marker position and independent avatar clearance")
		local returnFrame = root.CFrame
		check(request("Enter"), "Nil arena retains legitimate legacy default")
		check(near(root.CFrame, arenaSpawn.CFrame * CFrame.new(0, 3, 0)) and root.Anchored,
			"Arena entry retains existing spawn and anchored contract")
		check(player:GetAttribute("ActiveArena") == "Arena_Tenkaichi" and player:GetAttribute("ArenaVisitOnly") == false,
			"Match entry sets existing arena attributes")
		check(not request("Destination", "Ranked"), "Lobby travel blocked during active match")
		check(not request("Visit", "JujutsuHigh"), "Arena switching blocked until Leave")
		check(request("Enter", "Tenkaichi", false), "Repeated identical entry is idempotent")
		check(request("Leave", nil, false), "Leave bypasses request cooldown")
		check(near(root.CFrame, returnFrame) and not root.Anchored and player:GetAttribute("ActiveArena") == nil,
			"Leave restores exact return pose, original anchoring and attributes")
		check(not request("Enter", "JujutsuHigh"), "Visit-only arena rejects combat entry")
		check(request("Visit", "JujutsuHigh") and player:GetAttribute("ArenaVisitOnly") == true,
			"Visit-only arena remains visitable")
		check(request("Leave", nil, false), "Visit return succeeds")
		local r15, root15, hum15 = character(true)
		player.CharacterRemoving:Fire(char)
		player.Character = r15
		root, humanoid = root15, hum15
		check(request("PackPortal"), "R15 teleport succeeds")
		check(math.abs(root.Position.Y - (summon.Position.Y + 3.52)) < 0.0001,
			"R15 landing uses HipHeight plus half root and safe offset")
		root.Anchored = true
		check(request("Visit", 2), "Numeric catalog entry remains supported")
		check(request("Leave", nil, false) and root.Anchored, "Leave restores an originally anchored character")
		root.Anchored = false
		check(request("Visit", "Tenkaichi"), "Entry before character removal succeeds")
		player.CharacterRemoving:Fire(r15)
		check(not root.Anchored and player:GetAttribute("ActiveArena") == nil, "Character removal clears and unanchors old visit")
		humanoid.Health = 0
		check(not request("PackPortal"), "Dead character cannot teleport")
		check(request("Leave", nil, false), "Dead character may clean up Leave")
		return { passed = true, count = #checks, checks = checks, liveWorkspaceTouched = false }
	end)
	owner:Destroy()
	if not ok then error(result) end
	return result
end

