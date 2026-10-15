local root=workspace:FindFirstChild("G-Blox NEW Lobby - Cloud Club")
assert(root)
local O=root.PrimaryPart.Position+Vector3.new(0,1.5,0)
for _,o in root:GetDescendants() do
 if o:IsA("PointLight") then o.Brightness=o.Name=="Soft indoor fill" and .32 or .45 end
 if o:IsA("SurfaceGui") and o.Name=="Lettering" then o.CanvasSize=Vector2.new(o.Parent.Size.X*8,o.Parent.Size.Y*8) end
end
-- Replace only our placeholder star geometry with true five-point silhouettes.
local roof=root:FindFirstChild("03 CLOSED Roof and Clouds")
for _,o in roof:GetChildren() do if o.Name=="Hanging star" or o.Name=="Star center" then o:Destroy() end end
local function triangle(a,b,c)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc) and ac:Dot(ac)>ab:Dot(ab) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local right=ac:Cross(ab).Unit local back=bc.Unit local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 for i,v in {{(a+b)/2,right,back,math.abs(ab:Dot(back))},{(a+c)/2,-right,-back,math.abs(ac:Dot(back))}} do
  if v[4]>.001 then
   local p=Instance.new("WedgePart") p.Name="Five point star"
   p.Size=Vector3.new(.55,height,v[4]) p.CFrame=CFrame.fromMatrix(v[1],v[2],up,v[3])
   p.Color=Color3.fromRGB(255,205,55) p.Material=Enum.Material.SmoothPlastic
   p.Anchored=true p.CanCollide=false p.CanTouch=false p.Parent=roof
  end
 end
end
for _,xz in {{-58,-62},{64,-64},{-84,7},{75,54},{-21,70},{32,21}} do
 local center=O+Vector3.new(xz[1],38,xz[2])
 local points={}
 for i=0,9 do local angle=math.pi/2+i*math.pi/5 local r=i%2==0 and 3.4 or 1.5
  table.insert(points,center+Vector3.new(math.cos(angle)*r,math.sin(angle)*r,0))
 end
 for i=1,10 do triangle(center,points[i],points[i%10+1]) end
end
return "Reduced local light glare, enlarged sign lettering, and refined five-point hanging stars. Still in Edit mode."
