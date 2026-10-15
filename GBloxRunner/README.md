# G-Blox Course 1 runner

These are backup copies of the scripts installed in the open **Gameplay (Course 1)** place in Roblox Studio.

- `RunnerConfig.luau` → `ReplicatedStorage.RunnerConfig`
- `RunnerServer.luau` → `ServerScriptService.RunnerServer`
- `RunnerClient.client.luau` → `StarterPlayer.StarterPlayerScripts.RunnerClient`
- `R6CharacterLoader.luau` → `ServerScriptService.R6CharacterLoader`

Course 1 loads each player's Roblox appearance onto an R6 rig. The system assigns up to six players to the numbered spawn parts, waits for the whole teleported party to ready up, runs a 3–2–1 countdown, and moves everyone forward automatically. Forward speed begins at 34 studs per second, builds gradually to 48, and is preserved through gravity changes. Space or controller A is accepted only while that runner is touching the surface on their current gravity side. A valid switch rotates the locally owned character immediately, then the server validates and reverses only that player's gravity without moving their horizontal position or velocity. This avoids a network correction during the switch and produces a smooth diagonal fall toward the opposite surface. Gravity uses the real mass of the character parts, avoiding the infinite assembly mass Roblox reports while the runner is anchored. A transparent body collider keeps the running pose above either surface, the owning client keeps the character on the straight course plane, and the camera follows a separately smoothed horizontal position without driving the character.

Course hazards and recovery are handled automatically. The runner waits for Roblox to finish assembling the avatar's body joints before taking control. Red spiked wheels rotate in place as touch-only hazards, so they trigger recovery without solid physics crushing or flinging the character. Tutorial recovery moves the complete character rig to a recent safe position, and the custom controller prevents Roblox from killing R15 avatars while their neck joint is briefly rebuilt. The speed pickup is shared, vanishes for everyone when collected, and doubles one player's speed for three seconds. Crossing the green end zone opens spectator controls for switching between active runners.

The current Ready button is temporary. A replacement button only needs to fire `ReplicatedStorage.RunnerEvent` with the action `"Ready"`; the existing client script can also be updated to reference the finished UI button instead.

Nothing has been published from Studio yet.
