local UIS=game:GetService("UserInputService"); local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players"); local RunService=game:GetService("RunService")
local plr=Players.LocalPlayer; local gui=script.Parent
local UIArt=(function()
-- Shared presentation only: existing controls retain their input and purchase handlers.
local UIArt={}
local assets=gui:WaitForChild("LaptopAssets")
function UIArt.image(name) return assets:WaitForChild(name).Value end
local function clearDecor(object)
 object.BackgroundTransparency=1;object.BorderSizePixel=0
 for _,c in object:GetChildren() do
  if c:IsA("UIStroke") then c.Enabled=false elseif c:IsA("UIGradient") then c.Enabled=false end
 end
end
function UIArt.panel(object,name,z)
 clearDecor(object)
 local a=object:FindFirstChild("SkinArt")
 if not a then a=Instance.new("ImageLabel");a.Name="SkinArt";a.BackgroundTransparency=1;a.BorderSizePixel=0;a.Active=false;a.Parent=object end
 a.Image=UIArt.image(name);a.ZIndex=math.max(1,(z or object.ZIndex)-1);a.ScaleType=Enum.ScaleType.Fit
 local p=object:FindFirstChildOfClass("UIPadding")
 local l,r,t,b=0,0,0,0
 if p then l=p.PaddingLeft.Offset;r=p.PaddingRight.Offset;t=p.PaddingTop.Offset;b=p.PaddingBottom.Offset end
 a.Position=UDim2.fromOffset(-l,-t);a.Size=UDim2.new(1,l+r,1,t+b)
 if object.BackgroundColor3==Color3.fromRGB(163,162,165) then object.BackgroundColor3=Color3.fromRGB(40,60,128) end
 local function loaded() object.BackgroundTransparency=a.IsLoaded and 1 or 0 end
 a:GetPropertyChangedSignal("IsLoaded"):Connect(loaded);loaded()
 return a
end
return UIArt

end)()
local Remotes=RS:WaitForChild("Remotes"); local action=Remotes:WaitForChild("ManualAction")
local function make(c,p,ch) local i=Instance.new(c); for k,v in pairs(p)do i[k]=v end for _,x in ipairs(ch or{})do x.Parent=i end return i end

-- Grab/Drop button (bottom-center; mobile-friendly)
local btn=make("TextButton",{Name="GrabBtn",BackgroundColor3=Color3.fromRGB(45,120,210),AnchorPoint=Vector2.new(0.5,1),
	Position=UDim2.new(0.5,0,1,-96),Size=UDim2.fromOffset(224,79),Text="",AutoButtonColor=true,ZIndex=14},{
	make("UICorner",{CornerRadius=UDim.new(0,12)}),
	make("UIStroke",{Color=Color3.fromRGB(120,180,255),Thickness=1.5}),
	make("TextLabel",{Name="L",BackgroundTransparency=1,Position=UDim2.fromOffset(54,0),Size=UDim2.new(1,-62,1,0),Font=Enum.Font.FredokaOne,TextSize=16,TextStrokeColor3=Color3.fromRGB(10,15,35),TextStrokeTransparency=.25,ZIndex=15,TextColor3=Color3.new(1,1,1),Text="Grab / Drop  (F)"})})
UIArt.panel(btn,"BlueButton",14)
make("ImageLabel",{Name="Hand",BackgroundTransparency=1,Image=UIArt.image("Hand"),Size=UDim2.fromOffset(44,44),Position=UDim2.new(0,9,.5,0),AnchorPoint=Vector2.new(0,.5),ScaleType=Enum.ScaleType.Fit,ZIndex=15,Parent=btn})
btn.Parent=gui
btn.Activated:Connect(function() action:FireServer() end)
UIS.InputBegan:Connect(function(input,gp)
	if gp then return end
	if input.KeyCode==Enum.KeyCode.F then action:FireServer() end
end)

-- subtle hint: brighten the button when near the staging area (use THIS player's own plot)
local function myWarehouse()
	local ov=plr:FindFirstChild("PlotModel") or plr:WaitForChild("PlotModel",10)
	if ov then
		if not ov.Value then ov:GetPropertyChangedSignal("Value"):Wait() end
		if ov.Value then return ov.Value end
	end
	return workspace:FindFirstChild("Warehouse")
end
local wh=myWarehouse()
local staging=wh and wh:FindFirstChild("Staging")
local acc=0
RunService.RenderStepped:Connect(function(dt)
	acc=acc+dt; if acc<0.3 then return end; acc=0
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
	if hrp and staging then
		local near=(hrp.Position-staging.Position).Magnitude<22
		btn.L.Text = near and "Grab a Parcel  (F)" or "Grab / Drop  (F)"
		btn.BackgroundColor3 = near and Color3.fromRGB(60,170,90) or Color3.fromRGB(45,120,210)
	end
end)
