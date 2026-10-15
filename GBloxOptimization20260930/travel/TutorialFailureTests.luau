local checks=0
local function check(value,message) checks+=1 assert(value,message) end
local build=assert(loadstring([====[
return function()
 local state="Menu"
 local main={Notice={Text=""},PlayButton={}}
 local player={}
 local root={}
 local connections={}
 local entered=0
 local eventCallback
 local gate={}
 local result="Teleporting"
 local earlyFailure=false
 local service={TeleportInitFailed={Connect=function(_,callback) eventCallback=callback return {} end}}
 local game={GetService=function() return service end}
 local ReplicatedStorage={WaitForChild=function() return gate end}
 local GuiService={}
 local UserInputService={GamepadEnabled=true}
 local setState=function(value) state=value end
 local tween=function() end
 local playSound=function() end
 local enterLobby=function() entered+=1 state="Lobby" end
 local warn=function() end
 gate.InvokeServer=function()
  if earlyFailure then eventCallback(player,{Name="Failure"},"network",128350578096458) end
  return result
 end
]====] .. [====[local tutorialGate = ReplicatedStorage:WaitForChild("GBloxTutorialGate", 10)
local playRequestInFlight = false
local tutorialPending = false
local tutorialRequestVersion = 0
local tutorialFailedVersion
table.insert(connections, game:GetService("TeleportService").TeleportInitFailed:Connect(function(who, result, message, placeId)
 if who ~= player or placeId ~= 128350578096458 or (not tutorialPending and not playRequestInFlight) then return end
 tutorialFailedVersion = tutorialRequestVersion
 tutorialPending = false
 playRequestInFlight = false
 setState("Menu")
 tween(root, 0.2, { GroupTransparency = 0 })
 main.Notice.Text = "Could not connect to the tutorial. Please try Play again."
 warn("[G-Blox tutorial travel]", result.Name, message)
 if UserInputService.GamepadEnabled then GuiService.SelectedObject = main.PlayButton end
end))

local function playFromMenu()
	if state ~= "Menu" or playRequestInFlight then return end
	if not tutorialGate then
		main.Notice.Text = "Tutorial service is still connecting"
		return
	end

	playRequestInFlight = true
 tutorialRequestVersion += 1
 local requestVersion = tutorialRequestVersion
	main.Notice.Text = "Checking tutorial..."
	local success, result = pcall(function()
		return tutorialGate:InvokeServer()
	end)
	if requestVersion ~= tutorialRequestVersion or tutorialFailedVersion == requestVersion then return end
 playRequestInFlight = false

	if success and result == "Completed" then
		main.Notice.Text = ""
		enterLobby()
	elseif success and result == "Teleporting" then
  tutorialPending = true
		setState("Fading")
		playSound("Play")
		GuiService.SelectedObject = nil
		tween(root, 0.25, { GroupTransparency = 1 })
	else
		main.Notice.Text = "Couldn't check tutorial progress. Try Play again."
	end
end

]====] .. [====[
 return {
  play=playFromMenu,
  setResult=function(value) result=value end,
  earlyFailure=function() earlyFailure=true end,
  fail=function(place) eventCallback(player,{Name="Failure"},"network",place or 128350578096458) end,
  state=function() return state,main.Notice.Text,entered end,
 }
end
]====]))()
local a=build()
a.play()
local state,notice=a.state()
check(state=="Fading","accepted tutorial fades")
a.fail()
state,notice=a.state()
check(state=="Menu" and notice:find("try Play again",1,true),"late failure restores menu")
a.setResult("Completed") a.play()
state,notice,entered=a.state()
check(state=="Lobby" and entered==1,"retry Play works after failure")
local b=build() b.earlyFailure() b.play()
state,notice=b.state()
check(state=="Menu","failure before InvokeServer returns cannot fade afterward")
local c=build() c.play() c.fail(999)
check(c.state()=="Fading","unrelated place event ignored")
local d=build() d.setResult("Unavailable") d.play()
check(d.state()=="Menu","unavailable route remains usable")
d.setResult("Completed") d.play()
check(d.state()=="Lobby","normal failure releases click debounce")
print(string.format("Tutorial failure UI: %d checks passed",checks))

