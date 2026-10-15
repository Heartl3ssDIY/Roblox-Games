from pathlib import Path
import hashlib
import json
import math
import re
import xml.etree.ElementTree as ET
import os
import struct

class NativeTrueTypeMetrics:
    def __init__(self, path):
        self.path = path
        self.data = path.read_bytes()
        count = struct.unpack_from(">H", self.data, 4)[0]
        self.tables = {}
        for index in range(count):
            offset = 12 + index * 16
            tag = self.data[offset:offset + 4].decode("ascii")
            self.tables[tag] = struct.unpack_from(">II", self.data, offset + 8)
        self.units = struct.unpack_from(">H", self.data, self.tables["head"][0] + 18)[0]
        self.metric_count = struct.unpack_from(">H", self.data, self.tables["hhea"][0] + 34)[0]
        self.hmtx = self.tables["hmtx"][0]
        cmap = self.tables["cmap"][0]
        count = struct.unpack_from(">H", self.data, cmap + 2)[0]
        records = [struct.unpack_from(">HHI", self.data, cmap + 4 + index * 8) for index in range(count)]
        preferred = [record for record in records if record[0] in (0, 3) and struct.unpack_from(">H", self.data, cmap + record[2])[0] == 4]
        assert preferred, f"No format-4 Unicode cmap in {path}"
        self.cmap = cmap + preferred[0][2]
        self.segment_count = struct.unpack_from(">H", self.data, self.cmap + 6)[0] // 2

    def glyph(self, codepoint):
        segment_count, base, data = self.segment_count, self.cmap, self.data
        for index in range(segment_count):
            end = struct.unpack_from(">H", data, base + 14 + index * 2)[0]
            if codepoint > end:
                continue
            start = struct.unpack_from(">H", data, base + 16 + segment_count * 2 + index * 2)[0]
            if codepoint < start:
                return 0
            delta = struct.unpack_from(">h", data, base + 16 + segment_count * 4 + index * 2)[0]
            offset_position = base + 16 + segment_count * 6 + index * 2
            range_offset = struct.unpack_from(">H", data, offset_position)[0]
            if range_offset == 0:
                return (codepoint + delta) & 0xffff
            glyph = struct.unpack_from(">H", data, offset_position + range_offset + (codepoint - start) * 2)[0]
            return ((glyph + delta) & 0xffff) if glyph else 0
        return 0

    def width(self, text, size):
        advance = 0
        for character in text:
            glyph = self.glyph(ord(character))
            metric = min(glyph, self.metric_count - 1)
            advance += struct.unpack_from(">H", self.data, self.hmtx + metric * 4)[0]
        return advance * size / self.units

FONT_FILES = {"Luckiest Guy": "LuckiestGuy-Regular.ttf", "Fredoka One": "FredokaOne-Regular.ttf", "Arimo": "Arimo-Regular.ttf"}
FONT_METRICS = {}
for family, name in FONT_FILES.items():
    versions = Path(os.environ.get("LOCALAPPDATA", r"C:\Users\sandt\AppData\Local")) / "Roblox" / "Versions"
    candidates = sorted(versions.glob("*/content/fonts/" + name))
    assert candidates, f"Installed Roblox font not found: {name}"
    FONT_METRICS[family] = NativeTrueTypeMetrics(candidates[-1])


ROOT = Path(__file__).resolve().parent
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)

def element(name, attributes=None, text=None):
    node = ET.Element("{" + SVG + "}" + name, {key: str(value) for key, value in (attributes or {}).items()})
    if text is not None:
        node.text = text
    return node

def number(value):
    return f"{value:.4f}".rstrip("0").rstrip(".") or "0"

def color(value):
    return "#" + "".join(f"{int(channel):02x}" for channel in value)

def identifier(value):
    return re.sub(r"[^A-Za-z0-9_.-]", "-", value)

def serialize(root):
    ET.indent(root, space="  ")
    for text in root.findall(".//{" + SVG + "}text"):
        if list(text):
            text.text = None
            for span in text:
                span.tail = None
    return ET.tostring(root, encoding="unicode") + "\n"

def children(node, class_name):
    return [child for child in node.get("children", []) if child["class"] == class_name]

def canvas_rectangle(node, parent):
    px, py, pw, ph = parent
    sx, ox, sy, oy = node["size"]
    width, height = sx * pw + ox, sy * ph + oy
    limits = children(node, "UISizeConstraint")
    if limits:
        width = max(limits[0]["minSize"][0], min(limits[0]["maxSize"][0], width))
        height = max(limits[0]["minSize"][1], min(limits[0]["maxSize"][1], height))
    sx, ox, sy, oy = node["position"]
    ax, ay = node["anchor"]
    return px + sx * pw + ox - ax * width, py + sy * ph + oy - ay * height, width, height

def font_name(node):
    family = node["font"]["family"].split("/")[-1].removesuffix(".json")
    return {"LuckiestGuy": "Luckiest Guy", "FredokaOne": "Fredoka One", "LegacyArial": "Arimo", "SourceSansPro": "Source Sans Pro"}.get(family, family)

def measured_width(node, font_size):
    metrics = FONT_METRICS.get(font_name(node))
    if metrics:
        return max(metrics.width(line, font_size) for line in node['text'].split('\n'))
    measurements = node.get("measurements", [])
    if not measurements:
        return len(node["text"]) * font_size * 0.55
    below = max((m for m in measurements if m[0] <= font_size), default=measurements[0], key=lambda m: m[0])
    above = min((m for m in measurements if m[0] >= font_size), default=measurements[-1], key=lambda m: m[0])
    if above[0] == below[0]:
        return above[1]
    t = (font_size - below[0]) / (above[0] - below[0])
    return below[1] + (above[1] - below[1]) * t

def text_layout(node, rectangle):
    x, y, width, height = rectangle
    pads = children(node, "UIPadding")
    if pads:
        padding = pads[0]["padding"]
        left = padding["left"][0] * width + padding["left"][1]
        right = padding["right"][0] * width + padding["right"][1]
        top = padding["top"][0] * height + padding["top"][1]
        bottom = padding["bottom"][0] * height + padding["bottom"][1]
        x, y, width, height = x + left, y + top, width - left - right, height - top - bottom
    lines = node["text"].split("\n")
    limits = children(node, "UITextSizeConstraint")
    minimum, maximum = (limits[0]["minTextSize"], limits[0]["maxTextSize"]) if limits else (1, 100)
    size = node["textSize"]
    if node.get("textScaled"):
        size = maximum
        while size > minimum and (measured_width(node, size) > width or size * len(lines) > height):
            size -= 1
    anchor = {"Left": "start", "Center": "middle", "Right": "end"}[node["alignX"]]
    tx = {"Left": x, "Center": x + width / 2, "Right": x + width}[node["alignX"]]
    total_height = size * len(lines)
    top = {"Top": y, "Center": y + (height - total_height) / 2, "Bottom": y + height - total_height}[node["alignY"]]
    # Roblox uses a one-font-size line box. Place each SVG baseline from that box.
    baseline = top + size * 0.82
    return lines, size, tx, baseline, anchor

def render_node(node, parent_rectangle, sequence, text_records, viewbox_origin):
    if "position" not in node:
        return []
    rectangle = canvas_rectangle(node, parent_rectangle)
    x, y, width, height = rectangle
    seq = sequence[0]
    sequence[0] += 1
    group = element("g", {
        "id": identifier(node["name"]) + f"-{seq}",
        "data-native-name": node["name"],
        "data-native-class": node["class"],
        "data-native-visible": str(node.get("visible", True)).lower(),
    })
    group.append(element("title", text=node["name"]))
    if node.get("rotation"):
        group.set("transform", f"rotate({number(node['rotation'])} {number(x + width / 2)} {number(y + height / 2)})")
    corners = children(node, "UICorner")
    radius = min(width, height) * corners[0]["radius"][0] + corners[0]["radius"][1] if corners else 0
    radius = min(radius, min(width, height) / 2)
    transparency = node.get("backgroundTransparency", 1)
    if transparency < 1:
        group.append(element("rect", {
            "id": f"Background-{seq}", "x": number(x), "y": number(y),
            "width": number(width), "height": number(height), "rx": number(radius),
            "fill": color(node["backgroundColor"]), "fill-opacity": number(1 - transparency),
        }))
    for stroke in children(node, "UIStroke"):
        if stroke["mode"] != "Border" or stroke["transparency"] >= 1:
            continue
        group.append(element("rect", {
            "id": f"Outline-{seq}", "x": number(x), "y": number(y),
            "width": number(width), "height": number(height), "rx": number(radius),
            "fill": "none", "stroke": color(stroke["color"]),
            "stroke-width": number(stroke["thickness"]), "stroke-opacity": number(1 - stroke["transparency"]),
            "stroke-linejoin": stroke["join"].lower(),
        }))
    if node["class"] in ("TextLabel", "TextButton") and node.get("text"):
        lines, size, tx, baseline, anchor = text_layout(node, rectangle)
        attributes = {
            "id": f"EditableText-{seq}", "font-family": font_name(node),
            "font-size": number(size), "font-weight": node["font"].get("weight", "Regular").lower().replace("regular", "400"),
            "font-style": node["font"].get("style", "Normal").lower(),
            "fill": color(node["textColor"]), "fill-opacity": number(1 - node["textTransparency"]),
            "text-anchor": anchor, "xml:space": "preserve",
            "data-roblox-font-family": node["font"]["family"],
            "data-native-text-scaled": str(node.get("textScaled", False)).lower(),
        }
        contextual = [stroke for stroke in children(node, "UIStroke") if stroke["mode"] == "Contextual" and stroke["transparency"] < 1]
        if contextual:
            attributes.update({"stroke": color(contextual[0]["color"]), "stroke-width": number(contextual[0]["thickness"] * 2), "stroke-opacity": number(1 - contextual[0]["transparency"]), "paint-order": "stroke fill", "stroke-linejoin": "round"})
        elif node.get("textStrokeTransparency", 1) < 1:
            attributes.update({"stroke": color(node["textStrokeColor"]), "stroke-width": "2", "stroke-opacity": number(1 - node["textStrokeTransparency"]), "paint-order": "stroke fill", "stroke-linejoin": "round"})
        text = element("text", attributes)
        for index, line in enumerate(lines):
            text.append(element("tspan", {"x": number(tx), "y": number(baseline + index * size)}, text=line))
            pads = children(node, "UIPadding")
            line_width = width
            if pads:
                padding = pads[0]["padding"]
                line_width -= (padding["left"][0] + padding["right"][0]) * width + padding["left"][1] + padding["right"][1]
            left = {"start": tx, "middle": tx - line_width / 2, "end": tx - line_width}[anchor]
            text_records.append({
                "name": node["name"] + (f" / Line {index + 1}" if len(lines) > 1 else ""),
                "text": line, "x": float(number(left - viewbox_origin[0])),
                "y": float(number(baseline + index * size - size * 0.82 - viewbox_origin[1])),
                "width": float(number(line_width)), "height": size,
                "fontFamily": font_name(node), "fontSize": size,
                "color": attributes["fill"], "opacity": float(attributes["fill-opacity"]),
                "strokeColor": attributes.get("stroke"), "strokeWidth": float(attributes.get("stroke-width", "0")),
                "strokeOpacity": float(attributes.get("stroke-opacity", "0")),
                "align": {"start": "LEFT", "middle": "CENTER", "end": "RIGHT"}[anchor],
            })
        group.append(text)
    ordered = sorted((child for child in node.get("children", []) if "position" in child), key=lambda child: child.get("zIndex", 1))
    for child in ordered:
        for rendered in render_node(child, rectangle, sequence, text_records, viewbox_origin):
            group.append(rendered)
    return [group]

def filename(record):
    labels = [child["text"] for child in record["children"] if child["class"] in ("TextLabel", "TextButton")]
    text = labels[0] if labels else ""
    if record["name"] == "TaggedTemplate":
        return "Overhead-Tagged.svg"
    if record["name"] == "TaggerTemplate":
        return "Overhead-Youre-It.svg"
    if record["name"] == "MuddyTemplate":
        return "Overhead-Stuck.svg"
    if ".ArenaWalls." in record["path"]:
        return "Arena-British-Bulldog-Title.svg"
    if ".VotingAlcove." in record["path"]:
        for key, name in (("BritishBulldogStand", "British-Bulldog"), ("TagYoureItStand", "Tag-Youre-It"), ("StuckInTheMudStand", "Stuck-In-The-Mud")):
            if key in record["path"]:
                return "Vote-Stand-" + name + ".svg"
    if ".HopscotchSquare." in record["path"]:
        return f"School-Hopscotch-{text}.svg"
    return {"ROOM 4": "School-Room-4.svg", "CLASS\n4B": "School-Class-4B.svg", "SPORTS\nDAY": "School-Sports-Day.svg"}[text]

def make_svg(record):
    width, height = record["canvas"]
    bleed = 4 if record["class"] == "BillboardGui" else 0
    root = element("svg", {
        "width": number(width + bleed * 2), "height": number(height + bleed * 2),
        "viewBox": f"{number(-bleed)} {number(-bleed)} {number(width + bleed * 2)} {number(height + bleed * 2)}",
    })
    root.append(element("title", text=filename(record).removesuffix(".svg")))
    root.append(element("desc", text="Editable SVG exported read-only from Roblox Studio. All label text remains live text. Named groups preserve authored UI layers. Surface host color is included as an editable backplate; scene lighting is omitted."))
    root.append(element("metadata", text=json.dumps({"source": record["path"], "locator": record["locator"], "enabled": record["enabled"], "canvas": record["canvas"], "fontSizeResolution": "Installed Roblox TrueType advance widths with integer size fitting"}, ensure_ascii=False)))
    if record.get("host"):
        host = element("g", {"id": "Editable-Host-Part-Surface-Backplate"})
        host.append(element("title", text="Host part surface color (visual context)"))
        host.append(element("rect", {"x": "0", "y": "0", "width": number(width), "height": number(height), "fill": color(record["host"]["color"]), "fill-opacity": number(1 - record["host"]["transparency"])}))
        root.append(host)
    native = element("g", {"id": identifier(record["name"]), "data-source-enabled": str(record["enabled"]).lower()})
    text_records = []
    for child in sorted(record["children"], key=lambda child: child.get("zIndex", 1)):
        for rendered in render_node(child, (0, 0, width, height), [1], text_records, (-bleed, -bleed)):
            native.append(rendered)
    root.append(native)
    root.append(element("metadata", {"id": "playground-text-layers"}, text=json.dumps({"version": 1, "texts": text_records}, ensure_ascii=False)))
    return serialize(root)

def create_emoji(glyph, rgb, name):
    root = element("svg", {"width": "84", "height": "84", "viewBox": "-2 -2 84 84"})
    root.append(element("title", text="PCEmojiBubble " + name))
    root.append(element("desc", text="Editable runtime emoji billboard from PlaygroundEconomyService.lua. Roblox TextLabel engine default font maps to LegacyArial; its installed Roblox font is Arimo. Glyph, colors, dimensions, stroke and offsets remain editable."))
    root.append(element("metadata", text=json.dumps({"source": "StuckInTheMud20261003/PlaygroundEconomyService.lua", "runtimeName": "PCEmojiBubble", "size": [80,80], "StudsOffset": [0,3.5,0], "AlwaysOnTop": False, "lifetimeSeconds": 2.5, "font": "Engine default Enum.Font.Legacy / LegacyArial; Roblox LegacyArial.json uses Arimo-Regular.ttf"}, ensure_ascii=False)))
    group = element("g", {"id": "PCEmojiBubble"})
    group.append(element("text", {"id": "Editable-Emoji-" + name, "x": "40", "y": "65.6", "font-family": "Arimo", "font-size": "80", "font-weight": "400", "text-anchor": "middle", "fill": color(rgb), "stroke": "#18233e", "stroke-width": "2", "stroke-linejoin": "round", "paint-order": "stroke fill", "data-roblox-font-family": "rbxasset://fonts/families/LegacyArial.json"}, text=glyph))
    root.append(group)
    root.append(element("metadata", {"id": "playground-text-layers"}, text=json.dumps({"version": 1, "texts": [{
        "name": "Emoji " + name, "text": glyph, "x": 2, "y": 2, "width": 80, "height": 80,
        "fontFamily": "Arimo", "fontSize": 80, "color": color(rgb), "opacity": 1,
        "strokeColor": "#18233e", "strokeWidth": 2, "strokeOpacity": 1, "align": "CENTER"
    }]}, ensure_ascii=False)))
    return serialize(root)

data = json.loads((ROOT / "NativeWorldUISnapshot.json").read_text(encoding="utf-8"))
art = {}
sources = []
for record in data["records"]:
    name = filename(record)
    svg = make_svg(record)
    sources.append({"path": record["path"], "locator": record["locator"], "class": record["class"], "enabledInSource": record["enabled"], "file": name, "canvas": record["canvas"], "host": record.get("host")})
    if name not in art:
        art[name] = svg
        (ROOT / name).write_text(svg, encoding="utf-8")
    else:
        # The shared art differs only in source paths and face orientation.
        prior = ET.fromstring(art[name])
        current = ET.fromstring(svg)
        for tree in (prior, current):
            for metadata in tree.findall("{" + SVG + "}metadata"):
                tree.remove(metadata)
        assert ET.tostring(prior) == ET.tostring(current), f"Unexpected non-identical deduplication: {name}"

for name, glyph, rgb in (("Star", "★", [255,212,74]), ("Heart", "♥", [255,103,146])):
    key = "Emoji-Bubble-" + name + ".svg"
    art[key] = create_emoji(glyph, rgb, name)
    (ROOT / key).write_text(art[key], encoding="utf-8")

files = []
for name in sorted(art):
    tree = ET.fromstring(art[name])
    texts = tree.findall(".//{" + SVG + "}text")
    assert texts and not tree.findall(".//{" + SVG + "}image")
    assert "display:none" not in art[name] and "data:image" not in art[name]
    text_layer_metadata = tree.find("{" + SVG + "}metadata[@id='playground-text-layers']")
    text_layers = json.loads(text_layer_metadata.text)
    assert text_layers["version"] == 1
    assert len(text_layers["texts"]) == sum(len(text.findall("{" + SVG + "}tspan")) or 1 for text in texts)
    files.append({"file": name, "sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), "width": float(tree.attrib["width"]), "height": float(tree.attrib["height"]), "liveTextElements": len(texts), "textImporterLines": len(text_layers["texts"]), "fonts": sorted({text.attrib["font-family"] for text in texts})})

manifest = {
    "studioId": data["studioId"], "datamodel": "Edit", "nativeMutation": False,
    "nativeGuiCount": len(sources), "svgCount": len(files), "nativeDedupeCount": len(art) - 2,
    "runtimeEmojiVariants": 2, "sources": sources, "files": files,
    "fontSources": {family: {"fontFile": metrics.path.name, "sha256": hashlib.sha256(metrics.data).hexdigest()} for family, metrics in FONT_METRICS.items()},
    "notes": [
        "Every original native Gui path has a corresponding SVG. Sibling-indexed locator paths disambiguate repeated object names.",
        "Identical school artwork and British Bulldog arena titles are shared across original instances.",
        "Native disabled billboards are exported visibly as standalone editable artwork.",
        "Surface host part color is included as a separately named editable vector backplate.",
        "World scene lighting, perspective and 3D host geometry are not baked into 2D artwork.",
        "TextScaled uses installed Roblox TrueType advance widths with integer font-size fitting. Captured TextService measurements are also retained in the snapshot. Live SVG text metrics can differ slightly from Roblox.",
        "Runtime emoji font is the TextLabel engine default LegacyArial, whose Roblox font is Arimo; glyph fallback depends on locally installed fonts.",
        "All art contains editable SVG text and primitive shapes; no bitmap embeddings.",
        "Optional playground-text-layers metadata stores one editable text-importer record per rendered line. Coordinates are relative to the SVG viewport; y is the line-box top. The helper is not executed by the exporter."
    ]
}
(ROOT / "WorldUIManifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({"nativeGuiCount": len(sources), "svgCount": len(files), "files": [file["file"] for file in files]}))

