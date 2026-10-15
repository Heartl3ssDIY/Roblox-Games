BASE=r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\SchoolAssetLibrary'
scene.name='School Asset Library | Detailed Review 02';scene['project']='School — name undecided';scene['stage']='Detailed review 02';scene['source_logo']='User revised bird emblem only'
LIB.name='School Assets | Detailed Review 02'
removed=[]
for ob in list(scene.objects):
 if ob.type=='FONT' and ('WREN' in ob.data.body.upper() or ob.name in ['TV subtitle']):removed.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True)
for record in ASSETS:
 ob=bpy.data.objects[record['root']];ob.name=ob.name.replace('Wren_','School_');record['root']=ob.name
 col=bpy.data.collections[record['collection']];col.name=col.name.replace('Wren | ','School | ');record['collection']=col.name
 record['name']=record['name'].replace('Wren ','');ob['asset_name']=record['name'];ob['revision']='Detailed Review 02'
 ob.asset_data.description=record['category']+' / Detailed editable school prop. Name undecided.'
 for tag in list(ob.asset_data.tags):ob.asset_data.tags.remove(tag)
 ob.asset_data.tags.new('School assets')
for m in MAT.values():m.name=m.name.replace('Wren | ','School | ')
for ob in scene.objects:
 if 'Wren' in ob.name:ob.name=ob.name.replace('Wren','Bird')
image.filepath=os.path.join(BASE,'textures','Bird-Logo.png');image.name='Bird-Logo.png';image.pack()
def linear(hexcode):
 h=hexcode.lstrip('#');rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
def rich_material(key,hexcode,kind='noise',rough=.6,metal=0):
 m=MAT[key];m.node_tree.nodes.clear();n=m.node_tree.nodes;L=m.node_tree.links
 p=n.new('ShaderNodeBsdfPrincipled');out=n.new('ShaderNodeOutputMaterial');L.new(p.outputs['BSDF'],out.inputs['Surface'])
 c=linear(hexcode);m.diffuse_color=(*c,1);p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 coords=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');L.new(coords.outputs['Generated'],mapping.inputs['Vector'])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=4;noise.inputs['Roughness'].default_value=.65;L.new(mapping.outputs['Vector'],noise.inputs['Vector'])
 variation=noise.outputs['Factor'];height=variation;strength=.12;dist=.0006
 if kind=='wood':
  mapping.inputs['Scale'].default_value=(1,24,7);noise.inputs['Scale'].default_value=3.8
  wave=n.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='Y';wave.inputs['Scale'].default_value=4;wave.inputs['Distortion'].default_value=7;wave.inputs['Detail'].default_value=5;wave.inputs['Detail Scale'].default_value=1.4;L.new(mapping.outputs['Vector'],wave.inputs['Vector'])
  mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs['Factor'].default_value=.38;L.new(variation,mix.inputs['Color1']);L.new(wave.outputs['Factor'],mix.inputs['Color2']);variation=mix.outputs['Color'];height=variation;strength=.22;dist=.0010
  p.inputs['Coat Weight'].default_value=.18;p.inputs['Coat Roughness'].default_value=.37
 elif kind=='fabric':
  mapping.inputs['Scale'].default_value=(1,1,1);noise.inputs['Scale'].default_value=110
  waves=[]
  for axis in ['X','Y']:
   wave=n.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction=axis;wave.inputs['Scale'].default_value=145;wave.inputs['Distortion'].default_value=.6;L.new(mapping.outputs['Vector'],wave.inputs['Vector']);waves.append(wave)
  mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';L.new(waves[0].outputs['Factor'],mul.inputs[0]);L.new(waves[1].outputs['Factor'],mul.inputs[1]);height=mul.outputs[0];strength=.32;dist=.0007
  p.inputs['Sheen Weight'].default_value=.22;p.inputs['Sheen Roughness'].default_value=.85
 elif kind=='bark':
  mapping.inputs['Scale'].default_value=(15,15,1);noise.inputs['Scale'].default_value=3.5;strength=.5;dist=.014
 elif kind=='leaf':
  noise.inputs['Scale'].default_value=8;strength=.20;dist=.003;p.inputs['Subsurface Weight'].default_value=.035
 elif kind=='metal':
  mapping.inputs['Scale'].default_value=(1,110,5);noise.inputs['Scale'].default_value=14;strength=.08;dist=.00008
 elif kind=='ceramic':
  noise.inputs['Scale'].default_value=220;strength=.09;dist=.00012;p.inputs['Coat Weight'].default_value=.24;p.inputs['Coat Roughness'].default_value=.2
 else:noise.inputs['Scale'].default_value=165
 mix=n.new('ShaderNodeMixRGB');mix.inputs['Color1'].default_value=(*(v*(.62 if kind=='wood' else .86) for v in c),1);mix.inputs['Color2'].default_value=(*(min(1,v*(1.17 if kind=='wood' else 1.07)) for v in c),1);L.new(variation,mix.inputs['Factor']);L.new(mix.outputs['Color'],p.inputs['Base Color'])
 r=n.new('ShaderNodeMapRange');r.inputs['From Min'].default_value=0;r.inputs['From Max'].default_value=1;r.inputs['To Min'].default_value=max(.06,rough-.065);r.inputs['To Max'].default_value=min(.99,rough+.07);L.new(noise.outputs['Factor'],r.inputs['Value']);L.new(r.outputs['Result'],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=strength;bump.inputs['Distance'].default_value=dist;L.new(height,bump.inputs['Height']);L.new(bump.outputs['Normal'],p.inputs['Normal'])
for values in [
 ('black','#24292F','noise',.48,0),('rubber','#121519','noise',.9,0),('sand','#B69B80','noise',.55,0),('ivory','#D1C3AB','ceramic',.46,0),('taupe','#8E7B6E','noise',.61,0),('clay','#AC7E6C','noise',.60,0),('fabric','#B7A087','fabric',.9,0),('fabricdark','#756357','fabric',.91,0),('wood','#705039','wood',.53,0),('woodlight','#B58A59','wood',.56,0),('pink','#CC788C','noise',.88,0),('metal','#A0AAB0','metal',.28,.82),('brass','#A98A48','metal',.31,.76),('white','#EAE8DF','ceramic',.25,0),('leaf','#31513A','leaf',.75,0),('leaflight','#5C7751','leaf',.72,0),('leafdark','#253F2A','leaf',.83,0),('bark','#664530','bark',.9,0),('soil','#33271E','noise',.98,0)]:rich_material(*values)
MAT['thread']=mat('Saddle stitching',linear('#776354'),.94)
MAT['seam']=mat('Dark upholstery seam',linear('#51483F'),.93)
MAT['ceramic']=mat('Glazed ivory ceramic',linear('#D6C7AF'),.24)
MAT['silver']=mat('Polished keywork',linear('#C5CDCF'),.19,.9)
MAT['endgrain']=mat('Endgrain oak',linear('#89653E'),.67,texture='wood')
for ob in scene.objects:
 if ob.type=='MESH':
  for mod in ob.modifiers:
   if mod.type=='BEVEL':mod.segments=6
  if any(mod.type=='BEVEL' for mod in ob.modifiers):
   mod=ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
scene.view_settings.exposure=-.65
print('Removed unconfirmed branding:',removed,'and upgraded physical materials')
