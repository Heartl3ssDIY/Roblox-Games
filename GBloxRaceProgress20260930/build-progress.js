const fs = require('fs');
const path = require('path');
const font = fs.readFileSync('C:/Users/sandt/AppData/Local/Roblox/Versions/version-02c37bc51a384b8f/content/fonts/PressStart2P-Regular.ttf').toString('base64');
const out = __dirname;
const C = { ink:'#061822',bg:'#071624',panel:'#0B2839',surface:'#143D50',line:'#35667A',cyan:'#00DAE2',ice:'#ACFAFF',white:'#F2FBFF',muted:'#A8C4D3',gold:'#FFD370' };
let serial = 0;
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
function group(label, body, attrs='') { return `<g id="${label.replace(/[^a-zA-Z0-9_-]/g,'-')}-${serial++}" ${attrs}><title>${esc(label)}</title>${body}</g>`; }
function rect(x,y,w,h,fill,stroke='none',r=8,sw=1) { return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`; }
function line(x1,y1,x2,y2,color,width=2,extra='') { return `<path d="M${x1} ${y1}L${x2} ${y2}" fill="none" stroke="${color}" stroke-width="${width}" ${extra}/>`; }
function text(label,x,y,size=12,color=C.white,anchor='start',extra='') { return `<text x="${x}" y="${y}" font-family="GBloxPixel, 'Press Start 2P', monospace" font-size="${size*1.65}" font-weight="400" fill="${color}" text-anchor="${anchor}" ${extra}>${esc(label)}</text>`; }
function pill(label,x,y,w,color=C.cyan,size=10,h=24) { return group('Editable label '+label,rect(x,y,w,h,C.ink,color,6,1.5)+text(label,x+w/2,y+h/2+size*.42,size,color,'middle')); }
function defs() { return `<defs><style>@font-face{font-family:GBloxPixel;src:url(data:font/ttf;base64,${font}) format('truetype')}text{font-family:GBloxPixel,'Press Start 2P',monospace}</style><linearGradient id="progress-fill" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#007F96"/><stop offset="1" stop-color="#00E3E5"/></linearGradient><linearGradient id="panel-gloss" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#17495E"/><stop offset="1" stop-color="#0B2839"/></linearGradient><pattern id="halftone" width="12" height="12" patternUnits="userSpaceOnUse"><circle cx="3" cy="3" r="1.4" fill="#62EAF0" opacity=".12"/></pattern></defs>`; }
function document(title,w,h,body) { return `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" role="img" aria-label="${esc(title)}"><title>${esc(title)}</title><desc>Editable G-Blox race HUD concept. Sample race data and fictional names. Avatar art is removable vector placeholder artwork, not a live ViewportFrame. Shapes, labels, progress fill and markers are separate named groups. No raster images.</desc>${defs()}${body}</svg>`; }
function flag(x,y,s=1,color=C.white) {
 let f=line(0,0,0,27,color,2.2)+`<path d="M2 1H22V17H2Z" fill="${color}"/>`;
 for(let row=0;row<2;row++) for(let col=0;col<4;col++) if((row+col)%2===0) f+=rect(2+col*5,1+row*8,5,8,C.ink,'none',0);
 return group('Finish flag',f,`transform="translate(${x} ${y}) scale(${s})"`);
}
function avatar(shirt,skin='#E5B986',hair='#263D51',hat=false) {
 let b=`<path d="M-24 28V18L-14 11H14L24 18V28Z" fill="${shirt}" stroke="${C.ink}" stroke-width="2.4"/><path d="M-14 12L-8 16H8L14 12M0 16V29" fill="none" stroke="#DDFBFF" stroke-width="2"/>`;
 b+=rect(-13,-18,26,31,skin,C.ink,5,2.3);
 if(hat) b+=`<path d="M-15-9V-19L-8-25H10L16-18V-9Z" fill="${hair}" stroke="${C.ink}" stroke-width="2.2"/><path d="M-18-9H17V-4H-18Z" fill="${hair}" stroke="${C.ink}" stroke-width="2"/><path d="M2-24V-10" stroke="${shirt}" stroke-width="3"/>`;
 else b+=`<path d="M-13-9V-18L-8-24H8L14-18V-7L8-12L4-11V-15L-3-12L-7-13L-10-8Z" fill="${hair}" stroke="${C.ink}" stroke-width="2"/>`;
 b+=rect(-7,-3,3,5,C.ink,'none',1)+rect(5,-3,3,5,C.ink,'none',1)+`<path d="M-4 5Q1 10 6 5" fill="none" stroke="${C.ink}" stroke-width="1.8" stroke-linecap="round"/>`;
 return b;
}
function portrait(name,x,y,r,color,shirt,rank,local=false,hat=false,skin,terminal='') {
 const clip='avatar-clip-'+serial++;
 const scale=(r-4)/27;
 let b=`<circle cx="${x}" cy="${y+3}" r="${r+3}" fill="${C.ink}"/>`;
 if(local) b+=`<circle cx="${x}" cy="${y}" r="${r+5}" fill="none" stroke="${C.cyan}" opacity=".2" stroke-width="4"/>`;
 b+=`<circle cx="${x}" cy="${y}" r="${r}" fill="${local?'#155767':'#23495D'}" stroke="${color}" stroke-width="${local?3:2}"/><defs><clipPath id="${clip}"><circle cx="${x}" cy="${y}" r="${r-3}"/></clipPath></defs>`;
 b+=group('REMOVE for live avatar - '+name,`<g clip-path="url(#${clip})"><g transform="translate(${x} ${y+1}) scale(${scale})">${avatar(shirt,skin,'#263D51',hat)}</g></g>`);
 if(rank) b+=group('Rank badge '+rank,`<circle cx="${x+r*.72}" cy="${y+r*.72}" r="${r*.41}" fill="${local?C.cyan:color}" stroke="${C.ink}" stroke-width="2"/>`+text(rank,x+r*.72,y+r*.72+4,r*.39,C.ink,'middle'));
 if(terminal==='finished') b+=flag(x+r-3,y-r-6,.65,C.gold);
 if(terminal==='out') b+=`<circle cx="${x}" cy="${y}" r="${r-2}" fill="${C.ink}" opacity=".45"/>`+line(x-8,y-8,x+8,y+8,C.white,3)+line(x+8,y-8,x-8,y+8,C.white,3);
 return group('Avatar slot '+name,b);
}
const players = [
 {name:'MILO',p:.11,rank:6,bottom:true,shirt:'#557C99',hat:true},
 {name:'AXEL',p:.29,rank:5,bottom:false,shirt:'#6096A2',skin:'#A67354'},
 {name:'RILEY',p:.56,rank:4,bottom:true,shirt:'#B3CCDC',hat:true},
 {name:'YOU',p:.62,rank:3,bottom:false,shirt:'#00CBD6',hat:true,local:true},
 {name:'JUNO',p:.78,rank:2,bottom:true,shirt:'#8C91B3',skin:'#B88060'},
 {name:'NOVA',p:.92,rank:1,bottom:false,shirt:'#D4B577',skin:'#D59B6B'}
];
function shell(w,h) {
 return group('Panel background',rect(3,9,w-6,h-12,C.ink,'none',18)+rect(3,3,w-6,h-12,'url(#panel-gloss)',C.cyan,18,2)+rect(w-184,7,160,29,'url(#halftone)','none',12)+line(25,40,w-25,40,C.line,1)+line(23,8,w-23,8,C.ice,1,'opacity=".16"'));
}
function track(left,right,y,h,progress=.62) {
 const w=right-left;
 let b=rect(left-5,y-5,w+10,h+10,C.ink,C.line,(h+10)/2,1.3)+rect(left,y,w,h,'#274252','none',h/2);
 b+=group('Editable local progress fill - 62 percent',rect(left,y,w*progress,h,'url(#progress-fill)','none',h/2)+line(left+7,y+3,left+w*progress-7,y+3,C.ice,1.4,'opacity=".6"'));
 let ticks='';
 for(let n=1;n<20;n++) ticks+=line(left+w*n/20,y+3,left+w*n/20,y+h-3,n%5===0?C.white:C.ice,n%5===0?2:1,`opacity="${n%5===0?.5:.15}"`);
 b+=group('Editable track ticks',ticks);
 return group('Track - start to finish',b);
}
function hud(compact=false) {
 const w=compact?680:1120,h=compact?220:288,left=compact?45:86,right=w-left,ty=compact?121:143,th=compact?14:18,top=compact?76:93,bottom=compact?173:213,r=compact?22:28;
 let b=shell(w,h);
 b+=group('Header labels',text('RACE PROGRESS',compact?22:27,28,compact?10:12,C.ice)+text('3RD / 6',compact?w-135:w-242,28,compact?10:12,C.white,'end')+text('62%',w-25,28,compact?12:14,C.cyan,'end')+(!compact?text('ROUND 3 / 5',w/2,28,11,C.muted,'middle'):''));
 b+=track(left,right,ty,th);
 b+=group('Endpoint labels',text('START',left,ty+th+24,compact?8:10,C.muted,'middle')+text('FINISH',right,ty+th+24,compact?8:10,C.white,'middle')+flag(right+17,ty-5,compact?.65:.8));
 for(const p of players) {
  const x=left+(right-left)*p.p,y=p.bottom?bottom:top,c=p.local?C.cyan:p.rank===1?C.gold:'#BCD7E3';
  let m=line(x,p.bottom?ty+th:y+r,x,p.bottom?y-r:ty,c,p.local?2.5:1.5,'opacity=".8"')+`<circle cx="${x}" cy="${ty+th/2}" r="${p.local?5:3.5}" fill="${c}" stroke="${C.ink}" stroke-width="1.5"/>`;
  m+=portrait(p.name,x,y,r,c,p.shirt,p.rank,p.local,p.hat,p.skin);
  if(p.local) m+=pill('YOU',x-(compact?24:29),y-r-(compact?20:25),compact?48:58,C.cyan,compact?8:10,compact?17:21);
  else if(!compact) m+=text(p.name,x,p.bottom?y+r+20:y-r-12,9,p.rank===1?C.gold:C.muted,'middle');
  b+=group('Player '+p.name+' - '+Math.round(p.p*100)+' percent',m,`data-progress="${p.p}"`);
 }
 return b;
}
function states() {
 let b=rect(0,0,382,218,C.panel,C.line,15,1.5)+text('MARKER STATES',22,31,12,C.ice);
 b+=portrait('Local example',65,91,27,C.cyan,C.cyan,3,true,true)+portrait('Finished example',191,91,27,C.gold,'#D4B577',1,false,false,undefined,'finished')+portrait('Eliminated example',317,91,27,'#6E8898','#577383',null,false,false,undefined,'out');
 b+=text('YOU',65,145,10,C.cyan,'middle')+text('FINISHED',191,145,9,C.gold,'middle')+text('OUT',317,145,10,C.muted,'middle');
 b+=text('Finished and OUT are separate states.',22,183,8,C.muted)+text('All avatar slots remain editable.',22,201,8,C.muted);
 return group('Editable marker states',b);
}
function preview() {
 let b=rect(0,0,1248,832,C.bg,'none',0)+`<path d="M915 0H1248V192Z" fill="#133D51" opacity=".5"/><path d="M0 695L475 832H0Z" fill="#0C3448"/>`;
 b+=text('G-BLOX',64,55,13,C.cyan)+text('RACE PROGRESS',64,99,30)+text('An at-a-glance view of the race. Your place. Your competition.',64,132,12,C.muted);
 b+=text('01 / WIDE HUD',64,183,11,C.ice)+text('Example: you are third, 62% through the course.',1184,183,10,C.muted,'end');
 b+=group('Wide HUD editable composition',hud(), 'transform="translate(64 205)"');
 b+=text('02 / COMPACT HUD',64,529,11,C.ice)+text('Same positions. Less text.',744,529,9,C.muted,'end');
 b+=group('Compact HUD editable composition',hud(true),'transform="translate(64 552)"');
 b+=group('Marker variants',states(),'transform="translate(802 552)"');
 b+=text('SVG CONCEPT / SAMPLE PLAYERS / NO LIVE GAME CHANGES',64,807,9,C.muted);
 return document('G-Blox race progress - editable design preview',1248,832,b);
}
const files = {
 'race-progress-wide.svg':document('G-Blox race progress - wide HUD',1120,288,hud()),
 'race-progress-compact.svg':document('G-Blox race progress - compact HUD',680,220,hud(true)),
 'race-marker-states.svg':document('G-Blox race marker states',382,218,states()),
 'G-Blox-race-progress-concept.svg':preview()
};
for(const [name,svg] of Object.entries(files)) fs.writeFileSync(path.join(out,name),svg);
fs.writeFileSync(path.join(out,'READ-ME.txt'),`G-BLOX / EDITABLE RACE PROGRESS CONCEPT

Open the SVGs in your vector editor. Everything is made from vector shapes,
separate named groups and live SVG text. No flattened bitmap is inside the SVG.
The PNGs are previews only. All names and race positions are examples.

FILES
race-progress-wide.svg       Main HUD, 1120 x 288
race-progress-compact.svg    Compact HUD, 680 x 220
race-marker-states.svg       Local / finished / eliminated examples
G-Blox-race-progress-concept.svg  Presentation sheet (also fully editable)

EDITING
The text uses Press Start 2P, matching the G-Blox pixel style. A font is embedded
for browser previews. Some editors do not import embedded web fonts: install or
select Press Start 2P if prompted. SVG is editable; this is not a native Figma
component library. Different editors can outline text during SVG import.

Each player has a named group and a removable avatar-art subgroup. Move the
player's position anchor along the track, then keep its avatar aligned above or
below that anchor. The cyan filled portion represents YOUR progress, not time.
The small number on a portrait is that player's current rank.

These drawings are avatar placeholders, not live ViewportFrames. The runtime
version would need native Roblox UI with each player's portrait/ViewportFrame
inserted into its slot. Preserve the editable StarterGui layouts when binding
behavior. Blender is not required for this 2D interface.

IMPLEMENTATION NOTES (not implemented in this mockup)
Measure validated progress along checkpoint/course segments, not raw world X:
the courses can change direction and height. Move all player anchors using the
same progress scale. Keep local-player emphasis and gently smooth visual motion.
Stagger nearby portraits vertically without falsifying their progress anchors;
larger clusters need additional stacking or a small grouped-count indicator.
Keep finished and eliminated racers visually distinct. Do not label OUT racers
as active. The compact version omits full names to preserve readability.

If animated character previews are added, use simple cached rigs with a reduced
update rate and a static portrait fallback. Do not duplicate maps into each slot.
This design does not require fully simulating six characters inside the HUD.

No Studio files were changed, no gameplay behavior was implemented, and nothing
was published by this design task.
`);
console.log(JSON.stringify({folder:out,files:Object.keys(files)},null,2));
