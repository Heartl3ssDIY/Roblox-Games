local Vector = {}
local vectorMeta = {}
vectorMeta.__index = function(self, key)
 if key == "Magnitude" then return math.sqrt(self.X*self.X + self.Y*self.Y + self.Z*self.Z) end
 return Vector[key]
end
vectorMeta.__add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectorMeta) end
vectorMeta.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vectorMeta) end
vectorMeta.__mul = function(a,b) return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vectorMeta) end
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero = Vector3.new(0,0,0)

local Frame = {}
local frameMeta = {}
local CFrame = {}
function CFrame.new(x,y,z)
 return setmetatable({Position=type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0), sign=1},frameMeta)
end
frameMeta.__index = Frame
frameMeta.__mul = function(a,b)
 return setmetatable({Position=a.Position+Vector3.new(b.Position.X,b.Position.Y*a.sign,b.Position.Z*a.sign),sign=a.sign*b.sign},frameMeta)
end
function Frame:ToObjectSpace(b)
 local delta=b.Position-self.Position
 return setmetatable({Position=Vector3.new(delta.X,delta.Y*self.sign,delta.Z*self.sign),sign=self.sign*b.sign},frameMeta)
end
CFrame.identity = CFrame.new()

local methods = {}
local instanceMeta = {}
local Instance = {}
instanceMeta.__index = function(self,key)
 if key == "CFrame" and self:IsA("BasePart") and self._properties.Anchored == false then
  for _, weld in self._children do
   if weld:IsA("Weld") and weld.Part1==self and weld.Part0 then return weld.Part0.CFrame * weld.C0 end
   if weld:IsA("WeldConstraint") and weld.Part1==self and weld.Part0 then return weld.Part0.CFrame * weld._properties.LocalFrame end
  end
 end
 if key=="Position" then return self.CFrame.Position end
 if key=="WorldCFrame" and self:IsA("Attachment") then return self.Parent.CFrame*self.CFrame end
 return methods[key] or self._properties[key]
end
instanceMeta.__newindex = function(self,key,value)
 if key=="Parent" then
  local previous=self._properties.Parent
  if previous then local index=table.find(previous._children,self) if index then table.remove(previous._children,index) end end
  if value and self:IsA("WeldConstraint") then self._properties.LocalFrame=self.Part0.CFrame:ToObjectSpace(self.Part1.CFrame) end
  self._properties.Parent=value
  if value then table.insert(value._children,self) end
 elseif key=="Anchored" and value==true and self._properties.Anchored==false then
  self._properties.CFrame=self.CFrame
  self._properties.Anchored=value
 else self._properties[key]=value end
end
function Instance.new(class)
 return setmetatable({_children={},_properties={ClassName=class,Name=class,CFrame=CFrame.new(),PivotOffset=CFrame.identity,WorldPivot=CFrame.new(),Size=Vector3.new(1,2,1),Anchored=true}},instanceMeta)
end
function methods:IsA(class)
 return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart"))
  or (class=="JointInstance" and self.ClassName=="Weld")
end
function methods:GetDescendants()
 local result={}
 local function visit(v) for _,c in v._children do table.insert(result,c) visit(c) end end
 visit(self)
 return result
end
function methods:FindFirstChild(name)
 for _,c in self._children do if c.Name==name then return c end end
 return nil
end
function methods:IsDescendantOf(ancestor)
 local current=self.Parent
 while current do if current==ancestor then return true end current=current.Parent end
 return false
end
function methods:Destroy()
 if self:IsA("Weld") and self.Part1 and self.Part1.Parent then self.Part1._properties.CFrame=self.Part1.CFrame end
 if self:IsA("WeldConstraint") and self.Part1 and self.Part1.Parent then self.Part1._properties.CFrame=self.Part1.CFrame end
 for _,c in table.clone(self._children) do c:Destroy() end
 self.Parent=nil
 self.Destroyed=true
end
function methods:GetPivot()
 return self.PrimaryPart and self.PrimaryPart.CFrame*self.PrimaryPart.PivotOffset or self.WorldPivot
end
function methods:PivotTo(frame)
 local old=self:GetPivot()
 local parts={}
 for _,c in self:GetDescendants() do if c:IsA("BasePart") then table.insert(parts,{c,old:ToObjectSpace(c.CFrame)}) end end
 for _,entry in parts do entry[1].CFrame=frame*entry[2] end
 self.WorldPivot=frame
end

local Subject=(function()
local Throw = {}

local function finite(value)
 return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function handFor(data)
 if not data or not data.character or not data.character.Parent or not data.root or not data.root.Parent
  or not data.root:IsDescendantOf(data.character) then return nil end
 for _, name in {"RightHand", "Right Arm"} do
  local hand = data.character:FindFirstChild(name)
  if hand and hand:IsA("BasePart") then return hand end
 end
 return nil
end

local function partsFor(model)
 if not model or not model.Parent then return nil end
 if model:IsA("BasePart") then return {model} end
 if not model:IsA("Model") then return nil end
 local parts = {}
 for _, object in model:GetDescendants() do
  if object:IsA("BasePart") then table.insert(parts, object) end
 end
 return #parts > 0 and parts or nil
end

local function currentFrame(state)
 return state.model:IsA("Model") and state.model:GetPivot() or state.model.CFrame
end

local function valid(state)
 local data = state.data
 return state.model.Parent and state.character.Parent and data.character == state.character
  and data.root == state.root and state.root.Parent and state.root:IsDescendantOf(state.character)
  and state.hand.Parent and state.hand:IsDescendantOf(state.character)
  and not data.recovering and (not data.status or data.status == "Running")
  and (not data.humanoid or data.humanoid.Health > 0)
end

function Throw.CanHold(data)
 return handFor(data) ~= nil
end

function Throw.Begin(model, data, now, holdSeconds)
 local hand = handFor(data)
 local parts = partsFor(model)
 if not hand or not parts or not finite(now) then return nil, "The pumpkin cannot be held yet." end
 holdSeconds = finite(holdSeconds) and math.clamp(holdSeconds, 0.15, 1) or 0.4
 local carrier = parts[1]
 local initialFrame = model:IsA("Model") and model:GetPivot() or model.CFrame
 for _, object in model:GetDescendants() do
  if object:IsA("JointInstance") or object:IsA("WeldConstraint") then object:Destroy() end
 end
 for _, part in parts do
  part.Anchored = true
  part.Massless = true
  part.CanCollide = false
  part.CanTouch = false
  part.CanQuery = false
  part.CastShadow = false
 end
 if model:IsA("Model") then
  carrier.PivotOffset = carrier.CFrame:ToObjectSpace(initialFrame)
  model.PrimaryPart = carrier
 else
  carrier.PivotOffset = CFrame.identity
 end
 local grip = hand:FindFirstChild("RightGripAttachment")
 local holdFrame = grip and grip:IsA("Attachment") and grip.WorldCFrame * CFrame.new(0, 0, -0.65)
  or hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.5, -0.65)
 if model:IsA("Model") then model:PivotTo(holdFrame)
 else carrier.CFrame = holdFrame end
 local bodyWelds = {}
 for _, part in parts do
  if part ~= carrier then
   local weld = Instance.new("WeldConstraint")
   weld.Name = "PumpkinBodyWeld"
   weld.Part0 = carrier
   weld.Part1 = part
   weld.Parent = part
   table.insert(bodyWelds, weld)
  end
 end
 local holdWeld = Instance.new("Weld")
 holdWeld.Name = "PumpkinHandHold"
 holdWeld.Part0 = hand
 holdWeld.Part1 = carrier
 holdWeld.C0 = hand.CFrame:ToObjectSpace(carrier.CFrame)
 holdWeld.C1 = CFrame.identity
 holdWeld.Parent = carrier
 for _, part in parts do part.Anchored = false end
 return {
  model = model, data = data, character = data.character, root = data.root, hand = hand,
  parts = parts, holdWeld = holdWeld, bodyWelds = bodyWelds, baseC0 = holdWeld.C0,
  startedAt = now, releaseAt = now + holdSeconds, phase = "Holding", lastFrame = holdFrame,
 }
end

function Throw.Release(state)
 if not state or state.phase == "Cancelled" then return nil end
 if state.phase == "Released" then return state.lastFrame.Position end
 if state.model.Parent then state.lastFrame = currentFrame(state) end
 if state.holdWeld then state.holdWeld:Destroy() state.holdWeld = nil end
 for _, weld in state.bodyWelds do weld:Destroy() end
 state.bodyWelds = {}
 for _, part in state.parts do
  if part.Parent then part.Anchored = true end
 end
 if state.model.Parent then
  if state.model:IsA("Model") then state.model:PivotTo(state.lastFrame)
  else state.model.CFrame = state.lastFrame end
 end
 state.phase = "Released"
 return state.lastFrame.Position
end

function Throw.Clear(state)
 if not state or state.phase == "Cancelled" then return end
 Throw.Release(state)
 state.phase = "Cancelled"
end

function Throw.Update(state, now)
 if not state or state.phase == "Cancelled" then return "Cancelled", nil end
 if state.phase == "Released" then return "Released", state.lastFrame.Position end
 if not finite(now) or not valid(state) then
  Throw.Clear(state)
  return "Cancelled", nil
 end
 if now >= state.releaseAt then return "Released", Throw.Release(state) end
 local alpha = math.clamp((now - state.startedAt) / (state.releaseAt - state.startedAt), 0, 1)
 state.holdWeld.C0 = state.baseC0 * CFrame.new(0, 0, math.sin(alpha * math.pi) * 0.35)
 state.lastFrame = currentFrame(state)
 return "Holding", state.lastFrame.Position
end

return Throw
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
