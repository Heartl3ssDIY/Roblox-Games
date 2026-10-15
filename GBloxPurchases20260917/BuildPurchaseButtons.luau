-- UI objects only, to be applied with the reviewed shop client and server handlers.
local gui=game.StarterGui.GBloxShopMockups
for _,section in {gui.Canvas.Shop.Gamepasses,gui.Canvas.Shop.Cash,gui.Canvas.Shop.Trophies} do
 for _,card in section:GetChildren() do
  local artwork=card:FindFirstChild("PriceArtwork")
  if artwork then
   local button=artwork:FindFirstChild("PurchaseButton") or Instance.new("TextButton")
   button.Name="PurchaseButton";button.Text="";button.BackgroundTransparency=1
   button.Size=UDim2.fromScale(1,1);button.ZIndex=artwork.ZIndex+3;button.AutoButtonColor=false;button.Parent=artwork
   if not card:GetAttribute("ProductId") and not card:GetAttribute("GamePassId") then artwork.Price.Text="Coming soon" end
  end
 end
end
gui.Canvas.Shop.Gamepasses.Card_1:SetAttribute("CashMultiplier",2)
gui.Canvas.Shop.Gamepasses.Card_2:SetAttribute("CashMultiplier",5)
gui.Canvas.Shop.MockupNotice.Text="Purchases use Robux. Cash boosts use your highest owned multiplier."
gui.Canvas.Shop.MockupNotice.Visible=true

