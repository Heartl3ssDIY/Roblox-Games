# G-Blox futuristic pet collection

Every pet is a floating, bodyless cube-head model based on the approved Falcon style. Species features are attached directly to the head. Each animal has its own Blender source, base FBX, VFX FBX, preview and parts manifest.

All visible colour regions are separate one-material mesh objects. They use consistently named recolour groups: Pearl, Cyan, Purple, Silver, Yellow, Ink, White and Glow. Import FBX files without merging their meshes. The VFX versions contain separate Neon-intended underlight, speed-rail and species glow meshes; Blender emission itself does not transfer through FBX.

These are static pet meshes rather than rigs. Attach the root/head to the game's existing pet-follow system and make physical pieces non-colliding and massless as appropriate. `Roblox_Pet_VFX.server.lua` is an optional shared setup that turns the named VFX meshes into Neon pieces with cyan lights and short movement trails.
