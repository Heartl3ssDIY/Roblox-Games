local a=game.ReplicatedStorage:WaitForChild("FootballMayhem")
local p=game.Players.LocalPlayer
a.Feedback.OnClientEvent:Connect(function(data)
 if data.kind=="Reveal" then
  task.delay(.25,function()
   local f=workspace:FindFirstChild("PersonalFootballReveals")
   local r=f and f:FindFirstChild("Row"..data.row)
   script:SetAttribute("RevealSample",game:GetService("HttpService"):JSONEncode({row=data.row,dangerLane=data.dangerLane,localRevealExists=r~=nil,noFullPath=data.wrong==nil,quarterbackRevealed=r and r:FindFirstChild("RevealedQuarterback")~=nil}))
  end)
 end
end)
a.Effects.OnClientEvent:Connect(function(kind,id)
 if kind=="Stun" and id==p.UserId then
  task.delay(.7,function()
   local f=workspace:FindFirstChild("FootballStun_"..id)
   local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
   local birds,stars,swirls=0,0,0
   if f then for _,v in f:GetChildren() do if v.Name=="LittleBird" then birds+=1 elseif v.Name=="Star" then stars+=1 elseif v.Name=="Swirl" then swirls+=1 end end end
   local grunt=r and r:FindFirstChild("TackleGrunt")
   script:SetAttribute("StunSample",game:GetService("HttpService"):JSONEncode({birds=birds,stars=stars,swirls=swirls,fallen=r and math.abs(r.CFrame.UpVector.Y)<.1,platformStand=h and h.PlatformStand,gruntLoaded=grunt and grunt.IsLoaded,gruntLength=grunt and grunt.TimeLength}))
  end)
 end
end)

