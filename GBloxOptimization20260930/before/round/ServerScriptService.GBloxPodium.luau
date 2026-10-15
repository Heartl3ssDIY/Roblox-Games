local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local remote=RS:WaitForChild("GBloxPodiumEvent")
local M={}
M.ReturnSeconds=60
local RankingEmotes=require(game.ServerScriptService:WaitForChild("RankingEmotes"))
local returnHandler
function M.SetReturnHandler(handler) returnHandler=handler end
local active
local rewards={}
local last={}
local function send(player)
 if active and active.allowed[player] then
  -- Camera/placement information is public. Reward amounts are sent only to their owner.
  remote:FireClient(player,"Ceremony",active.packet)
  if rewards[player] then remote:FireClient(player,"Rewards",rewards[player]) end
 end
end
local function emoteOptions(player)
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local r15=humanoid and humanoid.RigType==Enum.HumanoidRigType.R15
 local options={}
 for _,option in RankingEmotes.Options(player) do
  if r15 or (string.sub(option.key,1,7)~="avatar:" and string.sub(option.key,1,5)~="shop:") then
   table.insert(options,{key=option.key,name=option.name})
  end
 end
 return options
end
local function sendEmotes(player)
 remote:FireClient(player,"EmoteOptions",{
  options=emoteOptions(player),selected=RankingEmotes.Selected(player),
  message=player:GetAttribute("GBloxPodiumEmoteError"),
 })
end
remote.OnServerEvent:Connect(function(player,action,key)
 if active and active.allowed[player] and (action=="EmoteOptions" or action=="SelectEmote") then
  if os.clock()-(last[player] or -math.huge)<.2 then return end
  last[player]=os.clock()
  if action=="SelectEmote" then
   local allowed=false for _,option in emoteOptions(player) do if option.key==key then allowed=true break end end
   if allowed and RankingEmotes.Select(player,key) then
    task.spawn(function()
     RankingEmotes.PlayPodium(player,key)
     if player.Parent and active and active.allowed[player] then sendEmotes(player) end
    end)
   end
  end
  sendEmotes(player)
  return
 end
 if action~="Request" or os.clock()-(last[player] or -math.huge)<1 then return end
 last[player]=os.clock() send(player)
end)
function M.UpdateReward(player,breakdown,state)
 rewards[player]={breakdown=breakdown,state=state}
 if player.Parent then remote:FireClient(player,"Rewards",rewards[player]) end
end
function M.PlaceCharacter(player,character)
 if not active or not active.allowed[player] then return false end
 local marker=active.spawns:FindFirstChild("Place"..active.allowed[player])
 local root=character:FindFirstChild("HumanoidRootPart")
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if not marker or not root or not humanoid then return false end
 root.Anchored=true root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
 -- Place the root explicitly: model pivots can have avatar-specific offsets.
 local target=marker.CFrame
 local surface=marker:GetAttribute("PodiumSurfacePosition")
 if surface then
  local leg=character:FindFirstChild("Left Leg")
  local height=humanoid.HipHeight+root.Size.Y*.5+(humanoid.RigType==Enum.HumanoidRigType.R6 and leg and leg.Size.Y or 0)
  target=CFrame.new(surface+Vector3.new(0,height+.12,0))*marker.CFrame.Rotation
 end
 character:PivotTo(target*root.CFrame:ToObjectSpace(character:GetPivot()))
 humanoid.PlatformStand=false humanoid.AutoRotate=false humanoid.WalkSpeed=0 humanoid.JumpPower=0 humanoid.JumpHeight=0
 humanoid.DisplayName=player.DisplayName
 if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator",humanoid) end
 if humanoid.RigType==Enum.HumanoidRigType.R15 then
  for _,part in character:GetDescendants() do
   if part:IsA("BasePart") then part.CanCollide=false part.CanTouch=false end
  end
 end
 if humanoid.Health>0 then humanoid:ChangeState(Enum.HumanoidStateType.Running) end
 local animator=humanoid:FindFirstChildOfClass("Animator")
 if animator then for _,track in animator:GetPlayingAnimationTracks() do track:Stop(.15) end end
 player:SetAttribute("RunnerStatus","Podium")
 player:SetAttribute("GBloxPodiumActive",true)
 return true
end
-- This creates a presentation character only after the match is complete.
-- The race loader stays R6; asynchronous results never replace a newer character.
local loading={}
function M.EnsureCharacter(player)
 if not active or not active.allowed[player] or not player.Parent or loading[player] then return end
 local existing=player.Character
 local hum=existing and existing:FindFirstChildOfClass("Humanoid")
 if hum and hum.RigType==Enum.HumanoidRigType.R15 and hum.Health>0 then
  M.PlaceCharacter(player,existing)
  return
 end
 local session=active
 loading[player]=true
 player:SetAttribute("GBloxPodiumAvatarLoading",true)
 task.spawn(function()
  local created
  for attempt=1,3 do
   if not player.Parent or active~=session or not session.allowed[player]
    or workspace:GetServerTimeNow()>=session.returnAt then break end
   local description
   local ok,result=pcall(function()
    description=Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
    return Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
   end)
   if description then description:Destroy() end
   if ok and result then created=result break end
   if attempt<3 then task.wait(1) end
  end
  loading[player]=nil
  if not player.Parent or active~=session or not session.allowed[player]
   or player.Character~=existing or workspace:GetServerTimeNow()>=session.returnAt then
   if created then created:Destroy() end
   if player.Parent then player:SetAttribute("GBloxPodiumAvatarLoading",false) end
   return
  end
  player:SetAttribute("GBloxPodiumAvatarLoading",false)
  if not created then
   player:SetAttribute("GBloxPodiumEmoteError","Avatar couldn't load. Basic emotes are still available.")
   sendEmotes(player)
   return
  end
  created.Name=player.Name
  created:SetAttribute("GBloxPodiumR15",true)
  -- No imported avatar scripts execute in the presentation character.
  for _,v in created:GetDescendants() do if v:IsA("LuaSourceContainer") then v:Destroy() end end
  if not M.PlaceCharacter(player,created) then created:Destroy() return end
  created.Parent=workspace
  player.Character=created
  if existing and existing~=created then existing:Destroy() end
  player:SetAttribute("GBloxPodiumEmoteError",nil)
  player:SetAttribute("GBloxPodiumR15Ready",true)
  task.defer(function()
   if player.Parent and player.Character==created then
    RankingEmotes.PlayPodium(player,RankingEmotes.Selected(player))
    sendEmotes(player)
   end
  end)
 end)
end
function M.Start(entries,matchId,version,runners,options)
 if active then return end
 local stage=workspace:FindFirstChild("Podium")
 local spawns=stage and stage:FindFirstChild("PlacementSpawns")
 assert(spawns,"Podium placement markers are missing.")
 local allowed,roster={},{}
 for place,entry in entries do
  if place<=6 then
   local player=entry.player
   local marker=spawns:FindFirstChild("Place"..place)
   assert(marker,"Missing podium place "..place)
   allowed[player]=place
   table.insert(roster,{place=place,userId=player.UserId,displayName=player.DisplayName,cframe=marker.CFrame})
  end
 end
 local base
 for _,v in stage:GetChildren() do if v:IsA("BasePart") and v.Name=="Podium base" and (not base or v.Position.Y>base.Position.Y) then base=v end end
 local center=base and base.Position+Vector3.new(0,10.5,0) or roster[1].cframe.Position
 active={allowed=allowed,spawns=spawns,nextReturn={},preview=game:GetService("RunService"):IsStudio() and options and options.preview==true,returnAt=workspace:GetServerTimeNow()+M.ReturnSeconds,packet={id=matchId,courseVersion=version,roster=roster,center=center,stageSize=base and Vector3.new(base.Size.X,36,base.Size.Z) or Vector3.new(100,36,90)}}
 for player in allowed do
  local data=runners[player]
  if data then data.status="Podium" data.recovering=false data.recoveryVersion=(data.recoveryVersion or 0)+1 end
  player:SetAttribute("GBloxPodiumActive",true)
  local character=player.Character
  if character and character:FindFirstChildOfClass("Humanoid") and character.Humanoid.Health>0 then
   M.PlaceCharacter(player,character)
  end
  M.EnsureCharacter(player)
  send(player)
 end
end
-- Server-owned deadline; hiding UI, emotes, respawning and repeated Request packets never reset it.
function M.Step(now)
 if not active or now<active.returnAt then return end
 for _,player in Players:GetPlayers() do
  if player.Parent and now>=(active.nextReturn[player] or 0) then
   active.nextReturn[player]=now+5
   if active.preview or game:GetService("RunService"):IsStudio() then
    active.nextReturn[player]=math.huge
    player:SetAttribute("GBloxPodiumReturnDue",true)
    remote:FireClient(player,"AutoReturnPreview")
   elseif returnHandler then
    task.spawn(returnHandler,player,active.packet.courseVersion)
   end
  end
 end
end
local stepClock=0
game:GetService("RunService").Heartbeat:Connect(function(dt)
 stepClock+=dt
 if stepClock>=1 then stepClock=0 M.Step(workspace:GetServerTimeNow()) end
end)
Players.PlayerRemoving:Connect(function(player) rewards[player]=nil last[player]=nil loading[player]=nil if active then active.allowed[player]=nil end end)
return M

