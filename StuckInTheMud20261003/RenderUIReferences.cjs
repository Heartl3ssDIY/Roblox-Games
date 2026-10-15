const fs = require('fs');
const path = require('path');
const output = path.join(__dirname, 'Temp');
fs.mkdirSync(output, { recursive: true });
const versions = 'C:\\Users\\sandt\\AppData\\Local\\Roblox\\Versions';
const fontFolders = [ 'C:/Windows/Fonts' ];
for (const item of fs.readdirSync(versions, { withFileTypes: true })) {
  if (!item.isDirectory()) continue;
  const folder = path.join(versions, item.name, 'content', 'fonts');
  if (fs.existsSync(path.join(folder, 'LuckiestGuy-Regular.ttf'))) fontFolders.push(folder.replaceAll('\\', '/'));
}
const fontConfig = path.join(output, 'UIReferenceFonts.conf');
const cache = path.join(output, 'fontcache').replaceAll('\\', '/');
fs.mkdirSync(cache, { recursive: true });
fs.writeFileSync(fontConfig, '<fontconfig>' + fontFolders.map(folder => '<dir>' + folder + '</dir>').join('') + '<cachedir>' + cache + '</cachedir></fontconfig>');
process.env.FONTCONFIG_FILE = fontConfig;
if (!process.argv.includes('--configured')) {
  const result = require('child_process').spawnSync(process.execPath, [__filename, '--configured'], {
    env: { ...process.env, FONTCONFIG_FILE: fontConfig, FONTCONFIG_PATH: output, XDG_CACHE_HOME: cache },
    stdio: 'inherit'
  });
  if (result.error) throw result.error;
  process.exit(result.status === null ? 1 : result.status);
}
const sharp = require('C:\\Users\\sandt\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\sharp');

async function render() {
  const folder = __dirname;
  for (const name of ['MudHUD', 'TagSprint']) {
    const source = path.join(folder, name + '.svg');
    const destination = path.join(output, name + '_Reference.png');
    await sharp(source).png().toFile(destination);
    const image = await sharp(destination).metadata();
    console.log(JSON.stringify({ source, destination, width: image.width, height: image.height }));
  }
}

render().catch(error => { console.error(error); process.exitCode = 1; });
