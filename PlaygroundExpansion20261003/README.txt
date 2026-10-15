Playground Classics expansion

InstallPlaygroundExpansion.luau is the combined Studio edit-mode installer.
It requires the existing "British Bulldog game" folder and its Gameplay objects.
It creates missing Tag/lobby maps and editable StarterGui layouts, then refreshes
the runtime scripts. Re-running preserves existing map geometry, UI positions,
sizes, and admin IDs. The first upgrade keeps an old admin panel backup.
Original source backups are in ServerStorage.PlaygroundBeforeExpansion20261003.

Press Play, then ADMIN (or F6). Choose British Bulldog or Tag You're It.
Solo buttons supply practice bots. Start Round needs at least two ready players.
Stop returns everybody to the lobby. Automatic rounds use the voting area.
In Tag, jump normally; Q vaults a nearby low obstacle and X dodges.
Equivalent touch buttons are in the editable Tag HUD.

Tag uses one tagger and passes that role on a successful tag. The default winner
rule compares total time spent as tagger over three minutes; the longest total
loses. The first tagger gets eight seconds of uncounted setup time. Setting the
Tag arena WinRule attribute to LastTagger enables the hot-potato alternative.

Walk into the shop or press SHOP. Its twelve authored ViewportFrame slots contain
editable 3D previews. Pets, emotes, emojis, trails, and highlights are prototypes
you can buy/equip/use. Snow Potion and Star Wand are display-only future gear.
Studio sessions start with 150 test coins. Practice does not earn normal wins.
Studio test progress resets between Play sessions. Published play currently uses
session coins/inventory under the existing sandbox permissions; durable progress
saving is not enabled. This installer adds no DataStore or capability-management
permissions.

RebuildExpansionPackage.py refreshes the combined installer from all local
sources and builders. expansion-package-manifest.json records their SHA-256 hashes.
Verified: 32 Tag checks, 105 economy checks, 43 coordinator/admin checks, 494 UI
checks, and 1,999 lobby-depth checks. The final lobby depth pass has 1,553 parts.
All 15 live Humanoid movement checks passed: dodge traveled 7.02 studs; vault
traveled 10.72 studs across a hurdle and rose 6.89 studs. Movement helpers cleaned
up and server cooldowns were verified. Player-group balance still needs playtests.
Run the supplied geometry, shell, lobby, Tag, economy, and coordinator checks
after further edits.
