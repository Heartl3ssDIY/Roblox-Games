from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import json

root = Path(__file__).resolve().parents[1]
package = root.parent / 'PlaygroundClassics-Reusable-UI.zip'
names = ['Playground-UI-Templates.svg', 'Playground-UI-Templates.png', 'TemplateReuseMap.json', 'README.txt']
validation = json.loads((root / 'Validation.json').read_text(encoding='utf-8'))
assert validation['valid'] and validation['templateCount'] == 11
with ZipFile(package, 'w', compression=ZIP_DEFLATED) as archive:
    for name in names:
        archive.write(root / name, arcname=name)
with ZipFile(package) as archive:
    assert archive.namelist() == names
    assert archive.testzip() is None
    assert sum(name.endswith('.svg') for name in archive.namelist()) == 1
    reuse = json.loads(archive.read('TemplateReuseMap.json'))
    assert reuse['templateCount'] == 11
    assert reuse['buttonMasterCount'] == 1
print(json.dumps({'zip': str(package), 'files': names, 'templates': 11, 'svgFiles': 1}))
