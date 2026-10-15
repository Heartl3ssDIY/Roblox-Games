const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');
const root = path.resolve(__dirname, '..');
const cache = path.join(__dirname, '.fontcache');
const fontRoot = 'C:/Users/sandt/AppData/Local/Roblox/Versions';
const fontDirectory = fs.readdirSync(fontRoot).map(version => path.join(fontRoot, version, 'content', 'fonts'))
  .find(directory => fs.existsSync(path.join(directory, 'LuckiestGuy-Regular.ttf')));
if (!fontDirectory) throw new Error('Roblox UI fonts were not found');
fs.mkdirSync(cache, { recursive: true });
const config = path.join(__dirname, 'Fonts.conf');
fs.writeFileSync(config, '<fontconfig><dir>' + fontDirectory.replaceAll('\\', '/') + '</dir><dir>C:/Windows/Fonts</dir><cachedir>' + cache.replaceAll('\\', '/') + '</cachedir></fontconfig>');
if (!process.argv.includes('--configured')) {
  const result = childProcess.spawnSync(process.execPath, [__filename, '--configured'], {
    env: { ...process.env, FONTCONFIG_FILE: config, FONTCONFIG_PATH: __dirname }, stdio: 'inherit'
  });
  process.exit(result.status === null ? 1 : result.status);
}
const sharp = require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp(path.join(root, 'Playground-UI-Templates.svg')).png()
  .toFile(path.join(root, 'Playground-UI-Templates.png'))
  .then(info => console.log(JSON.stringify(info)))
  .catch(error => { console.error(error); process.exitCode = 1; });
