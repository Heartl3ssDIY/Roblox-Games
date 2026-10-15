local Effects=require("./ServerScriptService.GBloxAbilityEffects.after")
local zero={X=0,Y=0,Z=0}
local created={}
local globals=getfenv(Effects.new)
globals.Vector3={zero=zero,new=function(x,y,z) return {X=x,Y=y,Z=z} end}
globals.Enum={ActuatorRelativeTo={World="World"},VelocityConstraintMode={Vector="Vector"},ForceLimitMode={Magnitude="Magnitude"}}
globals.Instance={new=function(class)
 local object={ClassName=class,Enabled=true}
 function object:Destroy() self.destroyed=true self.Parent=nil end
 table.insert(created,object)
 return object
end}
local assertions,scenarios=0,0
local function equal(actual,expected,label)
 assertions+=1
 assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function truth(actual,label) equal(not not actual,true,label) end
local function root(player)
 local part={Parent=true,Anchored=false,AssemblyLinearVelocity=zero,AssemblyAngularVelocity=zero,owner=player,auto=false,owners=0,autos=0}
 function part:SetNetworkOwner(value)
  assert(not self.Anchored,"ownership cannot be assigned while anchored")
  if self.failOwnership then error("No ownership capability") end
  self.owner=value self.auto=false self.owners+=1
 end
 function part:GetNetworkOwner() return self.owner end
 function part:GetNetworkOwnershipAuto() return self.auto end
 function part:SetNetworkOwnershipAuto()
  assert(not self.Anchored,"automatic ownership cannot be assigned while anchored")
  self.auto=true self.autos+=1
 end
 return part
end
local function fixture()
 created={}
 local attrs={}
 local player={Parent=true}
 function player:SetAttribute(name,value) attrs[name]=value end
 local part=root(player)
 local data={root=part,status="Running",gravitySign=1,humanoid={Health=100},recovering=false}
 data.velocity={Parent=part,Enabled=true,LineVelocity=32}
 data.attachment={Parent=part}
 data.runTrack={}
 function data.runTrack:AdjustSpeed(value) self.speed=value end
 local now,phase,round=100,"Running",1
 local runners={[player]=data}
 local context={Runners=runners,Now=function() return now end,Phase=function() return phase end,RoundKey=function() return round end,BoostMultiplier=2}
 context.SetSpeed=function(target,multiplier)
  if (target.superUntil or 0)>now then multiplier=math.max(multiplier,context.BoostMultiplier*2) end
  target.mockSpeed=multiplier
  target.runTrack:AdjustSpeed(multiplier)
 end
 return {player=player,data=data,attrs=attrs,runners=runners,effects=Effects.new(context),
  time=function(value) now=value end,phase=function(value) phase=value end,round=function(value) round=value end}
end
local function constraint()
 for _,object in created do if object.Name=="GBloxCornerWebFall" and not object.destroyed then return object end end
end
local function liveInstances()
 local count=0
 for _,object in created do if not object.destroyed then count+=1 end end
 return count
end
local function scenario(name,callback)
 scenarios+=1 callback(fixture()) print("PASS "..name)
end

scenario("Seven-second slow fall remains unanchored and restores controls",function(f)
 equal(f.effects.HoldCornerWeb(f.player,7,6),107,"reported deadline")
 equal(f.data.cornerWebUntil,107,"server corner deadline")
 equal(f.attrs.GBloxCornerWebHeldUntil,107,"client corner deadline")
 equal(f.attrs.GBloxFrozenUntil,nil,"corner does not become paid freeze")
 equal(f.data.freezeUntil,nil,"corner does not merge anchor-freeze state")
 equal(f.data.root.Anchored,false,"slow fall stays unanchored")
 equal(f.data.velocity.Enabled,false,"forward constraint disabled")
 equal(f.data.velocity.LineVelocity,0,"forward target stopped")
 equal(f.data.runTrack.speed,0,"run track paused")
 equal(f.data.root.owner,nil,"server temporarily owns trapped assembly")
 local hold=constraint()
 truth(hold,"temporary slow-fall constraint exists")
 equal(hold.Attachment0,f.data.attachment,"existing attachment reused")
 equal(hold.VelocityConstraintMode,"Vector","full velocity control")
 equal(hold.RelativeTo,"World","world-relative velocity")
 equal(hold.VectorVelocity.X,0,"no forward velocity")
 equal(hold.VectorVelocity.Y,-6,"normal gravity falls down slowly")
 equal(hold.VectorVelocity.Z,0,"no lateral velocity")
 equal(hold.ForceLimitsEnabled,true,"fall constraint force bounded")
 f.time(106.999) f.effects.Step()
 equal(hold.destroyed,nil,"not released before seven seconds")
 equal(f.data.root.Anchored,false,"late hold remains unanchored")
 f.time(107) f.effects.Step()
 equal(hold.destroyed,true,"released exactly at deadline")
 equal(f.data.velocity.Enabled,true,"original forward constraint restored")
 equal(f.data.cornerWebUntil,nil,"server hold cleared")
 equal(f.attrs.GBloxCornerWebHeldUntil,nil,"client hold cleared")
 equal(f.data.root.owner,f.player,"original owner restored")
 equal(f.data.root.owners,2,"single acquisition and restoration")
 equal(f.data.mockSpeed,1,"normal movement animation restored")
 equal(liveInstances(),0,"all temporary instances destroyed")
 f.time(109) f.effects.Step()
 equal(f.data.root.owners,2,"release cannot repeat")
end)

scenario("Inverted gravity falls upward and forced gravity changes follow smoothly",function(f)
 f.data.gravitySign=-1
 f.effects.HoldCornerWeb(f.player,7,6)
 local hold=constraint()
 equal(hold.VectorVelocity.Y,6,"inverted runner slowly falls upward")
 f.data.gravitySign=1 f.time(101) f.effects.Step()
 equal(hold.VectorVelocity.Y,-6,"forced gravity reversal updates fall")
 equal(f.data.root.Anchored,false,"gravity reversal never anchors")
 equal(f.data.root.owners,1,"gravity reversal does not churn ownership")
end)

scenario("Repeated corner contact cannot extend seven-second penalty",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 f.time(106)
 equal(f.effects.HoldCornerWeb(f.player,7,9),107,"retrigger reports original deadline")
 equal(f.data.cornerWebUntil,107,"retrigger keeps original expiry")
 equal(constraint().VectorVelocity.Y,-6,"retrigger cannot change fall speed")
 equal(liveInstances(),1,"retrigger adds no constraint")
 f.time(107) f.effects.Step()
 equal(f.data.velocity.Enabled,true,"original hold still releases on time")
end)

scenario("Longer paid Freeze survives corner expiry",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 local hold=constraint()
 f.time(102) f.effects.Freeze(f.player,10)
 equal(f.data.root.Anchored,true,"paid Freeze anchors")
 equal(hold.Enabled,false,"slow-fall force suspended during anchor")
 equal(f.data.freezeUntil,112,"paid deadline untouched")
 f.time(107) f.effects.Step()
 equal(hold.destroyed,true,"corner instance removed on its deadline")
 equal(f.data.root.Anchored,true,"corner expiry cannot release paid Freeze")
 equal(f.data.freezeUntil,112,"paid freeze continues")
 equal(f.attrs.GBloxFrozenUntil,112,"paid client deadline continues")
 equal(f.attrs.GBloxCornerWebHeldUntil,nil,"corner deadline cleared independently")
 f.time(112) f.effects.Step()
 equal(f.data.root.Anchored,false,"paid Freeze eventually releases")
 equal(f.data.root.owner,f.player,"client ownership restored after paid Freeze")
 equal(f.data.runTrack.speed,1,"run track resumes after overlapping effects")
end)

scenario("Shorter paid Freeze resumes the remaining slow fall",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 local hold=constraint()
 f.time(101) f.effects.Freeze(f.player,2)
 equal(hold.Enabled,false,"anchored overlap suspends constraint")
 f.time(103) f.effects.Step()
 equal(f.data.root.Anchored,false,"expired paid freeze unanchors")
 equal(hold.Enabled,true,"remaining corner fall resumes")
 equal(f.data.root.owner,nil,"server retains corner physics")
 equal(f.data.cornerWebUntil,107,"corner expiry not extended by freeze")
 equal(f.data.velocity.Enabled,false,"runner movement remains blocked")
 f.time(107) f.effects.Step()
 equal(f.data.root.owner,f.player,"owner restored at original deadline")
 equal(f.data.velocity.Enabled,true,"movement restored at original deadline")
end)

scenario("Seasonal freeze cancellation does not cancel corner hold",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 f.effects.FreezeSeasonal(f.player,5)
 equal(f.data.root.Anchored,true,"ordinary Web/Grave hold anchors")
 f.time(102) f.effects.ClearSeasonalFreeze(f.player)
 equal(f.data.root.Anchored,false,"seasonal freeze cancellation releases anchor")
 equal(f.data.cornerWebUntil,107,"corner hold preserved")
 equal(constraint().Enabled,true,"corner fall restored")
 equal(f.attrs.GBloxHalloweenHeldUntil,nil,"seasonal attribute removed only")
 f.effects.ClearCornerWebHold(f.player)
 equal(liveInstances(),0,"direct corner cancellation cleans instances")
 equal(f.data.root.owner,f.player,"corner cancellation restores ownership")
 equal(f.data.velocity.Enabled,true,"corner cancellation restores forward controller")
end)

scenario("Corner cancellation cannot cancel paid or seasonal anchoring",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 f.effects.Freeze(f.player,10)
 f.effects.FreezeSeasonal(f.player,5)
 f.time(102) f.effects.ClearCornerWebHold(f.player)
 equal(f.data.root.Anchored,true,"both anchor freezes remain")
 equal(f.data.freezeUntil,110,"paid maximum preserved")
 equal(f.attrs.GBloxHalloweenHeldUntil,105,"seasonal expiry preserved")
 equal(f.attrs.GBloxCornerWebHeldUntil,nil,"only corner flag removed")
 equal(liveInstances(),0,"corner physics removed")
end)

scenario("Starting corner while already Frozen defers physics safely",function(f)
 f.effects.Freeze(f.player,2)
 equal(f.effects.HoldCornerWeb(f.player,7,6),107,"hold starts during known freeze")
 equal(constraint(),nil,"no fall constraint on anchored root")
 equal(f.data.root.owners,0,"no ownership calls on anchor")
 f.time(102) f.effects.Step()
 equal(f.data.root.Anchored,false,"paid expiry releases root")
 truth(constraint(),"fall constraint starts after unanchor")
 equal(f.data.root.owner,nil,"deferred fall server owned")
 f.time(107) f.effects.Step()
 equal(f.data.root.owner,f.player,"deferred ownership restored")
 equal(liveInstances(),0,"deferred instance cleaned")
end)

scenario("Automatic ownership mode and previously disabled forward state restore",function(f)
 f.data.root.auto=true f.data.velocity.Enabled=false
 f.effects.HoldCornerWeb(f.player,7,6)
 equal(f.data.root.auto,false,"hold takes manual server ownership")
 f.time(107) f.effects.Step()
 equal(f.data.root.auto,true,"original automatic ownership restored")
 equal(f.data.root.autos,1,"automatic mode restored once")
 equal(f.data.velocity.Enabled,false,"original disabled forward state preserved")
end)

scenario("Separate attachment is created only when runner attachment is absent",function(f)
 f.data.attachment=nil
 f.effects.HoldCornerWeb(f.player,7,6)
 local hold=constraint()
 equal(hold.Attachment0.Name,"GBloxCornerWebAttachment","private fallback attachment")
 equal(liveInstances(),2,"constraint and fallback attachment")
 f.effects.ClearCornerWebHold(f.player)
 equal(liveInstances(),0,"both temporary instances cleaned")
end)

for _,kind in {"Loading","Intermission","Recovery","Dead","Absent","RoundChange","RootChange","DataChange"} do
 scenario("Lifecycle "..kind.." never leaks or unanchors replacement",function(f)
  f.effects.HoldCornerWeb(f.player,7,6)
  local oldRoot=f.data.root
  local oldForward=f.data.velocity
  local hold=constraint()
  if kind=="Loading" then f.data.status="Loading" oldRoot.Anchored=true
  elseif kind=="Intermission" then f.phase("Intermission") oldRoot.Anchored=true
  elseif kind=="Recovery" then f.data.recovering=true oldRoot.Anchored=true
  elseif kind=="Dead" then f.data.humanoid.Health=0 oldRoot.Anchored=true
  elseif kind=="Absent" then f.player.Parent=nil oldRoot.Anchored=true
  elseif kind=="RoundChange" then f.round(2) oldRoot.Anchored=true
  elseif kind=="RootChange" then f.data.root=root(f.player) f.data.root.Anchored=true
  elseif kind=="DataChange" then
   local replacement={root=root(f.player),status="Running",humanoid={Health=100},cornerWebUntil=500}
   replacement.root.Anchored=true f.runners[f.player]=replacement
  end
  local ownerCount=oldRoot.owners
  f.time(101) f.effects.Step()
  equal(hold.destroyed,true,"stale hold destroyed")
  equal(liveInstances(),0,"no leaked temporary instances")
  equal(oldForward.Enabled,true,"old forward constraint state restored")
  equal(oldRoot.owners,ownerCount,"invalid lifecycle does not reassign old owner")
  equal(f.attrs.GBloxCornerWebHeldUntil,nil,"stale client hold cleared")
  if kind=="DataChange" then equal(f.runners[f.player].cornerWebUntil,500,"replacement state untouched")
  else
   equal(f.data.cornerWebUntil,nil,"old data hold cleared")
   equal(f.data.root.Anchored,true,"lifecycle anchor preserved")
  end
  f.time(110) f.effects.Step()
  equal(oldRoot.owners,ownerCount,"no delayed old owner reset")
 end)
end

scenario("State replacement immediately cleans old private physics",function(f)
 f.effects.HoldCornerWeb(f.player,7,6)
 local hold=constraint()
 local newRoot=root(f.player)
 f.data.root=newRoot f.data.velocity={Parent=newRoot,Enabled=true,LineVelocity=32} f.data.attachment={Parent=newRoot}
 equal(f.effects.HoldCornerWeb(f.player,7,6),107,"new runner can create fresh hold")
 equal(hold.destroyed,true,"old constraint removed before new state")
 equal(liveInstances(),1,"only replacement constraint remains")
 f.effects.Remove(f.player)
 equal(liveInstances(),0,"explicit removal cleans replacement")
 equal(newRoot.Anchored,false,"explicit removal does not anchor")
 equal(newRoot.owner,f.player,"valid explicit removal restores ownership")
end)

scenario("Corner release preserves still-active speed bonuses",function(f)
 f.effects.Superspeed(f.player,20)
 f.effects.HoldCornerWeb(f.player,7,6)
 f.time(107) f.effects.Step()
 equal(f.data.mockSpeed,4,"super bonus restored")
 equal(f.attrs.GBloxSuperspeedUntil,120,"super deadline unchanged")
 equal(f.data.superUntil,120,"super state unchanged")
end)

scenario("Malformed duration and anchored unrelated lifecycle cannot be captured",function(f)
 equal(f.effects.HoldCornerWeb(f.player,0,6),nil,"zero duration rejected")
 equal(f.effects.HoldCornerWeb(f.player,0/0,6),nil,"NaN duration rejected")
 equal(f.effects.HoldCornerWeb(f.player,math.huge,6),nil,"infinite duration rejected")
 f.data.root.Anchored=true
 equal(f.effects.HoldCornerWeb(f.player,7,6),nil,"unrelated anchor rejected")
 equal(liveInstances(),0,"invalid inputs create no instances")
 equal(f.attrs.GBloxCornerWebHeldUntil,nil,"invalid inputs create no hold attribute")
end)

print(string.format("PASS %d corner-web assertions across %d isolated scenarios",assertions,scenarios))
