local g=script.Parent
local panel=g.Panel
local player=game.Players.LocalPlayer
local SS=game:GetService("SoundService")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local remote=RS:WaitForChild("GBloxAudioSettings")
local lobby=game.PlaceId==74498603638770
local applyingSaved=false
local revision=0
local saveVersion=0
local groups={}
for _,kind in {"Music","SFX"} do
 local group=Instance.new("SoundGroup") group.Name="GBlox"..kind group.Parent=SS groups[kind]=group
end
local function route(sound)
 if not sound:IsA("Sound") then return end
 local kind=sound:GetAttribute("AudioCategory")
 if kind~="Music" and kind~="SFX" then
  kind="SFX"
  local ancestor=sound
  while ancestor and ancestor~=game do
   if ancestor.Name:lower():find("music",1,true) then kind="Music" break end
   ancestor=ancestor.Parent
  end
 end
 sound.SoundGroup=groups[kind]
end
for _,container in {workspace,SS,player:WaitForChild("PlayerGui")} do
 container.DescendantAdded:Connect(route)
 for _,sound in container:GetDescendants() do route(sound) end
end
for _,key in {"MusicEnabled","SFXEnabled"} do if player:GetAttribute(key)==nil then player:SetAttribute(key,true) end end
local function refreshAudio()
 for _,kind in {"Music","SFX"} do
  local enabled=player:GetAttribute(kind.."Enabled")~=false
  groups[kind].Volume=enabled and 1 or 0
  local button=panel[kind.."Toggle"]
  button.Text=enabled and "ON" or "OFF"
  button.BackgroundColor3=enabled and Color3.fromRGB(0,162,185) or Color3.fromRGB(55,72,83)
 end
end
local function queueSave()
 revision+=1 saveVersion+=1
 local version=saveVersion
 task.delay(1,function()
  if version~=saveVersion then return end
  local values={MusicEnabled=player:GetAttribute("MusicEnabled")~=false,SFXEnabled=player:GetAttribute("SFXEnabled")~=false}
  local ok,saved=pcall(function() return remote:InvokeServer("Save",values) end)
  if version==saveVersion then panel.Status.Text=ok and saved and "Audio settings saved" or "Applied for this session; saving unavailable" end
 end)
end
for _,kind in {"Music","SFX"} do
 player:GetAttributeChangedSignal(kind.."Enabled"):Connect(function()
  refreshAudio()
  if not applyingSaved then queueSave() end
 end)
 panel[kind.."Toggle"].Activated:Connect(function()
  player:SetAttribute(kind.."Enabled",player:GetAttribute(kind.."Enabled")==false)
 end)
end
refreshAudio()
task.spawn(function()
 local before=revision
 local initialMusic=player:GetAttribute("MusicEnabled")
 local initialSFX=player:GetAttribute("SFXEnabled")
 local ok,success,result=pcall(function() return remote:InvokeServer("Load") end)
 if ok and success and revision==before and player:GetAttribute("MusicEnabled")==initialMusic and player:GetAttribute("SFXEnabled")==initialSFX then
  applyingSaved=true
  player:SetAttribute("MusicEnabled",result.MusicEnabled)
  player:SetAttribute("SFXEnabled",result.SFXEnabled)
 end
 applyingSaved=false
 refreshAudio()
 -- Failed loads leave the local defaults untouched.
end)
local function otherPanelOpen()
 if player:GetAttribute("GBloxCommunityRewardsOpen") then return true end
 if player:GetAttribute("GBloxDailyRewardsOpen") or player:GetAttribute("GBloxPlaytimeRewardsOpen") then return true end
 local shop=player.PlayerGui:FindFirstChild("GBloxShopMockups")
 if shop and shop:FindFirstChild("Canvas") then
  for _,p in shop.Canvas:GetChildren() do if p:IsA("GuiObject") and p.Visible then return true end end
 end
 return false
end
local function updateLaunch()
 g.Settings.Visible=not panel.Visible and (not lobby or player:GetAttribute("GBloxLobbyReady")==true) and not otherPanelOpen()
end
local function open(show)
 if show then
  local shop=player.PlayerGui:FindFirstChild("GBloxShopMockups")
  if shop and shop:FindFirstChild("OpenPanel") then shop.OpenPanel:Fire(nil) end
 end
 panel.Visible=show g.Shade.Visible=show
 updateLaunch()
end
g.Settings.Activated:Connect(function() open(true) end)
panel.Close.Activated:Connect(function() open(false) end)
g.Shade.Activated:Connect(function() open(false) end)
g.OpenSettings.Event:Connect(function() open(true) end)
player:GetAttributeChangedSignal("GBloxLobbyReady"):Connect(updateLaunch)
player:GetAttributeChangedSignal("GBloxDailyRewardsOpen"):Connect(updateLaunch)
player:GetAttributeChangedSignal("GBloxPlaytimeRewardsOpen"):Connect(updateLaunch)
player:GetAttributeChangedSignal("GBloxCommunityRewardsOpen"):Connect(updateLaunch)
local function watchShop(shop)
 if shop.Name~="GBloxShopMockups" then return end
 local canvas=shop:WaitForChild("Canvas",5) if not canvas then return end
 for _,p in canvas:GetChildren() do if p:IsA("GuiObject") then
  p:GetPropertyChangedSignal("Visible"):Connect(function()
   if p.Visible and panel.Visible then open(false) end updateLaunch()
  end)
 end end
end
player.PlayerGui.ChildAdded:Connect(watchShop)
for _,child in player.PlayerGui:GetChildren() do task.spawn(watchShop,child) end
local cameraConnection
local function resize()
 local camera=workspace.CurrentCamera if not camera then return end
 local v=camera.ViewportSize
 local portrait=v.X<650 and v.Y>v.X
 local width=portrait and 420 or 560
 local height=portrait and 570 or 530
 panel.Size=UDim2.fromOffset(width,height)
 panel.Aspect.AspectRatio=width/height
 panel.ResponsiveScale.Scale=math.min(1,(v.X-28)/width,(v.Y-60)/height)
 panel.Title.Size=UDim2.fromOffset(width-110,48)
 panel.Title.TextSize=portrait and 26 or 32
 for _,kind in {"Music","SFX"} do
  panel[kind.."Toggle"].Position=UDim2.fromOffset(width-134,kind=="Music" and 100 or 166)
  panel[kind.."Toggle"].Size=UDim2.fromOffset(104,52)
  panel[kind.."Label"].Size=UDim2.fromOffset(width-174,52)
  panel[kind.."Label"].TextSize=portrait and 20 or (kind=="Music" and 26 or 23)
 end
 panel.ReplayTutorial.Size=UDim2.fromOffset(width-60,52)
 panel.ReplayTutorial.TextSize=portrait and 18 or 22
 panel.ReplayHint.Size=UDim2.fromOffset(width-60,34)
 panel.CodesTitle.Size=UDim2.fromOffset(width-115,44)
 panel.CodesTitle.TextSize=portrait and 20 or 24
 panel.CodeInput.Size=UDim2.fromOffset(width-236,52)
 panel.RedeemCode.Position=UDim2.fromOffset(width-190,402)
 panel.RedeemCode.Size=UDim2.fromOffset(160,52)
 panel.RedeemCode.TextSize=portrait and 18 or 22
 panel.Status.Size=UDim2.fromOffset(width-60,58)
 local size=v.X<650 and 44 or 52
 g.Settings.Size=UDim2.fromOffset(size,size)
 g.Settings.Position=UDim2.new(0,12,1,-12)
end
local function bindCamera()
 if cameraConnection then cameraConnection:Disconnect() end
 if workspace.CurrentCamera then cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
 resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
local replayBusy=false
panel.ReplayTutorial.Activated:Connect(function()
 if replayBusy then return end
 if not lobby then panel.Status.Text="Return to the lobby to replay the tutorial." return end
 replayBusy=true panel.Status.Text="Opening tutorial..."
 task.spawn(function()
  local gate=RS:FindFirstChild("GBloxTutorialGate")
  local ok,result=pcall(function() return gate and gate:InvokeServer("ReplayTutorial") end)
  panel.Status.Text=ok and result=="Teleporting" and "Teleporting..." or ok and result=="InParty" and "Leave your party before replaying." or ok and result=="StudioOnly" and "Test tutorial teleports in the published game." or "Could not teleport. Please try again."
  if not ok or result~="Teleporting" then replayBusy=false end
 end)
end)
if not lobby then panel.ReplayHint.Text="Replay is available from the G-Blox lobby." end
panel.RedeemCode.Activated:Connect(function() panel.Status.Text="Twitter codes are coming soon!" end)
local gate=RS:FindFirstChild("GBloxTutorialGate")
if gate then
 game:GetService("TeleportService").TeleportInitFailed:Connect(function(who)
  if who==player and replayBusy then replayBusy=false panel.Status.Text="Teleport failed. Please try again." end
 end)
end
open(false)

