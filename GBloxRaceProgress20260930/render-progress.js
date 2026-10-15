const fs = require('fs');
const path = require('path');
const {pathToFileURL} = require('url');
const {chromium} = require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
async function main() {
 const browser = await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
 const page = await browser.newPage({viewport:{width:1248,height:832},deviceScaleFactor:1});
 const checks = [];
 for(const name of ['race-progress-wide','race-progress-compact','race-marker-states','G-Blox-race-progress-concept']) {
  await page.goto(pathToFileURL(path.join(__dirname,name+'.svg')).href);
  await page.evaluate(()=>document.fonts.ready);
  const size = await page.evaluate(()=>({width:document.documentElement.viewBox.baseVal.width,height:document.documentElement.viewBox.baseVal.height}));
  await page.setViewportSize(size);
  const check = await page.evaluate(()=>{
   const root = document.documentElement, v = root.viewBox.baseVal, ids = [...document.querySelectorAll('[id]')].map(e=>e.id);
   return {fontLoaded:document.fonts.check('12px GBloxPixel'),textNodes:document.querySelectorAll('text').length,rasterImages:document.querySelectorAll('image').length,groups:document.querySelectorAll('g').length,duplicateIds:ids.filter((id,i)=>ids.indexOf(id)!==i),xmlErrors:document.querySelectorAll('parsererror').length,overflow:[...document.querySelectorAll('text')].filter(t=>{let b=t.getBBox(),m=t.getCTM();let pts=[[b.x,b.y],[b.x+b.width,b.y+b.height]].map(([x,y])=>{const p=new DOMPoint(x,y).matrixTransform(m);return p;});return pts.some(p=>p.x<-.5||p.y<-.5||p.x>v.width+.5||p.y>v.height+.5);}).map(t=>t.textContent)};
  });
  await page.locator('svg').screenshot({path:path.join(__dirname,name+'.png'),omitBackground:true});
  checks.push({name,...size,...check});
 }
 await browser.close();
 fs.writeFileSync(path.join(__dirname,'validation.json'),JSON.stringify(checks,null,2));
 console.log(JSON.stringify(checks,null,2));
 if(checks.some(c=>!c.fontLoaded||c.rasterImages||c.duplicateIds.length||c.xmlErrors||c.overflow.length)) process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exit(1)});
