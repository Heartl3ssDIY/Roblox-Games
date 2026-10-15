import bpy,json,os,bmesh
from mathutils import Vector
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('Export')]
def cells(ob):
 if ob.get('Cells'):
  return [(tuple(p[i]-s[i]/2 for i in range(3)),tuple(p[i]+s[i]/2 for i in range(3))) for p,s in json.loads(ob['Cells'])]
 vs=[ob.matrix_world@Vector(v) for v in ob.bound_box]
 return [(tuple(min(v[i] for v in vs) for i in range(3)),tuple(max(v[i] for v in vs) for i in range(3)))]
bpy.context.view_layer.update()
cache={o.name:cells(o) for o in objects}
overlaps=[]
for i,a in enumerate(objects):
 for b in objects[i+1:]:
  hit=0
  for mn,mx in cache[a.name]:
   for bn,bx in cache[b.name]:
    ds=[min(mx[k],bx[k])-max(mn[k],bn[k]) for k in range(3)]
    if min(ds)>.002:hit+=ds[0]*ds[1]*ds[2]
  if hit>.002:overlaps.append([a.name,b.name,round(hit,4)])
nonmanifold=[];materials=[]
for ob in objects:
 bm=bmesh.new();bm.from_mesh(ob.data)
 count=sum(not e.is_manifold for e in bm.edges)
 if count:nonmanifold.append([ob.name,count])
 bm.free()
 if len(ob.data.materials)!=1:materials.append(ob.name)
result={'export_parts':len(objects),'overlapping_bounds_or_cells':overlaps,'nonmanifold_edges':nonmanifold,'material_errors':materials,'modifiers':sum(len(o.modifiers) for o in objects)}
with open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\WarehouseRedesign\geometry_checks.json','w') as f:json.dump(result,f,indent=2)
print(json.dumps(result))
