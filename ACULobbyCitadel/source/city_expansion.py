from common import *
from districts import B,C,T,R,I,_lantern,_post,_portal
from district_backdrop import _sky_roof

class _Batch:
    def __init__(self,name,group):
        self.name=name;self.group=group;self.parts={}
    def box(self,loc,size,mat):
        if mat not in self.parts:self.parts[mat]=[[],[]]
        verts,faces=self.parts[mat];base=len(verts)
        x,y,z=loc;w,d,h=[v/2 for v in size]
        verts.extend([(x-w,y-d,z-h),(x+w,y-d,z-h),(x+w,y+d,z-h),(x-w,y+d,z-h),(x-w,y-d,z+h),(x+w,y-d,z+h),(x+w,y+d,z+h),(x-w,y+d,z+h)])
        faces.extend([tuple(base+i for i in f) for f in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7))])
    def finish(self):
        for mat,(verts,faces) in self.parts.items():
            mesh(self.name+'_'+mat,verts,faces,mat,self.group)

def _roof_at(name,loc,w,d,rise,g,angle=0):
    previous=set(collection(g).objects)
    _sky_roof(name,loc[2],w,d,rise,g)
    for ob in collection(g).objects:
        if ob not in previous:
            ob.location=(loc[0],loc[1],0)
            ob.rotation_euler.z=angle

def _window_batch(batch,x,y,z,width=1.7,height=2.4,side='front'):
    if side in ('front','back'):
        s=-1 if side=='front' else 1
        batch.box((x,y,z),(width+.25,.26,height+.30),'wood')
        batch.box((x,y+s*.145,z),(width,.10,height),'goldGlow')
        for xx in (-.33,.33):
            batch.box((x+xx,y+s*.22,z),(.065,.06,height),'wood')
        for zz in (-.65,0,.65):
            batch.box((x,y+s*.23,z+zz),(width,.06,.065),'wood')
    else:
        s=-1 if side=='left' else 1
        batch.box((x,y,z),(.26,width+.25,height+.30),'wood')
        batch.box((x+s*.145,y,z),(.10,width,height),'goldGlow')
        for yy in (-.33,.33):
            batch.box((x+s*.22,y+yy,z),(.06,.065,height),'wood')
        for zz in (-.65,0,.65):
            batch.box((x+s*.23,y,z+zz),(.06,width,.065),'wood')

def _veranda(batch,w,d,z):
    for s in (-1,1):
        batch.box((0,s*(d/2+1.0),z),(w+2.6,2.2,.25),'wood')
        batch.box((0,s*(d/2+1.85),z+1.35),(w+2.6,.20,.20),'gold')
        batch.box((0,s*(d/2+1.85),z+.65),(w+2.6,.12,.12),'red')
        for i in range(max(7,int(w/1.7))):
            xx=-w/2-1.0+(w+2.0)*i/(max(7,int(w/1.7))-1)
            batch.box((xx,s*(d/2+1.85),z+.78),(.10,.12,1.45),'red')

def _steps(name,loc,width,count,rise,run,g,material='stoneLight'):
    x,y,z=loc
    batch=_Batch(name,g)
    for j in range(count):
        height=(j+1)*rise
        batch.box((x,y+j*run,z+height/2),(width,run+.06,height),material)
        batch.box((x,y+j*run-run*.46,z+height+.02),(width-.2,.07,.045),'gold')
    batch.finish()

def _house(name,loc,w=16,d=17,floors=2,kind=0,yaw=0):
    g='50_City_'+name
    a=_Batch(name,g)
    a.box((0,0,1.6),(w+2,d+2,.8),'stoneDark')
    a.box((0,0,2.1),(w+.6,d+.6,.25),'stoneLight')
    for k in range(floors):
        z=2.3+k*6.35
        ww=w*(1-.065*k);dd=d*(1-.035*k)
        mat='ivory' if (kind+k)%3!=0 else 'wood'
        a.box((0,0,z+2.75),(ww,dd,5.5),mat)
        for sx in (-1,1):
            for sy in (-1,1):
                a.box((sx*(ww/2-.22),sy*(dd/2-.22),z+2.65),(.45,.45,5.7),'wood' if mat=='ivory' else 'red')
        for sy in (-1,1):
            for i in range(max(3,int(ww/4))):
                xx=-ww*.34+ww*.68*i/(max(3,int(ww/4))-1)
                _window_batch(a,xx,sy*(dd/2+.04),z+3,1.65,2.55,'front' if sy==-1 else 'back')
            a.box((0,sy*(dd/2+.16),z+.25),(ww,.20,.22),'red')
            a.box((0,sy*(dd/2+.16),z+5.25),(ww+.5,.25,.55),'red')
            a.box((0,sy*(dd/2+.31),z+5.2),(ww+.25,.07,.065),'gold')
        for sx in (-1,1):
            for yy in (-dd*.27,dd*.27):
                _window_batch(a,sx*(ww/2+.04),yy,z+3,1.5,2.5,'left' if sx==-1 else 'right')
        if k>0 and (kind%3!=2 or k==floors-1):
            _veranda(a,ww,dd,z+.15)
        if kind in (0,3,4) or k==floors-1:
            _roof_at(name+'_eaves'+str(k),(0,0,z+5.6),ww+4.3,dd+4.2,2.0 if k<floors-1 else 3.3,g)
    a.box((0,-d/2-.25,4.03),(3.3,.35,3.55),'purple')
    for x in (-1.8,1.8):
        a.box((x,-d/2-.47,4.0),(.15,.11,3.85),'gold')
    a.box((0,-d/2-.48,5.99),(3.7,.11,.16),'gold')
    a.box((0,-d/2-.49,4.0),(.07,.1,3.6),'gold')
    for x in (-.35,.35):
        a.box((x,-d/2-.61,4.0),(.14,.14,.4),'gold')
    if kind%2==0:
        for x in (-w/2+.7,w/2-.7):
            a.box((x,-d/2-2.1,4.15),(.25,.25,5.6),'red')
        _roof_at(name+'_entrance_canopy',(0,-d/2-1.0,6.65),w+2,6.0,1.15,g)
        for i in range(5):
            a.box(((i-2)*w/5,-d/2-3.92,5.93),(w/5-.10,.07,.92),'purple' if kind%3 else 'red')
            a.box(((i-2)*w/5,-d/2-3.97,5.52),(w/5-.15,.05,.06),'gold')
    if kind==1:
        top=2.3+(floors-1)*6.35+8.9
        a.box((0,0,top+1.3),(w*.46,d*.48,2.6),'wood')
        for x in (-w*.16,0,w*.16):
            _window_batch(a,x,-d*.24-.02,top+1.3,1.2,1.6)
        _roof_at(name+'_lantern_attic',(0,0,top+2.65),w*.65,d*.65,2.3,g)
    if kind==2:
        wx=w/2+2.8;wy=d*.08
        a.box((wx,wy,4.45),(5.8,d*.73,5.6),'ivory')
        _roof_at(name+'_side_workshop',(wx,wy,7.2),8.1,d*.73+2.2,2.4,g)
        a.box((wx,wy+2.8,10.0),(1.9,1.9,4.8),'stoneDark')
        a.box((wx,wy+2.8,12.5),(2.35,2.35,.34),'gold')
    if kind==3:
        for x in (-w*.42,w*.42):
            a.box((x,-d/2-.45,10.0),(1.3,.12,4.1),'purple')
            a.box((x,-d/2-.53,10.0),(.10,.035,3.4),'gold')
    if kind==4:
        for i in range(4):
            xx=(i-1.5)*2.5
            a.box((xx,-d/2-1.4,3.2),(1.5,.9,1.9),'wood')
            a.box((xx,-d/2-1.4,4.22),(1.7,1.1,.14),'gold')
    a.finish()
    _steps(name+'_entry_stairs',(0,-d/2-5.3,1.2),5.5,3,.25,.70,g)
    for x in (-w*.37,w*.37):
        _lantern(name+'_welcome_lantern',x,-d/2-1,6.1,g,.52)
    transform_group(g,(loc[0],loc[1],0),yaw)

def _temple_hall(name,loc,w,d,levels=2,yaw=0):
    g='51_Academy_'+name
    a=_Batch(name,g)
    a.box((0,0,1.6),(w+5,d+5,.8),'stoneDark')
    a.box((0,0,2.2),(w+3.5,d+3.5,.4),'stoneLight')
    for k in range(levels):
        ww=w*(1-k*.12);dd=d*(1-k*.12);z=2.4+k*10.1
        a.box((0,0,z+3.95),(ww-3,dd-3,7.9),'ivory')
        for sy in (-1,1):
            count=max(4,int(ww/5))
            for i in range(count):
                x=-ww*.4+ww*.8*i/(count-1)
                a.box((x,sy*(dd/2-1),z+4),(.52,.52,8.0),'wood')
                _window_batch(a,x,sy*(dd/2-1.40),z+4.4,2.6,3.7,'front' if sy==-1 else 'back')
                for t in (-1,1):
                    a.box((x+t*.8,sy*(dd/2-1),z+7.6),(2.3,.8,.35),'gold')
            a.box((0,sy*(dd/2-.9),z+7.85),(ww+2,1.15,.8),'red')
            a.box((0,sy*(dd/2-1.50),z+7.86),(ww+1,.06,.10),'gold')
        for sx in (-1,1):
            for y in (-dd*.3,0,dd*.3):
                a.box((sx*(ww/2-1),y,z+4),(.52,.52,8.0),'wood')
                _window_batch(a,sx*(ww/2-1.40),y,z+4.4,2.6,3.7,'left' if sx==-1 else 'right')
        if k==0:
            _veranda(a,ww,dd,z+.14)
        else:
            for sy in (-1,1):
                a.box((0,sy*(dd/2+1.5),z+.15),(ww+4.0,5.2,.26),'wood')
                for xx in (-ww*.38,ww*.38):
                    a.box((xx,sy*(dd/2+3.75),z+1.3),(ww*.25,.18,.18),'gold')
                for xx in (-ww/2-1.5,0,ww/2+1.5):
                    a.box((xx,sy*(dd/2+3.75),z+.78),(.18,.18,1.5),'red')
            for sx in (-1,1):
                a.box((sx*(ww/2+1),0,z+.15),(4.2,dd+6.3,.26),'wood')
                a.box((sx*(ww/2+2.9),0,z+1.3),(.18,dd+6.3,.18),'gold')
        _roof_at(name+'_great_roof'+str(k),(0,0,z+8.05),ww+8,dd+7,4.8 if k==levels-1 else 3.0,g)
    for x in (-w/2+2.5,w/2-2.5):
        _lantern(name+'_temple_lantern',x,-d/2,8.4,g,.90)
    a.finish()
    _steps(name+'_approach',(0,-d/2-6.3,1.2),w*.5,4,.26,1.0,g)
    transform_group(g,(loc[0],loc[1],0),yaw)

def _academy():
    g='51_Academy_Courtyard'
    a=_Batch('AcademyCourtyard',g)
    a.box((-172,55,1.20),(87,112,.16),'stoneLight')
    for x in (-211,-133):
        a.box((x,41,1.32),(2.1,75,.08),'gold')
    a.box((-172,8,1.32),(78,2.1,.08),'gold')
    for y in range(10,89,4):
        a.box((-172,y,1.303),(45,.08,.035),'stoneDark')
    for x in range(-194,-149,4):
        a.box((x,48,1.30),(.08,83,.04),'stoneDark')
    for x in (-198,-147):
        a.box((x,31,1.43),(3,12,.34),'stoneDark')
        a.box((x,31,1.68),(2.55,11.5,.19),'moss')
    a.finish()
    _temple_hall('GrandDojo',(-172,91),60,34,3)
    _temple_hall('WestScrollWing',(-209,41),21,58,1)
    _temple_hall('EastScrollWing',(-135,41),21,58,1)
    entry_group='51_Academy_SouthGate'
    for x in (-17,17):
        _post('AcademyGatePillar',x,0,1.2,14,entry_group,'red',radius=.8)
        _post('AcademyGateRearPillar',x,7,1.2,14,entry_group,'wood',radius=.5)
        B('AcademyGateTieBeam',(x,3.5,12.8),(1,10,.8),'wood',entry_group)
        _lantern('AcademyGateLantern',x,-2.6,11.7,entry_group,.85)
    B('AcademyGateLintel',(0,0,13.2),(41,1.6,1.1),'red',entry_group)
    _roof_at('AcademySouthGateRoof',(0,3.5,14),47,19,4.3,entry_group)
    transform_group(entry_group,(-172,-2,0),0)
    _steps('AcademyGalleryStairs',(-192,54,1.2),8.5,40,.2895,.50,g)
    B('AcademyGalleryUpperLanding',(-192,75.2,12.65),(9.0,4.3,.26),'wood',g)
    T('AcademyGalleryStairHandrail',[(-196.6,53.5,2.6),(-196.6,74.7,14.2)],[.13,.13],'gold',g)
    T('AcademyGalleryStairHandrail',[(-187.4,53.5,2.6),(-187.4,74.7,14.2)],[.13,.13],'gold',g)
    marker('ACCESS_AcademyUpperGallery',(-192,55,1.2),'walkable_upper_gallery')
    _house('AcademyResidenceA',(-211,120),17,17,3,3)
    _house('AcademyResidenceB',(-135,120),17,17,3,1)
    marker('DISTRICT_Academy',(-172,11,1.2),'district_training_academy')

def _pagoda():
    g='52_CelestialPagoda'
    a=_Batch('CelestialPagoda',g)
    a.box((140,140,4.25),(58,58,6.1),'stoneDark')
    a.box((140,140,7.6),(58.6,58.6,.6),'stoneLight')
    for x in (112,168):
        for y in range(113,169,7):
            a.box((x,y,8.9),(.5,.5,2.1),'red')
        a.box((x,140,10.0),(.25,56,.22),'gold')
    for y in (113,167):
        for x in range(112,169,7):
            if y==113 and abs(x-140)<10:continue
            a.box((x,y,8.9),(.5,.5,2.1),'red')
        for x in (120.5,159.5) if y==113 else (140,):
            a.box((x,y,10.0),(17 if y==113 else 56,.25,.22),'gold')
    a.finish()
    _steps('PagodaGrandStair',(140,98,1.2),22,24,.275,.57,g)
    tower_group='52_CelestialPagoda_Tower'
    b=_Batch('CelestialPagodaTower',tower_group)
    for level in range(7):
        w=35-level*3.3;d=w*.93;z=8.0+level*8.1
        b.box((0,0,z+3.8),(w,d,7.6),'ivory' if level%3==0 else 'wood')
        for sx in (-1,1):
            for sy in (-1,1):
                b.box((sx*(w/2-.25),sy*(d/2-.25),z+3.85),(.5,.5,7.7),'red')
        n=max(3,int(w/5))
        for sy in (-1,1):
            for i in range(n):
                xx=-w*.34+w*.68*i/(n-1)
                _window_batch(b,xx,sy*(d/2+.06),z+4.2,2.2 if level<4 else 1.4,3.2,'front' if sy==-1 else 'back')
        for sx in (-1,1):
            for yy in (-d*.29,0,d*.29):
                _window_batch(b,sx*(w/2+.06),yy,z+4.2,1.6,3.0,'left' if sx==-1 else 'right')
        _veranda(b,w,d,z+.25)
        _roof_at('PagodaTier'+str(level),(0,0,z+7.2),w+8.2,d+8.0,3.8,tower_group)
    b.finish()
    tip=8+6*8.1+11.1
    C('PagodaSacredSpire',(0,0,tip+2.6),.4,5.3,'gold',tower_group,vertices=12)
    for i in range(6):
        R('PagodaSpireDisc',(0,0,tip+i*.95),2.0-i*.23,1.7-i*.23,.18,'gold',tower_group,segments=24)
    I('PagodaFinial',(0,0,tip+6.6),(.6,.6,1.7),'goldLight',tower_group)
    transform_group(tower_group,(140,140,0),0)
    _steps('PagodaSecondFloorStair',(162.5,121,8),6.2,34,.25,.66,g)
    B('PagodaSecondFloorLanding',(160,144,16.35),(11.0,4.5,.30),'wood',g)
    B('PagodaSecondFloorEastGallery',(157.8,140,16.35),(4.5,33,.30),'wood',g)
    T('PagodaSecondFloorOuterHandrail',[(166.0,120.7,9.4),(166.0,143.5,17.9)],[.13,.13],'gold',g)
    for yy in (127,134,151):
        B('PagodaGalleryBaluster',(160.0,yy,17.1),(.14,.14,1.5),'red',g)
    T('PagodaGalleryRail',[(160,124,17.8),(160,140.8,17.8)],[.13,.13],'gold',g)
    marker('ACCESS_PagodaUpperGallery',(162.5,121,8),'walkable_upper_gallery')
    for x in (113,167):
        for y in (116,164):
            _lantern('PagodaTerraceLantern',x,y,11.2,g,1.0)
    _house('PagodaKeeperWest',(101,161),17,18,3,3,.12)
    _house('PagodaKeeperEast',(178,157),17,18,3,0,-.12)
    _house('PagodaObservatory',(142,190),18,17,4,1,0)
    marker('DISTRICT_CelestialPagoda',(140,111,8.0),'district_celestial_pagoda')
    marker('VISTA_PagodaBalcony',(140,123,64.8),'exploration_vista')

def _fortress():
    g='53_NorthFortressGate'
    a=_Batch('FortressGate',g)
    for x in (-25,25):
        a.box((x,0,15.5),(9.0,16,28.6),'stoneDark')
        a.box((x,-8.15,15.6),(5.7,.25,24.9),'red')
        for xx in (-3.9,3.9):
            a.box((x+xx,-8.35,15.6),(.22,.18,26.0),'gold')
        for z in (3,8,14,20,26,29):
            a.box((x,-8.35,z),(8.6,.18,.24),'stoneLight')
        _post('FortressCeremonialPillar',x-(-3.8 if x<0 else 3.8),-9.1,1.2,29.7,g,'red',radius=.83)
    a.box((0,0,30.0),(64,17.5,3.0),'red')
    a.box((0,-8.9,29.7),(63,.25,.30),'gold')
    a.box((0,0,38.7),(32,14,8.2),'ivory')
    for x in (-13,-8,-3,3,8,13):
        _window_batch(a,x,-7.15,39.1,2.3,4.0)
    _veranda(a,33,14,35.0)
    _roof_at('FortressLowerRoof',(0,0,31.5),72,30,5.5,g)
    _roof_at('FortressUpperRoof',(0,0,43.0),43,25,5.6,g)
    C('FortressSolarCrest',(0,-8.45,39.0),2.1,.30,'gold',g,vertices=24).rotation_euler.x=pi/2
    C('FortressSolarCrestInset',(0,-8.65,39.0),1.6,.13,'purple',g,vertices=24).rotation_euler.x=pi/2
    for s in (-1,1):
        x=s*63
        a.box((x,4,8.8),(60,13,15.2),'stoneDark')
        a.box((x,-2.8,8.8),(58,.18,12.6),'stone')
        for xx in range(-25,26,5):
            a.box((x+xx,4,17.4),(2.8,13.7,2.1),'stoneLight')
        for xx in range(-24,25,8):
            a.box((x+xx,-3.0,9.3),(.26,.15,12.5),'gold')
            a.box((x+xx,-3.2,8.5),(1.7,.15,3.4),'black')
    a.finish()
    for x in (-32,32):
        _lantern('FortressGreatLantern',x,-11.5,25.2,g,1.6)
    _portal('FortressDistantWorlds',0,4,15.3,32,27,g,'purpleGlow')
    transform_group(g,(0,228,0),0)
    _house('FortressWestKeep',(-67,235),24,22,5,3,0)
    _house('FortressEastKeep',(67,235),24,22,5,0,0)
    _house('FortressWestBarracks',(-103,249),22,17,3,2,0)
    _house('FortressEastBarracks',(103,249),22,17,3,4,0)
    marker('DISTRICT_NorthGate',(0,213,1.2),'district_outer_world_gate')

def _merchant_city():
    g='54_MerchantStreet'
    a=_Batch('MerchantStreet',g)
    a.box((155,-148,1.23),(30,157,.12),'stoneLight')
    for x in (143.2,166.8):
        a.box((x,-148,1.31),(.34,156,.07),'gold')
    for y in range(-223,-71,4):
        a.box((155,y,1.30),(24,.07,.025),'stoneDark')
    a.finish()
    for i,y in enumerate((-208,-183,-158,-133,-108,-83)):
        _house('MarketWest'+str(i+1),(128,y),16+(i%2)*2,18,2+(i%3==0),i%5,pi/2)
        _house('MarketEast'+str(i+1),(182,y),17+(i%2),18,2+(i%3==1),(i+2)%5,-pi/2)
    for j,y in enumerate((-218,-168,-118,-68)):
        for x in (141.8,168.2):
            C('MerchantLanternPost',(x,y,6.4),.20,10.4,'wood',g,vertices=10)
            _lantern('MerchantStreetLantern',x,y,11.1,g,.72)
        points=[(141.8+26.4*t/8,y,11.4-1.9*sin(pi*t/8)) for t in range(9)]
        T('MerchantFestivalGarland',points,[.035]*9,'wood',g,sides=5)
        for k in range(1,7):
            x=141.8+26.4*k/7;z=11.4-1.9*sin(pi*k/7)-.6
            _lantern('MerchantHangingLantern',x,y,z,g,.45)
    marker('DISTRICT_MerchantQuarter',(155,-68,1.2),'district_merchant_quarter')

def _outer_neighbourhoods():
    west_sites=[(-252,-150),(-252,-114),(-252,-78),(-252,-42),(-252,-6),(-252,30),(-252,66),(-252,102),(-252,138),(-212,-155),(-212,-119),(-212,-83),(-212,-47)]
    for i,p in enumerate(west_sites):
        _house('WesternWard'+str(i+1),p,17+(i%3)*2,16+(i%2)*3,2+(i%4==0),i%5,pi/2 if i<9 else (pi/2-.15))
    north_sites=[(-218,204),(-177,205),(-134,196),(-84,194),(-42,187),(42,186),(218,202),(-220,251),(-175,254),(-132,265),(-42,268),(42,268),(143,258),(184,253),(225,249)]
    for i,p in enumerate(north_sites):
        _house('NorthernWard'+str(i+1),p,17+(i%4)*1.2,18+(i%3),2+(i%4==2),i%5,(i%3-1)*.09)
    south_sites=[(-170,-211),(-130,-193),(-92,-235),(-52,-260),(45,-267),(85,-236),(217,-210),(236,-172)]
    for i,p in enumerate(south_sites):
        _house('SouthernWard'+str(i+1),p,18+(i%3),18+(i%2)*3,2+(i%3==1),(i+1)%5,pi*.1*(i%3-1))

def build():
    _academy()
    _pagoda()
    _fortress()
    _merchant_city()
    _outer_neighbourhoods()
