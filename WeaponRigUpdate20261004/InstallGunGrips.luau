local assets=game.ReplicatedStorage:WaitForChild("MudAssets")
local backup=game.ServerStorage:FindFirstChild("WeaponRigBackup20261004")
assert(backup and backup:FindFirstChild("MudGun") and backup:FindFirstChild("HeatGun"),"Gun backups required before authoring grip attachments")
local result={}
for _,name in ipairs({"MudGun","HeatGun"})do
	local tool=assets:WaitForChild(name)
	local handle=tool:WaitForChild("Handle")
	assert(tool:IsA("Tool") and handle:IsA("BasePart"),name.." requires a native Tool handle")
	tool.Grip=CFrame.new(0,-0.15,0)
	tool.CanBeDropped=false
	tool.RequiresHandle=true
	local grip=handle:FindFirstChild("RightGripAttachment")or Instance.new("Attachment")
	assert(grip:IsA("Attachment"),"RightGripAttachment has wrong class")
	grip.Name="RightGripAttachment"
	grip.CFrame=tool.Grip
	grip.Parent=handle
	local muzzle=handle:WaitForChild("MuzzleAttachment")
	muzzle.CFrame=CFrame.new(0,1,-2.65)
	tool:SetAttribute("HandRigVersion",3)
	tool:SetAttribute("RestrictedGame","StuckInTheMud")
	local meshCount=0
	for _,part in ipairs(tool:GetDescendants())do
		if part:IsA("BasePart")then
			part.Anchored=false
			part.CanCollide=false
			part.CanTouch=false
			part.CanQuery=false
			part.Massless=true
			if part:IsA("MeshPart")then meshCount+=1 end
		end
	end
	table.insert(result,{tool=name,meshes=meshCount,grip={grip.CFrame:GetComponents()},muzzle={muzzle.CFrame:GetComponents()}})
end
return game.HttpService:JSONEncode(result)
