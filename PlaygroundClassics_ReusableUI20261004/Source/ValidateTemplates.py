from __future__ import annotations

import argparse
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"
IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
EPSILON = 0.05
TEMPLATE_COUNT = 11


def local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def number(value: str | None, default: float | None = None) -> float:
    if value is None and default is not None:
        return default
    if value is None or not re.fullmatch(rf"\s*({NUMBER})(?:px)?\s*", value):
        raise ValueError(f"Expected a finite number, found {value!r}")
    result = float(re.search(NUMBER, value).group())
    if not math.isfinite(result):
        raise ValueError(f"Non-finite number: {value!r}")
    return result


def multiply(a: tuple, b: tuple) -> tuple:
    return (
        a[0] * b[0] + a[2] * b[1],
        a[1] * b[0] + a[3] * b[1],
        a[0] * b[2] + a[2] * b[3],
        a[1] * b[2] + a[3] * b[3],
        a[0] * b[4] + a[2] * b[5] + a[4],
        a[1] * b[4] + a[3] * b[5] + a[5],
    )


def transform(value: str | None) -> tuple:
    if not value or not value.strip():
        return IDENTITY
    result = IDENTITY
    offset = 0
    for match in re.finditer(r"([A-Za-z]+)\s*\(([^)]*)\)", value):
        if value[offset:match.start()].strip(" \t\n\r,"):
            raise ValueError(f"Unsupported transform: {value!r}")
        raw = match.group(2)
        args = [float(token) for token in re.findall(NUMBER, raw)]
        if re.sub(NUMBER, "", raw).strip(" \t\n\r,") or not all(math.isfinite(arg) for arg in args):
            raise ValueError(f"Invalid transform arguments: {value!r}")
        name = match.group(1)
        if name == "translate" and len(args) in (1, 2):
            operation = (1, 0, 0, 1, args[0], args[1] if len(args) == 2 else 0)
        elif name == "scale" and len(args) in (1, 2):
            operation = (args[0], 0, 0, args[1] if len(args) == 2 else args[0], 0, 0)
        elif name == "matrix" and len(args) == 6:
            operation = tuple(args)
        elif name == "rotate" and len(args) in (1, 3):
            angle = math.radians(args[0])
            operation = (math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle), 0, 0)
            if len(args) == 3:
                operation = multiply(
                    multiply((1, 0, 0, 1, args[1], args[2]), operation),
                    (1, 0, 0, 1, -args[1], -args[2]),
                )
        elif name in ("skewX", "skewY") and len(args) == 1:
            slope = math.tan(math.radians(args[0]))
            operation = (1, 0, slope, 1, 0, 0) if name == "skewX" else (1, slope, 0, 1, 0, 0)
        else:
            raise ValueError(f"Unsupported transform: {value!r}")
        result = multiply(result, operation)
        offset = match.end()
    if offset == 0 or value[offset:].strip(" \t\n\r,"):
        raise ValueError(f"Unsupported transform: {value!r}")
    return result


def point(matrix: tuple, x: float, y: float) -> tuple:
    return matrix[0] * x + matrix[2] * y + matrix[4], matrix[1] * x + matrix[3] * y + matrix[5]


def rectangle_bounds(matrix: tuple, x: float, y: float, width: float, height: float) -> list:
    corners = [point(matrix, x, y), point(matrix, x + width, y), point(matrix, x, y + height), point(matrix, x + width, y + height)]
    return [min(p[0] for p in corners), min(p[1] for p in corners), max(p[0] for p in corners), max(p[1] for p in corners)]


def contains(outer: list, inner: list) -> bool:
    return inner[0] >= outer[0] - EPSILON and inner[1] >= outer[1] - EPSILON and inner[2] <= outer[2] + EPSILON and inner[3] <= outer[3] + EPSILON


def label_text(element: ET.Element) -> str:
    return " ".join("".join(element.itertext()).split())


def is_button_control(element: ET.Element) -> bool:
    semantic_attributes = ("data-template", "data-component", "data-control", "data-kind", "role")
    for attribute in semantic_attributes:
        value = element.get(attribute, "").lower()
        if value in ("button", "action-button", "actionbutton", "common-button", "commonbutton"):
            return True
    identifier = element.get("id", "")
    if re.search(r"(?:^|[-_])(?:button|actionbutton|commonbutton)(?:$|[-_])", identifier, re.IGNORECASE):
        return True
    if local_name(element.tag) == "g":
        has_rectangle = any(local_name(child.tag) == "rect" for child in element)
        texts = [label_text(child).upper() for child in element if local_name(child.tag) == "text"]
        return has_rectangle and any(text in ("BUY", "USE", "EQUIP", "ACTION", "SPRINT", "DODGE", "ADMIN", "SHOP") for text in texts)
    return False


def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def find_slot(master: ET.Element, role_names: tuple, id_fragments: tuple = (), tags: tuple = ()) -> ET.Element | None:
    roles = {normalized(role) for role in role_names}
    fragments = tuple(normalized(fragment) for fragment in id_fragments)
    for element in master.iter():
        if tags and local_name(element.tag) not in tags:
            continue
        role = normalized(element.get("data-slot", ""))
        identifier = normalized(element.get("id", ""))
        if role in roles or any(fragment in identifier for fragment in fragments):
            return element
    return None


def coverage_checks(masters: list, errors: list) -> dict:
    by_name = {master.get("data-template", ""): master for master in masters}
    checks = {}

    def require(master_name: str, label: str, roles: tuple, ids: tuple = (), tags: tuple = ()) -> ET.Element | None:
        master = by_name.get(master_name)
        found = find_slot(master, roles, ids, tags) if master is not None else None
        checks[label] = found.get("id") or local_name(found.tag) if found is not None else None
        if found is None:
            errors.append(f"Missing authored coverage slot: {label}")
        return found

    require("round-header", "Header left count", ("left-count", "count-left", "left-value"), ("LeftCount", "CountLeft", "LeftStatCount"), ("text",))
    require("round-header", "Header right count", ("right-count", "count-right", "right-value"), ("RightCount", "CountRight", "RightStatCount"), ("text",))
    require("round-header", "Header phase/crossing", ("phase", "crossing", "phase-label"), ("RoundHeader_Phase", "RoundHeader_Crossing"), ("text",))
    require("player-card", "Player XP track", ("xp-track", "xp-meter"), ("XPTrack",), ("rect",))
    require("player-card", "Player XP fill", ("xp-fill", "xp-progress"), ("XPFill", "XPTrack_Fill"), ("rect",))
    require("button", "Button optional icon slot", ("icon", "icon-slot", "optional-icon"), ("Button_IconSlot",))
    hint = require("button", "Button optional hint slot", ("hint", "key-hint", "keyboard-hint", "optional-hint"), ("Button_Hint", "Button_KeyHint"), ("text",))
    if hint is not None and not label_text(hint):
        errors.append("Button hint slot must retain editable SVG text")
    require("scrollbar", "Scrollbar track", ("scroll-track", "scrollbar-track", "track"), ("Scrollbar_Track",), ("rect",))
    require("scrollbar", "Scrollbar thumb", ("scroll-thumb", "scrollbar-thumb", "thumb"), ("Scrollbar_Thumb",), ("rect",))
    require("compact-badge", "Badge optional support line", ("optional-support", "support", "support-line"), ("Badge_Support",), ("text",))
    require("compact-badge", "Badge optional count", ("optional-count", "count", "count-box"), ("Badge_Count",))

    item_card = by_name.get("item-card")
    for identifier in ("ItemCard_ActionSlot", "ItemCard_TrySlot"):
        guide = next((element for element in item_card.iter() if element.get("id") == identifier), None) if item_card is not None else None
        checks[identifier] = guide.get("id") if guide is not None else None
        if guide is None:
            errors.append(f"Missing reusable Button placement guide: {identifier}")
            continue
        if guide.get("data-slot") != "button" or guide.get("data-guide", "").lower() != "true":
            errors.append(f"Button placement must be marked data-slot='button' and data-guide='true': {identifier}")
        for element in guide.iter():
            if local_name(element.tag) in ("rect", "circle", "ellipse", "polygon", "path"):
                fill = element.get("fill", "none").lower()
                opacity = number(element.get("fill-opacity"), 1)
                if fill not in ("none", "transparent") and opacity > 0:
                    errors.append(f"Button placement guide must not contain duplicated button artwork: {identifier}")
            if local_name(element.tag) == "text" and label_text(element).upper() in ("BUY", "USE", "EQUIP", "SPRINT", "DODGE", "ADMIN", "SHOP"):
                errors.append(f"Button placement guide contains an actual action label: {identifier}")
    return checks


def validate(svg_path: Path) -> dict:
    report = {
        "svg": str(svg_path.resolve()),
        "checkedAtUTC": datetime.now(timezone.utc).isoformat(),
        "valid": False,
        "errors": [],
        "warnings": [],
        "templates": [],
    }
    errors = report["errors"]
    if not svg_path.is_file():
        errors.append(f"Missing canonical SVG: {svg_path.name}")
        return report
    other_svgs = sorted(str(path.relative_to(svg_path.parent)) for path in svg_path.parent.rglob("*.svg") if path.resolve() != svg_path.resolve())
    report["additionalSVGFiles"] = other_svgs
    if other_svgs:
        errors.append("The minimal pack contains additional SVG files: " + ", ".join(other_svgs))
    try:
        root = ET.parse(svg_path).getroot()
    except (ET.ParseError, OSError) as exc:
        errors.append(f"Cannot parse SVG: {exc}")
        return report
    if local_name(root.tag) != "svg":
        errors.append("Root element must be svg")
        return report
    try:
        viewbox = root.get("viewBox")
        if viewbox:
            values = [float(token) for token in re.findall(NUMBER, viewbox)]
            if len(values) != 4 or re.sub(NUMBER, "", viewbox).strip(" \t\n\r,"):
                raise ValueError("Invalid viewBox")
            x, y, width, height = values
        else:
            x, y = 0, 0
            width, height = number(root.get("width")), number(root.get("height"))
        if not all(math.isfinite(value) for value in (x, y, width, height)) or width <= 0 or height <= 0:
            raise ValueError("Board dimensions must be finite and positive")
        board_bounds = [x, y, x + width, y + height]
        report["boardBounds"] = board_bounds
    except ValueError as exc:
        errors.append(str(exc))
        return report

    identifiers = {}
    internal_references = []
    live_text_count = 0
    masters = [element for element in root if local_name(element.tag) == "g" and element.get("data-template") is not None]
    all_masters = [element for element in root.iter() if element.get("data-template") is not None]
    report["templateCount"] = len(masters)
    if len(masters) != TEMPLATE_COUNT:
        errors.append(f"Expected exactly {TEMPLATE_COUNT} top-level template groups, found {len(masters)}")
    if len(all_masters) != len(masters):
        errors.append("Template masters must be direct top-level g elements; nested masters are not allowed")
    template_names = [element.get("data-template", "").strip().lower() for element in masters]
    if any(not name for name in template_names) or len(set(template_names)) != len(template_names):
        errors.append("Template names must be nonempty and unique")
    if template_names.count("button") != 1:
        errors.append("Expected exactly one data-template='button' master")
    for required in ("compact-badge", "scrollbar"):
        if required not in template_names:
            errors.append(f"Required distinct template is missing: {required}")

    for element in root.iter():
        tag = local_name(element.tag)
        identifier = element.get("id")
        if identifier:
            if identifier in identifiers:
                errors.append(f"Duplicate SVG id: {identifier}")
            identifiers[identifier] = element
        if tag in ("image", "script", "foreignObject"):
            errors.append(f"Disallowed SVG element: {tag}")
        if tag == "text" and label_text(element):
            live_text_count += 1
        for attribute, value in element.attrib.items():
            if local_name(attribute) == "href":
                if value.startswith("#") and len(value) > 1:
                    internal_references.append(value[1:])
                else:
                    errors.append(f"External or embedded href is not allowed: {identifier or tag}")
            if "data:image" in value.lower() or "base64," in value.lower():
                errors.append(f"Embedded raster/data asset found: {identifier or tag}")
            for match in re.finditer(r"url\(\s*['\"]?([^)'\"]+)", value, re.IGNORECASE):
                reference = match.group(1).strip()
                if reference.startswith("#"):
                    internal_references.append(reference[1:])
                else:
                    errors.append(f"External CSS URL is not allowed: {identifier or tag}")
        if tag == "style":
            style = "".join(element.itertext())
            if re.search(r"@import|https?://|data:image|base64,", style, re.IGNORECASE):
                errors.append("External or embedded assets are not allowed in SVG styles")

    for reference in sorted(set(internal_references)):
        if reference not in identifiers:
            errors.append(f"Unresolved internal reference: #{reference}")
    report["uniqueIds"] = len(identifiers)
    report["liveTextLayers"] = live_text_count
    if live_text_count == 0:
        errors.append("Editable SVG text labels are missing")

    for master in masters:
        name = master.get("data-template", "")
        identifier = master.get("id", "")
        entry = {"template": name, "id": identifier, "rectanglesChecked": 0}
        report["templates"].append(entry)
        if not identifier:
            errors.append(f"Template master has no id: {name}")
        try:
            component_width = number(master.get("data-width"))
            component_height = number(master.get("data-height"))
            if component_width <= 0 or component_height <= 0:
                raise ValueError("Component dimensions must be positive")
            master_matrix = transform(master.get("transform"))
            component_bounds = rectangle_bounds(master_matrix, 0, 0, component_width, component_height)
            entry["declaredSize"] = [component_width, component_height]
            entry["boardBounds"] = component_bounds
            if not contains(board_bounds, component_bounds):
                errors.append(f"Template declared bounds extend beyond the board: {name}")

            def check_rectangles(element: ET.Element, parent_matrix: tuple) -> None:
                matrix = multiply(parent_matrix, transform(element.get("transform")))
                if local_name(element.tag) == "rect":
                    rect_width = number(element.get("width"))
                    rect_height = number(element.get("height"))
                    if rect_width < 0 or rect_height < 0:
                        raise ValueError("Rectangle dimensions cannot be negative")
                    bounds = rectangle_bounds(matrix, number(element.get("x"), 0), number(element.get("y"), 0), rect_width, rect_height)
                    entry["rectanglesChecked"] += 1
                    if not contains(component_bounds, bounds):
                        errors.append(f"Rectangle exceeds declared component bounds: {name}/{element.get('id', 'rect')}")
                    if not contains(board_bounds, bounds):
                        errors.append(f"Rectangle extends beyond the board: {name}/{element.get('id', 'rect')}")
                for child in element:
                    check_rectangles(child, matrix)

            for child in master:
                check_rectangles(child, master_matrix)
        except ValueError as exc:
            errors.append(f"Invalid component geometry for {name}: {exc}")
        text_layers = sum(1 for element in master.iter() if local_name(element.tag) == "text" and label_text(element))
        entry["liveTextLayers"] = text_layers
        normalized = re.sub(r"[^a-z]", "", name.lower())
        if text_layers == 0 and normalized not in ("iconpalette", "icons", "scrollbar"):
            errors.append(f"Template has no editable text label: {name}")
        if normalized != "button":
            nested_controls = [element.get("id") or local_name(element.tag) for element in master.iter() if element is not master and is_button_control(element)]
            if nested_controls:
                errors.append(f"Repeated button controls inside {name}: " + ", ".join(nested_controls))

    try:
        report["coverageSlots"] = coverage_checks(masters, errors)
    except ValueError as exc:
        errors.append(f"Invalid coverage slot geometry: {exc}")

    restoration_metadata = identifiers.get("playground-reusable-templates")
    if restoration_metadata is not None:
        try:
            payload = json.loads("".join(restoration_metadata.itertext()))
            components = payload.get("components", [])
            component_keys = [component.get("key") for component in components]
            if len(components) != TEMPLATE_COUNT or len(set(component_keys)) != TEMPLATE_COUNT or set(component_keys) != set(template_names):
                errors.append(f"Figma metadata components must match the {TEMPLATE_COUNT} template masters exactly")
            metadata_text_count = 0
            text_names = set()
            master_by_id = {master.get("id"): master for master in masters}
            for component in components:
                master = master_by_id.get(component.get("id"))
                if master is None or master.get("data-template") != component.get("key"):
                    errors.append(f"Figma metadata references an unknown template: {component.get('key')}")
                    continue
                width = number(master.get("data-width"))
                height = number(master.get("data-height"))
                origin = point(transform(master.get("transform")), 0, 0)
                for field, expected in (("width", width), ("height", height), ("x", origin[0]), ("y", origin[1])):
                    actual = number(str(component.get(field)))
                    if abs(actual - expected) > EPSILON:
                        errors.append(f"Figma metadata {field} does not match the SVG template: {component.get('key')}")
                master_text_ids = {element.get("id") for element in master.iter() if local_name(element.tag) == "text" and label_text(element)}
                listed_text_ids = set()
                for text in component.get("texts", []):
                    metadata_text_count += 1
                    name = text.get("name")
                    listed_text_ids.add(name)
                    if name in text_names:
                        errors.append(f"Duplicate Figma metadata text name: {name}")
                    text_names.add(name)
                    element = identifiers.get(name)
                    if element is None or local_name(element.tag) != "text" or name not in master_text_ids:
                        errors.append(f"Figma metadata references missing template text: {name}")
                    elif " ".join(str(text.get("text", "")).split()) != label_text(element):
                        errors.append(f"Figma metadata text differs from the SVG label: {name}")
                    x, y, text_width, text_height = (number(str(text.get(field))) for field in ("x", "y", "width", "height"))
                    if text_width <= 0 or text_height <= 0 or not contains([0, 0, width, height], [x, y, x + text_width, y + text_height]):
                        errors.append(f"Figma metadata text box exceeds its template bounds: {name}")
                if master_text_ids != listed_text_ids:
                    errors.append(f"Figma metadata does not cover every live text layer in: {component.get('key')}")
            report["metadataTextLayers"] = metadata_text_count
        except (json.JSONDecodeError, TypeError, AttributeError, ValueError) as exc:
            errors.append(f"Invalid Figma restoration metadata: {exc}")

    report["errors"] = list(dict.fromkeys(errors))
    report["valid"] = not report["errors"]
    return report


def main() -> int:
    package_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Validate the single reusable Playground UI template board.")
    parser.add_argument("--svg", type=Path, default=package_root / "Playground-UI-Templates.svg")
    parser.add_argument("--report", type=Path, default=package_root / "Validation.json")
    args = parser.parse_args()
    result = validate(args.svg)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"valid": result["valid"], "templateCount": result.get("templateCount", 0), "errors": result["errors"], "report": str(args.report.resolve())}, indent=2))
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    sys.exit(main())
