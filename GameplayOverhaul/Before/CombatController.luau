-- CombatController: client side of the black market. Currently powers the Flying Carpet -- while the
-- carpet tool is equipped you glide with WASD + Space/Shift (relative to the camera). Desktop controls.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local plr=Players.LocalPlayer

local flying=false; local bv=nil; local conn=nil

local function stopFlight(char)
	flying=false
	if conn then conn:Disconnect(); conn=nil end
	if bv then bv:Destroy(); bv=nil end
	if char then local c=char:FindFirstChild("CarpetVisual"); if c then c:Destroy() end end
end

local function startFlight(char)
	local hrp=char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",3)
	if not hrp then return end
	flying=true
	bv=Instance.new("BodyVelocity"); bv.Name="CarpetFly"; bv.MaxForce=Vector3.new(1,1,1)*1e5; bv.Velocity=Vector3.zero; bv.Parent=hrp
	local carpet=Instance.new("Part"); carpet.Name="CarpetVisual"; carpet.Size=Vector3.new(5,0.4,7)
	carpet.Color=Color3.fromRGB(170,45,65); carpet.Material=Enum.Material.Fabric; carpet.CanCollide=false; carpet.Massless=true; carpet.Anchored=false
	carpet.CFrame=hrp.CFrame*CFrame.new(0,-3,0)
	local weld=Instance.new("WeldConstraint"); weld.Part0=hrp; weld.Part1=carpet; weld.Parent=carpet; carpet.Parent=char
	conn=RunService.RenderStepped:Connect(function()
		if not flying or not bv or not bv.Parent then stopFlight(char); return end
		local cam=workspace.CurrentCamera; if not cam then return end
		local dir=Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir+=Vector3.new(0,-1,0) end
		bv.Velocity = (dir.Magnitude>0) and (dir.Unit*65) or Vector3.new(0,0.1,0)
	end)
end

local function hookChar(char)
	char.ChildAdded:Connect(function(c) if c:IsA("Tool") and c.Name=="Flying Carpet" then startFlight(char) end end)
	char.ChildRemoved:Connect(function(c) if c:IsA("Tool") and c.Name=="Flying Carpet" then stopFlight(char) end end)
	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Died:Connect(function() stopFlight(char) end) end
end

-- Retired: the Magic Carpet is now a self-contained tool (ServerStorage.MagicCarpet) with its own
-- flight scripts, so the old generic carpet flight above is no longer hooked up.
local _=hookChar  -- keep reference (defined-but-unused) without running it

