from common import *
def camera(name,location,target,lens=42):
    data=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,data)
    collection('81_Cameras').objects.link(ob);ob.location=location
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    data.lens=lens;data.clip_end=2000
    return ob
def area(name,loc,target,color,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);collection('80_Lighting').objects.link(ob)
    ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
def build(save=True):
    s=bpy.context.scene
    world=bpy.data.worlds.new('Citadel | sapphire evening')
    world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.21,.31,.49,1);bg.inputs['Strength'].default_value=.5;s.world=world
    d=bpy.data.lights.new('Late festival sunlight','SUN');d.energy=2.5;d.color=(1,.78,.55);d.angle=.12
    ob=bpy.data.objects.new('Late festival sunlight',d);collection('80_Lighting').objects.link(ob);ob.rotation_euler=(.36,-.48,-.6)
    area('Warm hero softbox',(15,-55,75),(0,0,12),(1,.69,.40),35000,50)
    area('Blue sky rim',(-60,55,100),(0,0,0),(.30,.50,1),48000,65)
    area('Sakura blush',(40,50,28),(40,72,23),(1,.22,.37),4500,18)
    area('Summon cyan fill',(45,-7,16),(69,8,12),(.1,.65,1),2600,12)
    area('Ranked violet fill',(-45,-5,15),(-66,12,10),(.53,.18,1),2300,12)
    point_light('Statue warm footlight',(0,-8,5),(1,.46,.15),700,4)
    point_light('Halo aura',(0,1,22),(.38,.22,1),500,3)
    # Clouds and distant floating mountain silhouettes form a quiet backdrop.
    random.seed(911)
    for i in range(15):
        x=-310+i*43;y=260+random.uniform(-12,60);h=random.uniform(45,95)
        ico('Distant sky mountain',(x,y,-12),(random.uniform(25,48),random.uniform(22,43),h),'stoneDark','82_Backdrop',1)
        ico('Distant mountain cap',(x,y,h*.55),(random.uniform(12,20),random.uniform(9,15),h*.3),'stone','82_Backdrop',1)
    cloudmat=bpy.data.materials.new('ACU_Cloud');cloudmat.diffuse_color=(.5,.63,.74,1);cloudmat.use_nodes=True
    bs=next(n for n in cloudmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.5,.63,.74,1);bs.inputs['Roughness'].default_value=1
    for i in range(35):
        a=random.uniform(0,2*pi);r=random.uniform(170,290)
        ob=ico('Cloud bank',(r*cos(a),r*sin(a),random.uniform(-60,-32)),(random.uniform(22,50),random.uniform(15,32),random.uniform(3,8)),'ivory','82_Backdrop',2)
        ob.data.materials[0]=cloudmat
        for p in ob.data.polygons:p.use_smooth=True
    hero=camera('CAM_01_Citadel',(157,-216,167),(0,6,1),44)
    camera('CAM_02_Arrival',(25,-100,21),(0,28,16),28)
    camera('CAM_03_Champion',(31,-41,21),(0,0,15),40)
    camera('CAM_04_Summon',(24,-22,15),(65,10,11),31)
    camera('CAM_05_MoonGarden',(-91,-81,15),(-55,-48,8),34)
    camera('CAM_06_StoryGate',(-28,28,13),(5,73,16),30)
    camera('CAM_07_Masterplan',(0,-22,285),(0,0,0),40)
    s.camera=hero
    s.render.resolution_x=1600;s.render.resolution_y=1100;s.render.resolution_percentage=65
    s.render.image_settings.file_format='PNG';s.render.film_transparent=False
    s.render.filepath=os.path.join(ROOT,'previews','01_Citadel_Draft.png')
    s.view_settings.exposure=.25
    # Restrained optical bloom keeps bright portals legible.
    ng=bpy.data.node_groups.new('ACU Cinematic Compositor','CompositorNodeTree')
    s.compositing_node_group=ng
    inp=ng.nodes.new('CompositorNodeRLayers');inp.scene=s
    glare=ng.nodes.new('CompositorNodeGlare')
    try: glare.glare_type='FOG_GLOW';glare.quality='MEDIUM';glare.threshold=1.6
    except: pass
    out=ng.nodes.new('NodeGroupOutput')
    ng.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    ng.links.new(inp.outputs['Image'],glare.inputs['Image']);ng.links.new(glare.outputs['Image'],out.inputs['Image'])
    # Cameras and collections remain editable in the saved project.
    for a in (bpy.context.screen.areas if bpy.context.screen else []):
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.clip_end=2000
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'ACU_Festival_Citadel.blend'))

