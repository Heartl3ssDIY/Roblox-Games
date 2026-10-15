-- Client-only title polish. Original text, colour and outline remain untouched.
local RunService=game:GetService("RunService")
local Rules=require(script.Parent:WaitForChild("GBloxTitleRules"))
local E={}
local active={}
local heartbeat
local elapsed=0
local function visible(label)
 if not label:IsDescendantOf(game) then return false end
 local node=label
 while node and node~=game do
  if node:IsA("GuiObject") and not node.Visible then return false end
  if node:IsA("LayerCollector") and not node.Enabled then return false end
  if node:IsA("BillboardGui") then
   local camera=workspace.CurrentCamera
   local adornee=node.Adornee
   if camera and adornee and adornee:IsA("BasePart") and node.MaxDistance>0
    and (camera.CFrame.Position-adornee.Position).Magnitude>node.MaxDistance then return false end
  end
  node=node.Parent
 end
 return label.AbsoluteSize.X>0 and label.AbsoluteSize.Y>0
end
function E.Detach(label)
 local state=active[label]
 if not state then return end
 active[label]=nil
 for _,connection in state.connections do connection:Disconnect() end
 state.overlay:Destroy()
 if not next(active) and heartbeat then heartbeat:Disconnect() heartbeat=nil end
end
function E.IsHighTier(id)
 local def=Rules.ById[id]
 return def~=nil and type(def.Wins)=="number" and def.Wins>=5000
end
function E.Attach(label,id)
 if not label or not label:IsA("TextLabel") then return end
 if active[label] and active[label].id==id then return end
 E.Detach(label)
 if not E.IsHighTier(id) then return end
 local overlay=Instance.new("TextLabel")
 overlay.Name="GBloxTitleGloss"
 overlay.BackgroundTransparency=1 overlay.BorderSizePixel=0
 overlay.Position=UDim2.fromScale(0,0) overlay.Size=UDim2.fromScale(1,1)
 overlay.TextColor3=Color3.new(1,1,1) overlay.TextStrokeTransparency=1
 overlay.Active=false overlay.Selectable=false overlay.Visible=false
 local gradient=Instance.new("UIGradient")
 gradient.Rotation=18
 gradient.Transparency=NumberSequence.new({
  NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.39,1),
  NumberSequenceKeypoint.new(.5,.25),NumberSequenceKeypoint.new(.61,1),
  NumberSequenceKeypoint.new(1,1)})
 gradient.Parent=overlay
 local copied={Text=true,FontFace=true,TextSize=true,TextScaled=true,TextWrapped=true,
  TextXAlignment=true,TextYAlignment=true,RichText=true,TextTruncate=true,LineHeight=true}
 local function sync()
  for property in copied do overlay[property]=label[property] end
  overlay.ZIndex=label.ZIndex+1
  overlay.TextTransparency=label.TextTransparency
 end
 sync()
 for _,child in label:GetChildren() do
  if child:IsA("UITextSizeConstraint") or child:IsA("UIPadding") then child:Clone().Parent=overlay end
 end
 local sparks={}
 for i=1,(id=="BeyondInfinity" and 3 or 2) do
  local holder=Instance.new("Frame")
  holder.Name="Glitter"..i holder.BackgroundTransparency=1 holder.BorderSizePixel=0
  holder.AnchorPoint=Vector2.new(.5,.5)
  holder.Position=UDim2.fromScale(i/(id=="BeyondInfinity" and 4 or 3),i%2==0 and .25 or .7)
  holder.Size=UDim2.fromOffset(6,6) holder.ZIndex=overlay.ZIndex+1 holder.Parent=overlay
  for axis=1,2 do
   local line=Instance.new("Frame")
   line.Name="Ray"..axis line.BorderSizePixel=0 line.BackgroundColor3=Color3.fromRGB(240,255,255)
   line.AnchorPoint=Vector2.new(.5,.5) line.Position=UDim2.fromScale(.5,.5)
   line.Size=axis==1 and UDim2.new(1,0,0,1) or UDim2.new(0,1,1,0)
   line.BackgroundTransparency=1 line.ZIndex=holder.ZIndex line.Parent=holder
  end
  table.insert(sparks,holder)
 end
 overlay.Parent=label
 local state={id=id,overlay=overlay,gradient=gradient,sparks=sparks,connections={},phase=math.random()*4}
 active[label]=state
 table.insert(state.connections,label.Changed:Connect(function(property)
  if copied[property] or property=="ZIndex" or property=="TextTransparency" then sync() end
 end))
 table.insert(state.connections,label.Destroying:Connect(function() E.Detach(label) end))
 table.insert(state.connections,label.AncestryChanged:Connect(function(_,parent)
  if not parent then E.Detach(label) end
 end))
 if not heartbeat then
  heartbeat=RunService.Heartbeat:Connect(function(dt)
   elapsed+=dt
   if elapsed<.05 then return end
   elapsed=0
   local now=os.clock()
   for target,s in active do
    local shown=visible(target)
    s.overlay.Visible=shown
    if shown then
     local t=(now+s.phase)%4.8
     -- A single soft sweep followed by a quiet pause.
     s.gradient.Offset=Vector2.new(t<1.8 and (-1+2*t/1.8) or 1.2,0)
     for i,spark in s.sparks do
      local pulse=(now+s.phase+i*.83)%3.9
      local glow=pulse<1.25 and math.sin(pulse/1.25*math.pi)^2 or 0
      local size=(s.id=="BeyondInfinity" and 7 or 5)+glow*2
      spark.Size=UDim2.fromOffset(size,size)
      for _,ray in spark:GetChildren() do
       ray.BackgroundTransparency=1-glow*(s.id=="BeyondInfinity" and .8 or .6)*(1-target.TextTransparency)
      end
     end
    end
   end
  end)
 end
end
return E

