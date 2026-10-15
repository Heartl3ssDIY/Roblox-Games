from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

root = Path(__file__).parent.parent.parent / 'LobbyRepairs20261007' / 'FishingBoostIcons'
routes = {'/coins.png': root / 'boost-2x-coins.png', '/xp.png': root / 'boost-2x-xp.png'}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = routes.get(self.path)
        if path is None:
            self.send_error(404)
            return
        content = path.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'image/png')
        self.send_header('Content-Length', str(len(content)))
        self.end_headers()
        self.wfile.write(content)
    def log_message(self, *args):
        pass

ThreadingHTTPServer(('127.0.0.1', 8773), Handler).serve_forever()

