local gui=assert(game.StarterGui:FindFirstChild("TagHUD"),"Tag HUD missing")
local function authorNotices()
 for _,name in ipairs({"Protection","MoveMessage"}) do
  local notice=gui[name]
  notice.AnchorPoint=Vector2.new(0.5,1)
  notice.Position=UDim2.new(0.5,0,1,-126)
  notice.Size=UDim2.fromOffset(name=="Protection" and 240 or 280,16)
 end
 gui:SetAttribute("SprintLayoutVersion",2)
end
if gui:FindFirstChild("SprintPanel") then
 if (gui:GetAttribute("SprintLayoutVersion") or 0)<2 then authorNotices() return {preserved=true,noticesUpdated=true} end
 return {preserved=true}
end
local ink=Color3.fromRGB(24,35,62)
local blue=Color3.fromRGB(42,160,255)
local paper=Color3.fromRGB(255,250,226)
local headline=Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local body=Font.new("rbxasset://fonts/families/FredokaOne.json")
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name for key,value in pairs(props or {}) do o[key]=value end o.Parent=parent return o
end
local function finish(o,color)
 o.BackgroundColor3=color o.BorderSizePixel=0
 make("UICorner","Corner",o,{CornerRadius=UDim.new(0,12)})
 make("UIStroke","Outline",o,{Color=ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function text(parent,name,value,position,size,font,maximum)
 local o=make("TextLabel",name,parent,{Position=position,Size=size,Text=value,FontFace=font,TextColor3=ink,BackgroundTransparency=1,TextScaled=true,ZIndex=6})
 make("UITextSizeConstraint","TextLimit",o,{MinTextSize=9,MaxTextSize=maximum}) return o
end
local frame=make("Frame","SprintPanel",gui,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(280,100),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4,Visible=true})
local meter=make("Frame","Meter",frame,{Size=UDim2.new(1,0,0,44),ZIndex=5})
finish(meter,paper)
text(meter,"Role","RUNNER",UDim2.fromOffset(10,4),UDim2.new(0.55,0,0,17),headline,19).TextXAlignment=Enum.TextXAlignment.Left
text(meter,"Time","IT: 0.0s",UDim2.fromOffset(10,20),UDim2.new(0.55,0,0,12),body,11).TextXAlignment=Enum.TextXAlignment.Left
text(meter,"Charge","10.0s",UDim2.new(1,-94,0,6),UDim2.fromOffset(83,22),body,16).TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame","Track",meter,{Position=UDim2.fromOffset(10,34),Size=UDim2.new(1,-20,0,6),BackgroundColor3=Color3.fromRGB(195,211,211),BorderSizePixel=0,ZIndex=6})
make("UICorner","Corner",track,{CornerRadius=UDim.new(1,0)})
local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=7})
make("UICorner","Corner",fill,{CornerRadius=UDim.new(1,0)})
make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(0)})
local sprint=make("TextButton","Sprint",frame,{Position=UDim2.fromOffset(0,52),Size=UDim2.new(0.52,0,0,48),Text="SPRINT\nHOLD SHIFT",FontFace=headline,TextColor3=ink,TextScaled=true,ZIndex=5})
finish(sprint,blue)
make("UITextSizeConstraint","TextLimit",sprint,{MinTextSize=10,MaxTextSize=21})
local controls=gui.Controls
controls.AnchorPoint=Vector2.new(0.5,1)
controls.Position=UDim2.new(0.5,0,1,-18)
controls.Size=UDim2.fromOffset(280,48)
controls.ZIndex=5
for index,name in ipairs({"Vault","Dodge"}) do
 local button=controls[name]
 button.Position=UDim2.new(index==1 and 0.56 or 0.79,0,0,0)
 button.Size=UDim2.new(0.21,0,0,48)
 button.TextWrapped=true
 button.ZIndex=6
end
gui.Role.Visible=false
authorNotices()
return {created=true}
