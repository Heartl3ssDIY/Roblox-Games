import csv, hashlib, json
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OUTPUT = Path(r"C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/Btns/EmoteWheel20261005")
ROOT = Path(r"C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/PlayGround Classics/PlaygroundClassics-ItemPetReferences-20261004/PlaygroundClassics-ItemPetReferences-20261004")
records = []
routes = {}
for category, expected in [("Bats", 15), ("Event-Bats", 6), ("Pets", 20), ("Miscellaneous", 15)]:
    with (ROOT / category / "Catalogue.csv").open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == expected
    for row in rows:
        path = ROOT / category / "UI-512" / Path(row["PNG"]).name
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        route = "/" + category + "/" + row["ID"] + ".png"
        routes[route] = path
        records.append(dict(key=category+"/"+row["ID"], category=category, id=row["ID"], name=row["Name"], path=str(path), sha256=hashlib.sha256(data).hexdigest(), url="http://127.0.0.1:8768"+route))
OUTPUT.mkdir(parents=True,exist_ok=True)
(OUTPUT/"IconSources.json").write_text(json.dumps(records, indent=2),encoding="utf-8")
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = routes.get(self.path)
        if path is None:
            self.send_error(404)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type","image/png")
        self.send_header("Content-Length",str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self,*args): pass
print("Serving exactly",len(routes),"original UI-512 PNGs on 127.0.0.1:8768",flush=True)
ThreadingHTTPServer(("127.0.0.1",8768),Handler).serve_forever()

