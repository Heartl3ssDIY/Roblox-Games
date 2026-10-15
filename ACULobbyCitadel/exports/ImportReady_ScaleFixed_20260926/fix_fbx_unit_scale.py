"""Correct the proven 100x FBX unit bake without changing art, textures, UVs or normals."""
from pathlib import Path
from array import array
import struct,zlib,math,json,hashlib,shutil,sys
SOURCE=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports\ImportReady_20260926")
OUT=SOURCE.parent/"ImportReady_ScaleFixed_20260926"
FACTOR=.01
SCALARS={"Y":"h","I":"i","L":"q","F":"f","D":"d","C":"?"}
class Prop:
    def __init__(self,t,raw):self.t=t;self.raw=raw
    def value(self):
        data=self.raw[1:]
        if self.t in SCALARS:return struct.unpack("<"+SCALARS[self.t],data)[0]
        if self.t in ("S","R"):return data[4:]
        count,enc,n=struct.unpack("<III",data[:12])
        raw=zlib.decompress(data[12:]) if enc else data[12:]
        a=array(self.t);a.frombytes(raw)
        if sys.byteorder!="little":a.byteswap()
        assert len(a)==count
        return a
    def scalar(self,v):self.raw=self.t.encode()+struct.pack("<"+SCALARS[self.t],v)
    def numbers(self,a):
        if sys.byteorder!="little":a.byteswap()
        raw=a.tobytes();packed=zlib.compress(raw,1)
        self.raw=self.t.encode()+struct.pack("<III",len(a),1,len(packed))+packed
class Node:
    def __init__(self,name,props,children,term):self.name=name;self.props=props;self.children=children;self.term=term
def read(path):
    with Path(path).open("rb") as f:
        header=f.read(23);assert header==b"Kaydara FBX Binary  \x00\x1a\x00"
        version=struct.unpack("<I",f.read(4))[0];fmt="<QQQB" if version>=7500 else "<IIIB";hs=struct.calcsize(fmt)
        def node():
            data=f.read(hs)
            if len(data)!=hs:return None
            end,num,plen,nlen=struct.unpack(fmt,data)
            if not end:return None
            name=f.read(nlen);props=[]
            for _ in range(num):
                pos=f.tell();t=f.read(1).decode()
                if t in SCALARS:f.seek(struct.calcsize("<"+SCALARS[t]),1)
                elif t in ("S","R"):f.seek(struct.unpack("<I",f.read(4))[0],1)
                elif t in "fdlibc":
                    count,enc,n=struct.unpack("<III",f.read(12));f.seek(n,1)
                else:raise ValueError(t)
                finish=f.tell();f.seek(pos);props.append(Prop(t,f.read(finish-pos)))
            children=[];term=False
            while f.tell()<end:
                child=node()
                if child is None:term=True;break
                children.append(child)
            assert f.tell()==end
            return Node(name,props,children,term)
        children=[]
        while True:
            n=node()
            if n is None:break
            children.append(n)
        return version,children
def write(path,version,children):
    fmt="<QQQB" if version>=7500 else "<IIIB";hs=struct.calcsize(fmt);null=b"\0"*hs
    def size(n):return hs+len(n.name)+sum(len(p.raw) for p in n.props)+sum(size(c) for c in n.children)+(hs if n.term else 0)
    with Path(path).open("wb") as f:
        f.write(b"Kaydara FBX Binary  \x00\x1a\x00"+struct.pack("<I",version))
        def node(n):
            end=f.tell()+size(n)
            f.write(struct.pack(fmt,end,len(n.props),sum(len(p.raw) for p in n.props),len(n.name)));f.write(n.name)
            for p in n.props:f.write(p.raw)
            for c in n.children:node(c)
            if n.term:f.write(null)
            assert f.tell()==end
        for n in children:node(n)
        f.write(null)
        f.write(b"\xfa\xbc\xab\x09\xd0\xc8\xd4\x66\xb1\x76\xfb\x83\x1c\xf7\x26\x7e")
        f.write(b"\0"*4)
        pad=(-f.tell())%16 or 16;f.write(b"\0"*pad)
        f.write(struct.pack("<I",version));f.write(b"\0"*120)
        f.write(b"\xf8\x5a\x8c\x6a\xde\xf5\xd9\x7e\xec\xe9\x0c\xe3\x75\x8f\x29\x0b")
def child(n,name):return next((c for c in n.children if c.name==name),None)
def prop_values(n):return [p.value() for p in n.props]
def properties(n):
    p=child(n,b"Properties70")
    return {c.props[0].value().decode():[x.value() for x in c.props[4:]] for c in p.children} if p else {}
def object_data(nodes):
    obs=next(n for n in nodes if n.name==b"Objects")
    connections=next(n for n in nodes if n.name==b"Connections")
    models={int(n.props[0].value()):n for n in obs.children if n.name==b"Model"}
    geos={int(n.props[0].value()):n for n in obs.children if n.name==b"Geometry"}
    links={int(c.props[1].value()):int(c.props[2].value()) for c in connections.children if c.name==b"C" and c.props[0].value()==b"OO"}
    assert all(links.get(mid,0)==0 for mid in models),"Non-flat model hierarchy needs dedicated handling"
    return models,geos,links
def transformed_bounds(nodes):
    models,geos,links=object_data(nodes);lo=[math.inf]*3;hi=[-math.inf]*3
    for gid,g in geos.items():
        p=properties(models[links[gid]])
        for k in ("PreRotation","PostRotation","RotationPivot","ScalingPivot","RotationOffset","ScalingOffset"):
            assert all(abs(v)<1e-10 for v in p.get(k,[0,0,0])),(k,p.get(k))
        assert p.get("RotationOrder",[0])==[0]
        t=p.get("Lcl Translation",[0,0,0]);s=p.get("Lcl Scaling",[1,1,1]);r=p.get("Lcl Rotation",[0,0,0])
        rx,ry,rz=[math.radians(v) for v in r];cx,sx=math.cos(rx),math.sin(rx);cy,sy=math.cos(ry),math.sin(ry);cz,sz=math.cos(rz),math.sin(rz)
        a=child(g,b"Vertices").props[0].value()
        for i in range(0,len(a),3):
            x,y,z=a[i]*s[0],a[i+1]*s[1],a[i+2]*s[2]
            y,z=cx*y-sx*z,sx*y+cx*z
            x,z=cy*x+sy*z,-sy*x+cy*z
            x,y=cz*x-sz*y,sz*x+cz*y
            v=(x+t[0],y+t[1],z+t[2])
            for ax in range(3):lo[ax]=min(lo[ax],v[ax]);hi[ax]=max(hi[ax],v[ax])
    return {"min":lo,"max":hi,"size":[hi[i]-lo[i] for i in range(3)]}
def walk(nodes,prefix=()):
    for i,n in enumerate(nodes):
        path=prefix+((n.name.decode(),i),)
        for j,p in enumerate(n.props):yield path+(("property",j),),p
        yield from walk(n.children,path)
def fix_file(source,dest,collision=False):
    assert not dest.exists(),"Refusing to overwrite "+str(dest)
    version,nodes=read(source)
    before=transformed_bounds(nodes)
    before_props={p:prop.raw for p,prop in walk(nodes)}
    models,geos,links=object_data(nodes)
    changed=0
    if collision:
        for model in models.values():
            props=child(model,b"Properties70")
            assert props is not None
            entries={p.props[0].value():p for p in props.children}
            assert b"Lcl Scaling" in entries
            for key in (b"Lcl Translation",b"Lcl Scaling"):
                if key in entries:
                    for v in entries[key].props[4:]:v.scalar(v.value()*FACTOR);changed+=1
    else:
        for model in models.values():
            p=properties(model)
            assert p.get("Lcl Translation",[0,0,0])==[0,0,0]
            assert p.get("Lcl Rotation",[0,0,0])==[0,0,0]
            assert p.get("Lcl Scaling",[1,1,1])==[1,1,1]
        for geo in geos.values():
            p=child(geo,b"Vertices").props[0];a=p.value()
            p.numbers(array(a.typecode,(v*FACTOR for v in a)));changed+=1
    after=transformed_bounds(nodes)
    error=max(abs(after[k][i]-before[k][i]*FACTOR) for k in ("min","max","size") for i in range(3))
    assert error<.000001,error
    intended_props={p:prop.raw for p,prop in walk(nodes)}
    altered={p for p in before_props if before_props[p]!=intended_props[p]}
    for path in altered:
        if collision:
            assert path[-2][0]=="P"
        else:assert path[-2][0]=="Vertices"
    write(dest,version,nodes)
    read_version,reread=read(dest)
    assert read_version==version
    actual_props={p:prop.raw for p,prop in walk(reread)}
    assert actual_props==intended_props,"Re-encoded file changed an unexpected property"
    check=transformed_bounds(reread);assert check==after
    return {"file":dest.name,"collision":collision,"before":before,"after":after,"worldScaleRatio":.01,"maxScalingError":error,"models":len(models),"meshes":len(geos),"alteredPropertyCount":len(altered),"untouchedPropertiesByteIdentical":True,"bytes":dest.stat().st_size}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    old=json.loads((SOURCE/"import_manifest.json").read_text())
    checks=[]
    for b in old["batches"]:
        checks.append(fix_file(SOURCE/b["file"],OUT/b["file"]))
        print("SCALE_FIXED "+b["file"],flush=True)
    checks.append(fix_file(SOURCE/"ACU_Citadel_Collision.fbx",OUT/"ACU_Citadel_Collision.fbx",True))
    shutil.copytree(SOURCE/"textures",OUT/"textures",dirs_exist_ok=True)
    for filename in ("markers.json","collision_manifest.json","text_optimization.json","Lettering_Comparison.png","validate_fbx_files.py"):
        shutil.copy2(SOURCE/filename,OUT/filename)
    for tex in old["textures"]:assert sha(SOURCE/tex["file"])==sha(OUT/tex["file"])
    for b in old["batches"]:
        path=OUT/b["file"];b["bytes"]=path.stat().st_size;b["sha256"]=sha(path)
    visual=[c for c in checks if not c["collision"]]
    lo=[min(c["after"]["min"][i] for c in visual) for i in range(3)];hi=[max(c["after"]["max"][i] for c in visual) for i in range(3)]
    actual={"min":lo,"max":hi,"size":[hi[i]-lo[i] for i in range(3)]}
    meshlo=[min(m["boundsBlender"][0][i] for m in old["meshes"]) for i in range(3)];meshhi=[max(m["boundsBlender"][1][i] for m in old["meshes"]) for i in range(3)]
    expected={"min":[meshlo[0],meshlo[2],-meshhi[1]],"max":[meshhi[0],meshhi[2],-meshlo[1]],"size":[meshhi[0]-meshlo[0],meshhi[2]-meshlo[2],meshhi[1]-meshlo[1]]}
    bounds_error=max(abs(expected[k][i]-actual[k][i]) for k in expected for i in range(3))
    assert bounds_error<.0001,bounds_error
    old["scaleCorrection"]={"factorAppliedToPriorFBXWorldCoordinates":.01,"reason":"Blender exporter FBX_SCALE_NONE baked implicit100cm-per-unit into vertices/model transforms, while manifest and markers intended1unit=1stud.","actualBinaryWorldBounds":actual,"intendedManifestWorldBounds":expected,"maximumBoundsErrorStuds":bounds_error,"futureExportSettings":{"global_scale":.01,"apply_unit_scale":False,"apply_scale_options":"FBX_SCALE_NONE","bake_space_transform":True}}
    old["after"]["fbxBytes"]=sum(b["bytes"] for b in old["batches"]);old["after"]["maximumBatchBytes"]=max(b["bytes"] for b in old["batches"])
    (OUT/"import_manifest.json").write_text(json.dumps(old,indent=2),encoding="utf8")
    report={"allPassed":True,"scaleFactor":.01,"files":checks,"actualBinaryVisualWorldBounds":actual,"expectedManifestWorldBounds":expected,"maxBoundsErrorStuds":bounds_error,"allTextureBytesIdentical":True,"normalsUVsTopologyMaterialPropertiesUnchanged":True,"modelHierarchiesVerifiedFlat":True,"rootCause":"Blender5.2 export_fbx_bin.py3542-3545: apply_unit_scale=False still sets unit_scale100; FBX_SCALE_NONE bakes it into global_matrix and setsUnitScaleFactor1."}
    (OUT/"scale_validation.json").write_text(json.dumps(report,indent=2),encoding="utf8")
    print("ALL_SCALE_FIXED "+json.dumps(actual),flush=True)
if __name__=="__main__":main()

