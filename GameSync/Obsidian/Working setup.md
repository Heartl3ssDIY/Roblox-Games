# Working setup

[[Roblox Games]] · [[Sync status]]

Setup checked on 16 October 2026.

- **Obsidian:** the live vault is `C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games`. Access is through local files, not an Obsidian MCP connection. Vault writes use normal filesystem permissions.
- **Working files:** `C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns` remains the authoritative project folder. Existing sibling asset folders keep their recorded local working locations. Do not create new project work in the old OneDrive root.
- **GitHub:** [Heartl3ssDIY/Roblox-Games](https://github.com/Heartl3ssDIY/Roblox-Games) is the existing remote. The initial upload was previously verified. The current sync adds game notes, missing local assets, recovered files and a current Studio source snapshot; the task's final response records commit and push verification.
- **Vault backup:** `GameSync/Obsidian` stores versioned copies of the live notes. It replaces the original setup-only backup as the current snapshot. `WorkflowSetup20261016/vault` remains historical setup templates.
- **Graphify Cloud:** the plugin is installed, but its tools are not exposed in this chat. Authenticated cloud workspace access, repository indexing and index freshness remain unverified. The previous manual-server OAuth attempt also failed.
- **Local Graphify:** version 0.9.91 is installed in the project-local `sync-work/graphify-venv` environment. The selected scope is all game code and these current game notes; historical code exports are included, while media, dependency folders and Brainrot Murder club are excluded. Generated outputs belong in [the graph folder](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/graphify-out): [interactive graph](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/graphify-out/graph.html), [report](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/graphify-out/GRAPH_REPORT.md) and [graph data](file:///C:/Users/sandt/Documents/Local%20Projects/Roblox%20UI%20Assets/Btns/graphify-out/graph.json). Local indexing does not establish a Graphify Cloud connection.

From the project folder, run:

```powershell
python GameSync/sync_files.py
python GameSync/sync_files.py --apply
python GameSync/sync_files.py --verify
```

The first command is a dry run. The helper copies live notes and sibling assets into the repository, verifies SHA-256 hashes, refuses conflicting backup edits and never deletes files. Review the resulting Git changes, commit them and push to the existing remote. This is on-demand sync; there is no background automation. Studio snapshots require a separate fresh read from the connected game.

When requesting work, name the game and its note; update the note after completing and testing changes. Notes are readable but are not automatically loaded into every chat. For Roblox UI, keep editable layouts in StarterGui and let runtime scripts bind behaviour/data without replacing authored positions or sizes.
