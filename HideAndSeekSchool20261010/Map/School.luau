return function(furniture, target)
	target = target or workspace
	assert(not target:FindFirstChild("Hide and Seek"),"School island already exists")
	local arena=Instance.new("Folder")
	arena.Name="Hide and Seek"
	local origin=CFrame.new(11000,33,4546)
	local palette={ink=Color3.fromRGB(23,35,62),cream=Color3.fromRGB(255,246,214),blue=Color3.fromRGB(86,194,238),gold=Color3.fromRGB(255,204,77),grass=Color3.fromRGB(148,210,94),wall=Color3.fromRGB(248,207,126),brick=Color3.fromRGB(221,123,94)}
	local function folder(parent,name)
		local f=Instance.new("Folder") f.Name=name f.Parent=parent return f
	end
	local function model(parent,name)
		local m=Instance.new("Model") m.Name=name m.Parent=parent return m
	end
	local function part(parent,name,size,cf,color,collide)
		local p=Instance.new("Part")
		p.Name=name p.Size=size p.CFrame=cf p.Color=color p.Material=Enum.Material.SmoothPlastic
		p.Anchored=true p.CanCollide=collide~=false p.CanTouch=false p.CanQuery=collide~=false
		for _,face in {"TopSurface","BottomSurface","LeftSurface","RightSurface","FrontSurface","BackSurface"}do p[face]=Enum.SurfaceType.Studs end
		p.Parent=parent return p
	end
	local function localPart(parent,name,size,position,color,collide)
		return part(parent,name,size,origin*CFrame.new(position),color,collide)
	end
	local function sign(parent,name,cf,size,words,color)
		local board=part(parent,name,size,cf,palette.ink,false)
		local face=Instance.new("SurfaceGui")
		face.Name="EditableLabel" face.Face=Enum.NormalId.Front face.CanvasSize=Vector2.new(600,150)
		face.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize face.LightInfluence=0 face.PixelsPerStud=40 face.Parent=board
		local text=Instance.new("TextLabel") text.Name="Caption" text.Size=UDim2.fromScale(1,1)
		text.BackgroundTransparency=1 text.Text=words text.TextColor3=color or palette.cream
		text.Font=Enum.Font.FredokaOne text.TextScaled=true text.Parent=face
		local stroke=Instance.new("UIStroke") stroke.Color=palette.ink stroke.Thickness=2 stroke.Parent=text
		return board
	end
	local geometry=folder(arena,"Geometry")
	local island=model(geometry,"FourthIsland")
	local centre=CFrame.new(11000,33,4534)
	part(island,"NavyIslandRim",Vector3.new(208,1.4,204),centre*CFrame.new(0,-.8,0),palette.ink)
	part(island,"StuddedGrass",Vector3.new(206,1,202),centre*CFrame.new(0,-.5,0),palette.grass)
	part(island,"WarmEarth",Vector3.new(202,22,198),centre*CFrame.new(0,-12.7,0),Color3.fromRGB(174,113,74))
	part(island,"BottomOutline",Vector3.new(204,1.2,200),centre*CFrame.new(0,-24.3,0),palette.ink)
	for _,x in {-1,1}do
		for _,z in {-1,1}do
			local rock=part(island,"CornerRock",Vector3.new(14,16,14),centre*CFrame.new(x*94,-17,z*92)*CFrame.Angles(0,math.rad(25*x*z),0),Color3.fromRGB(145,92,66))
			rock.Shape=Enum.PartType.Ball
		end
	end
	local grounds=folder(arena,"Grounds")
	for _,x in {-101,101}do part(grounds,"IslandBoundary",Vector3.new(1.4,4,200),centre*CFrame.new(x,2,0),palette.ink) end
	for _,z in {-99,99}do part(grounds,"IslandBoundary",Vector3.new(202,4,1.4),centre*CFrame.new(0,2,z),palette.ink) end
	localPart(grounds,"EntrancePath",Vector3.new(16,.15,22),Vector3.new(0,.08,-68),palette.cream)
	local building=model(geometry,"PlaygroundPrimarySchool")
	local shell=folder(building,"Structure")
	local roomFolder=folder(building,"Classrooms")
	local toilets=folder(building,"Toilets")
	local detail=folder(building,"Details")
	localPart(shell,"GroundFloor",Vector3.new(124,1,116),Vector3.new(0,-.5,0),palette.cream)
	localPart(shell,"UpperFloorFront",Vector3.new(124,1,96),Vector3.new(0,17.5,-10),palette.cream)
	for _,x in {-36.5,36.5}do localPart(shell,"UpperFloorRear",Vector3.new(51,1,20),Vector3.new(x,17.5,48),palette.cream)end
	localPart(shell,"UpperFloorBackBridge",Vector3.new(22,1,2),Vector3.new(0,17.5,57),palette.cream)
	localPart(shell,"RoofNavyEdge",Vector3.new(128,1.2,120),Vector3.new(0,35.3,0),palette.ink)
	localPart(shell,"CartoonBlueRoof",Vector3.new(126,1,118),Vector3.new(0,36.1,0),palette.blue)
	localPart(detail,"RoofRidge",Vector3.new(4,1.2,116),Vector3.new(0,37.2,0),palette.gold,false)
	local function wall(parent,name,axis,cross,along,length,base,height,holes,color)
		local cuts={-length/2,length/2}
		for _,h in holes or {}do table.insert(cuts,h.a) table.insert(cuts,h.b)end
		table.sort(cuts)
		local function slab(a,b,bottom,tall,suffix)
			if b-a<.01 or tall<.01 then return end
			local pos=axis=="X" and Vector3.new(along+(a+b)/2,base+bottom+tall/2,cross)or Vector3.new(cross,base+bottom+tall/2,along+(a+b)/2)
			local size=axis=="X" and Vector3.new(b-a,tall,1)or Vector3.new(1,tall,b-a)
			localPart(parent,name..suffix,size,pos,color or palette.wall)
		end
		for i=1,#cuts-1 do
			local a,b=cuts[i],cuts[i+1]
			local opening
			for _,h in holes or {}do if (a+b)/2>=h.a and (a+b)/2<=h.b then opening=h break end end
			if opening then slab(a,b,0,opening.sill or 0,"Sill") slab(a,b,(opening.sill or 0)+opening.height,height-(opening.sill or 0)-opening.height,"Lintel")
			else slab(a,b,0,height,"Panel")end
		end
		for _,h in holes or {}do
			local size=axis=="X"and Vector3.new(.18,h.height,.18)or Vector3.new(.18,h.height,.18)
			for _,edge in {h.a,h.b}do
				local pos=axis=="X"and Vector3.new(along+edge,base+(h.sill or 0)+h.height/2,cross)or Vector3.new(cross,base+(h.sill or 0)+h.height/2,along+edge)
				localPart(parent,name.."OpeningOutline",size,pos,palette.ink,false)
			end
			for _,edge in {h.sill or 0,(h.sill or 0)+h.height}do
				local pos=axis=="X"and Vector3.new(along+(h.a+h.b)/2,base+edge,cross)or Vector3.new(cross,base+edge,along+(h.a+h.b)/2)
				local trimSize=axis=="X"and Vector3.new(h.b-h.a,.18,.18)or Vector3.new(.18,.18,h.b-h.a)
				localPart(parent,name.."OpeningOutline",trimSize,pos,palette.ink,false)
			end
			if h.glass then
				local sizeGlass=axis=="X"and Vector3.new(h.b-h.a,h.height,.15)or Vector3.new(.15,h.height,h.b-h.a)
				local pos=axis=="X"and Vector3.new(along+(h.a+h.b)/2,base+h.sill+h.height/2,cross)or Vector3.new(cross,base+h.sill+h.height/2,along+(h.a+h.b)/2)
				local glass=localPart(parent,name.."BlueWindow",sizeGlass,pos,palette.blue)
				glass.Transparency=.28
			end
		end
	end
	local themes={Color3.fromRGB(105,193,247),Color3.fromRGB(113,210,153),Color3.fromRGB(238,142,177),Color3.fromRGB(248,202,92),Color3.fromRGB(179,144,239),Color3.fromRGB(100,214,214),Color3.fromRGB(246,162,106),Color3.fromRGB(145,190,251)}
	local subjects={"MATHS","SCIENCE","ART","ENGLISH","MUSIC","GEOGRAPHY","COMPUTING","HISTORY"}
	for floor=0,1 do
		local base=floor*18
		local frontOpenings={{a=-48,b=-36,sill=5,height=6,glass=true},{a=-31,b=-19,sill=5,height=6,glass=true},{a=19,b=31,sill=5,height=6,glass=true},{a=36,b=48,sill=5,height=6,glass=true}}
		table.insert(frontOpenings,floor==0 and {a=-6,b=6,sill=0,height=11}or {a=-6,b=6,sill=4,height=7,glass=true})
		wall(shell,"FrontWall"..floor,"X",-58,0,124,base,16,frontOpenings,palette.brick)
		wall(shell,"BackWall"..floor,"X",58,0,124,base,16,{},palette.brick)
		for _,side in {-1,1}do
			local gaps={{a=-30,b=-23,sill=5,height=5,glass=true},{a=28,b=35,sill=5,height=5,glass=true},{a=-21,b=-13,sill=2.5,height=10}}
			wall(shell,"OutsideWall"..floor..side,"Z",side*62,0,116,base,16,gaps,palette.wall)
			wall(shell,"CorridorWall"..floor..side,"Z",side*11,0,116,base,16,{{a=-21,b=-13,sill=0,height=9},{a=18,b=26,sill=0,height=9},{a=46,b=54,sill=0,height=9}},palette.cream)
			wall(shell,"ClassDivider"..floor..side,"X",2.5,side*36,50,base,16,{{a=12,b=20,sill=2.2,height=10}},palette.wall)
			wall(shell,"ClassFront"..floor..side,"X",-36,side*36,50,base,16,{},palette.wall)
			wall(shell,"ClassRear"..floor..side,"X",41,side*36,50,base,16,{},palette.wall)
			for row=1,2 do
				local number=floor*4+(row-1)*2+(side==1 and 2 or 1)
				local z=row==1 and -17 or 22
				local room=model(roomFolder,string.format("Classroom%02d_%s",number,subjects[number]))
				room:SetAttribute("ClassroomNumber",number)room:SetAttribute("Floor",floor+1)
				local cf=origin*CFrame.new(side*36,base,z)
				furniture.classroom(room,cf,themes[number],number)
				sign(detail,"ClassroomLabel"..number,origin*CFrame.new(side*10.42,base+10,z)*CFrame.Angles(0,side==1 and math.pi/2 or -math.pi/2,0),Vector3.new(6,1.5,.15),string.format("%d · %s",floor==0 and 100+number or 200+number-4,subjects[number]),palette.cream)
			end
		end
		local toilet=model(toilets,"ToiletFloor"..(floor+1))
		toilet:SetAttribute("Floor",floor+1)
		furniture.toilet(toilet,origin*CFrame.new(-36,base,51),floor+1)
		sign(detail,"ToiletSign"..floor,origin*CFrame.new(-10.42,base+10,50)*CFrame.Angles(0,-math.pi/2,0),Vector3.new(6,1.5,.15),"TOILETS",palette.cream)
		for _,z in {-45,-16,15,44}do
			local light=localPart(detail,"CeilingLight",Vector3.new(8,.3,2),Vector3.new(0,base+15.5,z),Color3.fromRGB(255,252,221),false)
			local glow=Instance.new("PointLight")glow.Brightness=.6 glow.Range=24 glow.Color=palette.cream glow.Shadows=false glow.Parent=light
		end
		for _,x in {-60.4,60.4,-10.4,10.4}do localPart(detail,"FloorSkirting",Vector3.new(.15,.5,113),Vector3.new(x,base+.25,0),palette.ink,false)end
		for _,x in {-62,62}do for _,z in {-58,58}do localPart(detail,"BuildingCornerOutline",Vector3.new(.2,16,.2),Vector3.new(x,base+8,z),palette.ink,false)end end
	end
	local stairs=model(building,"SwitchbackStaircase")
	for step=1,12 do
		local rise=step*.75
		local z=39+(step-.5)*1.3
		localPart(stairs,"LowerStep"..step,Vector3.new(7,rise,1.3),Vector3.new(-5.2,rise*.5,z),palette.gold)
		localPart(stairs,"StepEdge",Vector3.new(7,.12,.16),Vector3.new(-5.2,rise+.06,z-.55),palette.ink,false)
		local rise2=9+step*.75
		local z2=54.6-(step-.5)*1.3
		localPart(stairs,"UpperStep"..step,Vector3.new(7,.75,1.3),Vector3.new(5.2,rise2-.375,z2),palette.gold)
		localPart(stairs,"StepEdge",Vector3.new(7,.12,.16),Vector3.new(5.2,rise2+.06,z2+.55),palette.ink,false)
	end
	localPart(stairs,"MiddleLanding",Vector3.new(18,1,4),Vector3.new(0,8.5,56.5),palette.gold)
	localPart(stairs,"UpperLandingLink",Vector3.new(7,1,1.1),Vector3.new(5.2,17.5,38.5),palette.gold)
	for _,x in {-9.4,0,9.4}do
		for _,z in {40,44,48,52,56}do
			local height=x<0 and math.clamp((z-39)/1.3*.75,1,9)or x>0 and math.clamp(9+(54.6-z)/1.3*.75,9,18)or 9
			localPart(stairs,"RailPost",Vector3.new(.3,3,.3),Vector3.new(x,height+1.5,z),palette.ink,false)
		end
	end
	localPart(stairs,"LandingGuard",Vector3.new(18,3,.3),Vector3.new(0,10.5,58.2),palette.ink)
	local exterior=model(building,"OutsideEscapeSteps")
	for step=1,24 do
		local rise=step*.75
		localPart(exterior,"ReturnStep"..step,Vector3.new(8,rise,1.3),Vector3.new(76,rise/2,14-(step-.5)*1.3),palette.blue)
	end
	localPart(exterior,"UpperJumpLanding",Vector3.new(18,1,8.8),Vector3.new(70,17.5,-21.6),palette.blue)
	for _,x in {-65.5,65.5}do
		localPart(detail,"UpperEscapeLedge",Vector3.new(7,1,88),Vector3.new(x,17.5,-2),palette.cream)
		for _,range in {{-45,-21},{-13,41}}do
			localPart(detail,"LedgeOuterRail",Vector3.new(.4,3.5,range[2]-range[1]),Vector3.new(x+(x<0 and -3.2 or 3.2),19.75,(range[1]+range[2])/2),palette.ink)
		end
	end
	localPart(detail,"EntranceCanopy",Vector3.new(24,1,8),Vector3.new(0,12,-61),palette.blue)
	for _,x in {-11,11}do localPart(detail,"CanopyPillar",Vector3.new(1,12,1),Vector3.new(x,6,-64),palette.ink)end
	sign(detail,"SchoolName",origin*CFrame.new(0,14,-58.65),Vector3.new(24,3,.3),"PLAYGROUND PRIMARY",palette.gold)
	local clock=localPart(detail,"SchoolClock",Vector3.new(5,5,.3),Vector3.new(0,29,-58.7),palette.cream,false)
	localPart(detail,"ClockFrame",Vector3.new(5.4,5.4,.2),Vector3.new(0,29,-58.5),palette.ink,false)
	localPart(detail,"ClockHandLong",Vector3.new(.15,1.7,.2),Vector3.new(0,29.7,-58.95),palette.ink,false)
	localPart(detail,"ClockHandShort",Vector3.new(1.4,.15,.2),Vector3.new(.6,29,-58.95),palette.ink,false)
	furniture.vending(detail,origin*CFrame.new(43,0,48))
	furniture.vending(detail,origin*CFrame.new(43,18,48))
	furniture.playground(grounds,CFrame.new(11000,33,4457))
	local gameplay=folder(arena,"Gameplay")
	local bounds=part(gameplay,"ArenaBounds",Vector3.new(208,84,204),CFrame.new(11000,75,4534),palette.ink,false)
	bounds.Transparency=1
	local function marker(parent,name,cf)
		local p=part(parent,name,Vector3.new(.4,.4,.4),cf,palette.ink,false)p.Transparency=1 return p
	end
	local hiderSpawns=folder(gameplay,"HiderSpawns")
	for floor=0,1 do for side=-1,1,2 do for _,z in {-26,-10,14,30}do marker(hiderSpawns,string.format("Hider%02d",#hiderSpawns:GetChildren()+1),origin*CFrame.new(side*4,floor*18+3,z))end end end
	local seekerSpawns=folder(gameplay,"SeekerSpawns")
	for i=1,4 do marker(seekerSpawns,"Seeker"..i,origin*CFrame.new((i-2.5)*4,3,-51))end
	local lockers=folder(gameplay,"LockerSpots")
	local function locker(cf,color)
		local id=#lockers:GetChildren()+1
		local m=model(lockers,string.format("Locker%02d",id))m:SetAttribute("LockerId",id)
		part(m,"Back",Vector3.new(4,8,.35),cf*CFrame.new(0,4,-1.825),palette.ink)
		for _,x in {-1.825,1.825}do part(m,"Side",Vector3.new(.35,8,4),cf*CFrame.new(x,4,0),color)end
		part(m,"Top",Vector3.new(4,.35,4),cf*CFrame.new(0,7.825,0),palette.ink)
		part(m,"Base",Vector3.new(4,.2,4),cf*CFrame.new(0,.1,0),palette.ink)
		local door=part(m,"Door",Vector3.new(3.55,7.3,.25),cf*CFrame.new(0,3.85,2.02),color)
		part(m,"Handle",Vector3.new(.2,.9,.12),cf*CFrame.new(-1.12,3.8,2.22),palette.ink,false)
		for row=1,3 do part(m,"Vent",Vector3.new(1.4,.10,.09),cf*CFrame.new(0,5.8+row*.3,2.2),palette.ink,false)end
		marker(m,"HidePoint",cf*CFrame.new(0,3,0))
		marker(m,"ExitPoint",cf*CFrame.new(0,3,6.4))
		local prompt=Instance.new("ProximityPrompt")prompt.Name="LockerPrompt"prompt.ActionText="Hide / Search"prompt.ObjectText="Locker "..id
		prompt.KeyboardKeyCode=Enum.KeyCode.E prompt.GamepadKeyCode=Enum.KeyCode.ButtonX prompt.MaxActivationDistance=6 prompt.HoldDuration=.25 prompt.RequiresLineOfSight=true prompt.Parent=door
		return m
	end
	for floor=0,1 do
		for _,z in {-47,-34,-6,5,12,34}do
			local side=floor==0 and -1 or 1
			locker(origin*CFrame.new(side*8,floor*18,z)*CFrame.Angles(0,side<0 and math.pi/2 or -math.pi/2,0),floor==0 and palette.blue or palette.gold)
		end
		for side=-1,1,2 do for row=1,2 do
			local z=(row==1 and -17 or 22)+14
			locker(origin*CFrame.new(side*16,floor*18,z)*CFrame.Angles(0,math.pi,0),themes[floor*4+(row-1)*2+(side==1 and 2 or 1)])
		end end
	end
	for key,value in pairs({RoundDuration=180,HideSeconds=20,MinimumPlayers=2,MaxPlayers=16,BaseSpeed=16,SeekerSpeed=18,TagDistance=10,CountdownSeconds=3,ResultsSeconds=7,FloorY=33,BuildVersion="20261010",ClassroomCount=8,ToiletCount=2,IslandNumber=4})do arena:SetAttribute(key,value)end
	arena.Parent=target
	return arena
end
