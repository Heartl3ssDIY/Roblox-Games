import json
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'SchoolAssetLibrary' / 'RobloxImport'
out = Path(__file__).resolve().parent
colors = dict(black='24292F', rubber='121519', sand='B69B80', ivory='D1C3AB', taupe='8E7B6E', clay='AC7E6C', fabric='B7A087', fabricdark='756357', wood='705039', woodlight='B58A59', pink='CC788C', metal='A0AAB0', brass='A98A48', white='EAE8DF', leaf='31513A', leaflight='5C7751', leafdark='253F2A', bark='664530', soil='33271E', thread='776354', seam='51483F', ceramic='D6C7AF', silver='C5CDCF', endgrain='89653E', screen='17232F', board='F3F0E6')
metadata = {}
for asset in json.loads((root / 'manifest.json').read_text()):
    if asset['id'] == 'SA11':
        continue
    gltf = json.loads((root / asset['file']).read_text())
    meshes = {}
    for node in gltf['nodes']:
        if 'mesh' not in node or '_REF_' in node['name']:
            continue
        mesh = gltf['meshes'][node['mesh']]
        material = gltf['materials'][mesh['primitives'][0]['material']]
        material_name = material['name']
        if material_name == 'Supplied white bird emblem':
            meshes[node['name']] = {'preserve': True, 'name': material_name}
        else:
            index = material['pbrMetallicRoughness']['baseColorTexture']['index']
            uri = gltf['images'][gltf['textures'][index]['source']]['uri']
            key = Path(uri).stem.removesuffix('_Color')
            h = colors[key]
            meshes[node['name']] = {'rgb': [int(h[i:i+2], 16) for i in (0, 2, 4)], 'name': material_name}
    metadata[asset['id']] = {'name': asset['name'], 'meshes': meshes, 'eligible': asset['id'] in ['SA01','SA02','SA03','SA04','SA05','SA06','SA07','SA08','SA18','SA19','SA31','SA32','SA34']}
(out / 'StyleMetadata.json').write_text(json.dumps(metadata, indent=2))
body = (out / 'BuildSchoolAssets.body.luau').read_text()
(out / 'BuildSchoolAssets.luau').write_text('local metadata = game:GetService("HttpService"):JSONDecode([====[' + json.dumps(metadata, separators=(',', ':')) + ']====])\n' + body)
print('Prepared', len(metadata), 'assets,', sum(x['eligible'] for x in metadata.values()), 'morphs')
