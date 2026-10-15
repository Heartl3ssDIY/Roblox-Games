local count=0
local function check(value,message) assert(value,message) count+=1 end
local admin=game.StarterGui.PlaygroundAdminPanel
local session=game.StarterGui.PlaygroundSessionControls
check(admin.Enabled==false and admin.AdminHub.Visible==false and admin.Toggle.Visible==false,"Admin not hidden by default")
check(admin:GetAttribute("OwnerUserId")==1201803949,"Owner config changed")
check(admin.AdminHub.Pages.Rewards:IsA("ScrollingFrame"),"Rewards cannot scroll")
check(admin.AdminHub.Pages.Rewards.Entitlements.GrantVIP:FindFirstChild("ReusableSkin")~=nil,"VIP art missing")
check(admin.AdminHub.Pages.Rewards.Entitlements.GrantBetaTester:FindFirstChild("ReusableSkin")~=nil,"Beta art missing")
check(session.Dock.Body:IsA("ScrollingFrame"),"Settings cannot scroll")
local preview=Instance.new("ScreenGui")
preview.Name="VIPLayoutVerification"
preview.Parent=game.StarterGui
local ok,result=pcall(function()
 for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(1024,768),Vector2.new(768,1024),Vector2.new(844,390),Vector2.new(390,844),Vector2.new(320,568),Vector2.new(568,320)}) do
  local viewport=Instance.new("Frame")
  viewport.Size=UDim2.fromOffset(size.X,size.Y)
  viewport.Parent=preview
  local dock=session.Dock:Clone()
  dock.Visible=true
  dock.Parent=viewport
  task.wait()
  local box=dock.Body.Codes.Input
  local button=dock.Body.Codes.Redeem
  local codes=dock.Body.Codes
  check(dock.AbsoluteSize.X<=size.X-20,"Dock wider than phone")
  check(dock.AbsoluteSize.Y<=size.Y,"Dock taller than screen")
  check(box.AbsoluteSize.Y>=44 and button.AbsoluteSize.Y>=44,"Code touch target too small")
  check(box.AbsolutePosition.X+box.AbsoluteSize.X <= button.AbsolutePosition.X,"Input overlaps redeem")
  check(codes.Position.Y.Offset+codes.Size.Y.Offset<=dock.Body.CanvasSize.Y.Offset,"Code messages outside canvas")
  check(dock.Body.ClipsDescendants and dock.Body.ScrollingEnabled,"Short settings cannot scroll")
  viewport:Destroy()
 end
 return {checks=count,viewports=7,minCodeControlHeight=44}
end)
preview:Destroy()
assert(ok,result)
return result
