from pathlib import Path
import hashlib
import json
import re
import subprocess

folder = Path(__file__).resolve().parents[1]
template = (folder / "Tests" / "ToyServiceReview.template.luau").read_text(encoding="utf-8")
service = (folder / "After" / "PlaygroundToyService.luau").read_text(encoding="utf-8-sig")
generated = folder / "Tests" / "ToyServiceReview.generated.luau"
generated.write_text(template.replace("__SERVICE_SOURCE__", service), encoding="utf-8")
runner = folder.parent / "AttackTiming20260926" / "tools" / "luau-0.740" / "luau.exe"
result = subprocess.run([str(runner), str(generated)], text=True, capture_output=True)
print(result.stdout)
print(result.stderr)
match = re.search(r"Toy service review: (\d+)/(\d+) passed; failures=(\d+)", result.stdout)
report = {
    "candidate": "After/PlaygroundToyService.luau",
    "sha256": hashlib.sha256((folder / "After" / "PlaygroundToyService.luau").read_bytes()).hexdigest().upper(),
    "passed": int(match[1]) if match else 0,
    "checks": int(match[2]) if match else 0,
    "success": result.returncode == 0,
    "scope": "Local service execution with Roblox vector, transform and instance doubles; no Studio mutation or Play",
    "confirmedFixes": ["Imported visual bounds-to-pivot offset retained during projectile motion", "R6 leg height included in pad detection", "Freeze during windup cancels pending contact"],
    "coverage": ["Lobby/readiness/liveness guards", "Movement multipliers and exact expiry", "Burn damage bounded to ten one-HP ticks", "Effect cleanup on death and owner departure", "Game entry, item swap and explicit cancellation reject delayed contacts", "Malformed aim rejected", "Ember activation and post-effect cooldown", "Pad ground validation", "Shutdown cleans tracked effects"],
    "limitations": ["Native sandbox permissions, real meshes, projectiles and visible rig poses remain for native validation", "Equipment must validate actual owned loadout and Tool binding before Use"],
}
(folder / "Validation-ToyServiceReview.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
raise SystemExit(result.returncode)
