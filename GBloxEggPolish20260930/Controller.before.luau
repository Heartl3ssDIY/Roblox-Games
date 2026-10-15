local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")

local player=Players.LocalPlayer
local gui=script.Parent
local root=gui:WaitForChild("Root")
local slots=root:WaitForChild("Slots")
local header=root:WaitForChild("Header")
local instruction=root:WaitForChild("Instruction")
local flash=root:WaitForChild("Flash")
local tap=root:WaitForChild("TapCatcher")
local remote=ReplicatedStorage:WaitForChild("GBloxEggRequest")
local Catalog=require(ReplicatedStorage:WaitForChild("GBloxPetCatalog"))

local queue={}
local holders={}
local busy=false
local locked=false
local state="idle"
local stage=1
local current
local spinConnection
local disabledPrompts={}
local controls
-- Custom character controllers may not install Roblox's PlayerModule.
-- Optional movement integration must never delay the hatch event listener.
task.defer(function()
 local scripts=player:FindFirstChild("PlayerScripts")
 local module=scripts and scripts:FindFirstChild("PlayerModule")
 if not module then return end
 local ok,result=pcall(function() return require(module):GetControls() end)
 if ok then
  controls=result
  if busy then controls:Disable() end
 end
end)

local function setWorldPrompts(enabled)
 if not enabled then
  table.clear(disabledPrompts)
  for _,stand in CollectionService:GetTagged("GBloxEggStand") do
   for _,object in stand:GetDescendants() do
    if object:IsA("ProximityPrompt") and object.Enabled then
     table.insert(disabledPrompts,object)
     object.Enabled=false
    end
   end
  end
 else
  for _,prompt in disabledPrompts do if prompt.Parent then prompt.Enabled=true end end
  table.clear(disabledPrompts)
 end
end

local function clearHolders()
 for _,object in slots:GetChildren() do
  if object:IsA("Frame") then object:Destroy() end
 end
 table.clear(holders)
end

local function makeHolder(result,count,index,eggImage)
 local holder=Instance.new("Frame")
 holder.Name="Hatch"..index holder.Size=UDim2.new(count==1 and .56 or .30,0,.96,0)
 holder.BackgroundTransparency=1 holder.LayoutOrder=index holder.ZIndex=4 holder.Parent=slots

 local spark=Instance.new("ImageLabel")
 spark.Name="Spark" spark.AnchorPoint=Vector2.new(.5,.5) spark.Position=UDim2.fromScale(.5,.47)
 spark.Size=UDim2.fromScale(.98,.9) spark.BackgroundTransparency=1
 spark.Image=Catalog.Opening.Spark spark.ImageTransparency=1 spark.ScaleType=Enum.ScaleType.Fit
 spark.Visible=false spark.ZIndex=5 spark.Parent=holder

 local egg=Instance.new("ImageLabel")
 egg.Name="Egg" egg.AnchorPoint=Vector2.new(.5,.5) egg.Position=UDim2.fromScale(.5,.47)
 egg.Size=UDim2.fromScale(.92,.82) egg.BackgroundTransparency=1
 egg.Image=eggImage egg.ScaleType=Enum.ScaleType.Fit egg.ZIndex=8 egg.Parent=holder

 local pet=Instance.new("ImageLabel")
 pet.Name="Pet" pet.AnchorPoint=Vector2.new(.5,.5) pet.Position=UDim2.fromScale(.5,.44)
 pet.Size=UDim2.fromScale(.05,.05) pet.BackgroundTransparency=1
 pet.Image=Catalog.PetImages[result.Id] or "" pet.ImageTransparency=1
 pet.ScaleType=Enum.ScaleType.Fit pet.Visible=false pet.ZIndex=9 pet.Parent=holder

 local name=Instance.new("TextLabel")
 name.Name="PetName" name.AnchorPoint=Vector2.new(.5,.5) name.Position=UDim2.fromScale(.5,.79)
 name.Size=UDim2.fromScale(.96,.13) name.BackgroundTransparency=1
 name.Text=string.upper(result.Id) name.TextColor3=Color3.new(1,1,1)
 name.TextStrokeColor3=Color3.fromRGB(0,224,235) name.TextStrokeTransparency=0
 name.Font=Enum.Font.Arcade name.TextScaled=true name.TextTransparency=1
 name.TextStrokeTransparency=1 name.ZIndex=10 name.Parent=holder
 local limit=Instance.new("UITextSizeConstraint")
 limit.MinTextSize=12 limit.MaxTextSize=count==1 and 42 or 25 limit.Parent=name

 local stats=Instance.new("TextLabel")
 stats.Name="Stats" stats.AnchorPoint=Vector2.new(.5,.5) stats.Position=UDim2.fromScale(.5,.9)
 stats.Size=UDim2.fromScale(.98,.1) stats.BackgroundTransparency=1
 stats.Text=string.format("×%g CASH  •  ×%g TROPHIES",result.CashMultiplier,result.TrophyMultiplier)
 stats.TextColor3=Color3.fromRGB(104,244,255) stats.TextStrokeColor3=Color3.fromRGB(0,18,30)
 stats.TextStrokeTransparency=0 stats.Font=Enum.Font.Arcade stats.TextScaled=true
 stats.TextTransparency=1 stats.ZIndex=10 stats.Parent=holder
 local statsLimit=Instance.new("UITextSizeConstraint")
 statsLimit.MinTextSize=8 statsLimit.MaxTextSize=count==1 and 24 or 15 statsLimit.Parent=stats

 local data={Holder=holder,Spark=spark,Egg=egg,Pet=pet,Name=name,Stats=stats,Spin=index%2==0 and -1 or 1}
 table.insert(holders,data)
 return data
end

local finishBatch
local function reveal()
 if state~="cracking" then return end
 state="revealing"
 root:SetAttribute("AnimationState",state)
 instruction.Text=""
 locked=true
 flash.BackgroundTransparency=1
 local flashIn=TweenService:Create(flash,TweenInfo.new(.1,Enum.EasingStyle.Quad),{BackgroundTransparency=.18})
 flashIn:Play()
 for _,item in holders do
  item.Spark.Visible=true
  TweenService:Create(item.Spark,TweenInfo.new(.25),{ImageTransparency=0}):Play()
  TweenService:Create(item.Egg,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),{
   ImageTransparency=1,
   Size=UDim2.fromScale(.2,.18),
  }):Play()
 end
 task.wait(.12)
 TweenService:Create(flash,TweenInfo.new(.28),{BackgroundTransparency=1}):Play()
 spinConnection=RunService.RenderStepped:Connect(function(dt)
  for _,item in holders do item.Spark.Rotation=(item.Spark.Rotation+dt*34*item.Spin)%360 end
 end)
 task.wait(.18)
 for _,item in holders do
  item.Pet.Visible=true
  TweenService:Create(item.Pet,TweenInfo.new(.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
   Size=UDim2.fromScale(.72,.62),
   ImageTransparency=0,
  }):Play()
 end
 task.wait(.42)
 for _,item in holders do
  TweenService:Create(item.Name,TweenInfo.new(.22),{TextTransparency=0,TextStrokeTransparency=0}):Play()
 end
 task.wait(.2)
 for _,item in holders do TweenService:Create(item.Stats,TweenInfo.new(.2),{TextTransparency=0}):Play() end
 state="complete"
 root:SetAttribute("AnimationState",state)
 locked=false
 instruction.Text=current.Auto and "AUTO OPENING..." or "TAP TO CONTINUE"
 if current.Auto then task.delay(1.25,finishBatch) end
end

local function shakeEggs()
 for index,item in holders do
  item.Egg.Rotation=(stage%2==0 and 7 or -7)*(index%2==0 and -1 or 1)
  item.Egg.Size=UDim2.fromScale(.98,.87)
  TweenService:Create(item.Egg,TweenInfo.new(.16,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
   Rotation=0,
   Size=UDim2.fromScale(.92,.82),
  }):Play()
 end
end

local function advance()
 if not busy or locked then return end
 if state=="complete" then finishBatch() return end
 if state~="cracking" then return end
 local stages=Catalog.Opening[current.Theme]
 if stage>=#stages then return end
 locked=true
 stage+=1
 for _,item in holders do item.Egg.Image=stages[stage] end
 shakeEggs()
 instruction.Text=stage<#stages and "TAP AGAIN!" or "HATCHING..."
 task.delay(.17,function() locked=false end)
 if stage==#stages then task.delay(.3,reveal) end
end

local function beginBatch(payload)
 busy=true
 current={Theme=payload.Theme,Results=payload.Results,Auto=payload.AutoActive==true}
 state="cracking"
 stage=1
 root:SetAttribute("AnimationState",state)
 clearHolders()
 header.Text=string.upper(payload.Theme).." EGG"
 instruction.Text=current.Auto and "AUTO CRACKING..." or "TAP ANYWHERE TO CRACK"
 root.Visible=true
 setWorldPrompts(false)
 if controls then controls:Disable() end
 local stages=Catalog.Opening[payload.Theme]
 for index,result in payload.Results do makeHolder(result,#payload.Results,index,stages[1]) end
 if current.Auto then
  task.spawn(function()
   while busy and current and current.Auto and state=="cracking" do
    task.wait(.34)
    advance()
   end
  end)
 end
end

finishBatch=function()
 if not busy then return end
 busy=false
 state="idle"
 root:SetAttribute("AnimationState",state)
 root.Visible=false
 if spinConnection then spinConnection:Disconnect() spinConnection=nil end
 clearHolders()
 setWorldPrompts(true)
 if controls then controls:Enable() end
 current=nil
 local nextPayload=table.remove(queue,1)
 if nextPayload then task.defer(beginBatch,nextPayload) end
end

tap.Activated:Connect(advance)
remote.OnClientEvent:Connect(function(payload)
 if typeof(payload)~="table" or typeof(payload.Results)~="table" or #payload.Results<1 then return end
 if not Catalog.Opening[payload.Theme] then return end
 if busy then table.insert(queue,payload) else beginBatch(payload) end
end)

