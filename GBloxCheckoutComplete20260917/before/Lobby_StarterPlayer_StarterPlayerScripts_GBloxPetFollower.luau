local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local templates=ReplicatedStorage:WaitForChild("GBloxPetTemplates")
local folder=workspace:FindFirstChild("GBloxActivePets") or Instance.new("Folder")
folder.Name="GBloxActivePets" folder.Parent=workspace
local states={}

local function remove(player)
 local state=states[player]
 if state and state.model then state.model:Destroy() end
 states[player]=nil
end

local function spawnPet(player)
 remove(player)
 local id=player:GetAttribute("GBloxEquippedPet")
 local template=typeof(id)=="string" and templates:FindFirstChild(id)
 if not template then return end
 local model=template:Clone()
 model.Name=player.Name.."_"..id
 local rotationOffset=model:GetPivot().Rotation
 local root=model.PrimaryPart
 if not root then root=model:FindFirstChildWhichIsA("BasePart",true) model.PrimaryPart=root end
 if not root then model:Destroy() return end
 for _,part in model:GetDescendants() do if part:IsA("BasePart") then
  part.CanCollide=false part.CanTouch=false part.CanQuery=false part.Massless=true
  part.Anchored=part==root
 end end
 model.Parent=folder
 local motors={}
 for _,v in model:GetDescendants() do if v:IsA("Motor6D") and string.find(v.Name,"WingMotor_",1,true) then
  table.insert(motors,{motor=v,side=v:GetAttribute("GBloxWingSide")=="L" and -1 or 1})
 end end
 states[player]={model=model,root=root,motors=motors,rotationOffset=rotationOffset,cf=nil,last=nil,phase=math.random()*math.pi*2}
end

local function watch(player)
 player:GetAttributeChangedSignal("GBloxEquippedPet"):Connect(function() spawnPet(player) end)
 player.CharacterAdded:Connect(function() task.defer(spawnPet,player) end)
 player.CharacterRemoving:Connect(function() remove(player) end)
 spawnPet(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(remove)
for _,player in Players:GetPlayers() do task.spawn(watch,player) end

RunService.RenderStepped:Connect(function(dt)
 local now=time()
 for player,state in states do
  local character=player.Character
  local characterRoot=character and character:FindFirstChild("HumanoidRootPart")
  local hum=character and character:FindFirstChildOfClass("Humanoid")
  if not characterRoot or not hum or hum.Health<=0 or not state.model.Parent then continue end
  local side=player==Players.LocalPlayer and 1 or -1
  local bob=math.sin(now*2.7+state.phase)*.22
  local desired=characterRoot.CFrame*CFrame.new(side*3.1,2.0+bob,4.1)*state.rotationOffset
  local alpha=1-math.exp(-8*dt)
  state.cf=state.cf and state.cf:Lerp(desired,alpha) or desired
  state.model:PivotTo(state.cf)
  local position=state.cf.Position
  local speed=state.last and (position-state.last).Magnitude/math.max(dt,1/240) or 0
  state.last=position
  local flapSpeed=speed>2 and 8.5 or 3.2
  local flapAmount=math.rad(speed>2 and 25 or 8)
  local angle=math.sin(now*flapSpeed+state.phase)*flapAmount
  for _,entry in state.motors do
   entry.motor.Transform=CFrame.Angles(0,entry.side*angle,0)
  end
  for _,v in state.model:GetDescendants() do if v:IsA("Trail") and v.Name=="GBloxVelocityTrail" then
   v.Enabled=speed>3
  end end
 end
end)

