import json, math, re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
source=(ROOT/'CreateEmoteWheelUI.luau').read_text()
assert 'wheel.Position = UDim2.fromScale(0.5, 0.415)' in source
assert 'wheel.Size = UDim2.fromScale(0.94, 0.640)' in source
assert 'slot.Size = UDim2.fromScale(0.245, 0.245)' in source
assert 'math.cos(angle) * 0.357' in source

def intersects(a,b):
    return min(a[2],b[2])-max(a[0],b[0])>0.01 and min(a[3],b[3])-max(a[1],b[1])>0.01

def check_case(width,height):
    safe_w=width-(88 if width>height and width<1000 else 0)
    safe_h=height-36
    ph=min(safe_h*.92,safe_w*.94/.96,680,650/.96)
    ph=max(ph,281.25)
    pw=ph*.96
    assert pw<=safe_w and ph<=safe_h,'panel exceeds safe viewport'
    ws=min(.94*pw,.640*ph)
    wx=.5*pw-ws/2;wy=.415*ph-ws/2
    ss=.245*ws
    slots=[]
    for i in range(8):
        angle=-math.pi/2+i*math.pi/4
        x=wx+(.5+math.cos(angle)*.357)*ws
        y=wy+(.5+math.sin(angle)*.357)*ws
        slots.append((x-ss/2,y-ss/2,x+ss/2,y+ss/2))
    assert all(0<=a[0]<a[2]<=pw and 0<=a[1]<a[3]<=ph for a in slots)
    for i,a in enumerate(slots):
        for b in slots[i+1:]:assert not intersects(a,b),'radial slots overlap'
    def rect(x,y,w,h,button=False):return (x*pw,y*ph,x*pw+max(w*pw,30 if button else 0),y*ph+max(h*ph,26 if button else 0))
    others={
        'Title':rect(.08,.025,.72,.065),
        'Close':rect(.87,.027,.085,.060,True),
        'Hint':rect(.37,.342,.26,.085),
        'StopButton':rect(.42,.448,.16,.048,True),
        'Status':rect(.075,.741,.85,.038),
        'Previous':rect(.22,.790,.12,.074,True),
        'PageLabel':rect(.36,.794,.28,.064),
        'Next':rect(.66,.790,.12,.074,True),
        'ShopButton':rect(.25,.894,.5,.070,True),
    }
    for name,a in others.items():
        assert 0<=a[0]<a[2]<=pw and 0<=a[1]<a[3]<=ph, name+' escapes panel'
        assert not any(intersects(a,b) for b in slots),name+' overlaps radial slot'
    names=list(others)
    for i,name in enumerate(names):
        for other in names[i+1:]:assert not intersects(others[name],others[other]),name+' overlaps '+other
    assert ss>=44,'radial tap targets below 44px'
    hotbar=(width-328,height-148,width-18,height-18)
    toggle=(width-158,height-198,width-18,height-160)
    assert not intersects(hotbar,toggle),'toggle overlaps toy hotbar'
    assert ss*.335>=14,'two name lines below minimum line height'
    assert ss*.16>=7,'state line below minimum line height'
    return {'viewport':[width,height],'safeArea':[safe_w,safe_h],'panel':[round(pw,2),round(ph,2)],'radialSlot':round(ss,2),'slotThumbnail':[round(ss*.72,2),round(ss*.405,2)],'minimumFooterHitHeight':26,'passed':True}

cases=[check_case(w,h) for w,h in [(1920,1080),(1280,720),(1024,768),(390,844),(375,667),(320,568),(844,390),(667,375),(568,320)]]
report={'passed':True,'cases':cases,'notes':['Pure authored-coordinate evaluation; no Studio installation or Play used.','Actual engine constraint evaluation will be verified after root installation.','All eight radial tap targets are >=44px, with no overlap with other slots or hub/footer controls.']}
(ROOT/'LayoutValidation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
