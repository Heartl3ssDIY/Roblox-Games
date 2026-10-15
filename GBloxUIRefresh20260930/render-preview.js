const fs=require('fs');
const path=require('path');
const {pathToFileURL}=require('url');
const {chromium}=require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
async function main(){
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const page=await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:1});
 const outputs=[];
 for(const name of ['shop-desktop','inventory-desktop','shop-phone','inventory-phone','ui-kit']){
  await page.goto(pathToFileURL(path.join(__dirname,name+'.svg')).href);
  await page.evaluate(()=>document.fonts.ready);
  const bounds=await page.locator('svg').boundingBox();
  await page.setViewportSize({width:Math.ceil(bounds.width),height:Math.ceil(bounds.height)});
  const check=await page.evaluate(()=>({font:document.fonts.check('12px GBloxPixel'),texts:document.querySelectorAll('text').length,images:document.querySelectorAll('image').length,invalidText:[...document.querySelectorAll('text')].filter(t=>{const b=t.getBBox();const s=document.documentElement.viewBox.baseVal;return b.x<0||b.y<0||b.x+b.width>s.width+1||b.y+b.height>s.height+1}).map(t=>t.textContent)}));
  await page.locator('svg').screenshot({path:path.join(__dirname,name+'.png')});
  outputs.push({name,...check});
 }
 await browser.close();
 const shop=await sharp(path.join(__dirname,'shop-desktop.png')).resize(1008,630).toBuffer();
 const inv=await sharp(path.join(__dirname,'inventory-desktop.png')).resize(1008,630).toBuffer();
 const p1=await sharp(path.join(__dirname,'shop-phone.png')).resize(1008).toBuffer();
 const p2=await sharp(path.join(__dirname,'inventory-phone.png')).resize(1008).toBuffer();
 await sharp({create:{width:2056,height:1144,channels:3,background:'#04101B'}}).composite([{input:shop,left:12,top:12},{input:inv,left:1036,top:12},{input:p1,left:12,top:660},{input:p2,left:1036,top:660}]).png().toFile(path.join(__dirname,'G-Blox-UI-preview.png'));
 fs.writeFileSync(path.join(__dirname,'validation.json'),JSON.stringify(outputs,null,2));
 console.log(JSON.stringify(outputs));
}
main().catch(e=>{console.error(e);process.exit(1)});
