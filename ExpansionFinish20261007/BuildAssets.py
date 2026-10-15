from pathlib import Path
root=Path(__file__).parent
s=(root.parent/'PriorityPass20261007/ExpansionAssetPatch.luau').read_text(encoding='utf-8')
s=s.replace('local APPLY = false','local APPLY = true')
s=s.replace('coat:ClearAllChildren()', '''for _, child in ipairs(coat:GetChildren()) do
							if not child:IsA("Bone") then child:Destroy() end
						end
						for _, bone in ipairs(coat:GetDescendants()) do
							if bone:IsA("Bone") then
								local originalBone = part:FindFirstChild(bone.Name, true)
								assert(originalBone and originalBone:IsA("Bone"), "Missing matching skin bone")
								local source = Instance.new("ObjectValue")
								source.Name, source.Value, source.Parent = "PCSourceBone", originalBone, bone
							end
						end''')
s=s.replace('clone.PrimaryPart = clone:FindFirstChild("RootPart") or clone.PrimaryPart', '''local root = clone:FindFirstChild("RootPart")
			if not root then
				root = Instance.new("Part")
				root.Name, root.Size = "RootPart", Vector3.new(0.2, 0.2, 0.2)
				root.Transparency, root.Anchored, root.CanCollide = 1, true, false
				root.CFrame = CFrame.new(clone:GetPivot().Position) * CFrame.Angles(0, -math.pi / 2, 0)
				root.Parent = clone
			end
			clone.PrimaryPart = root''')
s=s.replace('clone:SetAttribute("PetFacingYaw", 0)', 'clone:SetAttribute("PetFacingYaw", 0)\n\t\t\tclone:SetAttribute("PCProceduralPetRig", true)')
s=s.replace('PriorityExpansionBackup20261007','ExpansionFinishBackup20261007')
s=s.replace('if plan.previous then plan.previous:Destroy() end', '''if plan.previous then
			plan.previous.Name = plan.id .. "_PreviousLibrary"
			plan.previous.Parent = backup
		end''')
s=s.replace('source = plan.source:GetFullName(), meshes', 'source = plan.source:GetFullName(), library = plan.clone and plan.clone:GetFullName(), meshes')
(root/'InstallAssets.luau').write_text(s, encoding='utf-8')
