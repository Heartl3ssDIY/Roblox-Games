"""Snapshot sibling game assets and Obsidian notes without changing originals."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone


ASSET_FOLDERS = (
    "Anime Combat Units", "Audio", "Free Icon Pack 3.0.1 (Basic)", "G-Blox",
    "Icons", "Match time for brainrot", "PlayGround Classics", "UI (1)",
    "UI to be rich", "workers tab",
)
VAULT = Path(r"C:\Users\sandt\Documents\Local Projects\Obsidian_Roblox\Roblox Games")
BLOCKED_DIRS = {
    ".git", ".codex", ".aws", ".ssh", ".obsidian", "__pycache__", ".cache",
    ".pytest_cache", ".mypy_cache", ".ruff_cache", "node_modules", ".venv",
    "venv", ".test-work", "gamesync",
}
BLOCKED_SUFFIXES = {".pem", ".key", ".pfx", ".p12", ".kdbx", ".pyc", ".pyo"}
BLOCKED_NAMES = {"thumbs.db", "desktop.ini", "optix7cache.db", ".npmrc", ".pypirc", ".netrc"}
SENSITIVE = re.compile(r"^(?:credentials?|secrets?|tokens?|passwords?|cookies?|oauth)(?:[._-]|$)", re.I)
SHA256 = re.compile(r"^[0-9a-f]{64}$")


class SyncError(Exception):
    pass


def filesystem_path(path):
    """Use extended Windows paths for I/O, including directory enumeration."""
    value = os.fspath(path)
    if os.name != "nt" or value.startswith("\\\\?\\"):
        return Path(value)
    value = os.path.abspath(value)
    return Path("\\\\?\\UNC\\" + value[2:] if value.startswith("\\\\") else "\\\\?\\" + value)


def conventional_path(path):
    value = os.fspath(path)
    if os.name == "nt":
        if value.startswith("\\\\?\\UNC\\"):
            value = "\\\\" + value[8:]
        elif value.startswith("\\\\?\\"):
            value = value[4:]
    return Path(os.path.abspath(value))


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def is_link(info):
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & 0x400)


def assert_plain_path(path):
    for item in (path, *path.parents):
        try:
            info = filesystem_path(item).lstat()
        except FileNotFoundError:
            continue
        if is_link(info):
            raise SyncError(f"Refusing symlink or junction: {item}")


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def hash_file(path):
    assert_plain_path(path)
    io_path = filesystem_path(path)
    before = io_path.stat()
    if not stat.S_ISREG(before.st_mode):
        raise SyncError(f"Not a regular file: {path}")
    digest = hashlib.sha256()
    with io_path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            digest.update(block)
    after = io_path.stat()
    if fingerprint(before) != fingerprint(after):
        raise SyncError(f"File changed while hashing: {path}")
    return {"sha256": digest.hexdigest(), "bytes": after.st_size,
            "mtime_ns": after.st_mtime_ns,
            "mtime_utc": datetime.fromtimestamp(after.st_mtime, timezone.utc).isoformat()}


def excluded(name, directory=False):
    lower = name.lower()
    if directory:
        return lower in BLOCKED_DIRS or lower.startswith(".cache")
    return (lower in BLOCKED_NAMES or lower.startswith(".env")
            or lower.startswith(("id_rsa", "id_ed25519", "id_ecdsa"))
            or Path(name).suffix.lower() in BLOCKED_SUFFIXES
            or ".cache-" in lower or lower.endswith(".cache")
            or bool(SENSITIVE.match(name)) and Path(name).suffix.lower() not in {".png", ".jpg", ".svg", ".webp"})


def eligible_files(root, notes=False):
    assert_plain_path(root)
    if not filesystem_path(root).exists():
        return
    if not filesystem_path(root).is_dir():
        raise SyncError(f"Source root is not a directory: {root}")
    pending = [root]
    while pending:
        folder = pending.pop()
        with os.scandir(filesystem_path(folder)) as children:
            for child in sorted(children, key=lambda entry: entry.name.casefold()):
                info = child.stat(follow_symlinks=False)
                if is_link(info):
                    continue
                if stat.S_ISDIR(info.st_mode):
                    if not excluded(child.name, directory=True):
                        pending.append(folder / child.name)
                elif stat.S_ISREG(info.st_mode) and not excluded(child.name):
                    if not notes or Path(child.name).suffix.lower() in {".md", ".canvas"}:
                        yield folder / child.name


class Synchronizer:
    def __init__(self, project_root, vault=VAULT):
        self.project = conventional_path(project_root)
        assert_plain_path(self.project)
        if self.project.name != "Btns" or not filesystem_path(self.project).is_dir():
            raise SyncError("Expected the canonical Btns project directory")
        self.output = self.project / "GameSync"
        self.manifest_path = self.output / "manifest.json"
        self.vault = conventional_path(vault)
        self.sources = {f"Assets/{name}": self.project.parent / name for name in ASSET_FOLDERS}
        self.sources["Obsidian"] = self.vault
        assert_plain_path(self.output)

    def destination(self, relative):
        parts = PurePosixPath(relative)
        if (not relative or parts.is_absolute() or ".." in parts.parts or "\\" in relative
                or ":" in relative or str(parts) != relative):
            raise SyncError(f"Invalid snapshot path: {relative!r}")
        path = self.output.joinpath(*parts.parts)
        if not path.is_relative_to(self.output):
            raise SyncError(f"Snapshot escapes project: {relative}")
        assert_plain_path(path)
        return path

    def read_manifest(self):
        assert_plain_path(self.manifest_path)
        if not filesystem_path(self.manifest_path).exists():
            return {"entries": {}}
        with filesystem_path(self.manifest_path).open(encoding="utf-8") as stream:
            data = json.load(stream)
        if data.get("version") != 1 or data.get("project_root") != str(self.project):
            raise SyncError("Manifest version/project does not match this checkout")
        expected = {group: str(root) for group, root in self.sources.items()}
        if data.get("source_roots") != expected or not isinstance(data.get("entries"), dict):
            raise SyncError("Manifest sources do not match configured authoritative folders")
        for relative, entry in data["entries"].items():
            self.destination(relative)
            group = entry.get("source_group")
            source_relative = entry.get("source_relative", "")
            if group not in self.sources or relative != f"{group}/{source_relative}":
                raise SyncError(f"Invalid manifest source mapping: {relative}")
            if not source_relative or ".." in PurePosixPath(source_relative).parts:
                raise SyncError(f"Invalid source-relative path: {relative}")
            source_hash = entry.get("source_sha256", "")
            if not SHA256.fullmatch(source_hash) or entry.get("snapshot_sha256") != source_hash:
                raise SyncError(f"Manifest source/snapshot hash disagreement: {relative}")
        return data

    def inventory(self):
        current = {}
        missing_roots = []
        for group, root in self.sources.items():
            if not filesystem_path(root).exists():
                missing_roots.append(group)
                continue
            for path in eligible_files(root, notes=group == "Obsidian"):
                relative = path.relative_to(root).as_posix()
                key = f"{group}/{relative}"
                facts = hash_file(path)
                current[key] = {"source_group": group, "source_relative": relative,
                                "source_sha256": facts["sha256"], "snapshot_sha256": facts["sha256"],
                                "bytes": facts["bytes"], "source_mtime_ns": facts["mtime_ns"],
                                "source_mtime_utc": facts["mtime_utc"], "status": "current"}
        return current, missing_roots

    def source_path(self, entry):
        return self.sources[entry["source_group"]].joinpath(*PurePosixPath(entry["source_relative"]).parts)

    def plan(self):
        manifest = self.read_manifest()
        old = manifest["entries"]
        current, missing_roots = self.inventory()
        copies, conflicts, destination_hashes = [], [], {}
        for relative in sorted(set(old) | set(current)):
            target = self.destination(relative)
            facts = hash_file(target) if filesystem_path(target).exists() else None
            destination_hashes[relative] = facts["sha256"] if facts else None
            previous = old.get(relative)
            if previous and facts and facts["sha256"] != previous["snapshot_sha256"]:
                conflicts.append(relative)
            elif not previous and facts and facts["sha256"] != current[relative]["source_sha256"]:
                conflicts.append(relative)
            elif relative in current and (not facts or facts["sha256"] != current[relative]["source_sha256"]):
                copies.append(relative)
        stale = sorted(set(old) - set(current))
        snapshot_files = set()
        for group in self.sources:
            snapshot_root = self.destination(group)
            for path in eligible_files(snapshot_root, notes=group == "Obsidian"):
                snapshot_files.add(path.relative_to(self.output).as_posix())
        return {"manifest": manifest, "current": current, "copies": copies,
                "conflicts": conflicts, "stale": stale, "missing_roots": missing_roots,
                "destination_hashes": destination_hashes,
                "new": sorted(set(current) - set(old)),
                "unexpected_snapshots": sorted(snapshot_files - set(old) - set(current)),
                "source_changes": sorted(k for k in set(current) & set(old)
                                         if current[k]["source_sha256"] != old[k]["source_sha256"])}

    def verify(self, plan):
        problems = []
        for category in ("conflicts", "stale", "new", "source_changes", "missing_roots", "unexpected_snapshots"):
            problems.extend(f"{category}: {item}" for item in plan[category])
        for relative, entry in plan["current"].items():
            if plan["destination_hashes"][relative] != entry["source_sha256"]:
                problems.append(f"snapshot_missing_or_outdated: {relative}")
        return problems

    def apply(self, plan):
        if plan["conflicts"]:
            raise SyncError("Snapshot conflicts; preserve/reconcile destination edits before retrying: "
                            + ", ".join(plan["conflicts"][:5]))
        filesystem_path(self.output).mkdir(parents=True, exist_ok=True)
        assert_plain_path(self.output)
        with tempfile.TemporaryDirectory(prefix=".sync-stage-", dir=filesystem_path(self.output)) as temp:
            stage = Path(temp)
            for index, relative in enumerate(plan["copies"]):
                entry = plan["current"][relative]
                source = self.source_path(entry)
                before = hash_file(source)
                if before["sha256"] != entry["source_sha256"]:
                    raise SyncError(f"Source changed after preflight: {relative}")
                shutil.copy2(filesystem_path(source), filesystem_path(stage / str(index)), follow_symlinks=False)
                copied = hash_file(stage / str(index))
                after = hash_file(source)
                if copied["sha256"] != entry["source_sha256"] or before != after:
                    raise SyncError(f"Source changed during copy: {relative}")
            fresh = self.plan()
            if (fresh["current"] != plan["current"] or fresh["missing_roots"] != plan["missing_roots"]
                    or fresh["destination_hashes"] != plan["destination_hashes"]
                    or fresh["manifest"] != plan["manifest"]
                    or fresh["unexpected_snapshots"] != plan["unexpected_snapshots"]):
                raise SyncError("Sources, snapshots or manifest changed during staging; nothing installed")
            entries = dict(plan["current"])
            for relative in plan["stale"]:
                entries[relative] = dict(plan["manifest"]["entries"][relative])
                entries[relative]["status"] = "source_missing"
                entries[relative]["snapshot_present"] = plan["destination_hashes"][relative] is not None
            new_manifest = {"version": 1, "project_root": str(self.project),
                            "source_roots": {group: str(root) for group, root in self.sources.items()},
                            "updated_utc": utc_now(), "missing_source_roots": plan["missing_roots"],
                            "entries": dict(sorted(entries.items()))}
            staged_manifest = stage / "manifest.json"
            filesystem_path(staged_manifest).write_text(json.dumps(new_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            installed = []
            try:
                for index, relative in enumerate(plan["copies"]):
                    target = self.destination(relative)
                    filesystem_path(target.parent).mkdir(parents=True, exist_ok=True)
                    backup = stage / f"backup-{index}"
                    existed = filesystem_path(target).exists()
                    if existed:
                        os.replace(filesystem_path(target), filesystem_path(backup))
                    installed.append((target, backup, existed))
                    os.replace(filesystem_path(stage / str(index)), filesystem_path(target))
                    if hash_file(target)["sha256"] != entries[relative]["snapshot_sha256"]:
                        raise SyncError(f"Installed snapshot verification failed: {relative}")
                os.replace(filesystem_path(staged_manifest), filesystem_path(self.manifest_path))
            except Exception:
                for target, backup, existed in reversed(installed):
                    if existed:
                        os.replace(filesystem_path(backup), filesystem_path(target))
                    elif filesystem_path(target).exists():
                        filesystem_path(target).unlink()
                raise
        return len(plan["copies"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="Copy changed sources and update the manifest")
    mode.add_argument("--verify", action="store_true", help="Verify sources and snapshots without changing files")
    args = parser.parse_args(argv)
    try:
        sync = Synchronizer(conventional_path(__file__).parent.parent)
        plan = sync.plan()
        label = "VERIFY" if args.verify else "APPLY" if args.apply else "DRY RUN"
        print(f"{label}: {len(plan['current'])} source files; {len(plan['copies'])} copies; "
              f"{len(plan['new'])} unrecorded; {len(plan['source_changes'])} changed; "
              f"{len(plan['conflicts'])} conflicts; {len(plan['stale'])} missing-source entries; "
              f"{len(plan['missing_roots'])} missing roots; {len(plan['unexpected_snapshots'])} unrecorded snapshots")
        if args.verify:
            problems = sync.verify(plan)
            for problem in problems[:10]:
                print(problem)
            if len(problems) > 10:
                print(f"... {len(problems) - 10} more verification problems")
            print("Verified SHA-256 source and snapshot hashes." if not problems else "Verification failed.")
            return 1 if problems else 0
        if args.apply:
            count = sync.apply(plan)
            print(f"Copied {count} files; wrote {sync.manifest_path}")
        elif plan["conflicts"]:
            for relative in plan["conflicts"][:10]:
                print(f"Conflict: {relative}")
        return 1 if plan["conflicts"] or plan["stale"] or plan["missing_roots"] or plan["unexpected_snapshots"] else 0
    except (OSError, ValueError, TypeError, KeyError, SyncError) as error:
        print(f"Sync stopped: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
