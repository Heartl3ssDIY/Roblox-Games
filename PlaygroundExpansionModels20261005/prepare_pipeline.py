from pathlib import Path
root=Path(__file__).resolve().parent/'Blender'
path=root/'Source/build_pack.py'
s=path.read_text(encoding='utf-8-sig')
s=s.replace("REF=ROOT.parent/'PlaygroundClassics-ItemPetReferences-20261004'/'PlaygroundClassics-ItemPetReferences-20261004'", "REF=Path('C:/Users/sandt/Documents/Local Projects/Roblox UI Assets/PlayGround Classics/PlaygroundClassics-ExpansionReferences-20261005/PlaygroundClassics-ExpansionReferences-20261005')")
s=s.replace("from assetlib import *", "from assetlib import *\nfrom rigging import rig_asset")
s=s.replace("pieces.append((obj.name,vertices,faces,face_colors,smooth))", "pieces.append((obj.name,vertices,faces,face_colors,smooth,obj.get('RigBone','Body')))")
s=s.replace("vs=[];fs=[];cs=[];ss=[]", "vs=[];fs=[];cs=[];ss=[];weights=[]")
s=s.replace("for name,v,f,c,s in group:","for name,v,f,c,s,bone in group:")
s=s.replace("offset=len(vs);vs.extend(v);fs.extend", "offset=len(vs);weights.append((bone,list(range(offset,offset+len(v)))));vs.extend(v);fs.extend")
s=s.replace("obj['AssetId']=a.spec['id'];obj['IsRobloxExport']=True", "obj['AssetId']=a.spec['id'];obj['IsRobloxExport']=True\n        if getattr(a,'rig',None):\n            for bone,indices in weights:\n                vg=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)\n                vg.add(indices,1.0,'REPLACE')\n            mod=obj.modifiers.new('Pet deformation',checked_enum(bpy.types.Modifier,'type','ARMATURE'));mod.object=a.rig")
s=s.replace("    if spec['category']=='Pets':\n        from refine_pets import build_overrides\n        build_overrides(a,spec['id'])", "    if spec['category']=='Pets': rig_asset(a)")
s=s.replace("for obj in exports+a.anchors:obj.select_set(True)", "for obj in exports+a.anchors+([a.rig] if getattr(a,'rig',None) else []):obj.select_set(True)")
s=s.replace("object_types={'MESH','EMPTY'},use_mesh_modifiers=True,bake_anim=False", "object_types={'MESH','EMPTY','ARMATURE'},use_mesh_modifiers=True,bake_anim=bool(getattr(a,'rig',None)),bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False")
s=s.replace("'rigged':False", "'rigged':bool(getattr(a,'rig',None)),'rigBones':list(a.rig.data.bones.keys()) if getattr(a,'rig',None) else [],'collision':'Visual meshes non-colliding; use simple game-owned collision proxy','outline':'Navy geometry seams; Roblox Highlight with FillTransparency=1 and Occluded depth for silhouette'")
start=s.index("    catalog.append({'id':'C01'")
end=s.index('\n',start)
s=s[:start]+s[end:]
s=s.replace("    scene.view_settings.view_transform='Standard'", "    scene.view_settings.view_transform=checked_enum(scene.view_settings,'view_transform','Standard')")
s=s.replace("resolution_x=640;scene.render.resolution_y=640", "resolution_x=640;scene.render.resolution_y=640")
path.write_text(s,encoding='utf-8')
print('Expansion pipeline prepared')
