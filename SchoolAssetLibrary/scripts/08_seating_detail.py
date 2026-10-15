def select_asset(fragment):
 global ROOT,COL
 rec=next(r for r in ASSETS if fragment in r['name']);ROOT=bpy.data.objects[rec['root']];COL=bpy.data.collections[rec['collection']];return ROOT
def findpart(fragment):return next(o for o in COL.objects if fragment in o.name)
def rr(w,h,r,n=14):
 pts=[]
 for cx,cy,start in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,pi/2),(-w/2+r,-h/2+r,pi),(w/2-r,-h/2+r,pi*1.5)]:
  for i in range(n):
   a=start+pi*.5*i/n;pts.append((cx+r*cos(a),cy+r*sin(a)))
 return pts
def screw(name,loc,axis=(0,-1,0),r=.009,material='metal'):
 direction=Vector(axis).normalized();a=Vector(loc);rod(name,a,a+direction*.003,r,material,24)
 rod('Recessed hex socket',a+direction*.0031,a+direction*.0036,r*.38,'rubber',6)
def seam_cushion(ob,plane='XY'):
 coords=[v.co for v in ob.data.vertices];dx=max(v.x for v in coords)-min(v.x for v in coords);dy=max(v.y for v in coords)-min(v.y for v in coords);dz=max(v.z for v in coords)-min(v.z for v in coords)
 w,h=(dx,dy) if plane=='XY' else (dx,dz)
 def at(x,y):
  v=Vector((x,y,dz/2-.006)) if plane=='XY' else Vector((x,-dy/2-.0008,y))
  return tuple(ob.matrix_basis@v)
 pts=[at(x,y) for x,y in rr(w-.016,h-.016,min(.044,w*.1,h*.1),20)]
 tube('Rolled upholstery piping',pts,.0024,'seam',True)
 points=[at(x,y) for x,y in rr(w-.042,h-.042,min(.042,w*.1,h*.1),35)]
 tube('Inset stitched seam',points,.00065,'thread',True)
 for i in range(0,len(points)-1,2):rod('Individual upholstery stitch',points[i],points[i+1],.00085,'thread',6)
def seat_scoop(old,material,w=.46,d=.445):
 loc=old.location.copy();bpy.data.objects.remove(old,do_unlink=True)
 outer=rr(w,d,.065,12);n=len(outer);vs=[];rings=[.05,.25,.50,.75,1]
 for bottom in [False,True]:
  for rad in rings:
   for x,y in outer:
    x*=rad;y*=rad;z=.015*(x/(w*.5))**2+.012*(y/(d*.5))**2-.009*(max(0,-y/(d*.5))**6)
    vs.append((x,y,z-(.044 if bottom else 0)))
 fs=[];k=len(rings)*n
 for side in [0,1]:
  off=side*k
  for ring in range(4):
   for j in range(n):fs.append((off+ring*n+j,off+ring*n+(j+1)%n,off+(ring+1)*n+(j+1)%n,off+(ring+1)*n+j))
  fs.append(tuple(off+j for j in range(n)))
 for j in range(n):a=4*n+j;b=4*n+(j+1)%n;fs.append((a,b,b+k,a+k))
 o=mesh('Contoured waterfall seat shell',vs,fs,material,(loc.x,loc.y,loc.z+.024),True);bevel(o,.004,4)
 return o

for fragment,material in [('Maths','sand'),('Technology swivel','taupe'),('Art cantilever','ivory')]:
 select_asset(fragment);old=findpart('seat');seat_scoop(old,material)
 back=findpart('Curved ergonomic back shell')
 if fragment!='Technology swivel':
  cut=box('Hidden handhold cutter',(0,.195,.827),(.155,.24,.036),'black',.017)
  mod=back.modifiers.new('Rounded carry handle cutout','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;cut.hide_render=True;cut.hide_set(True)
 for x in [-.165,.165]:
  screw('Seat fixing',(x,-.135,.510),(0,0,1),.0065)
  screw('Back fixing',(x,.174,.622),(0,-1,0),.0065)
 for x in [-.16,.16]:box('Under-seat mounting bracket',(x,.005,.432),(.038,.18,.015),'black',.004)
 tube('Seat underside strengthening rim',[(x,y,.466) for x,y in rr(.412,.394,.053,18)],.006,material,True)

select_asset('Science lab')
tube('Rounded stool seat rim',[(.236*cos(2*pi*i/96),.236*sin(2*pi*i/96),.708) for i in range(96)],.004,'wood',True)
cylinder('Underseat mounting plate',(0,0,.647),.165,.014,'black',40)
for i in range(4):
 a=pi/4+i*pi/2;screw('Seat mount bolt',(.13*cos(a),.13*sin(a),.635),(0,0,-1),.008)
for r in [.17,.18]:tube('Subtle turned seat groove',[(r*cos(2*pi*i/96),r*sin(2*pi*i/96),.719) for i in range(96)],.0006,'wood',True)

for fragment in ['Technology swivel','Staff 01']:
 select_asset(fragment)
 for old in [o for o in COL.objects if 'Twin caster' in o.name]:bpy.data.objects.remove(old,do_unlink=True)
 radius=.29 if 'Technology' in fragment else .36
 for i in range(5):
  a=2*pi*i/5;p=Vector((radius*cos(a),radius*sin(a),.044));side=Vector((-sin(a),cos(a),0));direction=Vector((cos(a),sin(a),0))
  for sign in [-1,1]:
   c=p+side*.019*sign;rod('Individual castor wheel',c-side*.012,c+side*.012,.040,'rubber',32);rod('Castor wheel hub',c+side*.012,c+side*.014,.018,'metal',20)
  rod('Castor axle',p-side*.043,p+side*.043,.009,'black',16)
  cylinder('Swivel caster stem',(p.x,p.y,.102),.017,.07,'metal',20)
 box('Tilt mechanism housing',(0,.025,.386),(.23,.22,.056),'black',.018)
 rod('Seat adjustment paddle stem',(.08,-.04,.392),(.25,-.04,.375),.009,'metal')
 box('Adjustment paddle',(.25,-.04,.371),(.075,.045,.018),'rubber',.008)
 cylinder('Tension adjustment knob',(0,-.12,.357),.037,.052,'black',28)
 for i in range(16):
  a=2*pi*i/16;rod('Knob grip flute',(.037*cos(a),-.12+.037*sin(a),.337),(.037*cos(a),-.12+.037*sin(a),.374),.002,'rubber',6)

for fragment in ['Music posture','Staff 01','Staff 02','Staff 03','Piano bench']:
 select_asset(fragment)
 for ob in list(COL.objects):
  if ob.type!='MESH':continue
  name=ob.name.lower()
  if any(t in name for t in ['padded back','upholstered back','lounge back']):seam_cushion(ob,'XZ')
  elif any(t in name for t in ['upholstered seat','plush seat','loose seat cushion','lounge cushion','upholstered piano bench']):seam_cushion(ob,'XY')
select_asset('Staff 01')
back=findpart('High upholstered back')
for z in [-.13,.09]:
 pts=[tuple(back.matrix_basis@Vector((-.22+i*.44/40,-.061,z))) for i in range(41)];tube('Horizontal upholstery channel',pts,.0012,'seam')
for x in [-.32,.32]:
 screw('Armrest fixing',(x,-.105,.66),(0,0,-1),.008)
select_asset('Staff 02')
pts=[]
for i in range(90):
 a=-.12+(pi+.24)*i/89;pts.append((.379*cos(a),.379*sin(a)-.01,.67+.20*max(0,sin(a))+.003))
tube('Tub chair continuous top piping',pts,.0032,'thread')
for x in [-.28,.28]:
 for y in [-.23,.23]:screw('Foot bracket fixing',(x,y,.197),(0,0,-1),.011)
select_asset('Staff 03')
for x in [-.34,.34]:
 for y in [-.23,.23]:screw('Oak frame dowel',(x,y,.622),(0,0,1),.009,'wood')
print('Seating upgraded with contoured shells, carry handles, real caster assemblies, stitching and fittings')
