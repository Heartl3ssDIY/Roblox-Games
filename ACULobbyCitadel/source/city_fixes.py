from common import *
from expansion import curbed_route
import bmesh

ROAD_POLYLINES = [
    ('Arrival boulevard',[(0,-280),(0,-110)],24),
    ('Citadel north road',[(0,104),(0,244)],20),
    ('Academy road',[(-98,31),(-113,0),(-134,-23),(-172,-23),(-172,-8)],16),
    ('Water garden walk',[(-81,-79),(-122,-124),(-137,-125)],14),
    ('Market avenue',[(90,-77),(110,-57),(155,-57),(155,-220)],18),
    ('Pagoda boulevard',[(95,81),(117,92),(140,98)],17),
    ('Eastern forest trail',[(108,10),(243,10)],12),
    ('Academy boulevard bypass',[(-116.4,56.8),(-112,56.8),(-112,0),(-129.5,0)],11),
]

def _remove_route_objects():
    prefixes=[name for name,points,width in ROAD_POLYLINES]
    prefixes.extend(['Avenue limestone joint','Avenue centre diamond'])
    for ob in list(bpy.data.objects):
        if any(ob.name.startswith(prefix) for prefix in prefixes):
            bpy.data.objects.remove(ob,do_unlink=True)

def _boulevard_clearance():
    for ob in list(bpy.data.objects):
        if ob.name.startswith('Boulevard cut stones'):
            a=math.degrees(math.atan2(ob.location.y,ob.location.x))%360
            if 155 <= a <= 181:
                bpy.data.objects.remove(ob,do_unlink=True)
        elif ob.type=='MESH' and (ob.name.startswith('Town inner circular boulevard') or ob.name.startswith('Boulevard chamfered curb')):
            bm=bmesh.new()
            bm.from_mesh(ob.data)
            remove=[]
            for f in bm.faces:
                p=ob.matrix_world@f.calc_center_median()
                a=math.degrees(math.atan2(p.y,p.x))%360
                if 155 <= a <= 181:
                    remove.append(f)
            if remove:
                bmesh.ops.delete(bm,geom=remove,context='FACES')
                loose=[e for e in bm.edges if not e.link_faces]
                if loose:bmesh.ops.delete(bm,geom=loose,context='EDGES')
                loose_v=[v for v in bm.verts if not v.link_faces]
                if loose_v:bmesh.ops.delete(bm,geom=loose_v,context='VERTS')
                bm.to_mesh(ob.data)
                ob.data.update()
            bm.free()

def _marker_positions():
    updates={
        'AcademyFastTravel':(-172,17,2),
        'MarketFastTravel':(155,-112,2),
        'ACCESS_AcademyUpperGallery':(-192,49,1.2),
        'ACCESS_PagodaUpperGallery':(167.2,121,8),
    }
    for name,loc in updates.items():
        ob=bpy.data.objects.get(name)
        if ob:ob.location=loc

def _upper_access():
    g='55_CityAccessFixes'
    for ob in list(bpy.data.objects):
        if ob.name.startswith('FIX_Architecture_'):
            bpy.data.objects.remove(ob,do_unlink=True)
    for ob in list(bpy.data.objects):
        if ob.name.startswith('AcademyGalleryStairs_'):
            ob.location.y=-6.0
        elif ob.name.startswith('AcademyGalleryUpperLanding'):
            ob.location.y=71.5
            ob.scale.y=8.5/4.3
        elif ob.name.startswith('AcademyGalleryStairHandrail'):
            ob.location.y=-6.0
        elif ob.name.startswith('PagodaSecondFloorStair_'):
            ob.location.x=4.7
        elif ob.name.startswith('PagodaSecondFloorOuterHandrail'):
            ob.location.x=4.7
        elif ob.name.startswith('PagodaSecondFloorLanding'):
            ob.location.x=167.2
            ob.scale.x=6.8/11.0
        elif ob.name.startswith('PagodaSecondFloorEastGallery'):
            ob.location.x=167.2
            ob.scale.x=5.4/4.5
        elif ob.name.startswith('PagodaGalleryBaluster'):
            ob.location.x=170.1
        elif ob.name.startswith('PagodaGalleryRail'):
            ob.location.x=10.1
    for x in (-196.6,-187.4):
        tube('FIX_Architecture_AcademyLandingHandrail',[(x,68.7,14.05),(x,75.7,14.05)],[.13,.13],'gold',g)
        for y in (69.0,74.9):
            cylinder('FIX_Architecture_AcademyLandingRailPost',(x,y,13.36),.11,1.35,'red',g,vertices=8)
    for y in (126,137,152):
        cylinder('FIX_Architecture_PagodaGallerySupport',(167.2,y,12.12),.40,8.3,'wood',g,vertices=12)
        cylinder('FIX_Architecture_PagodaGallerySupportFoot',(167.2,y,8.25),.64,.5,'stoneLight',g,vertices=12)
        box('FIX_Architecture_PagodaGallerySupportBracket',(167.2,y,15.9),(5.4,.65,.35),'gold',g)
    tube('FIX_Architecture_PagodaInnerRail',[(164.35,124,17.8),(164.35,138.5,17.8)],[.12,.12],'gold',g)
    tube('FIX_Architecture_PagodaOuterRailEnd',[(170.1,147,17.8),(170.1,156.5,17.8)],[.12,.12],'gold',g)
    for y in (147.5,154):
        cylinder('FIX_Architecture_PagodaInnerRailPost',(164.35,y,17.1),.09,1.4,'red',g,vertices=8)

def build():
    _remove_route_objects()
    bpy.context.view_layer.update()
    _boulevard_clearance()
    for name,points,width in ROAD_POLYLINES:
        for i in range(len(points)-1):
            curbed_route(name+' segment '+str(i+1),points[i],points[i+1],width)
    _upper_access()
    _marker_positions()
    bpy.context.view_layer.update()
