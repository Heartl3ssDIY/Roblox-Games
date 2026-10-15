from common import *
# Real image materials with portable UVs and PBR maps.
SPECS={
'stone':('stone_floor',10.0),'stoneDark':('slate_floor',10.0),'stoneLight':('stone_floor',8.0),
'wood':('wood_planks',6.0),'roof':('grey_roof_01',14.0),
'moss':('aerial_grass_rock',18.0),'rock':('rock_face_03',22.0),'bark':('bark_brown_01',4.0)}
def apply():
    directory=os.path.join(ROOT,'textures','PBR')
    bark=bpy.data.materials.get('ACU_bark')
    if bark is None:
        bark=MATS['wood'].copy();bark.name='ACU_bark'
    MATS['bark']=bark
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH' and any(s in ob.name.lower() for s in ('trunk','bough','branch','root')):
            for i,mat in enumerate(ob.data.materials):
                if mat and mat.name=='ACU_wood':ob.data.materials[i]=bark
    for key,(asset,tile) in SPECS.items():
        mat=MATS[key];nodes=mat.node_tree.nodes;links=mat.node_tree.links
        bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
        # Clear the earlier procedural bump so actual scanned maps drive the surfaces.
        for n in list(nodes):
            if n.type not in ('BSDF_PRINCIPLED','OUTPUT_MATERIAL'):nodes.remove(n)
        uv=nodes.new('ShaderNodeUVMap');uv.uv_map='DetailUV'
        maps={}
        for label in ('Color','Normal','Roughness'):
            path=os.path.join(directory,asset+'_'+label+'.jpg')
            img=bpy.data.images.load(path,check_existing=True)
            if label!='Color':img.colorspace_settings.name='Non-Color'
            tex=nodes.new('ShaderNodeTexImage');tex.image=img;tex.label=label+' | '+asset
            links.new(uv.outputs['UV'],tex.inputs['Vector']);maps[label]=tex
        links.new(maps['Color'].outputs['Color'],bs.inputs['Base Color'])
        links.new(maps['Roughness'].outputs['Color'],bs.inputs['Roughness'])
        normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.6 if key!='rock' else .85
        links.new(maps['Normal'].outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
        bs.inputs['Metallic'].default_value=0
        mat['ACU_TextureSource']='https://polyhaven.com/a/'+asset
        mat['ACU_TextureLicense']='CC0'
        mat['ACU_TileSize']=tile
    changed=0
    for ob in bpy.context.scene.objects:
        if ob.type!='MESH':continue
        indices={}
        for i,mat in enumerate(ob.data.materials):
            key=mat.name.replace('ACU_','') if mat else ''
            if key in SPECS:indices[i]=SPECS[key][1]
        if not indices:continue
        me=ob.data
        uv=me.uv_layers.get('DetailUV') or me.uv_layers.new(name='DetailUV')
        me.uv_layers.active=uv;uv.active_render=True
        verts=[ob.matrix_world @ v.co for v in me.vertices]
        normalmat=ob.matrix_world.to_3x3().inverted_safe().transposed()
        for face in me.polygons:
            tile=indices.get(face.material_index)
            if tile is None:continue
            n=normalmat @ face.normal;axis=max(range(3),key=lambda k:abs(n[k]))
            # Dominant-axis box UVs give consistent world scale across every district.
            for li in face.loop_indices:
                v=verts[me.loops[li].vertex_index]
                if axis==2:coord=(v.x/tile,v.y/tile)
                elif axis==1:coord=(v.x/tile,v.z/tile)
                else:coord=(v.y/tile,v.z/tile)
                uv.data[li].uv=coord
        ob['ACU_HasDetailUV']=True;changed+=1
    # Animated-looking ripples are retained as an editable Blender material.
    water=MATS['water'];nodes=water.node_tree.nodes;links=water.node_tree.links
    bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Metallic'].default_value=.12;bs.inputs['Roughness'].default_value=.19;bs.inputs['IOR'].default_value=1.333
    for n in list(nodes):
        if n.type not in ('BSDF_PRINCIPLED','OUTPUT_MATERIAL'):nodes.remove(n)
    coord=nodes.new('ShaderNodeTexCoord')
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=8;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.65
    links.new(coord.outputs['Object'],noise.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.35;bump.inputs['Distance'].default_value=.15
    links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    scene=bpy.context.scene
    sky=next((n for n in scene.world.node_tree.nodes if n.type=='TEX_SKY'),None)
    if sky:sky.sun_elevation=.65
    bg=next((n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND'),None)
    if bg:bg.inputs['Strength'].default_value=.18
    for ob in scene.objects:
        if ob.type=='LIGHT' and ob.data.type=='SUN':
            ob.data.energy=3.0;ob.data.color=(1.0,.94,.85)
    bpy.context.view_layer.update()
    print('PBR_TEXTURES_APPLIED',changed,'meshes, 7 image texture families / 8 materials',flush=True)



