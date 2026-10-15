from pathlib import Path
import json,zipfile
base=Path(__file__).resolve().parent.parent
out=base/'RobloxImport'
interaction={b['id']:b for b in json.loads((base/'interaction-manifest.json').read_text(encoding='utf-8'))}
records=[];fixtures=[]
for i in range(1,39):
    p=out/f'SA{i:02d}_metadata.json';rec=json.loads(p.read_text(encoding='utf-8'))
    for b in rec['bodies']:b['angle']=interaction[b['id']]['angle']
    p.write_text(json.dumps(rec,indent=2),encoding='utf-8');records.append(rec)
    gltf=json.loads((out/rec['file']).read_text(encoding='utf-8'))
    fixtures.append({'id':rec['id'],'meshes':[n['name'] for n in gltf['nodes']]})
(out/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
sources={
 'MANIFEST_JSON':json.dumps(records,separators=(',',':')),
 'SERVER_SOURCE':(out/'SchoolInteraction.server.lua').read_text(encoding='utf-8'),
 'CLIENT_SOURCE':(out/'SchoolInteraction.client.lua').read_text(encoding='utf-8')}
installer='-- In Studio EDIT mode: select imported school model(s), paste this entire file into the Command Bar, and run.\n'
for k,v in sources.items():
    assert ']====]' not in v
    installer+=f'local {k} = [====[\n{v}\n]====]\n'
installer+=(base/'scripts'/'installer_body.lua').read_text(encoding='utf-8')
(out/'InstallSelectedAssets.lua').write_text(installer,encoding='utf-8')
(base/'scripts'/'setup-fixtures.json').write_text(json.dumps(fixtures),encoding='utf-8')
guide='''SCHOOL ASSETS — IMPORT AND INTERACTION GUIDE

School name: undecided. The boards use only your supplied bird symbol.

WHAT IS INCLUDED
38 detailed assets; 77 independently grouped bodies, including 45 pickup props and six door/lid hinges.
The Blender source keeps the individual modelling parts editable. The import files combine fixed detail by material, while preserving movable props as separate bodies.

START WITH ONE SMALL TEST
1. Extract the whole package to a folder. Keep each .gltf beside its .bin file and keep the textures folder with them.
2. Open a school test place in Roblox Studio. File > Import; start with SA09_Black_pencil_pink_eraser.gltf.
3. Use metre units, Merge Meshes OFF, Anchored ON, and import as a Model. Keep the original mesh names. You can leave upload-to-inventory off during the initial test.
4. Place the model above a table or floor. Select the complete imported Model in Explorer.
5. Open InstallSelectedAssets.lua, copy the complete contents, paste into Studio's Command Bar in Edit mode, and run once. This prepares only your selected imports and installs the shared interaction scripts.
6. Press Play. E / controller X / tap picks up a prop. Q / controller B / the Drop touch button releases it. E / tap opens a door or laptop lid.

Repeat for other assets. Prepare each copy before duplicating it. Keep Merge Meshes OFF: the setup needs the independent pieces and its three temporary reference markers, which it removes after setup.

MOVEMENT AND PHYSICS
The scripts weld each prop's detail together, add simple invisible collision shapes, and add pickup prompts. Pens and pencils fall under gravity from the start. Other props remain placed until first pickup; after dropping, they fall and tumble. In Properties, change a prepared pickup Model's InitialAnchored attribute to false if it should also fall immediately.
Pens inside pots are independent, so they can be removed or spill. Trays, the eraser, magnets, cups, kettle and instruments are separate bodies. Doors and the laptop lid use constrained hinges. Large furniture stays fixed by default.
The server checks pickup distance, line of sight and ownership; it releases carried items when a player dies or leaves. Items that reach the bottom of the map are returned to their starting point.
This is a pickup/drop starter system. Writing, erasing actual board strokes, playing musical notes, cup contents, seat interaction and custom hand animations are separate gameplay features.

COLOUR AND TEXTURES
The import copies include baked PNG colour, normal and metallic/roughness maps. Keep imported MeshPart colours white so they do not tint the textures. Roblox lighting may differ from the Blender previews. If Studio misses a texture, inspect the imported SurfaceAppearance and the neighbouring textures folder. The bird symbol uses transparency.
Procedural source materials remain editable in the .blend; the export uses shared baked surface samples, so grain placement is approximate. No school-name text is added.

VERIFICATION AND LIMITS
All 38 files were checked for their binary data, texture references, one material per mesh, UV coordinates and maximum 18,000 triangles per individual mesh. Exported stationery, boards and staff seating were reimported and rendered successfully in Blender.
The scripts compile in Luau and the setup is checked with temporary fixtures. The imported assets and pickup controls have not yet been play-tested in your school place. Check hinge direction, hand position, collision size and colour in that first small test before adding the full library.
Collision shapes are simplified deliberately; large furniture uses broad collision volumes. Fine collision fitting and lower-detail variants can be adjusted after gameplay review. Detailed source models are preserved.

OFFICIAL REFERENCES
Importer: https://create.roblox.com/docs/studio/importer
Assemblies: https://create.roblox.com/docs/physics/assemblies
PBR appearance: https://create.roblox.com/docs/art/modeling/surface-appearance
'''
(out/'START-HERE.txt').write_text(guide,encoding='utf-8')
(base/'README.txt').write_text('SCHOOL ASSET LIBRARY — INTERACTIVE SOURCES 03\n\nOpen School_Asset_Library_v03.blend for the detailed, editable Blender models.\n38 assets, 77 rigid bodies, 45 pickup props and six hinges. Name undecided; supplied bird emblem only.\n\nRoblox import files, baked textures, setup scripts and instructions are in RobloxImport.\nRead RobloxImport/START-HERE.txt before importing.\nThe original v02 source is preserved.\nPreview renders are in renders, including portable-*.png rendered from exported files.\n',encoding='utf-8')
print('Installer and guide created',len(installer),'characters')
