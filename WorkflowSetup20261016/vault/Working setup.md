[[Roblox Games]]

Setup status recorded on 16 October 2026.

- **Obsidian:** the vault is `C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games`. This assistant can read its notes through local file access; vault edits use the normal file permission checks. This is file access, not an Obsidian MCP connection.
- **Working files:** `C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns` remains the authoritative project folder. Keep Blender saves, exports, backups and temporary project work there. Do not restore the old OneDrive paths.
- **GitHub:** the project and initial Obsidian setup notes were successfully uploaded to `Heartl3ssDIY/Roblox-Games` on 16 October 2026, including the asset import `3e487c4`. GitHub sign-in is confirmed. This vault is outside that repository, so committing the project does not back up later vault edits automatically.
- **Graphify:** the user installed the Graphify plugin. Its tools have not become available in this chat, so authenticated workspace access and repository indexing remain unverified. The separate manual server is configured as `https://api.graphify.com/mcp`; its earlier OAuth sign-in failed during metadata discovery. Follow [Graphify's plugin instructions](https://docs.graphify.com/integrations/chatgpt): Connect, authorize the workspace personally, then start a new Codex chat and ask it to list workspaces and indexed repositories. Repository indexing is managed at [Graphify Cloud](https://app.graphify.com).

When asking for work, name the game and the relevant note. Ask the assistant to update that note after completing and testing the change. Notes are available to read; they are not automatically loaded into every chat.

For Roblox interfaces, keep editable layouts in StarterGui. Runtime scripts should bind behaviour and update data without replacing authored positions and sizes.
