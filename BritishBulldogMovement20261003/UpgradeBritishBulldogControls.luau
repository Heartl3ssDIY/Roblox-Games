local gui=assert(game:GetService("StarterGui"):FindFirstChild("BritishBulldogHUD"),"Editable British Bulldog HUD missing")
local existing=gui:FindFirstChild("MovementControls")
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local white=Color3.fromRGB(255,255,255)
local blue=Color3.fromRGB(42,160,255)
local red=Color3.fromRGB(255,81,92)
local yellow=Color3.fromRGB(255,204,54)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,properties)
 local object=Instance.new(class)
 object.Name=name
 for key,value in pairs(properties or {}) do object[key]=value end
 object.Parent=parent
 return object
end
local function finish(object,radius,thickness)
 make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius or 12)})
 make("UIStroke","Outline",object,{Thickness=thickness or 3,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function label(parent,name,value,position,size,font,max,z)
 local object=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font or body,TextColor3=ink,TextScaled=true,TextWrapped=true,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z or 5})
 make("UITextSizeConstraint","TextLimit",object,{MinTextSize=9,MaxTextSize=max or 23})
 return object
end
local function control(parent,name,value,position,size,color)
 local object=make("TextButton",name,parent,{Position=position,Size=size,Text="",AutoButtonColor=true,BackgroundColor3=color,BorderSizePixel=0,ZIndex=5})
 finish(object,12,3)
 label(object,"Caption",value,UDim2.new(0,33,0,2),UDim2.new(1,-38,1,-4),headline,21,6)
 local icon=make("ImageLabel","Icon",object,{Position=UDim2.fromOffset(7,8),Size=UDim2.fromOffset(25,25),BackgroundTransparency=1,BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Fit,ZIndex=6})
 label(object,"IconFallback",name=="Sprint" and "ϟ" or "↔",UDim2.fromOffset(5,5),UDim2.fromOffset(28,30),body,26,6)
 return object
end
local function addBoost(controls)
 if controls:FindFirstChild("EscapeBoost") then return end
 local badge=make("Frame","EscapeBoost",controls,{Position=UDim2.new(0.84,0,0,60),Size=UDim2.new(0.16,0,0,48),BackgroundColor3=yellow,BorderSizePixel=0,Visible=false,ZIndex=5})
 finish(badge,10,3)
 label(badge,"Caption","2×\nBOOST",UDim2.fromOffset(3,2),UDim2.new(1,-6,1,-4),headline,19,6)
end
local function addCompactDeparture()
 if gui:FindFirstChild("CompactDeparture") then return end
 local original=gui:FindFirstChild("Departure")
 if not original then return end
 local compact=original:Clone()
 compact.Name="CompactDeparture"
 compact.AnchorPoint=Vector2.new(0,1)
 compact.Position=UDim2.new(0,16,1,-140)
 compact.Size=UDim2.fromOffset(115,52)
 compact.Visible=false
 local limit=compact:FindFirstChildOfClass("UISizeConstraint")
 if limit then limit.MinSize=Vector2.new(115,52) limit.MaxSize=Vector2.new(115,52) end
 local prompt=compact.Panel.Prompt
 prompt.Text="LEAVE!"
 local textLimit=prompt:FindFirstChildOfClass("UITextSizeConstraint")
 if textLimit then textLimit.MinTextSize=9 textLimit.MaxTextSize=18 end
 compact.Parent=gui
end
addCompactDeparture()
if existing then addBoost(existing) return {created=false,preserved=true} end
local top=gui:FindFirstChild("TopCard")
local panel=top and top:FindFirstChild("Panel")
if panel then
 local bulldogs=panel:FindFirstChild("BulldogChip")
 local runners=panel:FindFirstChild("RunnerChip")
 if bulldogs and runners then
  bulldogs.BackgroundColor3=red
  runners.BackgroundColor3=blue
  if bulldogs.Position.X.Scale>runners.Position.X.Scale then local position=bulldogs.Position bulldogs.Position=runners.Position runners.Position=position end
 end
end
local controls=make("Frame","MovementControls",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.new(0.45,0,0,110),BackgroundTransparency=1,BorderSizePixel=0,Visible=true,ZIndex=4})
make("UISizeConstraint","SizeLimit",controls,{MinSize=Vector2.new(280,110),MaxSize=Vector2.new(375,110)})
local meter=make("Frame","Meter",controls,{Size=UDim2.new(1,0,0,48),BackgroundColor3=paper,BorderSizePixel=0,ZIndex=5})
finish(meter,13,4)
label(meter,"Role","RUNNER",UDim2.fromOffset(12,4),UDim2.new(0.52,0,0,18),headline,20,6).TextXAlignment=Enum.TextXAlignment.Left
label(meter,"Charge","10.0s / 10s",UDim2.new(1,-120,0,5),UDim2.fromOffset(107,17),body,15,6).TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame","Track",meter,{Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,10),BackgroundColor3=Color3.fromRGB(211,217,216),BorderSizePixel=0,ZIndex=6})
finish(track,6,2)
local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=7})
make("UICorner","Corner",fill,{CornerRadius=UDim.new(0,6)})
make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0),Rotation=0})
control(controls,"Sprint","SPRINT\nHOLD SHIFT",UDim2.fromOffset(0,60),UDim2.new(0.52,0,0,48),blue)
control(controls,"Dodge","DODGE\n[E]",UDim2.new(0.56,0,0,60),UDim2.new(0.25,0,0,48),yellow)
addBoost(controls)
local departure=gui:FindFirstChild("Departure")
if departure then departure.AnchorPoint=Vector2.new(0.5,1) departure.Position=UDim2.new(0.5,0,1,-146) end
local tagged=gui:FindFirstChild("Tagged")
if tagged then
 tagged.AnchorPoint=Vector2.new(0.5,1)
 tagged.Position=UDim2.new(0.5,0,1,-18)
 tagged.Size=UDim2.new(0.29,0,0,74)
 local sizeLimit=tagged:FindFirstChildOfClass("UISizeConstraint")
 if sizeLimit then sizeLimit.MinSize=Vector2.new(240,74) sizeLimit.MaxSize=Vector2.new(460,74) end
end
local oldRole=gui:FindFirstChild("RolePill")
if oldRole then oldRole.Visible=false end
gui.Enabled=true
gui:SetAttribute("MovementLayoutVersion",2)
return {created=true,controls=controls:GetFullName(),authoringVisible=gui.Enabled,layoutVersion=2}
