-- Presentation only: the owner's image assets remain unchanged.
local TweenService=game:GetService("TweenService")
local Effects={}
local function make(class,name,parent,properties)
 local object=Instance.new(class) object.Name=name
 for key,value in properties do object[key]=value end
 object.Parent=parent return object
end
local function gloss(target,isPanel)
 local inset=isPanel and .02 or .04
 local surface=make("Frame","GlossSweep",target,{
  BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0,BorderSizePixel=0,
  Position=UDim2.fromScale(inset,isPanel and .02 or .1),
  Size=UDim2.fromScale(1-inset*2,isPanel and .95 or .76),
  ZIndex=target.ZIndex,Active=false,
 })
 make("UICorner","SoftEdge",surface,{CornerRadius=UDim.new(isPanel and .025 or .24,0)})
 local gradient=make("UIGradient","Sweep",surface,{
  Rotation=20,Offset=Vector2.new(-1.4,0),
  Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,1),
   NumberSequenceKeypoint.new(.37,1),
   NumberSequenceKeypoint.new(.5,isPanel and .94 or .76),
   NumberSequenceKeypoint.new(.63,1),
   NumberSequenceKeypoint.new(1,1),
  }),
 })
 local tween
 local function reset()
  if tween then tween:Cancel() tween=nil end
  gradient.Offset=Vector2.new(-1.4,0)
 end
 local function shine()
  reset()
  tween=TweenService:Create(gradient,TweenInfo.new(.65,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Offset=Vector2.new(1.4,0)})
  tween:Play()
 end
 target.Destroying:Connect(reset)
 return shine,reset
end
function Effects.Button(button)
 button.AutoButtonColor=false
 local scale=make("UIScale","HoverPop",button,{Scale=1})
 local shine,resetGloss=gloss(button,false)
 local hovered,focused,pressed=false,false,false
 local tween
 local function animate(value)
  if tween then tween:Cancel() end
  tween=TweenService:Create(scale,TweenInfo.new(.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=value})
  tween:Play()
 end
 local function update()
  animate(pressed and .97 or ((hovered or focused) and 1.018 or 1))
 end
 button.MouseEnter:Connect(function() hovered=true update() shine() end)
 button.MouseLeave:Connect(function() hovered=false pressed=false update() end)
 button.SelectionGained:Connect(function() focused=true update() shine() end)
 button.SelectionLost:Connect(function() focused=false pressed=false update() end)
 button.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   pressed=true update() shine()
  end
 end)
 button.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
   pressed=false update()
  end
 end)
 local function reset()
  hovered=false focused=false pressed=false
  if tween then tween:Cancel() tween=nil end
  scale.Scale=1 resetGloss()
 end
 button.Destroying:Connect(reset)
 return {Shine=shine,Reset=reset}
end
function Effects.Panel(panel)
 local scale=make("UIScale","OpenPop",panel,{Scale=1})
 local shine,resetGloss=gloss(panel,true)
 local state={Open=false,Scale=scale}
 local tween,revision
 revision=0
 function state:SetOpen(open,immediate)
  self.Open=open
  revision+=1
  local current=revision
  if tween then tween:Cancel() tween=nil end
  if immediate then
   panel.Visible=open scale.Scale=1 resetGloss()
   return
  end
  if open then
   local wasVisible=panel.Visible
   panel.Visible=true
   if not wasVisible then scale.Scale=.88 end
   tween=TweenService:Create(scale,TweenInfo.new(.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
   tween:Play() shine()
  else
   resetGloss()
   tween=TweenService:Create(scale,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=.9})
   tween.Completed:Once(function(status)
    if revision==current and status==Enum.PlaybackState.Completed then
     panel.Visible=false scale.Scale=1
    end
   end)
   tween:Play()
  end
 end
 panel.Destroying:Connect(function()
  revision+=1
  if tween then tween:Cancel() end
  resetGloss()
 end)
 return state
end
return Effects

