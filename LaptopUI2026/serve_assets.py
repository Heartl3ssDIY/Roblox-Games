import http.server
import json
import pathlib
import shutil
import struct

root = pathlib.Path(__file__).resolve().parent
assets = json.loads((root / 'assets.json').read_text())
folder = root / 'images'
folder.mkdir(exist_ok=True)
for asset in assets:
    target = folder / asset['file']
    shutil.copy2(asset['source'], target)
    asset['width'], asset['height'] = struct.unpack('>II', target.read_bytes()[16:24])
(root / 'manifest.json').write_text(json.dumps(assets, indent=2))
handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(*args, directory=str(folder), **kwargs)
http.server.ThreadingHTTPServer(('127.0.0.1', 8766), handler).serve_forever()
