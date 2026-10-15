from pathlib import Path
import json
import re

folder = Path(__file__).resolve().parents[1]
base_path = folder.parent / "PodiumEmotes20261004" / "After" / "StarterPlayer.StarterPlayerScripts.PlaygroundEmotes.client.luau"
candidate_path = folder / "After" / "PlaygroundEmotes.client.luau"
base = base_path.read_text(encoding="utf-8").strip()
candidate = candidate_path.read_text(encoding="utf-8").strip()
test = (folder / "Tests" / "ToyMotionChecks.luau").read_text(encoding="utf-8")
block = candidate[candidate.index("local toyActions ="):candidate.index("local beforeAnimation =")]
assert block.strip() in test, "Local pose tests must exercise the exact candidate toy code"
prefix = candidate[:candidate.index("local toyActions =")]
assert prefix == base[:base.index("local beforeAnimation =")], "Existing bat and shared joint functions changed"
reconstructed = (prefix + candidate[candidate.index("local beforeAnimation ="):])
reconstructed = reconstructed.replace("record.weapon = nil record.toy = nil continue", "record.weapon = nil continue")
reconstructed = reconstructed.replace(
    "if animateBat(record, player, character, humanoid, now) then record.toy = nil continue end\n\t\tif animateToy(record, player, character, humanoid, now) then continue end",
    "if animateBat(record, player, character, humanoid, now) then continue end",
)
assert reconstructed == base, "Existing emote and cleanup behavior changed"
for forbidden in ['IsA("Tool")', 'FindFirstChildOfClass("Tool")', "Tool.Activated", "Instance.new("]:
    assert forbidden not in block, "Toy animation must not access tools or construct gameplay instances"
assert "restore(record)" in candidate[candidate.index("local frame ="):candidate.index("if animateToy")], "Restore must precede toy pose every frame"
contract = json.loads((folder / "ToyAnimationContract.json").read_text(encoding="utf-8"))
assert len(contract["actions"]) == 14 and contract["deferred"] == ["M09"]
print("Source preservation checks passed: 8")

