assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local function folder(parent,name)
	local existing=parent:FindFirstChild(name)
	assert(not existing or existing:IsA("Folder"),name.." is not a folder")
	if existing then return existing end
	local value=Instance.new("Folder")
	value.Name=name
	value.Parent=parent
	return value
end
local sources=ReplicatedStorage:FindFirstChild("PlaygroundSourceModels")
assert(not sources or sources:IsA("Folder"),"Source storage name is occupied")
local definitions={
	{name="c01-collectible-coin",group="Coins",reimport="bc3cecd5-50fb-4f66-a672-15bb5c86a336",meshes=2},
	{name="MudGun",group="Guns",reimport="4f64ca1c-0789-42a5-9f62-4b95e15308e0",meshes=70},
	{name="HeatGun",group="Guns",reimport="08ce59f1-f644-48c7-a8e9-645308fbc461",meshes=65},
}
local templates={ReplicatedStorage.PlaygroundCosmeticAssets.C01,ReplicatedStorage.MudAssets.MudGun,ReplicatedStorage.MudAssets.HeatGun}
local templateState={}
for _,template in ipairs(templates)do templateState[template]={parent=template.Parent,pivot=template:GetPivot(),descendants=#template:GetDescendants()}end
local plan={}
for _,entry in ipairs(definitions)do
	local model=workspace:FindFirstChild(entry.name)
	local group=sources and sources:FindFirstChild(entry.group)
	assert(not group or group:IsA("Folder"),"Source category is not a folder")
	local stored=group and group:FindFirstChild(entry.name)
	assert(not(model and stored),"Destination already contains a different "..entry.name)
	local target=model or stored
	assert(target and target.ClassName=="Model" and not target:IsA("Tool"),"Missing loose import Model: "..entry.name)
	assert(target:GetAttribute("RBX_ReimportId")==entry.reimport,"Unexpected source model: "..entry.name)
	local parts={}
	local meshes=0
	for _,part in ipairs(target:GetDescendants())do
		if part:IsA("BasePart")then
			parts[part]={cf=part.CFrame,size=part.Size,color=part.Color,transparency=part.Transparency,material=part.Material,mesh=part:IsA("MeshPart")and part.MeshId or nil}
			if part:IsA("MeshPart")then meshes+=1 end
		end
	end
	assert(meshes==entry.meshes,"Imported art count changed: "..entry.name)
	table.insert(plan,{definition=entry,model=target,move=model~=nil,parts=parts,pivot=target:GetPivot(),from=target:GetFullName()})
end
local backups=folder(ServerStorage,"CoinPickupPolishBackup20261004")
local moves=folder(backups,"SourceModelMoves")
sources=folder(ReplicatedStorage,"PlaygroundSourceModels")
local report={moves={},runtimeTemplatesPreserved=true,backup=moves:GetFullName()}
for index,entry in ipairs(plan)do
	local model=entry.model
	local destination=folder(sources,entry.definition.group)
	if entry.move then
		local key=string.format("Move%02d",index)
		local record=moves:FindFirstChild(key)
		assert(not record or(record:IsA("ObjectValue")and record.Value==model),"Unexpected move backup")
		if not record then
			record=Instance.new("ObjectValue")
			record.Name=key
			record.Value=model
			record:SetAttribute("OriginalName",model.Name)
			record:SetAttribute("OriginalPath",entry.from)
			record:SetAttribute("OriginalPivot",entry.pivot)
			local originalParent=Instance.new("ObjectValue")
			originalParent.Name="OriginalParent"
			originalParent.Value=model.Parent
			originalParent.Parent=record
			record.Parent=moves
		end
		model.Parent=destination
		record:SetAttribute("StoredPath",model:GetFullName())
	end
	assert(model:GetPivot()==entry.pivot,"Source pivot changed")
	for part,state in pairs(entry.parts)do
		assert(part.CFrame==state.cf and part.Size==state.size and part.Color==state.color and part.Transparency==state.transparency and part.Material==state.material,"Source artwork changed")
		if state.mesh then assert(part.MeshId==state.mesh,"Imported mesh changed")end
	end
	table.insert(report.moves,{from=entry.from,to=model:GetFullName(),moved=entry.move,meshes=entry.definition.meshes,preservedArt=true})
end
for template,state in pairs(templateState)do
	assert(template.Parent==state.parent and template:GetPivot()==state.pivot and #template:GetDescendants()==state.descendants,"Runtime template changed")
end
_G.CoinSourceMoveAudit=nil
return game.HttpService:JSONEncode(report)
