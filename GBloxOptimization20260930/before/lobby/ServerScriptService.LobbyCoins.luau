local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Data=require(script.Parent:WaitForChild("PlayerData"))
local folder=workspace:WaitForChild("LobbyCoins")
local floor=workspace:WaitForChild("Lobby"):WaitForChild("Lobby floor")
local event=game.ReplicatedStorage:WaitForChild("LobbyCoinCollected")
local rng=Random.new() local busy={} local accumulator=0
local Placement=(function()
-- Spatial placement shared by the live coin service and Edit-mode migration checks.
local Placement={}
function Placement.Contains(floor,position,margin)
 local p=floor.CFrame:PointToObjectSpace(position)
 margin=margin or 5
 return math.abs(p.X)<=floor.Size.X/2-margin and math.abs(p.Z)<=floor.Size.Z/2-margin
  and math.abs(p.Y-(floor.Size.Y/2+2.8))<.1
end
function Placement.IsClear(floor,folder,coin,position)
 if not Placement.Contains(floor,position,5) then return false end
 local excluded={floor,folder}
 local nav=workspace:FindFirstChild("LobbyNavigationTargets")
 if nav then table.insert(excluded,nav) end
 local overlap=OverlapParams.new()
 overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances=excluded
 if #workspace:GetPartBoundsInBox(CFrame.new(position+Vector3.new(0,1.2,0)),Vector3.new(5,7.5,5),overlap)>0 then return false end
 for _,other in folder:GetChildren() do
  if other~=coin and other:IsA("BasePart") and (other.Position-position).Magnitude<6 then return false end
 end
 return true
end
function Placement.Find(floor,folder,coin,rng,attempts)
 for _=1,attempts or 400 do
  local position=floor.CFrame:PointToWorldSpace(Vector3.new(
   rng:NextNumber(-floor.Size.X/2+5,floor.Size.X/2-5),
   floor.Size.Y/2+2.8,
   rng:NextNumber(-floor.Size.Z/2+5,floor.Size.Z/2-5)))
  if (position-coin.Position).Magnitude>=12 and Placement.IsClear(floor,folder,coin,position) then return position end
 end
 return nil
end
return Placement

end)()
local function location(coin)
 return Placement.Find(floor,folder,coin,rng,400)
end
Run.Heartbeat:Connect(function(dt)
 accumulator+=dt if accumulator<.12 then return end accumulator=0
 for _,coin in folder:GetChildren() do
  if not coin:IsA("BasePart") or busy[coin] then continue end
  for _,player in Players:GetPlayers() do
   local character=player.Character local root=character and character:FindFirstChild("HumanoidRootPart") local hum=character and character:FindFirstChildOfClass("Humanoid")
   if not root or not hum or hum.Health<=0 or player:GetAttribute("PlayerDataReady")~=true or (root.Position-coin.Position).Magnitude>4.5 then continue end
   local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={character,folder} ray.RespectCanCollide=true
   if workspace:Raycast(root.Position,coin.Position-root.Position,ray) then continue end
   local destination=location(coin) if not destination then break end
   busy[coin]=true
   local amount=coin:GetAttribute("CashValue")
   local result,awarded=Data.AddEarnedCash(player,amount)
   if result==nil then busy[coin]=nil break end
   coin.Transparency=1
   event:FireClient(player,awarded)
   task.delay(.35,function()
    if coin.Parent then
     coin.CFrame=CFrame.new(destination) coin:SetAttribute("RestCFrame",coin.CFrame)
     coin.Transparency=0
    end
    busy[coin]=nil
   end)
   break
  end
 end
end)
