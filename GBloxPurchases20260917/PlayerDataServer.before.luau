local Players=game:GetService("Players")
local Data=require(script.Parent:WaitForChild("PlayerData"))
Players.PlayerAdded:Connect(function(p) Data.Load(p) end)
Players.PlayerRemoving:Connect(function(p) Data.Remove(p) end)
for _,p in Players:GetPlayers() do task.spawn(Data.Load,p) end
task.spawn(function()
 while task.wait(45) do for _,p in Players:GetPlayers() do task.spawn(Data.Save,p) end end
end)
game:BindToClose(function()
 local pending=0
 for _,p in Players:GetPlayers() do pending+=1 task.spawn(function() Data.Remove(p) pending-=1 end) end
 local deadline=os.clock()+25
 while pending>0 and os.clock()<deadline do task.wait(.1) end
end)
