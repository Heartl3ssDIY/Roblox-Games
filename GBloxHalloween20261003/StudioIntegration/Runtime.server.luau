local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local settings = ReplicatedStorage:WaitForChild("GBloxCourseTheme")

local function selectedTheme()
	local value = settings:GetAttribute("ActiveTheme")
	if value == "Normal" or value == "Halloween" then return value end
	warn("GBloxCourseTheme: ActiveTheme must be Normal or Halloween; using Normal.")
	return "Normal"
end

local function refresh()
	settings:SetAttribute("AppliedParts", Theme.Apply(selectedTheme()))
end

settings:GetAttributeChangedSignal("ActiveTheme"):Connect(refresh)
workspace.DescendantAdded:Connect(function(instance)
	if not Theme.IsSupported(instance) then return end
	task.defer(function()
		local ancestor = instance.Parent
		while ancestor and ancestor.Parent ~= workspace do ancestor = ancestor.Parent end
		if ancestor and Theme.IsCourse(ancestor) then Theme.ApplyPart(instance, selectedTheme()) end
	end)
end)
refresh()
