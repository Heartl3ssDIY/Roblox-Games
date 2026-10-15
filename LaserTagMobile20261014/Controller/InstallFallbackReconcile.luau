local s=game.StarterGui.MudHUD.Controller
assert(s.Source==[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local player, gui = Players.LocalPlayer, script.Parent
local main = gui:WaitForChild("Main")
local state = ReplicatedStorage:WaitForChild("MudState")
local remote = ReplicatedStorage:WaitForChild("MudActionRequest")
local headers = { main.Top, main.CompactTop, main.PortraitTop }
local connections, characterConnections = {}, {}
local focused, alive, bound = true, true, false
local character, fireTool
local sprintKeys, fireInputs = {}, {}
local sprintTouch, sprintHeld
local currentInputMode
local lastSprint, nextShotAt, elapsed = 0, 0, 0
local sending, pending = {}, {}
local message, messageUntil = "", 0
main.Visible = false

local function connect(signal, callback, list)
 local connection = signal:Connect(callback)
 table.insert(list or connections, connection)
 return connection
end

local function bindImageFallback(fallback, skin)
 if not skin then return end
 local function refreshFallback()
  fallback.Visible = skin.Image == "" or not skin.IsLoaded
 end
 refreshFallback()
 connect(skin:GetPropertyChangedSignal("IsLoaded"), refreshFallback)
 connect(skin:GetPropertyChangedSignal("Image"), refreshFallback)
end

for _, descendant in ipairs(main:GetDescendants()) do
 if descendant.Name == "ArtFallback" and descendant:IsA("Frame") then
  bindImageFallback(descendant, descendant.Parent:FindFirstChild("ReusableSkin"))
 end
end

local function caption(button, value)
 button.Text = value
 local live = button:FindFirstChild("LiveCaption")
 if live then live.Text = value end
end

local function playing()
 return player:GetAttribute("MDParticipating") == true and state:GetAttribute("Phase") == "Playing"
  and player:GetAttribute("MDEliminated") ~= true and (player:GetAttribute("MDLives") or 3) > 0
end

local function sessionControls()
 return player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
end

local function modalOpen()
 local session = sessionControls()
 if session and (session:GetAttribute("SessionMenuOpen") == true or session:GetAttribute("Spectating") == true) then return true end
 for name, panels in pairs({PlaygroundShell={"ShopPanel","VotePanel","CompactVotePanel"},PlaygroundAdminPanel={"AdminHub"},PlaygroundEmoteWheel={"Panel"}}) do
  local screen = player.PlayerGui:FindFirstChild(name)
  if screen and screen.Enabled then
   for _, name in ipairs(panels) do
    local panel = screen:FindFirstChild(name)
    if panel and panel.Visible then return true end
   end
  end
 end
 return GuiService.MenuIsOpen
end

local function inputAllowed()
 return alive and focused and gui.Enabled and playing() and not UserInputService:GetFocusedTextBox() and not modalOpen()
end

local function request(action, value, quiet)
 pending[action] = { value = value, quiet = quiet }
 if sending[action] then return end
 sending[action] = true
 task.spawn(function()
  while alive and pending[action] do
   local nextRequest = pending[action]
   pending[action] = nil
   local ok, result = pcall(remote.InvokeServer, remote, action, nextRequest.value)
   if not nextRequest.quiet and (not ok or typeof(result) == "table" and result.ok == false) then
    message = ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil = workspace:GetServerTimeNow() + 1.4
   end
  end
  sending[action] = nil
 end)
end

local function releaseFire()
 table.clear(fireInputs)
 fireTool = nil
 pending.Fire = nil
end

local function release()
 table.clear(sprintKeys)
 sprintTouch, sprintHeld = nil, false
 releaseFire()
 request("Sprint", false, true)
end

local function sprintChange()
 local held = inputAllowed() and (next(sprintKeys) ~= nil or sprintTouch ~= nil)
 if held ~= sprintHeld then
  sprintHeld, lastSprint = held, os.clock()
  request("Sprint", held, true)
 end
end

local function selectedHeader(viewport)
 if viewport.Y > viewport.X then return main.PortraitTop end
 if viewport.X < 1000 or viewport.Y <= 600 then return main.CompactTop end
 return main.Top
end

local function viewportAim(viewport, mousePosition, deviceOrigin, cursorAim)
 local point = cursorAim and mousePosition - deviceOrigin or viewport * 0.5
 return Vector2.new(math.clamp(point.X, 0, viewport.X), math.clamp(point.Y, 0, viewport.Y))
end

local function inputMode()
 if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then return "Gamepad" end
 if UserInputService.TouchEnabled then return "Touch" end
 return "Mouse"
end

local function aimPoint(camera)
 local cursorAim = inputMode() == "Mouse"
  and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
 if not cursorAim then
  local forward = camera.CFrame.Position + camera.CFrame.LookVector * 100
  local projected = camera:WorldToViewportPoint(forward)
  return Vector2.new(projected.X, projected.Y)
 end
 local deviceArea = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local screenArea = GuiService:GetInsetArea(Enum.ScreenInsets.None)
 return viewportAim(camera.ViewportSize, UserInputService:GetMouseLocation(), deviceArea.Min - screenArea.Min, cursorAim)
end

local function aimRay()
 local camera = workspace.CurrentCamera
 if not camera then return nil end
 local point = aimPoint(camera)
 local ray = camera:ViewportPointToRay(point.X, point.Y)
 return { cameraOrigin = ray.Origin, cameraDirection = ray.Direction }
end

local function assignedGun(tool)
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 return tool and tool:IsA("Tool") and tool.Name == expected and tool:GetAttribute("MDManaged") == true
  and tool:GetAttribute("MDOwnerUserId") == player.UserId and tool:GetAttribute("MDRound") == state:GetAttribute("RoundNumber")
  and tool:GetAttribute("MDTeamId") == player:GetAttribute("MDTeamId") and tool.Enabled and tool or nil
end

local function equippedGun()
 local current = player.Character
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 return assignedGun(current and current:FindFirstChild(expected))
end

local function equipAssignedGun()
 local equipped = equippedGun()
 if equipped or not inputAllowed() then return equipped end
 local current = player.Character
 local humanoid = current and current:FindFirstChildOfClass("Humanoid")
 local backpack = player:FindFirstChildOfClass("Backpack")
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 local tool = assignedGun(backpack and backpack:FindFirstChild(expected))
 if tool and humanoid and humanoid.Health > 0 then pcall(humanoid.EquipTool, humanoid, tool) end
 return equippedGun()
end

local function fireWeapon()
 if not inputAllowed() then return end
 local tool = equippedGun()
 if not tool or fireTool and tool ~= fireTool then return end
 local now = workspace:GetServerTimeNow()
 if now < math.max(nextShotAt, player:GetAttribute("MDFireReadyAt") or 0) then return end
 local ray = aimRay()
 if not ray then return end
 fireTool = tool
 nextShotAt = now + (state:GetAttribute("LaserCooldownSeconds") or state:GetAttribute("MudCooldownSeconds") or 0.65) + 0.02
 request("Fire", ray, true)
end

local function beginFire(input)
 if not inputAllowed() then return end
 fireInputs[input] = true
 local tool = equipAssignedGun()
 if not tool then
  request("Equip", player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun", true)
 end
 fireWeapon()
end

local function keyAction(_, phase, input)
 if not player:GetAttribute("MDParticipating") or player:GetAttribute("MDEliminated") then return Enum.ContextActionResult.Pass end
 if phase == Enum.UserInputState.End or phase == Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode] = nil
 elseif phase == Enum.UserInputState.Begin and inputAllowed() then
  sprintKeys[input.KeyCode] = true
 end
 sprintChange()
 return Enum.ContextActionResult.Sink
end

local function triggerAction(_, phase, input)
 if not player:GetAttribute("MDParticipating") or player:GetAttribute("MDEliminated") then return Enum.ContextActionResult.Pass end
 if phase == Enum.UserInputState.Begin then beginFire(input.KeyCode)
 elseif phase == Enum.UserInputState.End or phase == Enum.UserInputState.Cancel then
  fireInputs[input.KeyCode] = nil
  if not next(fireInputs) then fireTool = nil end
 end
 return Enum.ContextActionResult.Sink
end

local function progress(track, fraction)
 fraction = math.clamp(fraction, 0, 1)
 local gradient = track.Fill.Progress
 if fraction <= 0 then gradient.Transparency = NumberSequence.new(1)
 elseif fraction >= 1 then gradient.Transparency = NumberSequence.new(0)
 else
  local edge = math.clamp(fraction, 0.001, 0.999)
  gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(edge-0.0001,0),
   NumberSequenceKeypoint.new(edge+0.0001,1), NumberSequenceKeypoint.new(1,1)})
 end
end

local function bindCharacter(nextCharacter)
 if nextCharacter == character then return end
 release()
 character, nextShotAt = nextCharacter, 0
 for _, connection in ipairs(characterConnections) do connection:Disconnect() end
 table.clear(characterConnections)
 if character then
  connect(character.ChildRemoved, function(child) if child == fireTool then releaseFire() end end, characterConnections)
 end
end

local function refresh()
 local phase = state:GetAttribute("Phase")
 local participating = player:GetAttribute("MDParticipating") == true
 local active = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
 local touch = inputMode() == "Touch"
 if participating and not bound then
  ContextActionService:BindActionAtPriority("LaserTagSprint", keyAction, false, 3000, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
  ContextActionService:BindActionAtPriority("LaserTagFire", triggerAction, false, 3000, Enum.KeyCode.ButtonR2)
  bound = true
 elseif not participating and bound then
  ContextActionService:UnbindAction("LaserTagSprint")
  ContextActionService:UnbindAction("LaserTagFire")
  bound = false
  release()
 end
 main.Visible = active
 if not active then return end
 local camera = workspace.CurrentCamera
 local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
 local selected = selectedHeader(viewport)
 local now = workspace:GetServerTimeNow()
 local duration = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds = math.ceil(duration)
 local out = player:GetAttribute("MDEliminated") == true
 local lives = math.clamp(player:GetAttribute("MDLives") or 3, 0, 3)
 local session = sessionControls()
 local hidden = session and session:GetAttribute("UIHidden") == true
 local modal = modalOpen()
 for _, header in ipairs(headers) do
  header.Visible = header == selected and phase ~= "Results" and not hidden and not modal
  header.Timer.Text = string.format("%d:%02d", math.floor(seconds/60), seconds%60)
  caption(header.Team, "RED\n" .. tostring(state:GetAttribute("RedAlive") or 0) .. " ALIVE")
  header.Other.Text = "BLUE\n" .. tostring(state:GetAttribute("BlueAlive") or 0) .. " ALIVE"
  header.Lives.Visible = not out
  header.Out.Visible = out
  header.Lives.Team.Text = player:GetAttribute("MDTeamId") == 1 and "RED" or "BLUE"
  for index = 1, 3 do header.Lives["Heart"..index].TextColor3 = index <= lives and Color3.fromRGB(255,82,105) or Color3.fromRGB(99,108,126) end
 end
 main.Countdown.Visible = phase == "Countdown" and not out
 main.Countdown.Text = tostring(state:GetAttribute("CountdownValue") or 3)
 local showControls = phase == "Playing" and not out and not modal
 main.Controls.Visible = showControls and touch
 main.DesktopControls.Visible = showControls and not touch
 main.MobileSprint.Visible = showControls and touch
 main.Crosshair.Visible = inputAllowed() and equippedGun() ~= nil
 local maximum = math.max(0.1, player:GetAttribute("MDSprintMax") or 10)
 local stamina = math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 local sprinting = player:GetAttribute("MDSprinting") == true
 caption(main.MobileSprint, (sprinting and "SPRINTING" or "SPRINT") .. string.format("\n%.1f/%gs",stamina,maximum))
 caption(main.DesktopControls.Sprint, sprinting and "SPRINTING" or UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and "SPRINT · HOLD L3" or "SPRINT · HOLD SHIFT")
 main.DesktopControls.InputHint.Text = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and "R2 · FIRE   L3 · SPRINT" or "CLICK · FIRE   SHIFT · SPRINT"
 main.DesktopControls.Meter.Charge.Text = now < messageUntil and message or string.format("SPRINT %.1fs / %gs",stamina,maximum)
 progress(main.DesktopControls.Meter.Track,stamina/maximum)
 main.Results.Visible = phase == "Results"
 if phase == "Results" then
  local won = player:GetAttribute("MDResult") == "Won"
  local reason = state:GetAttribute("ResultReason")
  main.Results.Title.Text = won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  main.Results.Reason.Text = reason == "TimeoutShared" and "TIME'S UP · TEAMS TIED"
   or reason == "Timeout" and "MOST PLAYERS LEFT · HEARTS BREAK TIES"
   or reason == "NoActiveTeams" and "BOTH TEAMS ARE OUT" or "LAST TEAM STANDING"
  main.Results.Rewards.Text = state:GetAttribute("LastResultPractice") == true and "PRACTICE ROUND"
   or (won and "+150 COINS" or "+50 COINS") .. " · +50 XP"
 end
 if not inputAllowed() then if sprintHeld or next(fireInputs) then release() end else sprintChange() end
end

local function sprintInput(input)
 if inputAllowed() and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
  sprintTouch = input
  sprintChange()
 end
end
connect(main.MobileSprint.InputBegan, sprintInput)
connect(main.DesktopControls.Sprint.InputBegan, sprintInput)
local function shootInput(input)
 if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then beginFire(input) end
end
connect(main.Controls.Fire.InputBegan, shootInput)
connect(UserInputService.InputBegan, function(input, processed)
 if not processed and inputMode() == "Mouse" and input.UserInputType == Enum.UserInputType.MouseButton1 then beginFire(input) end
end)
local function endInput(input)
 if input == sprintTouch then sprintTouch = nil end
 fireInputs[input] = nil
 if input.KeyCode ~= Enum.KeyCode.Unknown then
  fireInputs[input.KeyCode] = nil
  sprintKeys[input.KeyCode] = nil
 end
 if not next(fireInputs) then
  fireTool = nil
  pending.Fire = nil
 end
 sprintChange()
end
connect(UserInputService.InputEnded, endInput)
connect(UserInputService.InputChanged, function(input)
 if input.UserInputState == Enum.UserInputState.Cancel then endInput(input) end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false release() end)
connect(UserInputService.WindowFocused, function() focused = true end)
connect(UserInputService.TextBoxFocused, release)
connect(GuiService:GetPropertyChangedSignal("MenuIsOpen"), function() if GuiService.MenuIsOpen then release() end end)
local function inputModeChanged()
 local mode = inputMode()
 if currentInputMode ~= mode then release() end
 currentInputMode = mode
 refresh()
end
currentInputMode = inputMode()
connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), inputModeChanged)
connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), inputModeChanged)
connect(player.CharacterAdded, bindCharacter)
connect(player.CharacterRemoving, function() bindCharacter(nil) end)
connect(RunService.Heartbeat, function(delta)
 elapsed += delta
 if player.Character ~= character then bindCharacter(player.Character) end
 if elapsed >= 0.05 then elapsed = 0 refresh() end
 if sprintHeld and os.clock() - lastSprint >= 0.3 then lastSprint = os.clock() request("Sprint", true, true) end
end)
RunService:BindToRenderStep("LaserTagAim", Enum.RenderPriority.Camera.Value+1, function()
 local camera = workspace.CurrentCamera
 if camera and main.Crosshair.Visible then
  local point = aimPoint(camera)
  main.Crosshair.Position = UDim2.fromScale(point.X/camera.ViewportSize.X,point.Y/camera.ViewportSize.Y)
 end
 if next(fireInputs) then
  if not inputAllowed() or fireTool and equippedGun() ~= fireTool then releaseFire() else fireWeapon() end
 end
end)
connect(script.Destroying, function()
 release()
 alive = false
 table.clear(pending)
 RunService:UnbindFromRenderStep("LaserTagAim")
 if bound then ContextActionService:UnbindAction("LaserTagSprint") ContextActionService:UnbindAction("LaserTagFire") end
 for _, connection in ipairs(connections) do connection:Disconnect() end
 for _, connection in ipairs(characterConnections) do connection:Disconnect() end
end)
bindCharacter(player.Character)
refresh()


]====],"Controller changed")
s.Source=[====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local player, gui = Players.LocalPlayer, script.Parent
local main = gui:WaitForChild("Main")
local state = ReplicatedStorage:WaitForChild("MudState")
local remote = ReplicatedStorage:WaitForChild("MudActionRequest")
local headers = { main.Top, main.CompactTop, main.PortraitTop }
local connections, characterConnections = {}, {}
local imageFallbacks = {}
local focused, alive, bound = true, true, false
local character, fireTool
local sprintKeys, fireInputs = {}, {}
local sprintTouch, sprintHeld
local currentInputMode
local lastSprint, nextShotAt, elapsed = 0, 0, 0
local sending, pending = {}, {}
local message, messageUntil = "", 0
main.Visible = false

local function connect(signal, callback, list)
 local connection = signal:Connect(callback)
 table.insert(list or connections, connection)
 return connection
end

local function bindImageFallback(fallback, skin)
 if not skin then return end
 local function refreshFallback()
  local visible = skin.Image == "" or not skin.IsLoaded
  if fallback.Visible ~= visible then fallback.Visible = visible end
 end
 connect(skin:GetPropertyChangedSignal("IsLoaded"), refreshFallback)
 connect(skin:GetPropertyChangedSignal("Image"), refreshFallback)
 table.insert(imageFallbacks, refreshFallback)
 refreshFallback()
end

for _, descendant in ipairs(main:GetDescendants()) do
 if descendant.Name == "ArtFallback" and descendant:IsA("Frame") then
  bindImageFallback(descendant, descendant.Parent:FindFirstChild("ReusableSkin"))
 end
end

local function caption(button, value)
 button.Text = value
 local live = button:FindFirstChild("LiveCaption")
 if live then live.Text = value end
end

local function playing()
 return player:GetAttribute("MDParticipating") == true and state:GetAttribute("Phase") == "Playing"
  and player:GetAttribute("MDEliminated") ~= true and (player:GetAttribute("MDLives") or 3) > 0
end

local function sessionControls()
 return player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
end

local function modalOpen()
 local session = sessionControls()
 if session and (session:GetAttribute("SessionMenuOpen") == true or session:GetAttribute("Spectating") == true) then return true end
 for name, panels in pairs({PlaygroundShell={"ShopPanel","VotePanel","CompactVotePanel"},PlaygroundAdminPanel={"AdminHub"},PlaygroundEmoteWheel={"Panel"}}) do
  local screen = player.PlayerGui:FindFirstChild(name)
  if screen and screen.Enabled then
   for _, name in ipairs(panels) do
    local panel = screen:FindFirstChild(name)
    if panel and panel.Visible then return true end
   end
  end
 end
 return GuiService.MenuIsOpen
end

local function inputAllowed()
 return alive and focused and gui.Enabled and playing() and not UserInputService:GetFocusedTextBox() and not modalOpen()
end

local function request(action, value, quiet)
 pending[action] = { value = value, quiet = quiet }
 if sending[action] then return end
 sending[action] = true
 task.spawn(function()
  while alive and pending[action] do
   local nextRequest = pending[action]
   pending[action] = nil
   local ok, result = pcall(remote.InvokeServer, remote, action, nextRequest.value)
   if not nextRequest.quiet and (not ok or typeof(result) == "table" and result.ok == false) then
    message = ok and tostring(result.message or "Try again.") or "Try again."
    messageUntil = workspace:GetServerTimeNow() + 1.4
   end
  end
  sending[action] = nil
 end)
end

local function releaseFire()
 table.clear(fireInputs)
 fireTool = nil
 pending.Fire = nil
end

local function release()
 table.clear(sprintKeys)
 sprintTouch, sprintHeld = nil, false
 releaseFire()
 request("Sprint", false, true)
end

local function sprintChange()
 local held = inputAllowed() and (next(sprintKeys) ~= nil or sprintTouch ~= nil)
 if held ~= sprintHeld then
  sprintHeld, lastSprint = held, os.clock()
  request("Sprint", held, true)
 end
end

local function selectedHeader(viewport)
 if viewport.Y > viewport.X then return main.PortraitTop end
 if viewport.X < 1000 or viewport.Y <= 600 then return main.CompactTop end
 return main.Top
end

local function viewportAim(viewport, mousePosition, deviceOrigin, cursorAim)
 local point = cursorAim and mousePosition - deviceOrigin or viewport * 0.5
 return Vector2.new(math.clamp(point.X, 0, viewport.X), math.clamp(point.Y, 0, viewport.Y))
end

local function inputMode()
 if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then return "Gamepad" end
 if UserInputService.TouchEnabled then return "Touch" end
 return "Mouse"
end

local function aimPoint(camera)
 local cursorAim = inputMode() == "Mouse"
  and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
 if not cursorAim then
  local forward = camera.CFrame.Position + camera.CFrame.LookVector * 100
  local projected = camera:WorldToViewportPoint(forward)
  return Vector2.new(projected.X, projected.Y)
 end
 local deviceArea = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
 local screenArea = GuiService:GetInsetArea(Enum.ScreenInsets.None)
 return viewportAim(camera.ViewportSize, UserInputService:GetMouseLocation(), deviceArea.Min - screenArea.Min, cursorAim)
end

local function aimRay()
 local camera = workspace.CurrentCamera
 if not camera then return nil end
 local point = aimPoint(camera)
 local ray = camera:ViewportPointToRay(point.X, point.Y)
 return { cameraOrigin = ray.Origin, cameraDirection = ray.Direction }
end

local function assignedGun(tool)
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 return tool and tool:IsA("Tool") and tool.Name == expected and tool:GetAttribute("MDManaged") == true
  and tool:GetAttribute("MDOwnerUserId") == player.UserId and tool:GetAttribute("MDRound") == state:GetAttribute("RoundNumber")
  and tool:GetAttribute("MDTeamId") == player:GetAttribute("MDTeamId") and tool.Enabled and tool or nil
end

local function equippedGun()
 local current = player.Character
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 return assignedGun(current and current:FindFirstChild(expected))
end

local function equipAssignedGun()
 local equipped = equippedGun()
 if equipped or not inputAllowed() then return equipped end
 local current = player.Character
 local humanoid = current and current:FindFirstChildOfClass("Humanoid")
 local backpack = player:FindFirstChildOfClass("Backpack")
 local expected = player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun"
 local tool = assignedGun(backpack and backpack:FindFirstChild(expected))
 if tool and humanoid and humanoid.Health > 0 then pcall(humanoid.EquipTool, humanoid, tool) end
 return equippedGun()
end

local function fireWeapon()
 if not inputAllowed() then return end
 local tool = equippedGun()
 if not tool or fireTool and tool ~= fireTool then return end
 local now = workspace:GetServerTimeNow()
 if now < math.max(nextShotAt, player:GetAttribute("MDFireReadyAt") or 0) then return end
 local ray = aimRay()
 if not ray then return end
 fireTool = tool
 nextShotAt = now + (state:GetAttribute("LaserCooldownSeconds") or state:GetAttribute("MudCooldownSeconds") or 0.65) + 0.02
 request("Fire", ray, true)
end

local function beginFire(input)
 if not inputAllowed() then return end
 fireInputs[input] = true
 local tool = equipAssignedGun()
 if not tool then
  request("Equip", player:GetAttribute("MDTeamId") == 1 and "HeatGun" or "MudGun", true)
 end
 fireWeapon()
end

local function keyAction(_, phase, input)
 if not player:GetAttribute("MDParticipating") or player:GetAttribute("MDEliminated") then return Enum.ContextActionResult.Pass end
 if phase == Enum.UserInputState.End or phase == Enum.UserInputState.Cancel then
  sprintKeys[input.KeyCode] = nil
 elseif phase == Enum.UserInputState.Begin and inputAllowed() then
  sprintKeys[input.KeyCode] = true
 end
 sprintChange()
 return Enum.ContextActionResult.Sink
end

local function triggerAction(_, phase, input)
 if not player:GetAttribute("MDParticipating") or player:GetAttribute("MDEliminated") then return Enum.ContextActionResult.Pass end
 if phase == Enum.UserInputState.Begin then beginFire(input.KeyCode)
 elseif phase == Enum.UserInputState.End or phase == Enum.UserInputState.Cancel then
  fireInputs[input.KeyCode] = nil
  if not next(fireInputs) then fireTool = nil end
 end
 return Enum.ContextActionResult.Sink
end

local function progress(track, fraction)
 fraction = math.clamp(fraction, 0, 1)
 local gradient = track.Fill.Progress
 if fraction <= 0 then gradient.Transparency = NumberSequence.new(1)
 elseif fraction >= 1 then gradient.Transparency = NumberSequence.new(0)
 else
  local edge = math.clamp(fraction, 0.001, 0.999)
  gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(edge-0.0001,0),
   NumberSequenceKeypoint.new(edge+0.0001,1), NumberSequenceKeypoint.new(1,1)})
 end
end

local function bindCharacter(nextCharacter)
 if nextCharacter == character then return end
 release()
 character, nextShotAt = nextCharacter, 0
 for _, connection in ipairs(characterConnections) do connection:Disconnect() end
 table.clear(characterConnections)
 if character then
  connect(character.ChildRemoved, function(child) if child == fireTool then releaseFire() end end, characterConnections)
 end
end

local function refresh()
 for _, refreshFallback in ipairs(imageFallbacks) do refreshFallback() end
 local phase = state:GetAttribute("Phase")
 local participating = player:GetAttribute("MDParticipating") == true
 local active = participating and (phase == "Countdown" or phase == "Playing" or phase == "Results")
 local touch = inputMode() == "Touch"
 if participating and not bound then
  ContextActionService:BindActionAtPriority("LaserTagSprint", keyAction, false, 3000, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
  ContextActionService:BindActionAtPriority("LaserTagFire", triggerAction, false, 3000, Enum.KeyCode.ButtonR2)
  bound = true
 elseif not participating and bound then
  ContextActionService:UnbindAction("LaserTagSprint")
  ContextActionService:UnbindAction("LaserTagFire")
  bound = false
  release()
 end
 main.Visible = active
 if not active then return end
 local camera = workspace.CurrentCamera
 local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
 local selected = selectedHeader(viewport)
 local now = workspace:GetServerTimeNow()
 local duration = phase == "Countdown" and (state:GetAttribute("RoundDuration") or 300) or math.max(0,(state:GetAttribute("EndsAt") or 0)-now)
 local seconds = math.ceil(duration)
 local out = player:GetAttribute("MDEliminated") == true
 local lives = math.clamp(player:GetAttribute("MDLives") or 3, 0, 3)
 local session = sessionControls()
 local hidden = session and session:GetAttribute("UIHidden") == true
 local modal = modalOpen()
 for _, header in ipairs(headers) do
  header.Visible = header == selected and phase ~= "Results" and not hidden and not modal
  header.Timer.Text = string.format("%d:%02d", math.floor(seconds/60), seconds%60)
  caption(header.Team, "RED\n" .. tostring(state:GetAttribute("RedAlive") or 0) .. " ALIVE")
  header.Other.Text = "BLUE\n" .. tostring(state:GetAttribute("BlueAlive") or 0) .. " ALIVE"
  header.Lives.Visible = not out
  header.Out.Visible = out
  header.Lives.Team.Text = player:GetAttribute("MDTeamId") == 1 and "RED" or "BLUE"
  for index = 1, 3 do header.Lives["Heart"..index].TextColor3 = index <= lives and Color3.fromRGB(255,82,105) or Color3.fromRGB(99,108,126) end
 end
 main.Countdown.Visible = phase == "Countdown" and not out
 main.Countdown.Text = tostring(state:GetAttribute("CountdownValue") or 3)
 local showControls = phase == "Playing" and not out and not modal
 main.Controls.Visible = showControls and touch
 main.DesktopControls.Visible = showControls and not touch
 main.MobileSprint.Visible = showControls and touch
 main.Crosshair.Visible = inputAllowed() and equippedGun() ~= nil
 local maximum = math.max(0.1, player:GetAttribute("MDSprintMax") or 10)
 local stamina = math.clamp(player:GetAttribute("MDSprintRemaining") or maximum,0,maximum)
 local sprinting = player:GetAttribute("MDSprinting") == true
 caption(main.MobileSprint, (sprinting and "SPRINTING" or "SPRINT") .. string.format("\n%.1f/%gs",stamina,maximum))
 caption(main.DesktopControls.Sprint, sprinting and "SPRINTING" or UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and "SPRINT · HOLD L3" or "SPRINT · HOLD SHIFT")
 main.DesktopControls.InputHint.Text = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and "R2 · FIRE   L3 · SPRINT" or "CLICK · FIRE   SHIFT · SPRINT"
 main.DesktopControls.Meter.Charge.Text = now < messageUntil and message or string.format("SPRINT %.1fs / %gs",stamina,maximum)
 progress(main.DesktopControls.Meter.Track,stamina/maximum)
 main.Results.Visible = phase == "Results"
 if phase == "Results" then
  local won = player:GetAttribute("MDResult") == "Won"
  local reason = state:GetAttribute("ResultReason")
  main.Results.Title.Text = won and "YOUR TEAM WINS!" or "ROUND FINISHED!"
  main.Results.Reason.Text = reason == "TimeoutShared" and "TIME'S UP · TEAMS TIED"
   or reason == "Timeout" and "MOST PLAYERS LEFT · HEARTS BREAK TIES"
   or reason == "NoActiveTeams" and "BOTH TEAMS ARE OUT" or "LAST TEAM STANDING"
  main.Results.Rewards.Text = state:GetAttribute("LastResultPractice") == true and "PRACTICE ROUND"
   or (won and "+150 COINS" or "+50 COINS") .. " · +50 XP"
 end
 if not inputAllowed() then if sprintHeld or next(fireInputs) then release() end else sprintChange() end
end

local function sprintInput(input)
 if inputAllowed() and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
  sprintTouch = input
  sprintChange()
 end
end
connect(main.MobileSprint.InputBegan, sprintInput)
connect(main.DesktopControls.Sprint.InputBegan, sprintInput)
local function shootInput(input)
 if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then beginFire(input) end
end
connect(main.Controls.Fire.InputBegan, shootInput)
connect(UserInputService.InputBegan, function(input, processed)
 if not processed and inputMode() == "Mouse" and input.UserInputType == Enum.UserInputType.MouseButton1 then beginFire(input) end
end)
local function endInput(input)
 if input == sprintTouch then sprintTouch = nil end
 fireInputs[input] = nil
 if input.KeyCode ~= Enum.KeyCode.Unknown then
  fireInputs[input.KeyCode] = nil
  sprintKeys[input.KeyCode] = nil
 end
 if not next(fireInputs) then
  fireTool = nil
  pending.Fire = nil
 end
 sprintChange()
end
connect(UserInputService.InputEnded, endInput)
connect(UserInputService.InputChanged, function(input)
 if input.UserInputState == Enum.UserInputState.Cancel then endInput(input) end
end)
connect(UserInputService.WindowFocusReleased, function() focused = false release() end)
connect(UserInputService.WindowFocused, function() focused = true end)
connect(UserInputService.TextBoxFocused, release)
connect(GuiService:GetPropertyChangedSignal("MenuIsOpen"), function() if GuiService.MenuIsOpen then release() end end)
local function inputModeChanged()
 local mode = inputMode()
 if currentInputMode ~= mode then release() end
 currentInputMode = mode
 refresh()
end
currentInputMode = inputMode()
connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), inputModeChanged)
connect(UserInputService:GetPropertyChangedSignal("TouchEnabled"), inputModeChanged)
connect(player.CharacterAdded, bindCharacter)
connect(player.CharacterRemoving, function() bindCharacter(nil) end)
connect(RunService.Heartbeat, function(delta)
 elapsed += delta
 if player.Character ~= character then bindCharacter(player.Character) end
 if elapsed >= 0.05 then elapsed = 0 refresh() end
 if sprintHeld and os.clock() - lastSprint >= 0.3 then lastSprint = os.clock() request("Sprint", true, true) end
end)
RunService:BindToRenderStep("LaserTagAim", Enum.RenderPriority.Camera.Value+1, function()
 local camera = workspace.CurrentCamera
 if camera and main.Crosshair.Visible then
  local point = aimPoint(camera)
  main.Crosshair.Position = UDim2.fromScale(point.X/camera.ViewportSize.X,point.Y/camera.ViewportSize.Y)
 end
 if next(fireInputs) then
  if not inputAllowed() or fireTool and equippedGun() ~= fireTool then releaseFire() else fireWeapon() end
 end
end)
connect(script.Destroying, function()
 release()
 alive = false
 table.clear(imageFallbacks)
 table.clear(pending)
 RunService:UnbindFromRenderStep("LaserTagAim")
 if bound then ContextActionService:UnbindAction("LaserTagSprint") ContextActionService:UnbindAction("LaserTagFire") end
 for _, connection in ipairs(connections) do connection:Disconnect() end
 for _, connection in ipairs(characterConnections) do connection:Disconnect() end
end)
bindCharacter(player.Character)
refresh()


]====]
return {installed=true}
