assert(not game:GetService("RunService"):IsRunning())
local box=game.StarterGui.MudHUD.Controller:Clone()
box.Name="_MudHUDVisibilityCheck"box.Enabled=false box.Parent=game.ServerStorage
local gui=game.StarterGui.MudHUD:Clone()gui.Name="Fixture"gui.Parent=box
local m=Instance.new("ModuleScript")m.Source=[======[local gui=script.Parent:WaitForChild("Fixture")
local main=gui.Main
local controls=main.DesktopControls
local palette=gui.ColourPicker
local pValues,sValues={},{}
local player={PlayerGui={FindFirstChild=function()return nil end}}
function player:GetAttribute(k)return pValues[k]end
local state={}
function state:GetAttribute(k)return sValues[k]end
local UserInputService={TouchEnabled=false}
local ContextActionService={BindActionAtPriority=function()end,UnbindAction=function()end}
local HttpService=game:GetService("HttpService")
local binding,sprintHeld,fireHeld=false,false,false
local messageUntil,message=0,""
local workspace={GetServerTimeNow=function()return 100 end}
local function release()sprintHeld=false fireHeld=false end
local function keys()end
local function playing()return pValues.MDParticipating==true and sValues.Phase=="Playing" and not pValues.MDMuddy end
local function sprintChange()end
local function progress()end
local function caption(button,text)button.Text=text local label=button:FindFirstChild("LiveCaption")if label then label.Text=text end end
local function refresh()
 local phase=state:GetAttribute("Phase")
 local participating=player:GetAttribute("MDParticipating")==true
 local active=participating and (phase=="Countdown" or phase=="Playing" or phase=="Results")
 local shell=player.PlayerGui:FindFirstChild("PlaygroundShell")
 local compactVote=shell and shell:FindFirstChild("CompactVotePanel")
 local blocked=player:GetAttribute("BBParticipating") or player:GetAttribute("TGParticipating")
  or shell and (shell.ShopPanel.Visible or shell.VotePanel.Visible or compactVote and compactVote.Visible)
 if palette.Visible and blocked then palette.Visible=false release() end
 main.Visible=active
 gui.ColourToggle.Visible=not participating and not player:GetAttribute("BBParticipating") and not player:GetAttribute("TGParticipating")
 if participating and not binding then
  ContextActionService:BindActionAtPriority("MudControls",keys,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)
  binding=true
 elseif not participating and binding then ContextActionService:UnbindAction("MudControls") binding=false release() end
 if not active then return end
 local now=workspace:GetServerTimeNow()
 local remaining=phase=="Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds=math.ceil(remaining)
 main.Top.Timer.Text=string.format("%d:%02d",math.floor(seconds/60),seconds%60)
 main.Top.Visible=phase~="Results"
 main.Countdown.Visible=phase=="Countdown"
 main.Countdown.Text=tostring(state:GetAttribute("CountdownValue") or 3)
 local teamId=player:GetAttribute("MDTeamId") or 0
 local own
 local other
 local ok,teams=pcall(function() return HttpService:JSONDecode(state:GetAttribute("TeamSummaryJSON") or "[]") end)
 if ok and typeof(teams)=="table" then for _,team in ipairs(teams) do if team.teamId==teamId then own=team else other=team end end end
 local color=player:GetAttribute("MDTeamColor") or Color3.fromRGB(42,160,255)
 main.Top.Team.BackgroundColor3=color
 local teamColour=main.Top.Team:FindFirstChild("TeamColour")
 if teamColour then teamColour.BackgroundColor3=color end
 caption(main.Top.Team,string.upper(player:GetAttribute("MDTeamColorName") or "TEAM").."\n"..(own and tostring(own.free).."/"..tostring(own.total).." FREE" or ""))
 main.Top.Other.Text=(state:GetAttribute("TeamCount") or 2)==2 and other and string.upper(other.colorName).."\n"..tostring(other.free).."/"..tostring(other.total).." FREE" or "TEAMS LEFT:\n"..tostring(state:GetAttribute("ActiveTeamCount") or 0)
 local muddy=player:GetAttribute("MDMuddy")==true or player:GetAttribute("MDEliminated")==true
 local showControls=(phase=="Playing" or phase=="Countdown") and not muddy and not palette.Visible
 main.Controls.Visible=controls==main.Controls and showControls
 local desktopControls=main:FindFirstChild("DesktopControls")
 if desktopControls then desktopControls.Visible=controls==desktopControls and showControls end
 controls.Visible=showControls
 controls.Mud.Visible=UserInputService.TouchEnabled
 controls.Heat.Visible=UserInputService.TouchEnabled
 controls.Fire.Visible=UserInputService.TouchEnabled
 main.Frozen.Visible=(phase=="Playing" or phase=="Countdown") and muddy
 main.Crosshair.Visible=playing() and not palette.Visible
 local maximum=math.max(0.1,player:GetAttribute("MDSprintMax") or 10)
 local stamina=math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 if player:GetAttribute("MDHeatActive") then
  controls.Meter.Charge.Text=string.format("RESCUING %.1fs / %gs",player:GetAttribute("MDHeatProgress") or 0,state:GetAttribute("RescueSeconds") or 5)
 else controls.Meter.Charge.Text=now<messageUntil and message or string.format("SPRINT %.1fs / %ds",stamina,maximum) end
 progress(controls.Meter.Track,stamina/maximum)
 local sprinting=player:GetAttribute("MDSprinting")
 caption(controls.Sprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT").." · "..(UserInputService.TouchEnabled and "HOLD" or "HOLD SHIFT"))
 controls.Sprint.BackgroundColor3=color
 local equipped=player:GetAttribute("MDTool") or ""
 controls.Mud.Outline.Color=equipped=="MudGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Heat.Outline.Color=equipped=="HeatGun" and Color3.fromRGB(255,205,77) or Color3.fromRGB(24,35,62)
 controls.Mud.Outline.Enabled=equipped=="MudGun"
 controls.Heat.Outline.Enabled=equipped=="HeatGun"
 caption(controls.Fire,equipped=="HeatGun" and "HEAT\nHOLD" or "SPLAT!")
 local rescueSeconds=math.max(0.1,state:GetAttribute("RescueSeconds") or 5)
 local rescue=math.clamp(player:GetAttribute("MDRescueProgress") or 0,0,rescueSeconds)
 main.Frozen.Title.Text=player:GetAttribute("MDEliminated") and "TEAM ELIMINATED" or "STUCK IN THE MUD!"
 main.Frozen.Status.Text=string.format("TEAMMATE HEAT: %.1f / %gs",rescue,rescueSeconds)
 progress(main.Frozen.RescueTrack,rescue/rescueSeconds)
 main.Results.Visible=phase=="Results"
 if phase=="Results" then
  local won=player:GetAttribute("MDResult")=="Won"
  main.Results.Title.Text=won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  local reason=state:GetAttribute("ResultReason")
  main.Results.Reason.Text=reason=="TimeoutShared" and "BEST SURVIVING TEAMS SHARE THE WIN" or reason=="Timeout" and "MOST OF THE TEAM STAYED FREE" or reason=="NoActiveTeams" and "EVERY TEAM IS STUCK" or "LAST TEAM STILL FREE"
  local practice=state:GetAttribute("LastResultPractice")==true
  main.Results.Rewards.Text=practice and "PRACTICE ROUND" or (won and "+150 COINS" or "+50 COINS").." · +50 XP"
 end
 if not playing() then if sprintHeld or fireHeld then release() end else sprintChange() end
end

return function(p,s,touch)
 pValues=p sValues=s UserInputService.TouchEnabled=touch==true controls=touch and main.Controls or main.DesktopControls refresh()
 return {main=main.Visible,mobile=main.Controls.Visible,desktop=main.DesktopControls.Visible,results=main.Results.Visible,top=main.Top.Visible,frozen=main.Frozen.Visible,team=gui.ColourToggle.Visible,crosshair=main.Crosshair.Visible}
end]======]m.Parent=box
local checks={}local function check(n,v)assert(v,n)table.insert(checks,n)end
local ok,err=xpcall(function()
 local step=require(m)
 local p={MDParticipating=false}
 local s={Phase="Waiting",EndsAt=220}
 local r=step(p,s,false)
 check("Lobby hides Mud gameplay",not r.main and r.team)
 p.MDParticipating=true
 check("Inactive Mud phase remains hidden",not step(p,s,false).main)
 s.Phase="Countdown"r=step(p,s,false)
 check("Desktop controls selected exclusively",r.main and r.desktop and not r.mobile)
 s.Phase="Playing"r=step(p,s,true)
 check("Mobile controls selected exclusively",r.main and r.mobile and not r.desktop)
 p.MDMuddy=true r=step(p,s,true)
 check("Frozen state hides both controls",r.frozen and not r.mobile and not r.desktop)
 p.MDMuddy=false s.Phase="Results"r=step(p,s,false)
 check("Results hides top and both control variants",r.main and r.results and not r.top and not r.mobile and not r.desktop)
 p.MDParticipating=false p.TGParticipating=true r=step(p,s,false)
 check("Tag round hides Mud gameplay and lobby team picker",not r.main and not r.team)
 p.TGParticipating=false p.BBParticipating=true r=step(p,s,true)
 check("Bulldog round hides Mud gameplay and team picker",not r.main and not r.team)
end,debug.traceback)
box:Destroy()
return game.HttpService:JSONEncode({passed=ok,error=not ok and err or nil,checks=checks,fixtureDestroyed=box.Parent==nil,playStarted=false})
