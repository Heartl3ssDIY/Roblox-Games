"""Procedural G-Blox pet collection builder, intended to run inside Blender MCP."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector

ROOT = Path('C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/GBloxPets')
original_scene = bpy.context.window.scene
PALETTE = {
    'Pearl': ('EAF2FF', .18, .28), 'Cyan': ('14CADA', .25, .25),
    'Purple': ('8455E8', .25, .26), 'Silver': ('9BABBF', .75, .23),
    'Yellow': ('FFD33D', .25, .25), 'Ink': ('071628', .10, .18),
    'White': ('FFFFFF', 0, .18), 'Glow': ('18F1FF', .05, .18),
}

def lin(c): return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4

def mat(name, spec):
    hx,metal,rough=spec
    rgb=tuple(lin(int(hx[i:i+2],16)/255) for i in (0,2,4))
    m=bpy.data.materials.new('RECOLOUR | '+name)
    m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if name=='Glow':
        p.inputs['Emission Color'].default_value=(*rgb,1); p.inputs['Emission Strength'].default_value=4
    return m

def reset(species):
    global scene, geo, vfx, studio, mats, root
    scene=bpy.data.scenes.new('GBlox_'+species)
    bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    geo=bpy.data.collections.new(species.upper()+' | Recolourable parts')
    vfx=bpy.data.collections.new(species.upper()+' | Optional VFX')
    studio=bpy.data.collections.new('STUDIO | Do not export')
    for c in (geo,vfx,studio): scene.collection.children.link(c)
    mats={k:mat(k,v) for k,v in PALETTE.items()}
    root=bpy.data.objects.new(species+'_ROOT',None); geo.objects.link(root)
    root['Pet']=species; root['FrontAxis']='-Y'; root['NoBodyOrLegs']=True

def assign(obj,name,group,collection=None,parent=True):
    obj.name=name
    target=collection or geo
    for c in list(obj.users_collection): c.objects.unlink(obj)
    target.objects.link(obj); obj.data.materials.append(mats[group])
    obj['RecolourGroup']=group; obj['RobloxMaterial']='Neon' if target==vfx else 'SmoothPlastic'
    if target==vfx: obj['OptionalVFX']=True
    if parent: obj.parent=root
    return obj

def finish(o,bevel=.04):
    if bevel:
        m=o.modifiers.new('Rounded game edge','BEVEL'); m.width=bevel; m.segments=2
        bpy.context.view_layer.objects.active=o; o.select_set(True)
        bpy.ops.object.modifier_apply(modifier=m.name); o.select_set(False)
    for p in o.data.polygons: p.use_smooth=True
    return o

def box(name,loc,size,group='Pearl',bevel=.06,rot=(0,0,0),collection=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot)
    o=bpy.context.object; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(assign(o,name,group,collection),bevel)

def orb(name,loc,size,group='Pearl',collection=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=loc)
    o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(assign(o,name,group,collection),0)

def rod(name,a,b,r,group='Silver',collection=None,r2=None):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish(assign(o,name,group,collection),.018)

def prism(name,points,y,depth,group='Purple',collection=None):
    n=len(points); vs=[]
    for yy in (y-depth/2,y+depth/2): vs += [(x,yy,z) for x,z in points]
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new(name,me); geo.objects.link(o)
    return finish(assign(o,name,group,collection),.035)

def mirror_points(points,side): return [(side*x,z) for x,z in points]

def base_head(species,scale=(1,1,1),face='Cyan'):
    sx,sy,sz=scale
    box('Head_Pearl_Cube',(0,0,0),(3*sx,2.5*sy,2.62*sz),'Pearl',.22)
    box('Face_'+face+'_Panel',(0,-1.27*sy,-.05),(2.63*sx,.16,1.50*sz),face,.18)
    box('Helmet_Pearl_Cap',(0,0,1.02*sz),(3.05*sx,2.55*sy,.72*sz),'Pearl',.16)
    box('Helmet_Cyan_Stripe',(0,-.01,1.39*sz),(.64*sx,2.20*sy,.06),'Cyan',.025)
    # Modular visor bars avoid baked graphics and remain recolourable.
    box('Visor_Silver_Top',(0,-1.39*sy,.46*sz),(2.76*sx,.17,.16),'Silver',.055)
    box('Visor_Silver_Bottom',(0,-1.40*sy,-.61*sz),(2.67*sx,.17,.14),'Silver',.05)
    for side in (-1,1):
        s='L' if side<0 else 'R'
        box(f'Visor_{s}_Violet_Temple',(side*1.38*sx,-1.30*sy,-.05),(.18,.25,1.05*sz),'Purple',.06)
        orb(f'Eye_{s}_Ink',(side*.63*sx,-1.405*sy,-.08*sz),(.37*sx,.115,.48*sz),'Ink')
        orb(f'Eye_{s}_White_Glint',(side*.72*sx,-1.505*sy,.10*sz),(.105,.025,.14),'White')
    prism('Helmet_Yellow_Bolt',[(.07,1.26),(-.17,.98),(-.02,.98),(-.07,.79),(.19,1.09),(.035,1.09)],-1.405*sy,.045,'Yellow')

def feather_wings(kind='Falcon',tiny=False):
    reach=1.35 if tiny else 2.3
    for side in (-1,1):
        s='L' if side<0 else 'R'; orb(f'Wing_{s}_Silver_Joint',(side*1.52,.15,-.14),(.25,.34,.36),'Silver')
        for i in range(3):
            x=1.50+i*.16; z=.14-i*.13
            pts=[(x,z+.17),(x+.30,z+.12),(x+reach-.18*i,z-.38),(x+reach-.05-.18*i,z-.58),(x+.50,z-.49),(x+.05,z-.10)]
            prism(f'Wing_{s}_Feather_{i+1}',mirror_points(pts,side),.02+i*.23,.16,'Purple' if i else 'Pearl')
        a=(side*2.02,.35,-.55); b=(side*2.11,.68,-.96)
        rod(f'Thruster_{s}_Silver',a,b,.18,'Silver'); rod(f'VFX_{s}_Jet',b,(side*2.22,1.15,-1.55),.13,'Glow',vfx,.008)

def ears(shape='point',droop=False):
    for side in (-1,1):
        s='L' if side<0 else 'R'
        if droop:
            pts=[(1.30,.75),(1.73,.52),(1.86,-.60),(1.55,-1.20),(1.25,-.78)]
        elif shape=='hare':
            pts=[(.74,1.15),(1.02,1.18),(1.20,2.95),(.91,3.25),(.67,2.95)]
        else: pts=[(.78,1.15),(1.28,1.12),(1.12,2.00),(.85,2.20)]
        prism(f'Ear_{s}_Pearl',mirror_points(pts,side),0,.30,'Pearl')
        center=[(x*.93,z*.95) for x,z in pts]
        prism(f'Ear_{s}_Violet_Inlay',mirror_points(center,side),-.17,.035,'Purple')

def muzzle(long=False):
    orb('Muzzle_Pearl',(0,-1.47,-.49),(.72,.35,.48 if not long else .60),'Pearl')
    orb('Nose_Ink',(0,-1.79,-.39),(.28,.16,.20),'Ink')

def tail_fan(aquatic=False):
    if aquatic:
        for side in (-1,1):
            prism(f'Tail_{"L" if side<0 else "R"}_Cyan',mirror_points([(1.30,.05),(1.68,.14),(2.38,.70),(2.27,.05),(2.40,-.65),(1.67,-.16)],side),1.00,.22,'Cyan')
    else:
        for i in (-1,0,1):
            x=i*.34; prism(f'Tail_{i+2}_Pearl',[(x-.15,1.15),(x+.15,1.15),(x+i*.12+.18,2.03),(x+i*.12,2.25),(x+i*.12-.18,2.03)],-.55,.15,'Pearl')

def species_parts(name):
    if name=='Eagle':
        base_head(name); feather_wings(name)
        prism('Beak_Yellow_Hook',[(-.28,-.23),(.28,-.23),(.22,-.73),(0,-1.12),(-.22,-.73)],-1.72,.38,'Yellow'); tail_fan()
        for side in (-1,1): prism(f'Brow_{side}_Pearl',mirror_points([(.20,.40),(.42,.62),(1.13,.69),(1.15,.49)],side),-1.52,.12,'Pearl')
    elif name=='Bat':
        base_head(name,face='Purple'); ears()
        orb('Nose_Purple',(0,-1.46,-.42),(.24,.10,.18),'Purple')
        for side in (-1,1):
            pts=[(1.42,.31),(1.88,.78),(2.74,1.02),(2.50,.28),(2.85,-.37),(2.10,-.18),(1.76,-.77),(1.40,-.31)]
            prism(f'Wing_{"L" if side<0 else "R"}_Bat',mirror_points(pts,side),.05,.18,'Ink')
            for i in range(3): rod(f'Wing_{side}_Cyan_Strut',(side*1.50,.03,.15-i*.12),(side*(2.48-i*.18),.03,.67-i*.48),.035,'Cyan')
        for side in (-1,1): rod(f'Fang_{side}_White',(side*.26,-1.53,-.52),(side*.26,-1.57,-.87),.075,'White',r2=.01)
    elif name=='Hummingbird':
        base_head(name,(.92,.94,.94)); feather_wings(name,tiny=True); tail_fan()
        rod('Beak_Yellow_Needle',(0,-1.35,-.30),(0,-3.06,-.34),.14,'Yellow',r2=.025)
    elif name=='Ostrich':
        base_head(name,(.92,.94,1.06)); feather_wings(name,tiny=True)
        prism('Beak_Yellow_Wide',[(-.45,-.28),(.45,-.28),(.31,-.63),(0,-.82),(-.31,-.63)],-1.60,.44,'Yellow')
        for i in (-1,0,1): orb(f'Crest_{i+2}_Pearl',(i*.28,.35,1.72+abs(i)*.04),(.30,.22,.45),'Pearl')
    elif name=='Cheetah':
        base_head(name,face='Yellow'); ears(); muzzle()
        for side in (-1,1):
            for i,(x,z) in enumerate(((.62,.80),(1.02,.66),(.91,.20),(.51,.31))): orb(f'Spot_{side}_{i}',(side*x,-1.37,z),(.11,.035,.14),'Ink')
            prism(f'Cheek_{side}_Cyan_SpeedFin',mirror_points([(1.20,-.16),(1.74,-.02),(2.08,-.28),(1.70,-.42),(1.22,-.37)],side),.22,.16,'Cyan')
    elif name=='Lion':
        base_head(name,face='Yellow'); ears(); muzzle()
        for i in range(10):
            a=2*math.pi*i/10; x=1.62*math.cos(a); z=1.45*math.sin(a)
            orb(f'Mane_{i+1}_Purple',(x,.30,z),(.45,.24,.48),'Purple')
    elif name=='Hare':
        base_head(name,(.92,.94,.98)); ears('hare'); muzzle()
        for side in (-1,1):
            for i,z in enumerate((-.36,-.49,-.62)): rod(f'Whisker_{side}_{i}',(side*.35,-1.70,z),(side*1.25,-1.84,z+.11*(i-1)),.018,'Silver')
    elif name=='Bloodhound':
        base_head(name,(1.02,1.02,.96),face='Yellow'); ears(droop=True); muzzle(True)
        for side in (-1,1): orb(f'Jowl_{side}_Pearl',(side*.43,-1.51,-.71),(.48,.29,.38),'Pearl')
    elif name=='Horse':
        base_head(name,(.95,1.05,1.03)); ears(); muzzle(True)
        for i in range(5): prism(f'Mane_{i+1}_Purple',[(-.22,1.25+i*.13),(.22,1.25+i*.13),(.16,1.78+i*.13),(0,2.05+i*.13),(-.16,1.78+i*.13)],.68+i*.22,.16,'Purple')
        for side in (-1,1): orb(f'Nostril_{side}_Ink',(side*.23,-1.79,-.67),(.07,.04,.05),'Ink')
    elif name in ('Shark','Swordfish','Orca'):
        face='Ink' if name=='Orca' else 'Cyan'; base_head(name,(1.16,1.08,.82),face=face)
        prism('Dorsal_Cyan_Fin',[(-.18,1.01),(.18,1.01),(.04,2.20),(-.12,2.02)],.40,.34,'Cyan')
        for side in (-1,1): prism(f'Fin_{side}_Pearl',mirror_points([(1.25,.05),(1.80,.02),(2.45,-.55),(2.30,-.75),(1.44,-.45)],side),.20,.19,'Pearl')
        tail_fan(True)
        if name=='Shark':
            for i in range(5): rod(f'Tooth_{i+1}_White',((i-2)*.22,-1.48,-.42),((i-2)*.22,-1.54,-.69),.055,'White',r2=.005)
        elif name=='Swordfish': rod('Sword_Silver_Rostrum',(0,-1.34,-.25),(0,-3.75,-.25),.16,'Silver',r2=.035)
        else:
            for side in (-1,1): orb(f'Orca_{side}_White_EyePatch',(side*.66,-1.43,.05),(.53,.06,.26),'White')
    elif name=='Alien':
        base_head(name,(.95,.92,1.0),face='Purple')
        for side in (-1,1):
            rod(f'Antenna_{side}_Silver',(side*.60,0,1.35),(side*.83,0,2.22),.055,'Silver')
            orb(f'Antenna_{side}_Glow',(side*.83,0,2.27),(.20,.20,.20),'Glow',vfx)
            prism(f'Ear_{side}_Cyan',mirror_points([(1.33,.43),(1.86,.54),(2.18,.14),(1.80,-.10),(1.34,.02)],side),0,.22,'Cyan')
        orb('Mouth_Ink',(0,-1.41,-.55),(.25,.045,.08),'Ink')
    # Shared underglow and rear velocity rails.
    box('VFX_Cyan_Underlight',(0,0,-1.34),(2.15,1.75,.045),'Glow',.018,collection=vfx)
    for side in (-1,1): rod(f'VFX_{side}_SpeedRail',(side*1.10,.95,-.92),(side*1.10,2.10,-.92),.045,'Glow',vfx,r2=.005)

def prepare_and_export(name):
    folder=ROOT/name; folder.mkdir(parents=True,exist_ok=True)
    meshes=[o for o in list(geo.objects)+list(vfx.objects) if o.type=='MESH']
    # Bake rotations/scales and fix normals before export.
    for o in meshes:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    # Studio setup.
    floor_m=mat('STUDIO Navy',('101D35',.05,.48))
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-2.10)); floor=bpy.context.object
    for c in list(floor.users_collection): c.objects.unlink(floor)
    studio.objects.link(floor); floor.data.materials.append(floor_m)
    def aim(o,t=(0,0,0)): o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
    for label,loc,col,pwr,size in [('Key',(1,-5,7),(1,.94,.86),1000,5),('Fill',(-5,-2,3),(.25,.85,1),650,4),('Rim',(4,4,5),(.65,.35,1),1000,3)]:
        d=bpy.data.lights.new('STUDIO_'+label,'AREA'); d.energy=pwr; d.shape='DISK'; d.size=size; d.color=col
        o=bpy.data.objects.new(d.name,d); studio.objects.link(o); o.location=loc; aim(o)
    d=bpy.data.cameras.new('Preview Camera'); cam=bpy.data.objects.new('STUDIO_Camera',d); studio.objects.link(cam)
    cam.location=(6.2,-10.8,4.7); aim(cam,(0,.05,0)); d.type='ORTHO'; d.ortho_scale=7.7 if name not in ('Hare','Alien') else 8.4; scene.camera=cam
    scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=720; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(folder/f'GBlox_{name}_Preview.png')
    scene.world=bpy.data.worlds.new(name+' World'); scene.world.color=(.01,.02,.05)
    geo_names={o.name for o in geo.objects}; vfx_names={o.name for o in vfx.objects}
    report={'pet':name,'mesh_count':len(meshes),'base_meshes':len([o for o in meshes if o.name in geo_names]),'vfx_meshes':len([o for o in meshes if o.name in vfx_names]),'triangles':0,'one_material_each':all(len(o.data.materials)==1 for o in meshes),'parts':[]}
    for o in meshes:
        o.data.calc_loop_triangles(); n=len(o.data.loop_triangles); report['triangles']+=n
        report['parts'].append({'name':o.name,'recolour':o.get('RecolourGroup'),'triangles':n})
    for filename,objects in [(f'GBlox_{name}_Parts.fbx',list(geo.objects)),(f'GBlox_{name}_WithVFX.fbx',list(geo.objects)+list(vfx.objects))]:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects: o.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.fbx(filepath=str(folder/filename),use_selection=True,object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_unit_scale=True,use_mesh_modifiers=True,add_leaf_bones=False,bake_anim=False,use_custom_props=True)
    (folder/'parts_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    bpy.ops.render.render(write_still=True)
    # Write only this generated scene and its dependencies into a standalone
    # .blend. This leaves every pre-existing scene and unsaved edit untouched.
    bpy.data.libraries.write(str(folder/f'GBlox_{name}.blend'),{scene},fake_user=True,compress=True)
    bpy.context.window.scene=original_scene
    return {k:v for k,v in report.items() if k!='parts'}

def build(name):
    reset(name); base_only=False
    species_parts(name)
    result=prepare_and_export(name)
    print('PET_COMPLETE '+json.dumps(result)); return result

def validate_fbx(name):
    path=ROOT/name/f'GBlox_{name}_WithVFX.fbx'
    old=bpy.context.scene
    check=bpy.data.scenes.new('TEMP_FBX_CHECK')
    bpy.context.window.scene=check
    bpy.ops.import_scene.fbx(filepath=str(path))
    imported=list(check.objects); meshes=[o for o in imported if o.type=='MESH']
    result={'pet':name,'imported_meshes':len(meshes),'one_material_each':all(len(o.data.materials)==1 for o in meshes),'all_nonzero_size':all(min(o.dimensions)>0 for o in meshes),'vfx_meshes':len([o for o in meshes if o.name.startswith('VFX_')])}
    bpy.context.window.scene=old
    for o in imported: bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(check)
    return result
