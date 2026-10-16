from pathlib import Path
import json, zipfile
root=Path(__file__).resolve().parent.parent
qa=json.loads((root/"Source/Final-QA.json").read_text(encoding="utf-8-sig"))
if qa["issues"] or qa["designs"]!=68:
    raise RuntimeError("Do not package an incomplete or failed pack")
out=root/"HandOff-ZIPs"
out.mkdir(exist_ok=True)
categories=["Bats","Event-Bats","Miscellaneous","Event-Decorations","Pets"]
results=[]
for category in categories:
    dest=out/(category+".zip")
    with zipfile.ZipFile(dest,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for f in sorted((root/category).rglob("*")):
            if f.is_file(): archive.write(f,f.relative_to(root).as_posix())
    with zipfile.ZipFile(dest) as archive:
        bad=archive.testzip()
        if bad: raise RuntimeError(bad)
    results.append({"name":dest.name,"bytes":dest.stat().st_size})
dest=root.with_suffix(".zip")
with zipfile.ZipFile(dest,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for f in sorted(root.rglob("*")):
        if f.is_file() and "HandOff-ZIPs" not in f.relative_to(root).parts:
            archive.write(f,(Path(root.name)/f.relative_to(root)).as_posix())
with zipfile.ZipFile(dest) as archive:
    bad=archive.testzip()
    if bad: raise RuntimeError(bad)
results.append({"name":dest.name,"bytes":dest.stat().st_size})
(root/"Source/Archives.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
print(json.dumps(results))

