local Service={}
local workspace={GetServerTimeNow=function() return 100 end}
local Players={}
local Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)} end}
Vector3.zero=Vector3.new(0,0,0)
local function set(p,k,v) p.attrs[k]=v end
function Service:_setting(name,fallback,minimum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.max(minimum or 0,value)
end


function Service:_active(player,record)
 return self.tag.active and self.tag.phase=="Playing" and record and record.participating and not record.frozen and not record.ragdoll and player:GetAttribute("TGRagdolled") ~= true
  and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent
  and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
end


function Service:_tick(delta)
 local now=workspace:GetServerTimeNow()
 for _,player in ipairs(Players:GetPlayers()) do
  local record=self.tag.records[player]
  local participating=record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
  local entry=self.entries[player]
  if not participating then
   if entry then self.entries[player]=nil end
   set(player,"TGSprinting",false)
   set(player,"TGSprintExhausted",false)
   set(player,"TGSprintRemaining",self:_setting("SprintSeconds",10,0.1))
  else
   local maximum=self:_setting("SprintSeconds",10,0.1)
   local round=self.tag.currentRound or self.tag.roundNumber
   if not entry or entry.round~=round then
    entry={remaining=maximum,held=false,locked=false,lease=0,character=record.character,round=round}
    self.entries[player]=entry
   elseif entry.character~=record.character then
    entry.character=record.character
    entry.held=false entry.lease=0
   end
   entry.remaining=math.clamp(entry.remaining,0,maximum)
   if now>entry.lease then entry.held=false end
   local canMove=self:_active(player,record)
   local velocity=record.root and record.root.AssemblyLinearVelocity or Vector3.zero
   local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
   local sprinting=canMove and entry.held and entry.remaining>0 and moving
   local sprintFraction=sprinting and math.min(1,entry.remaining/math.max(delta,0.00001)) or 0
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
   end
   entry.locked=entry.remaining<=0
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=(record.frozen or record.ragdoll or player:GetAttribute("TGRagdolled")==true) and 0 or base*(1+(self:_setting("SprintMultiplier",2.5,1)-1)*sprintFraction)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end


local checks=0
local function check(v,m) checks+=1 assert(v,m) end
local player={attrs={TGParticipating=true},Parent=Players}
function player:GetAttribute(k) return self.attrs[k] end
function Players:GetPlayers() return {player} end
local record={participating=true,role="Runner",character={},humanoid={Health=100},root={Parent=true,AssemblyLinearVelocity=Vector3.new(10,0,0)}}
local arena={GetAttribute=function() return nil end}
local entry={remaining=0,held=true,locked=true,lease=110,character=record.character,round=1}
local service=setmetatable({tag={active=true,phase="Playing",currentRound=1,records={[player]=record}},arena=arena,entries={[player]=entry}}, {__index=Service})
service:_tick(.05)
check(entry.remaining>0 and not entry.locked,"Any refill unlocks Tag sprint")
check(record.humanoid.WalkSpeed==16 and not player.attrs.TGSprinting,"Empty tick walks and recharges")
service:_tick(.05)
check(entry.remaining==0 and record.humanoid.WalkSpeed>16 and record.humanoid.WalkSpeed<40 and player.attrs.TGSprinting,"Tiny partial gives proportional actual movement")
entry.remaining=1
service:_tick(.05)
check(record.humanoid.WalkSpeed==40 and math.abs(entry.remaining-.95)<.00001,"Enough stamina gives full multiplier")
entry.held=false
service:_tick(.05)
check(record.humanoid.WalkSpeed==16 and entry.remaining>.95,"Release recharges at normal speed")
entry.held=true entry.remaining=.01
service:_tick(.1)
check(math.abs(record.humanoid.WalkSpeed-18.4)<.00001,"Final .01s budget only buys .01s of boost")
entry.remaining=0
local spent=0
for tick=1,20 do
 service:_tick(.05)
 spent+=(record.humanoid.WalkSpeed/16-1)/1.5*.05
end
check(math.abs(spent-10*(10/15*.05))<.00001,"Holding sprint conserves regenerated budget")
record.frozen=true entry.remaining=1
service:_tick(.05)
check(record.humanoid.WalkSpeed==0 and not player.attrs.TGSprinting,"Frozen cannot sprint")
record.frozen=false entry.lease=99
service:_tick(.05)
check(record.humanoid.WalkSpeed==16 and not entry.held,"Expired input lease releases sprint")
player.attrs.TGParticipating=false
service:_tick(.05)
check(service.entries[player]==nil and not player.attrs.TGSprinting,"Leaving round clears stamina entry")
print(tostring(checks).." Tag stamina checks passed")
