Lobby polish installed in the connected Anime Combat Units Studio Edit scene at the current 1.5× lobby scale.

The collision and seating specification was derived from the saved [ACU_Festival_Citadel.blend](../ACULobbyCitadel/ACU_Festival_Citadel.blend). It targets `Workspace.Lobby_MainModeZone` in place `111313211501470`.

The installed plan has 172 invisible colliders and 24 Roblox Seats, for 196 objects total. It covers 118 conservative tree-trunk cylinders, 31 rock ellipsoids, four market/shop counters, seven boards/signs and 12 bench backs, with two seats per existing bench. Trees use the lower trunk profile rather than their branch or root bounds; rocks are inset from the visual mesh; roads, floors, terrain and cliff masses are intentionally excluded.

The Champions Court now has five empty display slots for future player avatars: three ranked podiums and two side display stands. Six imported blue figure mesh batches were archived rather than destroyed. The central plaza pedestal was already empty.

[LobbyCollision_Polished.luau](LobbyCollision_Polished.luau) is a local copy of the installed Studio collision module. It compiles and respects the `LobbyNoCollision` attribute on individual collision parts.

To regenerate without changing the Blender scene:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b '.\ACULobbyCitadel\ACU_Festival_Citadel.blend' --python '.\LobbyPolish20260926\generate_lobby_collision_spec.py'
```

All positions and sizes are Roblox studs at the current live model scale of 1.5. The source file uses Blender coordinates; the generator applies `Roblox (X,Y,Z) = (-Blender X, Blender Z, Blender Y) × 1.5`. Collision entries are deliberately inset to leave walkways clear.

No live Play test has been run since this installation. Check walking clearance, bench seating and avatar display placement in Play mode before treating the lobby polish as final.
