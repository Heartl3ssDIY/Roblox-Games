import csv, hashlib, json
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OUTPUT=Path(__file__).resolve().parent
ROOT=OUTPUT.parent/'PlaygroundClassics-ExpansionReferences-20261005'
routes={}
records=[]
for category, expected in [('Bats',10),('Pets',15),('Miscellaneous',10)]:
    rows=list(csv.DictReader((ROOT/category/'Catalogue.csv').open(encoding='utf-8-sig')))
    assert len(rows)==expected
    for row in rows:
        path=ROOT/category/'UI-512'/Path(row['PNG']).name
        data=path.read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        route='/'+row['ID']+'.png'
        routes[route]=path
        records.append(dict(id=row['ID'],category=category,name=row['Name'],path=str(path),sha256=hashlib.sha256(data).hexdigest(),url='http://127.0.0.1:8772'+route))
(OUTPUT/'ExpansionIconSources.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path=routes.get(self.path)
        if path is None:
            self.send_error(404)
            return
        data=path.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type','image/png')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self,*args): pass
print('Serving 35 expansion UI-512 PNGs on 127.0.0.1:8772',flush=True)
ThreadingHTTPServer(('127.0.0.1',8772),Handler).serve_forever()
