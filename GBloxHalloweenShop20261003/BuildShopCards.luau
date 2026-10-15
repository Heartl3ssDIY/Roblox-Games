local StarterGui=game:GetService("StarterGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local gui=StarterGui:WaitForChild("GBloxShopMockups")
local list=gui.Canvas.Abilities.AbilityCards
local items=gui.Canvas.Inventory.Items
local imported=ServerStorage:WaitForChild("HalloweenImportedModels")
local sourceNames={Pumpkin="Throwable_Pumpkin",Web="Floor_Web_Trap"}
for _,name in sourceNames do assert(imported:FindFirstChild(name),"Missing Halloween model: "..name) end

local function folder(parent,name)
 local result=parent:FindFirstChild(name)
 if not result then result=Instance.new("Folder") result.Name=name result.Parent=parent end
 return result
end
local models=folder(ReplicatedStorage,"GBloxHalloweenShopPreviews")
local templates=folder(gui,"AbilityPreviewTemplates")
local function cleanModel(model)
 for _,object in model:GetDescendants() do
  if object:IsA("LuaSourceContainer") or object:IsA("Sound") or object:IsA("ParticleEmitter")
   or object:IsA("Trail") or object:IsA("Beam") or object:IsA("ProximityPrompt")
   or object:IsA("ClickDetector") or object:IsA("Constraint") then
   object:Destroy()
  elseif object:IsA("BasePart") then
   object.Anchored=true object.CanCollide=false object.CanTouch=false object.CanQuery=false
  end
 end
 local center=model:GetBoundingBox()
 model:PivotTo(CFrame.new(-center.Position)*model:GetPivot())
end
local function makePreview(id)
 local old=models:FindFirstChild(id)
 if old then old:Destroy() end
 local model=imported[sourceNames[id]]:Clone()
 model.Name=id cleanModel(model) model.Parent=models
 local oldTemplate=templates:FindFirstChild(id)
 if oldTemplate then oldTemplate:Destroy() end
 local preview=Instance.new("ViewportFrame")
 preview.Name=id preview:SetAttribute("AbilityId",id)
 preview.BackgroundTransparency=1 preview.BorderSizePixel=0
 preview.Visible=false
 preview.Position=UDim2.fromScale(.22,.32) preview.Size=UDim2.fromScale(.56,.45)
 preview.Active=false preview.ZIndex=3 preview.Ambient=Color3.fromRGB(215,225,235)
 preview.LightColor=Color3.new(1,1,1) preview.LightDirection=Vector3.new(-1,-1,-1)
 preview.Parent=templates
 local world=Instance.new("WorldModel") world.Name="PreviewWorld" world.Parent=preview
 local display=model:Clone() display.Parent=world
 local _,size=display:GetBoundingBox()
 local distance=math.max(size.X,size.Y,size.Z)/(2*math.tan(math.rad(28)/2))*1.35
 local camera=Instance.new("Camera") camera.Name="PreviewCamera" camera.FieldOfView=28
 local direction=id=="Web" and Vector3.new(0,.96,.28) or Vector3.new(.25,.15,1).Unit
 camera.CFrame=CFrame.lookAt(direction*distance,Vector3.zero)
 camera.Parent=preview preview.CurrentCamera=camera
 return preview
end
local previewById={Pumpkin=makePreview("Pumpkin"),Web=makePreview("Web")}
local specs={
 {Id="Pumpkin",Name="Pumpkin",Price=150000,Recharge=15000,Order=7,
  Description="4-second orange splat.\nCooldown: 25 seconds.\nUnlimited during Halloween.\nAfter 1 Nov: 15,000 cash / game."},
 {Id="Web",Name="Web",Price=350000,Recharge=35000,Order=8,
  Description="Trap opponents for 5 seconds.\nCooldown: 30 seconds.\nUnlimited during Halloween.\nAfter 1 Nov: 35,000 cash / game."},
}
for _,spec in specs do
 local name="Card_"..spec.Order
 local card=list:FindFirstChild(name)
 if card then assert(card:GetAttribute("AbilityId")==spec.Id,"Refusing to replace unrelated "..name)
 else card=list.Card_1:Clone() card.Name=name card.Parent=list end
 card.LayoutOrder=spec.Order card.Visible=true
 card:SetAttribute("AbilityId",spec.Id) card:SetAttribute("CashPrice",spec.Price)
 card:SetAttribute("RechargeCashPrice",spec.Recharge) card:SetAttribute("RobuxPrice",nil)
 card:SetAttribute("PreservePurchaseLayout",true)
 card:FindFirstChild("Name").Text=spec.Name
 card.Description.Text=spec.Description card.Description.TextSize=16 card.Description.TextWrapped=true
 card.Description.Size=UDim2.new(1,-152,0,106)
 card.Refill.Visible=false card.PriceArtwork.Visible=false
 card.RobuxRefill.Visible=false card.RobuxRefill.Active=false card.RobuxRefill.Selectable=false
 card.RobuxRefill:SetAttribute("ProductId",nil)
 card.CashPurchase.AnchorPoint=Vector2.new(.5,1)
 card.CashPurchase.Position=UDim2.new(.5,0,1,-16) card.CashPurchase.Size=UDim2.fromOffset(214,49)
 card.CashPurchase.Label.Text=tostring(spec.Price/1000).."K CASH"
 card.CashPurchase.Label.TextScaled=true
 local oldPreview=card:FindFirstChild("AbilityPreview")
 if oldPreview then oldPreview:Destroy() end
 local preview=previewById[spec.Id]:Clone() preview.Name="AbilityPreview"
 preview.CurrentCamera=preview:FindFirstChild("PreviewCamera")
 preview.Visible=true
 preview.AnchorPoint=Vector2.new(1,0) preview.Position=UDim2.new(1,-14,0,70)
 preview.Size=UDim2.fromOffset(114,102) preview.Parent=card
 local state=card:FindFirstChild("AbilityState")
 if not state then state=card.Description:Clone() state.Name="AbilityState" state.Parent=card end
 state.Position=UDim2.new(0,18,0,177) state.Size=UDim2.new(1,-36,0,24)
 state.Text="HALLOWEEN ABILITY" state.TextScaled=true state.TextColor3=Color3.fromRGB(115,255,207)
 state.ZIndex=3
 local limit=state:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit=Instance.new("UITextSizeConstraint") limit.Parent=state end
 limit.MinTextSize=8 limit.MaxTextSize=15
end
for i=1,8 do
 local name="Slot"..i
 local slot=items:FindFirstChild(name)
 if not slot then slot=items.Slot1:Clone() slot.Name=name slot.Parent=items end
 slot.LayoutOrder=i
 local status=slot:FindFirstChild("AbilityStatus")
 if not status then status=slot.Description:Clone() status.Name="AbilityStatus" status.Parent=slot end
 status.Position=UDim2.fromScale(.04,.8) status.Size=UDim2.fromScale(.92,.16)
 status.Text="" status.TextScaled=true status.Visible=false status.ZIndex=4
 local limit=status:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit=Instance.new("UITextSizeConstraint") limit.Parent=status end
 limit.MinTextSize=8 limit.MaxTextSize=14
end
list.AutomaticCanvasSize=Enum.AutomaticSize.Y
items.AutomaticCanvasSize=Enum.AutomaticSize.Y
return {Cards=8,AvailableAbilities=7,InventorySlots=8,Previews={"Pumpkin","Web"}}
