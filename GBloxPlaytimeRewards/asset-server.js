const http = require('http');
const fs = require('fs');
const files = {
 '/clock.png': 'C:/Users/sandt/Downloads/Group 94.png',
 '/panel.png': 'C:/Users/sandt/Downloads/Daily rewards.png',
 '/cards-a.png': 'C:/Users/sandt/Downloads/Group 82.png',
 '/cards-b.png': 'C:/Users/sandt/Downloads/Group 83.png',
 '/claim.png': 'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/G-Blox/DailyRewardsUI/claim-small.png',
 '/claimed.png': 'C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/G-Blox/DailyRewardsUI/claimed.png',
};
http.createServer((req,res) => {
 const file = files[req.url];
 if (!file) { res.writeHead(404); res.end(); return; }
 res.writeHead(200, {'Content-Type':'image/png'});
 fs.createReadStream(file).pipe(res);
}).listen(8879, '127.0.0.1', () => console.log('Playtime art server on localhost:8879'));
