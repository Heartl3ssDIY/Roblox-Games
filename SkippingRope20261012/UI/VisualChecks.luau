assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local fixture=Instance.new("Folder") fixture.Name,fixture.Parent="_SkippingVisualFixture",game.ServerStorage
local results={}
local function check(name,fn) local ok,err=xpcall(fn,debug.traceback) table.insert(results,{name=name,passed=ok,error=not ok and tostring(err) or nil}) end
local function signal()
	local callbacks={}
	return {Connect=function(_,fn) callbacks[fn]=true return {Disconnect=function() callbacks[fn]=nil end} end,
	Fire=function(_,...) for fn in pairs(callbacks) do fn(...) end end,Count=function() local n=0 for _ in pairs(callbacks) do n+=1 end return n end}
end
local outcome
local ok,failure=xpcall(function()
	local arena=Instance.new("Folder") arena.Name,arena.Parent="Skipping Rope",fixture
	local gameplay=Instance.new("Folder") gameplay.Name,gameplay.Parent="Gameplay",arena
	workspace["Skipping Rope"].Gameplay.Lanes:Clone().Parent=gameplay
	local state=Instance.new("Folder") state.Parent=fixture
	state:SetAttribute("Phase","Waiting") state:SetAttribute("StartedAt",0) state:SetAttribute("RoundDuration",120)
	local mathModule=game.ReplicatedStorage.SkippingRopeMath:Clone() mathModule.Parent=fixture
	local RopeMath=require(mathModule)
	local render,destroy=signal(),signal()
	local env={now=0}
	env.workspace={GetServerTimeNow=function() return env.now end,FindFirstChild=function(_,name) return name=="Skipping Rope" and arena or nil end}
	local services={RunService={RenderStepped=render},ReplicatedStorage={WaitForChild=function(_,name) return name=="SkippingRopeMath" and mathModule or name=="SkippingRopeState" and state or nil end}}
	env.game={GetService=function(_,name) return assert(services[name],name) end}
	env.script={Destroying=destroy}
	local module=Instance.new("ModuleScript") module.Name="VisualsCandidate"
	module.Source="return function(env)\nlocal game,workspace,script=env.game,env.workspace,env.script\n"..game.StarterPlayer.StarterPlayerScripts.SkippingRopeVisuals.Source.."\nend"
	module.Parent=fixture
	require(module)(env)
	local originalArms={}
	for _,lane in gameplay.Lanes:GetChildren() do
		for _,name in {"LeftTurner","RightTurner"} do local arm=lane[name].TurnArm originalArms[arm]=arm:GetAttribute("TurnBaseCFrame") or arm:GetPivot() end
	end
	local function verifyPose(time,phase)
		env.now=time state:SetAttribute("Phase",phase) render:Fire(0.1)
		local elapsed=phase=="Playing" and math.clamp(time,0,120) or phase=="Results" and math.clamp(state:GetAttribute("FinishedAt") or 120,0,120) or 0
		local angle=RopeMath.GetAngle(elapsed)
		for _,lane in gameplay.Lanes:GetChildren() do
			local origin=lane.RopeOrigin.CFrame
			local settings={halfSpan=lane:GetAttribute("RopeHalfSpan"),flatHalfSpan=lane:GetAttribute("RopeFlatHalfSpan"),radius=lane:GetAttribute("RopeRadius"),pivotHeight=lane:GetAttribute("RopePivotHeight")}
			for _,part in lane.RopeSegments:GetChildren() do
				local a=origin:PointToWorldSpace(RopeMath.Point(angle,part:GetAttribute("RopeStartX"),settings))
				local b=origin:PointToWorldSpace(RopeMath.Point(angle,part:GetAttribute("RopeEndX"),settings))
				assert((part.Position-(a+b)*0.5).Magnitude<0.025,"Rope render differs from hit path")
				assert(math.abs(part.Size.X-(a-b).Magnitude-0.035)<0.025,"Rope gap")
				assert(not part.CanCollide and not part.CanTouch and not part.CanQuery,"Rope physical barrier")
			end
			for _,name in {"LeftTurner","RightTurner"} do
				local turner=lane[name] local arm=turner.TurnArm local pivot=CFrame.new(turner.TurnPivot.Position)
				local expected=pivot*CFrame.fromAxisAngle(origin.RightVector,-(angle-math.pi))*pivot:Inverse()*originalArms[arm]
				local actual=arm:GetPivot()
				assert((actual.Position-expected.Position).Magnitude<0.025 and actual.UpVector:Dot(expected.UpVector)>0.999,"Turner pose drift")
			end
		end
	end
	check("Waiting ropes rest overhead",function() verifyPose(0,"Waiting") end)
	for _,time in ipairs({0.5,1.8,9.999,10,10.001,30,60,110,119.9}) do
		check("Visual matches server path and six arms at "..time,function() verifyPose(time,"Playing") end)
	end
	check("Results hold the ending pose",function() verifyPose(130,"Results") end)
	check("All-out results freeze at the actual finish time",function()
		state:SetAttribute("FinishedAt",24.75) verifyPose(131,"Results") state:SetAttribute("FinishedAt",nil)
	end)
	check("Next waiting resets rope and arms overhead",function() verifyPose(132,"Waiting") end)
	check("Late streamed rope part restores at its authored span",function()
		local lane=gameplay.Lanes.Lane01 local part=lane.RopeSegments:FindFirstChildWhichIsA("BasePart")
		local saved=part:Clone() part:Destroy() env.now=135 render:Fire(0.1)
		saved.Parent=lane.RopeSegments verifyPose(136,"Playing")
	end)
	destroy:Fire()
	check("Visual cleanup disconnects render and restores six rigs",function()
		assert(render:Count()==0)
		for arm,base in pairs(originalArms) do assert((arm:GetPivot().Position-base.Position).Magnitude<0.025 and arm:GetPivot().UpVector:Dot(base.UpVector)>0.999) end
	end)
	local passed=true for _,r in results do if not r.passed then passed=false end end
	outcome={passed=passed,checkCount=#results,checks=results}
end,debug.traceback)
fixture:Destroy()
assert(ok,failure)
return outcome
