assert(not game.RunService:IsRunning(), "Edit mode required")
local serverFolders = {"PlaygroundBeforeMud20261003", "WeaponRigBackup20261004", "WeaponRigFixtures", "PodiumEmotesBackup20261004", "ShopViewportRefreshBackup20261004", "ToyGameplayUIBackup20261005", "EmoteShopUIBackup20261005", "EmoteWheelBackup20261005", "MobileFinishBackup20261007", "PlaygroundStyledSourceAssets20261007"}
local targets = {}
local function take(outline)
	assert(outline:IsA("Highlight") and outline.Name == "CartoonOutline" and outline.Parent:IsA("Model"))
	assert(outline.Adornee == outline.Parent, "Unexpected external adornee: " .. outline:GetFullName())
	table.insert(targets, outline)
end
for _, name in ipairs(serverFolders) do
	local folder = assert(game.ServerStorage:FindFirstChild(name), name)
	for _, object in ipairs(folder:GetDescendants()) do if object:IsA("Highlight") then take(object) end end
end
for _, range in ipairs({{"B",16,25},{"M",16,25},{"P",21,35}}) do
	for n=range[2],range[3] do
		local id=string.format("%s%02d",range[1],n)
		local model=assert(game.ReplicatedStorage.PlaygroundCosmeticAssets:FindFirstChild(id))
		take(assert(model:FindFirstChild("CartoonOutline")))
	end
end
assert(#targets == 149, "Highlight plan count changed")

local SS = game.ServerStorage
assert(not SS:FindFirstChild("OutlinePropertyBackup20261007"),"Backup exists; inspect before rerunning")
local backup=Instance.new("Folder")
backup.Name="OutlinePropertyBackup20261007"
backup.Parent=SS
local fields={"Enabled","FillColor","FillTransparency","OutlineColor","OutlineTransparency"}
for i,h in ipairs(targets) do
 local record=Instance.new("Configuration")
 record.Name=string.format("Outline%03d",i)
 record:SetAttribute("OriginalPath",h:GetFullName())
 record:SetAttribute("OriginalName",h.Name)
 record:SetAttribute("DepthMode",h.DepthMode.Name)
 for _,field in ipairs(fields) do record:SetAttribute(field,h[field]) end
 local owner=Instance.new("ObjectValue") owner.Name="Owner" owner.Value=h.Parent owner.Parent=record
 local attributes=Instance.new("Configuration") attributes.Name="OriginalAttributes"
 for key,value in pairs(h:GetAttributes()) do attributes:SetAttribute(key,value) end
 attributes.Parent=record
 record.Parent=backup
 local restored=Instance.new("Highlight")
 restored.Name=record:GetAttribute("OriginalName")
 restored.Adornee=owner.Value
 restored.DepthMode=Enum.HighlightDepthMode[record:GetAttribute("DepthMode")]
 for _,field in ipairs(fields) do restored[field]=record:GetAttribute(field) assert(restored[field]==h[field],"Round-trip mismatch") end
 for key,value in pairs(attributes:GetAttributes()) do restored:SetAttribute(key,value) assert(restored:GetAttribute(key)==h:GetAttribute(key)) end
 assert(restored.Adornee==h.Adornee and restored.DepthMode==h.DepthMode and restored.Name==h.Name)
 restored:Destroy()
end
assert(#backup:GetChildren()==149)
backup:SetAttribute("RoundTripVerified",true)
return game.HttpService:JSONEncode({records=149,roundTripVerified=true,originalHighlightsUntouched=true,backup=backup:GetFullName()})
