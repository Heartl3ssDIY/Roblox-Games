def fuse(objects,name,material,group,bone,voxel=.028,target=10000,smooth=4):
    o=join_group(objects,name)
    bpy.context.view_layer.objects.active=o
    # Explicit transforms before remeshing keeps voxel sizes predictable.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mod=o.modifiers.new('Sculpt union','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Relax sculpt','SMOOTH');mod.factor=.7;mod.iterations=smooth
    bpy.ops.object.modifier_apply(modifier=mod.name)
    triangles=sum(len(p.vertices)-2 for p in o.data.polygons)
    if triangles>target:
        mod=o.modifiers.new('Game mesh budget','DECIMATE');mod.ratio=target/triangles
        bpy.ops.object.modifier_apply(modifier=mod.name)
    adopt(o,name,material,group,bone)
    for p in o.data.polygons:p.use_smooth=True
    return o

for s,side in [(1,'Left'),(-1,'Right')]:
    uvball(side+'ShoulderBlend',(s*.805,0,4.41),(.285,.288,.288),fur,bone='UpperTorso')
    uvball(side+'ElbowBlend',(s*1.35,-.013,3.77),(.218,.22,.23),fur,bone=side+'LowerArm')
    uvball(side+'KneeBlend',(s*.47,-.02,1.73),(.24,.238,.25),fur,bone=side+'LowerLeg')
    uvball(side+'AnkleBlend',(s*.44,0,.61),(.247,.24,.23),fur,bone=side+'Foot')

body=fuse([o for o in collections['01 Body'].objects if o.type=='MESH' and o.data.materials[0]==fur],'Body_BlackFur',fur,'01 Body',None,voxel=.027,target=16000,smooth=5)
body['AttachTo']='Body - skin to rig when making morph'
bibparts=[o for o in collections['01 Body'].objects if o.type=='MESH' and o.data.materials[0]==white]
fuse(bibparts,'Body_WhiteBib',white,'01 Body',None,voxel=.013,target=4000,smooth=4)

faceparts=[o for o in collections['02 Face'].objects if o.name in ['Face_WhiteMask','LeftMuzzle','RightMuzzle','Nose_Bridge','Chin_White','LeftCheek_WhiteTufts','RightCheek_WhiteTufts']]
fuse(faceparts,'Face_WhiteFur',white,'02 Face','Head',voxel=.009,target=6500,smooth=8)
blackparts=[o for o in collections['02 Face'].objects if o.name in ['Head_BlackFur','LeftEar_Black','RightEar_Black','LeftCheek_BlackTufts','RightCheek_BlackTufts']]
fuse(blackparts,'Head_BlackFur',fur,'02 Face','Head',voxel=.016,target=5000,smooth=5)

for s,side in [(1,'Left'),(-1,'Right')]:
    parts=[o for o in collections['05 Gloves'].objects if o.name.startswith(side+'Glove') and (o.name.endswith('_White') or '_Knuckle_' in o.name)]
    fuse(parts,side+'Glove_White',glovewhite,'05 Gloves',side+'Hand',voxel=.01,target=2300,smooth=5)

# Soften the round staring eye shape into a more relaxed expression.
for o in collections['02 Face'].objects:
    if any(t in o.name for t in ['Eye_White','Eye_Iris','Eye_Pupil','Eye_Catchlight','Eye_Socket']):
        o.scale.z=.87

# Fine directional surface detail only affects normals, never base colour.
# These shader nodes remain editable in Blender; the exports remain tintable.
for m,strength,distance in [(fur,.38,.025),(white,.28,.018),(red,.14,.009),(hatwhite,.14,.009),(bowred,.12,.007)]:
    nt=m.node_tree;p=nt.nodes.get('Principled BSDF')
    tex=nt.nodes.new('ShaderNodeTexNoise');tex.name='Fine directional grain'
    tex.inputs['Scale'].default_value=58 if m in [fur,white] else 110
    tex.inputs['Detail'].default_value=2
    coord=nt.nodes.new('ShaderNodeTexCoord')
    mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY'
    mapping.inputs[1].default_value=(1.8,1.8,.18) if m in [fur,white] else (1,1,1)
    nt.links.new(coord.outputs['Object'],mapping.inputs[0]);nt.links.new(mapping.outputs[0],tex.inputs['Vector'])
    bump=nt.nodes.new('ShaderNodeBump');bump.name='Recolor-safe surface grain'
    bump.inputs['Strength'].default_value=strength;bump.inputs['Distance'].default_value=distance
    nt.links.new(tex.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],p.inputs['Normal'])

# Additional tapered fur ends on the edge of the bib.
items=[]
for s in [-1,1]:
    for j in range(14):
        z=2.78+j*.125
        if z<3.4:w=.40+.045*sin((z-2.8)*3)
        elif z<3.8:w=.435-(z-3.4)*.3
        else:w=.315-(z-3.8)*.19
        x=s*w
        y=body_front(z,x)-.012
        items.append(tube('Bib fur tip',[(x-s*.026,y-.008,z),(x+s*.018,y+.001,z-.055),(x+s*.007,y+.027,z-.14)],[.043,.034,.002],white,'01 Body',None,n=8,steps=2,aspect=.55))
join_group(items,'Bib_WhiteFurEdge')

# Frame the whole hat and feet with space in the viewport.
for area_ in bpy.context.screen.areas:
    if area_.type=='VIEW_3D':
        v=area_.spaces.active
        v.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        v.region_3d.view_distance=15.0
        v.region_3d.view_location=(0,0,4.0)
        v.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1080;scene.render.resolution_y=1200
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'CatInTheHat_Base.blend'))
print('Refinement complete. Triangles:',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in root.all_objects if o.type=='MESH'))
