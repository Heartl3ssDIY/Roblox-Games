import json,zipfile,xml.etree.ElementTree as E
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];NS='{http://www.w3.org/2000/svg}'
manifest=json.loads((ROOT/'Maps/AssetManifest.json').read_text(encoding='utf-8-sig'))
report={'blankArtwork':0,'optionalLabelledButtons':0,'directImportSVGs':0,'transparentVisiblePNGs':0,'errors':[],'liveFigmaImportTested':False}
for a in manifest['assets']:
 r=E.parse(ROOT/a['svg']).getroot()
 if a['category']=='OptionalLabels':report['optionalLabelledButtons']+=1
 else:
  report['blankArtwork']+=1
  if list(r.iter(NS+'text')) or list(r.iter(NS+'image')):report['errors'].append('Unexpected content: '+a['svg'])
 figma=E.parse(ROOT/a['figma']).getroot();report['directImportSVGs']+=1
 if list(figma.iter(NS+'text')) or any('font-family' in n.attrib for n in figma.iter()):report['errors'].append('Font dependency: '+a['figma'])
 ids=[n.get('id') for n in figma.iter() if n.get('id')]
 if len(ids)!=len(set(ids)):report['errors'].append('Duplicate IDs: '+a['figma'])
 with Image.open(ROOT/a['png']) as im:
  if list(im.size)!=a['pixelSize']:report['errors'].append('Wrong dimensions: '+a['png'])
  low,high=im.getchannel('A').getextrema()
  if low!=0 or high==0:report['errors'].append('Alpha or empty image: '+a['png'])
  else:report['transparentVisiblePNGs']+=1
report['passed']=not report['errors'];(ROOT/'Maps/Final-Checks.json').write_text(json.dumps(report,indent=2));assert report['passed'],report['errors']
(ROOT/'START-HERE.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Clean UI Import</title><style>body{font:17px system-ui;background:#242b43;color:white;margin:40px auto;padding:0 24px;max-width:1100px}p{color:#d0deef;line-height:1.6}a{color:#a9e1ff}nav{display:flex;flex-wrap:wrap;gap:20px;margin:25px 0}img{width:100%;border-radius:16px}section{margin:36px 0}</style><h1>Clean UI parts, ready to import</h1><p>Empty backgrounds and frames, with the favourite labelled buttons kept separately. No portraits, sample counters, item models or complete screens.</p><nav><a href="Figma-DragDrop/">Figma: drag these SVGs into your canvas</a><a href="PNG/">Transparent PNGs</a><a href="START-HERE.txt">Import notes</a></nav><p>No developer mode or plugin needed. Fixed lettering in Figma-DragDrop is vector artwork, not typeable text. Use a blank button when you want to add your own editable text.</p><section><h2>Empty parts</h2><img src="Clean-Parts-Preview.png" alt="Empty UI parts"></section><section><h2>Optional labelled buttons</h2><img src="Labelled-Buttons-Preview.png" alt="Centred outlined button lettering"></section><p>The grey preview backgrounds are not included in individual assets. Files were checked locally; a live Figma import has not been tested.</p></html>''',encoding='utf-8')
archive=ROOT.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in ROOT.rglob('*'):
  if f.is_file() and 'fontcache' not in f.parts:z.write(f,ROOT.name+'/'+f.relative_to(ROOT).as_posix())
print(json.dumps({'checks':report,'zip':str(archive),'bytes':archive.stat().st_size}))
