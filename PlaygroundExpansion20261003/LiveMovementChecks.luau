local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local state = ReplicatedStorage:WaitForChild("TagState")
local arena = workspace:WaitForChild("Tag You're It")

if RunService:IsServer() then
	assert(state:GetAttribute("Phase") == "Playing", "Start Tag practice before preparing movement QA")
	local player
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate:GetAttribute("TGParticipating") then player = candidate break end
	end
	assert(player and player.Character, "A real Tag player is required")
	local folder = ReplicatedStorage:FindFirstChild("TagMovementCheckState")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "TagMovementCheckState"
	local root = player.Character:WaitForChild("HumanoidRootPart")
	local center = arena.Gameplay.TaggerSpawn.Position
	folder:SetAttribute("PlayerUserId", player.UserId)
	folder:SetAttribute("SavedCFrame", root.CFrame)
	folder:SetAttribute("DodgeCFrame", CFrame.lookAt(center + Vector3.new(0, 0, 14), center + Vector3.new(30, 0, 14)))
	local vault
	for _, part in ipairs(arena.Gameplay.VaultObstacles:GetChildren()) do
		if part:IsA("BasePart") and part:GetAttribute("Vaultable") then vault = part break end
	end
	assert(vault, "Expected an authored vault hurdle")
	local forward = vault.CFrame.LookVector
	local approach = vault.Position - forward * (vault.Size.Z / 2 + 3.2)
	approach = Vector3.new(approach.X, center.Y, approach.Z)
	folder:SetAttribute("VaultCFrame", CFrame.lookAt(approach, approach + forward))
	folder:SetAttribute("VaultCenter", vault.Position)
	folder:SetAttribute("VaultForward", forward)
	folder:SetAttribute("VaultDepth", vault.Size.Z)
	folder:SetAttribute("VaultTopY", vault.Position.Y + vault.Size.Y / 2)
	local bots = workspace:FindFirstChild("TagPracticeBots")
	if bots then
		for _, character in ipairs(bots:GetChildren()) do
			local botRoot = character:FindFirstChild("HumanoidRootPart")
			if botRoot then
				botRoot:SetAttribute("QAMovementOriginalAnchored", botRoot.Anchored)
				botRoot.Anchored = true
			end
		end
	end
	folder.Parent = ReplicatedStorage
	return { prepared = true, player = player.Name, vault = vault.Name, instructions = "Run this same file in Client, then use Stop Game to clean up practice bots." }
end

assert(RunService:IsClient(), "Run in Server or Client Play")
local player = Players.LocalPlayer
local fixture = ReplicatedStorage:WaitForChild("TagMovementCheckState", 5)
assert(fixture and fixture:GetAttribute("PlayerUserId") == player.UserId, "Run Server preparation first")
assert(player:GetAttribute("TGParticipating") and state:GetAttribute("Phase") == "Playing", "Active Tag practice required")
local character = player.Character
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("TagMovementRequest")
local output = { checks = {}, measurements = {} }
local function check(name, condition)
	assert(condition, name)
	table.insert(output.checks, name)
end
local function place(cframe)
	character:PivotTo(cframe * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local untilTime = workspace:GetServerTimeNow() + 0.9
	repeat task.wait(0.05) until humanoid.FloorMaterial ~= Enum.Material.Air or workspace:GetServerTimeNow() >= untilTime
	check("Player grounded before move", humanoid.FloorMaterial ~= Enum.Material.Air)
	task.wait(0.2)
end
local function sample(duration, first)
	first = first or root.Position
	local maximumY, maximumSpeed = first.Y, 0
	local untilTime = workspace:GetServerTimeNow() + duration
	repeat
		RunService.Heartbeat:Wait()
		maximumY = math.max(maximumY, root.Position.Y)
		maximumSpeed = math.max(maximumSpeed, Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude)
	until workspace:GetServerTimeNow() >= untilTime
	return { start = first, finish = root.Position, rise = maximumY - first.Y, maximumY = maximumY, maximumSpeed = maximumSpeed,
		distance = Vector3.new(root.Position.X - first.X, 0, root.Position.Z - first.Z).Magnitude }
end
local ok, failure = xpcall(function()
	place(fixture:GetAttribute("DodgeCFrame"))
	local origin = root.Position
	local accepted, reason = remote:InvokeServer("Dodge")
	check("Dodge request accepted", accepted == true)
	local movement = sample(0.55, origin)
	output.measurements.dodge = movement
	check("Dodge creates physical forward movement", movement.distance > 1.5)
	check("Dodge stays grounded", movement.rise < 2)
	check("Dodge constraint cleaned up", not root:FindFirstChild("TGBurstVelocity") and not root:FindFirstChild("TGBurstAttachment"))
	accepted, reason = remote:InvokeServer("Dodge")
	check("Repeated dodge is refused during cooldown", accepted == false)
	place(fixture:GetAttribute("VaultCFrame"))
	origin = root.Position
	accepted, reason = remote:InvokeServer("Vault")
	check("Vault request accepted", accepted == true)
	movement = sample(1, origin)
	output.measurements.vault = movement
	check("Vault produces upward movement", movement.rise > 2.8)
	local clearance = movement.maximumY - (root.Size.Y / 2 + (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight))
	check("Vault body clears the hurdle top", clearance > fixture:GetAttribute("VaultTopY"))
	local beyond = (root.Position - fixture:GetAttribute("VaultCenter")):Dot(fixture:GetAttribute("VaultForward"))
	output.measurements.vaultDistanceBeyond = beyond
	check("Vault reaches the other side of the hurdle", beyond > fixture:GetAttribute("VaultDepth") / 2 + 0.5)
	check("Vault lands alive inside the arena", humanoid.Health > 0 and player:GetAttribute("TGParticipating"))
	check("Vault constraint cleaned up", not root:FindFirstChild("TGBurstVelocity") and not root:FindFirstChild("TGBurstAttachment"))
	accepted, reason = remote:InvokeServer("Vault")
	check("Repeated vault is refused during cooldown", accepted == false)
end, debug.traceback)
place(fixture:GetAttribute("SavedCFrame"))
output.passed = #output.checks
output.ok = ok
output.failure = ok and nil or failure
return output
