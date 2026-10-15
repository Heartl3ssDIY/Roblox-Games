local player=game.Players.LocalPlayer
local Run=game:GetService("RunService")
local folder=workspace:WaitForChild("LobbyCoins")
local sound=Instance.new("Sound") sound.Name="CoinCollect" sound.SoundId="rbxassetid://85549623140205" sound.Volume=.3 sound.PlaybackSpeed=1.35 sound.Parent=game:GetService("SoundService")
game.ReplicatedStorage:WaitForChild("LobbyCoinCollected").OnClientEvent:Connect(function(amount)
 game:GetService("SoundService"):PlayLocalSound(sound)

end)
Run.RenderStepped:Connect(function()
 local time=workspace:GetServerTimeNow() local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 for _,coin in folder:GetChildren() do
  if coin:IsA("BasePart") then
   local rest=coin:GetAttribute("RestCFrame")
   if rest and root and (root.Position-rest.Position).Magnitude<180 then
    coin.CFrame=rest*CFrame.new(0,math.sin(time*2.4+rest.Position.X*.37+rest.Position.Z*.21)*.55,0)*CFrame.Angles(0,time*1.2,0)
   end
  end
 end
end)
