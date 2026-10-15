const fs = require('fs');
const path = require('path');
const root = __dirname;
const fontCache = path.join(root, 'font-cache');
fs.mkdirSync(fontCache, { recursive: true });
const fontConfig = path.join(root, 'fontconfig.xml');
fs.writeFileSync(fontConfig, `<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>C:/Windows/Fonts</dir><cachedir>${fontCache.replace(/\\/g, '/')}</cachedir></fontconfig>`);
process.env.FONTCONFIG_FILE = fontConfig;
const sharp = require('C:/Users/sandt/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');

async function render() {
  const source = fs.existsSync(path.join(root, 'svg')) ? path.join(root, 'svg') : root;
  const output = path.join(root, 'png');
  fs.mkdirSync(output, { recursive: true });
  const results = [];
  for (const name of fs.readdirSync(source).filter(name => name.endsWith('.svg'))) {
    const destination = path.join(output, name.replace(/\.svg$/, '.png'));
    const metadata = await sharp(path.join(source, name), { density: 192 }).png().toFile(destination);
    results.push({ name, width: metadata.width, height: metadata.height, bytes: metadata.size });
  }
  fs.writeFileSync(path.join(root, 'svg-render-manifest.json'), JSON.stringify(results, null, 2));
  process.stdout.write(JSON.stringify(results));
}

render().catch(error => { process.stderr.write(error.stack); process.exitCode = 1; });
