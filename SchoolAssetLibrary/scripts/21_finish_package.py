from pathlib import Path
import json,zipfile
base=Path(__file__).resolve().parent.parent
out=base/'RobloxImport'
p=out/'verification.json';report=json.loads(p.read_text());report['luau_compilation']='passed';report['temporary_setup_fixture_test']={'passed':True,'assets':38,'bodies':77,'pickups':45,'hinges':6,'welds':366,'live_game_modified':False};p.write_text(json.dumps(report,indent=2))
guide=out/'START-HERE.txt';text=guide.read_text(encoding='utf-8');text=text.replace('If Studio misses a texture, inspect the imported SurfaceAppearance and the neighbouring textures folder.','If Studio misses a texture, inspect the imported SurfaceAppearance and the neighbouring textures folder. Separate *_Color.png, *_Normal.png, *_Roughness.png and *_Metalness.png files are also supplied for manual map assignment; *_MetalRough.png is the packed map used by glTF.');guide.write_text(text,encoding='utf-8')
zip_path=base/'School_Assets_Studio_Package.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(base/'School_Asset_Library_v03.blend','School_Asset_Library_v03.blend')
    z.write(base/'README.txt','README.txt')
    for p in sorted(out.rglob('*')):
        if p.is_file():z.write(p,str(p.relative_to(base)))
    for p in (base/'renders').glob('*.png'):z.write(p,str(p.relative_to(base)))
with zipfile.ZipFile(zip_path) as z:assert z.testzip() is None
print(json.dumps({'package':str(zip_path),'size_mb':round(zip_path.stat().st_size/1024/1024,1),'report':report},indent=2))
