-- SecurityArmouryService: places a gun-rack display in each plot office, and AT NIGHT hands owned
-- armoury guns to the player (removed by day). The guns are the player-supplied FE weapon kits --
-- their own scripts handle firing; we only gate equip to night + ownership (level 15+).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local PlotService=require(script.Parent.PlotService)
local SecurityService=require(script.Parent.SecurityService)
local AccessService=require(script.Parent.AccessService)
local Cfg=require(RS.Configs.SecurityConfig)

local SecurityArmouryService={}
local KIT={gun1="Gun1", gun2="Gun2", shotgun="Gun3"}
local PRIMARY_DESK=Vector3.new(78,3,11)   -- the DeskTop position in the template office
local function models() return ServerStorage:FindFirstChild("SecurityModels") end

-- place a rack in a plot's office (once)
local function ensureRack(plr)
	local plot=PlotService.forPlayer(plr); if not plot then return end
	local folder=plot.LoadBays and plot.LoadBays.Parent; if not folder then return end
	if folder:FindFirstChild("ArmouryRack") then return end
	-- find this plot's desk anywhere in its folder (desk lives under OfficeFurniture)
	local desk; for _,d in ipairs(folder:GetDescendants()) do if d.Name=="DeskTop" then desk=d break end end
	if not desk then return end
	local tmpl=models() and models():FindFirstChild("ArmouryRack"); if not tmpl then return end
	local clone=tmpl:Clone()
	local off=desk.Position - PRIMARY_DESK
	for _,p in ipairs(clone:GetDescendants()) do if p:IsA("BasePart") then p.Position=p.Position+off; p.Anchored=true end end
	clone.Name="ArmouryRack"; clone:SetAttribute("LabelOwner", plot.owner and plot.owner.UserId or 0)
	clone.Parent=folder
end

-- night-gated grant: ensure owned guns are in the backpack at night, gone by day
local function refresh(plr)
	local char=plr.Character; local bp=plr:FindFirstChildOfClass("Backpack"); if not bp then return end
	local night=AccessService.isNight()
	for _,g in ipairs(Cfg.Guns) do
		local toolName = (g.key=="gun1") and SecurityService.gunName(plr,"gun1") or g.name
		local want = night and SecurityService.ownsGun(plr, g.key)
		local existing
		for _,where in ipairs({char, bp}) do
			if where then for _,t in ipairs(where:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SecGun")==g.key then existing=t end end end
		end
		if want and not existing then
			local src=models() and models():FindFirstChild(KIT[g.key])
			if src and src:IsA("Tool") then
				local tool=src:Clone(); tool.Name=toolName; tool:SetAttribute("SecGun", g.key); tool.Parent=bp
			end
		elseif (not want) and existing then existing:Destroy()
		elseif existing and g.key=="gun1" and existing.Name~=toolName then existing.Name=toolName end
	end
end

function SecurityArmouryService.Start()
	-- drop the loose preview rack if present (we place per-office instead)
	local pv=workspace:FindFirstChild("ArmouryRack_Preview"); if pv then pv:Destroy() end
	local function hook(plr)
		plr.CharacterAdded:Connect(function() task.wait(1); pcall(function() refresh(plr) end) end)
	end
	Players.PlayerAdded:Connect(hook)
	for _,plr in ipairs(Players:GetPlayers()) do hook(plr) end
	task.spawn(function()
		while true do
			for _,plr in ipairs(Players:GetPlayers()) do
				pcall(function() ensureRack(plr) end)
				pcall(function() refresh(plr) end)
			end
			task.wait(3)
		end
	end)
	print("[SecurityArmouryService] started")
end
return SecurityArmouryService

