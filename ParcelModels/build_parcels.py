import bpy,math,json,os
from mathutils import Vector,Matrix
OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ParcelModels'
assert 'To be rich - Parcels' not in bpy.data.scenes
scene=bpy.data.scenes.new('To be rich - Parcels');bpy.context.window.scene=scene
materials={}
def mat(name,rgb):
    m=bpy.data.materials.new('Parcel_'+name);m.use_nodes=True
    c=tuple((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in rgb)
    m.diffuse_color=(*c,1);m['RGB']=rgb
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=.88
    n.inputs['Specular IOR Level'].default_value=.12
    materials[name]=m
    return m
for name,rgb in {'Cardboard':(185,141,87),'Flaps':(202,159,104),'Tape':(217,182,118),'TapeSeam':(171,135,79),'Paper':(243,239,225),'Ink':(54,46,36),'Red':(215,48,41),'White':(250,243,226),'Ground':(48,57,72),'Gold':(224,162,43),'GoldTop':(242,193,71),'GoldGlow':(255,194,34),'Rainbow':(168,99,214),'RainbowTop':(196,135,232),'GlowRed':(255,62,86),'GlowOrange':(255,157,48),'GlowYellow':(251,233,66),'GlowGreen':(78,227,137),'GlowBlue':(51,183,255),'GlowPurple':(196,84,253)}.items():mat(name,rgb)
for name in ('Gold','GoldTop','Rainbow','RainbowTop'):
    n=next(n for n in materials[name].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Metallic'].default_value=.35;n.inputs['Roughness'].default_value=.3
for name in ('GoldGlow','GlowRed','GlowOrange','GlowYellow','GlowGreen','GlowBlue','GlowPurple'):
    n=next(n for n in materials[name].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Emission Color'].default_value=materials[name].diffuse_color;n.inputs['Emission Strength'].default_value=1.6
src=open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LaptopModels\build_laptops.py',encoding='utf-8').read()
exec(src[src.index('class Meshes:'):src.index('\nmodels=[]')])
models=[]
for name,d,offset,fragile in [('Small',1.3,-4.2,False),('Medium',1.9,-1.1,False),('Large',2.6,2.6,False),('Fragile',1.9,-4.2,True),('Gold',1.9,-1.1,False),('Rainbow',1.9,2.6,False)]:
    col=bpy.data.collections.new('Parcel_'+name);scene.collection.children.link(col)
    a=Meshes(col,'Parcel'+name,offset);h=d
    coat=name if name in ('Gold','Rainbow') else 'Cardboard'
    flap=name+'Top' if name in ('Gold','Rainbow') else 'Flaps'
    a.box('Body',coat,(0,0,(h-.012)/2),(d,d,h-.012))
    for side in (-1,1):a.box('TopFlaps',flap,(side*(d+.008)/4,0,h-.006),((d-.008)/2,d,.012))
    a.box('PackingTape','Tape',(0,0,h+.002),(.17*d,d,.004))
    for side in (-1,1):a.box('PackingTape','Tape',(0,side*(d/2+.002),h*.855),(.17*d,.004,h*.29))
    a.box('TapeJoin','TapeSeam',(0,0,h+.0045),(.006,d,.001))
    # A side label and a smaller routing sticker on top.
    front=Matrix.Translation((0,-d/2-.003,0))@Matrix.Rotation(math.pi/2,4,'X')
    a.box('ShippingLabels','Paper',(d*.225,h*.39,.002),(d*.42,h*.36,.004),front)
    a.text('ShippingInk','Ink','TBR / EXPRESS',d*.225,h*.515,.005,d*.034,front)
    a.text('ShippingInk','Ink','SHIP TO WAREHOUSE',d*.225,h*.455,.005,d*.023,front)
    a.text('ShippingInk','Ink','0482  7160',d*.225,h*.275,.005,d*.029,front)
    widths=[1,1,3,1,2,2,1,3,1,1,2,1,3,2,1,1,1,3,2,2,1,1]
    step=d*.007;x=d*.05
    for unit in widths:
        a.box('ShippingInk','Ink',(x+unit*step/2,h*.355,.005),(unit*step,h*.105,.001),front)
        x+=(unit+1)*step
    a.box('ShippingLabels','Paper',(-d*.285,-d*.12,h+.002),(d*.32,d*.38,.004))
    a.text('ShippingInk','Ink',name.upper() if not fragile else 'HANDLE',-d*.285,-d*.08,h+.005,d*.045)
    a.text('ShippingInk','Ink','TBR',-d*.285,-d*.18,h+.005,d*.055)
    # Printed upright handling arrows on the left side of the front face.
    for x in (-d*.35,-d*.20):
        poly=[(x-d*.045,h*.29),(x-d*.016,h*.29),(x-d*.016,h*.43),(x+d*.016,h*.43),(x+d*.016,h*.29),(x+d*.045,h*.29),(x,h*.22)]
        # Flip the arrow vertically so the head points up.
        a.prism('HandlingMarks','Ink',[(px,h*.68-py) for px,py in reversed(poly)],.001,.003,front)
    if fragile:
        a.box('FragileSticker','Red',(-d*.275,h*.40,.005),(d*.34,h*.34,.004),front)
        a.text('FragilePrint','White','FRAGILE',-d*.275,h*.29,.008,d*.042,front)
        # Wine glass silhouette.
        cx=-d*.275
        glass=[(cx-d*.064,h*.52),(cx+d*.064,h*.52),(cx+d*.052,h*.45),(cx+d*.012,h*.423),(cx+d*.012,h*.37),(cx+d*.052,h*.37),(cx+d*.052,h*.354),(cx-d*.052,h*.354),(cx-d*.052,h*.37),(cx-d*.012,h*.37),(cx-d*.012,h*.423),(cx-d*.052,h*.45)]
        a.prism('FragilePrint','White',list(reversed(glass)),.0075,.0085,front)
    if name in ('Fragile','Gold','Rainbow'):
        colours=['Red'] if fragile else (['GoldGlow'] if name=='Gold' else ['GlowRed','GlowOrange','GlowYellow','GlowGreen','GlowBlue','GlowPurple'])
        j=0
        for axis in range(3):
            others=[i for i in range(3) if i!=axis]
            for aa in (-1,1):
                for bb in (-1,1):
                    p=[0,0,h/2];size=[.015,.015,.015]
                    p[others[0]]+=aa*(d/2+.005);p[others[1]]+=bb*(d/2+.005);size[axis]=d+.016
                    a.box('Outline' if fragile else 'GlowBorder',colours[j%len(colours)],p,size);j+=1
    obs=a.finish()
    dims={'Small':(1.50,1.08,.72),'Medium':(1.90,1.55,1.45),'Large':(2.25,1.90,2.60)}.get(name,(1.90,1.55,1.45))
    yoffset=1.7 if name in ('Small','Medium','Large') else -1.7
    for ob in obs:
        ob['ParcelPart']=ob.pop('LaptopPart')
        for v in ob.data.vertices:
            v.co.x=offset+(v.co.x-offset)*dims[0]/d
            v.co.y=yoffset+v.co.y*dims[1]/d
            v.co.z*=dims[2]/d
    models.append({'name':name,'dim':dims,'offset':offset,'yoffset':yoffset,'objects':obs})
bpy.app.driver_namespace['parcel_models']=models
stage=bpy.data.collections.new('Parcel Presentation');scene.collection.children.link(stage)
me=bpy.data.meshes.new('ParcelGround');me.from_pydata([(-100,-100,-.015),(100,-100,-.015),(100,100,-.015),(-100,100,-.015)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('ParcelGround',me);stage.objects.link(ob);me.materials.append(materials['Ground'])
world=bpy.data.worlds.new('ParcelWorld');world.use_nodes=True
n=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');n.inputs[0].default_value=(.21,.25,.32,1);n.inputs[1].default_value=.45;scene.world=world
for name,pos,power,size in [('Key',(-4,-5,9),1500,7),('Fill',(6,-2,6),800,5),('Rim',(1,5,8),1000,5)]:
    ld=bpy.data.lights.new('Parcel_'+name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
    ob=bpy.data.objects.new('Parcel_'+name,ld);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('ParcelCamera');ob=bpy.data.objects.new('ParcelCamera',cam);stage.objects.link(ob)
ob.location=(8,-16,14);ob.rotation_euler=(Vector((-.6,0,1))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=12.7;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX';scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.region_3d.view_rotation=ob.rotation_euler.to_quaternion();sp.region_3d.view_location=(-.6,0,1);sp.region_3d.view_distance=13;area.tag_redraw()
bpy.context.view_layer.update()
print(json.dumps({'scene':scene.name,'models':[{k:v for k,v in m.items() if k!='objects'}|{'parts':len(m['objects'])} for m in models]}))
