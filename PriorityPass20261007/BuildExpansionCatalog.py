import json,re
from pathlib import Path

root=Path(__file__).resolve().parent
source=(root/'Before/PlaygroundCatalog.luau').read_text(encoding='utf-8')
specs=json.loads((root.parent/'PlaygroundClassics-ExpansionReferences-20261005/Source/Catalog.json').read_text(encoding='utf-8-sig'))
icons=json.loads((root/'ExpansionIconAssets.json').read_text())
schedule={
 'B16':('Coins',12000,None),'B17':('Level',100,None),'B18':('Coins',16000,None),'B19':('Level',75,None),'B20':('Wins',100,'StuckInTheMud'),
 'B21':('Coins',25000,None),'B22':('Coins',30000,None),'B23':('Coins',40000,None),'B24':('Level',250,None),'B25':('Coins',50000,None),
 'P21':('Coins',50000,None),'P22':('Wins',150,'StuckInTheMud'),'P23':('Level',150,None),'P24':('Wins',200,'BritishBulldog'),'P25':('Level',250,None),
 'P26':('Coins',18000,None),'P27':('Coins',22000,None),'P28':('Level',100,None),'P29':('Coins',35000,None),'P30':('Coins',45000,None),
 'P31':('Coins',24000,None),'P32':('Level',75,None),'P33':('Coins',28000,None),'P34':('Wins',150,'TagYoureIt'),'P35':('Level',500,None),
 'M16':('Coins',12000,None),'M17':('Coins',22000,None),'M18':('Coins',15000,None),'M19':('Coins',13000,None),'M20':('Coins',20000,None),
 'M21':('Coins',18000,None),'M22':('Coins',16000,None),'M23':('Coins',30000,None),'M24':('Coins',35000,None),'M25':('Coins',40000,None),
}
colours={'B16':[232,213,163],'B17':[71,180,119],'B18':[232,170,75],'B19':[225,226,255],'B20':[121,181,93],'B21':[90,188,247],'B22':[250,196,57],'B23':[192,145,85],'B24':[217,122,204],'B25':[119,193,243],
 'P21':[89,170,239],'P22':[233,111,69],'P23':[223,210,248],'P24':[237,186,85],'P25':[254,225,157],'P26':[184,206,126],'P27':[109,184,108],'P28':[156,187,231],'P29':[187,150,118],'P30':[247,173,191],'P31':[224,177,87],'P32':[234,182,101],'P33':[155,113,200],'P34':[139,189,112],'P35':[249,170,55],
 'M16':[127,214,245],'M17':[93,162,229],'M18':[246,142,196],'M19':[255,216,85],'M20':[241,112,96],'M21':[240,180,73],'M22':[242,99,103],'M23':[234,94,93],'M24':[89,211,234],'M25':[237,126,105]}
changed=[]
def coins(m):
    changed.append((m.group(1),int(m.group(2)),int(m.group(2))*3))
    return m.group(1)+str(int(m.group(2))*3)
source,n1=re.subn(r'(item\("[BMP]\d\d"[^\n]+?"Coins", )(\d+)',coins,source)
source,n2=re.subn(r'(\{ id = "E\d\d"[^\n]+?kind = "Coins", amount = )(\d+)',coins,source)
assert n1==30 and n2==20,(n1,n2)
lines=[]
manifest=[]
for s in sorted(specs,key=lambda s:s['id']):
    id=s['id']; kind,amount,game=schedule[id]
    category={'B':'Bats','P':'Pets','M':'Toys'}[id[0]]
    slot={'B':'Bat','P':'Pet','M':'Gear'}[id[0]]
    desc=s['brief'].split('. ')[0]+'.'
    if slot=='Gear':desc='Lobby collectible. Own and equip this toy; its action is coming later.'
    fmt=lambda v:'nil' if v is None else json.dumps(v,ensure_ascii=False)
    args=[id,s['name'],category,slot,kind,amount,game,desc]
    lines.append('\titem('+', '.join(fmt(v) for v in args)+', {'+', '.join(map(str,colours[id]))+'}),')
    manifest.append(dict(id=id,name=s['name'],category=category,slot=slot,unlockKind=kind,amount=amount,gameId=game,price=amount if kind=='Coins' else 0,thumbnail=icons[id],toyActionPending=slot=='Gear'))
source=source.replace('\n}\n\nlocal emoteAnimations = {}','\n'+'\n'.join(lines)+'\n}\n\nlocal emoteAnimations = {}',1)
source=source.replace('local suppliedThumbnails = {','local suppliedThumbnails = {\n'+'\n'.join('\t["'+id+'"] = "'+url+'",' for id,url in sorted(icons.items())),1)
source=source.replace('(entry.slot == "Emote" and 15000 or 10000)','50000')
source=source.replace('byId.M09.toyActionPending = true','byId.M09.toyActionPending = true\nfor index = 16, 25 do byId[string.format("M%02d", index)].toyActionPending = true end')
source=source.replace('MaxCoinPrice = 15000','MaxCoinPrice = 50000').replace('MaxEquipmentCoinPrice = 10000','MaxEquipmentCoinPrice = 50000')
source=source.replace('StarterBat = "B01",','StarterBat = "B01",\n\tPriceVersion = 20261007,')
(root/'After').mkdir(exist_ok=True)
(root/'After/PlaygroundCatalog.luau').write_text(source,encoding='utf-8')
(root/'ExpansionUnlocks.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(root/'PriceChanges.json').write_text(json.dumps(dict(existingCoinPricesTripled=n1+n2,equipment=n1,emotes=n2,changes=changed),indent=2),encoding='utf-8')
print('Prepared',len(manifest),'new items; tripled',n1+n2,'existing coin prices exactly once.')
