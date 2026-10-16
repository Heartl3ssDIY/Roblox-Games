"""Write portable Roblox XML animation files from the validated baked samples."""
import json
from pathlib import Path
import xml.etree.ElementTree as E

base = Path(__file__).parent / "exports"
specs = [("rock_lii_triple_punch", "RockLiiTriplePunch", 2, 91381829613134),
         ("rock_lii_drunken_fist", "RockLiiDrunkenFist", 3, 82528180377250)]
parents = {"Torso": "HumanoidRootPart", "Head": "Torso", "Right Arm": "Torso",
           "Left Arm": "Torso", "Right Leg": "Torso", "Left Leg": "Torso"}
names = ["HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]

def prop(parent, tag, name, value):
    E.SubElement(parent, tag, name=name).text = str(value)

for stem, name, priority, asset_id in specs:
    data = json.loads((base / (stem + ".keyframes.json")).read_text())
    root = E.Element("roblox", version="4")
    sequence = E.SubElement(root, "Item", {"class": "KeyframeSequence"})
    properties = E.SubElement(sequence, "Properties")
    prop(properties, "string", "Name", name)
    prop(properties, "bool", "Loop", "false")
    prop(properties, "token", "Priority", priority)
    for index, sample in enumerate(data["kfs"]):
        frame = E.SubElement(sequence, "Item", {"class": "Keyframe"})
        properties = E.SubElement(frame, "Properties")
        prop(properties, "string", "Name", f"Frame{index:03d}")
        prop(properties, "float", "Time", sample["t"])
        poses = {}
        for bone in names:
            pose = E.SubElement(poses.get(parents.get(bone), frame), "Item", {"class": "Pose"})
            poses[bone] = pose
            properties = E.SubElement(pose, "Properties")
            prop(properties, "string", "Name", bone)
            prop(properties, "float", "Weight", 0 if bone == "HumanoidRootPart" else 1)
            prop(properties, "token", "EasingStyle", 0)
            prop(properties, "token", "EasingDirection", 1)
            cf = E.SubElement(properties, "CoordinateFrame", name="CFrame")
            for key, value in zip(["X", "Y", "Z"] + [f"R{i}{j}" for i in range(3) for j in range(3)], sample["kf"][bone][0]):
                E.SubElement(cf, key).text = str(value)
        if stem.endswith("triple_punch") and index in (8, 19, 32):
            marker = E.SubElement(frame, "Item", {"class": "KeyframeMarker"})
            properties = E.SubElement(marker, "Properties")
            prop(properties, "string", "Name", "Hit")
            prop(properties, "string", "Value", (8, 19, 32).index(index) + 1)
    E.indent(root)
    E.ElementTree(root).write(base / (stem + ".rbxmx"), encoding="utf-8", xml_declaration=True)
    print(f"{name}: {len(data['kfs'])} keyframes; published {asset_id}")
