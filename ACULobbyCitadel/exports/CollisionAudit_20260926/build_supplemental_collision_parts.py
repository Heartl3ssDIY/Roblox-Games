import bpy, json, math, collections
from pathlib import Path
from mathutils import Matrix, Vector
ROOT = Path(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel')
OUT = ROOT / 'exports' / 'CollisionAudit_20260926'
audit = json.loads((OUT/'collision_repair_candidates.json').read_text(encoding='utf8'))
parts=[]; skipped=[]
for item in audit['missingCandidates']:
    if not item['simpleCuboid']: continue
    if min(item['sizeRoblox']) < .05:
        skipped.append({'source':item['source'],'reason':'Thin decorative inlay; leave noncolliding instead of inflating to Roblox minimum.'})
        continue
    assert all(m == 'BEVEL' for m in item['sourceModifiersIgnoredForProxy']), item['source']
    row={'source':item['source'],'collection':item['collection'],'reason':item['reason'],'shape':'Block','sizeRoblox':item['sizeRoblox'],'cframeRoblox':item['cframeRoblox'],'proxyType':'Exact raw source cuboid; visual bevel omitted'}
    parts.append(row)
lookup={r['source']:r for r in audit['missingCandidates']}
for name in ['Garden terrace | walkable island top','Grand court foundation','Champion_Dais_Foundation','Waterfall_VistaDeck']:
    item=lookup[name]; cf=list(item['cframeRoblox']); sx,sy,sz=item['sizeRoblox']
    note='Circular floor proxy matching source height and circumference.'
    if name == 'Grand court foundation':
        cf[1]=1.52-sy/2
        note='Top set to visible limestone paving Y1.52; original foundation top Y1.46. One circular floor replaces 240 radial paving colliders.'
    assert cf[3:] == [1.,0.,0.,0.,1.,0.,0.,0.,1.]
    cf[3:]=[0.,-1.,0.,1.,0.,0.,0.,0.,1.]
    parts.append({'source':name,'collection':item['collection'],'reason':'missing_circular_walk_surface','shape':'Cylinder','sizeRoblox':[sy,sx,sz],'cframeRoblox':cf,'proxyType':note})
B=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
central=[]
for name in ['Champion_Plinth_Foot','Champion_Plinth','Champion_Plinth_Capital','Champion_Plinth_Top']:
    ob=bpy.data.objects.get(name)
    if not ob: raise RuntimeError('Missing source '+name)
    pts=[B@(ob.matrix_world@v.co) for v in ob.data.vertices]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]); hi=Vector([max(p[i] for p in pts) for i in range(3)])
    center=(lo+hi)/2
    xz=sorted(set((round(p.x-center.x,7),round(p.z-center.z,7)) for p in pts),key=lambda p:math.atan2(p[1],p[0]))
    radii=[]
    for i,p in enumerate(xz):
        q=xz[(i+1)%len(xz)]
        edge=math.hypot(q[0]-p[0],q[1]-p[1])
        if edge>1e-7:radii.append(abs(p[0]*q[1]-p[1]*q[0])/edge)
    radius=min(radii)
    cf=[*center,0.,-1.,0.,1.,0.,0.,0.,0.,1.]
    row={'source':name,'collection':'20_Statue','reason':'missing_pedestal_solid','shape':'Cylinder','sizeRoblox':[hi.y-lo.y,2*radius,2*radius],'cframeRoblox':cf,'proxyType':'Inscribed circular collision inside original faceted pedestal. Exact vertical bounds; does not protrude invisibly beyond eight-sided artwork.','sourceBoundsRoblox':[list(lo),list(hi)],'sourcePolygonSides':len(xz)}
    parts.append(row);central.append({'name':name,'center':list(center),'height':hi.y-lo.y,'radius':radius,'sides':len(xz)})
for i,p in enumerate(parts,1):
    p['id']='SUP_COL_%04d'%i
    cf=p['cframeRoblox'];R=[cf[3:6],cf[6:9],cf[9:12]]
    for a in range(3):
        for b in range(3):
            assert abs(sum(R[a][j]*R[b][j] for j in range(3))-(a==b))<1e-5,(p['source'],'nonrigid')
    assert len(cf)==12 and all(math.isfinite(x) for x in cf+p['sizeRoblox'])
    assert min(p['sizeRoblox'])>=.05,p['source']
existing={x['source'] for x in audit['existing']}
assert not existing.intersection(p['source'] for p in parts)
assert sum(p['reason']=='missing_waterfall_steps' for p in parts)==84
assert len({p['id'] for p in parts})==len(parts)
summary={'total':len(parts),'blocks':sum(p['shape']=='Block' for p in parts),'cylinders':sum(p['shape']=='Cylinder' for p in parts),'waterfallSteps':84,'skippedThinDecorations':len(skipped),'byReason':dict(collections.Counter(p['reason'] for p in parts))}
data={'version':1,'sourceMaster':str(ROOT/'ACU_Festival_Citadel.blend'),'unit':'stud','coordinateFrame':'BASE FILE FRAME = Blender X,Z,-Y. CFrames below are NOT pre-rotated to the live lobby and NOT pre-scaled.','placement':'Use currentRoot:GetPivot() * CFrame.Angles(0,math.pi,0) * (CFrame.new(basePosition * currentRoot:GetScale()) * baseRotation). Multiply sizeRoblox by currentRoot:GetScale(). The root was reported scale2; read it immediately before installation.','cylinderOrientation':'All Cylinder CFrames already orient Roblox local X axis vertically; do not apply an extra cylinder rotation.','recommendedProperties':{'Anchored':True,'CanCollide':True,'CanQuery':True,'CanTouch':False,'Transparency':1,'CastShadow':False},'destination':'workspace.ACU_Citadel_Staging.Collision.SupplementalSourceSolids','existingCollisionPolicy':'Preserve the 798 imported MeshParts. Do not Box combined stairs, rings, arches, or buildings.','summary':summary,'parts':parts,'skipped':skipped,'limitations':['Source cuboids omit only visual bevels.','Circular proxies approximate polygonal floors, with identical vertical walk height.','Four pedestal cylinders are inscribed to avoid invisible collision protruding outside the eight-sided visual plinth.','This fills identified safe omissions; irregular batched walls/roofs and terrain still require a Studio traversal check.']}
(OUT/'supplemental_collision_parts.json').write_text(json.dumps(data,indent=2),encoding='utf8')
(OUT/'supplemental_collision_parts_compact.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
print(json.dumps({'summary':summary,'centralPedestal':central,'output':str(OUT/'supplemental_collision_parts.json')}))
