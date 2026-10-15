[[Roblox Games]]

Setup status recorded on 16 October 2026.

- **Obsidian:** the vault is `C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games`. This assistant can read its notes through local file access; vault edits use the normal file permission checks. This is file access, not an Obsidian MCP connection.
- **Working files:** `C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns` remains the authoritative project folder. Keep Blender saves, exports, backups and temporary project work there. Do not restore the old OneDrive paths.
- **GitHub:** the local repository points to `Heartl3ssDIY/Roblox-Games`. The asset import was committed locally as `3e487c4`; its push is still pending GitHub sign-in. This vault is outside that repository, so committing the project does not back up later vault edits automatically.
- **Graphify:** the server address is configured as `https://api.graphify.com/mcp`. OAuth sign-in failed during metadata discovery. No authenticated connection, workspace access or repository index has been verified yet.

When asking for work, name the game and the relevant note. Ask the assistant to update that note after completing and testing the change. Notes are available to read; they are not automatically loaded into every chat.

For Roblox interfaces, keep editable layouts in StarterGui. Runtime scripts should bind behaviour and update data without replacing authored positions and sizes.
