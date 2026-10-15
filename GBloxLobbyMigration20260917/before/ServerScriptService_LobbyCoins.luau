local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Data=require(script.Parent:WaitForChild("PlayerData"))
local folder=workspace:WaitForChild("LobbyCoins")
local floor=workspace:WaitForChild("Lobby"):WaitForChild("Lobby floor")
local event=game.ReplicatedStorage:WaitForChild("LobbyCoinCollected")
local rng=Random.new() local busy={} local accumulator=0
local function location(coin)
 local filter={floor,folder}
 local overlap=OverlapParams.new() overlap.FilterType=Enum.RaycastFilterType.Exclude overlap.FilterDescendantsInstances=filter
 for i=1,300 do
  local p=floor.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-floor.Size.X/2+5,floor.Size.X/2-5),floor.Size.Y/2+2.8,rng:NextNumber(-floor.Size.Z/2+5,floor.Size.Z/2-5)))
  if (p-coin.Position).Magnitude<12 then continue end
  if #workspace:GetPartBoundsInBox(CFrame.new(p+Vector3.new(0,1.2,0)),Vector3.new(5,7.5,5),overlap)>0 then continue end
  local clear=true
  for _,other in folder:GetChildren() do if other~=coin and other:IsA("BasePart") and (other.Position-p).Magnitude<6 then clear=false break end end
  if clear then return p end
 end
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
