local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local ContentProvider=game:GetService("ContentProvider")
local ProximityPromptService=game:GetService("ProximityPromptService")

local player=Players.LocalPlayer
local gui=script.Parent
local root=gui:WaitForChild("Root")
local slots=root:WaitForChild("Slots")
local header=root:WaitForChild("Header")
local instruction=root:WaitForChild("Instruction")
local flash=root:WaitForChild("Flash")
local tap=root:WaitForChild("TapCatcher")
local templates=gui:WaitForChild("Templates")
local remote=ReplicatedStorage:WaitForChild("GBloxEggRequest")
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))
local petTemplates=ReplicatedStorage:FindFirstChild("GBloxPetTemplates")

local queue={}
local holders={}
local busy=false
local locked=false
local state="idle"
local stage=1
local current
local generation=0
local destroyed=false
local clock=0
local assetElapsed=0
local effectConnection
local disabledPrompts={}
local controls
local tweens={}
local imageCache={}
local readyImages={}
local warmedThemes={}
local rng=Random.new()
local themes={
 Velocity=Color3.fromRGB(0,218,235),
 Gravity=Color3.fromRGB(180,121,255),
 Orbit=Color3.fromRGB(255,219,92),
}
local assetCache=Instance.new("Folder")
assetCache.Name="HatchImageCache"
assetCache.Parent=gui

local function active(token)
 return not destroyed and busy and token==generation
end

local function animate(object,info,properties)
 local tween=TweenService:Create(object,info,properties)
 table.insert(tweens,tween)
 tween:Play()
 return tween
end

local function preload(ids)
 local images={}
 for _,id in ids do
  if type(id)=="string" and id~="" and not imageCache[id] then
   local image=templates.CacheImage:Clone()
   image.Image=id
   image.Parent=assetCache
   imageCache[id]=image
   table.insert(images,image)
  end
 end
 if #images>0 then
  task.spawn(function()
   pcall(function()
    ContentProvider:PreloadAsync(images,function(id,status)
     if not destroyed then readyImages[id]=status==Enum.AssetFetchStatus.Success end
    end)
   end)
  end)
 end
end

local function imageReady(id)
 local image=imageCache[id]
 return image~=nil and (image.IsLoaded or readyImages[id]==true)
end

local function warmTheme(theme)
 if warmedThemes[theme] or type(Catalog.Opening[theme])~="table" then return end
 warmedThemes[theme]=true
 preload(Catalog.Opening[theme])
end

task.defer(function()
 local scripts=player:FindFirstChild("PlayerScripts")
 local module=scripts and scripts:FindFirstChild("PlayerModule")
 if not module then return end
 local ok,result=pcall(function() return require(module):GetControls() end)
 if ok and not destroyed then
  controls=result
  if busy then controls:Disable() end
 end
end)

local function setWorldPrompts(enabled)
 if not enabled then
  table.clear(disabledPrompts)
  for _,stand in CollectionService:GetTagged("GBloxEggStand") do
   if not stand:IsDescendantOf(workspace) then continue end
   for _,object in stand:GetDescendants() do
    if object:IsA("ProximityPrompt") and object.Enabled then
     table.insert(disabledPrompts,object)
     object.Enabled=false
    end
   end
  end
 else
  for _,prompt in disabledPrompts do
   if prompt.Parent then prompt.Enabled=true end
  end
  table.clear(disabledPrompts)
 end
end

local function clearHolders()
 if effectConnection then effectConnection:Disconnect() effectConnection=nil end
 for _,tween in tweens do tween:Cancel() end
 table.clear(tweens)
 for _,item in holders do item.Holder:Destroy() end
 table.clear(holders)
 flash.BackgroundTransparency=1
end

local function setEggStage(item,number)
 local images=Catalog.Opening[current.Theme]
 item.WantedEgg=images[number]
 local loaded
 for i=number,1,-1 do
  if imageReady(images[i]) then loaded=images[i] break end
 end
 if loaded then item.Egg.Image=loaded end
 item.Egg.Visible=item.Egg.Image~=""
 item.Fallback.Visible=not item.Egg.IsLoaded
 item.Fallback.Crack.Text=number>1 and string.rep("/",math.min(number-1,4)) or ""
end

local function makePetFallback(item)
 if item.FallbackBuilt then return end
 item.FallbackBuilt=true
 local source=petTemplates and petTemplates:FindFirstChild(item.Result.Id)
 if not source or not source:IsA("Model") then return end
 local ok,err=pcall(function()
  local model=source:Clone()
  model.Name="HatchedPet"
  model.Parent=item.Viewport.World
  for _,object in model:GetDescendants() do
   if object:IsA("LuaSourceContainer") or object:IsA("Sound") or object:IsA("ParticleEmitter")
    or object:IsA("Trail") or object:IsA("Beam") then
    object:Destroy()
   elseif object:IsA("BasePart") then
    object.Anchored=true
    object.CanCollide=false
    object.CanTouch=false
    object.CanQuery=false
   end
  end
  local cf,size=model:GetBoundingBox()
  model:PivotTo(CFrame.new(-cf.Position)*model:GetPivot())
  local camera=Instance.new("Camera")
  camera.FieldOfView=35
  local width=item.Viewport.AbsoluteSize.X
  local height=item.Viewport.AbsoluteSize.Y
  local aspect=height>0 and math.max(.3,width/height) or 1
  local extent=math.max(size.Y,size.X/aspect)
  local distance=extent*.65/math.tan(math.rad(camera.FieldOfView/2))+size.Z*.5
  camera.CFrame=CFrame.lookAt(Vector3.new(distance*.22,extent*.12,distance),Vector3.zero)
  camera.Parent=item.Viewport
  item.Viewport.CurrentCamera=camera
 end)
 if not ok then
  item.Viewport:FindFirstChild("World"):ClearAllChildren()
  warn("[GBloxHatch] Pet preview fallback:",err)
 end
end

local function burst(item,revealBurst)
 local count=revealBurst and 10 or 6
 for i=1,count do
  local particle=item.Particles[i]
  local angle=(i/count)*math.pi*2+rng:NextNumber(-.18,.18)
  particle.Start=clock
  particle.Duration=revealBurst and .8 or .4
  particle.Distance=revealBurst and rng:NextNumber(.25,.42) or rng:NextNumber(.1,.2)
  particle.Direction=Vector2.new(math.cos(angle),math.sin(angle))
  particle.Object.Position=UDim2.fromScale(.5,.45)
  particle.Object.Visible=true
  particle.Object.Rotation=rng:NextNumber(0,90)
 end
end

local function makeHolder(result,count,index)
 local holder=templates[count==1 and "SingleHatch" or "TripleHatch"]:Clone()
 holder.Name="Hatch"..index
 holder.LayoutOrder=index
 holder.Visible=true
 holder.Parent=slots
 local visual=holder.EggVisual
 local petVisual=holder.PetVisual
 local item={
  Holder=holder,Result=result,Visual=visual,Egg=visual.Egg,Fallback=visual.EggFallback,
  PetVisual=petVisual,Pet=petVisual.Pet,Viewport=petVisual.PetViewport,
  Spark=holder.Spark,Name=holder.PetName,Stats=holder.Stats,
  Particles={},Spin=index%2==0 and -1 or 1,
  EggPosition=visual.Position,EggRotation=visual.Rotation,Scale=visual.AnimatedScale,
  PetScale=petVisual.AnimatedScale,
 }
 item.Name.Text=string.upper(result.Id)
 item.Stats.Text=string.format("×%g CASH  •  ×%g TROPHIES",result.CashMultiplier,result.TrophyMultiplier)
 item.Pet.Image=Catalog.PetImages[result.Id] or ""
 item.Spark.Image=Catalog.Opening.Spark
 local color=themes[current.Theme] or themes.Velocity
 item.Fallback.Body.BackgroundColor3=color
 item.Fallback.Body.Outline.Color=color
 holder.Halo.Outline.Color=color
 petVisual.FallbackLabel.Text=string.upper(result.Id)
 for i=1,10 do
  local spark=templates.Sparkle:Clone()
  spark.Name="Sparkle"..i
  spark.Parent=holder
  for _,part in spark:GetChildren() do
   if part:IsA("Frame") then part.BackgroundColor3=color end
  end
  table.insert(item.Particles,{Object=spark})
 end
 table.insert(holders,item)
 setEggStage(item,1)
 return item
end

local function updateEffects(dt)
 clock+=dt
 assetElapsed+=dt
 local checkAssets=assetElapsed>=.1
 if checkAssets then assetElapsed=0 end
 for _,item in holders do
  if state=="cracking" then
   if checkAssets then setEggStage(item,stage) end
   local elapsed=clock-(item.ShakeStart or -10)
   if elapsed<.36 then
    local strength=(1-elapsed/.36)^2
    local wave=math.sin(elapsed*65)*strength
    item.Visual.Rotation=item.EggRotation+wave*(12+stage*2)*item.Spin
    item.Visual.Position=item.EggPosition+UDim2.fromOffset(wave*math.min(8,2+stage),0)
    item.Scale.Scale=1+strength*.07
   else
    item.Visual.Position=item.EggPosition
    item.Visual.Rotation=item.EggRotation
    item.Scale.Scale=1
   end
  elseif state=="revealing" or state=="complete" then
   item.Spark.Rotation=(item.Spark.Rotation+dt*38*item.Spin)%360
   if checkAssets then
    item.Viewport.Visible=not item.Pet.IsLoaded
    item.PetVisual.FallbackLabel.Visible=not item.Pet.IsLoaded
   end
  end
  for _,particle in item.Particles do
   if not particle.Start then continue end
   local age=(clock-particle.Start)/particle.Duration
   if age>=1 then
    particle.Object.Visible=false
    particle.Start=nil
   else
    local radius=(1-(1-age)^3)*particle.Distance
    particle.Object.Position=UDim2.fromScale(.5+particle.Direction.X*radius,.45+particle.Direction.Y*radius)
    particle.Object.Rotation+=dt*130*item.Spin
    particle.Object.AnimatedScale.Scale=.5+math.sin(age*math.pi)*.8
    for _,part in particle.Object:GetChildren() do
     if part:IsA("Frame") then part.BackgroundTransparency=age^2 end
    end
   end
  end
 end
end

local finishBatch
local function reveal(token)
 if not active(token) or state~="cracking" then return end
 state="revealing"
 root:SetAttribute("AnimationState",state)
 instruction.Text=""
 locked=true
 animate(flash,TweenInfo.new(.1,Enum.EasingStyle.Quad),{BackgroundTransparency=.72})
 for _,item in holders do
  item.Visual.Position=item.EggPosition
  item.Visual.Rotation=item.EggRotation
  item.Spark.Visible=true
  item.Holder.Halo.Visible=true
  burst(item,true)
  animate(item.Spark,TweenInfo.new(.25),{ImageTransparency=0})
  animate(item.Scale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Scale=.15})
  animate(item.Egg,TweenInfo.new(.22),{ImageTransparency=1})
 end
 task.wait(.12)
 if not active(token) then return end
 animate(flash,TweenInfo.new(.28),{BackgroundTransparency=1})
 task.wait(.18)
 if not active(token) then return end
 for _,item in holders do
  item.Visual.Visible=false
  item.PetVisual.Visible=true
  item.Pet.Visible=true
  if not item.Pet.IsLoaded then makePetFallback(item) end
  item.Viewport.Visible=not item.Pet.IsLoaded
  item.PetVisual.FallbackLabel.Visible=not item.Pet.IsLoaded
  animate(item.PetScale,TweenInfo.new(.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
 end
 task.wait(.42)
 if not active(token) then return end
 for _,item in holders do
  animate(item.Name,TweenInfo.new(.22),{TextTransparency=0,TextStrokeTransparency=0})
 end
 task.wait(.2)
 if not active(token) then return end
 for _,item in holders do animate(item.Stats,TweenInfo.new(.2),{TextTransparency=0}) end
 state="complete"
 root:SetAttribute("AnimationState",state)
 locked=false
 instruction.Text=current.Auto and "AUTO OPENING..." or "TAP TO CONTINUE"
 if current.Auto then task.delay(1.25,function() finishBatch(token) end) end
end

local function advance()
 if not busy or locked then return end
 local token=generation
 if state=="complete" then finishBatch(token) return end
 if state~="cracking" then return end
 local stages=Catalog.Opening[current.Theme]
 if stage>=#stages then return end
 locked=true
 stage+=1
 for _,item in holders do
  setEggStage(item,stage)
  item.ShakeStart=clock
  burst(item,false)
 end
 instruction.Text=stage<#stages and "TAP AGAIN!" or "HATCHING..."
 task.delay(.37,function() if active(token) and state=="cracking" then locked=false end end)
 if stage==#stages then task.delay(.4,function() reveal(token) end) end
end

local beginBatch
finishBatch=function(token)
 if not active(token) then return end
 busy=false
 generation+=1
 state="idle"
 locked=false
 root:SetAttribute("AnimationState",state)
 root.Visible=false
 clearHolders()
 setWorldPrompts(true)
 if controls then controls:Enable() end
 current=nil
 local nextPayload=table.remove(queue,1)
 if nextPayload and not destroyed then task.defer(function() beginBatch(nextPayload) end) end
end

beginBatch=function(payload)
 if destroyed then return end
 if busy then table.insert(queue,payload) return end
 generation+=1
 local token=generation
 busy=true
 locked=false
 current={Theme=payload.Theme,Results=payload.Results,Auto=payload.AutoActive==true}
 state="cracking"
 stage=1
 root:SetAttribute("AnimationState",state)
 clearHolders()
 header.Text=string.upper(payload.Theme).." EGG"
 instruction.Text=current.Auto and "AUTO CRACKING..." or "TAP ANYWHERE TO CRACK"
 root.Visible=true
 local ok,err=pcall(function()
  setWorldPrompts(false)
  if controls then controls:Disable() end
  warmTheme(payload.Theme)
  local ids={}
  for _,result in payload.Results do table.insert(ids,Catalog.PetImages[result.Id] or "") end
  preload(ids)
  for index,result in payload.Results do makeHolder(result,#payload.Results,index) end
  effectConnection=RunService.RenderStepped:Connect(updateEffects)
 end)
 if not ok then
  warn("[GBloxHatch] Visual setup:",err)
  finishBatch(token)
  return
 end
 if current.Auto then
  task.spawn(function()
   while active(token) and state=="cracking" do
    task.wait(.45)
    if not active(token) then return end
    advance()
   end
  end)
 end
end

local tapConnection=tap.Activated:Connect(advance)
local remoteConnection=remote.OnClientEvent:Connect(function(payload)
 if typeof(payload)~="table" or typeof(payload.Results)~="table" or #payload.Results<1 or #payload.Results>3 then return end
 if type(Catalog.Opening[payload.Theme])~="table" then return end
 for _,result in payload.Results do
  if type(result)~="table" or type(result.Id)~="string"
   or type(result.CashMultiplier)~="number" or type(result.TrophyMultiplier)~="number" then return end
 end
 beginBatch(payload)
end)
local promptConnection=ProximityPromptService.PromptShown:Connect(function(prompt)
 local theme=prompt:GetAttribute("EggTheme")
 if theme then warmTheme(theme) end
end)
script.Destroying:Connect(function()
 destroyed=true
 generation+=1
 busy=false
 remoteConnection:Disconnect()
 tapConnection:Disconnect()
 promptConnection:Disconnect()
 clearHolders()
 root.Visible=false
 setWorldPrompts(true)
 if controls then controls:Enable() end
 assetCache:Destroy()
end)

local initial={Catalog.Opening.Spark}
for theme in themes do
 local stages=Catalog.Opening[theme]
 if stages then table.insert(initial,stages[1]) end
end
preload(initial)

