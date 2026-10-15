local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local exit = game.ReplicatedStorage:WaitForChild("TreadmillExit")
local CHARGE, REWARD_TIME = 10, 5
local active, occupied, cooldown, rewards = {}, {}, {}, {}

-- Imported mesh axes are not upright. Use the console direction for a level belt frame.
local function beltFrame(belt)
 local console = belt.Parent:FindFirstChild(belt.Name:gsub("_Belt$", "_Console"))
 local dir = console and console.Position - belt.Position or belt.Parent:GetPivot().LookVector
 dir = Vector3.new(dir.X, 0, dir.Z)
 if dir.Magnitude < .01 then dir = Vector3.new(0, 0, -1) end
 return CFrame.lookAt(belt.Position, belt.Position + dir.Unit)
end

local function clearReward(player)
 local r = rewards[player]
 if not r then return end
 rewards[player] = nil
 if r.hum.Parent then
  if r.kind == "Speed" then
   r.hum.WalkSpeed = r.speed
  else
   r.hum.JumpPower = r.power
   r.hum.JumpHeight = r.height
  end
 end
 player:SetAttribute("TreadmillBoostKind", nil)
 player:SetAttribute("TreadmillBoostUntil", nil)
end

local function grantReward(player, a)
 clearReward(player)
 local h = a.hum
 local r = {hum=h, character=a.character, kind=a.kind, speed=h.WalkSpeed, power=h.JumpPower, height=h.JumpHeight, expires=workspace:GetServerTimeNow()+REWARD_TIME}
 rewards[player] = r
 if a.kind == "Speed" then
  h.WalkSpeed = r.speed * 5
 else
  -- JumpPower is velocity: sqrt(3) gives three times the height.
  h.JumpPower = r.power * math.sqrt(3)
  h.JumpHeight = r.height * 3
 end
 player:SetAttribute("TreadmillBoostKind", a.kind)
 player:SetAttribute("TreadmillBoostUntil", r.expires)
end

local function release(player, move, completed)
 local a = active[player]
 if not a then return end
 active[player], occupied[a.belt] = nil, nil
 cooldown[player] = os.clock() + (completed and REWARD_TIME+1 or 3)
 if a.belt.Parent then a.belt:SetAttribute("InUse", false) end
 if a.track then a.track:Stop(.15) a.track:Destroy() end
 if a.hum.Parent then a.hum.AutoRotate = a.rotate end
 local launch = false
 if a.root.Parent then
  if move and a.belt.Parent then
   local frame = beltFrame(a.belt)
   local target = frame:PointToWorldSpace(Vector3.new(0, 0, a.belt.Size.Z/2+4))
   local ray = RaycastParams.new()
   ray.FilterType = Enum.RaycastFilterType.Exclude
   ray.FilterDescendantsInstances = {a.character, a.belt.Parent}
   ray.RespectCanCollide = true
   local hit = workspace:Raycast(target+Vector3.new(0,8,0), Vector3.new(0,-30,0), ray)
   local landed = hit and hit.Normal.Y > .6
   target = landed and hit.Position+Vector3.new(0,a.height+.5,0) or a.previous.Position
   local away = -frame.LookVector
   a.root.CFrame = CFrame.lookAt(target, target+away)
   a.launchDirection = away
   launch = completed and landed and a.hum.Health > 0
  end
  a.root.Anchored = a.anchored
  a.root.AssemblyAngularVelocity = Vector3.zero
  a.root.AssemblyLinearVelocity = Vector3.zero
 end
 if completed and a.hum.Parent and a.hum.Health>0 and player.Character==a.character then
  grantReward(player,a)
  if launch then
   a.root.AssemblyLinearVelocity = a.launchDirection*(a.kind=="Speed" and 45 or 22)+Vector3.new(0,22,0)
  end
 end
 player:SetAttribute("OnTreadmill", false)
 player:SetAttribute("TreadmillStartedAt", nil)
 player:SetAttribute("TreadmillKind", nil)
end

local function mount(player, belt, hum, root)
 if active[player] or rewards[player] or occupied[belt] or root.Anchored or hum.Sit or hum.Health<=0
  or not player:GetAttribute("GBloxLobbyReady") or player:GetAttribute("GBloxInParty") then return end
 local character = player.Character
 local leg = character:FindFirstChild("Left Leg")
 local height = root.Size.Y/2 + hum.HipHeight + (hum.RigType==Enum.HumanoidRigType.R6 and (leg and leg.Size.Y or 2) or 0)
 local a = {belt=belt,root=root,hum=hum,character=character,previous=root.CFrame,anchored=root.Anchored,
  rotate=hum.AutoRotate,height=height,started=workspace:GetServerTimeNow(),
  kind=belt.Name:find("Gravity") and "Gravity" or "Speed"}
 active[player], occupied[belt] = a, player
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 root.Anchored = true
 hum.AutoRotate = false
 local frame = beltFrame(belt)
 local point = frame:PointToWorldSpace(Vector3.new(0,belt.Size.Y/2+height+.05,0))
 root.CFrame = CFrame.lookAt(point,point+frame.LookVector)
 local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
 local anim = Instance.new("Animation")
 local animate = character:FindFirstChild("Animate")
 local run = animate and animate:FindFirstChild("run")
 local source = run and run:FindFirstChildWhichIsA("Animation")
 anim.AnimationId = source and source.AnimationId or (hum.RigType==Enum.HumanoidRigType.R6 and "rbxassetid://180426354" or "rbxassetid://507767714")
 local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
 anim:Destroy()
 if ok then
  a.track = track
  track.Priority = Enum.AnimationPriority.Action
  track.Looped = true
  track:Play(.15)
  track:AdjustSpeed(1.25)
 end
 belt:SetAttribute("InUse",true)
 player:SetAttribute("TreadmillDuration",CHARGE)
 player:SetAttribute("TreadmillKind",a.kind)
 player:SetAttribute("TreadmillStartedAt",a.started)
 player:SetAttribute("OnTreadmill",true)
end

exit.OnServerEvent:Connect(function(player) release(player,true,false) end)
Players.PlayerRemoving:Connect(function(player)
 release(player,false,false)
 clearReward(player)
 cooldown[player]=nil
end)
local elapsed = 0
Run.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < .1 then return end
 elapsed = 0
 local now = workspace:GetServerTimeNow()
 for player,r in rewards do
  if now>=r.expires or player.Character~=r.character or not r.hum.Parent or r.hum.Health<=0 then clearReward(player) end
 end
 for player,a in active do
  if player.Character~=a.character or not a.root.Parent or a.hum.Health<=0 or not a.belt:IsDescendantOf(workspace) then
   release(player,false,false)
  elseif player:GetAttribute("GBloxInParty") then
   release(player,true,false)
  elseif now-a.started>=CHARGE then
   release(player,true,true)
  end
 end
 for _,player in Players:GetPlayers() do
  if active[player] or rewards[player] or os.clock()<(cooldown[player] or 0) then continue end
  local character = player.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local hum = character and character:FindFirstChildOfClass("Humanoid")
  if not root or not hum then continue end
  for _,belt in CS:GetTagged("GBloxTreadmill") do
   if belt:IsA("BasePart") and belt:IsDescendantOf(workspace) and not occupied[belt] then
    local point = beltFrame(belt):PointToObjectSpace(root.Position)
    if math.abs(point.X)<belt.Size.X/2-.3 and math.abs(point.Z)<belt.Size.Z/2-.3
     and point.Y>belt.Size.Y/2 and point.Y<belt.Size.Y/2+7 then
     mount(player,belt,hum,root)
     break
    end
   end
  end
 end
end)
game:BindToClose(function()
 for player in active do release(player,false,false) end
 for player in rewards do clearReward(player) end
end)

