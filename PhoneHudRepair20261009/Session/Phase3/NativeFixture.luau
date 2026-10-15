assert(not game:GetService("RunService"):IsRunning())
local gui = game:GetService("StarterGui").PlaygroundSessionControls
local function section(first,last)
	local source=gui.Controller.Source
	local startAt=assert(string.find(source,first,1,true))
	local endAt=assert(string.find(source,last,startAt,true))
	return string.sub(source,startAt,endAt-1)
end
local helper=section("local function compactLayout()","local function gamepadActive()")
local visibility=section("\tlocal showRoundSettings =", "\tpanel.Visible =")
local test=Instance.new("ModuleScript")
test.Name="CompactRoundSettingsNativeFixture"
test.Capabilities=gui.Controller.Capabilities
test.Source="return function(workspace, gui, modal, participating)\n"..helper..[[
local roundToggle, compactRoundToggle, portraitRoundToggle = gui.RoundToggle, gui.CompactRoundToggle, gui.PortraitRoundToggle
local compact,portrait=compactLayout()
]]..visibility.."\nend"
test.Parent=game:GetService("ServerStorage")
local render=require(test)
local clone=gui:Clone()
clone.Parent=game:GetService("ServerStorage")
local checks=0
local function check(value,message)checks+=1 assert(value,message)end
local names={"RoundToggle","CompactRoundToggle","PortraitRoundToggle"}
local geometry={}
for _,name in names do geometry[name]={clone[name].Position,clone[name].Size}end
local ok,failure=pcall(function()
	for _,case in {
		{Vector2.new(852,393),2},{Vector2.new(568,320),2},{Vector2.new(667,375),2},
		{Vector2.new(390,844),3},{Vector2.new(320,568),3},{Vector2.new(1180,820),2},{Vector2.new(1920,1080),1}
	}do
		local camera={CurrentCamera={ViewportSize=case[1]}}
		render(camera,clone,false,true)
		for i,name in names do check(clone[name].Visible==(i==case[2]),"Wrong round settings profile "..name)end
		for _,mode in {{false,false},{true,true}}do
			render(camera,clone,mode[1],mode[2])
			for _,name in names do check(not clone[name].Visible,"Round settings not hidden "..name)end
		end
	end
	for _,name in names do check(clone[name].Position==geometry[name][1] and clone[name].Size==geometry[name][2],"Runtime geometry overwritten "..name)end
	check(gui.Controller.Source:find('for _, launcher in ipairs(roundLaunchers) do connect(launcher.Activated, toggleSettings) end',1,true)~=nil,"Round settings handlers differ")
	local backup=game:GetService("ServerStorage").PhoneHudRoundSettingsBackup20261009.PlaygroundSessionControls
	check(gui.Controller.Capabilities==backup.Controller.Capabilities,"Capabilities changed")
	return {ok=true,checks=checks,profiles=7}
end)
clone:Destroy()test:Destroy()
assert(ok,failure)
return failure

