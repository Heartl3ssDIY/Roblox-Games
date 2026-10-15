local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local config = require(ReplicatedStorage:WaitForChild("RunnerConfig"))
if game.PlaceId ~= config.PlaceId then return end

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("RunnerEvent")
-- Camera settings replicate independently of the distant, streamed-out marker.
local camera = workspace.CurrentCamera
local startX = -506.8
local courseCenterY = 23
local courseCenterZ = -9.5
local cameraTarget = player
local spectateIndex = 0
local phase = "Waiting"
local cameraCourseVersion
local finishDeadline

local function create(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for property, value in properties do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local gui = create("ScreenGui", "RunnerUI", player:WaitForChild("PlayerGui"), {
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 20,
})

local readyButton = create("TextButton", "TemporaryReadyButton", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.94),
	Size = UDim2.fromOffset(260, 64),
	BackgroundColor3 = Color3.fromRGB(45, 192, 222),
	BorderSizePixel = 0,
	Font = Enum.Font.Arcade,
	Text = "READY",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 30,
	Visible = false,
})
create("UICorner", "Corner", readyButton, { CornerRadius = UDim.new(0, 10) })

local countdown = create("TextLabel", "Countdown", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(320, 160),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0,
})

local hint = create("TextLabel", "FlipHint", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.995),
	Size = UDim2.fromOffset(450, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "SPACE: FLIP GRAVITY",
	TextColor3 = Color3.fromRGB(220, 250, 255),
	TextSize = 18,
	TextStrokeTransparency = 0.25,
	Visible = false,
})

local lifeStatus = create("TextLabel", "SecondLifeStatus", gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 70),
	Size = UDim2.fromOffset(250, 38),
	BackgroundColor3 = Color3.fromRGB(15, 38, 48),
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Font = Enum.Font.Arcade,
	Text = "SECOND LIFE READY",
	TextColor3 = Color3.fromRGB(175, 245, 255),
	TextSize = 17,
	Visible = false,
})
create("UICorner", "Corner", lifeStatus, { CornerRadius = UDim.new(0, 8) })
local function updateSecondLifeStatus()
	lifeStatus.Visible = player:GetAttribute("RunnerStatus") == "Running"
		and player:GetAttribute(config.SecondLifeAttribute) == 1
end
player:GetAttributeChangedSignal(config.SecondLifeAttribute):Connect(updateSecondLifeStatus)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(updateSecondLifeStatus)
updateSecondLifeStatus()

local flash = create("Frame", "RecoveryFlash", gui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 30, 30),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 20,
})

local spectate = create("Frame", "Spectate", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.96),
	Size = UDim2.fromOffset(420, 62),
	BackgroundColor3 = Color3.fromRGB(20, 28, 38),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Visible = false,
})
create("UICorner", "Corner", spectate, { CornerRadius = UDim.new(0, 10) })
local previous = create("TextButton", "Previous", spectate, {
	Size = UDim2.fromOffset(62, 62),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "<",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 34,
})
local spectateName = create("TextLabel", "PlayerName", spectate, {
	Position = UDim2.fromOffset(62, 0),
	Size = UDim2.new(1, -124, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = "SPECTATING",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
})
local nextButton = create("TextButton", "Next", spectate, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(62, 62),
	BackgroundTransparency = 1,
	Font = Enum.Font.Arcade,
	Text = ">",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 34,
})

local function getControls()
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then return end
	local ok, result = pcall(require, module)
	if ok then return result:GetControls() end
end

ContextActionService:BindActionAtPriority("RunnerBlockMovement", function()
	return Enum.ContextActionResult.Sink
end, false, 3000, table.unpack(Enum.PlayerActions:GetEnumItems()))

task.spawn(function()
	local controls
	repeat
		controls = getControls()
		if not controls then task.wait(0.2) end
	until controls
	controls:Disable()
end)

local function canFlip()
	local status = player:GetAttribute("RunnerStatus")
	return status == "Waiting" or status == "Running"
end

local landingRay = RaycastParams.new()
landingRay.FilterType = Enum.RaycastFilterType.Exclude
landingRay.RespectCanCollide = true

local GroundCheck=require(ReplicatedStorage:WaitForChild("RunnerGroundCheck"))
local SoundService=game:GetService("SoundService")
local whoosh=SoundService:WaitForChild("RunnerAirWhoosh")
local landing=SoundService:WaitForChild("RunnerLandingImpact")
local soundArmed=false
local soundAirSince
local soundMuteUntil=0
local function resetMovementSounds()
 soundArmed=false
 soundAirSince=nil
 soundMuteUntil=os.clock()+.4
 whoosh:Stop()
 landing:Stop()
end
local function playLaunchSound()
 soundArmed=true
 soundAirSince=os.clock()
 whoosh:Stop()
 whoosh:Play()
end
local function updateLandingSound(character,root,sign)
 local now=os.clock()
 if now<soundMuteUntil then return end
 local supported=GroundCheck.Support(character,root.Position,sign)~=nil
 if supported then
  if soundArmed and soundAirSince and now-soundAirSince>=.1 and root.AssemblyLinearVelocity.Y*sign<=2 then
   landing:Stop()
   landing:Play()
  end
  soundArmed=true
  soundAirSince=nil
 elseif soundArmed then
  soundAirSince=soundAirSince or now
 end
end
player.CharacterAdded:Connect(resetMovementSounds)
player:GetAttributeChangedSignal("RunnerCourseVersion"):Connect(resetMovementSounds)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(resetMovementSounds)
task.spawn(function()
 pcall(function() game:GetService("ContentProvider"):PreloadAsync({whoosh,landing}) end)
end)

local Motion=require(ReplicatedStorage.RunnerMotion)
local Somersault=require(ReplicatedStorage.RunnerSomersault)
local forwardBonus=0
local airborneLaunch=false
local lastGroundTime=-math.huge
local lastGroundPosition
local lastSupport
local lastGroundSign
local graceConsumed=false
local predictedSign
local flipPending = false
local flipRequestId=0
local pendingRequestId
local lastLocalFlip = -math.huge
local lastForcedAbilityRevision=0
local function currentSign()
	return predictedSign or player:GetAttribute("GravitySign") or 1
end

local function resetMotion()
 flipPending=false pendingRequestId=nil predictedSign=nil lastLocalFlip=-math.huge
 forwardBonus=0 airborneLaunch=false
 lastGroundTime=-math.huge lastGroundPosition=nil lastSupport=nil lastGroundSign=nil
 graceConsumed=false
 Somersault.Reset(player.Character)
end
local function rememberGround(root)
 if os.clock()-lastLocalFlip<.12 then return nil end
 local sign=currentSign()
 local support=GroundCheck.Support(player.Character,root.Position,sign)
 if support and root.AssemblyLinearVelocity.Y*sign<=2 then
  lastGroundTime=workspace:GetServerTimeNow()
  lastGroundPosition=root.Position lastSupport=support lastGroundSign=sign
  graceConsumed=false
  return support
 end
end
player.CharacterAdded:Connect(resetMotion)
player:GetAttributeChangedSignal("RunnerCourseVersion"):Connect(resetMotion)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(function()
 if player:GetAttribute("RunnerStatus")~="Running" then resetMotion() end
end)

player:GetAttributeChangedSignal("GravitySign"):Connect(function()
	if not flipPending then predictedSign = player:GetAttribute("GravitySign") end
end)
player:GetAttributeChangedSignal("RunnerCourseVersion"):Connect(function()
	flipPending = false
	predictedSign = player:GetAttribute("GravitySign")
	lastLocalFlip = -math.huge
end)
local function predictFlip(root)
 local oldSign=currentSign()
 local newSign=-oldSign
 predictedSign=newSign flipPending=true lastLocalFlip=os.clock()
 graceConsumed=true
 forwardBonus=config.FlipForwardBonus
 airborneLaunch=true
 Somersault.Play(player.Character,oldSign,newSign)
 root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(-1,0,0),Vector3.new(0,newSign,0))
 local running=player:GetAttribute("RunnerStatus")=="Running"
 local multiplier=player:GetAttribute("RunnerSpeedMultiplier") or 1
 local speed=running and Motion.Forward(player:GetAttribute("RunnerRaceStartedAt"),multiplier,forwardBonus) or 0
 root.AssemblyLinearVelocity=Vector3.new(-speed,-newSign*config.FlipVelocity,0)
end

local function stopLandingBounce(root)
	local character = player.Character
	if not character then return end
	landingRay.FilterDescendantsInstances = { character }

	local sign = currentSign()
	local velocity = root.AssemblyLinearVelocity
	if os.clock() - lastLocalFlip < 0.12 or math.abs(velocity.Y) > 12 then return end

	local hit = workspace:Raycast(
		root.Position,
		Vector3.new(0, -sign * 3.3, 0),
		landingRay
	)
	if hit and hit.Distance <= 3.08 and hit.Normal:Dot(Vector3.new(0, sign, 0)) > 0.9 then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, 0)
	end
end

local function flipAction(_, inputState)
 if inputState==Enum.UserInputState.Begin and canFlip() then
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  if root and not root.Anchored and not flipPending and os.clock()-lastLocalFlip>=config.FlipCooldown then
   rememberGround(root)
   local now=workspace:GetServerTimeNow()
   local grace=not graceConsumed and lastSupport and lastSupport.Parent and lastGroundSign==currentSign()
    and now-lastGroundTime<=config.EdgeGraceSeconds
   if not grace then return Enum.ContextActionResult.Sink end
   local takeoff=root.Position
   local support,groundPosition,groundTime=lastSupport,lastGroundPosition,lastGroundTime
   predictFlip(root)
   playLaunchSound()
   flipRequestId+=1
   local requestId=flipRequestId
   pendingRequestId=requestId
   event:FireServer("Flip",predictedSign,takeoff,support,groundPosition,groundTime,requestId,player:GetAttribute("RunnerRecoveryRevision") or 0,player:GetAttribute("RunnerAbilityRevision") or 0)
   task.delay(1.5,function()
    if pendingRequestId==requestId then resetMotion() end
   end)
  end
 end
 return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("RunnerFlipGravity", flipAction, false, 4000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
local touchEnabled = game:GetService("UserInputService").TouchEnabled
local flipButton = create("TextButton", "MobileGravityFlip", gui, {
 AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-24,1,-86),
 Size=UDim2.fromOffset(112,112), BackgroundColor3=Color3.fromRGB(0,128,151),
 Font=Enum.Font.Arcade, Text="FLIP", TextSize=22, TextColor3=Color3.new(1,1,1),
 Visible=touchEnabled and canFlip(), ZIndex=10,
})
create("UICorner","Corner",flipButton,{CornerRadius=UDim.new(1,0)})
create("UIAspectRatioConstraint","Aspect",flipButton,{AspectRatio=1})
flipButton.Activated:Connect(function() flipAction(nil,Enum.UserInputState.Begin) end)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(function()
 flipButton.Visible=touchEnabled and canFlip()
end)
player.CharacterAdded:Connect(function()
 flipPending=false
 predictedSign=nil
 lastLocalFlip=-math.huge
end)


local function runnersToWatch()
	local result = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("RunnerStatus") == "Running" then
			table.insert(result, other)
		end
	end
	table.sort(result, function(first, second)
		return first.UserId < second.UserId
	end)
	return result
end

local function chooseSpectatorTarget(direction)
	local runners = runnersToWatch()
	if #runners == 0 then
		cameraTarget = player
		spectateName.Text = "WAITING FOR NEXT ROUND"
		return
	end
	spectateIndex = (spectateIndex - 1 + direction) % #runners + 1
	cameraTarget = runners[spectateIndex]
	spectateName.Text = cameraTarget.DisplayName
end

previous.Activated:Connect(function() chooseSpectatorTarget(-1) end)
nextButton.Activated:Connect(function() chooseSpectatorTarget(1) end)

ContextActionService:BindActionAtPriority("RunnerSpectate", function(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin or not spectate.Visible then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.DPadLeft then
		chooseSpectatorTarget(-1)
	else
		chooseSpectatorTarget(1)
	end
	return Enum.ContextActionResult.Sink
end, false, 4000, Enum.KeyCode.Q, Enum.KeyCode.E,
	Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)

readyButton.Activated:Connect(function()
	if phase == "Waiting" then event:FireServer("Ready") end
end)

local function updateReadyButton()
	local status = player:GetAttribute("RunnerStatus")
	local isReady = player:GetAttribute("RunnerReady")
	readyButton.Visible = phase == "Waiting" and status == "Waiting"
		and not player:GetAttribute("RunnerAutoReady")
	readyButton.Text = isReady and "CANCEL READY" or "READY"
	readyButton.BackgroundColor3 = isReady
		and Color3.fromRGB(88, 210, 118)
		or Color3.fromRGB(45, 192, 222)
	hint.Visible = status == "Waiting" or status == "Running"
end

player:GetAttributeChangedSignal("RunnerReady"):Connect(updateReadyButton)
player:GetAttributeChangedSignal("RunnerStatus"):Connect(updateReadyButton)
player:GetAttributeChangedSignal("GBloxCourseReady"):Connect(updateReadyButton)

RunService.PreSimulation:Connect(function(deltaTime)
	local status = player:GetAttribute("RunnerStatus")
	if status ~= "Waiting" and status ~= "Running" then return end
	local laneZ = player:GetAttribute("RunnerLaneZ")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not laneZ or not root or root.Anchored then return end

	local sign = currentSign()
 local support=rememberGround(root)
 if support and os.clock()-lastLocalFlip>.12 then airborneLaunch=false end
 if not airborneLaunch then forwardBonus*=math.exp(-deltaTime/0.12) end
 local speed=root:FindFirstChild("RunnerForwardSpeed")
 if speed and status=="Running" then
  speed.LineVelocity=Motion.Forward(player:GetAttribute("RunnerRaceStartedAt"),player:GetAttribute("RunnerSpeedMultiplier") or 1,forwardBonus)
 end
 local gravity = root:FindFirstChild("RunnerGravity")
	local orientation = root:FindFirstChild("RunnerOrientation")
	if gravity then gravity.Force = Vector3.new(0, root.AssemblyMass * (workspace.Gravity - sign * config.Gravity), 0) end
	if orientation then orientation.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(-1,0,0), Vector3.new(0,sign,0)).Rotation end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y, 0)
	updateLandingSound(character,root,sign)
	stopLandingBounce(root)
	local difference = laneZ - root.Position.Z
	if math.abs(difference) > 0.01 then
		root.CFrame += Vector3.new(0, 0, difference)
	end
end)

event.OnClientEvent:Connect(function(action, data)
	data = data or {}
	if action=="AbilityFlip" then
  if data.character~=player.Character or typeof(data.revision)~="number" or data.revision<=lastForcedAbilityRevision or data.courseVersion~=player:GetAttribute("RunnerCourseVersion") then return end
  lastForcedAbilityRevision=data.revision
  resetMotion()
  flipPending=false predictedSign=data.sign lastLocalFlip=-math.huge
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and not root.Anchored then
   root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(-1,0,0),Vector3.new(0,data.sign,0))
   local v=root.AssemblyLinearVelocity
   root.AssemblyLinearVelocity=Vector3.new(v.X,-data.sign*config.FlipVelocity,0)
  end
 elseif action == "FlipAck" then
  if (data.abilityRevision or 0)<math.max(lastForcedAbilityRevision,player:GetAttribute("RunnerAbilityRevision") or 0) then return end
		if data.requestId~=pendingRequestId or data.courseVersion~=player:GetAttribute("RunnerCourseVersion")
			or data.recoveryRevision~=(player:GetAttribute("RunnerRecoveryRevision") or 0) then return end
		flipPending = false pendingRequestId=nil
        if data.accepted==false then
         resetMotion()
         local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
         if root and data.sign then
          root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(-1,0,0),Vector3.new(0,data.sign,0))
         end
        end
		predictedSign = data.sign
	elseif action == "State" then
		phase = data.phase or phase
		finishDeadline = data.finishDeadline
		if phase == "Waiting" then
			countdown.Text = ""
			spectate.Visible = false
			cameraTarget = player
		elseif phase == "Countdown" then
			countdown.Text = tostring(data.number or "")
			readyButton.Visible = false
		elseif phase == "Running" then
			countdown.Text = ""
			readyButton.Visible = false
		elseif phase == "Intermission" or phase == "AwaitingCourse" or phase == "MatchComplete" then
			countdown.Text = data.message or ("ROUND " .. tostring(data.courseNumber) .. " COMPLETE")
			readyButton.Visible = false
			spectate.Visible = false
			cameraTarget = player
		end
		updateReadyButton()
	elseif action == "ReadyChanged" then
		updateReadyButton()
	elseif action == "Recover" then
		if data.courseVersion and data.courseVersion~=player:GetAttribute("RunnerCourseVersion") then return end
		if data.usedSecondLife then
			hint.Text = "SECOND LIFE USED!"
			task.delay(2, function() hint.Text = "SPACE: FLIP GRAVITY" end)
		end
        resetMotion()
        resetMovementSounds()
		flipPending=false
		predictedSign=data.sign
		lastLocalFlip=-math.huge
		flash.BackgroundTransparency = 0.45
		TweenService:Create(flash, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		}):Play()
	elseif action == "SecondLife" then
		hint.Text = "SECOND LIFE READY!"
		task.delay(2, function()
			hint.Text = "SPACE: FLIP GRAVITY"
		end)
	elseif action == "Boost" then
		hint.Text = "2X SPEED!"
		task.delay(data.seconds or 3, function()
			hint.Text = "SPACE: FLIP GRAVITY"
		end)
	elseif action == "Finished" or action == "Out" then
		countdown.Text = action == "Finished" and "FINISHED!" or "OUT!"
		hint.Visible = false
		spectate.Visible = true
		spectateIndex = 0
		chooseSpectatorTarget(1)
	end
end)

local streamingKey
local function prepareCourse()
	local version = player:GetAttribute("RunnerCourseVersion")
	local revision = player:GetAttribute("RunnerSpawnRevision")
	local position = player:GetAttribute("RunnerSpawnPosition")
	if not version or not revision or typeof(position)~="Vector3"
		or not player:GetAttribute("GBloxCourseReady") then return end
	local key=tostring(version)..":"..tostring(revision)
	if streamingKey==key then return end
	streamingKey=key
	cameraTarget=player
	task.spawn(function()
		local streamed=false
		while player.Parent and player:GetAttribute("RunnerCourseVersion")==version
			and player:GetAttribute("RunnerSpawnRevision")==revision do
			if player:GetAttribute("RunnerStreamReadyRevision")==revision then return end
			if not streamed then
				streamed=not workspace.StreamingEnabled
				if not streamed then
					streamed=pcall(function() player:RequestStreamAroundAsync(position,10) end)
				end
			end
			if player:GetAttribute("RunnerCourseVersion")~=version
				or player:GetAttribute("RunnerSpawnRevision")~=revision then return end
			if streamed then
				-- Retry until acknowledged; a one-shot request can arrive before server setup.
				event:FireServer("CourseReady",version,revision)
			else
				countdown.Text="LOADING COURSE..."
			end
			task.wait(streamed and .5 or 3)
		end
	end)
end
for _,attribute in {"RunnerCourseVersion","RunnerSpawnRevision","RunnerSpawnPosition","GBloxCourseReady"} do
	player:GetAttributeChangedSignal(attribute):Connect(prepareCourse)
end
prepareCourse()

task.spawn(function()
	while not player:GetAttribute("GBloxCourseReady") do task.wait(0.1) end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = config.CameraFieldOfView
	updateReadyButton()
end)

RunService:BindToRenderStep("RunnerCamera", Enum.RenderPriority.Camera.Value + 1,
	function(deltaTime)
		if player:GetAttribute("GBloxPodiumActive") or player:GetAttribute("GBloxPodiumCameraActive") or not player:GetAttribute("GBloxCourseReady") then return end
		local character = cameraTarget and cameraTarget.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local center = player:GetAttribute("RunnerCourseCenter")
			or Vector3.new(startX, courseCenterY, courseCenterZ)
		local cameraOffset = workspace:GetAttribute("RunnerCameraOffset") or Vector3.new(-4.4, 2.53, -94.86)
		local courseCenter = Vector3.new(root.Position.X, center.Y, center.Z)
		local cameraPosition = courseCenter + cameraOffset
		local goal = CFrame.lookAt(cameraPosition, courseCenter)
		local version = player:GetAttribute("RunnerCourseVersion")
		local alpha = 1 - math.exp(-config.CameraFollowSpeed * deltaTime)
		if cameraCourseVersion ~= version then
			cameraCourseVersion = version
			camera.CFrame = goal
		else
			camera.CFrame = camera.CFrame:Lerp(goal, alpha)
		end
		if phase == "Running" and finishDeadline then
			countdown.Text = tostring(math.max(0, math.ceil(finishDeadline - workspace:GetServerTimeNow())))
		end
	end)

player:GetAttributeChangedSignal("GBloxPodiumActive"):Connect(function()
 if player:GetAttribute("GBloxPodiumActive") then
  gui.Enabled=false
  resetMotion()
  resetMovementSounds()
 end
end)

