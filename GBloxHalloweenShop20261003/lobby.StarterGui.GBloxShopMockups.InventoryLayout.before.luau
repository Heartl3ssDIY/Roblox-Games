local M={}
function M.Apply(g,v)
 local canvas=g.Canvas local outer=canvas.ResponsiveScale.Scale
 local width=math.min(1120,v.X-48) local height=math.min(719,v.Y-64)
 local compact=v.Y<500 or v.X<650
 for _,name in {"Inventory"} do
  local panel=canvas[name]
  panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.5)
  panel.Size=UDim2.fromOffset(width/outer,height/outer)
  panel.Close.Size=UDim2.fromOffset(44/outer,44/outer) panel.Close.Position=UDim2.new(1,-60/outer,0,12/outer)
  local portrait=v.X<v.Y
  local tabs=panel.Tabs
  tabs.Position=UDim2.new(.033,0,.22,0) tabs.Size=UDim2.new(compact and .90 or .47,0,0,48/outer)
  local list=panel.Items list.Position=UDim2.new(.033,0,.22,56/outer) list.Size=UDim2.new(.47,0,.71,-56/outer)
  list.Grid.CellSize=UDim2.new(compact and .5 or 1/3,-8,0,(compact and 165 or 210)/outer)
  panel.Details.Position=UDim2.new(.515,0,compact and .22 or .23,compact and 56/outer or 0)
  panel.Details.Size=UDim2.new(.447,0,compact and .71 or .70,compact and -56/outer or 0)
  for _,t in panel:GetDescendants() do if (t:IsA("TextLabel") or t:IsA("TextButton")) and t.Name~="EquipCaption" then
   local isDetail=t.Parent==panel.Details
   t.TextSize=(t.Name=="Title" and (isDetail and (compact and 20 or 30) or 13) or (isDetail and (compact and 12 or 18) or 10))/outer
  end end
  panel.Details.Equip.Size=UDim2.new(.8,0,0,44/outer) panel.Details.Equip.Position=UDim2.new(.1,0,1,-54/outer)
  panel.Details.Uses.Position=UDim2.new(.06,0,1,-80/outer)
  if portrait then
   tabs.Size=UDim2.new(.92,0,0,100/outer)
   list.Position=UDim2.new(.04,0,.22,106/outer) list.Size=UDim2.new(.92,0,.38,-30/outer)
   panel.Details.Position=UDim2.fromScale(.04,.69) panel.Details.Size=UDim2.fromScale(.92,.27)
   panel.Details.Title.Size=UDim2.fromScale(.9,.2)
   panel.Details.Description.Position=UDim2.fromScale(.06,.25) panel.Details.Description.Size=UDim2.fromScale(.88,.27)
  end
  for i,b in tabs:GetChildren() do if b:IsA("GuiButton") then
   b.Size=UDim2.new(portrait and .48 or (name=="Pets" and .2 or .24),0,portrait and .48 or 1,0)
   if portrait then
    local order=({Abilities=0,Titles=1,Deaths=2,VictoryEmotes=3,Pets=0})[b.Name]
    b.Position=UDim2.fromScale((order%2)*.5,math.floor(order/2)*.5)
   else
    local order=({Abilities=0,Titles=1,Deaths=2,VictoryEmotes=3,Pets=0})[b.Name]
    b.Position=UDim2.fromScale(order*.25,0)
   end
  end end
 end
 local pets=canvas.Pets
 pets.AnchorPoint=Vector2.new(.5,.5)
 pets.Position=UDim2.fromScale(.5,.5)
 pets.Size=UDim2.fromOffset(1120,719)
 pets.DesignScale.Scale=math.min((v.X-24)/(1120*outer),(v.Y-36)/(719*outer),1)
 local buttons=g.PreviewButtons
 local h=math.min(v.X,v.Y)<600 and 48 or math.min(84,(v.Y-90)/4-6)
 buttons.Size=UDim2.fromOffset(h*173/109,4*(h+6))
 for i,n in {"Shop","Abilities","Inventory","Pets"} do local b=buttons[n] b.Size=UDim2.fromOffset(h*173/109,h) b.Position=UDim2.fromOffset(0,(i-1)*(h+6)) end
end
return M
