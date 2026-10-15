from pathlib import Path
import xml.etree.ElementTree as E
import json
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1];NS='http://www.w3.org/2000/svg';E.register_namespace('',NS)
fontfile=r'C:/Users/sandt/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts/LuckiestGuy-Regular.ttf'
checks=[]
for file in sorted((ROOT/'Editable/Optional-Labelled-Buttons').glob('*.svg')):
 root=E.parse(file).getroot();face=next(n for n in root.iter('{'+NS+'}rect') if n.get('id','').endswith('-Face'))
 fx,fy,w,h=[float(face.get(k)) for k in ('x','y','width','height')];target=(fx+w/2,fy+h/2);texts=list(root.iter('{'+NS+'}text'));bounds=[]
 for n in texts:
  font=ImageFont.truetype(fontfile,size=float(n.get('font-size')));text=''.join(n.itertext());b=font.getbbox(text,anchor='ls');advance=font.getlength(text);x=float(n.get('x'));y=float(n.get('y'))
  # Centre every line by the actual glyph ink, not font advance width.
  x=target[0]+advance/2-(b[0]+b[2])/2;n.set('x',str(x));bounds.append((y+b[1],y+b[3]))
 cy=(min(b[0] for b in bounds)+max(b[1] for b in bounds))/2;dy=target[1]-cy
 for n in texts:n.set('y',str(float(n.get('y'))+dy))
 for meta in list(root.findall('{'+NS+'}metadata')):root.remove(meta)
 rows=[]
 for i,n in enumerate(texts):
  font=ImageFont.truetype(fontfile,size=float(n.get('font-size')));s=''.join(n.itertext());b=font.getbbox(s,anchor='ls');advance=font.getlength(s);x=float(n.get('x'));y=float(n.get('y'))
  rows.append({'name':file.stem+'/Line'+str(i+1),'text':s,'x':x-advance/2,'y':y+b[1],'width':advance,'height':b[3]-b[1],'fontFamily':'Luckiest Guy','fontSize':float(n.get('font-size')),'color':n.get('fill'),'opacity':1,'strokeColor':n.get('stroke'),'strokeWidth':float(n.get('stroke-width')),'strokeOpacity':1,'align':'CENTER','clips':[],'rotation':0})
 meta=E.Element('{'+NS+'}metadata',id='playground-text-layers');meta.text=json.dumps({'version':1,'texts':rows});root.insert(0,meta)
 E.ElementTree(root).write(file,encoding='utf-8',xml_declaration=True)
 checks.append({'file':file.name,'verticalAdjustment':round(dy,4),'eachLineCentredByGlyphBounds':True,'textBlockCentredOnInnerFace':True})
for file in (ROOT/'Editable/04-Meter-Parts').glob('*fill.svg'):
 root=E.parse(file).getroot()
 for stop in root.iter('{'+NS+'}stop'):stop.set('stop-opacity','1')
 E.ElementTree(root).write(file,encoding='utf-8',xml_declaration=True)
settings=json.loads((ROOT/'Maps/NineSlice-original-settings.json').read_text())
for row in settings:row['png']='PNG/07-Resizable-Skins/'+Path(row['png']).name
(ROOT/'Maps/NineSlice-original-settings.json').write_text(json.dumps(settings,indent=2))
(ROOT/'Maps/Text-Centring-Checks.json').write_text(json.dumps(checks,indent=2))
print(json.dumps({'correctedLabelledButtons':len(checks),'maxVerticalCorrection':max(abs(c['verticalAdjustment']) for c in checks),'meterFills':'opaque full-length artwork'}))
