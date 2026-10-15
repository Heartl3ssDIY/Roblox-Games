from pathlib import Path

root = Path(__file__).resolve().parent
source = (root / "NativeGeometry.template.luau").read_text(encoding="utf-8")
profile = (root / "CandidateProfile.luau").read_text(encoding="utf-8")
layout = (root.parent / "Layout.luau").read_text(encoding="utf-8")
source = source.replace('local part = Instance.new("Part")', 'if not source.PlaygroundShell:FindFirstChild("CompactDock") then\n(function()\n' + layout + '\nend)()(source,true)\nend\n\nlocal part = Instance.new("Part")', 1)
source = source.replace("    -- __CANDIDATE_PROFILE__", profile)
extra = [
    "PlaygroundShell.CompactDock",
    "PlaygroundSessionControls.CompactToggle",
    "PlaygroundSessionControls.CompactSpectate",
    "PlaygroundSessionControls.PortraitToggle",
    "PlaygroundSessionControls.PortraitSpectate",
    "PlaygroundSessionControls.CompactRoundToggle",
    "PlaygroundSessionControls.PortraitRoundToggle",
    "PlaygroundEmoteWheel.CompactEmoteToggle",
    "PlaygroundEmoteWheel.PortraitEmoteToggle",
    "PlaygroundIntermissionHUD.Portrait",
    "PlaygroundFishingHUD.PortraitDock",
    "PlaygroundFishingHUD.RoundDock",
]
source = source.replace("    -- __CANDIDATE_ROOTS__", "\n".join(f'    "{name}",' for name in extra))
(root / "NativeCandidate.luau").write_text(source, encoding="utf-8")
