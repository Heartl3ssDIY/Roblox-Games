import functools
import http.server
import json
import os
from pathlib import Path

root = Path(__file__).resolve().parent

class Handler(http.server.SimpleHTTPRequestHandler):
    def list_directory(self, path):
        self.send_error(403)
        return None

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(root/'Upload')))
(root/'HttpServer.json').write_text(json.dumps({'pid': os.getpid(), 'port': server.server_port}), encoding='utf-8')
server.serve_forever()
