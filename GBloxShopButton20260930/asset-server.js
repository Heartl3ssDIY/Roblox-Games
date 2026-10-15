const http = require('http');
const fs = require('fs');
const file = 'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/G-Blox/Shop button.png';
http.createServer((req,res)=>{
 if(req.method!=='GET'||req.url!=='/shop-button.png'){res.writeHead(404);res.end();return;}
 fs.readFile(file,(err,data)=>{
  if(err){res.writeHead(404);res.end();return;}
  res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'no-store'});
  res.end(data);
 });
}).listen(8894,'127.0.0.1');
