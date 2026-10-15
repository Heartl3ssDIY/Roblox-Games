-- Small, deterministic, client-local effects. No physics, damage, lights or external assets.
local V={}
V.Duration={DefaultDeath=1.35,GreenFinish=1.65}
local function part(parent,name,color,size)
 local p=Instance.new("Part")
 p.Name=name p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.CastShadow=false p.Material=Enum.Material.Neon p.Color=color p.Size=size
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent
 return p
end
function V.Create(packet,parent)
 if type(packet)~="table" or not V.Duration[packet.Kind] or typeof(packet.Origin)~="CFrame" then return nil end
 local finish=packet.Kind=="GreenFinish"
 local random=Random.new(packet.Seed or 1)
 local folder=Instance.new("Model") folder.Name=finish and "GreenFinish" or "DefaultDeath"
 local base=packet.Origin.Position
 local bits={}
 local count=finish and 26 or 18
 for i=1,count do
  local color=finish and (i%3==0 and Color3.fromRGB(192,255,179) or Color3.fromRGB(62,246,119))
   or (i%3==0 and Color3.fromRGB(150,250,255) or i%2==0 and Color3.fromRGB(0,196,218) or Color3.fromRGB(53,114,222))
  local size=finish and random:NextNumber(.12,.27) or random:NextNumber(.25,.65)
  local p=part(folder,"Pixel"..i,color,Vector3.one*size)
  local offset=finish and Vector3.new(random:NextNumber(-1.7,1.7),random:NextNumber(-2.4,2.4),random:NextNumber(-.7,.7)) or Vector3.zero
  local angle=random:NextNumber(0,math.pi*2)
  local speed=random:NextNumber(4,9)
  local velocity=finish and Vector3.new(random:NextNumber(-1.2,1.2),random:NextNumber(2,5),random:NextNumber(-.7,.7))
   or Vector3.new(math.cos(angle)*speed,math.sin(angle)*speed+3,random:NextNumber(-2.5,2.5))
  table.insert(bits,{p=p,size=size,offset=offset,velocity=velocity,spin=random:NextNumber(-5,5),delay=finish and random:NextNumber(0,.4) or 0})
 end
 local core
 if not finish then
  core=part(folder,"SoftBurst",Color3.fromRGB(135,243,255),Vector3.one*.5)
  core.Shape=Enum.PartType.Ball
 end
 local anchor=part(folder,"ParticleOrigin",Color3.new(1,1,1),Vector3.one)
 anchor.Transparency=1 anchor.CFrame=CFrame.new(base)
 local emitter=Instance.new("ParticleEmitter")
 emitter.Name=finish and "GreenSparkles" or "SmokePuff"
 emitter.Enabled=false emitter.Rate=0
 emitter.Texture=finish and "rbxasset://textures/particles/sparkles_main.dds" or "rbxasset://textures/particles/smoke_main.dds"
 emitter.Color=ColorSequence.new(finish and Color3.fromRGB(77,255,134) or Color3.fromRGB(105,160,178))
 emitter.LightEmission=finish and .6 or .1
 emitter.LightInfluence=0 emitter.Lifetime=NumberRange.new(.55,1.15)
 emitter.Speed=finish and NumberRange.new(2,5) or NumberRange.new(2,6)
 emitter.SpreadAngle=finish and Vector2.new(40,40) or Vector2.new(180,180)
 emitter.Acceleration=Vector3.new(0,finish and 3 or 2,0)
 emitter.Drag=2
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,finish and .35 or .7),NumberSequenceKeypoint.new(.35,finish and .55 or 2),NumberSequenceKeypoint.new(1,0)})
 emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,finish and .15 or .65),NumberSequenceKeypoint.new(.45,finish and .3 or .8),NumberSequenceKeypoint.new(1,1)})
 emitter.Rotation=NumberRange.new(0,360) emitter.RotSpeed=NumberRange.new(-50,50)
 emitter.Parent=anchor
 folder.Parent=parent
 local h={Model=folder,Duration=V.Duration[packet.Kind],Emitter=emitter}
 function h:Update(age)
  age=math.max(0,age)
  for _,bit in bits do
   local t=math.max(0,age-bit.delay)
   local fade=finish and math.clamp((t-.3)/.95,0,1) or math.clamp((t-.15)/1.05,0,1)
   bit.p.Transparency=age<bit.delay and 1 or fade
   bit.p.Size=Vector3.one*math.max(.01,bit.size*(1-fade*.85))
   local fall=finish and Vector3.zero or Vector3.new(0,-5*t*t,0)
   bit.p.CFrame=CFrame.new(base+bit.offset+bit.velocity*t+fall)*CFrame.Angles(0,0,bit.spin*t)
  end
  if core then
   local t=math.clamp(age/.32,0,1)
   core.CFrame=CFrame.new(base) core.Size=Vector3.one*(.5+6*t)
   core.Transparency=.62+.38*t
  end
  return age<self.Duration
 end
 function h:Burst() if folder.Parent then emitter:Emit(finish and 22 or 12) end end
 function h:Destroy() folder:Destroy() end
 h:Update(0)
 return h
end
return V

