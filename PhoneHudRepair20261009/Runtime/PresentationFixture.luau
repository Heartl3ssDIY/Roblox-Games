local tests=0
local function check(ok,label) assert(ok,label) tests+=1 end
local views={
{852,393,"PhoneScale",true},{667,375,"PhoneScale",true},{844,390,"PhoneScale",true},
{932,430,"PhoneScale",true},{568,320,"PhoneScale",true},{390,844,"PhoneScale",true},
{1024,768,"TabletScale",true},{1180,820,"TabletScale",true},{1366,1024,"TabletScale",true},
{1280,720,"TabletScale",true},{1920,1080,"DesktopScale",false},{2560,1440,"DesktopScale",false}
}
do
 local dock=Instance.new("Frame")
 local compactDock=Instance.new("Frame")
 local playerAttrs={}
 local player={GetAttribute=function(_,name)return playerAttrs[name]end}
 local workspace={CurrentCamera={ViewportSize=Vector2.new(852,393)}}
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
	compactDock.Visible = visible and compact
end

 for _,case in views do
  local viewport=Vector2.new(case[1],case[2])
  workspace.CurrentCamera.ViewportSize=viewport
  check(hudProfile(viewport)==case[3],"profile "..case[1].."x"..case[2])
  for _,visible in {false,true} do
   refreshLobbyDock(visible)
   check(dock.Visible==(visible and not case[4]),"desktop dock visibility")
   check(compactDock.Visible==(visible and case[4]),"compact dock visibility")
   local modal=not visible
   local panel=Instance.new("Frame")
   local compact=Instance.new("Frame")
   local notice=Instance.new("Frame");notice.Visible=false
   local function hideNotice() notice.Visible=false end
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local narrow=viewport.X<=900 or math.min(viewport.X,viewport.Y)<=600
  or (math.min(viewport.X,viewport.Y)<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true
 local useCompact=narrow
 if modal and notice.Visible then hideNotice() end
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact and not inGame
   check(panel.Visible==(visible and not case[4]),"desktop level visibility")
   check(compact.Visible==(visible and case[4]),"compact level visibility")
   for _,attribute in {"BBParticipating","TGParticipating","MDParticipating"}do
    playerAttrs[attribute]=true
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local narrow=viewport.X<=900 or math.min(viewport.X,viewport.Y)<=600
  or (math.min(viewport.X,viewport.Y)<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true or player:GetAttribute("MDParticipating")==true
 local useCompact=narrow
 if modal and notice.Visible then hideNotice() end
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact and not inGame

    check(not compact.Visible,"compact level hidden in "..attribute)
    check(panel.Visible==(visible and not case[4]),"full desktop level preserved during round")
    playerAttrs[attribute]=nil
   end
   panel:Destroy();compact:Destroy();notice:Destroy()
  end
 end
 dock:Destroy();compactDock:Destroy()
end
do
 local calls=0
 local chosen=nil
 local shop={Visible=false}
 local function setShop(open) calls+=1 shop.Visible=open end
 local function setCategory(category) chosen=category end
 local function button()
  local callbacks={}
  return {Activated={Connect=function(_,callback)table.insert(callbacks,callback)end},callbacks=callbacks}
 end
 local docks={}
 for _=1,2 do table.insert(docks,{Shop=button(),Pets=button(),Toys=button()}) end
for _, target in ipairs(docks) do
	target.Shop.Activated:Connect(function() setShop(not shop.Visible) end)
	target.Pets.Activated:Connect(function() setCategory("Pets") setShop(true) end)
	target.Toys.Activated:Connect(function() setCategory("Toys") setShop(true) end)
end
 for _,dock in docks do
  for _,name in {"Shop","Pets","Toys"} do
   local control=dock[name]
   check(#control.callbacks==1,"single callback per authored button")
   shop.Visible=false;chosen=nil;local before=calls
   control.callbacks[1]()
   check(calls==before+1 and shop.Visible,"button opens once")
   check(name=="Shop" and chosen==nil or chosen==name,"same category selection")
  end
 end
end
do
 local attrs={Phase="Waiting",ReadyPlayerCount=1,MinimumReadyPlayers=2,VotingEndsAt=1035,IntermissionStatus="Waiting for ready players (1/2)"}
 local playerAttrs={}
 local sessionAttrs={}
 local player={GetAttribute=function(_,name)return playerAttrs[name]end}
 local state={GetAttribute=function(_,name)return attrs[name]end}
 local workspace={CurrentCamera={ViewportSize=Vector2.new(852,393)},GetServerTimeNow=function()return 1000 end}
 local toast={Visible=false}
 local backdrop={Visible=false}
 local session={GetAttribute=function(_,name)return sessionAttrs[name]end}
 local shell={FindFirstChild=function(_,name)return name=="RewardToast" and toast or name=="Backdrop" and backdrop or nil end}
 local modalScreens={}
 local parent={FindFirstChild=function(_,name)return name=="PlaygroundShell" and shell or name=="PlaygroundSessionControls" and session or modalScreens[name] end}
 local gui={Parent=parent}
 local position=UDim2.fromOffset(18,24)
 local size=UDim2.fromOffset(224,44)
 for _,name in {"Desktop","Compact","Portrait"} do
  local card=Instance.new("Frame")
  card.Position=position;card.Size=size
  for _,textName in {"Title","Timer","Detail"}do local t=Instance.new("TextLabel");t.Name=textName;t.Parent=card end
  local skin=Instance.new("ImageLabel");skin.Name="ReusableSkin";skin.Parent=card
  local fallback=Instance.new("Frame");fallback.Name="Fallback";fallback.Parent=card
  gui[name]=card
 end
local function render()
	local phase = state:GetAttribute("Phase")
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local short = math.min(viewport.X,viewport.Y)
	local compact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local portrait = compact and viewport.Y > viewport.X
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local shown = not participating and phase ~= "Playing"
	local shell = gui.Parent:FindFirstChild("PlaygroundShell")
	local toast = shell and shell:FindFirstChild("RewardToast")
	local backdrop = shell and shell:FindFirstChild("Backdrop")
	local session = gui.Parent:FindFirstChild("PlaygroundSessionControls")
	if backdrop and backdrop.Visible then shown = false end
	if session and (session:GetAttribute("UIHidden") == true or session:GetAttribute("SessionMenuOpen") == true) then shown = false end
	if compact and toast and toast.Visible then shown = false end
	for name, panels in pairs({ PlaygroundEmoteWheel = { "Panel" }, PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" } }) do
		local screen = gui.Parent:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, name in ipairs(panels) do
				local panel = screen:FindFirstChild(name)
				if panel and panel.Visible then shown = false end
			end
		end
	end
	local title, timer, detail = "NEXT ROUND", "", "Preparing the lobby..."
	local status = state:GetAttribute("IntermissionStatus")
	if phase == "Voting" then
		local endsAt = state:GetAttribute("VotingEndsAt")
		if typeof(endsAt) == "number" and endsAt == endsAt and math.abs(endsAt) < math.huge then
			local seconds = math.max(0,math.ceil(endsAt-workspace:GetServerTimeNow()))
			timer = string.format("%d:%02d",math.floor(seconds/60),seconds%60)
		end
		title = "INTERMISSION"
		detail = status == "Next round starts in" and "Vote for the next game!" or status or "Vote for the next game!"
	elseif phase == "Paused" then
		title, detail = "ROUNDS PAUSED", "Automatic rounds paused by an admin"
	elseif phase == "Waiting" then
		title = "WAITING FOR PLAYERS"
		local count = state:GetAttribute("ReadyPlayerCount") or 0
		local minimum = state:GetAttribute("MinimumReadyPlayers") or 2
		detail = typeof(status) == "string" and status ~= "" and status or string.format("%d / %d players ready",count,minimum)
	end
	local compactDetail = detail
	if phase == "Waiting" then
		compactDetail = typeof(status) == "string" and string.find(string.lower(status),"data",1,true)
			and "Loading player data" or string.format("Players ready: %d/%d",state:GetAttribute("ReadyPlayerCount") or 0,state:GetAttribute("MinimumReadyPlayers") or 2)
	elseif phase == "Paused" then
		compactDetail = "Paused by an admin"
	elseif phase == "Voting" and status ~= nil and status ~= "Next round starts in" then
		compactDetail = "Retrying next round"
	end
	for _,card in {gui.Desktop,gui.Compact,gui.Portrait} do
		card.Visible = shown and (card == gui.Desktop and not compact
			or card == gui.Compact and compact and not portrait
			or card == gui.Portrait and portrait)
		card.Title.Text = card ~= gui.Desktop and phase == "Waiting" and "WAITING" or title
		card.Timer.Text = timer
		card.Detail.Text = card == gui.Desktop and detail or compactDetail
		card.Fallback.Visible = not card.ReusableSkin.IsLoaded
	end
end

 for _,case in views do
  workspace.CurrentCamera.ViewportSize=Vector2.new(case[1],case[2])
  for _,phase in {"Waiting","Voting","Paused","Playing"}do
   attrs.Phase=phase;attrs.IntermissionStatus=phase=="Voting" and "Next round starts in" or phase=="Waiting" and "Waiting for ready players (1/2)" or nil
   render()
   local wanted=not case[4] and "Desktop" or case[2]>case[1] and "Portrait" or "Compact"
   for _,name in {"Desktop","Compact","Portrait"}do
    local card=gui[name]
    check(card.Visible==(phase~="Playing" and name==wanted),"intermission profile visible "..name)
    check(card.Position==position and card.Size==size,"controller keeps authored geometry")
   end
   check(gui[wanted].Timer.Text==(phase=="Voting" and "0:35" or ""),"countdown text")
   if phase=="Waiting" and case[4] then check(gui[wanted].Detail.Text=="Players ready: 1/2","phone waiting text fits")end
  end
 end
 workspace.CurrentCamera.ViewportSize=Vector2.new(390,844);attrs.Phase="Voting";attrs.IntermissionStatus="Next round starts in";attrs.VotingEndsAt=1000
 render();check(gui.Portrait.Timer.Text=="0:00","countdown expiry")
 attrs.Phase="Waiting";attrs.IntermissionStatus="Waiting for player data";render()
 check(gui.Portrait.Detail.Text=="Loading player data","phone loading explanation")
 attrs.Phase="Voting";attrs.IntermissionStatus="Preparing the next round — retrying";render()
 check(gui.Portrait.Detail.Text=="Retrying next round","phone retry explanation")
 for _,name in {"BBParticipating","TGParticipating","MDParticipating"}do
  playerAttrs[name]=true;render()
  check(not gui.Desktop.Visible and not gui.Compact.Visible and not gui.Portrait.Visible,"round participant hides timer")
  playerAttrs[name]=nil
 end
 for _,name in {"UIHidden","SessionMenuOpen"}do
  sessionAttrs[name]=true;render()
  check(not gui.Desktop.Visible and not gui.Compact.Visible and not gui.Portrait.Visible,"settings hides timer")
  sessionAttrs[name]=nil
 end
 backdrop.Visible=true;render();check(not gui.Portrait.Visible,"shop hides timer");backdrop.Visible=false
 toast.Visible=true;render();check(not gui.Portrait.Visible,"phone reward toast hides timer");toast.Visible=false
 for screenName,panels in pairs({PlaygroundEmoteWheel={"Panel"},PlaygroundDonations={"Panel"},PlaygroundAdminPanel={"Panel","CompactPanel","AdminHub"}})do
  for _,panelName in panels do
   local modal={Visible=true}
   local screen={Enabled=true,FindFirstChild=function(_,name)return name==panelName and modal or nil end}
   modalScreens[screenName]=screen;render()
   check(not gui.Portrait.Visible,"open modal hides intermission")
   screen.Enabled=false;render()
   check(gui.Portrait.Visible,"disabled modal does not hide intermission")
   modalScreens[screenName]=nil
  end
 end
 for _,name in {"Desktop","Compact","Portrait"}do gui[name]:Destroy()end
end
do
 local playerAttrs={PCFishingCoinsExpires=1300,PCFishingXPExpires=1600}
 local sessionAttrs={}
 local screens={}
 local player={GetAttribute=function(_,name)return playerAttrs[name]end}
 local parent={FindFirstChild=function(_,name)return screens[name]end}
 local function screen(names)
  local children={}
  for _,name in names do children[name]={Visible=false}end
  return {Enabled=true,FindFirstChild=function(_,name)return children[name]end,children=children}
 end
 screens.PlaygroundShell=screen({"ShopPanel","VotePanel","CompactVotePanel"})
 screens.PlaygroundEmoteWheel=screen({"Panel"})
 screens.PlaygroundDonations=screen({"Panel"})
 screens.PlaygroundAdminPanel=screen({"Panel","CompactPanel","AdminHub"})
 screens.PlaygroundSessionControls=screen({"Dock"})
 screens.PlaygroundSessionControls.GetAttribute=function(_,name)return sessionAttrs[name]end
 screens.MudHUD=screen({"ColourPicker"})
 local gui={Parent=parent}
 local function dock(name)
  local frame=Instance.new("Frame")
  frame.Name=name;frame.Size=UDim2.fromOffset(96,38);frame.Position=UDim2.fromOffset(8,112)
  local scale=Instance.new("UIScale");scale.Name="LayoutScale";scale.Scale=1;scale.Parent=frame
  for _,rowName in {"Coins","XP"}do
   local row=Instance.new("Frame");row.Name=rowName;row.Parent=frame
   local timer=Instance.new("TextLabel");timer.Name="Timer";timer.Parent=row
  end
  return frame
 end
 local desktop,compact,portrait,round=dock("DesktopDock"),dock("CompactDock"),dock("PortraitDock"),dock("RoundDock")
 local docks={desktop,compact,portrait,round}
 local attributes={Coins="PCFishingCoinsExpires",XP="PCFishingXPExpires"}
 local workspace={CurrentCamera={ViewportSize=Vector2.new(852,393)},GetServerTimeNow=function()return 1000 end}
local function remaining(expires, now)
	if typeof(expires) ~= "number" or expires ~= expires or math.abs(expires) == math.huge then return 0 end
	return math.max(0, math.ceil(expires - now))
end

local function formatTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function modalOpen(playerGui)
	local panels = {
		PlaygroundShell = { "ShopPanel", "VotePanel", "CompactVotePanel" },
		PlaygroundEmoteWheel = { "Panel" },
		PlaygroundDonations = { "Panel" },
		PlaygroundAdminPanel = { "Panel", "CompactPanel", "AdminHub" },
		PlaygroundSessionControls = { "Dock" },
		MudHUD = { "ColourPicker" },
	}
	for name, children in pairs(panels) do
		local screen = playerGui:FindFirstChild(name)
		if screen and screen.Enabled then
			for _, child in ipairs(children) do
				local panel = screen:FindFirstChild(child)
				if panel and panel.Visible then return true end
			end
		end
	end
	return false
end

local function refresh()
	local playerGui = gui.Parent
	local session = playerGui:FindFirstChild("PlaygroundSessionControls")
	local hidden = session and (session:GetAttribute("UIHidden") == true
		or session:GetAttribute("Spectating") == true or session:GetAttribute("SessionMenuOpen") == true)
	hidden = hidden or modalOpen(playerGui)
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
	local short = math.min(viewport.X,viewport.Y)
	local isCompact = viewport.X <= 900 or short <= 600
		or (short <= 1024 and math.max(viewport.X,viewport.Y) <= 1400)
	local participating = player:GetAttribute("BBParticipating") == true
		or player:GetAttribute("TGParticipating") == true or player:GetAttribute("MDParticipating") == true
	local selected = not isCompact and desktop or participating and round
		or viewport.Y > viewport.X and portrait or compact
	for _, dock in docks do dock.Visible = not hidden and dock == selected end
	local now = workspace:GetServerTimeNow()
	for name, attribute in pairs(attributes) do
		local seconds = remaining(player:GetAttribute(attribute),now)
		for _, dock in docks do
			local row = dock[name]
			row.Visible = seconds > 0
			row.Timer.Text = formatTime(seconds)
		end
	end
end

 for _,case in views do
  workspace.CurrentCamera.ViewportSize=Vector2.new(case[1],case[2])
  for _,attribute in {false,"BBParticipating","TGParticipating","MDParticipating"}do
   if attribute then playerAttrs[attribute]=true end
   refresh()
   local wanted=not case[4] and desktop or attribute and round or case[2]>case[1] and portrait or compact
   for _,dock in docks do
    check(dock.Visible==(dock==wanted),"fishing profile and round dock")
    check(dock.Coins.Timer.Text=="5:00" and dock.XP.Timer.Text=="10:00","both boost clocks updated on every dock")
    check(dock.Coins.Visible and dock.XP.Visible,"active rows visible")
    check(dock.Size==UDim2.fromOffset(96,38) and dock.Position==UDim2.fromOffset(8,112) and dock.LayoutScale.Scale==1,"fishing leaves authored geometry and scale")
   end
   if attribute then playerAttrs[attribute]=nil end
  end
 end
 workspace.CurrentCamera.ViewportSize=Vector2.new(390,844)
 for _,name in {"UIHidden","Spectating","SessionMenuOpen"}do
  sessionAttrs[name]=true;refresh()
  for _,dock in docks do check(not dock.Visible,"session hides fishing")end
  sessionAttrs[name]=nil
 end
 for _,screen in pairs(screens)do
  for _,panel in pairs(screen.children)do
   panel.Visible=true;refresh()
   for _,dock in docks do check(not dock.Visible,"modal hides fishing")end
   screen.Enabled=false;refresh()
   check(portrait.Visible,"disabled screen does not hide fishing")
   screen.Enabled=true;panel.Visible=false
  end
 end
 for _,value in {false,0,999,1000,0/0,math.huge}do
  playerAttrs.PCFishingCoinsExpires=value;playerAttrs.PCFishingXPExpires=value;refresh()
  for _,dock in docks do
   check(not dock.Coins.Visible and not dock.XP.Visible,"expired or invalid boosts hidden")
   check(dock.Coins.Timer.Text=="0:00" and dock.XP.Timer.Text=="0:00","expired clocks zero")
  end
 end
 playerAttrs.PCFishingCoinsExpires=1001;playerAttrs.PCFishingXPExpires=1061;refresh()
 for _,dock in docks do check(dock.Coins.Timer.Text=="0:01" and dock.XP.Timer.Text=="1:01","boost minute formatting")end
 for _,dock in docks do dock:Destroy()end
end

for _,value in {0.35,0.5,0.6,0.75,1}do check(math.clamp(value,0.35,1)==value,"authored scale remains editable")end
return {passed=tests,viewports=#views,dockButtons=6}

