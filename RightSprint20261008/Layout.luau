return function(root,guarded)
 local changes={
  {path={"BritishBulldogHUD","MobileSprint"},before={UDim2.new(0,18,1,-202),Vector2.new(0,1),UDim2.fromOffset(120,54)},after={UDim2.new(1,-18,1,-124),Vector2.new(1,1),UDim2.fromOffset(120,54)}},
  {path={"TagHUD","MobileSprint"},before={UDim2.new(0,18,1,-202),Vector2.new(0,1),UDim2.fromOffset(120,54)},after={UDim2.new(1,-18,1,-124),Vector2.new(1,1),UDim2.fromOffset(120,54)}},
  {path={"MudHUD","Main","MobileSprint"},before={UDim2.new(0,18,1,-202),Vector2.new(0,1),UDim2.fromOffset(120,54)},after={UDim2.new(1,-18,1,-124),Vector2.new(1,1),UDim2.fromOffset(120,54)}},
  {path={"PlaygroundBatControls","Swing"},before={UDim2.new(1,-24,0.5,0),Vector2.new(1,0.5),UDim2.fromOffset(104,68)},after={UDim2.new(1,-24,1,-192),Vector2.new(1,1),UDim2.fromOffset(104,54)}},
  {path={"PlaygroundPushControls","MobilePush"},before={UDim2.new(1,-140,0.5,0),Vector2.new(1,0.5),UDim2.fromOffset(104,68)},after={UDim2.new(1,-140,0.81,-61),Vector2.new(1,1),UDim2.fromOffset(94,54)}},
  {path={"MudHUD","Main","Controls","Mud"},before={UDim2.new(1,-88,1,-238),Vector2.new(1,1),UDim2.fromOffset(62,44)},after={UDim2.new(0,12,1,-202),Vector2.new(0,1),UDim2.fromOffset(56,44)}},
  {path={"MudHUD","Main","Controls","Heat"},before={UDim2.new(1,-18,1,-238),Vector2.new(1,1),UDim2.fromOffset(62,44)},after={UDim2.new(0,76,1,-202),Vector2.new(0,1),UDim2.fromOffset(56,44)}},
  {path={"MudHUD","Main","Controls","Fire"},before={UDim2.new(1,-18,1,-180),Vector2.new(1,1),UDim2.fromOffset(132,54)},after={UDim2.new(1,-18,1,-192),Vector2.new(1,1),UDim2.fromOffset(120,54)}},
 }
 local targets={}
 for _,change in ipairs(changes)do
  local target=root
  for _,name in ipairs(change.path)do target=assert(target:FindFirstChild(name),table.concat(change.path,"."))end
  assert(target:IsA("GuiButton"),target:GetFullName().." must be a button")
  if guarded then
   assert(target.Position==change.before[1]and target.AnchorPoint==change.before[2]and target.Size==change.before[3],"Layout changed: "..target:GetFullName())
  end
  table.insert(targets,{button=target,change=change})
 end
 for _,entry in ipairs(targets)do
  local button,after=entry.button,entry.change.after
  button.Position=after[1]
  button.AnchorPoint=after[2]
  button.Size=after[3]
  if button.Name=="MobileSprint"then
   button:SetAttribute("MobileSprintPlacement","RightAboveJump")
   local caption=button:FindFirstChild("LiveCaption")
   if caption then caption.TextScaled=true end
  end
 end
 return targets
end
