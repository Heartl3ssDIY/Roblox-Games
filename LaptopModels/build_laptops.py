import bpy, math, json, os
from mathutils import Vector, Matrix

OUT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\LaptopModels'
SCENE='To be rich - Laptops'
assert SCENE not in bpy.data.scenes, 'Laptop scene already exists'
scene=bpy.data.scenes.new(SCENE)
bpy.context.window.scene=scene
scene.unit_settings.scale_length=1
materials={}
def mat(name,rgb):
    m=bpy.data.materials.new('Laptop_'+name)
    m.use_nodes=True
    c=tuple((v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in rgb)
    m.diffuse_color=(*c,1)
    node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=(*c,1)
    node.inputs['Roughness'].default_value=.78
    node.inputs['Metallic'].default_value=0
    node.inputs['Specular IOR Level'].default_value=.16
    m['RGB']=rgb
    materials[name]=m
    return m
for name,rgb in {'DellBody':(47,51,57),'DellDeck':(62,66,72),'HPBody':(155,165,175),'HPDeck':(185,194,201),'MacBody':(190,194,199),'MacDeck':(211,215,220),'Black':(8,10,13),'Screen':(0,0,0),'Keys':(29,31,35),'Legends':(204,208,214),'Dark':(62,66,73),'Silver':(186,193,203),'Blue':(37,125,207),'Rubber':(29,30,32)}.items():mat(name,rgb)

class Meshes:
    def __init__(self,col,prefix,offset):
        self.col=col;self.prefix=prefix;self.offset=Vector((offset,0,0));self.groups={}
    def add(self,name,material,verts,faces,transform=None):
        key=(name,material)
        vs,fs=self.groups.setdefault(key,([],[]));start=len(vs)
        vs.extend([(transform@Vector(v) if transform else Vector(v))+self.offset for v in verts])
        fs.extend([tuple(start+i for i in face) for face in faces])
    def box(self,name,material,loc,size,transform=None):
        x,y,z=loc;a,b,c=[v/2 for v in size]
        vs=[(x+i*a,y+j*b,z+k*c) for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.add(name,material,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],transform)
    def prism(self,name,material,poly,z0,z1,transform=None):
        n=len(poly);vs=[(x,y,z) for z in (z0,z1) for x,y in poly]
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(name,material,vs,fs,transform)
    def rounded(self,name,material,x,y,w,d,z0,z1,r=.04,transform=None):
        poly=[]
        for cx,cy,ang in [(x+w/2-r,y+d/2-r,0),(x-w/2+r,y+d/2-r,90),(x-w/2+r,y-d/2+r,180),(x+w/2-r,y-d/2+r,270)]:
            for k in range(4):
                t=math.radians(ang+k*30);poly.append((cx+r*math.cos(t),cy+r*math.sin(t)))
        self.prism(name,material,poly,z0,z1,transform)
    def circle(self,name,material,x,y,r,z0,z1,transform=None,n=16):
        self.prism(name,material,[(x+r*math.cos(i*2*math.pi/n),y+r*math.sin(i*2*math.pi/n)) for i in range(n)],z0,z1,transform)
    def ring(self,name,material,x,y,r,t,z,transform=None,n=32):
        vs=[]
        for rad in (r,r-t):vs.extend([(x+rad*math.cos(i*2*math.pi/n),y+rad*math.sin(i*2*math.pi/n),z) for i in range(n)])
        self.add(name,material,vs,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],transform)
    def text(self,name,material,text,x,y,z,size,transform=None):
        cu=bpy.data.curves.new('glyph','FONT');cu.body=text;cu.size=size;cu.align_x='CENTER';cu.align_y='CENTER';cu.resolution_u=2
        ob=bpy.data.objects.new('glyph',cu);self.col.objects.link(ob)
        dg=bpy.context.evaluated_depsgraph_get();me=bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        self.add(name,material,[(v.co.x+x,v.co.y+y,v.co.z+z) for v in me.vertices],[tuple(f.vertices) for f in me.polygons],transform)
        bpy.data.meshes.remove(me);bpy.data.objects.remove(ob,do_unlink=True);bpy.data.curves.remove(cu)
    def finish(self):
        result=[]
        for (name,material),(vs,fs) in self.groups.items():
            me=bpy.data.meshes.new(self.prefix+'_'+name);me.from_pydata(vs,[],fs);me.update()
            ob=bpy.data.objects.new(self.prefix+'_'+name,me);self.col.objects.link(ob);me.materials.append(materials[material])
            ob['LaptopPart']=name;ob['RGB']=materials[material]['RGB'];ob['Export']=True
            result.append(ob)
        return result

models=[]
configs=[('Dell','Laptop1',-3.85,3.2,2.1,.20,1.88,1.0),('HP','Laptop2',0,3.15,2.05,.17,1.85,1.4),('MacBook','Laptop3',3.85,3.3,2.13,.13,1.95,.5)]
for brand,tier,offset,w,d,top,h,factor in configs:
    col=bpy.data.collections.new('Laptop_'+brand);scene.collection.children.link(col)
    a=Meshes(col,brand,offset);body=brand+'Body' if brand!='MacBook' else 'MacBody';deck=brand+'Deck' if brand!='MacBook' else 'MacDeck'
    a.rounded('Body',body,0,0,w,d,.035,top-.015,.05 if brand=='Dell' else .075)
    a.rounded('Deck',deck,0,0,w-.025,d-.025,top-.015,top,.045 if brand=='Dell' else .065)
    for x in (-w*.38,w*.38):
        for y in (-d*.37,d*.37):a.rounded('Feet','Rubber',x,y,.30,.14,0,.035,.025)
    kw=w-.32 if brand!='MacBook' else w-.66
    ky=.24;kd=.98
    a.rounded('KeyboardWell','Black',0,ky,kw+.055,kd+.055,top+.0005,top+.006,.025)
    rows=[(['esc']+['F'+str(i) for i in range(1,13)]+['pwr'],[1]*14,.092),
          (['`','1','2','3','4','5','6','7','8','9','0','-','=','del'],[1]*13+[1.35],.148),
          (['tab','Q','W','E','R','T','Y','U','I','O','P','[',']','\\'],[1.3]+[1]*13,.148),
          (['caps','A','S','D','F','G','H','J','K','L',';','\'','enter'],[1.55]+[1]*11+[1.55],.148),
          (['shift','Z','X','C','V','B','N','M',',','.','/','shift'],[1.9]+[1]*10+[1.9],.148),
          (['ctrl','fn','alt','cmd' if brand=='MacBook' else 'win','','alt','<','v','>'],[1.1,1,1,1.1,5.15,1.1,1,1,1],.148)]
    y=ky+kd/2-.064
    for ri,(labels,units,kh) in enumerate(rows):
        gap=.025;unit=(kw-gap*(len(units)-1))/sum(units);x=-kw/2
        for label,u in zip(labels,units):
            wid=unit*u;cx=x+wid/2
            a.box('Keycaps','Keys',(cx,y,top+.023),(wid,kh,.034))
            if label:a.text('KeyLegends','Legends',label,cx,y,top+.0405,.043 if len(label)>1 else .075)
            x+=wid+gap
        y-=kh/2+(rows[ri+1][2]/2 if ri<len(rows)-1 else 0)+.022
    tw=1.18 if brand=='Dell' else (1.28 if brand=='HP' else 1.53);td=.44 if brand=='Dell' else .52;ty=-.66
    a.rounded('TrackpadSeam','Black' if brand=='Dell' else 'Dark',0,ty,tw+.027,td+.027,top+.0006,top+.002,.022)
    a.rounded('Trackpad',deck,0,ty,tw,td,top+.002,top+.004,.018)
    if brand=='Dell':
        a.box('TrackpadSeam','Dark',(0,ty-.13,top+.0045),(tw-.03,.009,.001))
        a.box('TrackpadSeam','Dark',(0,ty-.18,top+.0045),(.009,.095,.001))
    if brand=='MacBook':
        for x in (-w/2+.17,w/2-.17):
            for j in range(25):
                a.box('SpeakerGrilles','Dark',(x,-.18+j*.035,top+.001),(.16,.009,.002))
    else:
        for j in range(42):
            x=-w*.36+j*(w*.72/41)
            a.box('SpeakerGrilles','Black',(x,.86,top+.001),(.012,.071,.002))
    # Ports are deliberately shallow, readable dark openings with visible contacts.
    for side in (-1,1):
        ys=[-.18,.20,.59] if brand!='MacBook' else [.36,.61]
        for j,py in enumerate(ys):
            pw=.22 if brand!='MacBook' and j<2 else .13;ph=.060 if pw>.2 else .035
            a.box('Ports','Black',(side*(w/2+.001),py,(top+.035)/2),(.003,pw,ph))
            a.box('PortContacts','Silver',(side*(w/2+.003),py,(top+.035)/2),(.002,pw*.7,.012))
        for j in range(7):a.box('CoolingVents','Black',(side*(w/2+.001),-.71+j*.038,(top+.035)/2),(.002,.015,.045 if brand!='MacBook' else .027))
    for x in (-w*.33,w*.33):
        a.rounded('Hinges','Dark',x,d/2-.115,.40,.145,top-.025,top+.095,.03)
    hinge=Matrix.Translation(Vector((0,d/2-.095,top+.018)))@Matrix.Rotation(math.radians(76),4,'X')
    thick=.074 if brand=='Dell' else (.060 if brand=='HP' else .045)
    a.rounded('Lid',body,0,h/2,w,h,-thick/2,thick/2,.055,hinge)
    a.rounded('Bezel','Black',0,h/2,w-.055,h-.055,thick/2,thick/2+.008,.035,hinge)
    lower=.18 if brand!='MacBook' else .10
    screen_bottom=lower;screen_top=h-.115
    a.box('Screen','Screen',(0,(screen_bottom+screen_top)/2,thick/2+.0095),(w-.19,screen_top-screen_bottom,.003),hinge)
    if brand=='MacBook':a.box('CameraHousing','Black',(0,h-.145,thick/2+.012),(.30,.07,.003),hinge)
    a.circle('Webcam','Dark',0,h-.071,.025,thick/2+.009,thick/2+.012,hinge)
    a.circle('WebcamLens','Black',0,h-.071,.012,thick/2+.012,thick/2+.014,hinge)
    a.circle('WebcamLens','Dark',.075,h-.071,.006,thick/2+.009,thick/2+.011,hinge,n=8)
    if brand!='MacBook':a.text('FrontBrand','Silver','DELL' if brand=='Dell' else 'hp',0,.083,thick/2+.009,.089,hinge)
    back=hinge@Matrix.Diagonal(Vector((-1,1,-1,1)))
    if brand=='Dell':
        a.ring('LidLogo','Silver',0,h*.54,.28,.014,thick/2+.002,back)
        a.text('LidLogo','Silver','DELL',0,h*.54,thick/2+.002,.18,back)
        a.rounded('Badge','Blue',-w*.37,-.69,.17,.19,top+.001,top+.003,.008)
        a.text('BadgeLegend','Legends','i5',-w*.37,-.69,top+.0035,.083)
    elif brand=='HP':
        a.ring('LidLogo','Silver',0,h*.54,.26,.011,thick/2+.002,back)
        a.text('LidLogo','Silver','hp',0,h*.54,thick/2+.002,.36,back)
    else:
        # Small polygon silhouette with a bitten right edge and a separate leaf.
        shape=[(-.01,-.17),(-.085,-.205),(-.145,-.19),(-.21,-.10),(-.25,.035),(-.235,.14),(-.18,.195),(-.10,.22),(-.015,.185),(.06,.218),(.145,.206),(.205,.16),(.15,.125),(.13,.065),(.15,.005),(.205,-.025),(.16,-.125),(.10,-.195),(.04,-.20)]
        a.prism('LidLogo','Dark',[(x,y+h*.54) for x,y in reversed(shape)],thick/2+.001,thick/2+.004,back)
        a.prism('LidLogo','Dark',[(.00,h*.54+.235),(.025,h*.54+.305),(.10,h*.54+.342),(.10,h*.54+.28),(.045,h*.54+.235)],thick/2+.001,thick/2+.004,back)
        a.box('OpeningNotch','Dark',(0,-d/2-.0005,top-.013),(.35,.003,.016))
    objects=a.finish()
    models.append({'brand':brand,'tier':tier,'offset':offset,'factor':factor,'objects':objects,'width':w})

bpy.app.driver_namespace['laptop_models']=models
world=bpy.data.worlds.new('LaptopStudioWorld');world.use_nodes=True
next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(.21,.25,.32,1)
next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[1].default_value=.45
scene.world=world
stage=bpy.data.collections.new('Laptop Presentation');scene.collection.children.link(stage)
groundmat=mat('Ground',(48,57,72))
me=bpy.data.meshes.new('Ground');me.from_pydata([(-200,-200,-.017),(200,-200,-.017),(200,200,-.017),(-200,200,-.017)],[],[(0,1,2,3)])
ground=bpy.data.objects.new('LaptopGround',me);stage.objects.link(ground);me.materials.append(groundmat)
for name,pos,power,size in [('Key',(-4,-5,9),1600,7),('Fill',(5,-2,6),900,5),('Rim',(1,5,8),1300,5)]:
    ld=bpy.data.lights.new('Laptop_'+name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
    ob=bpy.data.objects.new('Laptop_'+name,ld);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,.7))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('LaptopCamera');ob=bpy.data.objects.new('LaptopCamera',cam);stage.objects.link(ob)
ob.location=(7.8,-13.8,10.5);ob.rotation_euler=(Vector((0,.15,.6))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=13.1;scene.camera=ob
scene.render.resolution_x=1800;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.engine='CYCLES';scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.view_settings.view_transform='AgX'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.region_3d.view_distance=14
            area.spaces.active.region_3d.view_location=(0,0,.6)
            area.spaces.active.region_3d.view_rotation=ob.rotation_euler.to_quaternion()
            area.spaces.active.region_3d.view_perspective='PERSP'
            area.tag_redraw()
bpy.context.view_layer.update()
print(json.dumps({'scene':scene.name,'laptops':[{k:v for k,v in m.items() if k!='objects'}|{'parts':len(m['objects'])} for m in models]}))
