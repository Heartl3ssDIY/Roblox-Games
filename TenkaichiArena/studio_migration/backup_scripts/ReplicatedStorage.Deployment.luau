--!strict
-- Deployment: spawns unit models onto the arena field. No combat yet —
-- units stand at their start positions facing the enemy side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage.UnitData)
local ArenaConfig = require(ReplicatedStorage.ArenaConfig)
local UnitModels = ReplicatedStorage:WaitForChild("UnitModels")

local Deployment = {}

-- Track how many units are on each (side,line) so new ones spread out.
-- Keyed "side|line" -> count.
local lineCounts = {}

-- Folder in workspace holding all deployed units this match.
local function getDeployFolder()
	local arena = workspace:FindFirstChild(ArenaConfig.arenaName)
	if not arena then return nil end
	local f = arena:FindFirstChild("DeployedUnits")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DeployedUnits"
		f.Parent = arena
	end
	return f
end

function Deployment.reset()
	lineCounts = {}
	local arena = workspace:FindFirstChild(ArenaConfig.arenaName)
	local f = arena and arena:FindFirstChild("DeployedUnits")
	if f then f:Destroy() end
end

-- Deploy a unit by id onto a side ("player"|"opponent"). Returns the model.
function Deployment.deploy(unitId: string, side: string)
	local unit = UnitData.get(unitId)
	if not unit then warn("[Deploy] unknown unit "..tostring(unitId)); return nil end
	local tmpl = UnitModels:FindFirstChild(unit.model)
	if not tmpl then warn("[Deploy] no model for "..unit.model); return nil end

	local line = ArenaConfig.lineForUnit(unit)
	local key = side .. "|" .. line
	local idx = lineCounts[key] or 0
	lineCounts[key] = idx + 1
	-- recompute positions for all on this line so they stay centred as count grows
	local count = lineCounts[key]
	local pos = ArenaConfig.slotPosition(side, line, idx, count)

	local model = tmpl:Clone()
	model.Name = unit.name .. "_" .. side .. "_" .. idx
	local hrp = model:FindFirstChild("HumanoidRootPart")

	-- Weld any "orphan" parts (heads/hair/faces/accessory handles) that have no
	-- Motor6D joint to a body part, so they stay attached once we unanchor. Done
	-- BEFORE unanchoring, while everything is still in its template pose.
	local mainBody = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or hrp
	local head = model:FindFirstChild("Head")
	if mainBody then
		-- which parts are already connected via a Motor6D (as Part1)?
		local jointed = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 then jointed[d.Part1] = true end
		end
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p ~= hrp and p ~= mainBody and not jointed[p] then
				-- weld to the head if it's a face/hair part and a head exists, else to body
				local anchorTo = mainBody
				local lname = p.Name:lower()
				if head and (lname:find("hair") or lname:find("face") or lname:find("hat")) then
					anchorTo = head
				end
				local w = Instance.new("WeldConstraint")
				w.Part0 = anchorTo
				w.Part1 = p
				w.Parent = anchorTo
			end
		end
	end

	-- Anchor ONLY the HumanoidRootPart; leave limbs unanchored so their Motor6D
	-- joints can pose them for attack animations. The rig hangs rigidly from the
	-- anchored root (no gravity fall). Limbs are non-collidable to avoid jitter.
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = (p == hrp)
			p.CanCollide = false
			p.Massless = (p ~= hrp)
		end
	end
	-- Keep the Humanoid from auto-stating/ragdolling the unanchored rig.
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		hum.AutoRotate = false
	end
	-- tag with metadata for later combat use
	model:SetAttribute("UnitId", unitId)
	model:SetAttribute("Side", side)
	model:SetAttribute("Line", line)

	local facing = ArenaConfig.facing(side)
	local look = pos + facing
	model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 2.5, 0), look + Vector3.new(0, 2.5, 0)))
	model.Parent = getDeployFolder()

	-- re-center existing units on this line now that count changed
	Deployment.recenterLine(side, line)
	return model
end

-- Reposition all units currently on (side,line) so they're evenly centred.
function Deployment.recenterLine(side: string, line: string)
	local f = getDeployFolder()
	if not f then return end
	local onLine = {}
	for _, m in ipairs(f:GetChildren()) do
		if m:GetAttribute("Side") == side and m:GetAttribute("Line") == line then
			table.insert(onLine, m)
		end
	end
	local count = #onLine
	for i, m in ipairs(onLine) do
		local pos = ArenaConfig.slotPosition(side, line, i-1, count)
		local facing = ArenaConfig.facing(side)
		m:PivotTo(CFrame.lookAt(pos + Vector3.new(0,2.5,0), pos + facing + Vector3.new(0,2.5,0)))
	end
end

return Deployment

