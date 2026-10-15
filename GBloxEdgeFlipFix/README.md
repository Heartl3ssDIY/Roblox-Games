# Edge gravity flip fix — 16 September 2026

Applied only to the open Round 1 Muliplayer Studio place (106769122906103), whose controller serves all five courses. Not published. Lobby, tutorial, map geometry, spike damage, idle timeout and camera follow were not edited.

## Changes
- RunnerGroundCheck now samples the runner collision footprint edges and corners, within its physical 1.5-by-2 stud footprint.
- Server takeoff validation verifies real ground at the sampled position without requiring the first ray to choose the exact same adjacent platform as the client.
- RunnerClient uses the same support check to suppress landing bounce.
- Rejected/timed-out predicted flips restore orientation and cancel only upward launch momentum, preserving forward and downward velocity and local cooldown.
- GravityFlipAssist is retained as an inert script: its deferred server-side orientation/36-stud impulse duplicated the owning client's configured launch.

## Verification
- All four affected/related scripts compile (GroundCheck, Client, Assist, Server).
- 69 isolated Studio ground/takeoff/rollback rule assertions passed.
- 16 tests using the actual client acknowledgement/cancellation code passed, including stale request/course/recovery/ability acknowledgements, accepted flips and timeout.
- Scan of 2,024 candidate edge positions on courses 3/4: missed support detections fell from 816 to 63 (753 positions now detected). This is a geometric candidate scan, not a claim that all positions are playable; some candidate box faces are covered or have different actual mesh geometry.
- Temporary regression fixture removed.
- No live multiplayer playtest performed; one is still needed before publishing.

Original sources are preserved under before/. Installed sources and the isolated client test are also saved here.

