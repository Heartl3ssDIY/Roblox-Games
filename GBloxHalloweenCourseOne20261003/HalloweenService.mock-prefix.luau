local Vector = {}
local vectorMeta = {}
vectorMeta.__index = function(self, key)
 if key == "Magnitude" then return math.sqrt(self.X*self.X + self.Y*self.Y + self.Z*self.Z) end
 if key == "Unit" then local n = self.Magnitude return n > 0 and self/n or setmetatable({X=0,Y=0,Z=0}, vectorMeta) end
 return Vector[key]
end
vectorMeta.__add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectorMeta) end
vectorMeta.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vectorMeta) end
vectorMeta.__unm = function(a) return setmetatable({X=-a.X,Y=-a.Y,Z=-a.Z},vectorMeta) end
vectorMeta.__mul = function(a,b)
 if type(a)=="number" then a,b=b,a end
 return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vectorMeta)
end
vectorMeta.__div = function(a,b) return a*(1/b) end
function Vector:Dot(other) return self.X*other.X+self.Y*other.Y+self.Z*other.Z end
local Vector3 = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero=Vector3.new(0,0,0)
Vector3.xAxis=Vector3.new(1,0,0)
Vector3.yAxis=Vector3.new(0,1,0)
Vector3.zAxis=Vector3.new(0,0,1)

local Frame = {}
local frameMeta = {}
local CFrame = {}
function CFrame.new(x,y,z)
 local position = type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
 return setmetatable({Position=position,sign=1},frameMeta)
end
frameMeta.__index = function(self,key)
 if key=="Rotation" then local rotation=CFrame.new() rotation.sign=self.sign return rotation end
 if key=="RightVector" then return Vector3.new(self.sign,0,0) end
 if key=="UpVector" then return Vector3.new(0,self.sign,0) end
 if key=="ZVector" then return Vector3.zAxis end
 return Frame[key]
end
function Frame:PointToObjectSpace(position)
 local offset=position-self.Position
 return Vector3.new(offset.X*self.sign,offset.Y*self.sign,offset.Z)
end
function Frame:ToObjectSpace(other)
 local result=CFrame.new(self:PointToObjectSpace(other.Position))
 result.sign=self.sign*other.sign
 return result
end
frameMeta.__mul = function(a,b)
 if getmetatable(b)==vectorMeta then return a.Position+Vector3.new(b.X*a.sign,b.Y*a.sign,b.Z) end
 local result=CFrame.new(a*b.Position)
 result.sign=a.sign*b.sign
 return result
end
function CFrame.lookAt(position,_target,up)
 local frame=CFrame.new(position) frame.sign=up.Y return frame
end
function CFrame.Angles() return CFrame.new() end
CFrame.identity=CFrame.new()

local methods = {}
local instanceMeta = {}
local Instance = {}
instanceMeta.__index=function(self,key)
 if key=="Position" then return self._properties.CFrame.Position end
 return methods[key] or self._properties[key]
end
instanceMeta.__newindex=function(self,key,value)
 if key=="Parent" then
  local previous=self._properties.Parent
  if previous then
   local index=table.find(previous._children,self)
   if index then table.remove(previous._children,index) end
  end
  self._properties.Parent=value
  if value then table.insert(value._children,self) end
 else self._properties[key]=value end
end
function Instance.new(class)
 return setmetatable({_attrs={},_children={},_properties={ClassName=class,Name=class,Size=Vector3.new(2,2,2),CFrame=CFrame.new(),WorldPivot=CFrame.new(),Transparency=0}},instanceMeta)
end
function methods:IsA(class)
 return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation"))
end
function methods:SetAttribute(name,value) self._attrs[name]=value end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
 local result={}
 local function add(object)
  for _,child in object._children do table.insert(result,child) add(child) end
 end
 add(self)
 return result
end
function methods:FindFirstChild(name,recursive)
 for _,child in self._children do if child.Name==name then return child end end
 if recursive then
  for _,child in self._children do local result=child:FindFirstChild(name,true) if result then return result end end
 end
 return nil
end
function methods:IsDescendantOf(ancestor)
 local current=self.Parent
 while current do if current==ancestor then return true end current=current.Parent end
 return false
end
function methods:Destroy()
 self.Parent=nil
 for _,child in self:GetChildren() do child:Destroy() end
 self.Destroyed=true
end
function methods:Clone()
 local clone=Instance.new(self.ClassName)
 for key,value in self._properties do if key~="Parent" then clone[key]=value end end
 clone._attrs=table.clone(self._attrs)
 for _,child in self._children do local copied=child:Clone() copied.Parent=clone end
 return clone
end
function methods:GetPivot() return self.WorldPivot end
function methods:PivotTo(frame)
 local previous=self:GetPivot()
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then object.CFrame=frame*previous:ToObjectSpace(object.CFrame)
  elseif object:IsA("Model") then object.WorldPivot=frame*previous:ToObjectSpace(object.WorldPivot) end
 end
 self.WorldPivot=frame
end
function methods:GetScale() return self.Scale or 1 end
function methods:ScaleTo(value)
 local factor=value/self:GetScale()
 local frame=self:GetPivot()
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then
   object.Size*=factor
   object.CFrame=CFrame.new(frame.Position+(object.Position-frame.Position)*factor)
  end
 end
 self.Scale=value
end
function methods:GetBoundingBox()
 local center=self:GetPivot().Position
 local maximum=Vector3.new(0,0,0)
 for _,object in self:GetDescendants() do
  if object:IsA("BasePart") then
   local offset=object.Position-center
   maximum=Vector3.new(math.max(maximum.X,math.abs(offset.X)+object.Size.X/2),math.max(maximum.Y,math.abs(offset.Y)+object.Size.Y/2),math.max(maximum.Z,math.abs(offset.Z)+object.Size.Z/2))
  end
 end
 return CFrame.new(center),maximum*2
end

local Players=Instance.new("Folder")
local ReplicatedStorage=Instance.new("Folder")
local Workspace=Instance.new("Folder")
local currentSupport
function methods:Raycast(position,direction,_parameters)
 return currentSupport and {Position=Vector3.new(position.X,0,position.Z),Normal=direction.Y>0 and -Vector3.yAxis or Vector3.yAxis,Instance=currentSupport} or nil
end
local game={}
function game:GetService(name)
 if name=="Players" then return Players end
 if name=="ReplicatedStorage" then return ReplicatedStorage end
 if name=="Workspace" then return Workspace end
 error("Unexpected service "..name)
end
local Enum={RaycastFilterType={Include="Include"}}
local RaycastParams={new=function() return {} end}
local function typeof(value)
 if getmetatable(value)==vectorMeta then return "Vector3" end
 return type(value)
end

local Subject=(function()
