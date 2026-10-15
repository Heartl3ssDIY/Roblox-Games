from pathlib import Path
folder = Path(__file__).resolve().parents[1]
source = (folder / "After" / "PlaygroundEmotes.client.luau").read_text(encoding="utf-8")
test_path = folder / "Tests" / "ToyMotionChecks.luau"
test = test_path.read_text(encoding="utf-8")
block = source[source.index("local toyActions ="):source.index("local beforeAnimation =")]
test = test[:test.index("local toyActions =")] + block + test[test.index("local function close(a,b)"):]
test_path.write_text(test, encoding="utf-8")
