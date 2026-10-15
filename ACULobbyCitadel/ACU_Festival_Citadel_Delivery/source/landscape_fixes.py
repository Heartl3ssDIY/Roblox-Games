from common import *


BUILDING_MOVES = {
    '50_City_AcademyResidenceA': ((-211,120),(-110,112)),
    '50_City_WesternWard7': ((-252,66),(-264,-180)),
    '50_City_WesternWard8': ((-252,102),(-239,-209)),
    '50_City_WesternWard11': ((-212,-119),(-282,-101)),
    '50_City_WesternWard12': ((-212,-83),(-282,-65)),
}


def _group(name):
    c=bpy.data.collections.get('ACU | '+name)
    assert c is not None, 'Missing landscape integration collection: '+name
    return c


def _shift_objects(objects, offset):
    mat=Matrix.Translation(Vector(offset))
    for ob in list(objects): ob.matrix_world=mat @ ob.matrix_world


def _prefix_objects(prefix):
    return [ob for ob in bpy.data.objects if ob.name==prefix or ob.name.startswith(prefix+'_')]


def _shift_prefix(prefix, offset):
    objects=_prefix_objects(prefix)
    assert objects, 'Missing landscape integration assembly: '+prefix
    _shift_objects(objects, offset)


def _rect_for_collection(c):
    points=[]
    for ob in c.objects:
        if ob.type!='MESH': continue
        points.extend([ob.matrix_world @ Vector(p) for p in ob.bound_box])
    if not points:return None
    return (min(p.x for p in points),max(p.x for p in points),min(p.y for p in points),max(p.y for p in points))


def _building_rects():
    rects=[]
    for c in bpy.data.collections:
        name=c.name.replace('ACU | ','')
        keep=(name.startswith(('50_City_','36_Backdrop_')) or name in (
            '51_Academy_GrandDojo','51_Academy_WestScrollWing','51_Academy_EastScrollWing',
            '51_Academy_SouthGate','52_CelestialPagoda','52_CelestialPagoda_Tower',
            '53_NorthFortressGate','30_StoryGate','31_SummonHall','32_RankedHall','33_Champions','34_Shop'))
        if keep:
            rect=_rect_for_collection(c)
            if rect:rects.append((name,rect))
    return rects


def _segment_distance(p,a,b):
    px,py=p;ax,ay=a;bx,by=b
    dx,dy=bx-ax,by-ay
    t=max(0,min(1,((px-ax)*dx+(py-ay)*dy)/max(dx*dx+dy*dy,.001)))
    return ((px-ax-t*dx)**2+(py-ay-t*dy)**2)**.5


def _routes():
    lines=[]
    def route(points,width,label):
        for a,b in zip(points,points[1:]):lines.append((a,b,width,label))
    from city_fixes import ROAD_POLYLINES
    for label,points,width in ROAD_POLYLINES:route(points,width,label)
    route([(155,-226),(155,-69)],30,'Merchant paved street')
    route([(177,-9),(190,0),(196,18),(201,35),(215,44),(219,60),(216,79),(204,95),(192,103)],6.5,'Woodland footpath')
    oval=[(-172+40*cos(i*2*pi/80),-112+31.2*sin(i*2*pi/80)) for i in range(81)]
    route(oval,5.1,'Lotus garden promenade')
    return lines


def _ellipse_contains(p,center,radii,padding=0):
    return ((p[0]-center[0])/(radii[0]+padding))**2+((p[1]-center[1])/(radii[1]+padding))**2<1


def _tree_assemblies():
    valid=('Hero_Sakura','Garden_Sakura_','WestMoonLake_Grove_','Waterfall_AncientPine_','Waterfall_HangingSakura','EasternForest_Cedar_','EasternForest_FloweringTree_','RimForest_')
    found=[]
    for ob in bpy.data.objects:
        if ob.type!='MESH' or not ob.name.startswith(valid):continue
        name=ob.name.split('.')[0]
        if name.endswith('_OldTwistedTrunk'):suffix='_OldTwistedTrunk';sides=10
        elif name.endswith('_SculptedTrunk'):suffix='_SculptedTrunk';sides=10 if name.startswith('Hero_') else 8
        elif name.endswith('_Trunk'):suffix='_Trunk';sides=8
        else:continue
        prefix=name[:-len(suffix)]
        points=[ob.matrix_world @ v.co for v in list(ob.data.vertices)[:sides]]
        p=sum(points,Vector((0,0,0)))/len(points)
        found.append({'prefix':prefix,'point':p})
    return sorted(found,key=lambda item:item['prefix'])


def _clear_tree_routes():
    bpy.context.view_layer.update()
    rectangles=_building_rects();roads=_routes();trees=_tree_assemblies()
    def obstacle(p,extra=3.3):
        xy=(p.x,p.y)
        angle=math.degrees(math.atan2(p.y,p.x))%360
        if not 155<=angle<=181 and 124-extra < (p.x*p.x+p.y*p.y)**.5 < 135+extra:return 'Circular boulevard'
        for a,b,width,label in roads:
            if _segment_distance(xy,a,b)<width/2+extra:return label
        for name,(x0,x1,y0,y1) in rectangles:
            if x0-extra<p.x<x1+extra and y0-extra<p.y<y1+extra:return name
        for center,radii,label in [((-172,-112),(35,26.5),'Lotus lake'),((-60,-54),(23.1,16.2),'Inner moon pond')]:
            if _ellipse_contains(xy,center,radii,1):return label
        return None
    def candidate_ok(p,current_index):
        if (abs(p.x)/290)**4+(abs(p.y)/290)**4>.93:return False
        if p.x*p.x+p.y*p.y<118*118:return False
        # The ravine has several elevations; new ground-level trees stay off its geology.
        if -299<p.x<-181 and 38<p.y<185:return False
        if obstacle(p,4.3):return False
        for i,item in enumerate(trees):
            if i==current_index:continue
            other=item['point']
            if (p.x-other.x)**2+(p.y-other.y)**2<12.5**2:return False
        return True
    moved=[]
    for index,item in enumerate(trees):
        p=item['point'];prefix=item['prefix']
        # Ravine specimens have authored elevated planting positions, fixed below.
        if p.z>6 or prefix.startswith('Waterfall_'):continue
        reason=obstacle(p)
        if not reason:continue
        chosen=None
        phase=(sum(ord(c) for c in prefix)%31)*2*pi/31
        for radius in (14,22,32,44,58,74,94,116,142):
            options=[]
            for j in range(32):
                a=phase+j*2*pi/32
                candidate=Vector((p.x+radius*cos(a),p.y+radius*sin(a),p.z))
                if candidate_ok(candidate,index):options.append(candidate)
            if options:
                # Favor outer garden pockets over the civic centre.
                chosen=min(options,key=lambda q:abs((q.x*q.x+q.y*q.y)**.5-215))
                break
        assert chosen is not None, 'No clear planting pocket for '+prefix
        delta=chosen-p
        _shift_prefix(prefix,delta)
        item['point']=chosen
        moved.append({'tree':prefix,'from':[round(p.x,2),round(p.y,2)],'to':[round(chosen.x,2),round(chosen.y,2)],'cleared':reason})
    bpy.context.view_layer.update()
    unresolved=[]
    for item in trees:
        if item['point'].z>6 or item['prefix'].startswith('Waterfall_'):continue
        reason=obstacle(item['point'])
        if reason:unresolved.append((item['prefix'],reason))
    assert not unresolved, 'Landscape tree clearance remains unresolved: '+str(unresolved)
    return moved


def build():
    if bpy.context.scene.get('ACU_LandscapeFixesApplied',False):return {'already_applied':True}
    for name,(old,new) in BUILDING_MOVES.items():
        _shift_objects(_group(name).objects,(new[0]-old[0],new[1]-old[1],0))
    _shift_objects(_group('61_WaterfallRavine').objects,(-50,0,0))
    for name in ('Waterfall_RiverBridge_WalkSurface','SECRET_WaterfallVista','NPC_WaterfallWanderer'):
        ob=bpy.data.objects.get(name)
        if ob is not None:_shift_objects([ob],(-50,0,0))
    # The scenic bridge originally ended in the water; widen the whole authored assembly.
    centre=Vector((-272,79,0))
    stretch=Matrix.Translation(centre) @ Matrix.Diagonal((1.6,1,1,1)) @ Matrix.Translation(-centre)
    for ob in _prefix_objects('Waterfall_RiverBridge'):ob.matrix_world=stretch @ ob.matrix_world
    _shift_prefix('Waterfall_AncientPine_05',(-11,26,0))
    _shift_prefix('Waterfall_AncientPine_06',(-9,-14,0))
    _shift_prefix('Waterfall_TerraceFern_01',(-12,-20,0))
    guide=bpy.data.objects.get('NPC_WaterfallWanderer')
    if guide is not None:guide.location=(-260,47,2)
    _shift_prefix('WestMoonLake_Bamboo_02',(21,-10,0))
    marker_ob=bpy.data.objects.get('OuterGardenFastTravel')
    if marker_ob is not None:marker_ob.location=(-135,-127,2.8)
    bpy.context.view_layer.update()
    moved_trees=_clear_tree_routes()
    bpy.context.scene['ACU_LandscapeFixesApplied']=True
    return {'ravine_shift':[-50,0,0],'moved_buildings':list(BUILDING_MOVES),'relocated_trees':moved_trees,'waterfall_camera':[-300,80,43],'waterfall_camera_target':[-235,141,28]}
