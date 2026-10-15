"""Read-only source evaluation in a separate Blender process; writes plain glTF 2.0."""
import bpy, json, os, re, math, struct, array, collections, sys, shutil
from mathutils import Vector
BASE=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(BASE,'RobloxImport');os.makedirs(OUT,exist_ok=True)
ASSETS=json.load(open(os.path.join(BASE,'asset-manifest.json'),encoding='utf-8'))
BODIES=json.load(open(os.path.join(BASE,'interaction-manifest.json'),encoding='utf-8'))
scene=next(s for s in bpy.data.scenes if s.name.startswith('School Asset Library'))
bpy.context.window.scene=scene
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
NAMES={'Graphite powder coat':'black','Soft black rubber':'rubber','Blue black screen':'screen','Sand shell':'sand','Warm ivory':'ivory','Mushroom taupe':'taupe','Muted clay':'clay','Oatmeal woven fabric':'fabric','Warm taupe upholstery':'fabricdark','Smoked oak':'wood','Natural ash':'woodlight','Dusty pink eraser':'pink','Brushed steel':'metal','Muted brass':'brass','Porcelain white':'white','Warm white enamel':'board','Forest foliage':'leaf','Sage foliage':'leaflight','Deep green foliage':'leafdark','Potting soil':'soil','Bark':'bark','Saddle stitching':'thread','Dark upholstery seam':'seam','Glazed ivory ceramic':'ceramic','Polished keywork':'silver','Endgrain oak':'endgrain'}
shutil.copyfile(os.path.join(BASE,'textures','Bird-Logo.png'),os.path.join(OUT,'textures','Bird-Logo.png'))

def coord(v):return (v[0],v[2],-v[1])

class Writer:
    def __init__(self):
        self.doc={'asset':{'version':'2.0','generator':'School asset portable export'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],'textures':[],'images':[],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],'accessors':[],'bufferViews':[],'buffers':[]}
        self.buf=bytearray();self.mats={};self.textures={}
    def texture(self,path):
        if path not in self.textures:
            assert os.path.isfile(os.path.join(OUT,path)),path
            idx=len(self.doc['images']);self.doc['images'].append({'uri':path});self.doc['textures'].append({'source':idx,'sampler':0});self.textures[path]=idx
        return {'index':self.textures[path]}
    def material(self,name):
        if name in self.mats:return self.mats[name]
        short=name.split(' | ')[-1]
        if 'bird emblem' in short.lower():
            mat={'name':'Supplied white bird emblem','doubleSided':True,'alphaMode':'BLEND','pbrMetallicRoughness':{'baseColorTexture':self.texture('textures/Bird-Logo.png'),'metallicFactor':0,'roughnessFactor':.5}}
        elif short=='Setup marker':mat={'name':short,'pbrMetallicRoughness':{'baseColorFactor':[1,.02,0,1],'metallicFactor':0,'roughnessFactor':1}}
        else:
            key=NAMES[short]
            mat={'name':short,'doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':self.texture('textures/'+key+'_Color.png'),'metallicRoughnessTexture':self.texture('textures/'+key+'_MetalRough.png'),'metallicFactor':1,'roughnessFactor':1},'normalTexture':self.texture('textures/'+key+'_Normal.png')}
        idx=len(self.doc['materials']);self.doc['materials'].append(mat);self.mats[name]=idx;return idx
    def accessor(self,values,kind,component,target,bounds=False):
        while len(self.buf)%4:self.buf.append(0)
        offset=len(self.buf);flat=[c for v in values for c in v] if kind!='SCALAR' else values
        data=array.array('f' if component==5126 else 'I',flat).tobytes();self.buf.extend(data)
        vi=len(self.doc['bufferViews']);self.doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(data),'target':target})
        acc={'bufferView':vi,'componentType':component,'count':len(values),'type':kind}
        if bounds:acc.update({'min':[min(v[i] for v in values) for i in range(3)],'max':[max(v[i] for v in values) for i in range(3)]})
        idx=len(self.doc['accessors']);self.doc['accessors'].append(acc);return idx
    def mesh(self,name,triangles,material):
        lookup={};positions=[];normals=[];uvs=[];inds=[]
        for tri in triangles:
            for pos,norm,uv in tri:
                key=pos+norm+uv
                if key not in lookup:
                    lookup[key]=len(positions);positions.append(coord(pos));normals.append(coord(norm));uvs.append((uv[0],1-uv[1]))
                inds.append(lookup[key])
        attrs={'POSITION':self.accessor(positions,'VEC3',5126,34962,True),'NORMAL':self.accessor(normals,'VEC3',5126,34962),'TEXCOORD_0':self.accessor(uvs,'VEC2',5126,34962)}
        mi=len(self.doc['meshes']);self.doc['meshes'].append({'name':name,'primitives':[{'attributes':attrs,'indices':self.accessor(inds,'SCALAR',5125,34963),'material':self.material(material)}]})
        ni=len(self.doc['nodes']);self.doc['nodes'].append({'name':name,'mesh':mi});self.doc['scenes'][0]['nodes'].append(ni)
    def marker(self,name,point):
        s=.008;v=[tuple(point[i]+p[i]*s for i in range(3)) for p in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)];tris=[]
        for f in faces:
            normal=tuple((Vector(v[f[1]])-Vector(v[f[0]])).cross(Vector(v[f[2]])-Vector(v[f[0]])).normalized())
            for t in [(f[0],f[1],f[2]),(f[0],f[2],f[3])]:tris.append([(v[i],normal,(0,0)) for i in t])
        self.mesh(name,tris,'Setup marker')
    def save(self,name):
        binary=name.replace('.gltf','.bin');self.doc['buffers']=[{'uri':binary,'byteLength':len(self.buf)}]
        open(os.path.join(OUT,binary),'wb').write(self.buf)
        open(os.path.join(OUT,name),'w',encoding='utf-8').write(json.dumps(self.doc,separators=(',',':')))

def export(ai):
    asset=ASSETS[ai-1];aid='SA%02d'%ai;root=bpy.data.objects[asset['root']];inverse=root.matrix_world.inverted()
    writer=Writer();record={'id':aid,'name':asset['name'],'bodies':[],'mesh_count':0,'triangles':0}
    for body in [b for b in BODIES if b['asset_id']==aid]:
        chunks=collections.defaultdict(list);bounds=[];collision=[]
        for oname in body['parts']:
            ob=bpy.data.objects[oname]
            if ob.hide_render:continue
            ev=ob.evaluated_get(deps);me=ev.to_mesh(preserve_all_data_layers=True,depsgraph=deps)
            if not me or not len(me.vertices):ev.to_mesh_clear();continue
            me.calc_loop_triangles();tr=inverse@ob.matrix_world;nm=tr.to_3x3().inverted().transposed()
            local=[v.co.copy() for v in me.vertices];verts=[tr@v for v in local];bounds.extend(verts)
            lo=Vector([min(v[i] for v in local) for i in range(3)]);hi=Vector([max(v[i] for v in local) for i in range(3)]);span=Vector([max(.00001,hi[i]-lo[i]) for i in range(3)])
            vlo=Vector([min(v[i] for v in verts) for i in range(3)]);vhi=Vector([max(v[i] for v in verts) for i in range(3)])
            if any(t in oname for t in ['cabinet side','Cabinet back','horizontal panel','oak shelf','Tray unit','Tray divider','Pot base','Pot side','Tray bottom','Tray side','Tray rear','Tray front']):collision.append({'center':list((vlo+vhi)/2),'size':list(vhi-vlo)})
            normals=[tuple((nm@n.vector).normalized()) for n in me.corner_normals]
            for tri in me.loop_triangles:
                material=me.materials[tri.material_index].name
                items=chunks[material]
                if not items or len(items[-1])>=18000:items.append([])
                axis=max(range(3),key=lambda i:abs(tri.normal[i]));axes=[i for i in range(3) if i!=axis];corners=[]
                for vi,li in zip(tri.vertices,tri.loops):
                    if 'bird emblem' in material.lower():uv=tuple(me.uv_layers.active.data[li].uv)
                    else:uv=tuple(max(0,min(1,(local[vi][i]-lo[i])/span[i])) for i in axes)
                    corners.append((tuple(verts[vi]),normals[li],uv))
                items[-1].append(corners)
            ev.to_mesh_clear()
        assert bounds,body['id']
        low=Vector([min(v[i] for v in bounds) for i in range(3)]);high=Vector([max(v[i] for v in bounds) for i in range(3)])
        if body['label']=='Round graphite pencil pot':
            collision=[{'center':[0,0,.005],'size':[.13,.13,.01]}]+[{'center':[.065*math.cos(2*math.pi*i/12),.065*math.sin(2*math.pi*i/12),.06],'size':[.023,.023,.11]} for i in range(12)]
        if not collision:collision=[{'center':list((low+high)/2),'size':list(high-low)}]
        info={k:v for k,v in body.items() if k not in ['parts','root','asset_root']};info['collision']=collision;info['bounds']={'min':list(low),'max':list(high)};record['bodies'].append(info)
        count=0
        for material,cs in chunks.items():
            for tris in cs:
                count+=1;writer.mesh(body['id']+'_M%02d'%count,tris,material);record['triangles']+=len(tris);record['mesh_count']+=1
    for suffix,point in [('O',(0,0,0)),('X',(.1,0,0)),('Y',(0,.1,0))]:writer.marker(aid+'_REF_'+suffix,point)
    filename=aid+'_'+re.sub('[^A-Za-z0-9]+','_',asset['name']).strip('_')+'.gltf';writer.save(filename);record['file']=filename
    open(os.path.join(OUT,aid+'_metadata.json'),'w',encoding='utf-8').write(json.dumps(record,indent=2))
    print('EXPORTED',aid,asset['name'],record['mesh_count'],'meshes',record['triangles'],'triangles',flush=True)
    return record

ids=[int(v) for v in sys.argv[sys.argv.index('--')+1:]] if '--' in sys.argv else list(range(1,39))
for ai in ids:export(ai)
print('DONE',flush=True)
