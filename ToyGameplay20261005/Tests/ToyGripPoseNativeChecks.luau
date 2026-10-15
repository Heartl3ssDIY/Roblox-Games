assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local fixtureName = "ToyGripPosePreview20261005"
assert(not workspace:FindFirstChild(fixtureName), "Previous preview must be cleaned first")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = fixtureName, workspace
local report = { checks = {}, metrics = {}, fixture = folder:GetFullName(), playStarted = false, limitation = "Edit dummy has no real Player Backpack or automatic RightGrip generation. _makeGear initial container is its rig; preview grip is synthesized from native hand attachment or captured fixture C0 and Tool.Grip. Equipment welding and native pose functions execute under exact capabilities. Player Backpack transfer and automatic grip creation require later user testing." }
local services = {}
local function check(value, message)
	assert(value, message)
	table.insert(report.checks, message)
end
local function closeFrame(a,b)
	return (a.Position-b.Position).Magnitude<0.0001 and a.LookVector:Dot(b.LookVector)>0.99999 and a.UpVector:Dot(b.UpVector)>0.99999
end
local ok, problem = xpcall(function()
	local liveEquipment = game.ServerScriptService.PlaygroundEquipmentService
	local equipmentModule = liveEquipment:Clone()
	equipmentModule.Name, equipmentModule.Parent = "ExactEquipment", folder
	local Equipment = require(equipmentModule)
	local liveMotion = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local motionModule = Instance.new("ModuleScript")
	motionModule.Name = "ExactToyPoseHelpers"
	motionModule.Capabilities, motionModule.Sandboxed = liveMotion.Capabilities, liveMotion.Sandboxed
	motionModule.Source = assert((_G.ToyMotionCandidate or liveMotion.Source):match("^(.-)local beforeAnimation ="))
		.. "\nreturn {sample=sampleToyPose,apply=applyToyPose,animate=animateToy,restore=restore,collect=collectJoints}"
	motionModule.Parent = folder
	local animation = require(motionModule)
	check(equipmentModule.Capabilities==liveEquipment.Capabilities and equipmentModule.Sandboxed==liveEquipment.Sandboxed, "Equipment preserves exact live capabilities")
	check(motionModule.Capabilities==liveMotion.Capabilities and motionModule.Sandboxed==liveMotion.Sandboxed, "Motion preserves exact live capabilities")
	check(not tostring(motionModule.Capabilities):find("Input"), "Animation still has no Input capability")
	local catalog = require(game.ReplicatedStorage.PlaygroundCatalog)
	local sources = game.ReplicatedStorage.PlaygroundCosmeticAssets
	local cases = { M01={action="Kick",time=.60,index=1}, M04={action="BarrelThrow",time=.40,index=2}, M05={action="Drink",time=.82,index=3} }
	for row, rigName in ipairs({"R6","R15"}) do
		local rig = game.ServerStorage.WeaponRigFixtures[rigName]:Clone()
		rig.Name = "Audit"..rigName
		local originalHand=rig:FindFirstChild("RightHand") or rig:FindFirstChild("Right Arm")
		local originalGrip=originalHand:FindFirstChild("RightGrip")
		local nativeC0=rigName=="R6" and originalGrip and originalGrip.C0 or originalHand:FindFirstChild("RightGripAttachment") and originalHand.RightGripAttachment.CFrame
		assert(nativeC0,"Native fixture has no hand grip frame")
		for _,child in ipairs(rig:GetDescendants()) do
			if child:IsA("Tool") or child:IsA("LuaSourceContainer") then child:Destroy() end
			if child.Name=="RightGrip" and child:IsA("JointInstance") then child:Destroy() end
		end
		rig.Parent = folder
		rig:PivotTo(CFrame.new(0,800,0))
		local backpack = Instance.new("Backpack")
		backpack.Parent = folder
		local attrs = {PCDataReady=true}
		local player = {Character=rig,Parent=game.Players}
		function player:GetAttribute(key) return attrs[key] end
		function player:SetAttribute(key,value) attrs[key]=value end
		function player:FindFirstChildOfClass(class) return class=="Backpack" and backpack or nil end
		local held, cancelled = 0, 0
		local toys = {Hold=function()held+=1 end,CancelAction=function()cancelled+=1 end}
		local equipment = Equipment.new(nil,toys)
		function equipment:_queue() end
		local record = {player=player,character=rig,gearConnections={}}
		table.insert(services,{equipment=equipment,record=record})
		for index=1,15 do
			local id=string.format("M%02d",index)
			attrs.PCGear=id
			equipment:_makeGear(record,assert(catalog.ById[id]),rig,assert(sources:FindFirstChild(id)))
			task.wait()
			local tool=assert(record.gear,"Missing gear "..id)
			local handle=assert(tool:FindFirstChild("Handle"))
			local visual=assert(tool:FindFirstChild("Visual"))
			local hand=rig:FindFirstChild("RightHand") or rig:FindFirstChild("Right Arm")
			local grip=Instance.new("Weld")
			grip.Name,grip.Part0,grip.Part1,grip.C0,grip.C1="RightGrip",hand,handle,nativeC0,tool.Grip
			grip.Parent=hand
			check(tool.Parent==rig and rig:GetAttribute("PCToyHeld")==id,rigName.." "..id.." equips and mirrors held state")
			check(grip.Part0==hand and grip.Part1==handle and grip.C1==tool.Grip,rigName.." "..id.." preview uses native hand frame and authored tool grip")
			local parts, bad, welded = 0, false, {}
			for _,child in ipairs(visual:GetDescendants()) do
				if child:IsA("BasePart") then
					parts+=1
					bad=bad or child.Anchored or not child.Massless or child.CanCollide or child.CanTouch or child.CanQuery
				elseif child:IsA("WeldConstraint") and child.Part0 and child.Part1 then table.insert(welded,{child.Part0,child.Part1}) end
			end
			local reachable={[handle]=true}
			for pass=1,20 do for _,pair in ipairs(welded) do if reachable[pair[1]] then reachable[pair[2]]=true end if reachable[pair[2]] then reachable[pair[1]]=true end end end
			for _,child in ipairs(visual:GetDescendants()) do if child:IsA("BasePart") and not reachable[child] then bad=true end end
			check(parts>0 and not bad,rigName.." "..id.." all visible parts are safe and welded")
			if cases[id] then
				local case=cases[id]
				local joints=animation.collect(rig)
				local originals={}
				for _,joint in pairs(joints) do originals[joint]=joint.Transform end
				local animationRecord={joints={}}
				animation.apply(animationRecord,joints,animation.sample(id,case.action,case.time),rigName=="R6",1)
				local shoulder=joints[rigName=="R6" and "Right Shoulder" or "RightShoulder"]
				check(not closeFrame(shoulder.Transform,originals[shoulder]),rigName.." "..id.." native pose changes shoulder")
				local preview=rig:Clone()
				preview.Name=rigName.."_"..id.."_"..case.action
				preview.Parent=folder
				local previewJoints=animation.collect(preview)
				for name,joint in pairs(previewJoints) do joint.Transform=originals[joints[name]] or CFrame.identity end
				animation.apply({joints={}},previewJoints,animation.sample(id,case.action,case.time),rigName=="R6",1)
				local previewTool=assert(preview:FindFirstChildOfClass("Tool"))
				local previewHandle=previewTool.Handle
				local offsets={}
				for _,child in ipairs(previewTool:GetDescendants()) do if child:IsA("BasePart") then offsets[child]=previewHandle.CFrame:ToObjectSpace(child.CFrame) end end
				local equations={}
				for _,child in ipairs(preview:GetDescendants()) do
					if child:IsA("Motor6D") or child:IsA("AnimationConstraint") or child:IsA("Weld") then
						table.insert(equations,{a=child.Part0,b=child.Part1,c0=child.C0,c1=child.C1,transform=(child:IsA("Weld") and CFrame.identity or child.Transform)}) child.Enabled=false
					elseif child:IsA("Constraint") or child:IsA("WeldConstraint") then child.Enabled=false
					elseif child:IsA("BasePart") then
						child.Anchored=true child.CanCollide=false
						if not child:IsDescendantOf(previewTool) and child.Name~="HumanoidRootPart" then
							child.Color=(child.Name=="Head" or child.Name:find("Hand") or child.Name:find("Arm")) and Color3.fromRGB(239,185,130) or Color3.fromRGB(39,120,180)
						end
					elseif child:IsA("LuaSourceContainer") then child:Destroy() end
				end
				local root=preview.HumanoidRootPart
				root.CFrame=CFrame.new((case.index-1)*9,903,(row-1)*12)
				local known={[root]=true}
				for pass=1,24 do for _,eq in ipairs(equations) do if known[eq.a] and not known[eq.b] then eq.b.CFrame=eq.a.CFrame*eq.c0*eq.transform*eq.c1:Inverse() known[eq.b]=true end end end
				local previewHand=preview:FindFirstChild("RightHand") or preview:FindFirstChild("Right Arm")
				local handleFrame=previewHand.CFrame*nativeC0*previewTool.Grip:Inverse()
				for child,offset in pairs(offsets) do child.CFrame=handleFrame*offset end
				local box,size=previewTool.Visual:GetBoundingBox()
				table.insert(report.metrics,{rig=rigName,item=id,pose=case.action,at=case.time,visualCenter=tostring(root.CFrame:PointToObjectSpace(box.Position)),visualSize=tostring(size),nativeGripClass=grip.ClassName})
				animation.restore(animationRecord)
				local restored=true for joint,original in pairs(originals) do restored=restored and closeFrame(joint.Transform,original) end
				check(restored,rigName.." "..id.." native pose restores original transforms")
			end
			equipment:_clearGear(record)
			grip:Destroy()
			check(record.gear==nil and tool.Parent==nil and rig:GetAttribute("PCToyHeld")==nil,rigName.." "..id.." cleanup removes tool and held flag")
		end
		check(held>=15 and cancelled>=15,rigName.." toy hold/cancel hooks connected")
		rig:Destroy() backpack:Destroy()
	end
	equipmentModule:Destroy() motionModule:Destroy()
end,debug.traceback)
for _,entry in ipairs(services) do pcall(function()entry.equipment:_clearGear(entry.record)end) end
report.passed,report.error=ok,not ok and tostring(problem) or nil
report.checkCount=#report.checks
if not ok then folder:Destroy() report.fixture=nil end
return game.HttpService:JSONEncode(report)
