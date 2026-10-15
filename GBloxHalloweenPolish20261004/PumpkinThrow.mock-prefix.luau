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
