
local gui=game.StarterGui.WarehouseUI
local backup=Instance.new("Folder");backup.Name="LaptopUIBackup_20260916";backup.Parent=game.ServerStorage
local old=Instance.new("StringValue");old.Name="ControllerSource";old.Value=gui.Controller.Source;old.Parent=backup
local copy=gui:Clone();copy.Name="WarehouseUI"
for _,s in copy:GetDescendants() do if s:IsA("LuaSourceContainer") then s:Destroy() end end
copy.Parent=backup
local assets={Scroll="rbxassetid://90134202623283",Selected="rbxassetid://91854102239386",Trash="rbxassetid://99874395924591",Purchase="rbxassetid://140701042175796",Elite="rbxassetid://120221076103326",Premium="rbxassetid://82359542621900",Standard="rbxassetid://84028318333670",Hud="rbxassetid://108477340117255",Security="rbxassetid://71647040025674",Agency="rbxassetid://73549632083174",Customise="rbxassetid://101012527578415",Stats="rbxassetid://100747683790359",Store="rbxassetid://114583608947811",Trucks="rbxassetid://123277693851395",Payments="rbxassetid://119301932730570",Contracts="rbxassetid://136591036580371",Sidebar="rbxassetid://119813521714734",TabHud="rbxassetid://104008744879966",Back="rbxassetid://112836458410322",Close="rbxassetid://109046512994540",OS="rbxassetid://87178666587670",LaptopFrame="rbxassetid://92275331063673",Car="rbxassetid://109399846869683",Jet="rbxassetid://79035020231990",Warehouse="rbxassetid://130560341608479",LaptopIcon="rbxassetid://95736390159727",Locked="rbxassetid://123216544362953",Achievements="rbxassetid://126061786762514",Market="rbxassetid://115835686476024"}
local folder=Instance.new("Folder");folder.Name="LaptopAssets";folder.Parent=gui
for name,id in assets do local v=Instance.new("StringValue");v.Name=name;v.Value=id;v.Parent=folder end
local function make(class,name,parent,props)
 local p=Instance.new(class);p.Name=name;for k,v in props do p[k]=v end;p.Parent=parent;return p
end
local function image(name,parent,id,pos,size,z)
 return make("ImageLabel",name,parent,{Image=id,BackgroundTransparency=1,BorderSizePixel=0,Position=pos,Size=size,ZIndex=z or 8})
end
local function clearDecor(object)
 for _,c in object:GetChildren() do if c:IsA("UIStroke") or c:IsA("UICorner") or c:IsA("UIGradient") or c:IsA("UIPadding") then c:Destroy() end end
 if object:IsA("GuiObject") then object.BackgroundTransparency=1;object.BorderSizePixel=0 end
end
local root=gui.LaptopOverlay.Root
root.Size=UDim2.fromOffset(1000,664);root.Position=UDim2.fromScale(.5,.5);root.AnchorPoint=Vector2.new(.5,.5)
root:SetAttribute("FitW",1000);root:SetAttribute("FitH",664);root:SetAttribute("FitMin",.15);root:SetAttribute("FitMarginX",.97);root:SetAttribute("FitMarginY",.94)
root.ZIndex=7;clearDecor(root)
for _,c in root:GetChildren() do if c.Name=="Shadow" then c:Destroy() end end
image("LaptopFrame",root,assets.LaptopFrame,UDim2.new(),UDim2.fromScale(1,1),7)
local screen=root.Screen;clearDecor(screen)
screen.Position=UDim2.fromOffset(22,30);screen.Size=UDim2.fromOffset(956,542);screen.ClipsDescendants=true;screen.ZIndex=8
image("OSSkin",screen,assets.OS,UDim2.new(),UDim2.fromScale(1,1),8)
local header=screen.Header;clearDecor(header);header.Size=UDim2.new(1,0,0,86);header.ZIndex=12
for _,c in header:GetChildren() do c:Destroy() end
for i,name in {"Back","Close"} do
 make("ImageButton",name,header,{Image=assets[name],BackgroundTransparency=1,Size=UDim2.fromOffset(32,22.5),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8-(2-i)*38,0,7),ZIndex=25,AutoButtonColor=false})
end
local main=screen.Main;clearDecor(main);main.Position=UDim2.fromOffset(0,87);main.Size=UDim2.new(1,0,1,-87)
image("SidebarSkin",main,assets.Sidebar,UDim2.new(),UDim2.new(0,199,1,0),8)
local side=main.Sidebar;clearDecor(side);side.Position=UDim2.fromOffset(5,5);side.Size=UDim2.new(0,189,1,-10);side.ScrollBarThickness=0;side.CanvasSize=UDim2.new();side.AutomaticCanvasSize=Enum.AutomaticSize.Y
local list=side:FindFirstChildOfClass("UIListLayout")
if not list then list=Instance.new("UIListLayout");list.Parent=side end
list.Padding=UDim.new(0,4);list.SortOrder=Enum.SortOrder.LayoutOrder
local order={"Contracts","Payments","Trucks","Stats","Agency","Store","Customise","Market","Security","Achievements"}
for i,name in order do
 local button=side:FindFirstChild(name.."Tab")
 if not button then button=Instance.new("TextButton");button.Name=name.."Tab";button.Parent=side end
 for _,c in button:GetChildren() do c:Destroy() end
 button.Text="";button.BackgroundTransparency=1;button.BorderSizePixel=0;button.Size=UDim2.new(1,0,0,59.75);button.LayoutOrder=i;button.ZIndex=10
 image("Art",button,assets[name],UDim2.new(),UDim2.fromScale(1,1),10)
 local selection=image("Selection",button,assets.Selected,UDim2.fromOffset(-1,-1),UDim2.new(1,2,1,2),11);selection.Visible=false
end
local content=main.Content;clearDecor(content);content.Position=UDim2.fromOffset(204,0);content.Size=UDim2.new(1,-204,1,0)
image("ContractsSkin",content,assets.TabHud,UDim2.new(),UDim2.fromScale(1,1),8)
for _,p in content:GetChildren() do if p:IsA("ScrollingFrame") then
 clearDecor(p);p.Position=UDim2.fromOffset(5,p.Name=="Contracts" and 42 or 5)
 p.Size=UDim2.new(1,-18,1,p.Name=="Contracts" and -48 or -10)
 p.ScrollBarThickness=0;p.AutomaticCanvasSize=Enum.AutomaticSize.Y;p.CanvasSize=UDim2.new()
 local padding=Instance.new("UIPadding");padding.PaddingRight=UDim.new(0,2);padding.PaddingBottom=UDim.new(0,4);padding.Parent=p
 local layout=p:FindFirstChildOfClass("UIListLayout")
 if layout then layout.Padding=UDim.new(0,7);layout.SortOrder=Enum.SortOrder.LayoutOrder end
 local title=p:FindFirstChild("PageTitle");if title and p.Name=="Contracts" then title.Visible=false;title.Size=UDim2.new() end
end end
local business=make("Frame","BusinessSelection",root,{BackgroundTransparency=1,Position=UDim2.fromOffset(22,30),Size=UDim2.fromOffset(956,542),ClipsDescendants=true,ZIndex=9})
local scroller=make("ScrollingFrame","Businesses",business,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,1,-22),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=0,ZIndex=10,ElasticBehavior=Enum.ElasticBehavior.WhenScrollable})
local row=Instance.new("UIListLayout");row.FillDirection=Enum.FillDirection.Horizontal;row.Padding=UDim.new(0,12);row.SortOrder=Enum.SortOrder.LayoutOrder;row.Parent=scroller
for i,name in {"Warehouse","Car","Jet"} do
 local b=make("ImageButton",name,scroller,{BackgroundTransparency=1,Image=assets[name],Size=UDim2.fromOffset(368,515),LayoutOrder=i,AutoButtonColor=false,ZIndex=10})
 if i>1 then
  b:SetAttribute("Locked",true)
  make("Frame","Shade",b,{BackgroundColor3=Color3.new(),BackgroundTransparency=.45,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=11})
  local lock=image("Lock",b,assets.Locked,UDim2.fromScale(.5,.47),UDim2.fromOffset(145,145),12);lock.AnchorPoint=Vector2.new(.5,.5)
  make("TextLabel","LockedText",b,{BackgroundTransparency=1,Text="COMING SOON",TextColor3=Color3.new(1,1,1),TextStrokeTransparency=0,Font=Enum.Font.FredokaOne,TextSize=24,AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.63),Size=UDim2.new(1,0,0,32),ZIndex=12})
 end
end
make("ImageButton","Close",business,{Image=assets.Close,BackgroundTransparency=1,Size=UDim2.fromOffset(32,22.5),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,7),ZIndex=25,AutoButtonColor=false})
local launcher=gui.LaptopBtn
for _,c in launcher:GetChildren() do c:Destroy() end
launcher.Text="";launcher.BackgroundTransparency=1;launcher.BorderSizePixel=0;launcher.Size=UDim2.fromOffset(100,100);launcher.AnchorPoint=Vector2.new(1,1);launcher.Position=UDim2.new(1,-18,1,-12)
image("Art",launcher,assets.LaptopIcon,UDim2.new(),UDim2.fromScale(1,1),launcher.ZIndex)
screen.Visible=false;business.Visible=true;gui.LaptopOverlay.Visible=false
local main=game.StarterGui.WarehouseUI.LaptopOverlay.Root.Screen.Main
main.ZIndex=9;main.Sidebar.ZIndex=10;main.Content.ZIndex=10
for _,page in main.Content:GetChildren() do if page:IsA("ScrollingFrame") then page.ZIndex=10 end end
return {backup=backup:GetFullName(),tabs=#order}

