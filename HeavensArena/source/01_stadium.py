exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\HeavensArena\source\common.py',encoding='utf-8').read(),'common.py','exec'))
MAT,GLOW=atlas();sc=bpy.context.scene
base=Builder();floor=Builder();aisle=Builder();trim=Builder()
# Full octagonal foundation and broad circulation bands.
for i in range(8):
 a=i*pi/4
 base.sector(a,.001,130,-3,-.4,4)
 floor.sector(a,.001,66,-.35,0,0)
 floor.sector(a,.001,49,0,.025,14)
 aisle.sector(a,66,79,-.35,0,6)
 trim.sector(a,65.8,66.3,0,.07,7)
 trim.sector(a,48.7,49.1,.026,.055,11)
 # Fine lines in blue apron.
 for r in [55,61]:trim.sector(a,r,r+.06,.01,.02,15)
base.build('HA_Octagonal_Foundation','01_Foundation')
floor.build('HA_Blue_Arena_Floor','02_Arena_Floor')
aisle.build('HA_Warm_Concourse','03_Concourse')
trim.build('HA_Floor_Edges','04_Trim')
singlebox('HA_Platform_Base',(0,0,.66),(65.4,65.4,1.25),5,'05_Combat_Platform')
singlebox('HA_Platform_Rim',(0,0,1.34),(65,65,.16),12,'05_Combat_Platform')
singlebox('HA_Tile_Grout',(0,0,1.54),(64.25,64.25,.3),9,'05_Combat_Platform')
tiles=Builder()
for x in range(16):
 for y in range(16):
  tiles.box((-30+4*x,-30+4*y,1.69),(3.945,3.945,.2),1 if (x+y)%5 else 14)
tiles.build('HA_Unmarked_64x64_Tiled_Platform','05_Combat_Platform')
edge=Builder()
for s in [-1,1]:
 edge.box((s*32.25,0,1.75),(.25,64.5,.15),7);edge.box((0,s*32.25,1.75),(64.5,.25,.15),7)
 for j in range(3):edge.box((0,s*(33.2+j*.8),1.48-j*.42),(9,.8,.5),1)
edge.build('HA_Platform_Edges_and_Steps','05_Combat_Platform')
# Stadium bowl: eight sides, two seating decks, central stair aisles.
for i in range(8):
 a=i*pi/4;structure=Builder();rails=Builder();stairs=Builder();walls=Builder()
 # Low spectator wall, interrupted by an access opening.
 half=79*tan(pi/8)
 for sg in [-1,1]:
  walls.radialbox(a,sg*(half+4.2)/2,78.8,1.6,half-4.2,1.4,3.2,2)
  walls.radialbox(a,sg*(half+4.2)/2,78.8,3.3,half-4.2,1.65,.22,7)
 # Tiers have no geometry in the central stair lane.
 for tier,count,rstart,zstart in [(0,8,80,3.4),(1,10,103,18.1)]:
  seats=Builder()
  for row in range(count):
   r=rstart+row*2.35;z=zstart+row*1.4;hw=r*tan(pi/8)-.9
   for sg in [-1,1]:
    u=sg*(hw+4)/2
    structure.radialbox(a,u,r+1.08,z-.55,hw-4,2.35,1.1,11)
    structure.radialbox(a,u,r-.055,z-.09,hw-4,.16,.18,7)
   for step in range(2):
    stairs.radialbox(a,0,r+.59+step*1.175,z-.35+step*.7,7.6,1.175,.7,11)
    stairs.radialbox(a,0,r+.045+step*1.175,z+.015+step*.7,7.6,.09,.025,6)
   # Seats face inward, away from the outside rim.
   for sg in [-1,1]:
    n=int((hw-5)/2.3)
    for j in range(n):
     u=sg*(5.3+j*2.3)
     seats.radialbox(a,u,r+.85,z+.55,1.76,1.32,.24,3 if (row+j)%5 else 2)
     seats.radialbox(a,u,r+1.38,z+1.19,1.76,.22,1.1,3 if (row+j)%5 else 2)
     seats.radialbox(a,u,r+.98,z+.21,.9,.72,.46,9)
  seats.build('HA_Seats_Section%02d_Deck%d'%(i+1,tier+1),'20_Seats')
 # Wide mid-deck walkway and rail overlooking the lower deck.
 structure.sector(a,98.8,103,14.5,15.8,11)
 for sg in [-1,1]:
  hw=99*tan(pi/8)-1
  rails.beam(point(a,sg*4.4,99,18.1),point(a,sg*hw,99,18.1),.13,5)
  rails.beam(point(a,sg*4.4,99,16.8),point(a,sg*hw,99,16.8),.08,5)
  for u in np.arange(5,hw,5):rails.beam(point(a,sg*u,99,15.8),point(a,sg*u,99,18.1),.11,5)
 # Handrails beside each central stair aisle.
 for sg in [-1,1]:
  for r0,r1,z0,z1 in [(80,98.7,5.5,16.7),(103,126,20.2,33.9)]:
   rails.beam(point(a,sg*3.7,r0,z0),point(a,sg*3.7,r1,z1),.13,5)
   for t in np.linspace(0,1,7):
    r=r0+(r1-r0)*t;z=z0+(z1-z0)*t
    rails.beam(point(a,sg*3.7,r,z-2),point(a,sg*3.7,r,z),.1,5)
 # Rear concourse, wall and upper gallery panels.
 structure.sector(a,126.5,130,31,32.2,11)
 walls.radialbox(a,0,130,37.4,2*130*tan(pi/8),1.5,10.4,4)
 # luminous-looking pale portal and structural framing.
 walls.radialbox(a,0,129.1,35.25,7.6,.3,6.1,10)
 walls.radialbox(a,0,128.82,35.2,5.8,.05,5.4,15)
 for u in [-4.3,4.3]:walls.radialbox(a,u,128.7,35.4,.65,1,6.5,7)
 walls.radialbox(a,0,128.7,38.8,9.25,1,.55,7)
 # Repeated upper facade bays.
 for u in [-43,-29,-15,15,29,43]:
  walls.radialbox(a,u,129,38.4,11,.35,6.1,5)
  walls.radialbox(a,u,128.75,39.1,9.4,.12,3.6,9)
  walls.radialbox(a,u,128.58,37.1,10.5,.5,.3,7)
 # Outer corner piers.
 for sg in [-1,1]:
  walls.radialbox(a,sg*(130*tan(pi/8)-.6),129.5,22,1.4,2.3,44,4)
 structure.build('HA_Terraces_Section%02d'%(i+1),'10_Terraces')
 stairs.build('HA_Stair_Aisle%02d'%(i+1),'11_Stairs')
 rails.build('HA_Railings_Section%02d'%(i+1),'12_Railings')
 walls.build('HA_Walls_Section%02d'%(i+1),'13_Walls')
 # Upper roof rim and lighting fascia; open centre allows overhead viewing.
 roof=Builder();bulbs=Builder()
 roof.sector(a,123.5,133,43.4,45.2,4);roof.sector(a,123.2,123.6,42.9,44.8,7)
 roof.sector(a,128.5,133,45.2,45.6,5)
 for u in np.arange(-46,47,5.1):
  roof.radialbox(a,u,122.8,43.85,3.6,.8,1.4,13)
  bulbs.radialbox(a,u,122.35,43.85,2.8,.16,.85,8)
 roof.build('HA_Roof_Rim%02d'%(i+1),'14_Roof_Rim')
 bulbs.build('HA_Floodlights%02d'%(i+1),'15_Lamps',GLOW)
# Arena markers are kept as editable Blender empties.
for name,loc in [('HA_Arena_Center',(0,0,1.8)),('HA_Team_A_Spawn',(0,-22,1.8)),('HA_Team_B_Spawn',(0,22,1.8)),('HA_Board_Min',(-32,-32,1.8)),('HA_Board_Max',(32,32,1.8))]:
 o=bpy.data.objects.new(name,None);collection('80_Gameplay_Markers').objects.link(o);o.location=loc;o.empty_display_size=1
sc['Design']='Heavens Arena stadium, single unmarked fighting platform'
sc['Combat_Size']='64 x 64 Blender units'
sc['Reference']='User images 1 and 2; square tile platform from image 3'
print('Built stadium geometry',len(sc.objects))
