import numpy as np
EXPORT=os.path.join(BASE,'RobloxImport');os.makedirs(EXPORT,exist_ok=True)
TEX=os.path.join(EXPORT,'textures');os.makedirs(TEX,exist_ok=True)
BAKE=bpy.data.scenes.new('Material texture baking')
bpy.context.window.scene=BAKE
try:BAKE.render.engine='CYCLES'
except TypeError as e:raise RuntimeError(str(e))
BAKE.cycles.samples=1
BAKE.render.bake.margin=8;BAKE.render.bake.use_clear=True
me=bpy.data.meshes.new('Bake plane');me.from_pydata([(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[],[(0,1,2,3)])
uv=me.uv_layers.new(name='UVMap')
for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
PLANE=bpy.data.objects.new('Material sample',me);BAKE.collection.objects.link(PLANE)
PLANE.select_set(True);BAKE.view_layers[0].objects.active=PLANE
PMAT={};BAKED={}

def bake_material(key):
    src=MAT[key];m=src.copy();m.name='Baking '+key
    me.materials.clear();me.materials.append(m)
    n=m.node_tree.nodes;L=m.node_tree.links
    p=next(x for x in n if x.type=='BSDF_PRINCIPLED');out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    uvnode=n.new('ShaderNodeTexCoord')
    for link in list(L):
        if link.from_node.type=='TEX_COORD' and link.from_socket.name=='Generated':L.new(uvnode.outputs['UV'],link.to_socket)
    metal=p.inputs['Metallic'].default_value
    ims={}
    for channel,socket in [('Color','Base Color'),('Roughness','Roughness'),('Normal',None)]:
        im=bpy.data.images.new(key+'_'+channel,width=1024,height=1024,alpha=False)
        # Color-space identifiers are dynamic; use names advertised by the data block.
        if channel!='Color':im.colorspace_settings.name='Non-Color'
        im.filepath_raw=os.path.join(TEX,key+'_'+channel+'.png');im.file_format='PNG'
        target=n.new('ShaderNodeTexImage');target.image=im
        for x in n:x.select=False
        target.select=True;n.active=target
        if socket:
            em=n.new('ShaderNodeEmission')
            s=p.inputs[socket]
            if s.is_linked:L.new(s.links[0].from_socket,em.inputs['Color'])
            else:
                v=s.default_value;em.inputs['Color'].default_value=tuple(v) if hasattr(v,'__len__') else (v,v,v,1)
            L.new(em.outputs[0],out.inputs['Surface']);bpy.ops.object.bake(type='EMIT')
            n.remove(em)
        else:
            L.new(p.outputs['BSDF'],out.inputs['Surface']);bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT')
        im.save();ims[channel]=im
    # glTF metallic-roughness convention: roughness G, metallic B.
    arr=np.empty(1024*1024*4,dtype=np.float32);ims['Roughness'].pixels.foreach_get(arr);arr=arr.reshape((-1,4))
    arr[:,0]=1;arr[:,2]=metal;arr[:,3]=1
    orm=bpy.data.images.new(key+'_MetalRough',width=1024,height=1024,alpha=False)
    orm.colorspace_settings.name='Non-Color';orm.pixels.foreach_set(arr.ravel());orm.filepath_raw=os.path.join(TEX,key+'_MetalRough.png');orm.file_format='PNG';orm.save()
    pm=bpy.data.materials.new('Portable | '+key);pm.use_nodes=True;pm.diffuse_color=src.diffuse_color
    pn=pm.node_tree.nodes;pl=pm.node_tree.links;q=next(x for x in pn if x.type=='BSDF_PRINCIPLED')
    tex=pn.new('ShaderNodeTexImage');tex.image=ims['Color'];pl.new(tex.outputs['Color'],q.inputs['Base Color'])
    tex=pn.new('ShaderNodeTexImage');tex.image=orm
    sep=pn.new('ShaderNodeSeparateColor');sep.mode='RGB';pl.new(tex.outputs['Color'],sep.inputs[0]);pl.new(sep.outputs['Green'],q.inputs['Roughness']);pl.new(sep.outputs['Blue'],q.inputs['Metallic'])
    tex=pn.new('ShaderNodeTexImage');tex.image=ims['Normal'];norm=pn.new('ShaderNodeNormalMap');pl.new(tex.outputs['Color'],norm.inputs['Color']);pl.new(norm.outputs['Normal'],q.inputs['Normal'])
    PMAT[src.name]=pm;BAKED[key]=ims
    bpy.data.materials.remove(m)
    print('Baked',key)

KEYS=[k for k in MAT if k not in ['floor','plinth']]
print('Ready to bake',len(KEYS),'shared PBR materials')
