-- InventoryService: a per-player inventory for gift rewards the player ACTIVATES on demand instead of
-- them auto-applying -- weather mutations + x2 XP / x2 Cash boosts. Other gift rewards still apply on
-- delivery. Saved in Econ.inv. Replicated to the client via the Inventory RF + InventoryUpdate event.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local CurrencyService=require(script.Parent.CurrencyService)
local WeatherService=require(script.Parent.WeatherService)
local RewardService=require(script.Parent.RewardService)

local InventoryService={}
local byPlayer={}   -- [uid] = { {kind=, ...}, ... }

local function notify(plr,text,kind)
	local rem=RS:FindFirstChild("Remotes"); local n=rem and rem:FindFirstChild("Notify")
	if n then n:FireClient(plr,{text=text,kind=kind or "info"}) end
end
local function ensureIO()
	local rem=RS:FindFirstChild("Remotes"); if not rem then rem=Instance.new("Folder"); rem.Name="Remotes"; rem.Parent=RS end
	local rf=rem:FindFirstChild("Inventory")
	if not rf then rf=Instance.new("RemoteFunction"); rf.Name="Inventory"; rf.Parent=rem end
	local ev=rem:FindFirstChild("InventoryUpdate")
	if not ev then ev=Instance.new("RemoteEvent"); ev.Name="InventoryUpdate"; ev.Parent=rem end
	return rf, ev
end
local function push(plr)
	local _,ev=ensureIO()
	pcall(function() ev:FireClient(plr, byPlayer[plr.UserId] or {}) end)
end
InventoryService.push=push

function InventoryService.get(plr) return byPlayer[plr.UserId] or {} end

function InventoryService.add(plr, item)
	local list=byPlayer[plr.UserId]; if not list then list={}; byPlayer[plr.UserId]=list end
	table.insert(list, item)
	push(plr)
	pcall(function() CurrencyService.SaveNow(plr) end)
	notify(plr, "Inventory: "..(item.label or item.kind).." (open your bag to use it)", "success")
end

function InventoryService.activate(plr, index)
	local list=byPlayer[plr.UserId]; if not list then return {ok=false,msg="Empty"} end
	local item=list[index]; if not item then return {ok=false,msg="No such item"} end
	if item.kind=="weather" then
		if WeatherService.isActive() then return {ok=false,msg="A weather event is already active -- wait for it to end."} end
		WeatherService.forceToday(item.weather)
		table.remove(list, index)
		notify(plr, (item.label or item.weather).." activated!", "success")
	elseif item.kind=="boost" then
		RewardService.addBoost(plr, item.boost, (item.mins or 15)*60)
		table.remove(list, index)
		notify(plr, (item.label or "Boost").." activated -- stacks with any active boost!", "success")
	elseif item.kind=="pkgmutation" then
		-- mutate the parcels currently on the player's floor (rainbow = upgrade rarity, fragile = mark fragile)
		local n=0
		pcall(function()
			local PlotService=require(script.Parent.PlotService)
			local PackageService=require(script.Parent.PackageService)
			local plot=PlotService.forPlayer(plr)
			if plot and plot.staging then
				for _,p in ipairs(plot.staging:GetDescendants()) do
					if p:IsA("BasePart") and p:GetAttribute("Value")~=nil then
						if item.mutation=="rainbow" then pcall(function() PackageService.setRarity(p,"Rainbow") end)
						else p:SetAttribute("Fragile", true) end
						n+=1
					end
				end
			end
		end)
		if n==0 then return {ok=false,msg="No parcels on your floor right now -- use it when packages are out."} end
		table.remove(list, index)
		notify(plr, (item.label or "Mutation").." applied to "..n.." parcel(s)!", "success")
	else
		return {ok=false,msg="Unknown item"}
	end
	push(plr)
	pcall(function() CurrencyService.SaveNow(plr) end)
	return {ok=true}
end

-- SaveService aggregates these into Econ.inv
function InventoryService.getSaved(plr) return byPlayer[plr.UserId] or {} end
function InventoryService.loadSaved(plr, data)
	byPlayer[plr.UserId]=(type(data)=="table") and data or {}
	push(plr)
end
function InventoryService.clearPlayer(plr) byPlayer[plr.UserId]=nil end

function InventoryService.Start()
	local rf=ensureIO()
	rf.OnServerInvoke=function(plr, req)
		if type(req)~="table" then return {ok=false} end
		if req.action=="get" then return {ok=true, items=byPlayer[plr.UserId] or {}} end
		if req.action=="activate" then return InventoryService.activate(plr, tonumber(req.index) or 0) end
		return {ok=false,msg="unknown"}
	end
	Players.PlayerRemoving:Connect(function(plr) byPlayer[plr.UserId]=nil end)
	print("[InventoryService] started")
end

return InventoryService

