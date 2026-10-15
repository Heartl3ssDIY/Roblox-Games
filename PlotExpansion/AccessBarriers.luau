-- AccessBarriers: an invisible perimeter that keeps players OUT of warehouses they're not allowed to
-- enter (Friends / Closed). Server-authoritative: if a disallowed player crosses into a warehouse's
-- building footprint, they're pushed back to the nearest edge -- it feels like an invisible wall.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local SSS=game:GetService("ServerScriptService")
local PlotService=require(SSS.Services.PlotService)
local AccessService=require(SSS.Services.AccessService)

local STRUCT={Wall=true, OfficeWall=true, Roof=true, Pillar=true}   -- parts that define the building shell
local aabbCache=setmetatable({},{__mode="k"})   -- [plot.id] = {minX,maxX,minZ,maxZ,topY}

local function plotAABB(plot)
 if not (plot and plot.wh and plot.frame) then return nil end
 local cached=aabbCache[plot.wh];if cached then return cached end
 local mn,mx
 for _,part in plot.wh:GetDescendants() do
  if part:IsA("BasePart") and STRUCT[part:GetAttribute("CustomGroup")] then
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local p=plot.frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5))
    if not mn then mn=p;mx=p else mn=mn:Min(p);mx=mx:Max(p) end
   end end end
  end
 end
 if not mn then return nil end
 local bounds={minX=mn.X,maxX=mx.X,minZ=mn.Z,maxZ=mx.Z,topY=mx.Y}
 aabbCache[plot.wh]=bounds
 return bounds
end

local function notify(plr,text)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind="error"}) end
end
local lastNotify={}   -- [uid]=os.clock() throttle

local function enforce(plr)
	local char=plr.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local pos=hrp.Position
	for _,plot in ipairs(PlotService.all()) do
		local owner=plot.owner
		if owner and owner~=plr and not AccessService.canEnter(plr, owner) then
			local b=plotAABB(plot)
			local pos=plot.frame:PointToObjectSpace(hrp.Position)
			if b and pos.X>b.minX and pos.X<b.maxX and pos.Z>b.minZ and pos.Z<b.maxZ and pos.Y < b.topY+6 then
				local dxMin=pos.X-b.minX; local dxMax=b.maxX-pos.X; local dzMin=pos.Z-b.minZ; local dzMax=b.maxZ-pos.Z
				local m=math.min(dxMin,dxMax,dzMin,dzMax)
				local nx,nz=pos.X,pos.Z
				if m==dxMin then nx=b.minX-3 elseif m==dxMax then nx=b.maxX+3 elseif m==dzMin then nz=b.minZ-3 else nz=b.maxZ+3 end
				hrp.AssemblyLinearVelocity=Vector3.new(0,0,0)
				hrp.CFrame=CFrame.new(plot.frame:PointToWorldSpace(Vector3.new(nx,pos.Y,nz)))*hrp.CFrame.Rotation
				if (os.clock()-(lastNotify[plr.UserId] or 0))>3 then
					lastNotify[plr.UserId]=os.clock()
					notify(plr, (owner.DisplayName or owner.Name).."'s warehouse is closed to you.")
				end
				return
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(plr) lastNotify[plr.UserId]=nil end)
local acc=0
RunService.Heartbeat:Connect(function(dt)
	acc+=dt; if acc<0.2 then return end; acc=0
	for _,plr in ipairs(Players:GetPlayers()) do pcall(enforce, plr) end
end)
print("[AccessBarriers] started")

