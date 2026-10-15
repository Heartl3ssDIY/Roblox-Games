const http = require('http');
const fs = require('fs');
const root = 'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/G-Blox/';
const files = {
 'gold-ring.png':'Player-NOVA---92-percent-37.png',
 'gold-badge.png':'Rank-badge-1-35.png',
 'silver-ring.png':'Player-JUNO---78-percent-32.png',
 'silver-badge.png':'Rank-badge-2-30.png',
 'bronze-ring.png':'Player pos. race progress 3rd.png',
 'bronze-badge.png':'Rank-badge-3rd.png',
 'you-badge.png':'Rank-badge-YOUR Position.png',
 'you-label.png':'Editable-label-YOU-26.png',
 'you-ring.png':'Avatar-slot-YOU-25.png',
 'other-ring.png':'Player label.png',
 'other-badge.png':'Rank-badge-6-9.png',
 'start.png':'START.png',
 'finish.png':'FINISH.png',
 'flag.png':'Finish-flag-5.png',
 'track.png':'Track---start-to-finish-4.png',
 'fill.png':'Editable-local-progress-fill---62-percent-2.png'
};
http.createServer((req,res)=>{
 const key = req.url.slice(1);
 const file = files[key];
 if(req.method!=='GET' || !file) { res.writeHead(404); res.end(); return; }
 fs.readFile(root+file,(error,data)=>{
  if(error){res.writeHead(404);res.end();return;}
  res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'no-store'});
  res.end(data);
 });
}).listen(8893,'127.0.0.1',()=>console.log('Serving only the 16 supplied race HUD assets on port 8893'));
