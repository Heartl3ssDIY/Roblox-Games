local checks=0
local function check(name, value) assert(value,name) checks+=1 end
local attr=nil
local player={UserId=1201803949,GetAttribute=function()return attr end}
local gui={Enabled=true,OwnerUserId=1201803949}
for _,name in ipairs({"Toggle","AdminHub","Panel","CompactPanel","CompactToggle"})do gui[name]={Visible=true}end
function gui:GetAttribute(name)return self[name]end
function gui:FindFirstChild(name)return self[name]end
local hub=gui.AdminHub
local pages={GetChildren=function()return {}end}
hub.Tabs={GetChildren=function()return {}end}
local opened=false
local tab="Items"
local gold,blue=1,2
local function caption(object,text)object.Text=text end
local function enabled()end
local calls=0
local function refreshLocalRoster()end
local function request()calls+=1 end
gui.Enabled = false
for _, name in ipairs({ "Toggle", "AdminHub", "Panel", "CompactPanel", "CompactToggle" }) do
	local object = gui:FindFirstChild(name)
	if object then object.Visible = false end
end

check("hidden before yielding",not gui.Enabled and not gui.Toggle.Visible and not hub.Visible)
local function admin()
	return player.UserId == gui:GetAttribute("OwnerUserId") and player:GetAttribute("PlaygroundAdmin") == true
end

local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	gui.Toggle.Visible = allowed
	caption(gui.Toggle, opened and "CLOSE" or "ADMIN")
	for _, pageObject in ipairs(pages:GetChildren()) do
		if pageObject:IsA("GuiObject") then pageObject.Visible = pageObject.Name == tab end
	end
	for _, button in ipairs(hub.Tabs:GetChildren()) do
		if button:IsA("TextButton") then enabled(button, allowed, button.Name == tab and gold or blue) end
	end
end

local function toggle()
	if not admin() then return end
	opened = not opened
	syncVisibility()
	if opened then refreshLocalRoster() request("GetStatus", nil, true) end
end

syncVisibility()
check("owner waits for server authorization",not gui.Enabled)
toggle()
check("not authorized cannot toggle or request",not opened and calls==0)
attr=true
for _,id in ipairs({123456,168026080,0,-1,-2})do
 player.UserId=id
 syncVisibility()
 toggle()
 check("nonowner denied even forged attribute "..id,not gui.Enabled and not gui.Toggle.Visible and not opened and calls==0)
end
player.UserId=1201803949
syncVisibility()
check("owner can see ADMIN only",gui.Enabled and gui.Toggle.Visible and not hub.Visible)
toggle()
check("owner opens and requests status",hub.Visible and opened and calls==1)
attr=false
syncVisibility()
check("authorization revoked closes panel",not gui.Enabled and not gui.Toggle.Visible and not hub.Visible and not opened)
print("PASS "..checks.." client identity/visibility checks")
