import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
files = ['BritishBulldogService.lua', 'BBMovement.client.luau', 'BritishBulldogCamera.client.luau', 'PlaygroundEconomyService.lua', 'PlaygroundBootstrap.server.luau', 'PlaygroundLeaderboardService.lua', 'BuildLeaderboards.luau', 'ApplyMovementChanges.luau', 'ApplyLeaderboards.luau', 'ApplyApprovedLauncherInput.luau']
report = {
    'place': 'Playground Classics', 'placeId': 95034648955135,
    'date': '2026-10-04', 'appliedInEditMode': True,
    'playStarted': False, 'gameplayTested': False, 'dataStoreRequests': 0,
    'syntaxCompiledWithoutExecution': 6,
    'changes': ['Bulldog server and client jump locks; previous jump settings restored on exit', 'Grounded 0.32 second dodge with 8 stud lateral travel, forward momentum, wall checks, synchronized body lean and camera banking', 'Two editable world leaderboards: Highest Level and Most Wins; ten rows each and a shared row design', 'Global ranks queued from confirmed profile loads/saves; no Studio profile or ranking writes'],
    'leaderboardBase': {'position': [-12, 4, -82], 'yawDegrees': 180},
    'backupsInServerStorage': ['BulldogDodgeBackup20261004', 'PlaygroundLeaderboardsBackup20261004'],
    'capabilitiesAdded': {'PlaygroundEconomyService': ['DataStore'], 'PlaygroundBootstrap': ['DataStore', 'Input'], 'PlaygroundLeaderboardService': ['RunServerScript', 'AccessOutsideWrite', 'Basic', 'DataStore', 'UI', 'Players']},
    'pendingApproval': None,
    'launcherInputApproval': 'The user explicitly approved launcher Input on 2026-10-04 after automatic review required separate authorization. Applied successfully; sandbox remains enabled.',
    'runtimeLimitations': ['No movement, camera, player-session or live global-persistence test was run because the user paused Play testing.', 'Existing persisted XP/wins enter the ranking index when their profile is next loaded or saved.', 'Ranks are refreshed about once a minute; latest queued ranks may wait for a later join if shutdown budget expires.'],
    'sha256': {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files},
}
(root/'DeploymentReport.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
notes = '''Applied to Playground Classics in Studio Edit mode on 2026-10-04.

British Bulldog now locks jumping on the server and local client for the full participation period, including role changes. Existing jump settings are restored when the round ends. Dodge is a grounded, eased sideways burst with forward movement preserved, body lean visible to other players, and a subtle camera bank.

The two boards are under Workspace > Playground Lobby > Leaderboards, on the north lawn facing the plaza. Edit their authored SurfaceGui layouts and hidden RowTemplate directly. LeaderboardMaster.svg is one reusable editable design for both board types. Runtime updates data/visibility only.

Play testing remains stopped. Syntax compilation and Edit-mode source/structure/placement checks passed. Movement feel, multiplayer behavior and live DataStores have not been tested.

The user approved Input on the launcher, and that permission is now applied so it can require the already-approved mud-gun module. Sandbox remains enabled. No DataStore requests were made during editing.

Before/ contains exact native source snapshots. ServerStorage contains matching disabled-script backups. The Apply*.luau files are source-guarded installation records; they deliberately refuse a second run over changed sources or existing boards. Do not rerun older all-games installers over this refinement.
'''
(root/'Notes.txt').write_text(notes, encoding='utf-8')
ink='#1b2a41'; cream='#fff6dc'; cyan='#43c0f2'; muted='#5b6d7d'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="720" height="1000" viewBox="0 0 720 1000">', '<title>Playground Classics — reusable leaderboard master</title>', '<desc>Edit this single master for Highest Level or Most Wins. All shapes and text remain editable.</desc>', f'<rect id="BoardFace" width="720" height="1000" fill="{cream}"/>', f'<g id="Header"><rect x="18" y="18" width="684" height="128" rx="22" fill="{cyan}" stroke="{ink}" stroke-width="4"/><text x="65" y="78" text-anchor="middle" font-size="58" fill="{ink}">★</text><text x="400" y="75" text-anchor="middle" font-size="46" fill="{ink}" font-family="Fredoka One, sans-serif">HIGHEST LEVEL</text><text x="360" y="120" text-anchor="middle" font-size="23" fill="{ink}" font-family="Fredoka One, sans-serif">ALL TIME · TOP 10</text></g>']
for i in range(10):
    y=174+74*i
    badge=['#ffca45','#bed6e4','#da9e71'][i] if i<3 else ink
    rankcolor=ink if i<3 else cream
    svg.append(f'<g id="Row{i+1:02}" transform="translate(24 {y})"><rect width="672" height="67" rx="13" fill="#f8eccf" stroke="#d1c5b1" stroke-width="2"/><rect x="8" y="10" width="47" height="47" rx="12" fill="{badge}"/><text x="31.5" y="45" text-anchor="middle" font-family="Fredoka One, sans-serif" font-size="30" fill="{rankcolor}">{i+1}</text><rect id="AvatarSlot{i+1}" x="69" y="7" width="53" height="53" rx="13" fill="#e3e8e2" stroke="{ink}" stroke-width="2"/><text x="95.5" y="45" text-anchor="middle" font-size="29" fill="{muted}">?</text><text x="137" y="44" font-family="Fredoka One, sans-serif" font-size="30" fill="{ink}">PLAYER NAME</text><text x="654" y="45" text-anchor="end" font-family="Fredoka One, sans-serif" font-size="32" fill="{ink}">LV 1</text></g>')
svg.extend([f'<text id="Status" x="360" y="949" text-anchor="middle" font-family="Fredoka One, sans-serif" font-size="23" fill="{ink}">GLOBAL · ALL TIME</text>',f'<text id="Footnote" x="360" y="978" text-anchor="middle" font-family="Fredoka One, sans-serif" font-size="18" fill="{muted}">LEVEL · TOTAL XP BREAKS TIES</text>','</svg>'])
(root/'LeaderboardMaster.svg').write_text('\n'.join(svg), encoding='utf-8')
print('Saved deployment report, notes, and one editable leaderboard SVG master.')
