from pathlib import Path
import importlib.util,json,copy,math,shutil,hashlib
from array import array
BASE=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel\exports\ImportReady_ScaleFixed_20260926")
OUT=BASE.parent/"Retry_TwoBatches_20260926"
sp=importlib.util.spec_from_file_location("fx",BASE/"fix_fbx_unit_scale.py");fx=importlib.util.module_from_spec(sp);sp.loader.exec_module(fx)
OUT.mkdir(parents=True,exist_ok=True)
old=json.loads((BASE/"import_manifest.json").read_text());records={m["name"]:m for m in old["meshes"]}
def text(n):return n.props[0].value()
def find_bad(g):
 v=fx.child(g,b"Vertices").props[0].value();p=fx.child(g,b"PolygonVertexIndex").props[0].value();bad=[]
 for i in range(0,len(p),3):
  ids=[k if k>=0 else -k-1 for k in p[i:i+3]];vs=[v[k*3:k*3+3] for k in ids];a=[vs[1][k]-vs[0][k] for k in range(3)];b=[vs[2][k]-vs[0][k] for k in range(3)]
  c=(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
  if sum(x*x for x in c)==0:bad.append(i//3)
 return bad
def clean_degenerate(g):
 bad=find_bad(g)
 if not bad:return 0
 badset=set(bad);pi=fx.child(g,b"PolygonVertexIndex").props[0];original=pi.value();nf=len(original)//3;kept=[i for i in range(nf) if i not in badset];loops=[3*i+j for i in kept for j in range(3)]
 newpi=array(original.typecode,(original[i] for i in loops));pi.numbers(newpi)
 for layer in g.children:
  if not layer.name.startswith(b"LayerElement"):continue
  mapping=fx.child(layer,b"MappingInformationType");ref=fx.child(layer,b"ReferenceInformationType")
  if mapping is None:continue
  mode=text(mapping)
  if mode==b"AllSame":continue
  if mode==b"ByPolygon":
   assert layer.name==b"LayerElementSmoothing" and text(ref)==b"Direct"
   data=fx.child(layer,b"Smoothing").props[0];a=data.value();assert len(a)==nf;data.numbers(array(a.typecode,(a[i] for i in kept)))
  elif mode==b"ByPolygonVertex":
   assert text(ref)==b"IndexToDirect"
   key={b"LayerElementNormal":b"NormalsIndex",b"LayerElementUV":b"UVIndex"}[layer.name]
   data=fx.child(layer,key).props[0];a=data.value();assert len(a)==nf*3;data.numbers(array(a.typecode,(a[i] for i in loops)))
  else:raise AssertionError((layer.name,mode))
 edges=fx.child(g,b"Edges")
 if edges is not None:
  seen=set();edgeindices=[]
  for i in range(0,len(newpi),3):
   ids=[k if k>=0 else -k-1 for k in newpi[i:i+3]]
   for j in range(3):
    key=tuple(sorted((ids[j],ids[(j+1)%3])))
    if key not in seen:seen.add(key);edgeindices.append(i+j)
  edges.props[0].numbers(array("i",edgeindices))
 assert find_bad(g)==[]
 return len(bad)
def subset(nodes,keep_geos):
 ns=copy.deepcopy(nodes);models,geos,links=fx.object_data(ns)
 keep_models={links[g] for g in keep_geos}
 removed=(set(geos)-set(keep_geos))|(set(models)-keep_models)
 objects=next(n for n in ns if n.name==b"Objects")
 objects.children=[n for n in objects.children if not(n.name in (b"Model",b"Geometry") and int(n.props[0].value()) in removed)]
 connections=next(n for n in ns if n.name==b"Connections")
 connections.children=[c for c in connections.children if not(c.name==b"C" and (int(c.props[1].value()) in removed or int(c.props[2].value()) in removed))]
 defs=next(n for n in ns if n.name==b"Definitions")
 count=fx.child(defs,b"Count").props[0];count.scalar(count.value()-len(removed))
 for obtype in defs.children:
  if obtype.name!=b"ObjectType":continue
  name=obtype.props[0].value()
  if name in (b"Model",b"Geometry"):fx.child(obtype,b"Count").props[0].scalar(len(keep_models) if name==b"Model" else len(keep_geos))
 return ns
outputs=[];cleanup=[];outrecords=[]
for source,maxmeshes in (("16_Outer_Gardens_Forests_01.fbx",64),("14_60_ArenaPortals_Torii_01_01.fbx",8)):
 version,nodes=fx.read(BASE/source);models,geos,links=fx.object_data(nodes)
 before=fx.transformed_bounds(nodes)
 for gid,g in geos.items():
  name=g.props[1].value().split(b"\x00")[0].decode();removed=clean_degenerate(g)
  if removed:
   cleanup.append({"mesh":name,"zeroAreaTrianglesRemoved":removed,"reason":"Coincident vertices created no visible surface."})
   records[name]=copy.deepcopy(records[name]);records[name]["triangles"]-=removed
   props=fx.child(models[links[gid]],b"Properties70")
   for prop in props.children:
    if prop.props[0].value()==b"ACU_TriangleCount":prop.props[-1].scalar(records[name]["triangles"])
 assert before==fx.transformed_bounds(nodes),"Cleanup moved geometry"
 ids=sorted(geos,key=lambda gid:geos[gid].props[1].value())
 for start in range(0,len(ids),maxmeshes):
  use=ids[start:start+maxmeshes];part=start//maxmeshes;name=Path(source).stem+"_RETRY_"+chr(65+part)+".fbx";dest=OUT/name
  assert not dest.exists()
  ns=subset(nodes,use);fx.write(dest,version,ns);_,check=fx.read(dest)
  assert {p:v.raw for p,v in fx.walk(ns)}=={p:v.raw for p,v in fx.walk(check)}
  mm,gg,ll=fx.object_data(check);assert len(gg)==len(use)
  names=[g.props[1].value().split(b"\x00")[0].decode() for g in gg.values()]
  assert all(not find_bad(g) for g in gg.values())
  r=[records[n] for n in names];outrecords+=r
  bounds=fx.transformed_bounds(check)
  outputs.append({"file":name,"replaces":source,"bytes":dest.stat().st_size,"meshes":len(gg),"triangles":sum(x["triangles"] for x in r),"meshNames":names,"worldBounds":bounds,"sha256":hashlib.sha256(dest.read_bytes()).hexdigest()})
shutil.copytree(BASE/"textures",OUT/"textures",dirs_exist_ok=True)
assert len({n for b in outputs for n in b["meshNames"]})==266
m={"sourcePackage":str(BASE),"batches":outputs,"meshes":outrecords,"cleanup":cleanup,"textures":old["textures"],"PBRMaterials":old["PBRMaterials"],"coordinates":"Unchanged from scale-fixed package. Studs, import scale1.","failureCauseKnown":False}
(OUT/"import_manifest.json").write_text(json.dumps(m,indent=2),encoding="utf8")
shutil.copy2(BASE/"validate_fbx_files.py",OUT/"validate_fbx_files.py")
notes="""RETRY FILES FOR ONLY TWO MISSING LOBBY BATCHES

Use these files only if the original two batches still fail. Do not import them on top of those batches if the retry succeeds.
Four files marked16_...RETRY_A throughD collectively replace16_Outer_Gardens_Forests_01.fbx.
Two files marked14_...RETRY_A throughB collectively replace14_60_ArenaPortals_Torii_01_01.fbx.
Do not reimport the other40successful batches.

Settings: Studs / scale1; Merge Meshes OFF; Insert Using Scene Position ON; Set Pivot to Scene Origin ON; Anchored ON.
No additional scaling. Every coordinate remains unchanged from the corrected package.
Keep the textures folder beside these files.

The forest batch had16 zero-area triangles with coincident vertices in one wood mesh. Only those invisible collapsed faces were removed.
All other geometry, vertex positions, texture images and visible face UVs/normals are retained.
Torii geometry was unchanged and only divided into two uploads.
The original import failure's cause is not confirmed; splitting reduces the amount processed in each retry.

Original files are untouched. import_manifest.json records all266mesh names, replacements and cleanup.
"""
(OUT/"START_HERE.txt").write_text(notes,encoding="utf8")
print(json.dumps({"files":[{"file":b["file"],"bytes":b["bytes"],"meshes":b["meshes"],"triangles":b["triangles"]} for b in outputs],"cleanup":cleanup}))

