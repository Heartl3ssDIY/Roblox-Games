# Local project storage

The user requested this migration on 2026-09-17 to keep project files off OneDrive.
The authoritative working folder is: C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Match time for brainrot
Use that absolute local path for all project output, Blender saves, backups, renders, exports, packages, and temporary work.
This is the authoritative local folder. The corresponding old OneDrive folder is a migration pointer only; do not recreate assets there.
Map old paths under C:\Users\sandt\OneDrive\Roblox UI Assets to the same relative paths under C:\Users\sandt\Documents\Local Projects\Roblox UI Assets.
When opening an older Blender file, check its render/output and external-asset paths and remap old project-root references to the local root before saving.
Use normal tool approval mechanisms if the local destination is outside the current writable roots; never fall back to OneDrive to bypass a permission restriction.