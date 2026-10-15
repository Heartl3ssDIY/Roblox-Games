from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
reports={}
def function_body(source,name,next_name):
 return source[source.index("local function "+name+"("):source.index("local function "+next_name+"(")]
for name in ["Shell.Controller.luau","PlaygroundToyHotbar.Controller.client.luau"]:
 before=(root/"Before"/name).read_text(encoding="utf-8-sig")
 after=(root/"After"/name).read_text(encoding="utf-8-sig")
 assert "ContentProvider" not in after and "framePreview" not in after and "record.model" not in after
 assert not re.search(r"\.(?:Position|Size|AnchorPoint)\s*=",after)
 reports[name]={"sha256":hashlib.sha256((root/"After"/name).read_bytes()).hexdigest(),"naturalImageLoading":True,"noRuntimeLayoutWrites":True}
 if name.startswith("PlaygroundToy"):
  for first,next_name in [("syncLoadout","invoke"),("invoke","aimAt"),("aimAt","useToy"),("useToy","selectToy")]:
   assert function_body(before,first,next_name)==function_body(after,first,next_name),first
  assert before[before.index("refresh = function()"):before.index("for index = 1, 4 do")]==after[after.index("refresh = function()"):after.index("for index = 1, 4 do")]
  assert 'wheel and wheel.Enabled and wheelPanel and wheelPanel.Visible' in after
 else:
  for first,next_name in [("requirement","isEquipped"),("isEquipped","refreshCards"),("refreshCards","applyReply")]:
   assert function_body(before,first,next_name)==function_body(after,first,next_name),first
  assert 'gui:GetAttributeChangedSignal("OpenEmoteShopSerial")' in after
assets=json.loads((root/"ItemIconAssets.json").read_text())
assert len(assets)==56 and len({a["assetId"] for a in assets})==56
assert all(a["fetchStatus"]=="Enum.AssetFetchStatus.Success" for a in assets)
assert len([a for a in assets if a["category"]=="Event-Bats"])==6
for asset in assets:
 assert hashlib.sha256(Path(asset["path"]).read_bytes()).hexdigest()==asset["sha256"]
(root/"Tests/SourcePreservation.json").write_text(json.dumps({"sources":reports,"all56OriginalsUnmodified":True,"all56UniqueUploadedImagesVerified":True,"eventIdsCategoryQualified":True},indent=2))
print(json.dumps(reports,indent=2))

