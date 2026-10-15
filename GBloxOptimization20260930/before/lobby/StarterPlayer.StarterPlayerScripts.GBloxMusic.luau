local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("SoundService")
local Tween=game:GetService("TweenService")
local p=Players.LocalPlayer
local lobby=game.PlaceId==74498603638770
local track=SS:WaitForChild(lobby and "GBloxLobbyMusic" or "GBloxGameplayMusic")
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
if lobby then
 -- Lobby readiness alone is not enough: the main menu may still be on screen.
 local gui=p:WaitForChild("PlayerGui")
 local function bind(menu)
  if menu.Name~="GBloxMenu" then return end
  local function refresh() switch(menu:GetAttribute("State")=="Lobby") end
  menu:GetAttributeChangedSignal("State"):Connect(refresh)
  refresh()
 end
 gui.ChildAdded:Connect(bind)
 for _,menu in gui:GetChildren() do bind(menu) end
else
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
end

