assert(not game:GetService("RunService"):IsRunning())
local box=game.StarterGui.TagHUD.Controller:Clone()box.Name="_TagHUDVisibilityCheck"box.Enabled=false box.Parent=game.ServerStorage
local fixture=game.StarterGui.TagHUD:Clone()fixture.Name="Fixture"fixture.Parent=box
local m=Instance.new("ModuleScript")m.Source=[======[local gui=script.Parent:WaitForChild("Fixture")
local pValues,sValues={},{}
local player={}
function player:GetAttribute(k)return pValues[k]end
local state={}
function state:GetAttribute(k)return sValues[k]end
local workspace={GetServerTimeNow=function()return 100 end}
local UserInputService={TouchEnabled=false}
local top = gui:WaitForChild("Top")
local taggerName = top:WaitForChild("TaggerChip"):WaitForChild("Name")
local rolePanel = gui:WaitForChild("Role")
local controls = gui:WaitForChild("Controls")
local results = gui:WaitForChild("Results")
local blue = Color3.fromRGB(54, 174, 255)
local red = Color3.fromRGB(255, 83, 100)
local yellow = Color3.fromRGB(255, 204, 54)
local messageEndsAt = 0
local busy = false
local phaseStartedAt = workspace:GetServerTimeNow()
local currentPhase = state:GetAttribute("Phase")
local alive = true
local moveSerial = 0

local function secondsRemaining(endsAt, now)
	return math.max(0, (tonumber(endsAt) or 0) - now)
end

local function update()
	local now = workspace:GetServerTimeNow()
	local participating = player:GetAttribute("TGParticipating") == true
	local phase = state:GetAttribute("Phase") or "Waiting"
	gui.Enabled = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
	if not gui.Enabled then return end
	top.Visible = phase ~= "Results"
	if currentPhase ~= phase then currentPhase = phase phaseStartedAt = now end
	local remaining = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 180) or secondsRemaining(state:GetAttribute("EndsAt"), now)
	local whole = math.ceil(remaining)
	top.Timer.Text = string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	taggerName.Text = "IT: " .. tostring(state:GetAttribute("TaggerName") or "")
	local lastTaggerRule = state:GetAttribute("WinRule") == "LastTagger"
	local grace = secondsRemaining(state:GetAttribute("InitialGraceEndsAt"), now)
	top.Rule.Text = lastTaggerRule and "DON'T BE IT WHEN TIME RUNS OUT!" or grace > 0 and "FIRST CHASE GRACE: " .. tostring(math.ceil(grace)) .. "s" or "MOST TIME AS IT LOSES"
	local role = player:GetAttribute("TGRole") or "Runner"
	rolePanel.Visible = not gui:FindFirstChild("SprintPanel")
	rolePanel.BackgroundColor3 = role == "Tagger" and red or blue
	rolePanel.Title.Text = role == "Tagger" and "YOU'RE IT!" or "RUNNER"
	rolePanel.Time.Text = string.format("TIME AS IT: %.1fs", tonumber(player:GetAttribute("TGTaggerSeconds")) or 0)
	local protected = secondsRemaining(player:GetAttribute("TGProtectedEndsAt"), now)
	gui.Protection.Visible = protected > 0 and role == "Runner" and phase == "Playing" and now >= messageEndsAt
	gui.Protection.Text = "TAGBACK SHIELD: " .. tostring(math.ceil(protected)) .. "s"
	gui.Countdown.Visible = phase == "Countdown" or phase == "Playing" and now - phaseStartedAt < 0.7
	gui.Countdown.Text = phase == "Countdown" and tostring(state:GetAttribute("CountdownValue") or 3) or "GO!"
	controls.Visible = phase == "Playing"
	local button = controls.Dodge
	local cooldown = secondsRemaining(player:GetAttribute("TGDodgeReadyAt"), now)
	button.Text = "DODGE\n" .. (cooldown > 0 and string.format("%.1fs", cooldown) or UserInputService.TouchEnabled and "TAP" or "[E]")
	button.Active = cooldown == 0 and not busy and player:GetAttribute("TGRagdolled") ~= true

	gui.MoveMessage.Visible = now < messageEndsAt
	results.Visible = phase == "Results"
	if phase == "Results" then
		local won = player:GetAttribute("TGResult") == "Won"
		results.Title.Text = won and "YOU WIN!" or "TRY AGAIN!"
		results.Title.TextColor3 = Color3.fromRGB(255,248,221)
		results.Loser.Text = (lastTaggerRule and "FINAL TAGGER: " or "MOST TIME AS IT: ") .. tostring(state:GetAttribute("LosersText") or "")
		results.WinnersScroll.Winners.Text = "WINNERS: " .. tostring(state:GetAttribute("WinnersText") or "")
	end
end


return function(p,s)
 pValues=p sValues=s update()
 return {enabled=gui.Enabled,controls=gui.Controls.Visible,results=gui.Results.Visible,role=gui.Role.Visible,name=gui.Top.TaggerChip:FindFirstChild("Name").Text,color=gui.Results.Title.TextColor3,top=gui.Top.Visible}
end]======]m.Parent=box
local checks={}local function check(n,v)assert(v,n)table.insert(checks,n)end
local ok,err=xpcall(function()
 local step=require(m)local p={TGParticipating=false}local s={Phase="Waiting",EndsAt=220,TaggerName="Test Runner"}
 check("Lobby Tag HUD is hidden",not step(p,s).enabled)
 p.TGParticipating=true
 check("Tag inactive phase is hidden",not step(p,s).enabled)
 s.Phase="Countdown"local r=step(p,s)
 check("Countdown displays one Tag HUD",r.enabled and not r.controls)
 check("Redundant role panel stays hidden with SprintPanel present",not r.role)
 s.Phase="Playing"r=step(p,s)
 check("Playing displays dodge control",r.enabled and r.controls)
 check("Tagger caption binds real name data",r.name=="IT: Test Runner")
 s.Phase="Results"r=step(p,s)
 check("Results hides gameplay controls and top card",r.results and not r.controls and not r.top)
 check("Results has light readable text fill",r.color.R>.9 and r.color.G>.9 and r.color.B>.8)
 p.TGParticipating=false
 check("Leaving Tag hides its HUD",not step(p,s).enabled)
end,debug.traceback)
box:Destroy()
return game.HttpService:JSONEncode({passed=ok,error=not ok and err or nil,checks=checks,fixtureDestroyed=box.Parent==nil,playStarted=false})
