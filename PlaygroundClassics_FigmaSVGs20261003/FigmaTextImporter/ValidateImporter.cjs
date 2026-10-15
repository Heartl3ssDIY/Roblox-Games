const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "manifest.json"), "utf8"));
assert.deepEqual(manifest.networkAccess.allowedDomains, ["none"]);
assert.equal(manifest.documentAccess, "dynamic-page");
new vm.Script(fs.readFileSync(path.join(__dirname, "code.js"), "utf8"));
const html = fs.readFileSync(path.join(__dirname, "ui.html"), "utf8");
new vm.Script(html.match(/<script>([\s\S]*)<\/script>/)[1]);
assert(html.includes('root.querySelectorAll("text, script, foreignObject, metadata")'));
assert(!/\bfetch\s*\(|XMLHttpRequest/.test(html));

let completion;
let calls = 0;
const texts = [];
const frames = [];
const loaded = new Set();
const messages = [];
function frame() {
  const node = {
    children: [], removed: false,
    appendChild(child) { this.children.push(child); child.parent = this; },
    resize(width, height) { this.width = width; this.height = height; },
    setPluginData(key, value) { this[key] = value; },
    findOne(predicate) { return this.children.find(predicate); },
    remove() { this.removed = true; }
  };
  frames.push(node);
  return node;
}
const page = { children: [], appendChild(node) { this.children.push(node); } };
const figma = {
  currentPage: page,
  viewport: { center: { x: 100, y: 200 }, scrollAndZoomIntoView(nodes) { this.selected = nodes; } },
  ui: { postMessage(message) {
    messages.push(message);
    if (message.type === "complete" && completion) completion(message);
  } },
  showUI() {}, notify() {}, commitUndo() {}, closePlugin() {},
  createNodeFromSvg(svg) {
    calls++;
    assert(!svg.includes("<text"));
    const result = frame();
    if (svg.includes("__playground_import_viewport_bounds__")) {
      result.appendChild({ name: "__playground_import_viewport_bounds__", remove() { this.removed = true; } });
    }
    return result;
  },
  createFrame() { return frame(); },
  async loadFontAsync(font) {
    if (font.family === "Fredoka One") throw Error("Unavailable");
    loaded.add(font.family + "/" + font.style);
  },
  createText() {
    const node = {
      x: 0, y: 0,
      setPluginData(key, value) { this[key] = value; },
      resize(width, height) { this.width = width; this.height = height; }
    };
    Object.defineProperty(node, "characters", {
      set(value) {
        assert(loaded.has(node.fontName.family + "/" + node.fontName.style));
        node._characters = value;
      },
      get() { return node._characters; }
    });
    Object.defineProperty(node, "relativeTransform", {
      set(value) { node._transform = value; node.x = value[0][2]; node.y = value[1][2]; },
      get() { return node._transform || [[1, 0, node.x], [0, 1, node.y]]; }
    });
    texts.push(node);
    return node;
  }
};
const context = vm.createContext({ figma, __html__: "", Map, Set, Array, Number, String, Math, Error });
vm.runInContext(fs.readFileSync(path.join(__dirname, "code.js"), "utf8"), context);
assert.equal(calls, 0, "Opening the helper does not create artwork.");
figma.ui.onmessage({ type: "import", files: [] });
assert.equal(calls, 0, "Empty import does not create artwork.");
assert.equal(messages.at(-1).type, "error");
const record = {
  name: "Top.Timer/Line1", text: "3:00", x: 10, y: 20, width: 120, height: 50,
  fontFamily: "Luckiest Guy", fontSize: 36, color: "#2aa0ff", opacity: .8,
  strokeColor: "#18233e", strokeWidth: 3, strokeOpacity: .9, align: "CENTER"
};
const finished = new Promise(resolve => { completion = resolve; });
figma.ui.onmessage({
  type: "import",
  files: [
    { name: "HUD.svg", svg: '<svg width="1366" height="767"><rect id="__playground_import_viewport_bounds__" width="1366" height="767"/></svg>', width: 1366, height: 767, boundsName: "__playground_import_viewport_bounds__",
      texts: [record, { ...record, name: "Role/Line1", text: "RUNNER", fontFamily: "Fredoka One", strokeWidth: 0 }] },
    { name: "Bad.svg", svg: '<svg><rect id="__playground_import_viewport_bounds__"/></svg>', boundsName: "__playground_import_viewport_bounds__", texts: [{ text: null }] },
    { name: "MissingMarker.svg", svg: "<svg/>", boundsName: "__playground_import_viewport_bounds__", texts: [] }
  ]
});
finished.then(async result => {
  assert.equal(result.imported, 1);
  assert.equal(result.labels, 2);
  assert.equal(result.failures.length, 2);
  assert(result.warnings.includes("Fredoka One Regular unavailable; used Inter Regular."));
  assert.equal(frames[1].removed, true, "A failed file removes its partial artwork.");
  assert.equal(frames[2].removed, true, "A missing viewport marker skips and removes the file.");
  assert.equal(frames[0].children[0].removed, true, "Viewport marker is removed after preserving source bounds.");
  assert.equal(frames[0].clipsContent, true);
  assert.equal(frames[0].width, 1366);
  assert.equal(frames[0].height, 767);
  assert.equal(frames[0].name, "HUD");
  assert.equal(texts[0].characters, "3:00");
  assert.equal(texts[0].fontName.family, "Luckiest Guy");
  assert.equal(texts[0].fontName.style, "Regular");
  assert.equal(texts[1].fontName.family, "Inter");
  assert.equal(texts[0].x, 10);
  assert.equal(texts[0].y, 20);
  assert.equal(texts[0].width, 120);
  assert.equal(texts[0].height, 50);
  assert.equal(texts[0].textAlignHorizontal, "CENTER");
  assert.equal(texts[0].strokeWeight, 3);
  assert.equal(texts[0].strokes[0].opacity, .9);
  assert.equal(texts[0].opacity, .8);
  assert.equal(texts[1].strokes.length, 0);
  assert.equal(page.selection.length, 1);
  const clipChain = [
    { name: "Panel", x: 100, y: 50, width: 600, height: 300, radius: 14 },
    { name: "Scroll", x: 120, y: 100, width: 200, height: 120, radius: 8 }
  ];
  const clipCountBefore = frames.length;
  const textCountBefore = texts.length;
  const clipFinished = new Promise(resolve => { completion = resolve; });
  figma.ui.onmessage({ type: "import", files: [{ name: "Clipped.svg", svg: '<svg><rect id="__playground_import_viewport_bounds__"/></svg>', boundsName: "__playground_import_viewport_bounds__", texts: [
    { ...record, name: "Visible", x: 130, y: 110, clips: clipChain },
    { ...record, name: "Partly clipped", x: 130, y: 210, clips: clipChain },
    { ...record, name: "Rotated", x: 130, y: 110, clips: clipChain, rotation: -3, rotationCenter: [150, 130] }
  ] }] });
  const clipResult = await clipFinished;
  assert.equal(clipResult.imported, 1);
  assert.equal(clipResult.labels, 3);
  assert.equal(frames.length - clipCountBefore, 3, "Repeated labels reuse their two cached clip frames.");
  const outer = frames[clipCountBefore + 1];
  const inner = frames[clipCountBefore + 2];
  assert.equal(outer.x, 100);
  assert.equal(outer.y, 50);
  assert.equal(outer.cornerRadius, 14);
  assert.equal(outer.clipsContent, true);
  assert.equal(outer.fills.length, 0);
  assert.equal(inner.parent, outer);
  assert.equal(inner.x, 20);
  assert.equal(inner.y, 50);
  assert.equal(inner.width, 200);
  assert.equal(inner.height, 120);
  assert.equal(inner.cornerRadius, 8);
  assert.equal(inner.clipsContent, true);
  assert.equal(texts[textCountBefore].parent, inner);
  assert.equal(texts[textCountBefore].x, 10);
  assert.equal(texts[textCountBefore].y, 10);
  assert.equal(texts[textCountBefore + 1].y, 110, "Partly clipped text remains editable inside the real clip frame.");
  const rotated = texts[textCountBefore + 2].relativeTransform;
  const cosine = Math.cos(-3 * Math.PI / 180);
  const sine = Math.sin(-3 * Math.PI / 180);
  assert(Math.abs(rotated[0][0] - cosine) < 1e-12);
  assert(Math.abs(rotated[0][1] + sine) < 1e-12);
  assert(Math.abs(rotated[1][0] - sine) < 1e-12);
  assert(Math.abs(rotated[1][1] - cosine) < 1e-12);
  assert(Math.abs(rotated[0][2] - (150 + cosine * -20 - sine * -20 - 120)) < 1e-12);
  assert(Math.abs(rotated[1][2] - (130 + sine * -20 + cosine * -20 - 100)) < 1e-12);
  const exportedPaths = [
    path.join(__dirname, "..", "Screens", "BritishBulldog_BulldogCall.svg"),
    path.join(__dirname, "..", "Panels", "PlaygroundAdminPanel", "Panel.svg"),
    path.join(__dirname, "..", "Panels", "PlaygroundShell", "ShopPanel.svg")
  ];
  for (const exportedPath of exportedPaths.filter(fs.existsSync)) {
    const source = fs.readFileSync(exportedPath, "utf8");
    const match = source.match(/<metadata id="playground-text-layers"><!\[CDATA\[([\s\S]*?)\]\]><\/metadata>/);
    assert(match, "Exported SVG includes native text metadata.");
    const metadata = JSON.parse(match[1]);
    assert.equal(metadata.version, 1);
    assert(metadata.texts.length > 0);
    const width = Number(source.match(/<svg[^>]*width="([0-9.]+)"/)[1]);
    const height = Number(source.match(/<svg[^>]*height="([0-9.]+)"/)[1]);
    const stripped = source.replace(/<text\b[\s\S]*?<\/text>/g, "").replace(/<metadata\b[\s\S]*?<\/metadata>/g, "").replace(/(<svg[^>]*>)/, '$1<rect id="__playground_import_viewport_bounds__" width="' + width + '" height="' + height + '" fill="#fe00fd"/>');
    const countBefore = texts.length;
    const actualFinished = new Promise(resolve => { completion = resolve; });
    figma.ui.onmessage({ type: "import", files: [{ name: path.basename(exportedPath), svg: stripped, width, height, boundsName: "__playground_import_viewport_bounds__", texts: metadata.texts }] });
    const actualResult = await actualFinished;
    assert.equal(actualResult.imported, 1);
    assert.equal(actualResult.labels, metadata.texts.length);
    assert.equal(actualResult.failures.length, 0);
    metadata.texts.forEach((record, index) => {
      const node = texts[countBefore + index];
      assert.equal(node.characters, record.text);
      assert.equal(node.name, record.name);
      assert.equal(node.width, record.width);
      assert.equal(node.height, record.height);
      const clip = record.clips && record.clips.length ? record.clips.at(-1) : { x: 0, y: 0 };
      if (record.rotation) {
        const c = Math.cos(record.rotation * Math.PI / 180);
        const s = Math.sin(record.rotation * Math.PI / 180);
        const [cx, cy] = record.rotationCenter;
        assert(Math.abs(node.x - (cx + c * (record.x - cx) - s * (record.y - cy) - clip.x)) < 1e-9);
        assert(Math.abs(node.y - (cy + s * (record.x - cx) + c * (record.y - cy) - clip.y)) < 1e-9);
      } else {
        assert.equal(node.x, record.x - clip.x);
        assert.equal(node.y, record.y - clip.y);
      }
      if (record.clips && record.clips.length) {
        assert.equal(node.parent.clipsContent, true);
        assert.equal(node.parent.width, clip.width);
        assert.equal(node.parent.height, clip.height);
      }
    });
    console.log(path.basename(exportedPath) + ": all " + metadata.texts.length + " labels, clipping and rotation passed mocked import.");
  }
  console.log("Importer syntax, offline manifest and mocked import behavior passed.");
  console.log("This is local verification; no Figma API session was used.");
}).catch(error => { console.error(error); process.exitCode = 1; });
