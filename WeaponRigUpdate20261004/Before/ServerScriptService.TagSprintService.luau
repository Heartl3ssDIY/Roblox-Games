local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Service={}
Service.__index=Service
local runningService

local function set(player,name,value)
 if player:GetAttribute(name)~=value then player:SetAttribute(name,value) end
end

function Service.new(tag)
 return setmetatable({tag=tag,arena=tag.arena,entries={},connections={},running=false},Service)
end

function Service:_setting(name,fallback,minimum)
 local value=self.arena:GetAttribute(name)
 if typeof(value)~="number" or value~=value or math.abs(value)==math.huge then return fallback end
 return math.max(minimum or 0,value)
end

function Service:_active(player,record)
 return self.tag.active and self.tag.phase=="Playing" and record and record.participating and not record.frozen
  and record.humanoid and record.humanoid.Health>0 and record.root and record.root.Parent
  and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating")
end

function Service:Request(player,held)
 if typeof(held)~="boolean" then return {ok=false,message="Hold or release sprint."} end
 local record=self.tag.records[player]
 local entry=self.entries[player]
 if not held then
  if entry then entry.held=false entry.lease=0 end
  return {ok=true}
 end
 if player.Parent~=Players or not self:_active(player,record) then return {ok=false,message="Sprint is available during Tag."} end
 if not entry then return {ok=false,message="Sprint is getting ready."} end
 local now=workspace:GetServerTimeNow()
 if now-(entry.lastRequest or -math.huge)<0.075 then return {ok=false,message="Sprint request too soon."} end
 entry.lastRequest=now
 entry.held=true
 entry.lease=now+1
 return {ok=true}
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
   local sprinting=canMove and entry.held and not entry.locked and moving
   if sprinting then
    entry.remaining=math.max(0,entry.remaining-delta)
    if entry.remaining<=0 then entry.locked=true sprinting=false end
   else
    entry.remaining=math.min(maximum,entry.remaining+delta*maximum/self:_setting("SprintRefillSeconds",15,0.1))
    if entry.locked and entry.remaining>=maximum-0.00001 then entry.locked=false end
   end
   if record.humanoid and record.humanoid.Health>0 then
    local fallback=record.role=="Tagger" and 18 or 16
    local base=self:_setting(record.role=="Tagger" and "TaggerWalkSpeed" or "RunnerWalkSpeed",fallback,0)
    record.humanoid.WalkSpeed=record.frozen and 0 or base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)
   end
   set(player,"TGSprintMax",maximum)
   set(player,"TGSprintRemaining",entry.remaining)
   set(player,"TGSprinting",sprinting)
   set(player,"TGSprintExhausted",entry.locked)
  end
 end
end

function Service:Start()
 if self.running then return end
 self.running=true
 runningService=self
 self.remote=ReplicatedStorage:WaitForChild("TagSprintRequest")
 self.remote.OnServerInvoke=function(player,held) return self:Request(player,held) end
 local accumulated=0
 table.insert(self.connections,RunService.Heartbeat:Connect(function(delta)
  accumulated+=delta
  if accumulated>=0.05 then local step=accumulated accumulated=0 self:_tick(math.min(step,0.25)) end
 end))
 table.insert(self.connections,Players.PlayerRemoving:Connect(function(player) self.entries[player]=nil end))
end

function Service:Stop()
 self.running=false
 if self.remote then self.remote.OnServerInvoke=nil end
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 table.clear(self.connections)
 for player in pairs(self.entries) do
  local record=self.tag.records[player]
  if record and record.participating and player:GetAttribute("TGParticipating")==true
   and not player:GetAttribute("BBParticipating") and not player:GetAttribute("MDParticipating") then self.tag:_movement(record) end
  set(player,"TGSprinting",false)
 end
 table.clear(self.entries)
 if runningService==self then runningService=nil end
end

function Service.GetRunningService() return runningService end

return Service
