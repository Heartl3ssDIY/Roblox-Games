import sys,json,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Source'))
from build_pack import build_one,REF
catalog=json.loads((REF/'Source'/'Catalog.json').read_text(encoding='utf-8-sig'))
for spec in catalog:
    if spec['id']=='B01':build_one(spec,render=False)
runpy.run_path(str(ROOT/'Source'/'validate_pack.py'),run_name='__main__')
runpy.run_path(str(ROOT/'Source'/'build_library.py'),run_name='__main__')
sys.argv=['review_views.py']
runpy.run_path(str(ROOT/'Source'/'review_views.py'),run_name='__main__')
print('FINALIZE_COMPLETE',flush=True)
