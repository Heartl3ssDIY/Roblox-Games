local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("SoundService")
local Tween=game:GetService("TweenService")
local p=Players.LocalPlayer
local track=SS:WaitForChild("GBloxGameplayMusic")
track:SetAttribute("AudioCategory","Music")
track.Looped=true track.Volume=0 track:Stop()
local current=false
local fade
local function switch(enabled)
 enabled=enabled==true and track.SoundId~=""
 if current==enabled then return end
 current=enabled
 if fade then fade:Cancel() end
 if enabled then
  if not track.IsPlaying then track:Play() end
  fade=Tween:Create(track,TweenInfo.new(.45),{Volume=.28})
 else
  fade=Tween:Create(track,TweenInfo.new(.35),{Volume=0})
  fade.Completed:Once(function(state)
   if state==Enum.PlaybackState.Completed and not current then track:Stop() end
  end)
 end
 fade:Play()
end
-- Loading, menus and results have no music until a replacement is assigned.
local phase="Waiting"
local function refresh()
 local results=phase=="Intermission" or phase=="MatchComplete"
  or phase=="AwaitingCourse" or phase=="TutorialComplete"
 switch(not results and (phase=="Running" or p:GetAttribute("RunnerStatus")=="Running"))
end
RS:WaitForChild("RunnerEvent").OnClientEvent:Connect(function(action,data)
 if action=="State" then phase=data and data.phase or phase
 elseif action=="TutorialComplete" then phase="TutorialComplete" end
 refresh()
end)
p:GetAttributeChangedSignal("RunnerStatus"):Connect(refresh)
refresh()

