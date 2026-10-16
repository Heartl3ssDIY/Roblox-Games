local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local gui=script.Parent
local panel=gui:WaitForChild("LevelPanel")
local compact=gui:WaitForChild("CompactLevelPanel")
local panels={panel,compact}
local notice=gui:WaitForChild("LevelUpNotice")
local noticeScale=notice:WaitForChild("NoticeScale")
local noticeGeneration=0
local noticeTweens={}
local lastAnnouncedLevel=nil
local refreshPending=false
local connections={}
local alive=true
local previewGeneration=0
local previewCharacter=nil
local previewPending=false

for _,target in ipairs(panels) do
 local viewport=target:WaitForChild("FacePreview")
 local camera=viewport:FindFirstChild("Camera")
 if not camera then
  camera=Instance.new("Camera")
  camera.Name="Camera"
  camera.FieldOfView=viewport:GetAttribute("PreviewFieldOfView") or 32
  camera.CFrame=viewport:GetAttribute("PreviewCameraCFrame") or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))
  camera.Parent=viewport
 end
 viewport.CurrentCamera=camera
end

local function connect(signal,callback)
 local connection=signal:Connect(callback)
 table.insert(connections,connection)
 return connection
end

local function numberAttribute(name,fallback)
 local value=player:GetAttribute(name)
 return typeof(value)=="number" and value==value and math.abs(value)<math.huge and value or fallback
end

local function progress(gradient,fraction)
 fraction=math.clamp(fraction,0,1)
 if fraction<=0 then gradient.Transparency=NumberSequence.new(1)
 elseif fraction>=1 then gradient.Transparency=NumberSequence.new(0)
 else
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(math.max(0.0001,fraction-0.0001),0),NumberSequenceKeypoint.new(math.min(0.9999,fraction+0.0001),1),NumberSequenceKeypoint.new(1,1)})
 end
end

local function integerText(value)
 local text=string.format("%.0f",math.max(0,math.floor(value)))
 local formatted=text:reverse():gsub("(%d%d%d)","%1,"):reverse()
 return formatted:gsub("^,","")
end

local function clearNoticeTweens()
 for _,tween in ipairs(noticeTweens) do tween:Cancel() tween:Destroy() end
 table.clear(noticeTweens)
end

local function hideNotice()
 noticeGeneration+=1
 clearNoticeTweens()
 notice.Visible=false
 notice.GroupTransparency=1
 noticeScale.Scale=1
end

local function tweenNotice(object,duration,properties)
 local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
 table.insert(noticeTweens,tween)
 tween:Play()
end

local function announceLevel(level)
 local controls=gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")
 if controls and (controls:GetAttribute("UIHidden")==true or controls:GetAttribute("Spectating")==true or controls:GetAttribute("SessionMenuOpen")==true) then return end
 noticeGeneration+=1
 local generation=noticeGeneration
 clearNoticeTweens()
 notice.Level.Text="LEVEL "..integerText(level)
 notice.Title.Text="LEVEL UP!"
 notice.GroupTransparency=1
 noticeScale.Scale=0.92
 notice.Visible=true
 tweenNotice(notice,0.2,{GroupTransparency=0})
 tweenNotice(noticeScale,0.24,{Scale=1})
 local hold=notice:GetAttribute("HoldSeconds")
 if typeof(hold)~="number" or hold~=hold or math.abs(hold)==math.huge then hold=3 end
 task.delay(math.clamp(hold,1.5,6),function()
  if not alive or generation~=noticeGeneration or not notice.Parent then return end
  clearNoticeTweens()
  tweenNotice(notice,0.2,{GroupTransparency=1})
  task.delay(0.22,function()
   if alive and generation==noticeGeneration and notice.Parent then hideNotice() end
  end)
 end)
end

local function observeLevel(level,ready)
 if not ready then
  lastAnnouncedLevel=nil
  if notice.Visible then hideNotice() end
  return
 end
 if lastAnnouncedLevel==nil then lastAnnouncedLevel=level return end
 if level>lastAnnouncedLevel then
  lastAnnouncedLevel=level
  announceLevel(level)
 end
end

local function sanitize(object)
 for _,descendant in ipairs(object:GetDescendants()) do
  local keep=descendant:IsA("BasePart") or descendant:IsA("DataModelMesh") or descendant:IsA("Decal") or descendant:IsA("Texture")
   or descendant:IsA("SurfaceAppearance") or descendant:IsA("Attachment") or descendant:IsA("Bone")
  if not keep then descendant:Destroy() end
 end
 local parts={}
 if object:IsA("BasePart") then table.insert(parts,object) end
 for _,descendant in ipairs(object:GetDescendants()) do if descendant:IsA("BasePart") then table.insert(parts,descendant) end end
 for _,part in ipairs(parts) do part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false part.CastShadow=false end
 return parts
end

local function clonePart(source)
 local ok,clone=pcall(function() return source:Clone() end)
 return ok and clone or nil
end

local function rebuildPreview()
 if not alive then return end
 local character=player.Character
 local head=character and character:FindFirstChild("Head")
 if not head or not head:IsA("BasePart") then return end
 local generation=previewGeneration
 local headAttachments={}
 for _,attachment in ipairs(head:GetChildren()) do if attachment:IsA("Attachment") then headAttachments[attachment.Name]=true end end
 local prototype=Instance.new("Model")
 prototype.Name="AvatarPreview"
 local headClone=clonePart(head)
 if not headClone then prototype:Destroy() return end
 local headOrigin=head.CFrame
 local headParts=sanitize(headClone)
 for _,part in ipairs(headParts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
 headClone.Parent=prototype
 prototype.PrimaryPart=headClone
 for _,accessory in ipairs(character:GetChildren()) do
  if accessory:IsA("Accessory") then
   local handle=accessory:FindFirstChild("Handle")
   if handle and handle:IsA("BasePart") then
    local attachedToHead=false
    for _,attachment in ipairs(handle:GetChildren()) do
     if attachment:IsA("Attachment") and headAttachments[attachment.Name] then attachedToHead=true break end
     if attachment:IsA("Weld") and (attachment.Part0==head or attachment.Part1==head) then attachedToHead=true break end
    end
    if attachedToHead then
     local clone=clonePart(handle)
     if clone then
      clone.Name=accessory.Name
      local parts=sanitize(clone)
      for _,part in ipairs(parts) do part.CFrame=headOrigin:ToObjectSpace(part.CFrame) end
      clone.Parent=prototype
     end
    end
   end
  end
 end
 if not alive or generation~=previewGeneration or character~=player.Character then prototype:Destroy() return end
 for _,target in ipairs(panels) do
  local viewport=target.FacePreview
  local world=viewport.World
  local clone=prototype:Clone()
  if clone then
   local old=world:FindFirstChild("AvatarPreview")
   if old then old:Destroy() end
   clone.Parent=world
   viewport.CurrentCamera=viewport.Camera
  end
 end
 prototype:Destroy()
end

local function schedulePreview()
 if previewPending then return end
 previewPending=true
 task.delay(0.12,function()
  previewPending=false
  rebuildPreview()
 end)
end

local characterConnection=nil
local function bindCharacter(character)
 previewGeneration+=1
 previewCharacter=character
 if characterConnection then characterConnection:Disconnect() characterConnection=nil end
 if character then
  characterConnection=character.DescendantAdded:Connect(function(descendant)
   if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Attachment") or descendant:IsA("SpecialMesh") then schedulePreview() end
  end)
 end
 schedulePreview()
end

local function refresh()
 if not alive then return end
 local levelValue=numberAttribute("PCLevel",0)
 local ready=player:GetAttribute("PCDataReady")==true and levelValue>=1
 local level=math.max(1,math.floor(levelValue))
 local required=math.max(1,numberAttribute("PCLevelXPRequired",200+50*(level-1)))
 local xp=math.clamp(numberAttribute("PCLevelXP",0),0,required)
 panel.Level.Text=ready and "LEVEL "..integerText(level) or "LEVEL —"
 compact.Level.Text=ready and "LV "..integerText(level) or "LV —"
 panel.NextLevel.Text=ready and "NEXT: LEVEL "..integerText(level+1) or "LOADING PROGRESS"
 compact.NextLevel.Text=ready and "NEXT: LV "..integerText(level+1) or "LOADING"
 local xpText=ready and integerText(xp).." / "..integerText(required).." XP" or "Loading..."
 panel.XP.Text=xpText
 compact.XP.Text=xpText
 for _,target in ipairs(panels) do
  local fill=target.XPTrack.Fill
  progress(fill.Progress,ready and xp/required or 0)
  local skin=fill:FindFirstChild("ReusableSkin")
  local skinProgress=skin and skin:FindFirstChild("Progress")
  if skinProgress then skinProgress.Transparency=fill.Progress.Transparency end
 end
 observeLevel(level,ready)
 local shop=gui:FindFirstChild("ShopPanel")
 local vote=gui:FindFirstChild("VotePanel")
 local compactVote=gui:FindFirstChild("CompactVotePanel")
 local mudHUD=gui.Parent and gui.Parent:FindFirstChild("MudHUD")
 local palette=mudHUD and mudHUD:FindFirstChild("ColourPicker")
 local controls=gui.Parent and gui.Parent:FindFirstChild("PlaygroundSessionControls")
 local watching=controls and (controls:GetAttribute("Spectating")==true or controls:GetAttribute("UIHidden")==true or controls:GetAttribute("SessionMenuOpen")==true)
 local modal=watching or (shop and shop.Visible) or (vote and vote.Visible) or (compactVote and compactVote.Visible) or (mudHUD and mudHUD.Enabled and palette and palette.Visible)
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local narrow=viewport.X<=900 or math.min(viewport.X,viewport.Y)<=600
  or (math.min(viewport.X,viewport.Y)<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 local inGame=player:GetAttribute("BBParticipating")==true or player:GetAttribute("TGParticipating")==true or ( player:GetAttribute("MDParticipating") == true or player:GetAttribute("HSParticipating") == true or player:GetAttribute("DGParticipating") == true or player:GetAttribute("DGEliminated") == true or player:GetAttribute("SKParticipating") == true or player:GetAttribute("SKEliminated") == true )
 local useCompact=narrow
 if modal and notice.Visible then hideNotice() end
 panel.Visible=not modal and not useCompact
 compact.Visible=not modal and useCompact and not inGame
 if player.Character~=previewCharacter then bindCharacter(player.Character) end
end

local function scheduleRefresh()
 if refreshPending or not alive then return end
 refreshPending=true
 task.defer(function()
  refreshPending=false
  if alive then refresh() end
 end)
end

for _,name in ipairs({"PCXP","PCLevel","PCLevelXP","PCLevelXPRequired","PCDataReady","BBParticipating","TGParticipating","MDParticipating", "HSParticipating", "DGParticipating", "DGEliminated", "SKParticipating", "SKEliminated"}) do
 connect(player:GetAttributeChangedSignal(name),function()
  if name=="PCDataReady" and player:GetAttribute("PCDataReady")~=true then
   lastAnnouncedLevel=nil
   hideNotice()
  end
  scheduleRefresh()
 end)
end
local spectatorConnection
local function bindSpectatorControls(controls)
 if controls.Name~="PlaygroundSessionControls" then return end
 if spectatorConnection then spectatorConnection:Disconnect() end
 spectatorConnection=connect(controls.AttributeChanged,function(name)
  if name=="Spectating" or name=="UIHidden" or name=="SessionMenuOpen" then scheduleRefresh() end
 end)
 scheduleRefresh()
end
connect(player.PlayerGui.ChildAdded,bindSpectatorControls)
local sessionControls=player.PlayerGui:FindFirstChild("PlaygroundSessionControls")
if sessionControls then bindSpectatorControls(sessionControls) end
connect(player.CharacterAdded,bindCharacter)
connect(player.CharacterRemoving,function() bindCharacter(nil) end)
connect(player.CharacterAppearanceLoaded,function(character) if character==player.Character then schedulePreview() end end)
local elapsed=0
connect(RunService.Heartbeat,function(delta)
 elapsed+=delta
 if elapsed>=0.15 then elapsed=0 refresh() end
end)
local function cleanup()
 if not alive then return end
 alive=false
 hideNotice()
 previewGeneration+=1
 if characterConnection then characterConnection:Disconnect() end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
end
connect(script.Destroying,cleanup)
connect(gui.Destroying,cleanup)
hideNotice()
bindCharacter(player.Character)
refresh()
