import bpy,numpy as np,os,glob
base=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for path in glob.glob(os.path.join(base,'RobloxImport','textures','*_MetalRough.png')):
    im=bpy.data.images.load(path,check_existing=False);im.colorspace_settings.name='Non-Color'
    arr=np.empty(im.size[0]*im.size[1]*4,dtype=np.float32);im.pixels.foreach_get(arr);arr=arr.reshape((-1,4));metal=arr[:,2].copy();arr[:,:3]=metal[:,None];arr[:,3]=1
    out=bpy.data.images.new('Separate metalness',width=im.size[0],height=im.size[1],alpha=False);out.colorspace_settings.name='Non-Color';out.pixels.foreach_set(arr.ravel());out.filepath_raw=path.replace('_MetalRough','_Metalness');out.file_format='PNG';out.save()
    bpy.data.images.remove(out);bpy.data.images.remove(im)
print('Separate metalness maps saved for optional SurfaceAppearance assignment')
