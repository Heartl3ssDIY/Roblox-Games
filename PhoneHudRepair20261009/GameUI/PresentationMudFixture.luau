local tests=0
local function check(ok,message)assert(ok,message)tests+=1 end
local root=Instance.new("Frame")
local meter=Instance.new("Frame");meter.Name="Meter";meter.Parent=root
local controls=root
local mobileSprint=Instance.new("TextButton");mobileSprint.Parent=root
local live=Instance.new("TextLabel");live.Name="LiveCaption";live.Parent=mobileSprint
local workspace={CurrentCamera={ViewportSize=Vector2.new(852,393)}}
local attrs={}
local player={GetAttribute=function(_,name)return attrs[name]end}
local position,size=controls.Position,controls.Size
local function refreshArtwork(button,value)
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if artwork and not artwork.IsLoaded then
  artwork.Visible=true
  if textless then textless.Visible=false end
  if live then live.Visible=false end
  return
 end
 local authored=button:GetAttribute("ArtworkText")
 local showLive=not artwork or authored==nil or value~=authored
 if artwork then artwork.Visible=not showLive end
 if textless then textless.Visible=showLive end
 if live then live.Visible=showLive end
end
local function caption(button,value)
 button.Text=value
 local live=button:FindFirstChild("LiveCaption")
 if live then live.Text=value end
 refreshArtwork(button,value)
end

for _,case in {
 {852,393,false,false,false,6.2,10,"SPRINT\n6.2/10s"},
 {1024,768,false,true,false,0,10,"RECHARGING\n0.0/10s"},
 {1920,1080,true,false,true,7.6,10,"SPRINTING\n7.6/10s"}
}do
 workspace.CurrentCamera.ViewportSize=Vector2.new(case[1],case[2])
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local short=math.min(viewport.X,viewport.Y)
 local compactHud=viewport.X<=900 or short<=600 or (short<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 controls.Meter.Visible=not compactHud

 check(controls.Meter.Visible==case[3],"Mud meter profile visibility")
 attrs.MDSprintExhausted=case[4]
 local sprinting,stamina,maximum=case[5],case[6],case[7]
 caption(mobileSprint,(player:GetAttribute("MDSprintExhausted") and "RECHARGING" or sprinting and "SPRINTING" or "SPRINT")..string.format("\n%.1f/%gs",stamina,maximum))
 check(mobileSprint.Text==case[8],"Mud mobile stamina text")
 check(live.Text==case[8] and live.Visible,"Mud reusable live text")
 check(controls.Position==position and controls.Size==size,"Mud authored geometry retained")
end
root:Destroy()
return {passed=tests,mudCases=3}

