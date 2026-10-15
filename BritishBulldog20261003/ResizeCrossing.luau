assert(not game:GetService("RunService"):IsRunning(), "Stop the playtest before resizing")
local arena=workspace["British Bulldog game"]
local gameplay=arena.Gameplay
local bounds=gameplay.ArenaBounds
local center=bounds.Position.Z
local north=gameplay.NorthLine.Position.Z-center
local south=gameplay.SouthLine.Position.Z-center
local current=south-north
local target=288
if math.abs(current-target)<0.01 then return {crossing=current,alreadySized=true} end
local extra=(target-current)/2
local oldHalf=current/2
local scale=target/current
local function shifted(z)
 local localZ=z-center
 if localZ < -oldHalf then return center+localZ-extra end
 if localZ > oldHalf then return center+localZ+extra end
 return center+localZ*scale
end
for _,parent in ipairs({gameplay,arena.CourtArtwork,arena.ArenaWalls}) do
 for _,p in ipairs(parent:GetDescendants()) do
  if p:IsA("BasePart") then
   local oldPosition=p.Position
   local newZ=shifted(oldPosition.Z)
   if string.match(p.Name,"^Paw") then
    newZ=oldPosition.Z
   elseif p.Name=="CrossingChevron" then
    newZ=center+(oldPosition.Z<center and -1 or 1)*(target/2-7)
   end
   p.CFrame=p.CFrame+Vector3.new(0,0,newZ-oldPosition.Z)
   if p==bounds or p.Name=="CourtFoundationOutline" or p.Name=="CourtFloor" or string.match(p.Name,"^SideWall") then
    p.Size=Vector3.new(p.Size.X,p.Size.Y,p.Size.Z+extra*2)
   elseif string.match(p.Name,"^GrassStripe") then
    p.Size=Vector3.new(p.Size.X,p.Size.Y,p.Size.Z*scale)
   end
  end
 end
end
arena:SetAttribute("CrossingLength",target)
arena:SetAttribute("CourtLength",bounds.Size.Z)
arena:SetAttribute("CameraZoomDistance",30)
arena:SetAttribute("ResizeVersion","20261003-1.5")
return {crossing=target,courtLength=bounds.Size.Z,walkSeconds=target/(arena:GetAttribute("RunnerWalkSpeed") or 16),collisionPropertiesPreserved=true}
