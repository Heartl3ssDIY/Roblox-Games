assert(not game.RunService:IsRunning())
local folder=Instance.new("Folder") folder.Name="OutlineCloneVerification" folder.Parent=workspace
local module=Instance.new("ModuleScript")
module.Source=[====[local localPlayer={UserId=-987654321}
local outlineCandidates = {}
local knownHighlights = {}
local outlineConnections = {}
local outlineClock = 1

local function outlineCandidate(object)
	if object:IsA("Model") and object:GetAttribute("PCOutlineStored") == true and object:IsDescendantOf(workspace) then
		outlineCandidates[object] = true
		local outline = object:FindFirstChild("CartoonOutline")
		if outline and outline:IsA("Highlight") then outline:SetAttribute("PCCosmeticManaged", true) end
	end
end

local function observeOutlineObject(object)
	if object:IsA("Highlight") then knownHighlights[object] = true end
	outlineCandidate(object)
end

local function clearCosmeticOutline(model)
	local outline = model:FindFirstChild("CartoonOutline")
	if outline and outline:IsA("Highlight") and outline:GetAttribute("PCCosmeticManaged") == true then outline:Destroy() end
end

local function updateCartoonOutlines()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local external = 0
	for highlight in pairs(knownHighlights) do
		if not highlight.Parent then knownHighlights[highlight] = nil
		elseif highlight:GetAttribute("PCCosmeticManaged") ~= true then external += 1 end
	end
	local budget = math.clamp(239 - external, 0, 128)
	local candidates = {}
	for model in pairs(outlineCandidates) do
		if not model.Parent or not model:IsDescendantOf(workspace) then
			clearCosmeticOutline(model)
			outlineCandidates[model] = nil
		elseif model:GetAttribute("PCOutlineEnabled") ~= false then
			local position = model:GetPivot().Position
			local distance = (position - camera.CFrame.Position).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(position)
			local owner = model:GetAttribute("PetOwnerUserId")
			local tool = model:FindFirstAncestorOfClass("Tool")
			local localItem = owner == localPlayer.UserId or (tool and localPlayer.Character and tool:IsDescendantOf(localPlayer.Character))
			local score = localItem and -10000 or distance + (onScreen and 0 or 2000)
			if owner or tool then score -= 100 end
			table.insert(candidates, {model = model, score = score})
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	local wanted = {}
	for index = 1, math.min(budget, #candidates) do wanted[candidates[index].model] = true end
	for model in pairs(outlineCandidates) do
		if not wanted[model] then clearCosmeticOutline(model) end
	end
	for model in pairs(wanted) do
		local outline = model:FindFirstChild("CartoonOutline")
		if not outline then
			outline = Instance.new("Highlight")
			outline.Name = "CartoonOutline"
			outline:SetAttribute("PCCosmeticManaged", true)
			outline.Adornee = model
			outline.Parent = model
		end
		if outline:IsA("Highlight") then
			outline.Enabled = true
			outline.Adornee = model
			outline.FillTransparency = model:GetAttribute("PCOutlineFillTransparency") or 1
			outline.FillColor = model:GetAttribute("PCOutlineFillColor") or Color3.new(1, 1, 1)
			outline.OutlineTransparency = model:GetAttribute("PCOutlineTransparency") or 0
			outline.OutlineColor = model:GetAttribute("PCOutlineColor") or Color3.new(0, 0, 0)
			outline.DepthMode = model:GetAttribute("PCOutlineDepthMode") == "AlwaysOnTop" and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		end
	end
end

local function releaseCartoonOutlines()
	for _, connection in ipairs(outlineConnections) do connection:Disconnect() end
	for model in pairs(outlineCandidates) do if model.Parent then clearCosmeticOutline(model) end end
	table.clear(outlineCandidates)
	table.clear(knownHighlights)
end


return {track=observeOutlineObject,update=updateCartoonOutlines,release=releaseCartoonOutlines,external=function(n) for i=1,n do knownHighlights[{Parent=true,GetAttribute=function() return nil end}]=true end end}]====]
module.Capabilities=game.ServerScriptService.PlaygroundEquipmentService.Capabilities
module.Sandboxed=true module.Parent=game.ServerStorage
local function run()
 local driver=require(module)
 local count,newCount=0,0
 for _,source in ipairs(game.ReplicatedStorage.PlaygroundCosmeticAssets:GetChildren()) do
  if source:IsA("Model") then
   local clone=source:Clone() clone:PivotTo(CFrame.new(0,-10000,0)) clone.Parent=folder
   driver.track(clone)
   for _,h in ipairs(clone:GetDescendants()) do if h:IsA("Highlight") then driver.track(h) end end
   driver.update()
   local h=assert(clone:FindFirstChild("CartoonOutline"),"Missing clone outline "..source.Name)
   assert(h.Adornee==clone and h.OutlineColor==source:GetAttribute("PCOutlineColor") and h.FillTransparency==1)
   if source:GetAttribute("PCExpansionVersion")==20261007 then assert(h.OutlineColor==Color3.new(0,0,0)) newCount+=1 end
   count+=1 driver.release() clone:Destroy()
  end
 end
 local clone=game.ReplicatedStorage.PlaygroundCosmeticAssets.P21:Clone() clone:PivotTo(CFrame.new(0,-10000,0)) clone.Parent=folder
 driver.track(clone) driver.update() assert(clone:FindFirstChild("CartoonOutline"))
 driver.external(239) driver.update() assert(not clone:FindFirstChild("CartoonOutline"),"Budget exceeded")
 driver.release() clone:Destroy()
 return {templates=count,newBlackTemplates=newCount,budgetGuard=true,sandboxed=true}
end
local ok,result=xpcall(run,debug.traceback)
folder:Destroy() module:Destroy()
if not ok then error(result) end
return game.HttpService:JSONEncode(result)
