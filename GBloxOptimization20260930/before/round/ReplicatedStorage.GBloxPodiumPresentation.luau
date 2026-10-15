local M={}
M.Order={3,2,1}
function M.Shots(packet,aspect)
 local shots={}
 for _,place in M.Order do
  for _,entry in packet.roster do
   if entry.place==place then
    local target=entry.cframe.Position+Vector3.new(0,1,0)
    local distance=math.max(22,12/math.max(.4,aspect))
    table.insert(shots,{cframe=CFrame.lookAt(target+Vector3.new(0,2,-distance),target),fov=45,place=place,name=entry.displayName,move=1.4,hold=1.5})
   end
  end
 end
 local center=packet.center
 local size=packet.stageSize
 if #packet.roster>0 then
  local low,high=packet.roster[1].cframe.Position,packet.roster[1].cframe.Position
  for _,entry in packet.roster do local pos=entry.cframe.Position low=low:Min(pos) high=high:Max(pos) end
  center=(low+high)*.5+Vector3.new(0,.5,0)
  size=Vector3.new(math.max(40,high.X-low.X+16),high.Y-low.Y+12,math.max(12,high.Z-low.Z+12))
 end
 local vertical=math.rad(52)/2
 local distance=math.max(size.Y/2/math.tan(vertical),size.X/2/(math.tan(vertical)*math.max(.3,aspect)))+size.Z/2+12
 table.insert(shots,{cframe=CFrame.lookAt(center+Vector3.new(0,distance*.22,-distance),center),fov=52,move=2.1,hold=1.3})
 return shots
end
return M

