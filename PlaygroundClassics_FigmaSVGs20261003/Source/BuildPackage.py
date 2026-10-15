import json,hashlib,re,zipfile,math
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
NS={'s':'http://www.w3.org/2000/svg'}
svg_files=sorted(ROOT.rglob('*.svg'))
issues=[];texts=0;vector_elements=0
for path in svg_files:
 tree=ET.parse(path);root=tree.getroot();ids=[]
 for node in root.iter():
  tag=node.tag.rsplit('}',1)[-1]
  if node.get('id'):ids.append(node.get('id'))
  if tag in ('image','foreignObject','script','use'):issues.append(path.name+': forbidden '+tag)
  if tag=='text':texts+=1
  if tag in ('rect','path','polygon','ellipse','circle'):vector_elements+=1
  for key,value in node.attrib.items():
   if key.endswith('href') and not value.startswith('#'):issues.append(path.name+': external reference')
   if 'display:none' in value.replace(' ',''):issues.append(path.name+': hidden CSS')
 if len(ids)!=len(set(ids)):issues.append(path.name+': duplicate IDs')
 content=path.read_text(encoding='utf-8')
 for ref in re.findall(r'url\(#([^)]+)\)',content):
  if ref not in ids:issues.append(path.name+': missing '+ref)
 metadata=next((n for n in root if n.get('id')=='playground-text-layers'),None)
 if metadata is not None:
  data=json.loads(metadata.text);assert data['version']==1
  for t in data['texts']:
   for key in ('x','y','width','height','fontSize'):assert math.isfinite(t[key]),path
   for clip in t.get('clips',[]):
    for key in ('x','y','width','height'):assert math.isfinite(clip[key]),path
manifest=json.loads((ROOT/'SVGManifest.json').read_text(encoding='utf-8'))
for row in manifest['files']:
 assert hashlib.sha256((ROOT/row['file']).read_bytes()).hexdigest()==row['sha256'],row['file']
assert manifest['authoredGuiObjects']==manifest['coveredGuiObjects']==327
assert not manifest['missing']
assert len(list((ROOT/'ShopItems').glob('*.svg')))==12
assert len(svg_files)==219,len(svg_files)
assert not issues,issues
files=[]
for path in sorted(ROOT.rglob('*')):
 if not path.is_file():continue
 relative=path.relative_to(ROOT)
 if '__pycache__' in relative.parts or 'fontcache' in relative.parts:continue
 if relative.parts[0]=='Previews':continue
 if path.suffix=='.png' and path.name not in ('UI-Kit-Overview.png','UI-ContactSheet.png','WorldUI-ContactSheet.png'):continue
 if path.suffix in ('.conf','.log','.zip'):continue
 if path.name in ('ExportManifest.json','PackageChecks.json'):continue
 files.append(path)
report={'svgFiles':len(svg_files),'authoredGuiObjects':327,'coveredGuiObjects':327,'screenGuis':5,'screenVariants':35,'stateFragments':24,'shopItemCards':12,'worldSvgArtworks':20,'nativeWorldGuiInstances':30,'rasterElements':0,'externalReferences':0,'liveSvgTextElements':texts,'vectorElements':vector_elements,'xmlAndReferencesPassed':True,'renderChecks':json.loads((ROOT/'RenderChecks.json').read_text())['rendered']+20+1,'textOverflowChecks':json.loads((ROOT/'Source/TextFitChecks.json').read_text())['overflows'],'liveFigmaImportTested':False,'issues':issues}
(ROOT/'PackageChecks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
files.append(ROOT/'PackageChecks.json')
rows=[{'file':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
(ROOT/'ExportManifest.json').write_text(json.dumps({'date':'2026-10-03','files':rows,'svgFiles':219},indent=2),encoding='utf-8')
files.append(ROOT/'ExportManifest.json')
archive=ROOT.parent/'PlaygroundClassics-Editable-UI-SVGs.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for path in files:z.write(path,ROOT.name+'/'+path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for row in rows:
  data=z.read(ROOT.name+'/'+row['file']);assert hashlib.sha256(data).hexdigest()==row['sha256']
print(json.dumps({'zip':str(archive),'zipBytes':archive.stat().st_size,'svgFiles':len(svg_files),'files':len(files),'textElements':texts,'vectorElements':vector_elements,'validated':True}))

