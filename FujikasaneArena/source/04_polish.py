exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\FujikasaneArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
for v in bpy.data.objects['Forest_earth'].data.vertices:v.co.z=ground_height(v.co.x,v.co.y)
bpy.data.objects['Forest_earth'].data.update()
for ob in collection('05_Rock_Outcrops').objects:ob.location.z=ground_height(ob.location.x,ob.location.y)
for v in bpy.data.objects['Soft_moss_patches'].data.vertices:v.co.z=ground_height(v.co.x,v.co.y)+.025
for v in bpy.data.objects['Woodland_grass'].data.vertices:
 v.co.z=ground_height(v.co.x,v.co.y)+max(.035,min(.9,v.co.z%1))
positions=[]
for side in [-1,1]:
 for j,y in enumerate([-62,-33,-3,28,59]):positions.append((side*(57+(-1 if j%2 else 2)),y,25+(j%3)*1.8))
positions += [(-30,86,26),(0,91,27),(30,86,25),(-32,-83,24),(32,-83,26)]
flower_mat=bpy.data.materials['Fujikasane | softly luminous wisteria']
for index,(x,y,h) in enumerate(positions):
 trunk=next(o for o in collection('20_Tree_%02d'%index).objects if o.name.startswith('Twisted_wisteria_trunk'))
 base=sum((trunk.matrix_world@v.co).z for v in list(trunk.data.vertices)[:10])/10;delta=ground_height(x,y)-base
 for group in ['20_Tree_%02d'%index,'21_Blossoms_%02d'%index,'23_Canopy_%02d'%index]:
  for ob in collection(group).objects:ob.location.z+=delta
 rng=random.Random(1600+index);surface=Builder()
 for ob in collection('23_Canopy_%02d'%index).objects:
  if not ob.name.startswith('Wisteria_crown'):continue
  coords=[v.co for v in ob.data.vertices];lo=Vector(tuple(min(v[j] for v in coords) for j in range(3)));hi=Vector(tuple(max(v[j] for v in coords) for j in range(3)));center=(lo+hi)/2
  # Uneven crown height and spread break the uniform umbrella silhouette.
  stretch=Vector((rng.uniform(.91,1.1),rng.uniform(.91,1.1),rng.uniform(1.35,1.85)))
  offset=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-.8,2)))
  for v in ob.data.vertices:
   p=v.co-center;v.co=center+Vector((p.x*stretch.x,p.y*stretch.y,p.z*stretch.z))+offset
  ob.data.update()
  for poly in ob.data.polygons:
   if poly.normal.z<.16 or rng.random()>.38:continue
   p=sum((ob.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
   p=ob.matrix_world@p;normal=poly.normal.normalized();p+=normal*.075
   tangent=normal.cross(Vector((0,1,0))).normalized();side=normal.cross(tangent)
   w=rng.uniform(.19,.40)
   surface.face([p+tangent*w,p+side*w*.66,p-tangent*w,p-side*w*.66],rng.choice([11,12,13]),True)
 ob=surface.build('Crown_small_blossom_petals','24_Crown_Detail');ob.data.materials.clear();ob.data.materials.append(flower_mat)
sc=bpy.context.scene
for name,cam,w,h in [('Fujikasane_Hero.png','FK_Camera_Hero',1700,1400),('Fujikasane_Approach.png','FK_Camera_Approach',1600,1100)]:
 sc.camera=bpy.data.objects[cam];sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
sc.camera=bpy.data.objects['FK_Camera_Hero']
bpy.data.libraries.write(os.path.join(ROOT,'Fujikasane_Arena_Editable.blend'),{sc},fake_user=True,compress=True)
print('Adjusted crown shapes, anchored trees and smoothed clearing approach')
