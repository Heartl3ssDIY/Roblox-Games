local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RopeMath = require(ReplicatedStorage:WaitForChild("SkippingRopeMath"))
local state = ReplicatedStorage:WaitForChild("SkippingRopeState")
local laneCache, connections = {}, {}
local accumulator, refreshAt = 0, 0
local function discover()
	local arena = workspace:FindFirstChild("Skipping Rope")
	local gameplay = arena and arena:FindFirstChild("Gameplay")
	local lanes = gameplay and gameplay:FindFirstChild("Lanes")
	for model in pairs(laneCache) do if not lanes or model.Parent ~= lanes then laneCache[model] = nil end end
	if not lanes then return end
	for _, model in lanes:GetChildren() do
		local origin, segments = model:FindFirstChild("RopeOrigin"), model:FindFirstChild("RopeSegments")
		if origin and origin:IsA("BasePart") and segments then
			local entry = laneCache[model]
			if not entry then entry = {model=model,origin=origin,parts={},arms={}} laneCache[model]=entry end
			entry.origin=origin
			entry.settings={halfSpan=model:GetAttribute("RopeHalfSpan") or 26,flatHalfSpan=model:GetAttribute("RopeFlatHalfSpan") or 16,
				radius=model:GetAttribute("RopeRadius") or 8,pivotHeight=model:GetAttribute("RopePivotHeight") or 8.8}
			entry.parts={}
			for _, part in segments:GetChildren() do if part:IsA("BasePart") then table.insert(entry.parts,part) end end
			table.sort(entry.parts,function(a,b) return a.Name<b.Name end)
			for _,name in {"LeftTurner","RightTurner"} do
				local turner=model:FindFirstChild(name)
				local arm=turner and turner:FindFirstChild("TurnArm")
				local pivot=turner and turner:FindFirstChild("TurnPivot")
				local previous=entry.arms[name]
				if arm and arm:IsA("Model") and pivot and pivot:IsA("BasePart") then
					if not previous or previous.arm~=arm or previous.pivot~=pivot then
						entry.arms[name]={arm=arm,pivot=pivot,base=arm:GetAttribute("TurnBaseCFrame") or arm:GetPivot()}
					end
				else entry.arms[name]=nil end
			end
		end
	end
end
local function cylinder(part, first, last, up)
	local offset=last-first
	if offset.Magnitude<0.001 then return end
	local right=offset.Unit
	local y=up-right*up:Dot(right)
	if y.Magnitude<0.001 then y=Vector3.zAxis-right*Vector3.zAxis:Dot(right) end
	y=y.Unit
	part.CFrame=CFrame.fromMatrix((first+last)*0.5,right,y,right:Cross(y))
	if math.abs(part.Size.X-offset.Magnitude-0.035)>0.001 then part.Size=Vector3.new(offset.Magnitude+0.035,part.Size.Y,part.Size.Z) end
end
local function render(dt)
	local now=workspace:GetServerTimeNow()
	if now>=refreshAt then discover() refreshAt=now+0.5 end
	if not next(laneCache) then return end
	local phase=state:GetAttribute("Phase")
	local active=phase=="Playing"
	accumulator+=dt
	if not active and accumulator<1/15 then return end
	accumulator=0
	local started=state:GetAttribute("StartedAt") or now
	local duration=state:GetAttribute("RoundDuration") or 120
	local finished=state:GetAttribute("FinishedAt") or started+duration
	local elapsed=active and math.clamp(now-started,0,duration) or phase=="Results" and math.clamp(finished-started,0,duration) or 0
	local angle=RopeMath.GetAngle(elapsed)
	for _,entry in pairs(laneCache) do
		local count=#entry.parts
		if count>0 and entry.origin.Parent then
			local origin, settings=entry.origin.CFrame,entry.settings
			for index,part in ipairs(entry.parts) do
				if part.Parent then
					local firstX=part:GetAttribute("RopeStartX") or (-settings.halfSpan+(index-1)*2*settings.halfSpan/count)
					local lastX=part:GetAttribute("RopeEndX") or (-settings.halfSpan+index*2*settings.halfSpan/count)
					cylinder(part,origin:PointToWorldSpace(RopeMath.Point(angle,firstX,settings)),origin:PointToWorldSpace(RopeMath.Point(angle,lastX,settings)),origin.UpVector)
				end
			end
			for _,rig in pairs(entry.arms) do
				if rig.arm.Parent and rig.pivot.Parent then
					local anchor=CFrame.new(rig.pivot.Position)
					local rotation=CFrame.fromAxisAngle(origin.RightVector,-(angle-math.pi))
					rig.arm:PivotTo(anchor*rotation*anchor:Inverse()*rig.base)
				end
			end
		end
	end
end
table.insert(connections,RunService.RenderStepped:Connect(render))
table.insert(connections,script.Destroying:Connect(function()
	for _,connection in connections do connection:Disconnect() end
	for _,entry in pairs(laneCache) do
		for _,rig in pairs(entry.arms) do if rig.arm.Parent then rig.arm:PivotTo(rig.base) end end
	end
	table.clear(laneCache)
end))
discover()