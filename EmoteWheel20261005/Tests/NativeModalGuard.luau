assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local box=game.StarterGui.PlaygroundToyHotbar.Controller:Clone() box.Name="_IconModalGuard" box.Enabled=false box.Parent=game.ServerStorage
local fixture=Instance.new("Folder") fixture.Name="PlayerGui" fixture.Parent=box
local gui=game.StarterGui.PlaygroundToyHotbar:Clone() gui.Parent=fixture
local shell=game.StarterGui.PlaygroundShell:Clone() shell.Parent=fixture
for _,name in ipairs({"ShopPanel","VotePanel","CompactVotePanel"}) do shell[name].Visible=false end
local wheel=Instance.new("ScreenGui") wheel.Name="PlaygroundEmoteWheel" wheel.Parent=fixture
local panel=Instance.new("Frame") panel.Name="Panel" panel.Parent=wheel
local module=Instance.new("ModuleScript") module.Name="Checks" module.Parent=box
module.Source=[========[
local player={PlayerGui=script.Parent.PlayerGui}
local gui=player.PlayerGui.PlaygroundToyHotbar
local bar=gui.Bar gui.Enabled=true bar.Visible=true
local GuiService={MenuIsOpen=false}
local slots={{id="M01"}}
local activeId="M01"
local pending=false
local catalog={ById={M01={}}}
local calls=0
local function invoke() calls+=1 end
local function usable() return true end
local function cooldownEndsAt() return 0 end
local function aimAt() return nil end
local function tell() end
local function refresh() end
local function modalOpen()
	local shell = player.PlayerGui:FindFirstChild("PlaygroundShell")
	if shell then
		for _, name in ipairs({ "ShopPanel", "VotePanel", "CompactVotePanel" }) do
			local panel = shell:FindFirstChild(name)
			if panel and panel.Visible then return true end
		end
	end
	local wheel = player.PlayerGui:FindFirstChild("PlaygroundEmoteWheel")
	local wheelPanel = wheel and wheel:FindFirstChild("Panel")
	if wheel and wheel.Enabled and wheelPanel and wheelPanel.Visible then return true end
	local admin = player.PlayerGui:FindFirstChild("PlaygroundAdminPanel")
	local adminHub = admin and admin:FindFirstChild("AdminHub")
	if admin and admin.Enabled and adminHub and adminHub.Visible then return true end
	return GuiService.MenuIsOpen
end


local function useToy(position)
	if not gui.Enabled or not bar.Visible or not usable() or modalOpen() or activeId == "" or pending then return end
	local item = catalog.ById[activeId]
	if item and item.toyActionPending then tell("This toy's action is coming soon.") refresh() return end
	if cooldownEndsAt(activeId) > workspace:GetServerTimeNow() then return end
	invoke("PlaygroundToyRequest", "Use", aimAt(position), activeId)
end

local function selectToy(index)
	local record = slots[index]
	if not gui.Enabled or not record or record.id == "" or not bar.Visible or not usable() or modalOpen() or pending then return end
	invoke("PlaygroundShopRequest", "SelectToy", index)
end


local checks={}
local function check(v,label) assert(v,label)table.insert(checks,label)end
local wheel=player.PlayerGui.PlaygroundEmoteWheel
wheel.Enabled=true wheel.Panel.Visible=true
check(modalOpen(),"Visible enabled emote wheel is modal")
selectToy(1)useToy(nil)
check(calls==0,"Wheel blocks slot selection and toy activation")
wheel.Panel.Visible=false
check(not modalOpen(),"Closed wheel releases modal lock")
selectToy(1)useToy(nil)
check(calls==2,"Closing wheel restores ordinary toy controls")
wheel.Panel.Visible=true wheel.Enabled=false
check(not modalOpen(),"Disabled wheel does not block controls")
GuiService.MenuIsOpen=true check(modalOpen(),"Roblox menu remains modal")
local alive=true local lobby=true local lastCategory=nil local shown=false
local openCallback
local gui={GetAttributeChangedSignal=function(_,name)
 assert(name=="OpenEmoteShopSerial")
 return {Connect=function(_,callback)openCallback=callback end}
end}
local function emoteInLobby()return lobby end
local function setCategory(v)lastCategory=v end
local function setShop(v)shown=v end
gui:GetAttributeChangedSignal("OpenEmoteShopSerial"):Connect(function()
	if not alive or not emoteInLobby() then return end
	setCategory("Emotes")
	setShop(true)
end)

openCallback()
check(lastCategory=="Emotes" and shown,"Wheel Shop action opens Emotes via authored attribute binding")
lobby=false shown=false openCallback()
check(not shown,"Gameplay phase prevents wheel shop trigger")
return {passed=#checks,checks=checks}
]========]
local ok,result=pcall(require,module)
box:Destroy()
assert(ok,result)
return game:GetService("HttpService"):JSONEncode(result)

