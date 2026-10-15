import struct,zlib,math,json,hashlib,sys
from array import array
from pathlib import Path

class Reader:
    def __init__(self,path):
        self.data=Path(path).read_bytes();self.pos=27
        assert self.data[:23]==b"Kaydara FBX Binary  \x00\x1a\x00"
        self.version=struct.unpack_from("<I",self.data,23)[0]
        self.header="<QQQB" if self.version>=7500 else "<IIIB"
        self.hs=struct.calcsize(self.header)
    def take(self,n):
        b=self.data[self.pos:self.pos+n];self.pos+=n;return b
    def prop(self,nodeName):
        t=self.take(1).decode()
        types={"Y":"h","C":"?","I":"i","L":"q","F":"f","D":"d"}
        if t in types:
            fmt="<"+types[t];return struct.unpack(fmt,self.take(struct.calcsize(fmt)))[0]
        if t in ("S","R"):
            n=struct.unpack("<I",self.take(4))[0];b=self.take(n)
            return b.decode("utf8",errors="replace") if t=="S" else {"rawHash":hashlib.sha256(b).hexdigest()}
        if t in "fdlibc":
            count,enc,size=struct.unpack("<III",self.take(12));b=self.take(size)
            if enc:b=zlib.decompress(b)
            if nodeName=="Vertices":
                a=array(t);a.frombytes(b)
                if sys.byteorder!="little":a.byteswap()
                assert len(a)==count
                return a
            return {"arrayCount":count,"arrayType":t,"arrayHash":hashlib.sha256(b).hexdigest()}
        raise ValueError(t)
    def node(self):
        end,nprops,nbytes,nlen=struct.unpack(self.header,self.take(self.hs))
        if not end:return None
        name=self.take(nlen).decode()
        props=[self.prop(name) for _ in range(nprops)]
        children=[]
        while self.pos<end:
            c=self.node()
            if c is None:break
            children.append(c)
        assert self.pos==end,(name,self.pos,end)
        return {"name":name,"props":props,"children":children}
    def all(self):
        out=[]
        while True:
            n=self.node()
            if n is None:return out
            out.append(n)
def child(n,name):
    return next((c for c in n["children"] if c["name"]==name),None)
def props(n):
    p=child(n,"Properties70")
    return {c["props"][0]:c["props"][4:] for c in p["children"]} if p else {}
def identity():
    return [[1. if i==j else 0. for j in range(4)] for i in range(4)]
def mm(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def translation(v):
    a=identity()
    for i in range(3):a[i][3]=v[i]
    return a
def scale(v):
    a=identity()
    for i in range(3):a[i][i]=v[i]
    return a
def rotate(v,order=0):
    rotations=[]
    for axis,deg in enumerate(v):
        a=identity();i,j=((1,2),(2,0),(0,1))[axis];c=math.cos(math.radians(deg));s=math.sin(math.radians(deg))
        a[i][i]=a[j][j]=c;a[i][j]=-s;a[j][i]=s
        rotations.append(a)
    assert order==0,("Unsupported non-XYZ order",order)
    return mm(rotations[2],mm(rotations[1],rotations[0]))
def invrot(m):
    a=identity()
    for i in range(3):
        for j in range(3):a[i][j]=m[j][i]
    return a
def compose(*matrices):
    a=identity()
    for m in matrices:a=mm(a,m)
    return a
def nodeMatrix(p,geometric=False):
    if geometric:
        return compose(translation(p.get("GeometricTranslation",[0,0,0])),rotate(p.get("GeometricRotation",[0,0,0])),scale(p.get("GeometricScaling",[1,1,1])))
    rp=p.get("RotationPivot",[0,0,0]);sp=p.get("ScalingPivot",[0,0,0])
    return compose(translation(p.get("Lcl Translation",[0,0,0])),
        translation(p.get("RotationOffset",[0,0,0])),translation(rp),
        rotate(p.get("PreRotation",[0,0,0])),
        rotate(p.get("Lcl Rotation",[0,0,0]),p.get("RotationOrder",[0])[0]),
        invrot(rotate(p.get("PostRotation",[0,0,0]))),
        translation([-x for x in rp]),translation(p.get("ScalingOffset",[0,0,0])),
        translation(sp),scale(p.get("Lcl Scaling",[1,1,1])),translation([-x for x in sp]))
def audit(path):
    nodes=Reader(path).all();objects=next(n for n in nodes if n["name"]=="Objects")
    connections=next(n for n in nodes if n["name"]=="Connections")
    parents={n["props"][1]:n["props"][2] for n in connections["children"] if n["props"][0]=="OO"}
    models={n["props"][0]:n for n in objects["children"] if n["name"]=="Model"}
    geos=[n for n in objects["children"] if n["name"]=="Geometry" and n["props"][2]=="Mesh"]
    def world(mid,seen=None):
        if mid not in models:return identity()
        seen=set() if seen is None else seen
        assert mid not in seen;seen.add(mid)
        p=props(models[mid]);local=nodeMatrix(p)
        parent=parents.get(mid,0)
        if parent in models:
            assert props(models[parent]).get("Lcl Scaling",[1,1,1])==[1,1,1],"Need explicit FBX scaling inheritance"
        return mm(world(parent,seen),local)
    out=[]
    for g in geos:
        mid=parents[g["props"][0]];model=models[mid];p=props(model)
        mat=mm(world(mid),nodeMatrix(p,True))
        vertices=child(g,"Vertices")["props"][0]
        lo=[math.inf]*3;hi=[-math.inf]*3
        for k in range(0,len(vertices),3):
            x,y,z=vertices[k:k+3]
            point=[r[0]*x+r[1]*y+r[2]*z+r[3] for r in mat[:3]]
            for i,v in enumerate(point):lo[i]=min(lo[i],v);hi[i]=max(hi[i],v)
        out.append({"name":g["props"][1].split("\x00")[0],"model":model["props"][1].split("\x00")[0],"bounds":[lo,hi],"vertices":len(vertices)//3,"properties":p})
    settings=next(n for n in nodes if n["name"]=="GlobalSettings")
    return {"file":Path(path).name,"meshes":len(out),"unit":props(settings).get("UnitScaleFactor"),"bounds":[[min(g["bounds"][0][i] for g in out) for i in range(3)],[max(g["bounds"][1][i] for g in out) for i in range(3)]],"geometry":out,"nodes":nodes}

root=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports")
old=root/"ImportReady_20260926";new=root/"ImportReady_ScaleFixed_20260926"
manifest=json.loads((new/"import_manifest.json").read_text(encoding="utf-8-sig"))
expected={g["name"]:g for g in manifest["meshes"]}
def arrays(nodes,path=""):
    out={}
    for idx,n in enumerate(nodes):
        key=path+"/"+str(idx)+":"+n["name"]
        if n["name"]!="Vertices":
            for j,p in enumerate(n["props"]):
                if isinstance(p,dict) and "arrayHash" in p:out[key+":"+str(j)]=p
        out.update(arrays(n["children"],key))
    return out
def geometry(nodes):
    objs=next(n for n in nodes if n["name"]=="Objects")
    return {g["props"][1].split("\x00")[0]:g for g in objs["children"] if g["name"]=="Geometry" and g["props"][2]=="Mesh"}
reports=[]
for filename in ["01_Landscape_01.fbx","03_Civic_Branding_01.fbx","05_Summon_Hall_01.fbx","10_Academy_01.fbx","14_60_ArenaPortals_Gate_04_01.fbx","ACU_Citadel_Collision.fbx"]:
    a=audit(old/filename);b=audit(new/filename);collision=filename=="ACU_Citadel_Collision.fbx"
    ga={g["name"]:g for g in a["geometry"]};gb={g["name"]:g for g in b["geometry"]}
    assert ga.keys()==gb.keys()
    maxratio=max(abs(gb[n]["bounds"][k][i]-ga[n]["bounds"][k][i]*.01) for n in ga for k in range(2) for i in range(3))
    aa,ab=arrays(a["nodes"]),arrays(b["nodes"]);assert aa==ab
    vertsBefore=geometry(a["nodes"]);vertsAfter=geometry(b["nodes"])
    maxVertexError=0
    for name,geo in vertsBefore.items():
        va=child(geo,"Vertices")["props"][0];vb=child(vertsAfter[name],"Vertices")["props"][0]
        assert len(va)==len(vb)
        maxVertexError=max(maxVertexError,max(abs(y-x*(1 if collision else .01)) for x,y in zip(va,vb)))
    assert maxVertexError<1e-10
    maxmanifest=0
    if not collision:
        for name,g in gb.items():
            bl=expected[name]["boundsBlender"]
            bounds=[[bl[0][0],bl[0][2],-bl[1][1]],[bl[1][0],bl[1][2],-bl[0][1]]]
            maxmanifest=max(maxmanifest,max(abs(g["bounds"][j][i]-bounds[j][i]) for i in range(3) for j in range(2)))
        assert maxmanifest<.0001
    assert maxratio<.00001
    reports.append({"file":filename,"meshes":len(gb),"bounds":b["bounds"],"size":[b["bounds"][1][i]-b["bounds"][0][i] for i in range(3)],"unitScaleFactor":b["unit"],"maximumWorldRatioError":maxratio,"maximumVertexRatioError":maxVertexError,"maximumManifestError":maxmanifest if not collision else None,"otherArrayHashesEqual":True,"otherArraysCompared":len(aa)})
textureNames=sorted(p.name for p in (new/"textures").iterdir() if p.is_file())
assert textureNames==sorted(p.name for p in (old/"textures").iterdir() if p.is_file())
for name in textureNames:
    assert hashlib.sha256((old/"textures"/name).read_bytes()).digest()==hashlib.sha256((new/"textures"/name).read_bytes()).digest()
assert (old/"markers.json").read_bytes()==(new/"markers.json").read_bytes()
assert (old/"text_optimization.json").read_bytes()==(new/"text_optimization.json").read_bytes()
markers=json.loads((new/"markers.json").read_text())
for m in markers["markers"]:
    x,y,z=m["blender"];assert max(abs(a-b) for a,b in zip(m["roblox"],[x,z,-y]))<1e-8
result={"allPassed":True,"independentReader":"Custom binary parser; independent transform matrices and bound math; no Blender runtime used.","reports":reports,"texturesByteIdentical":len(textureNames),"markerCoordinatesUnchanged":len(markers["markers"]),"markerAxisConversionVerified":True,"textOptimizationManifestByteIdentical":True}
print(json.dumps(result))


cube=audit(new/"00_SCALE_CHECK_10_STUDS.fbx")
assert cube["bounds"]==[[-5.,-5.,-5.],[5.,5.,5.]]
print(json.dumps({"calibrationPassed":True,"bounds":cube["bounds"],"meshes":cube["meshes"]}))

