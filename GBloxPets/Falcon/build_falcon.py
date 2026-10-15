"""Staged Blender MCP build. No generation services; original scene preserved."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector

OUT = Path(__file__).resolve().parent

def setup():
    global scene, model, fx, stage
    scene = bpy.data.scenes.new('GBlox_Falcon_Reference')
    bpy.context.window.scene = scene
    scene.unit_settings.system = 'METRIC'
    model = bpy.data.collections.new('FALCON | Recolourable meshes')
    fx = bpy.data.collections.new('FALCON | Optional VFX meshes')
    stage = bpy.data.collections.new('STUDIO | Not exported')
    for c in (model,fx,stage): scene.collection.children.link(c)
    # Reuse only our local primitive-building helpers, never the Eagle build.
    source = (OUT.parent/'Eagle'/'build_eagle.py').read_text(encoding='utf-8')
    helpers = source[source.index('def linear('):source.index('# Single head volume:')]
    helpers = helpers.replace("obj['Pet'] = 'Eagle'", "obj['Pet'] = 'Falcon'")
    helpers = helpers.replace('Eagle gold','Falcon yellow')
    exec(helpers,globals())
    print('Falcon scene created; pre-existing scene untouched.')

def ring(name, outer, inner, y, thickness, mat):
    n=len(outer)
    verts=[]
    for depth in (y-thickness/2,y+thickness/2):
        verts += [(x,depth,z) for x,z in outer]+[(x,depth,z) for x,z in inner]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),
                  (2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    model.objects.link(obj)
    put(obj,name,mat)
    return finish(obj,.035,True)

def head():
    box('Head_Pearl_MainCube',(0,0,0),(3.05,2.65,2.76),'Pearl',.23)
    # Close-fit helmet cap; no separate neck, torso or legs.
    box('Helmet_Pearl_Cap',(0,0,1.025),(3.09,2.69,.80),'Pearl',.17)
    box('Face_Cyan_Panel',(0,-1.36,-.035),(2.65,.16,1.62),'Cyan',.20)
    box('Helmet_Cyan_Forehead',(0,-1.37,1.03),(.72,.085,.72),'Cyan',.055)
    box('Helmet_Cyan_TopStripe',(0,0,1.43),(.70,2.36,.055),'Cyan',.022)
    # Small separate metallic seams suggest segmented sci-fi panels.
    for side in (-1,1):
        s='L' if side<0 else 'R'
        box(f'Helmet_{s}_Silver_TopSeam',(side*.91,0,1.43),(.018,2.20,.025),'Silver',.008)
        box(f'Helmet_{s}_Cyan_Band',(side*1.535,.05,.17),(.06,2.35,.32),'Cyan',.025)
        box(f'Goggles_{s}_Violet_Temple',(side*1.425,-1.04,-.02),(.19,.75,.50),'Purple',.065)
        ellipsoid(f'Eye_{s}_White_Surround',(side*.67,-1.457,-.055),(.46,.078,.58),'White')
        ellipsoid(f'Eye_{s}_Ink_Pupil',(side*.67,-1.535,-.055),(.325,.115,.455),'Ink')
        ellipsoid(f'Eye_{s}_White_Glint',(side*.67-.085,-1.647,.13),(.103,.019,.137),'White')
    outer=[(-1.39,.58),(-1.12,.64),(-.49,.51),(-.25,.38),(.25,.38),(.49,.51),(1.12,.64),(1.39,.58),
           (1.43,-.40),(1.24,-.66),(.69,-.77),(.29,-.59),(0,-.39),(-.29,-.59),(-.69,-.77),(-1.24,-.66),(-1.43,-.40)]
    inner=[(x*.916,z*.78-.006) for x,z in outer]
    ring('Goggles_Silver_ContinuousFrame',outer,inner,-1.568,.135,'Silver')
    # Purple perimeter is a second thin part behind the silver rim.
    ring('Goggles_Violet_OuterTrim',[(x*1.03,z*1.04) for x,z in outer],outer,-1.50,.075,'Purple')
    prism_xz('Helmet_Yellow_Lightning',[(.075,1.31),(-.19,.99),(-.03,.99),(-.09,.77),(.21,1.11),(.04,1.11)],-1.429,.045,'Gold',.008)
    # Compact falcon beak with friendly rounded planes, unlike Eagle hook.
    verts=[(-.235,-1.49,-.41),(.235,-1.49,-.41),(-.235,-1.51,-.68),(.235,-1.51,-.68),
           (-.105,-1.92,-.60),(.105,-1.92,-.60),(0,-1.84,-.96)]
    faces=[(0,1,5,4),(0,4,6,2),(1,3,6,5),(2,6,3),(4,5,6),(0,2,3,1)]
    mesh=bpy.data.meshes.new('Falcon beak topology')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('Beak_Yellow',mesh)
    model.objects.link(obj)
    put(obj,obj.name,'Gold')
    finish(obj,.065,True)
    print('Falcon head, eyes, helmet, beak and goggles built as separate parts.')

def appendages():
    for side in (-1,1):
        s='L' if side<0 else 'R'
        # Each wing joins directly to the cube head at the side band.
        ellipsoid(f'Wing_{s}_Silver_Joint',(side*1.51,.07,-.17),(.27,.37,.38),'Silver')
        # Chunky scalloped feathers fan out and down, swept slightly backward.
        for i in range(3):
            x=1.58+i*.16
            z=.04-i*.13
            shape=[(x,z+.20),(x+.36,z+.12),(x+.93,z-.46),(x+.93,z-.63),
                   (x+.77,z-.72),(x+.53,z-.59),(x+.03,z-.12)]
            feather=prism_xz(f'Wing_{s}_Violet_Feather_{i+1}',[(side*a,b) for a,b in shape],.01+i*.30,.19,'Purple',.08)
            # Small metallic cover overlaps only the root half of each feather.
            cap=[(x-.04,z+.25),(x+.26,z+.20),(x+.57,z-.10),(x+.55,z-.30),
                 (x+.38,z-.35),(x+.08,z-.16),(x-.05,z+.01)]
            prism_xz(f'Wing_{s}_Silver_Covert_{i+1}',[(side*a,b) for a,b in cap],-.115+i*.30,.16,'Silver',.065)
        # The compact thrusters point down/back, as on the supplied reference.
        a=Vector((side*2.10,.26,-.63))
        direction=Vector((side*.14,.42,-.76)).normalized()
        b=a+direction*.38
        rod(f'Thruster_{s}_Silver_Housing',a,b,.195,'Silver')
        rod(f'Thruster_{s}_Ink_Nozzle',b,b+direction*.055,.158,'Ink')
        rod(f'VFX_{s}_Cyan_Jet',b+direction*.06,b+direction*.68,.133,'Glow',fx,.007)
        rod(f'VFX_{s}_White_Core',b+direction*.07,b+direction*.47,.067,'GlowInner',fx,.003)
        for i in range(3):
            box(f'Thruster_{s}_Silver_Rib_{i+1}',(side*(2.1+.105),.24+i*.075,-.69-i*.08),(.055,.04,.115),'Silver',.012)
    for i in (-1,0,1):
        x=i*.35
        pts=[(x-.15,1.12),(x+.15,1.12),(x+i*.11+.19,1.96),(x+i*.11,2.22),(x+i*.11-.19,1.96)]
        prism_xy(f'Tail_{i+2}_Pearl_Feather',pts,-.62,.16,'Pearl',.075)
        pts=[(x-.065,1.27),(x+.065,1.27),(x+i*.11+.065,1.98),(x+i*.11,2.11),(x+i*.11-.065,1.98)]
        prism_xy(f'Tail_{i+2}_Cyan_Stripe',pts,-.525,.035,'Cyan',.018)
    box('VFX_Cyan_Underlight',(0,.0,-1.371),(2.27,1.97,.045),'Glow',.018,fx)
    print('Head-mounted feather wings, tail and optional thrusters complete.')

def studio():
    global root, camera
    all_meshes=list(model.objects)+list(fx.objects)
    for obj in all_meshes:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
    root=bpy.data.objects.new('Falcon_ROOT',None)
    model.objects.link(root)
    root['FrontAxis']='-Y'
    root['Notes']='Static pet. Separate one-material meshes. Wing joints can be animated after import.'
    for obj in all_meshes: obj.parent=root
    # Optional jet locator empties, children of the actual nozzle parts.
    for side in ('L','R'):
        nozzle=bpy.data.objects[f'Thruster_{side}_Ink_Nozzle']
        anchor=bpy.data.objects.new(f'VFX_{side}_EmitterGuide',None)
        fx.objects.link(anchor)
        anchor.empty_display_size=.12
        anchor.parent=nozzle
        anchor.location=(0,0,.028)
    floor_mat=material('STUDIO | Navy','10213A',.12,.42)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-2.02))
    floor=bpy.context.object
    for c in list(floor.users_collection): c.objects.unlink(floor)
    stage.objects.link(floor)
    floor.name='STUDIO_Floor'
    floor.data.materials.append(floor_mat)
    def aim(obj,position): obj.rotation_euler=(Vector(position)-obj.location).to_track_quat('-Z','Y').to_euler()
    for name,loc,col,power,size in [
        ('Key',(0,-5,7),(1,.93,.85),1150,5),
        ('Fill',(-5,-2,3),(.35,.80,1),750,4),
        ('Rim',(4,4,5),(.65,.40,1),1350,3),
        ('Front',(1,-6,0),(1,1,1),180,3)]:
        data=bpy.data.lights.new('STUDIO_'+name,'AREA')
        data.energy=power
        data.shape='DISK'
        data.size=size
        data.color=col
        obj=bpy.data.objects.new(data.name,data)
        stage.objects.link(obj)
        obj.location=loc
        aim(obj,(0,0,0))
    data=bpy.data.cameras.new('Falcon preview')
    camera=bpy.data.objects.new('STUDIO_Camera',data)
    stage.objects.link(camera)
    camera.location=(5.7,-10.5,4.6)
    aim(camera,(0,.05,-.03))
    data.type='ORTHO'
    data.ortho_scale=7.15
    scene.camera=camera
    scene.render.engine='CYCLES'
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1100
    scene.render.resolution_y=1100
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Falcon studio world')
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.17,.28,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.file_format='PNG'
    # Embed the approved reference as an image datablock, not exported geometry.
    ref=Path('C:/Users/sandt/.codex/generated_images/01a0679e-4be5-74a0-9a3d-de8a52fa2e46/exec-9fe0ab47-a9f9-49e3-95a0-43129034480d.png')
    if ref.exists():
        image=bpy.data.images.load(str(ref),check_existing=True)
        image.name='REFERENCE | Approved floating falcon'
        image.pack()
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.color_type='MATERIAL'
    print('Studio and embedded reference ready; other scene preserved.')

def export():
    meshes=[o for o in list(model.objects)+list(fx.objects) if o.type=='MESH']
    report={'mesh_count':len(meshes),'triangles':0,'parts':[],'single_material_per_mesh':True}
    import bmesh
    for obj in meshes:
        obj.data.calc_loop_triangles()
        tris=len(obj.data.loop_triangles)
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bad=sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        report['triangles']+=tris
        report['single_material_per_mesh'] &= len(obj.data.materials)==1
        report['parts'].append({'name':obj.name,'material':obj.data.materials[0].name,'triangles':tris,'non_manifold_edges':bad})
    for filename,objects in [('GBlox_Falcon_Parts.fbx',list(model.objects)),('GBlox_Falcon_WithGlow.fbx',list(model.objects)+list(fx.objects))]:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.fbx(filepath=str(OUT/filename),use_selection=True,
            object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_unit_scale=True,
            use_mesh_modifiers=True,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,
            use_custom_props=True)
    (OUT/'parts_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    scene.render.filepath=str(OUT/'GBlox_Falcon_Preview.png')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active=bpy.data.objects['Head_Pearl_MainCube']
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'GBlox_Falcon.blend'))
    print(json.dumps({'meshes':len(meshes),'triangles':report['triangles'],'one_material_each':report['single_material_per_mesh'],
        'non_manifold_edges':sum(p['non_manifold_edges'] for p in report['parts'])}))

def render():
    bpy.ops.render.render(write_still=True)
    print(str(OUT/'GBlox_Falcon_Preview.png'))
