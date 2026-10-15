-- Small vertical motion stays in a dead zone; larger rises/falls move the camera.
-- Bound smoothing lag so rapid falls cannot take the runner out of frame.
local M={}
function M.StepY(currentY,playerY,deltaTime,deadZone,speed,maxLag)
 if currentY==nil then return playerY end
 deadZone=math.max(0,deadZone)
 maxLag=math.max(deadZone,maxLag)
 local targetY=math.clamp(currentY,playerY-deadZone,playerY+deadZone)
 local alpha=1-math.exp(-math.max(0,speed)*math.max(0,deltaTime))
 local nextY=currentY+(targetY-currentY)*alpha
 return math.clamp(nextY,playerY-maxLag,playerY+maxLag)
end
function M.Limits(cameraOffset,fieldOfView,deadZone,maxLag)
 local halfHeight=math.max(1,math.abs(cameraOffset.Z)*math.tan(math.rad(fieldOfView*.5)))
 -- Reserve room around the character even at unusually close zooms.
 local limit=math.min(maxLag,halfHeight*.55)
 return math.min(deadZone,limit*.5),limit
end
return M
