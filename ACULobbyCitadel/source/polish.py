from common import *
def pine(name,cx,cy,h=12):
    G='46_PineGardens'
    tube(name+' twisting trunk',[(cx,cy,1.3),(cx+.7,cy,4),(cx-1,cy+.6,8),(cx+.8,cy,h)],[.8,.72,.42,.12],'wood',G,9)
    clusters=[(-3,-.8,h*.65,3.8),(3,1,h*.76,4),(0,-2,h*.93,4.4),(-1,2,h,3.2)]
    for idx,(dx,dy,z,r) in enumerate(clusters):
        tube(name+' bough',[(cx,cy,z*.64),(cx+dx*.6,cy+dy*.6,z-.5),(cx+dx,cy+dy,z)],[.31,.24,.08],'wood',G,7)
        for j in range(5):
            a=j*2*pi/5
            ob=ico(name+' cloud foliage',(cx+dx+cos(a)*r*.5,cy+dy+sin(a)*r*.42,z+random.uniform(-.2,.25)),(r*.76,r*.64,random.uniform(.65,1.1)),'leafLight' if j%3==0 else 'leaf',G,2)
            for p in ob.data.polygons:p.use_smooth=True
def lantern(name,loc,scale=1):
    x,y,z=loc;G='47_FestivalLight'
    # Paper lantern: fluted octagonal profile with raised bamboo ribs.
    points=[(0,0,-1.25),(.72,0,-1.0),(1,0,-.5),(1,0,.55),(.7,0,1),(0,0,1.2)]
    n=12;verts=[]
    for r,_,zz in points[1:-1]:
        for i in range(n):verts.append((x+r*scale*cos(i*2*pi/n),y+r*scale*sin(i*2*pi/n),z+zz*scale))
    faces=[]
    for j in range(3):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    mesh(name+' paper shade',verts,faces,'goldGlow',G)
    for dz in (-1.03,1.02):cylinder(name+' bamboo crown',(x,y,z+dz*scale),.74*scale,.14*scale,'wood',G,vertices=12)
    for i in range(0,n,2):
        a=2*pi*i/n
        tube(name+' shade rib',[(x+.72*scale*cos(a),y+.72*scale*sin(a),z-scale),(x+scale*cos(a),y+scale*sin(a),z-.5*scale),(x+scale*cos(a),y+scale*sin(a),z+.55*scale),(x+.7*scale*cos(a),y+.7*scale*sin(a),z+scale)],.022*scale,'red',G,4)
    tube(name+' tassel',[(x,y,z-1.1*scale),(x,y,z-1.8*scale)],[.06*scale,.01],'red',G,5)
def build():
    random.seed(8391)
    # Remove the bulky distant placeholder peaks; replace with distant misty islands.
    for ob in list(collection('82_Backdrop').objects):
        if 'Distant' in ob.name:
            bpy.data.objects.remove(ob,do_unlink=True)
    for x,y,z,s in [(-210,330,25,1),(180,390,45,.9),(-340,520,90,1.5)]:
        ico('Distant floating island',(x,y,z),(56*s,35*s,20*s),'stone','82_Backdrop',1)
        ico('Distant green plateau',(x,y,z+15*s),(51*s,30*s,4*s),'moss','82_Backdrop',2)
        for dx in (-12,0,16):pine('Far pines',x+dx*s,y,12*s) # Move foliage to backdrop below.
    for ob in list(collection('46_PineGardens').objects):
        if ob.name.startswith('Far'):
            for c in list(ob.users_collection):c.objects.unlink(ob)
            collection('82_Backdrop').objects.link(ob)
    for idx,(x,y,h) in enumerate([(-35,-47,14),(36,-50,13),(-18,-78,11),(20,-79,11),(-84,-6,15),(78,-26,13),(-27,64,12)]):
        pine('Sculpted pine '+str(idx),x,y,h)
        cylinder('Pine raised garden plinth',(x,y,1.6),5.6,.75,'stoneDark','46_PineGardens',vertices=32)
        cylinder('Pine moss mound',(x,y,2.05),5.2,.25,'moss','46_PineGardens',vertices=32)
        ring('Pine plinth coping',(x,y,2),5.7,5.15,.3,'stoneLight','46_PineGardens',segments=32)
        for j in range(8):
            a=random.uniform(0,2*pi);r=random.uniform(2.6,4.8)
            ob=ico('Garden basalt accent',(x+cos(a)*r,y+sin(a)*r,2.2),(random.uniform(.3,.7),random.uniform(.3,.7),random.uniform(.3,.8)),'rock','46_PineGardens',1)
    # Curved garden paths connect main boulevards to the quieter outer walk.
    connections=[((-11,-66),(-42,-68)),((11,-66),(44,-66)),((-77,-18),(-88,-28)),((-37,37),(-34,86)),((34,26),(48,48)),((72,-19),(91,-16))]
    for a,b in connections:
        path_strip('Garden link',a,b,4.6,'stone',1.3)
    # Festival canopy behind the champion, keeping the centre open.
    for idx,(a,b,z) in enumerate([((-46,34),(30,48),22),((-83,36),(-25,77),23),((37,43),(84,37),24),((-40,-61),(-13,-76),15),((14,-76),(40,-61),15)]):
        av=Vector(a);bv=Vector(b);pts=[]
        for j in range(13):
            t=j/12;p=av.lerp(bv,t);zz=z-3.5*sin(pi*t)
            pts.append((p.x,p.y,zz))
            if j%2 and j not in (0,12):lantern('Hanging festival lantern', (p.x,p.y,zz-1.3),.55 if idx<3 else .4)
        tube('Festival catenary',pts,.047,'wood','47_FestivalLight',sides=5)
        for p in (pts[0],pts[-1]):
            cylinder('Festival mast',(p[0],p[1],(p[2]+1.2)/2),.19,p[2]-1.2,'wood','47_FestivalLight',vertices=8)
            ico('Festival mast golden tip',(p[0],p[1],p[2]+.4),(.42,.42,.68),'gold','47_FestivalLight',1)
    for i in range(18):
        x=random.uniform(-100,100);y=random.uniform(55,140);z=random.uniform(35,70)
        lantern('Sky wish lantern',(x,y,z),random.uniform(.4,.8))
    # Intentionally scattered falling petals in the sakura court.
    for i in range(90):
        x=random.gauss(44,11);y=random.gauss(70,12);z=random.uniform(2.4,35)
        ob=ico('Sakura drifting petal',(x,y,z),(.13,.3,.035),'blossomLight','47_FestivalLight',1)
        ob.rotation_euler=(random.uniform(0,pi),random.uniform(0,pi),random.uniform(0,pi))
    # A quartet of ceremonial floating shards gives the champion its own identity.
    for i in range(4):
        a=pi*2*i/4+pi/4
        ico('Champion orbital crystal',(8.6*cos(a),8.6*sin(a),12+sin(a)*3),(.5,.5,2),'purpleGlow','21_StatueGlow',1)
    # Additional mood lights aim into the activity spaces.
    for loc,col in [((-63,12,8),(.52,.2,1)),((64,5,8),(.06,.65,1)),((0,68,8),(.55,.2,1)),((-59,59,6),(1,.45,.12)),((-59,-53,6),(1,.45,.12))]:
        point_light('District light pool',loc,col,650,4)
    s=bpy.context.scene
    bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.16,.24,.38,1);bg.inputs['Strength'].default_value=.4
    s.view_settings.exposure=.3
    # Fine procedural surface response for close shots; export retains portable base colors.
    for key in ('stone','stoneDark','stoneLight','wood','roof','rock'):
        mat=MATS[key];nodes=mat.node_tree.nodes;links=mat.node_tree.links
        bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
        tex=nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=22 if key!='wood' else 12
        tex.inputs['Detail'].default_value=2
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.08
        links.new(tex.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    # Make arrival crest face the visitor with exact source alpha.
    mat=bpy.data.materials.get('ACU_Logo_Texture')
    if mat:
        nodes=mat.node_tree.nodes;links=mat.node_tree.links
        tex=next(n for n in nodes if n.type=='TEX_IMAGE')
        out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
        bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
        trans=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader')
        links.new(tex.outputs['Alpha'],mix.inputs[0]);links.new(trans.outputs[0],mix.inputs[1]);links.new(bs.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
    s.camera=bpy.data.objects['CAM_01_Citadel']
    s.camera.location=(150,-214,137);s.camera.rotation_euler=(Vector((0,10,8))-s.camera.location).to_track_quat('-Z','Y').to_euler()
    s.camera.data.lens=45

