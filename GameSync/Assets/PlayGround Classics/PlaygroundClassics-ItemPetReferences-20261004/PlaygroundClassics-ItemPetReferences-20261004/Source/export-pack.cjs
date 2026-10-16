const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..');
const catalog=fs.readFileSync(path.join(root,'Source/Catalog.jsonl'),'utf8').split(/\r?\n/).filter(x=>x.trim()).map(JSON.parse);
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
const mkdir=p=>fs.mkdirSync(p,{recursive:true});
const csv=v=>'"'+String(v??'').replace(/"/g,'""')+'"';
function alphaBounds(data,w,h,threshold=8){let x0=w,y0=h,x1=-1,y1=-1,count=0,min=255,max=0,edge=0;for(let y=0;y<h;y++)for(let x=0;x<w;x++){const a=data[(y*w+x)*4+3];min=Math.min(min,a);max=Math.max(max,a);if(a>threshold){count++;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);if(x===0||y===0||x===w-1||y===h-1)edge++;}}return {left:x0,top:y0,width:x1-x0+1,height:y1-y0+1,minAlpha:min,maxAlpha:max,subjectPixels:count,edgePixels:edge};}
async function silhouette(input,output){const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});const original=Buffer.from(data);for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){const i=(y*info.width+x)*4;data[i]=21;data[i+1]=33;data[i+2]=51;if(original[i+3]>8&&x>0&&y>0&&x<info.width-1&&y<info.height-1){let interior=true;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)if(original[((y+dy)*info.width+x+dx)*4+3]<=8)interior=false;if(interior)data[i+3]=255;}}await sharp(data,{raw:{width:info.width,height:info.height,channels:4}}).png().toFile(output);}
async function sheet(items,out,sil=false){
 const cols=5,cw=240,ch=274,head=75,rows=Math.ceil(items.length/cols),w=cols*cw,h=head+rows*ch+20;
 let svg='<svg width="'+w+'" height="'+h+'" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#eaf0f5"/><text x="25" y="35" font-family="Arial" font-size="24" font-weight="bold" fill="#152133">'+esc(items[0]?.category||'Assets')+(sil?' | index silhouettes':' | reference gallery')+'</text><text x="25" y="58" font-family="Arial" font-size="14" fill="#536577">PNG artwork has a transparent background. Names appear only on this overview.</text>';
 const comps=[];
 for(let i=0;i<items.length;i++){const a=items[i],x=(i%cols)*cw,y=head+Math.floor(i/cols)*ch;svg+='<rect x="'+(x+8)+'" y="'+(y+5)+'" width="224" height="259" rx="16" fill="#fff" stroke="#c7d4de"/><text x="'+(x+cw/2)+'" y="'+(y+238)+'" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#152133">'+esc(a.id+' '+a.name)+'</text><text x="'+(x+cw/2)+'" y="'+(y+257)+'" text-anchor="middle" font-family="Arial" font-size="11" fill="#697b89">'+esc(a.tier||a.category)+'</text>';comps.push({input:await sharp(path.join(root,a.category,sil?'Silhouettes-256':'UI-256',a.slug+'.png')).resize(210,210).toBuffer(),left:x+15,top:y+12});}
 svg+='</svg>';await sharp(Buffer.from(svg)).composite(comps).png().toFile(out);
}
(async()=>{
 const report=[],present=[];
 for(const a of catalog){
  const dir=path.join(root,a.category),src=path.join(dir,'Originals',a.slug+'.png');
  if(!fs.existsSync(src))continue;
  const {data,info}=await sharp(src).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const bounds=alphaBounds(data,info.width,info.height);if(bounds.minAlpha!==0||bounds.maxAlpha===0)throw Error('Transparency invalid: '+a.id);
  const crop={left:bounds.left,top:bounds.top,width:bounds.width,height:bounds.height};
  for(const size of [512,256]){
   const sub='UI-'+size;mkdir(path.join(dir,sub));
   const inside=Math.round(size*.88),pad=Math.floor((size-inside)/2);
   const resized=await sharp(src).extract(crop).resize(inside,inside,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).extend({top:pad,bottom:size-inside-pad,left:pad,right:size-inside-pad,background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer();
   await sharp(resized).png().toFile(path.join(dir,sub,a.slug+'.png'));
   if(a.category==='Pets'){mkdir(path.join(dir,'Silhouettes-'+size));await silhouette(resized,path.join(dir,'Silhouettes-'+size,a.slug+'.png'));}
  }
  if(a.category==='Pets'){mkdir(path.join(dir,'Silhouettes-Originals'));await silhouette(src,path.join(dir,'Silhouettes-Originals',a.slug+'.png'));}
  a.status="generated";a.reference=a.category+"/Originals/"+a.slug+".png";report.push({id:a.id,width:info.width,height:info.height,...bounds});present.push(a);
 }
 for(const cat of [...new Set(present.map(a=>a.category))]){
  const items=present.filter(a=>a.category===cat),dir=path.join(root,cat);
  await sheet(items,path.join(dir,'Contact-Sheet.png'));
  if(cat==='Pets')await sheet(items,path.join(dir,'Index-Silhouettes.png'),true);
  fs.writeFileSync(path.join(dir,'Catalogue.csv'),['ID,Name,Theme,PNG,Design brief',...items.map(a=>[a.id,a.name,a.tier,'Originals/'+a.slug+'.png',a.brief].map(csv).join(','))].join('\r\n'));
  let brief='PLAYGROUND CLASSICS / '+cat.toUpperCase()+'\r\n\r\n'+
  'HAND THIS WHOLE FOLDER TO THE BLENDER CHAT.\r\n'+
  'Create game-ready stylised models using the Originals PNGs as the visual reference. Each PNG is one distinct asset. Contact-Sheet.png is an overview, not a texture atlas. UI-512 and UI-256 are transparent shop icons of the same designs.\r\n\r\n'+
  'VISUAL DIRECTION\r\nChunky toy proportions, rounded bevels, broad glossy colour zones, deep navy seams and collars, cream inset panels and bold silhouettes. Build attached decorations as robust forms. Avoid tiny text, thin loose ornaments, photorealistic grunge or detached glow effects. Use the picture as the final visual reference if it differs slightly from the written concept.\r\n\r\n'+
  'MODELLING HANDOFF\r\nThese are single-view concept images, not measured turnarounds or existing 3D models. Infer unseen sides simply and consistently. Match the overall silhouette and visible colour blocking first. Keep materials reusable. Establish scale, pivot, triangle budget, collision and attachments in the Blender/game implementation chat before export. Bats need a handle grip pivot; other item pivots depend on their use. No gameplay or claim rules are implemented in these PNGs.\r\n\r\n'+
  'ROBLOX UI\r\nUse the square UI exports with ScaleType Fit and a square UIAspectRatioConstraint, or retain the square aspect ratio yourself. Do not stretch them to fill a rectangular slot. Background transparency is already included. Do not bake item names, prices or counts into the artwork.\r\n\r\n';
  if(cat==='Event-Bats')brief+='EVENT RULE\r\nBirthday Wish is a player-birthday claim concept, NOT a game-anniversary reward. All six event bats are additional to the 15 core bats. Entitlement checking belongs in game logic.\r\n\r\n';
  if(cat==='Event-Decorations')brief+='EVENT SCOPE\r\nTwo props each for Halloween, St Patrick’s Day, Lunar New Year, Christmas, Easter and birthdays. These are additional to the core miscellaneous items.\r\n\r\n';
  if(cat==='Pets')brief+='INDEX SILHOUETTES\r\nSilhouettes-Originals, Silhouettes-512 and Silhouettes-256 use the same outline and pose as the corresponding colour image, with solid dark interiors and antialiased boundary pixels. Match files by their ID/filename. Do not re-model a silhouette as a separate pet. The dark fill is RGB 21,33,51.\r\n\r\n';
  brief+='ASSETS\r\n'+items.map(a=>a.id+' / '+a.name+(a.tier?' / '+a.tier:'')+'\r\n'+a.brief+(a.unlockNote?'\r\n'+a.unlockNote:'')+'\r\n').join('\r\n');
  fs.writeFileSync(path.join(dir,'Modelling-Brief.txt'),brief);
 }
 mkdir(path.join(root,'Previews'));
 fs.writeFileSync(path.join(root,'Source/Validation.json'),JSON.stringify({expected:catalog.length,exported:present.length,missing:catalog.filter(a=>!present.includes(a)).map(a=>a.id),assets:report},null,2));
 fs.writeFileSync(path.join(root,'Source/Catalog.json'),JSON.stringify(catalog,null,2));
 const title='Playground Classics — Items & Pets';
 let html='<!doctype html><html><head><meta charset="utf-8"><title>'+title+'</title><style>body{margin:0;padding:40px;background:#111c30;color:#eef5ff;font:16px Arial}h1{font-size:34px}h2{margin-top:38px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:14px}.card{background:#eaf0f5;color:#17253b;border-radius:18px;padding:12px;text-align:center}.card img{width:100%;aspect-ratio:1;object-fit:contain}.card p{margin:6px}a{color:inherit}.note{color:#aebed1;max-width:850px;line-height:1.6}</style></head><body><h1>'+title+'</h1><p class="note">'+present.length+' full-colour designs. Transparent PNGs for shop UI and single-view Blender references. Each category includes a modelling brief, overview and 512/256 pixel exports. Pet silhouettes match the outlines and placement of their colour counterparts.</p>';
 for(const cat of [...new Set(present.map(a=>a.category))]){html+='<h2>'+cat+'</h2><div class="grid">';for(const a of present.filter(a=>a.category===cat)){html+='<div class="card"><a href="'+cat+'/Originals/'+a.slug+'.png"><img src="'+cat+'/UI-256/'+a.slug+'.png"></a><p><b>'+esc(a.id+' '+a.name)+'</b></p><small>'+esc(a.tier||'')+'</small></div>';}html+='</div>';}
 html+='</body></html>';fs.writeFileSync(path.join(root,'Gallery.html'),html);
 fs.writeFileSync(path.join(root,'START-HERE.txt'),'PLAYGROUND CLASSICS: ITEMS AND PETS\r\n\r\nOpen Gallery.html or the category Contact-Sheet.png files to browse.\r\nGive any entire category folder (or its matching ZIP) to your Blender chat. Each folder is self-contained.\r\n\r\nContents: 15 core baseball bats; 6 additional event bats; 15 miscellaneous items; 12 event decorations; 20 pets plus 20 exact matching index silhouettes.\r\nOriginals are the large transparent modelling references. UI-512 and UI-256 are the corresponding square shop icon exports. Names, prices and stats are not baked into the individual art. No 3D models are included.\r\n\r\nBirthday bat: player birthday, not game anniversary. Other rarity/theme labels are suggestions, not implemented unlock logic.\r\n\r\nAll subjects are concepts with a single three-quarter view. Unseen sides and production mesh details are left for the modelling step.\r\n');
 console.log(JSON.stringify({exported:present.length,total:catalog.length,edgeWarnings:report.filter(x=>x.edgePixels>0).map(x=>x.id)}));
})().catch(e=>{console.error(e);process.exit(1)});
