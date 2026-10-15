import bpy,os,json
from mathutils import Vector
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ParcelModels\Textures'
os.makedirs(OUT,exist_ok=True)
scene=bpy.data.scenes['To be rich - Parcels'];bpy.context.window.scene=scene
models=bpy.app.driver_namespace['parcel_models']
mats={}
for model in models:
    for ob in model['objects']:
        if ob.get('ParcelPart') not in ('Body','TopFlaps'):continue
        material=ob.active_material;mats[material.name]=material
        mesh=ob.data;uv=mesh.uv_layers.new(name='CardboardUV') if not mesh.uv_layers else mesh.uv_layers.active
        lo=Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
        hi=Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
        for poly in mesh.polygons:
            axis=max(range(3),key=lambda i:abs(poly.normal[i]));other=[i for i in range(3) if i!=axis]
            for li in poly.loop_indices:
                p=mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv=tuple((p[i]-lo[i])/max(.0001,hi[i]-lo[i]) for i in other)
        ob['TextureFile']=material.name+'.png'
for material in mats.values():
    nt=material.node_tree;n=nt.nodes;l=nt.links
    bsdf=next(x for x in n if x.type=='BSDF_PRINCIPLED')
    base=tuple(bsdf.inputs['Base Color'].default_value)
    uv=n.new('ShaderNodeTexCoord')
    grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=165;grain.inputs['Detail'].default_value=2;grain.inputs['Roughness'].default_value=.72
    l.new(uv.outputs['UV'],grain.inputs['Vector'])
    broad=n.new('ShaderNodeTexNoise');broad.inputs['Scale'].default_value=6;broad.inputs['Detail'].default_value=3
    l.new(uv.outputs['UV'],broad.inputs['Vector'])
    mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(5,70,1);l.new(uv.outputs['UV'],mapping.inputs[0])
    fibres=n.new('ShaderNodeTexNoise');fibres.inputs['Scale'].default_value=8;fibres.inputs['Detail'].default_value=2;l.new(mapping.outputs[0],fibres.inputs['Vector'])
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[0].default_value=.23;l.new(grain.outputs['Fac'],mix.inputs[1]);l.new(broad.outputs['Fac'],mix.inputs[2])
    mix2=n.new('ShaderNodeMixRGB');mix2.blend_type='MIX';mix2.inputs[0].default_value=.24;l.new(mix.outputs[0],mix2.inputs[1]);l.new(fibres.outputs['Fac'],mix2.inputs[2])
    ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=tuple(v*.58 for v in base[:3])+(1,)
    ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=tuple(min(1,v*1.30) for v in base[:3])+(1,)
    l.new(mix2.outputs[0],ramp.inputs[0]);l.new(ramp.outputs[0],bsdf.inputs['Base Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.006
    l.new(mix2.outputs[0],bump.inputs['Height']);l.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    material['BakeRamp']=ramp.name;material['BakeBump']=bump.name

temp=bpy.data.collections.new('CardboardBakeTemporary');scene.collection.children.link(temp)
me=bpy.data.meshes.new('CardboardBakePlane');me.from_pydata([(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[],[(0,1,2,3)])
uv=me.uv_layers.new(name='UVMap')
for i,p in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=p
plane=bpy.data.objects.new('CardboardBakePlane',me);temp.objects.link(plane)
plane.location=(0,0,-5)
bpy.app.driver_namespace['cardboard_bake']={'materials':list(mats.values()),'plane':plane,'collection':temp,'out':OUT}
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=4
scene.cycles.samples=1
print(json.dumps({'materials':[m.name for m in mats.values()],'resolution':1024}))
