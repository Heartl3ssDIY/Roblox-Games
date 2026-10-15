import json,struct,zlib,sys,hashlib
from pathlib import Path
from array import array
ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/"import_manifest.json").read_text(encoding="utf-8"))
meshmap={r["name"]:r for r in manifest["meshes"]}
reports=[]
def scan(path):
    with path.open("rb") as f:
        assert f.read(23)==b"Kaydara FBX Binary  \x00\x1a\x00"
        version=struct.unpack("<I",f.read(4))[0]
        fmt="<QQQB" if version>=7500 else "<IIIB"
        hsize=struct.calcsize(fmt)
        geometries=[]
        texture_refs=[]
        def node():
            start=f.tell()
            data=f.read(hsize)
            if len(data)<hsize:return None
            end,nprops,plen,nlen=struct.unpack(fmt,data)
            if end==0:return None
            name=f.read(nlen).decode("utf8")
            props=[]
            for _ in range(nprops):
                t=f.read(1).decode("ascii")
                if t in "YILFDC":
                    formats={"Y":"h","I":"i","L":"q","F":"f","D":"d","C":"?"}
                    spec="<"+formats[t]
                    props.append(struct.unpack(spec,f.read(struct.calcsize(spec)))[0])
                elif t in "SR":
                    length=struct.unpack("<I",f.read(4))[0]
                    raw=f.read(length)
                    props.append(raw.decode("utf8") if t=="S" else None)
                elif t in "fdlibc":
                    count,encoding,length=struct.unpack("<III",f.read(12))
                    if name=="PolygonVertexIndex":
                        raw=f.read(length);raw=zlib.decompress(raw) if encoding else raw
                        idx=array("i");idx.frombytes(raw)
                        if sys.byteorder!="little":idx.byteswap()
                        assert len(idx)==count and count%3==0
                        assert all((v<0)==(i%3==2) for i,v in enumerate(idx)),"Non-triangle geometry"
                        props.append({"arrayLength":count,"triangles":count//3})
                    else:
                        f.seek(length,1);props.append({"arrayLength":count})
                else:raise ValueError("Unknown FBX property "+repr(t))
            children=[]
            while f.tell()<end:
                child=node()
                if child is None:break
                if name=="Geometry":children.append(child)
            assert f.tell()==end,(name,f.tell(),end)
            record={"name":name,"props":props,"children":children}
            if name=="RelativeFilename" and props and props[0]:
                ref=(path.parent/props[0].replace(chr(92),"/")).resolve()
                assert ref.is_file(),str(ref)
                texture_refs.append(str(ref))
            if name=="Geometry" and props[2]=="Mesh":
                gname=props[1].split("\x00")[0]
                c={n["name"]:n for n in children}
                triangles=c["PolygonVertexIndex"]["props"][0]["triangles"]
                vertices=c["Vertices"]["props"][0]["arrayLength"]//3
                assert triangles<=9000
                assert gname in meshmap,gname
                expected=meshmap[gname]
                assert expected["triangles"]==triangles,(gname,triangles,expected["triangles"])
                assert expected["vertices"]==vertices,(gname,vertices,expected["vertices"])
                geometries.append({"name":gname,"triangles":triangles,"vertices":vertices})
            return record
        while node() is not None:pass
        return geometries
for batch in manifest["batches"]:
    path=ROOT/batch["file"]
    geos=scan(path)
    names=sorted(g["name"] for g in geos)
    assert names==sorted(batch["meshNames"]),(path.name,len(names),batch["meshes"])
    assert path.stat().st_size<=50*1024**2
    reports.append({"file":path.name,"geometryCount":len(geos),"triangles":sum(g["triangles"] for g in geos),"bytes":path.stat().st_size,"passed":True})
result={"allPassed":True,"batches":len(reports),"meshes":sum(r["geometryCount"] for r in reports),"triangles":sum(r["triangles"] for r in reports),"checks":["FBX binary file parse","all geometry names equal manifest","all triangle and vertex counts equal manifest","every face triangulated","every mesh<=9000 triangles","every batch<=50 MiB","all relative texture references resolve"],"reports":reports}
(ROOT/"file_validation.json").write_text(json.dumps(result,indent=2),encoding="utf8")
print(json.dumps({k:v for k,v in result.items() if k!="reports"}))


