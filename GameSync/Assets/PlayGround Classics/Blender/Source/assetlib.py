import bpy
import bmesh
import math
import json
from math import sin, cos, pi, sqrt
from mathutils import Vector, Matrix

PALETTE = {
    'navy':'17213C','cream':'FFF0CF','wood':'CD8B3A','tan':'C8965B',
    'brown':'784326','blue':'176BE4','cyan':'24C8F3','teal':'11999F',
    'mint':'91E2B5','green':'3AA642','lime':'A1DB26','pink':'F2A4C6',
    'magenta':'F0379A','purple':'7841BE','lavender':'B198E5','red':'E93643',
    'orange':'F88623','yellow':'FFE449','gold':'EBB435','silver':'B9C9DC',
    'white':'FFFDF5','black':'111526','coral':'FF827D','ice':'BCEEFF',
}

def rgba(color):
    if isinstance(color, str):
        value=PALETTE.get(color,color).lstrip('#')
        return tuple(int(value[i:i+2],16)/255 for i in (0,2,4))+(1.0,)
    return tuple(color[:3])+(color[3] if len(color)>3 else 1.0,)

def linear(value):
    return value/12.92 if value<=0.04045 else ((value+0.055)/1.055)**2.4

def material(color):
    c=rgba(color)
    key='PC_' + ''.join(f'{round(v*255):02X}' for v in c[:3])
    mat=bpy.data.materials.get(key)
    if mat: return mat
    mat=bpy.data.materials.new(key)
    mat.use_nodes=True
    mat.diffuse_color=tuple(linear(v) for v in c[:3])+(1,)
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=mat.diffuse_color
    node.inputs['Roughness'].default_value=.4
    node.inputs['Metallic'].default_value=0
    if 'Coat Weight' in node.inputs: node.inputs['Coat Weight'].default_value=.08
    if 'Coat Roughness' in node.inputs: node.inputs['Coat Roughness'].default_value=.3
    mat['palette_srgb']=list(c)
    return mat

def checked_enum(owner, prop, value):
    properties=owner.properties if hasattr(owner,'properties') and prop in owner.properties else owner.bl_rna.properties
    items=[i.identifier for i in properties[prop].enum_items]
    if value not in items: raise ValueError(f'{prop}: {value} not in {items}')
    return value

class Asset:
    def __init__(self,spec):
        self.spec=spec
        self.collection=bpy.data.collections.new(spec['id']+'_'+spec['name'].replace(' ','_'))
        bpy.context.scene.collection.children.link(self.collection)
        self.root=bpy.data.objects.new(spec['slug'],None)
        self.collection.objects.link(self.root)
        self.root.empty_display_type=checked_enum(self.root,'empty_display_type','PLAIN_AXES')
        self.root.empty_display_size=.25
        self.objects=[]
        self.anchors=[]
        for k in ['id','name','category','tier','brief','reference']:
            self.root[k]=spec.get(k,'')
        self.root['ModelingUnits']='1 authored unit = 1 intended Roblox stud'
        self.root['Front']='-Y (Blender)'
        self.root['Gameplay']='Unassigned; model asset only'

    def mesh(self,name,vertices,faces,color,smooth=False):
        mesh=bpy.data.meshes.new(self.spec['id']+'_'+name)
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        bm=bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh); bm.free()
        for p in mesh.polygons: p.use_smooth=smooth
        obj=bpy.data.objects.new(self.spec['id']+'_'+name,mesh)
        self.collection.objects.link(obj)
        obj.parent=self.root
        obj.data.materials.append(material(color))
        obj['Part']=name
        obj['AssetId']=self.spec['id']
        self.objects.append(obj)
        return obj

    def bevel(self,obj,width,segments=2):
        if width<=0: return obj
        modifier=obj.modifiers.new('Rounded toy edges',checked_enum(bpy.types.Modifier,'type','BEVEL'))
        modifier.width=width
        modifier.segments=segments
        modifier.harden_normals=True
        return obj

    def sphere(self,name,loc,scale,color,segments=24,rings=16,smooth=True):
        verts=[(0,0,-1)]
        for j in range(1,rings):
            a=-pi/2+pi*j/rings
            for i in range(segments):
                t=2*pi*i/segments
                verts.append((cos(a)*cos(t),cos(a)*sin(t),sin(a)))
        verts.append((0,0,1)); top=len(verts)-1
        faces=[]
        for i in range(segments): faces.append((0,1+(i+1)%segments,1+i))
        for j in range(rings-2):
            for i in range(segments):
                a=1+j*segments+i; b=1+j*segments+(i+1)%segments
                faces.append((a,b,b+segments,a+segments))
        for i in range(segments):
            a=1+(rings-2)*segments+i; b=1+(rings-2)*segments+(i+1)%segments
            faces.append((a,b,top))
        verts=[(v[0]*scale[0],v[1]*scale[1],v[2]*scale[2]) for v in verts]
        obj=self.mesh(name,verts,faces,color,smooth)
        obj.location=loc
        return obj

    def box(self,name,loc,size,color,bevel=.08,rotation=None):
        x,y,z=[v/2 for v in size]
        v=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        f=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        obj=self.mesh(name,v,f,color)
        obj.location=loc
        if rotation is not None: obj.rotation_euler=rotation
        return self.bevel(obj,min(bevel,min(size)*.45))

    def lathe(self,name,profile,color,loc=(0,0,0),segments=32):
        verts=[]; rows=[]
        for radius,z in profile:
            if abs(radius)<1e-8:
                rows.append([len(verts)]); verts.append((0,0,z))
            else:
                rows.append(list(range(len(verts),len(verts)+segments)))
                verts.extend((radius*cos(2*pi*i/segments),radius*sin(2*pi*i/segments),z) for i in range(segments))
        faces=[]
        if len(rows[0])>1: faces.append(tuple(reversed(rows[0])))
        for a,b in zip(rows,rows[1:]):
            for i in range(segments):
                n=(i+1)%segments
                if len(a)==1 and len(b)>1: faces.append((a[0],b[n],b[i]))
                elif len(b)==1 and len(a)>1: faces.append((a[i],a[n],b[0]))
                elif len(a)>1 and len(b)>1: faces.append((a[i],a[n],b[n],b[i]))
        if len(rows[-1])>1: faces.append(tuple(rows[-1]))
        obj=self.mesh(name,verts,faces,color,True)
        for p in obj.data.polygons:
            if len(p.vertices)>4: p.use_smooth=False
        obj.location=loc
        return obj

    def cone(self,name,loc,r1,r2,depth,color,vertices=24,rotation=None):
        obj=self.lathe(name,[(r1,-depth/2),(r2,depth/2)],color,loc,vertices)
        if rotation is not None: obj.rotation_euler=rotation
        return obj

    def torus(self,name,loc,major,minor,color,rotation=None,segments=32,sides=8):
        verts=[]; faces=[]
        for i in range(segments):
            a=2*pi*i/segments
            for j in range(sides):
                b=2*pi*j/sides
                verts.append(((major+minor*cos(b))*cos(a),(major+minor*cos(b))*sin(a),minor*sin(b)))
        for i in range(segments):
            for j in range(sides):
                faces.append((i*sides+j,((i+1)%segments)*sides+j,((i+1)%segments)*sides+(j+1)%sides,i*sides+(j+1)%sides))
        obj=self.mesh(name,verts,faces,color,True); obj.location=loc
        if rotation is not None: obj.rotation_euler=rotation
        return obj

    def tube(self,name,points,radius,color,sides=8):
        points=[Vector(p) for p in points]
        verts=[]; faces=[]; prior=None
        for i,p in enumerate(points):
            tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            if prior is None:
                reference=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
                u=tangent.cross(reference).normalized()
            else:
                u=prior-tangent*prior.dot(tangent)
                if u.length<1e-7:
                    reference=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
                    u=tangent.cross(reference)
                u.normalize()
            prior=u; v=tangent.cross(u).normalized()
            rad=radius[i] if isinstance(radius,(tuple,list)) else radius
            for j in range(sides):
                t=2*pi*j/sides
                verts.append(tuple(p+rad*(u*cos(t)+v*sin(t))))
        for i in range(len(points)-1):
            for j in range(sides):
                faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
        faces.append(tuple(reversed(range(sides))))
        faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
        return self.mesh(name,verts,faces,color,True)

    def prism(self,name,points,depth,color,y=0,bevel=.03):
        n=len(points)
        verts=[(x,y-depth/2,z) for x,z in points]+[(x,y+depth/2,z) for x,z in points]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        return self.bevel(self.mesh(name,verts,faces,color),min(bevel,depth*.3))

    def anchor(self,name,loc):
        obj=bpy.data.objects.new(name,None)
        self.collection.objects.link(obj); obj.parent=self.root; obj.location=loc
        obj.empty_display_type=checked_enum(obj,'empty_display_type','PLAIN_AXES')
        obj.empty_display_size=.12
        obj['Attachment']=True
        self.anchors.append(obj)
        return obj
