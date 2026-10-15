local gui=assert(game:GetService("StarterGui"):FindFirstChild("PlaygroundShell"),"Editable Playground shell missing")
local function cameraSettings(viewport)
 local camera=viewport:FindFirstChild("Camera")
 if viewport:GetAttribute("PreviewCameraCFrame")==nil then viewport:SetAttribute("PreviewCameraCFrame",camera and camera.CFrame or CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))) end
 if viewport:GetAttribute("PreviewFieldOfView")==nil then viewport:SetAttribute("PreviewFieldOfView",camera and camera.FieldOfView or 32) end
end
for _,name in ipairs({"LevelPanel","CompactLevelPanel"}) do
 local panel=gui:FindFirstChild(name)
 local viewport=panel and panel:FindFirstChild("FacePreview")
 if viewport then cameraSettings(viewport) end
end
if gui:FindFirstChild("LevelPanel") then return {created=false,preserved=true} end
local ink=Color3.fromRGB(24,35,62)
local paper=Color3.fromRGB(255,250,226)
local yellow=Color3.fromRGB(255,204,54)
local blue=Color3.fromRGB(42,160,255)
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
 make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius)})
 make("UIStroke","Outline",object,{Thickness=thickness,Color=ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
end
local function label(parent,name,value,position,size,font,max)
 local object=make("TextLabel",name,parent,{Position=position,Size=size,BackgroundTransparency=1,BorderSizePixel=0,FontFace=font,Text=value,TextScaled=true,TextWrapped=true,TextColor3=ink,ZIndex=7})
 make("UITextSizeConstraint","TextLimit",object,{MinTextSize=8,MaxTextSize=max})
 return object
end
local function preview(parent,position,size)
 local viewport=make("ViewportFrame","FacePreview",parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(194,233,243),BorderSizePixel=0,Ambient=Color3.fromRGB(195,199,205),LightColor=Color3.fromRGB(255,255,255),LightDirection=Vector3.new(0.4,-1,0.5),ZIndex=7})
 finish(viewport,11,2)
 local world=make("WorldModel","World",viewport)
 local camera=make("Camera","Camera",viewport,{FieldOfView=32,CFrame=CFrame.lookAt(Vector3.new(0,0.15,-4.2),Vector3.new(0,0.15,0))})
 viewport.CurrentCamera=camera
 cameraSettings(viewport)
 local model=make("Model","AvatarPreview",world)
 local head=make("Part","Head",model,{Shape=Enum.PartType.Ball,Size=Vector3.new(1.8,1.6,1.5),Color=Color3.fromRGB(255,213,145),Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 model.PrimaryPart=head
 for _,side in ipairs({-1,1}) do make("Part","Eye",model,{Shape=Enum.PartType.Ball,Size=Vector3.new(0.15,0.18,0.10),Position=Vector3.new(side*0.33,0.18,-0.70),Color=ink,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false}) end
 make("Part","Smile",model,{Size=Vector3.new(0.28,0.08,0.08),Position=Vector3.new(0,-0.26,-0.75),Color=ink,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 return viewport
end
local function progress(parent,position,size)
 local track=make("Frame","XPTrack",parent,{Position=position,Size=size,BackgroundColor3=Color3.fromRGB(211,217,216),BorderSizePixel=0,ZIndex=7})
 finish(track,5,2)
 local fill=make("Frame","Fill",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=blue,BorderSizePixel=0,ZIndex=8})
 make("UICorner","Corner",fill,{CornerRadius=UDim.new(0,5)})
 make("UIGradient","Progress",fill,{Transparency=NumberSequence.new(1)})
end
local panel=make("Frame","LevelPanel",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,18,1,-82),Size=UDim2.fromOffset(264,80),BackgroundColor3=paper,BorderSizePixel=0,Visible=true,ZIndex=6})
finish(panel,16,4)
preview(panel,UDim2.fromOffset(9,10),UDim2.fromOffset(60,60))
local star=make("ImageLabel","LevelIcon",panel,{Position=UDim2.fromOffset(80,10),Size=UDim2.fromOffset(21,21),BackgroundTransparency=1,BorderSizePixel=0,Image="",ScaleType=Enum.ScaleType.Fit,ZIndex=7})
label(panel,"IconFallback","★",UDim2.fromOffset(80,8),UDim2.fromOffset(21,23),body,22).TextColor3=yellow
label(panel,"Level","LEVEL 1",UDim2.fromOffset(105,8),UDim2.fromOffset(147,26),headline,26).TextXAlignment=Enum.TextXAlignment.Left
label(panel,"XP","0 / 100 XP",UDim2.fromOffset(82,36),UDim2.fromOffset(171,17),body,15).TextXAlignment=Enum.TextXAlignment.Left
progress(panel,UDim2.fromOffset(82,59),UDim2.fromOffset(169,10))
local compact=make("Frame","CompactLevelPanel",gui,{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-201),Size=UDim2.fromOffset(115,52),BackgroundColor3=paper,BorderSizePixel=0,Visible=false,ZIndex=6})
finish(compact,11,3)
preview(compact,UDim2.fromOffset(5,5),UDim2.fromOffset(41,41))
label(compact,"Level","LV 1",UDim2.fromOffset(51,4),UDim2.fromOffset(60,20),headline,18).TextXAlignment=Enum.TextXAlignment.Left
label(compact,"XP","0 / 100",UDim2.fromOffset(51,24),UDim2.fromOffset(59,11),body,10).TextXAlignment=Enum.TextXAlignment.Left
progress(compact,UDim2.fromOffset(51,40),UDim2.fromOffset(56,6))
gui:SetAttribute("LevelLayoutVersion",1)
return {created=true,levelPanel=panel:GetFullName(),compactPanel=compact:GetFullName(),avatarViewports=2}
