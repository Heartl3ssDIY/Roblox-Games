local p=game.Players.LocalPlayer
local g=script.Parent
local panel=g.Panel
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local remote=RS:WaitForChild("GBloxPodiumEvent")
local runner=RS:WaitForChild("RunnerEvent")
local Presentation=require(RS:WaitForChild("GBloxPodiumPresentation"))
local Effects=require(RS:WaitForChild("RankingEmoteEffects"))
local pop=Effects.Panel(panel)
Effects.Button(panel.ReturnToLobby)
local packet,reward,shownId
local completed=false
local leaving=false
local heldCamera,heldFov
local activeTween
local rows={}
local toggle=g:WaitForChild("RewardsToggle")
local emoteButton=g:WaitForChild("ChooseEmote")
local emoteMenu=g:WaitForChild("EmoteMenu")
local emoteList=emoteMenu.Options
local emoteTemplate=emoteList.EmoteTemplate
local emoteStatus=Instance.new("TextLabel")
emoteStatus.Name="EmoteStatus"
emoteStatus.BackgroundTransparency=1
emoteStatus.Position=UDim2.fromOffset(8,4)
emoteStatus.Size=UDim2.new(1,-16,0,36)
emoteStatus.Font=Enum.Font.Arcade emoteStatus.TextSize=12
emoteStatus.TextColor3=Color3.new(1,1,1) emoteStatus.TextWrapped=true
emoteStatus.ZIndex=emoteTemplate.ZIndex+2
emoteStatus.Text="AVATAR EMOTES"
emoteStatus.Parent=emoteMenu
emoteList.Position=UDim2.fromOffset(0,42)
emoteList.Size=UDim2.new(1,0,1,-42)
local menuPop=Effects.Panel(emoteMenu)
local Visuals=require(RS:WaitForChild("GBloxPodiumVisuals"))
local visuals
local optionButtons={}
Effects.Button(toggle) Effects.Button(emoteButton)
toggle.Visible=false emoteButton.Visible=false
emoteTemplate.Visible=false
menuPop:SetOpen(false,true)
local function showRewards(open)
 pop:SetOpen(open,not open)
 toggle.Label.Text=open and "HIDE REWARDS -" or "SHOW REWARDS +"
 if open then menuPop:SetOpen(false,true) end
end
toggle.Activated:Connect(function() if completed then showRewards(not pop.Open) end end)
emoteButton.Activated:Connect(function()
 if not completed then return end
 local open=not menuPop.Open
 menuPop:SetOpen(open,not open)
 if open then showRewards(false) remote:FireServer("EmoteOptions") end
end)
local function populateEmotes(data)
 emoteStatus.Text=data.message or (p:GetAttribute("GBloxPodiumAvatarLoading") and "LOADING AVATAR..." or "AVATAR EMOTES")
 for _,b in optionButtons do b:Destroy() end table.clear(optionButtons)
 for i,option in data.options or {} do
  local b=emoteTemplate:Clone() b.Name="Option"..i b.Visible=true
  b.AnchorPoint=Vector2.zero b.Position=UDim2.fromOffset(8,8+(i-1)*52)
  b.Size=UDim2.new(1,-16,0,44)
  b.Label.Text=(data.selected==option.key and "> " or "")..option.name
  b.Label.TextSize=18 b.Parent=emoteList
  Effects.Button(b)
  b.Activated:Connect(function() remote:FireServer("SelectEmote",option.key) end)
  table.insert(optionButtons,b)
 end
 emoteList.CanvasSize=UDim2.fromOffset(0,#optionButtons*52+16)
end
local function comma(n)
 local text=tostring(math.floor(n or 0))
 return text:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function timeText(seconds)
 return string.format("%02d:%05.2f",math.floor((seconds or 0)/60),(seconds or 0)%60)
end
local function place(object,x,y,w,h) object.Position=UDim2.fromOffset(x,y) object.Size=UDim2.fromOffset(w,h) end
local function layout()
 local camera=workspace.CurrentCamera if not camera then return end
 local viewport=camera.ViewportSize
 local small=viewport.X<700
 toggle.Position=UDim2.new(1,-18,0,math.max(18,18-g.AbsolutePosition.Y))
 toggle.Size=UDim2.fromOffset(small and 190 or 230,42)
 toggle.Label.TextSize=small and 15 or 18
 emoteButton.Size=UDim2.fromOffset(small and 160 or 190,42)
 emoteMenu.Size=UDim2.fromOffset(math.min(280,viewport.X-36),math.min(300,math.max(130,viewport.Y-140)))
 local width=math.min(1100,viewport.X-24)
 local height=math.min(small and 620 or 474,viewport.Y-24)
 panel.Size=UDim2.fromOffset(width,height)
 local margin=small and 18 or 30
 local content=width-2*margin
 local font=small and 12 or 18
 place(panel.Title,margin,16,content,34) panel.Title.TextSize=small and 23 or 32
 place(panel.Stats,margin,54,content,small and 42 or 28) panel.Stats.TextSize=small and 12 or 16
 local headerY=small and 104 or 94
 place(panel.ReasonHeader,margin,headerY,content*.54,24)
 place(panel.CashHeader,margin+content*.54,headerY,content*.22,24)
 place(panel.TrophyHeader,margin+content*.76,headerY,content*.24,24)
 for _,name in {"ReasonHeader","CashHeader","TrophyHeader"} do panel[name].TextSize=font end
 local bottom=height-132
 place(panel.Rows,margin,headerY+30,content,math.max(35,bottom-headerY-42))
 local rowHeight=small and 43 or 28
 for i,row in rows do
  place(row.frame,0,(i-1)*rowHeight,content-8,rowHeight)
  for _,v in {row.label,row.cash,row.trophies} do v.TextSize=font end
 end
 panel.Rows.CanvasSize=UDim2.fromOffset(0,#rows*rowHeight)
 place(panel.TotalLabel,margin,bottom,content*.54,30)
 place(panel.TotalCash,margin+content*.54,bottom,content*.22,30)
 place(panel.TotalTrophies,margin+content*.76,bottom,content*.24,30)
 for _,name in {"TotalLabel","TotalCash","TotalTrophies"} do panel[name].TextSize=small and 17 or 24 end
 local bw=math.min(330,content*.88)
 place(panel.ReturnToLobby,(width-bw)/2,height-86,bw,47)
 panel.ReturnToLobby.Label.TextSize=small and 16 or 20
 place(panel.Status,margin,height-35,content,26)
end
local function refresh()
 if not reward then panel.Status.Text="Loading your rewards..." return end
 local b=reward.breakdown
 if not b then return end
 for _,row in rows do row.frame:Destroy() end table.clear(rows)
 panel.Stats.Text=string.format("PLACE %d  |  TIME %s  |  DEATHS %d  |  %.2f POINTS",b.place,timeText(b.time),b.deaths,b.score)
 for _,entry in b.rows do
  local frame=Instance.new("Frame") frame.BackgroundTransparency=1 frame.Parent=panel.Rows
  local function label(text,x,width,alignment)
   local v=Instance.new("TextLabel") v.BackgroundTransparency=1 v.Text=text v.Font=Enum.Font.Arcade v.TextColor3=Color3.new(1,1,1) v.TextStrokeTransparency=0
   v.TextWrapped=true v.TextXAlignment=alignment v.Position=UDim2.fromScale(x,0) v.Size=UDim2.fromScale(width,1) v.ZIndex=5 v.Parent=frame return v
  end
  table.insert(rows,{frame=frame,label=label(entry.label,0,.54,Enum.TextXAlignment.Left),
   cash=label("+"..comma(entry.cash),.54,.22,Enum.TextXAlignment.Right),
   trophies=label("+"..comma(entry.trophies),.76,.24,Enum.TextXAlignment.Right)})
 end
 panel.TotalCash.Text=comma(b.cash) panel.TotalTrophies.Text=comma(b.trophies)
 panel.Status.Text=reward.state=="Preview" and "STUDIO PREVIEW - no rewards awarded." or reward.state=="Saved" and "Rewards added to your balance." or reward.state=="SavePending" and "Rewards recorded; saving before you leave..." or reward.state=="Unavailable" and "Rewards are not ready. Please stay connected." or "Saving your rewards..."
 layout()
end
local function reveal()
 completed=true g.RevealTitle.Text="" refresh() showRewards(false)
 toggle.Visible=true emoteButton.Visible=true
 remote:FireServer("EmoteOptions")
end
local function ceremony(data)
 if shownId==data.id then return end
 if activeTween then activeTween:Cancel() activeTween=nil end
 shownId=data.id packet=data completed=false leaving=false pop:SetOpen(false,true)
 toggle.Visible=false emoteButton.Visible=false menuPop:SetOpen(false,true)
 panel.ReturnToLobby.Active=true panel.ReturnToLobby.Label.Text="RETURN TO LOBBY"
 if visuals then visuals:Destroy() visuals=nil end
 p:SetAttribute("GBloxPodiumCameraActive",true)
 local runnerUI=p.PlayerGui:FindFirstChild("RunnerUI") if runnerUI then runnerUI.Enabled=false end
 local rankings=p.PlayerGui:FindFirstChild("GBloxRoundRankings") if rankings then rankings.Enabled=false end
 task.spawn(function()
  g.RevealTitle.Text="MATCH COMPLETE"
  if workspace.StreamingEnabled then pcall(function() p:RequestStreamAroundAsync(data.center,8) end) end
  if shownId~=data.id then return end
  local camera=workspace.CurrentCamera camera.CameraType=Enum.CameraType.Scriptable
  visuals=Visuals.Begin(data)
  local shots=Presentation.Shots(data,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y))
  for index,shot in shots do
   if shownId~=data.id then return end
   visuals:Reveal(shot.place)
   g.RevealTitle.Text=shot.place and (({"1ST","2ND","3RD"})[shot.place].." PLACE - "..shot.name) or "THE FINAL PLACEMENTS"
   heldCamera=nil heldFov=nil
   if index==1 then
    -- Cut to third place instead of flying across the entire map from the course.
    camera.CFrame=shot.cframe camera.FieldOfView=shot.fov
   else
    activeTween=Tween:Create(camera,TweenInfo.new(shot.move,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{CFrame=shot.cframe,FieldOfView=shot.fov})
    activeTween:Play()
    -- Do not depend on a rendered tween completion while a window is unfocused.
    task.wait(shot.move)
    if shownId~=data.id then return end
    if activeTween then activeTween:Cancel() activeTween=nil end
    camera.CFrame=shot.cframe camera.FieldOfView=shot.fov
   end
   heldCamera=shot.cframe heldFov=shot.fov task.wait(shot.hold+(index==1 and shot.move or 0))
   if shownId~=data.id then return end
  end
  reveal()
 end)
end
remote.OnClientEvent:Connect(function(action,data)
 if action=="Ceremony" then ceremony(data)
 elseif action=="Rewards" then reward=data if completed then refresh() end
 elseif action=="EmoteOptions" then populateEmotes(data)
 elseif action=="AutoReturnPreview" then
  g.RevealTitle.Text="STUDIO PREVIEW - LOBBY RETURN DUE"
  panel.Status.Text="60 seconds elapsed. Live games automatically return to the lobby."
 end
end)
panel.ReturnToLobby.Activated:Connect(function()
 if not completed or leaving or not packet then return end
 leaving=true panel.ReturnToLobby.Label.Text="RETURNING..." panel.ReturnToLobby.Active=false
 runner:FireServer("LeaveRankings",packet.courseVersion)
end)
runner.OnClientEvent:Connect(function(action,data)
 if action=="LeaveLobbyResult" and packet and data.courseVersion==packet.courseVersion then
  leaving=data.ok==true
  panel.ReturnToLobby.Active=not leaving
  panel.ReturnToLobby.Label.Text=leaving and "RETURNING..." or "RETURN TO LOBBY"
  if data.message then panel.Status.Text=data.message end
 end
end)
Run:BindToRenderStep("GBloxPodiumCamera",Enum.RenderPriority.Camera.Value+5,function()
 if shownId and heldCamera then
  local camera=workspace.CurrentCamera camera.CameraType=Enum.CameraType.Scriptable camera.CFrame=heldCamera camera.FieldOfView=heldFov
 end
end)
local function cameraChanged()
 local camera=workspace.CurrentCamera
 if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
 layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({panel,panel.ReturnToLobby}) end) end)
-- Recover a packet if the GUI loaded after the match ended.
remote:FireServer("Request")
p:GetAttributeChangedSignal("GBloxPodiumActive"):Connect(function()
 if p:GetAttribute("GBloxPodiumActive") then remote:FireServer("Request") end
end)

p:GetAttributeChangedSignal("RankingEmotesLoaded"):Connect(function()
 if completed and p:GetAttribute("RankingEmotesLoaded") then remote:FireServer("EmoteOptions") end
end)
p:GetAttributeChangedSignal("GBloxPodiumR15Ready"):Connect(function()
 if completed then remote:FireServer("EmoteOptions") end
end)

script.Destroying:Connect(function()
 Run:UnbindFromRenderStep("GBloxPodiumCamera")
 if activeTween then activeTween:Cancel() end
 if visuals then visuals:Destroy() end
end)

