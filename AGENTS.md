# Local project storage

The user requested this migration on 2026-09-17 to keep project files off OneDrive.
The authoritative working folder is: C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns
Use that absolute local path for all project output, Blender saves, backups, renders, exports, packages, and temporary work.
This is the authoritative local folder. The corresponding old OneDrive folder is a migration pointer only; do not recreate assets there.
Map old paths under C:\Users\sandt\OneDrive\Roblox UI Assets to the same relative paths under C:\Users\sandt\Documents\Local Projects\Roblox UI Assets.
When opening an older Blender file, check its render/output and external-asset paths and remap old project-root references to the local root before saving.
Use normal tool approval mechanisms if the local destination is outside the current writable roots; never fall back to OneDrive to bypass a permission restriction.
# User preferences

Do not control the desktop mouse, keyboard, or app windows without separate, explicit permission for that action. Permission to use project files and the Roblox Studio connection does not grant desktop-control permission.
For Roblox UI, keep editable layouts as ScreenGui objects in StarterGui. Runtime scripts should bind behavior and update data without overwriting authored positions or sizes. Use editable templates for repeated elements.
Avoid decorative comment banners, section headings, and redundant explanatory comments in Luau scripts. Keep the code direct and readable.
