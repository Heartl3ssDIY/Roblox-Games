import bpy
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
criteria={
    'P21':[('OpaqueTurquoiseCrystal',3),('IvoryHorn',2),('WingMembrane',2)],
    'P22':[('CharcoalHorn',2),('WingMembrane',2),('FrontAnkleCuff',2),('BackAnkleCuff',2)],
    'P23':[('HorseEar',2),('FrontBlueHoof',2),('BackBlueHoof',2),('CurledLavenderTailLock',3)],
    'P24':[('Talon',6),('SweptGoldCrest',4),('FlightFeather',10)],
    'P25':[('ConnectedGoldHalo',1),('HaloGoldPhysicalBridge',1),('FlightFeather',10)],
    'P26':[('BrowHorn',2),('SmallNoseHorn',1),('CreamFrillKnob',9)],
    'P27':[('DorsalPlate',10),('TailSpike',4)],
    'P28':[('PinkWingMembrane',2),('ForelimbWingSpar',2),('HindToe',6)],
    'P29':[('CurvedIvoryTusk',2),('KnittedScarfWrap',3),('BroadTrunkCrease',4)],
    'P30':[('ThreePointGoldCrown',1),('RedSquareCrownJewel',1),('RoyalCapeSide',2),('CurlyPigTail',1)],
    'P31':[('DomedRecessedWaffleCell',9),('ButterSquare',1),('ConformingCaramelSyrupPatch',1)],
    'P32':[('Pancake1_FluffyBody',1),('Pancake2_FluffyBody',1),('Pancake3_FluffyBody',1),('AttachedButterCube',1)],
    'P33':[('ConformingPeachHeartMark',1),('LegL',16),('LegR',16)],
    'P34':[('CreamButtonEye',1),('CrossedButtonStitch',2),('GoofyTwoToothSmile_tooth_',2),('CreamForeheadClothPatch',1)],
    'P35':[('SolidTailFlame',3),('ThreePartCrest',3),('GoldenToe',6)],
}
reports=[]
for path in sorted((root/'Pets'/'Metadata').glob('*.json')):
    meta=json.loads(path.read_text())
    bpy.ops.wm.open_mainfile(filepath=meta['blend'])
    source=[o for o in bpy.data.objects if o.type=='MESH' and 'Part'in o]
    row={'id':meta['id'],'checks':[],'passed':True}
    for prefix,expected in criteria[meta['id']]:
        matching=[o['Part'] for o in source if o['Part'].startswith(prefix)]
        passed=len(matching)==expected
        row['checks'].append({'partPrefix':prefix,'expected':expected,'actual':len(matching),'passed':passed})
        row['passed'] &= passed
    if meta['id']=='P33':
        rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
        legs=[b.name for b in rig.data.bones if b.name.startswith('Leg')]
        passed=len(legs)==8
        row['checks'].append({'rigLegCount':len(legs),'expected':8,'passed':passed});row['passed'] &= passed
    if meta['id'] in('P32','P34'):
        prefix='Eye' if meta['id']=='P32' else 'CreamDrawstring'
        objs=[o for o in source if o['Part'].startswith(prefix)]
        passed=all(o['RigBone']=='Body' for o in objs)
        row['checks'].append({'bodyDetailsStayOnBody':passed,'passed':passed});row['passed'] &= passed
    reports.append(row)
out={'passed':all(r['passed'] for r in reports),'assets':reports,'checkCount':sum(len(r['checks']) for r in reports)}
(root/'Validation-PetDetails.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print('PET_DETAILS',json.dumps({'passed':out['passed'],'assets':len(reports),'checks':out['checkCount']}))
