end)()

local checks=0
local function check(value,message)
 checks+=1
 assert(value,message)
end
local function near(a,b) return math.abs(a-b)<0.00001 end
local world=Instance.new("Folder")
local function runner(rig,sign)
 local character=Instance.new("Model") character.Parent=world
 local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Parent=character
 local hand=Instance.new("Part") hand.Name=rig=="R15" and "RightHand" or "Right Arm" hand.Parent=character
 hand.CFrame=CFrame.new(10,20,30) hand.CFrame.sign=sign or 1
 local data={character=character,root=root,humanoid={Health=100},status="Running",gravitySign=sign or 1}
 return data,hand
end
local function pumpkin(single)
 if single then local part=Instance.new("MeshPart") part.Parent=world return part,{part} end
 local model=Instance.new("Model") model.Parent=world model.WorldPivot=CFrame.new(4,5,6)
 local parts={}
 for index=1,8 do
  local part=Instance.new("MeshPart") part.Name="PumpkinPart"..index part.CFrame=CFrame.new(4+index*.1,5,6) part.Parent=model
  table.insert(parts,part)
 end
 return model,parts
end

local data,hand=runner("R6",1)
local model,parts=pumpkin()
local rootFrame=data.root.CFrame
check(Subject.CanHold(data),"R6 hand supported")
local state=assert(Subject.Begin(model,data,50,.4))
check(state.phase=="Holding" and near(state.releaseAt,50.4),"hold duration")
check(model.PrimaryPart==parts[1],"physics-followed model pivot")
check(#state.bodyWelds==7,"all eight mesh parts welded")
check(state.holdWeld.Part0==hand and state.holdWeld.Part1==parts[1],"prop attached to actual hand")
for _,part in parts do
 check(not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,"held part safe")
end
check(data.root.CFrame==rootFrame and data.root.Anchored,"avatar root unmodified")
local phase,position=Subject.Update(state,50.2)
check(phase=="Holding" and near(position.X,10),"windup stays in hand")
check(near(state.holdWeld.C0.Position.Z,state.baseC0.Position.Z+.35),"pullback only temporary prop weld")
hand.CFrame=CFrame.new(18,20,30)
phase,position=Subject.Update(state,50.4)
check(phase=="Released" and near(position.X,18),"launch uses current hand position")
check(not state.holdWeld and #state.bodyWelds==0,"all hold welds removed before flight")
for _,part in parts do check(part.Anchored,"flying parts anchored") end
check(near(model:GetPivot().Position.X,18),"centered model pivot follows release")
check(near(Subject.Release(state).X,18),"release idempotent")
Subject.Clear(state) Subject.Clear(state)
check(state.phase=="Cancelled" and model.Parent==world,"cleanup idempotent, caller owns model destruction")

local inverted,reverseHand=runner("R6",-1)
local reversedModel=pumpkin()
local reversed=assert(Subject.Begin(reversedModel,inverted,0,.4))
phase,position=Subject.Update(reversed,.1)
check(phase=="Holding" and near(position.Y,21),"inverted gravity uses actual hand orientation")
check(reversedModel:GetPivot().sign==-1,"pumpkin shares inverted hand orientation")
Subject.Clear(reversed)

local r15,r15Hand=runner("R15",1)
local attachment=Instance.new("Attachment") attachment.Name="RightGripAttachment" attachment.CFrame=CFrame.new(0,.3,0) attachment.Parent=r15Hand
local r15Model=pumpkin()
local r15State=assert(Subject.Begin(r15Model,r15,10,.4))
phase,position=Subject.Update(r15State,10.1)
check(phase=="Holding" and near(position.Y,20.3),"R15 grip attachment used")
Subject.Clear(r15State)

local noHand,noHandPart=runner("R6",1) noHandPart:Destroy()
check(not Subject.CanHold(noHand),"missing hand rejected")
check(Subject.Begin(pumpkin(),noHand,0)==nil,"missing hand cannot reserve visual")
check(Subject.Begin(Instance.new("Folder"),data,0)==nil,"unsupported artwork rejected")
check(Subject.Begin(pumpkin(),data,0/0)==nil,"invalid clock rejected")

for _,reason in {"death","replacement","rootReplacement","recovery","spectating","handRemoved","artRemoved"} do
 local owner,ownerHand=runner("R6",1)
 local artwork,meshParts=pumpkin()
 local pending=assert(Subject.Begin(artwork,owner,0,.4))
 if reason=="death" then owner.humanoid.Health=0
 elseif reason=="replacement" then owner.character=Instance.new("Model")
 elseif reason=="rootReplacement" then owner.root=Instance.new("Part")
 elseif reason=="recovery" then owner.recovering=true
 elseif reason=="spectating" then owner.status="Spectating"
 elseif reason=="handRemoved" then ownerHand:Destroy()
 elseif reason=="artRemoved" then artwork:Destroy() end
 phase=Subject.Update(pending,.2)
 check(phase=="Cancelled",reason.." cancels hand hold")
 check(not pending.holdWeld and #pending.bodyWelds==0,reason.." removes constraints")
 for _,part in meshParts do if part.Parent then check(part.Anchored,reason.." unanchors no surviving prop") end end
end

local plain=pumpkin(true)
local plainState=assert(Subject.Begin(plain,data,0,.4))
check(#plainState.parts==1 and #plainState.bodyWelds==0,"single MeshPart supported")
Subject.Clear(plainState)
check(plain.Anchored,"single part cleanup")

local low=assert(Subject.Begin(pumpkin(),data,0,-20))
check(near(low.releaseAt,.15),"hold minimum bounded") Subject.Clear(low)
local high=assert(Subject.Begin(pumpkin(),data,0,20))
check(near(high.releaseAt,1),"hold maximum bounded") Subject.Clear(high)
local default=assert(Subject.Begin(pumpkin(),data,0))
check(near(default.releaseAt,.4),"default hold duration") Subject.Clear(default)
print("Pumpkin throw checks passed: "..checks)
