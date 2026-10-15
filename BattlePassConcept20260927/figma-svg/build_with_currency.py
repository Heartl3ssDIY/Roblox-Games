from __future__ import annotations

import base64
import xml.etree.ElementTree as ET
from pathlib import Path


SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", XLINK)

root_dir = Path(__file__).resolve().parent
source = root_dir / "battle-pass-layout.svg"
output = root_dir / "battle-pass-with-currency.svg"
art_dir = root_dir.parent / "preview" / "assets"

art = {
    "COINS": art_dir / "reward-coin.png",
    "DIAMONDS": art_dir / "reward-diamond.png",
    "MASTERY COINS": art_dir / "reward-mastery.png",
}
encoded = {
    name: "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")
    for name, path in art.items()
}
sequences = {
    "free": ["COINS", "DIAMONDS", "MASTERY COINS", "COINS", "DIAMONDS", "MASTERY COINS"],
    "paid": ["DIAMONDS", "MASTERY COINS", "COINS", "DIAMONDS", "MASTERY COINS", "COINS"],
}

tree = ET.parse(source)
root = tree.getroot()
for lane, names in sequences.items():
    for index, name in enumerate(names, start=1):
        group = root.find(f".//{{{SVG}}}g[@id='{lane}-reward-{index}']")
        if group is None:
            raise ValueError(f"Missing {lane} reward slot {index}")
        x = 232 + (index - 1) * 191 + 53
        y = 297 if lane == "free" else 544
        icon = ET.Element(
            f"{{{SVG}}}image",
            {
                "id": f"{lane}-currency-{index}-{name.lower().replace(' ', '-')}",
                "x": str(x),
                "y": str(y),
                "width": "70",
                "height": "70",
                "preserveAspectRatio": "xMidYMid meet",
                f"{{{XLINK}}}href": encoded[name],
            },
        )
        group.insert(2, icon)
        label = group.find(f"{{{SVG}}}text")
        if label is None or label.text != "REWARD TBD":
            raise ValueError(f"Unexpected label in {lane} reward slot {index}")
        label.text = name

tree.write(output, encoding="utf-8", xml_declaration=True)
print(output)
