local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local root = Instance.new("Model")
root.Name = "Lobby_MainModeZone"
local rng = Random.new(2917)
local colors = {
	stone = Color3.fromRGB(178, 174, 157), edge = Color3.fromRGB(94, 107, 110),
	wood = Color3.fromRGB(91, 48, 39), red = Color3.fromRGB(154, 49, 42),
	roof = Color3.fromRGB(34, 64, 72), roofLight = Color3.fromRGB(49, 85, 88),
	gold = Color3.fromRGB(202, 163, 89), plaster = Color3.fromRGB(231, 219, 188),
	lamp = Color3.fromRGB(255, 203, 109), grass = Color3.fromRGB(69, 119, 79),
	leaf = Color3.fromRGB(60, 123, 85), pink = Color3.fromRGB(223, 121, 158),
}
local function folder(name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent or root
	return model
end
local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function block(parent, name, size, position, color, material, collide)
	return part(parent, name, size, CFrame.new(position), color, material, collide)
end
local function cylinder(parent, name, radius, height, position, color, material, collide)
	local p = part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function sphere(parent, name, position, size, color, material)
	local p = block(parent, name, size, position, color, material, false)
	p.Shape = Enum.PartType.Ball
	return p
end
local function beam(parent, name, a, b, width, depth, color, material, collide)
	local delta = b - a
	return part(parent, name, Vector3.new(width, depth, delta.Magnitude), CFrame.lookAt((a+b)/2, b), color, material, collide)
end
local function label(parent, text, cf, width, height, color, subtitle)
	local board = part(parent, "Sign_" .. text, Vector3.new(width, height, 0.4), cf, colors.wood, Enum.Material.Wood, false)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 65
	gui.LightInfluence = 0.15
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, subtitle and 0.64 or 1, -4)
	title.Position = UDim2.fromOffset(8, 2)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Bangers
	title.TextStrokeColor3 = Color3.fromRGB(48, 26, 23)
	title.TextStrokeTransparency = 0.65
	title.Text = text
	title.TextColor3 = color or colors.plaster
	title.TextScaled = true
	title.Parent = gui
	if subtitle then
		local sub = title:Clone()
		sub.Name = "Subtitle"
		sub.Position = UDim2.new(0, 8, 0.66, 0)
		sub.Size = UDim2.new(1, -16, 0.27, 0)
		sub.Text = subtitle
		sub.Font = Enum.Font.Oswald
		sub.TextStrokeTransparency = 1
		sub.TextColor3 = colors.plaster
		sub.Parent = gui
	end
	for _, y in ipairs({-height/2, height/2}) do
		part(parent, "SignTrim", Vector3.new(width+0.3, 0.14, 0.5), cf * CFrame.new(0, y, 0), colors.gold, Enum.Material.Metal, false)
	end
	return board
end
local function lantern(parent, cf, scale, hanging, lit)
	local size = scale or 1
	local lamp = part(parent, "PaperLantern", Vector3.new(1.4, 1.9, 1.4) * size, cf, colors.lamp, Enum.Material.Neon, false)
	lamp.Shape = Enum.PartType.Ball
	for _, y in ipairs({-0.9, 0.9}) do
		part(parent, "LanternCap", Vector3.new(1, 0.16, 1) * size, cf * CFrame.new(0,y*size,0), colors.wood, Enum.Material.Wood, false)
	end
	if hanging then
		part(parent, "HangingCord", Vector3.new(0.06,1.2,0.06)*size, cf*CFrame.new(0,1.6*size,0),colors.wood,nil,false)
		part(parent, "Tassel", Vector3.new(0.12,0.7,0.12)*size, cf*CFrame.new(0,-1.3*size,0),colors.red,Enum.Material.Fabric,false)
	end
	if lit then
		local light = Instance.new("PointLight")
		light.Color = colors.lamp
		light.Brightness = 0.8
		light.Range = 12 * size
		light.Shadows = false
		light.Parent = lamp
	end
end
local function roof(parent, cf, width, depth, ridge, name)
	local model = folder(name or "Roof", parent)
	local profile = {{0,ridge},{0.24,ridge-0.5},{0.5,ridge-1.65},{0.74,ridge-2.6},{0.9,ridge-2.85},{1,ridge-2.35}}
	for _, side in ipairs({-1,1}) do
		for i = 1, #profile-1 do
			local a,b = profile[i],profile[i+1]
			local p1 = Vector3.new(side * a[1] * depth / 2, a[2], 0)
			local p2 = Vector3.new(side * b[1] * depth / 2, b[2], 0)
			local dz,dy = p2.X-p1.X,p2.Y-p1.Y
			local angle = -math.atan2(dy,dz)
			if side < 0 then angle = angle + math.pi end
			local midZ = (p1.X+p2.X)/2
			local midY = (p1.Y+p2.Y)/2
			local segment = math.sqrt(dz*dz+dy*dy)
			part(model,"RoofPanel",Vector3.new(width,0.3,segment+0.07),cf*CFrame.new(0,midY,midZ)*CFrame.Angles(angle,0,0),colors.roof,Enum.Material.Slate,false)
			for x = -width/2, width/2, 1.6 do
				local start = cf:PointToWorldSpace(Vector3.new(x,p1.Y+0.2,p1.X))
				local finish = cf:PointToWorldSpace(Vector3.new(x,p2.Y+0.2,p2.X))
				beam(model,"TileRib",start,finish,0.13,0.13,colors.roofLight,Enum.Material.Slate,false)
			end
			for _, x in ipairs({-width/2,width/2}) do
				beam(model,"GableTrim",cf:PointToWorldSpace(Vector3.new(x,p1.Y,p1.X)),cf:PointToWorldSpace(Vector3.new(x,p2.Y,p2.X)),0.24,0.24,colors.gold,Enum.Material.Metal,false)
			end
		end
		part(model,"Eave",Vector3.new(width+0.8,0.32,0.36),cf*CFrame.new(0,ridge-2.35,side*depth/2),colors.red,Enum.Material.Wood,false)
	end
	part(model,"RidgeCap",Vector3.new(width+0.8,0.4,0.5),cf*CFrame.new(0,ridge+0.16,0),colors.roofLight,Enum.Material.Slate,false)
	for _, side in ipairs({-1,1}) do
		beam(model,"UpturnedRidge",cf:PointToWorldSpace(Vector3.new(side*width/2,ridge+0.1,0)),cf:PointToWorldSpace(Vector3.new(side*(width/2+1.2),ridge+1.25,0)),0.3,0.3,colors.gold,Enum.Material.Metal,false)
	end
	return model
end
local function window(parent, cf, width, height)
	part(parent,"PaperWindow",Vector3.new(width,height,0.2),cf,colors.plaster,Enum.Material.SmoothPlastic,false)
	for x=-width/2,width/2,1.1 do
		part(parent,"WindowLattice",Vector3.new(0.1,height+0.2,0.28),cf*CFrame.new(x,0,-0.12),colors.wood,Enum.Material.Wood,false)
	end
	for y=-height/2,height/2,1.2 do
		part(parent,"WindowLattice",Vector3.new(width+0.2,0.1,0.28),cf*CFrame.new(0,y,-0.12),colors.wood,Enum.Material.Wood,false)
	end
end
local function pavilion(name, position, width, depth, accent, subtitle, tall)
	local model = folder(name)
	local cf = CFrame.lookAt(position,Vector3.new(0,position.Y,5))
	local function p(n,s,x,y,z,c,m,collide)
		return part(model,n,s,cf*CFrame.new(x,y,z),c,m,collide)
	end
	p("StoneFoundation",Vector3.new(width+2,0.8,depth+2),0,0.4,0,colors.edge,Enum.Material.Slate,true)
	p("TimberFloor",Vector3.new(width,0.2,depth),0,0.9,0,colors.wood,Enum.Material.WoodPlanks,true)
	for i=1,3 do
		p("EntranceStep",Vector3.new(width*0.65,i*0.27,1.3),0,i*0.135,-depth/2-4+i*1.2,colors.stone,Enum.Material.Slate,true)
	end
	for _,x in ipairs({-width/2+0.8,width/2-0.8}) do
		for _,z in ipairs({-depth/2+0.6,depth/2-0.6}) do
			p("ColumnFoot",Vector3.new(1.6,1.1,1.6),x,1.3,z,colors.edge,Enum.Material.Slate,true)
			p("RedTimberColumn",Vector3.new(0.8,8.1,0.8),x,5.2,z,colors.red,Enum.Material.Wood,true)
			p("ColumnCollar",Vector3.new(1.12,0.27,1.12),x,8.3,z,colors.gold,Enum.Material.Metal,false)
			p("Bracket",Vector3.new(2.4,0.5,1.3),x,9,z,colors.red,Enum.Material.Wood,false)
		end
	end
	p("RearWall",Vector3.new(width-1,7.3,0.5),0,4.55,depth/2-0.5,colors.plaster,Enum.Material.Plaster,true)
	for _,side in ipairs({-1,1}) do
		p("SideWall",Vector3.new(0.5,6.8,depth-1),side*(width/2-0.5),4.3,0,colors.plaster,Enum.Material.Plaster,true)
		p("SideBeam",Vector3.new(0.65,0.4,depth),side*(width/2-0.5),3,0,colors.red,Enum.Material.Wood,false)
		p("FrontPanel",Vector3.new(width*0.22,6.6,0.45),side*width*0.36,4.2,-depth/2+0.5,colors.red,Enum.Material.Wood,true)
		window(model,cf*CFrame.new(side*width*0.36,5.2,-depth/2+0.15),width*0.18,3.8)
		lantern(model,cf*CFrame.new(side*width*0.33,8,-depth/2-1.3),0.85,true,true)
	end
	for _,z in ipairs({-depth/2,depth/2}) do
		p("Lintel",Vector3.new(width+1.8,0.6,0.8),0,9.15,z,colors.red,Enum.Material.Wood,false)
	end
	roof(model,cf,width+5,depth+5,12.6)
	label(model,name:upper(),cf*CFrame.new(0,8.6,-depth/2-0.8),width*0.55,2.3,accent,subtitle)
	if tall then
		p("UpperHall",Vector3.new(width*0.52,5.4,depth*0.56),0,14,0,colors.plaster,Enum.Material.Plaster,false)
		for _,x in ipairs({-width*0.26,width*0.26}) do
			p("UpperColumn",Vector3.new(0.7,5.8,depth*0.56+0.3),x,14,0,colors.red,Enum.Material.Wood,false)
		end
		window(model,cf*CFrame.new(0,14.2,-depth*0.28-0.15),width*0.4,3.5)
		roof(model,cf,width*0.65,depth*0.75,20,"UpperRoof")
	end
	return model, cf
end
local function ring(parent, name, radius, y, color, center)
	for i=1,48 do
		local angle=(i-0.5)*math.pi/24
		part(parent,name,Vector3.new(radius*math.pi/24+0.12,0.12,0.18),CFrame.new(center.X+math.sin(angle)*radius,y,center.Z+math.cos(angle)*radius)*CFrame.Angles(0,angle,0),color,Enum.Material.Metal,false)
	end
end
local function portal(parent, position, accent, name)
	cylinder(parent,"PortalBase",6.7,0.35,position,colors.edge,Enum.Material.Slate,true)
	cylinder(parent,"PortalInlay",5.9,0.08,position+Vector3.new(0,0.2,0),colors.stone,Enum.Material.Marble,false)
	ring(parent,"PortalLight",6.1,position.Y+0.27,accent,position)
	local marker=block(parent,name or "InteractionPoint",Vector3.new(1,1,1),position+Vector3.new(0,3,0),accent,nil,false)
	marker.Transparency=1
	return marker
end

local landscape=folder("Landscape")
cylinder(landscape,"IslandStone",84,8,Vector3.new(0,-4,0),colors.edge,Enum.Material.Rock,true)
cylinder(landscape,"GardenGround",82,1,Vector3.new(0,-0.1,0),colors.grass,Enum.Material.Grass,true)
local plaza=folder("Courtyard")
cylinder(plaza,"CourtyardBase",43,1,Vector3.new(0,0.5,4),colors.edge,Enum.Material.Slate,true)
cylinder(plaza,"CourtyardStone",42.5,0.15,Vector3.new(0,1.02,4),colors.stone,Enum.Material.Slate,false)
for i=1,48 do
	local angle=(i-0.5)*math.pi/24
	local cf=CFrame.new(math.sin(angle)*27.8,1.13,4+math.cos(angle)*27.8)*CFrame.Angles(0,angle,0)
	part(plaza,"RadialTimber",Vector3.new(3.53,0.12,11.2),cf,colors.wood,Enum.Material.WoodPlanks,false)
	part(plaza,"OuterPavingJoint",Vector3.new(0.08,0.025,8),CFrame.new(math.sin(angle)*38,1.11,4+math.cos(angle)*38)*CFrame.Angles(0,angle,0),colors.edge,Enum.Material.Slate,false)
end
for _,radius in ipairs({21.7,33.8,42.3}) do ring(plaza,"CourtyardInlay",radius,1.19,colors.gold,Vector3.new(0,0,4)) end
for x=-16,16,4 do for z=-12,20,4 do
	if Vector2.new(x,z-4).Magnitude<18 then
		block(plaza,"CourtyardPaver",Vector3.new(3.93,0.08,3.93),Vector3.new(x,1.14,z),colors.stone:Lerp(colors.plaster,rng:NextNumber(0,0.12)),Enum.Material.Slate,false)
	end
end end

local structures=folder("Pavilions")
local play,playCF=pavilion("Play",Vector3.new(0,1,-62),32,18,Color3.fromRGB(145,231,206),"STORY ARENAS",true)
play.Parent=structures
local shop,shopCF=pavilion("Shop",Vector3.new(-49,1,-20),24,16,colors.lamp,"PACKS & SUPPLIES",false)
shop.Parent=structures
local ranked,rankedCF=pavilion("Ranked",Vector3.new(49,1,-20),24,16,Color3.fromRGB(215,181,247),"SEASON HALL",true)
ranked.Parent=structures
local pvp,pvpCF=pavilion("PvP",Vector3.new(-47,1,34),24,16,Color3.fromRGB(255,149,128),"DUEL COURT",false)
pvp.Parent=structures
local clans,clanCF=pavilion("Clans",Vector3.new(47,1,34),24,16,Color3.fromRGB(146,218,182),"GUILD HOUSE",false)
clans.Parent=structures

local routes=folder("GardenPaths")
for _,cf in ipairs({playCF,shopCF,rankedCF,pvpCF,clanCF}) do
	local outside=cf:PointToWorldSpace(Vector3.new(0,0,-12))
	local direction=Vector3.new(outside.X,0,outside.Z-4).Unit
	local inside=Vector3.new(0,1,4)+direction*33
	local finish=Vector3.new(outside.X,1,outside.Z)
	beam(routes,"StoneWalk",inside,finish,11,0.4,colors.stone,Enum.Material.Slate,true)
	local delta=finish-inside
	local side=Vector3.new(-direction.Z,0,direction.X)
	for _,s in ipairs({-1,1}) do
		beam(routes,"WalkBorder",inside+side*5.6*s,finish+side*5.6*s,0.35,0.45,colors.edge,Enum.Material.Slate,true)
	end
	for d=2,delta.Magnitude,3 do
		beam(routes,"WalkJoint",inside+direction*d-side*5,inside+direction*d+side*5,0.05,0.04,colors.edge,Enum.Material.Slate,false)
	end
end

local playMarker=portal(root,Vector3.new(0,1.15,-47),Color3.fromRGB(86,202,177),"RingOuter")
playMarker.Position=Vector3.new(0,1.2,-47)
local modeSpawn=block(root,"MainModeSpawn",Vector3.new(1,0.2,1),Vector3.new(0,1.3,-44),colors.stone,nil,false)
modeSpawn.Transparency=1
local shopZone=folder("Lobby_PackShopZone")
local shopPoint=shopCF:PointToWorldSpace(Vector3.new(0,0.3,-12.5))
local shopMarker=portal(shopZone,shopPoint,colors.lamp,"PackShopTrigger")
local destinations=folder("Destinations")
for _,item in ipairs({{ranked,rankedCF,"Ranked",Color3.fromRGB(193,153,233)}, {pvp,pvpCF,"PvP",Color3.fromRGB(237,125,99)}, {clans,clanCF,"Clans",Color3.fromRGB(117,197,143)}}) do
	local marker=portal(destinations,item[2]:PointToWorldSpace(Vector3.new(0,0.3,-12.5)),item[4],item[3])
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="DestinationPrompt"
	prompt.ActionText="View "..item[3]
	prompt.ObjectText=item[3]=="Clans" and "Guild House" or item[3]=="PvP" and "Duel Court" or "Season Hall"
	prompt.MaxActivationDistance=10
	prompt.RequiresLineOfSight=false
	prompt.HoldDuration=0
	prompt.Parent=marker
end

local tree=folder("BlossomTree")
cylinder(tree,"TreePlanter",7.6,1.6,Vector3.new(0,1.65,4),colors.edge,Enum.Material.Slate,true)
cylinder(tree,"PlanterRim",7.9,0.25,Vector3.new(0,2.45,4),colors.gold,Enum.Material.Metal,false)
cylinder(tree,"Soil",7.2,0.1,Vector3.new(0,2.5,4),Color3.fromRGB(70,61,49),Enum.Material.Ground,false)
local trunkPoints={Vector3.new(0,2.6,4),Vector3.new(-0.8,8,4.4),Vector3.new(0.2,13,3.5),Vector3.new(-1,18,4)}
for i=1,#trunkPoints-1 do
	beam(tree,"Trunk",trunkPoints[i],trunkPoints[i+1],3-i*0.45,3-i*0.45,colors.wood,Enum.Material.Wood,true)
end
for i=1,10 do
	local angle=i*math.pi*0.2
	local origin=Vector3.new(0,10+rng:NextNumber(0,6),4)
	local reach=rng:NextNumber(7,12)
	local tip=Vector3.new(math.cos(angle)*reach,18+rng:NextNumber(-1,4),4+math.sin(angle)*reach)
	local elbow=origin:Lerp(tip,0.6)+Vector3.new(0,1,0)
	beam(tree,"Branch",origin,elbow,0.9,0.9,colors.wood,Enum.Material.Wood,false)
	beam(tree,"Twig",elbow,tip,0.45,0.45,colors.wood,Enum.Material.Wood,false)
	for k=1,4 do
		local point=tip+Vector3.new(rng:NextNumber(-3,3),rng:NextNumber(-1.5,2),rng:NextNumber(-3,3))
		local size=Vector3.new(rng:NextNumber(5,8),rng:NextNumber(3.2,5),rng:NextNumber(5,8))
		sphere(tree,"BlossomCanopy",point,size,colors.pink:Lerp(Color3.fromRGB(251,191,192),rng:NextNumber(0,0.8)),Enum.Material.SmoothPlastic)
	end
	if i%2==0 then lantern(tree,CFrame.new(tip-Vector3.new(0,4,0)),0.65,true,false) end
end
for i=1,8 do
	local a=i*math.pi/4
	beam(tree,"SurfaceRoot",Vector3.new(0,2.75,4),Vector3.new(math.cos(a)*5,2.6,4+math.sin(a)*5),0.45,0.35,colors.wood,Enum.Material.Wood,false)
end
for i=1,22 do
	local a=rng:NextNumber(0,math.pi*2) local r=rng:NextNumber(8.5,17)
	part(tree,"FallenPetal",Vector3.new(0.22,0.035,0.45),CFrame.new(math.sin(a)*r,1.24,4+math.cos(a)*r)*CFrame.Angles(0,a,0),colors.pink,nil,false)
end

local decor=folder("GardenDetails")
local function rock(position,scale)
	local p=part(decor,"GardenRock",Vector3.new(2.8,2,2.2)*scale,CFrame.new(position)*CFrame.Angles(rng:NextNumber(-0.3,0.3),rng:NextNumber(0,6.28),rng:NextNumber(-0.25,0.25)),colors.edge:Lerp(colors.stone,rng:NextNumber(0,0.4)),Enum.Material.Rock,true)
	p.Shape=Enum.PartType.Ball
end
local function bamboo(position)
	local height=rng:NextNumber(8,13)
	block(decor,"BambooStem",Vector3.new(0.28,height,0.28),position+Vector3.new(0,height/2,0),Color3.fromRGB(91,147,83),Enum.Material.Wood,false)
	for y=2,height,2 do
		block(decor,"BambooNode",Vector3.new(0.36,0.12,0.36),position+Vector3.new(0,y,0),Color3.fromRGB(145,174,102),nil,false)
	end
	for j=1,3 do
		local yaw=rng:NextNumber(0,6.28)
		part(decor,"BambooLeaf",Vector3.new(0.5,0.06,3),CFrame.new(position+Vector3.new(math.sin(yaw),height-j*0.8,math.cos(yaw)))*CFrame.Angles(-0.3,yaw,0),colors.leaf,Enum.Material.Grass,false)
	end
end
for _,center in ipairs({Vector3.new(-31,0,7),Vector3.new(31,0,7),Vector3.new(-23,0,-45),Vector3.new(23,0,-45),Vector3.new(-64,0,9),Vector3.new(64,0,9),Vector3.new(-24,0,56),Vector3.new(24,0,56)}) do
	for j=1,3 do rock(center+Vector3.new(rng:NextNumber(-3,3),1,rng:NextNumber(-3,3)),rng:NextNumber(0.8,1.5)) end
	for j=1,5 do bamboo(center+Vector3.new(rng:NextNumber(-4,4),0.5,rng:NextNumber(-4,4))) end
	for j=1,4 do sphere(decor,"Shrub",center+Vector3.new(rng:NextNumber(-4,4),1.4,rng:NextNumber(-4,4)),Vector3.new(4,2.5,3.5),colors.leaf:Lerp(colors.grass,rng:NextNumber()),Enum.Material.Grass) end
end
for i=1,12 do
	local a=i*math.pi/6
	local position=Vector3.new(math.sin(a)*39,1.2,4+math.cos(a)*39)
	cylinder(decor,"LanternBase",0.85,0.35,position,colors.edge,Enum.Material.Slate,true)
	block(decor,"LanternPost",Vector3.new(0.25,3.8,0.25),position+Vector3.new(0,2,0),colors.wood,Enum.Material.Wood,true)
	lantern(decor,CFrame.new(position+Vector3.new(0,4.5,0)),0.65,false,true)
end
for _,angle in ipairs({-1.1,1.1,2.2,-2.2}) do
	local cf=CFrame.new(math.sin(angle)*18,1.3,4+math.cos(angle)*18)*CFrame.Angles(0,angle,0)
	for _,x in ipairs({-2.5,2.5}) do part(decor,"BenchFoot",Vector3.new(0.6,1.2,1.7),cf*CFrame.new(x,0.6,0),colors.edge,Enum.Material.Slate,true) end
	part(decor,"BenchSeat",Vector3.new(7,0.3,2),cf*CFrame.new(0,1.2,0),colors.wood,Enum.Material.WoodPlanks,true)
	part(decor,"BenchBack",Vector3.new(7,1.1,0.25),cf*CFrame.new(0,2,0.8),colors.wood,Enum.Material.Wood,true)
end
for _,cf in ipairs({shopCF,pvpCF,clanCF}) do
	for _,x in ipairs({-4,4}) do
		part(decor,"StorageChest",Vector3.new(2.8,1.6,1.8),cf*CFrame.new(x,1.85,5.2),colors.wood,Enum.Material.WoodPlanks,true)
		for _,dx in ipairs({-0.9,0.9}) do part(decor,"ChestBand",Vector3.new(0.15,1.68,1.88),cf*CFrame.new(x+dx,1.85,5.2),colors.gold,Enum.Material.Metal,false) end
	end
end
label(ranked,"SEASON 01",rankedCF*CFrame.new(0,5.3,6.7),10,3.8,colors.gold,"RANKED · COMING SOON")
label(pvp,"CHALLENGE COURT",pvpCF*CFrame.new(0,5.3,6.7),13,3.8,Color3.fromRGB(244,156,132),"PvP · COMING SOON")
label(clans,"FIND YOUR CLAN",clanCF*CFrame.new(0,5.3,6.7),13,3.8,Color3.fromRGB(156,226,177),"CLANS · COMING SOON")
label(shop,"CARD PACKS",shopCF*CFrame.new(0,5.3,6.7),12,3.8,colors.lamp,"BUILD YOUR TEAM")

local pond=folder("ReflectionGarden")
cylinder(pond,"PondBasin",12,0.6,Vector3.new(0,0.4,61),colors.edge,Enum.Material.Slate,true)
local water=cylinder(pond,"Water",11.5,0.15,Vector3.new(0,0.8,61),Color3.fromRGB(58,148,158),Enum.Material.Glass,false)
water.Transparency=0.18 water.Reflectance=0.15
for i=1,16 do local a=i*math.pi/8 rock(Vector3.new(math.sin(a)*12,1,61+math.cos(a)*12),0.85) end
for i=1,6 do
	local pos=Vector3.new(rng:NextNumber(-7,7),0.94,61+rng:NextNumber(-7,7))
	cylinder(pond,"LilyPad",0.8,0.04,pos,colors.leaf,Enum.Material.Grass,false)
	sphere(pond,"Lotus",pos+Vector3.new(0,0.22,0),Vector3.new(0.7,0.4,0.7),colors.pink,nil)
end

local boundary=folder("Boundary")
for i=1,64 do
	local angle=i*math.pi/32
	local p=Vector3.new(math.sin(angle)*80,1,math.cos(angle)*80)
	local cf=CFrame.new(p)*CFrame.Angles(0,angle,0)
	part(boundary,"StoneCoping",Vector3.new(8,1.2,1.4),cf,colors.edge,Enum.Material.Slate,true)
	if i%2==0 then
		part(boundary,"WallPost",Vector3.new(1.5,3.8,1.5),cf*CFrame.new(0,1.8,0),colors.stone,Enum.Material.Slate,true)
		part(boundary,"PostCap",Vector3.new(2,0.35,2),cf*CFrame.new(0,3.8,0),colors.roof,Enum.Material.Slate,false)
	end
	part(boundary,"TimberRail",Vector3.new(8,0.3,0.35),cf*CFrame.new(0,2.5,0),colors.red,Enum.Material.Wood,true)
	local invisible=part(boundary,"SafetyWall",Vector3.new(8.5,15,1),cf*CFrame.new(0,7,0),colors.edge,nil,true)
	invisible.Transparency=1
end
local backdrop=folder("DistantCliffs")
for i=1,18 do
	local angle=i*math.pi/9
	local distance=rng:NextNumber(115,150)
	local height=rng:NextNumber(24,57)
	local position=Vector3.new(math.sin(angle)*distance,height/2-9,math.cos(angle)*distance)
	local cliff=part(backdrop,"Cliff",Vector3.new(rng:NextNumber(14,24),height,rng:NextNumber(13,24)),CFrame.new(position)*CFrame.Angles(0,angle,0),Color3.fromRGB(99,135,134),Enum.Material.Rock,false)
	part(backdrop,"MossCrown",Vector3.new(cliff.Size.X+0.3,1.5,cliff.Size.Z+0.3),cliff.CFrame*CFrame.new(0,height/2,0),colors.grass,Enum.Material.Grass,false)
	for _,y in ipairs({-height*0.2,height*0.1}) do part(backdrop,"RockStratum",Vector3.new(cliff.Size.X+0.8,0.8,cliff.Size.Z+0.8),cliff.CFrame*CFrame.new(0,y,0),Color3.fromRGB(129,153,143),Enum.Material.Rock,false) end
end

local spawn=Instance.new("SpawnLocation")
spawn.Name="SpawnLocation"
spawn.Size=Vector3.new(7,0.2,7)
spawn.CFrame=CFrame.new(0,1.2,40)
spawn.Anchored=true spawn.Neutral=true spawn.Duration=0 spawn.Transparency=1
spawn.CanCollide=false spawn.CanTouch=false
spawn.Parent=root
ring(plaza,"SpawnInlay",4,1.2,colors.gold,Vector3.new(0,0,40))
label(decor,"ANIME COMBAT UNITS",CFrame.new(0,4,48),18,2.5,colors.gold,"DRAFT · BATTLE · ASCEND")

local backup=ServerStorage:FindFirstChild("BeforeCourtyard_20260917")
if not backup then
	backup=Instance.new("Folder") backup.Name="BeforeCourtyard_20260917" backup.Parent=ServerStorage
	local old=workspace:FindFirstChild("Lobby_MainModeZone")
	if old then local copy=old:Clone() copy.Parent=backup end
	local lightingBackup=Instance.new("Folder") lightingBackup.Name="Lighting" lightingBackup.Parent=backup
	for _,v in ipairs(Lighting:GetChildren()) do v:Clone().Parent=lightingBackup end
	for _,name in ipairs({"ClockTime","Brightness","Ambient","OutdoorAmbient","FogColor","FogEnd","ExposureCompensation"}) do backup:SetAttribute(name,Lighting[name]) end
end
local old=workspace:FindFirstChild("Lobby_MainModeZone")
if old then old:Destroy() end
root.Parent=workspace
root:SetAttribute("DesignVersion",1)
workspace:SetAttribute("StudioQuickRoundOnPlay",false)
Lighting.ClockTime=15.7
Lighting.Brightness=1.8
Lighting.ExposureCompensation=-0.25
Lighting.Ambient=Color3.fromRGB(104,112,123)
Lighting.OutdoorAmbient=Color3.fromRGB(132,145,151)
Lighting.FogColor=Color3.fromRGB(188,216,225)
Lighting.FogEnd=900
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then atmosphere.Color=Color3.fromRGB(198,220,225) atmosphere.Decay=Color3.fromRGB(142,158,175) atmosphere.Density=0.24 atmosphere.Haze=1.2 atmosphere.Glare=0.1 end
local correction=Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if correction then correction.TintColor=Color3.fromRGB(255,249,238) correction.Saturation=0.07 correction.Contrast=0.08 correction.Brightness=0 end
local bloom=Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then bloom.Intensity=0.08 bloom.Size=20 bloom.Threshold=1.6 end
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(106,97,119),Vector3.new(0,6,-6))
workspace.CurrentCamera.Focus=CFrame.new(0,6,-6)
local count=0
for _,v in ipairs(root:GetDescendants()) do if v:IsA("BasePart") then count+=1 end end
return {parts=count,model=root:GetFullName(),backup=backup:GetFullName()}
