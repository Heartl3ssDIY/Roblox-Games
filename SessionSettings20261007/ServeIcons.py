from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

root = Path(__file__).parent.parent / 'PlaygroundClassics-SpectateSettings-20261007' / 'PNG-512'
routes = {'/settings.png': root / 'settings.png', '/spectate.png': root / 'spectate.png'}

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

ThreadingHTTPServer(('127.0.0.1', 8771), Handler).serve_forever()
