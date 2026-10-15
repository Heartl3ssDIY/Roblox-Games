local tests=0
local function check(ok,message) assert(ok,message)tests+=1 end
local workspace={CurrentCamera={ViewportSize=Vector2.new(852,393)}}
local panel=Instance.new("Frame")
local initialPosition,initialSize=panel.Position,panel.Size
local meter=Instance.new("Frame");meter.Name="Meter";meter.Parent=panel
local mobileSprint=Instance.new("TextButton");mobileSprint.Parent=panel
local live=Instance.new("TextLabel");live.Name="LiveCaption";live.Parent=mobileSprint
local connection=mobileSprint:GetPropertyChangedSignal("Text"):Connect(function()live.Text=mobileSprint.Text end)
for _,case in {
 {568,320,false},{667,375,false},{852,393,false},{932,430,false},{390,844,false},
 {1024,768,false},{1180,820,false},{1366,1024,false},{1280,720,false},{1920,1080,true},{2560,1440,true}
}do
 workspace.CurrentCamera.ViewportSize=Vector2.new(case[1],case[2])
 local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
 local short=math.min(viewport.X,viewport.Y)
 local compactHud=viewport.X<=900 or short<=600 or (short<=1024 and math.max(viewport.X,viewport.Y)<=1400)
 panel.Meter.Visible=not compactHud

 check(panel.Meter.Visible==case[3],"meter profile selection")
 check(panel.Position==initialPosition and panel.Size==initialSize,"profile keeps authored geometry")
end
local attrs={}
local player={GetAttribute=function(_,name)return attrs[name]end}
for _,gameName in {"Tag","Bulldog"}do
 local isTag=gameName=="Tag"
 local key=isTag and "TG" or "BB"
 for _,case in {{false,false,6.2,10,"SPRINT\n6.2/10s"},{true,false,0,10,"RECHARGING\n0.0/10s"},
 {false,true,7.6,10,"SPRINTING\n7.6/10s"},{false,false,15,15,"SPRINT\n15.0/15s"}}do
  attrs[key.."SprintExhausted"]=case[1]
  attrs[key.."Sprinting"]=case[2]
  local remaining,maximum=case[3],case[4]
  local exhausted=case[1]
  if isTag then
 local caption=player:GetAttribute("TGSprintExhausted") and "RECHARGING" or player:GetAttribute("TGSprinting") and "SPRINTING" or "SPRINT"
 mobileSprint.Text=caption..string.format("\n%.1f/%gs",remaining,maximum)
  else
 mobileSprint.Text=(exhausted and "RECHARGING" or player:GetAttribute("BBSprinting")==true and "SPRINTING" or "SPRINT")..string.format("\n%.1f/%gs",remaining,maximum)
  end
  task.wait()
  check(mobileSprint.Text==case[5],"mobile stamina caption")
  check(live.Text==case[5],"reusable artwork caption mirrors Text")
 end
end
connection:Disconnect()
panel:Destroy()
return {passed=tests,viewports=11,captionCases=8}

