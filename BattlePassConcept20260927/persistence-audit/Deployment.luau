local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage.UnitData)
local ArenaConfig = require(ReplicatedStorage.ArenaConfig)
local AttackAnimator = require(ReplicatedStorage.AttackAnimator)
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")
local Deployment = {}
local nextIndex = 0

function Deployment.getFolder()
	local arena = ArenaConfig.getArena()
	if not arena then return nil end
	local folder = arena:FindFirstChild("DeployedUnits")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DeployedUnits"
		folder.Parent = arena
	end
	return folder
end

function Deployment.reset()
	AttackAnimator.stopAll()
	nextIndex = 0
	local arena = ArenaConfig.getArena()
	local folder = arena and arena:FindFirstChild("DeployedUnits")
	if folder then folder:Destroy() end
end

local function prepareRig(model, root)
	model.PrimaryPart = root
	local connected = { [root] = true }
	local joints = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			table.insert(joints, item)
		elseif item:IsA("BaseScript") then
			item:Destroy()
		end
	end
	for _ = 1, #joints + 1 do
		local changed = false
		for _, joint in ipairs(joints) do
			local a, b = joint.Part0, joint.Part1
			if a and b and (connected[a] or connected[b]) and not (connected[a] and connected[b]) then
				connected[a], connected[b] = true, true
				changed = true
			end
		end
		if not changed then break end
	end
	local body = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or root
	local head = model:FindFirstChild("Head") or body
	local lowest = root.Position.Y - 2.5
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if not connected[part] then
				local weld = Instance.new("WeldConstraint")
				local name = part.Name:lower()
				weld.Part0 = (name:find("hair") or name:find("face") or part.Parent:IsA("Accessory")) and head or body
				weld.Part1 = part
				weld.Parent = part
			end
			if part.Parent == model and (part.Name:find("Leg") or part.Name:find("Foot")) then
				local cf, size = part.CFrame, part.Size
				local height = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
				lowest = math.min(lowest, part.Position.Y - height / 2)
			end
			part.Anchored = part == root
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = part ~= root
		end
	end
	model:SetAttribute("RootHeight", root.Position.Y - lowest)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function Deployment.recenterLine(side, line)
	local folder = Deployment.getFolder()
	if not folder then return end
	local models = {}
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Side") == side and model:GetAttribute("Line") == line then
			table.insert(models, model)
		end
	end
	table.sort(models, function(a, b) return a:GetAttribute("SpawnIndex") < b:GetAttribute("SpawnIndex") end)
	for i, model in ipairs(models) do
		local position = ArenaConfig.slotPosition(side, line, i - 1, #models) + Vector3.new(0, model:GetAttribute("RootHeight"), 0)
		model:PivotTo(CFrame.lookAt(position, position + ArenaConfig.facing(side)))
	end
end

function Deployment.deploy(unitId, side)
	local unit = UnitData.get(unitId)
	local template = unit and UnitModels:FindFirstChild(unit.model)
	local folder = Deployment.getFolder()
	if not template or not folder or (side ~= "player" and side ~= "opponent") then return nil end
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then model:Destroy() return nil end
	nextIndex += 1
	local line = ArenaConfig.lineForUnit(unit)
	model.Name = unitId .. "_" .. side .. "_" .. nextIndex
	model:SetAttribute("UnitId", unitId)
	model:SetAttribute("Side", side)
	model:SetAttribute("Line", line)
	model:SetAttribute("SpawnIndex", nextIndex)
	prepareRig(model, root)
	model.Parent = folder
	Deployment.recenterLine(side, line)
	return model
end

return Deployment
