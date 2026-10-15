import bpy, bmesh, math, json, os, shutil
from mathutils import Vector, Matrix

ROOT=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns'
OUT=os.path.join(ROOT,'GiftParcelModels')
os.makedirs(OUT,exist_ok=True)
assert 'To be rich - Gift Parcels' not in bpy.data.scenes
shutil.copy2(bpy.data.filepath,os.path.join(OUT,'Before_GiftParcels.blend'))
scene=bpy.data.scenes.new('To be rich - Gift Parcels')
bpy.context.window.scene=scene
scene.unit_settings.scale_length=1
materials={}
def mat(name,rgb,rough=.8):
    m=bpy.data.materials.new('Gift_'+name);m.use_nodes=True
    c=tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
    m.diffuse_color=(*c,1);m['RGB']=rgb
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*c,1)
    n.inputs['Roughness'].default_value=rough
    n.inputs['Specular IOR Level'].default_value=.15
    materials[name]=m
    return m
palette={'Rose':(218,65,87),'Sky':(64,169,222),'Violet':(124,81,185),'Mint':(70,171,133),'Amber':(231,156,50),'Coral':(230,104,141)}
for name,rgb in palette.items():
    mat(name,rgb)
    mat(name+'Lid',tuple(min(255,int(v*.92+23)) for v in rgb))
    mat(name+'Ink',tuple(min(255,int(v*.65+89)) for v in rgb))
mat('Cream',(248,230,183),.63)
mat('Ivory',(245,243,229),.7)
mat('Gold',(226,176,72),.57)
mat('Navy',(42,61,86),.7)
mat('Tag',(246,235,210))
mat('Ground',(38,48,62))
src=open(os.path.join(ROOT,'LaptopModels','build_laptops.py'),encoding='utf-8').read()
exec(src[src.index('class Meshes:'):src.index('\nmodels=[]')])

def star(cx,cy,r):
    return [(cx+math.cos(math.pi/2+i*math.pi/5)*r*(1 if i%2==0 else .43),cy+math.sin(math.pi/2+i*math.pi/5)*r*(1 if i%2==0 else .43)) for i in range(10)]

def bow(a,material,z,scale=1):
    for side in (-1,1):
        vs=[];faces=[];count=24
        transform=Matrix.Rotation(math.radians(side*12),4,'Z')
        for i in range(count):
            t=2*math.pi*i/count
            p=Vector((side*(.235+.255*math.cos(t))*scale,0,z+(.16+.145*math.sin(t))*scale))
            outward=Vector((side*math.cos(t),0,math.sin(t))).normalized()*.007
            for y,sign in [(-.085,-1),(.085,-1),(.085,1),(-.085,1)]:
                vs.append(transform@(p+Vector((0,y*scale,0))+outward*sign))
        for i in range(count):
            for j in range(4):faces.append((i*4+j,i*4+(j+1)%4,((i+1)%count)*4+(j+1)%4,((i+1)%count)*4+j))
        a.add('Bow',material,vs,faces)
    a.box('Knot',material,(0,0,z+.09*scale),(.19*scale,.23*scale,.18*scale))

models=[]
configs=[('Rose',1.5,1.35,1.35,'Cream',-2.8,-1.65),('Sky',1.85,1.3,.80,'Ivory',0,-1.65),('Violet',1.12,1.12,1.8,'Gold',2.8,-1.65),('Mint',1.5,1.5,1.02,'Ivory',-2.8,1.65),('Amber',1.95,.96,1.03,'Navy',0,1.65),('Coral',1.3,1.3,1.2,'Cream',2.8,1.65)]
for index,(name,w,d,h,ribbon,x,y) in enumerate(configs):
    col=bpy.data.collections.new('Gift_'+name);scene.collection.children.link(col)
    a=Meshes(col,'Gift'+name,0);a.offset=Vector((x,y,0))
    lid=.10;bw=min(w,d)*.15;top=h+.003
    if name=='Mint':
        a.circle('Body',name,0,0,w/2,0,h-lid-.005,n=32)
        a.circle('Lid',name+'Lid',0,0,w/2+.012,h-lid,h,n=32)
        n=64;vs=[];fs=[]
        for z,r in [(h*.37,w/2+.002),(h*.37,w/2+.008),(h*.58,w/2+.008),(h*.58,w/2+.002)]:
            vs.extend([(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for i in range(n)])
        for j in range(4):
            for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
        a.add('Ribbon',ribbon,vs,fs)
        for angle in range(0,360,30):
            rad=math.radians(angle)
            tr=Matrix.Rotation(rad,4,'Z')@Matrix.Translation((0,-w/2-.001,0))@Matrix.Rotation(math.pi/2,4,'X')
            for zz in (.19,.76):a.circle('Print',name+'Ink',0,zz,.035,.001,.003,tr,n=8)
    else:
        a.box('Body',name,(0,0,(h-lid-.005)/2),(w,d,h-lid-.005))
        a.box('Lid',name+'Lid',(0,0,h-lid/2),(w+.024,d+.024,lid))
        for side in (-1,1):
            a.box('Ribbon',ribbon,(0,side*(d/2+.003),h*.44),(bw,.006,h*.88))
            a.box('Ribbon',ribbon,(side*(w/2+.003),0,h*.44),(.006,bw,h*.88))
            a.box('LidRibbon',ribbon,(0,side*(d/2+.015),h-lid/2),(bw,.006,lid))
            a.box('LidRibbon',ribbon,(side*(w/2+.015),0,h-lid/2),(.006,bw,lid))
        for side in (-1,1):
            front=Matrix.Rotation(0 if side==-1 else math.pi,4,'Z')@Matrix.Translation((0,-d/2-.001,0))@Matrix.Rotation(math.pi/2,4,'X')
            for px in (-w*.33,w*.33):
                for zz in (h*.23,h*.57):
                    if name in ('Rose','Violet'):a.prism('Print',name+'Ink',star(px,zz,.07),.001,.003,front)
                    elif name=='Sky':a.circle('Print',name+'Ink',px,zz,.042,.001,.003,front,n=10)
                    elif name=='Amber':a.prism('Print',name+'Ink',[(px-.04,zz-.06),(px+.035,zz-.015),(px+.04,zz+.06),(px-.035,zz+.015)],.001,.003,front)
                    else:a.prism('Print',name+'Ink',[(px,zz-.055),(px+.045,zz),(px,zz+.055),(px-.045,zz)],.001,.003,front)
    a.box('LidRibbon',ribbon,(0,0,top),(bw,d+.02,.006))
    a.box('LidRibbon',ribbon,(0,0,top+.006),(w+.02,bw,.006))
    # Two short notched ribbon ends sit on the lid beneath the bow.
    tail=[(-.085,-.02),(.085,-.02),(.11,-.42),(0,-.35),(-.11,-.42)]
    a.prism('Tails',ribbon,list(reversed(tail)),h+.013,h+.027)
    a.prism('Tails',ribbon,list(reversed(tail)),h+.013,h+.027,Matrix.Rotation(math.radians(140),4,'Z'))
    bow(a,ribbon,h+.023,min(1,w/1.5))
    tagtr=Matrix.Translation((w*.24,-d*.24,h+.004))@Matrix.Rotation(math.radians(-18),4,'Z')
    tag=[(-.13,-.16),(.13,-.16),(.13,.105),(0,.17),(-.13,.105)]
    a.prism('Tag','Tag',tag,0,.009,tagtr)
    a.prism('TagInk',name,star(0,-.025,.062),.010,.012,tagtr)
    objects=a.finish()
    for ob in objects:
        ob['GiftPart']=ob.pop('LaptopPart');ob['GiftVariant']=name
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
        assert len(ob.name)<50
    models.append({'name':name,'model':'Gift_'+name,'objects':objects,'offset':[x,y,0],'size':[w,h,d],'ribbon':ribbon})
bpy.app.driver_namespace['gift_models']=models
stage=bpy.data.collections.new('Gift Presentation');scene.collection.children.link(stage)
me=bpy.data.meshes.new('GiftGround');me.from_pydata([(-100,-100,-.016),(100,-100,-.016),(100,100,-.016),(-100,100,-.016)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('GiftGround',me);stage.objects.link(ob);me.materials.append(materials['Ground'])
world=bpy.data.worlds.new('GiftWorld');world.use_nodes=True
n=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');n.inputs[0].default_value=(.21,.25,.32,1);n.inputs[1].default_value=.45;scene.world=world
for name,pos,power,size in [('Key',(-4,-5,9),1400,7),('Fill',(6,-2,6),850,5),('Rim',(1,5,8),1100,5)]:
    ld=bpy.data.lights.new('Gift_'+name,'AREA');ld.energy=power;ld.size=size
    ob=bpy.data.objects.new('Gift_'+name,ld);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('GiftCamera');ob=bpy.data.objects.new('GiftCamera',cam);stage.objects.link(ob)
ob.location=(6.5,-14,12);ob.rotation_euler=(Vector((0,0,.65))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=11.8;scene.camera=ob
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1500;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.render.filepath=os.path.join(OUT,'Gift_Parcels_Preview.png')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.region_3d.view_rotation=ob.rotation_euler.to_quaternion();sp.region_3d.view_location=(0,0,.65);sp.region_3d.view_distance=12;area.tag_redraw()
bpy.context.view_layer.update()
print(json.dumps({'scene':scene.name,'models':[{'name':m['name'],'parts':len(m['objects']),'triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in m['objects'])} for m in models]}))
