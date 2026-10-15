local GroundCheck=assert(loadstring(game.ReplicatedStorage.RunnerGroundCheck.Source))()
local root=Instance.new("Part") root.Anchored=false
local character={FindFirstChild=function(_,name) if name=="HumanoidRootPart" then return root end end}
local attrs={GravitySign=1,RunnerAbilityRevision=0,RunnerRecoveryRevision=2,RunnerCourseVersion=3}
local player={Character=character,GetAttribute=function(_,key) return attrs[key] end}
local lastLocalFlip=10 local flipPending=true local pendingRequestId=7 local predictedSign=-1 local lastForcedAbilityRevision=0 local resets=0
local function resetMotion() resets+=1 flipPending=false pendingRequestId=nil predictedSign=nil lastLocalFlip=-math.huge end
local function cancelPredictedFlip(sign)
 local lastAttempt=lastLocalFlip
 resetMotion()
 lastLocalFlip=lastAttempt
 predictedSign=sign
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root and not root.Anchored then
  root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(-1,0,0),Vector3.new(0,sign,0))
  root.AssemblyLinearVelocity=GroundCheck.RejectedVelocity(root.AssemblyLinearVelocity,sign)
 end
end

local function ack(data)

  if (data.abilityRevision or 0)<math.max(lastForcedAbilityRevision,player:GetAttribute("RunnerAbilityRevision") or 0) then return end
		if data.requestId~=pendingRequestId or data.courseVersion~=player:GetAttribute("RunnerCourseVersion")
			or data.recoveryRevision~=(player:GetAttribute("RunnerRecoveryRevision") or 0) then return end
		flipPending = false pendingRequestId=nil
        if data.accepted==false then
         cancelPredictedFlip(data.sign)
        end
		predictedSign = data.sign
	end
local count=0
local function check(value,label) count+=1 assert(value,label) end
local ok,err=xpcall(function()
 for _,sign in {1,-1} do
  attrs.GravitySign=sign
  lastLocalFlip=10 flipPending=true pendingRequestId=7 predictedSign=-sign
  root.AssemblyLinearVelocity=Vector3.new(-48,sign*36,0)
  ack({abilityRevision=0,recoveryRevision=2,courseVersion=3,requestId=7,accepted=false,sign=sign})
  check(root.AssemblyLinearVelocity.Y==0,"no rejected bounce")
  check(root.AssemblyLinearVelocity.X==-48,"forward momentum preserved")
  check(root.CFrame.UpVector.Y==sign,"orientation restored")
  check(not flipPending and pendingRequestId==nil and predictedSign==sign,"prediction cleared")
  check(lastLocalFlip==10,"cooldown preserved")
 end
 flipPending=true pendingRequestId=8 predictedSign=-1
 local before=resets
 ack({abilityRevision=0,recoveryRevision=2,courseVersion=3,requestId=7,accepted=false,sign=1})
 check(resets==before and pendingRequestId==8,"stale request ignored")
 ack({abilityRevision=0,recoveryRevision=1,courseVersion=3,requestId=8,accepted=false,sign=1})
 check(resets==before and pendingRequestId==8,"stale recovery ignored")
 ack({abilityRevision=0,recoveryRevision=2,courseVersion=2,requestId=8,accepted=false,sign=1})
 check(resets==before and pendingRequestId==8,"stale course ignored")
 attrs.RunnerAbilityRevision=1
 ack({abilityRevision=0,recoveryRevision=2,courseVersion=3,requestId=8,accepted=false,sign=1})
 check(resets==before and pendingRequestId==8,"stale ability ignored")
 attrs.RunnerAbilityRevision=0
 root.AssemblyLinearVelocity=Vector3.new(-48,18,0)
 ack({abilityRevision=0,recoveryRevision=2,courseVersion=3,requestId=8,accepted=true,sign=-1})
 check(resets==before and not flipPending and predictedSign==-1 and root.AssemblyLinearVelocity.Y==18,"accepted flip unmodified")
 lastLocalFlip=20 predictedSign=-1 flipPending=true pendingRequestId=9
 cancelPredictedFlip(1)
 check(not flipPending and predictedSign==1 and root.AssemblyLinearVelocity.Y==0,"timeout rollback")
end,debug.traceback)
root:Destroy() assert(ok,err) return {clientChecksPassed=count}
