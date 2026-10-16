import bpy, math, json
from mathutils import Vector

def choose(owner, name, value):
    prop=owner.bl_rna.properties.get(name)
    choices=[i.identifier for i in prop.enum_items] if prop and prop.type=='ENUM' else []
    if value not in choices:raise RuntimeError(str((name,value,choices)))
    setattr(owner,name,value)

def build_rig(scene,body_collection,hair_collection,rig_collection):
    data=bpy.data.armatures.new('R6 - seven bone skeleton')
    rig=bpy.data.objects.new('Guku_MasterInstinct_R6',data);rig_collection.objects.link(rig)
    rig.show_in_front=True
    choose(data,'display_type','STICK')
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    modes=[x.identifier for x in bpy.ops.object.mode_set.get_rna_type().properties['mode'].enum_items]
    assert 'EDIT' in modes and 'OBJECT' in modes
    bpy.ops.object.mode_set(mode='EDIT')
    specs=[
        ('HumanoidRootPart',(0,0,3),(0,0,3.45),None),
        ('Torso',(0,0,3),(0,0,4),'HumanoidRootPart'),
        ('Head',(0,0,4.10),(0,0,5.10),'Torso'),
        ('Right Arm',(-1.04,0,3.80),(-1.565,0,2.15),'Torso'),
        ('Left Arm',(1.04,0,3.80),(1.565,0,2.15),'Torso'),
        ('Right Leg',(-.53,0,2.02),(-.53,0,.20),'Torso'),
        ('Left Leg',(.53,0,2.02),(.53,0,.20),'Torso'),
    ]
    for name,head,tail,parent in specs:
        b=data.edit_bones.new(name);b.head=head;b.tail=tail
        if parent:b.parent=data.edit_bones[parent]
        b.use_connect=False
    bpy.ops.object.mode_set(mode='OBJECT')
    for o in list(body_collection.objects)+list(hair_collection.objects):
        if o.type!='MESH':continue
        bone=o['r6_part']
        vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
        o.parent=rig
        mod=o.modifiers.new('R6 rigid binding','ARMATURE');mod.object=rig
        o['Binding']='Rigid, one bone per vertex; no elbow/knee deformation'
    for b in rig.pose.bones:
        choose(b,'rotation_mode','XYZ')
        b.lock_scale=(True,True,True)
        if b.name!='HumanoidRootPart':b.lock_location=(True,True,True)
    rig['RigType']='R6 - Blender animation rig'
    rig['ExportNote']='Six body parts plus root. Studio Motor6D setup/import verification remains a separate step.'
    rig['ResetPose']='Pose Mode: select all bones; Alt+R and Alt+G'
    return rig

def stage(scene,collection,mats):
    world=bpy.data.worlds.new('Midnight navy studio');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.016,.022,.050,1);bg.inputs['Strength'].default_value=.35
    scene.world=world
    def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    def light(name,pos,color,power,size):
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);collection.objects.link(o);o.location=pos;aim(o,(0,0,3));return o
    light('Key - soft warm',( -4,-6,8),(1,.83,.65),1050,5)
    light('Fill - cool front',(4,-4,5),(.63,.79,1),850,4)
    light('Rim - ultraviolet',(3,3,6),(.42,.21,1),1400,3)
    light('Rim - ice',(-3,2,6),(.28,.72,1),1700,3)
    d=bpy.data.cameras.new('Mastered Instinct portrait camera');choose(d,'type','ORTHO');d.ortho_scale=8.2
    cam=bpy.data.objects.new('CAMERA - full form',d);collection.objects.link(cam)
    cam.location=(8,-19,8);aim(cam,(0,0,3.24));scene.camera=cam
    scene.render.resolution_x=1000;scene.render.resolution_y=1150;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.render.fps=30;scene.frame_start=1;scene.frame_end=90
    # Subtle grounding disc, separate from the exportable model.
    verts=[(0,0,-.05)];n=96
    verts.extend((2.90*math.cos(i*math.tau/n),2.20*math.sin(i*math.tau/n),-.05) for i in range(n))
    mesh=bpy.data.meshes.new('Grounding disc');mesh.from_pydata(verts,[],[(0,i+1,(i+1)%n+1) for i in range(n)]);mesh.update()
    obj=bpy.data.objects.new('STUDIO - shadow platform',mesh);collection.objects.link(obj)
    m=bpy.data.materials.new('Platform slate');m.diffuse_color=(.025,.034,.065,1);m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(.025,.034,.065,1);p.inputs['Roughness'].default_value=.55
    mesh.materials.append(m)
    # Low-cost physically shaded preview; scene retains its available Eevee engine.
    scene.render.engine='BLENDER_EEVEE'
    if hasattr(scene,'eevee'):scene.eevee.taa_render_samples=48
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.region_3d.view_camera_zoom=0
                area.spaces.active.overlay.show_overlays=False
                choose(area.spaces.active.shading,'type','MATERIAL')
                area.spaces.active.shading.use_scene_world=True
                area.spaces.active.shading.use_scene_lights=True
    return cam
