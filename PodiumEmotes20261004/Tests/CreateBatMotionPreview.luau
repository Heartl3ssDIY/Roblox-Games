local name = "BatMotionPreview20261004"
assert(not workspace:FindFirstChild(name), "Remove previous temporary preview first")
local folder = Instance.new("Folder")
folder.Name = name
folder.Parent = workspace
local ok, result = xpcall(function()
	local live = game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes
	local module = Instance.new("ModuleScript")
	module.Name = "MotionPreviewHelpers"
	module.Capabilities = live.Capabilities
	module.Sandboxed = live.Sandboxed
	module.Source = assert(_G.BatMotionCandidate):match("^(.-)local beforeAnimation =")
		.. "\nreturn {sample=sampleBatPose,apply=applyBatPose,restore=restore,collect=collectJoints}"
	module.Parent = folder
	local animation = require(module)
	local rows = {}
	for row, rigName in ipairs({"R6","R15"}) do
		for col, stage in ipairs({{name="READY",time=0},{name="WINDUP",time=.105},{name="CONTACT",time=.22},{name="FOLLOW",time=.30}}) do
			local rig = game.ServerStorage.WeaponRigFixtures[rigName]:Clone()
			rig.Name = rigName .. "_" .. stage.name
			for _,child in ipairs(rig:GetChildren()) do
				if child:IsA("Tool") or child:IsA("Accessory") then child:Destroy() end
			end
			for _,child in ipairs(rig:GetDescendants()) do
				if child:IsA("BaseScript") then child:Destroy() end
			end
			rig.Parent = folder
			rig.HumanoidRootPart.CFrame=CFrame.new((col-1)*8,903,(row-1)*10)
			local joints = animation.collect(rig)
			for _,joint in pairs(joints) do joint.Transform=CFrame.identity end
			animation.apply({joints={}}, joints, animation.sample(stage.time,rigName=="R6"), rigName=="R6",1)
			local equations={}
			for _,part in ipairs(rig:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored=true
					part.CanCollide=false
					if part.Name=="Head" or part.Name:find("Hand") or part.Name=="Right Arm" or part.Name=="Left Arm" then
						part.Color=Color3.fromRGB(239,185,130)
					else part.Color=Color3.fromRGB(39,120,180) end
				elseif part:IsA("Motor6D") or part:IsA("AnimationConstraint") then
					table.insert(equations,{a=part.Part0,b=part.Part1,c0=part.C0,c1=part.C1,transform=part.Transform})
					part.Enabled=false
				elseif part:IsA("Constraint") then part.Enabled=false end
			end
			local known={[rig.HumanoidRootPart]=true}
			for pass=1,20 do
				for _,equation in ipairs(equations) do
					if known[equation.a] and not known[equation.b] then
						equation.b.CFrame=equation.a.CFrame*equation.c0*equation.transform*equation.c1:Inverse()
						known[equation.b]=true
					end
				end
			end
			local visual=game.ReplicatedStorage.PlaygroundCosmeticAssets.B01:Clone()
			local low,high=Vector3.one*math.huge,-Vector3.one*math.huge
			for _,part in ipairs(visual:GetDescendants()) do
				if part:IsA("BasePart") and part:GetAttribute("PCStudLayer")~=true then
					for _,x in ipairs({-.5,.5}) do for _,y in ipairs({-.5,.5}) do for _,z in ipairs({-.5,.5}) do
						local p=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z))
						low=low:Min(p) high=high:Max(p)
					end end end
				end
			end
			local size=high-low
			local grip=Vector3.new((low.X+high.X)/2,low.Y+math.min(size.Y*.14,.42),(low.Z+high.Z)/2)
			local hand=rig:FindFirstChild("RightHand") or rig:FindFirstChild("Right Arm")
			local nativeC0=rigName=="R6" and CFrame.new(0,-1,0)*CFrame.Angles(-math.pi/2,0,0) or hand.RightGripAttachment.CFrame
			local frame=hand.CFrame*nativeC0
			visual:PivotTo(frame*CFrame.new(-grip)*visual:GetPivot())
			visual.Name="PreviewBat"
			visual.Parent=rig
			for _,part in ipairs(visual:GetDescendants()) do
				if part:IsA("BasePart") then part.Anchored=true part.CanCollide=false
				elseif part:IsA("ParticleEmitter") or part:IsA("Trail") then part.Enabled=false end
			end
			local sign=Instance.new("Part")
			sign.Name="PoseLabel"
			sign.Anchored=true
			sign.CanCollide=false
			sign.Size=Vector3.new(6,.8,.05)
			sign.CFrame=CFrame.new((col-1)*8,899.4,(row-1)*10-1)
			sign.Color=Color3.fromRGB(22,37,59)
			sign.Parent=rig
			local surface=Instance.new("SurfaceGui")
			surface.Face=Enum.NormalId.Front
			surface.CanvasSize=Vector2.new(600,80)
			surface.Parent=sign
			local label=Instance.new("TextLabel")
			label.BackgroundTransparency=1
			label.Size=UDim2.fromScale(1,1)
			label.Text=rigName.." · "..stage.name.." "..tostring(stage.time).."s"
			label.Font=Enum.Font.GothamBold
			label.TextColor3=Color3.new(1,1,1)
			label.TextScaled=true
			label.Parent=surface
			local tip=frame:PointToWorldSpace(Vector3.new(0,size.Y-math.min(size.Y*.14,.42),0))
			local root=rig.HumanoidRootPart
			local localTip=root.CFrame:PointToObjectSpace(tip)
			table.insert(rows,{rig=rigName,stage=stage.name,tip={localTip.X,localTip.Y,localTip.Z}})
		end
	end
	module:Destroy()
	return rows
end,debug.traceback)
_G.BatMotionCandidate=nil
if not ok then folder:Destroy() error(result) end
return game.HttpService:JSONEncode(result)

