for side,y,xs in [('Dispatch',-45,[-39,-13,13,39]),('Receiving',45,[-18,18])]:
    direction=-1 if y<0 else 1
    for j,x in enumerate(xs):
        prefix=side+'_%02d'%(j+1)
        box(prefix+'_Header',(x,y,13.15),(14,1,4.3),'Wall','Docks','Wall')
        for dx in (-7.05,7.05):
            box(prefix+'_Jamb',(x+dx,y+direction*.8,5.4),(.5,1.2,10.8),'Pillar','Docks','Pillar')
            box(prefix+'_Seal',(x+dx*.94,y+direction*.7,5.0),(.3,.4,10),'Rubber','Docks')
        box(prefix+'_RollerCase',(x,y+direction*.7,11.25),(14.2,1.5,1.4),'Metal','Docks')
        slats=[((x,y+direction*.84,10.5+i*.16),(13.4,.45,.12)) for i in range(5)]
        boxes(prefix+'_Shutter',slats,'Roof','Docks','Roof',.015)
        box(prefix+'_Canopy',(x,y+direction*2.4,15.0),(16,5.8,.35),'Pillar','Docks','Pillar')
        box(prefix+'_CanopyEdge',(x,y+direction*5.15,15.0),(16,.25,.5),'Trim','Docks','Trim')
        box(prefix+'_SignBoard',(x,y+direction*1.05,13.15),(13, .25,2.05),'Screen','Docks')
        rot=(math.pi/2,0,0) if y<0 else (math.pi/2,0,math.pi)
        ob=text(prefix+'_BayLabel',('LOAD ' if y<0 else 'RECEIVE ')+str(j+1).zfill(2),(x,y+direction*1.22,12.7),.85,'White','Docks',rot)
        ob['PreviewLabel']=True
        if y>0: ob.location.x+=ob.dimensions.x
        for dx in (-7.8,7.8):
            cylinder(prefix+'_Bollard',(x+dx,y+direction*2.2,1.45),.3,2.9,'Trim','Docks','Trim',sides=12)
            cylinder(prefix+'_BollardStripe',(x+dx,y+direction*2.2,2.0),.315,.35,'Rubber','Docks',sides=12)
        box(prefix+'_StatusLight',(x+8.0,y+direction*.75,8.8),(.4,.35,.85),'Neon','Docks','Neon')
        yy=-32 if y<0 else 32
        dd=12 if y<0 else 10
        for dx in (-7.25,7.25):
            box(prefix+'_BayLine',(x+dx,yy,.055),(.28,dd,.07),'Trim','Yard','Trim',.01)
        for dy in (-dd/2,dd/2):
            box(prefix+'_BayEnd',(x,yy+dy,.055),(14.8,.28,.07),'Trim','Yard','Trim',.01)
        box(prefix+'_Threshold',(x,y,.07),(13.5,1.3,.12),'Metal','Docks',bevel=.02)

box('DispatchApron',(0,-110,-.6),(120,130,1),'Asphalt','Yard',bevel=.15)
box('ReceivingApron',(0,110,-.6),(60,130,1),'Asphalt','Yard',bevel=.15)
for side,sgn,xs in [('Dispatch',-1,[-39,-13,13,39]),('Receiving',1,[-18,18])]:
    for x in xs:
        for dx in (-8,8):
            box(side+'_Guide',(x+dx,sgn*92,-.045),(.18,86,.06),'White','Yard',bevel=.008)
        for y in (70,105,140):
            yy=sgn*y
            box(side+'_LaneDash',(x,yy,-.03),(.3,4,.075),'Trim','Yard','Trim',.01)
        box(side+'_StopBar',(x,sgn*53,-.03),(15,.4,.075),'Trim','Yard','Trim',.01)
for y in (-49,49):
    for x in range(-48,49,8):
        box('WalkwayTile',(x,y,-.02),(3,2.5,.06),'White','Yard',bevel=.01)
for x in (-21,21):
    box('StagingBoundary',(x,6,.05),(.25,32,.05),'Neon','Yard','Neon',.01)
for y in (-10,22):
    box('StagingEnd',(0,y,.05),(42,.25,.05),'Neon','Yard','Neon',.01)

box('OfficeFoundation',(76,-16,-.8),(43,38,1.3),'Concrete','Office',bevel=.15)
box('OfficeFloor',(75.5,-16,-.08),(40,35.5,.15),'Concrete','Office',bevel=.025)
box('OfficeFrontWall',(75.5,-34,6),(42,1,12),'OfficeWall','Office','OfficeWall')
box('OfficeRearWall',(75.5,2,6),(42,1,12),'OfficeWall','Office','OfficeWall')
box('OfficeEastSill',(96,-16,1.8),(1,36,3.6),'OfficeWall','Office','OfficeWall')
box('OfficeEastHeader',(96,-16,10.8),(1,36,2.4),'OfficeWall','Office','OfficeWall')
for y in (-31,-25,-19,-13,-7,-1):
    box('OfficeEastGlass',(96,y,6.5),(.2,5.6,5.7),'Glass','Office',bevel=.035)
for y in (-34,-28,-22,-16,-10,-4,2):
    box('OfficeEastMullion',(96.25,y,6.5),(.6,.24,6.2),'Pillar','Office','Pillar',.035)
for y in (-34,2):
    for x in (56.3,65,75,85,95):
        box('OfficeCladdingFin',(x,y+(-.58 if y<0 else .58),6),(.22,.25,11.6),'OfficeWall','Office','OfficeWall',.025)
box('OfficeCornice',(76,-16,12.25),(43,38,.65),'Pillar','Roof','Pillar')
for i in range(3):
    box('OfficeRoof_%02d'%i,(76,-28+i*12,12.65),(44,11.95,.5),'Roof','Roof','Roof')
box('OfficeFrontAccent',(76,-35,11.65),(42,.2,.32),'Neon','Lighting','Neon',.025)
box('OfficeEastAccent',(97,-16,11.65),(.2,36,.32),'Neon','Lighting','Neon',.025)
for y in (-20,-12):
    box('OfficeDoorJamb',(54.35,y,5.5),(.3,.4,11),'Pillar','Office','Pillar')
box('OfficeDoorLintel',(54.35,-16,11),(.3,8.4,.4),'Trim','Office','Trim')
door=box('OfficeGlassDoor',(55,-16,5.4),(.14,7.35,10.3),'Glass','Office',bevel=.035)
door['CanCollide']=False
box('OfficeDoorKickPlate',(54.84,-16,.75),(.14,7.35,1.1),'Metal','Office')
beam('OfficeDoorHandle',(54.6,-13.25,4.4),(54.6,-13.25,6.3),.15,.15,'Trim','Office','Trim')
box('OfficeDoorSign',(54.35,-16,12.5),(.2,8.8,1.65),'Pillar','Office','Pillar')
office_text=text('OfficeDoorText','OFFICE',(54.18,-16,12.1),.85,'White','Office',(math.pi/2,0,-math.pi/2))
office_text.location.x=54.18
office_text.location.y=-16+office_text.dimensions.y/2
for x in (65,87):
    for y in (-5,-24):
        box('OfficeLightHousing',(x,y,11.7),(7.2,2.4,.3),'Pillar','Lighting','Pillar')
        box('OfficeLightDiffuser',(x,y,11.5),(6.8,2,.1),'Warm','Lighting',bevel=.02)

for y in (-27,27):
    box('RoofVentBase',(0,y,23.3),(10,9,.5),'Pillar','Roof','Pillar')
    box('RoofVentBody',(0,y,24),(8.4,7.4,1.2),'Roof','Roof','Roof')
    box('RoofVentCap',(0,y,24.8),(10,9,.45),'Trim','Roof','Trim')
    for dx in (-4.25,4.25):
        boxes('RoofVentLouvers',[((dx,y,23.6+i*.26),(.15,6.8,.12)) for i in range(4)],'Rubber','Roof',bevel=.01)

box('WarehouseNameFrame',(0,46.1,18.0),(45.5,.55,7.8),'Trim','Docks','Trim')
box('WarehouseNameFace',(0,46.45,18.0),(44.4,.25,6.8),'Screen','Docks')
name=text('WarehouseNamePreview','YOUR WAREHOUSE',(0,46.6,18),2.0,'White','Presentation',(math.pi/2,0,math.pi))
name.location.x=name.dimensions.x/2
tag=text('WarehouseNameSubline','RECEIVING  /  LOGISTICS',(0,46.62,16),.8,'White','Presentation',(math.pi/2,0,math.pi))
tag.location.x=tag.dimensions.x/2
print('Exterior details complete:',len(scene.objects),'objects')
