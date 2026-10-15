from common import *
import shutil
def boundary(a):
    return 300/(abs(cos(a))**6+abs(sin(a))**6)**(1/6)+4*sin(7*a)
def build():
    random.seed(9677)
    # Reshape the island into an organic rounded square to support the new town wards.
    ob=bpy.data.objects.get('Expanded citadel | ancient island cliffs')
    if ob:
        for j,scale in enumerate((1,1.005,.98,.89,.62,.12)):
            for i in range(160):
                a=2*pi*i/160;v=ob.data.vertices[j*160+i]
                r=boundary(a)*scale;v.co.x=r*cos(a);v.co.y=r*sin(a)
    ob=bpy.data.objects.get('Expanded island top')
    if ob:
        for i,v in enumerate(ob.data.vertices):
            a=2*pi*i/160;r=boundary(a);v.co.x=r*cos(a);v.co.y=r*sin(a)
    for ob in collection('50_ExpandedLand').objects:
        if ob.name.startswith(('Stratified outer cliff mass','Cliff grassy cap')):
            a=math.atan2(ob.location.y,ob.location.x);r=boundary(a)
            ob.location.x=r*cos(a);ob.location.y=r*sin(a)
    # Terraced fortress perimeter gives the town a substantial skyline at eye level.
    G='70_CityPerimeter'
    n=160
    for i in range(n):
        a=2*pi*i/n;b=2*pi*(i+1)/n;mid=(a+b)/2
        if abs(cos(mid))<.074:continue
        p=Vector(((boundary(a)-5)*cos(a),(boundary(a)-5)*sin(a)))
        q=Vector(((boundary(b)-5)*cos(b),(boundary(b)-5)*sin(b)))
        c=(p+q)/2;d=q-p
        ob=box('City retaining wall',(c.x,c.y,3.7),(d.length+.3,3.6,5.4),'stone','70_CityPerimeter',bevel=.12);ob.rotation_euler.z=math.atan2(d.y,d.x)
        ob=box('Perimeter dark plinth',(c.x,c.y,1.7),(d.length+.4,4.2,.8),'stoneDark',G,bevel=.12);ob.rotation_euler.z=math.atan2(d.y,d.x)
        ob=box('Perimeter promenade cap',(c.x,c.y,6.65),(d.length+.4,4.7,.55),'stoneLight',G,bevel=.13);ob.rotation_euler.z=math.atan2(d.y,d.x)
        # Masonry joint courses and inset stone blocks.
        for z in (2.4,4.2):
            pp=c+Vector((cos(mid),sin(mid)))*1.82
            ob=box('Wall cut-stone course',(pp.x,pp.y,z),(d.length,.045,.055),'stoneDark',G);ob.rotation_euler.z=math.atan2(d.y,d.x)
        if i%2==0:
            box('Outer wall pier',(p.x,p.y,4.4),(4.6,4.6,7.0),'stoneDark',G,bevel=.14)
            cylinder('Wall post gilded cap',(p.x,p.y,8.1),2,.25,'gold',G,vertices=8)
    # Landscape medallions fill the arrival quarter without blocking the boulevard.
    for cx,cy,r in [(-68,-155,18),(65,-169,15),(-78,-211,11),(68,-231,12)]:
        cylinder('Garden roundel masonry',(cx,cy,1.5),r,.7,'stoneDark','71_ArrivalGardens',vertices=64)
        ring('Garden roundel pale coping',(cx,cy,1.92),r+.1,r-.7,.25,'stoneLight','71_ArrivalGardens',segments=64)
        cylinder('Roundel planted soil',(cx,cy,1.9),r-.75,.18,'moss','71_ArrivalGardens',vertices=64)
        ring('Garden inner walkway',(cx,cy,2.03),r-2.5,r-5.5,.15,'stone','71_ArrivalGardens',segments=64)
        for k in range(9):
            a=2*pi*k/9;px=cx+(r-1.6)*cos(a);py=cy+(r-1.6)*sin(a)
            for j in range(5):
                ob=ico('Cloud hedge scallop',(px+random.uniform(-1,1),py+random.uniform(-1,1),2.5+random.uniform(0,.5)),(1.5,1.35,.9),'leaf' if j%2 else 'leafLight','71_ArrivalGardens',2)
                for p in ob.data.polygons:p.use_smooth=True
            for j in range(8):
                x=px+random.uniform(-1.8,1.8);y=py+random.uniform(-1.8,1.8)
                ico('Garden blossoms',(x,y,3.25),(.22,.22,.15),'blossom' if k%2 else 'goldLight','71_ArrivalGardens',1)
        for k in range(5):
            a=2*pi*k/5
            ico('Zen basalt grouping',(cx+4*cos(a),cy+4*sin(a),3.6),(2.1,1.7,2.5 if k==0 else 1.5),'rock','71_ArrivalGardens',2)
        cylinder('Roundel stone lamp pedestal',(cx,cy,2.4),1.3,1,'stoneDark','71_ArrivalGardens',vertices=8)
        box('Stone garden lantern',(cx,cy,4.3),(1.7,1.7,2.5),'stone','71_ArrivalGardens',bevel=.15)
        box('Lantern luminous inset',(cx,cy-.87,4.3),(.75,.03,.85),'goldGlow','71_ArrivalGardens')
        mesh('Garden lantern pointed roof',[(cx-1.4,cy-1.4,5.5),(cx+1.4,cy-1.4,5.5),(cx+1.4,cy+1.4,5.5),(cx-1.4,cy+1.4,5.5),(cx,cy,6.7)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'roof','71_ArrivalGardens')
    # Pack and display the supplied full logo near the new arrival gate.
    src=r'C:\Users\sandt\Downloads\Codex Image 26 Sept 2026, 12_45_50.png'
    dst=os.path.join(ROOT,'textures','Anime_Combat_Units_Full_Logo.png')
    if not os.path.exists(dst):shutil.copy2(src,dst)
    img=bpy.data.images.load(dst,check_existing=True)
    ma=bpy.data.materials.new('ACU_Full_Logo_Texture');ma.use_nodes=True
    ns=ma.node_tree.nodes;lk=ma.node_tree.links
    bs=next(n for n in ns if n.type=='BSDF_PRINCIPLED')
    tex=ns.new('ShaderNodeTexImage');tex.image=img;lk.new(tex.outputs['Color'],bs.inputs['Base Color']);lk.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    lk.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.15;bs.inputs['Roughness'].default_value=.6
    cx=-35;cy=-236
    box('Arrival brand monument',(cx,cy,10.4),(20,2,20),'stoneDark','72_ACUBrand',bevel=.4)
    for dx in (-10.25,10.25):box('Monument gilt border',(cx+dx,cy-1.1,10.4),(.3,.22,20.3),'gold','72_ACUBrand',bevel=.03)
    for dz in (0,20.7):box('Monument gilt border',(cx,cy-1.1,dz),(20.7,.22,.3),'gold','72_ACUBrand',bevel=.03)
    ob=mesh('Original full ACU logo plaque',[(cx-9.6,cy-1.15,.8),(cx+9.6,cy-1.15,.8),(cx+9.6,cy-1.15,20),(cx-9.6,cy-1.15,20)],[(0,1,2,3)],'gold','72_ACUBrand');ob.data.materials[0]=ma
    for i,uv in enumerate(((0,0),(1,0),(1,1),(0,1))):ob.data.uv_layers.active.data[i].uv=uv
    # More saturated, lower-fill lighting brings the colour palette back.
    bg=next(n for n in bpy.context.scene.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Strength'].default_value=.055
    bpy.context.scene.view_settings.exposure=.1
    for key,col in {'moss':(.10,.23,.095),'leaf':(.025,.19,.085),'leafLight':(.12,.38,.14),'red':(.55,.015,.035),'purple':(.21,.016,.4)}.items():
        mat=MATS[key];mat.diffuse_color=(*col,1)
        bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(*col,1)
    # Choose views from real open routes, not through foreground foliage.
    views={'CAM_08_ExpandedCity':((483,-677,510),(0,0,6),43),
           'CAM_10_Waterfall':((-295,40,26),(-242,127,27),30),
           'CAM_13_CivicCourt':((-31,-31,10),(9,45,17),28),
           'CAM_09_MarketStreet':((155,-211,9),(155,-91,18),31)}
    for name,(loc,target,lens) in views.items():
        ob=bpy.data.objects.get(name)
        if ob:ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();ob.data.lens=lens

