local ReplicatedStorage=game:GetService("ReplicatedStorage")
local gui=assert(game:GetService("StarterGui"):FindFirstChild("PlaygroundShell"),"Playground shell missing")
local catalog=require(assert(ReplicatedStorage:FindFirstChild("PlaygroundCatalog"),"Catalog missing"))
local assets=assert(ReplicatedStorage:FindFirstChild("PlaygroundCosmeticAssets"),"Cosmetic assets missing")
local checks=0
local function check(value,message) assert(value,message) checks+=1 end
check(gui:IsA("ScreenGui") and gui.Enabled and not gui.ResetOnSpawn,"Shell must stay editable in StarterGui")
check(gui.Templates:FindFirstChild("ItemCard")~=nil,"Repeated item template missing")
check(gui.ShopPanel.Cards:FindFirstChildOfClass("UIGridLayout")~=nil,"Shop grid layout missing")
check(gui.ShopPanel.Cards.AutomaticCanvasSize==Enum.AutomaticSize.Y,"Shop must scroll vertically")
check(gui.ShopPanel.Categories.AutomaticCanvasSize==Enum.AutomaticSize.X,"Categories must scroll horizontally")
local cardCount,viewportCount,previewParts=0,0,0
for index,item in ipairs(catalog.Items) do
 local card=gui.ShopPanel.Cards:FindFirstChild(string.format("Slot%02d",index))
 check(card~=nil,"Missing authored shop slot")
 check(card:GetAttribute("CatalogId")==item.id,"Shop slot catalog binding differs")
 check(card:GetAttribute("Category")==item.category,"Shop category binding differs")
 check(card:FindFirstChild("Name").Text==item.name,"Shop card label differs")
 local preview=card:FindFirstChild("Preview")
 check(preview and preview:IsA("ViewportFrame"),"Shop slot needs a true ViewportFrame")
 check(preview:FindFirstChild("World") and preview.World:IsA("WorldModel"),"Viewport needs authored WorldModel")
 check(preview:FindFirstChild("Camera") and preview.CurrentCamera==preview.Camera,"Viewport needs its own authored camera")
 local model=preview.World:FindFirstChild("ItemModel")
 check(model and model:IsA("Model"),"Shop preview needs a 3D model")
 local count=0
 for _,part in ipairs(model:GetDescendants()) do
  check(not part:IsA("LuaSourceContainer"),"Preview model contains executable code")
  if part:IsA("BasePart") then
   count+=1 previewParts+=1
   check(part.Anchored and not part.CanCollide and not part.CanQuery,"Preview geometry must not affect play")
  end
 end
 check(count>=2,"Shop preview is not a real multi-part model")
 check(assets:FindFirstChild(item.id)~=nil,"Reusable cosmetic asset missing")
 check(card:FindFirstChild("Action") and card:FindFirstChild("Try"),"Editable item action buttons missing")
 cardCount+=1 viewportCount+=1
end
check(cardCount==12 and viewportCount==12,"The shop needs twelve authored preview slots")
for _,category in ipairs(catalog.Categories) do check(gui.ShopPanel.Categories:FindFirstChild(category)~=nil,"Category control missing") end
check(gui.VotePanel:FindFirstChild("BritishBulldog") and gui.VotePanel:FindFirstChild("TagYoureIt"),"Vote controls missing")
check(gui.Wallet:FindFirstChild("Coins") and gui.Wallet:FindFirstChild("Wins"),"Wallet bindings missing")
check(gui.RewardToast:FindFirstChild("Message")~=nil,"Reward toast missing")
return {passed=checks,editableSlots=cardCount,viewportFrames=viewportCount,previewParts=previewParts,template=gui.Templates.ItemCard:GetFullName(),runtimeLayoutWrites=false}
