local model = game.ReplicatedStorage.UnitModels.Yumcha
local torso, head, hair = model.Torso, model.Head, model.Handle
local backupName = "YumchaBeforeNeckRepair_20260921"
if not game.ServerStorage:FindFirstChild(backupName) then
 local backup = model:Clone()
 backup.Name = backupName
 backup.Parent = game.ServerStorage
end
if not torso:FindFirstChild("Neck") then
 local joint = Instance.new("Motor6D")
 joint.Name = "Neck"
 joint.Part0 = torso
 joint.Part1 = head
 joint.C1 = CFrame.new(0, -head.Size.Y / 2, 0)
 joint.C0 = torso.CFrame:ToObjectSpace(head.CFrame * joint.C1)
 joint.Parent = torso
end
if not head:FindFirstChild("HairWeld") then
 local joint = Instance.new("Weld")
 joint.Name = "HairWeld"
 joint.Part0 = head
 joint.Part1 = hair
 joint.C0 = head.CFrame:ToObjectSpace(hair.CFrame)
 joint.C1 = CFrame.identity
 joint.Parent = head
end
return "Yumcha neck and hair joints repaired; original model backed up."