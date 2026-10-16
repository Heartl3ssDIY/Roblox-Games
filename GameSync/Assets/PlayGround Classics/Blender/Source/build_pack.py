import bpy, bmesh, math, sys, json, struct, zlib, shutil, traceback
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT.parent/'PlaygroundClassics-ItemPetReferences-20261004'/'PlaygroundClassics-ItemPetReferences-20261004'
sys.path.insert(0,str(ROOT/'Source'))
from assetlib import *

def png_palette(path, colors):
    side=512; cols=8; cell=64
    pixels=[]
    for y in range(side):
        row=bytearray([0])
        for x in range(side):
            i=(7-y//cell)*cols+x//cell
            c=colors[min(i,len(colors)-1)]
            row.extend(round(max(0,min(1,v))*255) for v in c[:3])
            row.append(255)
        pixels.append(bytes(row))
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',side,side,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(pixels),9))+chunk(b'IEND',b''))

def bounds(objects):
    points=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))

def export_meshes(a, texture_path):
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    colors=[]; index={}; pieces=[]
    for obj in a.objects:
        ev=obj.evaluated_get(dg); mesh=ev.to_mesh()
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh);bm.free();mesh.calc_loop_triangles()
        vertices=[tuple(obj.matrix_world@v.co) for v in mesh.vertices]
        faces=[]; face_colors=[]; smooth=[]
        for tri in mesh.loop_triangles:
            if tri.area<1e-14: continue
            polygon=mesh.polygons[tri.polygon_index]
            mat=obj.data.materials[min(polygon.material_index,len(obj.data.materials)-1)]
            c=tuple(mat.get('palette_srgb',(1,1,1,1)))
            key=tuple(round(v,5) for v in c)
            if key not in index:index[key]=len(colors);colors.append(c)
            faces.append(tuple(tri.vertices));face_colors.append(index[key]);smooth.append(polygon.use_smooth)
        pieces.append((obj.name,vertices,faces,face_colors,smooth))
        ev.to_mesh_clear()
    assert len(colors)<=64, f'{a.spec["id"]} too many palette colors'
    png_palette(texture_path,colors)
    image=bpy.data.images.load(str(texture_path),check_existing=True)
    image.pack()
    mat=bpy.data.materials.new(a.spec['id']+'_RobloxPalette')
    mat.use_nodes=True
    shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    shader.inputs['Roughness'].default_value=.56 if a.spec['id']=='C01'else .38
    if 'Metallic' in shader.inputs:shader.inputs['Metallic'].default_value=.03 if a.spec['id']=='C01'else .0
    if 'Coat Weight' in shader.inputs:shader.inputs['Coat Weight'].default_value=0 if a.spec['id']=='C01'else .1
    exports=bpy.data.collections.new(a.spec['id']+'_RobloxExport')
    bpy.context.scene.collection.children.link(exports)
    groups=[];group=[];count=0
    for piece in pieces:
        if count+len(piece[2])>19000 and group:groups.append(group);group=[];count=0
        group.append(piece);count+=len(piece[2])
    if group:groups.append(group)
    out=[]
    for gi,group in enumerate(groups):
        vs=[];fs=[];cs=[];ss=[]
        for name,v,f,c,s in group:
            offset=len(vs);vs.extend(v);fs.extend(tuple(i+offset for i in face) for face in f);cs.extend(c);ss.extend(s)
        mesh=bpy.data.meshes.new(a.spec['slug']+'_export_mesh');mesh.from_pydata(vs,[],fs);mesh.update()
        obj=bpy.data.objects.new(a.spec['slug']+(''if len(groups)==1 else f'_Part{gi+1}'),mesh);exports.objects.link(obj)
        mesh.materials.append(mat)
        uv=mesh.uv_layers.new(name='PaletteUV')
        for p,ci,smooth in zip(mesh.polygons,cs,ss):
            p.use_smooth=smooth
            cx=ci%8;cy=ci//8
            pts=[(.32,.32),(.68,.32),(.5,.68)]
            for k,li in enumerate(p.loop_indices):uv.data[li].uv=((cx+pts[k%3][0])/8,(cy+pts[k%3][1])/8)
        obj['AssetId']=a.spec['id'];obj['IsRobloxExport']=True
        out.append(obj)
    return out,exports,len(colors)

def studio(scene, objects, bat=False):
    lo,hi=bounds(objects);center=(lo+hi)/2
    camdata=bpy.data.cameras.new('PreviewCamera');camdata.type=checked_enum(camdata,'type','ORTHO')
    cam=bpy.data.objects.new('PreviewCamera',camdata);scene.collection.objects.link(cam)
    direction=Vector((-4.5,-8,3.3)).normalized()
    rotation=direction.to_track_quat('Z','Y')
    if bat:rotation=rotation@Quaternion((0,0,1),.5)
    cam.rotation_euler=rotation.to_euler();cam.location=center+direction*15
    corners=[Vector((x,y,z)) for x in(lo.x,hi.x)for y in(lo.y,hi.y)for z in(lo.z,hi.z)]
    projected=[rotation.inverted()@(v-center) for v in corners]
    extent=max(max(v.x for v in projected)-min(v.x for v in projected),max(v.y for v in projected)-min(v.y for v in projected))
    camdata.ortho_scale=extent*1.22
    scene.camera=cam
    for name,pos,energy,size in [('Key',(-3,-5,7),500,5),('Fill',(5,-2,3),280,4),('Rim',(1,4,6),450,4)]:
        ld=bpy.data.lights.new(name,checked_enum(bpy.types.Light,'type','AREA'));ld.energy=energy;ld.shape=checked_enum(ld,'shape','DISK');ld.size=size
        ob=bpy.data.objects.new(name,ld);scene.collection.objects.link(ob);ob.location=center+Vector(pos);ob.rotation_euler=(center-ob.location).to_track_quat('-Z','Y').to_euler()
    if not scene.world:scene.world=bpy.data.worlds.new('SoftStudio')
    scene.world.use_nodes=True
    bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.36,.39,.45,1);bg.inputs['Strength'].default_value=.4
    try:scene.render.engine='BLENDER_EEVEE'
    except TypeError:pass
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.view_settings.view_transform='Standard'
    scene.view_settings.exposure=-.2
    scene.render.image_settings.file_format=checked_enum(scene.render.image_settings,'file_format','PNG')
    scene.render.image_settings.color_mode=checked_enum(scene.render.image_settings,'color_mode','RGBA')
    scene.render.image_settings.color_depth=checked_enum(scene.render.image_settings,'color_depth','8')
    if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=32
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_rotation=rotation
                area.spaces.active.region_3d.view_location=center
                area.spaces.active.region_3d.view_distance=camdata.ortho_scale*1.6
                area.spaces.active.shading.type=checked_enum(area.spaces.active.shading,'type','MATERIAL')
    return lo,hi

def reset_scene():
    for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
    for col in list(bpy.data.collections):bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        if mesh.users==0:bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        if mat.users==0:bpy.data.materials.remove(mat)

def build_one(spec,render=True):
    reset_scene()
    if spec['category'] in ('Bats','Event-Bats'):import build_bats as module
    elif spec['category']=='Pets':import build_pets as module
    elif spec['category']=='Miscellaneous':import build_misc as module
    else:import build_decorations as module
    a=module.build(spec)
    if spec['category']=='Pets':
        from refine_pets import build_overrides
        build_overrides(a,spec['id'])
    scene=bpy.context.scene;scene.name=spec['id']+' '+spec['name']
    base=ROOT/spec['category']
    for folder in ['Blend','FBX','Textures','Previews','Metadata']:(base/folder).mkdir(parents=True,exist_ok=True)
    for obj in a.objects:
        if obj.data.validate(verbose=False):obj['ValidatedGeometry']=True
    bpy.context.view_layer.update()
    if spec['id']in('M03','M14'):
        grip=next((o for o in a.anchors if o.name.startswith('GripAttachment')),None)
        if grip:
            offset=grip.location.copy()
            for obj in a.objects+a.anchors:obj.location-=offset
    texture=base/'Textures'/(spec['slug']+'-palette.png')
    exports,export_collection,color_count=export_meshes(a,texture)
    bpy.ops.object.select_all(action=checked_enum(bpy.ops.object.select_all.get_rna_type(),'action','DESELECT'))
    for obj in exports+a.anchors:obj.select_set(True)
    bpy.context.view_layer.objects.active=exports[0]
    fbx=base/'FBX'/(spec['slug']+'.fbx')
    bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH','EMPTY'},use_mesh_modifiers=True,bake_anim=False,add_leaf_bones=False,axis_forward='-Z',axis_up='Y',apply_unit_scale=False,global_scale=1.0,mesh_smooth_type='FACE',use_triangles=True,path_mode='COPY',embed_textures=True,use_custom_props=True)
    export_collection.hide_render=True
    export_collection.hide_viewport=True
    refs=bpy.data.collections.new('Reference (toggle to compare)');scene.collection.children.link(refs)
    refimage=bpy.data.images.load(str(REF/spec['reference']),check_existing=True);refimage.pack()
    refobj=bpy.data.objects.new('Original - '+spec['name'],None);refs.objects.link(refobj)
    refobj.empty_display_type=checked_enum(refobj,'empty_display_type','IMAGE');refobj.data=refimage;refobj.empty_display_size=3.5;refobj.location=(3,0,1.7);refobj.rotation_euler=(math.pi/2,0,0)
    refs.hide_render=True;refs.hide_viewport=True
    lo,hi=studio(scene,a.objects,spec['category']in('Bats','Event-Bats'))
    for ob in bpy.context.selected_objects:ob.select_set(False)
    a.root.select_set(True);bpy.context.view_layer.objects.active=a.root
    scene.render.filepath=str(base/'Previews'/(spec['slug']+'.png'))
    blend=base/'Blend'/(spec['slug']+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True,check_existing=False)
    metadata={'id':spec['id'],'name':spec['name'],'category':spec['category'],'reference':str(REF/spec['reference']),'brief':spec['brief'],'blend':str(blend),'fbx':str(fbx),'texture':str(texture),'preview':scene.render.filepath,'parts':len(a.objects),'triangles':sum(len(o.data.polygons)for o in exports),'meshes':len(exports),'maxMeshTriangles':max(len(o.data.polygons)for o in exports),'dimensions':list(hi-lo),'boundsMin':list(lo),'boundsMax':list(hi),'paletteColors':color_count,'anchors':{o.name:list(o.location)for o in a.anchors},'editable':True,'rigged':False,'gameplayImplemented':False}
    export_lo,export_hi=bounds(exports)
    metadata['exportDimensions']=list(export_hi-export_lo)
    (base/'Metadata'/(spec['slug']+'.json')).write_text(json.dumps(metadata,indent=2),encoding='utf-8')
    if render:bpy.ops.render.render(write_still=True)
    print('ASSET_COMPLETE '+json.dumps(metadata),flush=True)
    return metadata

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]if'--'in sys.argv else[]
    catalog=json.loads((REF/'Source'/'Catalog.json').read_text(encoding='utf-8-sig'))
    catalog.append({'id':'C01','name':'Collectible Coin','slug':'c01-collectible-coin','category':'Miscellaneous','tier':'Collectible','reference':'C:/Users/sandt/Downloads/ChatGPT Image 4 Oct 2026, 10_00_54.png','brief':'Remodel the gold dollar coin currently used in Studio as a detailed, chunky cartoon 3D pickup. Rounded rim, inset gold faces, raised dollar relief on both faces, warm orange edge, navy outline accents, and centered spin pivot. Preserve editable separate parts.'})
    targets=[s for s in catalog if not args or s['id']in args or s['category']in args or'ALL'in args]
    reports=[]
    for spec in targets:
        try:reports.append(build_one(spec,'--no-render'not in args))
        except Exception:
            print('ASSET_FAILED '+spec['id']+'\n'+traceback.format_exc(),flush=True)
            raise
    print('PACK_COMPLETE '+json.dumps({'count':len(reports),'ids':[s['id']for s in reports]}),flush=True)
