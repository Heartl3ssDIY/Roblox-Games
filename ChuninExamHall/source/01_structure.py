exec(compile(open(r'C:\Users\sandt\Documents\Local Projects\Roblox UI Assets\Btns\ChuninExamHall\source\common.py',encoding='utf-8').read(),'common.py','exec'))
g='01_Foundation'
box('Hall_Foundation',(0,0,-1),(82,102,2),9,g,.12)
box('Dark_Grout_Bed',(0,-2,-.04),(64.4,92.4,.18),9,g)
for row in range(23):
 for col in range(16):
  x=-30+col*4;y=-46+row*4
  cat=0 if random.random()<.68 else 1 if random.random()<.55 else 15
  ob=box('Floor_Tile_%02d_%02d'%(row,col),(x,y,.09),(3.96,3.96,.22),cat,'02_Tiled_Floor',.025)
  ob['walkable']=True
for x in [-32,-16,0,16,32]:
 box('Floor_Major_Seam_X',(x,-2,.207),(.075,92,.012),9,'03_Floor_Weathering')
for y in range(-48,45,16):
 box('Floor_Major_Seam_Y',(0,y,.207),(64,.075,.012),9,'03_Floor_Weathering')
for i in range(40):
 x=random.uniform(-30,30);y=random.uniform(-45,21)
 if abs(x)<15 and abs(y+12)<18 and random.random()<.8:continue
 pts=[(x,y,.213)]
 for k in range(random.randint(2,4)):
  x+=random.uniform(-.7,.8);y+=random.uniform(.3,1.1);pts.append((x,y,.213))
 tube('Hairline_Stone_Crack',pts,.014,9,'03_Floor_Weathering',4)
box('Dais_Rear_Block',(0,37,.84),(64,22,1.3),1,'04_Judges_Dais',.06)
coords=[(-13,26),(13,26)]+[(13*cos(a),26+13*sin(a)) for a in [(-pi*j/32) for j in range(33)]]
verts=[(x,y,.2) for x,y in coords]+[(x,y,1.5) for x,y in coords]
n=len(coords)
mesh('Dais_Semicircle',verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],0,'04_Judges_Dais')
tube('Dais_Arc_Edge',[(13*cos(-pi*j/48),26+13*sin(-pi*j/48),1.48) for j in range(49)],.09,2,'04_Judges_Dais',6)
for x in range(-28,29,4):
 ymin=26-math.sqrt(max(0,169-x*x)) if abs(x)<13 else 26
 box('Dais_Tile_Seam',(x,(ymin+47)/2,1.506),(.045,47-ymin,.014),1,'04_Judges_Dais')
for y in range(14,48,4):
 width=2*math.sqrt(max(0,169-(y-26)**2)) if y<26 else 64
 if width>0:box('Dais_Horizontal_Seam',(0,y,1.51),(width,.045,.015),1,'04_Judges_Dais')
box('Sculpture_Base',(0,40,2.25),(59,11,1.5),3,'04_Judges_Dais',.25)
for side in [-1,1]:
 g='05_West_Gallery' if side<0 else '06_East_Gallery'
 box('Gallery_Support',(side*36,-1,6.8),(8,94,13.6),3,g,.1)
 box('Gallery_Walking_Surface',(side*36,-1,13.8),(8.2,94.2,.5),7,g,.08)
 box('Gallery_Front_Fascia',(side*31.85,-1,13.35),(.4,94.5,1.5),6,g,.08)
 for y in range(-44,46,8):
  box('Gallery_Wall_Panel',(side*31.91,y,6.5),(.22,7.7,11.2),3,g,.05)
  box('Gallery_Buttress',(side*32.15,y-4,6.5),(.55,.48,12.7),9,g,.04)
 for y in range(-47,47,3):
  beam('Rail_Baluster',(side*32.25,y,14.04),(side*32.25,y,17.1),.075,9,g,6)
 for z in [14.3,15.4,17.15]:
  beam('Gallery_Rail',(side*32.25,-47,z),(side*32.25,46,z),.13 if z==17.15 else .07,6 if z==17.15 else 9,g,8)
 for y in range(-44,47,12):
  box('Rail_Primary_Post',(side*32.25,y,15.7),(.32,.32,3.5),6,g,.06)
  ellipsoid('Post_Cap',(side*32.25,y,17.48),(.25,.25,.2),12,g,8,4)
 for i in range(14):
  top=(i+1)
  box('Access_Stair_%02d'%i,(side*26.5,-46+i*.85,top/2),(10,.87,top),7,g,.025)
 beam('Stair_Handrail',(side*21.5,-47,3),(side*21.5,-34,17),.13,6,g)
 for i in range(0,14,2):
  beam('Stair_Rail_Post',(side*21.5,-46+i*.85,i+1),(side*21.5,-46+i*.85,i+4),.07,9,g,6)
g='07_Tall_Walls'
box('Rear_Wall',(0,48.5,21),(81,1.5,44),3,g,.12)
for side in [-1,1]:
 box('Side_Wall',(side*40.5,-1,21),(1.4,99,44),3,g,.1)
 for y in range(-46,48,12):
  box('Tall_Wall_Pilaster',(side*39.65,y,25),(1,1,35),2,g,.08)
  box('Upper_Wall_Panel',(side*39.73,y+5.7,28),(.12,10.4,25),15,g,.03)
 box('Upper_Trim',(side*39.25,-1,42.4),(.5,98,1),6,g,.08)
 box('Front_Corner_Pillar',(side*39,-48,21),(3,3,44),2,g,.16)
box('Rear_Gallery_Band',(0,47.35,15.1),(80,.8,1.3),6,g,.06)
for x in [-36,-20,-4,12,28,36]:
 box('Rear_Pillar',(x,47.15,25),(1.5,1,38),2,g,.08)
for x in [-25,0,25]:
 box('Window_Recess',(x,47.15,29.5),(22,.3,24),9,'08_Rear_Windows')
 box('Blue_Window',(x,46.93,29.5),(20.5,.18,22.5),10,'08_Rear_Windows')
 for xx in [x-10.8,x,x+10.8]:
  box('Window_Mullion',(xx,46.65,29.5),(.65,.5,23.8),2,'08_Rear_Windows',.04)
 for zz in [18,28,41]:
  box('Window_Transom',(x,46.6,zz),(22,.55,.65),2,'08_Rear_Windows',.04)
 for k in range(9):
  xx=x-9+k*2.2
  box('Window_Reflection',(xx,46.805,random.uniform(26,35)),(.09,.025,random.uniform(5,11)),11,'08_Rear_Windows')
print("Hall shell, tiled floor, semicircle dais and raised galleries built.")
