local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local state = ReplicatedStorage:WaitForChild("BritishBulldogState")
local arena = workspace["British Bulldog game"]

if RunService:IsServer() then
	local untilTime = workspace:GetServerTimeNow() + 4
	while state:GetAttribute("Phase") == "Countdown" and workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end
	assert(state:GetAttribute("Phase") == "Crossing", "Start Runner practice before movement QA")
	local player
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate:GetAttribute("BBParticipating") and candidate:GetAttribute("BBRole") == "Runner" then player = candidate break end
	end
	assert(player and player.Character, "Real Runner practice player required")
	local old = ReplicatedStorage:FindFirstChild("BBMovementCheckState")
	if old then old:Destroy() end
	local fixture = Instance.new("Folder")
	fixture.Name = "BBMovementCheckState"
	local bounds = arena.Gameplay.ArenaBounds
	local spawn = arena.Gameplay.BulldogSpawns:GetChildren()[1]
	local start = Vector3.new(bounds.Position.X + 30, spawn.Position.Y, bounds.Position.Z)
	local root = player.Character.HumanoidRootPart
	local cframe = CFrame.lookAt(start, start + bounds.CFrame.RightVector)
	player.Character:PivotTo(cframe * root.CFrame:Inverse() * player.Character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	fixture:SetAttribute("PlayerUserId", player.UserId)
	fixture:SetAttribute("StartCFrame", cframe)
	fixture:SetAttribute("Right", bounds.CFrame.RightVector)
	fixture:SetAttribute("BoundaryCFrame", CFrame.new(bounds.CFrame:PointToWorldSpace(Vector3.new(bounds.Size.X / 2 - 4, spawn.Position.Y - bounds.Position.Y, 0))))
	local bots = workspace:FindFirstChild("BritishBulldogPracticeBots")
	assert(bots, "Runner practice Bulldog required")
	local count = 0
	for _, character in ipairs(bots:GetChildren()) do
		local botRoot = character:FindFirstChild("HumanoidRootPart")
		if botRoot then
			local target = CFrame.new(start + Vector3.new(0, 0, 7))
			character:PivotTo(target * botRoot.CFrame:Inverse() * character:GetPivot())
			botRoot.AssemblyLinearVelocity = Vector3.zero
			botRoot.Anchored = true
			count += 1
		end
	end
	assert(count > 0, "No practice Bulldog rig found")
	fixture.Parent = ReplicatedStorage
	return { prepared = true, player = player.Name, instructions = "Run same file in Client. Stop Game afterward removes anchored practice bots." }
end

local player = Players.LocalPlayer
local fixture = ReplicatedStorage:WaitForChild("BBMovementCheckState", 5)
assert(fixture and fixture:GetAttribute("PlayerUserId") == player.UserId, "Run Server preparation first")
assert(player:GetAttribute("BBRole") == "Runner" and state:GetAttribute("Phase") == "Crossing", "Active Runner practice required")
local character = player.Character
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("BBMovementRequest")
local output = { checks = {}, measurements = {} }
local movingConnection
local function check(condition, name)
	assert(condition, name)
	table.insert(output.checks, name)
end
local function place(cframe)
	character:PivotTo(cframe * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.wait(0.35)
	check(humanoid.FloorMaterial ~= Enum.Material.Air, "Runner grounded before action")
end
local function stopMoving()
	if movingConnection then movingConnection:Disconnect() movingConnection = nil end
	humanoid:Move(Vector3.zero, false)
end
local ok, failure = xpcall(function()
	place(fixture:GetAttribute("StartCFrame"))
	check(player:GetAttribute("BBSprintMax") == 10, "Live Runner pool is10s")
	local first = root.Position
	local pool = player:GetAttribute("BBSprintRemaining")
	check(remote:InvokeServer("Sprint", true).ok, "Live sprint hold accepted")
	movingConnection = RunService.PreSimulation:Connect(function() humanoid:Move(fixture:GetAttribute("Right"), false) end)
	task.wait(0.6)
	stopMoving()
	local distance = Vector3.new(root.Position.X - first.X, 0, root.Position.Z - first.Z).Magnitude
	local remaining = player:GetAttribute("BBSprintRemaining")
	output.measurements.sprint = { distance = distance, poolBefore = pool, poolAfter = remaining, speed = humanoid.WalkSpeed }
	check(distance > 12, "Sprint physically exceeds normal walking distance")
	check(humanoid.WalkSpeed == 40, "Live Runner sprint speed is40")
	check(remaining < pool - 0.2, "Actual moving sprint consumes stamina")
	check(remote:InvokeServer("Sprint", false).ok, "Live sprint release accepted")
	task.wait(0.35)
	check(humanoid.WalkSpeed == 16, "Release restores base Runner speed")
	check(player:GetAttribute("BBSprintRemaining") > remaining, "Release recharges live stamina")
	place(fixture:GetAttribute("StartCFrame"))
	check(remote:InvokeServer("Sprint", true).ok, "Stationary hold accepted")
	pool = player:GetAttribute("BBSprintRemaining")
	task.wait(0.35)
	check(math.abs(player:GetAttribute("BBSprintRemaining") - pool) < 0.2, "Stationary hold does not drain live stamina")
	task.wait(0.85)
	check(humanoid.WalkSpeed == 16 and player:GetAttribute("BBSprinting") ~= true, "Unrefreshed hold lease expires safely")
	place(fixture:GetAttribute("StartCFrame"))
	first = root.Position
	local response = remote:InvokeServer("Dodge", 1)
	check(response.ok, "Live lateral dodge accepted")
	task.wait(0.55)
	distance = (root.Position - first).Magnitude
	output.measurements.dodge = { distance = distance, role = player:GetAttribute("BBRole"), speed = humanoid.WalkSpeed,
		boostEndsAt = player:GetAttribute("BBBoostEndsAt"), confirmedAt = player:GetAttribute("BBDodgeConfirmedAt") }
	check(distance > 5, "Lateral dodge physically moves runner")
	check(player:GetAttribute("BBRole") == "Runner", "Close dodge grants no automatic tag")
	check(player:GetAttribute("BBDodgeConfirmedAt") > 0 and player:GetAttribute("BBBoostEndsAt") > workspace:GetServerTimeNow(), "Survived close threat confirms temporary boost")
	check(humanoid.WalkSpeed == 32, "Live dodge boost is2x base speed")
	check(not root:FindFirstChild("BBDodgeVelocity") and not root:FindFirstChild("BBDodgeAttachment"), "Dodge actuator cleanup completed")
	check(not remote:InvokeServer("Dodge", -1).ok, "Live dodge cooldown rejects immediate repeat")
	check(remote:InvokeServer("Sprint", true).ok, "Sprint accepted during live boost")
	task.wait(0.1)
	check(humanoid.WalkSpeed == 40, "Live Sprint plus boost does not stack")
	remote:InvokeServer("Sprint", false)
	local untilTime = (player:GetAttribute("BBBoostEndsAt") or 0) + 0.15
	while workspace:GetServerTimeNow() < untilTime do task.wait(0.05) end
	check(humanoid.WalkSpeed == 16, "Live escape boost expires")
end, debug.traceback)
stopMoving()
remote:InvokeServer("Sprint", false)
output.ok = ok
output.failure = ok and nil or failure
output.passed = #output.checks
return output
