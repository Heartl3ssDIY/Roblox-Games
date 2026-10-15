assert(not game:GetService("RunService"):IsRunning())
local fixture = Instance.new("Part")
fixture.Name = "CommerceLayoutFixture20261007"
fixture.Anchored = true
fixture.CanCollide = false
fixture.CanTouch = false
fixture.CanQuery = false
fixture.Transparency = 1
fixture.Position = Vector3.new(0, -10000, 0)
fixture.Parent = workspace
local records = {}
local ok, failure = pcall(function()
 for _, viewport in {{320,568},{390,844},{844,390},{640,360},{768,1024},{1024,768},{1365,768}} do
  local surface = Instance.new("SurfaceGui")
  surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
  surface.CanvasSize = Vector2.new(viewport[1], viewport[2])
  surface.Parent = fixture
  local shop = game.StarterGui.PlaygroundShell.ShopPanel:Clone()
  shop.Visible = true
  shop.Cards.Visible = false
  shop.Pager.Visible = false
  shop.EmoteEmptyState.Visible = false
  shop.Status.Visible = false
  shop.BuyCoinsPanel.Visible = true
  shop.Parent = surface
  task.wait(0.1)
  local panel=shop.BuyCoinsPanel
  local count=0
  local labels=0
  for _,card in panel.Offers:GetChildren() do
   if card:IsA("Frame") then
    count+=1
    assert(card.Buy.AbsoluteSize.X>=44 and card.Buy.AbsoluteSize.Y>=44,"Purchase tap target")
    assert(card.AbsoluteSize.X <= panel.Offers.AbsoluteSize.X, "Card width")
    for _,label in card:GetDescendants() do
     if label:IsA("TextLabel") then labels+=1 assert(label.TextFits, label:GetFullName().." overflow at "..viewport[1]) end
    end
   end
  end
  for _,label in {panel.Heading,panel.Intro,panel.Status,shop.Categories.BuyCoins.LiveCaption} do
   labels+=1
   assert(label.TextFits,label:GetFullName().." overflow at "..viewport[1])
  end
  assert(count==8,"8 offers expected")
  assert(panel.Offers.AbsoluteCanvasSize.Y>=1100,"All offers reachable by scroll")
  assert(panel.Offers.AbsoluteSize.Y>=100,"Scrolling window too short")
  local p,s=shop.AbsolutePosition,shop.AbsoluteSize
  assert(p.X>=0 and p.Y>=0 and p.X+s.X<=viewport[1]+1 and p.Y+s.Y<=viewport[2]+1,"Outside viewport")
  table.insert(records,{viewport=viewport,offers=count,labels=labels,canvas=panel.Offers.AbsoluteCanvasSize.Y,scrollHeight=panel.Offers.AbsoluteSize.Y})
  surface:Destroy()
 end
end)
fixture:Destroy()
assert(ok,failure)
return game.HttpService:JSONEncode({passed=true,viewports=records,play=false})

