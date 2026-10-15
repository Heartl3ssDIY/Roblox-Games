import bpy,os,re,math
from mathutils import Vector
ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall'
path=os.path.join(ROOT,'source','common.py')
source=open(path,encoding='utf-8').read()
source=re.sub(r'PALETTE=\[[^\n]+\]',"PALETTE=[(142,155,113),(135,148,108),( ninety,83,70),(118,130,128),(37,70,67),(70,101,90),(83,57,48),(137,115,88),(150,136,104),(45,50,43),(80,113,130),(131,166,170),(198,133,62),(225,175,80),(50,70,60),(154,162,151)]".replace('ninety','90'),source)
open(path,'w',encoding='utf-8').write(source)
exec(compile(source,'common.py','exec'))
old=MAT;old.name='Chunin | original palette'
MAT=make_atlas()
for ob in bpy.context.scene.objects:
 if ob.type=='MESH' and ob.get('surface') is not None:
  ob.data.materials.clear();ob.data.materials.append(MAT)
  cat=int(ob['surface'])
  if ob.name.startswith('Floor_Tile'):
   cat=1 if random.random()<.22 else 0
  if ob.name.startswith('Upper_Wall_Panel'):cat=15
  if ob.name.startswith('Gallery_Walking_Surface') or ob.name.startswith('Access_Stair'):cat=3
  ob['surface']=cat;atlas_uv(ob,cat)
ob=bpy.data.objects.get('Dais_Semicircle')
bpy.data.objects.remove(ob,do_unlink=True)
coords=[(13*cos(-pi*j/32),26+13*sin(-pi*j/32)) for j in range(33)]
n=len(coords)
mesh('Dais_Semicircle',[(x,y,.2) for x,y in coords]+[(x,y,1.5) for x,y in coords],
 [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],0,'04_Judges_Dais')
# Fuse the clay volumes into one continuous stone sculpture, retaining engraved crease pieces.
parts=[o for o in collection('10_Hand_Seal').objects if 'Crease' not in o.name]
for ob in bpy.context.selected_objects:ob.select_set(False)
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join();hand=bpy.context.object;hand.name='Sculpted_Hand_Seal'
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
rem=hand.modifiers.new('Stone union','REMESH');rem.mode='VOXEL';rem.voxel_size=.17
rem.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=rem.name)
smooth=hand.modifiers.new('Stone smoothing','SMOOTH');smooth.factor=.7;smooth.iterations=3
bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=hand.modifiers.new('Game mesh reduction','DECIMATE');dec.ratio=.4
bpy.ops.object.modifier_apply(modifier=dec.name)
hand.data.materials.clear();hand.data.materials.append(MAT);hand['surface']=8;atlas_uv(hand,8)
# Wider dark floor dividers establish the reference's large stone grid.
for ob in collection('03_Floor_Weathering').objects:
 if ob.name.startswith('Floor_Major_Seam_X'):ob.scale.x=1.6
 if ob.name.startswith('Floor_Major_Seam_Y'):ob.scale.y=1.6
scene=bpy.context.scene
scene.render.resolution_x=1500;scene.render.resolution_y=1200
scene.render.filepath=os.path.join(ROOT,'previews','Chunin_Hall_Hero.png')
scene.camera=bpy.data.objects['Camera_Hall_Hero']
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Chunin_Exam_Hall_Editable.blend'))
bpy.ops.render.render(write_still=True)
print("Refined materials and sculpture rendered.")
