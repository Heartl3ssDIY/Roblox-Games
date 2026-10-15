const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');
const root = __dirname;
const preview = path.join(root, 'Preview');
fs.mkdirSync(preview, { recursive: true });
const versions = 'C:\\Users\\sandt\\AppData\\Local\\Roblox\\Versions';
const folders = ['C:/Windows/Fonts'];
for (const item of fs.readdirSync(versions, { withFileTypes: true })) {
  if (!item.isDirectory()) continue;
  const folder = path.join(versions, item.name, 'content', 'fonts');
  if (fs.existsSync(path.join(folder, 'LuckiestGuy-Regular.ttf'))) folders.push(folder.replaceAll('\\', '/'));
}
const config = path.join(preview, 'FontConfig.conf');
const cache = path.join(preview, 'fontcache').replaceAll('\\', '/');
fs.mkdirSync(cache, { recursive: true });
fs.writeFileSync(config, '<fontconfig>' + folders.map(folder => '<dir>' + folder + '</dir>').join('') + '<cachedir>' + cache + '</cachedir></fontconfig>');
if (!process.argv.includes('--configured')) {
  const result = childProcess.spawnSync(process.execPath, [__filename, '--configured'], {
    env: { ...process.env, FONTCONFIG_FILE: config, FONTCONFIG_PATH: preview, XDG_CACHE_HOME: cache },
    stdio: 'inherit'
  });
  if (result.error) throw result.error;
  process.exit(result.status === null ? 1 : result.status);
}
const sharp = require('C:\\Users\\sandt\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\sharp');
function escape(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
async function run() {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'WorldUIManifest.json'), 'utf8'));
  const cellW = 288, cellH = 224, columns = 5;
  const rows = Math.ceil(manifest.files.length / columns);
  const composites = [];
  const records = [];
  for (let index = 0; index < manifest.files.length; index += 1) {
    const file = manifest.files[index].file;
    const source = path.join(root, file);
    const destination = path.join(preview, file.replace('.svg', '.png'));
    await sharp(source).png().toFile(destination);
    const image = await sharp(destination).metadata();
    const thumb = await sharp(destination).resize(244, 144, { fit: 'contain', background: '#e5eff1' }).png().toBuffer();
    const x = (index % columns) * cellW, y = Math.floor(index / columns) * cellH;
    composites.push({ input: thumb, left: x + 22, top: y + 14 });
    const label = '<svg xmlns="http://www.w3.org/2000/svg" width="288" height="62"><text x="144" y="26" text-anchor="middle" font-family="Arial" font-size="12" fill="#18233e">' + escape(file.replace('.svg','')) + '</text><text x="144" y="45" text-anchor="middle" font-family="Arial" font-size="10" fill="#597077">' + image.width + ' × ' + image.height + '</text></svg>';
    composites.push({ input: Buffer.from(label), left: x, top: y + 164 });
    records.push({ file, width: image.width, height: image.height, preview: path.relative(root, destination) });
  }
  const sheet = path.join(root, 'WorldUI-ContactSheet.png');
  await sharp({create:{width:columns*cellW,height:rows*cellH,channels:4,background:'#e5eff1'}}).composite(composites).png().toFile(sheet);
  fs.writeFileSync(path.join(root, 'WorldUIRenderValidation.json'), JSON.stringify({renderer:'sharp/libvips',allRendered:true,svgCount:records.length,records,contactSheet:path.basename(sheet)}, null, 2) + '\n');
  console.log(JSON.stringify({rendered:records.length,contactSheet:sheet}));
}
run().catch(error => {console.error(error);process.exitCode=1;});

