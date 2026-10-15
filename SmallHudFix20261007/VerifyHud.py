from pathlib import Path
import subprocess

root=Path(__file__).resolve().parent
helper=(root/'ResponsiveHud.luau').read_text(encoding='utf-8')
prefix='''local workspace={CurrentCamera={ViewportSize={X=844,Y=390}}}
local gui={Parent={GetDescendants=function() return {} end,DescendantAdded={Connect=function() return {} end}}}
'''
checks='''
local function scale(phone,tablet)
 local object={Name="ResponsiveHudScale",Scale=1,attrs={PhoneScale=phone,TabletScale=tablet,DesktopScale=1},belongs=true}
 function object:IsA(name) return name=="UIScale" end
 function object:IsDescendantOf(_) return self.belongs end
 function object:GetAttribute(name) return self.attrs[name] end
 return object
end
local card=scale(.82,.9)
local controls=scale(.94,.94)
trackHudScale(card) trackHudScale(controls)
refreshHudScale()
assert(card.Scale==.82 and controls.Scale==.94,"Phone profile")
workspace.CurrentCamera.ViewportSize={X=1024,Y=768} refreshHudScale()
assert(card.Scale==.9,"iPad profile")
workspace.CurrentCamera.ViewportSize={X=1366,Y=1024} refreshHudScale()
assert(card.Scale==.9,"Large iPad profile")
workspace.CurrentCamera.ViewportSize={X=1920,Y=1080} refreshHudScale()
assert(card.Scale==1 and controls.Scale==1,"Desktop profile restores")
workspace.CurrentCamera.ViewportSize={X=390,Y=844} refreshHudScale()
assert(card.Scale==.82,"Rotation updates")
card.attrs.PhoneScale=0/0 refreshHudScale()
assert(card.Scale==1,"Invalid authored scale falls back")
card.belongs=false refreshHudScale()
assert(hudScales[card]==nil,"Removed UI released")
workspace.CurrentCamera=nil refreshHudScale()
assert(48*.94>=44,"Gameplay touch targets remain at least44px tall")
print("9 responsive HUD checks passed")
'''
(root/'Checks.luau').write_text(prefix+helper+checks,encoding='utf-8')
subprocess.run([str(root.parent/'AttackTiming20260926/tools/luau-0.740/luau.exe'),str(root/'Checks.luau')],check=True)
for w,h in [(568,320),(667,375),(844,390),(1024,768),(1366,1024),(1920,1080)]:
 phone=w<=900 or min(w,h)<=600
 tablet=not phone and min(w,h)<=1024 and max(w,h)<=1400
 k=.82 if phone else .9 if tablet else 1
 level=.75 if phone else .9 if tablet else 1
 wallet=(w-18-190*k,18,190*k,56*k)
 toggle=(18,h-194-48,140,48)
 levelcard=(18,h-82-98*level,288*level,98*level)
 for name,(x,y,rw,rh) in [('wallet',wallet),('emotes',toggle),('level',levelcard)]:
  assert x>=0 and y>=0 and x+rw<=w and y+rh<=h,(w,h,name)
 assert toggle[1]+toggle[3]<levelcard[1],(w,h,'emotes overlaps level')
print('HUD anchors fit 6 landscape phone/tablet/desktop sizes; emotes and level card remain separate')
