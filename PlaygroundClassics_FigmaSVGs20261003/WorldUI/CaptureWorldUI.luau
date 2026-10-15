local HttpService=game:GetService("HttpService")
local TextService=game:GetService("TextService")
local function u(v) return {v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset} end
local function dim(v) return {v.Scale,v.Offset} end
local function color(v) return {math.floor(v.R*255+0.5),math.floor(v.G*255+0.5),math.floor(v.B*255+0.5)} end
local function ordinalPath(o)
 local segments={}
 while o and o~=game do
  local n=1
  if o.Parent then for _,s in ipairs(o.Parent:GetChildren()) do if s==o then break end if s.Name==o.Name then n+=1 end end end
  table.insert(segments,1,o.Name.."["..n.."]")
  o=o.Parent
 end
 return table.concat(segments,"/")
end
local function snapshot(o)
 local out={name=o.Name,class=o.ClassName,path=o:GetFullName(),locator=ordinalPath(o),children={}}
 if o:IsA("GuiObject") then
  out.position=u(o.Position) out.size=u(o.Size) out.anchor={o.AnchorPoint.X,o.AnchorPoint.Y}
  out.rotation=o.Rotation out.backgroundColor=color(o.BackgroundColor3) out.backgroundTransparency=o.BackgroundTransparency
  out.borderColor=color(o.BorderColor3) out.borderSize=o.BorderSizePixel out.visible=o.Visible out.zIndex=o.ZIndex
  out.clip=o.ClipsDescendants
 end
 if o:IsA("TextLabel") or o:IsA("TextButton") then
  out.text=o.Text out.textColor=color(o.TextColor3) out.textTransparency=o.TextTransparency
  out.textStrokeColor=color(o.TextStrokeColor3) out.textStrokeTransparency=o.TextStrokeTransparency
  out.font={family=o.FontFace.Family,weight=o.FontFace.Weight.Name,style=o.FontFace.Style.Name,enum=o.Font.Name}
  out.textScaled=o.TextScaled out.textSize=o.TextSize out.textWrapped=o.TextWrapped
  out.alignX=o.TextXAlignment.Name out.alignY=o.TextYAlignment.Name out.richText=o.RichText
  out.measurements={}
  for _,fontSize in ipairs({10,12,14,16,18,20,24,28,32,40,48,64,80,100}) do
   local ok,bounds=pcall(function() return TextService:GetTextSize(o.Text,fontSize,o.Font,Vector2.new(100000,100000)) end)
   if ok then table.insert(out.measurements,{fontSize,bounds.X,bounds.Y}) end
  end
 elseif o:IsA("UICorner") then out.radius=dim(o.CornerRadius)
 elseif o:IsA("UIStroke") then out.color=color(o.Color) out.thickness=o.Thickness out.transparency=o.Transparency out.mode=o.ApplyStrokeMode.Name out.join=o.LineJoinMode.Name
 elseif o:IsA("UIPadding") then out.padding={left=dim(o.PaddingLeft),right=dim(o.PaddingRight),top=dim(o.PaddingTop),bottom=dim(o.PaddingBottom)}
 elseif o:IsA("UITextSizeConstraint") then out.minTextSize=o.MinTextSize out.maxTextSize=o.MaxTextSize
 elseif o:IsA("UISizeConstraint") then out.minSize={o.MinSize.X,o.MinSize.Y} out.maxSize={o.MaxSize.X,o.MaxSize.Y}
 end
 for _,child in ipairs(o:GetChildren()) do
  if child:IsA("GuiObject") or child:IsA("UIComponent") then table.insert(out.children,snapshot(child)) end
 end
 return out
end
local records={}
for _,root in ipairs({game.ReplicatedStorage,workspace}) do
 for _,o in ipairs(root:GetDescendants()) do
  if o:IsA("BillboardGui") or o:IsA("SurfaceGui") then
   local record=snapshot(o)
   record.enabled=o.Enabled record.lightInfluence=o.LightInfluence record.alwaysOnTop=o.AlwaysOnTop
   if o:IsA("BillboardGui") then record.canvas={o.Size.X.Offset,o.Size.Y.Offset} record.billboardSize=u(o.Size)
   else
    record.sizingMode=o.SizingMode.Name record.face=o.Face.Name record.pixelsPerStud=o.PixelsPerStud
    local host=o.Adornee or o.Parent
    if host and host:IsA("BasePart") then
     local size=host.Size
     local w,h=size.X,size.Y
     if o.Face==Enum.NormalId.Top or o.Face==Enum.NormalId.Bottom then w,h=size.X,size.Z
     elseif o.Face==Enum.NormalId.Left or o.Face==Enum.NormalId.Right then w,h=size.Z,size.Y end
     record.host={path=host:GetFullName(),locator=ordinalPath(host),color=color(host.Color),transparency=host.Transparency,size={size.X,size.Y,size.Z}}
     if o.SizingMode==Enum.SurfaceGuiSizingMode.PixelsPerStud then record.canvas={w*o.PixelsPerStud,h*o.PixelsPerStud} else record.canvas={o.CanvasSize.X,o.CanvasSize.Y} end
    end
   end
   table.insert(records,record)
  end
 end
end
return {studioId="a6fea703-0c19-4811-ba3e-0e9f90090fe9",datamodel="Edit",nativeMutation=false,records=records}
