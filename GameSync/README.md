# Game file snapshots

The authoritative working project is `C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns`. Sibling asset folders keep their original locations under `C:\Users\sandt\Documents\Local Projects\Roblox UI Assets`. The live notes remain in `C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games`.

`sync_files.py` creates one-way copies in this repository. `Assets` mirrors the ten named sibling asset folders; `Obsidian` mirrors eligible `.md` and `.canvas` notes. Edit originals, then refresh these snapshots. This helper does not change originals, publish Roblox games, contact GitHub, or connect Graphify. Commit and push verified snapshots using the repository's existing Git LFS configuration.

Run from the Btns directory:

```powershell
python .\GameSync\sync_files.py
python .\GameSync\sync_files.py --apply
python .\GameSync\sync_files.py --verify
```

The default is a dry run. `--apply` hashes every eligible source and destination, stages changes, checks that sources stayed unchanged, copies changed files, and updates `manifest.json`. Existing destination edits that differ from the last recorded snapshot cause the operation to stop. Preserve those edits and reconcile them with the authoritative source before retrying. Copies are never deleted because a source disappears: the manifest retains those entries as `source_missing` and verification reports them.

`--verify` reads files only, checks SHA-256 hashes against source and snapshot records, and reports new, changed, missing, or conflicting files. Exit status is zero for success, one for detected differences/missing sources, and two for an error that prevents safe processing. A dry run can succeed while listing proposed copies; only a successful `--verify` establishes that all eligible sources have matching recorded snapshots.

The helper skips symbolic links/junctions, private configuration and key filenames, environment files, Python/dependency caches, and Obsidian settings. It includes ordinary artwork such as `Secret Index card.png`. Snapshots preserve file timestamps. The manifest records relative source paths, byte counts, timestamps, SHA-256 hashes and missing-source status. It is machine maintained; do not edit its hashes to bypass a conflict. An interrupted process may leave a `.sync-stage-*` directory; preserve it for recovery rather than automatically deleting it. A subsequent run refuses destination changes that disagree with the last completed manifest.

The source list is explicit in `ASSET_FOLDERS`; no parent-directory crawl is used. On Windows, file operations use extended-length paths so deeply nested asset names work beyond 260 characters; the manifest keeps conventional readable paths. The current `GameSync` tree is excluded from source traversal. `StudioSnapshots` and other manually authored files under `GameSync` are outside this helper's managed snapshot paths.
