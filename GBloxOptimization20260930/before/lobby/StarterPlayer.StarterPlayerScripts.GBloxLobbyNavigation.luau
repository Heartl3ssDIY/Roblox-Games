local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local gui=pg:WaitForChild("GBloxLobbyNavigation")
local row=gui.TopButtons
local panel=gui.Training
local remote=game.ReplicatedStorage:WaitForChild("GBloxLobbyNavigate")
for _,name in {"Eggs","Play","Shops"} do
 row[name].Activated:Connect(function() remote:FireServer(name) end)
end
local function modalOpen()
 if player:GetAttribute("GBloxCommunityRewardsOpen") then return true end
 if player:GetAttribute("GBloxDailyRewardsOpen") then return true end
 local shop=pg:FindFirstChild("GBloxShopMockups")
 local canvas=shop and shop:FindFirstChild("Canvas")
 if canvas and canvas.Visible and shop.Enabled then
  for _,name in {"Shop","Abilities","Inventory","Pets"} do
   local p=canvas:FindFirstChild(name)
   if p and p.Visible then return true end
  end
 end
 return false
end
local CS=game:GetService("CollectionService")
local belts={}
local function registerBelt(belt)
 if belts[belt] or not belt:IsA("BasePart") then return end
 local console=belt.Parent:FindFirstChild(belt.Name:gsub("_Belt$","_Console"))
 if not console then return end
 local direction=console.Position-belt.Position
 direction=Vector3.new(direction.X,0,direction.Z)
 if direction.Magnitude<.01 then return end
 local frame=CFrame.lookAt(belt.Position,belt.Position+direction.Unit)
 local data={frame=frame,phase=0,length=18,seams={}}
 for _,seam in belt.Parent:GetChildren() do
  if seam:IsA("BasePart") and seam.Name:find("BeltSeam") then
   table.insert(data.seams,{part=seam,rest=seam.CFrame,offset=frame:PointToObjectSpace(seam.Position)})
  end
 end
 belts[belt]=data
end
for _,belt in CS:GetTagged("GBloxTreadmill") do registerBelt(belt) end
CS:GetInstanceAddedSignal("GBloxTreadmill"):Connect(registerBelt)
CS:GetInstanceRemovedSignal("GBloxTreadmill"):Connect(function(belt) belts[belt]=nil end)
Run.RenderStepped:Connect(function(dt)
 for belt,data in belts do
  if belt.Parent and belt:GetAttribute("InUse") then
   data.phase=(data.phase+dt*10)%data.length
   for _,seam in data.seams do
    if seam.part.Parent then
     local z=(seam.offset.Z+data.phase+data.length/2)%data.length-data.length/2
     local position=data.frame:PointToWorldSpace(Vector3.new(seam.offset.X,seam.offset.Y,z))
     seam.part.CFrame=CFrame.new(position)*seam.rest.Rotation
    end
   end
  end
 end
end)

local elapsed=0
Run.RenderStepped:Connect(function(dt)
 elapsed+=dt
 if elapsed<.05 then return end
 elapsed=0
 local ready=player:GetAttribute("GBloxLobbyReady")==true
 local training=player:GetAttribute("OnTreadmill")==true
 row.Visible=ready and not training and not player:GetAttribute("GBloxInParty") and not modalOpen()
 local camera=workspace.CurrentCamera
 if camera then
  local width=camera.ViewportSize.X
  row.Size=UDim2.new(width<700 and .9 or .74,0,0,width<700 and 44 or 58)
 end
 local now=workspace:GetServerTimeNow()
 local boostUntil=player:GetAttribute("TreadmillBoostUntil") or 0
 panel.Visible=ready and (training or boostUntil>now)
 if training then
  local duration=math.max(.1,player:GetAttribute("TreadmillDuration") or 10)
  local time=math.clamp(now-(player:GetAttribute("TreadmillStartedAt") or now),0,duration)
  local kind=player:GetAttribute("TreadmillKind")
  local reward=kind=="Gravity" and "3x jump height" or "5x speed"
  panel.Status.Text=string.format("Run to charge: %d / %d seconds\n%s for 5 seconds when ready!",math.floor(time),duration,reward)
  local charge=math.clamp(time/duration,0,1)
  panel.ProgressBar.Inner.Fill.Size=UDim2.fromScale(charge,1)
  panel.ProgressBar.Inner.Percentage.Text=string.format("%d%%",math.floor(charge*100))
 elseif boostUntil>now then
  local remaining=boostUntil-now
  local kind=player:GetAttribute("TreadmillBoostKind")
  panel.Status.Text=string.format("%s!  %d seconds left",kind=="Gravity" and "3x jump height" or "5x speed",math.ceil(remaining))
  panel.ProgressBar.Inner.Fill.Size=UDim2.fromScale(1,1)
  panel.ProgressBar.Inner.Percentage.Text="BOOST ACTIVE"
 end
end)

