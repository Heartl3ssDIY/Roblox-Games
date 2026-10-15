import bpy, json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
reports=[]
for file in sorted((root/'Miscellaneous'/'Metadata').glob('*.json')):
    meta=json.loads(file.read_text(encoding='utf-8'))
    bpy.ops.wm.open_mainfile(filepath=meta['blend'])
    objects=[o for o in bpy.data.objects if o.type=='MESH' and o.get('AssetId')==meta['id'] and not o.get('IsRobloxExport')]
    parts=[o.get('Part','') for o in objects]
    checks={}
    checks['gripAnchor']='Grip' in meta['anchors']
    checks['noGameplay']=meta['gameplayImplemented'] is False
    checks['editableVolumes']=all(len(o.data.polygons)>3 and o.data.users>=1 for o in objects)
    if meta['id']=='M17':
        checks['exactlyThreeSnowballs']=sum(p.startswith('Attached Snowball ') for p in parts)==3
        checks['muzzleAndHopperAnchors']=all(p in meta['anchors'] for p in ['Muzzle','Hopper'])
        checks['snowballCradle']='Internal Snowball Cradle' in parts
    if meta['id']=='M18':
        checks['attachedNozzleFeed']='Connected Hollow Nozzle Feed' in parts
        checks['muzzleAndReservoirAnchors']=all(p in meta['anchors'] for p in ['Muzzle','Reservoir'])
    if meta['id']=='M19': checks['exactlyThreePeels']=sum(p.startswith('Peel ') for p in parts)==3
    if meta['id']=='M20': checks['exactlyThreeSpringLoops']=any(o.get('Turns')==3 and o.get('Part')=='Exactly Three Compression Loops' for o in objects)
    if meta['id']=='M24': checks['exactlyThreeBlades']=sum(p.startswith('Blade ') for p in parts)==3
    if meta['id']=='M25':
        checks['lidHeadAndCrankAnchors']=all(p in meta['anchors'] for p in ['LidHinge','Head','WindUp'])
        checks['twoCreamHorns']=sum(p.startswith('Tiny Cream Horn ') for p in parts)==2
    if meta['id'] in ['M16','M21']: checks['spoutAnchor']='Spout' in meta['anchors']
    assert all(checks.values()), (meta['id'],checks)
    reports.append({'id':meta['id'],'checks':checks,'passed':True})
(root/'Validation-Miscellaneous-Details.json').write_text(json.dumps({'passed':True,'count':len(reports),'assets':reports},indent=2),encoding='utf-8')
print('MISC_DETAILS_PASSED',len(reports),flush=True)
