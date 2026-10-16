"""Read the installed Studio animation publisher's API usage, without running it."""
import importlib.util
import pathlib
import sys
import types

root = pathlib.Path(__file__).resolve().parent / "rbxmonkey_addon" / "core"
package = types.ModuleType("rbx_inspection")
package.__path__ = [str(root)]
sys.modules[package.__name__] = package
for name in ("schema", "rbxm"):
    spec = importlib.util.spec_from_file_location(f"rbx_inspection.{name}", root / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
parser = sys.modules["rbx_inspection.rbxm"]
from compression import zstd
original_decompress = parser._decompress_chunk_body
def decompress(body, compressed_len, uncompressed_len):
    if compressed_len and body.startswith(b"\x28\xb5\x2f\xfd"):
        result = zstd.decompress(body)
        if len(result) != uncompressed_len:
            raise ValueError("Unexpected decompressed size")
        return result
    return original_decompress(body, compressed_len, uncompressed_len)
parser._decompress_chunk_body = decompress
parser._PROPS_CLASSES = set(parser._PROPS_CLASSES) | {"ModuleScript", "LocalScript", "Script", "Folder"}
source = pathlib.Path(sys.argv[1])
instances, _ = parser._parse_chunks(source.read_bytes())
for instance in instances.values():
    code = instance.props.get("Source", "")
    if isinstance(code, bytes):
        code = code.decode("utf-8", errors="replace")
    if not isinstance(code, str):
        continue
    lines = code.splitlines()
    matches = [i for i, line in enumerate(lines) if any(term in line for term in (
        "CreateAssetAndWaitForAssetId", "CreateAssetOrAssetVersion", "UploadAnimation", "uploadAnimation",
    ))]
    if matches:
        print("SCRIPT", instance.name)
        for match in matches:
            for i in range(max(0, match - 6), min(len(lines), match + 24)):
                print(f"{i + 1}: {lines[i]}")
