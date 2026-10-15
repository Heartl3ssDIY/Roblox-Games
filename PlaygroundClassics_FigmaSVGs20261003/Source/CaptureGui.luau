local function capture(root,startIndex,count)
 local function values(value) return {value:GetComponents()} end
 local function color(value) return string.format("#%02x%02x%02x",math.round(value.R*255),math.round(value.G*255),math.round(value.B*255)) end
 local function udim(value) return {value.X.Scale,value.X.Offset,value.Y.Scale,value.Y.Offset} end
 local function v2(value) return {value.X,value.Y} end
 local all={root}
 for _,d in ipairs(root:GetDescendants()) do
  if d:IsA("GuiObject") or d:IsA("UIComponent") or d:IsA("Folder") then table.insert(all,d) end
 end
 local rows={}
 for index=startIndex,math.min(#all,startIndex+count-1) do
  local d=all[index]
  local row={id=d:GetFullName(),p=d.Parent and d.Parent:GetFullName(),n=d.Name,c=d.ClassName}
  if d:IsA("ScreenGui") then row.inset=d.IgnoreGuiInset row.enabled=d.Enabled row.order=d.DisplayOrder end
  if d:IsA("GuiObject") then
   row.r={d.AbsolutePosition.X,d.AbsolutePosition.Y,d.AbsoluteSize.X,d.AbsoluteSize.Y}
   row.pos=udim(d.Position) row.size=udim(d.Size) row.anchor=v2(d.AnchorPoint)
   row.bg=color(d.BackgroundColor3) row.bt=d.BackgroundTransparency row.border=d.BorderSizePixel row.bc=color(d.BorderColor3)
   row.visible=d.Visible row.clip=d.ClipsDescendants row.rot=d.Rotation row.z=d.ZIndex row.order=d.LayoutOrder
   if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
    row.t={value=d.Text,content=d.ContentText,font=d.FontFace.Family,weight=d.FontFace.Weight.Name,style=d.FontFace.Style.Name,size=d.TextSize,scaled=d.TextScaled,wrapped=d.TextWrapped,rich=d.RichText,color=color(d.TextColor3),alpha=d.TextTransparency,stroke=color(d.TextStrokeColor3),strokeAlpha=d.TextStrokeTransparency,x=d.TextXAlignment.Name,y=d.TextYAlignment.Name,line=d.LineHeight,bounds=v2(d.TextBounds),truncate=d.TextTruncate.Name}
   end
   if d:IsA("ImageLabel") or d:IsA("ImageButton") then row.image={asset=d.Image,color=color(d.ImageColor3),alpha=d.ImageTransparency,scale=d.ScaleType.Name} end
   if d:IsA("ScrollingFrame") then row.scroll={canvas=udim(d.CanvasSize),absolute=v2(d.AbsoluteCanvasSize),content=v2(d.CanvasPosition),bar=d.ScrollBarThickness,color=color(d.ScrollBarImageColor3)} end
   if d:IsA("ViewportFrame") then
    local camera=d.CurrentCamera or d:FindFirstChildWhichIsA("Camera")
    row.v={camera=camera and values(camera.CFrame),fov=camera and camera.FieldOfView or 40,parts={}}
    for _,part in ipairs(d:GetDescendants()) do if part:IsA("BasePart") then table.insert(row.v.parts,{name=part.Name,class=part.ClassName,shape=part:IsA("Part") and part.Shape.Name or part.ClassName,size={part.Size.X,part.Size.Y,part.Size.Z},cf=values(part.CFrame),color=color(part.Color),alpha=part.Transparency}) end end
   end
  elseif d:IsA("UICorner") then row.radius={d.CornerRadius.Scale,d.CornerRadius.Offset}
  elseif d:IsA("UIStroke") then row.stroke={color=color(d.Color),width=d.Thickness,alpha=d.Transparency,mode=d.ApplyStrokeMode.Name,join=d.LineJoinMode.Name,enabled=d.Enabled}
  elseif d:IsA("UIGradient") then
   local colors={} for _,k in ipairs(d.Color.Keypoints) do table.insert(colors,{k.Time,color(k.Value)}) end
   local alpha={} for _,k in ipairs(d.Transparency.Keypoints) do table.insert(alpha,{k.Time,k.Value}) end
   row.gradient={colors=colors,alpha=alpha,offset=v2(d.Offset),rot=d.Rotation,enabled=d.Enabled}
  elseif d:IsA("UITextSizeConstraint") then row.textConstraint={d.MinTextSize,d.MaxTextSize}
  elseif d:IsA("UISizeConstraint") then row.sizeConstraint={v2(d.MinSize),v2(d.MaxSize)}
  elseif d:IsA("UIListLayout") then row.list={fill=d.FillDirection.Name,padding={d.Padding.Scale,d.Padding.Offset},horizontal=d.HorizontalAlignment.Name,vertical=d.VerticalAlignment.Name,content=v2(d.AbsoluteContentSize)}
  elseif d:IsA("UIGridLayout") then row.grid={cell=udim(d.CellSize),padding=udim(d.CellPadding),content=v2(d.AbsoluteContentSize)}
  elseif d:IsA("UIPadding") then row.padding={d.PaddingLeft.Scale,d.PaddingLeft.Offset,d.PaddingTop.Scale,d.PaddingTop.Offset,d.PaddingRight.Scale,d.PaddingRight.Offset,d.PaddingBottom.Scale,d.PaddingBottom.Offset}
  end
  table.insert(rows,row)
 end
 return game.HttpService:JSONEncode({root=root.Name,viewport={1366,767},total=#all,start=startIndex,nodes=rows})
end

