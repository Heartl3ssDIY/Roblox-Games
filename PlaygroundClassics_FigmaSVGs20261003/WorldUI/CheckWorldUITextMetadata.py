from pathlib import Path
import hashlib
import json
import math
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
ns = {"s": "http://www.w3.org/2000/svg"}
manifest = json.loads((root / "WorldUIManifest.json").read_text(encoding="utf-8"))
required = {"name", "text", "x", "y", "width", "height", "fontFamily", "fontSize", "color", "opacity", "strokeColor", "strokeWidth", "strokeOpacity", "align"}
line_count = 0
for item in manifest["files"]:
    path = root / item["file"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]
    tree = ET.parse(path).getroot()
    origin_x, origin_y, viewport_width, viewport_height = map(float, tree.attrib["viewBox"].split())
    assert viewport_width == float(tree.attrib["width"])
    assert viewport_height == float(tree.attrib["height"])
    metadata = tree.find("s:metadata[@id='playground-text-layers']", ns)
    assert metadata is not None
    payload = json.loads(metadata.text)
    assert payload["version"] == 1
    rendered = []
    for text in tree.findall(".//s:text", ns):
        spans = text.findall("s:tspan", ns)
        if spans:
            rendered.extend((text, span) for span in spans)
        else:
            rendered.append((text, text))
    assert len(payload["texts"]) == len(rendered)
    for entry, (text, span) in zip(payload["texts"], rendered):
        assert set(entry) == required
        assert entry["text"] == span.text
        assert entry["align"] in ("LEFT", "CENTER", "RIGHT")
        assert entry["width"] > 0 and entry["height"] > 0
        assert all(math.isfinite(entry[key]) for key in ("x", "y", "width", "height", "fontSize", "opacity", "strokeWidth", "strokeOpacity"))
        size = float(text.attrib["font-size"])
        assert entry["fontSize"] == size
        assert entry["fontFamily"] == text.attrib["font-family"]
        assert entry["color"] == text.attrib["fill"]
        anchor = {"LEFT": 0, "CENTER": 0.5, "RIGHT": 1}[entry["align"]]
        expected_anchor_x = entry["x"] + entry["width"] * anchor
        assert abs(expected_anchor_x - (float(span.attrib["x"]) - origin_x)) < 0.001
        expected_baseline_y = entry["y"] + size * 0.82
        assert abs(expected_baseline_y - (float(span.attrib["y"]) - origin_y)) < 0.001
    line_count += len(payload["texts"])
print(json.dumps({"svgCount": len(manifest["files"]), "metadataLineCount": line_count, "metadataCoordinatesVerified": True, "allSVGHashesMatchManifest": True}))

