local hud=game.StarterGui.ArenaHUD
local function make(class,name,parent,props)
 local o=Instance.new(class);o.Name=name
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent;return o
end
local function label(name,parent,x,y,w,h,text,size,z)
 return make("TextLabel",name,parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
 BackgroundTransparency=1,Text=text,TextSize=size,Font=Enum.Font.PermanentMarker,
 TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0,TextStrokeColor3=Color3.fromRGB(18,10,29),ZIndex=z or 110})
end
local old=hud:FindFirstChild("PauseOverlay");if old then old:Destroy() end
local overlay=make("TextButton","PauseOverlay",hud,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),
 BackgroundTransparency=.38,Text="",AutoButtonColor=false,Modal=true,Selectable=false,Visible=false,ZIndex=100})
local panel=make("ImageLabel","Panel",overlay,{Size=UDim2.fromOffset(520,540),Position=UDim2.fromScale(.5,.5),
 AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Image="rbxassetid://72544862064291",ZIndex=101})
make("UIScale","FitToScreen",panel,{Scale=1})
label("Title",panel,40,35,440,60,"Paused",43)
label("Subtitle",panel,40,93,440,32,"Tenkaichi · AI Match",18)
local template=make("TextButton","PauseAction",hud.Templates,{Size=UDim2.fromOffset(370,72),BackgroundColor3=Color3.fromRGB(58,188,49),
 BorderSizePixel=0,Text="",AutoButtonColor=false,Visible=false,ZIndex=110})
make("UICorner","Corner",template,{CornerRadius=UDim.new(0,15)})
make("UIStroke","Border",template,{Color=Color3.fromRGB(255,208,78),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
make("UIGradient","Gradient",template,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(115,115,145))})
local gloss=make("Frame","Gloss",template,{Position=UDim2.new(0,5,0,4),Size=UDim2.new(1,-10,.44,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=111})
make("UICorner","Corner",gloss,{CornerRadius=UDim.new(0,12)})
label("Label",template,8,0,354,72,"",29,112)
local function page(name)
 return make("Frame",name,panel,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=name=="Main",ZIndex=105})
end
local function button(name,parent,y,text,color)
 local o=template:Clone();o.Name=name;o.Visible=true;o.Position=UDim2.fromOffset(75,y)
 o.BackgroundColor3=color;o.Label.Text=text;o.Parent=parent;return o
end
local green=Color3.fromRGB(68,213,41)
local purple=Color3.fromRGB(132,63,208)
local red=Color3.fromRGB(195,48,65)
local main=page("Main")
local resume=button("Resume",main,157,"Resume",green)
local settings=button("Settings",main,250,"Settings",purple)
local quit=button("Quit",main,343,"Quit Match",red)
resume.NextSelectionDown=settings;resume.NextSelectionUp=quit
settings.NextSelectionDown=quit;settings.NextSelectionUp=resume
quit.NextSelectionDown=resume;quit.NextSelectionUp=settings
label("Hint",main,50,453,420,32,"Your battle is paused.",17)
local options=page("Settings")
button("Sounds",options,157,"UI Sounds: ON",purple)
button("Effects",options,250,"Battle Effects: ON",purple)
button("Back",options,343,"Back",green)
local confirmation=page("Confirm")
local warning=label("Warning",confirmation,65,147,390,100,"Forfeit this match?\nYou lose 1 arena win of progress.\nEarned rewards stay yours.",20)
warning.TextWrapped=true
button("Cancel",confirmation,278,"Keep Playing",green)
button("Confirm",confirmation,373,"Forfeit & Quit",red)
label("Error",panel,40,491,440,30,"",15).Visible=false
local exit=hud.LeaveArena
exit.Name="Pause"
exit.Text="Ⅱ  Pause"
exit.Font=Enum.Font.PermanentMarker;exit.TextSize=21;exit.TextColor3=Color3.new(1,1,1)
exit.TextStrokeTransparency=0
exit.Size=UDim2.fromOffset(150,42)
exit.BackgroundColor3=Color3.fromRGB(70,30,114)
for _,o in ipairs(exit:GetChildren()) do if o:IsA("UIStroke") then o.Color=Color3.fromRGB(255,203,66);o.Thickness=2 end end
return "Editable pause menu authored under ArenaHUD"
