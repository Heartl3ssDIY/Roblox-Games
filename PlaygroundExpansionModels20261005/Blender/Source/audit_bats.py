import bpy, json, math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
results=[]
expect={
    'B16': [('Fossil rib',6),('Embossed three-toed',1)],
    'B17': [('Overlapping rounded scale band',4),('Rounded gold dorsal ridge',3)],
    'B18': [('Waffle pocket',15),('Caramel grip ring',2)],
    'B19': [('Left feather panel',1),('Right feather panel',1),('Attached thick gold tip ring',1)],
    'B20': [('Rope broad wrap',4),('Cream leaf engraving',2)],
    'B21': [('Button 1 glossy',1),('Button 2 glossy',1),('Button 3 glossy',1)],
    'B22': [('Honeycomb hexagonal panel',5)],
    'B23': [('Eight-tooth brass toy gear',1),('Broad navy clockwork collar',2),('Wind-up key rounded finger hole',2)],
    'B24': [('Large orange button rim',1),('Mint sewn broad panel',2)],
    'B25': [('Six broad opaque crystal facets',1),('Crystal collar 1 cream',1),('Crystal collar 2 cream',1)],
}
for path in sorted((ROOT/'Bats'/'Metadata').glob('*.json')):
    m=json.loads(path.read_text()); asset_id=m['id']; checks=[]
    bpy.ops.wm.open_mainfile(filepath=m['blend'])
    def check(name,value):
        if not value:raise AssertionError(asset_id+': '+name)
        checks.append(name)
    objects=[o for o in bpy.data.objects if o.type=='MESH' and o.get('AssetId')==asset_id and not o.get('IsRobloxExport')]
    check('Editable individually named geometry retained',len(objects)==m['parts'])
    grip=bpy.data.objects.get('GripAttachment')
    check('Grip attachment retained at hand origin',grip is not None and grip.location.length<1e-7)
    check('Bat total length within authored hand scale',3.4<=m['dimensions'][2]<=3.8)
    check('Model remains narrower than one stud',max(m['dimensions'][:2])<1.0)
    check('Every exported mesh below 19000 triangles',m['maxMeshTriangles']<=19000)
    check('All editable vertices finite',all(math.isfinite(v) for o in objects for p in o.data.vertices for v in p.co))
    check('No zero-area editable faces',all(p.area>1e-12 for o in objects for p in o.data.polygons))
    check('Reference image packed into blend',any(i.packed_file and 'palette' not in i.name for i in bpy.data.images if i.source=='FILE'))
    check('Export palette packed into blend',any(i.packed_file and 'palette' in i.name for i in bpy.data.images))
    check('FBX and texture export present',Path(m['fbx']).stat().st_size>10000 and Path(m['texture']).stat().st_size>100)
    for prefix,count in expect[asset_id]:check(prefix+' count '+str(count),sum(o.get('Part','').startswith(prefix) for o in objects)==count)
    if asset_id=='B18':check('All 15 waffle cells have real inset depth',sum(o.get('RecessDepthStuds',0)>=.04 for o in objects)==15)
    if asset_id=='B25':
        crystal=next(o for o in objects if o.get('Part','').startswith('Six broad'))
        check('Six cross-section vertices per crystal profile ring',len(crystal.data.vertices)==9*6)
        check('Crystal faces remain opaque and flat-shaded',not any(p.use_smooth for p in crystal.data.polygons))
    results.append({'id':asset_id,'passed':len(checks),'checks':checks,'triangles':m['triangles'],'editableParts':len(objects),'viewTransform':bpy.context.scene.view_settings.view_transform})
report={'count':len(results),'totalChecks':sum(r['passed'] for r in results),'assets':results,'method':'Opened every saved editable Blender file; inspected native geometry, attachments, packed images and brief-specific detail counts. No Studio or Play changes.'}
(ROOT/'Bats'/'Validation.json').write_text(json.dumps(report,indent=2))
print('BATS_AUDIT_PASS '+json.dumps({'assets':len(results),'checks':report['totalChecks']}),flush=True)
