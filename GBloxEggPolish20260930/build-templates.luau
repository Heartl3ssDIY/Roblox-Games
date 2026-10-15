local function frame(name,parent,position,size,z)
 local x=Instance.new("Frame")
 x.Name=name
 x.BackgroundTransparency=1
 x.AnchorPoint=Vector2.new(.5,.5)
 x.Position=position
 x.Size=size
 x.ZIndex=z or 5
 x.Parent=parent
 return x
end
local function image(name,parent,position,size,z)
 local x=Instance.new("ImageLabel")
 x.Name=name
 x.BackgroundTransparency=1
 x.AnchorPoint=Vector2.new(.5,.5)
 x.Position=position
 x.Size=size
 x.ScaleType=Enum.ScaleType.Fit
 x.ZIndex=z
 x.Parent=parent
 return x
end
local function outline(parent,color,thickness)
 local s=Instance.new("UIStroke")
 s.Name="Outline"
 s.Color=color
 s.Thickness=thickness
 s.Parent=parent
end
local function round(parent,radius)
 local c=Instance.new("UICorner")
 c.CornerRadius=UDim.new(radius or 1,0)
 c.Parent=parent
end
local function scale(parent,value)
 local s=Instance.new("UIScale")
 s.Name="AnimatedScale"
 s.Scale=value
 s.Parent=parent
end
local function text(name,parent,pos,size,z)
 local x=Instance.new("TextLabel")
 x.Name=name
 x.BackgroundTransparency=1
 x.AnchorPoint=Vector2.new(.5,.5)
 x.Position=pos
 x.Size=size
 x.ZIndex=z
 x.Font=Enum.Font.Arcade
 x.TextScaled=true
 x.TextColor3=Color3.new(1,1,1)
 x.TextStrokeColor3=Color3.fromRGB(0,18,30)
 x.TextStrokeTransparency=0
 x.Text=""
 x.Parent=parent
 return x
end
local templates=Instance.new("Folder")
templates.Name="Templates"
local cache=image("CacheImage",templates,UDim2.new(),UDim2.fromOffset(1,1),1)
cache.Visible=false
local sparkle=frame("Sparkle",templates,UDim2.fromScale(.5,.45),UDim2.fromOffset(15,15),11)
sparkle.Visible=false
scale(sparkle,1)
for _,spec in {{".Vertical",UDim2.fromScale(.24,1)},{".Horizontal",UDim2.fromScale(1,.24)}} do
 local bar=frame(spec[1],sparkle,UDim2.fromScale(.5,.5),spec[2],11)
 bar.BackgroundTransparency=0
 bar.BackgroundColor3=Color3.fromRGB(0,224,235)
 bar.Rotation=45
end
for _,spec in {{"SingleHatch",.56,42,24},{"TripleHatch",.30,25,15}} do
 local h=frame(spec[1],templates,UDim2.new(),UDim2.fromScale(spec[2],.96),4)
 h.AnchorPoint=Vector2.zero
 h.Visible=false
 local spark=image("Spark",h,UDim2.fromScale(.5,.47),UDim2.fromScale(.98,.9),5)
 spark.ImageTransparency=1
 spark.Visible=false
 local halo=frame("Halo",h,UDim2.fromScale(.5,.44),UDim2.fromScale(.65,.6),6)
 halo.Visible=false
 local a=Instance.new("UIAspectRatioConstraint")
 a.AspectRatio=1
 a.Parent=halo
 round(halo)
 outline(halo,Color3.fromRGB(0,224,235),2)
 local visual=frame("EggVisual",h,UDim2.fromScale(.5,.47),UDim2.fromScale(.92,.82),8)
 scale(visual,1)
 local fallback=frame("EggFallback",visual,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),8)
 local body=frame("Body",fallback,UDim2.fromScale(.5,.5),UDim2.fromScale(.75,.95),8)
 body.BackgroundTransparency=0
 body.BackgroundColor3=Color3.fromRGB(0,218,235)
 local aspect=Instance.new("UIAspectRatioConstraint")
 aspect.AspectRatio=.72
 aspect.Parent=body
 round(body,.48)
 outline(body,Color3.fromRGB(0,224,235),3)
 local gradient=Instance.new("UIGradient")
 gradient.Rotation=45
 gradient.Color=ColorSequence.new(Color3.fromRGB(197,255,255),Color3.fromRGB(14,74,109))
 gradient.Parent=body
 local shine=frame("Shine",body,UDim2.fromScale(.31,.28),UDim2.fromScale(.18,.27),8)
 shine.BackgroundTransparency=.4
 shine.BackgroundColor3=Color3.new(1,1,1)
 shine.Rotation=25
 round(shine)
 local crack=text("Crack",fallback,UDim2.fromScale(.5,.52),UDim2.fromScale(.5,.35),8)
 crack.TextColor3=Color3.fromRGB(8,27,43)
 crack.TextStrokeTransparency=1
 local egg=image("Egg",visual,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),9)
 local pv=frame("PetVisual",h,UDim2.fromScale(.5,.44),UDim2.fromScale(.72,.62),9)
 pv.Visible=false
 scale(pv,.08)
 local label=text("FallbackLabel",pv,UDim2.fromScale(.5,.5),UDim2.fromScale(.95,.15),9)
 local limit=Instance.new("UITextSizeConstraint")
 limit.MaxTextSize=spec[3]
 limit.MinTextSize=8
 limit.Parent=label
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="PetViewport"
 viewport.AnchorPoint=Vector2.new(.5,.5)
 viewport.Position=UDim2.fromScale(.5,.5)
 viewport.Size=UDim2.fromScale(1,1)
 viewport.BackgroundTransparency=1
 viewport.Ambient=Color3.fromRGB(220,235,255)
 viewport.LightColor=Color3.new(1,1,1)
 viewport.LightDirection=Vector3.new(-1,-1,-1)
 viewport.ZIndex=10
 viewport.Parent=pv
 local world=Instance.new("WorldModel")
 world.Name="World"
 world.Parent=viewport
 local pet=image("Pet",pv,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),11)
 local name=text("PetName",h,UDim2.fromScale(.5,.79),UDim2.fromScale(.96,.13),12)
 name.TextTransparency=1
 name.TextStrokeTransparency=1
 name.TextStrokeColor3=Color3.fromRGB(0,224,235)
 local nlimit=Instance.new("UITextSizeConstraint")
 nlimit.MinTextSize=8
 nlimit.MaxTextSize=spec[3]
 nlimit.Parent=name
 local stats=text("Stats",h,UDim2.fromScale(.5,.9),UDim2.fromScale(.98,.1),12)
 stats.TextColor3=Color3.fromRGB(104,244,255)
 stats.TextTransparency=1
 local slimit=Instance.new("UITextSizeConstraint")
 slimit.MinTextSize=8
 slimit.MaxTextSize=spec[4]
 slimit.Parent=stats
end
return templates
