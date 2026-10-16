The user's Obsidian vault is at:

`C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games`

Start with `Roblox Games.md` and `Working setup.md` in that vault. Read the relevant notes when the user asks to use them, and verify dated status against the current project before acting.

The authoritative working project remains this Btns folder. The vault holds notes and links; it does not replace project assets. Vault edits require the normal permissions for its location.

`GameSync/Obsidian` is the versioned backup of live vault notes. Run `python GameSync/sync_files.py` for a dry run, then `python GameSync/sync_files.py --apply` and `python GameSync/sync_files.py --verify` to refresh and verify it alongside sibling asset backups. Review and commit/push afterward. This is an on-demand workflow, not a background sync. Edit the live vault notes, not their backup copies; the helper refuses conflicting backup edits and never deletes files.

`WorkflowSetup20261016/vault` contains the initial note templates only. The live Obsidian notes are in the vault above.
