import bpy, os, json, math
from mathutils import Matrix, Vector

def parent_keep(ob, parent):
    world=ob.matrix_world.copy();ob.parent=parent;ob.matrix_world=world

def body(a,label,objects,kind='pickup',pivot=None,axis=None,angle=0):
    root=bpy.data.objects[a['root']];col=bpy.data.collections[a['collection']]
    ob=bpy.data.objects.new(label,None);col.objects.link(ob)
    ob.parent=root;ob.location=pivot or (0,0,0)
    bpy.context.view_layer.update()
    for part in objects:parent_keep(part,ob)
    ob['interaction']=kind;ob['display_name']=label
    if axis:ob['hinge_axis']=axis;ob['open_angle']=angle
    return ob

for m in bpy.data.materials:
    m.name=m.name.replace('Wren','School')
for a in ASSETS:
    col=bpy.data.collections[a['collection']];col.name=col.name.replace('Wren','School');a['collection']=col.name
    root=bpy.data.objects[a['root']]
    root['interaction']='static';root['display_name']=a['name']
    if a['category'] in ['01 Stationery','07 Staffroom'] or a['name'] in ['Piano bench','Desktop monitor']:
        root['interaction']='pickup'
    objs=[o for o in col.all_objects if o.parent==root and o.type!='EMPTY']
    name=a['name']
    if name in ['Round graphite pencil pot','Square ivory pen pot']:
        for o in col.all_objects:
            if o.type=='EMPTY' and o!=root:
                o['interaction']='pickup';o['display_name']='Pencil' if 'Pencil' in o.name else 'Pen'
    if name=='Whiteboard marker and eraser':
        root['interaction']='container'
        body(a,'Whiteboard marker',[o for o in objs if 'Marker' in o.name])
        body(a,'Whiteboard eraser',[o for o in objs if 'Marker' not in o.name])
    if name=='Compact desktop keyboard and mouse':
        root['interaction']='container'
        body(a,'Keyboard',[o for o in objs if 'Mouse' not in o.name])
        body(a,'Mouse',[o for o in objs if 'Mouse' in o.name])
    if name=='Simple school laptop':
        root['display_name']='Laptop base'
        hinge=next(o for o in col.all_objects if o.type=='EMPTY' and o!=root)
        hinge['interaction']='hinge';hinge['display_name']='Laptop lid';hinge['hinge_axis']=[1,0,0];hinge['open_angle']=-100
        # Source is posed open; close once to establish a useful export rest pose.
        hinge.rotation_euler.x=math.pi/2
    if name in ['Tall double cupboard','Low staffroom cupboard']:
        if name.startswith('Tall'):
            h=next(o for o in col.all_objects if o.type=='EMPTY' and o!=root)
            h.rotation_euler.z=0;h['interaction']='hinge';h['display_name']='Right cupboard door';h['hinge_axis']=[0,0,1];h['open_angle']=100
            body(a,'Left cupboard door',[o for o in objs if any(t in o.name for t in ['Flat sand cabinet door','Slim vertical handle','Handle fixing'])], 'hinge',(-.451,-.266,.93),[0,0,1],-100)
        else:
            for x in [-.474,0,.474]:
                body(a,'Cupboard door '+str(x),[o for o in objs if any(t in o.name for t in ['Lower cabinet door','Horizontal pull']) and abs(o.location.x-x)<.02], 'hinge',(x-.23,-.266,.44),[0,0,1],-100)
    if name=='Classroom tray cupboard':
        for c in range(3):
            for r in range(4):
                x=(c-1)*.467;z=.145+r*.17
                parts=[o for o in objs if (o.name.startswith('Tray ') and not o.name.startswith(('Tray unit','Tray divider')) or o.name.startswith('Inset tray')) and abs(o.location.x-x)<.21 and z-.015<o.location.z<z+.11]
                assert len(parts)==7,(c,r,[o.name for o in parts])
                body(a,'Removable tray %d-%d'%(c+1,r+1),parts)
    if name=='Acoustic guitar and stand':
        body(a,'Acoustic guitar',[o for o in objs if not ('stand' in o.name.lower() or 'cradle' in o.name.lower())])
    if name=='Clarinet and stand':
        body(a,'Clarinet',[o for o in objs if not ('stand' in o.name.lower() or 'Clarinet support' in o.name)])
    if name=='Graphite electric kettle':
        root['interaction']='static';root['display_name']='Kettle power base'
        keep=['Power base','Detachable base cord','Kettle power plug','Plug contact','Base screw','Recessed hex socket']
        body(a,'Kettle',[o for o in objs if not any(o.name.startswith(t) for t in keep)])
    if name=='Cup and saucer':
        root['display_name']='Saucer'
        body(a,'Teacup',[o for o in objs if 'Saucer' not in o.name])
    if name=='mobile whiteboard':
        body(a,'Magnetic whiteboard eraser',[o for o in objs if o.name.startswith(('Magnetic eraser','Eraser grip rib'))])
        for o in [o for o in objs if o.name.startswith(('Board marker','Small board magnet'))]:body(a,o.name,[o])

bpy.context.view_layer.update()
BODYDATA=[]
def body_owner(o):
    p=o.parent
    while p and 'interaction' not in p:p=p.parent
    return p
for ai,a in enumerate(ASSETS,1):
    root=bpy.data.objects[a['root']];col=bpy.data.collections[a['collection']]
    parents=[root]+[o for o in col.all_objects if o.type=='EMPTY' and o!=root and 'interaction' in o]
    for bi,p in enumerate(parents,1):
        parts=[o for o in col.all_objects if o.type in ['MESH','CURVE','FONT'] and body_owner(o)==p]
        if not parts:continue
        uid='SA%02d_B%02d'%(ai,bi)
        p['body_id']=uid
        for o in parts:o['body_id']=uid
        BODYDATA.append({'id':uid,'asset_id':'SA%02d'%ai,'asset':a['name'],'label':p['display_name'],'kind':p['interaction'],'root':p.name,'asset_root':root.name,'parts':[o.name for o in parts],'pivot':list((root.matrix_world.inverted()@p.matrix_world).translation),'axis':list(p.get('hinge_axis',[0,0,1])),'angle':p.get('open_angle',0)})
scene['interaction_workflow']='Separate rigid prop bodies; movable erasers, pens, trays, cups and instruments. Door/lid pivots; Roblox setup supplied separately.'
open(os.path.join(BASE,'asset-manifest.json'),'w',encoding='utf-8').write(json.dumps(ASSETS,indent=2))
open(os.path.join(BASE,'interaction-manifest.json'),'w',encoding='utf-8').write(json.dumps(BODYDATA,indent=2))
print('Interactive bodies:',len(BODYDATA),'pickup:',sum(b['kind']=='pickup' for b in BODYDATA),'hinges:',sum(b['kind']=='hinge' for b in BODYDATA))
