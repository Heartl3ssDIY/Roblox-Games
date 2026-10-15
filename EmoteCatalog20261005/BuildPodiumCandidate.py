from pathlib import Path
folder=Path(__file__).resolve().parent
source=(folder/'Before/PlaygroundPodiumController.client.luau').read_text(encoding='utf-8')
source=source.replace('local function stopTrack(avatar)\n', '''local function stopTrack(avatar)
	local token = avatar.animationToken
	if token then
		token.expired = true
		if token.worker and coroutine.status(token.worker) ~= "dead" and token.worker ~= coroutine.running() then pcall(task.cancel, token.worker) end
		avatar.animationToken = nil
	end
''',1)
old='local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(token.userId) end)'
new='''local ok, model = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserIdAsync(token.userId)
			local created, value = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
			description:Destroy()
			if not created then error(value) end
			return value
		end)'''
assert old in source
source=source.replace(old,new,1)
start=source.index('local function updateAnimation(avatar)')
end=source.index('\nfor index = 1, 3 do',start)
source=source[:start]+(folder/'PodiumAnimationPlayback.luau').read_text()+source[end:]
source=source.replace('updateAnimation(avatar)','updateAnimation(slot)')
source=source.replace('if gui.Enabled then folder.Parent = workspace else folder.Parent = nil end', '''if gui.Enabled then folder.Parent = workspace else
		for _, slot in ipairs(slots) do if slot.avatar then stopTrack(slot.avatar) end end
		folder.Parent = nil
	end''')
(folder/'After/PlaygroundPodiumController.client.luau').write_text(source,encoding='utf-8')
print('Equipped-emote podium candidate prepared')
