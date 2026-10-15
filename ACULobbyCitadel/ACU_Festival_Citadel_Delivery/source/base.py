from common import *
import shutil
random.seed(90726)
def tiled_annulus(name,inner,outer,z,segments,group,mat1='stone',mat2='stoneLight',gap=.035):
    for i in range(segments):
        a=2*pi*i/segments+gap/inner;b=2*pi*(i+1)/segments-gap/inner
        pts=[(r*cos(t),r*sin(t),h) for h in (z-.13,z) for r,t in ((inner,a),(outer,a),(outer,b),(inner,b))]
        mesh(name+'_%03d'%i,pts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat1 if i%5 else mat2,group)
def build():
    G='10_Island'
    n=96; rr=[110+random.uniform(-3,3) for i in range(n)]
    verts=[]
    for scale,z in ((1,1.05),(1.015,-3),(.95,-12),(.74,-25),(.48,-42),(.07,-55)):
        for i in range(n):
            a=2*pi*i/n; r=rr[i]*scale
            verts.append((r*cos(a),r*sin(a),z+random.uniform(-1,1)*(z<0)))
    faces=[]
    for j in range(5):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces += [(a,b,b+n),(a,b+n,a+n)]
    faces.append(tuple(range(5*n,6*n)))
    ob=mesh('Citadel | hewn floating bedrock',verts,faces,'rock',G)
    for key in ('stoneDark','moss','stone'):ob.data.materials.append(MATS[key])
    for p in ob.data.polygons:p.material_index=random.choices([0,1,2,3],[.48,.4,.07,.05])[0]
    cylinder('Garden terrace | walkable island top',(0,0,.65),109,1.1,'moss',G,vertices=128)
    ring('Outer masonry retaining cornice',(0,0,.6),111,107,1.8,'stoneDark',G,segments=128)
    ring('Outer terrace gold coping',(0,0,1.37),110,108,.28,'stoneLight',G,segments=128)
    # Secondary footpaths form a continuous exploration loop.
    ring('Promenade | loop path',(0,0,1.22),97,91,.22,'stone', '11_Paths',segments=128)
    for radius in (91,97):
        ring('Promenade narrow edging',(0,0,1.36),radius+.1,radius-.1,.12,'stoneLight','11_Paths',segments=128)
    for a in range(0,360,5):
        t=math.radians(a)
        for r in (91.4,96.6):
            ob=box('Loop pavement joint',(r*cos(t),r*sin(t),1.4),(1.9,.075,.06),'stoneDark','11_Paths')
            ob.rotation_euler.z=t
    # Grand radial arrival court, deliberately broad for movement.
    cylinder('Grand court foundation',(0,0,1.25),33,0.42,'stoneDark','12_GrandPlaza',vertices=128)
    for inn,out,seg in ((8.5,13,40),(13.2,19,56),(19.2,25,64),(25.2,31.8,80)):
        tiled_annulus('Radial cut limestone',inn,out,1.52,seg,'12_GrandPlaza')
    for r in (8.4,13.1,19.1,25.1,32.4):
        ring('Court gilded concentric inlay',(0,0,1.56),r+.06,r-.06,.04,'gold','12_GrandPlaza',segments=128)
    for i in range(12):
        a=2*pi*i/12
        ob=box('Twelve compass spokes',(20.5*cos(a),20.5*sin(a),1.58),(24.5,.13,.04),'gold','12_GrandPlaza')
        ob.rotation_euler.z=a
        # outer diamond jewels
        ob=box('Court compass jewel',(30*cos(a),30*sin(a),1.6),(1.3,1.3,.045),'purple','12_GrandPlaza')
        ob.rotation_euler.z=a+pi/4
    routes=[((0,-123),(0,-31),16),((0,31),(0,82),18),((31,4),(72,4),14),((-31,8),(-70,12),14),((-24,24),(-63,65),11),((27,-21),(68,-52),11)]
    for idx,(a,b,w) in enumerate(routes):
        path_strip('Main route base '+str(idx),a,b,w+1.1,'stoneDark',1.16)
        path_strip('Main route paving '+str(idx),a,b,w,'stoneLight',1.29)
        av=Vector(a);bv=Vector(b);d=(bv-av).normalized();s=Vector((d.y,-d.x));length=(bv-av).length
        for e in (-1,1):
            aa=av+s*e*(w/2-.38);bb=bv+s*e*(w/2-.38)
            path_strip('Gold navigation inlay',aa,bb,.12,'gold',1.40)
            aa=av+s*e*(w/2-.74);bb=bv+s*e*(w/2-.74)
            path_strip('Indigo paving border',aa,bb,.32,'stoneDark',1.4)
        for j in range(int(length/3)):
            p=av+d*(j*3+1.5)
            ob=box('Paving cross joint',(p.x,p.y,1.391),(w-2,.055,.02),'stoneDark','11_Paths')
            ob.rotation_euler.z=-math.atan2(d.x,d.y)
        for j in range(int(length/5)):
            p=av+d*(j*5+2.5)
            ob=box('Central wayfinding dash',(p.x,p.y,1.423),(.13,1.2,.025),'gold','11_Paths')
            ob.rotation_euler.z=-math.atan2(d.x,d.y)
    # Main approach has sculpted bridge supports and safety balustrades.
    box('Arrival bridge undercroft',(0,-111,-1.2),(18,27,4),'stoneDark','13_Arrival')
    for x in (-9,9):
        tube('Arrival bridge rail',[(x,-123,3.6),(x,-107,3.6),(x,-92,3.6)],[.22,.22,.22],'red','13_Arrival',sides=8)
        tube('Arrival bridge gold handrail',[(x,-123,4.2),(x,-92,4.2)],[.18,.18],'gold','13_Arrival',sides=8)
        for y in range(-122,-91,5):
            box('Arrival baluster',(x,y,2.45),(.6,.6,2.6),'wood','13_Arrival',bevel=.08)
            cylinder('Baluster cap',(x,y,3.94),.45,.24,'gold','13_Arrival',vertices=8)
    for y in (-107,-115,-123):
        # pointed buttresses under the bridge
        mesh('Bridge support fin',[(-8,y-1,-1),(8,y-1,-1),(5,y-1,-12),(0,y-1,-16),(-5,y-1,-12),(-8,y+1,-1),(8,y+1,-1),(5,y+1,-12),(0,y+1,-16),(-5,y+1,-12)],[(0,4,3,2,1),(5,6,7,8,9),(0,1,6,5),(1,2,7,6),(2,3,8,7),(3,4,9,8),(4,0,5,9)],'rock','13_Arrival')
    marker('PlayerArrival',(0,-102,2.8),'PlayerSpawn')
    marker('ArrivalCameraLook',(0,0,18),'CameraLook')
    # Raised framing lantern pylons and indigo banners.
    for side in (-1,1):
        for y in (-83,-59):
            x=side*12.5;g='14_Wayfinding'
            box('Lantern square stone foot',(x,y,1.7),(2.3,2.3,1),'stoneDark',g,bevel=.1)
            cylinder('Arrival lantern column',(x,y,6.5),.38,9,'red',g,vertices=12)
            for h in (2.4,7.8,10.6):ring('Lantern collars',(x,y,h),.59,.30,.25,'gold',g,segments=12)
            box('Lantern luminous chamber',(x,y,9.5),(1.3,1.3,2),'goldGlow',g,bevel=.12)
            for dx,dy in ((-.75,-.75),(.75,-.75),(.75,.75),(-.75,.75)):
                box('Lantern fine frame',(x+dx,y+dy,9.5),(.13,.13,2.2),'wood',g)
            mesh('Lantern upswept cap',[(x-1.3,y-1.3,10.7),(x+1.3,y-1.3,10.7),(x+1.3,y+1.3,10.7),(x-1.3,y+1.3,10.7),(x,y,11.5)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'roof',g)
            tube('Banner crossbar',[(x,y,8),(x+side*3.5,y,8)],.12,'gold',g,sides=6)
            v=[(x+side*.5,y,7.9),(x+side*3.3,y,7.9),(x+side*3.2,y+.5,3.9),(x+side*1.9,y+.2,3.2),(x+side*.6,y,3.9)]
            mesh('Silk pennant | ACU purple',v,[(0,1,2,3,4)],'purple',g)
            text('Banner seal','ACU',(x+side*1.9,y-.07,6.5),.72,'goldLight',g)
            point_light('Amber arrival lamp',(x,y,9.5),(1,.43,.14),85,1.3)
    # The rim is detailed on the skyline, with intentional gaps at arrival.
    for i in range(56):
        a=2*pi*i/56
        if abs(math.atan2(sin(a+pi/2),cos(a+pi/2)))<.18:continue
        x=108*cos(a);y=108*sin(a)
        ob=box('Rim pier',(x,y,2.4),(1.6,1.6,2.2),'stoneDark','15_Rim',bevel=.09);ob.rotation_euler.z=a
        cylinder('Rim gold finial',(x,y,3.8),.47,.4,'gold','15_Rim',vertices=8)
        an=a+2*pi/56
        tube('Rim upper rail',[(108*cos(a),108*sin(a),3.3),(108*cos(an),108*sin(an),3.3)],.12,'gold','15_Rim',sides=6)
        tube('Rim lower rail',[(108*cos(a),108*sin(a),2.4),(108*cos(an),108*sin(an),2.4)],.11,'wood','15_Rim',sides=6)
    # Floating rock splinters and streams below the garden.
    for i in range(38):
        a=random.uniform(0,2*pi);r=random.uniform(78,113);z=random.uniform(-30,-4)
        ico('Floating geological shard',(r*cos(a),r*sin(a),z),(random.uniform(2,6),random.uniform(2,6),random.uniform(4,11)),'rock','16_SkyScenery',1)
    for a in (0.3,2.7,4.9):
        x=106*cos(a);y=106*sin(a)
        tube('Celestial waterfall',[(x,y,.9),(x*1.02,y*1.02,-8),(x*1.05,y*1.05,-29),(x*1.07,y*1.07,-50)],[1.8,1.6,1.3,.5],'cyan','16_SkyScenery',sides=8)
        tube('Waterfall luminous thread',[(x-.4,y-.3,.9),(x*1.02-.4,y*1.02,-8),(x*1.05,y*1.05,-29),(x*1.07,y*1.07,-50)],[.22,.2,.15,.06],'cyanGlow','16_SkyScenery',sides=5)
    # Arrival seal sits in the paving in front of the champion.
    cylinder('Arrival medallion',(0,-25,1.6),3,.08,'purple','12_GrandPlaza',vertices=48)
    ring('Arrival medallion gold rim',(0,-25,1.65),3.05,2.85,.08,'gold','12_GrandPlaza',segments=48)
    text('Arrival court inscription','A C U',(0,-25,1.73),1.8,'goldLight','12_GrandPlaza',rotation=(0,0,0))
    text('Arrival welcome inlay','FESTIVAL CITADEL',(0,-42,1.45),1.3,'stoneDark','14_Wayfinding',rotation=(0,0,0))
    # Lightweight navigation stones at the main forks.
    for x,y,label in [(-15,-33,'RANKED'),(15,-33,'SUMMON'),(-35,27,'CHAMPIONS'),(31,-26,'SHOP')]:
        cylinder('Waystone foot',(x,y,1.6),1.5,.5,'stoneDark','14_Wayfinding',vertices=12)
        box('Waystone monolith',(x,y,3.6),(3.8,.65,3.8),'stoneDark','14_Wayfinding',bevel=.16)
        box('Waystone luminous underline',(x,y-.36,2.6),(3,.04,.10),'purpleGlow','14_Wayfinding')
        text('Waystone '+label,label,(x,y-.38,3.8),.52,'goldLight','14_Wayfinding')
    for name,loc,role in [('StoryDestination',(0,85,2),'TeleportStory'),('SummonDestination',(61,5,2),'OpenSummon'),('RankedDestination',(-59,9,2),'OpenRanked'),('ShopDestination',(62,-42,2),'OpenShop')]:marker(name,loc,role)
def brand():
    source=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Anime Combat Units\Main Screen UI\Arena selection\ACU abrevviation logo(mini packet logo).png'
    target=os.path.join(ROOT,'textures','ACU_Logo.png')
    if not os.path.exists(target):shutil.copy2(source,target)
    img=bpy.data.images.load(target,check_existing=True)
    mat=bpy.data.materials.new('ACU_Logo_Texture');mat.use_nodes=True
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.35
    bs.inputs['Roughness'].default_value=.45
    # Brand crest is a real texture-backed plane, not reconstructed lettering.
    ob=mesh('ACU original logo | arrival crest',[(-9,-48,9),(9,-48,9),(9,-48,19.12),(-9,-48,19.12)],[(0,1,2,3)],'gold','17_Brand')
    ob.data.materials.clear();ob.data.materials.append(mat)
    for i,uv in enumerate(((0,0),(1,0),(1,1),(0,1))):ob.data.uv_layers.active.data[i].uv=uv
    for x in (-10,10):
        box('Crest support',(x,-47.8,8),(1.1,1.1,13.6),'wood','17_Brand',bevel=.08)
        ring('Crest gold collar',(x,-47.8,12),.75,.5,.35,'gold','17_Brand',segments=12)
    tube('Crest lintel',[(-11,-47.8,14),(-8,-47.8,13.3),(8,-47.8,13.3),(11,-47.8,14)],[.5,.5,.5,.5],'red','17_Brand',sides=8)

