-- Reuses the supplied G-Blox artwork; no gameplay or purchase behaviour.
local A={}
A.ButtonImage="rbxassetid://120915846902729"
A.PanelImage="rbxassetid://119353987494774"
local bound=setmetatable({},{__mode="k"})
function A.Text(label)
 label.Font=Enum.Font.Arcade
 label.TextStrokeColor3=Color3.fromRGB(0,13,22)
 label.TextStrokeTransparency=0
end
function A.Panel(frame)
 frame.BackgroundTransparency=1 frame.BorderSizePixel=0
 local art=frame:FindFirstChild("SuppliedBackground")
 if not art then art=Instance.new("ImageLabel") art.Name="SuppliedBackground" end
 art.BackgroundTransparency=1 art.Size=UDim2.fromScale(1,1)
 art.Position=UDim2.fromScale(0,0) art.Image=A.PanelImage
 art.ScaleType=Enum.ScaleType.Stretch art.Active=false art.ZIndex=frame.ZIndex
 for _,child in frame:GetChildren() do
  if child:IsA("GuiObject") and child~=art then child.ZIndex=math.max(child.ZIndex,frame.ZIndex+1) end
  if child:IsA("UIStroke") or child:IsA("UIGradient") then child.Enabled=false end
 end
 art.Parent=frame
 return art
end
function A.Button(button)
 A.Text(button)
 button.BackgroundTransparency=1 button.BorderSizePixel=0
 local art=button:FindFirstChild("SuppliedButtonArtwork")
 if not art then art=Instance.new("ImageLabel") art.Name="SuppliedButtonArtwork" end
 art.BackgroundTransparency=1 art.Position=UDim2.fromScale(0,0) art.Size=UDim2.fromScale(1,1)
 art.Image=A.ButtonImage art.Active=false art.ZIndex=button.ZIndex art.Parent=button
 local caption=button:FindFirstChild("SuppliedCaption")
 if not caption then caption=Instance.new("TextLabel") caption.Name="SuppliedCaption" end
 caption.BackgroundTransparency=1 caption.Position=UDim2.fromScale(.06,.12)
 caption.Size=UDim2.fromScale(.88,.76) caption.Active=false caption.Selectable=false
 caption.TextScaled=true caption.TextWrapped=true caption.RichText=button.RichText
 A.Text(caption) caption.Parent=button
 local limit=caption:FindFirstChildOfClass("UITextSizeConstraint")
 if not limit then limit=Instance.new("UITextSizeConstraint") limit.Parent=caption end
 limit.MinTextSize=8
 local function sync()
  caption.Text=button.Text caption.TextColor3=button.TextColor3
  caption.ZIndex=button.ZIndex+2 art.ZIndex=button.ZIndex
  limit.MaxTextSize=math.max(12,button.TextSize)
 end
 button.TextTransparency=1 sync()
 for _,child in button:GetChildren() do if child:IsA("UIStroke") then child.Enabled=false end end
 if not bound[button] then
  local change=button.Changed:Connect(function(prop)
   if prop=="Text" or prop=="TextColor3" or prop=="TextSize" or prop=="ZIndex" then sync() end
  end)
  local destroy
  destroy=button.Destroying:Connect(function() change:Disconnect() destroy:Disconnect() bound[button]=nil end)
  bound[button]=true
 end
 return art
end
return A

