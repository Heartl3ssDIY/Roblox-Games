assert(not game:GetService("RunService"):IsRunning())
local folder=Instance.new("Folder") folder.Name="ExpansionFinishVerification" folder.Parent=game.ServerStorage
local totals={models=0,bats=0,toys=0,pets=0,coats=0,originalBones=0,skinBones=0,animatedBones=0,workspacePivotsPreserved=0}
local function test()
local rigModule=Instance.new("ModuleScript") rigModule.Parent=folder
rigModule.Capabilities=game.StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.Capabilities
rigModule.Sandboxed=true
rigModule.Source=[==[local hoveringPets={P23=true,P25=true,P28=true,P35=true}
local function prepareRigMotion(state)
	state.bones, state.skinBones = {}, {}
	local pivot = state.model:GetPivot()
	for _, bone in ipairs(state.model:GetDescendants()) do
		if bone:IsA("Bone") then
			local source = bone:FindFirstChild("PCSourceBone")
			if source and source:IsA("ObjectValue") and source.Value then
				table.insert(state.skinBones, { bone = bone, source = source.Value })
			elseif state.model:GetAttribute("PCProceduralPetRig") == true then
				local frame = bone.WorldCFrame
				table.insert(state.bones, {
					bone = bone, name = bone.Name, rest = bone.Transform,
					pitch = frame:VectorToObjectSpace(pivot.RightVector),
					yaw = frame:VectorToObjectSpace(pivot.UpVector),
					roll = frame:VectorToObjectSpace(pivot.LookVector),
				})
			end
		end
	end
end

local function updateRigMotion(state, reducedMotion)
	if not state.tracks.idle and not state.tracks.walk then
		local phase, movement = state.phase, state.movement
		local intensity = reducedMotion and 0 or 1
		for _, entry in ipairs(state.bones) do
			local name, pitch, yaw, roll = entry.name, 0, 0, 0
			local right = name:find("R") ~= nil
			if name == "Head" then
				pitch = math.sin(phase * 0.5) * 3
				yaw = math.sin(phase * 0.29) * 5
			elseif name == "Tail" then
				yaw = math.sin(phase * 0.8) * (7 + movement * 9)
				pitch = math.sin(phase * 0.4) * 3
			elseif name:find("Wing") then
				roll = math.sin(phase) * (hoveringPets[state.id] and 22 or 10) * (right and -1 or 1)
			elseif name:find("Leg") or name:find("Arm") then
				local offset = right and math.pi or 0
				if name:find("Back") then offset += math.pi end
				local number = tonumber(name:match("(%d+)$"))
				if number then offset += (number - 1) * math.pi end
				pitch = math.sin(phase + offset) * (2 + movement * 18)
			elseif name == "Body" then
				pitch = math.sin(phase * 0.5) * 1.5
			end
			entry.bone.Transform = entry.rest
				* CFrame.fromAxisAngle(entry.pitch, math.rad(pitch * intensity))
				* CFrame.fromAxisAngle(entry.yaw, math.rad(yaw * intensity))
				* CFrame.fromAxisAngle(entry.roll, math.rad(roll * intensity))
		end
	end
	for _, entry in ipairs(state.skinBones) do
		entry.bone.Transform = entry.source.Transform
	end
end


return {prepare=prepareRigMotion,update=updateRigMotion}]==]
local rig=require(rigModule)
for _,range in ipairs({{"B",16,25},{"M",16,25},{"P",21,35}}) do
for n=range[2],range[3] do
 local id=string.format("%s%02d",range[1],n)
 local source=assert(game.ReplicatedStorage.PlaygroundCosmeticAssets:FindFirstChild(id))
 local saved=assert(game.ServerStorage.ExpansionFinishBackup20261007:FindFirstChild(id))
 local sourcePath=saved:GetAttribute("OriginalPath")
 local sourceFolder=range[1]=="B" and workspace.Bats or range[1]=="M" and workspace["Toys and misc items"] or workspace.Pets2
 local sourceModel=assert(sourceFolder:FindFirstChild(source:GetAttribute("OriginalModelName")))
 assert(sourceModel:GetPivot()==saved:GetPivot(),"Source moved "..id)
 totals.workspacePivotsPreserved+=1
 assert(source:GetAttribute("PCArtVersion")==1 and source:GetAttribute("CatalogId")==id)
 local outline=assert(source:FindFirstChild("CartoonOutline"))
 assert(outline.Adornee==source and outline.FillTransparency==1 and outline.OutlineTransparency==0)
 local originalBoneCount=0
 for _,d in ipairs(saved:GetDescendants()) do if d:IsA("Bone") then originalBoneCount+=1 end end
 local boneCount=0
 for _,d in ipairs(source:GetDescendants()) do
  if d:IsA("BasePart") then assert(not d.CanCollide and not d.CanTouch and not d.CanQuery and d.Massless) end
  if d:IsA("MeshPart") and d:GetAttribute("PCStudLayer")~=true then
   local previous=assert(saved:FindFirstChild(d.Name,true))
   assert(d.MeshId==previous.MeshId and d.TextureID==previous.TextureID,"Mesh/palette changed "..id)
   local coat=assert(d:FindFirstChild("PCStudFinish"))
   assert(coat.MaterialVariant=="PlaygroundItemStuds" and coat.StudFinishWeld.Part0==d and coat.StudFinishWeld.Part1==coat)
   totals.coats+=1
  elseif d:IsA("Bone") then
   if not d:FindFirstChild("PCSourceBone") then boneCount+=1 end
  end
 end
 assert(boneCount==originalBoneCount,"Original skeleton changed "..id)
 totals.originalBones+=boneCount
 if range[1]=="P" then
  local model=source:Clone() model.Parent=folder
  local state={model=model,id=id,tracks={},phase=.81,movement=.8}
  rig.prepare(state) rig.update(state,false)
  assert(#state.bones==originalBoneCount)
  for _,entry in ipairs(state.bones) do if entry.name~="Root" then assert(entry.bone.Transform~=entry.rest, "No motion "..id.." "..entry.name) totals.animatedBones+=1 end end
  for _,entry in ipairs(state.skinBones) do assert(entry.bone.Transform==entry.source.Transform) totals.skinBones+=1 end
  rig.update(state,true)
  for _,entry in ipairs(state.bones) do assert(entry.bone.Transform==entry.rest,"Reduced motion failed") end
  totals.pets+=1
 elseif range[1]=="B" then totals.bats+=1 else totals.toys+=1 end
 totals.models+=1
end end
return totals
end
local ok,result=xpcall(test,debug.traceback)
folder:Destroy()
if not ok then error(result) end
return game.HttpService:JSONEncode(result)
