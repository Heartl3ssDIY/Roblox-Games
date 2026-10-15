const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'Previews');
fs.mkdirSync(out,{recursive:true});
const fontDir='C:/Users/sandt/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts';
const conf=path.join(out,'Fonts.conf'),cache=path.join(out,'fontcache');fs.mkdirSync(cache,{recursive:true});
fs.writeFileSync(conf,'<fontconfig><dir>'+fontDir+'</dir><dir>C:/Windows/Fonts</dir><cachedir>'+cache.replaceAll('\\','/')+'</cachedir></fontconfig>');
if(!process.argv.includes('--configured')){
 const r=require('child_process').spawnSync(process.execPath,[__filename,'--configured'],{env:{...process.env,FONTCONFIG_FILE:conf,FONTCONFIG_PATH:out,XDG_CACHE_HOME:cache},stdio:'inherit'});
 process.exit(r.status===null?1:r.status);
}
const sharp=require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'SVGManifest.json'),'utf8'));
const all=manifest.files.map(f=>f.file).concat(['Icons/sprint-lightning.svg','Icons/dodge-swoosh.svg','Icons/level-star.svg']);
async function main(){
 const rows=[];
 for(let i=0;i<all.length;i+=6){
  const part=await Promise.all(all.slice(i,i+6).map(async f=>{
   const output=path.join(out,'Individual',f.replace(/\.svg$/,'.png'));fs.mkdirSync(path.dirname(output),{recursive:true});
   const info=await sharp(path.join(root,f)).png().toFile(output);return{file:f,width:info.width,height:info.height,bytes:info.size};
  }));rows.push(...part);
 }
 fs.writeFileSync(path.join(root,'RenderChecks.json'),JSON.stringify({rendered:rows.length,files:rows},null,2));
 if(fs.existsSync(path.join(root,'UI-Kit-Overview.svg'))) await sharp(path.join(root,'UI-Kit-Overview.svg')).resize({width:1800}).png().toFile(path.join(root,'UI-Kit-Overview.png'));
 const chosen=['Screens/BritishBulldog_Runner.svg','Screens/Tag_YoureIt.svg','Screens/Mud_MudGun.svg','Screens/BritishBulldog_Tagged.svg','Screens/Tag_Win.svg','Screens/Mud_BeingRescued.svg','Panels/PlaygroundShell/Shop_CompleteExpanded.svg','Panels/PlaygroundShell/VotePanel.svg','Panels/PlaygroundAdminPanel/Panel_AllGamesExpanded.svg','Panels/PlaygroundShell/LevelPanel.svg','Panels/MudHUD/ColourPicker.svg','Panels/PlaygroundShell/Shop_All12Items.svg'];
 const candidates=chosen.filter(f=>fs.existsSync(path.join(root,f)));
 const fallback=manifest.files.filter(f=>f.file.startsWith('Screens/')).map(f=>f.file);
 while(candidates.length<12){const f=fallback.shift();if(!f)break;if(!candidates.includes(f))candidates.push(f);}
 const tileW=500,tileH=342,cols=3,margin=22;const layers=[];
 for(let index=0;index<candidates.length;index++){
  const f=candidates[index],left=margin+(index%cols)*(tileW+margin),top=margin+Math.floor(index/cols)*(tileH+margin);
  const image=await sharp(path.join(root,f)).resize(tileW-20,tileH-50,{fit:'inside'}).png().toBuffer();
  const m=await sharp(image).metadata();layers.push({input:image,left:Math.round(left+(tileW-m.width)/2),top:Math.round(top+42+(tileH-50-m.height)/2)});
  const label='<svg width="'+tileW+'" height="34"><rect width="'+tileW+'" height="34" rx="8" fill="#18233e"/><text x="14" y="24" font-family="Arimo" font-size="17" fill="#ffffff">'+path.basename(f,'.svg').replaceAll('_',' ')+'</text></svg>';
  layers.push({input:Buffer.from(label),left,top});
 }
 const height=Math.ceil(candidates.length/cols)*(tileH+margin)+margin;
 await sharp({create:{width:cols*(tileW+margin)+margin,height,channels:4,background:'#e8eef3'}}).composite(layers).png().toFile(path.join(root,'UI-ContactSheet.png'));
 console.log(JSON.stringify({rendered:rows.length,contactSheet:candidates}));
}
main().catch(e=>{console.error(e);process.exitCode=1});

