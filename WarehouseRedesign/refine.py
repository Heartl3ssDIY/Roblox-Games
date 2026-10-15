def patch(vertices,faces,xa,xb,ya,yb,offset=0,thickness=.3):
    n=len(vertices); za,zb=roof_z(xa)+offset,roof_z(xb)+offset
    vertices.extend([(xa,ya,za),(xb,ya,zb),(xb,yb,zb),(xa,yb,za),(xa,ya,za-thickness),(xb,ya,zb-thickness),(xb,yb,zb-thickness),(xa,yb,za-thickness)])
    faces.extend([tuple(n+i for i in f) for f in [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]])

for side, xa, xb, cx in [('West',-56,0,-27),('East',0,56,27)]:
    for j in (1,4):
        ya=-46+j*92/6; yb=ya+92/6-.04; cy=(ya+yb)/2
        name='Roof_%s_%02d'%(side,j+1)
        ob=bpy.data.objects[name]
        verts=[]; faces=[]
        for rect in [(xa,cx-7,ya,yb),(cx+7,xb,ya,yb),(cx-7,cx+7,ya,cy-4),(cx-7,cx+7,cy+4,yb)]: patch(verts,faces,*rect)
        old=ob.data; me=bpy.data.meshes.new(name+' SkylightCutout'); me.from_pydata(verts,[],faces); me.materials.append(old.materials[0]); me.update(); ob.data=me
        verts=[];faces=[];patch(verts,faces,cx-7,cx+7,cy-4,cy+4,.14,.12)
        mesh('Skylight_'+side+'_'+str(j),verts,faces,'Glass','Roof',bevel=.025)
        for xx in (cx-7,cx+7):
            beam('SkylightSide',(xx,cy-4.2,roof_z(xx)+.25),(xx,cy+4.2,roof_z(xx)+.25),.24,.3,'Pillar','Roof','Pillar')
        for yy in (cy-4,cy,cy+4):
            beam('SkylightRail',(cx-7.2,yy,roof_z(cx-7.2)+.25),(cx+7.2,yy,roof_z(cx+7.2)+.25),.24,.3,'Pillar','Roof','Pillar')
    for yy in range(-42,43,4):
        spans=[(xa,xb)]
        if 18.9<abs(yy)<27.1: spans=[(xa,cx-7.3),(cx+7.3,xb)]
        for x0,x1 in spans:
            beam('RoofSeamFine',(x0,yy,roof_z(x0)+.08),(x1,yy,roof_z(x1)+.08),.07,.12,'Roof','Roof','Roof')

box('OfficeHVACBase',(83,-6,13.1),(7.7,6.1,.3),'Pillar','Roof','Pillar')
box('OfficeHVAC',(83,-6,14.1),(7,5.5,1.8),'Metal','Roof',bevel=.15)
for i in range(6): box('OfficeHVACLouvre',(83,-8.81,13.5+i*.22),(5.8,.14,.08),'Rubber','Roof',bevel=.01)
cylinder('OfficeHVACFan',(83,-6,15.04),1.8,.1,'Rubber','Roof',sides=24)
for i in range(4):
    ob=box('OfficeHVACFanBlade',(83,-6,15.12),(3.2,.12,.06),'Metal','Roof',bevel=.01);ob.rotation_euler.z=i*math.pi/4

for ob in cols['Presentation'].objects:
    if ob.type=='LIGHT' and ob.name in ('Key','Fill','Rim'): ob.data.energy*=.24
next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.4
for ob in scene.objects:
    if ob.type=='MESH' and ob.get('Export') and ob.modifiers:
        for mod in ob.modifiers:
            if mod.type=='BEVEL': mod.segments=1
print('Roof openings, roof seams and lower-cost bevels finished')
