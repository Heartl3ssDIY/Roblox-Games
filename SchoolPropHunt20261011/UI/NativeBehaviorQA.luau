return function(ui)
local report={checks={}}
local function check(name,value) table.insert(report.checks,{name=name,passed=value==true}) assert(value,name) end
local player=Instance.new("Folder")
local workspace={CurrentCamera={ViewportSize=Vector2.new(844,390)}}
local gameView=workspace
local connections={}
local function connect(signal,callback) table.insert(connections,signal:Connect(callback)) end
local adminAPI=(function()
local gui=ui.PlaygroundAdminPanel
local hub=gui.AdminHub
local pages=hub.Pages
local opened,tab=false,"Items"
local gold,blue,muted=Color3.fromRGB(255,211,78),Color3.fromRGB(89,193,244),Color3.fromRGB(194,201,206)
local calls=0
local function refreshLocalRoster() end
local function request(action) assert(action=="GetStatus") calls+=1 end
local function admin()
	return player:GetAttribute("PlaygroundAdmin") == true
end
local function caption(object, text)
	object.Text = text
	local live = object:FindFirstChild("LiveCaption")
	if live then live.Text = text end
end
local function enabled(button, value, color)
	button.Active = value
	button.Selectable = value
	button.AutoButtonColor = false
	button.BackgroundColor3 = value and (color or button:GetAttribute("ReadyColor") or blue) or muted
end
local function message(text)
	hub.Message.Text = tostring(text or "")
end
local function syncVisibility()
	local allowed = admin()
	gui.Enabled = allowed
	if not allowed then opened = false end
	hub.Visible = allowed and opened
	gui.Panel.Visible = false
	gui.CompactPanel.Visible = false
	gui.CompactToggle.Visible = false
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
	local short, long = math.min(viewport.X,viewport.Y), math.max(viewport.X,viewport.Y)
	local compact = viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400)
	gui.Toggle.Visible = allowed and not compact
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
connect(gui.Toggle.Activated, toggle)
connect(gui:GetAttributeChangedSignal("OpenAdminSerial"), function()
	if not admin() then return end
	opened = false
	toggle()
end)

return {refresh=syncVisibility,calls=function() return calls end}
end)()
local shellAPI=(function()
local gui=ui.PlaygroundShell
local dock,compactDock,portraitDock=gui.Dock,gui.CompactDock,gui.PortraitDock
local function hudProfile(viewport)
	local short = math.min(viewport.X, viewport.Y)
	if viewport.X <= 900 or short <= 600 then return "PhoneScale" end
	if short <= 1024 and math.max(viewport.X, viewport.Y) <= 1400 then return "TabletScale" end
	return "DesktopScale"
end

local function refreshLobbyDock(visible)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local compact = hudProfile(viewport) ~= "DesktopScale"
	dock.Visible = visible and not compact
	local portrait = viewport.Y > viewport.X
	compactDock.Visible = visible and compact and not portrait
	portraitDock.Visible = visible and compact and portrait
end


return {refresh=refreshLobbyDock,profile=hudProfile}
end)()
local sessionAPI=(function()
local gui=ui.PlaygroundSessionControls
local content=gui.Dock.Body
local menuOpen=true
local function closeMenu() menuOpen=false gui:SetAttribute("SessionMenuOpen",false) end
local function refresh() content.AdminAccess.Visible=player:GetAttribute("PlaygroundAdmin")==true end
local function compactLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(viewport.X, viewport.Y)
	local long = math.max(viewport.X, viewport.Y)
	return viewport.X <= 900 or short <= 600 or (short <= 1024 and long <= 1400), viewport.Y > viewport.X
end


local callback
local realConnect=connect
local function connect(_,handler) callback=handler end
connect(content.AdminAccess.Activated, function()
	if player:GetAttribute("PlaygroundAdmin") ~= true then return end
	local admin = gui.Parent:FindFirstChild("PlaygroundAdminPanel")
	if not admin then return end
	closeMenu()
	refresh()
	admin:SetAttribute("OpenAdminSerial", (tonumber(admin:GetAttribute("OpenAdminSerial")) or 0) + 1)
end)

return {activate=function() callback() end,refresh=refresh,compact=compactLayout}
end)()
local ok,failure=xpcall(function()
for _,viewport in ipairs({Vector2.new(568,320),Vector2.new(667,375),Vector2.new(844,390),Vector2.new(896,414),Vector2.new(1024,768),Vector2.new(1180,820),Vector2.new(1366,1024),Vector2.new(390,844),Vector2.new(1920,1080)}) do
 workspace.CurrentCamera.ViewportSize=viewport
 local compact,portrait=sessionAPI.compact()
 check(tostring(viewport)..": session and shell agree on compact mode",compact==(shellAPI.profile(viewport)~="DesktopScale"))
 shellAPI.refresh(true)
 check(tostring(viewport)..": exactly one lobby dock is visible",(ui.PlaygroundShell.Dock.Visible and 1 or 0)+(ui.PlaygroundShell.CompactDock.Visible and 1 or 0)+(ui.PlaygroundShell.PortraitDock.Visible and 1 or 0)==1)
 check(tostring(viewport)..": portrait selects raised dock",ui.PlaygroundShell.PortraitDock.Visible==(compact and portrait))
 shellAPI.refresh(false)
 check(tostring(viewport)..": hiding HUD hides all three docks",not ui.PlaygroundShell.Dock.Visible and not ui.PlaygroundShell.CompactDock.Visible and not ui.PlaygroundShell.PortraitDock.Visible)
 player:SetAttribute("PlaygroundAdmin",false) adminAPI.refresh() sessionAPI.refresh()
 check(tostring(viewport)..": non-admin has no launcher or panel",not ui.PlaygroundAdminPanel.Enabled and not ui.PlaygroundAdminPanel.Toggle.Visible and not ui.PlaygroundAdminPanel.AdminHub.Visible and not ui.PlaygroundSessionControls.Dock.Body.AdminAccess.Visible)
 local serial=ui.PlaygroundAdminPanel:GetAttribute("OpenAdminSerial")
 sessionAPI.activate()
 check(tostring(viewport)..": non-admin settings action ignored",ui.PlaygroundAdminPanel:GetAttribute("OpenAdminSerial")==serial)
 player:SetAttribute("PlaygroundAdmin",true) adminAPI.refresh() sessionAPI.refresh()
 check(tostring(viewport)..": mobile admin launcher stays hidden",ui.PlaygroundAdminPanel.Toggle.Visible==not compact and not ui.PlaygroundAdminPanel.CompactToggle.Visible)
 check(tostring(viewport)..": admin settings entry is available",ui.PlaygroundSessionControls.Dock.Body.AdminAccess.Visible)
 ui.PlaygroundSessionControls:SetAttribute("SessionMenuOpen",true)
 local calls=adminAPI.calls()
 sessionAPI.activate()
 task.wait()
 check(tostring(viewport)..": settings admin action closes settings and opens panel",not ui.PlaygroundSessionControls:GetAttribute("SessionMenuOpen") and ui.PlaygroundAdminPanel.AdminHub.Visible and adminAPI.calls()==calls+1)
 player:SetAttribute("PlaygroundAdmin",false) adminAPI.refresh() sessionAPI.refresh()
 check(tostring(viewport)..": permission revocation hides open panel",not ui.PlaygroundAdminPanel.Enabled and not ui.PlaygroundAdminPanel.AdminHub.Visible and not ui.PlaygroundSessionControls.Dock.Body.AdminAccess.Visible)
end
end,debug.traceback)
for _,connection in ipairs(connections) do connection:Disconnect() end
player:Destroy()
report.passed,report.error,report.checkCount=ok,ok and nil or failure,#report.checks
return report
end
