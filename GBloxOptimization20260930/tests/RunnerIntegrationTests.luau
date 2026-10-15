local checks=0
local function check(value,message) checks+=1 assert(value,message) end
local rules=assert(loadstring(game.ServerScriptService.RunnerArrivalRules.Source))()
local valid={SourcePlaceId=74498603638770,SourceGameId=10611575889,TeleportData={FromLobby=true,HumanCount=6}}
check(rules.Expected(valid,74498603638770,10611575889,6)==6,"trusted party")
for _,bad in {false,0,"bad",{},{SourcePlaceId=1,SourceGameId=10611575889,TeleportData=valid.TeleportData},{SourcePlaceId=74498603638770,SourceGameId=1,TeleportData=valid.TeleportData}} do
 check(rules.Expected(bad,74498603638770,10611575889,6)==nil,"untrusted data accepted")
end
for _,count in {0/0,math.huge,-math.huge,"bad",false} do
 valid.TeleportData.HumanCount=count
 check(rules.Expected(valid,74498603638770,10611575889,6)==nil,"nonfinite count")
end
for _,row in {{-10,1},{0,1},{1,1},{3.9,3},{6,6},{999,6},{"4",4}} do
 valid.TeleportData.HumanCount=row[1]
 check(rules.Expected(valid,74498603638770,10611575889,6)==row[2],"bounded count")
end
valid.TeleportData.FromLobby=false
check(rules.Expected(valid,74498603638770,10611575889,6)==nil,"missing lobby marker")
local readiness=assert(loadstring([====[return function(players,Players,courseVersion,expectedPlayers)
local function allReady()
	local count, waiting = 0, false
	for player, data in players do
		if player.Parent==Players and data.status~="Spectating" then
			count+=1
			-- A connected/loading party member must never be skipped.
			if not player:GetAttribute("GBloxCourseReady") or not data.spawn
				or not data.root or not data.root.Parent or not data.humanoid
				or data.humanoid.Health<=0 or data.courseStreamReady~=courseVersion
				or not data.ready then waiting=true end
		end
	end
	return not waiting and count>=math.max(1,expectedPlayers), count
end

return allReady()
end]====]))()
local Players={}
for count=0,6 do
 for expected=1,6 do
  for readyCount=0,count do
   local runners={}
   for i=1,count do
    local player={Parent=Players,GetAttribute=function() return true end}
    runners[player]={status="Waiting",spawn={},root={Parent=true},humanoid={Health=100},courseStreamReady=1,ready=i<=readyCount}
   end
   local before,total=readiness(runners,Players,1,expected)
   check(total==count,"connected count")
   check(before==(count>=expected and readyCount==count),"original barrier")
   local revised=rules.AfterDeadline(expected,total)
   local after,newTotal=readiness(runners,Players,1,revised)
   check(revised==math.min(expected,math.max(1,count)),"deadline lowers absent only")
   check(newTotal==total,"deadline mutated connected roster")
   check(after==(count>=1 and readyCount==count),"connected loading players skipped")
  end
 end
end
local p={Parent=Players,GetAttribute=function() return true end}
local data={status="Waiting",spawn={},root={Parent=true},humanoid={Health=100},courseStreamReady=1,ready=true}
for _,mutation in {
 function() data.spawn=nil end,
 function() data.root=nil end,
 function() data.root.Parent=nil end,
 function() data.humanoid=nil end,
 function() data.humanoid.Health=0 end,
 function() data.courseStreamReady=0 end,
 function() data.ready=false end,
 function() p.GetAttribute=function() return false end end,
} do
 data={status="Waiting",spawn={},root={Parent=true},humanoid={Health=100},courseStreamReady=1,ready=true}
 p.GetAttribute=function() return true end
 mutation()
 check(not readiness({[p]=data},Players,1,1),"connected readiness bypass")
end
local wheels=0
local maxPositionDelta=0
for _,model in workspace:GetDescendants() do
 if model:IsA("Model") and model.Name=="Red_Spiked_Wheel" then
  wheels+=1
  local pivot=model:GetPivot()
  local center=CFrame.new(pivot.Position)
  local teeth=model:FindFirstChild("RedWheel_Teeth",true)
  check(teeth and teeth:IsA("BasePart"),"teeth missing")
  for _,angle in {0,.3,1.5,3.14,6.1} do
   local rotate=CFrame.fromAxisAngle(Vector3.zAxis,angle)
   local before=center*rotate*(center:Inverse()*pivot)
   local after=center*rotate*pivot.Rotation
   local positionDelta=(before.Position-after.Position).Magnitude
   maxPositionDelta=math.max(positionDelta,maxPositionDelta)
   check(positionDelta<.05,"wheel position changed")
   check(before.LookVector:Dot(after.LookVector)>.99999,"wheel orientation changed")
  end
  local radius=teeth.Size.Magnitude*.5+8
  for _,scale in {0,.25,.9,1.1,2,10} do
   local offset=Vector3.new(radius*scale,0,0)
   check((offset.Magnitude<radius)==(offset:Dot(offset)<radius^2),"contact prefilter changed")
  end
 end
end
local source=game.ServerScriptService.RunnerServer.Source
check(source:find([====[local function allReady()
	local count, waiting = 0, false
	for player, data in players do
		if player.Parent==Players and data.status~="Spectating" then
			count+=1
			-- A connected/loading party member must never be skipped.
			if not player:GetAttribute("GBloxCourseReady") or not data.spawn
				or not data.root or not data.root.Parent or not data.humanoid
				or data.humanoid.Health<=0 or data.courseStreamReady~=courseVersion
				or not data.ready then waiting=true end
		end
	end
	return not waiting and count>=math.max(1,expectedPlayers), count
end
]====],1,true)~=nil,"readiness function changed")
check(source:find('spectating:Select(player,version)',1,true)~=nil,"spectator request missing")
check(source:find('returnTravel:Remove(player)',1,true)~=nil,"return cleanup missing")
check(source:find('arrivalDeadline=workspace:GetServerTimeNow()+60',1,true)~=nil,"arrival deadline missing")
return game.HttpService:JSONEncode({checks=checks,wheels=wheels,maxWheelPositionDelta=maxPositionDelta})
