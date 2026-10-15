local g=script.Parent
local canvas=g.Canvas
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local Input=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local p=Players.LocalPlayer
local event=RS:WaitForChild("RunnerEvent")
local assets={["5th place (left HUD).png"]="rbxassetid://79174018798985",["6th place (left HUD).png"]="rbxassetid://84254995247976",["6th.png"]="rbxassetid://136657542511716",["3rd place (left HUD).png"]="rbxassetid://80215191398354",["1st place (left HUD).png"]="rbxassetid://114601171696769",["2nd.png"]="rbxassetid://73024045137601",["2nd place (left HUD).png"]="rbxassetid://111484350020397",["Bronze Podium Player Label.png"]="rbxassetid://91995433585082",["Gold Podium Player Label.png.png"]="rbxassetid://96563239668944",["1st.png"]="rbxassetid://133887820369829",["rankings score bkground bar.png"]="rbxassetid://79932143461787",["4th place (left HUD).png"]="rbxassetid://75449202232945",["Silver Podium Player Label.png.png"]="rbxassetid://100152328262214",["4th.png"]="rbxassetid://95339487442647",["Rankings race progress position bkground.png"]="rbxassetid://138080281336243",["Race Rankings bkground.png"]="rbxassetid://77432091840977",["Ranking race progress.png"]="rbxassetid://136299778388368",["rankings score frames.png"]="rbxassetid://115624444293548",["5th.png"]="rbxassetid://96116624306269",["Non-podium player label.png"]="rbxassetid://82566612410017",["3rd.png"]="rbxassetid://125148859325942"}
local ordinals={"1st","2nd","3rd","4th","5th","6th"}
local packet,phase,lastShown,compact
local fills,tweens={},{}
local Preview=require(RS:WaitForChild("RankingAvatarPreview"))
local previews={}
local readiness={readyCount=0,totalCount=0,readyIds={}}
local ownReady=false
local emoteOptions,selectedEmote={}, "idle"
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name
 for k,v in props do o[k]=v end o.Parent=parent return o
end
-- Use the owner's supplied artwork, also visible/editable in StarterGui.
local emoteButton=canvas:WaitForChild("ChooseEmote")
local readyCount=make("TextLabel","ReadyCount",canvas,{
 BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),Font=Enum.Font.Arcade,
 TextSize=24,Text="0 / 0 READY",ZIndex=12,
})
local emoteMenu=canvas:WaitForChild("EmoteMenu")
local emoteList=emoteMenu:WaitForChild("Options")
local emoteTemplate=emoteList:WaitForChild("EmoteTemplate")
local Effects=require(RS:WaitForChild("RankingEmoteEffects"))
local leaveButton=g:WaitForChild("LeaveToLobby")
local leaveMessage=g:WaitForChild("LeaveMessage")
local leaveRules=require(RS:WaitForChild("RankingLeaveRules"))
local leavePending=false
Effects.Button(leaveButton)
local function updateLeave()
 leaveButton.Visible=g.Enabled and packet~=nil and leaveRules.CanLeave(phase,packet.courseVersion,p:GetAttribute("RunnerCourseVersion"))
 leaveMessage.Visible=leaveButton.Visible and leaveMessage.Text~=""
 leaveButton.Active=not leavePending
 leaveButton.Label.Text=leavePending and "Leaving..." or "Leave"
end
leaveButton.Activated:Connect(function()
 if not leaveButton.Visible or leavePending or not packet then return end
 leavePending=true leaveMessage.Text="" updateLeave()
 event:FireServer("LeaveRankings",packet.courseVersion)
end)
local emoteButtonEffect=Effects.Button(emoteButton)
local emoteMenuEffect=Effects.Panel(emoteMenu)
emoteMenu.AnchorPoint=Vector2.new(0,1)
task.spawn(function()
 -- Load the supplied art during the race, before the picker is opened.
 pcall(function()
  game:GetService("ContentProvider"):PreloadAsync({emoteButton.Image,emoteMenu.Image,emoteTemplate.Image})
 end)
end)
local function layoutEmoteOptions()
 local width=emoteList.AbsoluteSize.X
 local scale=canvas.Fit.Scale*emoteMenuEffect.Scale.Scale
 if width<=0 or scale<=0 then return end
 local contentWidth=width/scale-12
 local height=contentWidth*93/407
 local index=0
 for _,button in emoteList:GetChildren() do
  if button:IsA("ImageButton") and button~=emoteTemplate then
   button.Position=UDim2.fromOffset(0,index*(height+10))
   button.Size=UDim2.fromOffset(contentWidth,height)
   index+=1
  end
 end
 emoteList.CanvasSize=UDim2.fromOffset(0,math.max(0,index*(height+10)-10))
end
emoteList:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutEmoteOptions)
local function clearPreviews()
 for _,preview in previews do preview:Clear() end
 emoteMenuEffect:SetOpen(false,true)
 emoteButtonEffect.Reset()
end
local function updateReadiness(data)
 if not packet or data.courseVersion~=packet.courseVersion then return end
 readiness=data
 local ids={} for _,id in data.readyIds or {} do ids[id]=true end
 ownReady=ids[p.UserId]==true
 readyCount.Text=string.format("%d / %d READY",data.readyCount or 0,data.totalCount or 0)
 for i=1,6 do
  local row=canvas.Rows["Row"..i]
  local id=row:GetAttribute("UserId")
  row.ReadyState.Text=ids[id] and "READY" or (Players:GetPlayerByUserId(id or 0) and "..." or "LEFT")
  row.ReadyState.TextColor3=ids[id] and Color3.fromRGB(125,255,170) or Color3.fromRGB(210,225,255)
 end
end
local function populateEmotes(data)
 emoteOptions=data.options or emoteOptions
 selectedEmote=data.selected or selectedEmote
 for _,child in emoteList:GetChildren() do
  if child:IsA("ImageButton") and child~=emoteTemplate then child:Destroy() end
 end
 for i,option in emoteOptions do
  local button=emoteTemplate:Clone()
  button.Name="Option"..i button.Visible=true
  button:SetAttribute("EmoteKey",option.key)
  button:SetAttribute("Selected",option.key==selectedEmote)
  button.Label.Text=option.name
  button.Label.TextColor3=option.key==selectedEmote and Color3.fromRGB(255,232,116) or Color3.new(1,1,1)
  button.Parent=emoteList
  Effects.Button(button)
  button.Activated:Connect(function()
   if packet and phase=="Intermission" then
    event:FireServer("SelectRankingEmote",packet.courseVersion,option.key)
    emoteMenuEffect:SetOpen(false)
   end
  end)
 end
 layoutEmoteOptions()
 emoteButton:SetAttribute("SelectedEmote",selectedEmote)
end
emoteButton.Activated:Connect(function()
 if phase~="Intermission" then return end
 event:FireServer("RequestRankingEmotes")
 emoteMenuEffect:SetOpen(not emoteMenuEffect.Open)
 emoteButtonEffect.Shine()
end)

local barX,barY,barWidth,barHeight,markerSize=687,59,930,35,45
local function pos(v,x,y,w,h)
 v.Position=UDim2.fromOffset(x,y) v.Size=UDim2.fromOffset(w,h)
end
local function number(v)
 local str=string.format("%.2f",v or 0)
 return str:gsub("%.?0+$","")
end
local function duration(seconds)
 if seconds==nil then return "--:--.--" end
 local centiseconds=math.floor(seconds*100+.5)
 return string.format("%02d:%02d.%02d",math.floor(centiseconds/6000),math.floor(centiseconds/100)%60,centiseconds%100)
end
local function progress(row,fraction)
 fraction=math.clamp(fraction,0,1)
 pos(row.ProgressClip,barX,barY,barWidth*fraction,barHeight)
 pos(row.ProgressClip.Fill,0,0,barWidth,barHeight)
 local x=math.clamp(barX+barWidth*fraction,barX+markerSize/2,barX+barWidth-markerSize/2)
 pos(row.RoundPosition,x,barY-(markerSize-barHeight)/2,markerSize,markerSize)
 pos(row.RoundPosition.Placement,4,markerSize*.25,markerSize-8,markerSize*.5)
end
local function layout()
 local camera=workspace.CurrentCamera if not camera then return end
 local v=camera.ViewportSize
 compact=v.X<1000
 local width,height,scale
 if compact then
  width=720 scale=math.min(1,(v.X-20)/width)
  height=math.min(1100,(v.Y-30)/scale)
 else
  width=1707 height=821 scale=math.min((v.X-20)/width,(v.Y-20)/height,1)
 end
 canvas.Size=UDim2.fromOffset(width,height) canvas.Fit.Scale=math.max(.1,scale)
 canvas.BackgroundTransparency=compact and 0 or 1
 canvas.BackgroundColor3=Color3.fromRGB(67,109,208)
 canvas.Background.Size=UDim2.fromOffset(width,width*821/1707)
 if compact then
  pos(canvas.RoundTitle,305,0,405,65) canvas.RoundTitle.TextSize=31
  pos(canvas.Rows,0,92,width,math.max(100,height-230))
  canvas.Rows.CanvasSize=UDim2.fromOffset(0,(packet and #packet.rows or 6)*214)
  canvas.Rows.ScrollingEnabled=true canvas.Rows.ScrollBarThickness=5
  barX,barY,barWidth,barHeight,markerSize=216,128,466,32,52
  pos(canvas.Continue,20,height-68,width-40,55) canvas.Continue.TextSize=25
  pos(emoteButton,20,height-120,188,43) pos(readyCount,425,height-120,275,43)
  local panelSize=math.min(540,math.max(220,height-235))
  pos(emoteMenu,20,height-130,panelSize,panelSize*939/935)
 else
  pos(canvas.RoundTitle,735,15,900,100) canvas.RoundTitle.TextSize=65
  pos(canvas.Rows,0,168,width,599)
  canvas.Rows.CanvasSize=UDim2.fromOffset(0,(packet and #packet.rows or 6)*182)
  canvas.Rows.ScrollingEnabled=true canvas.Rows.ScrollBarThickness=5
  barX,barY,barWidth,barHeight,markerSize=687,59,930,35,45
  pos(canvas.Continue,1050,766,625,48) canvas.Continue.TextSize=28
  pos(emoteButton,28,766,210,48) pos(readyCount,605,766,420,48)
  pos(emoteMenu,28,194+550*939/935,550,550*939/935)
 end
 for i=1,6 do
  local row=canvas.Rows["Row"..i]
  if compact then
   pos(row,0,(i-1)*214,width,208)
   pos(row.OverallCard,10,0,185,56)
   pos(row.AvatarPlaceholder,73,57,122,122)
   pos(row.ReadyState,12,94,58,28)
   pos(row.TotalPoints,13,180,180,26) row.TotalPoints.TextSize=24
   pos(row.RowBackground,202,40,503,124)
   pos(row.PlayerPlate,210,42,475,44)
   pos(row.RoundPoints,218,42,90,38) row.RoundPoints.TextSize=30
   pos(row.RoundGain,320,48,90,26) row.RoundGain.TextSize=22
   pos(row.Username,432,47,246,28) row.Username.TextLimit.MaxTextSize=22
   pos(row.FinishTime,420,89,266,30) row.FinishTime.TextSize=24
   pos(row.BarTrack,211,121,477,48)
  else
   pos(row,0,(i-1)*182,width,176)
   pos(row.OverallCard,5,35,274,82)
   pos(row.AvatarPlaceholder,198,0,146,152)
   pos(row.ReadyState,198,154,146,22)
   pos(row.TotalPoints,28,93,163,24) row.TotalPoints.TextSize=17
   pos(row.RowBackground,357,55,1320,61)
   pos(row.PlayerPlate,412,57,274,44)
   pos(row.RoundPoints,434,51,94,42) row.RoundPoints.TextSize=32
   pos(row.RoundGain,435,96,92,20) row.RoundGain.TextSize=15
   pos(row.Username,540,59,140,28) row.Username.TextLimit.MaxTextSize=14
   pos(row.FinishTime,533,96,154,20) row.FinishTime.TextSize=16
   pos(row.BarTrack,683,51,950,50)
  end
  progress(row,fills[i] and fills[i].Value or 0)
 end
 task.defer(layoutEmoteOptions)
end
local function canContinue()
 return packet and workspace:GetServerTimeNow()>=(packet.continueAt or 0)
end
local lastReadyClick=0
local function continue()
 if not g.Enabled or leavePending or not canContinue() then return end
 if phase=="MatchComplete" then g.Enabled=false clearPreviews() return end
 if phase~="Intermission" or os.clock()-lastReadyClick<.25 then return end
 lastReadyClick=os.clock()
 event:FireServer("RankingsReady",packet.courseVersion,not ownReady)
end
local function show(data)
 local finalParticipant=false
 if typeof(data)=="table" and data.courseNumber and data.totalRounds and data.courseNumber>=data.totalRounds then
  for _,row in data.rows or {} do if row.userId==p.UserId then finalParticipant=true break end end
 end
 if p:GetAttribute("GBloxPodiumActive") or finalParticipant then g.Enabled=false clearPreviews() return end
 if typeof(data)~="table" or typeof(data.rows)~="table" then return end
 if lastShown==data.courseVersion then if data.readiness then updateReadiness(data.readiness) end return end
 lastShown=data.courseVersion packet=data phase="Intermission" ownReady=false
 clearPreviews()
 canvas.RoundTitle.Text=string.format("Round %d of %d",data.courseNumber,data.totalRounds)
 for _,t in tweens do t:Cancel() end table.clear(tweens)
 for i=1,6 do
  local row=canvas.Rows["Row"..i] local entry=data.rows[i]
  row.Visible=entry~=nil
  if entry then
   row:SetAttribute("UserId",entry.userId)
   row.AvatarPlaceholder:SetAttribute("UserId",entry.userId)
   previews[i]:Show(entry.userId,entry.emoteKey or "idle",entry.emoteAnimationId)
   row.OverallCard.Image=assets[(ordinals[entry.overallPlace] or "6th").." place (left HUD).png"]
   row.RoundPosition.Placement.Image=assets[(ordinals[entry.roundPlace] or "6th")..".png"]
   local plate=({"Gold Podium Player Label.png.png","Silver Podium Player Label.png.png","Bronze Podium Player Label.png"})[entry.roundPlace] or "Non-podium player label.png"
   row.PlayerPlate.Image=assets[plate]
   row.Username.Text=entry.username
   row.FinishTime.Text=duration(entry.finishTime)
   row.RoundPoints.Text=number(entry.roundScore)
   row.RoundGain.Text="+ "..number(entry.roundScore)
   row.TotalPoints.Text=number(entry.totalScore).." points"
   row:SetAttribute("TargetProgress",entry.finished and 1 or math.min(entry.progress or 0,.999))
   fills[i].Value=0
  end
 end
 canvas.Rows.CanvasPosition=Vector2.zero
 layout() g.Enabled=true
 leavePending=false leaveMessage.Text="" updateLeave()
 if data.readiness then updateReadiness(data.readiness) end
 event:FireServer("RequestRankingEmotes")
 for i=1,6 do
  local row=canvas.Rows["Row"..i]
  if row.Visible then
   local t=Tween:Create(fills[i],TweenInfo.new(1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,(i-1)*.07),{Value=row:GetAttribute("TargetProgress")})
   table.insert(tweens,t) t:Play()
  end
 end
end
for i=1,6 do
 local row=canvas.Rows["Row"..i]
 previews[i]=Preview.new(row.AvatarPlaceholder)
 make("TextLabel","ReadyState",row,{
  BackgroundTransparency=1,Text="...",Font=Enum.Font.Arcade,TextSize=14,
  TextColor3=Color3.new(1,1,1),ZIndex=8,
 })
 local v=Instance.new("NumberValue") v.Name="DisplayedProgress" v.Parent=canvas.Rows["Row"..i] fills[i]=v
 v:GetPropertyChangedSignal("Value"):Connect(function() progress(canvas.Rows["Row"..i],v.Value) end)
end
canvas.Continue.Activated:Connect(continue)
CAS:BindActionAtPriority("RankingsContinue",function(_,state)
 if not g.Enabled then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then continue() end
 return Enum.ContextActionResult.Sink
end,false,5000,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA)
g.ShowRankings.Event:Connect(show)
event.OnClientEvent:Connect(function(action,data)
 if action=="LeaveLobbyResult" then
  if packet and data.courseVersion==packet.courseVersion then
   leavePending=data.ok==true leaveMessage.Text=data.message or "" updateLeave()
  end
 elseif action=="RoundRankings" then show(data)
 elseif action=="RankingsReadiness" then updateReadiness(data)
 elseif action=="RankingEmoteOptions" then populateEmotes(data)
 elseif action=="RankingEmoteChanged" then
  if packet and data.courseVersion==packet.courseVersion then
   if data.userId==p.UserId then selectedEmote=data.key populateEmotes({selected=data.key}) end
   for i=1,6 do
    local row=canvas.Rows["Row"..i]
    if row:GetAttribute("UserId")==data.userId and g.Enabled then previews[i]:Show(data.userId,data.key,data.animationId) end
   end
  end
 elseif action=="State" then
  phase=data.phase
  updateLeave()
  if phase=="Running" or phase=="Countdown" or (packet and data.courseVersion~=packet.courseVersion) then
   g.Enabled=false clearPreviews()
  elseif phase=="AwaitingCourse" then
   canvas.Continue.Text="NEXT ROUND NOT BUILT YET"
  end
 end
end)
local cameraConnection
local function cameraChanged()
 if cameraConnection then cameraConnection:Disconnect() end
 if workspace.CurrentCamera then cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
 layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
task.spawn(function()
 while g.Parent do
  if g.Enabled then
   updateLeave()
   if canContinue() then
    if phase=="MatchComplete" then canvas.Continue.Text="CLOSE"
    elseif phase=="AwaitingCourse" then canvas.Continue.Text="NEXT ROUND NOT BUILT YET"
    elseif ownReady then canvas.Continue.Text="READY - WAITING FOR PLAYERS"
    else canvas.Continue.Text=Input.TouchEnabled and "TAP WHEN READY" or Input.GamepadEnabled and "PRESS A WHEN READY" or "READY - PRESS ENTER" end
    canvas.Continue.BackgroundColor3=ownReady and Color3.fromRGB(35,130,80) or Color3.fromRGB(24,80,135)
   else
    canvas.Continue.Text="Ready in "..math.max(0,math.ceil((packet.continueAt or 0)-workspace:GetServerTimeNow()))
   end
  end
  task.wait(.25)
 end
end)
g:GetPropertyChangedSignal("Enabled"):Connect(function() if not g.Enabled then clearPreviews() end updateLeave() end)
p:GetAttributeChangedSignal("RunnerCourseVersion"):Connect(updateLeave)
updateLeave()
p:GetAttributeChangedSignal("RankingEmotesLoaded"):Connect(function()
 if g.Enabled then task.delay(1.1,function() event:FireServer("RequestRankingEmotes") end) end
end)
event:FireServer("RequestRoundRankings")

