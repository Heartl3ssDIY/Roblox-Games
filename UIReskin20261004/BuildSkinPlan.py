import json
import math
import re
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PACK = ROOT.parent / "PlaygroundClassics-CleanImport-20261004"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


nodes = read(ROOT / "Before/GuiLayout.json")
by_path = {node["path"]: node for node in nodes}
inventory = read(ROOT / "AssetInventory.json")
styles = read(ROOT / "TextStyleRecommendations.json")
upload = read(ROOT / "UploadPlan.json")
asset_info = {asset["png"]: asset for asset in inventory["assets"]}
component_map = read(PACK / "Maps/ComponentMap.json")
explicit = {}
for item in component_map:
    path = re.sub(r"_Background(?:-Glossy)?$", "", item["node"])
    explicit.setdefault(path, "PNG/" + item["asset"][:-4] + ".png")

template_root = "StarterGui.PlaygroundShell.Templates.ItemCard"
for path, asset in list(explicit.items()):
    if path.startswith(template_root):
        for number in range(1, 13):
            explicit[f"StarterGui.PlaygroundShell.ShopPanel.Cards.Slot{number:02}" + path[len(template_root):]] = asset
    if ".PlaygroundAdminPanel.Panel" in path:
        explicit.setdefault(path.replace(".Panel", ".CompactPanel", 1), asset)
    if ".MudHUD.Main.Controls." in path:
        explicit[path.replace(".Controls.", ".DesktopControls.", 1)] = asset

favourites = dict(inventory["recommendedFavouriteOverrides"])
for path, asset in list(favourites.items()):
    if ".MudHUD.Main.Controls." in path:
        favourites[path.replace(".Controls.", ".DesktopControls.", 1)] = asset
for node in nodes:
    if node["path"].endswith(".Close") and node["class"] == "TextButton":
        favourites[node["path"]] = "PNG/05-Favourite-Buttons-Blank/close.png"
    if node["path"].endswith(".Sprint") and node["class"] == "TextButton":
        ratio = node["absolute"][0] / node["absolute"][1]
        options = ["PNG/05-Favourite-Buttons-Blank/sprint.png", "PNG/05-Favourite-Buttons-Blank/sprint-wide.png"]
        favourites[node["path"]] = min(options, key=lambda asset: abs(math.log(ratio / (asset_info[asset]["actualSize"][0] / asset_info[asset]["actualSize"][1]))))
        if node["path"] == "StarterGui.BritishBulldogHUD.MovementControls.Sprint":
            favourites[node["path"]] = "PNG/05-Favourite-Buttons-Blank/sprint.png"
    if node["path"].endswith(".Dodge") and node["class"] == "TextButton":
        favourites[node["path"]] = "PNG/05-Favourite-Buttons-Blank/dodge.png"

FULL_CONTAINER_PANELS = {
    "StarterGui.PlaygroundShell.ShopPanel": "Shop title, close button and status lie outside horizontally letterboxed fixed artwork.",
    "StarterGui.TagHUD.Results": "Result title reaches beyond the fixed artwork's inset after horizontal letterboxing.",
    "StarterGui.PlaygroundAdminPanel.CompactPanel": "Compact header and close button reach into the top gap from vertically letterboxed artwork.",
    "StarterGui.PlaygroundShell.LevelPanel": "Portrait and level/XP text extend beyond the fixed artwork's horizontal inset.",
    "StarterGui.PlaygroundShell.CompactVotePanel": "Full-width vote message extends beyond horizontally letterboxed artwork.",
    "StarterGui.MudHUD.Main.Frozen": "Frozen title and rescue status extend beyond horizontally letterboxed artwork.",
}

PALETTE = {
    "blue": (42, 160, 255), "red": (255, 81, 92),
    "green": (94, 203, 162), "gold": (255, 211, 78),
    "cream": (255, 255, 248), "black": (43, 48, 57),
    "orange": (255, 158, 69), "purple": (162, 110, 226),
    "silver": (194, 201, 206), "mud": (151, 94, 44),
}
VARIANT_ASSETS = {key.title(): f"PNG/07-Resizable-Skins/{key}-normal.png" for key in PALETTE}
VARIANT_ASSETS["Pink"] = "PNG/07-Resizable-Skins/red-normal.png"
SLICE_CENTER = [88, 88, 424, 232]


def nearest_theme(node):
    rgb = [value * 255 for value in node.get("color", [1, 1, 1])]
    return min(PALETTE, key=lambda key: sum((a - b) ** 2 for a, b in zip(rgb, PALETTE[key])))


def inferred_theme(node):
    path = node["path"]
    name = path.rsplit(".", 1)[-1]
    if path.startswith("StarterGui.BritishBulldogHUD"):
        if "BulldogChip" in path:
            return "red"
        if "RunnerChip" in path or "RolePill.Panel" in path:
            return "blue"
        if name == "SecondsBadge":
            return "cream"
        if ".Departure.Panel" in path or ".CompactDeparture.Panel" in path or ".Tagged.Panel" in path or name == "EscapeBoost":
            return "gold"
    if name in ("Meter", "Top", "Results", "ColourPicker", "Frozen", "Wallet", "ShopPanel", "LevelPanel", "CompactLevelPanel", "VotePanel", "CompactVotePanel", "Preview", "ItemCard") or re.fullmatch(r"Slot\d{2}", name):
        return "panel"
    if ".PlaygroundAdminPanel." in path and node["class"] == "Frame":
        return "panel"
    if path.endswith(".TopCard.Panel") or path.endswith(".Results.Panel"):
        return "panel"
    if name == "Close":
        return "silver"
    if name == "Mud":
        return "mud"
    if name == "Heat":
        return "orange"
    if name in ("Fire", "Dodge", "Vault"):
        return "blue" if ".TagHUD.Controls.Dodge" in path else "gold"
    if name == "Team" or name == "Sprint":
        return "blue"
    if name in ("Red", "Blue", "Green", "Black"):
        return name.lower()
    return nearest_theme(node)


def is_vote(path):
    return bool(re.search(r"\.PlaygroundShell\.(?:Compact)?VotePanel\.(BritishBulldog|TagYoureIt|StuckInTheMud)$", path))


def is_dynamic(node):
    path = node["path"]
    if is_vote(path):
        return False
    if path in ("StarterGui.BritishBulldogHUD.RolePill.Panel", "StarterGui.TagHUD.Role", "StarterGui.MudHUD.Main.Top.Team"):
        return True
    if path.endswith(".Sprint") or path.startswith("StarterGui.TagHUD.Controls."):
        return True
    if ".PlaygroundAdminPanel." in path and node["class"] == "TextButton" and not path.endswith(".Close"):
        return True
    if ".ShopPanel.Categories." in path:
        return True
    if (".ShopPanel.Cards.Slot" in path or path.startswith(template_root)) and path.endswith(".Action"):
        return True
    return False


def transformed_face(asset):
    svg = PACK / asset.replace("PNG/", "Editable/", 1).replace(".png", ".svg")
    root = ET.parse(svg).getroot()
    width, height = map(float, root.attrib["viewBox"].split()[2:])
    result = None

    def visit(element, tx=0, ty=0):
        nonlocal result
        transform = element.get("transform", "")
        match = re.fullmatch(r"translate\(([-\d.]+)[ ,]+([-\d.]+)\)", transform)
        if match:
            tx += float(match[1])
            ty += float(match[2])
        if element.get("id", "").endswith("-Face"):
            result = [float(element.get("x")) + tx, float(element.get("y")) + ty, float(element.get("width")), float(element.get("height"))]
        for child in element:
            visit(child, tx, ty)

    visit(root)
    return (width, height), result


def fit_text_rect(node, asset):
    width, height = node["absolute"]
    source_size, face = transformed_face(asset)
    if not face:
        return [0.06, 0.10, 0.88, 0.78]
    scale = min(width / source_size[0], height / source_size[1])
    origin_x = (width - source_size[0] * scale) / 2
    origin_y = (height - source_size[1] * scale) / 2
    pad_x = min(4, face[2] * .08)
    pad_y = min(2, face[3] * .06)
    return [round((origin_x + (face[0] + pad_x) * scale) / width, 6), round((origin_y + (face[1] + pad_y) * scale) / height, 6), round((face[2] - 2 * pad_x) * scale / width, 6), round((face[3] - 2 * pad_y) * scale / height, 6)]


def slice_text_rect(node):
    width, height = node["absolute"]
    left = min(12, width * .20)
    top = min(10.5, height * .18)
    bottom = min(14.5, height * .25)
    return [round(left / width, 6), round(top / height, 6), round((width - 2 * left) / width, 6), round((height - top - bottom) / height, 6)]


def fits(node, asset):
    width, height = node["absolute"]
    source_width, source_height = asset_info[asset]["actualSize"]
    return abs((width / height) / (source_width / source_height) - 1) <= .10


def meter_mapping(node, fill=False):
    path = node["path"]
    kind = "xp" if ".XPTrack" in path else "stamina"
    asset = f"PNG/04-Meter-Parts/{kind}-{'fill' if fill else 'track'}.png"
    source_width, source_height = asset_info[asset]["actualSize"]
    return {
        "path": path, "asset": asset, "mode": "Slice",
        "sliceCenter": [28, 24, source_width - 28, 32],
        "sliceScale": round(node["absolute"][1] / source_height, 7),
        "role": "meterFill" if fill else "meterTrack",
        "reason": "Seven logical pixels retain each round end; the middle is flat. SliceScale fits source height to existing authored height.",
        "dynamic": False, "selectionFromColour": False, "selectionFromOutline": False,
        "gradientSource": path + ".Progress" if fill else None,
    }


mappings = []
meter_fills = []
skipped = []
clear_shadows = []
legacy_skins = []
uncovered = []
icons = []
native_indicators = []

for node in nodes:
    path = node["path"]
    name = path.rsplit(".", 1)[-1]
    kind = node["class"]
    skip_reason = None
    if "Leaderboard" in path:
        skip_reason = "Leaderboard artwork deferred by user."
    elif name == "Shadow":
        clear_shadows.append(path)
        skip_reason = "Existing geometric shadow will be hidden; new artwork includes its own bevel."
    elif name == "TextlessSkin":
        legacy_skins.append(path)
        skip_reason = "Previous generated skin wrapper; replaced by a single ReusableSkin under the control."
    elif path == "StarterGui.PlaygroundShell.Backdrop":
        skip_reason = "Modal scrim: preserve native translucent full-screen blocker."
    elif ".Crosshair" in path:
        skip_reason = "Functional reticle, preserve native bars."
    elif name in ("FacePreview", "ViewportFaces") or ".FacePreview." in path:
        skip_reason = "Real player portrait viewport is retained."
    elif name == "TeamColour":
        native_indicators.append(path)
        skip_reason = "Narrow live team-colour indicator, retain native colour strip."
    elif path == "StarterGui.PlaygroundShell.Wallet.Coin":
        icons.append({"path": path, "asset": "Attachments/icon-coin.png", "mode": "Fit", "replaceBackground": True, "clearText": [path + ".Symbol"]})
        skip_reason = "Supplied original coin icon replaces old circular star-as-coin decoration."
    elif kind == "ImageLabel":
        icon_key = "icon-sprint-lightning" if name == "Icon" and ".Sprint." in path else "icon-dodge-arrow" if name == "Icon" and ".Dodge." in path else "icon-xp-star" if name == "LevelIcon" else None
        if icon_key:
            icons.append({"path": path, "asset": f"Attachments/{icon_key}.png", "mode": "Fit", "replaceImage": True})
        skip_reason = "Image content handled by supplied icon mapping; no panel skin."
    elif name == "Fill" and any(token in path for token in (".Track.Fill", ".XPTrack.Fill", ".RescueTrack.Fill")):
        entry = meter_mapping(node, fill=True)
        entry["currentColorRGB"] = [round(value * 255) for value in node["color"]]
        if ".BritishBulldogHUD." in path or ".TagHUD." in path or ".RescueTrack.Fill" in path:
            entry["colourPolicy"] = "PreserveNativeFill"
            entry["reason"] += " Native role/rescue colour is significant. The supplied fill is blue and cannot be recoloured faithfully by multiplicative ImageColor3; keep this native coloured fill plus its Progress gradient, within the new artwork track."
        else:
            entry["colourPolicy"] = "UseBlueArtwork"
            entry["copyProgressGradient"] = True
        meter_fills.append(entry)
        skip_reason = "Meter fill handled separately with progress and colour policy."
    elif kind in ("Frame", "ScrollingFrame") and node.get("background", 1) >= 1 and path not in explicit:
        skip_reason = "Transparent layout-only container."
    elif kind == "TextLabel" and node.get("background", 1) >= 1:
        skip_reason = "Text-only label; native editable glyph style handled separately."
    elif kind not in ("Frame", "TextButton", "TextLabel", "ViewportFrame"):
        skip_reason = "Non-panel GUI type."
    if skip_reason:
        skipped.append({"path": path, "reason": skip_reason})
        continue

    if name in ("Track", "XPTrack", "RescueTrack"):
        mappings.append(meter_mapping(node))
        continue

    theme = inferred_theme(node)
    dynamic = is_dynamic(node)
    selection_colour = is_vote(path) or ".ShopPanel.Categories." in path
    selection_outline = path.endswith((".Controls.Mud", ".Controls.Heat", ".DesktopControls.Mud", ".DesktopControls.Heat"))
    candidate = explicit.get(path)
    origin = "ComponentMap explicit/expanded mapping" if candidate else "Semantic fallback for authored visible background"
    if is_vote(path):
        game_name = path.rsplit(".", 1)[-1]
        candidate = inventory["gameCardReuse"][game_name]
        theme = {"BritishBulldog": "blue", "TagYoureIt": "red", "StuckInTheMud": "green"}[game_name]
        origin = "Three reusable smooth game cards"
    elif path in favourites:
        candidate = favourites[path]
        origin = "User's reusable favourite blank control"

    if path in favourites:
        dynamic = False
    force_panel = path in FULL_CONTAINER_PANELS
    if force_panel:
        theme = "panel"
    use_fixed = not force_panel and candidate is not None and (path in favourites or fits(node, candidate) and not dynamic)
    if use_fixed:
        asset = candidate
        mode = "Fit"
        if path in favourites:
            reason = origin + "; retain exact halftone artwork regardless of aspect difference, with Fit and text authored inside the actual coloured face."
        else:
            reason = origin + "; actual artwork aspect is within ten percent of the authored control."
    else:
        asset = f"PNG/07-Resizable-Skins/{theme}-normal.png"
        mode = "Slice"
        reason = origin + "; reusable slice preserves authored dimensions."
        if dynamic:
            reason += " Matching 512x320 colour variants are required for runtime image-only state swaps."
        elif candidate:
            reason += " Fixed artwork aspect differs by more than ten percent."
        if force_panel:
            reason = FULL_CONTAINER_PANELS[path] + " Nine-slice panel fills the authored container without moving edge controls."
    record = {
        "path": path, "asset": asset, "mode": mode, "theme": theme,
        "dynamic": dynamic, "selectionFromColour": selection_colour,
        "selectionFromOutline": selection_outline, "reason": reason,
        "originalClass": kind, "originalAbsoluteSize": node["absolute"],
        "textFaceRect": fit_text_rect(node, asset) if mode == "Fit" else slice_text_rect(node),
    }
    if mode == "Slice":
        record["sliceCenter"] = SLICE_CENTER
        record["sliceScale"] = .25
        if min(node["absolute"]) < 48:
            record["belowRecommendedMinimum"] = True
    if candidate:
        record["preferredFixedAsset"] = candidate
    if path in favourites:
        record["fixedFavourite"] = True
        record["paletteSwapping"] = False
        record["feedbackPolicy"] = "Preserve exact image; native labels, hover tint and existing selection marks provide state feedback."
    if dynamic:
        record["variantAssets"] = VARIANT_ASSETS
    if selection_colour:
        record["selectionDescription"] = "Existing controller gold BackgroundColor3 drives a separate SelectionMark; preserve game colour/card art."
    if selection_outline:
        record["selectionDescription"] = "Existing Mud/Heat Outline.Enabled drives SelectionMark; keep Outline instance available to game logic, suppress its frame-border rendering."
    if kind == "ViewportFrame":
        record["viewportBackgroundOnly"] = True
        record["reason"] += " Original placeholder contents are removed separately; this retains the authored empty ViewportFrame."
    mappings.append(record)

mapped_paths = {record["path"] for record in mappings}
icons.append({
    "path": "StarterGui.PlaygroundShell.Dock.Emoji",
    "asset": "Attachments/icon-heart.png", "mode": "Fit",
    "createChild": True, "childName": "ArtworkIcon", "replaceText": True,
    "imageRect": [.20, .10, .60, .70],
})
assert all(record["path"] in by_path for record in icons)
separate_paths = {record["path"] for record in meter_fills + icons}
skipped_paths = {record["path"] for record in skipped}
for node in nodes:
    if node["path"] not in mapped_paths | separate_paths | skipped_paths:
        uncovered.append(node["path"])
used_assets = {record["asset"] for record in mappings + meter_fills + icons}
for record in mappings:
    used_assets.update(record.get("variantAssets", {}).values())
missing_upload = sorted(used_assets - upload["assetToFile"].keys())
assert not uncovered, uncovered
assert not missing_upload, missing_upload
assert len(mapped_paths) == len(mappings)
assert not any("Leaderboard" in path for path in mapped_paths)

library_assets = {}
for file in upload["files"]:
    for asset in file["relativeAssetPaths"]:
        metadata = {
            "width": file["width"], "height": file["height"],
            "mode": "Fit", "sha256": file["sha256"],
            "sourceFile": file["uploadFile"],
        }
        if asset in asset_info:
            metadata["logicalSize"] = asset_info[asset]["logicalSize"]
        if asset.startswith("PNG/07-Resizable-Skins/"):
            metadata.update(mode="Slice", sliceCenter=SLICE_CENTER, sliceScale=.25)
        elif asset.startswith("PNG/04-Meter-Parts/"):
            metadata.update(mode="Slice", sliceCenter=[28, 24, file["width"] - 28, 32], sliceScale=.25)
        library_assets[asset] = metadata

plan = {
    "schemaVersion": 1,
    "sourceLayout": str(ROOT / "Before/GuiLayout.json"),
    "mappings": mappings, "meterFills": meter_fills, "icons": icons,
    "libraryAssets": library_assets,
    "clearShadows": clear_shadows, "clearLegacySkins": legacy_skins,
    "clearIconFallbacks": [node["path"] for node in nodes if node["path"].endswith(".IconFallback")],
    "nativeIndicators": native_indicators,
    "textFaceRectFormat": "Normalized [x,y,width,height] in the existing target; only for authored caption descendants, never changes outer control layout.",
    "preserveProperties": ["Parent", "Name", "Position", "Size", "AnchorPoint", "LayoutOrder", "AutomaticSize", "Visible", "Active"],
    "coverage": {
        "nativeGuiNodes": len(nodes), "mappedBackgrounds": len(mappings),
        "mappingModes": dict(Counter(record["mode"] for record in mappings)),
        "dynamicSkins": sum(record["dynamic"] for record in mappings),
        "separateMeterFills": len(meter_fills), "iconPlacements": len(icons),
        "clearShadows": len(clear_shadows), "oldSkinWrappers": len(legacy_skins),
        "uniqueReferencedAssets": len(used_assets), "uncovered": uncovered,
        "missingUploadAssets": missing_upload,
        "slotFrames": len([path for path in mapped_paths if re.search(r"\.Cards\.Slot\d{2}$", path)]),
        "slotPreviews": len([path for path in mapped_paths if re.search(r"\.Cards\.Slot\d{2}\.Preview$", path)]),
        "slotActions": len([path for path in mapped_paths if re.search(r"\.Cards\.Slot\d{2}\.Action$", path)]),
    },
    "skipped": skipped,
    "notes": [
        "All artwork is blank and labels remain native editable text. No old product names/prices/previews are reintroduced by this mapping.",
        "The normal 07 assets include the requested own artwork outline. Native text uses one Contextual UIStroke, independently of panel imagery.",
        "Default plain panels are light cream; text colour/stroke authoring is handled separately by the installer.",
        "The provided 07 family has no pink theme. Compact Tag vote cards that cannot preserve fixed-card proportions use red, the same warm hue family; normal vote uses exact supplied pink game-card art.",
        "Meter SliceCenter inferred from SVG geometry: source rounded rail/fill has radius5 logical px and2px transparent margin, so end caps need28 raster px on each side. Eight raster-pixel vertical slice preserves flat middle.",
        "Do not skin modal Backdrop, reticles, avatar viewports, old TextlessSkin wrappers, or transparent layout Frames.",
        "Leaderboard artwork is deferred. There are no world SurfaceGui mappings.",
        "This plan is based on edit-time snapshot dimensions. Favourite controls always preserve their exact halftone art with Fit, and captions are inset to the fitted coloured face. Other fixed artwork uses a ten-percent aspect tolerance.",
        "Large panels with edge controls use full-container nine-slice artwork where fixed-image letterboxing would leave text, portrait or close controls outside the art.",
    ],
}
(ROOT / "SkinPlan.json").write_text(json.dumps(plan, indent=2), encoding="utf-8")
initial_path = ROOT / "InitialSkinPlan.json"
if initial_path.exists():
    initial = read(initial_path)
    initial_mappings = {record["path"]: record for record in initial["mappings"]}
    changed = [record for record in mappings if initial_mappings.get(record["path"]) != record]
    change_plan = {
        "schemaVersion": 1,
        "baseline": str(initial_path),
        "mappings": changed,
        "changedCount": len(changed),
        "disablePaletteSwapping": [record["path"] for record in changed if record.get("fixedFavourite")],
        "changedPanels": [record["path"] for record in changed if record["path"] in FULL_CONTAINER_PANELS],
        "instruction": "Update only skin image, Fit/Slice properties, DefaultImage/UISkinDynamic state and the authored caption's textFaceRect. Keep outer hierarchy/positions/sizes and selection marks unchanged. Never rerun full builder solely for this refinement.",
    }
    (ROOT / "SkinPlanChanges.json").write_text(json.dumps(change_plan, indent=2), encoding="utf-8")
print(json.dumps(plan["coverage"], indent=2))
