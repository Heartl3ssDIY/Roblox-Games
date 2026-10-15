local replacements = assert(_G.UIShellTextureReplacements, "Provide an old rbxassetid URI to new rbxassetid URI mapping")
local commit = _G.UIShellTextureRepairCommit == true
assert(not game:GetService("RunService"):IsRunning(), "Install only in Edit mode")
local provider = game:GetService("ContentProvider")
local normalized = {}
local unchangedAssets = 0
for old, new in pairs(replacements) do
	assert(typeof(old) == "string" and old:match("^rbxassetid://%d+$"), "Invalid original URI")
	assert(typeof(new) == "string" and (new:match("^rbxassetid://%d+$")
		or new:match("^https://www%.roblox%.com/asset/%?id=%d+&version=%d+$")), "Invalid replacement URI")
	if commit then
		assert(provider:GetAssetFetchStatus(new) == Enum.AssetFetchStatus.Success, "Replacement must load before installation: " .. new)
	end
	if old ~= new then
		table.insert(normalized, {old=old,new=new,oldId=old:match("%d+"),newId=new:match("%d+")})
	else unchangedAssets += 1 end
end
table.sort(normalized,function(a,b)return a.old < b.old end)
local edits = {}
local function plan(object, property, before, after, attribute)
	if before ~= after then table.insert(edits,{object=object,property=property,before=before,after=after,attribute=attribute}) end
end
local roots = {game.StarterGui, game.ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets")}
for _, name in ipairs({"Bats","Pets","Toys and misc items","Playground Lobby"}) do
	local root = workspace:FindFirstChild(name)
	if root then table.insert(roots,root) end
end
local seen = {}
for _, root in ipairs(roots) do
	for _, object in ipairs(root:GetDescendants()) do
		if not seen[object] then
			seen[object] = true
			for key, value in pairs(object:GetAttributes()) do
				if typeof(value) == "string" and replacements[value] then plan(object,key,value,replacements[value],true) end
			end
			if object:IsA("ImageLabel") or object:IsA("ImageButton") then
				local new = replacements[object.Image]
				if new then plan(object,"Image",object.Image,new) end
			elseif object:IsA("MeshPart") then
				local new = replacements[object.TextureID]
				if new then plan(object,"TextureID",object.TextureID,new) end
			elseif object:IsA("LocalScript") and object:IsDescendantOf(game.StarterGui)
				and (object.Name == "BackgroundFallbackController" or object == game.StarterGui.PlaygroundLeaderboards.Controller) then
				local source = object.Source
				local after = source
				for _, replacement in ipairs(normalized) do
					for _, quote in ipairs({'"', "'"}) do
						after = after:gsub(quote .. replacement.old .. quote, quote .. replacement.new .. quote)
						after = after:gsub(quote .. replacement.oldId .. quote, quote .. replacement.newId .. quote)
					end
				end
				plan(object,"Source",source,after)
			end
		end
	end
end
local report = {commit=commit,unchangedAssets=unchangedAssets,total=#edits,images=0,textures=0,attributes=0,scripts=0,targets={}}
for _, edit in ipairs(edits) do
	if edit.attribute then report.attributes += 1
	elseif edit.property == "Image" then report.images += 1
	elseif edit.property == "TextureID" then report.textures += 1
	elseif edit.property == "Source" then report.scripts += 1 end
	table.insert(report.targets,{path=edit.object:GetFullName(),property=edit.property,attribute=edit.attribute or false})
end
if not commit or #edits == 0 then return game.HttpService:JSONEncode(report) end
local backupName = _G.UIShellTextureRepairBackupName or "UITextureRepairBackup20261004"
assert(backupName == "UITextureRepairBackup20261004" or backupName == "UIArtworkRepairBackup20261004", "Unexpected backup destination")
assert(not game.ServerStorage:FindFirstChild(backupName), "Do not overwrite an existing texture repair backup")
local backup = Instance.new("Folder")
backup.Name = backupName
backup.Parent = game.ServerStorage
for index, edit in ipairs(edits) do
	local value = Instance.new("StringValue")
	value.Name = string.format("%04d",index)
	value.Value = edit.before
	value:SetAttribute("Property",edit.property)
	value:SetAttribute("IsAttribute",edit.attribute or false)
	value:SetAttribute("TargetPath",edit.object:GetFullName())
	value:SetAttribute("Replacement",edit.after)
	local target = Instance.new("ObjectValue")
	target.Name = "Target"
	target.Value = edit.object
	target.Parent = value
	value.Parent = backup
end
local ok, message = xpcall(function()
	for _, edit in ipairs(edits) do
		if edit.attribute then edit.object:SetAttribute(edit.property,edit.after)
		else edit.object[edit.property] = edit.after end
	end
end,debug.traceback)
if not ok then
	for _, edit in ipairs(edits) do
		pcall(function()
			if edit.attribute then edit.object:SetAttribute(edit.property,edit.before)
			else edit.object[edit.property] = edit.before end
		end)
	end
	error(message)
end
report.backup = backup:GetFullName()
return game.HttpService:JSONEncode(report)

