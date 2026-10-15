# Vertical camera follow

Installed in Round 1 Muliplayer (106769122906103), shared by all five rounds. Not published.

- Keeps existing side-on offset and 58-degree field of view.
- Six-stud vertical dead zone, smoothing rate 7, maximum lag 18 studs (reduced automatically at closer zooms).
- Fast climbs/falls are constrained to remain in the vertical view.
- Round changes, recovery revisions, character replacements and spectator switches reset the follow state.
- Podium/reveal and loading cameras are not overridden.
- 17,942 isolated camera math/framing/compilation checks and 10 callback integration checks passed. No live multiplayer playtest was performed for this change.
- Originals are in Backups; these source exports match the installed scripts.
