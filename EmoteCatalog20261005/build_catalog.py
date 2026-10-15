from pathlib import Path
import json

root = Path(__file__).resolve().parent
assets = json.loads((root / 'Assets.json').read_text(encoding='utf-8-sig'))
costs = [500,750,1000,('Level',5),1500,('Level',8),None,2000,2500,('Level',12),5000,3000,('Level',16),3500,('Level',20),4000,('Level',25),6500,4500,5000,('Level',30),7500,10000,('Level',35),6000,('Level',40),8000,12500,9000,('Level',3),15000,('Level',50)]
names = ['Dougie','Street Glide','Money Hop Switch','Coffin Walkout','The Tylil Dance','Scuba Trend','Take The L','Rollie','Out West','Four Lokos Dance','Griddy','Gangstar Dance','Keep It Gangsta','Jabba Switchway','Billy Bounce','Jamal Brazil Groove','67','Orange Justice','Dab Steps','Creepin Dance','Nervy Dance','Pretty Young Thing','Party Rock Anthem','Passinho do Jamal','Camden Bop','Every Beat','One Hand Push Ups','Gangnam Style','Murda Bend','Monkey','NLE Choppa Demon','Brazilian Dance']
def q(s): return json.dumps(s, ensure_ascii=False)
rows, balance = [], []
for entry in assets:
    i = entry['index']
    if not entry['available'] or not entry['playable']:
        continue
    cost = costs[i-1]
    kind, amount = cost if isinstance(cost, tuple) else ('Coins', cost)
    id = f'E{i:02}'
    rows.append(f'\t{{ id = {q(id)}, name = {q(names[i-1])}, kind = {q(kind)}, amount = {amount}, catalogId = {entry["catalogId"]}, animationId = {entry["animationId"]} }},')
    balance.append({'id':id,'name':names[i-1],'unlock':kind,'amount':amount,'catalogId':entry['catalogId'],'animationId':entry['animationId']})
block = '''local emoteAnimations = {}
for _, dance in ipairs({
''' + '\n'.join(rows) + '''
}) do
	local description = "Dance in the lobby. Move or jump to stop. Equip for your winner podium."
	local entry = item(dance.id, dance.name, "Emotes", "Emote", dance.kind, dance.amount, nil, description, {120, 193, 244})
	entry.catalogId = dance.catalogId
	entry.thumbnail = "rbxthumb://type=Asset&id=" .. string.format("%.0f", dance.catalogId) .. "&w=420&h=420"
	entry.playable = true
	entry.rigType = "R15"
	emoteAnimations[dance.id] = { R15AnimationId = dance.animationId }
	table.insert(items, entry)
end

'''
s = (root / 'Before/PlaygroundCatalog.luau').read_text(encoding='utf-8-sig')
s = s.replace('local byId = {}',block+'local byId = {}',1)
s = s.replace('entry.price <= 10000', 'entry.price <= (entry.slot == "Emote" and 15000 or 10000)',1)
s = s.replace('EmoteAnimations = {},', 'EmoteAnimations = emoteAnimations,',1)
s = s.replace('MaxCoinPrice = 10000,', 'MaxCoinPrice = 15000,\n\tMaxEquipmentCoinPrice = 10000,',1)
(root / 'After/PlaygroundCatalog.luau').write_text(s, encoding='utf-8')
(root / 'EmoteUnlocks.json').write_text(json.dumps(balance,indent=2),encoding='utf-8')
print(f'{len(balance)} active emotes; {sum(x["unlock"]=="Coins" for x in balance)} coin purchases; disabled emotes omitted.')
