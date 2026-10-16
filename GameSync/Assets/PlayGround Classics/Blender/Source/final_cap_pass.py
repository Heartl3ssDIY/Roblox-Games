import sys,json,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from build_pack import build_one,REF
catalog=json.loads((REF/'Source'/'Catalog.json').read_text(encoding='utf-8-sig'))
for spec in catalog:
    if spec['id']in('B06','E06'):build_one(spec,render=False)
sys.argv=['validate_pack.py','--','B06','E06']
runpy.run_path(str(ROOT/'Source'/'validate_pack.py'),run_name='__main__')
runpy.run_path(str(ROOT/'Source'/'build_library.py'),run_name='__main__')
sys.argv=['render_final_previews.py','--','B06','E06']
runpy.run_path(str(ROOT/'Source'/'render_final_previews.py'),run_name='__main__')
print('CAP_PASS_COMPLETE',flush=True)
