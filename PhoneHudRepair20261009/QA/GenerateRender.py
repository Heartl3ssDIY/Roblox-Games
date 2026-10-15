from pathlib import Path

root = Path(__file__).resolve().parent
prefix = (root / "NativeCandidate.luau").read_text(encoding="utf-8").split("local records = {}",1)[0]
body = r'''
part.Name="PhoneHudVisualQA20261009"
part.Size=Vector3.new(85.2,39.3,1)
part.Transparency=0
part.Color=Color3.fromRGB(150,181,142)
local viewport=viewports[1]
local clones=source:Clone()
configure(clones,viewport,"lobby")
local surface=Instance.new("SurfaceGui")
surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
surface.CanvasSize=Vector2.new(viewport.width,viewport.height)
surface.Face=Enum.NormalId.Front
surface.LightInfluence=0
surface.AlwaysOnTop=true
surface.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
surface.Parent=part
local background=Instance.new("Frame")
background.Size=UDim2.fromScale(1,1)
background.BackgroundColor3=Color3.fromRGB(145,184,141)
background.BorderSizePixel=0
background.ZIndex=0
background.Parent=surface
local roots=Instance.new("Folder")
roots.Name="ClonedScreenGuiWrappers"
roots.Parent=surface
for _,gui in clones:GetChildren() do
 local wrapper=Instance.new("Frame")
 wrapper.Name=gui.Name
 wrapper.BackgroundTransparency=1
 wrapper.ZIndex=gui.DisplayOrder
 local inset=gui.ScreenInsets~=Enum.ScreenInsets.None
 local device=inset and gui.ScreenInsets==Enum.ScreenInsets.DeviceSafeInsets
 local x=inset and viewport.left or 0
 local y=inset and viewport.top+(device and 0 or 58) or 0
 local right=inset and viewport.right or 0
 local bottom=inset and viewport.bottom or 0
 wrapper.Position=UDim2.fromOffset(x,y)
 wrapper.Size=UDim2.fromOffset(viewport.width-x-right,viewport.height-y-bottom)
 wrapper.Parent=roots
 for _,child in gui:GetChildren() do child.Parent=wrapper end
 gui:Destroy()
end
clones:Destroy()
source:Destroy()
local function hint(name,pos,size,text,circular)
 local frame=Instance.new("Frame")
 frame.Name=name
 frame.Position=UDim2.fromOffset(pos.X,pos.Y)
 frame.Size=UDim2.fromOffset(size.X,size.Y)
 frame.BorderSizePixel=0
 frame.BackgroundColor3=Color3.fromRGB(28,33,35)
 frame.BackgroundTransparency=circular and .65 or .1
 frame.ZIndex=100
 frame.Parent=surface
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(circular and .5 or 0,circular and 0 or 20)
 corner.Parent=frame
 local label=Instance.new("TextLabel")
 label.BackgroundTransparency=1
 label.Size=UDim2.fromScale(1,1)
 label.Text=text
 label.TextColor3=Color3.fromRGB(246,246,242)
 label.TextSize=circular and 18 or 20
 label.Font=Enum.Font.GothamBold
 label.TextWrapped=true
 label.ZIndex=101
 label.Parent=frame
end
hint("RobloxCoreBar",Vector2.new(44,24),Vector2.new(280,48),"◈    ☰    CHAT    MIC",false)
hint("JoystickReservation",Vector2.new(44,viewport.height-viewport.bottom-120),Vector2.new(120,120),"MOVE",true)
hint("JumpReservation",Vector2.new(viewport.width-viewport.right-98,viewport.height-viewport.bottom-98),Vector2.new(98,98),"↑",true)
hint("SceneCenter",Vector2.new(392,220),Vector2.new(68,90),"PLAYER",false)
task.wait(2)
return game.HttpService:JSONEncode({fixture=part.Name,canvas={852,393},camera={0,-20000,-58},lookAt={0,-20000,0},productionChanged=false,playStarted=false})
'''
(root / "RenderCandidate.luau").write_text(prefix+body,encoding="utf-8")
