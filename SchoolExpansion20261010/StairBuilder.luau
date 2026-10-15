local StairBuilder = {}
local dark = Color3.fromRGB(20,21,23)
local railColour = Color3.fromRGB(30,33,39)
local stone = Color3.fromRGB(153,145,129)
local edgeColour = Color3.fromRGB(175,165,143)
local materialVariant = "PlaygroundRetroStuds"

function StairBuilder.Build(origin)
	local stairs = Instance.new("Model")
	stairs.Name = "SwitchbackStaircase"
	stairs:SetAttribute("StairBuildVersion","20261010-expanded")
	stairs:SetAttribute("StepRise",.6)
	stairs:SetAttribute("StepRun",1.2)
	stairs:SetAttribute("FlightWidth",8)
	stairs:SetAttribute("LandingDepth",5)
	stairs:SetAttribute("StepsPerFlight",15)
	stairs:SetAttribute("FloorRise",18)
	local function part(parent,name,size,cf,colour,collide)
		local item = Instance.new("Part")
		item.Name, item.Size, item.CFrame = name,size,origin*cf
		item.Color, item.Material, item.MaterialVariant = colour,Enum.Material.SmoothPlastic,materialVariant
		item.Anchored, item.Locked, item.CanCollide, item.CanTouch, item.CanQuery = true,true,collide~=false,collide~=false,collide~=false
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		item.Parent = parent
		return item
	end
	local function rail(name,a,b,thickness,collide)
		local cf = CFrame.lookAt((a+b)/2,b)
		return part(stairs,name,Vector3.new(thickness,thickness,(b-a).Magnitude),cf,railColour,collide)
	end
	local function guard(name,x,a,b)
		local low = Vector3.new(x,a.Y+1.6,a.Z)
		local high = Vector3.new(x,b.Y+1.6,b.Z)
		local item = part(stairs,name,Vector3.new(.18,3.2,(high-low).Magnitude),CFrame.lookAt((low+high)/2,high),stone,true)
		item.Transparency = .72
		item:SetAttribute("StairSafetyGuard",true)
	end
	local function post(name,x,z,height)
		part(stairs,name,Vector3.new(.26,3.2,.26),CFrame.new(x,height+1.6,z),railColour,false)
	end
	local lower, upper = Instance.new("Folder"),Instance.new("Folder")
	lower.Name,upper.Name,lower.Parent,upper.Parent = "LowerFlight","UpperFlight",stairs,stairs
	for index=1,15 do
		local lowTop = index*.6
		local highTop = 9+index*.6
		local lowZ = 111.5+(index-.5)*1.2
		local highZ = 129.5-(index-.5)*1.2
		for _, data in {
			{folder=lower,prefix="Lower",x=-5.2,z=lowZ,top=lowTop,front=lowZ-.55},
			{folder=upper,prefix="Upper",x=5.2,z=highZ,top=highTop,front=highZ+.55},
		} do
			part(data.folder,data.prefix.."Riser"..index,Vector3.new(8,data.top-.12,1.2),CFrame.new(data.x,(data.top-.12)/2,data.z),stone,true)
			part(data.folder,data.prefix.."Step"..index,Vector3.new(8,.12,1.2),CFrame.new(data.x,data.top-.06,data.z),dark,true)
			part(data.folder,data.prefix.."Nosing"..index,Vector3.new(8,.045,.09),CFrame.new(data.x,data.top+.0225,data.front),edgeColour,false)
		end
	end
	local landing = part(stairs,"MiddleLanding",Vector3.new(20.4,.6,5),CFrame.new(0,8.7,132),dark,true)
	part(stairs,"LandingFrontFascia",Vector3.new(20.4,.5,.14),CFrame.new(0,8.7,129.52),stone,false)
	part(stairs,"UpperLandingLink",Vector3.new(8,.6,1.5),CFrame.new(5.2,17.7,110.75),dark,true)
	part(stairs,"UpperLandingFrontFascia",Vector3.new(8,.14,.08),CFrame.new(5.2,17.91,110.03),edgeColour,false)
	for _, side in {-1,1} do
		part(stairs,side<0 and "UpperLeftToiletPassage" or "UpperRightToiletPassage",Vector3.new(5.8,.6,26),CFrame.new(side*12.1,17.7,123),dark,true)
		local x=side*9.5
		rail("ToiletPassageHandrail",Vector3.new(x,21.2,111.5),Vector3.new(x,21.2,134.8),.36,false)
		part(stairs,"ToiletPassageGuard",Vector3.new(.18,3.2,23.3),CFrame.new(x,19.6,123.15),stone,true).Transparency=.72
		for _, z in {111.5,117.325,123.15,128.975,134.8} do post("ToiletPassagePost",x,z,18) end
	end
	rail("UpperPitRearHandrail",Vector3.new(-9.5,21.2,134.8),Vector3.new(9.5,21.2,134.8),.36,false)
	part(stairs,"UpperPitRearGuard",Vector3.new(19,3.2,.18),CFrame.new(0,19.6,134.8),stone,true).Transparency=.72
	rail("UpperPitFrontHandrail",Vector3.new(-9.5,21.2,110.9),Vector3.new(1.05,21.2,110.9),.36,false)
	part(stairs,"UpperPitFrontGuard",Vector3.new(10.55,3.2,.18),CFrame.new(-4.225,19.6,110.9),stone,true).Transparency=.72
	for _, data in {
		{x=-9.65,a=Vector3.new(0,0,111.5),b=Vector3.new(0,9,129.5),name="LowerOuter"},
		{x=-.75,a=Vector3.new(0,0,111.5),b=Vector3.new(0,9,129.5),name="LowerInner"},
		{x=9.65,a=Vector3.new(0,9,129.5),b=Vector3.new(0,18,111.5),name="UpperOuter"},
		{x=.75,a=Vector3.new(0,9,129.5),b=Vector3.new(0,18,111.5),name="UpperInner"},
	} do
		local a = Vector3.new(data.x,data.a.Y,data.a.Z)
		local b = Vector3.new(data.x,data.b.Y,data.b.Z)
		rail(data.name.."Handrail",a+Vector3.new(0,3.2,0),b+Vector3.new(0,3.2,0),.36,false)
		rail(data.name.."LowerRail",a+Vector3.new(0,.7,0),b+Vector3.new(0,.7,0),.22,false)
		guard(data.name.."Guard",data.x,a,b)
		for index=0,5 do
			local point = a:Lerp(b,index/5)
			post(data.name.."Post"..index,data.x,point.Z,point.Y)
		end
	end
	for _, x in {-9.65,9.65} do
		rail("LandingSideHandrail",Vector3.new(x,12.2,129.5),Vector3.new(x,12.2,134.45),.36,false)
		part(stairs,"LandingSideGuard",Vector3.new(.18,3.2,4.95),CFrame.new(x,10.6,131.975),stone,true).Transparency=.72
		post("LandingRearPost",x,134.45,9)
	end
	rail("LandingRearHandrail",Vector3.new(-9.65,12.2,134.45),Vector3.new(9.65,12.2,134.45),.36,false)
	part(stairs,"LandingRearGuard",Vector3.new(19.3,3.2,.18),CFrame.new(0,10.6,134.45),stone,true).Transparency=.72
	stairs.PrimaryPart = landing
	local route = Instance.new("Folder")
	route.Name, route.Parent = "WalkRoute",stairs
	local index=0
	local function waypoint(name,position)
		index+=1
		local value = Instance.new("CFrameValue")
		value.Name,value.Value,value.Parent = string.format("%02d_%s",index,name),origin*CFrame.new(position),route
	end
	waypoint("GroundApproach",Vector3.new(-5.2,0,110.75))
	for step=1,15 do waypoint("LowerTread"..step,Vector3.new(-5.2,step*.6,111.5+(step-.5)*1.2)) end
	for _, x in {-5.2,-2.6,0,2.6,5.2} do waypoint("LandingTurn",Vector3.new(x,9,132)) end
	for step=1,15 do waypoint("UpperTread"..step,Vector3.new(5.2,9+step*.6,129.5-(step-.5)*1.2)) end
	waypoint("UpperExit",Vector3.new(5.2,18,110.75))
	for _, level in {0,18} do
		for _, side in {-1,1} do
			local prefix=level==0 and "GroundToilet" or "UpperToilet"
			for _, x in {0,3,6,9,12.1} do waypoint(prefix.."HallCrossover",Vector3.new(side*x,level,109.4)) end
			for _, z in {112,115,118,121,124,127,129} do waypoint(prefix.."Passage",Vector3.new(side*12.1,level,z)) end
			for _, x in {14.8,16.4} do waypoint(prefix.."Doorway",Vector3.new(side*x,level,129)) end
		end
	end
	return stairs
end

function StairBuilder.Check(stairs,worldRoot,scope)
	local checks,failures=0,{}
	local function check(value,message)
		checks+=1
		if not value then table.insert(failures,message) end
	end
	check(stairs:GetAttribute("LandingDepth")>=5,"Middle landing must permit an easy turn")
	check(stairs:GetAttribute("FlightWidth")>=8,"Stairs need comfortable full-width flights")
	check(stairs:GetAttribute("StepRise")<=.6,"Steps are too high")
	check(#stairs.LowerFlight:GetChildren()==45 and #stairs.UpperFlight:GetChildren()==45,"Both flights need15complete treads,risers and edges")
	local params=OverlapParams.new()
	params.FilterType,params.FilterDescendantsInstances,params.RespectCanCollide = Enum.RaycastFilterType.Include,{scope or stairs},true
	local rays=RaycastParams.new()
	rays.FilterType,rays.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{scope or stairs}
	for _, value in stairs.WalkRoute:GetChildren() do
		local foot=value.Value.Position
		local support=worldRoot:Raycast(foot+Vector3.new(0,.3,0),Vector3.new(0,-1.3,0),rays)
		check(support~=nil and math.abs(support.Position.Y-foot.Y)<.05,value.Name.." has no matching walkable surface")
		local found=worldRoot:GetPartBoundsInBox(value.Value*CFrame.new(0,3.7,0),Vector3.new(2.6,6,2.6),params)
		local names={}
		for _, hit in found do if hit.CanCollide then table.insert(names,hit.Name) end end
		check(#names==0,value.Name.." R15 route blocked: "..table.concat(names,","))
	end
	for _, item in stairs:GetDescendants() do
		if item:IsA("BasePart") then
			check(item.Anchored and item.Locked,"Stair components must remain anchored")
			check(item.MaterialVariant==materialVariant,"Stud material missing")
			check(item.CanQuery==item.CanCollide,"Decorative stair details must not block bat rays")
		end
	end
	return {passed=#failures==0,checks=checks,failures=failures,waypoints=#stairs.WalkRoute:GetChildren(),rise=.6,run=1.2,landingDepth=5,flightWidth=8}
end
return StairBuilder
