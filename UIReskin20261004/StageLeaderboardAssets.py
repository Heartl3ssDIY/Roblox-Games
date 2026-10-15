import hashlib
import json
import shutil
import struct
from pathlib import Path

root = Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns")
source = root / "PlaygroundClassics-Leaderboard-Clean-20261004" / "PNG"
output = root / "UIReskin20261004"
upload = output / "Upload"
upload.mkdir(parents=True, exist_ok=True)
files = []
for name in (
    "avatar-border", "board-background", "header-background", "player-row",
    "rank-bronze", "rank-fourth-onwards", "rank-gold", "rank-silver",
):
    original = source / f"{name}.png"
    data = original.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = struct.unpack(">II", data[16:24])
    destination = upload / f"leaderboard-{name}.png"
    shutil.copy2(original, destination)
    assert destination.read_bytes() == data
    files.append({
        "uploadFile": str(destination), "assetKey": f"Leaderboard/{name}.png",
        "width": width, "height": height, "sha256": hashlib.sha256(data).hexdigest(),
    })
plan = {"files": files, "pixelPolicy": "Exact byte copies; original PNGs unchanged."}
(output / "LeaderboardUploadPlan.json").write_text(json.dumps(plan, separators=(",", ":")), encoding="utf-8")
print(json.dumps(plan, indent=2))
