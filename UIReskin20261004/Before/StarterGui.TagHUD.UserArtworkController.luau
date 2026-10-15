local gui=script.Parent
local connections={}
local bound={}
local pending={}
local loading=false
local alive=true
local count=0

local function waitForArtwork()
 if loading then return end
 loading=true
 task.spawn(function()
  while alive and next(pending) do
   task.wait(0.25)
   for button,update in pairs(pending) do
    local artwork=button:FindFirstChild("UserArtwork")
    if not button.Parent then pending[button]=nil
    elseif artwork and artwork.IsLoaded then pending[button]=nil update() end
   end
  end
  loading=false
 end)
end

local function connect(signal,callback)
 table.insert(connections,signal:Connect(callback))
end

local function bind(button)
 if bound[button] or not button:IsA("TextButton") or not button:GetAttribute("UserArtworkManaged") then return end
 bound[button]=true
 local artwork=button:FindFirstChild("UserArtwork")
 local textless=button:FindFirstChild("TextlessSkin")
 local live=button:FindFirstChild("LiveCaption")
 if not artwork then return end
 local source=button:FindFirstChild("Caption") or button
 local outline=button:FindFirstChild("Outline")
 local function original(value)
  button.BackgroundTransparency=value and (button:GetAttribute("OriginalBackgroundTransparency") or 0) or 1
  button.TextTransparency=value and (button:GetAttribute("OriginalTextTransparency") or 0) or 1
  if source~=button then source.Visible=value and button:GetAttribute("OriginalCaptionVisible")~=false end
  for _,name in ipairs({"Icon","IconFallback"}) do
   local icon=button:FindFirstChild(name)
   if icon and icon:IsA("GuiObject") then icon.Visible=value and button:GetAttribute("Original"..name.."Visible")==true end
  end
  if outline then outline.Enabled=value and button:GetAttribute("OriginalOutlineEnabled")~=false end
 end
 local function update()
  if not button.Parent then return end
  local value=source.Text
  if live then live.Text=value end
  if not artwork.IsLoaded then
   original(true)
   artwork.Visible=true
   if textless then textless.Visible=false end
   if live then live.Visible=false end
   pending[button]=update
   waitForArtwork()
   return
  end
  original(false)
  local authored=button:GetAttribute("ArtworkText")
  local showLive=live and textless and (authored==nil or value~=authored)
  artwork.Visible=not showLive
  if textless then textless.Visible=showLive==true end
  if live then live.Visible=showLive==true end
 end
 connect(source:GetPropertyChangedSignal("Text"),update)
 connect(artwork:GetPropertyChangedSignal("IsLoaded"),update)
 connect(button:GetAttributeChangedSignal("ArtworkText"),update)
 update()
 count+=1
 gui:SetAttribute("UserArtworkBoundButtons",count)
end

for _,object in ipairs(gui:GetDescendants()) do bind(object) end
connect(gui.DescendantAdded,bind)
connect(script.Destroying,function()
 alive=false
 for _,connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 table.clear(bound)
 table.clear(pending)
end)

