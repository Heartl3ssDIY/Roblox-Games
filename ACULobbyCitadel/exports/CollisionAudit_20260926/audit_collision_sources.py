import bpy,json,re,math
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(r"C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ACULobbyCitadel")
OUT=ROOT/"exports"/"CollisionAudit_20260926";OUT.mkdir(exist_ok=True)
package=ROOT/"exports"/"ImportReady_ScaleFixed_20260926"
original=json.loads((package/"collision_manifest.json").read_text())
included=set(original["sourceMeshes"])
manifest=json.loads((package/"import_manifest.json").read_text())
source_to_exports={}
for mesh in manifest["meshes"]:
 for source in mesh["sources"]:source_to_exports.setdefault(source,[]).append(mesh["name"])
B=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
walk_rx=re.compile(r"floor|foundation|plaza|court|terrace|paving|avenue|pavement|road|walkway|walkable|landing|stair|step|deck|bridge|gallery")
exclude_rx=re.compile(r"roof|rail|handrail|inlay|inscription|letter|label|text|sign|window|scroll|lantern|light|leaf|canopy|petal|foliage|water|gold|trim|seam|joint")
structures_rx=re.compile(r"wall|pillar|column|support|post|pier|plinth|base|platform|arch")
candidates=[];existing=[];text_names={o.name for o in bpy.context.scene.objects if o.type=="FONT"}
for ob in bpy.context.scene.objects:
 if ob.type!="MESH" or ob.name not in source_to_exports:continue
 n=ob.name.lower()
 collection=sorted(c.name.split("|")[-1].strip() for c in ob.users_collection)[0]
 reason=None
 if ob.name in included:reason="existing"
 elif n.startswith("waterfall_stair_"):reason="missing_waterfall_steps"
 elif ob.name in ("Grand court foundation","Garden terrace | walkable island top","Waterfall_VistaDeck","Expanded island top"):reason="missing_major_walk_surface"
 elif n.startswith("radial cut limestone"):reason="missing_plaza_paving"
 elif walk_rx.search(n) and not exclude_rx.search(n):reason="missing_named_walk_surface"
 elif collection.startswith(("50_City","51_Academy","52_Celestial","53_","36_Backdrop")) and n.endswith(("_ivory","_wood","_stone","_stonedark","_stonelight","_red","_roof")):reason="missing_batched_building_structure"
 elif structures_rx.search(n) and not exclude_rx.search(n) and collection.startswith(("30_","31_","32_","33_","34_","36_","37_","50_City","51_","52_","53_","54_","60_Arena")):reason="missing_structure_candidate"
 if reason is None:continue
 vs=ob.data.vertices
 if not len(vs):continue
 local_lo=Vector(tuple(min(v.co[i] for v in vs) for i in range(3)))
 local_hi=Vector(tuple(max(v.co[i] for v in vs) for i in range(3)))
 center_local=(local_lo+local_hi)/2
 corners=[ob.matrix_world@Vector((x,y,z)) for x in (local_lo.x,local_hi.x) for y in (local_lo.y,local_hi.y) for z in (local_lo.z,local_hi.z)]
 points=[B@c for c in corners]
 bounds=[[min(c[i] for c in points) for i in range(3)],[max(c[i] for c in points) for i in range(3)]]
 box=len(vs)==8 and all(min(abs(v.co[i]-local_lo[i]),abs(v.co[i]-local_hi[i]))<1e-6 for v in vs for i in range(3))
 loc,quat,scale=ob.matrix_world.decompose()
 center=B@(ob.matrix_world@center_local)
 rot=B@quat.to_matrix()@B.transposed()
 size_b=(local_hi-local_lo);size_b=Vector(tuple(size_b[i]*abs(scale[i]) for i in range(3)))
 size=[size_b.x,size_b.z,size_b.y]
 cf=[*center]+[rot[i][j] for i in range(3) for j in range(3)]
 row={"source":ob.name,"collection":collection,"reason":reason,"exportMeshNames":source_to_exports[ob.name],"sourceVertices":len(vs),"simpleCuboid":box,"proxyRecommendation":"NativePartBlock" if box else "ComplexMesh_Default_or_authored_proxy","cframeRoblox":cf,"sizeRoblox":size,"boundsRoblox":bounds,"sourceModifiersIgnoredForProxy":[m.type for m in ob.modifiers]}
 if reason=="existing":existing.append(row)
 else:candidates.append(row)
candidate_names={r["source"] for r in candidates}
exports=[]
for m in manifest["meshes"]:
 wanted=sorted(set(m["sources"])&candidate_names)
 if not wanted:continue
 extras=sorted(set(m["sources"])-candidate_names)
 exports.append({"mesh":m["name"],"collection":m["collection"],"material":m["material"],"wantedSources":wanted,"additionalSourceCount":len(extras),"containsText":bool(set(m["sources"])&text_names),"doubleSided":m["doubleSided"],"triangles":m["triangles"],"safeForBlanketBox":False})
counts={}
for r in candidates:counts[r["reason"]]=counts.get(r["reason"],0)+1
data={"fileOnlyAudit":True,"coordinateFrame":"File coordinates = Blender(X,Z,-Y). If live artwork has180Y rotation, premultiply every supplied CFrame by CFrame.Angles(0,math.pi,0) plus the same lobby translation; do not rotate only some colliders.","originalCollisionSourceObjects":len(included),"candidateCounts":counts,"existing":existing,"missingCandidates":candidates,"visualMeshesContainingCandidates":exports,"specificSurfaces":{"plazaVisualTopY":1.52,"plazaFoundationDiameter":66,"plazaFoundationTopY":1.46,"originalGardenTerraceTopY":1.2,"originalGardenTerraceDiameter":218,"broadExistingIslandProxyTopY":1.0,"broadExistingIslandProxyThickness":0},"warnings":["This is a geometry/label audit; complete runtime walkability still needs Studio playtesting.","Do not use Box fidelity for combined staircase meshes, arches, rings or non-convex objects.","Do not blanket-clone candidate-containing visual meshes: inspect additionalSourceCount and containsText first.","Native cuboid recommendations are exact raw source bounds; rounded visual bevels are intentionally omitted from the simple collision proxy.","Waterfall stairs rise up to45studs; the existing3landings cannot replace84missing stair pieces.","Roof and upper facade geometry may need separate obstruction checks if players can reach it."]}
(OUT/"collision_repair_candidates.json").write_text(json.dumps(data,indent=2),encoding="utf8")
print(json.dumps({"candidateCounts":counts,"missingCandidates":len(candidates),"simpleNativeParts":sum(c["simpleCuboid"] for c in candidates),"visualMeshCandidates":len(exports),"missingWaterfallSteps":sum(c["reason"]=="missing_waterfall_steps" for c in candidates)}))


