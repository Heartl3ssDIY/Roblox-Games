figma.showUI(__html__, { width: 420, height: 430, themeColors: true });

let importing = false;
const fonts = new Map();

function finite(value, fallback, minimum, maximum) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(minimum, Math.min(maximum, number)) : fallback;
}

function rgb(value, fallback) {
  const hex = typeof value === "string" ? value.trim() : "";
  if (/^#[0-9a-f]{6}$/i.test(hex)) {
    return {
      r: parseInt(hex.slice(1, 3), 16) / 255,
      g: parseInt(hex.slice(3, 5), 16) / 255,
      b: parseInt(hex.slice(5, 7), 16) / 255
    };
  }
  if (/^#[0-9a-f]{3}$/i.test(hex)) {
    return {
      r: parseInt(hex[1] + hex[1], 16) / 255,
      g: parseInt(hex[2] + hex[2], 16) / 255,
      b: parseInt(hex[3] + hex[3], 16) / 255
    };
  }
  return fallback;
}

async function fontFor(family, warnings) {
  const supported = ["Luckiest Guy", "Fredoka One", "Arimo", "Inter"];
  const requested = supported.indexOf(family) >= 0 ? family : "Inter";
  if (requested !== family && family) warnings.add("Unsupported font " + family + "; using Inter Regular.");
  if (!fonts.has(requested)) {
    fonts.set(requested, (async function () {
      const preferred = { family: requested, style: "Regular" };
      try {
        await figma.loadFontAsync(preferred);
        return { font: preferred, missing: false };
      } catch (error) {
        if (requested === "Inter") throw new Error("Inter Regular is unavailable. Enable that font and try again.");
        const fallback = { family: "Inter", style: "Regular" };
        await figma.loadFontAsync(fallback);
        return { font: fallback, missing: true };
      }
    })());
  }
  const result = await fonts.get(requested);
  if (result.missing) warnings.add(requested + " Regular unavailable; used Inter Regular.");
  return result.font;
}

function textParent(root, record, cache) {
  let current = { node: root, x: 0, y: 0 };
  let key = "";
  const clips = Array.isArray(record.clips) ? record.clips : [];
  if (clips.length > 50) throw new Error("Too many nested text clips.");
  for (const clip of clips) {
    if (!clip || typeof clip !== "object") throw new Error("Invalid text clip.");
    const x = finite(clip.x, 0, -1000000, 1000000);
    const y = finite(clip.y, 0, -1000000, 1000000);
    const width = finite(clip.width, 1, 0.01, 100000);
    const height = finite(clip.height, 1, 0.01, 100000);
    const radius = finite(clip.radius, 0, 0, Math.min(width, height) / 2);
    const name = typeof clip.name === "string" ? clip.name : "Text clip";
    key += JSON.stringify([name, x, y, width, height, radius]);
    if (!cache.has(key)) {
      const frame = figma.createFrame();
      current.node.appendChild(frame);
      frame.name = name + " · text clip";
      frame.layoutMode = "NONE";
      frame.fills = [];
      frame.strokes = [];
      frame.resize(width, height);
      frame.x = x - current.x;
      frame.y = y - current.y;
      frame.cornerRadius = radius;
      frame.clipsContent = true;
      frame.setPluginData("playground-clip-path", name);
      cache.set(key, { node: frame, x: x, y: y });
    }
    current = cache.get(key);
  }
  return current;
}

function positionText(node, record, parent) {
  const x = finite(record.x, 0, -1000000, 1000000);
  const y = finite(record.y, 0, -1000000, 1000000);
  const degrees = finite(record.rotation, 0, -36000, 36000);
  if (!degrees) {
    node.x = x - parent.x;
    node.y = y - parent.y;
    return;
  }
  if (!Array.isArray(record.rotationCenter) || record.rotationCenter.length !== 2) {
    throw new Error("A rotated text record needs its SVG rotation center.");
  }
  const cx = finite(record.rotationCenter[0], 0, -1000000, 1000000);
  const cy = finite(record.rotationCenter[1], 0, -1000000, 1000000);
  const radians = degrees * Math.PI / 180;
  const cosine = Math.cos(radians);
  const sine = Math.sin(radians);
  node.relativeTransform = [
    [cosine, -sine, cx + cosine * (x - cx) - sine * (y - cy) - parent.x],
    [sine, cosine, cy + sine * (x - cx) + cosine * (y - cy) - parent.y]
  ];
}

async function appendText(root, record, warnings, cache) {
  if (!record || typeof record.text !== "string") throw new Error("Invalid text record.");
  const font = await fontFor(record.fontFamily, warnings);
  const parent = textParent(root, record, cache);
  const node = figma.createText();
  parent.node.appendChild(node);
  node.fontName = font;
  node.fontSize = finite(record.fontSize, 16, 1, 1000);
  node.textAutoResize = "NONE";
  node.characters = record.text;
  node.name = typeof record.name === "string" && record.name ? record.name : record.text.slice(0, 80) || "Text";
  node.autoRename = false;
  node.textAlignHorizontal = ["LEFT", "CENTER", "RIGHT"].indexOf(record.align) >= 0 ? record.align : "LEFT";
  node.textAlignVertical = "CENTER";
  node.resize(finite(record.width, 100, 0.01, 100000), finite(record.height, node.fontSize * 1.2, 0.01, 100000));
  positionText(node, record, parent);
  node.fills = [{ type: "SOLID", color: rgb(record.color, { r: 24 / 255, g: 35 / 255, b: 62 / 255 }) }];
  node.opacity = finite(record.opacity, 1, 0, 1);
  const weight = finite(record.strokeWidth, 0, 0, 100);
  if (weight > 0 && record.strokeColor) {
    node.strokes = [{
      type: "SOLID",
      color: rgb(record.strokeColor, { r: 24 / 255, g: 35 / 255, b: 62 / 255 }),
      opacity: finite(record.strokeOpacity, 1, 0, 1)
    }];
    node.strokeWeight = weight;
    node.strokeAlign = "CENTER";
    node.strokeJoin = "ROUND";
  } else {
    node.strokes = [];
  }
  node.setPluginData("playground-source-path", node.name);
  node.setPluginData("playground-requested-font", String(record.fontFamily || "Inter"));
  return node;
}

async function importFiles(message) {
  if (importing) return;
  if (!Array.isArray(message.files) || !message.files.length || message.files.length > 250) {
    figma.ui.postMessage({ type: "error", message: "Choose between 1 and 250 SVGs." });
    return;
  }
  importing = true;
  const page = figma.currentPage;
  const center = figma.viewport.center;
  const imported = [];
  const failures = [];
  const warnings = new Set();
  let labels = 0;
  let x = center.x;
  let y = center.y;
  let rowHeight = 0;
  const rowWidth = 3200;
  const startX = x;
  try {
    for (let index = 0; index < message.files.length; index++) {
      const item = message.files[index];
      let frame = null;
      try {
        if (!item || typeof item.svg !== "string" || !Array.isArray(item.texts) || item.texts.length > 10000) {
          throw new Error("Invalid SVG import data.");
        }
        const width = finite(item.width, 1366, 1, 100000);
        const height = finite(item.height, 767, 1, 100000);
        frame = figma.createNodeFromSvg(item.svg);
        page.appendChild(frame);
        const bounds = frame.findOne(function (node) { return node.name === item.boundsName; });
        if (!bounds) throw new Error("Figma did not preserve the SVG viewport marker; import skipped to avoid moving text.");
        bounds.remove();
        frame.name = String(item.name || "Playground UI").replace(/\.svg$/i, "");
        frame.resize(width, height);
        frame.clipsContent = true;
        if (index > 0 && x - startX + width > rowWidth) {
          x = startX;
          y += rowHeight + 100;
          rowHeight = 0;
        }
        frame.x = x;
        frame.y = y;
        frame.setPluginData("playground-text-metadata-version", "1");
        const clipCache = new Map();
        for (const record of item.texts) {
          await appendText(frame, record, warnings, clipCache);
        }
        labels += item.texts.length;
        imported.push(frame);
        x += width + 100;
        rowHeight = Math.max(rowHeight, height);
      } catch (error) {
        if (frame && !frame.removed) frame.remove();
        failures.push(String(item && item.name || "SVG") + ": " + String(error && error.message || error));
      }
      figma.ui.postMessage({
        type: "progress", current: index + 1, total: message.files.length,
        message: "Imported " + imported.length + " SVGs and " + labels + " editable labels."
      });
    }
    if (imported.length) {
      page.selection = imported;
      figma.viewport.scrollAndZoomIntoView(imported);
      figma.commitUndo();
    }
    figma.ui.postMessage({
      type: "complete",
      imported: imported.length,
      labels: labels,
      warnings: Array.from(warnings),
      failures: failures
    });
    figma.notify("Imported " + imported.length + " SVGs with " + labels + " editable text layers.");
  } catch (error) {
    figma.ui.postMessage({ type: "error", message: String(error && error.message || error) });
  } finally {
    importing = false;
  }
}

figma.ui.onmessage = function (message) {
  if (!message || typeof message !== "object") return;
  if (message.type === "close") {
    if (!importing) figma.closePlugin();
  } else if (message.type === "import") {
    importFiles(message);
  }
};
