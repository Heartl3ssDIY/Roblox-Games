local tutorialGate = ReplicatedStorage:WaitForChild("GBloxTutorialGate", 10)
local playRequestInFlight = false

local function playFromMenu()
	if state ~= "Menu" or playRequestInFlight then return end
	if not tutorialGate then
		main.Notice.Text = "Tutorial service is still connecting"
		return
	end

	playRequestInFlight = true
	main.Notice.Text = "Checking tutorial..."
	local success, result = pcall(function()
		return tutorialGate:InvokeServer()
	end)
	playRequestInFlight = false

	if success and result == "Completed" then
		main.Notice.Text = ""
		enterLobby()
	elseif success and result == "Teleporting" then
		setState("Fading")
		playSound("Play")
		GuiService.SelectedObject = nil
		tween(root, 0.25, { GroupTransparency = 1 })
	else
		main.Notice.Text = "Couldn't check tutorial progress. Try Play again."
	end
end
