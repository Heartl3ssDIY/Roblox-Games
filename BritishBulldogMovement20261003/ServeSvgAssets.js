const http = require('http');
const fs = require('fs');
const path = require('path');
const folder = path.join(__dirname, 'png');
const port = Number(process.argv[2] || 8768);
http.createServer((request, response) => {
  const name = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname.slice(1));
  if (!/^[\w-]+\.png$/.test(name)) { response.writeHead(404); response.end(); return; }
  const file = path.join(folder, name);
  if (!fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(response);
}).listen(port, '127.0.0.1', () => process.stdout.write(`Assets available at http://127.0.0.1:${port}\n`));
